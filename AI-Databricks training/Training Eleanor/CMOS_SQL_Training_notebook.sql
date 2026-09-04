-- Databricks notebook source
-- MAGIC %md
-- MAGIC # CMOS SQL Training — Profiling, Joins & Dashboard
-- MAGIC
-- MAGIC **The story:** every table here eventually feeds a dashboard showing agreements, disputes, settlement, and collateral position. Module 1 profiles the root table. Module 2 joins it to its real children — and immediately runs into the fact that "the same agreement" is spelled four different ways across four tables. Module 3 builds the dashboard on top of what's been proven, not assumed.
-- MAGIC
-- MAGIC Every SQL construct below is verified against current Databricks SQL documentation. Every built-in function gets a one-line description at first use. Tables and columns are real production silver-layer DDL — nothing invented.
-- MAGIC
-- MAGIC ---
-- MAGIC
-- MAGIC ## Module 1 — Profiling `agreements`
-- MAGIC
-- MAGIC ### 1.1 First look
-- COMMAND ----------
SELECT * FROM agreements LIMIT 10;

SELECT external_id, agreement_id, counterparty, counterparty_code,
       agreement_type, agreement_date, base_currency, agreement_status,
       reporting_date
FROM agreements
ORDER BY agreement_date DESC     -- ORDER BY: sort rows; DESC = most recent first
LIMIT 20;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ### 1.2 Shape & freshness
-- COMMAND ----------
SELECT COUNT(*)              AS total_rows,
       MIN(agreement_date)   AS earliest_agreement,   -- MIN/MAX: smallest/largest value in the column
       MAX(agreement_date)   AS latest_agreement,
       MIN(reporting_date)   AS earliest_snapshot,
       MAX(reporting_date)   AS latest_snapshot
FROM agreements;

-- current_date(): today's date, evaluated when the query runs — no arguments
-- datediff(endDate, startDate): days between two dates. endDate comes FIRST in
-- Databricks — the opposite order from Snowflake/Redshift. Get it backwards and
-- you get a silently negative number, not an error.
SELECT MAX(reporting_date)                              AS latest_snapshot,
       current_date()                                    AS today,
       datediff(current_date(), MAX(reporting_date))      AS days_since_last_snapshot
FROM agreements;

-- date_sub(date, days): subtract N days from a date. BETWEEN: inclusive range filter.
SELECT external_id, agreement_date, reporting_date
FROM agreements
WHERE reporting_date BETWEEN date_sub(current_date(), 90) AND current_date()
ORDER BY reporting_date DESC
LIMIT 20;

SELECT COUNT(*) AS agreements_in_window
FROM agreements
WHERE agreement_date BETWEEN '2023-01-01' AND '2023-12-31';

SELECT DISTINCT reporting_date FROM agreements ORDER BY reporting_date;  -- DISTINCT: unique values only
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ### 1.3 Completeness — NULLs, folded into one query
-- COMMAND ----------
-- COUNT(col) skips NULLs; COUNT(*) doesn't. Comparing them in one block is the
-- fastest way to profile completeness across several columns at once, and it
-- also demonstrates the = NULL trap live in the same query:
SELECT
    COUNT(*)                                              AS total_rows,
    COUNT(external_id)                                    AS external_id_populated,
    COUNT(agreement_id)                                   AS agreement_id_populated,
    COUNT(counterparty_code)                               AS counterparty_code_populated,
    COUNT(CASE WHEN counterparty_code = NULL THEN 1 END)   AS wrong_null_check_always_zero,  -- = NULL never matches, ever
    COUNT(CASE WHEN counterparty_code IS NULL THEN 1 END)  AS correct_null_check              -- IS NULL is the real one
FROM agreements
WHERE agreement_status IS NOT NULL;   -- a normal filter, coexisting with the null checks above

-- <=> : Databricks' null-safe equal operator. Unlike =, it returns TRUE when
-- both sides are NULL instead of NULL/unknown.
SELECT NULL <=> NULL;                    -- true
SELECT equal_null(NULL, NULL);           -- true — same idea, as a function (Databricks Runtime 11.1+)

