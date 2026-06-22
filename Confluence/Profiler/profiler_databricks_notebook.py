# Databricks notebook source
# MAGIC %md
# MAGIC # Metadata Profiler — Databricks notebook
# MAGIC
# MAGIC Profiles one or more tables and proposes a governed schema (types, dates, enums, keys, comments),
# MAGIC flags anomalies, and can diff against — or apply to — Unity Catalog.
# MAGIC
# MAGIC **Parameters (widgets):**
# MAGIC - `catalog`, `schema` — required.
# MAGIC - `tables` — comma-separated list. **Leave blank to profile every table in the schema.**
# MAGIC - `mode` — `profile` (propose + anomalies) · `diff` (compare proposal vs Unity Catalog) · `apply` (ALTER the table).
# MAGIC - `sample_size` — rows pulled for value-pattern inference (default 50000).
# MAGIC - `apply_dry_run` — `true`/`false`; in `apply` mode, `true` only prints the DDL.
# MAGIC
# MAGIC **Assumptions for this run:** every column is treated as **nullable** (we do not assert NOT NULL).
# MAGIC Value-pattern inference (type/date/enum) uses **non-null, non-zero** representative values so a sample
# MAGIC that lands on 0/blank doesn't mislead the proposal.

# COMMAND ----------
dbutils.widgets.text("catalog", "d4001-centralus-tdvip-creditrisk", "Catalog")
dbutils.widgets.text("schema", "xvala_xva", "Schema")
dbutils.widgets.text("tables", "asts,ats_summary", "Tables (blank = whole schema)")
dbutils.widgets.dropdown("mode", "profile", ["profile", "diff", "apply"], "Mode")
dbutils.widgets.text("sample_size", "50000", "Sample size")
dbutils.widgets.dropdown("apply_dry_run", "true", ["true", "false"], "Apply: dry-run")
dbutils.widgets.text("results_location", "", "Results location catalog.schema (blank = print only)")

CATALOG = dbutils.widgets.get("catalog").strip()
SCHEMA  = dbutils.widgets.get("schema").strip()
TABLES  = [t.strip() for t in dbutils.widgets.get("tables").split(",") if t.strip()]
MODE    = dbutils.widgets.get("mode").strip()
SAMPLE  = int(dbutils.widgets.get("sample_size"))
DRYRUN  = dbutils.widgets.get("apply_dry_run").strip().lower() == "true"
RESULTS_LOCATION = dbutils.widgets.get("results_location").strip()
ASSUME_NULLABLE = True   # per current instruction

print("PARAMETERS")
print("  catalog        =", CATALOG)
print("  schema         =", SCHEMA)
print("  tables         =", TABLES or "(whole schema)")
print("  mode           =", MODE)
print("  sample_size    =", SAMPLE)
print("  apply_dry_run  =", DRYRUN)
print("  results_location =", RESULTS_LOCATION or "(print only — nothing persisted)")

# COMMAND ----------
# MAGIC %md ## Pure-Python detection helpers (no Spark — unit-tested below)

# COMMAND ----------
import re
from datetime import datetime

def log(msg):
    print(f"[{datetime.now():%H:%M:%S}] {msg}")

_THOUSANDS_NUM = re.compile(r'^[+-]?\d{1,3}(,\d{3})+(\.\d+)?$')   # 5,053  1,234.50
_PLAIN_NUM     = re.compile(r'^[+-]?\d+(\.\d+)?$')                # 5053   1234.50
_PLAIN_INT     = re.compile(r'^[+-]?\d+$')

