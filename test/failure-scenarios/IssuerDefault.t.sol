// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {EscrowVault} from "../../contracts/rwa/escrow/EscrowVault.sol";
import {SettlementStateMachine} from "../../contracts/rwa/settlement/SettlementStateMachine.sol";
import {WaterfallDistributor} from "../../contracts/rwa/settlement/WaterfallDistributor.sol";
import {AuctionLiquidator} from "../../contracts/rwa/liquidation/AuctionLiquidator.sol";
import {RWAToken} from "../../contracts/rwa/tokens/RWAToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title IssuerDefaultScenarioTest
 * @notice Tests the complete flow of an issuer default scenario
 * Follows the whitepaper's failure scenario walkthrough
 */
contract IssuerDefaultScenarioTest is Test {
    EscrowVault public vault;
    SettlementStateMachine public stateMachine;
    WaterfallDistributor public waterfall;
    AuctionLiquidator public liquidator;
    RWAToken public rwaToken;
    MockUSDC public usdc;
    
    address public governance = address(0x1);
    address public settlementEngine = address(0x2);
    address public issuer = address(0x3);
    address public tokenHolder1 = address(0x4);
    address public tokenHolder2 = address(0x5);
    address public bidder = address(0x6);
    
    function setUp() public {
        vm.startPrank(governance);

        usdc = new MockUSDC();
        rwaToken = new RWAToken("RWA", "RWA", governance, "Test", "ipfs://");
        rwaToken.grantRole(keccak256("MINTER_ROLE"), settlementEngine);

        vault = new EscrowVault(address(rwaToken), settlementEngine, governance);
        vault.addSupportedAsset(address(usdc));

        stateMachine = new SettlementStateMachine(governance);
        stateMachine.grantRole(keccak256("SETTLEMENT_ENGINE_ROLE"), settlementEngine);

        waterfall = new WaterfallDistributor(governance);
        waterfall.grantRole(keccak256("SETTLEMENT_ENGINE_ROLE"), settlementEngine);

        liquidator = new AuctionLiquidator(governance, 1 days);
        liquidator.grantRole(keccak256("SETTLEMENT_ENGINE_ROLE"), settlementEngine);

        // Configure waterfall
        waterfall.configureTranche(
            WaterfallDistributor.Tranche.PROTOCOL_RESERVES,
            governance,
            50e18
        );
        waterfall.configureTranche(
            WaterfallDistributor.Tranche.ISSUER_COLLATERAL,
            issuer,
            100e18
        );
        waterfall.configureTranche(
            WaterfallDistributor.Tranche.INSURANCE_FUND,
            governance,
            75e18
        );
        
        vm.stopPrank();
        
        // Setup initial state
        usdc.mint(address(vault), 200e18); // Escrow backing
        usdc.mint(address(liquidator), 100e18); // Collateral for auction
        usdc.mint(bidder, 500e18); // Bidder capital
        
        // Mint RWA tokens to holders
        vm.startPrank(settlementEngine);
        rwaToken.mint(tokenHolder1, 100e18);
        rwaToken.mint(tokenHolder2, 100e18);
        vm.stopPrank();
    }
    
    function test_IssuerDefaultFullFlow() public {
        // Initial state: NORMAL
        assertEq(stateMachine.getCurrentState(), 0);
        
        // Step 1: Issuer default detected, breach covenant
        vm.startPrank(settlementEngine);
        stateMachine.transitionTo(
            SettlementStateMachine.State.WARNING,
            "Issuer covenant breach detected"
        );
        vm.stopPrank();
        
        assertEq(stateMachine.getCurrentState(), 1); // WARNING
        
        // Step 2: Escalate to PROTECT
        vm.startPrank(settlementEngine);
        stateMachine.transitionTo(
            SettlementStateMachine.State.PROTECT,
            "Escalating to protect mode"
        );
        vm.stopPrank();

        assertEq(stateMachine.getCurrentState(), 2); // PROTECT

        // Step 2b: Grace period expires, confirm default
        vm.startPrank(settlementEngine);
        stateMachine.transitionTo(
            SettlementStateMachine.State.DEFAULT,
            "Grace period expired"
        );
        vm.stopPrank();

        assertEq(stateMachine.getCurrentState(), 3); // DEFAULT
        
        // Step 3: Trigger collateral liquidation via auction
        vm.startPrank(settlementEngine);
        uint256 auctionId = liquidator.createAuction(
            address(usdc),
            100e18,
            address(usdc),
            10e18,
            1 days
        );
        vm.stopPrank();
        
        // Step 4: Bidder purchases collateral
        vm.startPrank(bidder);
        usdc.approve(address(liquidator), 90e18);
        liquidator.placeBid(auctionId, 90e18);
        vm.stopPrank();
        
        // Step 5: Auction finalizes
        vm.warp(block.timestamp + 1 days + 1);
        liquidator.finalizeAuction(auctionId);
        
        // Step 6: Execute waterfall
        uint256 totalClaims = 200e18; // 100 + 100
        
        vm.startPrank(settlementEngine);
        waterfall.setTotalClaims(totalClaims);
        
        // Issuer default results in 100e18 loss from escrow (100 collateral - 90 bids)
        waterfall.executeWaterfall(10e18);
        vm.stopPrank();
        
        // Step 7: Verify waterfall distribution (protocol reserves absorb first)
        assertEq(waterfall.getTrancheLoss(WaterfallDistributor.Tranche.PROTOCOL_RESERVES), 10e18);
        
        // Step 8: Token holders calculate recovery
        uint256 holderRecovery = waterfall.calculateRecovery(100e18);
        assertGt(holderRecovery, 0);
        
        // Step 9: Transition to RECOVERY
        vm.startPrank(settlementEngine);
        stateMachine.transitionTo(
            SettlementStateMachine.State.RECOVERY,
            "Restructuring complete"
        );
        vm.stopPrank();
        
        assertEq(stateMachine.getCurrentState(), 4); // RECOVERY
    }
    
    function test_IssuerDefaultHaircutCalculation() public {
        // Setup: 200 total tokens, loss that leaves 10e18 reaching token holders
        // Tranche buffers: 50 + 100 + 75 = 225e18
        // Total loss = 235e18 so 10e18 reaches token holders → 95% recovery
        uint256 tokenSupply = 200e18;
        uint256 loss = 235e18;

        vm.startPrank(settlementEngine);
        waterfall.setTotalClaims(tokenSupply);
        waterfall.executeWaterfall(loss);
        vm.stopPrank();

        // Expected: 95% recovery ((200 - 10) / 200)
        uint256 holderRecovery = waterfall.calculateRecovery(100e18);
        assertApproxEqAbs(holderRecovery, 95e18, 1); // ~95%
    }
}
