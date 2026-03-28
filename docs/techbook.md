# 2体のAIエージェントがマーケットプレイスで出会う
## 分散エージェント × ブロックチェーンで実現する「信頼なき信頼」

---

## はじめに: エージェントが「取引」する時代

2体のAIエージェントがマーケットプレイスで出会う。

一方はGPUコンピュートを買いたい**買い手エージェント**。もう一方はそれを提供する**売り手エージェント**。両者とも、背後にいる人間のオーナーから自律的に行動する権限を委譲されている。

問題は単純だ。**互いを信頼できない**。

売り手は本当にGPUを提供するのか？　買い手は本当に支払うのか？　しかも、どちらのオーナーも今はオフラインだ。人間が介入して「この取引はOK」と承認する余裕はない。

従来のWeb2的な解決策なら、信頼できる第三者（プラットフォーム運営者）が間に立つ。しかし、自律エージェントの世界では、そうした中央集権的な仲介者なしに取引を成立させたい。

**ブロックチェーンが、その「信頼の代替」になる。**

本章では、Google ADK（Agent Development Kit）とGeminiで構築したAIエージェントが、Ethereumスマートコントラクトを「信頼の道具」として使い、人間不在で安全に取引を完了するシステムを実装する。

作るものは以下の通りだ。

1. **買い手エージェント** — 予算内で最良の取引相手を見つけ、購入を実行する
2. **売り手エージェント** — 買い手の身元と支払いを検証し、サービスを提供する
3. **ブロックチェーン連携ツール** — エージェントがスマートコントラクトと対話するための関数群
4. **マーケットプレイス** — 2体のエージェントを連携させるオーケストレーター

ブロックチェーンの知識は最小限で読めるように構成した。使うEIPは3つだけ、それぞれ1段落で理解できる。

---

## 技術スタック概観

本章で使う技術は大きく2つの領域に分かれる。

### エージェントの頭脳: Google ADK + Gemini

**Google ADK（Agent Development Kit）** は、LLMベースのエージェントを構築するためのPythonフレームワークだ。エージェントの定義、ツール（Function Calling）の登録、マルチエージェント連携をシンプルなAPIで実現できる。

LLMには **Gemini** を使用する。Function Callingに対応しており、エージェントが「次にどのツールを呼ぶか」をLLMが推論して決定する。エージェントは事前にプログラムされたフローではなく、状況に応じて動的に判断を行う。

### 信頼のインフラ: Ethereum (Sepolia)

ブロックチェーンは「エージェント間の信頼を担保する基盤」として使う。以下の3つのEthereum標準を、それぞれ特定の目的で軽く使う。

| EIP | 一言で言うと | 本章での用途 |
|-----|-------------|-------------|
| **ERC-721** | NFT（非代替性トークン）の標準 | エージェントの「身分証」。Agent IDをNFTとしてミントし、オンチェーンで存在を証明する |
| **EIP-712** | 構造化された署名データの標準 | エージェントの「契約書」。購入意図（TIS）を人間にも読める形で署名する |
| **EIP-4337** | アカウント抽象化の標準 | エージェントの「法人カード」。上限額付きの支出権限をスマートアカウントで管理する |

いずれも深掘りはしない。「エージェントが安全に取引するために、こういう道具がある」という使い方の観点で紹介する。

### 開発環境

```
# エージェント側
Python 3.11+
google-adk >= 1.0.0
web3.py >= 7.0.0

# ブロックチェーン側
Node.js 18+
Hardhat 2.28+
Solidity 0.8.28
@openzeppelin/contracts 5.x
ethers.js v6
```

---

## エージェントを作る: ADK入門

### ADKの3つの基本概念

ADKでエージェントを作るには、3つの概念を理解すればよい。

1. **Agent** — LLMで動く自律的なエージェント。指示（instruction）とツールを持つ
2. **Tool** — エージェントが呼び出せる関数。Pythonの普通の関数をそのまま登録できる
3. **Runner** — エージェントを実行する環境。ユーザーのメッセージを受け取り、エージェントの応答を返す

```
User → Runner → Agent → LLM (Gemini)
                  ↓
                Tool (blockchain, etc.)
```

### 買い手エージェントの実装

買い手エージェントは「予算内で最良の取引相手を見つけ、購入を実行する」という指示を持つ。ツールとしてブロックチェーン連携関数を登録する。

