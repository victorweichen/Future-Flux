# FutureFlux - Settlement-First RWA DEX

## Overview

FutureFlux is a decentralized exchange (DEX) for Real-World Asset (RWA) tokens, built on a **settlement-first design philosophy**. The protocol is implemented as a fork of **Uniswap v4** with additional settlement-critical smart contracts that guarantee predictable behavior in both success and failure scenarios.

### Key Principle

> **Trustless conditional settlement of value**

Unlike traditional RWA protocols, FutureFlux doesn't pretend to make RWAs "fully on-chain." Instead, it deliberately minimizes trust and **compresses discretion out of settlement** by separating three fundamentally different concerns:

- **Pricing**: Handled by Uniswap v4 AMM
- **Risk Resolution**: Enforced by deterministic settlement primitives
- **Compliance**: Implemented as a modular, replaceable boundary layer

---

## Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for complete technical details.

### Core Components

1. **Uniswap v4 Fork** - Price discovery and liquidity provision
2. **RWA Settlement Contracts** - Deterministic failure handling and settlement
3. **Compliance Layer** - Modular KYC/transfer restrictions

### Smart Contract Structure

```
contracts/
├── rwa/                      # RWA-specific settlement contracts
│   ├── escrow/              # Non-custodial asset holding
│   ├── settlement/          # State machine & waterfall logic
│   ├── tokens/              # RWA & restructured tokens
│   ├── oracles/             # Oracle health monitoring
│   ├── liquidation/         # Auction mechanisms
│   └── guards/              # Trading restrictions
├── compliance/              # Modular compliance layer
├── interfaces/              # Contract interfaces
└── core/                    # Uniswap v4 fork modifications
```

---

## Design Philosophy

### 1. RWA Is Not a Primitive

RWA tokens are **conditional claims**, not assets. The protocol focuses on on-chain settlement logic, treating legal enforcement strictly as a post-failure fallback.

### 2. Deterministic Failure Is a Feature

The system explicitly defines:
- Failure modes (oracle failure, issuer default, market crash)
- State transitions (NORMAL → WARNING → PROTECT → DEFAULT → RECOVERY)
- Asset redistribution logic (waterfall with immutable ordering)

### 3. No Governance Override

Governance CANNOT:
- Override settlement outcomes
- Reorder waterfall logic
- Cancel auctions
- Extract escrowed value

Governance CAN:
- Adjust risk parameters (with timelocks)
- Upgrade non-critical components
- Pause/unpause trading

---

## Settlement State Machine

```
NORMAL
  │
  ├─ Oracle anomaly OR protocol breach
  ↓
WARNING
  │
  ├─ Throttling active, monitoring escalated
  │
  ├─ Resolved → NORMAL
  │  OR anomaly persists
  ↓
PROTECT
  │
  ├─ Trading halted, AMM bypassed, auction scheduled
  │
  ├─ Crisis resolved → WARNING
  │  OR default confirmed
  ↓
DEFAULT
  │
  ├─ Collateral liquidation, waterfall execution
  ↓
RECOVERY
  │
  └─ Restructured token issuance, off-chain recovery
```

---

## Waterfall Distribution (Immutable Loss Ordering)

When assets are insufficient to cover claims:

1. **Protocol Reserves** - First line of defense
2. **Issuer Collateral/Margin** - Issuer's skin in the game
3. **Insurance Fund** - Protocol-level insurance
4. **Liquidity Buffers** - Additional reserves
5. **Token Holder Haircut** - Proportional loss distribution

> **No first-come-first-served. No governance discretion.**

---

## Key Innovations

### 1. Oracle Health Module
- Monitors oracle freshness, deviation, and anomalies
- **Does not trigger liquidation on oracle failure**
- Transitions to PROTECT mode instead

### 2. Auction-Based Liquidation
- Prevents AMM death spirals
- Real price discovery through competitive bidding
- Public, immutable clearing prices

### 3. Reverse Auction
- Designated buyers commit capital in advance
- Predefined execution windows
- Liquidity withdrawal temporarily restricted

### 4. Flashsale
- Multiparty settlement coordination
- Threshold-gated execution
- Proportional token distribution

### 5. Restructured Tokens
- Issued for uncovered claims post-default
- Represent off-chain recovery rights
- Tradeable on secondary markets

---

## Technology Stack

- **Smart Contracts**: Solidity 0.8.26+
- **Development**: Foundry (primary), Hardhat (deployment)
- **Testing**: Foundry fuzz testing + Hardhat integration tests
- **Oracles**: Chainlink, Pyth, custom adapters
- **Base Layer**: Uniswap v4 (git submodule)

---

## Project Status

⚠️ **Early Development** - Contracts are templates and not production-ready

### Development Phases

