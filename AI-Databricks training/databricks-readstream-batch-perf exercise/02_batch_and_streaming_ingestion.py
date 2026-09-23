# Databricks notebook source
# =============================================================================
#  02 - INGESTION: batch load vs. Auto Loader streaming, side by side
# =============================================================================
#  WHY side by side: this is the direct comparison you asked to see hands-on -
#  the SAME source data, loaded two different ways, so the incremental and
#  schema-evolution behaviour of Auto Loader is visible against the batch
#  baseline that has none of that behaviour.
# =============================================================================

# COMMAND ----------
VOLUME_PATH = "/Volumes/workspace/default/perf_prototype_raw"
CATALOG = "workspace"
SCHEMA  = "default"

# COMMAND ----------
# =============================================================================
#  PART A - BATCH load (spark.read + saveAsTable)
# =============================================================================
# WHY: the simplest path - reads whatever files exist RIGHT NOW, once, no
# checkpoint, no incremental memory. Re-running it re-reads everything.
df_batch = (spark.read
            .option("header", "true")
            .option("inferSchema", "true")
            .csv(f"{VOLUME_PATH}/transactions/"))

(df_batch.write.mode("overwrite")
   .saveAsTable(f"{CATALOG}.{SCHEMA}.bronze_transactions_batch"))

print("BATCH bronze row count:", spark.table(f"{CATALOG}.{SCHEMA}.bronze_transactions_batch").count())
# Expect 6 rows here (only wave1 has landed so far) - note there is NO
# checkpoint, so if you re-run this cell later after wave2 lands, it simply
# reprocesses ALL files again (no memory of "what it already saw").

# COMMAND ----------
# =============================================================================
#  PART B - Auto Loader STREAMING load (readStream + cloudFiles)
# =============================================================================
# WHY schemaLocation + checkpointLocation: cloudFiles needs a place to persist
# the schema it infers, and Structured Streaming needs a place to persist
# "which files have I already processed" (the checkpoint).
CHECKPOINT = f"{VOLUME_PATH}/_checkpoints/bronze_stream"
SCHEMA_LOC = f"{VOLUME_PATH}/_schema/bronze_stream"
dbutils.fs.rm(CHECKPOINT, recurse=True)   # clean slate for a repeatable demo
dbutils.fs.rm(SCHEMA_LOC, recurse=True)

stream_df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "csv")
    .option("cloudFiles.schemaLocation", SCHEMA_LOC)
    # 'addNewColumns' = default: a new column widens the schema and the
    # stream restarts to pick it up. We use it here so wave2's new 'channel'
    # column is absorbed automatically rather than rescued or failing.
    .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
    .option("header", "true")
    .load(f"{VOLUME_PATH}/transactions/"))

# trigger(availableNow=True) = process everything currently sitting in the
# source, then STOP (good for a demo / batch-like run of a streaming job,
# instead of running forever).
(stream_df.writeStream
    .option("checkpointLocation", CHECKPOINT)
    .trigger(availableNow=True)
    .toTable(f"{CATALOG}.{SCHEMA}.bronze_transactions_stream"))

print("STREAM bronze row count (run 1, wave1 only):",
      spark.table(f"{CATALOG}.{SCHEMA}.bronze_transactions_stream").count())
# Expect 6 rows - same as batch, because only wave1 exists so far.

# COMMAND ----------
# =============================================================================
#  PART C - land wave 2, then re-run EACH loader, and watch the difference
# =============================================================================
import shutil
dbutils.fs.cp("file:/tmp/transactions_wave2.csv", f"{VOLUME_PATH}/transactions/wave2.csv")
print("wave2.csv landed in the source folder.")

# COMMAND ----------
# Re-run the BATCH load: it has NO memory, so it reprocesses EVERYTHING -
# wave1 + wave2 together, from scratch.
df_batch2 = (spark.read.option("header", "true").option("inferSchema", "true")
             .csv(f"{VOLUME_PATH}/transactions/"))
