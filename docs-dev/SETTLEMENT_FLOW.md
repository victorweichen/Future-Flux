# Settlement Flow Documentation

## Overview

The settlement system enforces deterministic, trustless settlement of RWA token claims through a series of well-defined stages and state transitions.

---

## Settlement Stages

### Stage 1: Normal Operation

**State**: `NORMAL`

- Standard trading through AMM
- Escrow vault functioning normally
- Oracle prices trusted
- No restrictions on trading volume or frequency

**Transition Triggers**:
- Oracle anomaly detected
- Protocol health metric breached
- Governance alert

---

### Stage 2: Warning Period

**State**: `WARNING`

**Activated When**:
- Oracle deviation detected (cross-source mismatch)
- Price volatility exceeds threshold
- Heartbeat timeout on price feed
- Protocol risk indicator triggered

**Active Restrictions**:
- Position size limits reduced by 90% (e.g., 1M → 100K)
- Trading cadence throttled
- Large purchases require longer delays
- All trades logged for analysis

**Duration**: Configurable (default: 1 hour)

**Resolution Paths**:
- Issue resolved → Return to `NORMAL`
- Issue persists > T₁ → Escalate to `PROTECT`

**Key Invariant**: No user funds are locked in WARNING state

---

### Stage 3: Protective Mode

**State**: `PROTECT`

**Activated When**:
- WARNING duration exceeded
- Oracle fails completely
- Multiple critical metrics breached
- Manual governance escalation

**Active Restrictions**:
- **All trading halted** on affected RWA tokens
- AMM bypassed entirely
- New position opening disabled
- Existing positions frozen (no liquidation)
- Settlement engine switches to auction mode

**On-chain Behaviors**:
1. Auction scheduled for collateral liquidation
2. Liquidity provider locks prevented
3. Oracle feeds deprioritized
4. Bidding window opens for external buyers

**Resolution Paths**:
- Crisis resolved → Return to WARNING
- Default confirmed → Transition to DEFAULT

---

### Stage 4: Default

**State**: `DEFAULT`

**Triggered By**:
- Issuer covenant breach
- Collateral insufficient
- Grace period expired
- Governance emergency declaration

**Settlement Actions**:
1. Issuer margin/collateral seized
2. All escrow vaults locked
3. Collateral liquidated via auction
4. Waterfall distribution begins

**Token Holder Recovery**:
- Waterfall applied in fixed order
- Haircuts calculated once losses confirmed
- Recovery amounts frozen for distribution

---

### Stage 5: Recovery

**State**: `RECOVERY`

**Features**:
- Restructured tokens issued for uncovered claims
- Off-chain recovery processes managed
- Partial return to trading possible
- Governance-controlled exit windows

**Outcomes**:
- Full recovery → Return to NORMAL
- Partial recovery → Establish RECOVERY ratio
- Continued loss → Extended RECOVERY period

---

### Stage 6: Halt (Emergency)

**State**: `HALT`

**When Invoked**:
- Critical system failure
- Governance emergency vote
- Unrecoverable state reached

**Restrictions**: All operations frozen

**Recovery**: Requires governance vote + timelock

---

## Waterfall Distribution Logic

When assets insufficient (triggered in DEFAULT):

```
Loss Amount = Total Claims - Available Assets

1. Protocol Reserves - Take first
2. Issuer Collateral - Take second
3. Insurance Fund - Take third
4. Liquidity Buffers - Take fourth
5. Token Holders - Remaining loss distributed proportionally
```

### Example

**Scenario**: $1,000,000 total claims, $900,000 assets

**Loss**: $100,000

**Available Reserves**:
- Protocol reserves: $50,000
- Issuer collateral: $60,000
- Insurance fund: $40,000

**Distribution**:
1. Protocol loses $50,000 (fully depleted)
2. Issuer loses $50,000 (of their $60,000)
3. Insurance unaffected
4. Token holders unaffected

**Result**: Waterfall absorbed full loss

---

### Haircut Example

**Scenario**: $1,000,000 claims, $700,000 assets

**Loss**: $300,000

**Available Reserves**: $250,000 (protocol + issuer + insurance)

**Remaining Loss**: $50,000 → **Token Holder Haircut**

**Haircut Ratio**: (1,000,000 - 50,000) / 1,000,000 = **95%**

**Token Holder Recovery**: 
- Claim of $1,000 → recovers $950
- Claim of $100,000 → recovers $95,000

---

## Oracle Health Monitoring

### Continuous Checks

1. **Heartbeat**: Price updates at least every T seconds
2. **Deviation**: Cross-oracle prices diverge > threshold
3. **Volatility**: Price moves > circuit breaker level

### State Transitions on Failure

```
Oracle Healthy
    ↓
Heartbeat Timeout Detected
    ↓ (if not resolved in 5 min)
NORMAL → WARNING
    ↓
Cross-Oracle Deviation > 15%
    ↓ (if persists for 10 min)
WARNING → PROTECT
    ↓
Manual Reset OR Normal Recovery
```

### No Auto-Liquidation

**Key Design**: Oracle failures DO NOT trigger immediate liquidation

- Instead: State machine → WARNING → PROTECT
- Auctions scheduled with human review window
- Prices discovered through competitive bidding

---

## Auction-Based Liquidation

### Trigger Conditions

- PROTECT state entered
- DEFAULT declared
- Large collateral liquidation needed

### Auction Flow

```
1. CREATION
   - Asset amount set
   - Bid token specified
   - Min bid set (usually ~10-20% of collateral value)
   - Duration set (1-7 days)

2. BIDDING
   - Participants submit bids
   - Each bid must exceed previous by 1%+
   - Losing bids refunded
   - All on-chain (transparent)

3. FINALIZATION
   - After duration expires
   - Winner receives collateral
   - Proceeds go to settlement vault
   - Waterfall processes results
```

### Price Discovery

- **Transparent**: All bids public
- **Competitive**: Multiple bidders reduce manipulation risk
- **Final**: No post-hoc repricing
- **Immutable**: Results locked on-chain

---

## Compliance Integration

### Non-Blocking Design

Compliance operates at **transfer boundary**, not settlement layer:

```
Settlement Logic (Core)
    ↓
Transfer Execution
    ↓
Compliance Check ← KYC, Geography, Whitelist
    ↓
Accept or Reject Transfer
```

**Key Property**: Compliance failures do not affect settlement determinism

---

## Failure Recovery Timeline

### Oracle Failure Example

```
T=0:00  Oracle heartbeat misses 1 minute
T=0:05  Cross-oracle deviation detected
T=0:10  State: NORMAL → WARNING
T=1:00  Issue unresolved, thresholds exceeded
T=1:05  State: WARNING → PROTECT
        AMM halted, auctions scheduled
T=1:30  First auction opens
T=1:35  External bidders submit bids
T=8:30  Auction closes (7 days later)
T=8:35  Waterfall executes, token balances updated
T=8:40  Governance can restore if issue resolved
```

---

## Gas Considerations

- **State transitions**: ~50k-100k gas
- **Auction creation**: ~150k gas
- **Bid placement**: ~100k gas
- **Waterfall execution**: ~200k+ gas (scales with tranche count)

Batch operations where possible.

---

## Error Handling

### Non-Recoverable States

If any of these occur, system enters HALT:
- Escrow vault contract corrupted
- Waterfall logic inconsistent
- State machine deadlock
- Oracle consensus impossible

---

## References

See main ARCHITECTURE.md for contract-level details and code examples.

