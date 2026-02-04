# FutureFlux Developer Guide

## Quick Start

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Hardhat dependencies
npm install

# Copy environment template
cp .env.example .env.local
# Fill in your environment variables
```

### Build

```bash
# Build all contracts
forge build

# Build with specific Solidity version
forge build --use solc:0.8.26
```

### Testing

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/unit/EscrowVault.t.sol

# Run with verbosity
forge test -vv

# Run fuzz tests with high iteration count
forge test --fuzz-runs 10000

# Run specific test
forge test --match-test test_Deposit -vvv

# Generate coverage report
forge coverage

# Generate coverage with LCOV format
forge coverage --report lcov
```

### Deployment

#### Local Deployment

```bash
# Start local Ethereum node
anvil

# In another terminal, deploy
forge script scripts/deploy/01_deploy_core.s.sol --rpc-url localhost:8545 --broadcast

# Verify deployment
cast call <contract_address> "name()" --rpc-url localhost:8545
```

#### Testnet Deployment

```bash
# Deploy to Sepolia
PRIVATE_KEY=<your_key> GOVERNANCE_ADDRESS=<address> \
forge script scripts/deploy/01_deploy_core.s.sol \
  --rpc-url https://sepolia.infura.io/v3/YOUR_KEY \
  --broadcast \
  --verify

# Verify on Etherscan
forge verify-contract <contract_address> \
  --compiler-version v0.8.26 \
  contracts/rwa/escrow/EscrowVault.sol:EscrowVault \
  --etherscan-api-key YOUR_KEY
```

---

## Contract Architecture

### Core Settlement Flow

```
User Request
    ↓
RouterGuard.checkSwap() ← Validates state & oracle health
    ↓
SettlementStateMachine ← Verifies current state
    ↓
ConditionalSettlementEngine ← Executes settlement logic
    ↓
WaterfallDistributor ← Distributes losses
    ↓
EscrowVault ← Manages backing assets
    ↓
RWAToken ← Updates token balances
```

### State Transitions

```solidity
NORMAL (0) ← normal market conditions
  ↓
WARNING (1) ← risk detected, trading throttled
  ↓
PROTECT (2) ← trading halted, AMM bypassed
  ↓
DEFAULT (3) ← issuer default confirmed
  ↓
RECOVERY (4) ← restructuring phase
  ↓
HALT (5) ← emergency only (terminal)
```

---

## Key Testing Patterns

### 1. Basic Unit Test

```solidity
function test_BasicOperation() public {
    vm.prank(user);
    contract.method();
    
    assertEq(contract.state(), expectedValue);
}
```

### 2. State Machine Testing

```solidity
function test_StateTransition() public {
    vm.prank(settlementEngine);
    stateMachine.transitionTo(State.WARNING, "reason");
    
    assertEq(stateMachine.getCurrentState(), 1);
}
```

### 3. Waterfall Testing

```solidity
function test_LossDistribution() public {
    vm.prank(settlementEngine);
    waterfall.setTotalClaims(100e18);
    waterfall.executeWaterfall(10e18);
    
    uint256 recovery = waterfall.calculateRecovery(100e18);
    assertEq(recovery, 90e18);
}
```

### 4. Failure Scenario Testing

```solidity
function test_OracleFailureScenario() public {
    // Trigger oracle failure
    vm.prank(settlementEngine);
    stateMachine.transitionTo(State.WARNING, "Oracle failure");
    
    // Verify protective measures activated
    assertFalse(stateMachine.isTradingAllowed());
}
```

---

## Writing Tests

### Test File Structure

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../contracts/path/to/Contract.sol";

contract ContractTest is Test {
    Contract public contract;
    address public admin = address(0x1);
    address public user = address(0x2);
    
    function setUp() public {
        contract = new Contract(admin);
    }
    
    function test_Name() public {
        // Arrange, Act, Assert
    }
}
```

### Common Assertions

```solidity
// Equality
assertEq(actual, expected);
assertEq(string, string); // for strings

// Comparisons
assertTrue(condition);
assertFalse(condition);
assertGt(actual, expected);
assertLt(actual, expected);
assertGe(actual, expected);
assertLe(actual, expected);

// Approximate equality (with tolerance)
assertApproxEqAbs(actual, expected, tolerance);
assertApproxEqRel(actual, expected, percentage);

// Reverts
vm.expectRevert(bytes("error message"));
contract.method();

// Custom errors
vm.expectRevert(CustomError.selector);
contract.method();
```

### Common Test Patterns

```solidity
// Prank (set msg.sender)
vm.prank(user);
contract.method();

// Roll blocks
vm.roll(blockNumber);

// Warp time
vm.warp(timestamp);

// Deal (give ether/tokens)
vm.deal(user, 100 ether);

// Etch (set contract code)
vm.etch(address, code);

// Snapshot/Revert
uint256 snapshot = vm.snapshot();
// ... make changes ...
vm.revertToSnapshot(snapshot);
```

---

## Debugging

### Verbose Output

```bash
# Increase verbosity (-v to -vvvv)
forge test -vvv

# Show logs
forge test -vvv --logs
```

### Debug Transactions

```solidity
function test_Debug() public {
    emit log_uint(value);
    emit log_address(address);
    emit log_string("message");
}
```

### Using cast for RPC Calls

```bash
# Call function
cast call <address> "function()" --rpc-url <rpc>

# Get storage
cast storage <address> 0 --rpc-url <rpc>

# Decode calldata
cast 4byte-decode <calldata>
```

---

## Gas Optimization Tips

1. **Batch operations** where possible
2. **Use view functions** for queries
3. **Minimize storage reads/writes**
4. **Precompute values** when safe

Check gas usage:

```bash
forge test --gas-report
```

---

## Common Issues

### Issue: Contract not found

```bash
forge build
# Ensure import paths are correct
```

### Issue: Test fails with "assertion failed"

```bash
# Run with verbosity to see what failed
forge test -vvv --match-test test_name
```

### Issue: Compilation error

```bash
# Check Solidity version compatibility
forge --version
# Update if needed: foundryup
```

---

## Project Structure Reference

```
contracts/
├── rwa/              # RWA settlement contracts
├── compliance/       # Compliance layer
├── interfaces/       # Contract interfaces
└── core/             # Uniswap v4 fork

test/
├── unit/             # Individual contract tests
├── integration/      # Multi-contract tests
├── failure-scenarios/# Failure mode tests
└── fuzz/             # Fuzz testing

scripts/
├── deploy/           # Deployment scripts
└── utils/            # Utility scripts
```

---

## Resources

- [Foundry Book](https://book.getfoundry.sh)
- [Solidity Docs](https://docs.soliditylang.org)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- [Uniswap v4 Docs](https://docs.uniswap.org/contracts/v4)

---

## Next Steps

1. Install dependencies: `npm install && forge install`
2. Set up environment: `cp .env.example .env.local`
3. Build contracts: `forge build`
4. Run tests: `forge test`
5. Deploy locally: `anvil` + `forge script ... --broadcast`

