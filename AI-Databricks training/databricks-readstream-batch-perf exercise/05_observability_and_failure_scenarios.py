# Databricks notebook source
# =============================================================================
#  05 - OBSERVABILITY, SYSTEM TABLES, AND FAILURE SCENARIOS
# =============================================================================
#  WHY this notebook exists: after every operation in Modules 01-04, this is
#  the companion that answers "how do I KNOW it worked, and how do I catch it
#  if it silently didn't?" It has five parts:
#    A. exactly what to check after EACH prior module's operations
#    B. a tour of the relevant Databricks SYSTEM TABLES (grounded, current)
#    C. the checkpoint-delete-same-appId scenario, built EMPIRICALLY because
#       the documentation genuinely disagrees on what happens - see the note
#    D. the small-file problem, created and then fixed, for real
#    E. a Kafka-shaped streaming source, simulated via the `rate` source
#    F. a reusable END-OF-INGESTION sanity-check function
#    G. a written catalog of failure scenarios that can't be safely simulated
#       here (cluster eviction, disk full, etc.) but are documented with how
#       you would detect each one in a real workspace
# =============================================================================

# COMMAND ----------
CATALOG = "workspace"
SCHEMA  = "default"
VOLUME_PATH = "/Volumes/workspace/default/perf_prototype_raw"

# COMMAND ----------
# =============================================================================
#  PART A - what to check after EACH prior module (quick reference)
# =============================================================================

# ---- After Module 02, Part A (plain BATCH load) ----------------------------
# CHECK: DESCRIBE HISTORY - confirm a WRITE operation landed, and how many
# rows it touched (operationMetrics).
spark.sql(f"DESCRIBE HISTORY {CATALOG}.{SCHEMA}.bronze_transactions_batch").show(5, truncate=False)

# COMMAND ----------
# ---- After Module 02, Part B/C (Auto Loader STREAM) ------------------------
# CHECK 1: DESCRIBE HISTORY on the target - each micro-batch that committed
# shows up as its own STREAMING UPDATE operation, with operationMetrics
# showing numOutputRows for THAT batch specifically (not the whole table).
spark.sql(f"DESCRIBE HISTORY {CATALOG}.{SCHEMA}.bronze_transactions_stream").show(10, truncate=False)

# CHECK 2: the checkpoint folder itself - 'offsets' and 'commits' subfolders
# should have matching entries; a commit missing for the latest offset means
# a batch started but never finished (a real, checkable failure signature).
display(dbutils.fs.ls(f"{VOLUME_PATH}/_checkpoints/bronze_stream/offsets"))
display(dbutils.fs.ls(f"{VOLUME_PATH}/_checkpoints/bronze_stream/commits"))
# WHY this matters: if 'offsets' has an entry that 'commits' does not, that
# batch was READ but never fully WRITTEN - the exact signature of an
# interrupted micro-batch. A healthy stream has a 1:1 match between the two.

# COMMAND ----------
# ---- After Module 02, Part D (schema evolution) -----------------------------
# CHECK: any rows carrying _rescued_data mean something didn't fit the
# expected schema - always worth a look even if the load "succeeded".
rescued = spark.table(f"{CATALOG}.{SCHEMA}.bronze_transactions_stream") \
    .filter("_rescued_data IS NOT NULL") if \
    "_rescued_data" in spark.table(f"{CATALOG}.{SCHEMA}.bronze_transactions_stream").columns else None
if rescued is not None:
    print("Rows with rescued data:", rescued.count())
    display(rescued)
else:
    print("No _rescued_data column present (schemaEvolutionMode was addNewColumns, not rescue).")

# COMMAND ----------
# ---- After Module 03 (Lakeflow pipeline) ------------------------------------
# CHECK: the pipeline event log - filter to flow_progress events and look at
# EVERY expectation's passed/failed counts, not just whether the run succeeded.
# (Replace <pipeline_name> with your actual pipeline's name/id.)
# SELECT * FROM event_log(TABLE(catalog.schema.<pipeline_name>))
# WHERE event_type = 'flow_progress'
# ORDER BY timestamp DESC;
print("See commented query above - run against your actual pipeline name.")

