// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../interfaces/ISettlementStateMachine.sol";
import "../../interfaces/IAMMPool.sol";

/**
 * @title LPSettlementClaim
 * @notice Allows LP holders to claim settlement proceeds for RWA tokens locked in AMM pools
 * @dev When the system enters PROTECT/DEFAULT state, LP holders cannot withdraw liquidity.
 *      This contract lets them prove their underlying RWA token exposure via LP positions
 *      and receive haircutted settlement proceeds directly.
 *
 *      Flow:
 *      1. Governance registers known AMM pools containing RWA tokens
 *      2. LP holders call registerClaim() to lock LP tokens and record RWA exposure
 *      3. After waterfall execution, LP holders call claimSettlement() for recovery
 */
contract LPSettlementClaim is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // State: PROTECT = 2, DEFAULT = 3
    uint8 public constant STATE_PROTECT = 2;
    uint8 public constant STATE_DEFAULT = 3;

    ISettlementStateMachine public stateMachine;
    IERC20 public settlementToken;

    // Waterfall integration
    address public waterfallDistributor;

    // Pool registry
    mapping(address => bool) public registeredPools;
    mapping(address => address) public poolRWAToken;

    // Claim tracking: user → total RWA exposure across all pools
    mapping(address => uint256) public totalUserClaims;
    // Per-pool claim tracking: pool → user → RWA amount
    mapping(address => mapping(address => uint256)) public claims;
    // Settlement claim tracking
    mapping(address => bool) public hasClaimedSettlement;

    // Events
    event PoolRegistered(address indexed pool, address indexed rwaToken);
    event ClaimRegistered(address indexed user, address indexed pool, uint256 lpAmount, uint256 rwaExposure);
    event SettlementClaimed(address indexed user, uint256 rwaAmount, uint256 recoveryAmount);

    constructor(
        address _stateMachine,
        address _settlementToken,
        address _waterfallDistributor,
        address _governance
    ) {
        require(_stateMachine != address(0), "LPSettlementClaim: invalid state machine");
        require(_settlementToken != address(0), "LPSettlementClaim: invalid settlement token");
        require(_waterfallDistributor != address(0), "LPSettlementClaim: invalid waterfall");

        stateMachine = ISettlementStateMachine(_stateMachine);
        settlementToken = IERC20(_settlementToken);
        waterfallDistributor = _waterfallDistributor;

        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(GOVERNANCE_ROLE, _governance);
    }

    /**
     * @notice Register an AMM pool that contains RWA tokens
     * @param pool The AMM pool address
     * @param rwaToken The RWA token address held in the pool
     */
    function registerPool(address pool, address rwaToken) external onlyRole(GOVERNANCE_ROLE) {
        require(pool != address(0), "LPSettlementClaim: invalid pool");
        require(rwaToken != address(0), "LPSettlementClaim: invalid RWA token");
        require(!registeredPools[pool], "LPSettlementClaim: pool already registered");

        // Verify the pool actually contains the RWA token
        IAMMPool ammPool = IAMMPool(pool);
        require(
            ammPool.token0() == rwaToken || ammPool.token1() == rwaToken,
            "LPSettlementClaim: pool does not contain RWA token"
        );

        registeredPools[pool] = true;
        poolRWAToken[pool] = rwaToken;

        emit PoolRegistered(pool, rwaToken);
    }

    /**
     * @notice Register an LP claim by locking LP tokens
     * @param pool The AMM pool address
     * @param lpAmount The amount of LP tokens to lock
     */
    function registerClaim(address pool, uint256 lpAmount) external nonReentrant {
        // Must be in PROTECT or DEFAULT state
        uint8 currentState = stateMachine.getCurrentState();
        require(
            currentState == STATE_PROTECT || currentState == STATE_DEFAULT,
            "LPSettlementClaim: not in settlement state"
        );
        require(registeredPools[pool], "LPSettlementClaim: pool not registered");
        require(lpAmount > 0, "LPSettlementClaim: invalid amount");

        // Transfer LP tokens from caller (locks them)
        IERC20(pool).safeTransferFrom(msg.sender, address(this), lpAmount);

        // Calculate RWA exposure
        uint256 rwaExposure = getRWAExposure(pool, lpAmount);
        require(rwaExposure > 0, "LPSettlementClaim: zero exposure");

        // Record claim
        claims[pool][msg.sender] += rwaExposure;
        totalUserClaims[msg.sender] += rwaExposure;

        emit ClaimRegistered(msg.sender, pool, lpAmount, rwaExposure);
    }

    /**
     * @notice Claim settlement proceeds after waterfall execution
     */
    function claimSettlement() external nonReentrant {
        require(!hasClaimedSettlement[msg.sender], "LPSettlementClaim: already claimed");

        uint256 totalClaim = totalUserClaims[msg.sender];
        require(totalClaim > 0, "LPSettlementClaim: no claims");

        // Check waterfall has been executed
        (bool success, bytes memory data) = waterfallDistributor.staticcall(
            abi.encodeWithSignature("isExecuted()")
        );
        require(success && abi.decode(data, (bool)), "LPSettlementClaim: waterfall not executed");

        // Calculate recovery using waterfall's haircut ratio
        (success, data) = waterfallDistributor.staticcall(
            abi.encodeWithSignature("calculateRecovery(uint256)", totalClaim)
        );
        require(success, "LPSettlementClaim: recovery calculation failed");
        uint256 recoveryAmount = abi.decode(data, (uint256));

        hasClaimedSettlement[msg.sender] = true;

        if (recoveryAmount > 0) {
            settlementToken.safeTransfer(msg.sender, recoveryAmount);
        }

        emit SettlementClaimed(msg.sender, totalClaim, recoveryAmount);
    }

    /**
     * @notice Calculate RWA token exposure for a given LP amount
     * @param pool The AMM pool address
     * @param lpAmount The LP token amount
     * @return The equivalent RWA token amount
     */
    function getRWAExposure(address pool, uint256 lpAmount) public view returns (uint256) {
        require(registeredPools[pool], "LPSettlementClaim: pool not registered");

        IAMMPool ammPool = IAMMPool(pool);
        address rwaToken = poolRWAToken[pool];

        (uint256 reserve0, uint256 reserve1) = ammPool.getReserves();
        uint256 lpTotalSupply = ammPool.totalSupply();

        if (lpTotalSupply == 0) return 0;

        // Determine which reserve is the RWA token
        uint256 rwaReserve = ammPool.token0() == rwaToken ? reserve0 : reserve1;

        return (lpAmount * rwaReserve) / lpTotalSupply;
    }

    /**
     * @notice Get total registered claim amount for a user
     * @param user The user address
     * @return The total RWA token claim amount
     */
    function getClaimAmount(address user) external view returns (uint256) {
        return totalUserClaims[user];
    }

    /**
     * @notice Fund the contract with settlement tokens for payouts
     * @param amount The amount to deposit
     */
    function fundSettlement(uint256 amount) external onlyRole(OPERATOR_ROLE) {
        settlementToken.safeTransferFrom(msg.sender, address(this), amount);
    }
}
