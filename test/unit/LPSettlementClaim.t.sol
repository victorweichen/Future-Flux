// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../contracts/rwa/settlement/LPSettlementClaim.sol";
import "../../contracts/rwa/settlement/WaterfallDistributor.sol";
import "../../contracts/interfaces/IAMMPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ─── Mock contracts ───────────────────────────────────────────────

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockSettlementStateMachine {
    uint8 public state;

    function setCurrentState(uint8 _state) external {
        state = _state;
    }

    function getCurrentState() external view returns (uint8) {
        return state;
    }

    function isTradingAllowed() external view returns (bool) {
        return state == 0 || state == 1;
    }

    function shouldLiquidate() external view returns (bool) {
        return state == 2 || state == 3;
    }

    function hasExceededWarningThreshold() external pure returns (bool) {
        return false;
    }

    function getTimeInCurrentState() external pure returns (uint256) {
        return 0;
    }
}

contract MockAMMPool is ERC20 {
    address public token0;
    address public token1;
    uint256 public reserve0;
    uint256 public reserve1;

    constructor(
        address _token0,
        address _token1,
        uint256 _reserve0,
        uint256 _reserve1
    ) ERC20("LP Token", "LP") {
        token0 = _token0;
        token1 = _token1;
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setReserves(uint256 _reserve0, uint256 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }
}

// ─── Tests ────────────────────────────────────────────────────────

contract LPSettlementClaimTest is Test {
    LPSettlementClaim public lpClaim;
    WaterfallDistributor public waterfall;
    MockSettlementStateMachine public stateMachine;
    MockToken public rwaToken;
    MockToken public usdc;
    MockAMMPool public ammPool;
    MockAMMPool public ammPool2;

    address public governance = address(0x1);
    address public operator = address(0x2);
    address public lpHolder1 = address(0x3);
    address public lpHolder2 = address(0x4);

    function setUp() public {
        vm.warp(2 days);

        // Deploy mocks
        stateMachine = new MockSettlementStateMachine();
        rwaToken = new MockToken("RWA Token", "RWA");
        usdc = new MockToken("USDC", "USDC");

        // Deploy waterfall with governance
        waterfall = new WaterfallDistributor(governance);

        // Deploy AMM pool: RWA/USDC with 1000 RWA and 50000 USDC
        ammPool = new MockAMMPool(
            address(rwaToken),
            address(usdc),
            1000e18, // reserve0 = RWA
            50000e18 // reserve1 = USDC
        );

        // Second pool for multi-pool tests
        ammPool2 = new MockAMMPool(
            address(usdc),
            address(rwaToken),
            30000e18, // reserve0 = USDC
            600e18    // reserve1 = RWA
        );

        // Deploy LPSettlementClaim
        lpClaim = new LPSettlementClaim(
            address(stateMachine),
            address(usdc),
            address(waterfall),
            governance
        );

        // Grant roles
        vm.startPrank(governance);
        lpClaim.grantRole(keccak256("OPERATOR_ROLE"), operator);
        waterfall.grantRole(keccak256("SETTLEMENT_ENGINE_ROLE"), governance);
        vm.stopPrank();

        // Mint LP tokens to holders
        ammPool.mint(lpHolder1, 100e18);  // 10% of supply if total = 1000
        ammPool.mint(lpHolder2, 200e18);
        ammPool2.mint(lpHolder1, 50e18);

        // Fund LP claim contract with settlement tokens
        usdc.mint(operator, 100000e18);
        vm.startPrank(operator);
        usdc.approve(address(lpClaim), 100000e18);
        lpClaim.fundSettlement(100000e18);
        vm.stopPrank();
    }

    function test_RegisterPool() public {
        vm.prank(governance);
        lpClaim.registerPool(address(ammPool), address(rwaToken));

        assertTrue(lpClaim.registeredPools(address(ammPool)));
        assertEq(lpClaim.poolRWAToken(address(ammPool)), address(rwaToken));
    }

    function test_RegisterClaim() public {
        // Setup: register pool, set PROTECT state
        vm.prank(governance);
        lpClaim.registerPool(address(ammPool), address(rwaToken));
        stateMachine.setCurrentState(2); // PROTECT

        // LP holder registers claim
        vm.startPrank(lpHolder1);
        ammPool.approve(address(lpClaim), 100e18);
        lpClaim.registerClaim(address(ammPool), 100e18);
        vm.stopPrank();

        // 100 LP out of 300 total supply * 1000 RWA reserve = 333.33 RWA
        uint256 expectedExposure = (100e18 * 1000e18) / ammPool.totalSupply();
        assertEq(lpClaim.totalUserClaims(lpHolder1), expectedExposure);
        assertEq(lpClaim.claims(address(ammPool), lpHolder1), expectedExposure);
    }

    function test_RWAExposureCalculation() public {
        vm.prank(governance);
        lpClaim.registerPool(address(ammPool), address(rwaToken));

        // Pool has 1000 RWA, total LP supply = 300 (100 + 200 from setUp)
        uint256 exposure = lpClaim.getRWAExposure(address(ammPool), 100e18);
        uint256 expectedExposure = (100e18 * 1000e18) / ammPool.totalSupply();
        assertEq(exposure, expectedExposure);

        // Test second pool where RWA is token1
        vm.prank(governance);
        lpClaim.registerPool(address(ammPool2), address(rwaToken));

        uint256 exposure2 = lpClaim.getRWAExposure(address(ammPool2), 50e18);
        uint256 expectedExposure2 = (50e18 * 600e18) / ammPool2.totalSupply();
        assertEq(exposure2, expectedExposure2);
    }

    function test_CannotRegisterInNormalState() public {
        vm.prank(governance);
        lpClaim.registerPool(address(ammPool), address(rwaToken));

        stateMachine.setCurrentState(0); // NORMAL

        vm.startPrank(lpHolder1);
        ammPool.approve(address(lpClaim), 100e18);
        vm.expectRevert("LPSettlementClaim: not in settlement state");
        lpClaim.registerClaim(address(ammPool), 100e18);
        vm.stopPrank();
    }

    function test_CannotRegisterUnregisteredPool() public {
        stateMachine.setCurrentState(2); // PROTECT

        vm.startPrank(lpHolder1);
        ammPool.approve(address(lpClaim), 100e18);
        vm.expectRevert("LPSettlementClaim: pool not registered");
        lpClaim.registerClaim(address(ammPool), 100e18);
        vm.stopPrank();
    }

    function test_ClaimSettlement() public {
        // Setup pool, PROTECT state, register claim
        vm.prank(governance);
        lpClaim.registerPool(address(ammPool), address(rwaToken));
        stateMachine.setCurrentState(2);

        vm.startPrank(lpHolder1);
        ammPool.approve(address(lpClaim), 100e18);
        lpClaim.registerClaim(address(ammPool), 100e18);
        vm.stopPrank();

        uint256 claimAmount = lpClaim.totalUserClaims(lpHolder1);

        // Execute waterfall with no loss (100% recovery)
        vm.startPrank(governance);
        waterfall.setTotalClaims(10000e18);
        waterfall.configureTranche(
            WaterfallDistributor.Tranche.PROTOCOL_RESERVES,
            governance,
            10000e18
        );
        waterfall.executeWaterfall(100e18); // small loss, fully absorbed
        vm.stopPrank();

        // Claim settlement — haircutRatio should be 10000 (100% recovery)
        uint256 balanceBefore = usdc.balanceOf(lpHolder1);

        vm.prank(lpHolder1);
        lpClaim.claimSettlement();

        uint256 balanceAfter = usdc.balanceOf(lpHolder1);
        uint256 expectedRecovery = waterfall.calculateRecovery(claimAmount);
        assertEq(balanceAfter - balanceBefore, expectedRecovery);
        assertTrue(lpClaim.hasClaimedSettlement(lpHolder1));
    }

    function test_CannotClaimTwice() public {
        vm.prank(governance);
        lpClaim.registerPool(address(ammPool), address(rwaToken));
        stateMachine.setCurrentState(2);

        vm.startPrank(lpHolder1);
        ammPool.approve(address(lpClaim), 100e18);
        lpClaim.registerClaim(address(ammPool), 100e18);
        vm.stopPrank();

        // Execute waterfall
        vm.startPrank(governance);
        waterfall.setTotalClaims(10000e18);
        waterfall.configureTranche(
            WaterfallDistributor.Tranche.PROTOCOL_RESERVES,
            governance,
            10000e18
        );
        waterfall.executeWaterfall(100e18);
        vm.stopPrank();

        vm.startPrank(lpHolder1);
        lpClaim.claimSettlement();

        vm.expectRevert("LPSettlementClaim: already claimed");
        lpClaim.claimSettlement();
        vm.stopPrank();
    }

    function test_MultiplePoolClaims() public {
        // Register both pools
        vm.startPrank(governance);
        lpClaim.registerPool(address(ammPool), address(rwaToken));
        lpClaim.registerPool(address(ammPool2), address(rwaToken));
        vm.stopPrank();

        stateMachine.setCurrentState(2); // PROTECT

        // LP holder1 registers claims in both pools
        vm.startPrank(lpHolder1);
        ammPool.approve(address(lpClaim), 100e18);
        lpClaim.registerClaim(address(ammPool), 100e18);

        ammPool2.approve(address(lpClaim), 50e18);
        lpClaim.registerClaim(address(ammPool2), 50e18);
        vm.stopPrank();

        uint256 exposure1 = (100e18 * 1000e18) / ammPool.totalSupply();
        uint256 exposure2 = (50e18 * 600e18) / ammPool2.totalSupply();
        assertEq(lpClaim.totalUserClaims(lpHolder1), exposure1 + exposure2);
    }

    function test_SettlementWithHaircut() public {
        vm.prank(governance);
        lpClaim.registerPool(address(ammPool), address(rwaToken));
        stateMachine.setCurrentState(2);

        vm.startPrank(lpHolder1);
        ammPool.approve(address(lpClaim), 100e18);
        lpClaim.registerClaim(address(ammPool), 100e18);
        vm.stopPrank();

        uint256 claimAmount = lpClaim.totalUserClaims(lpHolder1);

        // Execute waterfall: 600 loss, 100 absorbed by tranche, 500 as haircut on 1000 claims
        vm.startPrank(governance);
        waterfall.setTotalClaims(1000e18);
        waterfall.configureTranche(
            WaterfallDistributor.Tranche.PROTOCOL_RESERVES,
            governance,
            100e18
        );
        waterfall.executeWaterfall(600e18);
        vm.stopPrank();

        // Haircut ratio should be 5000 (50% recovery): (1000-500)/1000 * 10000
        assertEq(waterfall.haircutRatio(), 5000);

        uint256 balanceBefore = usdc.balanceOf(lpHolder1);

        vm.prank(lpHolder1);
        lpClaim.claimSettlement();

        uint256 balanceAfter = usdc.balanceOf(lpHolder1);
        uint256 expectedRecovery = (claimAmount * 5000) / 10000; // 50% of claim
        assertEq(balanceAfter - balanceBefore, expectedRecovery);
    }

    function test_CannotClaimBeforeWaterfall() public {
        vm.prank(governance);
        lpClaim.registerPool(address(ammPool), address(rwaToken));
        stateMachine.setCurrentState(2);

        vm.startPrank(lpHolder1);
        ammPool.approve(address(lpClaim), 100e18);
        lpClaim.registerClaim(address(ammPool), 100e18);
        vm.stopPrank();

        // Try to claim without waterfall execution
        vm.prank(lpHolder1);
        vm.expectRevert("LPSettlementClaim: waterfall not executed");
        lpClaim.claimSettlement();
    }
}
