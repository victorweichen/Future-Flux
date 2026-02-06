// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ISettlementStateMachine} from "../../interfaces/ISettlementStateMachine.sol";

/**
 * @title PositionThrottler
 * @notice Limits position sizes and trading frequency under stress
 * @dev Active during WARNING and PROTECT states
 */
contract PositionThrottler is AccessControl {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    ISettlementStateMachine public stateMachine;
    
    // Throttling parameters
    uint256 public normalMaxPositionSize;
    uint256 public warningMaxPositionSize;
    uint256 public protectMaxPositionSize;
    
    // Rate limiting
    uint256 public minTimeBetweenTrades;
    mapping(address => uint256) public lastTradeTime;
    
    // Position tracking
    mapping(address => uint256) public currentPositionSize;
    
    // Events
    event PositionLimitsUpdated(uint256 normal, uint256 warning, uint256 protect);
    event TradeThrottled(address indexed trader, string reason);
    event RateLimitUpdated(uint256 minTime);

    constructor(
        address _stateMachine,
        address _governance
    ) {
        stateMachine = ISettlementStateMachine(_stateMachine);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(GOVERNANCE_ROLE, _governance);
        
        // Default limits
        normalMaxPositionSize = 1000000 * 1e18;  // 1M tokens
        warningMaxPositionSize = 100000 * 1e18;  // 100K tokens
        protectMaxPositionSize = 10000 * 1e18;   // 10K tokens
        minTimeBetweenTrades = 0;                 // No rate limit in normal
    }

    /**
     * @notice Check if a trade is allowed based on current state
     */
    function checkTrade(
        address trader,
        uint256 amount,
        bool isIncrease
    ) external view returns (bool, string memory) {
        uint8 state = stateMachine.getCurrentState();
        
        // State 0 = NORMAL, 1 = WARNING, 2 = PROTECT
        uint256 maxSize;
        if (state == 0) {
            maxSize = normalMaxPositionSize;
        } else if (state == 1) {
            maxSize = warningMaxPositionSize;
        } else if (state == 2) {
            maxSize = protectMaxPositionSize;
        } else {
            // DEFAULT, RECOVERY, HALT - no trading
            return (false, "Trading disabled in current state");
        }
        
        // Check position size
        uint256 newPosition = isIncrease 
            ? currentPositionSize[trader] + amount
            : currentPositionSize[trader];
            
        if (newPosition > maxSize) {
            return (false, "Position size exceeds limit");
        }
        
        // Check rate limiting
        if (state >= 1 && minTimeBetweenTrades > 0) {
            if (block.timestamp < lastTradeTime[trader] + minTimeBetweenTrades) {
                return (false, "Rate limit exceeded");
            }
        }
        
        return (true, "");
    }

    /**
     * @notice Enforce trade check (reverts if not allowed)
     */
    function enforceTrade(
        address trader,
        uint256 amount,
        bool isIncrease
    ) external view {
        (bool allowed, string memory reason) = this.checkTrade(trader, amount, isIncrease);
        require(allowed, reason);
    }

    /**
     * @notice Record a trade
     */
    function recordTrade(address trader, uint256 amount, bool isIncrease) external {
        if (isIncrease) {
            currentPositionSize[trader] += amount;
        } else {
            if (amount >= currentPositionSize[trader]) {
                currentPositionSize[trader] = 0;
            } else {
                currentPositionSize[trader] -= amount;
            }
        }
        
        lastTradeTime[trader] = block.timestamp;
    }

    /**
     * @notice Update position limits
     */
    function updatePositionLimits(
        uint256 _normal,
        uint256 _warning,
        uint256 _protect
    ) external onlyRole(GOVERNANCE_ROLE) {
        normalMaxPositionSize = _normal;
        warningMaxPositionSize = _warning;
        protectMaxPositionSize = _protect;
        
        emit PositionLimitsUpdated(_normal, _warning, _protect);
    }

    /**
     * @notice Update rate limit
     */
    function updateRateLimit(uint256 _minTime) external onlyRole(GOVERNANCE_ROLE) {
        minTimeBetweenTrades = _minTime;
        emit RateLimitUpdated(_minTime);
    }

    /**
     * @notice Get current max position size based on state
     */
    function getCurrentMaxPosition() external view returns (uint256) {
        uint8 state = stateMachine.getCurrentState();
        
        if (state == 0) return normalMaxPositionSize;
        if (state == 1) return warningMaxPositionSize;
        if (state == 2) return protectMaxPositionSize;
        
        return 0;
    }
}
