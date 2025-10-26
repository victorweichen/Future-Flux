// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FutureFluxDEX
 * @dev Core DEX contract for Future Flux platform
 * Handles token swaps and liquidity for RWA tokens
 */
contract FutureFluxDEX is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Trading pair structure
    struct TradingPair {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        bool active;
    }

    // Liquidity provider tracking
    struct LiquidityProvider {
        uint256 liquidity;
        uint256 lastDeposit;
    }

    // Trading pairs by ID
    mapping(uint256 => TradingPair) public pairs;
    // Liquidity providers per pair
    mapping(uint256 => mapping(address => LiquidityProvider)) public liquidityProviders;
    // Pair counter
    uint256 public pairCount;
    
    // Fee configuration (in basis points, e.g., 30 = 0.3%)
    uint256 public tradingFee = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;

    // Events
    event PairCreated(uint256 indexed pairId, address indexed tokenA, address indexed tokenB);
    event LiquidityAdded(uint256 indexed pairId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(uint256 indexed pairId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(uint256 indexed pairId, address indexed user, address indexed tokenIn, uint256 amountIn, uint256 amountOut);
    event FeeUpdated(uint256 newFee);

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Create a new trading pair
     */
    function createPair(address tokenA, address tokenB) external onlyOwner returns (uint256) {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token addresses");
        require(tokenA != tokenB, "Identical tokens");

        uint256 pairId = pairCount++;
        pairs[pairId] = TradingPair({
            tokenA: tokenA,
            tokenB: tokenB,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            active: true
        });

        emit PairCreated(pairId, tokenA, tokenB);
        return pairId;
    }

    /**
     * @dev Add liquidity to a trading pair
     */
    function addLiquidity(
        uint256 pairId,
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant returns (uint256 liquidity) {
        TradingPair storage pair = pairs[pairId];
        require(pair.active, "Pair not active");
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        // Transfer tokens from user
        IERC20(pair.tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(pair.tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        // Calculate liquidity tokens to mint
        if (pair.totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            uint256 liquidityA = (amountA * pair.totalLiquidity) / pair.reserveA;
            uint256 liquidityB = (amountB * pair.totalLiquidity) / pair.reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }

        require(liquidity > 0, "Insufficient liquidity minted");

        // Update state
        pair.reserveA += amountA;
        pair.reserveB += amountB;
        pair.totalLiquidity += liquidity;
        
        liquidityProviders[pairId][msg.sender].liquidity += liquidity;
        liquidityProviders[pairId][msg.sender].lastDeposit = block.timestamp;

        emit LiquidityAdded(pairId, msg.sender, amountA, amountB, liquidity);
    }

    /**
     * @dev Remove liquidity from a trading pair
     */
    function removeLiquidity(
        uint256 pairId,
        uint256 liquidity
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        TradingPair storage pair = pairs[pairId];
        require(pair.active, "Pair not active");
        require(liquidity > 0, "Invalid liquidity amount");
        require(liquidityProviders[pairId][msg.sender].liquidity >= liquidity, "Insufficient liquidity");

        // Calculate token amounts to return
        amountA = (liquidity * pair.reserveA) / pair.totalLiquidity;
        amountB = (liquidity * pair.reserveB) / pair.totalLiquidity;

        require(amountA > 0 && amountB > 0, "Insufficient amounts");

        // Update state
        pair.reserveA -= amountA;
        pair.reserveB -= amountB;
        pair.totalLiquidity -= liquidity;
        liquidityProviders[pairId][msg.sender].liquidity -= liquidity;

        // Transfer tokens back to user
        IERC20(pair.tokenA).safeTransfer(msg.sender, amountA);
        IERC20(pair.tokenB).safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(pairId, msg.sender, amountA, amountB, liquidity);
    }

    /**
     * @dev Swap tokens
     */
    function swap(
        uint256 pairId,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant returns (uint256 amountOut) {
        TradingPair storage pair = pairs[pairId];
        require(pair.active, "Pair not active");
        require(amountIn > 0, "Invalid input amount");
        require(tokenIn == pair.tokenA || tokenIn == pair.tokenB, "Invalid token");

        // Determine input/output reserves
        (uint256 reserveIn, uint256 reserveOut, address tokenOut) = tokenIn == pair.tokenA
            ? (pair.reserveA, pair.reserveB, pair.tokenB)
            : (pair.reserveB, pair.reserveA, pair.tokenA);

        // Calculate output amount with fee
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - tradingFee);
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);

        require(amountOut >= minAmountOut, "Insufficient output amount");
        require(amountOut < reserveOut, "Insufficient liquidity");

        // Transfer tokens
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        // Update reserves
        if (tokenIn == pair.tokenA) {
            pair.reserveA += amountIn;
            pair.reserveB -= amountOut;
        } else {
            pair.reserveB += amountIn;
            pair.reserveA -= amountOut;
        }

        emit Swap(pairId, msg.sender, tokenIn, amountIn, amountOut);
    }

    /**
     * @dev Update trading fee (only owner)
     */
    function setTradingFee(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "Fee too high"); // Max 1%
        tradingFee = newFee;
        emit FeeUpdated(newFee);
    }

    /**
     * @dev Get quote for swap
     */
    function getQuote(
        uint256 pairId,
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        TradingPair memory pair = pairs[pairId];
        require(pair.active, "Pair not active");
        require(tokenIn == pair.tokenA || tokenIn == pair.tokenB, "Invalid token");

        (uint256 reserveIn, uint256 reserveOut) = tokenIn == pair.tokenA
            ? (pair.reserveA, pair.reserveB)
            : (pair.reserveB, pair.reserveA);

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - tradingFee);
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);
    }

    /**
     * @dev Square root function for liquidity calculation
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
