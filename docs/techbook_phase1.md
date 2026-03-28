# AIエージェントのための信頼インフラをゼロから作る
## Phase 1: スマートコントラクトによるオンチェーン・アイデンティティと権限委譲

---

## はじめに

「AIエージェントが自律的に資金を動かす」——この一文を聞いてどう感じるだろうか。便利そうだと思う一方で、「それは安全なのか？」という疑問が浮かぶはずだ。

LLMベースのエージェントが普及しつつある現在、エージェントに*何をどこまで許すか*を技術的に保証する仕組みが求められている。本章では、その基盤となるスマートコントラクトを Solidity と Hardhat (TypeScript) で実装し、実際に Sepolia テストネットへデプロイするまでを解説する。

実装するのは以下の2つだ。

- **AgentRegistry** — エージェントのアイデンティティと評判をオンチェーンで管理する
- **AgentSmartAccount** — エージェントに「上限付き権限」を委譲するスマートアカウント

---

## 設計思想：なぜオンチェーンで信頼を構築するのか

オフチェーンで「このエージェントは信頼できる」と宣言するのは簡単だが、それは改ざん可能だ。ブロックチェーンに記録することで、エージェントの実績と権限の範囲が誰でも検証可能な形で残る。

本実装が参照した提案標準は以下の2つである。

| 標準 | 概念 | 本実装での位置づけ |
|---|---|---|
| EIP-8004 (Trustless Agents) | エージェントの身元・評判をオンチェーンで管理 | `AgentRegistry.sol` |
| EIP-7702 / ERC-4337 | スマートアカウントへの権限委譲・UserOperation | `AgentSmartAccount.sol` |

---

## 開発環境

```
Hardhat: 2.28.6
Solidity: 0.8.28 (EVM: Cancun)
@openzeppelin/contracts: 5.x
ethers.js: v6
TypeScript: 5.x
```

プロジェクト初期化：

```bash
npm init -y
npm install --save-dev hardhat@^2.22.0 "@nomicfoundation/hardhat-toolbox@hh2" typescript ts-node @types/node dotenv
npm install @openzeppelin/contracts
```

`hardhat.config.ts` の要点はEVMバージョンの指定だ。OpenZeppelin v5 が使用する `mcopy` オペコードはCancun以降でしか動作しない。

```typescript
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: { evmVersion: "cancun" },
  },
  networks: {
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: { mnemonic: MNEMONIC },
    },
  },
};
```

---

## Contract 1: AgentRegistry.sol

### IdentityRegistry — エージェントIDの発行

ERC721を継承し、エージェントごとにNFT（Agent ID）をミントする。トークンIDがそのままエージェントの識別子になる。

```solidity
contract IdentityRegistry is ERC721, Ownable {
    uint256 private _nextTokenId;

    event AgentRegistered(address indexed agent, uint256 indexed tokenId);

    constructor() ERC721("AgentID", "AID") Ownable(msg.sender) {}

    function registerAgent(address agent) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(agent, tokenId);
        emit AgentRegistered(agent, tokenId);
        return tokenId;
    }
}
```

NFTをアイデンティティに使う利点は、所有権の移転が標準インターフェース（ERC721）で表現できる点だ。エージェントが「別の主体に引き継がれる」といったユースケースにも対応できる。

### ReputationRegistry — 実績の蓄積

`IdentityRegistry` と連携し、Agent IDに紐づいた成功タスク数とスコアを記録する。

```solidity
contract ReputationRegistry is Ownable {
    struct Reputation {
        uint256 successTasks;
        uint256 score;
    }

    mapping(uint256 => Reputation) public reputations;
    IdentityRegistry public immutable identityRegistry;

    function recordSuccess(uint256 agentId, uint256 scoreIncrement) external onlyOwner {
        require(identityRegistry.ownerOf(agentId) != address(0), "Agent ID does not exist");
        Reputation storage rep = reputations[agentId];
        rep.successTasks += 1;
        rep.score += scoreIncrement;
        emit ReputationUpdated(agentId, rep.successTasks, rep.score);
    }
}
```