# (name, regex, parse->datetime, spark expression on `col`)
_DATE_CANDIDATES = [
    ('YYYYMMDD',     r'^\d{8}$',                      lambda s: datetime.strptime(s, '%Y%m%d'),
        "to_date(CAST({col} AS STRING),'yyyyMMdd')"),
    ('YYYY-MM-DD',   r'^\d{4}-\d{2}-\d{2}$',          lambda s: datetime.strptime(s, '%Y-%m-%d'),
        "to_date({col},'yyyy-MM-dd')"),
    ('YYYY/MM/DD',   r'^\d{4}/\d{2}/\d{2}$',          lambda s: datetime.strptime(s, '%Y/%m/%d'),
        "to_date({col},'yyyy/MM/dd')"),
    ('MM/DD/YYYY',   r'^\d{1,2}/\d{1,2}/\d{4}$',      lambda s: datetime.strptime(s, '%m/%d/%Y'),
        "to_date({col},'M/d/yyyy')"),
    ('DD-MON-YYYY',  r'^\d{1,2}-[A-Za-z]{3}-\d{4}$',  lambda s: datetime.strptime(s, '%d-%b-%Y'),
        "to_date({col},'d-MMM-yyyy')"),
    ('ISO_TIMESTAMP', r'^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}',
        lambda s: datetime.strptime(s.replace('T', ' ')[:19], '%Y-%m-%d %H:%M:%S'),
        "to_timestamp({col},'yyyy-MM-dd HH:mm:ss')"),
]

def _clean(v):
    if v is None:
        return None
    s = str(v).strip()
    # normalize int-like floats: 20180531.0 -> 20180531
    if s.endswith('.0') and s[:-2].lstrip('+-').isdigit():
        s = s[:-2]
    return s

def is_blank_or_zero(v):
    """True for None, '', and any numeric (incl. comma-thousands) equal to zero."""
    s = _clean(v)
    if s is None or s == '':
        return True
    try:
        return float(s.replace(',', '')) == 0.0
    except ValueError:
        return False

def representative_values(values, cap=1000):
    """Distinct, non-null, non-zero values for type/format inference."""
    out, seen = [], set()
    for v in values:
        s = _clean(v)
        if s is None or s == '' or is_blank_or_zero(s):
            continue
        if s not in seen:
            seen.add(s); out.append(s)
            if len(out) >= cap:
                break
    return out

def numeric_text_profile(values):
    """Detect numbers stored as text, including thousands separators (5,053)."""
    n = num = comma = 0
    has_dec = False
    for s in values:
        s = _clean(s)
        if not s:
            continue
        n += 1
        if _THOUSANDS_NUM.match(s):
            num += 1; comma += 1
            has_dec = has_dec or ('.' in s)
        elif _PLAIN_NUM.match(s):
            num += 1
            has_dec = has_dec or ('.' in s)
    if n == 0:
        return {'is_numeric_text': False}
    frac = num / n
    if frac < 0.95:
        return {'is_numeric_text': False, 'numeric_fraction': round(frac, 3)}
    proposed = 'DECIMAL(38,6)' if has_dec else 'BIGINT'
    return {'is_numeric_text': True, 'numeric_fraction': round(frac, 3),
            'thousands_separator': comma > 0, 'proposed_type': proposed,
            'cast_expr': "TRY_CAST(REPLACE({col}, ',', '') AS %s)" % proposed}

def date_profile(values, col_name=''):
    """Detect dates even when stored as int (YYYYMMDD) or string; return format + Spark cast."""
    n = excel = 0
    hits = {}
    name_hint = bool(re.search(r'(date|_dt\b|\bdt_|expiry|matur|asof|as_of|effective|valu(e|ation)_d)', col_name, re.I))
    for s in values:
        s = _clean(s)
        if not s:
            continue
        n += 1
        for name, rgx, parse, _spk in _DATE_CANDIDATES:
            if re.match(rgx, s):
                try:
                    d = parse(s)
                    if 1900 <= d.year <= 2100:
                        hits[name] = hits.get(name, 0) + 1
                except Exception:
                    pass
        if _PLAIN_INT.match(s) and 20000 <= int(s) <= 60000:
            excel += 1
    if n == 0:
        return {'is_date': False}
    if hits:
        name, c = max(hits.items(), key=lambda kv: kv[1])
        if c / n >= 0.95:
            spk = dict((x[0], x[3]) for x in _DATE_CANDIDATES)[name]
            kind = 'TIMESTAMP' if name == 'ISO_TIMESTAMP' else 'DATE'
            return {'is_date': True, 'date_format': name, 'proposed_type': kind,
                    'spark_expr': spk, 'match_fraction': round(c / n, 3)}
    if name_hint and n and excel / n >= 0.95:
        return {'is_date': True, 'date_format': 'EXCEL_SERIAL', 'proposed_type': 'DATE',
                'spark_expr': "date_add('1899-12-30', CAST({col} AS INT))",
                'match_fraction': round(excel / n, 3), 'note': 'Excel serial (name-hinted)'}
    return {'is_date': False}

