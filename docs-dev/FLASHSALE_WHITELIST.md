# Flashsale Participant Whitelist Feature

## Overview

The Flashsale contract now includes a comprehensive whitelist feature that allows administrators to control who can participate in flashsale campaigns. This feature enables the protocol to comply with regulatory requirements and manage participant access in a flexible manner.

## Key Features

### 1. **Whitelist Management**
- Add/remove individual participants to/from the whitelist
- Batch operations for efficiently managing multiple participants
- View function to check whitelist status

### 2. **Optional Enforcement**
- Whitelist enforcement can be toggled on/off
- When disabled, all addresses can participate (default behavior)
- When enabled, only whitelisted addresses can contribute to campaigns

### 3. **Access Control**
- Admin role-based permissions using OpenZeppelin's AccessControl
- Only addresses with ADMIN_ROLE can manage the whitelist
- Deployer is granted both DEFAULT_ADMIN_ROLE and ADMIN_ROLE by default

## Smart Contract Changes

### Added State Variables

```solidity
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
mapping(address => bool) public whitelist;
bool public whitelistEnabled;
```

### New Functions

#### Administrative Functions

1. **addToWhitelist(address participant)**
   - Adds a single participant to the whitelist
   - Requires ADMIN_ROLE
   - Emits `ParticipantWhitelisted` event

2. **removeFromWhitelist(address participant)**
   - Removes a participant from the whitelist
   - Requires ADMIN_ROLE
   - Emits `ParticipantRemovedFromWhitelist` event

3. **batchAddToWhitelist(address[] calldata participants)**
   - Efficiently adds multiple participants at once
   - Requires ADMIN_ROLE
   - Emits `ParticipantWhitelisted` event for each address

4. **batchRemoveFromWhitelist(address[] calldata participants)**
   - Efficiently removes multiple participants at once
   - Requires ADMIN_ROLE
   - Emits `ParticipantRemovedFromWhitelist` event for each address

5. **toggleWhitelist(bool enabled)**
   - Enables or disables whitelist enforcement
   - Requires ADMIN_ROLE
   - Emits `WhitelistToggled` event

#### View Functions

1. **isWhitelisted(address participant)**
   - Returns whether an address is whitelisted
   - Public view function, no permissions required

### Events

```solidity
event ParticipantWhitelisted(address indexed participant);
event ParticipantRemovedFromWhitelist(address indexed participant);
event WhitelistToggled(bool enabled);
```

## Usage Examples

### Scenario 1: Enable Whitelist and Add Participants

```solidity
// Enable whitelist enforcement
flashsale.toggleWhitelist(true);

// Add individual participants
flashsale.addToWhitelist(0x123...);
flashsale.addToWhitelist(0x456...);

// Or add multiple participants at once
address[] memory participants = new address[](3);
participants[0] = 0x123...;
participants[1] = 0x456...;
participants[2] = 0x789...;
flashsale.batchAddToWhitelist(participants);
```

### Scenario 2: Check Whitelist Status

```solidity
// Check if an address is whitelisted
bool isWhitelisted = flashsale.isWhitelisted(0x123...);

// Check if whitelist is enabled
bool enabled = flashsale.whitelistEnabled();
```

### Scenario 3: Remove Participants

```solidity
// Remove a single participant
flashsale.removeFromWhitelist(0x123...);

// Or remove multiple at once
address[] memory toRemove = new address[](2);
toRemove[0] = 0x123...;
toRemove[1] = 0x456...;
flashsale.batchRemoveFromWhitelist(toRemove);
```

### Scenario 4: Disable Whitelist

```solidity
// Disable whitelist enforcement (returns to open participation)
flashsale.toggleWhitelist(false);
```

## Security Considerations

1. **Access Control**: Only addresses with ADMIN_ROLE can manage the whitelist, preventing unauthorized modifications.

2. **Zero Address Protection**: The contract rejects attempts to whitelist the zero address, preventing potential exploits.

3. **Event Emission**: All whitelist changes emit events, providing a complete audit trail on-chain.

4. **Backward Compatibility**: By default, whitelist enforcement is disabled, maintaining compatibility with existing behavior.

5. **No Retroactive Effect**: Enabling the whitelist does not affect existing contributions, only new contributions are checked.

## Integration with Compliance

This whitelist feature complements the existing compliance layer in the FutureFlux protocol:

- **TransferRestriction**: Controls token transfers based on KYC/compliance
- **Flashsale Whitelist**: Controls participation in flashsale campaigns

These two layers work independently, allowing for flexible compliance strategies:
- Token-level restrictions (TransferRestriction)
- Campaign-level restrictions (Flashsale whitelist)

## Testing

Comprehensive tests have been added to `test/unit/Flashsale.t.sol` covering:

- ✅ Adding/removing individual participants
- ✅ Batch operations
- ✅ Whitelist toggle functionality
- ✅ Contribution with whitelist enabled/disabled
- ✅ Access control (only admin can manage)
- ✅ Edge cases (zero address, duplicate entries)
- ✅ Event emissions
- ✅ Multi-participant scenarios with whitelist

## Migration Guide

For existing deployments:

1. **No Breaking Changes**: Existing campaigns and contributions are unaffected
2. **Default Behavior**: Whitelist is disabled by default (same as before)
3. **Opt-in**: Enable whitelist only when needed for compliance
4. **Admin Setup**: Grant ADMIN_ROLE to appropriate addresses for whitelist management

## Future Enhancements

Potential future improvements:

1. **Per-Campaign Whitelist**: Allow different whitelists for different campaigns
2. **Time-Limited Whitelist**: Support temporary whitelist entries with expiration
3. **Whitelist Tiers**: Different contribution limits based on whitelist tier
4. **Integration with Identity Protocols**: Automatic whitelist based on on-chain identity verification

## References

- OpenZeppelin AccessControl: https://docs.openzeppelin.com/contracts/4.x/access-control
- FutureFlux Architecture: [ARCHITECTURE.md](../ARCHITECTURE.md)
- Compliance Layer: [contracts/compliance/TransferRestriction.sol](../contracts/compliance/TransferRestriction.sol)
