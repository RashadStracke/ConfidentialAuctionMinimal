import { ethers } from "hardhat";

async function main() {
  console.log("🚀 Deploying ConfidentialAuction contract...");

  // Get the contract factory (using minimal FHE version)
  const ConfidentialAuction = await ethers.getContractFactory("ConfidentialAuctionMinimal");

  // Deploy the contract
  console.log("📝 Deploying contract...");
  const confidentialAuction = await ConfidentialAuction.deploy();

  // Wait for deployment
  await confidentialAuction.waitForDeployment();

  const contractAddress = await confidentialAuction.getAddress();
  console.log("✅ ConfidentialAuction deployed to:", contractAddress);

  // Verify deployment
  console.log("🔍 Verifying deployment...");
  const deployedCode = await ethers.provider.getCode(contractAddress);
  if (deployedCode === "0x") {
    throw new Error("❌ Contract deployment failed - no code at address");
  }

  console.log("✅ Contract successfully deployed and verified!");

  // Display useful information
  console.log("\n📋 Deployment Summary:");
  console.log("=".repeat(50));
  console.log(`Contract Address: ${contractAddress}`);
  console.log(`Network: ${(await ethers.provider.getNetwork()).name}`);
  console.log(`Chain ID: ${(await ethers.provider.getNetwork()).chainId}`);

  // Get deployer info
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Deployer Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);

  // Test basic functionality
  console.log("\n🧪 Testing basic functionality...");
  try {
    const totalCounts = await confidentialAuction.getTotalCounts();
    console.log(`✅ Contract functional - Total auctions: ${totalCounts[0]}, Active: ${totalCounts[1]}`);
  } catch (error) {
    console.log("⚠️  Could not test contract functionality:", error);
  }

  console.log("\n🎯 Next steps:");
  console.log("1. Update frontend CONTRACT_ADDRESS to:", contractAddress);
  console.log("2. Fund deployer account with ETH for gas");
  console.log("3. Test creating auctions and placing bids");
  console.log("4. Verify contract on block explorer if needed");
}

// Handle deployment errors
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });