-- =====================================================================
-- vw_pfe_asts_scenario   (v1 — SCENARIO FACT; line × scenario)
-- Catalog d4001-centralus-tdvip-creditrisk · Schema xvala_core
--
-- WHY THIS VIEW EXISTS (rationale)
--   Powers the business ask: "select a scenario, see the portfolio view (sector,
--   industry, entity …) for that scenario." That needs scenario as a SELECTABLE
--   ATTRIBUTE with one exposure measure per line-scenario — i.e. the long shape.
--
--   Built by UNPIVOTING pfe_ats_summary's 8 scenario-max COLUMNS into 8 ROWS
--   (one per scenario), NOT from asts. Why ats_summary and not asts:
--     • friendly scenario names come straight from the column mapping (no crosswalk),
--     • BASE/Cartor is included (asts excludes it),
--     • ties EXACTLY to the line fact — the line fact's 8 Line_Scn_* maxima are the
--       same 8 columns, so Scenario_Exposure here = Line_Scn_X there by construction.
--
--   COMPUTES: the unpivot (stack) + the STRING->DOUBLE casts + Booking_Entity /
--   Client_Type derivations (same logic as the line fact, so the scenario view can
--   be filtered by the same dims standalone). Line attributes are REPEATED across
--   the 8 scenario rows (they are line-grain, inherited) — for filtering the
--   portfolio-by-scenario view without a join. Do NOT sum repeated line attrs.
--
-- GRAIN   line × scenario   (8 scenario rows per line)
-- KEY     Line + Scenario_Name
-- MEASURE Scenario_Exposure  (the per-scenario max — the selectable measure)
-- ROLLUP  line stress = GREATEST(Scenario_Exposure) over a line = ats_summary.max_of_all
--         = vw_pfe_ats_lines_detail.Stress_PFE. Portfolio-by-scenario = SUM(Scenario_Exposure)
--         within the selected Scenario_Name, grouped by dimension (additive within a scenario).
-- CONFORMS on: Line (to line fact & deal fact), Scenario_Name (to vw_dim_scenario & the
--         line fact's Line_Scn_* maxima), Counterparty_Name.
-- =====================================================================
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` (
  Line               COMMENT 'Credit line identifier. Conformed key (trim(upper)). FK to line grain. Line IS the Counterparty_Line_Code (CP rows = counterparty_code; HC rows = agent/facility, null on CP dim).',
  Line_Class         COMMENT 'CP or HC. DERIVED from the Line prefix (same as the line fact). CP = counterparty line; HC = agent/fund/house facility. Scenario-view CP/HC selector/filter.',
  Scenario_Name      COMMENT 'Scenario (friendly name, from the ats_summary column mapping). SELECTABLE attribute for the scenario picker. FK to vw_dim_scenario. Conforms to the line fact''s Line_Scn_* maxima.',
  Scenario_Exposure  COMMENT 'This line''s exposure under this scenario (the unpivoted *_max). The scenario-view measure. ADDITIVE within a scenario across lines (portfolio-by-scenario = SUM within the selected scenario). Across scenarios take GREATEST, not SUM.',
  Counterparty_Name  COMMENT 'Counterparty / line long name. Repeated line attribute.',
  Booking_Entity     COMMENT 'Booking entity. DERIVED: first parenthesised token of Line. Repeated line attribute.',
  Industry           COMMENT 'Granular industry (sic_industry). Denormalized CP reference. Repeated line attribute.',
  Client_Type        COMMENT 'Client type — 5-bucket higher-level industry classification from sic_code (HF=7298). Repeated line attribute.',
  Line_Worst_Rating  COMMENT 'Worst rating among the line''s clients (brr). Line-grain, distinct from counterparty rating. Repeated line attribute.',
  OTC_SFT            COMMENT 'OTC vs SFT split. Repeated line attribute.',
  Limit_Amount       COMMENT 'Line limit (peak bucket). Repeated line attribute — do NOT sum across scenario rows (use Max).',
  Business_Date      COMMENT 'As-of date, normalized to DATE. Repeated line attribute.'
)
AS
WITH ats_clean AS (
  -- line-grain clean of pfe_ats_summary (same derivations as the line fact so the
  -- scenario view filters by identical dims). The 8 *_max stay wide here; unpivoted below.
  SELECT
    trim(upper(line))                                                  AS Line,
    long_name                                                          AS Counterparty_Name,
    regexp_extract(line, '\\(([^)]+)\\)', 1)                           AS Booking_Entity,
    sic_industry                                                       AS Industry,
    industry                                                           AS industry_coarse,
    sic_code                                                           AS sic_code,
    worst_rating_of_associated_clients                                AS Line_Worst_Rating,
    otc_sft                                                            AS OTC_SFT,
    GREATEST(
      try_cast(replace(CAST(limit_3_mo  AS STRING),',','') AS DOUBLE),
      try_cast(replace(CAST(limit_1_yr  AS STRING),',','') AS DOUBLE),
      try_cast(replace(CAST(limit_2_yr  AS STRING),',','') AS DOUBLE),
      try_cast(replace(CAST(limit_5_yr  AS STRING),',','') AS DOUBLE),
      try_cast(replace(CAST(limit_10_yr AS STRING),',','') AS DOUBLE)
    )                                                                  AS Limit_Amount,
    try_cast(replace(CAST(cartor_max    AS STRING),',','') AS DOUBLE)  AS m_cartor,
    try_cast(replace(CAST(zero_max      AS STRING),',','') AS DOUBLE)  AS m_zero,
    try_cast(replace(CAST(c_25_max      AS STRING),',','') AS DOUBLE)  AS m_25,
    try_cast(replace(CAST(c_75_max      AS STRING),',','') AS DOUBLE)  AS m_75,
    try_cast(replace(CAST(str75_max     AS STRING),',','') AS DOUBLE)  AS m_str75,
    try_cast(replace(CAST(one_max       AS STRING),',','') AS DOUBLE)  AS m_one,
    try_cast(replace(CAST(prod_max      AS STRING),',','') AS DOUBLE)  AS m_prod,
    try_cast(replace(CAST(strmpr025_max AS STRING),',','') AS DOUBLE)  AS m_strmpr025,
    COALESCE(try_to_date(CAST(business_date AS STRING),'yyyyMMdd'),
             try_cast(CAST(business_date AS STRING) AS DATE))          AS Business_Date
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_ats_summary`
)
SELECT
  a.Line,
  CASE WHEN a.Line LIKE 'CP%' THEN 'CP'
       WHEN a.Line LIKE 'HC%' THEN 'HC'
       ELSE 'Other' END                                                 AS Line_Class,
  s.Scenario_Name,
  s.Scenario_Exposure,
  a.Counterparty_Name,
  a.Booking_Entity,
  a.Industry,
  CASE
    WHEN a.sic_code = '7298'                     THEN 'Hedge Funds'
    WHEN upper(a.industry_coarse) LIKE 'BANK%'   THEN 'Banks'
    WHEN upper(a.industry_coarse) LIKE 'GOV%'    THEN 'Government'
    WHEN upper(a.industry_coarse) LIKE 'FINANC%' THEN 'Financial'
    ELSE 'Corporates'
  END                                                                  AS Client_Type,
  a.Line_Worst_Rating,
  a.OTC_SFT,
  a.Limit_Amount,
  a.Business_Date
