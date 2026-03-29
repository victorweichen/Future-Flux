// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Flashsale
 * @notice Multiparty settlement coordination mechanism
 * @dev Enables multiple participants to collectively commit capital
 *      for RWA token acquisition with threshold-gated execution
 */
contract Flashsale is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum FlashsaleStatus {
        ACTIVE,
        THRESHOLD_MET,
        EXECUTED,
        FAILED,
        CANCELLED
    }

    struct FlashsaleData {
        uint256 campaignId;
        address targetToken;
        address settlementToken;
        uint256 minThreshold;
        uint256 maxRaise;
        uint256 executionTime;
        uint256 endTime;
        FlashsaleStatus status;
        uint256 totalCommitted;
        uint256 participantCount;
        uint256 tokensDeposited;
    }

    struct Contribution {
        address contributor;
        uint256 amount;
        uint256 timestamp;
    }

    // Campaign tracking
    uint256 public nextCampaignId;
    mapping(uint256 => FlashsaleData) public campaigns;
    mapping(uint256 => Contribution[]) public contributions;
    mapping(uint256 => mapping(address => uint256)) public contributorAmounts;
    
    // Participant tracking
    mapping(uint256 => address[]) public participants;
    mapping(uint256 => mapping(address => bool)) public isParticipant;
    
    // Claim tracking
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    // Active campaigns tracking
    uint256[] public activeCampaignIds;
    mapping(uint256 => uint256) public campaignIdToIndex;

    // Global parameters
    uint256 public maxCampaignDuration;
    uint256 public minCampaignCooldown;
    mapping(address => uint256) public lastCampaignTime;
    
    // Events
    event FlashsaleCreated(uint256 indexed campaignId, address targetToken, uint256 minThreshold, uint256 executionTime);
    event ContributionMade(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event ThresholdReached(uint256 indexed campaignId, uint256 totalCommitted);
    event FlashsaleExecuted(uint256 indexed campaignId, uint256 tokensAcquired, uint256 totalSpent);
    event FlashsaleFailed(uint256 indexed campaignId, string reason);
    event RefundIssued(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event TokensDeposited(uint256 indexed campaignId, address indexed depositor, uint256 amount);
    event TokensClaimed(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event ParticipantJoined(uint256 indexed campaignId, address indexed participant);

    constructor() {
        maxCampaignDuration = 7 days;
        minCampaignCooldown = 1 days;
        nextCampaignId = 1;
    }

    /**
     * @notice Create a new flashsale campaign
     */
    function createFlashsale(
        address targetToken,
        address settlementToken,
        uint256 minThreshold,
        uint256 maxRaise,
        uint256 executionTime,
        uint256 duration
    ) external returns (uint256) {
        require(targetToken != address(0), "Flashsale: invalid target token");
        require(settlementToken != address(0), "Flashsale: invalid settlement token");
        require(minThreshold > 0, "Flashsale: invalid threshold");
        require(maxRaise >= minThreshold, "Flashsale: max < threshold");
        require(executionTime > block.timestamp, "Flashsale: invalid execution time");
        require(duration <= maxCampaignDuration, "Flashsale: duration too long");
        
        // Check cooldown
        require(
            block.timestamp >= lastCampaignTime[targetToken] + minCampaignCooldown,
            "Flashsale: cooldown not elapsed"
        );
        
        uint256 campaignId = nextCampaignId++;
        uint256 endTime = block.timestamp + duration;
        
        campaigns[campaignId] = FlashsaleData({
            campaignId: campaignId,
            targetToken: targetToken,
            settlementToken: settlementToken,
            minThreshold: minThreshold,
            maxRaise: maxRaise,
            executionTime: executionTime,
            endTime: endTime,
            status: FlashsaleStatus.ACTIVE,
            totalCommitted: 0,
            participantCount: 0,
            tokensDeposited: 0
        });
        
        // Track active campaign
        campaignIdToIndex[campaignId] = activeCampaignIds.length;
        activeCampaignIds.push(campaignId);
        
        lastCampaignTime[targetToken] = block.timestamp;
        
        emit FlashsaleCreated(campaignId, targetToken, minThreshold, executionTime);
        
        return campaignId;
    }

    /**
     * @notice Contribute to a flashsale campaign
     */
    function contribute(uint256 campaignId, uint256 amount) external nonReentrant {
        FlashsaleData storage campaign = campaigns[campaignId];
        
        require(campaign.status == FlashsaleStatus.ACTIVE, "Flashsale: not active");
        require(block.timestamp < campaign.endTime, "Flashsale: campaign ended");
        require(amount > 0, "Flashsale: invalid amount");
        require(
            campaign.totalCommitted + amount <= campaign.maxRaise,
            "Flashsale: exceeds max raise"
        );
        
        // Transfer settlement token
        IERC20(campaign.settlementToken).safeTransferFrom(msg.sender, address(this), amount);
        
        // Track contribution and participant
        if (contributorAmounts[campaignId][msg.sender] == 0) {
            campaign.participantCount++;
            participants[campaignId].push(msg.sender);
            isParticipant[campaignId][msg.sender] = true;
            emit ParticipantJoined(campaignId, msg.sender);
        }
        
        contributorAmounts[campaignId][msg.sender] += amount;
        campaign.totalCommitted += amount;
        
        contributions[campaignId].push(Contribution({
            contributor: msg.sender,
            amount: amount,
            timestamp: block.timestamp
        }));
        
        emit ContributionMade(campaignId, msg.sender, amount);
        
        // Check if threshold met
        if (campaign.totalCommitted >= campaign.minThreshold && campaign.status == FlashsaleStatus.ACTIVE) {
            campaign.status = FlashsaleStatus.THRESHOLD_MET;
            emit ThresholdReached(campaignId, campaign.totalCommitted);
        }
    }

    /**
     * @notice Deposit target tokens into a campaign for distribution
     * @param campaignId The campaign to deposit into
     * @param amount The amount of target tokens to deposit
     */
    function depositTokens(uint256 campaignId, uint256 amount) external nonReentrant {
        FlashsaleData storage campaign = campaigns[campaignId];

        require(
            campaign.status == FlashsaleStatus.ACTIVE || campaign.status == FlashsaleStatus.THRESHOLD_MET,
            "Flashsale: not accepting deposits"
        );
        require(amount > 0, "Flashsale: invalid amount");

        IERC20(campaign.targetToken).safeTransferFrom(msg.sender, address(this), amount);
        campaign.tokensDeposited += amount;

        emit TokensDeposited(campaignId, msg.sender, amount);
    }

    /**
     * @notice Execute flashsale if threshold met
     */
    function execute(uint256 campaignId) external nonReentrant {
        FlashsaleData storage campaign = campaigns[campaignId];

        require(campaign.status == FlashsaleStatus.THRESHOLD_MET, "Flashsale: threshold not met");
        require(block.timestamp >= campaign.executionTime, "Flashsale: too early");
        require(block.timestamp < campaign.endTime, "Flashsale: window expired");
        require(campaign.tokensDeposited > 0, "Flashsale: no tokens deposited");

        campaign.status = FlashsaleStatus.EXECUTED;

        emit FlashsaleExecuted(campaignId, campaign.tokensDeposited, campaign.totalCommitted);
    }

    /**
     * @notice Fail campaign if threshold not met by end time
     */
    function failCampaign(uint256 campaignId) external nonReentrant {
        FlashsaleData storage campaign = campaigns[campaignId];
        
        require(campaign.status == FlashsaleStatus.ACTIVE, "Flashsale: not active");
        require(block.timestamp >= campaign.endTime, "Flashsale: not ended");
        require(campaign.totalCommitted < campaign.minThreshold, "Flashsale: threshold met");
        
        campaign.status = FlashsaleStatus.FAILED;
        
        emit FlashsaleFailed(campaignId, "Threshold not reached");
    }

    /**
     * @notice Claim refund if campaign failed
     */
    function claimRefund(uint256 campaignId) external nonReentrant {
        FlashsaleData storage campaign = campaigns[campaignId];
        
        require(campaign.status == FlashsaleStatus.FAILED, "Flashsale: not failed");
        
        uint256 refundAmount = contributorAmounts[campaignId][msg.sender];
        require(refundAmount > 0, "Flashsale: no contribution");
        
        contributorAmounts[campaignId][msg.sender] = 0;
        
        IERC20(campaign.settlementToken).safeTransfer(msg.sender, refundAmount);
        
        emit RefundIssued(campaignId, msg.sender, refundAmount);
    }

    /**
     * @notice Claim proportional token allocation after execution
     */
    function claimTokens(uint256 campaignId) external nonReentrant {
        FlashsaleData storage campaign = campaigns[campaignId];

        require(campaign.status == FlashsaleStatus.EXECUTED, "Flashsale: not executed");
        require(!hasClaimed[campaignId][msg.sender], "Flashsale: already claimed");

        uint256 contribution = contributorAmounts[campaignId][msg.sender];
        require(contribution > 0, "Flashsale: no contribution");

        hasClaimed[campaignId][msg.sender] = true;

        uint256 allocation = (contribution * campaign.tokensDeposited) / campaign.totalCommitted;
        require(allocation > 0, "Flashsale: zero allocation");

        IERC20(campaign.targetToken).safeTransfer(msg.sender, allocation);

        emit TokensClaimed(campaignId, msg.sender, allocation);
    }

    /**
     * @notice Get campaign details
     */
    function getCampaign(uint256 campaignId) external view returns (FlashsaleData memory) {
        return campaigns[campaignId];
    }

    /**
     * @notice Get contributions for a campaign
     */
    function getContributions(uint256 campaignId) external view returns (Contribution[] memory) {
        return contributions[campaignId];
    }

    /**
     * @notice Get contribution amount for a specific contributor
     */
    function getContributorAmount(uint256 campaignId, address contributor) external view returns (uint256) {
        return contributorAmounts[campaignId][contributor];
    }

    /**
     * @notice Calculate proportional token allocation for contributor
     */
    function calculateAllocation(
        uint256 campaignId,
        address contributor,
        uint256 totalTokens
    ) external view returns (uint256) {
        FlashsaleData memory campaign = campaigns[campaignId];
        uint256 contribution = contributorAmounts[campaignId][contributor];
        
        if (campaign.totalCommitted == 0) return 0;
        
        return (contribution * totalTokens) / campaign.totalCommitted;
    }

    /**
     * @notice Check if campaign can be executed
     */
    function canExecute(uint256 campaignId) external view returns (bool) {
        FlashsaleData memory campaign = campaigns[campaignId];
        return campaign.status == FlashsaleStatus.THRESHOLD_MET
            && block.timestamp >= campaign.executionTime
            && block.timestamp < campaign.endTime;
    }

    /**
     * @notice Check if campaign should fail
     */
    function shouldFail(uint256 campaignId) external view returns (bool) {
        FlashsaleData memory campaign = campaigns[campaignId];
        return campaign.status == FlashsaleStatus.ACTIVE
            && block.timestamp >= campaign.endTime
            && campaign.totalCommitted < campaign.minThreshold;
    }

    /**
     * @notice Get all active campaign IDs
     * @return Array of campaign IDs that are currently active
     * @dev Uses two-pass approach: first pass counts active campaigns to allocate
     *      correct array size, second pass populates the array. This ensures we
     *      don't waste gas on oversized arrays or complex dynamic array resizing.
     */
    function getActiveCampaigns() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        
        // Count truly active campaigns
        for (uint256 i = 0; i < activeCampaignIds.length; i++) {
            uint256 campaignId = activeCampaignIds[i];
            FlashsaleData memory campaign = campaigns[campaignId];
            if (campaign.status == FlashsaleStatus.ACTIVE || campaign.status == FlashsaleStatus.THRESHOLD_MET) {
                activeCount++;
            }
        }
        
        // Build array of active campaign IDs
        uint256[] memory activeCampaigns = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < activeCampaignIds.length; i++) {
            uint256 campaignId = activeCampaignIds[i];
            FlashsaleData memory campaign = campaigns[campaignId];
            if (campaign.status == FlashsaleStatus.ACTIVE || campaign.status == FlashsaleStatus.THRESHOLD_MET) {
                activeCampaigns[index] = campaignId;
                index++;
            }
        }
        
        return activeCampaigns;
    }

    /**
     * @notice Get list of participants in a campaign
     * @param campaignId The campaign to query
     * @return Array of participant addresses
     */
    function getParticipants(uint256 campaignId) external view returns (address[] memory) {
        return participants[campaignId];
    }

    /**
     * @notice Check if an address is a participant in a campaign
     * @param campaignId The campaign to check
     * @param participant The address to check
     * @return True if the address is a participant
     */
    function checkIsParticipant(uint256 campaignId, address participant) external view returns (bool) {
        return isParticipant[campaignId][participant];
    }

    /**
     * @notice Get count of all campaigns ever created
     * @return Total number of campaigns
     */
    function getTotalCampaignsCount() external view returns (uint256) {
        return nextCampaignId - 1;
    }
}