- [x] Architecture planning
- [x] Core contract templates
- [ ] Uniswap v4 integration
- [ ] Comprehensive testing
- [ ] Security audit
- [ ] Testnet deployment
- [ ] Mainnet deployment

---

## Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) - Complete technical architecture
- [docs/](./docs/) - Whitepapers and design documents
  - [RWA DEX Whitepaper](./docs/RWA%20DEX%20Whitepaper)
  - [FutureFlux WhitePaper](./docs/FutureFlux-WhitePaper.md)
  - [Dynamic Hedging System](./docs/FutureFlux-Dynamic-RWA-Hedging-System.md)

---

## Getting Started

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install
```

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Deploy

```bash
# Deploy to local testnet
forge script scripts/deploy/01_deploy_core.ts --rpc-url localhost --broadcast
```

---

## Security

### Security Model

1. **Immutable Core Settlement** - No upgrades to waterfall or state machine logic
2. **Timelocked Governance** - All parameter changes require minimum 7-day delay
3. **Oracle Redundancy** - Multi-oracle aggregation with health monitoring
4. **Audit Trail** - All state transitions logged on-chain

### Audit Status

🔴 **Not Audited** - Do not use in production

---

## Contributing

This is an early-stage project. Contributions welcome via:

1. GitHub Issues for bug reports
2. Pull Requests for improvements
3. Discussions for architecture feedback

---

## License

MIT License - See [LICENSE](./LICENSE) file

---

## Contact

- **Documentation**: [docs/](./docs/)
- **Architecture**: [ARCHITECTURE.md](./ARCHITECTURE.md)
- **Issues**: GitHub Issues

---

## Disclaimer

⚠️ **EXPERIMENTAL SOFTWARE**

This protocol is experimental and unaudited. Do not use with real funds. RWA tokens represent off-chain claims that may not be legally enforceable in all jurisdictions. No guarantees are made regarding solvency, recovery, or value preservation.

> "We do not claim to eliminate default risk.  
> We make it **deterministic**."

---

**Built with a focus on predictable outcomes when markets break.**

Future-Flux is an open RWA (Real-World Asset) protocol framework focused on programmable issuance, settlement, and governance of tokenized economic rights.

It provides a modular on-chain control plane (Vaults + Tokens + Adapters) designed for composable DeFi integration while supporting off-chain legal and cashflow structures.

---

## Who Is FutureFlux For?

FutureFlux is designed for:

- Protocol engineers building RWA or structured DeFi products  
- Teams experimenting with tokenized revenue, yield, or asset-backed instruments  
- Researchers exploring hybrid on-chain / off-chain financial architectures  
- Builders interested in programmable settlement and governance primitives  

If you’re working on RWA tokenization, structured products, or composable DeFi infrastructure, this project is for you.

---

## Architecture

At a high level, FutureFlux separates representation from control:

- **Tokens** — Thin representation of economic rights (ERC20-compatible)  
- **Vaults** — Deterministic control plane for issuance, redemption, accounting, governance, and settlement  
- **Adapters / Modules** — Pluggable components for oracles, strategies, compliance, and future extensions  

Conceptually:

- Real-world assets & cashflows live off-chain  
- Vault contracts manage lifecycle and economic logic on-chain  
- Tokens remain lightweight and composable across AMMs and DeFi protocols  

This separation enables upgradeable policy, multi-asset coordination, and programmable settlement without reissuing tokens.

---

## Use Cases & Examples

Typical applications include:

- Tokenized revenue participation  
- RWA-backed yield instruments  
- Basket or tranche-based products  
- Structured issuance + redemption flows  
- Future integration with auctions, hedging modules, and DEX settlement  

The framework is intentionally generic to support multiple asset types and strategies.

---

## Quick Start

Want to explore quickly?

1. Clone the repo  
2. Review the architecture docs  
3. Check discussions for current design threads  

Detailed setup instructions will be added as contracts stabilize.

---

## Installation

Coming soon.

(Initial smart contracts and deployment scripts are under active development.)

---

## Basic Usage

Coming soon.

Example flows will cover:

- Vault deployment  
- Token issuance  
- Redemption lifecycle  
- Governance hooks  

---

## Documentation

Documentation is evolving alongside the protocol design.

For now:

- Review Discussions for architectural context  
- Check the Whitepaper folder for conceptual models  
- Follow commits for implementation progress  

---

## Main Website

Coming soon.

---

## Docs & API Reference

Coming soon.

---

## Community & Support

Join the discussion:  
👉 https://github.com/victorweichen/Future-Flux/discussions

Discord (real-time chat, updates, design discussion):  
👉 *link coming soon*

---

## Contributing

We welcome contributions!

Please open issues or discussions for major ideas before submitting PRs.  
Coding standards and contribution guidelines will be added shortly.

---

## License

MIT
