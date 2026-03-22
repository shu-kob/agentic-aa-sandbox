/**
 * 02_record_reputation.ts
 * ReputationRegistry に Agent ID の成功タスクを記録する
 * ※ 01_register_agent.ts を先に実行してください
 */
import { ethers } from "hardhat";
import { ReputationRegistry } from "../../typechain-types";
import deployment from "../../deployments/sepolia.json";

// 01 で発行された Agent ID を指定
const AGENT_ID = 0n;
const SCORE_INCREMENT = 10n;

async function main() {
  const [owner] = await ethers.getSigners();
  console.log("Owner:", owner.address);

  const reputation = (await ethers.getContractAt(
    "ReputationRegistry",
    deployment.contracts.ReputationRegistry
  )) as unknown as ReputationRegistry;

  // 記録前の評判を確認
  const [beforeTasks, beforeScore] = await reputation.getReputation(AGENT_ID);
  console.log(`\n[Before] Agent ${AGENT_ID} — successTasks: ${beforeTasks}, score: ${beforeScore}`);

  console.log(`\nRecording success for Agent ID ${AGENT_ID} (score +${SCORE_INCREMENT})...`);
  const tx = await reputation.recordSuccess(AGENT_ID, SCORE_INCREMENT);
  console.log("Tx hash:", tx.hash);
  await tx.wait();

  // 記録後の評判を確認
  const [afterTasks, afterScore] = await reputation.getReputation(AGENT_ID);
  console.log(`\n[After]  Agent ${AGENT_ID} — successTasks: ${afterTasks}, score: ${afterScore}`);
  console.log(`Etherscan: https://sepolia.etherscan.io/tx/${tx.hash}`);
}

main().catch((err) => { console.error(err); process.exitCode = 1; });
