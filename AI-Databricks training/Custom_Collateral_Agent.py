# Databricks notebook source
# MAGIC %md
# MAGIC

# COMMAND ----------

# DBTITLE 1,Cell 1: Install Libraries
# ---- Cell 1: install the libraries the agent framework needs -----------------
# WHY each one:
#   databricks-langchain : gives us ChatDatabricks (model wrapper) + GenieAgent (tool wrapper)
#   langgraph            : the engine that runs the reason-act LOOP (agent<->tool cycling)
#   databricks-agents    : Databricks' agent utilities / deployment helpers
#   mlflow               : tracing, so we can SEE each step the agent takes
# %pip is used (not plain pip) because this installs into the notebook's Python env.
%pip install -U -q databricks-langchain "langgraph>=0.2,<0.4" databricks-agents mlflow
# WHY restart: newly-installed libraries are only picked up after the Python
# process restarts. Without this you'd get "module not found" on the imports below.
dbutils.library.restartPython()

# COMMAND ----------

# WHY: list the model-serving endpoints that are live in THIS workspace,
# so we pick one that actually answers instead of guessing a name.
from databricks.sdk import WorkspaceClient
w = WorkspaceClient()
for e in w.serving_endpoints.list():
    print(e.name)

# COMMAND ----------

# DBTITLE 1,Cell 2: Configuration
# ---- Cell 2: configuration — the two identifiers unique to YOUR workspace ------
# WHY put these at the top: everything else references them; keeping them in one
# place means if a name changes you edit ONE line, not many.

# The serving-endpoint name for the reasoning model (from your legacy serving URL:
#   .../serving-endpoints/databricks-claude-sonnet-5/invocations
# ChatDatabricks takes the ENDPOINT NAME, which is the last path segment.
#LLM_ENDPOINT = "databricks-claude-sonnet-5"
LLM_ENDPOINT = "databricks-llama-4-maverick"


# The ID of your Collateral Operations Genie space (from its room URL /
# its MCP server URL .../mcp/genie/<THIS_ID>). This tells GenieAgent WHICH
# governed data product to call.
GENIE_SPACE_ID = "01f194d88950157ba63ad2b5dafa69b3"

# COMMAND ----------

# DBTITLE 1,Cell 3: Enable MLflow Tracing
# ---- Cell 3: turn on MLflow tracing so we can SEE the agent's steps -----------
# WHY: an agent's value is in the LOOP (which tool it calls, what came back).
# autolog() records every model call + tool call as a trace you can expand,
# so "the agent decided to call Genie" becomes visible instead of a black box.
import mlflow
mlflow.langchain.autolog()

# COMMAND ----------

# DBTITLE 1,Cell 4: Connect the LLM Brain
# ---- Cell 4: the BRAIN — connect claude-sonnet-5 as the reasoning model -------
# WHY ChatDatabricks: it is the governed wrapper around a Databricks model-serving
# endpoint. Using it (instead of calling Anthropic directly) means every call is
# logged/governed by Unity Catalog + AI Gateway — the whole point of doing this
# on Databricks rather than raw API calls.
from databricks_langchain import ChatDatabricks

llm = ChatDatabricks(endpoint=LLM_ENDPOINT)

# quick sanity check that the model endpoint actually answers (fail fast, clearly):
print("Model check:", llm.invoke("Reply with the single word: ready").content)

# COMMAND ----------

# DBTITLE 1,Cell 5: Wrap Genie Space as a Tool
# ---- Cell 5: the TOOL — wrap the Collateral Operations Genie space -------------
# WHY GenieAgent: it takes your Genie space ID and exposes it as a callable tool.
# Under the hood this tool does exactly the two-step async pattern you learned:
# it QUERIES the space, then POLLS for the answer. The 'description' is important —
# it is what the reasoning model reads to DECIDE when to use this tool, so we make
# it explicit about what the tool is good for.
from databricks_langchain.genie import GenieAgent

genie_tool = GenieAgent(
    genie_space_id=GENIE_SPACE_ID,
    genie_agent_name="CollateralOperations",
    # description = the "when should I use this?" hint the model reads:
    description=(
        "Answers questions about COLLATERAL, EXPOSURE, and shortfalls for "
        "counterparties and agreements, using governed CMOS data. Use this for "
        "any question about collateral amounts (in CAD), exposure, agreements, "
        "or which agreements are under-collateralized."
    ),
)

# COMMAND ----------

# DBTITLE 1,Cell 6: Build the ReAct Agent
# ---- Cell 6: the AGENT — reason-act loop that can call the tool ----------------
# WHY create_react_agent: 'ReAct' = Reason + Act. It builds the loop:
#   model reasons -> decides to call a tool -> tool runs -> result returns to model
#   -> model reasons again -> ... -> final answer.
# We pass the brain (llm) and the list of tools it may use (just the Genie tool
# for now — Step 2 will add more). This is the minimal true agent.
from langgraph.prebuilt import create_react_agent
from langchain_core.tools import tool

# A system prompt = standing instructions for the agent's behavior.
# WHY: it tells the agent to PREFER the governed tool over guessing, which is the
# safety point of the whole architecture (correctness lives in the tool).
SYSTEM_PROMPT = (
  "You are a collateral operations assistant. "
    "For questions about collateral, exposure, agreements, or shortfalls, call CollateralOperations. "
    "For questions about whether a counterparty changed its name, merged, or was acquired "
    "(identity/name mismatches), call CorporateActions. "
    "Base answers on the tool result; do not guess."
)

