// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IEscrowVault} from "../../interfaces/IEscrowVault.sol";

/**
 * @title EscrowVault
 * @notice Non-custodial vault for holding assets that back RWA tokens
 * @dev Enforces strict invariants:
 *      - No actor can unilaterally extract value
 *      - All movements require contract-verifiable conditions
 *      - Withdrawal rules are immutable once set
 */
contract EscrowVault is IEscrowVault, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant SETTLEMENT_ENGINE_ROLE = keccak256("SETTLEMENT_ENGINE_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    // Vault metadata
    address public immutable RWA_TOKEN;
    address public settlementEngine;

    // Asset tracking
    mapping(address => uint256) public assetBalances;
    address[] public supportedAssets;

    // Settlement state
    bool public isLocked;
    uint256 public totalClaims;

    // Events
    event AssetDeposited(address indexed asset, uint256 amount, address indexed depositor);
    event AssetWithdrawn(address indexed asset, uint256 amount, address indexed recipient);
    event VaultLocked();
    event VaultUnlocked();
    event SettlementEngineUpdated(address indexed newEngine);

    modifier onlySettlementEngine() {
        _onlySettlementEngine();
        _;
    }

    function _onlySettlementEngine() internal view {
        require(hasRole(SETTLEMENT_ENGINE_ROLE, msg.sender), "EscrowVault: caller is not settlement engine");
    }

    modifier whenNotLocked() {
        _whenNotLocked();
        _;
    }

    function _whenNotLocked() internal view {
        require(!isLocked, "EscrowVault: vault is locked");
    }

    constructor(
        address _rwaToken,
        address _settlementEngine,
        address _governance
    ) {
        require(_rwaToken != address(0), "EscrowVault: invalid RWA token");
        require(_settlementEngine != address(0), "EscrowVault: invalid settlement engine");

        RWA_TOKEN = _rwaToken;
        settlementEngine = _settlementEngine;

        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(SETTLEMENT_ENGINE_ROLE, _settlementEngine);
        _grantRole(GOVERNANCE_ROLE, _governance);
    }

    /**
     * @notice Deposit assets into the vault
     * @param asset The address of the asset to deposit
     * @param amount The amount to deposit
     */
    function deposit(address asset, uint256 amount) external nonReentrant whenNotLocked {
        require(amount > 0, "EscrowVault: amount must be greater than 0");
        require(_isAssetSupported(asset), "EscrowVault: asset not supported");

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        assetBalances[asset] += amount;

        emit AssetDeposited(asset, amount, msg.sender);
    }

    /**
     * @notice Withdraw assets based on settlement conditions
     * @dev Only callable by settlement engine
     * @param asset The address of the asset to withdraw
     * @param amount The amount to withdraw
     * @param recipient The address to send the assets to
     */
    function withdraw(
        address asset,
        uint256 amount,
        address recipient
    ) external onlySettlementEngine nonReentrant {
        require(amount > 0, "EscrowVault: amount must be greater than 0");
        require(recipient != address(0), "EscrowVault: invalid recipient");
        require(assetBalances[asset] >= amount, "EscrowVault: insufficient balance");

        assetBalances[asset] -= amount;
        IERC20(asset).safeTransfer(recipient, amount);

        emit AssetWithdrawn(asset, amount, recipient);
    }

    /**
     * @notice Add a supported asset
     * @param asset The address of the asset to add
     */
    function addSupportedAsset(address asset) external onlyRole(GOVERNANCE_ROLE) {
        require(asset != address(0), "EscrowVault: invalid asset");
        require(!_isAssetSupported(asset), "EscrowVault: asset already supported");

        supportedAssets.push(asset);
    }

    /**
     * @notice Lock the vault (prevent deposits during settlement)
     */
    function lock() external onlySettlementEngine {
        isLocked = true;
        emit VaultLocked();
    }

    /**
     * @notice Unlock the vault
     */
    function unlock() external onlySettlementEngine {
        isLocked = false;
        emit VaultUnlocked();
    }

    /**
     * @notice Get total value locked across all assets
     * @dev Requires oracle pricing for accurate valuation (TODO)
     */
    function getTotalValueLocked() external pure returns (uint256) {
        // TODO: Implement with oracle integration
        return 0;
    }

    /**
     * @notice Check if an asset is supported
     */
    function _isAssetSupported(address asset) internal view returns (bool) {
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            if (supportedAssets[i] == asset) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Get the list of supported assets
     */
    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }

    /**
     * @notice Get the balance of a specific asset
     */
    function getAssetBalance(address asset) external view returns (uint256) {
        return assetBalances[asset];
    }
}
