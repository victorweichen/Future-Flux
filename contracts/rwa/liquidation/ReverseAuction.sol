// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ReverseAuction
 * @notice Designated buyer settlement window mechanism
 * @dev Allows designated buyer to commit capital and acquire RWA tokens
 *      Prevents liquidity flight during execution window
 */
contract ReverseAuction is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    enum ReverseAuctionStatus {
        PENDING,
        LOCKED,
        EXECUTED,
        CANCELLED
    }

    struct ReverseAuctionData {
        uint256 auctionId;
        address buyer;
        address settlementToken;
        uint256 committedAmount;
        uint256 executionTime;
        uint256 lockupPeriod;
        address targetToken;
        ReverseAuctionStatus status;
        uint256 acquiredAmount;
    }

    // Auction tracking
    uint256 public nextAuctionId;
    mapping(uint256 => ReverseAuctionData) public reverseAuctions;
    
    // Parameters
    uint256 public maxLockupDuration;
    uint256 public cooldownPeriod;
    mapping(address => uint256) public lastAuctionTime;
    
    // Events
    event ReverseAuctionCreated(uint256 indexed auctionId, address indexed buyer, uint256 committedAmount, uint256 executionTime);
    event CapitalCommitted(uint256 indexed auctionId, uint256 amount);
    event ReverseAuctionExecuted(uint256 indexed auctionId, uint256 acquiredTokens, uint256 avgPrice);
    event ReverseAuctionCancelled(uint256 indexed auctionId, string reason);

    constructor(address _governance) {
        _grantRole(DEFAULT_ADMIN_ROLE, _governance);
        _grantRole(GOVERNANCE_ROLE, _governance);
        
        maxLockupDuration = 7 days;
        cooldownPeriod = 1 days;
        nextAuctionId = 1;
    }

    /**
     * @notice Create a reverse auction
     */
    function createReverseAuction(
        address buyer,
        address settlementToken,
        uint256 committedAmount,
        uint256 executionTime,
        uint256 lockupPeriod,
        address targetToken
    ) external onlyRole(OPERATOR_ROLE) returns (uint256) {
        require(buyer != address(0), "ReverseAuction: invalid buyer");
        require(executionTime > block.timestamp, "ReverseAuction: invalid execution time");
        require(lockupPeriod <= maxLockupDuration, "ReverseAuction: lockup too long");
        require(committedAmount > 0, "ReverseAuction: invalid amount");
        
        // Check cooldown
        require(
            block.timestamp >= lastAuctionTime[targetToken] + cooldownPeriod,
            "ReverseAuction: cooldown not elapsed"
        );
        
        uint256 auctionId = nextAuctionId++;
        
        reverseAuctions[auctionId] = ReverseAuctionData({
            auctionId: auctionId,
            buyer: buyer,
            settlementToken: settlementToken,
            committedAmount: committedAmount,
            executionTime: executionTime,
            lockupPeriod: lockupPeriod,
            targetToken: targetToken,
            status: ReverseAuctionStatus.PENDING,
            acquiredAmount: 0
        });
        
        lastAuctionTime[targetToken] = block.timestamp;
        
        emit ReverseAuctionCreated(auctionId, buyer, committedAmount, executionTime);
        
        return auctionId;
    }

    /**
     * @notice Commit capital to reverse auction
     */
    function commitCapital(uint256 auctionId) external nonReentrant {
        ReverseAuctionData storage auction = reverseAuctions[auctionId];
        
        require(auction.status == ReverseAuctionStatus.PENDING, "ReverseAuction: not pending");
        require(msg.sender == auction.buyer, "ReverseAuction: not designated buyer");
        
        // Transfer settlement token
        IERC20(auction.settlementToken).safeTransferFrom(
            msg.sender,
            address(this),
            auction.committedAmount
        );
        
        auction.status = ReverseAuctionStatus.LOCKED;
        
        emit CapitalCommitted(auctionId, auction.committedAmount);
    }

    /**
     * @notice Execute reverse auction at execution time
     */
    function execute(uint256 auctionId) external onlyRole(OPERATOR_ROLE) nonReentrant {
        ReverseAuctionData storage auction = reverseAuctions[auctionId];
        
        require(auction.status == ReverseAuctionStatus.LOCKED, "ReverseAuction: not locked");
        require(block.timestamp >= auction.executionTime, "ReverseAuction: too early");
        require(
            block.timestamp < auction.executionTime + auction.lockupPeriod,
            "ReverseAuction: window expired"
        );
        
        // TODO: Integrate with AMM to execute swap
        // For now, this is a placeholder
        uint256 acquiredTokens = 0; // Will be calculated based on AMM interaction
        
        auction.status = ReverseAuctionStatus.EXECUTED;
        auction.acquiredAmount = acquiredTokens;
        
        // Transfer acquired tokens to buyer
        if (acquiredTokens > 0) {
            IERC20(auction.targetToken).safeTransfer(auction.buyer, acquiredTokens);
        }
        
        uint256 avgPrice = acquiredTokens > 0 ? (auction.committedAmount * 1e18) / acquiredTokens : 0;
        
        emit ReverseAuctionExecuted(auctionId, acquiredTokens, avgPrice);
    }

    /**
     * @notice Cancel reverse auction
     */
    function cancel(uint256 auctionId, string calldata reason) external onlyRole(GOVERNANCE_ROLE) {
        ReverseAuctionData storage auction = reverseAuctions[auctionId];
        
        require(
            auction.status == ReverseAuctionStatus.PENDING || auction.status == ReverseAuctionStatus.LOCKED,
            "ReverseAuction: cannot cancel"
        );
        
        // Refund if capital was committed
        if (auction.status == ReverseAuctionStatus.LOCKED) {
            IERC20(auction.settlementToken).safeTransfer(auction.buyer, auction.committedAmount);
        }
        
        auction.status = ReverseAuctionStatus.CANCELLED;
        
        emit ReverseAuctionCancelled(auctionId, reason);
    }

    /**
     * @notice Get reverse auction details
     */
    function getReverseAuction(uint256 auctionId) external view returns (ReverseAuctionData memory) {
        return reverseAuctions[auctionId];
    }

    /**
     * @notice Check if reverse auction can be executed
     */
    function canExecute(uint256 auctionId) external view returns (bool) {
        ReverseAuctionData memory auction = reverseAuctions[auctionId];
        return auction.status == ReverseAuctionStatus.LOCKED
            && block.timestamp >= auction.executionTime
            && block.timestamp < auction.executionTime + auction.lockupPeriod;
    }

    /**
     * @notice Update parameters
     */
    function updateParameters(
        uint256 _maxLockupDuration,
        uint256 _cooldownPeriod
    ) external onlyRole(GOVERNANCE_ROLE) {
        maxLockupDuration = _maxLockupDuration;
        cooldownPeriod = _cooldownPeriod;
    }
}
