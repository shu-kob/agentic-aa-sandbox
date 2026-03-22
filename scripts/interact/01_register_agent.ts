/**
 * 01_register_agent.ts
 * IdentityRegistry にエージェントを登録し、NFT (Agent ID) をミントする
 */
import { ethers } from "hardhat";
import { IdentityRegistry } from "../../typechain-types";
import deployment from "../../deployments/sepolia.json";

async function main() {
  const [owner] = await ethers.getSigners();
  console.log("Owner:", owner.address);

  const registry = (await ethers.getContractAt(
    "IdentityRegistry",
    deployment.contracts.IdentityRegistry
  )) as unknown as IdentityRegistry;

  // 登録するエージェントアドレス（ここでは owner 自身を登録）
  const agentAddress = owner.address;

  console.log(`\nRegistering agent: ${agentAddress}`);
  const tx = await registry.registerAgent(agentAddress);
  console.log("Tx hash:", tx.hash);

  const receipt = await tx.wait();

  // AgentRegistered イベントから tokenId を取得
  const event = receipt?.logs
    .map((log) => {
      try { return registry.interface.parseLog(log as unknown as { topics: string[]; data: string }); }
      catch { return null; }
    })
    .find((e) => e?.name === "AgentRegistered");

  const tokenId = event?.args.tokenId;
  console.log(`\nAgent ID (tokenId): ${tokenId}`);
  console.log(`Owner of token ${tokenId}:`, await registry.ownerOf(tokenId));
  console.log(`Etherscan: https://sepolia.etherscan.io/tx/${tx.hash}`);
}

main().catch((err) => { console.error(err); process.exitCode = 1; });
