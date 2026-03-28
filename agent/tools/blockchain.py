"""Blockchain interaction tools for ADK agents.

Provides functions that ADK agents can call via Function Calling
to interact with the deployed contracts on Sepolia.
"""

import json
import os
from pathlib import Path
from web3 import Web3
from eth_account import Account
from eth_account.messages import encode_defunct

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

_PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent

def _load_deployment() -> dict:
    with open(_PROJECT_ROOT / "deployments" / "sepolia.json") as f:
        return json.load(f)

def _load_abi(name: str) -> list:
    """Load ABI from Hardhat artifacts."""
    paths = {
        "IdentityRegistry": "AgentRegistry.sol/IdentityRegistry.json",
        "ReputationRegistry": "AgentRegistry.sol/ReputationRegistry.json",
        "AgentSmartAccount": "AgentSmartAccount.sol/AgentSmartAccount.json",
    }
    artifact_path = _PROJECT_ROOT / "artifacts" / "contracts" / paths[name]
    with open(artifact_path) as f:
        return json.load(f)["abi"]

def _get_web3() -> Web3:
    api_key = os.environ.get("ALCHEMY_API_KEY", "")
    rpc_url = f"https://eth-sepolia.g.alchemy.com/v2/{api_key}"
    return Web3(Web3.HTTPProvider(rpc_url))

def _get_contracts(w3: Web3) -> tuple:
    deployment = _load_deployment()
    addrs = deployment["contracts"]

    identity = w3.eth.contract(
        address=Web3.to_checksum_address(addrs["IdentityRegistry"]),
        abi=_load_abi("IdentityRegistry"),
    )
    reputation = w3.eth.contract(
        address=Web3.to_checksum_address(addrs["ReputationRegistry"]),
        abi=_load_abi("ReputationRegistry"),
    )
    smart_account = w3.eth.contract(
        address=Web3.to_checksum_address(addrs["AgentSmartAccount"]),
        abi=_load_abi("AgentSmartAccount"),
    )
    return identity, reputation, smart_account


# ---------------------------------------------------------------------------
# Tool functions (called by ADK agents)
# ---------------------------------------------------------------------------

def check_agent_identity(address: str) -> dict:
    """Check if an address owns an Agent ID NFT on the IdentityRegistry.

    Args:
        address: The Ethereum address to check.

    Returns:
        dict: Identity status with agent_id if found, or an error message.
    """
    try:
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
                "nft_balance": balance,
            }
        return {
            "status": "unverified",
            "address": address,
            "has_agent_id": False,
        }
    except Exception as e:
        return {"status": "error", "error": str(e)}


def get_reputation(agent_id: int) -> dict:
    """Get the on-chain reputation score for an Agent ID.

    Args:
        agent_id: The numeric Agent ID (token ID from IdentityRegistry).

    Returns:
        dict: Reputation data including success_tasks and score.
    """
    try:
        w3 = _get_web3()
        _, reputation, _ = _get_contracts(w3)
        tasks, score = reputation.functions.getReputation(agent_id).call()
        return {
            "status": "success",
            "agent_id": agent_id,
            "success_tasks": tasks,
            "score": score,
            "trustworthy": score >= 10,
        }
    except Exception as e:
        return {"status": "error", "error": str(e)}


def get_remaining_allowance(delegate_address: str) -> dict:
    """Check remaining spend allowance for a delegate on the AgentSmartAccount.

    Args:
        delegate_address: The Ethereum address of the delegate.

    Returns:
        dict: Remaining allowance in wei and ETH.
    """
    try:
        w3 = _get_web3()
        _, _, smart_account = _get_contracts(w3)
        remaining = smart_account.functions.remainingAllowance(
            Web3.to_checksum_address(delegate_address)
        ).call()
        return {
            "status": "success",
            "delegate": delegate_address,
            "remaining_wei": remaining,
            "remaining_eth": float(Web3.from_wei(remaining, "ether")),
        }
    except Exception as e:
        return {"status": "error", "error": str(e)}


def check_transaction(tx_hash: str) -> dict:
    """Verify a transaction on Sepolia by its hash.

    Args:
        tx_hash: The transaction hash to look up.

    Returns:
        dict: Transaction status including confirmation and value transferred.
    """
    try:
        w3 = _get_web3()
        receipt = w3.eth.get_transaction_receipt(tx_hash)
        tx = w3.eth.get_transaction(tx_hash)
        return {
            "status": "success",
            "confirmed": receipt["status"] == 1,
            "block_number": receipt["blockNumber"],
            "from": tx["from"],
            "to": tx["to"],
            "value_eth": float(Web3.from_wei(tx["value"], "ether")),
            "etherscan_url": f"https://sepolia.etherscan.io/tx/{tx_hash}",
        }
    except Exception as e:
        return {"status": "error", "error": str(e)}