log("detection helpers ready: numeric_text_profile, date_profile, representative_values, is_blank_or_zero")

# COMMAND ----------
# MAGIC %md ## Self-test of the detection helpers

# COMMAND ----------
def _selftest():
    assert numeric_text_profile(["5,053", "1,234.50", "42"])["is_numeric_text"] is True
    assert numeric_text_profile(["5,053", "1,234.50", "42"])["thousands_separator"] is True
    assert numeric_text_profile(["5,053", "1,234.50", "42"])["proposed_type"] == "DECIMAL(38,6)"
    assert numeric_text_profile(["100", "200", "300"])["proposed_type"] == "BIGINT"
    assert numeric_text_profile(["abc", "12", "xyz"])["is_numeric_text"] is False
    assert date_profile(["20180531", "20110516"], "Line_Expiry")["date_format"] == "YYYYMMDD"
    assert date_profile(["2024-01-15", "2024-12-31"], "as_of")["date_format"] == "YYYY-MM-DD"
    assert date_profile(["46000", "46001"], "expiry_date")["date_format"] == "EXCEL_SERIAL"
    assert date_profile(["100", "200"], "amount")["is_date"] is False
    assert is_blank_or_zero("0") and is_blank_or_zero("") and is_blank_or_zero(None) and is_blank_or_zero("0.0")
    assert not is_blank_or_zero("5,053")
    assert representative_values([None, "0", "", "5,053", "5,053", "42"]) == ["5,053", "42"]
    print("helper self-test: PASSED")

_selftest()

# COMMAND ----------
# MAGIC %md ## Spark helpers

# COMMAND ----------
from pyspark.sql import functions as F

def bq(name):
    """Backtick-quote one identifier part (catalog has hyphens)."""
    return "`" + name.replace("`", "``") + "`"

def fqn(table):
    return ".".join(bq(p) for p in [CATALOG, SCHEMA, table])

def list_tables():
    if TABLES:
        return TABLES
    rows = spark.sql(f"SHOW TABLES IN {bq(CATALOG)}.{bq(SCHEMA)}").collect()
    return [r["tableName"] for r in rows if not r["isTemporary"]]

def table_stats(df, cols):
    """Full-table counts + null/distinct per column + full-row duplicate count."""
    row_count = df.count()
    distinct_rows = df.distinct().count()           # heavy on very wide/large tables; fine for blueprint
    dup_rows = row_count - distinct_rows
    aggs = []
    for c in cols:
        cc = F.col(bq(c))
        aggs += [F.count(cc).alias(c + "__nn"), F.approx_count_distinct(cc).alias(c + "__nd")]
    r = df.agg(*aggs).collect()[0] if aggs else {}
    stats = {}
    for c in cols:
        nn = r[c + "__nn"]; nd = r[c + "__nd"]
        stats[c] = {"non_null": nn, "null_count": row_count - nn,
                    "null_pct": round((row_count - nn) / row_count, 4) if row_count else 0.0,
                    "approx_distinct": nd}
    return row_count, dup_rows, stats

def exact_unique(df, c, row_count):
    """Null-aware uniqueness test per FR-3.8: count(col)=count(*) AND count(distinct col)=count(*)."""
    cc = F.col(bq(c))
    r = df.agg(F.count(cc).alias("nn"), F.countDistinct(cc).alias("nd")).collect()[0]
    return r["nn"] == row_count and r["nd"] == row_count

log("spark helpers ready: fqn, list_tables, table_stats, exact_unique")