FROM ats_clean a
LATERAL VIEW stack(8,
  'Base/Cartor',      a.m_cartor,
  'Zero',             a.m_zero,
  '25th',             a.m_25,
  '75th',             a.m_75,
  'Stress 75',        a.m_str75,
  'Correlation 1.0',  a.m_one,
  'Product',          a.m_prod,
  'Stress MPR 0.25',  a.m_strmpr025
) s AS Scenario_Name, Scenario_Exposure
;

-- =====================================================================
-- VALIDATION
-- =====================================================================
-- V-GRAIN  8 scenario rows per line: out_rows = ats_summary lines × 8.
SELECT
  (SELECT COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.pfe_ats_summary) AS lines_,
  (SELECT COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_asts_scenario) AS out_rows,
  (SELECT COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_asts_scenario) * 1.0 /
    NULLIF((SELECT COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.pfe_ats_summary),0) AS ratio_should_be_8;
-- V-TIE  scenario fact must tie to the line fact: MAX(Scenario_Exposure) per line
--        should equal vw_pfe_ats_lines_detail.Stress_PFE for that line.
SELECT sc.Line,
       MAX(sc.Scenario_Exposure) AS scn_greatest,
       ld.Stress_PFE
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_asts_scenario sc
JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail ld ON ld.Line = sc.Line
GROUP BY sc.Line, ld.Stress_PFE
HAVING ABS(MAX(sc.Scenario_Exposure) - ld.Stress_PFE) > 1     -- expect ~0 rows (they tie)
LIMIT 20;
-- V-SCEN  8 scenarios present with the friendly names, incl. Base.
SELECT Scenario_Name, COUNT(*) AS lines_, ROUND(SUM(Scenario_Exposure)/1e9,3) AS exposure_b
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_asts_scenario
GROUP BY Scenario_Name ORDER BY exposure_b DESC;
