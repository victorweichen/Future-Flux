// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IOracleHealthModule
 * @notice Interface for OracleHealthModule contract
 */
interface IOracleHealthModule {
    function isHealthy() external view returns (bool);
    function checkAllOracles() external;
    function addOracle(address oracle, address adapter, uint256 heartbeat, uint256 deviation) external;
    function removeOracle(address oracle) external;
}