# COMMAND ----------
# MAGIC %md ## Profile one table → proposals + anomalies

# COMMAND ----------
def profile_table(table):
    fq = fqn(table)
    log(f"--- profiling {fq}")
    df = spark.table(fq)
    fields = df.schema.fields
    cols = [f.name for f in fields]
    log(f"    schema resolved: {len(cols)} columns")

    # value-pattern inference uses a sample, pulled once to the driver
    log(f"    sampling up to {SAMPLE:,} rows to the driver ...")
    sample_pdf = df.limit(SAMPLE).toPandas()
    log(f"    sample pulled: {len(sample_pdf):,} rows")

    log("    computing full-table counts, nulls, distincts, duplicate rows ...")
    row_count, dup_rows, stats = table_stats(df, cols)
    log(f"    row_count={row_count:,}  duplicate_rows={dup_rows:,}")

    proposals, anomalies = [], []
    if dup_rows > 0:
        anomalies.append(f"{table}: {dup_rows} duplicate row(s) — no valid key as-loaded (keys are 'valid-after-dedup').")

    for f in fields:
        c = f.name
        cur_type = f.dataType.simpleString()
        st = stats[c]
        raw = sample_pdf[c].tolist() if c in sample_pdf.columns else []
        reps = representative_values([x for x in raw], cap=1000)
        zero_blank = sum(1 for x in raw if is_blank_or_zero(x))

        proposed_type, date_fmt, cast_expr, notes = cur_type, None, None, []

        # date detection (covers int YYYYMMDD, excel serial, string dates)
        dp = date_profile(reps, c)
        ntp = numeric_text_profile(reps)
        low_card = (st["approx_distinct"] <= 50 and st["non_null"] > st["approx_distinct"] * 3)

        if dp.get("is_date"):
            proposed_type = dp["proposed_type"]; date_fmt = dp["date_format"]
            cast_expr = dp["spark_expr"].format(col=bq(c))
            notes.append(f"date stored as {('int' if cur_type in ('int','bigint') else 'text')} → {date_fmt}")
        elif cur_type == "string" and ntp.get("is_numeric_text"):
            proposed_type = ntp["proposed_type"]
            cast_expr = ntp["cast_expr"].format(col=bq(c))
            notes.append("numeric stored as text" + (" with thousands separators" if ntp.get("thousands_separator") else ""))
        elif cur_type == "string" and low_card:
            notes.append("low-cardinality string → enum candidate")

        if st["null_pct"] >= 0.5:
            anomalies.append(f"{table}.{c}: {int(st['null_pct']*100)}% null.")
        if cast_expr:
            anomalies.append(f"{table}.{c}: {notes[-1]} — cast: {cast_expr}")

        enum_vals = sorted(reps)[:25] if (cur_type == "string" and low_card and not dp.get("is_date") and not ntp.get("is_numeric_text")) else None

        proposals.append({
            "table": table, "column": c,
            "current_type": cur_type, "proposed_type": proposed_type,
            "nullable": True,                                  # assume nullable for now
            "date_format": date_fmt, "cast_expr": cast_expr,
            "null_count": st["null_count"], "null_pct": st["null_pct"],
            "zero_or_blank": zero_blank, "approx_distinct": st["approx_distinct"],
            "enum_values": ", ".join(enum_vals) if enum_vals else None,
            "sample_values": ", ".join(map(str, reps[:5])),
            "notes": "; ".join(notes) or None,
        })

    # ---- dup/null-aware key detection (FR-3.7/3.8/3.9) ----
    key_report = []
    candidates = [p["column"] for p in proposals if p["approx_distinct"] >= row_count * 0.98 and row_count > 0]
    log(f"    key check: {len(candidates)} candidate column(s) to verify")
    for c in candidates:
        valid = exact_unique(df, c, row_count)
        verdict = ("valid" if valid and dup_rows == 0 else
                   "valid-after-dedup" if valid else "invalid")
        ctype = next(p["proposed_type"] for p in proposals if p["column"] == c)
        is_surrogate = ctype in ("BIGINT", "INT", "bigint", "int")
        key_report.append({"table": table, "column": c,
                           "key_kind": "surrogate?" if is_surrogate else "natural/alternate?",
                           "unique_nonnull": valid, "verdict": verdict})
        if is_surrogate and not valid:
            anomalies.append(f"{table}.{c}: looks like a surrogate key but is NOT unique/non-null — load defect.")
    if not candidates:
        anomalies.append(f"{table}: no single-column key candidate" + (" (duplicate rows present)" if dup_rows else "") + ".")

    log(f"    done {table}: {len(proposals)} columns, {len(anomalies)} anomaly note(s)")
    return {"table": table, "row_count": row_count, "dup_rows": dup_rows,
            "proposals": proposals, "key_report": key_report, "anomalies": anomalies}

