# Glossary + Profiler — setup and run guide

This covers the four files that make up the glossary-driven metadata profiler:

| File | What it is | Where it goes |
|---|---|---|
| `create_glossary_table.sql` | Creates the glossary Delta table + seeds all terms | run once in a SQL editor |
| `glossary_load` (`.py` notebook) | Loads the glossary CSV from a Volume into the Delta table | Databricks notebook |
| `glossary_match` (`.py` notebook) | The name→glossary matcher; `%run` companion module | Databricks notebook, **same folder as the profiler** |
| `profiler_databricks_notebook` (`.py`) | The metadata profiler; calls the matcher in profile mode | Databricks notebook |

The single artifact **you** maintain is the glossary (the `credit_risk_abbreviations.csv` → `credit_risk_glossary` Delta table). Everything else reads from it.

---

## One-time setup

### 1. Create the glossary table

Run `create_glossary_table.sql` in a SQL editor. It creates
`` `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`credit_risk_glossary` `` and seeds every term via `INSERT OVERWRITE`.

- The hyphenated catalog means **every identifier is backtick-quoted** — already done in the file.
- If you want a different schema, find/replace the schema name at the top of the file.
- Re-running it is safe: `INSERT OVERWRITE` swaps the rows but keeps the table definition and comments.

### 2. (Repeatable path) Load the glossary from a Volume

Once your CSV is the master copy, use `glossary_load` instead of editing SQL:

1. Drop `credit_risk_abbreviations.csv` into a Volume.
2. Open `glossary_load`, set the `csv_path` widget to that Volume path.
3. Run all. It reads the CSV and `INSERT OVERWRITE`s the table (definition/comments preserved), then prints the per-domain term count.

Use **either** the SQL **or** the loader to refresh — they do the same thing. The loader is the one to keep for ongoing edits.

### 3. Put the matcher next to the profiler

Import `glossary_match` and `profiler_databricks_notebook` into the **same workspace folder**. The profiler calls the matcher with `%run ./glossary_match`; if they live in different folders, change that path in the profiler's "Glossary matcher" cell.

---

## Running the profiler

Open `profiler_databricks_notebook`, set the widgets, run all.

**Cluster requirement:** run on **Serverless** or a **Standard/Dedicated Unity-Catalog cluster**. A plain shared cluster without UC credential vending will throw 403 on `_delta_log` reads.

### Widgets

| Widget | Default | Notes |
|---|---|---|
| `catalog` | `d4001-centralus-tdvip-creditrisk` | hyphenated → quoted internally |
| `schema` | `xvala_xva` | schema to profile |
| `tables` | `asts,ats_summary` | blank = whole schema; comma list = several |
| `mode` | `profile` | `profile` \| `diff` \| `apply` |
| `sample_size` | `50000` | rows pulled to the driver for value inference |
| `apply_dry_run` | `true` | apply mode prints DDL without executing |
| `results_location` | `<catalog>.` | append a schema to persist results as Delta |
| `use_glossary` | `true` | attach proposed definitions from the glossary |
| `glossary_schema` | `xvala_core` | where the glossary table lives |
| `glossary_table` | `credit_risk_glossary` | |
| `glossary_status` | *(blank)* | set to `approved` later to match only signed-off terms |

### Modes

- **profile** — proposes types, dates, enums, keys, anomalies, **and** (via the matcher) per-column `canonical_term` + `business_definition` + `column_role` + `glossary_token` + `product_class`/`party`/`im_vm`. Writes to `profiler_proposals` if `results_location` is set. Nothing is changed on the source tables.
- **diff** — compares the proposal against the current Unity Catalog schema.
- **apply** — writes **safe metadata** to the source tables: column comments (the business definition), the standards tags it can populate (see the alignment doc), and informational PRIMARY KEY where a valid dup-free key exists. Type changes and physical renames are **printed as `-- MANUAL` DDL**, never auto-run. `apply_dry_run=true` prints everything without executing.

### What persists (when `results_location` is set)

Four Delta tables, each stamped with `run_ts`: `profiler_proposals`, `profiler_keys`, `profiler_anomalies`, `profiler_runlog`.

---

## The loop, in one line

You maintain the glossary table. **profile** mode reads it and proposes per-column business metadata into `profiler_proposals`. You review. **apply** mode writes the approved definition as the column comment plus the standards-aligned tags.

## Editing the glossary later

Edit `credit_risk_abbreviations.csv`, re-run `glossary_load` (or the SQL). The matcher picks up new terms/aliases on the next profiler run automatically — no profiler change needed. Tune matching behaviour (tokenizer, synonyms, product-class capture) in `glossary_match` only; the profiler doesn't change for that.

## Governance note

Set `glossary_status` to `approved` once you start signing off terms (the CSV `status` column). Until then it matches all `draft` terms so you can see coverage while building.
