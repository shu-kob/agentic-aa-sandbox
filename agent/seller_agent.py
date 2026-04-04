"""Seller Agent — ADK agent that provides GPU compute on the marketplace.

Verifies buyer identity and confirms on-chain payments before
delivering compute resources.
"""

from google.adk.agents import Agent

from tools.blockchain import (
    check_agent_identity,
    check_transaction,
    get_reputation,
    list_marketplace_inventory,
)

SELLER_INSTRUCTION = """\
You are a seller agent providing GPU compute resources in a decentralized marketplace.

Your workflow when a buyer wants to purchase:
1. Verify the buyer's identity using check_agent_identity. Only sell to verified agents.
2. Check the buyer's reputation with get_reputation for risk assessment.
3. After the buyer executes a payment, verify the transaction with check_transaction.
4. If the payment is confirmed on-chain, approve the delivery of compute resources.

You can show your inventory with list_marketplace_inventory.
Never deliver resources without confirming on-chain payment first.
Report each verification step clearly.
"""

seller_agent = Agent(
    name="seller_agent",
    model="gemini-2.5-flash",
    description="Sells GPU compute and verifies buyer trust and payment on-chain.",
    instruction=SELLER_INSTRUCTION,
    tools=[
        list_marketplace_inventory,
        check_agent_identity,
        get_reputation,
        check_transaction,
    ],
)
