// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../contracts/rwa/settlement/SettlementStateMachine.sol";

contract SettlementStateMachineTest is Test {
    SettlementStateMachine public stateMachine;
    
    address public governance = address(0x1);
    address public settlementEngine = address(0x2);
    
    function setUp() public {
        stateMachine = new SettlementStateMachine(governance);
        
        vm.prank(governance);
        stateMachine.grantRole(keccak256("SETTLEMENT_ENGINE_ROLE"), settlementEngine);
    }
    
    function test_InitialState() public {
        assertEq(stateMachine.getCurrentState(), 0); // NORMAL
    }
    
    function test_NormalToWarning() public {
        vm.prank(settlementEngine);
        stateMachine.transitionTo(
            SettlementStateMachine.State.WARNING,
            "Oracle anomaly detected"
        );
        
        assertEq(stateMachine.getCurrentState(), 1); // WARNING
    }
    
    function test_WarningToProtect() public {
        // First transition to WARNING
        vm.startPrank(settlementEngine);
        stateMachine.transitionTo(
            SettlementStateMachine.State.WARNING,
            "Oracle anomaly"
        );
        
        // Then to PROTECT
        stateMachine.transitionTo(
            SettlementStateMachine.State.PROTECT,
            "Threshold exceeded"
        );
        vm.stopPrank();
        
        assertEq(stateMachine.getCurrentState(), 2); // PROTECT
    }
    
    function test_InvalidTransition() public {
        // Try to go from NORMAL directly to DEFAULT (invalid)
        vm.prank(settlementEngine);
        vm.expectRevert("StateMachine: invalid transition");
        stateMachine.transitionTo(
            SettlementStateMachine.State.DEFAULT,
            "Invalid"
        );
    }
    
    function test_TradingAllowedInNormal() public {
        assertTrue(stateMachine.isTradingAllowed());
    }
    
    function test_TradingAllowedInWarning() public {
        vm.prank(settlementEngine);
        stateMachine.transitionTo(
            SettlementStateMachine.State.WARNING,
            "Test"
        );
        
        assertTrue(stateMachine.isTradingAllowed());
    }
    
    function test_TradingDisabledInProtect() public {
        // Transition to PROTECT via WARNING
        vm.startPrank(settlementEngine);
        stateMachine.transitionTo(SettlementStateMachine.State.WARNING, "Test");
        stateMachine.transitionTo(SettlementStateMachine.State.PROTECT, "Test");
        vm.stopPrank();
        
        assertFalse(stateMachine.isTradingAllowed());
    }
    
    function test_ShouldLiquidateInProtect() public {
        vm.startPrank(settlementEngine);
        stateMachine.transitionTo(SettlementStateMachine.State.WARNING, "Test");
        stateMachine.transitionTo(SettlementStateMachine.State.PROTECT, "Test");
        vm.stopPrank();
        
        assertTrue(stateMachine.shouldLiquidate());
    }
    
    function test_EmergencyHalt() public {
        vm.prank(governance);
        stateMachine.emergencyHalt("Emergency");
        
        assertEq(stateMachine.getCurrentState(), 5); // HALT
    }
    
    function test_TimeInCurrentState() public {
        uint256 startTime = block.timestamp;
        
        vm.warp(startTime + 1 hours);
        
        uint256 timeInState = stateMachine.getTimeInCurrentState();
        assertEq(timeInState, 1 hours);
    }
}