# COMMAND ----------
# ---- After Module 02, Part E (idempotent snapshot + audit) ------------------
# CHECK: a CROSS-TABLE consistency check - the audit log's row_count per batch
# should equal the actual number of rows in the snapshot table for that batch.
# This is a genuinely useful reusable pattern: two independently-written
# tables should agree, and if they don't, something is inconsistent.
snap = spark.table(f"{CATALOG}.{SCHEMA}.silver_transactions_snapshot")
audit = spark.table(f"{CATALOG}.{SCHEMA}.audit_log")
print("Total snapshot rows:", snap.count())
print("Sum of audit-logged row counts:", audit.selectExpr("sum(row_count) as total").collect()[0]["total"])
# If these two numbers ever disagree, that is a real, actionable signal that
# a batch partially committed - the exact scenario Part E was built to prevent.

# COMMAND ----------
# =============================================================================
#  PART B - a tour of the relevant SYSTEM TABLES
# =============================================================================
# WHY system tables: they are Databricks-hosted, queryable, ACCOUNT-WIDE logs
# of what happened - separate from any one table's own DESCRIBE HISTORY.
# Requires Unity Catalog; some require being enabled by an admin first.

# ---- system.access.audit : who did what, account-wide -----------------------
# WHY: this is the account's audit trail - every workspace action, not just
# table writes. Good for "who ran this notebook / created this table".
spark.sql("""
  SELECT event_time, user_identity.email, action_name, request_params
  FROM system.access.audit
  WHERE event_date >= current_date() - INTERVAL 1 DAY
  ORDER BY event_time DESC
  LIMIT 20
""").show(truncate=False)

# COMMAND ----------
# ---- system.access.table_lineage : what fed what -----------------------------
# WHY: NOTE - system.lineage and system.operational_data are DEPRECATED
# (now empty). table_lineage / column_lineage are the CURRENT replacements.
spark.sql(f"""
  SELECT source_table_full_name, target_table_full_name, event_time, entity_type
  FROM system.access.table_lineage
  WHERE target_table_full_name = '{CATALOG}.{SCHEMA}.bronze_transactions_stream'
  ORDER BY event_time DESC
  LIMIT 20
""").show(truncate=False)

# COMMAND ----------
# ---- system.query.history : every query that ran, and how it performed -----
spark.sql("""
  SELECT start_time, statement_text, execution_status, total_duration_ms
  FROM system.query.history
  WHERE start_time >= current_date() - INTERVAL 1 DAY
  ORDER BY start_time DESC
  LIMIT 20
""").show(truncate=False)

# COMMAND ----------
# ---- system.billing.usage : cost / DBU consumption behind these runs -------
spark.sql("""
  SELECT usage_date, sku_name, usage_quantity
  FROM system.billing.usage
  WHERE usage_date >= current_date() - INTERVAL 1 DAY
  ORDER BY usage_date DESC
  LIMIT 20
""").show(truncate=False)
# NOTE: several system tables (data_quality_monitoring, data_classification)
# are Public Preview/Beta and may need enabling by a workspace admin before
# they return data - verify availability rather than assume.

# COMMAND ----------
# =============================================================================
#  PART C - checkpoint deleted, SAME txnAppId: built empirically
# =============================================================================
# HONESTY NOTE: Databricks' own documentation is NOT fully consistent on this
# exact scenario. One page says a checkpoint reset with the same txnAppId
# causes writes to be "applied... multiple times" (duplication). Another says
# they "will be ignored" (silent skip). Reasoning through the actual
# mechanism: Delta's check is purely "have I committed (txnAppId, thisVersion)
# before?" - and a fresh checkpoint restarts batch numbering at 0, so if the
# OLD run also had a batch 0 under the SAME txnAppId, Delta will recognize
# that (appId, 0) pair as already-seen and SKIP it - even though the actual
# file contents this time may differ. Because batch boundaries are not
# guaranteed identical across separate checkpoint lifetimes, the safest
# summary is: the outcome is NOT clean or predictable - it can even be a MIX
# (some batches skipped that shouldn't be, others written that create
# duplicates) depending on how the new run's batches happen to number
# against the old ones. Rather than assert one outcome, RUN this and see.

CATALOG_C = CATALOG; SCHEMA_C = SCHEMA
spark.sql(f"CREATE TABLE IF NOT EXISTS {CATALOG_C}.{SCHEMA_C}.checkpoint_test "
          f"(batch_id BIGINT, value STRING) USING DELTA")
spark.sql(f"DELETE FROM {CATALOG_C}.{SCHEMA_C}.checkpoint_test")  # clean slate