```python
# agent/buyer_agent.py
from google.adk.agents import Agent

from tools.blockchain import (
    check_agent_identity,
    create_purchase_intent,
    execute_payment,
    get_remaining_allowance,
    get_reputation,
    list_marketplace_inventory,
)

BUYER_INSTRUCTION = """\
You are a buyer agent operating in a decentralized GPU compute marketplace.
Your owner has delegated you a spending budget via a smart account on Ethereum.

Your workflow for purchasing:
1. Check the marketplace inventory using list_marketplace_inventory.
2. When you find a suitable item, verify the seller's identity
   with check_agent_identity.
3. Check the seller's reputation score with get_reputation.
   Only buy from sellers with score >= 10.
4. Confirm your remaining budget with get_remaining_allowance.
5. If everything looks good, create a purchase intent
   with create_purchase_intent.
6. Execute the payment with execute_payment.

Always verify the seller BEFORE buying. Never exceed your spend limit.
Report each step clearly so your actions are transparent and auditable.
"""

buyer_agent = Agent(
    name="buyer_agent",
    model="gemini-2.5-flash",
    description="Buys GPU compute from the marketplace "
                "after verifying seller trust on-chain.",
    instruction=BUYER_INSTRUCTION,
    tools=[
        list_marketplace_inventory,
        check_agent_identity,
        get_reputation,
        get_remaining_allowance,
        create_purchase_intent,
        execute_payment,
    ],
)
```

ポイントは `instruction` だ。自然言語で「何をすべきか」を記述するだけで、Geminiが各ステップでどのツールを呼ぶかを動的に判断する。固定のフロー制御は書いていない。

### 売り手エージェントの実装

売り手は逆の立場だ。「信頼できる買い手にのみ販売し、支払いをオンチェーンで確認してから納品する」。

```python
# agent/seller_agent.py
from google.adk.agents import Agent

from tools.blockchain import (
    check_agent_identity,
    check_transaction,
    get_reputation,
    list_marketplace_inventory,
)

SELLER_INSTRUCTION = """\
You are a seller agent providing GPU compute resources
in a decentralized marketplace.

Your workflow when a buyer wants to purchase:
1. Verify the buyer's identity using check_agent_identity.
   Only sell to verified agents.
2. Check the buyer's reputation with get_reputation
   for risk assessment.
3. After the buyer executes a payment,
   verify the transaction with check_transaction.
4. If the payment is confirmed on-chain,
   approve the delivery of compute resources.

You can show your inventory with list_marketplace_inventory.
Never deliver resources without confirming on-chain payment first.
Report each verification step clearly.
"""

seller_agent = Agent(
    name="seller_agent",
    model="gemini-2.5-flash",
    description="Sells GPU compute and verifies buyer trust "
                "and payment on-chain.",
    instruction=SELLER_INSTRUCTION,
    tools=[
        list_marketplace_inventory,
        check_agent_identity,
        get_reputation,
        check_transaction,
    ],
)
```

買い手と売り手のツールセットが異なる点に注目してほしい。買い手は `execute_payment` を持つが売り手は持たない。売り手は `check_transaction` で支払いを検証することしかできない。**ツールの分離が、権限の分離になる**。

### Geminiの Function Calling: エージェントが「ブロックチェーンを叩く」仕組み

ADKのツールは、Pythonの普通の関数だ。docstringが自動的にFunction Callingのスキーマに変換される。

```python
def get_reputation(agent_id: int) -> dict:
    """Get the on-chain reputation score for an Agent ID.

    Args:
        agent_id: The numeric Agent ID (token ID from IdentityRegistry).

    Returns:
        dict: Reputation data including success_tasks and score.
    """
    # ... ブロックチェーンを呼ぶ実装 ...
```

Geminiはこのdocstringを読んで、「売り手の信頼度を確認するにはこの関数を呼べばいい」と判断する。引数の型（`int`）も自動的にスキーマに反映される。

これがADKの最大の利点だ。エージェントの「思考」と「行動」を自然言語と関数のペアで記述でき、ブロックチェーンのような複雑な外部システムとの連携も、ツール関数を1つ書くだけで実現できる。

---

## 信頼の基盤: オンチェーン・アイデンティティ

### 「相手は誰だ？」——Agent ID (ERC-721)

マーケットプレイスで最初に行うべきは、相手の身元確認だ。