log("profile_table() ready")

# COMMAND ----------
# MAGIC %md ## Unity Catalog current schema (for diff / apply)

# COMMAND ----------
def uc_current(table):
    """Current column types + comments from information_schema."""
    q = f"""SELECT column_name, full_data_type, comment
            FROM {bq(CATALOG)}.information_schema.columns
            WHERE table_schema = '{SCHEMA}' AND table_name = '{table}'"""
    out = {}
    for r in spark.sql(q).collect():
        out[r["column_name"]] = {"type": (r["full_data_type"] or "").lower(), "comment": r["comment"]}
    return out

log("uc_current() ready")

# COMMAND ----------
# MAGIC %md ## Run

# COMMAND ----------
tables_to_run = list_tables()
log(f"tables to profile: {tables_to_run}")

results, failures = [], []
for t in tables_to_run:
    try:
        results.append(profile_table(t))
    except Exception as e:
        msg = str(e)
        failures.append((t, msg))
        if "403" in msg or "AccessDenied" in msg or "not authorized" in msg.lower():
            log(f"!! ACCESS DENIED reading {t}: this is a permissions/credential issue, not the code. "
                f"Confirm SELECT on the table and READ FILES on its external location, and that you are on a "
                f"Unity-Catalog-enabled cluster. (raw: {msg[:160]})")
        else:
            log(f"!! FAILED {t}: {msg[:200]}")

log(f"profiling complete: {len(results)} table(s) ok, {len(failures)} failed")

# flatten
prop_rows = [p for res in results for p in res["proposals"]]
key_rows  = [k for res in results for k in res["key_report"]]
all_anom  = [a for res in results for a in res["anomalies"]]

def _strrows(rows):
    # stringify so Spark can always infer a schema (avoids all-None column errors)
    return [{k: ("" if v is None else str(v)) for k, v in r.items()} for r in rows]

print("=" * 70)
for res in results:
    print(f"TABLE {res['table']}: {res['row_count']} rows, {res['dup_rows']} duplicate rows, {len(res['proposals'])} columns")
for t, _ in failures:
    print(f"TABLE {t}: FAILED (see log above)")
print("=" * 70)
print(f"\nANOMALIES ({len(all_anom)})")
for a in all_anom:
    print("  •", a)

if prop_rows:
    try:
        display(spark.createDataFrame(_strrows(prop_rows)))
        if key_rows:
            display(spark.createDataFrame(_strrows(key_rows)))
    except Exception as e:
        print("display unavailable:", e)
else:
    log("no proposals produced (all tables failed?) — nothing to display")

# COMMAND ----------
# MAGIC %md
# MAGIC ## Persist results (optional)
# MAGIC If `results_location` (e.g. `my_catalog.my_metadata`) is set and you can write there, this saves four Delta
# MAGIC tables — `profiler_proposals`, `profiler_keys`, `profiler_anomalies`, `profiler_runlog` — tagged with a run
# MAGIC timestamp. If it's blank, results live only in this notebook's cell output + the driver log (nothing persisted).

# COMMAND ----------
RUN_TS = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
PERSISTED = []          # (quoted_table_name, rowcount) actually written
PERSIST_ERROR = None

