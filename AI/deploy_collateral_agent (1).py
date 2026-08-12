# Databricks notebook source
# /// script
# [tool.databricks.environment]
# environment_version = "5"
# ///
# WHY: list the catalogs THIS workspace can actually see, so we register
# into one that exists and that you can write to.
from databricks.sdk import WorkspaceClient
w = WorkspaceClient()
for c in w.catalogs.list():
    print(c.name)

# COMMAND ----------

  # =============================================================================
#  DEPLOY the Collateral Assistant agent  —  the full governance cycle
#  author -> log -> REGISTER in Unity Catalog (governance attaches here)
#  -> DEPLOY to a Model Serving endpoint (traced, permissioned, Review App)
#
#  WHY this notebook exists separately from your build notebook:
#  Your working agent is a LIVE notebook object. Deployment cannot ship a live
#  object — it needs the agent captured as a standalone FILE wrapped in MLflow's
#  ResponsesAgent interface (the standard agent-serving contract). Same logic
#  you already validated; just re-packaged into the deployable shape.
#
#  Run cells top to bottom on SERVERLESS.
# =============================================================================

# COMMAND ----------

# ---- Cell 1: install deploy-capable versions of the libraries ----------------
# WHY these pins: agents.deploy() needs databricks-agents>=1.1.0 and mlflow>=3.1.3
# (per Databricks docs). Older versions lack the deploy() API used below.
%pip install -U -q "mlflow>=3.1.3" "databricks-agents>=1.1.0" databricks-langchain "langgraph>=0.2,<0.4"
dbutils.library.restartPython()

# COMMAND ----------

# ---- Cell 2: config — same two IDs as your build notebook + where to register -
# WHY: keep identifiers in one place. The UC_MODEL_NAME is the 3-level name the
# agent will be REGISTERED under (catalog.schema.name) — this is the governed
# object Unity Catalog will control permissions/lineage on.
LLM_ENDPOINT   = "databricks-llama-4-maverick"                 # the reasoning brain
GENIE_SPACE_ID = "01f194d88950157ba63ad2b5dafa69b3"           # your Collateral Operations space

# WHERE to register the agent in Unity Catalog. Adjust catalog/schema to ones you
# can WRITE to. Using your CMOS schema keeps the agent next to its data.
CATALOG = "workspace"
#d4001-centralus-tdvip-creditrisk
SCHEMA  = "default"
MODEL   = "collateral_assistant_AGENT"
UC_MODEL_NAME = f"{CATALOG}.{SCHEMA}.{MODEL}"   # backticks: catalog name has hyphens

ENDPOINT_NAME = "collateral-assistant"            # the serving endpoint to create

# COMMAND ----------

# DBTITLE 1,Write deployable agent file
# ---- Cell 3: write the agent to a FILE in the ResponsesAgent shape ------------
# WHY: MLflow "Models from Code" logs the agent by capturing THIS FILE
# and replaying it at serving time. So the agent must live as a .py file, not a
# notebook variable. The logic inside is exactly your working agent (llama brain +
# Genie tool + ReAct loop), wrapped in the ResponsesAgent contract that Model
# Serving requires (predict() takes a request, returns a response).

agent_py = '''
import uuid
import mlflow
from typing import Any
from databricks_langchain import ChatDatabricks
from databricks_langchain.genie import GenieAgent
from langchain_core.tools import tool
from langgraph.prebuilt import create_react_agent
from mlflow.pyfunc import ResponsesAgent
from mlflow.types.responses import ResponsesAgentRequest, ResponsesAgentResponse

# ---- same config as the notebook (kept here so the FILE is self-contained) ----
LLM_ENDPOINT   = "databricks-llama-4-maverick"
GENIE_SPACE_ID = "01f194d88950157ba63ad2b5dafa69b3"

SYSTEM_PROMPT = (
    "You are a collateral operations assistant. For any question about collateral, "
    "exposure, agreements, or shortfalls, you MUST call the CollateralOperations tool "
    "and base your answer on its result. Do not guess numbers. Summarize the tool's "
    "answer clearly for the user."
)

# ---- the brain ----
llm = ChatDatabricks(endpoint=LLM_ENDPOINT)

# ---- the Genie tool (identical to your working Cell 5) ----
_genie = GenieAgent(
    genie_space_id=GENIE_SPACE_ID,
    genie_agent_name="CollateralOperations",
    description="Collateral, exposure, and shortfall questions over governed CMOS data.",
)

# ---- the tool wrapper (identical fix to your working Cell 6) ----
@tool
def CollateralOperations(query: str) -> str:
    """Answers questions about COLLATERAL, EXPOSURE, and shortfalls for counterparties
    and agreements, using governed CMOS data."""
    # GenieAgent wants a messages-dict, not a bare string — wrap it (your fix):
    result = _genie.invoke({"messages": [{"role": "user", "content": query}]})
    try:
        return result["messages"][-1].content
    except Exception:
        return str(result)

# ---- the ReAct agent (identical to your working build) ----
_agent = create_react_agent(model=llm, tools=[CollateralOperations], prompt=SYSTEM_PROMPT)

# ---- WRAP it in ResponsesAgent so Model Serving can call it ------------------
# WHY: Model Serving speaks a standard request/response contract. ResponsesAgent
# adapts our LangGraph agent to that contract: predict() receives the user input,
# runs the SAME reason-act loop, and returns the final text.
class CollateralResponsesAgent(ResponsesAgent):
    def predict(self, request: ResponsesAgentRequest) -> ResponsesAgentResponse:
        # pull the user's text out of the incoming request:
        user_msgs = [{"role": m.role, "content": m.content} for m in request.input]
        # run our agent's reason-act loop:
        out = _agent.invoke({"messages": user_msgs})
        final_text = out["messages"][-1].content
        # return in the ResponsesAgent output shape:
        return ResponsesAgentResponse(
            output=[{"type": "message", "role": "assistant",
                     "id": str(uuid.uuid4()),
                     "content": [{"type": "output_text", "text": final_text}]}]
        )

# MLflow needs to know WHICH object in this file is the servable agent:
mlflow.models.set_model(CollateralResponsesAgent())
'''.lstrip()

