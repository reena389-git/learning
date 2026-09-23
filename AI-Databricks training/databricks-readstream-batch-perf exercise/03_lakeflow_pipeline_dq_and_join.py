# Databricks notebook source
# =============================================================================
#  03 - LAKEFLOW DECLARATIVE PIPELINE: row-level DQ capture + join-reject capture
# =============================================================================
#  ** IMPORTANT - HOW TO RUN THIS FILE **
#  This is NOT a plain notebook you click "Run all" on. `@dp.table` / the
#  declarative dataset decorators only execute inside a PIPELINE's own runner.
#  Set it up once:
#    1. Left sidebar -> Jobs & Pipelines -> Create -> ETL Pipeline
#       (Lakeflow Declarative Pipeline).
#    2. Point "Source code" at THIS file.
#    3. Set Destination catalog/schema (e.g. workspace / default).
#    4. Click "Run" / "Start" on the pipeline - NOT the notebook Run button.
#  This is genuinely a different execution model from Modules 01-02 (which are
#  plain notebooks you run cell by cell) - worth knowing cold for an interview.
#
#  WHAT THIS ADDS beyond Module 02:
#    (a) DQ CAPTURE OF ACTUAL ROWS, not just pass/fail counts - the quarantine
#        pattern: compute a boolean flag column, keep ALL rows in one table,
#        then split into a "valid" and a "rejected" view/table downstream.
#    (b) JOIN-REJECT CAPTURE: when transactions join to customers, any
#        transaction whose customer_id has NO match becomes its own captured
#        table, not silently dropped - the exact thing you asked to add.
#
#  CAVEAT: `pyspark.pipelines` (dp) is the current (2026) module, replacing the
#  older `dlt` import. `dp.table`, `dp.expect`, `dp.expect_or_drop`, and
#  `dp.expect_or_fail` are confirmed current syntax. The dp.read / dp.read_stream
#  helper names below follow the same pattern as the old dlt.read / dlt.read_stream
#  (used to reference another dataset defined earlier in this same pipeline) -
#  if your workspace's Lakeflow version names these differently, check
#  Jobs & Pipelines docs for the current dp.read equivalent; the STRUCTURE of
#  the pattern (flag column -> split into two tables) is what matters most and
#  will not have changed.
# =============================================================================

# COMMAND ----------
from pyspark import pipelines as dp
from pyspark.sql.functions import col

VOLUME_PATH = "/Volumes/workspace/default/perf_prototype_raw"

# COMMAND ----------
# =============================================================================
#  BRONZE - ingest both sources via Auto Loader, inside the pipeline itself
# =============================================================================
@dp.table(name="bronze_customers")
def bronze_customers():
    return (spark.readStream.format("cloudFiles")
            .option("cloudFiles.format", "csv")
            .option("header", "true")
            .load(f"{VOLUME_PATH}/customers/"))

@dp.table(name="bronze_transactions_pipeline")
def bronze_transactions_pipeline():
    # WHY schemaEvolutionMode here too: this pipeline ingests independently
    # of Module 02's version, so it needs the same schema-evolution handling.
    return (spark.readStream.format("cloudFiles")
            .option("cloudFiles.format", "csv")
            .option("header", "true")
            .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
            .load(f"{VOLUME_PATH}/transactions/"))

# COMMAND ----------
# =============================================================================
#  SILVER - DQ quarantine: capture the ACTUAL bad rows, not just a count
# =============================================================================
# WHY: @dp.expect_or_drop would give you a COUNT of dropped rows in the event
# log, but the rows themselves are gone. Here, instead, we compute the SAME
# boolean condition as a COLUMN, keep every row, and split downstream - so the
# rejected rows are a real, queryable table you can investigate.
@dp.table(name="silver_transactions_quarantine")
@dp.expect("tracked_customer_valid", "customer_id IS NOT NULL")   # WARN-style: logs a count too
@dp.expect("tracked_amount_valid", "amount >= 0")
def silver_transactions_quarantine():
    df = dp.read_stream("bronze_transactions_pipeline")
    return df.withColumn(
        "is_quarantined",
        ~((col("customer_id").isNotNull()) & (col("amount") >= 0))
    )

@dp.table(name="silver_transactions_valid")
def silver_transactions_valid():
    return dp.read_stream("silver_transactions_quarantine").where("is_quarantined = false")

@dp.table(name="silver_transactions_rejected")
def silver_transactions_rejected():
    # THIS table has the full original rows that failed DQ - not just a count.
    return dp.read_stream("silver_transactions_quarantine").where("is_quarantined = true")

# COMMAND ----------
# =============================================================================
#  JOIN - enrich transactions with customer info, and CAPTURE unmatched rows
# =============================================================================
# WHY a LEFT JOIN + flag, not an INNER JOIN: an INNER JOIN would silently drop
# any transaction whose customer_id has no match (like orphan 'C999' from the
# synthetic data) - exactly the silent-row-loss problem from the SQL workshop.
# LEFT JOIN keeps every transaction; the flag tells us which ones didn't match.
@dp.table(name="transactions_enriched_quarantine")
def transactions_enriched_quarantine():
    t = dp.read_stream("silver_transactions_valid")
    c = dp.read("bronze_customers").dropDuplicates(["customer_id"])
    joined = t.join(c, on="customer_id", how="left")
    return joined.withColumn("is_unmatched", col("customer_name").isNull())

@dp.table(name="transactions_enriched")
def transactions_enriched():
    # the clean, business-ready result - every row here has a real customer.
    return dp.read_stream("transactions_enriched_quarantine").where("is_unmatched = false")

@dp.table(name="transactions_join_rejects")
def transactions_join_rejects():
    # every transaction whose customer_id didn't match ANY customer - captured,
    # not lost. This answers "when we join two tables, capture what got
    # filtered out" directly.
    return dp.read_stream("transactions_enriched_quarantine").where("is_unmatched = true")

# COMMAND ----------
# =============================================================================
#  WHAT TO CHECK ONCE THE PIPELINE RUNS
# =============================================================================
# 1. silver_transactions_rejected  -> should contain T1003 (null customer_id)
#    and T1004 (negative amount) - the FULL rows, every column, not a count.
# 2. transactions_join_rejects     -> should contain T1005 (customer 'C999',
#    which does not exist in bronze_customers) - the full row, flagged.
# 3. Data quality tab on silver_transactions_quarantine -> shows the SAME
#    facts as a count (2 violations) - compare the count view vs. the actual
#    row view side by side; that contrast IS the point of this module.
