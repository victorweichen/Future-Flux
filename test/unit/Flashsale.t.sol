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

    function test_GetActiveCampaigns() public {
        // Create multiple campaigns
        uint256 campaign1 = _createCampaign();
        
        // Warp to avoid cooldown
        vm.warp(block.timestamp + 2 days);
        uint256 campaign2 = _createCampaign();

        uint256[] memory activeCampaigns = flashsale.getActiveCampaigns();
        
        assertEq(activeCampaigns.length, 2);
        assertEq(activeCampaigns[0], campaign1);
        assertEq(activeCampaigns[1], campaign2);
    }

    function test_GetParticipants() public {
        uint256 campaignId = _createCampaign();

        // Contributor1 contributes
        vm.startPrank(contributor1);
        settlementToken.approve(address(flashsale), 50e18);
        flashsale.contribute(campaignId, 50e18);
        vm.stopPrank();

        // Contributor2 contributes
        vm.startPrank(contributor2);
        settlementToken.approve(address(flashsale), 50e18);
        flashsale.contribute(campaignId, 50e18);
        vm.stopPrank();

        address[] memory participants = flashsale.getParticipants(campaignId);
        
        assertEq(participants.length, 2);
        assertEq(participants[0], contributor1);
        assertEq(participants[1], contributor2);
    }

    function test_CheckIsParticipant() public {
        uint256 campaignId = _createCampaign();

        // Before contribution
        assertFalse(flashsale.checkIsParticipant(campaignId, contributor1));

        // Contributor1 contributes
        vm.startPrank(contributor1);
        settlementToken.approve(address(flashsale), 50e18);
        flashsale.contribute(campaignId, 50e18);
        vm.stopPrank();

        // After contribution
        assertTrue(flashsale.checkIsParticipant(campaignId, contributor1));
        assertFalse(flashsale.checkIsParticipant(campaignId, contributor2));
    }

    function test_ParticipantJoinedEvent() public {
        uint256 campaignId = _createCampaign();

        vm.startPrank(contributor1);
        settlementToken.approve(address(flashsale), 50e18);
        
        vm.expectEmit(true, true, false, false);
        emit Flashsale.ParticipantJoined(campaignId, contributor1);
        
        flashsale.contribute(campaignId, 50e18);
        vm.stopPrank();
    }

    function test_MultipleContributionsOnlyOneParticipantEvent() public {
        uint256 campaignId = _createCampaign();

        vm.startPrank(contributor1);
        settlementToken.approve(address(flashsale), 100e18);
        
        // First contribution - should emit ParticipantJoined
        flashsale.contribute(campaignId, 30e18);
        
        // Second contribution - should NOT emit ParticipantJoined
        flashsale.contribute(campaignId, 20e18);
        vm.stopPrank();

        address[] memory participants = flashsale.getParticipants(campaignId);
        assertEq(participants.length, 1);
        assertEq(participants[0], contributor1);
    }

    function test_GetTotalCampaignsCount() public {
        assertEq(flashsale.getTotalCampaignsCount(), 0);
        
        _createCampaign();
        assertEq(flashsale.getTotalCampaignsCount(), 1);
        
        vm.warp(block.timestamp + 2 days);
        _createCampaign();
        assertEq(flashsale.getTotalCampaignsCount(), 2);
    }

    function test_ActiveCampaignsOnlyShowsActiveStatus() public {
        uint256 campaignId = _createCampaign();

        uint256[] memory activeCampaigns = flashsale.getActiveCampaigns();
        assertEq(activeCampaigns.length, 1);

        // Contribute below threshold and let it fail
        vm.startPrank(contributor1);
        settlementToken.approve(address(flashsale), 50e18);
        flashsale.contribute(campaignId, 50e18);
        vm.stopPrank();

        // Warp past end time
        vm.warp(block.timestamp + DURATION + 1);
        flashsale.failCampaign(campaignId);

        // Failed campaigns should not show in active
        activeCampaigns = flashsale.getActiveCampaigns();
        assertEq(activeCampaigns.length, 0);
    }
}
