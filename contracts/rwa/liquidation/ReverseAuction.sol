// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../interfaces/IAMMPool.sol";

/**
 * @title ReverseAuction
 * @notice Designated buyer settlement window mechanism
 * @dev Allows designated buyer to commit capital, lock AMM liquidity,
 *      execute a swap via the AMM, and burn acquired RWA tokens.
 *      Prevents liquidity flight during execution window.
 */
contract ReverseAuction is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    enum ReverseAuctionStatus {
        PENDING,
        LOCKED,
        EXECUTED,
        CANCELLED
    }

    struct ReverseAuctionData {
        uint256 auctionId;
        address buyer;
        address settlementToken;
        uint256 committedAmount;
        uint256 executionTime;
        uint256 lockupPeriod;
        address targetToken;
        address ammPool;
        ReverseAuctionStatus status;
        uint256 acquiredAmount;
    }

    // Auction tracking
    uint256 public nextAuctionId;
    mapping(uint256 => ReverseAuctionData) public reverseAuctions;

    // Burn integration
    address public mintBurnController;

    // Parameters
    uint256 public maxLockupDuration;
    uint256 public cooldownPeriod;
    mapping(address => uint256) public lastAuctionTime;

    // Events
    event ReverseAuctionCreated(uint256 indexed auctionId, address indexed buyer, uint256 committedAmount, uint256 executionTime);
    event CapitalCommitted(uint256 indexed auctionId, uint256 amount);
    event LiquidityLocked(uint256 indexed auctionId, address indexed ammPool);
    event LiquidityUnlocked(uint256 indexed auctionId, address indexed ammPool);
    event ReverseAuctionExecuted(uint256 indexed auctionId, uint256 acquiredTokens, uint256 avgPrice);
    event TokensBurned(uint256 indexed auctionId, uint256 amount);
    event ReverseAuctionCancelled(uint256 indexed auctionId, string reason);

    constructor(address _governance, address _mintBurnController) {
        require(_mintBurnController != address(0), "ReverseAuction: invalid mint burn controller");

        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(GOVERNANCE_ROLE, _governance);

        mintBurnController = _mintBurnController;
        maxLockupDuration = 3 days;
        cooldownPeriod = 28 days;
        nextAuctionId = 1;
    }

    /**
     * @notice Create a reverse auction
     */
    function createReverseAuction(
        address buyer,
        address settlementToken,
        uint256 committedAmount,
        uint256 executionTime,
        uint256 lockupPeriod,
        address targetToken,
        address ammPool
    ) external onlyRole(OPERATOR_ROLE) returns (uint256) {
        require(buyer != address(0), "ReverseAuction: invalid buyer");
        require(ammPool != address(0), "ReverseAuction: invalid AMM pool");
        require(executionTime > block.timestamp, "ReverseAuction: invalid execution time");
        require(lockupPeriod <= maxLockupDuration, "ReverseAuction: lockup too long");
        require(committedAmount > 0, "ReverseAuction: invalid amount");

        // Check cooldown
        require(
            block.timestamp >= lastAuctionTime[targetToken] + cooldownPeriod,
            "ReverseAuction: cooldown not elapsed"
        );

        uint256 auctionId = nextAuctionId++;

        reverseAuctions[auctionId] = ReverseAuctionData({
            auctionId: auctionId,
            buyer: buyer,
            settlementToken: settlementToken,
            committedAmount: committedAmount,
            executionTime: executionTime,
            lockupPeriod: lockupPeriod,
            targetToken: targetToken,
            ammPool: ammPool,
            status: ReverseAuctionStatus.PENDING,
            acquiredAmount: 0
        });

        lastAuctionTime[targetToken] = block.timestamp;

        emit ReverseAuctionCreated(auctionId, buyer, committedAmount, executionTime);

        return auctionId;
    }

    /**
     * @notice Commit capital to reverse auction and lock AMM liquidity
     */
    function commitCapital(uint256 auctionId) external nonReentrant {
        ReverseAuctionData storage auction = reverseAuctions[auctionId];

        require(auction.status == ReverseAuctionStatus.PENDING, "ReverseAuction: not pending");
        require(msg.sender == auction.buyer, "ReverseAuction: not designated buyer");

        // Transfer settlement token
        IERC20(auction.settlementToken).safeTransferFrom(
            msg.sender,
            address(this),
            auction.committedAmount
        );

        auction.status = ReverseAuctionStatus.LOCKED;

        // Lock AMM liquidity to prevent front-running
        IAMMPool(auction.ammPool).lockLiquidity();

        emit CapitalCommitted(auctionId, auction.committedAmount);
        emit LiquidityLocked(auctionId, auction.ammPool);
    }

    /**
     * @notice Execute reverse auction: swap via AMM and burn acquired tokens
     */
    function execute(uint256 auctionId) external onlyRole(OPERATOR_ROLE) nonReentrant {
        ReverseAuctionData storage auction = reverseAuctions[auctionId];

        require(auction.status == ReverseAuctionStatus.LOCKED, "ReverseAuction: not locked");
        require(block.timestamp >= auction.executionTime, "ReverseAuction: too early");
        require(
            block.timestamp < auction.executionTime + auction.lockupPeriod,
            "ReverseAuction: window expired"
        );

        // Approve settlement token to AMM pool
        IERC20(auction.settlementToken).approve(auction.ammPool, auction.committedAmount);

        // Execute swap via AMM
        uint256 acquiredTokens = IAMMPool(auction.ammPool).swap(
            auction.settlementToken,
            auction.committedAmount,
            0
        );

        auction.status = ReverseAuctionStatus.EXECUTED;
        auction.acquiredAmount = acquiredTokens;

        // Burn acquired tokens via MintBurnController
        if (acquiredTokens > 0) {
            (bool success,) = mintBurnController.call(
                abi.encodeWithSignature("burn(address,uint256)", address(this), acquiredTokens)
            );
            require(success, "ReverseAuction: burn failed");

            emit TokensBurned(auctionId, acquiredTokens);
        }

        // Unlock AMM liquidity
        IAMMPool(auction.ammPool).unlockLiquidity();

        uint256 avgPrice = acquiredTokens > 0 ? (auction.committedAmount * 1e18) / acquiredTokens : 0;

        emit LiquidityUnlocked(auctionId, auction.ammPool);
        emit ReverseAuctionExecuted(auctionId, acquiredTokens, avgPrice);
    }

    /**
     * @notice Cancel reverse auction
     */
    function cancel(uint256 auctionId, string calldata reason) external onlyRole(GOVERNANCE_ROLE) {
        ReverseAuctionData storage auction = reverseAuctions[auctionId];

        require(
            auction.status == ReverseAuctionStatus.PENDING || auction.status == ReverseAuctionStatus.LOCKED,
            "ReverseAuction: cannot cancel"
        );

        // Unlock liquidity and refund if capital was committed
        if (auction.status == ReverseAuctionStatus.LOCKED) {
            IAMMPool(auction.ammPool).unlockLiquidity();
            IERC20(auction.settlementToken).safeTransfer(auction.buyer, auction.committedAmount);

            emit LiquidityUnlocked(auctionId, auction.ammPool);
        }

        auction.status = ReverseAuctionStatus.CANCELLED;

        emit ReverseAuctionCancelled(auctionId, reason);
    }

    /**
     * @notice Expire auction after execution window passes without execution
     */
    function expireAuction(uint256 auctionId) external nonReentrant {
        ReverseAuctionData storage auction = reverseAuctions[auctionId];

        require(auction.status == ReverseAuctionStatus.LOCKED, "ReverseAuction: not locked");
        require(
            block.timestamp >= auction.executionTime + auction.lockupPeriod,
            "ReverseAuction: window not expired"
        );

        // Unlock AMM liquidity
        IAMMPool(auction.ammPool).unlockLiquidity();

        // Refund committed capital
        IERC20(auction.settlementToken).safeTransfer(auction.buyer, auction.committedAmount);

        auction.status = ReverseAuctionStatus.CANCELLED;

        emit LiquidityUnlocked(auctionId, auction.ammPool);
        emit ReverseAuctionCancelled(auctionId, "Execution window expired");
    }

    /**
     * @notice Get reverse auction details
     */
    function getReverseAuction(uint256 auctionId) external view returns (ReverseAuctionData memory) {
        return reverseAuctions[auctionId];
    }

    /**
     * @notice Check if reverse auction can be executed
     */
    function canExecute(uint256 auctionId) external view returns (bool) {
        ReverseAuctionData memory auction = reverseAuctions[auctionId];
        return auction.status == ReverseAuctionStatus.LOCKED
            && block.timestamp >= auction.executionTime
            && block.timestamp < auction.executionTime + auction.lockupPeriod;
    }

    /**
     * @notice Update parameters
     */
    function updateParameters(
        uint256 _maxLockupDuration,
        uint256 _cooldownPeriod
    ) external onlyRole(GOVERNANCE_ROLE) {
        maxLockupDuration = _maxLockupDuration;
        cooldownPeriod = _cooldownPeriod;
    }
}