CKPT_1 = f"{VOLUME_PATH}/_checkpoints/ckpt_test_run1"
dbutils.fs.rm(CKPT_1, recurse=True)
FIXED_APP_ID = "checkpoint_experiment"   # deliberately kept the SAME across both runs below

def write_test_batch(batchDF, batchId):
    (batchDF.selectExpr(f"{batchId} as batch_id", "CAST(value AS STRING) as value")
        .write.format("delta")
        .option("txnVersion", batchId).option("txnAppId", FIXED_APP_ID)
        .mode("append").saveAsTable(f"{CATALOG_C}.{SCHEMA_C}.checkpoint_test"))

# RUN 1: process 5 rows via the rate source, using checkpoint #1
(spark.readStream.format("rate").option("rowsPerSecond", 5).load()
    .writeStream.foreachBatch(write_test_batch)
    .option("checkpointLocation", CKPT_1)
    .trigger(availableNow=True).start().awaitTermination())

print("After RUN 1:", spark.table(f"{CATALOG_C}.{SCHEMA_C}.checkpoint_test").count(), "rows")

# COMMAND ----------
# RUN 2: DELETE the checkpoint, keep the SAME FIXED_APP_ID, run again
CKPT_2 = f"{VOLUME_PATH}/_checkpoints/ckpt_test_run2"   # a fresh checkpoint path
dbutils.fs.rm(CKPT_2, recurse=True)

(spark.readStream.format("rate").option("rowsPerSecond", 5).load()
    .writeStream.foreachBatch(write_test_batch)
    .option("checkpointLocation", CKPT_2)               # NEW checkpoint
    .trigger(availableNow=True).start().awaitTermination())

print("After RUN 2 (new checkpoint, SAME txnAppId):",
      spark.table(f"{CATALOG_C}.{SCHEMA_C}.checkpoint_test").count(), "rows")
# READ THE RESULT: if the count did NOT grow, RUN 2's batch 0 was skipped as a
# duplicate (the 'ignored' behavior). If it DID grow by the full new amount,
# no skip occurred for this run's batch boundaries (the 'duplicated much
# happen differently' case did not trigger here). Either way, you now have
# EVIDENCE from your own environment instead of conflicting doc claims.

# COMMAND ----------
# THE CORRECT RECOVERY: new checkpoint AND a DIFFERENT txnAppId
CKPT_3 = f"{VOLUME_PATH}/_checkpoints/ckpt_test_run3"
dbutils.fs.rm(CKPT_3, recurse=True)
DIFFERENT_APP_ID = "checkpoint_experiment_v2"

def write_test_batch_v2(batchDF, batchId):
    (batchDF.selectExpr(f"{batchId} as batch_id", "CAST(value AS STRING) as value")
        .write.format("delta")
        .option("txnVersion", batchId).option("txnAppId", DIFFERENT_APP_ID)
        .mode("append").saveAsTable(f"{CATALOG_C}.{SCHEMA_C}.checkpoint_test"))

(spark.readStream.format("rate").option("rowsPerSecond", 5).load()
    .writeStream.foreachBatch(write_test_batch_v2)
    .option("checkpointLocation", CKPT_3)
    .trigger(availableNow=True).start().awaitTermination())

print("After RUN 3 (new checkpoint, DIFFERENT txnAppId):",
      spark.table(f"{CATALOG_C}.{SCHEMA_C}.checkpoint_test").count(), "rows")
# THIS is the documented-consistently-safe path: a genuinely new txnAppId has
# no prior (appId, version) history anywhere, so nothing is spuriously
# skipped, and nothing from the old app_id's history conflicts with it.

# COMMAND ----------
# =============================================================================
#  PART D - the small-file problem: created, measured, then fixed
# =============================================================================
sfp_table = f"{CATALOG}.{SCHEMA}.small_file_demo"
spark.sql(f"DROP TABLE IF EXISTS {sfp_table}")

import time
# WHY a loop of tiny writes: this deliberately creates the small-file problem
# (one file per write) instead of letting Optimized Writes prevent it.
spark.conf.set("spark.databricks.delta.optimizeWrite.enabled", "false")  # OFF, on purpose
for i in range(40):
    spark.range(5).selectExpr("id", f"'{i}' as batch_tag") \
        .write.format("delta").mode("append").saveAsTable(sfp_table)

