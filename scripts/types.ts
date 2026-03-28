/**
 * TIS (Transaction Intent Schema) & PDR (Policy Decision Record) type definitions.
 *
 * TIS: An agent's structured intent — what it wants to do.
 * PDR: A policy engine's decision — whether the intent is approved.
 *
 * Both are signed with EIP-712 typed data for on-chain verifiability.
 */

// EIP-712 domain separator
export interface EIP712Domain {
  name: string;
  version: string;
  chainId: number;
  verifyingContract: string;
}

// TIS: What the agent wants to do
export interface TIS {
  intentId: string;
  action: "SWAP" | "TRANSFER" | "STAKE";
  token: string;       // address (use ethers.ZeroAddress for native ETH)
  amount: bigint;       // in wei
  deadline: number;     // unix timestamp
}

// PDR: The policy engine's decision on a TIS
export interface PDR {
  tisHash: string;     // bytes32: keccak256 of the TIS
  decision: "APPROVE" | "REJECT";
  signature: string;   // bytes: EIP-712 signature
}

// EIP-712 type definitions for signing
export const TIS_TYPE = {
  TIS: [
    { name: "intentId", type: "string" },
    { name: "action", type: "string" },
    { name: "token", type: "address" },
    { name: "amount", type: "uint256" },
    { name: "deadline", type: "uint256" },
  ],
};

export const PDR_TYPE = {
  PDR: [
    { name: "tisHash", type: "bytes32" },
    { name: "decision", type: "string" },
  ],
};