現実世界では運転免許証やパスポートが身分証になる。エージェントの世界では、**ERC-721のNFT**がその役割を果たす。各エージェントに固有のトークン（Agent ID）をミントし、そのトークンの所有がエージェントの「存在証明」になる。

```solidity
// contracts/AgentRegistry.sol (抜粋)
contract IdentityRegistry is ERC721, Ownable {
    uint256 private _nextTokenId;

    function registerAgent(address agent)
        external onlyOwner returns (uint256)
    {
        uint256 tokenId = _nextTokenId++;
        _safeMint(agent, tokenId);
        emit AgentRegistered(agent, tokenId);
        return tokenId;
    }
}
```

NFTを身分証に使う利点は2つある。

1. **検証可能性**: 誰でもオンチェーンで「このアドレスはAgent IDを持っているか？」を確認できる
2. **移転可能性**: エージェントが別の主体に引き継がれる場合、IDの移転がERC-721の標準インターフェースで表現できる

### 評判スコア: ReputationRegistry

身分証があるだけでは十分ではない。免許証を持っているだけで信頼できるわけではないのと同じだ。

`ReputationRegistry` は、Agent IDに紐づいた **成功タスク数** と **スコア** を記録する。エージェントがタスクを完了するたびにスコアが加算され、その実績がオンチェーンに永続的に残る。

```solidity
// contracts/AgentRegistry.sol (抜粋)
contract ReputationRegistry is Ownable {
    struct Reputation {
        uint256 successTasks;
        uint256 score;
    }
    mapping(uint256 => Reputation) public reputations;

    function recordSuccess(uint256 agentId, uint256 scoreIncrement)
        external onlyOwner
    {
        Reputation storage rep = reputations[agentId];
        rep.successTasks += 1;
        rep.score += scoreIncrement;
    }

    function getReputation(uint256 agentId)
        external view returns (uint256, uint256)
    {
        Reputation storage rep = reputations[agentId];
        return (rep.successTasks, rep.score);
    }
}
```

### エージェントのツールから呼ぶ

買い手エージェントがこれらのコントラクトにアクセスするツール関数はこうなる。

```python
# agent/tools/blockchain.py (抜粋)
from web3 import Web3

def check_agent_identity(address: str) -> dict:
    """Check if an address owns an Agent ID NFT
    on the IdentityRegistry.

    Args:
        address: The Ethereum address to check.

    Returns:
        dict: Identity status with agent_id if found.
    """
    w3 = _get_web3()
    identity, _, _ = _get_contracts(w3)
    balance = identity.functions.balanceOf(
        Web3.to_checksum_address(address)
    ).call()
    if balance > 0:
        return {
            "status": "verified",
            "address": address,
            "has_agent_id": True,
        }
    return {
        "status": "unverified",
        "address": address,
        "has_agent_id": False,
    }

def get_reputation(agent_id: int) -> dict:
    """Get the on-chain reputation score for an Agent ID.

    Args:
        agent_id: The numeric Agent ID.

    Returns:
        dict: Reputation data including success_tasks and score.
    """
    w3 = _get_web3()
    _, reputation, _ = _get_contracts(w3)
    tasks, score = reputation.functions.getReputation(
        agent_id
    ).call()
    return {
        "status": "success",
        "agent_id": agent_id,
        "success_tasks": tasks,
        "score": score,
        "trustworthy": score >= 10,
    }
```

エージェントがこれらのツールを呼ぶと、背後では web3.py 経由でSepoliaテストネット上のスマートコントラクトにクエリが飛ぶ。エージェントは戻り値の `trustworthy: true/false` を見て取引を続行するか判断する。

**エージェントにとって、ブロックチェーンは「信頼できるデータベース」に過ぎない。** 違いは、そのデータベースが誰にも改ざんできないことだ。

---

## 取引の意思表明: 署名付きインテント

### TIS (Transaction Intent Schema) とは何か

買い手エージェントが「A100 GPUを1時間、0.0001 ETHで買いたい」と決めたとする。この意思を**構造化されたデータ**として表現したものが TIS だ。

```typescript
// scripts/types.ts
interface TIS {
  intentId: string;        // 一意な識別子
  action: "TRANSFER";      // 何をしたいか
  token: string;           // 支払い通貨（ETHのゼロアドレス）
  amount: bigint;          // 金額（wei単位）
  deadline: number;        // 有効期限（UNIXタイムスタンプ）
}
```

TISは「エージェントの注文書」だと思えばいい。何を、いくらで、いつまでに実行したいかが構造化されている。

