/**
 * Test script: Verify TIS/PDR signing and recovery with dummy wallets.
 *
 * Run: npx hardhat run scripts/test-signatures.ts
 */

import { ethers } from "ethers";
import { EIP712Domain, TIS } from "./types";
import { signTIS, hashTIS, signPDR, verifyTIS, verifyPDR } from "./signer";

async function main() {
  // --- Setup: dummy wallets ---
  const agentWallet = ethers.Wallet.createRandom();
  const policyWallet = ethers.Wallet.createRandom();

  console.log("Agent  address:", agentWallet.address);
  console.log("Policy address:", policyWallet.address);

  // --- EIP-712 domain ---
  const domain: EIP712Domain = {
    name: "AgentMarketplace",
    version: "1",
    chainId: 11155111, // Sepolia
    verifyingContract: "0xE6106b4c0899c0fE015f5d780fF5dd97F7ffE529",
  };

  // --- 1. Agent signs a TIS ---
  const tis: TIS = {
    intentId: "intent-001",
    action: "TRANSFER",
    token: ethers.ZeroAddress, // native ETH
    amount: ethers.parseEther("0.0001"),
    deadline: Math.floor(Date.now() / 1000) + 3600,
  };

  console.log("\n--- TIS Signing ---");
  const tisSig = await signTIS(agentWallet, tis, domain);
  console.log("TIS Signature:", tisSig.slice(0, 42) + "...");

  const recoveredAgent = verifyTIS(tis, tisSig, domain);
  console.log("Recovered signer:", recoveredAgent);
  console.log("Match:", recoveredAgent === agentWallet.address ? "✓" : "✗");

  // --- 2. Policy engine approves with PDR ---
  console.log("\n--- PDR Signing ---");
  const tisHash = hashTIS(tis, domain);
  console.log("TIS Hash:", tisHash);

  const pdr = await signPDR(policyWallet, tisHash, domain, "APPROVE");
  console.log("PDR Decision:", pdr.decision);
  console.log("PDR Signature:", pdr.signature.slice(0, 42) + "...");

  const recoveredPolicy = verifyPDR(pdr, domain);
  console.log("Recovered signer:", recoveredPolicy);
  console.log("Match:", recoveredPolicy === policyWallet.address ? "✓" : "✗");

  // --- 3. Rejection test ---
  console.log("\n--- Rejection Test ---");
  const rejectPdr = await signPDR(policyWallet, tisHash, domain, "REJECT");
  console.log("PDR Decision:", rejectPdr.decision);
  const recoveredReject = verifyPDR(rejectPdr, domain);
  console.log("Match:", recoveredReject === policyWallet.address ? "✓" : "✗");

  console.log("\n✓ All signature tests passed.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