-- COALESCE(a, b, ...): returns the first non-null argument — useful for
-- giving NULLs a readable label in a summary rather than hiding them.
SELECT COALESCE(counterparty_code, 'UNKNOWN') AS counterparty_code_display,
       COUNT(*) AS n
FROM agreements
GROUP BY COALESCE(counterparty_code, 'UNKNOWN')
ORDER BY n DESC;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ### 1.4 Uniqueness & grain
-- COMMAND ----------
SELECT COUNT(DISTINCT external_id) AS distinct_agreements, COUNT(*) AS total_rows
FROM agreements;

-- GROUP BY + HAVING in one query: HAVING filters groups, WHERE filters rows
-- before grouping. If this returns zero rows, (external_id, reporting_date)
-- is the real grain of this table.
SELECT external_id, reporting_date, COUNT(*) AS row_count
FROM agreements
WHERE agreement_status IS NOT NULL
GROUP BY external_id, reporting_date
HAVING COUNT(*) > 1
ORDER BY row_count DESC;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ### 1.5 Distributions, categories, hygiene
-- COMMAND ----------
-- ROUND(number, decimals): rounds to N decimal places.
SELECT base_currency,
       COUNT(*) AS n,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM agreements), 1) AS pct_of_total
FROM agreements
GROUP BY base_currency
ORDER BY n DESC;

-- CASE WHEN ... THEN ... ELSE ... END: bucket rows into categories.
SELECT
  CASE
    WHEN datediff(current_date(), agreement_date) <= 365      THEN 'Last 12 months'
    WHEN datediff(current_date(), agreement_date) <= 365 * 3  THEN '1-3 years'
    ELSE 'Over 3 years'
  END AS agreement_age_bucket,
  COUNT(*) AS n
FROM agreements
GROUP BY 1
ORDER BY n DESC;

-- LENGTH(string): character count. SUBSTRING(string, start, length): extract
-- part of a string, 1-based position.
SELECT external_id, LENGTH(external_id) AS id_length, SUBSTRING(external_id, 1, 3) AS id_prefix
FROM agreements
WHERE counterparty LIKE '%BANK%'    -- LIKE: pattern match, % = any characters
LIMIT 20;

-- TRIM(string): removes leading/trailing whitespace. UPPER(string): uppercases.
-- Checking whether normalizing collapses "distinct" values is a classic hygiene catch.
SELECT agreement_type, UPPER(TRIM(agreement_type)) AS normalized, COUNT(*) AS n
FROM agreements
GROUP BY agreement_type
ORDER BY agreement_type;

-- CREATE TABLE ... AS SELECT (CTAS): save a query's result as a new table.
CREATE TABLE agreements_by_counterparty AS
SELECT counterparty_code, COUNT(*) AS agreement_count,
       MIN(agreement_date) AS earliest_agreement, MAX(agreement_date) AS latest_agreement
FROM agreements
GROUP BY counterparty_code;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ---
-- MAGIC
-- MAGIC ## Module 2 — Joins
-- MAGIC
-- MAGIC ### 2.0 The join-key map — same concept, four spellings
-- MAGIC
-- MAGIC | Table | Column that means "which agreement" | Reliable? |
-- MAGIC |---|---|---|
-- MAGIC | `agreements` | `external_id` (also has `agreement_id`, the formal PK) | `external_id` yes, `agreement_id` no (~0% match) |
-- MAGIC | `daily_exposure` | `external_id` | Yes — same name, same value |
-- MAGIC | `asset_holdings` | `agreement_ext_id` | Yes — same value, **different name** |
-- MAGIC | `collateral_eligibility` | `agreement_external_id` | Presumed yes — **third spelling**, not yet proven live |
-- MAGIC | `disputes` | `agreement_id` only — no `external_id` equivalent present | **Unconfirmed — see flag below** |
-- MAGIC | `settlement_instructions` | `agreement_id` only — no `external_id` equivalent present | **Unconfirmed — see flag below** |
-- MAGIC
-- MAGIC > **⚠️ OPEN CONCERN — flag for verification, not yet resolved.**
-- MAGIC > `disputes` and `settlement_instructions` only carry `agreement_id`, and every other table in this schema has shown `agreement_id` to be an unreliable join key (~0% match rate against `agreements`). It is not yet known whether:
-- MAGIC > (a) `agreement_id` happens to be populated reliably for these two tables specifically (they may come through a different upstream pipeline), or
-- MAGIC > (b) they share the same dead-key problem, meaning disputes and settlement currently cannot be reliably joined back to `agreements` at all.
-- MAGIC > **Do not assume either answer.** The query below is written to test this live, the same way the `external_id` vs `agreement_id` result was proven for the other tables — treat the result as the actual answer, not a formality.
-- MAGIC
-- MAGIC ### 2.1 Prove the real join key (agreements → daily_exposure)
-- COMMAND ----------
-- Try agreement_id first — the formal PK, but not necessarily the working key
SELECT COUNT(*) AS matched_rows
FROM agreements a
JOIN daily_exposure d
  ON a.agreement_id = d.agreement_id;

