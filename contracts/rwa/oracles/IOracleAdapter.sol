// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IOracleAdapter
 * @notice Standard interface for oracle adapters (Chainlink, Pyth, etc.)
 */
interface IOracleAdapter {
    /**
     * @notice Get the latest price from the oracle
     * @return price The latest price
     * @return timestamp The timestamp of the price
     */
    function getLatestPrice() external view returns (uint256 price, uint256 timestamp);
    
    /**
     * @notice Get historical price at a specific timestamp
     * @param timestamp The timestamp to query
     * @return price The price at that timestamp
     */
    function getHistoricalPrice(uint256 timestamp) external view returns (uint256 price);
    
    /**
     * @notice Get price decimals
     * @return The number of decimals for the price
     */
    function decimals() external view returns (uint8);
    
    /**
     * @notice Get oracle description/identifier
     * @return Description string
     */
    function description() external view returns (string memory);
}
