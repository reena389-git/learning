-- Typed, fix-safe views over asts and ats_summary
-- Built from the profiler_anomalies recommendations (run_ts 2026-06-22 22:16).
--
-- DESIGN: every cast is idempotent. It yields the correct typed value whether the
-- column is still the messy original OR has already been fixed to the right type:
--   * dates  -> try YYYYMMDD first, then fall back to a native DATE/TIMESTAMP cast
--   * numbers-> strip thousands separators, then BIGINT; a no-op once already BIGINT
-- All conversions use try_* so a non-match returns NULL instead of raising — the
-- view never fails on a type change.
--
-- Pass-through: SELECT * EXCEPT(...) carries every other column unchanged (incl. the
-- 100%-null informational columns), so unknown/added columns keep flowing automatically.
-- Note: re-typed columns move to the end of the column list (star-except behaviour).
--
-- CONFIRM the source schemas below before running:
--   asts        -> xvala_xva
--   ats_summary -> xvala_core

CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_xva`.`vw_asts_typed` AS
SELECT
  * EXCEPT (`Line_Expiry`, `business_date`, `Standard_Usage_0_3_mo`, `Standard_Usage_3_12_mo`, `Standard_Usage_1_2_Yr`, `Standard_Usage_2_5_Yr`, `Standard_Usage_5_10_Yr`, `Standard_Usage_10_50_Yr`, `Max_Usage_0_3_mo`, `Max_Usage_3_12_mo`, `Max_Usage_1_2_Yr`, `Max_Usage_2_5_Yr`, `Max_Usage_5_10_Yr`, `Max_Usage_10_50_Yr`, `Limit_3_mo`, `Limit_1_Yr`, `Limit_2_Yr`, `Limit_5_Yr`, `Limit_10_Yr`, `Limit_50_Yr`, `Gross_Max_Exposure`, `Max_Scenario_Exposure`, `Standard_Exposure`),
  -- dates: YYYYMMDD (int/text today) OR native DATE/TIMESTAMP (after a fix) -> DATE
  COALESCE(try_to_date(CAST(`Line_Expiry` AS STRING), 'yyyyMMdd'), try_cast(CAST(`Line_Expiry` AS STRING) AS DATE)) AS `Line_Expiry`,
  COALESCE(try_to_date(CAST(`business_date` AS STRING), 'yyyyMMdd'), try_cast(CAST(`business_date` AS STRING) AS DATE)) AS `business_date`,
  -- numerics: thousands-separated text today OR BIGINT (after a fix) -> BIGINT
  try_cast(replace(CAST(`Standard_Usage_0_3_mo` AS STRING), ',', '') AS BIGINT) AS `Standard_Usage_0_3_mo`,
  try_cast(replace(CAST(`Standard_Usage_3_12_mo` AS STRING), ',', '') AS BIGINT) AS `Standard_Usage_3_12_mo`,
  try_cast(replace(CAST(`Standard_Usage_1_2_Yr` AS STRING), ',', '') AS BIGINT) AS `Standard_Usage_1_2_Yr`,
  try_cast(replace(CAST(`Standard_Usage_2_5_Yr` AS STRING), ',', '') AS BIGINT) AS `Standard_Usage_2_5_Yr`,
  try_cast(replace(CAST(`Standard_Usage_5_10_Yr` AS STRING), ',', '') AS BIGINT) AS `Standard_Usage_5_10_Yr`,
  try_cast(replace(CAST(`Standard_Usage_10_50_Yr` AS STRING), ',', '') AS BIGINT) AS `Standard_Usage_10_50_Yr`,
  try_cast(replace(CAST(`Max_Usage_0_3_mo` AS STRING), ',', '') AS BIGINT) AS `Max_Usage_0_3_mo`,
  try_cast(replace(CAST(`Max_Usage_3_12_mo` AS STRING), ',', '') AS BIGINT) AS `Max_Usage_3_12_mo`,
  try_cast(replace(CAST(`Max_Usage_1_2_Yr` AS STRING), ',', '') AS BIGINT) AS `Max_Usage_1_2_Yr`,
  try_cast(replace(CAST(`Max_Usage_2_5_Yr` AS STRING), ',', '') AS BIGINT) AS `Max_Usage_2_5_Yr`,
  try_cast(replace(CAST(`Max_Usage_5_10_Yr` AS STRING), ',', '') AS BIGINT) AS `Max_Usage_5_10_Yr`,
  try_cast(replace(CAST(`Max_Usage_10_50_Yr` AS STRING), ',', '') AS BIGINT) AS `Max_Usage_10_50_Yr`,
  try_cast(replace(CAST(`Limit_3_mo` AS STRING), ',', '') AS BIGINT) AS `Limit_3_mo`,
  try_cast(replace(CAST(`Limit_1_Yr` AS STRING), ',', '') AS BIGINT) AS `Limit_1_Yr`,
  try_cast(replace(CAST(`Limit_2_Yr` AS STRING), ',', '') AS BIGINT) AS `Limit_2_Yr`,
  try_cast(replace(CAST(`Limit_5_Yr` AS STRING), ',', '') AS BIGINT) AS `Limit_5_Yr`,
  try_cast(replace(CAST(`Limit_10_Yr` AS STRING), ',', '') AS BIGINT) AS `Limit_10_Yr`,
  try_cast(replace(CAST(`Limit_50_Yr` AS STRING), ',', '') AS BIGINT) AS `Limit_50_Yr`,
  try_cast(replace(CAST(`Gross_Max_Exposure` AS STRING), ',', '') AS BIGINT) AS `Gross_Max_Exposure`,
  try_cast(replace(CAST(`Max_Scenario_Exposure` AS STRING), ',', '') AS BIGINT) AS `Max_Scenario_Exposure`,
  try_cast(replace(CAST(`Standard_Exposure` AS STRING), ',', '') AS BIGINT) AS `Standard_Exposure`
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_xva`.`asts`;

CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_ats_summary_typed` AS
SELECT
  * EXCEPT (`business_date`),
  -- dates: YYYYMMDD (int/text today) OR native DATE/TIMESTAMP (after a fix) -> DATE
  COALESCE(try_to_date(CAST(`business_date` AS STRING), 'yyyyMMdd'), try_cast(CAST(`business_date` AS STRING) AS DATE)) AS `business_date`
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`ats_summary`;

-- ---------------------------------------------------------------------------
-- Notes
-- 1. asts has 35 duplicate rows / no single-column key. This view stays 1:1 with
--    the source (no dedup). If you want the de-duplicated grain, add DISTINCT or
--    use the tearsheet bucket-pivot view, which already drops the 35 dups.
-- 2. "100% null" / "63% null" columns are informational only — passed through as-is.
-- 3. The BIGINT casts assume whole-number values (the profiler's recommendation). If a
--    column is ever fixed to a fractional DECIMAL/DOUBLE instead, change BIGINT ->
--    DECIMAL(38,4) for that column to avoid truncation.
-- 4. Requires try_to_date (Databricks DBR 11.3+ / serverless). Present on a UC cluster.
