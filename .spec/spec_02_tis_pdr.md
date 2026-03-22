# Phase 2: TIS & PDR と EIP-712 署名のオフチェーン実装

## 概要
エージェントが生成するインテント（TIS）と、ポリシーエンジンが発行する承認証明（PDR）を TypeScript で定義し、EIP-712 を用いた署名ロジックを実装してください。

## 1. 型定義とスキーマ
ファイル名: `scripts/types.ts`
- **TIS (Transaction Intent Schema):** エージェントの目標を示す構造体。
  - `intentId` (string)
  - `action` (string: "SWAP", "TRANSFER" など)
  - `token` (address)
  - `amount` (uint256)
  - `deadline` (uint256)
- **PDR (Policy Decision Record):** ポリシーエンジンの審査結果。
  - `tisHash` (bytes32: TISのハッシュ)
  - `decision` (string: "APPROVE", "REJECT")
  - `signature` (bytes: EIP-712署名)

## 2. EIP-712 署名ユーティリティ
ファイル名: `scripts/signer.ts`
Ethers.js (v6) の `Signer.signTypedData` を使用して、以下の機能を実装してください。
- エージェントが TIS に署名する関数 `signTIS(agentWallet, tisObject, domain)`
- ポリシーエンジンが TIS を審査し、"APPROVE" の PDR に署名する関数 `signPDR(policyWallet, tisHash, domain)`

## 3. 確認手順
ダミーのWalletインスタンスを使って、TISとPDRの署名・検証が正しく行えるかを確認する短いスクリプト（`scripts/test-signatures.ts`）を作成し、実行してください。
