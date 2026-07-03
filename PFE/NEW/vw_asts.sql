-- =====================================================================
-- vw_asts   (v2 — explicit columns, type-corrected DOUBLE, null/type-safe)
-- Catalog d4001-centralus-tdvip-creditrisk · Schema xvala_core
--
-- WHY THIS VIEW EXISTS (rationale)
--   The single cleaned base view over pfe_asts. It does NOT aggregate or join —
--   it is a type-safe, null-safe, EXPLICIT-column pass-through so that (a) the
--   line fact and scenario fact read one clean, stably-typed source, and (b) an
--   upstream table change (a column renamed, retyped, or reordered) fails loudly
--   here instead of silently corrupting a downstream fact.
--
-- GRAIN            line × scenario   (one row per line per Scenario_Name)
-- KEY              Line + Scenario_Name   (Scenario code & Timestep are NULL in data)
--
-- CORRECTIONS vs the original vw_asts (which was authored when the base table was
-- all-STRING and mis-cast exposures to BIGINT):
--   (~) numerics -> DOUBLE (NOT BIGINT). The base table is now DOUBLE; a BIGINT
--       cast truncates fractional exposure and breaks any ratio built on it.
--   (~) EXPLICIT column list (no SELECT * EXCEPT). Adding/removing a base column
--       no longer silently changes this view's shape.
--   (~) No_Line_Indicator handled as real BOOLEAN.
--   (~) dates via COALESCE(try_to_date 'yyyyMMdd', try_cast AS DATE) — the house
--       idiom; survives STRING-yyyymmdd OR native DATE.
--   (~) numerics via try_cast(... AS DOUBLE) — survives clean DOUBLE today AND
--       thousands-separated STRING if a future load regresses. NULL on garbage,
--       never errors the view.
--   (+) Line conformance: trim(upper(Line)) IS applied here — the base view is the
--       one place the key is normalized, so every fact inherits a clean, conformed
--       key and joins on simple equality. (Decision: conformance belongs in the base
--       view, which exists precisely to be the conformed layer over the raw table.)
-- =====================================================================
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts` (
  Scenario_Name       COMMENT 'Scenario display name (already business-friendly). Populated. The scenario key. NOTE: asts scenario vocabulary differs from ats_summary *_max stems and lines_report.source — never join scenarios across tables on the raw label; see PFE Scenario_Name_Map.',
  Line                COMMENT 'Credit line identifier. CONFORMED KEY trim(upper(Line)) — normalized here in the base view so every consumer inherits a clean key. Grain key with Scenario_Name.',
  Long_Name           COMMENT 'Counterparty / line long name.',
  Line_Type           COMMENT 'Line type.',
  Line_Expiry         COMMENT 'Line expiry date (normalized to DATE). Attribute of the line, not a grain key.',
  No_Line_Indicator   COMMENT 'BOOLEAN true/false — whether the row has no line. Facts filter No_Line_Indicator = false (null-safe).',
  Line_Currency       COMMENT 'Currency of the line.',
  Worst_Rating_Of_Associated_Clients COMMENT 'Worst credit rating among associated clients.',
  Scenario_Code       COMMENT 'Raw scenario code from source. NULL in current data (kept for schema stability / future use).',
  Timestep            COMMENT 'Scenario timestep index. NULL in current data (not a grain dimension).',
  Max_Scenario_Name   COMMENT 'Scenario that produced the row-level max exposure.',
  Max_Exp_Time_Bucket COMMENT 'Tenor bucket that produced Max_Scenario_Exposure.',
  Standard_Usage_0_3_mo  COMMENT 'Standard (base) usage, 0-3 month bucket. DOUBLE.',
  Standard_Usage_3_12_mo COMMENT 'Standard usage, 3-12 month bucket.',
  Standard_Usage_1_2_Yr  COMMENT 'Standard usage, 1-2 year bucket.',
  Standard_Usage_2_5_Yr  COMMENT 'Standard usage, 2-5 year bucket.',
  Standard_Usage_5_10_Yr COMMENT 'Standard usage, 5-10 year bucket.',
  Standard_Usage_10_50_Yr COMMENT 'Standard usage, 10-50 year bucket.',
  Max_Usage_0_3_mo    COMMENT 'Max (stressed) usage, 0-3 month bucket. DOUBLE.',
  Max_Usage_3_12_mo   COMMENT 'Max usage, 3-12 month bucket.',
  Max_Usage_1_2_Yr    COMMENT 'Max usage, 1-2 year bucket.',
  Max_Usage_2_5_Yr    COMMENT 'Max usage, 2-5 year bucket.',
  Max_Usage_5_10_Yr   COMMENT 'Max usage, 5-10 year bucket.',
  Max_Usage_10_50_Yr  COMMENT 'Max usage, 10-50 year bucket.',
  Limit_3_mo          COMMENT 'Limit, 0-3 month bucket. DOUBLE.',
  Limit_1_Yr          COMMENT 'Limit, 3-12 month bucket.',
  Limit_2_Yr          COMMENT 'Limit, 1-2 year bucket.',
  Limit_5_Yr          COMMENT 'Limit, 2-5 year bucket.',
  Limit_10_Yr         COMMENT 'Limit, 5-10 year bucket.',
  Limit_50_Yr         COMMENT 'Limit, 10-50 year bucket.',
  `0_3_mo_Excess_Breach`   COMMENT 'NULL — no 0_3_mo breach flag exists in pfe_asts. Emitted as NULL so downstream has all 6 bucket slots uniformly. See PFE Data Checks #7.',
  `3_12_mo_Excess_Breach`  COMMENT 'Breach flag STRING TRUE/FALSE, 3-12 month bucket.',
  `1_2_Yr_Excess_Breach`   COMMENT 'Breach flag, 1-2 year bucket.',
  `2_5_Yr_Excess_Breach`   COMMENT 'Breach flag, 2-5 year bucket.',
  `5_10_Yr_Excess_Breach`  COMMENT 'Breach flag, 5-10 year bucket.',
  `10_50_Yr_Excess_Breach` COMMENT 'Breach flag, 10-50 year bucket.',
  `0_3_mo_Excess_Percentage`   COMMENT 'Excess percentage, 0-3 month bucket. DOUBLE.',
  `3_12_mo_Excess_Percentage`  COMMENT 'Excess percentage, 3-12 month bucket.',
  `1_2_Yr_Excess_Percentage`   COMMENT 'Excess percentage, 1-2 year bucket.',
  `2_5_Yr_Excess_Percentage`   COMMENT 'Excess percentage, 2-5 year bucket.',
  `5_10_Yr_Excess_Percentage`  COMMENT 'Excess percentage, 5-10 year bucket.',
  `10_50_Yr_Excess_Percentage` COMMENT 'Excess percentage, 10-50 year bucket.',
  Gross_Max_Exposure  COMMENT 'Gross max exposure across buckets. DOUBLE.',
  Max_Scenario_Exposure COMMENT 'Peak exposure across buckets for this scenario row. DOUBLE.',
  Standard_Exposure   COMMENT 'Standard exposure aligned to the max bucket. DOUBLE.',
  Excess_Percentage   COMMENT 'Row-level excess percentage. DOUBLE.',
  Exposure_Percentage COMMENT 'Row-level exposure percentage. DOUBLE.',
  Exposure_Percentage_0_3_mo   COMMENT 'Exposure percentage, 0-3 month bucket.',
  Exposure_Percentage_3_12_mo  COMMENT 'Exposure percentage, 3-12 month bucket.',
  Exposure_Percentage_1_2_yr   COMMENT 'Exposure percentage, 1-2 year bucket. (source uses lowercase yr)',
  Exposure_Percentage_2_5_yr   COMMENT 'Exposure percentage, 2-5 year bucket.',
  Exposure_Percentage_5_10_yr  COMMENT 'Exposure percentage, 5-10 year bucket.',
  Exposure_Percentage_10_50_yr COMMENT 'Exposure percentage, 10-50 year bucket.',
  Business_Date       COMMENT 'As-of date, normalized to DATE.'
)
AS
SELECT
  Scenario_Name,
  trim(upper(Line))                                                    AS Line,
  Long_Name,
  Line_Type,
  COALESCE(try_to_date(CAST(Line_Expiry AS STRING),'yyyyMMdd'),
           try_cast(CAST(Line_Expiry AS STRING) AS DATE))              AS Line_Expiry,
  CAST(No_Line_Indicator AS BOOLEAN)                                    AS No_Line_Indicator,
  Line_Currency,
  Worst_Rating_Of_Associated_Clients,
  Scenario                                                             AS Scenario_Code,
  Timestep,
  Max_Scenario_Name,
  Max_Exp_Time_Bucket,
  try_cast(replace(CAST(Standard_Usage_0_3_mo   AS STRING),',','') AS DOUBLE) AS Standard_Usage_0_3_mo,
  try_cast(replace(CAST(Standard_Usage_3_12_mo  AS STRING),',','') AS DOUBLE) AS Standard_Usage_3_12_mo,
  try_cast(replace(CAST(Standard_Usage_1_2_Yr   AS STRING),',','') AS DOUBLE) AS Standard_Usage_1_2_Yr,
  try_cast(replace(CAST(Standard_Usage_2_5_Yr   AS STRING),',','') AS DOUBLE) AS Standard_Usage_2_5_Yr,
  try_cast(replace(CAST(Standard_Usage_5_10_Yr  AS STRING),',','') AS DOUBLE) AS Standard_Usage_5_10_Yr,
  try_cast(replace(CAST(Standard_Usage_10_50_Yr AS STRING),',','') AS DOUBLE) AS Standard_Usage_10_50_Yr,
  try_cast(replace(CAST(Max_Usage_0_3_mo   AS STRING),',','') AS DOUBLE) AS Max_Usage_0_3_mo,
  try_cast(replace(CAST(Max_Usage_3_12_mo  AS STRING),',','') AS DOUBLE) AS Max_Usage_3_12_mo,
  try_cast(replace(CAST(Max_Usage_1_2_Yr   AS STRING),',','') AS DOUBLE) AS Max_Usage_1_2_Yr,
  try_cast(replace(CAST(Max_Usage_2_5_Yr   AS STRING),',','') AS DOUBLE) AS Max_Usage_2_5_Yr,
  try_cast(replace(CAST(Max_Usage_5_10_Yr  AS STRING),',','') AS DOUBLE) AS Max_Usage_5_10_Yr,
  try_cast(replace(CAST(Max_Usage_10_50_Yr AS STRING),',','') AS DOUBLE) AS Max_Usage_10_50_Yr,
  try_cast(replace(CAST(Limit_3_mo  AS STRING),',','') AS DOUBLE) AS Limit_3_mo,
  try_cast(replace(CAST(Limit_1_Yr  AS STRING),',','') AS DOUBLE) AS Limit_1_Yr,
  try_cast(replace(CAST(Limit_2_Yr  AS STRING),',','') AS DOUBLE) AS Limit_2_Yr,
  try_cast(replace(CAST(Limit_5_Yr  AS STRING),',','') AS DOUBLE) AS Limit_5_Yr,
  try_cast(replace(CAST(Limit_10_Yr AS STRING),',','') AS DOUBLE) AS Limit_10_Yr,
  try_cast(replace(CAST(Limit_50_Yr AS STRING),',','') AS DOUBLE) AS Limit_50_Yr,
  CAST(NULL AS STRING)              AS `0_3_mo_Excess_Breach`,   -- no source column
  `3_12_mo_Excess_Breach`,
  `1_2_Yr_Excess_Breach`,
  `2_5_Yr_Excess_Breach`,
  `5_10_Yr_Excess_Breach`,
  `10_50_Yr_Excess_Breach`,
  `0_3_mo_Excess_Percentage`,
  `3_12_mo_Excess_Percentage`,
  `1_2_Yr_Excess_Percentage`,
  `2_5_Yr_Excess_Percentage`,
  `5_10_Yr_Excess_Percentage`,
  `10_50_Yr_Excess_Percentage`,
  try_cast(replace(CAST(Gross_Max_Exposure    AS STRING),',','') AS DOUBLE) AS Gross_Max_Exposure,
  try_cast(replace(CAST(Max_Scenario_Exposure AS STRING),',','') AS DOUBLE) AS Max_Scenario_Exposure,
  try_cast(replace(CAST(Standard_Exposure     AS STRING),',','') AS DOUBLE) AS Standard_Exposure,
  Excess_Percentage,
  Exposure_Percentage,
  Exposure_Percentage_0_3_mo,
  Exposure_Percentage_3_12_mo,
  Exposure_Percentage_1_2_yr,
  Exposure_Percentage_2_5_yr,
  Exposure_Percentage_5_10_yr,
  Exposure_Percentage_10_50_yr,
  COALESCE(try_to_date(CAST(business_date AS STRING),'yyyyMMdd'),
           try_cast(CAST(business_date AS STRING) AS DATE))            AS Business_Date
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_asts`;

-- =====================================================================
-- VALIDATION
-- =====================================================================
-- V-TYPE  every exposure/limit column should be DOUBLE (not BIGINT/STRING).
--   DESCRIBE `d4001-centralus-tdvip-creditrisk`.xvala_core.vw_asts;
-- V-GRAIN one row per line × scenario (no dup); ~4 scenarios/line, ~47,216 rows.
SELECT COUNT(*) AS rows_, COUNT(DISTINCT concat(Line,'|',Scenario_Name)) AS line_scn
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_asts;
-- V-NULLBERT  Scenario_Code / Timestep expected NULL; Scenario_Name expected populated.
SELECT
  SUM(CASE WHEN Scenario_Name IS NULL THEN 1 ELSE 0 END) AS null_scn_name,
  SUM(CASE WHEN Scenario_Code IS NULL THEN 1 ELSE 0 END) AS null_scn_code,
  SUM(CASE WHEN Timestep      IS NULL THEN 1 ELSE 0 END) AS null_timestep
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_asts;
