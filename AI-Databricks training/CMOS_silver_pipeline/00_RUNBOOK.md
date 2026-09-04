# CMOS POC — load CSVs into SILVER via an Auto Loader pipeline

Flow:  CSV files  →  UC Volume (landing)  →  Auto Loader stream  →  RAW (all STRING)  →  typed load  →  SILVER (your real DDL types)

This builds a *real* streaming pipeline (checkpoints + lineage), not a one-off load — so Databricks records lineage that Genie can later read.

---
## 0. Prerequisites
- A Databricks workspace with Unity Catalog + a running **cluster or SQL warehouse** (Auto Loader needs a cluster/serverless, not just SQL warehouse — run steps 1–3 as a **Python notebook**).
- Pick your names. Edit the three variables at the top of each notebook:
  - `CAT`    = your catalog (on a private instance this is often `workspace`, or your UC catalog name)
  - `SILVER` = `cmos_core`
  - `RAW`    = `cmos_core_raw`
- **Do NOT run this against a catalog that holds real production `cmos_core` data** — it DROPs/TRUNCATEs the 12 tables. Use your private instance / a POC catalog.

## 1. Create schemas + silver tables  —  run `01_create_silver_tables.py`
Creates the `RAW` and `SILVER` schemas, a **Volume** `RAW.landing`, and the 12 silver tables using your **exact DDL** (real types, partitions, comments). Set the cell language to Python (`%python`).

## 2. Upload the CSVs to the Volume
Put each file under a folder named after the table:
```
/Volumes/<CAT>/cmos_core_raw/landing/agreements/agreements.csv
/Volumes/<CAT>/cmos_core_raw/landing/trades/trades.csv
... one folder per table ...
```
Upload via: Catalog UI → Volumes → landing → create folder `<table>` → upload the CSV, **or** CLI:
```
databricks fs cp agreements.csv dbfs:/Volumes/<CAT>/cmos_core_raw/landing/agreements/agreements.csv
```
(One folder per table — Auto Loader watches each folder.)

## 3. Stream CSV → RAW  —  run `02_autoloader_raw.py`
Auto Loader reads each folder and writes an all-STRING raw table `RAW.<table>`.
- `cloudFiles.inferColumnTypes=false` keeps RAW as strings (mirrors "lands as text").
- `trigger(availableNow=True)` processes what's there and stops (one-shot, still a real stream with a checkpoint).
- Directory-listing mode is used (no cloud file-notification/event setup needed — works on managed storage).

## 4. Typed load RAW → SILVER  —  run `03_silver_typed_load.py`
`INSERT ... SELECT CAST(col AS <type>)` per your DDL. Columns present in the DDL but absent from a CSV are `CAST(NULL AS <type>)` (e.g. agreements has 1 such column). `reporting_date` / `reporting_day` cast from string to DATE drives the partitioning.

## 5. Verify
```sql
SELECT 'agreements' t, COUNT(*) FROM <CAT>.cmos_core.agreements
UNION ALL SELECT 'daily_exposure', COUNT(*) FROM <CAT>.cmos_core.daily_exposure;
-- key-wiring sanity (should mirror real: ext ~100%, agreement_id ~0%)
SELECT COUNT(*) rows,
  SUM(CASE WHEN f.external_id  IN (SELECT external_id  FROM <CAT>.cmos_core.agreements) THEN 1 ELSE 0 END) ext_match,
  SUM(CASE WHEN f.agreement_id IN (SELECT agreement_id FROM <CAT>.cmos_core.agreements) THEN 1 ELSE 0 END) aid_match
FROM <CAT>.cmos_core.daily_exposure f;
```

---
## Alternative (all-SQL, no Python): COPY INTO
If you can't run a Python notebook, skip Auto Loader and load straight to silver with `COPY INTO` (batch Auto Loader). Per table:
```sql
COPY INTO <CAT>.cmos_core.agreements
FROM '/Volumes/<CAT>/cmos_core_raw/landing/agreements/'
FILEFORMAT = CSV
FORMAT_OPTIONS ('header'='true','inferSchema'='false','nullValue'='')
COPY_OPTIONS ('mergeSchema'='false');
```
`COPY INTO` casts strings to the target column types on load. It's simpler but does **not** create the raw layer or the streaming lineage — so prefer the Python pipeline if you want the lineage signal for Genie.

---
## What this gives the POC
- Silver tables with your **real types**, real keys, and the preserved ambiguities (44×-style snapshot grain over 5 dates, agreement_id-dead / external_id-live, null/XXXX contamination).
- A **raw → silver lineage** graph in Unity Catalog (from the streaming write) — a signal Genie can later read.
- Ready to point a Genie space at `cmos_core` and run the ★ baseline test (which key does Genie join on).
