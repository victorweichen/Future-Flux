// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IComplianceModule
 * @notice Interface for compliance modules
 */
interface IComplianceModule {
    /**
     * @notice Check if a transfer is compliant
     * @param from Sender address
     * @param to Receiver address
     * @param amount Transfer amount
     * @return bool True if transfer is allowed
     */
    function canTransfer(address from, address to, uint256 amount) external view returns (bool);
    
    /**
     * @notice Check if an address is whitelisted
     * @param account Address to check
     * @return bool True if whitelisted
     */
    function isWhitelisted(address account) external view returns (bool);
}