def _qualify(name):
    # backtick-quote every part so a hyphenated catalog (d4001-...) is valid
    return ".".join(bq(p.strip()) for p in (RESULTS_LOCATION.split(".") + [name]))

if RESULTS_LOCATION:
    from pyspark.sql.types import StructType, StructField, StringType

    def _save(rows, name, columns):
        # always creates the table, even when empty, using an explicit string schema
        tgt = _qualify(name)
        rows = _strrows(rows)
        cols = columns + ["run_ts"]
        if rows:
            sdf = spark.createDataFrame(rows).withColumn("run_ts", F.lit(RUN_TS))
            sdf = sdf.select(*cols)                       # stable column order
        else:
            schema = StructType([StructField(c, StringType(), True) for c in cols])
            sdf = spark.createDataFrame([], schema)
        sdf.write.mode("append").option("mergeSchema", "true").saveAsTable(tgt)
        n = sdf.count()
        PERSISTED.append((tgt, n))
        log(f"    wrote {n} row(s) -> {tgt}")

    PROP_COLS = ["table", "column", "current_type", "proposed_type", "nullable", "date_format",
                 "cast_expr", "null_count", "null_pct", "zero_or_blank", "approx_distinct",
                 "enum_values", "sample_values", "notes"]
    KEY_COLS  = ["table", "column", "key_kind", "unique_nonnull", "verdict"]
    ANOM_COLS = ["anomaly"]
    RUNLOG_COLS = ["catalog", "schema", "tables", "mode", "sample_size",
                   "tables_ok", "tables_failed", "failures"]
    try:
        log(f"persisting results to {RESULTS_LOCATION} ...")
        _save(prop_rows, "profiler_proposals", PROP_COLS)
        _save(key_rows,  "profiler_keys", KEY_COLS)
        _save([{"anomaly": a} for a in all_anom], "profiler_anomalies", ANOM_COLS)
        _save([{"catalog": CATALOG, "schema": SCHEMA, "tables": ",".join(tables_to_run),
                "mode": MODE, "sample_size": SAMPLE,
                "tables_ok": len(results), "tables_failed": len(failures),
                "failures": "; ".join(f"{t}: {m[:120]}" for t, m in failures)}], "profiler_runlog", RUNLOG_COLS)
        log("persistence done.")
    except Exception as e:
        PERSIST_ERROR = str(e)
        log(f"!! could not persist to {RESULTS_LOCATION}: {PERSIST_ERROR[:240]} "
            f"(you likely need CREATE TABLE on that schema; results are still in the cell output above)")
else:
    log("results_location blank -> nothing persisted. Set it to a catalog.schema you can write to, "
        "to save profiler_proposals / _keys / _anomalies / _runlog as Delta tables.")

# COMMAND ----------
# MAGIC %md ## Mode: diff (proposal vs Unity Catalog)

# COMMAND ----------
if MODE == "diff":
    log("diff mode: comparing proposal against Unity Catalog ...")
    diffs = []
    for res in results:
        cur = uc_current(res["table"])
        for p in res["proposals"]:
            c = p["column"]; cinfo = cur.get(c, {})
            cur_t = (cinfo.get("type") or p["current_type"]).lower()
            prop_t = p["proposed_type"].lower()
            if prop_t != cur_t:
                diffs.append({"table": res["table"], "column": c, "attribute": "data_type",
                              "unity_catalog": cur_t, "proposed": prop_t,
                              "action": f"ALTER (manual rewrite — {p['cast_expr']})" if p["cast_expr"] else "review"})
            if not cinfo.get("comment"):
                diffs.append({"table": res["table"], "column": c, "attribute": "comment",
                              "unity_catalog": cinfo.get("comment"), "proposed": "(profiler seed)",
                              "action": "ALTER … COMMENT"})
    log(f"diff mode: {len(diffs)} difference(s) found.")
    try:
        display(spark.createDataFrame(_strrows(diffs)) if diffs else spark.createDataFrame([{"info": "no differences"}]))
    except Exception as e:
        for d in diffs: print(d)
else:
    log(f"diff cell skipped (mode={MODE}).")

