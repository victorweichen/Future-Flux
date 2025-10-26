const hre = require("hardhat");

async function main() {
  console.log("Deploying Future Flux DEX contracts...");

  // Deploy DEX
  const FutureFluxDEX = await hre.ethers.getContractFactory("FutureFluxDEX");
  const dex = await FutureFluxDEX.deploy();
  await dex.waitForDeployment();
  const dexAddress = await dex.getAddress();
  console.log(`FutureFluxDEX deployed to: ${dexAddress}`);

  // Deploy sample RWA tokens
  const RWAToken = await hre.ethers.getContractFactory("RWAToken");
  
  const realEstateToken = await RWAToken.deploy(
    "Real Estate Token",
    "RET",
    "Real Estate",
    hre.ethers.parseEther("1000000")
  );
  await realEstateToken.waitForDeployment();
  const retAddress = await realEstateToken.getAddress();
  console.log(`Real Estate Token deployed to: ${retAddress}`);

  const commodityToken = await RWAToken.deploy(
    "Commodity Token",
    "CMT",
    "Commodities",
    hre.ethers.parseEther("1000000")
  );
  await commodityToken.waitForDeployment();
  const cmtAddress = await commodityToken.getAddress();
  console.log(`Commodity Token deployed to: ${cmtAddress}`);

  // Create trading pair
  const tx = await dex.createPair(retAddress, cmtAddress);
  await tx.wait();
  console.log("Trading pair created between RET and CMT");

  console.log("\n=== Deployment Summary ===");
  console.log(`DEX: ${dexAddress}`);
  console.log(`Real Estate Token (RET): ${retAddress}`);
  console.log(`Commodity Token (CMT): ${cmtAddress}`);
  console.log("========================\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