(df_batch2.write.mode("overwrite")
   .saveAsTable(f"{CATALOG}.{SCHEMA}.bronze_transactions_batch"))
print("BATCH bronze row count AFTER wave2 (full reprocess):",
      spark.table(f"{CATALOG}.{SCHEMA}.bronze_transactions_batch").count())
# Expect 9 rows (6+3) - but note it had to re-read wave1 too; it doesn't know
# wave1 was already loaded. This is the batch trade-off: simple, but no
# incremental memory.

# COMMAND ----------
# Re-run the STREAM load: same trigger, but the CHECKPOINT remembers wave1
# was already processed - it should pick up ONLY wave2's 3 new rows.
stream_df2 = (spark.readStream.format("cloudFiles")
    .option("cloudFiles.format", "csv")
    .option("cloudFiles.schemaLocation", SCHEMA_LOC)
    .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
    .option("header", "true")
    .load(f"{VOLUME_PATH}/transactions/"))

(stream_df2.writeStream
    .option("checkpointLocation", CHECKPOINT)   # SAME checkpoint as before
    .trigger(availableNow=True)
    .toTable(f"{CATALOG}.{SCHEMA}.bronze_transactions_stream"))

print("STREAM bronze row count AFTER wave2 (incremental):",
      spark.table(f"{CATALOG}.{SCHEMA}.bronze_transactions_stream").count())
# Expect 9 rows too - but the SECOND run only had to READ wave2's 3 rows
# (verify in Spark UI / event log: it processed far fewer input rows this
# time, because the checkpoint told it wave1 was already done).

# COMMAND ----------
# =============================================================================
#  PART D - see the schema evolution: did 'channel' get absorbed?
# =============================================================================
print("Stream table schema (should now include 'channel' from wave2):")
spark.table(f"{CATALOG}.{SCHEMA}.bronze_transactions_stream").printSchema()

display(spark.table(f"{CATALOG}.{SCHEMA}.bronze_transactions_stream")
        .orderBy("transaction_id"))
# Wave1 rows will show 'channel' = NULL (the column didn't exist for them yet)
# - a good, honest illustration of what "schema evolution" actually looks
# like in the data: old rows backfilled with NULL, not an error.

# COMMAND ----------
# =============================================================================
#  TRY IT: change cloudFiles.schemaEvolutionMode to "rescue" above, delete the
#  checkpoint, and re-run from Part B. Compare: does 'channel' become a real
#  column, or does it land inside _rescued_data instead? That contrast is the
#  clearest possible demonstration of what each mode actually does.
# =============================================================================

# COMMAND ----------
# =============================================================================
#  PART E - IDEMPOTENT SNAPSHOT APPEND + AUDIT LOG (foreachBatch)
# =============================================================================
# WHY this part exists: Parts A-D used the NATIVE .toTable() streaming sink,
# which is automatically exactly-once - no protection needed there. But a lot
# of REAL silver tables are SNAPSHOT-APPEND: every load just appends a full
# batch of rows as-is (e.g. daily_exposure - one row per agreement per day,
# rows are never updated, only new snapshots are added). That is NOT a
# MERGE/upsert pattern, so foreachBatch gives it NO automatic idempotency - a
# batch that fails halfway through and gets retried can silently double-
# append an entire snapshot.
#
# THE REALISTIC RISK, made concrete: this Part writes to TWO tables per batch
# - the snapshot itself, AND a companion AUDIT LOG row ("batch N loaded, R
# rows, at T"). If the snapshot write succeeds but the audit write fails (a
# crash, a cluster hiccup, anything), a naive retry re-runs BOTH writes -
# duplicating the one that already succeeded. This is EXACTLY the
# "fails halfway through and leaves things inconsistent" scenario you
# described.
#
# THE FIX: txnAppId + txnVersion, using the SAME pair for BOTH writes. Delta
# tracks which (appId, version) pairs it has already committed SEPARATELY per
# table. So on retry: whichever table already has that version silently
# SKIPS the duplicate; whichever table doesn't yet have it proceeds normally.
# The two tables converge to a consistent state across a partial failure,
# with no retry/rollback logic written by you.
# =============================================================================