@tool
def CollateralOperations(query: str) -> str:
    """Answers questions about COLLATERAL, EXPOSURE, and shortfalls for counterparties and agreements, using governed CMOS data. Use this for any question about collateral amounts (in CAD), exposure, agreements, or which agreements are under-collateralized."""
    #return genie_tool.invoke(query)
     # GenieAgent expects a messages-dict, not a bare string — so wrap it:
    result = genie_tool.invoke({"messages": [{"role": "user", "content": query}]})
    # pull the text answer out of the returned messages:
    try:
        return result["messages"][-1].content
    except Exception:
        return str(result)
    

    # ---- Corporate Actions tool (add this near your CollateralOperations tool) ----

@tool
def CorporateActions(entity_name: str) -> str:
    """Look up CORPORATE ACTIONS (name changes, mergers) for a counterparty or
    issuer. Use this when asked whether an entity changed its name, was acquired,
    merged, or renamed — i.e. to explain identity mismatches. Input is the entity
    name to look up. Returns any matching corporate-action records as text."""
    # ^ This triple-quoted string right under the function is the DOCSTRING.
    #   It is NOT just a comment — the @tool decorator feeds this docstring to the
    #   MODEL as the tool's "description". The model reads it to DECIDE when to
    #   call this tool vs. another. So the docstring is functionally important:
    #   it's how the agent knows "use this for name-change / merger questions".

    # Build a SQL query against the corporate_actions table we created.
    # We match on entity_old OR entity_new so a lookup works whether the user
    # gives the old name ("Bank of Nova Scotia") or the new one ("Scotiabank").
    # NOTE the backticks around the hyphenated catalog name (required).
    # `{entity_name}` is inserted via an f-string; we lowercase + use LIKE so the
    # match is forgiving of case and partial names.
    sql = f"""
        SELECT entity_old, entity_new, action_type, effective_date, notes
        FROM `d4001-centralus-tdvip-creditrisk`.cmos_core.corporate_actions
        WHERE lower(entity_old) LIKE lower('%{entity_name}%')
           OR lower(entity_new) LIKE lower('%{entity_name}%')
    """

    # spark.sql(...) runs the query and returns a DataFrame.
    # .collect() pulls the result rows back into Python as a list of Row objects.
    rows = spark.sql(sql).collect()

    # If nothing matched, return a clear message (the agent will relay this).
    if not rows:
        return f"No corporate actions found for '{entity_name}'."

    # Otherwise, format the matching rows into readable text for the agent.
    # Each `r` is a Row; we access columns by name (r.entity_old, etc.).
    lines = []
    for r in rows:
        if r.action_type == "NONE":
            lines.append(f"{r.entity_old}: no corporate action on record. ({r.notes})")
        else:
            lines.append(
                f"{r.entity_old} -> {r.entity_new} "
                f"[{r.action_type}, effective {r.effective_date}]. {r.notes}"
            )
    # join the lines into one string and return it (tools return text to the agent):
    return "\n".join(lines)

agent = create_react_agent(
    model=llm,
    tools=[CollateralOperations,CorporateActions],
    prompt=SYSTEM_PROMPT,
)

# COMMAND ----------

# DBTITLE 1,Cell 7: Run the Agent
# ---- Cell 7: TEST — ask the proven collateral question and watch the loop ------
# WHY this question: it's the one we validated against the metric view earlier
# (Central 1 -> BCCU, latest snapshot, CAD). If the agent routes it to the Genie
# tool and returns the right breakdown, the whole chain works.
question1 = "What is the total collateral in CAD for Central 1, broken down by agreement?"

# invoke() runs the full reason-act loop. The input format is a messages list —
# the same chat shape the model expects.
result = agent.invoke({"messages": [{"role": "user", "content": question1}]})

# The final answer is the last message in the returned conversation:
print("\n================ FINAL ANSWER ================\n")
print(result["messages"][-1].content)


question2 = "Has Bank of Nova Scotia had any name changes or mergers?"
result = agent.invoke({"messages": [{"role": "user", "content": question2}]})
print(result["messages"][-1].content)

# COMMAND ----------

# ---- Cell 8: TEST — ask the proven collateral question and watch the loop ------



question2 = "Has Bank of Nova Scotia had any name changes or mergers?"
result = agent.invoke({"messages": [{"role": "user", "content": question2}]})
print(result["messages"][-1].content)

# COMMAND ----------

# DBTITLE 1,Cell 8: Print Full Reasoning Trace
# ---- Cell 9: SEE the reasoning — print every step the agent took ---------------
# WHY: this is the learning payoff. It prints each message in order so you can see:
#   user question -> agent's decision to call CollateralOperations (a tool call)
#   -> the tool's returned data -> the agent's final synthesized answer.
# This is the reason-act loop made visible.
print("\n================ FULL TRACE (each step) ================\n")
for i, m in enumerate(result["messages"]):
    role = getattr(m, "type", getattr(m, "role", "?"))
    # tool calls show up as an attribute on the assistant messages:
    tool_calls = getattr(m, "tool_calls", None)
    print(f"[{i}] role={role}")
    if tool_calls:
        for tc in tool_calls:
            print(f"     -> TOOL CALL: {tc.get('name')}  args={tc.get('args')}")
    if getattr(m, "content", None):
        print(f"     content: {str(m.content)[:400]}")
    print()
# Also open the MLflow trace UI (the flask icon / Experiments) to explore the
# same loop visually — every model + tool call is recorded there.