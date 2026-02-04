// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title ISettlementEngine
 * @notice Interface for the settlement engine used by EscrowVault
 */
interface ISettlementEngine {
    function executeCondition(bytes32 conditionId) external;
    function canExecuteCondition(bytes32 conditionId) external view returns (bool);
}
