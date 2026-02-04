# FutureFlux RWA DEX - Code Architecture

## Overview

FutureFlux is a settlement-first DEX for Real-World Asset (RWA) tokens, implemented as a fork of **Uniswap v4** with additional settlement-critical smart contracts. The architecture separates:

- **Pricing & Liquidity**: Standard Uniswap v4 AMM
- **Risk & Settlement**: Deterministic settlement primitives
- **Compliance**: Modular boundary layer

---

## Project Structure

```
FutureFlux/
├── README.md
├── docs/                          # All whitepapers and documentation
│   ├── RWA DEX Whitepaper
│   ├── FutureFlux-WhitePaper.md
│   ├── FutureFlux-Dynamic-RWA-Hedging-System.md
│   └── ...
├── ARCHITECTURE.md                # This file
├── package.json
├── hardhat.config.ts
├── foundry.toml
│
├── lib/                           # Git submodules (Uniswap v4, OpenZeppelin, etc.)
│   └── v4-core/                   # Uniswap v4 core (git submodule)
│
├── contracts/                     # All smart contracts
│   ├── core/                      # Uniswap v4 fork modifications
│   │   ├── PoolManager.sol        # Modified for RWA guard integration
│   │   └── ...
│   │
│   ├── rwa/                       # RWA Settlement Contracts (NEW)
│   │   ├── escrow/
│   │   │   ├── EscrowVault.sol
│   │   │   └── EscrowVaultFactory.sol
│   │   │
│   │   ├── settlement/
│   │   │   ├── ConditionalSettlementEngine.sol
│   │   │   ├── SettlementStateMachine.sol
│   │   │   └── WaterfallDistributor.sol
│   │   │
│   │   ├── tokens/
│   │   │   ├── RWAToken.sol               # Base RWA token with conditional logic
│   │   │   ├── MintBurnController.sol     # Controls token supply based on escrow
│   │   │   └── RestructuredToken.sol      # Post-default recovery tokens
│   │   │
│   │   ├── oracles/
│   │   │   ├── OracleHealthModule.sol     # Monitors oracle health
│   │   │   ├── MultiOracleAggregator.sol  # Cross-oracle validation
│   │   │   └── IOracleAdapter.sol         # Interface for oracle adapters
│   │   │
│   │   ├── liquidation/
│   │   │   ├── AuctionLiquidator.sol      # On-chain auction for distressed assets
│   │   │   ├── ReverseAuction.sol         # Designated buyer settlement window
│   │   │   └── Flashsale.sol              # Multiparty settlement mechanism
│   │   │
│   │   ├── guards/
│   │   │   ├── RouterGuard.sol            # State-based trading restrictions
│   │   │   └── PositionThrottler.sol      # Position size limits under stress
│   │   │
│   │   └── governance/
│   │       ├── MinimalGovernance.sol      # Parameter updates with timelocks
│   │       └── UpgradeSafety.sol          # Controlled upgrade mechanism
│   │
│   ├── compliance/                # Compliance Layer (Modular)
│   │   ├── TransferRestriction.sol
│   │   ├── KYCRegistry.sol
│   │   ├── JurisdictionFilter.sol
│   │   └── IComplianceModule.sol
│   │
│   ├── interfaces/                # Contract interfaces
│   │   ├── IRWA.sol
│   │   ├── IEscrowVault.sol
│   │   ├── ISettlementEngine.sol
│   │   └── ...
│   │
│   └── libraries/                 # Shared libraries
│       ├── SettlementMath.sol
│       ├── WaterfallLogic.sol
│       └── StateTransitions.sol
│
├── test/                          # Test suite
│   ├── unit/                      # Unit tests for individual contracts
│   ├── integration/               # Cross-contract integration tests
│   ├── failure-scenarios/         # Failure mode testing
│   │   ├── OracleFailure.test.ts
│   │   ├── IssuerDefault.test.ts
│   │   └── MarketCrash.test.ts
│   └── fuzz/                      # Fuzz testing with Foundry
│
├── scripts/                       # Deployment and utility scripts
│   ├── deploy/
│   │   ├── 01_deploy_core.ts
│   │   ├── 02_deploy_rwa_contracts.ts
│   │   └── 03_configure_system.ts
│   └── utils/
│
└── docs-dev/                      # Developer documentation
    ├── SETTLEMENT_FLOW.md
    ├── STATE_MACHINE.md
    ├── FAILURE_MODES.md
    └── INTEGRATION_GUIDE.md
```

---

## Core Components

### 1. Uniswap v4 Fork (Base Layer)

**Purpose**: Price discovery and liquidity provision

**Key Modifications**:
- Integration points for RouterGuard checks
- RWA token handling in swap logic
- State-aware liquidity management

**Contracts** (modified from v4-core):
- `PoolManager.sol` - Central pool management with RWA guards
- `PoolSwapTest.sol` - Modified for state checks
- Hooks integration for settlement state monitoring

