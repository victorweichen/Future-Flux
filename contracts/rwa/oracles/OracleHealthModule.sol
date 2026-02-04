// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../../interfaces/IOracleAdapter.sol";

/**
 * @title OracleHealthModule
 * @notice Monitors oracle health and triggers protective measures
 * @dev Does NOT trigger liquidations on oracle failure
 *      Instead, transitions to PROTECT mode
 */
contract OracleHealthModule is AccessControl {
    bytes32 public constant ORACLE_ADMIN_ROLE = keccak256("ORACLE_ADMIN_ROLE");
    bytes32 public constant SETTLEMENT_ENGINE_ROLE = keccak256("SETTLEMENT_ENGINE_ROLE");

    struct OracleConfig {
        IOracleAdapter adapter;
        uint256 heartbeatThreshold;  // Max time between updates
        uint256 deviationThreshold;  // Max % deviation from other oracles (basis points)
        bool isActive;
    }

    // Oracle configurations
    mapping(address => OracleConfig) public oracles;
    address[] public oracleAddresses;
    
    // Health tracking
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => bool) public oracleHealthStatus;
    
    uint256 public minHealthyOracles; // Minimum number of healthy oracles required
    uint256 public volatilityThreshold; // Max acceptable volatility (basis points)
    
    // Circuit breaker
    bool public circuitBreakerTripped;
    uint256 public circuitBreakerTripTime;
    
    // Events
    event OracleAdded(address indexed oracle, uint256 heartbeat, uint256 deviation);
    event OracleRemoved(address indexed oracle);
    event OracleUnhealthy(address indexed oracle, string reason);
    event OracleRecovered(address indexed oracle);
    event CircuitBreakerTripped(string reason);
    event CircuitBreakerReset();
    event HealthParametersUpdated(uint256 minHealthy, uint256 volatilityThreshold);

    constructor(address _governance, uint256 _minHealthyOracles) {
        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(ORACLE_ADMIN_ROLE, _governance);
        
        minHealthyOracles = _minHealthyOracles;
        volatilityThreshold = 1000; // 10% default
    }

    /**
     * @notice Add an oracle to the health monitoring system
     */
    function addOracle(
        address oracle,
        address adapter,
        uint256 heartbeat,
        uint256 deviation
    ) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(oracle != address(0), "OracleHealth: invalid oracle");
        require(adapter != address(0), "OracleHealth: invalid adapter");
        require(!oracles[oracle].isActive, "OracleHealth: oracle already exists");
        
        oracles[oracle] = OracleConfig({
            adapter: IOracleAdapter(adapter),
            heartbeatThreshold: heartbeat,
            deviationThreshold: deviation,
            isActive: true
        });
        
        oracleAddresses.push(oracle);
        oracleHealthStatus[oracle] = true;
        lastUpdateTime[oracle] = block.timestamp;
        
        emit OracleAdded(oracle, heartbeat, deviation);
    }

    /**
     * @notice Remove an oracle from monitoring
     */
    function removeOracle(address oracle) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(oracles[oracle].isActive, "OracleHealth: oracle not active");
        
        oracles[oracle].isActive = false;
        
        // Remove from array
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            if (oracleAddresses[i] == oracle) {
                oracleAddresses[i] = oracleAddresses[oracleAddresses.length - 1];
                oracleAddresses.pop();
                break;
            }
        }
        
        emit OracleRemoved(oracle);
    }

    /**
     * @notice Check health of all oracles
     */
    function checkAllOracles() external onlyRole(SETTLEMENT_ENGINE_ROLE) {
        uint256 healthyCount = 0;
        
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            address oracle = oracleAddresses[i];
            if (!oracles[oracle].isActive) continue;
            
            bool healthy = _checkOracleHealth(oracle);
            oracleHealthStatus[oracle] = healthy;
            
            if (healthy) {
                healthyCount++;
            } else {
                emit OracleUnhealthy(oracle, "Health check failed");
            }
        }
        
        // Trip circuit breaker if too few healthy oracles
        if (healthyCount < minHealthyOracles && !circuitBreakerTripped) {
            _tripCircuitBreaker("Insufficient healthy oracles");
        }
    }

    /**
     * @dev Check health of a single oracle
     */
    function _checkOracleHealth(address oracle) internal returns (bool) {
        OracleConfig memory config = oracles[oracle];
        
        // Check heartbeat
        try config.adapter.getLatestPrice() returns (uint256 price, uint256 timestamp) {
            if (block.timestamp - timestamp > config.heartbeatThreshold) {
                return false; // Stale data
            }
            
            lastUpdateTime[oracle] = timestamp;
            
            // Check cross-oracle deviation
            if (!_checkDeviation(oracle, price)) {
                return false;
            }
            
            return true;
        } catch {
            return false; // Oracle call failed
        }
    }

    /**
     * @dev Check if oracle price deviates too much from others
     */
    function _checkDeviation(address oracle, uint256 price) internal view returns (bool) {
        OracleConfig memory config = oracles[oracle];
        uint256 healthyOracleCount = 0;
        uint256 totalPrice = 0;
        
        // Calculate average price from other healthy oracles
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            address otherOracle = oracleAddresses[i];
            if (otherOracle == oracle || !oracles[otherOracle].isActive || !oracleHealthStatus[otherOracle]) {
                continue;
            }
            
            try oracles[otherOracle].adapter.getLatestPrice() returns (uint256 otherPrice, uint256) {
                totalPrice += otherPrice;
                healthyOracleCount++;
            } catch {
                continue;
            }
        }
        
        if (healthyOracleCount == 0) return true; // No comparison possible
        
        uint256 avgPrice = totalPrice / healthyOracleCount;
        uint256 deviation = price > avgPrice 
            ? ((price - avgPrice) * 10000) / avgPrice
            : ((avgPrice - price) * 10000) / avgPrice;
        
        return deviation <= config.deviationThreshold;
    }

    /**
     * @notice Trip circuit breaker
     */
    function _tripCircuitBreaker(string memory reason) internal {
        circuitBreakerTripped = true;
        circuitBreakerTripTime = block.timestamp;
        emit CircuitBreakerTripped(reason);
    }

    /**
     * @notice Reset circuit breaker (governance only)
     */
    function resetCircuitBreaker() external onlyRole(ORACLE_ADMIN_ROLE) {
        require(circuitBreakerTripped, "OracleHealth: circuit breaker not tripped");
        circuitBreakerTripped = false;
        emit CircuitBreakerReset();
    }

    /**
     * @notice Check if system is healthy
     */
    function isHealthy() external view returns (bool) {
        if (circuitBreakerTripped) return false;
        
        uint256 healthyCount = 0;
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]].isActive && oracleHealthStatus[oracleAddresses[i]]) {
                healthyCount++;
            }
        }
        
        return healthyCount >= minHealthyOracles;
    }

    /**
     * @notice Get health status of all oracles
     */
    function getHealthStatus() external view returns (
        address[] memory healthyOracles,
        address[] memory unhealthyOracles
    ) {
        uint256 healthyCount = 0;
        uint256 unhealthyCount = 0;
        
        // Count first
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]].isActive) {
                if (oracleHealthStatus[oracleAddresses[i]]) {
                    healthyCount++;
                } else {
                    unhealthyCount++;
                }
            }
        }
        
        // Allocate arrays
        healthyOracles = new address[](healthyCount);
        unhealthyOracles = new address[](unhealthyCount);
        
        // Fill arrays
        uint256 hIndex = 0;
        uint256 uIndex = 0;
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            address oracle = oracleAddresses[i];
            if (oracles[oracle].isActive) {
                if (oracleHealthStatus[oracle]) {
                    healthyOracles[hIndex++] = oracle;
                } else {
                    unhealthyOracles[uIndex++] = oracle;
                }
            }
        }
        
        return (healthyOracles, unhealthyOracles);
    }

    /**
     * @notice Update health parameters
     */
    function updateHealthParameters(
        uint256 _minHealthyOracles,
        uint256 _volatilityThreshold
    ) external onlyRole(ORACLE_ADMIN_ROLE) {
        minHealthyOracles = _minHealthyOracles;
        volatilityThreshold = _volatilityThreshold;
        emit HealthParametersUpdated(_minHealthyOracles, _volatilityThreshold);
    }
}