def list_marketplace_inventory() -> dict:
    """List available items in the GPU compute marketplace.

    Returns:
        dict: Available compute resources with pricing in ETH.
    """
    return {
        "status": "success",
        "items": [
            {
                "id": "gpu-a100-1h",
                "name": "NVIDIA A100 GPU - 1 hour",
                "price_eth": 0.0001,
                "seller_agent_id": 1,
                "available": True,
            },
            {
                "id": "gpu-a100-4h",
                "name": "NVIDIA A100 GPU - 4 hours",
                "price_eth": 0.00035,
                "seller_agent_id": 1,
                "available": True,
            },
            {
                "id": "gpu-h100-1h",
                "name": "NVIDIA H100 GPU - 1 hour",
                "price_eth": 0.0002,
                "seller_agent_id": 1,
                "available": True,
            },
        ],
    }


def create_purchase_intent(
    buyer_address: str,
    seller_address: str,
    item_id: str,
    amount_eth: float,
) -> dict:
    """Create a TIS (Transaction Intent Schema) for a purchase.

    The TIS is a structured intent that describes what the buyer wants to do.
    It will be signed with EIP-712 typed data for on-chain verification.

    Args:
        buyer_address: Buyer's Ethereum address.
        seller_address: Seller's Ethereum address.
        item_id: The item identifier from the marketplace.
        amount_eth: The payment amount in ETH.

    Returns:
        dict: The generated TIS object with a unique intent ID.
    """
    import hashlib
    import time

    intent_id = hashlib.sha256(
        f"{buyer_address}{seller_address}{item_id}{time.time()}".encode()
    ).hexdigest()[:16]

    tis = {
        "intent_id": intent_id,
        "action": "TRANSFER",
        "buyer": buyer_address,
        "seller": seller_address,
        "item_id": item_id,
        "amount_eth": amount_eth,
        "amount_wei": int(amount_eth * 1e18),
        "deadline": int(time.time()) + 3600,
    }

    return {
        "status": "success",
        "tis": tis,
        "message": f"Purchase intent created: {amount_eth} ETH for {item_id}",
    }


def execute_payment(
    buyer_address: str,
    seller_address: str,
    amount_eth: float,
    intent_id: str,
) -> dict:
    """Execute a payment through the AgentSmartAccount with signature verification.

    This constructs and submits a UserOperation to the smart account,
    which verifies the delegate's signature and spend limit before executing.

    Args:
        buyer_address: The buyer (delegate) address.
        seller_address: The payment recipient address.
        amount_eth: Amount to send in ETH.
        intent_id: The TIS intent ID for traceability.

    Returns:
        dict: Transaction result with hash and remaining allowance.
    """
    try:
        w3 = _get_web3()
        _, _, smart_account = _get_contracts(w3)
        deployment = _load_deployment()

        # Check remaining allowance first
        remaining = smart_account.functions.remainingAllowance(
            Web3.to_checksum_address(buyer_address)
        ).call()
        amount_wei = Web3.to_wei(amount_eth, "ether")

        if remaining < amount_wei:
            return {
                "status": "rejected",
                "reason": f"Exceeds spend limit. Remaining: {Web3.from_wei(remaining, 'ether')} ETH, Requested: {amount_eth} ETH",
                "intent_id": intent_id,
            }

        # Get nonce
        nonce = smart_account.functions.nonces(
            Web3.to_checksum_address(buyer_address)
        ).call()

        # Build operation hash (matching contract's _operationHash)
        data = b""
        inner_hash = Web3.solidity_keccak(
            ["bytes"],
            [
                w3.codec.encode(
                    ["address", "address", "uint256", "bytes32", "uint256", "address"],
                    [
                        Web3.to_checksum_address(buyer_address),
                        Web3.to_checksum_address(seller_address),
                        amount_wei,
                        Web3.keccak(data),
                        nonce,
                        Web3.to_checksum_address(
                            deployment["contracts"]["AgentSmartAccount"]
                        ),
                    ],
                )
            ],
        )
        op_hash = Web3.solidity_keccak(
            ["bytes"],
            [b"\x19\x01" + inner_hash],
        )

        # Sign with delegate's private key
        mnemonic = os.environ.get("MNEMONIC", "")
        Account.enable_unaudited_hdwallet_features()
        delegate_account = Account.from_mnemonic(
            mnemonic, account_path="m/44'/60'/0'/0/1"
        )
        signed = delegate_account.signHash(op_hash)

        # Build UserOperation
        op = {
            "delegate": Web3.to_checksum_address(buyer_address),
            "to": Web3.to_checksum_address(seller_address),
            "value": amount_wei,
            "data": data,
            "nonce": nonce,
            "signature": signed.signature,
        }

        # Submit transaction
        tx = smart_account.functions.executeOperation(op).build_transaction(
            {
                "from": delegate_account.address,
                "nonce": w3.eth.get_transaction_count(delegate_account.address),
                "gas": 200000,
                "gasPrice": w3.eth.gas_price,
            }
        )
        signed_tx = delegate_account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

        new_remaining = smart_account.functions.remainingAllowance(
            Web3.to_checksum_address(buyer_address)
        ).call()

        return {
            "status": "success" if receipt["status"] == 1 else "failed",
            "tx_hash": tx_hash.hex(),
            "intent_id": intent_id,
            "amount_eth": amount_eth,
            "remaining_allowance_eth": float(
                Web3.from_wei(new_remaining, "ether")
            ),
            "etherscan_url": f"https://sepolia.etherscan.io/tx/{tx_hash.hex()}",
        }
    except Exception as e:
        return {"status": "error", "error": str(e), "intent_id": intent_id}