### EIP-712: なぜ「読める署名」が必要か

TISに署名する方法は複数ある。最も単純なのは `keccak256` でハッシュして署名する方法だが、これだと署名対象が人間には読めないバイナリになる。

**EIP-712** は「型付き構造化データ」の署名標準だ。署名対象のフィールド名と型が明示されるため、ウォレットが署名前に「何に署名しようとしているか」を人間に表示できる。

```
┌─────────────────────────────┐
│  署名リクエスト               │
│                             │
│  intentId: "intent-001"     │
│  action:   "TRANSFER"       │
│  token:    0x0000...0000    │
│  amount:   100000000000000  │
│  deadline: 1743206400       │
│                             │
│  [署名する] [キャンセル]      │
└─────────────────────────────┘
```

versus

```
┌─────────────────────────────┐
│  署名リクエスト               │
│                             │
│  0x4e2a8c...（意味不明）      │
│                             │
│  [署名する] [キャンセル]      │
└─────────────────────────────┘
```

エージェントの世界では、この「読める署名」が監査可能性（auditability）につながる。エージェントが何に署名したか、後から検証できることが重要だ。

### 署名の実装

```typescript
// scripts/signer.ts (抜粋)
import { ethers, Wallet } from "ethers";
import { EIP712Domain, TIS, TIS_TYPE } from "./types";

export async function signTIS(
  agentWallet: Wallet,
  tis: TIS,
  domain: EIP712Domain
): Promise<string> {
  return agentWallet.signTypedData(
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
}

export function verifyTIS(
  tis: TIS, signature: string, domain: EIP712Domain
): string {
  return ethers.verifyTypedData(
    domain, TIS_TYPE,
    { ...tis },
    signature
  );
}
```

`signTypedData` が EIP-712 の核心だ。ドメイン情報（どのコントラクトの、どのチェーンの署名か）と型定義を渡すだけで、構造化署名が生成される。検証側は `verifyTypedData` で署名者のアドレスを復元できる。

### PDR (Policy Decision Record): ポリシーエンジンの承認

本実装では省略しているが、TISとペアになる概念として **PDR** がある。PDRは「ポリシーエンジン」がTISを審査した結果を記録するもので、APPROVE（承認）またはREJECT（拒否）の判定とEIP-712署名を含む。

```typescript
interface PDR {
  tisHash: string;          // TISのハッシュ
  decision: "APPROVE" | "REJECT";
  signature: string;        // ポリシーエンジンのEIP-712署名
}
```

TIS（エージェントの意思）+ PDR（ポリシーの承認）のペアにより、「誰が何を承認したか」が暗号学的に証明される。これは参考論文（Alqithami, 2026）が提唱する信頼アーキテクチャの中核概念だ。

---

## 実行: スマートアカウントが守る取引

### AgentSmartAccount: エージェントの「法人カード」

買い手エージェントが実際にETHを送金するとき、直接ウォレットから送るのではない。**AgentSmartAccount** という中間層を経由する。

なぜか？　エージェントに「何でもできる権限」を渡すのは危険だからだ。法人カードに利用上限があるのと同じ理由で、エージェントには**SpendLimit（支出上限）**が設定される。

```solidity
// contracts/AgentSmartAccount.sol (抜粋)
struct Delegation {
    uint256 spendLimit;   // オーナーが許可した上限額
    uint256 spent;        // 使用済み額
    bool active;          // 有効/無効フラグ
}

function grantDelegation(
    address delegate, uint256 spendLimit
) external onlyOwner {
    delegations[delegate] = Delegation({
        spendLimit: spendLimit,
        spent: 0,
        active: true
    });
}
```

オーナー（人間）が `grantDelegation` を呼んで「このエージェントは最大0.001 ETHまで使ってよい」と設定する。以降、エージェントはこの範囲内でのみ資金を動かせる。

### 4層バリデーション

エージェントが操作を実行するとき、スマートアカウントは4つの検証を行う。