`identityRegistry.ownerOf()` で存在確認をすることで、存在しないAgent IDへの書き込みを防いでいる。

---

## Contract 2: AgentSmartAccount.sol

### 設計の核心：上限付き委譲

エージェントに「何でもできる権限」を渡すのは危険だ。本実装では**SpendLimit**（支出上限額）をオーナーが設定し、エージェントはその範囲内でのみ資金を動かせる。

```solidity
struct Delegation {
    uint256 spendLimit;  // オーナーが許可した上限額
    uint256 spent;       // 使用済み額
    bool active;         // 有効/無効フラグ
}

function grantDelegation(address delegate, uint256 spendLimit) external onlyOwner {
    delegations[delegate] = Delegation({
        spendLimit: spendLimit,
        spent: 0,
        active: true
    });
}
```

### UserOperation — 署名付き操作の構造体

ERC-4337に着想を得た構造体で、エージェントが実行したい操作を記述する。

```solidity
struct UserOperation {
    address delegate;     // 操作を提出するエージェント
    address payable to;   // 送金先
    uint256 value;        // 送金額
    bytes data;           // calldata（任意のコントラクト呼び出しに対応）
    uint256 nonce;        // リプレイアタック防止
    bytes signature;      // エージェントのECDSA署名
}
```

### executeOperation — 多段検証の実行フロー

操作実行時に行う検証は4層ある。

```solidity
function executeOperation(UserOperation calldata op) external {
    // 1. 委譲が有効か
    require(del.active, "Delegation not active");
    // 2. 上限額以内か
    require(del.spent + op.value <= del.spendLimit, "Exceeds spend limit");
    // 3. ノンスが正しいか（リプレイ防止）
    require(op.nonce == nonces[op.delegate], "Invalid nonce");
    // 4. 署名がデリゲート本人のものか
    address signer = _recoverSigner(hash, op.signature);
    require(signer == op.delegate, "Invalid signature");

    // CEIパターン：外部呼び出しの前に状態を更新
    del.spent += op.value;
    nonces[op.delegate] += 1;

    (bool success, ) = op.to.call{value: op.value}(op.data);
    require(success, "Execution failed");
}
```

4番目の署名検証がポイントで、**「権限を持つ者が実際に署名した操作しか実行できない」**ことをコントラクトレベルで強制する。リレーヤー（第三者）がトランザクションを代理送信しても、署名がなければ操作は通らない。

状態更新を外部呼び出しより先に行うのは**CEI（Checks-Effects-Interactions）パターン**によるリエントランシー攻撃対策だ。

### ハッシュの構築

署名対象のハッシュはEIP-191の `\x19\x01` プレフィックスを使って構築する。

```solidity
function _operationHash(UserOperation calldata op) internal view returns (bytes32) {
    return keccak256(
        abi.encodePacked(
            "\x19\x01",
            keccak256(abi.encode(
                op.delegate, op.to, op.value,
                keccak256(op.data), op.nonce,
                address(this)  // コントラクトアドレスでクロスコントラクト攻撃を防ぐ
            ))
        )
    );
}
```

`address(this)` を含めることで、同じ署名が別のコントラクトで使い回されるクロスコントラクト攻撃を防止している。

---

## Sepoliaへのデプロイ

### 準備

