**RWA Technical Whitepaper**  
*Issued by Future Flux*  
*Version 1.0*

---

# Table of Contents
- [Executive Summary](#executive-summary)
- [1. Business Logic Overview](#1-business-logic-overview)
- [2. Technical Architecture](#2-technical-architecture)
- [3. ERC-3643 Token Standard](#3-erc-3643-token-standard)
- [4. Regulated DEX Architecture](#4-regulated-dex-architecture)
- [5. Smart Contract Interfaces](#5-smart-contract-interfaces)
- [6. Governance, Risk Control, and Compliance](#6-governance-risk-control-and-compliance)
- [7. Conclusion](#7-conclusion)

---

## Executive Summary

The Future Flux RWA (Real World Asset) initiative aims to bridge regulated off-chain assets—such as bonds, real estate, fund shares, and receivables—with blockchain infrastructure in a fully compliant, secure, and transparent manner. The system introduces an end-to-end architecture enabling regulated asset tokenization, investor onboarding through KYC/AML verification, and controlled trading within permissioned decentralized exchanges.

Through the integration of ERC-3643, a compliance-focused token standard, the platform ensures that only qualified investors can hold or transfer tokens while preserving composability and interoperability within the broader DeFi ecosystem. Future Flux builds a modular infrastructure that interlinks legal, technical, and financial components to enable a sustainable, auditable, and scalable RWA ecosystem.

---

## 1. Business Logic Overview

### Objective
To tokenize regulated real-world assets (bonds, real estate, fund units, receivables, etc.) on-chain through compliant legal structures, enabling secure issuance, redemption, and secondary trading under regulatory oversight.

### End-to-End Workflow

**1. Asset Side (Off-chain)**  
- Asset selection and due diligence  
- Valuation and rating  
- Legal structuring through SPV, trust, or custody arrangements  
- Generation of legal documents and ownership proofs (Pledge Agreement, Subscription Agreement, Custody/Trust Agreement)

**2. Compliance Layer**  
- Investor KYC/AML verification  
- Accredited investor certification by jurisdiction, qualification, and quota  
- Results written to on-chain *Identity Registry*

**3. Primary Market**  
- Token issuance under ERC-3643 representing beneficiary rights or units  
- Subscription, redemption, and dividend/interest distribution automated through smart contracts connected to custodial accounts  
- Off-chain fund settlement synchronized with on-chain events

**4. Secondary Market**  
- Trading occurs within regulated DEX environments (Permissioned AMM/OTC)  
- Optionally, wrapped versions (wRWA) may be issued for exposure on public DEXs, subject to redemption via KYC channels

**Key Constraints:**  
- Only KYC-approved whitelisted addresses may hold or transfer tokens  
- Geographic and quota restrictions apply  
- Triggered regulatory events can freeze, forcibly transfer, or prioritize redemption

---

## 2. Technical Architecture

### System Overview

**Off-Chain Components:**
- **Asset Management:** Legal entities (SPV, Custodian, or Trust)
- **KYC/AML Services:** Providers such as Sumsub, Trulioo, or proprietary systems
- **Financial Flow:** Bank custodians and payment gateways
- **Audit & Risk Control:** External audit and reporting systems

**On-Chain Components (EVM-compatible):**
- **ERC-3643 Token Contract**
- **Identity Registry** for verified investor status
- **Compliance Module** enforcing transfer rules
- **Controller** for authority-based actions (freeze/forced transfer)
- **Primary Market Contracts** for subscription/redemption
- **Permissioned DEX/Router** managing compliant secondary liquidity
- **Oracle / Proof-of-Reserve Module** for NAV, asset valuation, and custody proof

### Suggested Technology Stack
- **Blockchain Layer:** Ethereum mainnet or compliant Layer 2 (Base, Arbitrum, zkEVM). Issue on mainnet; trade on L2 for cost efficiency.
- **Wallets:** EOA + MPC (institutional custody) / Account Abstraction (user experience)
- **Data & Analytics:** Event bus + Data Warehouse (BigQuery/ClickHouse) + real-time reporting
- **Privacy:** Personally Identifiable Information (PII) remains off-chain; only hashed labels and expiry data stored on-chain

---

## 3. ERC-3643 Token Standard

### A. Standard Overview

ERC-3643 is a compliance-oriented token standard designed for regulated assets such as securities, fund shares, bonds, and other RWAs. It extends ERC-20 composability while embedding KYC/AML enforcement and regulatory disposability within token transfer logic.

Originally developed by Tokeny as T-REX, ERC-3643 formalizes the concept of controlled transferability: defining who can hold or transfer tokens, under what restrictions, and within which jurisdictions.

### B. Key Actors
- **Issuer:** Deploys and manages tokens, defines compliance policies, executes corporate actions (dividends, redemptions)
- **Compliance Administrator:** Maintains compliance rules, updates whitelists/labels, handles freezes and forced transfers
- **KYC Provider:** Performs off-chain verification, writes status to on-chain Identity Registry
- **Investor:** Whitelisted address permitted to hold and transfer tokens
- **Custodian/Trustee:** Manages legal ownership and custody of underlying off-chain assets

### C. Core Components
1. **Identity Registry:** Maintains on-chain status (labels, expiry, blacklist). PII remains off-chain.
2. **Compliance Module:** Enforces restrictions pre-transfer (jurisdiction, qualification, quota, concentration, etc.). Configurable via JSON/DSL encoded policies.
3. **Controllability:** Provides freeze, forced transfer, and revoke interfaces to meet legal and regulatory needs.
4. **ERC-20 Compatibility Layer:** Retains ERC-20 interface for wallets and DeFi integration, but enforces compliance pre-transfer.

### D. Token Lifecycle
1. Investor completes KYC; Identity Registry updated.  
2. Funds confirmed in custodial account; Primary Contract mints or allocates tokens.  
3. Secondary transfers validated by Compliance Module.  
4. Corporate actions (dividends, redemptions, buybacks) executed through issuer contracts.  
5. Legal events trigger freezes or forced transfers.  
6. KYC expiry automatically invalidates holdings until renewal.

### E. Comparison
| Dimension | ERC-20 | Whitelist Token | ERC-3643 |
|------------|---------|----------------|-----------|
| Transfer Control | None | Static whitelist | Identity-based + rule engine |
| KYC/Expiry | None | Basic | Multi-label with expiry |
| Legal Intervention | Not supported | Optional | Native freeze/force/revoke |
| Compliance Model | None | Static | Configurable (region, limit, lockup) |
| Composability | High | Medium | High (ERC-20 compatible with pre-transfer checks) |

### F. Integration with Identity & Credential Standards
- Compatible with Verifiable Credentials (VC) and DID for off-chain credential anchoring
- Optional integration with Soulbound Tokens (SBT) as investor accreditation proof
- Proof-of-Reserve and audit hashes linked to enhance transparency

### G. Design Principles
- Minimize on-chain sensitive data (store only hashed tags and expiry)
- Versioned and auditable compliance policies (hash and version tracking)
- Router-level enforcement to prevent bypassing Compliance Module
- Cross-chain bridging requires synchronized registries or revalidation mechanisms

---

## 4. Regulated DEX Architecture

### 4.1 Why a Regulated DEX
Public DEXs (e.g., Uniswap) cannot prevent non-KYC wallets from trading, violating compliance rules enforced by ERC-3643. A regulated DEX ensures only qualified investors can provide liquidity or trade, with full traceability of compliance states.

### 4.2 Design Goals
- **Whitelist Gateway:** All swaps and liquidity operations routed through *ComplianceRouter*
- **Auditability:** All matched trades and liquidity events fully traceable
- **Composability:** Supports Uniswap V3/V4, Balancer, Curve-style AMMs through a unified compliance layer
- **Configurability:** Different pools can define rules such as geography, trade limits, hours, and spreads

### 4.3 Data Flow (Sequence Diagram)
```
User (EOA/AA)
  → ComplianceRouter.swapExactTokensForTokens(...)
  → IdentityRegistry.check(address)
  → ComplianceModule.beforeTransfer()
  ← OK/REVERT
  → AMM.safeSwap()
  ← Output Tokens
  → ComplianceModule.beforeTransfer(to)
  ← OK/REVERT
  ← Tokens received
```
**Key Enforcement Points:**  
- Direct AMM calls prohibited; all access passes through the router  
- LP actions (add/remove liquidity) also require whitelist verification  
- Optional pool-level hooks for double compliance validation

### 4.4 Rule Engine Example (JSON Policy)
```json
{
  "allowLabelsAnyOf": ["ACCREDITED_US", "EU_PROFESSIONAL"],
  "denyCountries": ["KP", "IR"],
  "maxPerTxUSD": 500000,
  "maxHoldingPct": 0.2,
  "poolOpenHoursUTC": "09:00-17:00",
  "cooldownSeconds": 300
}
```
Stored off-chain with on-chain hash verification for tamper-proof version control.

### 4.5 Wrapped Token Mechanism (Optional)
A custodial entity may issue a *wrapped RWA (wRWA)* representing ERC-3643 tokens.  
- wRWA tradable on public DEXs for exposure and liquidity  
- Redemption back to ERC-3643 requires full KYC verification  
- Requires PoR (Proof-of-Reserve) and withdrawal SLA to mitigate custodial risk

---

## 5. Smart Contract Interfaces

### 5.1 Identity Registry
```solidity
interface IIdentityRegistry {
    struct Status { bytes32[] labels; uint64 kycExpiry; bool blacklisted; }
    function statusOf(address user) external view returns (Status memory);
    function isAllowed(address user, bytes32 requiredLabel) external view returns (bool);
    event StatusUpdated(address indexed user, bytes32[] labels, uint64 kycExpiry, bool blacklisted);
}
```

### 5.2 Compliance Module
```solidity
interface ICompliance {
    function beforeTransfer(address from, address to, uint256 amount, bytes calldata policy)
        external view returns (bool ok, bytes32 reason);
}
```

### 5.3 ERC-3643 Token
```solidity
interface IControllable {
    function freeze(address user) external;  // multi-signature or court order
    function forcedTransfer(address from, address to, uint256 amount, bytes32 reason) external;
    event Frozen(address indexed user);
    event ForcedTransfer(address indexed from, address indexed to, uint256 amount, bytes32 reason);
}
```

### 5.4 Primary Market
```solidity
interface IPrimary {
    function subscribe(uint256 amount, bytes calldata offchainReceipt) external;
    function redeem(uint256 shares, bytes calldata bankAccountRef) external;
    event Subscribed(address indexed user, uint256 amount, bytes offchain);
    event Redeemed(address indexed user, uint256 shares, bytes bankRef);
}
```
Subscription links to off-chain deposit proofs; redemption triggers off-chain payment instructions.

### 5.5 Compliance Router
```solidity
interface IComplianceRouter {
    function swapExactTokensForTokens(
        address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin,
        address to, bytes calldata poolPolicy
    ) external returns (uint256 amountOut);

    function addLiquidity(
        address tokenA, address tokenB, uint256 amtA, uint256 amtB,
        address to, bytes calldata poolPolicy
    ) external returns (uint256 lpTokens);
}
```
---

## 6. Governance, Risk Control, and Compliance

### 6.1 Legal and Governance
- Multi-signature (2/3 or 3/5) approval for freeze or forced transfer actions  
- Conflict resolution and audit trail through on-chain events and off-chain case IDs  
- Investor disclosure page including NAV, pool balances, and redemption progress

### 6.2 Proof of Reserve (PoR) & Valuation
- Custodians sign periodic PoR attestations; audit hashes stored on-chain (IPFS/Arweave)  
- Oracles feed NAV/T+1 valuations or AMM TWAP  
- Router enters limited/redeem-only mode during oracle anomalies

### 6.3 Security
- Dual audits and formal verification of key functions (freeze, forcedTransfer, mint/burn)  
- Segregation of roles among compliance admin, treasury operator, and trading manager  
- Real-time monitoring: anomalous trading density, blacklist hits, limit breaches, KYC expiry alerts

### 6.4 Privacy & Data Protection
- No PII stored on-chain; only anonymized compliance fingerprints  
- GDPR/PDPA alignment: right-to-be-forgotten handled off-chain; on-chain labels expire or anonymize  

---

## 7. Conclusion

Future Flux presents a fully compliant, end-to-end framework for tokenizing regulated real-world assets on blockchain infrastructure. By combining ERC-3643 tokenization standards, modular compliance architecture, and permissioned liquidity environments, the system enables institutional-grade participation in decentralized finance while maintaining regulatory alignment.

This architecture creates a foundation for scalable asset interoperability, improved investor trust, and verifiable transparency—paving the way for the next evolution of regulated DeFi.