with open("agent.py", "w", encoding="utf-8") as f:
    f.write(agent_py)

print("Wrote agent.py")

# COMMAND ----------

# DBTITLE 1,Cell 5
# ---- Cell 4: quick local validation BEFORE deploying (fail fast) --------------
# WHY: mlflow.models.predict() runs the agent.py exactly as serving will, in a
# fresh subprocess. If it works here, it will work deployed — this catches
# packaging/dependency errors NOW instead of after a slow endpoint provision.
import mlflow
mlflow.langchain.autolog()
from mlflow.models import predict as _predict   # (name alias to avoid confusion)

# smoke-test input in the ResponsesAgent request shape:
test_req = {"input": [{"role": "user",
             "content": "What is the total collateral in CAD for Central 1, broken down by agreement?"}]}
print("Local validation (this replays agent.py as serving will)...")
# NOTE: full mlflow.models.predict validation needs the logged model; here we do a
# lighter direct check by importing the class from the file we just wrote:
import importlib.util, sys
spec = importlib.util.spec_from_file_location("agent_module", "agent.py")
agent_module = importlib.util.module_from_spec(spec); spec.loader.exec_module(agent_module)
resp = agent_module.CollateralResponsesAgent().predict(
    __import__("mlflow.types.responses", fromlist=["ResponsesAgentRequest"]).ResponsesAgentRequest(**test_req)
)
print("LOCAL ANSWER:", resp.output[0].content[0]["text"][:500])

# COMMAND ----------

# ---- Cell 5: LOG the agent as an MLflow model, declaring its resources --------
# WHY declare resources: this is the governance hook. By listing the Genie space
# and the LLM endpoint as resources, Unity Catalog knows exactly what this agent
# is allowed to touch, and can enforce/lineage-track it. Without this, the
# deployed agent wouldn't have credentials to reach the Genie space.
import mlflow
from mlflow.models.resources import DatabricksServingEndpoint, DatabricksGenieSpace

with mlflow.start_run():
    logged = mlflow.pyfunc.log_model(
        name="agent",
        python_model="agent.py",          # Models-from-Code: log the FILE we wrote
        resources=[                         # <-- what UC will govern for this agent
            DatabricksServingEndpoint(endpoint_name=LLM_ENDPOINT),
            DatabricksGenieSpace(genie_space_id=GENIE_SPACE_ID),
        ],
        pip_requirements=[
            "mlflow>=3.1.3", "databricks-agents>=1.1.0",
            "databricks-langchain", "langgraph>=0.2,<0.4",
        ],
    )
print("Logged model URI:", logged.model_uri)

# COMMAND ----------

# ---- Cell 6: REGISTER the logged model into Unity Catalog --------------------
# WHY: this is THE governance moment you wanted to see. Registering turns the
# agent into a governed UC OBJECT — it now has permissions, lineage, versions,
# and an owner, exactly like a table. You'll see it in Catalog under the schema.
import mlflow
mlflow.set_registry_uri("databricks-uc")   # register into Unity Catalog (not the workspace registry)

uc_model = mlflow.register_model(model_uri=logged.model_uri, name=UC_MODEL_NAME)
print("Registered in Unity Catalog as:", UC_MODEL_NAME, "version", uc_model.version)

# COMMAND ----------

# ---- Cell 7: DEPLOY the UC model to a Model Serving endpoint -----------------
# WHY agents.deploy(): it provisions an AGENT-optimized endpoint — it wires up
# authentication to the Genie space + LLM, real-time MLflow tracing, and the
# Review App, all automatically. scale_to_zero_enabled=True means the endpoint
# SLEEPS when idle so it doesn't bill continuously (wakes on first request).
from databricks import agents

deployment = agents.deploy(
    model_name=UC_MODEL_NAME,
    model_version=uc_model.version,
    scale_to_zero_enabled=True,     # <-- cost control: idle endpoint costs ~nothing
    endpoint_name=ENDPOINT_NAME,
)
print("Deploying endpoint:", ENDPOINT_NAME)
print("It takes several minutes to provision. Watch Serving -> Endpoints for State: Ready.")

# COMMAND ----------

# ---- Cell 8: where to SEE the full governed cycle ---------------------------
# After Cell 7 finishes provisioning (a few minutes), you can see the cycle:
#  - Catalog  -> {CATALOG}.{SCHEMA}.collateral_assistant  = the governed UC model
#                (permissions, lineage to the Genie space + llama endpoint, versions)
#  - Serving  -> collateral-assistant endpoint            = the live, callable agent
#  - Experiments                                          = every request traced
#  - The Review App URL (printed by deploy)               = stakeholders can test + rate
#
# To DELETE the endpoint later (stop any cost):
#   from databricks import agents
#   agents.delete_deployment(model_name=UC_MODEL_NAME, endpoint_name=ENDPOINT_NAME)
print("Done. See Catalog + Serving + Experiments for the governed agent.")