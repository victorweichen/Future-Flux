// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IComplianceModule.sol";

/**
 * @title TransferRestriction
 * @notice Modular compliance layer for RWA token transfers
 * @dev Operates at transfer boundary, does not alter settlement logic
 */
contract TransferRestriction is IComplianceModule, AccessControl {
    bytes32 public constant COMPLIANCE_ADMIN_ROLE = keccak256("COMPLIANCE_ADMIN_ROLE");

    mapping(address => bool) public whitelist;
    bool public whitelistEnabled;
    
    // Transfer limits
    uint256 public maxTransferAmount;
    uint256 public dailyTransferLimit;
    mapping(address => uint256) public dailyTransferred;
    mapping(address => uint256) public lastTransferDay;
    
    // Events
    event AddressWhitelisted(address indexed account);
    event AddressRemovedFromWhitelist(address indexed account);
    event WhitelistToggled(bool enabled);
    event TransferLimitsUpdated(uint256 maxAmount, uint256 dailyLimit);

    constructor(address _governance) {
        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(COMPLIANCE_ADMIN_ROLE, _governance);
        
        whitelistEnabled = true;
        maxTransferAmount = type(uint256).max;
        dailyTransferLimit = type(uint256).max;
    }

    /**
     * @notice Check if a transfer is compliant
     */
    function canTransfer(address from, address to, uint256 amount) external view override returns (bool) {
        // Check whitelist if enabled
        if (whitelistEnabled) {
            if (!whitelist[from] || !whitelist[to]) {
                return false;
            }
        }
        
        // Check transfer limits
        if (amount > maxTransferAmount) {
            return false;
        }
        
        // Check daily limit for sender
        uint256 currentDay = block.timestamp / 1 days;
        if (lastTransferDay[from] == currentDay) {
            if (dailyTransferred[from] + amount > dailyTransferLimit) {
                return false;
            }
        }
        
        return true;
    }

    /**
     * @notice Add address to whitelist
     */
    function addToWhitelist(address account) external onlyRole(COMPLIANCE_ADMIN_ROLE) {
        whitelist[account] = true;
        emit AddressWhitelisted(account);
    }

    /**
     * @notice Remove address from whitelist
     */
    function removeFromWhitelist(address account) external onlyRole(COMPLIANCE_ADMIN_ROLE) {
        whitelist[account] = false;
        emit AddressRemovedFromWhitelist(account);
    }

    /**
     * @notice Batch add to whitelist
     */
    function batchAddToWhitelist(address[] calldata accounts) external onlyRole(COMPLIANCE_ADMIN_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            whitelist[accounts[i]] = true;
            emit AddressWhitelisted(accounts[i]);
        }
    }

    /**
     * @notice Toggle whitelist enforcement
     */
    function toggleWhitelist(bool enabled) external onlyRole(COMPLIANCE_ADMIN_ROLE) {
        whitelistEnabled = enabled;
        emit WhitelistToggled(enabled);
    }

    /**
     * @notice Update transfer limits
     */
    function updateTransferLimits(
        uint256 _maxTransferAmount,
        uint256 _dailyTransferLimit
    ) external onlyRole(COMPLIANCE_ADMIN_ROLE) {
        maxTransferAmount = _maxTransferAmount;
        dailyTransferLimit = _dailyTransferLimit;
        emit TransferLimitsUpdated(_maxTransferAmount, _dailyTransferLimit);
    }

    /**
     * @notice Check if address is whitelisted
     */
    function isWhitelisted(address account) external view override returns (bool) {
        return whitelist[account];
    }
}
