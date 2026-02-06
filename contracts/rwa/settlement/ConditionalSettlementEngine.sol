// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IEscrowVault} from "../../interfaces/IEscrowVault.sol";
import {ISettlementStateMachine} from "../../interfaces/ISettlementStateMachine.sol";
import {IOracleHealthModule} from "../../interfaces/IOracleHealthModule.sol";

/**
 * @title ConditionalSettlementEngine
 * @notice Defines and executes settlement conditions based on protocol state
 * @dev Inputs: time, oracle-verified states, protocol health, governance params
 *      Outputs: RELEASE, CONVERT, LIQUIDATE, REALLOCATE
 */
contract ConditionalSettlementEngine is AccessControl, ReentrancyGuard {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    enum SettlementAction {
        RELEASE,      // Normal settlement
        CONVERT,      // Token conversion
        LIQUIDATE,    // Trigger auction
        REALLOCATE    // Waterfall execution
    }

    // Core protocol contracts
    IEscrowVault public escrowVault;
    ISettlementStateMachine public stateMachine;
    IOracleHealthModule public oracleModule;
    
    // Settlement conditions
    struct SettlementCondition {
        bool isActive;
        uint256 triggerTime;
        uint256 priceThreshold;
        SettlementAction action;
        address[] assets;
    }
    
    mapping(bytes32 => SettlementCondition) public conditions;
    bytes32[] public conditionIds;
    
    // Execution tracking
    mapping(bytes32 => bool) public executedConditions;
    
    // Events
    event ConditionCreated(bytes32 indexed conditionId, SettlementAction action, uint256 triggerTime);
    event ConditionExecuted(bytes32 indexed conditionId, SettlementAction action, uint256 timestamp);
    event ConditionCancelled(bytes32 indexed conditionId);

    constructor(
        address _escrowVault,
        address _stateMachine,
        address _oracleModule,
        address _governance
    ) {
        require(_escrowVault != address(0), "SettlementEngine: invalid vault");
        require(_stateMachine != address(0), "SettlementEngine: invalid state machine");
        require(_oracleModule != address(0), "SettlementEngine: invalid oracle module");
        
        escrowVault = IEscrowVault(_escrowVault);
        stateMachine = ISettlementStateMachine(_stateMachine);
        oracleModule = IOracleHealthModule(_oracleModule);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(GOVERNANCE_ROLE, _governance);
    }

    /**
     * @notice Create a new settlement condition
     */
    function createCondition(
        bytes32 conditionId,
        uint256 triggerTime,
        uint256 priceThreshold,
        SettlementAction action,
        address[] calldata assets
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(!conditions[conditionId].isActive, "SettlementEngine: condition exists");
        require(triggerTime > block.timestamp, "SettlementEngine: invalid trigger time");
        
        conditions[conditionId] = SettlementCondition({
            isActive: true,
            triggerTime: triggerTime,
            priceThreshold: priceThreshold,
            action: action,
            assets: assets
        });
        
        conditionIds.push(conditionId);
        
        emit ConditionCreated(conditionId, action, triggerTime);
    }

    /**
     * @notice Execute a settlement condition if requirements are met
     */
    function executeCondition(bytes32 conditionId) external onlyRole(OPERATOR_ROLE) nonReentrant {
        SettlementCondition memory condition = conditions[conditionId];
        
        require(condition.isActive, "SettlementEngine: condition not active");
        require(!executedConditions[conditionId], "SettlementEngine: already executed");
        require(block.timestamp >= condition.triggerTime, "SettlementEngine: too early");
        
        // Check oracle health
        require(oracleModule.isHealthy(), "SettlementEngine: oracle unhealthy");
        
        // Execute the appropriate action
        if (condition.action == SettlementAction.RELEASE) {
            _executeRelease(condition);
        } else if (condition.action == SettlementAction.CONVERT) {
            _executeConvert(condition);
        } else if (condition.action == SettlementAction.LIQUIDATE) {
            _executeLiquidate(condition);
        } else if (condition.action == SettlementAction.REALLOCATE) {
            _executeReallocate(condition);
        }
        
        executedConditions[conditionId] = true;
        conditions[conditionId].isActive = false;
        
        emit ConditionExecuted(conditionId, condition.action, block.timestamp);
    }

    /**
     * @notice Cancel a settlement condition (governance only)
     */
    function cancelCondition(bytes32 conditionId) external onlyRole(GOVERNANCE_ROLE) {
        require(conditions[conditionId].isActive, "SettlementEngine: condition not active");
        
        conditions[conditionId].isActive = false;
        
        emit ConditionCancelled(conditionId);
    }

    /**
     * @dev Execute RELEASE action
     */
    function _executeRelease(SettlementCondition memory condition) internal {
        // TODO: Implement release logic
        // - Verify settlement conditions met
        // - Authorize escrow withdrawal
        // - Update token supply via MintBurnController
    }

    /**
     * @dev Execute CONVERT action
     */
    function _executeConvert(SettlementCondition memory condition) internal {
        // TODO: Implement conversion logic
        // - Convert tokens to alternative form
        // - Update balances
        // - Emit conversion events
    }

    /**
     * @dev Execute LIQUIDATE action
     */
    function _executeLiquidate(SettlementCondition memory condition) internal {
        // TODO: Implement liquidation logic
        // - Transition state machine to PROTECT
        // - Trigger auction mechanism
        // - Lock escrow vault
    }

    /**
     * @dev Execute REALLOCATE action
     */
    function _executeReallocate(SettlementCondition memory condition) internal {
        // TODO: Implement reallocation logic
        // - Execute waterfall distribution
        // - Apply haircuts if necessary
        // - Update token balances
    }

    /**
     * @notice Check if a condition can be executed
     */
    function canExecuteCondition(bytes32 conditionId) external view returns (bool) {
        SettlementCondition memory condition = conditions[conditionId];
        
        return condition.isActive 
            && !executedConditions[conditionId]
            && block.timestamp >= condition.triggerTime
            && oracleModule.isHealthy();
    }

    /**
     * @notice Get condition details
     */
    function getCondition(bytes32 conditionId) external view returns (
        bool isActive,
        uint256 triggerTime,
        uint256 priceThreshold,
        SettlementAction action,
        address[] memory assets
    ) {
        SettlementCondition memory condition = conditions[conditionId];
        return (
            condition.isActive,
            condition.triggerTime,
            condition.priceThreshold,
            condition.action,
            condition.assets
        );
    }
}