# COMMAND ----------
AUDIT_CATALOG = "workspace"
AUDIT_SCHEMA  = "default"
# APP_ID identifies THIS pipeline to Delta's idempotency check. WHY fixed and
# named, not random: it must be STABLE across retries/restarts for the
# (appId, version) matching to work. See the checkpoint-reset caveat below.
APP_ID = "transactions_snapshot_loader"

spark.sql(f"""
  CREATE TABLE IF NOT EXISTS {AUDIT_CATALOG}.{AUDIT_SCHEMA}.silver_transactions_snapshot
  (transaction_id STRING, customer_id STRING, amount DOUBLE,
   transaction_date STRING, status STRING, channel STRING) USING DELTA
""")
spark.sql(f"""
  CREATE TABLE IF NOT EXISTS {AUDIT_CATALOG}.{AUDIT_SCHEMA}.audit_log
  (batch_id BIGINT, row_count BIGINT, loaded_at TIMESTAMP) USING DELTA
""")

# COMMAND ----------
from pyspark.sql.functions import current_timestamp

# WHY a flag to force a failure: this lets us PROVE the idempotency works,
# rather than just asserting it. First run below forces a crash between the
# two writes; the following run proves the retry converges correctly.
SIMULATE_FAILURE_ON_BATCH = 0   # set to None to disable the forced crash

def load_snapshot_with_audit(microBatchDF, batchId):
    row_count = microBatchDF.count()

    # ---- write 1: the snapshot itself - append-only, made idempotent ------
    (microBatchDF.write.format("delta")
        .option("txnVersion", batchId)      # ties this write to THIS batch
        .option("txnAppId", APP_ID)         # identifies THIS pipeline
        .mode("append")
        .saveAsTable(f"{AUDIT_CATALOG}.{AUDIT_SCHEMA}.silver_transactions_snapshot"))

    # ---- simulate an interruption AFTER write 1 succeeds -------------------
    if SIMULATE_FAILURE_ON_BATCH is not None and batchId == SIMULATE_FAILURE_ON_BATCH:
        raise RuntimeError(
            f"SIMULATED failure after the snapshot write, batch {batchId}. "
            "Re-run the next cell with SIMULATE_FAILURE_ON_BATCH = None to "
            "see the retry behave correctly."
        )

    # ---- write 2: the audit row - SAME txnAppId + txnVersion pair ---------
    audit_row = (spark.createDataFrame([(batchId, row_count)], ["batch_id", "row_count"])
                 .withColumn("loaded_at", current_timestamp()))
    (audit_row.write.format("delta")
        .option("txnVersion", batchId)
        .option("txnAppId", APP_ID)
        .mode("append")
        .saveAsTable(f"{AUDIT_CATALOG}.{AUDIT_SCHEMA}.audit_log"))

# COMMAND ----------
# WHY a NEW checkpoint here: Part E is a separate pipeline from Parts B/C -
# it needs its own checkpoint so batch numbering starts clean at 0 for this demo.
CHECKPOINT_E = f"{VOLUME_PATH}/_checkpoints/snapshot_with_audit"
dbutils.fs.rm(CHECKPOINT_E, recurse=True)   # clean slate for a repeatable demo

# NOTE: if you ever delete THIS checkpoint later and start fresh for real,
# you MUST also change APP_ID - otherwise Delta will think batch 0 was
# already committed (from this earlier run) and silently skip a genuinely
# new run. This is the exact trap the docs warn about.

(spark.readStream.format("cloudFiles")
    .option("cloudFiles.format", "csv")
    .option("cloudFiles.schemaLocation", f"{VOLUME_PATH}/_schema/snapshot_with_audit")
    .option("header", "true")
    .load(f"{VOLUME_PATH}/transactions/")
    .writeStream
    .foreachBatch(load_snapshot_with_audit)
    .option("checkpointLocation", CHECKPOINT_E)
    .trigger(availableNow=True)
    .start())

