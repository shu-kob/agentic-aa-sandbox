/**
 * EIP-712 signing utilities for TIS and PDR.
 *
 * - signTIS: Agent signs a Transaction Intent Schema
 * - signPDR: Policy engine signs a Policy Decision Record
 * - verifyTIS / verifyPDR: Recover signer from signature
 */

import { ethers, Wallet } from "ethers";
import { EIP712Domain, TIS, PDR, TIS_TYPE, PDR_TYPE } from "./types";

/**
 * Agent signs a TIS with EIP-712 typed data.
 */
export async function signTIS(
  agentWallet: Wallet,
  tis: TIS,
  domain: EIP712Domain
): Promise<string> {
  const signature = await agentWallet.signTypedData(
    domain,
    TIS_TYPE,
    {
      intentId: tis.intentId,
      action: tis.action,
      token: tis.token,
      amount: tis.amount,
      deadline: tis.deadline,
    }
  );
  return signature;
}

/**
 * Compute the keccak256 hash of a TIS (used as input to PDR).
 */
export function hashTIS(tis: TIS, domain: EIP712Domain): string {
  return ethers.TypedDataEncoder.hash(domain, TIS_TYPE, {
    intentId: tis.intentId,
    action: tis.action,
    token: tis.token,
    amount: tis.amount,
    deadline: tis.deadline,
  });
}

/**
 * Policy engine signs an APPROVE/REJECT PDR with EIP-712.
 */
export async function signPDR(
  policyWallet: Wallet,
  tisHash: string,
  domain: EIP712Domain,
  decision: "APPROVE" | "REJECT" = "APPROVE"
): Promise<PDR> {
  const pdrData = { tisHash, decision };
  const signature = await policyWallet.signTypedData(
    domain,
    PDR_TYPE,
    pdrData
  );
  return { tisHash, decision, signature };
}

/**
 * Recover the signer address from a TIS signature.
 */
export function verifyTIS(
  tis: TIS,
  signature: string,
  domain: EIP712Domain
): string {
  return ethers.verifyTypedData(
    domain,
    TIS_TYPE,
    {
      intentId: tis.intentId,
      action: tis.action,
      token: tis.token,
      amount: tis.amount,
      deadline: tis.deadline,
    },
    signature
  );
}

/**
 * Recover the signer address from a PDR signature.
 */
export function verifyPDR(
  pdr: PDR,
  domain: EIP712Domain
): string {
  return ethers.verifyTypedData(
    domain,
    PDR_TYPE,
    { tisHash: pdr.tisHash, decision: pdr.decision },
    pdr.signature
  );
}
