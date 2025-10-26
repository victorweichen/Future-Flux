const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FutureFluxDEX", function () {
  let dex, tokenA, tokenB;
  let owner, user1, user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy DEX
    const FutureFluxDEX = await ethers.getContractFactory("FutureFluxDEX");
    dex = await FutureFluxDEX.deploy();
    await dex.waitForDeployment();

    // Deploy test tokens
    const RWAToken = await ethers.getContractFactory("RWAToken");
    tokenA = await RWAToken.deploy("Token A", "TKA", "Real Estate", ethers.parseEther("1000000"));
    await tokenA.waitForDeployment();
    
    tokenB = await RWAToken.deploy("Token B", "TKB", "Commodities", ethers.parseEther("1000000"));
    await tokenB.waitForDeployment();

    // Mint tokens to users
    await tokenA.mint(user1.address, ethers.parseEther("10000"));
    await tokenB.mint(user1.address, ethers.parseEther("10000"));
  });

  describe("Pair Creation", function () {
    it("Should create a trading pair", async function () {
      const tx = await dex.createPair(await tokenA.getAddress(), await tokenB.getAddress());
      await expect(tx).to.emit(dex, "PairCreated");
      
      const pair = await dex.pairs(0);
      expect(pair.active).to.be.true;
    });

    it("Should not allow non-owner to create pair", async function () {
      await expect(
        dex.connect(user1).createPair(await tokenA.getAddress(), await tokenB.getAddress())
      ).to.be.reverted;
    });
  });

  describe("Liquidity Management", function () {
    beforeEach(async function () {
      await dex.createPair(await tokenA.getAddress(), await tokenB.getAddress());
      await tokenA.connect(user1).approve(await dex.getAddress(), ethers.parseEther("1000"));
      await tokenB.connect(user1).approve(await dex.getAddress(), ethers.parseEther("1000"));
    });

    it("Should add liquidity", async function () {
      const tx = await dex.connect(user1).addLiquidity(0, ethers.parseEther("100"), ethers.parseEther("100"));
      await expect(tx).to.emit(dex, "LiquidityAdded");
      
      const pair = await dex.pairs(0);
      expect(pair.reserveA).to.equal(ethers.parseEther("100"));
      expect(pair.reserveB).to.equal(ethers.parseEther("100"));
    });

    it("Should remove liquidity", async function () {
      await dex.connect(user1).addLiquidity(0, ethers.parseEther("100"), ethers.parseEther("100"));
      
      const lpInfo = await dex.liquidityProviders(0, user1.address);
      const liquidity = lpInfo.liquidity;
      
      const tx = await dex.connect(user1).removeLiquidity(0, liquidity);
      await expect(tx).to.emit(dex, "LiquidityRemoved");
    });
  });

  describe("Token Swaps", function () {
    beforeEach(async function () {
      await dex.createPair(await tokenA.getAddress(), await tokenB.getAddress());
      await tokenA.connect(user1).approve(await dex.getAddress(), ethers.parseEther("10000"));
      await tokenB.connect(user1).approve(await dex.getAddress(), ethers.parseEther("10000"));
      await dex.connect(user1).addLiquidity(0, ethers.parseEther("1000"), ethers.parseEther("1000"));
    });

    it("Should swap tokens", async function () {
      const amountIn = ethers.parseEther("10");
      const quote = await dex.getQuote(0, await tokenA.getAddress(), amountIn);
      
      const tx = await dex.connect(user1).swap(0, await tokenA.getAddress(), amountIn, quote);
      await expect(tx).to.emit(dex, "Swap");
    });

    it("Should get accurate quote", async function () {
      const quote = await dex.getQuote(0, await tokenA.getAddress(), ethers.parseEther("10"));
      expect(quote).to.be.gt(0);
    });
  });
});
