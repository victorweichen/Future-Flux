// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IAMMPool
 * @notice Interface for AMM pool operations
 * @dev Used by LPSettlementClaim for LP exposure queries and
 *      ReverseAuction for swap execution and liquidity lockup
 */
interface IAMMPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut);
    function lockLiquidity() external;
    function unlockLiquidity() external;
}
