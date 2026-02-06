// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {SettlementStateMachine} from "../../contracts/rwa/settlement/SettlementStateMachine.sol";
import {RouterGuard} from "../../contracts/rwa/guards/RouterGuard.sol";
import {OracleHealthModule} from "../../contracts/rwa/oracles/OracleHealthModule.sol";

contract RouterGuardTest is Test {
    RouterGuard public guard;
    SettlementStateMachine public stateMachine;
    OracleHealthModule public oracleModule;
    
    address public governance = address(0x1);
    address public settlementEngine = address(0x2);
    address public rwaToken = address(0x3);
    address public trader = address(0x4);
    
    function setUp() public {
        stateMachine = new SettlementStateMachine(governance);
        oracleModule = new OracleHealthModule(governance, 0);
        
        guard = new RouterGuard(address(stateMachine), address(oracleModule), governance);
        
        vm.prank(governance);
        stateMachine.grantRole(keccak256("SETTLEMENT_ENGINE_ROLE"), settlementEngine);
    }
    
    function test_SwapAllowedInNormalState() public view {
        (bool allowed, ) = guard.checkSwap(rwaToken, trader, 100e18);
        assertTrue(allowed);
    }
    
    function test_SwapBlockedAfterTransitionToProtect() public {
        // Transition to WARNING
        vm.startPrank(settlementEngine);
        stateMachine.transitionTo(SettlementStateMachine.State.WARNING, "Test");
        
        // Transition to PROTECT
        stateMachine.transitionTo(SettlementStateMachine.State.PROTECT, "Test");
        vm.stopPrank();
        
        (bool allowed, ) = guard.checkSwap(rwaToken, trader, 100e18);
        assertFalse(allowed);
    }
    
    function test_ExemptAddressCanAlwaysSwap() public {
        vm.prank(governance);
        guard.setExemption(trader, true);
        
        // Transition to PROTECT
        vm.startPrank(settlementEngine);
        stateMachine.transitionTo(SettlementStateMachine.State.WARNING, "Test");
        stateMachine.transitionTo(SettlementStateMachine.State.PROTECT, "Test");
        vm.stopPrank();
        
        (bool allowed, ) = guard.checkSwap(rwaToken, trader, 100e18);
        assertTrue(allowed);
    }
    
    function test_ToggleGuards() public {
        vm.prank(governance);
        guard.toggleGuards(false);
        
        // Transition to PROTECT (would normally block)
        vm.startPrank(settlementEngine);
        stateMachine.transitionTo(SettlementStateMachine.State.WARNING, "Test");
        stateMachine.transitionTo(SettlementStateMachine.State.PROTECT, "Test");
        vm.stopPrank();
        
        (bool allowed, ) = guard.checkSwap(rwaToken, trader, 100e18);
        assertTrue(allowed); // Still allowed because guards are disabled
    }
}