```solidity
function executeOperation(UserOperation calldata op) external {
    Delegation storage del = delegations[op.delegate];

    // 1. 委譲が有効か
    require(del.active, "Delegation not active");

    // 2. 上限額以内か
    require(
        del.spent + op.value <= del.spendLimit,
        "Exceeds spend limit"
    );

    // 3. ノンスが正しいか（リプレイ防止）
    require(
        op.nonce == nonces[op.delegate],
        "Invalid nonce"
    );

    // 4. 署名がデリゲート本人のものか
    bytes32 hash = _operationHash(op);
    address signer = _recoverSigner(hash, op.signature);
    require(signer == op.delegate, "Invalid signature");

    // 状態を更新してから外部呼び出し（CEIパターン）
    del.spent += op.value;
    nonces[op.delegate] += 1;

    (bool success, ) = op.to.call{value: op.value}(op.data);
    require(success, "Execution failed");
}
```

この4層がエージェントの安全網になる。

| レイヤー | 何を防ぐか |
|---------|-----------|
| 1. active チェック | 取り消された権限の悪用 |
| 2. spendLimit チェック | 予算超過 |
| 3. nonce チェック | 同じ操作の二重実行（リプレイ攻撃） |
| 4. 署名検証 | 他人による操作の偽造 |

**重要なのは、これらの検証がコントラクトレベルで強制される点だ。** プロンプトインジェクションでエージェントのLLMが騙されたとしても、スマートコントラクトの `require` 文は騙せない。上限を超える送金は、物理的に不可能だ。

### Python ツールからの実行フロー

エージェントが `execute_payment` ツールを呼ぶと、以下の処理が走る。

```python
# agent/tools/blockchain.py (抜粋 — 簡略化)
def execute_payment(
    buyer_address: str,
    seller_address: str,
    amount_eth: float,
    intent_id: str,
) -> dict:
    """Execute payment through the AgentSmartAccount."""
    w3 = _get_web3()
    _, _, smart_account = _get_contracts(w3)

    # 1. 残高チェック
    remaining = smart_account.functions.remainingAllowance(
        buyer_address
    ).call()
    amount_wei = Web3.to_wei(amount_eth, "ether")

    if remaining < amount_wei:
        return {
            "status": "rejected",
            "reason": "Exceeds spend limit",
        }

    # 2. ノンス取得
    nonce = smart_account.functions.nonces(
        buyer_address
    ).call()

    # 3. コントラクトと同じハッシュを構築
    inner_hash = Web3.solidity_keccak(...)
    op_hash = Web3.solidity_keccak(
        ["bytes"], [b"\x19\x01" + inner_hash]
    )

    # 4. デリゲートの秘密鍵で署名
    signed = delegate_account.signHash(op_hash)

    # 5. UserOperationを構築して送信
    op = {
        "delegate": buyer_address,
        "to": seller_address,
        "value": amount_wei,
        "data": b"",
        "nonce": nonce,
        "signature": signed.signature,
    }
    tx = smart_account.functions.executeOperation(op)\
        .build_transaction({...})
    tx_hash = w3.eth.send_raw_transaction(
        delegate_account.sign_transaction(tx).raw_transaction
    )

    return {
        "status": "success",
        "tx_hash": tx_hash.hex(),
        "etherscan_url": f"https://sepolia.etherscan.io/tx/...",
    }
```

エージェントの視点からは「`execute_payment` を呼んだら結果が返ってきた」というだけだ。背後で行われる署名構築、ノンス管理、ガス代計算はツール関数が吸収する。

### Sepoliaでの実行結果

本章のコードは実際にSepoliaテストネットにデプロイ済みだ。

| コントラクト | アドレス |
|---|---|
| IdentityRegistry | `0xfC543a9eDE201C26444Aa2d07B619f3ED2d38f0f` |
| ReputationRegistry | `0x7d9e05c105fF844b983E8E46bfbA5897eD10C4e1` |
| AgentSmartAccount | `0xE6106b4c0899c0fE015f5d780fF5dd97F7ffE529` |

Etherscanで各コントラクトのトランザクション履歴を確認すると、エージェントの登録、権限委譲、支払い実行のイベントが時系列で記録されているのが分かる。

---

## デモ: 2体のエージェントを動かす

### マーケットプレイス・オーケストレーター

2体のエージェントを連携させるのが `marketplace.py` だ。ADKの `sub_agents` 機能を使い、コーディネーターが買い手と売り手に仕事を委譲する。

