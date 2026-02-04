// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../contracts/rwa/settlement/WaterfallDistributor.sol";

contract WaterfallDistributorTest is Test {
    WaterfallDistributor public waterfall;
    
    address public governance = address(0x1);
    address public settlementEngine = address(0x2);
    address public protocolReserve = address(0x3);
    address public issuerCollateral = address(0x4);
    address public insuranceFund = address(0x5);
    address public liquidityBuffer = address(0x6);
    
    function setUp() public {
        waterfall = new WaterfallDistributor(governance);
        
        vm.startPrank(governance);
        waterfall.grantRole(keccak256("SETTLEMENT_ENGINE_ROLE"), settlementEngine);
        
        // Configure tranches
        waterfall.configureTranche(
            WaterfallDistributor.Tranche.PROTOCOL_RESERVES,
            protocolReserve,
            100e18
        );
        waterfall.configureTranche(
            WaterfallDistributor.Tranche.ISSUER_COLLATERAL,
            issuerCollateral,
            200e18
        );
        waterfall.configureTranche(
            WaterfallDistributor.Tranche.INSURANCE_FUND,
            insuranceFund,
            150e18
        );
        waterfall.configureTranche(
            WaterfallDistributor.Tranche.LIQUIDITY_BUFFER,
            liquidityBuffer,
            50e18
        );
        
        vm.stopPrank();
    }
    
    function test_WaterfallExecution_SmallLoss() public {
        uint256 loss = 50e18; // Less than protocol reserves
        
        vm.startPrank(settlementEngine);
        waterfall.executeWaterfall(loss);
        vm.stopPrank();
        
        assertTrue(waterfall.isExecuted());
        assertEq(waterfall.getTrancheLoss(WaterfallDistributor.Tranche.PROTOCOL_RESERVES), 50e18);
    }
    
    function test_WaterfallExecution_LargeLoss() public {
        uint256 loss = 500e18; // Exceeds reserves + collateral + insurance + buffer

        vm.startPrank(settlementEngine);
        waterfall.setTotalClaims(100e18);
        waterfall.executeWaterfall(loss);
        vm.stopPrank();

        assertTrue(waterfall.isExecuted());

        // Protocol reserves fully consumed
        assertEq(waterfall.getTrancheLoss(WaterfallDistributor.Tranche.PROTOCOL_RESERVES), 100e18);
        // Issuer collateral fully consumed
        assertEq(waterfall.getTrancheLoss(WaterfallDistributor.Tranche.ISSUER_COLLATERAL), 200e18);
        // Insurance fully consumed
        assertEq(waterfall.getTrancheLoss(WaterfallDistributor.Tranche.INSURANCE_FUND), 150e18);
    }
    
    function test_HaircutCalculation() public {
        uint256 totalClaims = 100e18;
        uint256 loss = 20e18; // 20% loss
        
        vm.startPrank(settlementEngine);
        waterfall.setTotalClaims(totalClaims);
        // Assume loss goes to token holders tranche
        waterfall.executeWaterfall(loss);
        vm.stopPrank();
        
        // haircut should be 80% (80% recovery)
        uint256 expectedHaircut = (80e18 * 10000) / 100e18;
        
        uint256 recovery = waterfall.calculateRecovery(100e18);
        assertGt(recovery, 0);
    }
    
    function test_ProportionalRecovery() public {
        uint256 claim1 = 50e18;
        uint256 claim2 = 50e18;
        uint256 totalClaims = 100e18;

        vm.startPrank(settlementEngine);
        waterfall.setTotalClaims(totalClaims);

        // Loss of 510e18 exceeds all tranche buffers (500e18 total),
        // leaving 10e18 as token holder haircut → 90% recovery
        waterfall.executeWaterfall(510e18);
        vm.stopPrank();

        uint256 recovery1 = waterfall.calculateRecovery(claim1);
        uint256 recovery2 = waterfall.calculateRecovery(claim2);

        // Both should be 45e18 (proportional)
        assertApproxEqAbs(recovery1, 45e18, 1);
        assertApproxEqAbs(recovery2, 45e18, 1);
    }
    
    function test_GetTotalAvailableFunds() public {
        uint256 total = waterfall.getTotalAvailableFunds();
        assertEq(total, 500e18); // 100 + 200 + 150 + 50
    }
    
    function test_CannotExecuteTwice() public {
        vm.startPrank(settlementEngine);
        waterfall.executeWaterfall(10e18);
        
        vm.expectRevert("WaterfallDistributor: already executed");
        waterfall.executeWaterfall(10e18);
        vm.stopPrank();
    }
}
