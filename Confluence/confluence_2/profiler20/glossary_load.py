# Databricks notebook source
# MAGIC %md
# MAGIC # glossary_load — load the glossary CSV (from a Volume) into the Delta table
# MAGIC
# MAGIC One-time / re-runnable. Point `csv_path` at the CSV you uploaded to a Volume.
# MAGIC Run **after** creating the table with `create_glossary_table.sql` (or it will
# MAGIC create the table from the CSV schema if missing). Uses `INSERT OVERWRITE` so the
# MAGIC table definition, comments and constraints are preserved across reloads.

# COMMAND ----------

dbutils.widgets.text("catalog", "d4001-centralus-tdvip-creditrisk", "Catalog")
dbutils.widgets.text("schema", "xvala_core", "Schema")
dbutils.widgets.text("glossary_table", "credit_risk_glossary", "Glossary table")
dbutils.widgets.text(
    "csv_path",
    "/Volumes/d4001-centralus-tdvip-creditrisk/xvala_core/xvala_core_volume/credit_risk_abbreviations.csv",
    "CSV path (Volume)",
)

CATALOG = dbutils.widgets.get("catalog").strip().strip("`")
SCHEMA = dbutils.widgets.get("schema").strip().strip("`")
TABLE = dbutils.widgets.get("glossary_table").strip().strip("`")
CSV_PATH = dbutils.widgets.get("csv_path").strip()
FQN = f"`{CATALOG}`.`{SCHEMA}`.`{TABLE}`"

COLS = ["token", "canonical_term", "definition", "category", "owner_domain",
        "source_standard", "standard_reference", "also_seen_as", "status",
        "steward", "notes"]

# COMMAND ----------

# Read CSV exactly as text (multiLine for any definition that wraps; quoted commas handled)
df = (spark.read
      .option("header", True)
      .option("multiLine", True)
      .option("escape", '"')
      .csv(CSV_PATH))

missing = [c for c in COLS if c not in df.columns]
if missing:
    raise ValueError(f"CSV is missing expected columns: {missing}\nfound: {df.columns}")

df = df.select(*[f"`{c}`" for c in COLS])
n = df.count()
print(f"read {n} rows from {CSV_PATH}")
display(df.limit(5))

# COMMAND ----------

# Create the table from this schema if it does not already exist (no-op if you ran the DDL)
spark.sql(f"""
CREATE TABLE IF NOT EXISTS {FQN} (
  `token` STRING, `canonical_term` STRING, `definition` STRING, `category` STRING,
  `owner_domain` STRING, `source_standard` STRING, `standard_reference` STRING,
  `also_seen_as` STRING, `status` STRING, `steward` STRING, `notes` STRING
) USING DELTA
COMMENT 'Credit-risk business glossary (system of record).'
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
""")

# COMMAND ----------

# Refresh contents (keeps table definition/comments; swaps the rows)
df.createOrReplaceTempView("_glossary_src")
spark.sql(f"INSERT OVERWRITE {FQN} ({', '.join('`'+c+'`' for c in COLS)}) "
          f"SELECT {', '.join('`'+c+'`' for c in COLS)} FROM _glossary_src")

cnt = spark.table(FQN).count()
print(f"loaded {cnt} terms into {FQN}")
display(spark.sql(f"""
  SELECT owner_domain, count(*) AS terms
  FROM {FQN} GROUP BY owner_domain ORDER BY terms DESC
"""))