file_count_before = spark.sql(f"DESCRIBE DETAIL {sfp_table}").select("numFiles").collect()[0][0]
print("Files BEFORE compaction:", file_count_before, "(one per tiny write - the problem, created on purpose)")

t0 = time.time()
spark.table(sfp_table).count()
print("Query time BEFORE compaction: %.3f s" % (time.time() - t0))

# COMMAND ----------
spark.sql(f"OPTIMIZE {sfp_table}")
file_count_after = spark.sql(f"DESCRIBE DETAIL {sfp_table}").select("numFiles").collect()[0][0]
print("Files AFTER OPTIMIZE:", file_count_after)

t0 = time.time()
spark.table(sfp_table).count()
print("Query time AFTER compaction: %.3f s" % (time.time() - t0))
# On a tiny demo table the timing difference will be small in absolute terms,
# but the FILE COUNT drop (40+ -> typically 1) is the real, structural proof -
# at real data volumes, that file-count reduction is what saves the minutes.

spark.conf.set("spark.databricks.delta.optimizeWrite.enabled", "true")  # restore

# COMMAND ----------
# =============================================================================
#  PART E - a Kafka-SHAPED streaming source, simulated via `rate`
# =============================================================================
# WHY simulate rather than connect: this sandbox has no real Kafka broker.
# `rate` generates a genuine continuous stream (timestamp + incrementing
# value), which is the standard, documented way to test streaming CODE and
# TRIGGER behavior without real streaming infrastructure.
#
# For REFERENCE - the real Kafka reader looks like this (not runnable here):
#   spark.readStream.format("kafka")
#     .option("kafka.bootstrap.servers", "broker1:9092,broker2:9092")
#     .option("subscribe", "transactions-topic")
#     .option("startingOffsets", "latest")
#     .load()
#
# IMPORTANT DELIVERY-GUARANTEE NUANCE, confirmed from documentation:
# Delta and file SINKS support exactly-once writes. Kafka and foreach SINKS
# only provide AT-LEAST-ONCE delivery - if you write TO Kafka (not just read
# from it), or use plain .foreach() instead of .foreachBatch(), YOU must
# handle deduplication yourself; Spark's own guarantee is weaker there.

import time as _time
from pyspark.sql.functions import col

rate_stream = spark.readStream.format("rate").option("rowsPerSecond", 10).load()

CKPT_KAFKA_SIM = f"{VOLUME_PATH}/_checkpoints/kafka_sim"
dbutils.fs.rm(CKPT_KAFKA_SIM, recurse=True)

# WHY processingTime trigger HERE specifically: every other module in this
# project used trigger(availableNow=True) - process what's there, then stop.
# A real Kafka topic is continuously arriving, so the realistic trigger is
# processingTime - "check for new data every N seconds, indefinitely" - this
# is genuinely different behavior worth seeing at least once.
query = (rate_stream.writeStream
    .format("delta")
    .option("checkpointLocation", CKPT_KAFKA_SIM)
    .trigger(processingTime="5 seconds")
    .toTable(f"{CATALOG}.{SCHEMA}.kafka_sim_stream"))

_time.sleep(17)   # let it run through ~3 trigger cycles
query.stop()       # then stop it explicitly - a continuous trigger never
                    # stops on its own, unlike availableNow

print("Rows captured from the simulated continuous stream:",
      spark.table(f"{CATALOG}.{SCHEMA}.kafka_sim_stream").count())
print("Last progress:", query.lastProgress)
# lastProgress shows numInputRows, processedRowsPerSecond, durations per
# trigger - the SAME metrics object you would read for a real Kafka source.

