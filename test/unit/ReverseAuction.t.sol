// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ReverseAuction} from "../../contracts/rwa/liquidation/ReverseAuction.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ─── Mock contracts ───────────────────────────────────────────────

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract MockAMMPool {
    address public token0;
    address public token1;
    uint256 public reserve0;
    uint256 public reserve1;
    bool public liquidityLocked;
    uint256 public swapRate; // amountOut per amountIn in basis points (10000 = 1:1)

    constructor(address _token0, address _token1, uint256 _reserve0, uint256 _reserve1) {
        token0 = _token0;
        token1 = _token1;
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        swapRate = 5000; // default: 0.5 targetToken per settlementToken
    }

    function setSwapRate(uint256 _rate) external {
        swapRate = _rate;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function totalSupply() external pure returns (uint256) {
        return 1000e18;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }

    function lockLiquidity() external {
        liquidityLocked = true;
    }

    function unlockLiquidity() external {
        liquidityLocked = false;
    }

    function swap(address tokenIn, uint256 amountIn, uint256) external returns (uint256 amountOut) {
        amountOut = (amountIn * swapRate) / 10000;

        // Transfer tokenIn from caller
        require(ERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "transferFrom failed");

        // Determine tokenOut
        address tokenOut = tokenIn == token0 ? token1 : token0;

        // Transfer tokenOut to caller
        require(ERC20(tokenOut).transfer(msg.sender, amountOut), "transfer failed");

        return amountOut;
    }
}

contract MockMintBurnController {
    uint256 public totalBurned;
    address public lastBurnFrom;
    uint256 public lastBurnAmount;
    MockToken public targetToken;

    constructor(address _targetToken) {
        targetToken = MockToken(_targetToken);
    }

    function burn(address from, uint256 amount) external {
        lastBurnFrom = from;
        lastBurnAmount = amount;
        totalBurned += amount;
        targetToken.burn(from, amount);
    }
}

// ─── Tests ────────────────────────────────────────────────────────

contract ReverseAuctionTest is Test {
    ReverseAuction public auction;
    MockToken public settlementToken;
    MockToken public targetToken;
    MockAMMPool public ammPool;
    MockMintBurnController public burnController;

    address public governance = address(0x1);
    address public operator = address(0x2);
    address public buyer = address(0x3);

    uint256 public constant COMMITTED = 100e18;
    uint256 public constant LOCKUP = 2 days;

    function setUp() public {
        vm.warp(30 days); // past cooldown

        settlementToken = new MockToken("USDC", "USDC");
        targetToken = new MockToken("RWA", "RWA");
        burnController = new MockMintBurnController(address(targetToken));

        ammPool = new MockAMMPool(
            address(settlementToken),
            address(targetToken),
            10000e18,
            5000e18
        );

        auction = new ReverseAuction(governance, address(burnController));

        vm.prank(governance);
        auction.grantRole(keccak256("OPERATOR_ROLE"), operator);

        // Fund buyer with settlement tokens
        settlementToken.mint(buyer, 1000e18);

        // Fund AMM pool with target tokens for swap output
        targetToken.mint(address(ammPool), 10000e18);
    }

    function _createAuction() internal returns (uint256) {
        uint256 executionTime = block.timestamp + 1 days;
        vm.prank(operator);
        return auction.createReverseAuction(
            buyer,
            address(settlementToken),
            COMMITTED,
            executionTime,
            LOCKUP,
            address(targetToken),
            address(ammPool)
        );
    }

    function _commitCapital(uint256 auctionId) internal {
        vm.startPrank(buyer);
        settlementToken.approve(address(auction), COMMITTED);
        auction.commitCapital(auctionId);
        vm.stopPrank();
    }

    function test_CreateReverseAuction() public {
        uint256 auctionId = _createAuction();

        assertEq(auctionId, 1);

        ReverseAuction.ReverseAuctionData memory data = auction.getReverseAuction(auctionId);
        assertEq(data.buyer, buyer);
        assertEq(data.ammPool, address(ammPool));
        assertEq(data.committedAmount, COMMITTED);
        assertEq(data.lockupPeriod, LOCKUP);
        assertEq(uint256(data.status), uint256(ReverseAuction.ReverseAuctionStatus.PENDING));
    }

    function test_CommitCapitalLocksLiquidity() public {
        uint256 auctionId = _createAuction();

        assertFalse(ammPool.liquidityLocked());

        _commitCapital(auctionId);

        assertTrue(ammPool.liquidityLocked());

        ReverseAuction.ReverseAuctionData memory data = auction.getReverseAuction(auctionId);
        assertEq(uint256(data.status), uint256(ReverseAuction.ReverseAuctionStatus.LOCKED));
        assertEq(settlementToken.balanceOf(address(auction)), COMMITTED);
    }

    function test_ExecuteSwapsAndBurns() public {
        uint256 auctionId = _createAuction();
        _commitCapital(auctionId);

        // Warp to execution time
        vm.warp(block.timestamp + 1 days);

        uint256 buyerTargetBefore = targetToken.balanceOf(buyer);

        vm.prank(operator);
        auction.execute(auctionId);

        // Buyer should NOT receive tokens (they're burned)
        assertEq(targetToken.balanceOf(buyer), buyerTargetBefore);

        // Burn controller should have been called
        assertEq(burnController.lastBurnAmount(), 50e18); // 100 * 5000/10000
        assertEq(burnController.totalBurned(), 50e18);

        // AMM liquidity unlocked
        assertFalse(ammPool.liquidityLocked());
    }

    function test_ExecuteRecordsAcquiredAmount() public {
        uint256 auctionId = _createAuction();
        _commitCapital(auctionId);

        vm.warp(block.timestamp + 1 days);

        vm.prank(operator);
        auction.execute(auctionId);

        ReverseAuction.ReverseAuctionData memory data = auction.getReverseAuction(auctionId);
        assertEq(data.acquiredAmount, 50e18); // 100 * 0.5 swap rate
        assertEq(uint256(data.status), uint256(ReverseAuction.ReverseAuctionStatus.EXECUTED));
    }

    function test_CancelUnlocksLiquidity() public {
        uint256 auctionId = _createAuction();
        _commitCapital(auctionId);

        assertTrue(ammPool.liquidityLocked());
        uint256 buyerBalBefore = settlementToken.balanceOf(buyer);

        vm.prank(governance);
        auction.cancel(auctionId, "Market conditions changed");

        assertFalse(ammPool.liquidityLocked());
        assertEq(settlementToken.balanceOf(buyer) - buyerBalBefore, COMMITTED);

        ReverseAuction.ReverseAuctionData memory data = auction.getReverseAuction(auctionId);
        assertEq(uint256(data.status), uint256(ReverseAuction.ReverseAuctionStatus.CANCELLED));
    }

    function test_ExpireAuction() public {
        uint256 auctionId = _createAuction();
        _commitCapital(auctionId);

        // Warp past execution window
        vm.warp(block.timestamp + 1 days + LOCKUP + 1);

        uint256 buyerBalBefore = settlementToken.balanceOf(buyer);

        auction.expireAuction(auctionId);

        assertFalse(ammPool.liquidityLocked());
        assertEq(settlementToken.balanceOf(buyer) - buyerBalBefore, COMMITTED);

        ReverseAuction.ReverseAuctionData memory data = auction.getReverseAuction(auctionId);
        assertEq(uint256(data.status), uint256(ReverseAuction.ReverseAuctionStatus.CANCELLED));
    }

    function test_CannotExecuteAfterWindow() public {
        uint256 auctionId = _createAuction();
        _commitCapital(auctionId);

        // Warp past window
        vm.warp(block.timestamp + 1 days + LOCKUP + 1);

        vm.prank(operator);
        vm.expectRevert("ReverseAuction: window expired");
        auction.execute(auctionId);
    }

    function test_CannotCommitTwice() public {
        uint256 auctionId = _createAuction();
        _commitCapital(auctionId);

        settlementToken.mint(buyer, 100e18);

        vm.startPrank(buyer);
        settlementToken.approve(address(auction), 100e18);
        vm.expectRevert("ReverseAuction: not pending");
        auction.commitCapital(auctionId);
        vm.stopPrank();
    }

    function test_CooldownEnforced() public {
        _createAuction(); // first auction succeeds

        // Try to create another immediately — 28-day cooldown
        vm.prank(operator);
        vm.expectRevert("ReverseAuction: cooldown not elapsed");
        auction.createReverseAuction(
            buyer,
            address(settlementToken),
            COMMITTED,
            block.timestamp + 1 days,
            LOCKUP,
            address(targetToken),
            address(ammPool)
        );
    }

    function test_MaxLockupDuration() public {
        // maxLockupDuration is 3 days, try 4 days
        vm.prank(operator);
        vm.expectRevert("ReverseAuction: lockup too long");
        auction.createReverseAuction(
            buyer,
            address(settlementToken),
            COMMITTED,
            block.timestamp + 1 days,
            4 days,
            address(targetToken),
            address(ammPool)
        );
    }
}
