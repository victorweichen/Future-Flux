# Flashsale Participant Management

## Overview

The Flashsale contract has been enhanced with features to better support participant discovery and invitation. These improvements make it easier for potential participants to find active campaigns and for campaign creators to track who has joined.

## New Features

### 1. Campaign Discovery

#### `getActiveCampaigns()`
Returns an array of all campaign IDs that are currently active (in ACTIVE or THRESHOLD_MET status).

**Usage:**
```solidity
uint256[] memory activeCampaigns = flashsale.getActiveCampaigns();
```

**Purpose:** Allows UIs and external systems to discover all ongoing campaigns without needing to iterate through all campaign IDs.

#### `getTotalCampaignsCount()`
Returns the total number of campaigns ever created.

**Usage:**
```solidity
uint256 totalCampaigns = flashsale.getTotalCampaignsCount();
```

**Purpose:** Helps applications understand the campaign ID space and paginate through historical campaigns.

### 2. Participant Tracking

#### `getParticipants(uint256 campaignId)`
Returns an array of all participant addresses in a specific campaign.

**Usage:**
```solidity
address[] memory participants = flashsale.getParticipants(campaignId);
```

**Purpose:** Enables viewing who has joined a campaign, useful for:
- Building participant lists in UIs
- Analyzing campaign participation
- Off-chain notification systems

#### `checkIsParticipant(uint256 campaignId, address participant)`
Checks if a specific address is a participant in a campaign.

**Usage:**
```solidity
bool isParticipant = flashsale.checkIsParticipant(campaignId, userAddress);
```

**Purpose:** Quick lookup for checking participation status without fetching the full participant list.

### 3. Participant Join Event

#### `ParticipantJoined` Event
Emitted when a new participant makes their first contribution to a campaign.

**Event Signature:**
```solidity
event ParticipantJoined(uint256 indexed campaignId, address indexed participant);
```

**Purpose:**
- Real-time notifications when someone joins a campaign
- Off-chain indexing of participant activity
- Building social features around campaign participation

**Note:** This event is only emitted on the first contribution from an address. Subsequent contributions from the same address do not trigger this event.

## Implementation Details

### Storage Changes

```solidity
// Participant tracking
mapping(uint256 => address[]) public participants;
mapping(uint256 => mapping(address => bool)) public isParticipant;

// Active campaigns tracking
uint256[] public activeCampaignIds;
mapping(uint256 => uint256) public campaignIdToIndex;
```

### Behavior

1. **Campaign Creation**: When a campaign is created, it's automatically added to `activeCampaignIds`
2. **First Contribution**: When an address contributes for the first time:
   - Added to `participants[campaignId]` array
   - `isParticipant[campaignId][address]` set to true
   - `ParticipantJoined` event emitted
3. **Subsequent Contributions**: Only update contribution amounts, no participant tracking changes

## Use Cases

### For UIs/Frontends

```javascript
// Discover all active campaigns
const activeCampaignIds = await flashsale.getActiveCampaigns();

// For each campaign, get details and participants
for (const campaignId of activeCampaignIds) {
  const campaign = await flashsale.getCampaign(campaignId);
  const participants = await flashsale.getParticipants(campaignId);
  
  // Display campaign with participant count
  console.log(`Campaign ${campaignId}: ${participants.length} participants`);
}
```

### For Notification Systems

```javascript
// Listen for new participants
flashsale.on('ParticipantJoined', (campaignId, participant) => {
  console.log(`New participant ${participant} joined campaign ${campaignId}`);
  // Send notification, update UI, etc.
});
```

### For Analytics

```javascript
// Check if a user has participated in a campaign
const hasParticipated = await flashsale.checkIsParticipant(campaignId, userAddress);

if (!hasParticipated) {
  // Show "Join Campaign" button
} else {
  // Show "Add More" or contribution details
}
```

## Gas Considerations

- `getActiveCampaigns()`: O(n) where n is total campaigns ever created. For large numbers of campaigns, consider caching results off-chain.
- `getParticipants()`: Returns entire array, cost grows with participant count. Consider pagination for very large campaigns.
- Participant tracking adds minimal gas to the `contribute()` function (~22k gas for first contribution, ~5k for subsequent)

## Backward Compatibility

All changes are backward compatible:
- Existing campaigns continue to work without modification
- New storage variables are append-only
- No changes to existing function signatures
- All new functions are view functions (no state changes)

## Security Considerations

- Participant lists are public and permanently stored on-chain
- No ability to remove participants (by design - immutable record)
- `getActiveCampaigns()` iterates over all campaigns - potential DoS if contract has thousands of campaigns (mitigate with off-chain indexing)