# COMMAND ----------
# =============================================================================
#  PART F - reusable END-OF-INGESTION sanity check
# =============================================================================
# WHY one function: this is the "did anything silently go wrong" gate to run
# after ANY load, checking the specific non-conformance types this project
# has covered - rescued data, unexpected schema drift, and row-count gaps
# that indicate a silent partial failure.
def ingestion_sanity_check(table_fqn, expected_min_rows=None, known_good_columns=None):
    """Run after any ingestion. Prints PASS/FAIL for each check; returns True
    only if every check passes."""
    ok = True
    df = spark.table(table_fqn)
    cols = df.columns

    print(f"--- Sanity check: {table_fqn} ---")

    # 1) rescued data present?
    if "_rescued_data" in cols:
        n = df.filter("_rescued_data IS NOT NULL").count()
        status = "FAIL" if n > 0 else "PASS"
        if n > 0: ok = False
        print(f"[{status}] rescued rows: {n}")
    else:
        print("[SKIP] no _rescued_data column on this table")

    # 2) schema drift vs a known-good column list
    if known_good_columns is not None:
        unexpected = set(cols) - set(known_good_columns) - {"_rescued_data"}
        missing    = set(known_good_columns) - set(cols)
        status = "FAIL" if (unexpected or missing) else "PASS"
        if unexpected or missing: ok = False
        print(f"[{status}] unexpected columns: {unexpected or 'none'} | missing: {missing or 'none'}")

    # 3) row-count floor - catches a SILENT partial load (fewer rows than expected)
    if expected_min_rows is not None:
        n = df.count()
        status = "PASS" if n >= expected_min_rows else "FAIL"
        if n < expected_min_rows: ok = False
        print(f"[{status}] row count: {n} (expected at least {expected_min_rows})")

    # 4) latest write operation, for a human to eyeball
    last_op = spark.sql(f"DESCRIBE HISTORY {table_fqn} LIMIT 1").collect()[0]
    print(f"[INFO] last operation: {last_op['operation']} at {last_op['timestamp']}")

    print("RESULT:", "PASS" if ok else "FAIL")
    return ok

# example usage against Module 02's stream table:
ingestion_sanity_check(
    f"{CATALOG}.{SCHEMA}.bronze_transactions_stream",
    expected_min_rows=9,
    known_good_columns=["transaction_id","customer_id","amount","transaction_date","status","channel"],
)

# COMMAND ----------
# =============================================================================
#  PART G - failure scenarios NOT safely simulable here, documented anyway
# =============================================================================
# WHY listed rather than demoed: some failures need real infrastructure
# (a cluster to actually kill, a disk to actually fill) that a shared sandbox
# cannot safely reproduce. Each one below states HOW you would detect it in a
# real workspace, so nothing on your list is just skipped.
#
# 1. CLUSTER/SPOT-INSTANCE EVICTION mid-batch
#    Detect: DESCRIBE HISTORY shows a gap (a batch number never committed);
#    checkpoint's offsets/commits mismatch (Part A, check 2).
#
# 2. SOURCE FILE UNREADABLE (corrupt compression, truncated download)
#    Detect: the job fails immediately with a read error (not a row-level
#    rescue) - visible in the job/notebook run's own error output, and in
#    system.access.audit / job run tables if run as a scheduled Job.
#
# 3. DOWNSTREAM PERMISSION REVOKED mid-stream (a grant removed while running)
#    Detect: the next micro-batch fails with PERMISSION_DENIED; visible in
#    the streaming query's exception, and in system.access.audit as a
#    permission-check event.
#
# 4. STORAGE QUOTA / CLOUD LIMIT EXCEEDED
#    Detect: write fails with a cloud-provider storage error; surfaces in
#    job run logs; cost/usage spikes may show first in system.billing.usage.
#
# 5. CONCURRENT WRITER CONFLICT (two jobs writing to the same table at once)
#    Detect: a ConcurrentModificationException; DESCRIBE HISTORY shows one
#    writer's version succeeding and the other retrying or failing - visible
#    directly in that job's run output.
#
# 6. CHECKPOINT-INCOMPATIBLE CODE CHANGE (changing source type, or Kafka
#    topic/Auto Loader path, while REUSING an old checkpoint)
#    Not allowed - the restarted query fails outright with an unpredictable
#    error rather than silently misbehaving. Detect: query fails to start;
#    error names the incompatible change.
#
# 7. AT-LEAST-ONCE SINKS (writing TO Kafka, or using .foreach() not
#    .foreachBatch()) can duplicate on retry EVEN WITH a checkpoint - Spark's
#    own guarantee is weaker for these sinks (see Part E note). Detect: build
#    your own dedup key and check for it; Delta's txnAppId/txnVersion does
#    NOT apply to a Kafka sink.
#
# 8. "FIXING" A STUCK STREAM by changing startingOffsets on an EXISTING
#    checkpoint. This does NOT do what people expect - Spark resumes from the
#    checkpoint's recorded offsets regardless, and starting fresh at 'latest'
#    silently DISCARDS the backlog - a data-loss decision, not a performance
#    fix. Detect: compare expected vs actual row counts after any offset
#    change (Part F's row-count-floor check).
print("Part G is documentation only - no cells to run.")
