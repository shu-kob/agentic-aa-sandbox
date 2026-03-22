import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  // 1. Deploy IdentityRegistry
  const IdentityRegistry = await ethers.getContractFactory("IdentityRegistry");
  const identityRegistry = await IdentityRegistry.deploy();
  await identityRegistry.waitForDeployment();
  const identityAddress = await identityRegistry.getAddress();
  console.log("IdentityRegistry deployed:", identityAddress);

  // 2. Deploy ReputationRegistry
  const ReputationRegistry = await ethers.getContractFactory("ReputationRegistry");
  const reputationRegistry = await ReputationRegistry.deploy(identityAddress);
  await reputationRegistry.waitForDeployment();
  const reputationAddress = await reputationRegistry.getAddress();
  console.log("ReputationRegistry deployed:", reputationAddress);

  // 3. Deploy AgentSmartAccount
  const AgentSmartAccount = await ethers.getContractFactory("AgentSmartAccount");
  const agentSmartAccount = await AgentSmartAccount.deploy({ value: ethers.parseEther("0.001") });
  await agentSmartAccount.waitForDeployment();
  const accountAddress = await agentSmartAccount.getAddress();
  console.log("AgentSmartAccount deployed:", accountAddress);

  console.log("\n=== Deployment Summary ===");
  console.log(`IdentityRegistry:   ${identityAddress}`);
  console.log(`ReputationRegistry: ${reputationAddress}`);
  console.log(`AgentSmartAccount:  ${accountAddress}`);
  console.log(`\nSepolia Etherscan: https://sepolia.etherscan.io/address/${accountAddress}`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
