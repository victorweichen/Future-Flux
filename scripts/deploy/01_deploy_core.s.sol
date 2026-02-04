// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../contracts/rwa/escrow/EscrowVault.sol";
import "../contracts/rwa/settlement/SettlementStateMachine.sol";
import "../contracts/rwa/settlement/ConditionalSettlementEngine.sol";
import "../contracts/rwa/settlement/WaterfallDistributor.sol";
import "../contracts/rwa/tokens/RWAToken.sol";
import "../contracts/rwa/tokens/MintBurnController.sol";
import "../contracts/rwa/oracles/OracleHealthModule.sol";
import "../contracts/rwa/guards/RouterGuard.sol";

/**
 * @title DeployCore
 * @notice Deploys core FutureFlux protocol contracts
 */
contract DeployCore is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address governance = vm.envAddress("GOVERNANCE_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy State Machine
        SettlementStateMachine stateMachine = new SettlementStateMachine(governance);
        console.log("SettlementStateMachine deployed at:", address(stateMachine));
        
        // 2. Deploy Waterfall Distributor
        WaterfallDistributor waterfall = new WaterfallDistributor(governance);
        console.log("WaterfallDistributor deployed at:", address(waterfall));
        
        // 3. Deploy RWA Token
        RWAToken rwaToken = new RWAToken(
            "RWA Token",
            "RWA",
            governance,
            "Real-World Asset Token",
            "ipfs://QmYourIPFSHash"
        );
        console.log("RWAToken deployed at:", address(rwaToken));
        
        // 4. Deploy Oracle Health Module
        OracleHealthModule oracleModule = new OracleHealthModule(governance, 2);
        console.log("OracleHealthModule deployed at:", address(oracleModule));
        
        // 5. Deploy Escrow Vault (requires settlement engine)
        // For now, use governance as settlement engine
        EscrowVault escrowVault = new EscrowVault(
            address(rwaToken),
            governance,
            governance
        );
        console.log("EscrowVault deployed at:", address(escrowVault));
        
        // 6. Deploy Router Guard
        RouterGuard routerGuard = new RouterGuard(
            address(stateMachine),
            address(oracleModule),
            governance
        );
        console.log("RouterGuard deployed at:", address(routerGuard));
        
        // 7. Deploy Mint Burn Controller
        MintBurnController mintBurnController = new MintBurnController(
            address(rwaToken),
            address(escrowVault),
            governance,
            10000 // 100% collateral ratio initially
        );
        console.log("MintBurnController deployed at:", address(mintBurnController));
        
        vm.stopBroadcast();
        
        // Log deployment addresses
        console.log("\n=== Deployment Complete ===");
        console.log("SettlementStateMachine:", address(stateMachine));
        console.log("WaterfallDistributor:", address(waterfall));
        console.log("RWAToken:", address(rwaToken));
        console.log("OracleHealthModule:", address(oracleModule));
        console.log("EscrowVault:", address(escrowVault));
        console.log("RouterGuard:", address(routerGuard));
        console.log("MintBurnController:", address(mintBurnController));
    }
}
