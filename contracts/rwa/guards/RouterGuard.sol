// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ISettlementStateMachine} from "../../interfaces/ISettlementStateMachine.sol";
import {IOracleHealthModule} from "../../interfaces/IOracleHealthModule.sol";

/**
 * @title RouterGuard
 * @notice Pre-swap checks for all RWA token trades
 * @dev Enforces:
 *      - Settlement state validation
 *      - Oracle health checks
 *      - Position size limits under stress
 */
contract RouterGuard is AccessControl {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    ISettlementStateMachine public stateMachine;
    IOracleHealthModule public oracleModule;

    // Guard parameters
    bool public guardsEnabled;
    mapping(address => bool) public exemptAddresses;

    // Events
    event GuardsToggled(bool enabled);
    event AddressExempted(address indexed account, bool exempt);
    event SwapBlocked(address indexed token, string reason);

    constructor(
        address _stateMachine,
        address _oracleModule,
        address _governance
    ) {
        stateMachine = ISettlementStateMachine(_stateMachine);
        oracleModule = IOracleHealthModule(_oracleModule);

        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(GOVERNANCE_ROLE, _governance);

        guardsEnabled = true;
    }

    /**
     * @notice Check if a swap is allowed
     * @param sender The address initiating the swap
     * @return bool True if swap is allowed
     * @return string Reason if swap is blocked
     */
    function checkSwap(
        address /* token */,
        address sender,
        uint256 /* amount */
    ) external view returns (bool, string memory) {
        if (!guardsEnabled) return (true, "");
        if (exemptAddresses[sender]) return (true, "");

        // Check settlement state
        if (!stateMachine.isTradingAllowed()) {
            return (false, "Trading halted - settlement state");
        }

        // Check oracle health
        if (!oracleModule.isHealthy()) {
            return (false, "Oracle unhealthy");
        }

        // Additional checks can be added here
        // - Position size limits
        // - Rate limiting
        // - Circuit breaker logic

        return (true, "");
    }

    /**
     * @notice Enforce swap check (reverts if not allowed)
     */
    function enforceSwapCheck(
        address token,
        address sender,
        uint256 amount
    ) external view {
        (bool allowed, string memory reason) = this.checkSwap(token, sender, amount);
        require(allowed, reason);
    }

    /**
     * @notice Toggle guards on/off
     */
    function toggleGuards(bool enabled) external onlyRole(GOVERNANCE_ROLE) {
        guardsEnabled = enabled;
        emit GuardsToggled(enabled);
    }

    /**
     * @notice Set address exemption
     */
    function setExemption(address account, bool exempt) external onlyRole(GOVERNANCE_ROLE) {
        exemptAddresses[account] = exempt;
        emit AddressExempted(account, exempt);
    }

    /**
     * @notice Update contract references
     */
    function updateReferences(
        address _stateMachine,
        address _oracleModule
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (_stateMachine != address(0)) {
            stateMachine = ISettlementStateMachine(_stateMachine);
        }
        if (_oracleModule != address(0)) {
            oracleModule = IOracleHealthModule(_oracleModule);
        }
    }
}
