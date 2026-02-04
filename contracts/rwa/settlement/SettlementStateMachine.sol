// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../../interfaces/ISettlementStateMachine.sol";

/**
 * @title SettlementStateMachine
 * @notice Manages settlement states and transitions for the RWA protocol
 * @dev States: NORMAL → WARNING → PROTECT → DEFAULT → RECOVERY → HALT
 *      All transitions are rule-based and observable on-chain
 */
contract SettlementStateMachine is ISettlementStateMachine, AccessControl {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant SETTLEMENT_ENGINE_ROLE = keccak256("SETTLEMENT_ENGINE_ROLE");

    enum State {
        NORMAL,      // Normal operation
        WARNING,     // Risk detected, monitoring escalated
        PROTECT,     // Trading halted, AMM bypassed
        DEFAULT,     // Issuer default confirmed
        RECOVERY,    // Post-default recovery phase
        HALT         // Emergency halt
    }

    State public currentState;
    
    // State transition tracking
    uint256 public lastStateChange;
    mapping(State => uint256) public stateEnterTime;
    
    // Transition parameters
    uint256 public warningThreshold;      // Time in WARNING before PROTECT
    uint256 public protectCooldown;       // Min time in PROTECT before resolution
    
    // State history
    struct StateTransition {
        State fromState;
        State toState;
        uint256 timestamp;
        string reason;
    }
    StateTransition[] public stateHistory;

    // Events
    event StateChanged(State indexed fromState, State indexed toState, string reason);
    event TransitionParametersUpdated(uint256 warningThreshold, uint256 protectCooldown);

    modifier onlyValidTransition(State newState) {
        require(_isValidTransition(currentState, newState), "StateMachine: invalid transition");
        _;
    }

    constructor(address _governance) {
        currentState = State.NORMAL;
        lastStateChange = block.timestamp;
        stateEnterTime[State.NORMAL] = block.timestamp;
        
        warningThreshold = 1 hours;
        protectCooldown = 30 minutes;
        
        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(GOVERNANCE_ROLE, _governance);
    }

    /**
     * @notice Transition to a new state
     * @param newState The target state
     * @param reason Description of why the transition occurred
     */
    function transitionTo(
        State newState,
        string calldata reason
    ) external onlyRole(SETTLEMENT_ENGINE_ROLE) onlyValidTransition(newState) {
        State oldState = currentState;
        currentState = newState;
        lastStateChange = block.timestamp;
        stateEnterTime[newState] = block.timestamp;
        
        stateHistory.push(StateTransition({
            fromState: oldState,
            toState: newState,
            timestamp: block.timestamp,
            reason: reason
        }));
        
        emit StateChanged(oldState, newState, reason);
    }

    /**
     * @notice Emergency halt - can only be called by governance
     */
    function emergencyHalt(string calldata reason) external onlyRole(GOVERNANCE_ROLE) {
        State oldState = currentState;
        currentState = State.HALT;
        lastStateChange = block.timestamp;
        stateEnterTime[State.HALT] = block.timestamp;
        
        stateHistory.push(StateTransition({
            fromState: oldState,
            toState: State.HALT,
            timestamp: block.timestamp,
            reason: reason
        }));
        
        emit StateChanged(oldState, State.HALT, reason);
    }

    /**
     * @notice Check if a state transition is valid
     */
    function _isValidTransition(State from, State to) internal pure returns (bool) {
        // NORMAL can go to WARNING or HALT
        if (from == State.NORMAL) {
            return to == State.WARNING || to == State.HALT;
        }
        
        // WARNING can go to NORMAL, PROTECT, or HALT
        if (from == State.WARNING) {
            return to == State.NORMAL || to == State.PROTECT || to == State.HALT;
        }
        
        // PROTECT can go to WARNING, DEFAULT, or HALT
        if (from == State.PROTECT) {
            return to == State.WARNING || to == State.DEFAULT || to == State.HALT;
        }
        
        // DEFAULT can only go to RECOVERY or HALT
        if (from == State.DEFAULT) {
            return to == State.RECOVERY || to == State.HALT;
        }
        
        // RECOVERY can go to NORMAL or HALT
        if (from == State.RECOVERY) {
            return to == State.NORMAL || to == State.HALT;
        }
        
        // HALT is terminal unless governance intervenes
        if (from == State.HALT) {
            return to == State.NORMAL; // Only governance can restore from HALT
        }
        
        return false;
    }

    /**
     * @notice Check if trading is allowed in current state
     */
    function isTradingAllowed() external view returns (bool) {
        return currentState == State.NORMAL || currentState == State.WARNING;
    }

    /**
     * @notice Check if liquidation should occur
     */
    function shouldLiquidate() external view returns (bool) {
        return currentState == State.PROTECT || currentState == State.DEFAULT;
    }

    /**
     * @notice Get time spent in current state
     */
    function getTimeInCurrentState() external view returns (uint256) {
        return block.timestamp - stateEnterTime[currentState];
    }

    /**
     * @notice Check if WARNING threshold has been exceeded
     */
    function hasExceededWarningThreshold() external view returns (bool) {
        if (currentState != State.WARNING) return false;
        return block.timestamp - stateEnterTime[State.WARNING] >= warningThreshold;
    }

    /**
     * @notice Update transition parameters
     */
    function updateParameters(
        uint256 _warningThreshold,
        uint256 _protectCooldown
    ) external onlyRole(GOVERNANCE_ROLE) {
        warningThreshold = _warningThreshold;
        protectCooldown = _protectCooldown;
        
        emit TransitionParametersUpdated(_warningThreshold, _protectCooldown);
    }

    /**
     * @notice Get current state as uint
     */
    function getCurrentState() external view returns (uint8) {
        return uint8(currentState);
    }

    /**
     * @notice Get state history length
     */
    function getStateHistoryLength() external view returns (uint256) {
        return stateHistory.length;
    }
}
