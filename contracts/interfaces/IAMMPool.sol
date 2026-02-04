// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IAMMPool
 * @notice Minimal interface for querying AMM pool state
 * @dev Used by LPSettlementClaim to calculate RWA token exposure from LP positions
 */
interface IAMMPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}