1. [Alchemy](https://alchemy.com) でプロジェクトを作成し、Sepolia の API Key を取得する
2. `.env` ファイルを作成する

```
ALCHEMY_API_KEY=xxxxxxxxxxxxxxxxxxxx
MNEMONIC=word1 word2 ... word12
```

3. ニーモニックから導出されるアドレス（index 0）に Sepolia ETH をフォーセットから入手する

### デプロイスクリプト

```typescript
async function main() {
  const [deployer] = await ethers.getSigners();

  const identityRegistry = await (await ethers.getContractFactory("IdentityRegistry")).deploy();
  await identityRegistry.waitForDeployment();

  const reputationRegistry = await (await ethers.getContractFactory("ReputationRegistry"))
    .deploy(await identityRegistry.getAddress());
  await reputationRegistry.waitForDeployment();

  // デプロイ時に 0.001 ETH を入金しておく
  const agentSmartAccount = await (await ethers.getContractFactory("AgentSmartAccount"))
    .deploy({ value: ethers.parseEther("0.001") });
  await agentSmartAccount.waitForDeployment();
}
```

```bash
npx hardhat run scripts/deploy.ts --network sepolia
```

### デプロイ結果（Sepolia）

| コントラクト | アドレス |
|---|---|
| IdentityRegistry | `0xfC543a9eDE201C26444Aa2d07B619f3ED2d38f0f` |
| ReputationRegistry | `0x7d9e05c105fF844b983E8E46bfbA5897eD10C4e1` |
| AgentSmartAccount | `0xE6106b4c0899c0fE015f5d780fF5dd97F7ffE529` |

---

## インタラクション：実際に動かす

### 1. エージェントを登録する

```typescript
const registry = await ethers.getContractAt("IdentityRegistry", IDENTITY_ADDRESS);
const tx = await registry.registerAgent(agentAddress);
const receipt = await tx.wait();
// AgentRegistered イベントから tokenId を取得
```

### 2. 評判を記録する

```typescript
const reputation = await ethers.getContractAt("ReputationRegistry", REPUTATION_ADDRESS);
await reputation.recordSuccess(agentId, scoreIncrement);
const [tasks, score] = await reputation.getReputation(agentId);
```

### 3. 委譲実行のポイント：JS側でのハッシュ再現

コントラクトの `_operationHash` と完全に同じハッシュをJS側で作る必要がある。

```typescript
// ニーモニックからデリゲートウォレットを導出
const delegateWallet = ethers.HDNodeWallet.fromPhrase(mnemonic, undefined, "m/44'/60'/0'/0/1");

// コントラクトと同じハッシュを再現
const innerHash = ethers.keccak256(
  ethers.AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "uint256", "bytes32", "uint256", "address"],
    [delegateWallet.address, to, value, ethers.keccak256(data), nonce, accountAddress]
  )
);
const opHash = ethers.keccak256(
  ethers.concat([ethers.toUtf8Bytes("\x19\x01"), ethers.getBytes(innerHash)])
);

// signingKey で raw 署名（signMessage は Ethereum prefix を付加するので使わない）
const rawSig = delegateWallet.signingKey.sign(opHash);
const sig = ethers.Signature.from(rawSig).serialized;
```

`signMessage()` は内部で `\x19Ethereum Signed Message:\n32` を付加するため、コントラクトの `ecrecover` と一致しない。`signingKey.sign()` で raw 署名する点が落とし穴になりやすい。

---

## セキュリティ上の考慮点

本実装はモックであり、プロダクションには以下の追加が必要だ。

| 項目 | 現状 | 本番向けの対応 |
|---|---|---|
| 署名ハッシュ | EIP-191ライク | EIP-712（ドメイン分離）に完全準拠 |
| SpendLimit | 累積制限のみ | 期間制限（有効期限）の追加 |
| ReputationRegistry | ownerのみ書き込み | 複数の承認者による多数決など |
| 秘密鍵管理 | 環境変数 | HSM / MPC ウォレット |

---

## まとめと次のステップ

本章では、AIエージェントが安全にオンチェーンで活動するための基盤コントラクト2本を実装し、Sepoliaテストネットへのデプロイまで完了した。

- **IdentityRegistry**: NFTでエージェントのアイデンティティを表現
- **ReputationRegistry**: 実績をオンチェーンに蓄積
- **AgentSmartAccount**: ECDSA署名 + SpendLimit による多段検証で安全な権限委譲を実現

次の Phase 2 では、エージェントが生成するインテント（TIS: Transaction Intent Schema）とポリシーエンジンが発行する承認証明（PDR: Policy Decision Record）をEIP-712で署名するオフチェーンロジックを実装する。オンチェーンとオフチェーンの境界で「誰が何を承認したか」を暗号学的に証明する仕組みが完成する。

---

*コード全体は [GitHub リポジトリ] を参照。*
