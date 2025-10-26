# Smart Contract Documentation

## Overview

The Future Flux platform consists of two main smart contracts:

1. **FutureFluxDEX** - The core DEX contract
2. **RWAToken** - Token standard for Real World Assets

## FutureFluxDEX

### Core Functions

#### createPair
```solidity
function createPair(address tokenA, address tokenB) external onlyOwner returns (uint256)
```
Creates a new trading pair between two tokens.

**Parameters:**
- `tokenA`: Address of the first token
- `tokenB`: Address of the second token

**Returns:** Pair ID

**Access:** Only contract owner

#### addLiquidity
```solidity
function addLiquidity(uint256 pairId, uint256 amountA, uint256 amountB) 
    external nonReentrant returns (uint256 liquidity)
```
Adds liquidity to a trading pair.

**Parameters:**
- `pairId`: ID of the trading pair
- `amountA`: Amount of token A to add
- `amountB`: Amount of token B to add

**Returns:** Liquidity tokens minted

#### removeLiquidity
```solidity
function removeLiquidity(uint256 pairId, uint256 liquidity) 
    external nonReentrant returns (uint256 amountA, uint256 amountB)
```
Removes liquidity from a trading pair.

**Parameters:**
- `pairId`: ID of the trading pair
- `liquidity`: Amount of liquidity tokens to burn

**Returns:** Amounts of tokens A and B returned

#### swap
```solidity
function swap(uint256 pairId, address tokenIn, uint256 amountIn, uint256 minAmountOut) 
    external nonReentrant returns (uint256 amountOut)
```
Swaps tokens in a trading pair.

**Parameters:**
- `pairId`: ID of the trading pair
- `tokenIn`: Address of the input token
- `amountIn`: Amount of input tokens
- `minAmountOut`: Minimum acceptable output amount (slippage protection)

**Returns:** Amount of output tokens received

#### getQuote
```solidity
function getQuote(uint256 pairId, address tokenIn, uint256 amountIn) 
    external view returns (uint256 amountOut)
```
Gets a quote for a token swap without executing it.

**Parameters:**
- `pairId`: ID of the trading pair
- `tokenIn`: Address of the input token
- `amountIn`: Amount of input tokens

**Returns:** Expected output amount

### Events

- `PairCreated(uint256 indexed pairId, address indexed tokenA, address indexed tokenB)`
- `LiquidityAdded(uint256 indexed pairId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity)`
- `LiquidityRemoved(uint256 indexed pairId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity)`
- `Swap(uint256 indexed pairId, address indexed user, address indexed tokenIn, uint256 amountIn, uint256 amountOut)`
- `FeeUpdated(uint256 newFee)`

## RWAToken

### Core Functions

#### mint
```solidity
function mint(address to, uint256 amount) external onlyOwner
```
Mints new tokens (only callable by owner).

#### burn
```solidity
function burn(uint256 amount) external
```
Burns tokens from sender's balance.

#### setTransfersEnabled
```solidity
function setTransfersEnabled(bool enabled) external onlyOwner
```
Enables or disables token transfers.

#### updateAssetMetadata
```solidity
function updateAssetMetadata(string memory metadata) external onlyOwner
```
Updates the asset metadata string.

### Properties

- `assetType`: Type of the real-world asset (e.g., "Real Estate", "Commodities")
- `assetMetadata`: JSON or URI containing asset details
- `maxSupply`: Maximum token supply
- `transfersEnabled`: Whether transfers are currently enabled

## Security Features

1. **ReentrancyGuard**: Protects against reentrancy attacks on critical functions
2. **Ownable**: Access control for administrative functions
3. **SafeERC20**: Safe token transfers using OpenZeppelin's SafeERC20 library
4. **Input Validation**: Comprehensive checks on all parameters
5. **Slippage Protection**: Minimum output amounts on swaps

## Trading Fee

- Default: 0.3% (30 basis points)
- Maximum: 1% (100 basis points)
- Configurable by contract owner
- Applied to all swaps

## AMM Algorithm

The DEX uses a constant product formula (x * y = k):
- Trading pairs maintain reserves of both tokens
- Price is determined by the ratio of reserves
- Larger trades have higher price impact
- Fees are deducted from the input amount before calculation

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for deployment instructions.