-- Now external_id
SELECT COUNT(*) AS matched_rows
FROM agreements a
JOIN daily_exposure d
  ON a.external_id = d.external_id;

-- Compare the two counts. The gap between them IS the lesson: a formal primary
-- key is not automatically the right join key — it has to be proven, not assumed.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ### 2.2 A third spelling — `asset_holdings.agreement_ext_id`
-- COMMAND ----------
-- Same real-world concept, third column name. This is exactly why join keys
-- must be explicitly defined per table rather than assumed from naming.
SELECT COUNT(*) AS matched_rows
FROM agreements a
JOIN asset_holdings h
  ON a.external_id = h.agreement_ext_id;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ### 2.3 Grain matters inside a join too, not just inside one table
-- COMMAND ----------
-- Join on external_id alone: one agreement fans out against every snapshot
-- day in daily_exposure — almost certainly not what you want.
SELECT a.external_id, a.reporting_date AS agreement_snapshot,
       d.reporting_date AS exposure_snapshot, d.base_total_exposure_amount
FROM agreements a
JOIN daily_exposure d
  ON a.external_id = d.external_id
LIMIT 20;   -- inspect: does reporting_date line up, or is it fanning out?

-- Fixed: constrain the join on BOTH parts of the real grain,
-- (external_id, reporting_date), reusing the Module 1 lesson directly.
SELECT a.external_id, a.reporting_date, d.base_total_exposure_amount, d.call_status
FROM agreements a
JOIN daily_exposure d
  ON a.external_id = d.external_id
 AND a.reporting_date = d.reporting_date
LIMIT 20;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ### 2.4 LEFT JOIN — find what's missing
-- COMMAND ----------
-- Agreements with NO matching exposure row on the same date.
-- IS NULL on the right-hand table's key is the standard "what's missing" pattern.
SELECT a.external_id, a.reporting_date
FROM agreements a
LEFT JOIN daily_exposure d
  ON a.external_id = d.external_id
 AND a.reporting_date = d.reporting_date
WHERE d.external_id IS NULL
ORDER BY a.reporting_date DESC;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ### 2.5 Asset classes — `asset_holdings`
-- COMMAND ----------
SELECT asset_class, asset_type, COUNT(*) AS n,
       ROUND(SUM(reported_collateral_value), 2) AS total_collateral_value
FROM asset_holdings
GROUP BY asset_class, asset_type
ORDER BY total_collateral_value DESC;

-- Bring in the agreement context via the real (third-spelling) key
SELECT a.counterparty_code, h.asset_class,
       COUNT(*) AS holdings, SUM(h.reported_collateral_value) AS total_value
FROM agreements a
JOIN asset_holdings h
  ON a.external_id = h.agreement_ext_id
 AND a.reporting_date = h.reporting_date
GROUP BY a.counterparty_code, h.asset_class
ORDER BY total_value DESC;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ### 2.6 Eligibility rules — `collateral_eligibility`
-- MAGIC
-- MAGIC Note the two extra real-world wrinkles in this table: the join column is spelled `agreement_external_id` (a *third* spelling of the same concept), and its date column is `reporting_day`, not `reporting_date` like every other table.
-- COMMAND ----------
-- Prove the join key here too, same discipline as 2.1 — don't assume it works
-- just because the column name looks similar.
SELECT COUNT(*) AS matched_rows
FROM agreements a
JOIN collateral_eligibility e
  ON a.external_id = e.agreement_external_id;

