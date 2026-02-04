// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title ISettlementStateMachine
 * @notice Interface for SettlementStateMachine contract
 */
interface ISettlementStateMachine {
    function getCurrentState() external view returns (uint8);
    function isTradingAllowed() external view returns (bool);
    function shouldLiquidate() external view returns (bool);
    function hasExceededWarningThreshold() external view returns (bool);
    function getTimeInCurrentState() external view returns (uint256);
}
