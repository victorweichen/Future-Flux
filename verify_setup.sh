#!/usr/bin/env bash

# FutureFlux - Setup Verification Script
# Checks that all project components are in place

echo "🔍 FutureFlux Project Verification"
echo "===================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize counters
total=0
passed=0

# Function to check file existence
check_file() {
    local file=$1
    local name=$2
    total=$((total + 1))
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅${NC} $name"
        passed=$((passed + 1))
    else
        echo -e "${RED}❌${NC} $name - NOT FOUND: $file"
    fi
}

# Function to check directory existence
check_dir() {
    local dir=$1
    local name=$2
    total=$((total + 1))
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅${NC} $name"
        passed=$((passed + 1))
    else
        echo -e "${RED}❌${NC} $name - NOT FOUND: $dir"
    fi
}

echo "📂 Checking Directories..."
check_dir "contracts/rwa/escrow" "RWA Escrow Contracts"
check_dir "contracts/rwa/settlement" "Settlement Contracts"
check_dir "contracts/rwa/tokens" "Token Contracts"
check_dir "contracts/rwa/oracles" "Oracle Contracts"
check_dir "contracts/rwa/liquidation" "Liquidation Contracts"
check_dir "contracts/rwa/guards" "Guard Contracts"
check_dir "contracts/compliance" "Compliance Contracts"
check_dir "contracts/interfaces" "Interface Contracts"
check_dir "test/unit" "Unit Tests"
check_dir "test/integration" "Integration Tests"
check_dir "test/failure-scenarios" "Failure Scenario Tests"
check_dir "scripts/deploy" "Deployment Scripts"
check_dir "docs" "Whitepapers"
check_dir "docs-dev" "Developer Docs"

echo ""
echo "🔧 Checking Configuration Files..."
check_file "package.json" "NPM Configuration"
check_file "foundry.toml" "Foundry Configuration"
check_file "hardhat.config.ts" "Hardhat Configuration"
check_file "tsconfig.json" "TypeScript Configuration"
check_file ".env.example" "Environment Template"
check_file ".gitignore" "Git Ignore"

echo ""
echo "📄 Checking Documentation Files..."
check_file "README.md" "Project README"
check_file "ARCHITECTURE.md" "Technical Architecture"
check_file "BUILD_SETUP_COMPLETE.md" "Build Setup Status"
check_file "PROJECT_COMPLETION.md" "Project Completion Report"
check_file "docs-dev/DEVELOPER_GUIDE.md" "Developer Guide"
check_file "docs-dev/SETTLEMENT_FLOW.md" "Settlement Flow"

echo ""
echo "📝 Checking Smart Contracts..."
check_file "contracts/rwa/escrow/EscrowVault.sol" "EscrowVault"
check_file "contracts/rwa/settlement/SettlementStateMachine.sol" "SettlementStateMachine"
check_file "contracts/rwa/settlement/ConditionalSettlementEngine.sol" "ConditionalSettlementEngine"
check_file "contracts/rwa/settlement/WaterfallDistributor.sol" "WaterfallDistributor"
check_file "contracts/rwa/tokens/RWAToken.sol" "RWAToken"
check_file "contracts/rwa/tokens/MintBurnController.sol" "MintBurnController"
check_file "contracts/rwa/tokens/RestructuredToken.sol" "RestructuredToken"
check_file "contracts/rwa/oracles/OracleHealthModule.sol" "OracleHealthModule"
check_file "contracts/rwa/oracles/MultiOracleAggregator.sol" "MultiOracleAggregator"
check_file "contracts/rwa/liquidation/AuctionLiquidator.sol" "AuctionLiquidator"
check_file "contracts/rwa/liquidation/ReverseAuction.sol" "ReverseAuction"
check_file "contracts/rwa/liquidation/Flashsale.sol" "Flashsale"
check_file "contracts/rwa/guards/RouterGuard.sol" "RouterGuard"
check_file "contracts/rwa/guards/PositionThrottler.sol" "PositionThrottler"
check_file "contracts/compliance/TransferRestriction.sol" "TransferRestriction"

echo ""
echo "🧪 Checking Test Files..."
check_file "test/unit/EscrowVault.t.sol" "EscrowVault Tests"
check_file "test/unit/SettlementStateMachine.t.sol" "SettlementStateMachine Tests"
check_file "test/unit/WaterfallDistributor.t.sol" "WaterfallDistributor Tests"
check_file "test/unit/AuctionLiquidator.t.sol" "AuctionLiquidator Tests"
check_file "test/integration/RouterGuardIntegration.t.sol" "RouterGuard Integration Tests"
check_file "test/failure-scenarios/IssuerDefault.t.sol" "Issuer Default Scenario Tests"

echo ""
echo "📚 Checking Interface Files..."
check_file "contracts/interfaces/IEscrowVault.sol" "IEscrowVault"
check_file "contracts/interfaces/ISettlementStateMachine.sol" "ISettlementStateMachine"
check_file "contracts/interfaces/IOracleHealthModule.sol" "IOracleHealthModule"
check_file "contracts/interfaces/IComplianceModule.sol" "IComplianceModule"
check_file "contracts/rwa/oracles/IOracleAdapter.sol" "IOracleAdapter"

echo ""
echo "🚀 Checking Deployment Scripts..."
check_file "scripts/deploy/01_deploy_core.s.sol" "Core Deployment Script"

echo ""
echo "📊 Summary"
echo "=========="
echo -e "Total Checks: $total"
echo -e "${GREEN}Passed: $passed${NC}"

if [ $passed -eq $total ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. npm install"
    echo "  2. forge install"
    echo "  3. forge build"
    echo "  4. forge test"
    exit 0
else
    failed=$((total - passed))
    echo -e "${RED}❌ $failed checks failed${NC}"
    exit 1
fi