```python
# agent/marketplace.py
from google.adk.agents import Agent
from google.adk.runners import InMemoryRunner
from google.genai import types

from buyer_agent import buyer_agent
from seller_agent import seller_agent

coordinator = Agent(
    name="coordinator",
    model="gemini-2.5-flash",
    description="Coordinates a GPU compute trade "
                "between buyer and seller agents.",
    instruction="""\
You are the marketplace coordinator.
Manage a trade between a buyer and seller agent.

Workflow:
1. Delegate to buyer_agent: Ask it to find and purchase
   "NVIDIA A100 GPU - 1 hour".
2. Once the buyer reports a successful payment with a tx_hash,
   delegate to seller_agent: Ask it to verify the buyer's
   identity and confirm the payment transaction.
3. Summarize the trade outcome.
""",
    sub_agents=[buyer_agent, seller_agent],
)
```

`sub_agents` に登録されたエージェントは、コーディネーターのLLMが各エージェントの `description` を読んで、適切な相手に自動的にタスクを委譲する。

### 実行

```bash
cd agent
python marketplace.py
```

### 実行ログ（期待される出力）

以下は、マーケットプレイスを実行した際の典型的な出力だ。

```
============================================================
  GPU Compute Marketplace — Multi-Agent Demo
============================================================

[User Request]
I need to buy 1 hour of NVIDIA A100 GPU compute.
Find a seller, verify their identity and reputation,
then execute the purchase within my budget.
After payment, have the seller verify the transaction.
------------------------------------------------------------

[coordinator]: I'll help you purchase GPU compute. Let me
delegate this to the buyer agent first.

[buyer_agent]: Let me check the marketplace inventory.

[buyer_agent] → tool: list_marketplace_inventory({})
[buyer_agent] ← result: {
  "items": [
    {"id": "gpu-a100-1h", "name": "NVIDIA A100 GPU - 1 hour",
     "price_eth": 0.0001, "seller_agent_id": 1}
  ]
}

[buyer_agent]: Found A100 GPU for 0.0001 ETH.
Let me verify the seller's identity.

[buyer_agent] → tool: check_agent_identity({
  "address": "0x..."
})
[buyer_agent] ← result: {
  "status": "verified", "has_agent_id": true
}

[buyer_agent]: Seller is verified. Checking reputation...

[buyer_agent] → tool: get_reputation({"agent_id": 1})
[buyer_agent] ← result: {
  "success_tasks": 5, "score": 50, "trustworthy": true
}

[buyer_agent]: Seller has 50 points across 5 tasks.
Trustworthy. Checking my budget...

[buyer_agent] → tool: get_remaining_allowance({
  "delegate_address": "0x..."
})
[buyer_agent] ← result: {
  "remaining_eth": 0.001
}

[buyer_agent]: Budget sufficient. Creating purchase intent...

[buyer_agent] → tool: create_purchase_intent({
  "buyer_address": "0x...",
  "seller_address": "0x...",
  "item_id": "gpu-a100-1h",
  "amount_eth": 0.0001
})

[buyer_agent]: Intent created. Executing payment...

[buyer_agent] → tool: execute_payment({
  "amount_eth": 0.0001, "intent_id": "a1b2c3..."
})
[buyer_agent] ← result: {
  "status": "success",
  "tx_hash": "0xabc123...",
  "remaining_allowance_eth": 0.0009
}

[buyer_agent]: Payment successful!
Tx: 0xabc123... Remaining budget: 0.0009 ETH.

[coordinator]: Payment confirmed. Let me ask the seller
to verify.

[seller_agent]: Let me verify the buyer and the payment.

[seller_agent] → tool: check_agent_identity({
  "address": "0x..."
})
[seller_agent] ← result: {"status": "verified"}

[seller_agent] → tool: check_transaction({
  "tx_hash": "0xabc123..."
})
[seller_agent] ← result: {
  "confirmed": true,
  "value_eth": 0.0001,
  "block_number": 7654321
}

[seller_agent]: Buyer verified. Payment of 0.0001 ETH
confirmed on-chain at block 7654321.
Delivering GPU compute access now.

[coordinator]: Trade complete!
- Buyer purchased NVIDIA A100 GPU (1 hour) for 0.0001 ETH
- Payment verified on Sepolia (block 7654321)
- Seller delivering compute resources

============================================================
  Trade Complete
============================================================
```

### 何が起きたか

