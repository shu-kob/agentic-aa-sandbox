# Phase 1: スマートコントラクトの実装 (EIP-8004 & Delegation)

## 概要
AIエージェントがオンチェーンで信頼を構築し、安全に権限を委譲されるためのスマートコントラクトを実装してください。フレームワークは Hardhat (TypeScript) を使用します。

## 1. 開発環境のセットアップ
- 必要なパッケージ: `hardhat`, `@nomicfoundation/hardhat-toolbox`, `ethers` (v6), `@openzeppelin/contracts`
- `contracts/` ディレクトリに以下のSolidityファイルを作成してください。

## 2. 実装要件

### A. EIP-8004 Registry (Trustless Agents)
ファイル名: `contracts/AgentRegistry.sol`
エージェントの身元と評判を管理するシンプルなレジストリを実装してください。
- `IdentityRegistry`: ERC721ベースでエージェントにNFT（Agent ID）をミントする機能。
- `ReputationRegistry`: 特定のAgent IDに対して、成功タスク数やスコアを記録・更新できる機能。

### B. Delegation & Policy Module (EIP-7702 / ERC-4337 インスパイア)
ファイル名: `contracts/AgentSmartAccount.sol`
ユーザーの資産を管理し、エージェントに一時的な権限を委譲するスマートアカウントのモックです。
- ユーザー（Owner）がエージェント（Delegate）に対して、上限額（Spend Limit）を設定して権限を付与できる機能。
- エージェントが署名付きの操作（UserOperationライクな構造体）を提出すると、上限額以内であればトランザクションを実行（資金の転送など）する機能。

## 3. 確認手順
`npx hardhat compile` がエラーなく通ることを確認してください。
