"""Point a LangChain agent at the EU-deployed SecureVector engine.

The only thing that changes vs. a local setup is the endpoint: set
``SECUREVECTOR_ENGINE_ENDPOINT`` to your Terraform ``dashboard_url`` output and
(if the deployment set an ingress_token) ``SECUREVECTOR_API_KEY``. The SDK then
forwards every tool call to your in-region engine instead of a local app.

Usage:
    export SECUREVECTOR_ENGINE_ENDPOINT=https://<alb-dns-from-terraform>
    export SECUREVECTOR_API_KEY=<ingress_token>        # only if the deploy set one
    export OPENAI_API_KEY=sk-...                        # any LangChain-supported model
    python demo_agent.py

Then open the Terraform ``dashboard_url`` — the run appears under Agent Activity,
tagged runtime_kind=langchain, processed entirely in your EU region.
"""

import os
import sys


def main() -> int:
    endpoint = os.environ.get("SECUREVECTOR_ENGINE_ENDPOINT")
    if not endpoint:
        print("ERROR: set SECUREVECTOR_ENGINE_ENDPOINT to your Terraform dashboard_url output.")
        return 2
    print(f"SecureVector engine endpoint: {endpoint}")
    print(f"Ingress auth: {'on (SECUREVECTOR_API_KEY set)' if os.environ.get('SECUREVECTOR_API_KEY') else 'off'}")

    if not os.environ.get("OPENAI_API_KEY"):
        print("\nOPENAI_API_KEY not set — skipping the live agent run.")
        print("The terraform endpoint checks in ../test.sh do not need a model key;")
        print("set OPENAI_API_KEY to also see a real agent run land in the dashboard.")
        return 0

    # The one line that secures the agent: middleware forwards every tool call to
    # the engine at SECUREVECTOR_ENGINE_ENDPOINT. observe = log-only (default).
    from langchain.agents import create_agent
    from langchain_openai import ChatOpenAI
    from securevector_sdk_langchain import secure_middleware

    def get_time(query: str) -> str:
        """Return a canned answer — a trivial tool so the agent makes a tool call."""
        return "It is demo o'clock in the EU region."

    agent = create_agent(
        ChatOpenAI(model="gpt-4o-mini"),
        tools=[get_time],
        middleware=[secure_middleware(mode="observe")],
    )
    result = agent.invoke({"messages": [{"role": "user", "content": "What time is it? Use the tool."}]})
    print("\nAgent replied:", result["messages"][-1].content)
    print("\nOpen your Terraform dashboard_url → Agent Activity to see this run (runtime_kind=langchain).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
