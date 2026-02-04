// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../contracts/rwa/liquidation/AuctionLiquidator.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AuctionLiquidatorTest is Test {
    AuctionLiquidator public liquidator;
    MockToken public assetToken;
    MockToken public bidToken;
    
    address public governance = address(0x1);
    address public settlementEngine = address(0x2);
    address public bidder1 = address(0x3);
    address public bidder2 = address(0x4);
    
    function setUp() public {
        liquidator = new AuctionLiquidator(governance, 1 days);
        assetToken = new MockToken("Asset", "ASSET");
        bidToken = new MockToken("Bid Token", "BID");
        
        vm.startPrank(governance);
        liquidator.grantRole(keccak256("SETTLEMENT_ENGINE_ROLE"), settlementEngine);
        vm.stopPrank();
        
        // Mint tokens
        assetToken.mint(address(liquidator), 1000e18);
        bidToken.mint(bidder1, 1000e18);
        bidToken.mint(bidder2, 1000e18);
    }
    
    function test_CreateAuction() public {
        vm.prank(settlementEngine);
        uint256 auctionId = liquidator.createAuction(
            address(assetToken),
            100e18,
            address(bidToken),
            10e18,
            1 days
        );
        
        assertEq(auctionId, 1);
        
        AuctionLiquidator.Auction memory auction = liquidator.getAuction(auctionId);
        assertEq(auction.assetAmount, 100e18);
        assertEq(auction.minBid, 10e18);
    }
    
    function test_PlaceBid() public {
        vm.prank(settlementEngine);
        uint256 auctionId = liquidator.createAuction(
            address(assetToken),
            100e18,
            address(bidToken),
            10e18,
            1 days
        );
        
        vm.startPrank(bidder1);
        bidToken.approve(address(liquidator), 50e18);
        liquidator.placeBid(auctionId, 50e18);
        vm.stopPrank();
        
        AuctionLiquidator.Auction memory auction = liquidator.getAuction(auctionId);
        assertEq(auction.highestBid, 50e18);
        assertEq(auction.highestBidder, bidder1);
    }
    
    function test_MultipleBidsWithIncrement() public {
        vm.prank(settlementEngine);
        uint256 auctionId = liquidator.createAuction(
            address(assetToken),
            100e18,
            address(bidToken),
            10e18,
            1 days
        );
        
        // First bid
        vm.startPrank(bidder1);
        bidToken.approve(address(liquidator), 100e18);
        liquidator.placeBid(auctionId, 50e18);
        vm.stopPrank();
        
        // Second bid (must meet increment requirement)
        vm.startPrank(bidder2);
        bidToken.approve(address(liquidator), 100e18);
        liquidator.placeBid(auctionId, 51e18); // 1% increase
        vm.stopPrank();
        
        AuctionLiquidator.Auction memory auction = liquidator.getAuction(auctionId);
        assertEq(auction.highestBidder, bidder2);
        assertEq(auction.highestBid, 51e18);
    }
    
    function test_InsufficientBidIncrement() public {
        vm.prank(settlementEngine);
        uint256 auctionId = liquidator.createAuction(
            address(assetToken),
            100e18,
            address(bidToken),
            10e18,
            1 days
        );
        
        vm.startPrank(bidder1);
        bidToken.approve(address(liquidator), 100e18);
        liquidator.placeBid(auctionId, 50e18);
        vm.stopPrank();
        
        vm.startPrank(bidder2);
        bidToken.approve(address(liquidator), 100e18);
        vm.expectRevert("AuctionLiquidator: bid increment too small");
        liquidator.placeBid(auctionId, 50.4e18); // Less than 1% increase
        vm.stopPrank();
    }
    
    function test_AuctionFinalization() public {
        vm.prank(settlementEngine);
        uint256 auctionId = liquidator.createAuction(
            address(assetToken),
            100e18,
            address(bidToken),
            10e18,
            1 days
        );
        
        vm.startPrank(bidder1);
        bidToken.approve(address(liquidator), 100e18);
        liquidator.placeBid(auctionId, 50e18);
        vm.stopPrank();
        
        // Warp to end time
        vm.warp(block.timestamp + 1 days + 1);
        
        uint256 balanceBefore = assetToken.balanceOf(bidder1);
        
        liquidator.finalizeAuction(auctionId);
        
        uint256 balanceAfter = assetToken.balanceOf(bidder1);
        assertEq(balanceAfter - balanceBefore, 100e18);
    }
    
    function test_BidderRefund() public {
        vm.prank(settlementEngine);
        uint256 auctionId = liquidator.createAuction(
            address(assetToken),
            100e18,
            address(bidToken),
            10e18,
            1 days
        );
        
        // Bidder1 places initial bid
        vm.startPrank(bidder1);
        bidToken.approve(address(liquidator), 100e18);
        liquidator.placeBid(auctionId, 50e18);
        vm.stopPrank();
        
        // Bidder2 outbids
        vm.startPrank(bidder2);
        bidToken.approve(address(liquidator), 100e18);
        liquidator.placeBid(auctionId, 51e18);
        vm.stopPrank();
        
        // Bidder1 claims refund
        uint256 bidder1BalanceBefore = bidToken.balanceOf(bidder1);
        
        vm.prank(bidder1);
        liquidator.claimRefund(auctionId);
        
        uint256 bidder1BalanceAfter = bidToken.balanceOf(bidder1);
        assertEq(bidder1BalanceAfter - bidder1BalanceBefore, 50e18);
    }
}