### 2. RWA Settlement Contracts (Core Innovation)

#### 2.1 Escrow System

**EscrowVault.sol**
```solidity
// Purpose: Non-custodial holding of backing assets
// Key Features:
// - Multi-asset support (USDC, USDT, wBTC, etc.)
// - Conditional release logic
// - Immutable withdrawal rules
// - State machine integration
```

**EscrowVaultFactory.sol**
```solidity
// Purpose: Standardized vault deployment per RWA issuer
```

#### 2.2 Settlement Engine

**ConditionalSettlementEngine.sol**
```solidity
// Purpose: Define and execute settlement conditions
// Inputs:
// - Time-based triggers
// - Oracle-verified states
// - Protocol health metrics
// - Governance parameters (timelocked)
//
// Outputs:
// - RELEASE: Normal settlement
// - CONVERT: Token conversion
// - LIQUIDATE: Trigger auction
// - REALLOCATE: Waterfall execution
```

**SettlementStateMachine.sol**
```solidity
// States: NORMAL → WARNING → PROTECT → DEFAULT → RECOVERY → HALT
// All transitions are rule-based and observable
```

**WaterfallDistributor.sol**
```solidity
// Enforces loss ordering:
// 1. Protocol reserves
// 2. Issuer collateral
// 3. Insurance funds
// 4. Liquidity buffers
// 5. Token holder haircut
```

#### 2.3 Token System

**RWAToken.sol**
```solidity
// ERC-20 with:
// - Transfer restrictions based on compliance layer
// - Supply linked to escrow state
// - Settlement state awareness
```

**MintBurnController.sol**
```solidity
// Enforces: Supply = Enforceable Claims
// Minting only when escrow conditions satisfied
// Burning as part of settlement
```

**RestructuredToken.sol**
```solidity
// Issued post-default for uncovered claims
// Represents:
// - Off-chain recovery rights
// - Recapitalization participation
// - Tradeable on secondary market
```

#### 2.4 Oracle Health System

**OracleHealthModule.sol**
```solidity
// Monitors:
// - Update freshness (heartbeat)
// - Cross-oracle divergence
// - Volatility anomalies
// - Circuit breaker triggers
//
// On failure: Transitions to PROTECT, NOT liquidation
```

**MultiOracleAggregator.sol**
```solidity
// Aggregates multiple oracle sources
// Detects manipulation attempts
// Provides confidence scores
```

#### 2.5 Liquidation Mechanisms

**AuctionLiquidator.sol**
```solidity
// Periodic on-chain auctions
// Competitive bidding
// Public, immutable clearing prices
// Prevents AMM death spirals
```

**ReverseAuction.sol**
```solidity
// Designated buyer commits capital
// Predefined execution window
// Liquidity withdrawal temporarily restricted
// Transparent, scheduled large purchases
```

**Flashsale.sol**
```solidity
// Multiparty settlement coordination
// Threshold-gated execution
// Proportional token distribution
// Deterministic outcomes
```

#### 2.6 Guard System

**RouterGuard.sol**
```solidity
// Pre-swap checks:
// - Settlement state validation
// - Oracle health verification
// - Position size limits
// - Stress-mode restrictions
```

**PositionThrottler.sol**
```solidity
// Under WARNING/PROTECT states:
// - Limit position sizes
// - Throttle trading cadence
// - Prevent new position opening
```

#### 2.7 Governance

**MinimalGovernance.sol**
```solidity
// CAN adjust:
// - Risk parameters
// - Oracle thresholds
// - Timelock delays
//
// CANNOT:
// - Override settlement outcomes
// - Reorder waterfall
// - Cancel auctions
// - Extract escrowed value
```

**UpgradeSafety.sol**
```solidity
// All upgrades:
// - Timelocked (minimum 7 days)
// - Exit window provided
// - Escrow integrity preserved
// - Immutable core settlement logic
```

### 3. Compliance Layer (Modular)

**TransferRestriction.sol**
- Operates at transfer boundary
- Does not alter settlement logic
- Upgradeable independently

**KYCRegistry.sol**
- On-chain or off-chain KYC verification
- Whitelist management

**JurisdictionFilter.sol**
- Geographic restrictions
- Regulatory compliance per jurisdiction

---

## State Machine

```
┌─────────────────────────────────────────────────────────────┐
│                      SETTLEMENT STATES                       │
└─────────────────────────────────────────────────────────────┘

NORMAL
  │
  ├─ Condition: Oracle anomaly detected
  │  OR protocol metric breached
  ↓
WARNING
  │
  ├─ Actions: Position throttling, monitoring escalated
  │
  ├─ Condition: Issue resolved → back to NORMAL
  │  OR anomaly persists > T1
  ↓
PROTECT
  │
  ├─ Actions: Trading halted, AMM bypassed, auction scheduled
  │
  ├─ Condition: Crisis resolved → WARNING → NORMAL
  │  OR issuer default confirmed
  ↓
DEFAULT
  │
  ├─ Actions: Collateral liquidation, waterfall execution
  │
  ↓
RECOVERY
  │
  ├─ Actions: Restructured token issuance, off-chain recovery
  │
  └─ Terminal state OR gradual return to NORMAL

HALT (Emergency Only)
  │
  └─ Governance-triggered, requires community vote
```

