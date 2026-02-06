// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {EscrowVault} from "../../contracts/rwa/escrow/EscrowVault.sol";
import {RWAToken} from "../../contracts/rwa/tokens/RWAToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 for testing
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract EscrowVaultTest is Test {
    EscrowVault public vault;
    RWAToken public rwaToken;
    MockUSDC public usdc;
    
    address public governance = address(0x1);
    address public settlementEngine = address(0x2);
    address public depositor = address(0x3);
    address public recipient = address(0x4);
    
    function setUp() public {
        vm.startPrank(governance);
        
        usdc = new MockUSDC();
        rwaToken = new RWAToken(
            "RWA Token",
            "RWA",
            governance,
            "Test RWA Asset",
            "ipfs://test"
        );
        
        vault = new EscrowVault(address(rwaToken), settlementEngine, governance);
        vault.addSupportedAsset(address(usdc));
        
        vm.stopPrank();
        
        // Mint USDC to depositor
        usdc.mint(depositor, 1000e18);
    }
    
    function test_Deposit() public {
        vm.startPrank(depositor);
        usdc.approve(address(vault), 100e18);
        vault.deposit(address(usdc), 100e18);
        vm.stopPrank();
        
        assertEq(vault.getAssetBalance(address(usdc)), 100e18);
    }
    
    function test_Withdraw() public {
        // First deposit
        vm.startPrank(depositor);
        usdc.approve(address(vault), 100e18);
        vault.deposit(address(usdc), 100e18);
        vm.stopPrank();
        
        // Withdraw via settlement engine
        vm.startPrank(settlementEngine);
        vault.withdraw(address(usdc), 50e18, recipient);
        vm.stopPrank();
        
        assertEq(vault.getAssetBalance(address(usdc)), 50e18);
        assertEq(usdc.balanceOf(recipient), 50e18);
    }
    
    function test_LockVault() public {
        vm.startPrank(settlementEngine);
        vault.lock();
        vm.stopPrank();
        
        assertTrue(vault.isLocked());
        
        vm.startPrank(depositor);
        usdc.approve(address(vault), 100e18);
        vm.expectRevert("EscrowVault: vault is locked");
        vault.deposit(address(usdc), 100e18);
        vm.stopPrank();
    }
    
    function test_UnlockVault() public {
        vm.startPrank(settlementEngine);
        vault.lock();
        vault.unlock();
        vm.stopPrank();
        
        assertFalse(vault.isLocked());
        
        vm.startPrank(depositor);
        usdc.approve(address(vault), 100e18);
        vault.deposit(address(usdc), 100e18);
        vm.stopPrank();
        
        assertEq(vault.getAssetBalance(address(usdc)), 100e18);
    }
    
    function test_InvalidAssetDeposit() public {
        address invalidAsset = address(0x5);
        
        vm.startPrank(depositor);
        vm.expectRevert("EscrowVault: asset not supported");
        vault.deposit(invalidAsset, 100e18);
        vm.stopPrank();
    }
    
    function test_ZeroAmountDeposit() public {
        vm.startPrank(depositor);
        vm.expectRevert("EscrowVault: amount must be greater than 0");
        vault.deposit(address(usdc), 0);
        vm.stopPrank();
    }
}