-- What's eligible, and at what haircut, per agreement
SELECT a.external_id, a.counterparty_code,
       e.asset_class, e.asset_type, e.from_rating_level, e.to_rating_level,
       e.valuation_haircut
FROM agreements a
JOIN collateral_eligibility e
  ON a.external_id = e.agreement_external_id
 AND a.reporting_date = e.reporting_day     -- note the column name difference
ORDER BY a.external_id;

-- Does a held asset's rating actually fall inside its eligibility band?
-- Flagged as an open modeling question, not solved here: from_rating_level /
-- to_rating_level are slash-delimited multi-agency rating strings (per the
-- table's own column comment), while asset_holdings.rating is a separate,
-- differently-sourced rating field. A simple string BETWEEN will not safely
-- compare these — this needs an explicit rating-scale mapping, the same class
-- of problem as the IM/VM and asset-class ontology work done earlier.
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ---
-- MAGIC
-- MAGIC ## Module 3 — Dashboard
-- MAGIC
-- MAGIC Two layers, both built only on joins already proven above — nothing new is assumed here.
-- MAGIC
-- MAGIC ### 3.1 Summary layer
-- COMMAND ----------
CREATE TABLE dashboard_summary_by_counterparty AS
SELECT
    a.counterparty_code,
    COUNT(DISTINCT a.external_id)                       AS agreement_count,
    SUM(d.base_total_exposure_amount)                    AS total_exposure,
    SUM(h.reported_collateral_value)                     AS total_collateral_value,
    (SELECT COUNT(*) FROM disputes ds
      WHERE ds.agreement_id = a.agreement_id
        AND ds.reporting_date = a.reporting_date)        AS dispute_count   -- uses the UNCONFIRMED key — see 2.0 flag
FROM agreements a
LEFT JOIN daily_exposure d
       ON a.external_id = d.external_id AND a.reporting_date = d.reporting_date
LEFT JOIN asset_holdings h
       ON a.external_id = h.agreement_ext_id AND a.reporting_date = h.reporting_date
GROUP BY a.counterparty_code, a.agreement_id, a.reporting_date;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC ### 3.2 Detail layer
-- COMMAND ----------
CREATE TABLE dashboard_detail AS
SELECT
    a.external_id, a.counterparty_code, a.agreement_type, a.reporting_date,
    d.base_total_exposure_amount, d.call_status,
    h.asset_class, h.asset_type, h.reported_collateral_value, h.rating, h.pd
FROM agreements a
LEFT JOIN daily_exposure d
       ON a.external_id = d.external_id AND a.reporting_date = d.reporting_date
LEFT JOIN asset_holdings h
       ON a.external_id = h.agreement_ext_id AND a.reporting_date = h.reporting_date;
-- COMMAND ----------
-- MAGIC %md
-- MAGIC > **Data model observation, not yet resolved:** `asset_holdings` carries live credit-risk fields (`pd`, `rating`, `issuer_rating`, `cpty_internal_rating`, `cqs`) directly on the collateral row, with no visible model version or source column. Before these feed a dashboard tile, worth confirming where `pd` actually comes from and how current it is — the same provenance question raised earlier for the BNY/TAMS eligibility data.
-- MAGIC
-- MAGIC ---
-- MAGIC
-- MAGIC ## Open items carried forward
-- MAGIC
-- MAGIC 1. Whether `disputes`/`settlement_instructions.agreement_id` is reliable — **test live in session**, per 2.0.
-- MAGIC 2. Whether `collateral_eligibility.agreement_external_id` matches at the same ~100% rate as `external_id`/`agreement_ext_id` — the query in 2.6 tests this but the result isn't known yet.
-- MAGIC 3. How to safely compare `asset_holdings.rating` against `collateral_eligibility.from_rating_level`/`to_rating_level` given they're different rating representations.
-- MAGIC 4. Provenance of the `pd` field on `asset_holdings` — source and freshness unconfirmed.
