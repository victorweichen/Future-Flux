// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IOracleAdapter.sol";

/**
 * @title MultiOracleAggregator
 * @notice Aggregates multiple oracle sources for price feeds
 * @dev Provides:
 *      - Cross-oracle validation
 *      - Manipulation detection
 *      - Confidence scoring
 */
contract MultiOracleAggregator is AccessControl {
    bytes32 public constant ORACLE_ADMIN_ROLE = keccak256("ORACLE_ADMIN_ROLE");

    struct OracleSource {
        IOracleAdapter adapter;
        uint256 weight;  // Basis points (10000 = 100%)
        bool isActive;
    }

    struct PriceData {
        uint256 weightedPrice;
        uint256 medianPrice;
        uint256 minPrice;
        uint256 maxPrice;
        uint256 confidence;  // Basis points (10000 = 100% confidence)
        uint256 timestamp;
    }

    // Oracle sources
    mapping(address => OracleSource) public oracles;
    address[] public oracleAddresses;
    
    // Aggregation parameters
    uint256 public maxDeviation; // Max acceptable deviation between oracles (basis points)
    uint256 public minOracleCount; // Minimum number of valid oracle responses
    
    // Events
    event OracleSourceAdded(address indexed oracle, uint256 weight);
    event OracleSourceRemoved(address indexed oracle);
    event OracleWeightUpdated(address indexed oracle, uint256 newWeight);
    event PriceAggregated(uint256 weightedPrice, uint256 confidence, uint256 sources);
    event DeviationDetected(uint256 maxDeviation, uint256 actualDeviation);

    constructor(address _governance, uint256 _maxDeviation) {
        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(ORACLE_ADMIN_ROLE, _governance);
        
        maxDeviation = _maxDeviation;
        minOracleCount = 2; // Require at least 2 oracles
    }

    /**
     * @notice Add an oracle source
     */
    function addOracleSource(
        address oracle,
        address adapter,
        uint256 weight
    ) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(oracle != address(0), "MultiOracle: invalid oracle");
        require(adapter != address(0), "MultiOracle: invalid adapter");
        require(!oracles[oracle].isActive, "MultiOracle: oracle exists");
        
        oracles[oracle] = OracleSource({
            adapter: IOracleAdapter(adapter),
            weight: weight,
            isActive: true
        });
        
        oracleAddresses.push(oracle);
        
        emit OracleSourceAdded(oracle, weight);
    }

    /**
     * @notice Remove an oracle source
     */
    function removeOracleSource(address oracle) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(oracles[oracle].isActive, "MultiOracle: oracle not active");
        
        oracles[oracle].isActive = false;
        
        // Remove from array
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            if (oracleAddresses[i] == oracle) {
                oracleAddresses[i] = oracleAddresses[oracleAddresses.length - 1];
                oracleAddresses.pop();
                break;
            }
        }
        
        emit OracleSourceRemoved(oracle);
    }

    /**
     * @notice Get aggregated price from all oracle sources
     */
    function getAggregatedPrice() external returns (PriceData memory) {
        uint256[] memory prices = new uint256[](oracleAddresses.length);
        uint256[] memory weights = new uint256[](oracleAddresses.length);
        uint256 validCount = 0;
        
        // Collect prices from all active oracles
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            address oracle = oracleAddresses[i];
            OracleSource memory source = oracles[oracle];
            
            if (!source.isActive) continue;
            
            try source.adapter.getLatestPrice() returns (uint256 price, uint256 timestamp) {
                // Reject stale prices (older than 1 hour)
                if (block.timestamp - timestamp > 1 hours) continue;
                
                prices[validCount] = price;
                weights[validCount] = source.weight;
                validCount++;
            } catch {
                continue; // Skip failed oracle
            }
        }
        
        require(validCount >= minOracleCount, "MultiOracle: insufficient valid oracles");
        
        // Calculate aggregated metrics
        uint256 weightedPrice = _calculateWeightedPrice(prices, weights, validCount);
        uint256 medianPrice = _calculateMedian(prices, validCount);
        (uint256 minPrice, uint256 maxPrice) = _getMinMax(prices, validCount);
        uint256 confidence = _calculateConfidence(prices, validCount);
        
        return PriceData({
            weightedPrice: weightedPrice,
            medianPrice: medianPrice,
            minPrice: minPrice,
            maxPrice: maxPrice,
            confidence: confidence,
            timestamp: block.timestamp
        });
    }

    /**
     * @dev Calculate weighted average price
     */
    function _calculateWeightedPrice(
        uint256[] memory prices,
        uint256[] memory weights,
        uint256 count
    ) internal pure returns (uint256) {
        uint256 totalWeighted = 0;
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < count; i++) {
            totalWeighted += prices[i] * weights[i];
            totalWeight += weights[i];
        }
        
        return totalWeighted / totalWeight;
    }

    /**
     * @dev Calculate median price
     */
    function _calculateMedian(uint256[] memory prices, uint256 count) internal pure returns (uint256) {
        // Simple bubble sort for median calculation
        for (uint256 i = 0; i < count - 1; i++) {
            for (uint256 j = 0; j < count - i - 1; j++) {
                if (prices[j] > prices[j + 1]) {
                    uint256 temp = prices[j];
                    prices[j] = prices[j + 1];
                    prices[j + 1] = temp;
                }
            }
        }
        
        if (count % 2 == 0) {
            return (prices[count / 2 - 1] + prices[count / 2]) / 2;
        } else {
            return prices[count / 2];
        }
    }

    /**
     * @dev Get min and max prices
     */
    function _getMinMax(uint256[] memory prices, uint256 count) internal pure returns (uint256, uint256) {
        uint256 min = prices[0];
        uint256 max = prices[0];
        
        for (uint256 i = 1; i < count; i++) {
            if (prices[i] < min) min = prices[i];
            if (prices[i] > max) max = prices[i];
        }
        
        return (min, max);
    }

    /**
     * @dev Calculate confidence score based on price deviation
     */
    function _calculateConfidence(uint256[] memory prices, uint256 count) internal returns (uint256) {
        if (count < 2) return 10000; // 100% if only one oracle
        
        (uint256 minPrice, uint256 maxPrice) = _getMinMax(prices, count);
        uint256 avgPrice = (minPrice + maxPrice) / 2;
        
        if (avgPrice == 0) return 0;
        
        uint256 deviation = ((maxPrice - minPrice) * 10000) / avgPrice;
        
        if (deviation > maxDeviation) {
            emit DeviationDetected(maxDeviation, deviation);
            return 0; // No confidence if deviation too high
        }
        
        // Linear confidence reduction based on deviation
        // 0% deviation = 100% confidence
        // maxDeviation = 0% confidence
        return 10000 - ((deviation * 10000) / maxDeviation);
    }

    /**
     * @notice Update oracle weight
     */
    function updateOracleWeight(address oracle, uint256 newWeight) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(oracles[oracle].isActive, "MultiOracle: oracle not active");
        oracles[oracle].weight = newWeight;
        emit OracleWeightUpdated(oracle, newWeight);
    }

    /**
     * @notice Update max deviation threshold
     */
    function updateMaxDeviation(uint256 _maxDeviation) external onlyRole(ORACLE_ADMIN_ROLE) {
        maxDeviation = _maxDeviation;
    }

    /**
     * @notice Get oracle count
     */
    function getOracleCount() external view returns (uint256 active, uint256 total) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]].isActive) {
                activeCount++;
            }
        }
        return (activeCount, oracleAddresses.length);
    }
}
