# Databricks notebook source
# =============================================================================
#  Register CorporateActions as a GOVERNED Unity Catalog FUNCTION
#  This is a SEPARATE, one-time SETUP notebook (like the table-creation notebook).
#  Run it ONCE. Afterward the function lives in the catalog permanently and ANY
#  notebook / agent / SQL query can call it by name.
#
#  We show BOTH ways:
#    Part A - SQL function   (simplest; the native way for a data lookup)
#    Part B - Python function (shows how arbitrary logic becomes a governed tool)
#  Then: attach the registered function to an agent via UCFunctionToolkit.
# =============================================================================

# COMMAND ----------
# =============================================================================
#  PART A - Register as a SQL FUNCTION  (recommended for a pure data lookup)
# =============================================================================
# WHY SQL: your CorporateActions is just a SELECT with one parameter. A SQL UDF is
# the native, simplest form - no Python context, no warehouse_id in code, runs in
# the SQL editor. The COMMENT becomes the tool's description that the agent reads.
#
# PERMISSION NOTE: creating a function needs CREATE FUNCTION on the schema - the
# cousin of CREATE MODEL. If cmos_core denies it (BROWSE-only catalog), change the
# catalog/schema below to workspace.default (which worked for the model).
#
# Run this whole cell as SQL (or paste into the SQL editor):

# MAGIC %sql
# MAGIC CREATE OR REPLACE FUNCTION `d4001-centralus-tdvip-creditrisk`.cmos_core.corp_actions_lookup(
# MAGIC     entity_name STRING COMMENT 'Counterparty or issuer name to look up'
# MAGIC )
# MAGIC RETURNS TABLE(entity_old STRING, entity_new STRING, action_type STRING,
# MAGIC              effective_date STRING, notes STRING)
# MAGIC COMMENT 'Look up corporate actions (name changes, mergers) for a counterparty by name. Use to explain when a trade name differs from the counterparty master.'
# MAGIC RETURN
# MAGIC   SELECT entity_old, entity_new, action_type, effective_date, notes
# MAGIC   FROM `d4001-centralus-tdvip-creditrisk`.cmos_core.corporate_actions
# MAGIC   WHERE lower(entity_old) LIKE lower('%' || entity_name || '%')
# MAGIC      OR lower(entity_new) LIKE lower('%' || entity_name || '%');

# COMMAND ----------
# Test the SQL function (call it like a table-valued function):
# MAGIC %sql
# MAGIC SELECT * FROM `d4001-centralus-tdvip-creditrisk`.cmos_core.corp_actions_lookup('Bank of Nova Scotia');

# COMMAND ----------
# =============================================================================
#  PART B - Register as a PYTHON FUNCTION (via the Databricks Function Client)
# =============================================================================
# WHY show this too: not every tool is a SQL lookup. This is how ARBITRARY Python
# logic becomes a governed UC function. Teaches the Function Client + the
# self-contained-function rule (imports go INSIDE the function).

# install the Unity Catalog AI integration (the Function Client + toolkit):
%pip install -U -q unitycatalog-ai[databricks] databricks-langchain
dbutils.library.restartPython()

# COMMAND ----------
from unitycatalog.ai.core.databricks import DatabricksFunctionClient
client = DatabricksFunctionClient()   # registers Python functions INTO Unity Catalog

CATALOG = "d4001-centralus-tdvip-creditrisk"   # if CREATE FUNCTION denied here,
SCHEMA  = "cmos_core"                            # fall back to workspace / default

# COMMAND ----------
# The function to register. RULES for a UC-registerable Python function:
#  - type hints on params and return (UC builds the signature from them)
#  - a Google-style docstring (UC uses it as the tool DESCRIPTION the agent reads)
#  - SELF-CONTAINED: imports go INSIDE, because it runs in its own context, not
#    your notebook (so it cannot rely on the notebook's `spark`/`w`).
def corp_actions_lookup_py(entity_name: str) -> str:
    """Look up corporate actions (name changes, mergers) for a counterparty.

    Args:
        entity_name: The counterparty or issuer name to look up.

    Returns:
        Matching corporate-action records as text, or a 'none found' message.
    """
    from databricks.sdk import WorkspaceClient
    w = WorkspaceClient()
    # NOTE: fill in a real warehouse_id (SQL Warehouses -> your warehouse -> ID).
    # list them with: [wh.id for wh in WorkspaceClient().warehouses.list()]
    sql = (
        "SELECT entity_old, entity_new, action_type, effective_date, notes "
        "FROM `d4001-centralus-tdvip-creditrisk`.cmos_core.corporate_actions "
        f"WHERE lower(entity_old) LIKE lower('%{entity_name}%') "
        f"   OR lower(entity_new) LIKE lower('%{entity_name}%')"
    )
    resp = w.statement_execution.execute_statement(statement=sql, warehouse_id="YOUR_WAREHOUSE_ID")
    rows = resp.result.data_array if resp.result else None
    if not rows:
        return f"No corporate actions found for '{entity_name}'."
    return "\n".join(f"{r[0]} -> {r[1]} [{r[2]}, {r[3]}]. {r[4]}" for r in rows)

# register it into Unity Catalog:
info = client.create_python_function(func=corp_actions_lookup_py, catalog=CATALOG, schema=SCHEMA, replace=True)
print("Registered UC function:", info.full_name)

# COMMAND ----------
# =============================================================================
#  PART C - Use the REGISTERED function as an agent tool (UCFunctionToolkit)
# =============================================================================
# WHY: this is the payoff - the agent now uses the GOVERNED function (by UC name),
# not the inline @tool Python. Swappable, shared, permissioned.
from databricks_langchain import UCFunctionToolkit

# point the toolkit at the registered function (use the SQL one or the Python one):
FUNC_NAME = f"{CATALOG}.{SCHEMA}.corp_actions_lookup"       # the SQL function from Part A
toolkit = UCFunctionToolkit(function_names=[FUNC_NAME])
uc_tools = toolkit.tools     # these are LangChain-compatible tools

# now you could build the agent with the GOVERNED tool instead of the inline one:
#   agent = create_react_agent(model=llm, tools=[CollateralOperations] + uc_tools, prompt=SYSTEM_PROMPT)
print("Toolkit tools ready:", [t.name for t in uc_tools])

# COMMAND ----------
# Permission to USE the function (for whoever/whatever runs the agent):
#   the privilege is EXECUTE on the function.
# MAGIC %sql
# MAGIC -- GRANT EXECUTE ON FUNCTION `d4001-centralus-tdvip-creditrisk`.cmos_core.corp_actions_lookup TO `account users`;
