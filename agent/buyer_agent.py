"""Buyer Agent — ADK agent that purchases GPU compute on the marketplace.

Uses Gemini to reason about purchases and blockchain tools to verify
seller identity, check reputation, and execute payments.
"""

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
2. When you find a suitable item, verify the seller's identity with check_agent_identity.
3. Check the seller's reputation score with get_reputation. Only buy from sellers with score >= 10.
4. Confirm your remaining budget with get_remaining_allowance.
5. If everything looks good, create a purchase intent with create_purchase_intent.
6. Execute the payment with execute_payment.

Always verify the seller BEFORE buying. Never exceed your spend limit.
Report each step clearly so your actions are transparent and auditable.
"""

buyer_agent = Agent(
    name="buyer_agent",
    model="gemini-2.5-flash",
    description="Buys GPU compute from the marketplace after verifying seller trust on-chain.",
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
