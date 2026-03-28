"""Marketplace — Orchestrates buyer and seller agents for a GPU compute trade.

Runs a SequentialAgent workflow:
  1. Buyer browses inventory, verifies seller, and executes payment
  2. Seller verifies buyer and confirms on-chain payment
"""

import asyncio

from dotenv import load_dotenv
from google.adk.agents import Agent, SequentialAgent
from google.adk.runners import InMemoryRunner
from google.genai import types

from buyer_agent import buyer_agent
from seller_agent import seller_agent

load_dotenv()

# ---------------------------------------------------------------------------
# Coordinator: orchestrates the multi-agent marketplace workflow
# ---------------------------------------------------------------------------

coordinator = Agent(
    name="coordinator",
    model="gemini-2.5-flash",
    description="Coordinates a GPU compute trade between buyer and seller agents.",
    instruction="""\
You are the marketplace coordinator. Manage a trade between a buyer and seller agent.

Workflow:
1. Delegate to buyer_agent: Ask it to find and purchase "NVIDIA A100 GPU - 1 hour".
2. Once the buyer reports a successful payment with a tx_hash, delegate to seller_agent:
   Ask it to verify the buyer's identity and confirm the payment transaction.
3. Summarize the trade outcome.

Always delegate tasks to the appropriate agent. Do not call blockchain tools directly.
""",
    sub_agents=[buyer_agent, seller_agent],
)


# ---------------------------------------------------------------------------
# Run the marketplace scenario
# ---------------------------------------------------------------------------

async def run_marketplace():
    runner = InMemoryRunner(agent=coordinator, app_name="gpu_marketplace")

    print("=" * 60)
    print("  GPU Compute Marketplace — Multi-Agent Demo")
    print("=" * 60)

    user_request = types.Content(
        role="user",
        parts=[
            types.Part(
                text=(
                    "I need to buy 1 hour of NVIDIA A100 GPU compute. "
                    "Find a seller, verify their identity and reputation, "
                    "then execute the purchase within my budget. "
                    "After payment, have the seller verify the transaction."
                )
            )
        ],
    )

    print("\n[User Request]")
    print(user_request.parts[0].text)
    print("-" * 60)

    async for event in runner.run_async(
        user_id="user_1",
        session_id="trade_001",
        new_message=user_request,
    ):
        if event.content and event.content.parts:
            for part in event.content.parts:
                if part.text:
                    print(f"\n[{event.author}]: {part.text}")
                if part.function_call:
                    print(f"\n[{event.author}] → tool: {part.function_call.name}({part.function_call.args})")
                if part.function_response:
                    print(f"\n[{event.author}] ← result: {part.function_response.response}")

    print("\n" + "=" * 60)
    print("  Trade Complete")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(run_marketplace())