# EXPECTED: the snapshot table gets batch 0's rows written, THEN a
# RuntimeError is raised and the streaming query fails. The audit_log table
# does NOT get a row for batch 0 - the failure landed between the two writes,
# by design, so you can see the inconsistency for real.

# COMMAND ----------
# ---- check state AFTER the simulated failure ------------------------------
print("Snapshot rows after the failed run:",
      spark.table(f"{AUDIT_CATALOG}.{AUDIT_SCHEMA}.silver_transactions_snapshot").count())
print("Audit log after the failed run:")
display(spark.table(f"{AUDIT_CATALOG}.{AUDIT_SCHEMA}.audit_log"))
# Expect: snapshot HAS batch 0's rows; audit_log is EMPTY. This is the
# "inconsistent state" you described - proven, not just described.

# COMMAND ----------
# ---- NOW disable the simulated failure and RETRY the SAME batch -----------
SIMULATE_FAILURE_ON_BATCH = None

(spark.readStream.format("cloudFiles")
    .option("cloudFiles.format", "csv")
    .option("cloudFiles.schemaLocation", f"{VOLUME_PATH}/_schema/snapshot_with_audit")
    .option("header", "true")
    .load(f"{VOLUME_PATH}/transactions/")
    .writeStream
    .foreachBatch(load_snapshot_with_audit)
    .option("checkpointLocation", CHECKPOINT_E)   # SAME checkpoint -> resumes at batch 0
    .trigger(availableNow=True)
    .start())

# COMMAND ----------
# ---- THE PROOF --------------------------------------------------------------
print("Snapshot rows AFTER retry:",
      spark.table(f"{AUDIT_CATALOG}.{AUDIT_SCHEMA}.silver_transactions_snapshot").count())
print("Audit log AFTER retry:")
display(spark.table(f"{AUDIT_CATALOG}.{AUDIT_SCHEMA}.audit_log"))
# THE PROOF, read carefully:
#  - snapshot row count is UNCHANGED from before the retry - batch 0's
#    snapshot write was correctly recognized as a DUPLICATE and skipped.
#  - audit_log now has EXACTLY ONE row for batch 0 - the write that hadn't
#    happened yet before the failure, now completes.
# Consistent end state across both tables, zero duplicate rows anywhere, and
# no retry/rollback logic written by you - Delta's (txnAppId, txnVersion)
# matching did all of it.

# COMMAND ----------
# =============================================================================
#  PART F - the pre-load validation step (complementary, not a substitute)
# =============================================================================
# YOUR POINT WAS RIGHT that a pre-load check reduces failures - but be precise
# about WHAT it protects against: predictable problems (an empty or malformed
# source file, missing columns, a schema that drifted unexpectedly). It CANNOT
# protect against infrastructure-level interruptions that happen AFTER
# validation passes cleanly - a spot-instance eviction, a network blip, an
# OOM on one executor, someone cancelling the job mid-run. Part E's
# idempotent-write pattern is what protects against THOSE. The two techniques
# are complementary - use both, neither replaces the other.
def preload_validate(path):
    """Lightweight checks BEFORE attempting a load. Returns a list of
    problems found; an empty list means it's safe to proceed."""
    df = spark.read.option("header", "true").csv(path)
    problems = []
    if df.rdd.isEmpty():
        problems.append("source file is empty")
    required_cols = {"transaction_id", "customer_id", "amount", "transaction_date"}
    missing = required_cols - set(df.columns)
    if missing:
        problems.append(f"missing required columns: {missing}")
    return problems

issues = preload_validate(f"{VOLUME_PATH}/transactions/wave1.csv")
if issues:
    print("PRE-LOAD CHECK FAILED - do not attempt the load:", issues)
else:
    print("Pre-load check passed - safe to proceed. (Still keep Part E's "
          "idempotent writes - this check does not cover mid-write failures.)")
