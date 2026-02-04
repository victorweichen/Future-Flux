// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IEscrowVault
 * @notice Interface for EscrowVault contract
 */
interface IEscrowVault {
    function deposit(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount, address recipient) external;
    function lock() external;
    function unlock() external;
    function getTotalValueLocked() external view returns (uint256);
    function getAssetBalance(address asset) external view returns (uint256);
    function isLocked() external view returns (bool);
}
