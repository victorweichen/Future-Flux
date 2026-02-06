// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AuctionLiquidator
 * @notice On-chain auction mechanism for distressed asset liquidation
 * @dev Prevents AMM death spirals through periodic competitive bidding
 *      - Public, immutable clearing prices
 *      - No MEV-based manipulation
 *      - Real price discovery
 */
contract AuctionLiquidator is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant SETTLEMENT_ENGINE_ROLE = keccak256("SETTLEMENT_ENGINE_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    enum AuctionStatus {
        PENDING,
        ACTIVE,
        FINALIZED,
        CANCELLED
    }

    struct Auction {
        uint256 auctionId;
        address assetToken;
        uint256 assetAmount;
        address bidToken;
        uint256 startTime;
        uint256 endTime;
        uint256 minBid;
        AuctionStatus status;
        address highestBidder;
        uint256 highestBid;
        uint256 totalBids;
    }

    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    // Auction tracking
    uint256 public nextAuctionId;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids;
    mapping(uint256 => mapping(address => uint256)) public bidderRefunds;
    
    // Auction parameters
    uint256 public defaultAuctionDuration;
    uint256 public minBidIncrement; // Basis points (100 = 1%)
    
    // Events
    event AuctionCreated(uint256 indexed auctionId, address indexed assetToken, uint256 assetAmount, uint256 startTime, uint256 endTime);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount, uint256 timestamp);
    event AuctionFinalized(uint256 indexed auctionId, address winner, uint256 finalPrice);
    event AuctionCancelled(uint256 indexed auctionId, string reason);
    event RefundClaimed(uint256 indexed auctionId, address indexed bidder, uint256 amount);

    constructor(address _governance, uint256 _defaultDuration) {
        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(GOVERNANCE_ROLE, _governance);
        
        defaultAuctionDuration = _defaultDuration;
        minBidIncrement = 100; // 1% minimum increment
        nextAuctionId = 1;
    }

    /**
     * @notice Create a new auction
     */
    function createAuction(
        address assetToken,
        uint256 assetAmount,
        address bidToken,
        uint256 minBid,
        uint256 duration
    ) external onlyRole(SETTLEMENT_ENGINE_ROLE) returns (uint256) {
        require(assetToken != address(0), "AuctionLiquidator: invalid asset token");
        require(bidToken != address(0), "AuctionLiquidator: invalid bid token");
        require(assetAmount > 0, "AuctionLiquidator: invalid amount");
        
        uint256 auctionId = nextAuctionId++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (duration > 0 ? duration : defaultAuctionDuration);
        
        auctions[auctionId] = Auction({
            auctionId: auctionId,
            assetToken: assetToken,
            assetAmount: assetAmount,
            bidToken: bidToken,
            startTime: startTime,
            endTime: endTime,
            minBid: minBid,
            status: AuctionStatus.ACTIVE,
            highestBidder: address(0),
            highestBid: 0,
            totalBids: 0
        });
        
        emit AuctionCreated(auctionId, assetToken, assetAmount, startTime, endTime);
        
        return auctionId;
    }

    /**
     * @notice Place a bid on an auction
     */
    function placeBid(uint256 auctionId, uint256 bidAmount) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        
        require(auction.status == AuctionStatus.ACTIVE, "AuctionLiquidator: auction not active");
        require(block.timestamp >= auction.startTime, "AuctionLiquidator: auction not started");
        require(block.timestamp < auction.endTime, "AuctionLiquidator: auction ended");
        require(bidAmount >= auction.minBid, "AuctionLiquidator: bid below minimum");
        
        // Check bid increment
        if (auction.highestBid > 0) {
            uint256 minNewBid = auction.highestBid + ((auction.highestBid * minBidIncrement) / 10000);
            require(bidAmount >= minNewBid, "AuctionLiquidator: bid increment too small");
            
            // Mark previous highest bidder for refund
            bidderRefunds[auctionId][auction.highestBidder] += auction.highestBid;
        }
        
        // Transfer bid token from bidder
        IERC20(auction.bidToken).safeTransferFrom(msg.sender, address(this), bidAmount);
        
        // Update auction state
        auction.highestBidder = msg.sender;
        auction.highestBid = bidAmount;
        auction.totalBids++;
        
        // Record bid
        auctionBids[auctionId].push(Bid({
            bidder: msg.sender,
            amount: bidAmount,
            timestamp: block.timestamp
        }));
        
        emit BidPlaced(auctionId, msg.sender, bidAmount, block.timestamp);
    }

    /**
     * @notice Finalize auction after end time
     */
    function finalizeAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        
        require(auction.status == AuctionStatus.ACTIVE, "AuctionLiquidator: auction not active");
        require(block.timestamp >= auction.endTime, "AuctionLiquidator: auction not ended");
        
        auction.status = AuctionStatus.FINALIZED;
        
        if (auction.highestBidder != address(0)) {
            // Transfer asset to winner
            IERC20(auction.assetToken).safeTransfer(auction.highestBidder, auction.assetAmount);
            
            // Transfer proceeds to settlement engine (need to implement destination)
            // For now, keep in contract for withdrawal by governance
            
            emit AuctionFinalized(auctionId, auction.highestBidder, auction.highestBid);
        } else {
            // No bids received - auction failed
            emit AuctionCancelled(auctionId, "No bids received");
        }
    }

    /**
     * @notice Claim refund for outbid amount
     */
    function claimRefund(uint256 auctionId) external nonReentrant {
        uint256 refundAmount = bidderRefunds[auctionId][msg.sender];
        require(refundAmount > 0, "AuctionLiquidator: no refund available");
        
        bidderRefunds[auctionId][msg.sender] = 0;
        
        Auction memory auction = auctions[auctionId];
        IERC20(auction.bidToken).safeTransfer(msg.sender, refundAmount);
        
        emit RefundClaimed(auctionId, msg.sender, refundAmount);
    }

    /**
     * @notice Cancel an auction (emergency only)
     */
    function cancelAuction(uint256 auctionId, string calldata reason) external onlyRole(GOVERNANCE_ROLE) {
        Auction storage auction = auctions[auctionId];
        require(auction.status == AuctionStatus.ACTIVE, "AuctionLiquidator: auction not active");
        
        auction.status = AuctionStatus.CANCELLED;
        
        // Refund highest bidder if exists
        if (auction.highestBidder != address(0)) {
            bidderRefunds[auctionId][auction.highestBidder] += auction.highestBid;
        }
        
        emit AuctionCancelled(auctionId, reason);
    }

    /**
     * @notice Get auction details
     */
    function getAuction(uint256 auctionId) external view returns (Auction memory) {
        return auctions[auctionId];
    }

    /**
     * @notice Get all bids for an auction
     */
    function getAuctionBids(uint256 auctionId) external view returns (Bid[] memory) {
        return auctionBids[auctionId];
    }

    /**
     * @notice Get bid count for an auction
     */
    function getBidCount(uint256 auctionId) external view returns (uint256) {
        return auctionBids[auctionId].length;
    }

    /**
     * @notice Check if auction can be finalized
     */
    function canFinalize(uint256 auctionId) external view returns (bool) {
        Auction memory auction = auctions[auctionId];
        return auction.status == AuctionStatus.ACTIVE && block.timestamp >= auction.endTime;
    }

    /**
     * @notice Update auction parameters
     */
    function updateParameters(
        uint256 _defaultDuration,
        uint256 _minBidIncrement
    ) external onlyRole(GOVERNANCE_ROLE) {
        defaultAuctionDuration = _defaultDuration;
        minBidIncrement = _minBidIncrement;
    }
}
