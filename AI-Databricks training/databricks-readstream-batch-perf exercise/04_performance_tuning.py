# Databricks notebook source
# =============================================================================
#  04 - PERFORMANCE: settings for faster WRITES and faster READS
# =============================================================================
#  SCOPE NOTE: this covers the tuning knobs that are quick to demonstrate and
#  don't need a deep separate topic. Z-ORDER and LIQUID CLUSTERING are
#  deliberately NOT covered in depth here - you flagged wanting a dedicated
#  session on those, so this file only names them at the end so you're not
#  blind if asked, without pretending to cover them properly.
# =============================================================================

# COMMAND ----------
CATALOG = "workspace"
SCHEMA  = "default"
TABLE   = f"{CATALOG}.{SCHEMA}.bronze_transactions_batch"   # reuse Module 02's table

# COMMAND ----------
# =============================================================================
#  PART A - WRITE performance: the small-file problem, and how to avoid it
# =============================================================================
# THE CORE PROBLEM to understand first: every write from a distributed engine
# like Spark tends to produce MANY small files (one per task/partition). Lots
# of tiny files slow down BOTH future writes (more file listing/metadata
# overhead) and reads (more files to open). Almost every write-speed setting
# below exists to fight this one problem.

# ---- 1. Optimized Writes: right-size files DURING the write itself --------
# WHY: instead of writing whatever size each task happens to produce, Spark
# adds a shuffle stage that repartitions data to hit a target file size
# (historically ~128MB) before writing. Costs a bit of shuffle time up front;
# usually pays for itself in fewer, bigger, healthier files.
spark.conf.set("spark.databricks.delta.optimizeWrite.enabled", "true")

# ---- 2. Auto Compaction: right-size files AFTER the write completes -------
# WHY: runs a background compaction job immediately after a write succeeds,
# coalescing small files into larger ones. Complementary to Optimized Writes,
# not a replacement for either it or manual OPTIMIZE.
spark.conf.set("spark.databricks.delta.autoCompact.enabled", "true")

# ---- 3. Set both at the TABLE level too (persists regardless of session) --
spark.sql(f"""
  ALTER TABLE {TABLE} SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
  )
""")

# ---- 4. Target file size: tell Delta what "right-sized" means -------------
# WHY explicit: without this, Delta picks an adaptive default. Setting it
# explicitly is useful when you know your workload (e.g. many small lookups
# vs. big scans want different target sizes).
spark.sql(f"""
  ALTER TABLE {TABLE} SET TBLPROPERTIES (
    'delta.targetFileSize' = '134217728'   -- 128 MB, a common default target
  )
""")
print("Optimized writes + auto compact + target file size configured.")

# COMMAND ----------
# ---- 5. Manual bin-packing: OPTIMIZE ---------------------------------------
# WHY: optimizeWrite/autoCompact happen automatically around writes, but
# OPTIMIZE is the on-demand, explicit compaction command - run it any time
# file health has degraded (e.g. after many small streaming micro-batches).
spark.sql(f"OPTIMIZE {TABLE}")
print("Manual OPTIMIZE run.")

# COMMAND ----------
# ---- 6. Right-size BEFORE a batch write, when you control the DataFrame ---
# WHY: if you're doing a one-off batch write of a DataFrame you built
# yourself (not a stream), you can just repartition it to a sensible number
# of partitions before writing, rather than relying on Delta's post-hoc
# fixes. Rule of thumb: aim for partitions that will each become a
# reasonably-sized file (not 1 giant partition, not 500 tiny ones).
df = spark.table(TABLE)
print("Partitions before repartition:", df.rdd.getNumPartitions())
df_right_sized = df.repartition(4)   # tune this number to your actual data volume
print("Partitions after repartition:", df_right_sized.rdd.getNumPartitions())

# COMMAND ----------
# =============================================================================
#  PART B - READ performance: help the query engine skip work
# =============================================================================

# ---- 1. Partition pruning: physically separate data by a commonly-filtered
#         column, so queries that filter on it can skip whole folders ------
# WHY transaction_date: if most queries filter "give me last week's
# transactions", partitioning by date means Spark never even opens the files
# for other dates.
spark.sql(f"""
  CREATE TABLE IF NOT EXISTS {CATALOG}.{SCHEMA}.transactions_partitioned
  USING DELTA
  PARTITIONED BY (transaction_date)
  AS SELECT * FROM {TABLE}
""")
print("Created a date-partitioned copy for comparison.")
# CAVEAT: partitioning is a trade-off, not a free win - too many small
# partitions (e.g. partitioning by a high-cardinality column) recreates the
# small-file problem PER partition. Use it for columns with a reasonable,
# bounded number of distinct values that queries actually filter on.

# COMMAND ----------
# ---- 2. Data skipping: Delta automatically tracks min/max stats per file --
# WHY dataSkippingNumIndexedCols: Delta collects min/max statistics for the
# FIRST N columns of a table (default 32) automatically, at write time, with
# no extra command. The query engine uses these to skip files that can't
# possibly contain a match for a filter (e.g. "amount > 1000" skips any file
# whose max amount is 500). Column ORDER matters - put your most-filtered
# columns first, or raise this setting if you have many useful columns.
spark.sql(f"""
  ALTER TABLE {TABLE} SET TBLPROPERTIES (
    'delta.dataSkippingNumIndexedCols' = '32'
  )
""")
print("Data skipping is automatic; this just confirms how many columns are indexed for it.")

# COMMAND ----------
# ---- 3. Keep the query optimizer informed: table statistics ---------------
# WHY: ANALYZE TABLE computes column-level statistics (row counts, distinct
# counts) that the query planner uses to choose good join strategies and
# scan orders - separate from Delta's automatic file-level min/max stats.
spark.sql(f"ANALYZE TABLE {TABLE} COMPUTE STATISTICS FOR ALL COLUMNS")
print("Table statistics computed for the query optimizer.")

# COMMAND ----------
# ---- 4. Column pruning: select only what you need -------------------------
# WHY this is a "read speed setting" too, even though it looks like habit:
# Delta/Parquet is COLUMNAR - reading fewer columns means reading less data
# off disk, not just less data returned to you. SELECT * defeats this.
display(spark.table(TABLE).select("transaction_id", "amount"))   # cheap
# vs
display(spark.table(TABLE))                                       # reads every column

# COMMAND ----------
# =============================================================================
#  PARKED FOR A DEDICATED SESSION: Liquid Clustering and Z-Ordering
# =============================================================================
# Both exist to solve the SAME problem: making file-skipping effective on
# columns you filter on OFTEN, beyond what partitioning alone can do -
# Z-ORDER co-locates similar values within files for a table you run OPTIMIZE
# on; Liquid Clustering is the newer, more flexible mechanism that manages
# this automatically without a rigid partition scheme. Both deserve a
# focused session with real query-latency before/after comparisons rather
# than a bullet point here - noted as the next topic, as you planned.
print("Liquid clustering / Z-order: intentionally out of scope for this prototype.")
