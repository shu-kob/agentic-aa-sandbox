/**
 * 03_delegate_and_execute.ts
 * AgentSmartAccount でデリゲートに権限を付与し、署名付き UserOperation を実行する
 *
 * accounts[0] = owner  : スマートアカウントのオーナー
 * accounts[1] = delegate: 権限を委譲されるエージェント（ニーモニックの index 1）
 */
import { ethers } from "hardhat";
import * as dotenv from "dotenv";
import { AgentSmartAccount } from "../../typechain-types";
import deployment from "../../deployments/sepolia.json";

dotenv.config();

// delegate が送金する先（ここでは owner に戻す）
const SEND_VALUE = ethers.parseEther("0.0001");
// delegate に許可する上限
const SPEND_LIMIT = ethers.parseEther("0.001");

async function main() {
  const [owner] = await ethers.getSigners();
  console.log("Owner:", owner.address);

  // ニーモニックから delegate ウォレットを導出（index 1）
  const mnemonic = process.env.MNEMONIC;
  if (!mnemonic) throw new Error("MNEMONIC not set in .env");
  const delegateWallet = ethers.HDNodeWallet.fromPhrase(
    mnemonic,
    undefined,
    "m/44'/60'/0'/0/1"
  ).connect(ethers.provider);
  console.log("Delegate:", delegateWallet.address);

  const account = (await ethers.getContractAt(
    "AgentSmartAccount",
    deployment.contracts.AgentSmartAccount
  )) as unknown as AgentSmartAccount;

  const accountBalance = await ethers.provider.getBalance(deployment.contracts.AgentSmartAccount);
  console.log(`\nAgentSmartAccount balance: ${ethers.formatEther(accountBalance)} ETH`);

  // ---- Step 0: Delegate のガス代が不足していれば owner から補充 ----
  const delegateBalance = await ethers.provider.getBalance(delegateWallet.address);
  console.log(`\nDelegate balance: ${ethers.formatEther(delegateBalance)} ETH`);
  const GAS_FUND = ethers.parseEther("0.005");
  if (delegateBalance < GAS_FUND) {
    console.log(`Funding delegate with ${ethers.formatEther(GAS_FUND)} ETH for gas...`);
    const fundTx = await owner.sendTransaction({ to: delegateWallet.address, value: GAS_FUND });
    console.log("Fund Tx:", fundTx.hash);
    await fundTx.wait();
    console.log("Funded.");
  }

  // ---- Step 1: Owner が Delegate に SpendLimit を付与 ----
  console.log(`\n[1] Granting delegation to ${delegateWallet.address} (limit: ${ethers.formatEther(SPEND_LIMIT)} ETH)...`);
  const grantTx = await account.connect(owner).grantDelegation(delegateWallet.address, SPEND_LIMIT);
  console.log("Tx:", grantTx.hash);
  await grantTx.wait();

  const remaining = await account.remainingAllowance(delegateWallet.address);
  console.log(`Remaining allowance: ${ethers.formatEther(remaining)} ETH`);

  // ---- Step 2: Delegate が UserOperation に署名して提出 ----
  const nonce = await account.nonces(delegateWallet.address);
  const data = "0x";

  // コントラクトの _operationHash と同じハッシュを JS 側で再現
  const innerHash = ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "address", "uint256", "bytes32", "uint256", "address"],
      [
        delegateWallet.address,
        owner.address,
        SEND_VALUE,
        ethers.keccak256(data),
        nonce,
        deployment.contracts.AgentSmartAccount,
      ]
    )
  );
  const opHash = ethers.keccak256(
    ethers.concat([ethers.toUtf8Bytes("\x19\x01"), ethers.getBytes(innerHash)])
  );

  // signingKey で raw 署名（Ethereum prefix なし）
  const rawSig = delegateWallet.signingKey.sign(opHash);
  const sig = ethers.Signature.from(rawSig).serialized;

  const op = {
    delegate: delegateWallet.address,
    to: owner.address,
    value: SEND_VALUE,
    data: data,
    nonce: nonce,
    signature: sig,
  };

  console.log(`\n[2] Executing UserOperation (send ${ethers.formatEther(SEND_VALUE)} ETH to ${owner.address})...`);
  const execTx = await account.connect(delegateWallet).executeOperation(op);
  console.log("Tx:", execTx.hash);
  const receipt = await execTx.wait();
  console.log("Status:", receipt?.status === 1 ? "Success ✓" : "Failed ✗");

  // ---- 結果確認 ----
  const remainingAfter = await account.remainingAllowance(delegateWallet.address);
  const balanceAfter = await ethers.provider.getBalance(deployment.contracts.AgentSmartAccount);
  console.log(`\n[Result]`);
  console.log(`AgentSmartAccount balance: ${ethers.formatEther(balanceAfter)} ETH`);
  console.log(`Remaining allowance:       ${ethers.formatEther(remainingAfter)} ETH`);
  console.log(`Etherscan: https://sepolia.etherscan.io/tx/${execTx.hash}`);
}

main().catch((err) => { console.error(err); process.exitCode = 1; });
