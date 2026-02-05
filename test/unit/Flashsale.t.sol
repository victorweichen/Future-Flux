// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../contracts/rwa/liquidation/Flashsale.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FlashsaleTest is Test {
    Flashsale public flashsale;
    MockToken public targetToken;
    MockToken public settlementToken;

    address public creator = address(0x1);
    address public seller = address(0x2);
    address public contributor1 = address(0x3);
    address public contributor2 = address(0x4);

    uint256 public constant MIN_THRESHOLD = 100e18;
    uint256 public constant MAX_RAISE = 200e18;
    uint256 public constant DURATION = 3 days;

    function setUp() public {
        // Warp past cooldown period so campaign creation succeeds
        vm.warp(2 days);

        flashsale = new Flashsale();
        targetToken = new MockToken("Target RWA", "RWA");
        settlementToken = new MockToken("USDC", "USDC");

        // Fund participants
        settlementToken.mint(contributor1, 1000e18);
        settlementToken.mint(contributor2, 1000e18);
        targetToken.mint(seller, 1000e18);
    }

    function _createCampaign() internal returns (uint256) {
        uint256 executionTime = block.timestamp + 1 days;
        vm.prank(creator);
        return flashsale.createFlashsale(
            address(targetToken),
            address(settlementToken),
            MIN_THRESHOLD,
            MAX_RAISE,
            executionTime,
            DURATION
        );
    }

    function _contributeAndMeetThreshold(uint256 campaignId) internal {
        vm.startPrank(contributor1);
        settlementToken.approve(address(flashsale), MIN_THRESHOLD);
        flashsale.contribute(campaignId, MIN_THRESHOLD);
        vm.stopPrank();
    }

    function test_CreateFlashsale() public {
        uint256 campaignId = _createCampaign();

        assertEq(campaignId, 1);

        Flashsale.FlashsaleData memory campaign = flashsale.getCampaign(campaignId);
        assertEq(campaign.targetToken, address(targetToken));
        assertEq(campaign.settlementToken, address(settlementToken));
        assertEq(campaign.minThreshold, MIN_THRESHOLD);
        assertEq(campaign.maxRaise, MAX_RAISE);
        assertEq(uint256(campaign.status), uint256(Flashsale.FlashsaleStatus.ACTIVE));
        assertEq(campaign.totalCommitted, 0);
        assertEq(campaign.tokensDeposited, 0);
    }

    function test_Contribute() public {
        uint256 campaignId = _createCampaign();

        vm.startPrank(contributor1);
        settlementToken.approve(address(flashsale), 50e18);
        flashsale.contribute(campaignId, 50e18);
        vm.stopPrank();

        Flashsale.FlashsaleData memory campaign = flashsale.getCampaign(campaignId);
        assertEq(campaign.totalCommitted, 50e18);
        assertEq(campaign.participantCount, 1);
        assertEq(flashsale.getContributorAmount(campaignId, contributor1), 50e18);
    }

    function test_ThresholdReached() public {
        uint256 campaignId = _createCampaign();

        _contributeAndMeetThreshold(campaignId);

        Flashsale.FlashsaleData memory campaign = flashsale.getCampaign(campaignId);
        assertEq(uint256(campaign.status), uint256(Flashsale.FlashsaleStatus.THRESHOLD_MET));
        assertEq(campaign.totalCommitted, MIN_THRESHOLD);
    }

    function test_DepositTokens() public {
        uint256 campaignId = _createCampaign();

        vm.startPrank(seller);
        targetToken.approve(address(flashsale), 500e18);
        flashsale.depositTokens(campaignId, 500e18);
        vm.stopPrank();

        Flashsale.FlashsaleData memory campaign = flashsale.getCampaign(campaignId);
        assertEq(campaign.tokensDeposited, 500e18);
        assertEq(targetToken.balanceOf(address(flashsale)), 500e18);
    }

    function test_Execute() public {
        uint256 campaignId = _createCampaign();

        // Contribute to meet threshold
        _contributeAndMeetThreshold(campaignId);

        // Deposit target tokens
        vm.startPrank(seller);
        targetToken.approve(address(flashsale), 500e18);
        flashsale.depositTokens(campaignId, 500e18);
        vm.stopPrank();

        // Warp to execution time
        vm.warp(block.timestamp + 1 days);

        flashsale.execute(campaignId);

        Flashsale.FlashsaleData memory campaign = flashsale.getCampaign(campaignId);
        assertEq(uint256(campaign.status), uint256(Flashsale.FlashsaleStatus.EXECUTED));
    }

    function test_ClaimTokens() public {
        uint256 campaignId = _createCampaign();

        // Contribute
        _contributeAndMeetThreshold(campaignId);

        // Deposit target tokens
        vm.startPrank(seller);
        targetToken.approve(address(flashsale), 500e18);
        flashsale.depositTokens(campaignId, 500e18);
        vm.stopPrank();

        // Execute
        vm.warp(block.timestamp + 1 days);
        flashsale.execute(campaignId);

        // Claim
        uint256 balanceBefore = targetToken.balanceOf(contributor1);

        vm.prank(contributor1);
        flashsale.claimTokens(campaignId);

        uint256 balanceAfter = targetToken.balanceOf(contributor1);
        // contributor1 committed 100% of totalCommitted, gets 100% of tokens
        assertEq(balanceAfter - balanceBefore, 500e18);
    }

    function test_ProportionalDistribution() public {
        uint256 campaignId = _createCampaign();

        // Contributor1 contributes 75e18
        vm.startPrank(contributor1);
        settlementToken.approve(address(flashsale), 75e18);
        flashsale.contribute(campaignId, 75e18);
        vm.stopPrank();

        // Contributor2 contributes 25e18 (total = 100e18, meets threshold)
        vm.startPrank(contributor2);
        settlementToken.approve(address(flashsale), 25e18);
        flashsale.contribute(campaignId, 25e18);
        vm.stopPrank();

        // Deposit 1000 target tokens
        vm.startPrank(seller);
        targetToken.approve(address(flashsale), 1000e18);
        flashsale.depositTokens(campaignId, 1000e18);
        vm.stopPrank();

        // Execute
        vm.warp(block.timestamp + 1 days);
        flashsale.execute(campaignId);

        // Contributor1 claims: 75/100 * 1000 = 750
        vm.prank(contributor1);
        flashsale.claimTokens(campaignId);
        assertEq(targetToken.balanceOf(contributor1), 750e18);

        // Contributor2 claims: 25/100 * 1000 = 250
        vm.prank(contributor2);
        flashsale.claimTokens(campaignId);
        assertEq(targetToken.balanceOf(contributor2), 250e18);
    }

    function test_CannotClaimTwice() public {
        uint256 campaignId = _createCampaign();

        _contributeAndMeetThreshold(campaignId);

        vm.startPrank(seller);
        targetToken.approve(address(flashsale), 500e18);
        flashsale.depositTokens(campaignId, 500e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        flashsale.execute(campaignId);

        vm.startPrank(contributor1);
        flashsale.claimTokens(campaignId);

        vm.expectRevert("Flashsale: already claimed");
        flashsale.claimTokens(campaignId);
        vm.stopPrank();
    }

    function test_ClaimRefundOnFailure() public {
        uint256 campaignId = _createCampaign();

        // Contribute below threshold
        vm.startPrank(contributor1);
        settlementToken.approve(address(flashsale), 50e18);
        flashsale.contribute(campaignId, 50e18);
        vm.stopPrank();

        // Warp past end time
        vm.warp(block.timestamp + DURATION + 1);

        flashsale.failCampaign(campaignId);

        uint256 balanceBefore = settlementToken.balanceOf(contributor1);

        vm.prank(contributor1);
        flashsale.claimRefund(campaignId);

        uint256 balanceAfter = settlementToken.balanceOf(contributor1);
        assertEq(balanceAfter - balanceBefore, 50e18);
    }

    function test_CannotExecuteWithoutDeposit() public {
        uint256 campaignId = _createCampaign();

        _contributeAndMeetThreshold(campaignId);

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert("Flashsale: no tokens deposited");
        flashsale.execute(campaignId);
    }

    // ========== Whitelist Tests ==========

    function test_AddToWhitelist() public {
        address participant = address(0x100);
        
        flashsale.addToWhitelist(participant);
        
        assertTrue(flashsale.isWhitelisted(participant));
    }

    function test_RemoveFromWhitelist() public {
        address participant = address(0x100);
        
        flashsale.addToWhitelist(participant);
        assertTrue(flashsale.isWhitelisted(participant));
        
        flashsale.removeFromWhitelist(participant);
        assertFalse(flashsale.isWhitelisted(participant));
    }

    function test_BatchAddToWhitelist() public {
        address[] memory participants = new address[](3);
        participants[0] = address(0x100);
        participants[1] = address(0x101);
        participants[2] = address(0x102);
        
        flashsale.batchAddToWhitelist(participants);
        
        assertTrue(flashsale.isWhitelisted(participants[0]));
        assertTrue(flashsale.isWhitelisted(participants[1]));
        assertTrue(flashsale.isWhitelisted(participants[2]));
    }

    function test_BatchRemoveFromWhitelist() public {
        address[] memory participants = new address[](3);
        participants[0] = address(0x100);
        participants[1] = address(0x101);
        participants[2] = address(0x102);
        
        flashsale.batchAddToWhitelist(participants);
        flashsale.batchRemoveFromWhitelist(participants);
        
        assertFalse(flashsale.isWhitelisted(participants[0]));
        assertFalse(flashsale.isWhitelisted(participants[1]));
        assertFalse(flashsale.isWhitelisted(participants[2]));
    }

    function test_ToggleWhitelist() public {
        assertFalse(flashsale.whitelistEnabled());
        
        flashsale.toggleWhitelist(true);
        assertTrue(flashsale.whitelistEnabled());
        
        flashsale.toggleWhitelist(false);
        assertFalse(flashsale.whitelistEnabled());
    }

    function test_ContributeWithWhitelistDisabled() public {
        uint256 campaignId = _createCampaign();
        
        // Whitelist is disabled by default, anyone can contribute
        vm.startPrank(contributor1);
        settlementToken.approve(address(flashsale), 50e18);
        flashsale.contribute(campaignId, 50e18);
        vm.stopPrank();
        
        assertEq(flashsale.getContributorAmount(campaignId, contributor1), 50e18);
    }

    function test_ContributeWithWhitelistEnabled() public {
        uint256 campaignId = _createCampaign();
        
        // Enable whitelist and add contributor1
        flashsale.toggleWhitelist(true);
        flashsale.addToWhitelist(contributor1);
        
        // Contributor1 should be able to contribute
        vm.startPrank(contributor1);
        settlementToken.approve(address(flashsale), 50e18);
        flashsale.contribute(campaignId, 50e18);
        vm.stopPrank();
        
        assertEq(flashsale.getContributorAmount(campaignId, contributor1), 50e18);
    }

    function test_CannotContributeWhenNotWhitelisted() public {
        uint256 campaignId = _createCampaign();
        
        // Enable whitelist but don't add contributor1
        flashsale.toggleWhitelist(true);
        
        // Contributor1 should NOT be able to contribute
        vm.startPrank(contributor1);
        settlementToken.approve(address(flashsale), 50e18);
        vm.expectRevert("Flashsale: not whitelisted");
        flashsale.contribute(campaignId, 50e18);
        vm.stopPrank();
    }

    function test_MultipleContributorsWithWhitelist() public {
        uint256 campaignId = _createCampaign();
        
        // Enable whitelist and add both contributors
        flashsale.toggleWhitelist(true);
        flashsale.addToWhitelist(contributor1);
        flashsale.addToWhitelist(contributor2);
        
        // Both should be able to contribute
        vm.startPrank(contributor1);
        settlementToken.approve(address(flashsale), 75e18);
        flashsale.contribute(campaignId, 75e18);
        vm.stopPrank();
        
        vm.startPrank(contributor2);
        settlementToken.approve(address(flashsale), 25e18);
        flashsale.contribute(campaignId, 25e18);
        vm.stopPrank();
        
        Flashsale.FlashsaleData memory campaign = flashsale.getCampaign(campaignId);
        assertEq(campaign.totalCommitted, 100e18);
        assertEq(campaign.participantCount, 2);
    }

    function test_CannotAddInvalidAddressToWhitelist() public {
        vm.expectRevert("Flashsale: invalid address");
        flashsale.addToWhitelist(address(0));
    }

    function test_CannotBatchAddInvalidAddress() public {
        address[] memory participants = new address[](2);
        participants[0] = address(0x100);
        participants[1] = address(0);
        
        vm.expectRevert("Flashsale: invalid address");
        flashsale.batchAddToWhitelist(participants);
    }

    function test_OnlyAdminCanAddToWhitelist() public {
        address nonAdmin = address(0x999);
        address participant = address(0x100);
        
        vm.prank(nonAdmin);
        vm.expectRevert();
        flashsale.addToWhitelist(participant);
    }

    function test_OnlyAdminCanToggleWhitelist() public {
        address nonAdmin = address(0x999);
        
        vm.prank(nonAdmin);
        vm.expectRevert();
        flashsale.toggleWhitelist(true);
    }

    function test_WhitelistEventsEmitted() public {
        address participant = address(0x100);
        
        vm.expectEmit(true, false, false, false);
        emit Flashsale.ParticipantWhitelisted(participant);
        flashsale.addToWhitelist(participant);
        
        vm.expectEmit(true, false, false, false);
        emit Flashsale.ParticipantRemovedFromWhitelist(participant);
        flashsale.removeFromWhitelist(participant);
        
        vm.expectEmit(false, false, false, true);
        emit Flashsale.WhitelistToggled(true);
        flashsale.toggleWhitelist(true);
    }
}
