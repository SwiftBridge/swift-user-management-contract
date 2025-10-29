const hre = require("hardhat");
const fs = require('fs');

async function main() {
  console.log("🚀 Deploying UserManagement Contract to Base Sepolia...\n");

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("📝 Deploying with account:", deployer.address);

  // Check balance
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", hre.ethers.formatEther(balance), "ETH\n");

  // Deploy UserManagement contract
  const UserManagement = await hre.ethers.getContractFactory("UserManagement");

  console.log("⏳ Deploying UserManagement contract...");
  const userManagement = await UserManagement.deploy();

  await userManagement.waitForDeployment();
  const contractAddress = await userManagement.getAddress();
  console.log("✅ UserManagement deployed to:", contractAddress);

  // Wait for block confirmations
  console.log("⏳ Waiting for 5 block confirmations...");
  const deployTx = userManagement.deploymentTransaction();
  await deployTx.wait(5);
  console.log("✅ Confirmed!\n");

  // Get deployment info
  const receipt = await deployTx.wait();

  // Save deployment info
  const deploymentInfo = {
    network: "base-sepolia",
    contractName: "UserManagement",
    contractAddress: contractAddress,
    deployer: deployer.address,
    chainId: 84532,
    timestamp: new Date().toISOString(),
    blockNumber: receipt.blockNumber,
    transactionHash: receipt.hash,
    gasUsed: receipt.gasUsed.toString(),
    gasPrice: receipt.gasPrice.toString()
  };

  // Save to file
  fs.writeFileSync(
    'deployment.json',
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("📄 Deployment info saved to deployment.json\n");

  console.log("═══════════════════════════════════════");
  console.log("🎉 DEPLOYMENT SUCCESSFUL!");
  console.log("═══════════════════════════════════════");
  console.log("Contract:", contractAddress);
  console.log("Gas Used:", receipt.gasUsed.toString());
  console.log("═══════════════════════════════════════\n");

  return userManagement;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });
