// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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
            participantCount: 0
        });
        
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
        
        // Track contribution
        if (contributorAmounts[campaignId][msg.sender] == 0) {
            campaign.participantCount++;
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
     * @notice Execute flashsale if threshold met
     */
    function execute(uint256 campaignId) external nonReentrant {
        FlashsaleData storage campaign = campaigns[campaignId];
        
        require(campaign.status == FlashsaleStatus.THRESHOLD_MET, "Flashsale: threshold not met");
        require(block.timestamp >= campaign.executionTime, "Flashsale: too early");
        require(block.timestamp < campaign.endTime, "Flashsale: window expired");
        
        // TODO: Integrate with AMM to execute swap
        // For now, this is a placeholder
        uint256 tokensAcquired = 0;
        
        campaign.status = FlashsaleStatus.EXECUTED;
        
        // Distribute tokens proportionally to contributors
        // TODO: Implement distribution logic
        
        emit FlashsaleExecuted(campaignId, tokensAcquired, campaign.totalCommitted);
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
}