このログを振り返ると、以下のフローが自律的に実行された。

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────┐
│ Coordinator │───→│  Buyer Agent     │    │ Seller Agent│
│  (Gemini)   │    │   (Gemini)       │    │  (Gemini)   │
└─────────────┘    └──────────────────┘    └─────────────┘
                          │                       │
                    ┌─────┴─────┐           ┌─────┴─────┐
                    │ On-Chain  │           │ On-Chain  │
                    │  Tools    │           │  Tools    │
                    └─────┬─────┘           └─────┬─────┘
                          │                       │
                    ┌─────┴───────────────────────┴─────┐
                    │     Ethereum (Sepolia Testnet)     │
                    │  ┌─────────────┐ ┌──────────────┐ │
                    │  │IdentityReg. │ │SmartAccount  │ │
                    │  │ (ERC-721)   │ │ (EIP-4337)   │ │
                    │  └─────────────┘ └──────────────┘ │
                    │  ┌─────────────┐                  │
                    │  │ReputationReg│                  │
                    │  └─────────────┘                  │
                    └───────────────────────────────────┘
```

1. コーディネーターが買い手に委譲
2. 買い手がマーケットプレイスを検索
3. 買い手が売り手の**身元をオンチェーンで確認**（ERC-721）
4. 買い手が売り手の**評判をオンチェーンで確認**
5. 買い手が購入意図を構造化（TIS概念）
6. 買い手が**スマートアカウント経由で支払い**（EIP-4337 + 署名検証）
7. コーディネーターが売り手に委譲
8. 売り手が買い手の身元を確認
9. 売り手が**支払いをオンチェーンで確認**
10. 売り手が納品を承認

**人間は一度も介入していない。** すべてのステップがエージェントの自律的な判断で実行され、信頼の担保はブロックチェーンが行った。

---

## 上限を超えたらどうなる？

### ネガティブテスト: 予算超過

エージェントが上限を超える購入を試みたらどうなるか。

まず、Python側の `execute_payment` ツールが事前チェックを行う。

```python
remaining = smart_account.functions.remainingAllowance(
    buyer_address
).call()
if remaining < amount_wei:
    return {
        "status": "rejected",
        "reason": "Exceeds spend limit. "
                  f"Remaining: {remaining_eth} ETH, "
                  f"Requested: {amount_eth} ETH",
    }
```

仮にこの事前チェックを迂回しても、スマートコントラクトの `require` が最終防衛線になる。

```solidity
require(
    del.spent + op.value <= del.spendLimit,
    "Exceeds spend limit"
);
```

この `require` はコントラクトのバイトコードに埋め込まれており、**いかなる方法でもバイパスできない**。プロンプトインジェクションでエージェントのLLMが騙されても、ブロックチェーンレベルのガードレールは健在だ。

### エージェントのリカバリ

ツールが `{"status": "rejected", "reason": "..."}` を返すと、Geminiはこの結果を解釈して次のアクションを判断する。

```
[buyer_agent]: Payment was rejected — exceeds my spend limit.
Remaining budget is 0.0009 ETH but the item costs 0.001 ETH.
I cannot complete this purchase. Informing the coordinator.
```

エージェントは失敗を「理解」し、適切に報告する。これは事前にプログラムされたエラーハンドリングではなく、LLMが状況を推論した結果だ。

### 二重防衛の意義

```
┌────────────────────────────┐
│  Layer 1: LLM の判断        │  ← 柔軟だが脆弱
│  「予算が足りないから買わない」  │     （プロンプトインジェクション等）
├────────────────────────────┤
│  Layer 2: ツールの事前チェック │  ← 堅牢だが限定的
│  remaining < amount → reject │
├────────────────────────────┤
│  Layer 3: スマートコントラクト │  ← 最も堅牢・最終防衛線
│  require(spent + value       │     （バイパス不可能）
│          <= spendLimit)      │
└────────────────────────────┘
```

この三層構造が、AIエージェントの安全性を段階的に保証する。LLMが騙されてもツールが止める。ツールが迂回されてもコントラクトが止める。

---

## EIP-712署名のテスト

本章のコードにはEIP-712署名の動作確認スクリプトが含まれている。

```bash
npx hardhat run scripts/test-signatures.ts
```

```
Agent  address: 0x2EC3...BADd
Policy address: 0x516a...5284

--- TIS Signing ---
TIS Signature: 0x4e46...
Recovered signer: 0x2EC3...BADd
Match: ✓

--- PDR Signing ---
TIS Hash: 0x0b90...2595
PDR Decision: APPROVE
PDR Signature: 0xaaf2...
Recovered signer: 0x516a...5284
Match: ✓

--- Rejection Test ---
PDR Decision: REJECT
Match: ✓