# COMMAND ----------
# MAGIC %md
# MAGIC ## Mode: apply (ALTER the table)
# MAGIC Applies **safe metadata** (column/table comments, and informational PRIMARY KEY when a valid key exists and
# MAGIC there are no duplicate rows). **Type changes are NOT auto-applied** — string→date/decimal needs a data
# MAGIC rewrite, so the DDL is printed for you to run deliberately. `apply_dry_run=true` prints everything without executing.

# COMMAND ----------
if MODE == "apply":
    log(f"apply mode ({'DRY-RUN' if DRYRUN else 'EXECUTE'}): comments + informational PK; type changes printed only.")
    def run(sql):
        print(("DRY-RUN  " if DRYRUN else "EXECUTE  ") + sql)
        if not DRYRUN:
            spark.sql(sql)

    for res in results:
        t = res["table"]; fq = fqn(t)
        cur = uc_current(t)
        # 1) column comments (safe)
        for p in res["proposals"]:
            if p["notes"] and not cur.get(p["column"], {}).get("comment"):
                seed = (p["notes"] or "").replace("'", "''")
                run(f"ALTER TABLE {fq} ALTER COLUMN {bq(p['column'])} COMMENT '{seed}'")
        # 2) informational primary key (only if a valid, dup-free key exists)
        if res["dup_rows"] == 0:
            valid_keys = [k["column"] for k in res["key_report"] if k["verdict"] == "valid"]
            if valid_keys:
                k = valid_keys[0]
                run(f"ALTER TABLE {fq} ADD CONSTRAINT {t}_pk PRIMARY KEY ({bq(k)})")
        # 3) type changes — emit DDL only, never auto-rewrite
        for p in res["proposals"]:
            if p["cast_expr"]:
                print(f"-- MANUAL TYPE CHANGE {t}.{p['column']}: {p['current_type']} -> {p['proposed_type']}")
                print(f"--   add a typed column then backfill:  {p['cast_expr']}  (avoid in-place ALTER COLUMN TYPE on Delta)")

    print("\napply complete" + (" (dry-run — nothing executed)" if DRYRUN else ""))
else:
    log(f"apply cell skipped (mode={MODE}).")

# COMMAND ----------
# MAGIC %md ## Run summary — where everything went

# COMMAND ----------
print("=" * 70)
print("RUN SUMMARY")
print("  mode             :", MODE)
print("  tables profiled  :", [r["table"] for r in results], f"({len(failures)} failed)")
print("  proposals        :", len(prop_rows), "rows")
print("  key candidates   :", len(key_rows), "rows")
print("  anomalies        :", len(all_anom))
print("-" * 70)
print("WHERE THE OUTPUT IS:")
print("  • Log lines + tables above  -> this notebook's cell output (and the cluster Driver log -> stdout;")
print("                                 if run as a Job, the job run page). Ephemeral — tied to this run.")
if not RESULTS_LOCATION:
    print("  • Nothing persisted (results_location is blank). Set it to a catalog.schema you can write to")
    print("    if you want profiler_proposals / _keys / _anomalies / _runlog saved as Delta tables.")
elif PERSIST_ERROR:
    print(f"  • PERSIST FAILED — tables were NOT created. Reason: {PERSIST_ERROR[:200]}")
    print("    Most common cause: you lack CREATE TABLE on that schema. Use a schema you can write to,")
    print("    or ask for CREATE TABLE on it, then re-run the persist cell.")
elif PERSISTED:
    print(f"  • Saved Delta tables (run_ts='{RUN_TS}'):")
    for tgt, n in PERSISTED:
        print(f"        {tgt}   ({n} rows)")
    print(f"    Query later:  SELECT * FROM {_qualify('profiler_proposals')} WHERE run_ts = '{RUN_TS}'")
    print("    (refresh Catalog Explorer to see them.)")
else:
    print("  • results_location is set but nothing was written — the persist cell didn't run.")
    print("    Run the 'Persist results' cell (or Run All) so the tables get created.")
print("=" * 70)
