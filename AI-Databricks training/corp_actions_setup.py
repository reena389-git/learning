# Databricks notebook source
# =============================================================================
#  STEP 1a — create a small CORPORATE ACTIONS table (synthetic, matched to your
#  existing counterparties). Run this ONCE in a notebook cell.
#
#  WHY a table: the corporate-actions TOOL (built next) will look up identity
#  changes here. Each row = one identity-changing event (a name change or merger)
#  with old name, new name, type, and effective date -- exactly the data that
#  explains "the name on the trade doesn't match the counterparty master".
# =============================================================================

# COMMAND ----------

# WHERE to create it. We use the workspace catalog (writable, same place your
# agent registered) so there are no permission surprises.
# NOTE: adjust if you prefer another schema you can write to.
CA_CATALOG = "workspace"
CA_SCHEMA  = "default"
CA_TABLE   = "corporate_actions"
CA_FQN     = f"{CA_CATALOG}.{CA_SCHEMA}.{CA_TABLE}"   # FQN = fully-qualified name

# make sure the schema exists (harmless if it already does):
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CA_CATALOG}.{CA_SCHEMA}")

# COMMAND ----------

# The synthetic corporate-actions data, matched to counterparties from THIS project.
# Columns:
#   entity_old      : the name as it might appear on an OLD trade / mismatched record
#   entity_new      : the current canonical name in the master
#   action_type     : NAME_CHANGE or MERGER (the two that cause identity mismatches)
#   effective_date  : when the change took legal effect
#   notes           : human context
rows = [
    ("Bank of Nova Scotia", "Scotiabank",              "NAME_CHANGE", "2019-04-01",
        "Rebranded operating name; same legal entity / LEI."),
    ("First Republic Bank", "JPMorgan Chase Bank NA",  "MERGER",      "2023-05-01",
        "Acquired by JPMorgan; positions moved to JPMorgan entity."),
    ("Central 1 Credit Union", "Central 1 Credit Union","NONE",        None,
        "No corporate action; counterparty_code BCCU unchanged."),
    ("Investec Bank Limited", "Investec Bank Limited",  "NONE",        None,
        "No corporate action on record."),
    ("Deutsche Bank AG",    "Deutsche Bank AG",         "NONE",        None,
        "No corporate action on record."),
]

# COMMAND ----------

# Build a Spark DataFrame from the rows and write it as a governed Delta table.
# WHY define an explicit schema: so the column types are clean (strings + a date),
# which the tool and Genie both rely on.
from pyspark.sql.types import StructType, StructField, StringType, DateType
from pyspark.sql import functions as F

schema = StructType([
    StructField("entity_old",     StringType(), True),
    StructField("entity_new",     StringType(), True),
    StructField("action_type",    StringType(), True),
    StructField("effective_date", StringType(), True),  # keep as string for simplicity
    StructField("notes",          StringType(), True),
])

df = spark.createDataFrame(rows, schema=schema)

# write it as a managed Delta table (overwrite so re-running is safe):
df.write.mode("overwrite").saveAsTable(CA_FQN)

# add a table comment (governance/documentation — Genie & humans read this):
spark.sql(f"""COMMENT ON TABLE {CA_FQN} IS
  'Corporate actions (name changes, mergers) affecting counterparty identity.
   Used to explain when a trade name differs from the counterparty master.'""")

print("Created corporate-actions table:", CA_FQN)
display(spark.table(CA_FQN))