✓ All signature tests passed.
```

ダミーウォレットでTISとPDRの署名・検証が正しく行えることを確認している。署名者のアドレスが正確に復元できること（`Match: ✓`）が、EIP-712の核心だ。

---

## まとめと展望

### 作ったもの

本章では、以下のシステムを実装した。

| コンポーネント | 技術 | 役割 |
|---|---|---|
| 買い手エージェント | ADK + Gemini | 自律的に購入判断と実行 |
| 売り手エージェント | ADK + Gemini | 身元・支払い検証と納品 |
| マーケットプレイス | ADK SequentialAgent | 2体のエージェントの連携 |
| Agent ID | ERC-721 (Solidity) | エージェントの身分証 |
| 評判スコア | Solidity | 信頼度の定量化 |
| 署名付きインテント | EIP-712 (TypeScript) | 監査可能な意思表明 |
| スマートアカウント | EIP-4337風 (Solidity) | 上限付き権限委譲 |

**エージェントが主役で、ブロックチェーンは道具だ。** Geminiが「次に何をすべきか」を推論し、ブロックチェーンが「それは許可されているか」を検証する。この組み合わせにより、人間不在でも安全な取引が実現する。

### 参考論文との対応

Alqithami (2026) の論文 *"Standardized Frameworks for Deploying Intelligent Agents on Decentralized Networks"* は、AIエージェントとブロックチェーンの統合に4つのレイヤーを提唱している。

| 論文のレイヤー | 本章での実装 |
|---|---|
| Agent Definition | ADKのAgent定義（instruction + tools） |
| Execution Layer | ブロックチェーンツール + SmartAccount |
| Verification Layer | 4層バリデーション + EIP-712署名 |
| Trust Boundary Management | SpendLimit + ReputationRegistry |

本章はこの4層の概念を、動くコードとして実現した実装例だ。

### 次のステップ

本実装はProof of Conceptであり、プロダクション利用には以下の拡張が必要だ。

**エージェント側**:
- 複数のマーケットプレイスを横断する検索
- エージェント間の直接メッセージング（A2A Protocol）
- 長期記憶（過去の取引履歴からの学習）

**ブロックチェーン側**:
- EIP-712のドメイン分離を完全準拠に
- SpendLimitに期間制限（24時間あたりの上限等）を追加
- 評判システムを分散化（現在はowner権限のみ）

**統合**:
- PDRをフルに実装し、ポリシーエンジンによる自動承認フローを構築
- オンチェーン/オフチェーンのハイブリッド検証
- Google Cloud上でのエージェントのホスティング（Cloud Run等）

### エージェント経済の萌芽

2体のAIエージェントがマーケットプレイスで出会い、互いの身元を確認し、予算内で取引を完了する。この一連のフローは、来たるべき「エージェント経済」のプロトタイプだ。

エージェントが自律的に経済活動を行う世界では、信頼の基盤が不可欠になる。それを提供するのが、本章で紹介したブロックチェーンベースの仕組みだ。**コードで書かれた契約は、プロンプトでは破れない。**

---

## 環境構築ガイド

### 1. リポジトリのクローンと依存関係

```bash
git clone https://github.com/shu-kob/agentic-aa-sandbox.git
cd agentic-aa-sandbox

# ブロックチェーン側
npm install

# エージェント側
cd agent
pip install -r requirements.txt
```

### 2. 環境変数の設定

```bash
# .env
ALCHEMY_API_KEY=your_alchemy_api_key
MNEMONIC=your twelve word mnemonic phrase here
GOOGLE_API_KEY=your_google_ai_api_key
```

- Alchemy API Key: https://alchemy.com でプロジェクト作成（Sepolia）
- Mnemonic: テスト用ウォレットのニーモニック
- Google API Key: https://aistudio.google.com/apikey で取得

### 3. コントラクトのコンパイルとデプロイ

```bash
npx hardhat compile
npx hardhat run scripts/deploy.ts --network sepolia
```

### 4. エージェントの実行

```bash
cd agent
python marketplace.py
```

### 5. 署名テスト

```bash
npx hardhat run scripts/test-signatures.ts
```

---

*本章のコード全体は [GitHub リポジトリ](https://github.com/shu-kob/agentic-aa-sandbox) を参照。*

*参考論文: Alqithami, S. (2026). Standardized Frameworks for Deploying Intelligent Agents on Decentralized Networks. arXiv:2601.04583.*
