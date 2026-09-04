# Databricks notebook — STEP 2: Auto Loader streams each CSV -> RAW (all strings)
# PREREQ: upload each CSV to /Volumes/{CAT}/{RAW}/landing/<table>/<table>.csv (see runbook)

CAT="workspace"; SILVER="cmos_core"; RAW="cmos_core_raw"
base = f"/Volumes/{CAT}/{RAW}/landing"
tables = ["agreements", "organization", "trades", "repo_trades", "daily_exposure", "repo_daily_exposure", "disputes", "settlement_instructions", "collateral_eligibility", "asset_holdings", "asset_settlements", "fx_rates"]

for t in tables:
    src  = f"{base}/{t}"
    chk  = f"{base}/_checkpoints/{t}"
    (spark.readStream.format("cloudFiles")
        .option("cloudFiles.format","csv")
        .option("header","true")
        .option("cloudFiles.inferColumnTypes","false")   # keep RAW all-STRING
        .option("cloudFiles.schemaLocation", chk)
        .load(src)
      .writeStream
        .option("checkpointLocation", chk)
        .trigger(availableNow=True)                       # one-shot batch, still a real stream
        .toTable(f"{CAT}.{RAW}.{t}"))
    print("streaming ->", t)

# wait for all availableNow streams to finish
for q in spark.streams.active: q.awaitTermination()
print("RAW load complete")