---

## Integration Points

### Uniswap v4 ↔ RWA Contracts

1. **Pre-swap hooks**: RouterGuard.checkState()
2. **Pool initialization**: RWA token registration
3. **Liquidity events**: State-aware withdrawal restrictions
4. **Price feeds**: Oracle health monitoring

### Settlement ↔ Liquidation

1. State machine triggers auction
2. Auction results feed into WaterfallDistributor
3. Haircut calculations update token controller
4. Restructured tokens minted if necessary

### Oracle ↔ State Machine

1. Oracle health continuously monitored
2. Failures trigger state transitions (NORMAL → WARNING → PROTECT)
3. No automatic liquidations on oracle failure

---

## Failure Mode Behaviors

### Oracle Failure
```
1. Detect anomaly (OracleHealthModule)
2. Transition: NORMAL → WARNING → PROTECT
3. Disable AMM, schedule auction
4. Execute auction with real bids
5. Apply waterfall, execute haircut if needed
```

### Issuer Default
```
1. Covenant breach confirmed
2. Grace period expires
3. State: NORMAL → DEFAULT
4. Seize issuer margin
5. Liquidate collateral via auction
6. Execute waterfall
7. Issue restructured tokens for shortfall
```

### Market Crash
```
1. Detect volatility spike
2. Transition: NORMAL → WARNING
3. Enable stress throttling
4. If continues: WARNING → PROTECT
5. Batch auctions for liquidations
6. Waterfall distribution
7. LP protection mechanisms activate
```

---

## Technology Stack

- **Smart Contracts**: Solidity 0.8.26+
- **Development**: Foundry (primary), Hardhat (deployment)
- **Testing**: Foundry fuzz testing + Hardhat integration tests
- **Oracles**: Chainlink, Pyth, custom adapters
- **Frontend**: (TBD - React/Next.js with ethers.js/viem)
- **Indexing**: The Graph (optional)

---

## Development Phases

### Phase 1: Core Settlement (Current)
- [ ] Fork Uniswap v4
- [ ] Implement EscrowVault
- [ ] Implement SettlementStateMachine
- [ ] Implement WaterfallDistributor
- [ ] Basic RouterGuard

### Phase 2: Liquidation Mechanisms
- [ ] AuctionLiquidator
- [ ] ReverseAuction
- [ ] Flashsale
- [ ] Integration with state machine

### Phase 3: Oracle & Monitoring
- [ ] OracleHealthModule
- [ ] MultiOracleAggregator
- [ ] Oracle adapters (Chainlink, Pyth)

### Phase 4: Token System
- [ ] RWAToken with restrictions
- [ ] MintBurnController
- [ ] RestructuredToken

### Phase 5: Compliance Layer
- [ ] KYCRegistry
- [ ] JurisdictionFilter
- [ ] TransferRestriction

### Phase 6: Governance & Upgrades
- [ ] MinimalGovernance
- [ ] UpgradeSafety
- [ ] Parameter management

### Phase 7: Testing & Audit
- [ ] Comprehensive failure scenario testing
- [ ] Fuzz testing of all critical paths
- [ ] Professional security audit
- [ ] Testnet deployment

---

## Security Considerations

1. **Reentrancy**: All state changes before external calls
2. **Access Control**: Minimal privileges, explicit roles
3. **Upgradeability**: Timelocked, exit windows mandatory
4. **Oracle Manipulation**: Multi-oracle validation, health checks
5. **MEV Protection**: Auction-based settlement, no AMM liquidations
6. **Governance Capture**: Immutable core settlement logic

---

## Design Principles (Enforced)

1. ✅ **Deterministic Settlement**: No discretionary overrides
2. ✅ **Separation of Concerns**: Pricing ≠ Settlement ≠ Compliance
3. ✅ **Failure as a Feature**: Explicitly defined, not exceptional
4. ✅ **Minimal Governance**: Cannot override core settlement
5. ✅ **Auditability**: All state transitions on-chain
6. ✅ **Regulatory Adaptability**: Modular compliance layer

---

## Next Steps

1. Initialize project with Foundry + Hardhat
2. Add Uniswap v4 as git submodule
3. Create all contract files with interfaces
4. Implement core settlement contracts
5. Write comprehensive test suite
6. Deploy to testnet
7. Security audit
8. Mainnet deployment

---

**Architecture Version**: 1.0  
**Last Updated**: February 3, 2026  
**Based On**: RWA DEX Whitepaper + Uniswap v4
