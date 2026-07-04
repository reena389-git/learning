-- =====================================================================
-- vw_pfe_ats_lines_detail   (v2 — LINE FACT; ats_summary folded in)
--   (was vw_pfe_line_detail; renamed because ats_summary cleaning is now inline)
-- Catalog d4001-centralus-tdvip-creditrisk · Schema xvala_core
--
-- WHY THIS VIEW EXISTS (rationale)
--   THE line fact — one row per credit line — and the line-grain object the whole
--   model hangs on. It assembles line measures from across the sources:
--     • ats_summary (folded in as the ats_clean CTE)  -> limits, 8 scenario maxima,
--       Line_Worst_Rating, OTC_SFT, denormalized CP reference attrs, Client_Type,
--       Booking_Entity (derived).  [was the separate vw_ats_summary — now inline,
--       since the line fact is its only consumer.]
--     • vw_asts   -> the 5 breach flags -> Is_Breached (window-MAX OR, dedup-proof).
--     • pfe_lines_report source=CARTOR       -> IA (initial_margin), Line_MTM_Base.
--     • pfe_lines_report source=STRMARKETC75 -> Line_MTM_Stress.
--     • pfe_exp_decomp_report product_group='Lines_Report - With IM', source=CARTOR -> IM
--       (= max_usage_0_3_mo, the line-level 0-3 bucket Initial Margin).
--
--   COMPUTES (not just joins): Is_Breached (window-MAX OR of 5 flags); Utilization
--   (ratio — metadata flags rederive_in_bi); Booking_Entity (regex parse of Line);
--   Client_Type (5-bucket industry rollup); the STRING->DOUBLE casts.
--   JOINS-as-context: IM/IA/MTM decorate the line, each via a scenario/product
--   filter that makes the joined source unique per line (no fan-out).
--
-- GRAIN   one row per line       KEY  Line (conformed trim(upper))
-- LINEAGE reconciled to PFE Column metadata (26 cols) + PFE Data Checks.
-- SAFETY  type-safe (try_cast DOUBLE), null-safe (No_Line_Indicator=false; flags
--   OR'd safely; COALESCE Is_Breached), explicit columns, LEFT JOINs so the ~73-line
--   CARTOR surplus and any missing IA/MTM rows are harmless.
-- =====================================================================
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` (
  Line              COMMENT 'Credit line identifier. Conformed key (trim(upper)). The spine every fact joins on. Line IS the Counterparty_Line_Code: for CP-format lines Line = pfe_clients_report.counterparty_code (join CP dim directly); for HC-format lines Line is an agent/facility key not in clients_report.',
  Line_Class        COMMENT 'CP or HC. DERIVED from the Line prefix. CP = counterparty line (Line = counterparty_code, joins the CP dimension). HC = agent/fund/house facility line (not a counterparty_code; null on CP dim but self-attributed here). Portfolio selector/filter; decomposes the CP+HC total (no double-count).',
  Counterparty_Name COMMENT 'Counterparty / line long name.',
  Booking_Entity    COMMENT 'Booking entity. DERIVED: first parenthesised token of Line — regexp_extract(Line, ''\\(([^)]+)\\)'', 1). E.g. CP_(TDBK)_(SKBS_DBL) -> TDBK.',
  Industry          COMMENT 'Granular industry (sic_industry). Denormalized counterparty reference attribute; refreshed each load.',
  Client_Type       COMMENT 'Client type (business label). DERIVED 5-bucket higher-level industry classification from sic_code (Hedge Funds = SIC 7298). Industry-based rollup, not a literal client-type field.',
  Line_Worst_Rating COMMENT 'Worst rating among the line''s associated clients (brr). LINE-GRAIN. Distinct from the counterparty''s own rating — not conformed.',
  OTC_SFT           COMMENT 'OTC vs SFT split. Line-level.',
  Stress_PFE        COMMENT 'Line stressed PFE = GREATEST of the 8 scenario maxima (ats_summary.max_of_all). ADDITIVE across lines; not across scenarios.',
  Standard_PFE      COMMENT 'Line standard/base PFE (cartor_max). Additive across lines.',
  Limit_Amount      COMMENT 'Approved limit (peak bucket). Additive (utilization denominator).',
  Utilization       COMMENT 'Stress PFE / Limit at LINE grain. NON-additive — recompute SUM(Stress_PFE)/SUM(Limit) at each roll-up level; never sum the stored ratio.',
  Is_Breached       COMMENT 'Y/N. Window-MAX OR of the 5 *_Excess_Breach flags in vw_asts (no 0_3_mo flag). Dedup-proof; the only breach signal (approaching = BI filter on Utilization).',
  Worst_Scenario    COMMENT 'Scenario that produced the worst exposure (ats_summary.scenario_of_max). ats_summary scenario vocabulary — see dim_scenario.',
  IM                COMMENT 'Initial Margin (line-level, 0-3 bucket). From pfe_exp_decomp_report max_usage_0_3_mo where product_group=''Lines_Report - With IM'', source=CARTOR. COALESCED to 0 (no IM posted = 0; ~99% of lines). NOTE: varies by scenario in source — base taken; definition to confirm with data owner.',
  IA                COMMENT 'Independent Amount. From pfe_lines_report.initial_margin (source=CARTOR, active line_type). COALESCED to 0 (IA is genuinely zero/absent for ~99% of lines — only ~98 carry a value; data reality). Line/agreement level, not per deal.',
  Line_MTM_Base     COMMENT 'Current mark-to-market (base). From pfe_lines_report source=CARTOR. Un-shocked. Additive across lines.',
  Line_MTM_Stress   COMMENT 'Line MTM under the 75% market stress. From pfe_lines_report source=STRMARKETC75 (only scenario whose MTM differs from base). Additive across lines.',
  Line_Scn_Cartor_Base    COMMENT 'Scenario maximum — Base/Cartor. SEMI-ADDITIVE (sum across lines; GREATEST across scenarios).',
  Line_Scn_Zero           COMMENT 'Scenario maximum — Zero. Semi-additive.',
  Line_Scn_25th           COMMENT 'Scenario maximum — 25th. Semi-additive.',
  Line_Scn_75th           COMMENT 'Scenario maximum — 75th. Semi-additive.',
  Line_Scn_Stress75       COMMENT 'Scenario maximum — Stress 75. Semi-additive.',
  Line_Scn_Correlation_1  COMMENT 'Scenario maximum — Correlation 1.0. Semi-additive.',
  Line_Scn_Product        COMMENT 'Scenario maximum — Product. Semi-additive.',
  Line_Scn_Stress_MPR_025 COMMENT 'Scenario maximum — Stress MPR 0.25. Semi-additive.',
  Business_Date     COMMENT 'As-of date, normalized to DATE.'
)
AS
WITH ats_clean AS (
  -- (folded-in vw_ats_summary) type-safe line-grain clean of pfe_ats_summary.
  SELECT
    trim(upper(line))                                                  AS Line,
    long_name                                                          AS Counterparty_Name,
    regexp_extract(line, '\\(([^)]+)\\)', 1)                           AS Booking_Entity,
    sic_industry                                                       AS Industry,
    industry                                                           AS industry_coarse,   -- drives Client_Type
    sic_code                                                           AS sic_code,
    worst_rating_of_associated_clients                                AS Line_Worst_Rating,
    otc_sft                                                            AS OTC_SFT,
    scenario_of_max                                                    AS Worst_Scenario,
    try_cast(replace(CAST(max_of_all AS STRING),',','') AS DOUBLE)     AS Stress_PFE,
    try_cast(replace(CAST(cartor_max AS STRING),',','') AS DOUBLE)     AS Standard_PFE,
    GREATEST(
      try_cast(replace(CAST(limit_3_mo  AS STRING),',','') AS DOUBLE),
      try_cast(replace(CAST(limit_1_yr  AS STRING),',','') AS DOUBLE),
      try_cast(replace(CAST(limit_2_yr  AS STRING),',','') AS DOUBLE),
      try_cast(replace(CAST(limit_5_yr  AS STRING),',','') AS DOUBLE),
      try_cast(replace(CAST(limit_10_yr AS STRING),',','') AS DOUBLE)
    )                                                                  AS Limit_Amount,
    try_cast(replace(CAST(cartor_max    AS STRING),',','') AS DOUBLE)  AS Line_Scn_Cartor_Base,
    try_cast(replace(CAST(zero_max      AS STRING),',','') AS DOUBLE)  AS Line_Scn_Zero,
    try_cast(replace(CAST(c_25_max      AS STRING),',','') AS DOUBLE)  AS Line_Scn_25th,
    try_cast(replace(CAST(c_75_max      AS STRING),',','') AS DOUBLE)  AS Line_Scn_75th,
    try_cast(replace(CAST(str75_max     AS STRING),',','') AS DOUBLE)  AS Line_Scn_Stress75,
    try_cast(replace(CAST(one_max       AS STRING),',','') AS DOUBLE)  AS Line_Scn_Correlation_1,
    try_cast(replace(CAST(prod_max      AS STRING),',','') AS DOUBLE)  AS Line_Scn_Product,
    try_cast(replace(CAST(strmpr025_max AS STRING),',','') AS DOUBLE)  AS Line_Scn_Stress_MPR_025,
    COALESCE(try_to_date(CAST(business_date AS STRING),'yyyyMMdd'),
             try_cast(CAST(business_date AS STRING) AS DATE))          AS Business_Date
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_ats_summary`
),
breach AS (
  -- Is_Breached = ANY of the 5 flags TRUE across the line's scenario rows (window-MAX, dedup-proof).
  SELECT
    Line,
    CASE WHEN MAX(
      CASE WHEN `3_12_mo_Excess_Breach`  = 'TRUE' OR `1_2_Yr_Excess_Breach`  = 'TRUE'
            OR `2_5_Yr_Excess_Breach`   = 'TRUE' OR `5_10_Yr_Excess_Breach` = 'TRUE'
            OR `10_50_Yr_Excess_Breach` = 'TRUE'
           THEN 1 ELSE 0 END
    ) = 1 THEN 'Y' ELSE 'N' END                                        AS Is_Breached
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts`
  WHERE No_Line_Indicator = false
  GROUP BY Line
),
lines_cartor AS (
  -- IA + base MTM from the CARTOR (base) scenario row.
  -- IA = pfe_lines_report.initial_margin (per requirement: "IA is Initial Margin from lines report").
  -- no_line_indicator=false selects the one active line_type -> one row per line.
  SELECT
    trim(upper(line))                                                  AS Line,
    try_cast(replace(CAST(initial_margin AS STRING),',','') AS DOUBLE) AS IA,
    try_cast(replace(CAST(mark_to_market AS STRING),',','') AS DOUBLE) AS Line_MTM_Base
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_lines_report`
  WHERE source = 'CARTOR'
    AND no_line_indicator = false
),
lines_stress AS (
  -- Stress MTM from the market-stress scenario row. Same grain/filter logic:
  -- no_line_indicator=false gives the one active line_type -> one row per line.
  SELECT
    trim(upper(line))                                                  AS Line,
    try_cast(replace(CAST(mark_to_market AS STRING),',','') AS DOUBLE) AS Line_MTM_Stress
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_lines_report`
  WHERE source = 'STRMARKETC75'
    AND no_line_indicator = false
),
im AS (
  -- IM = the line-level Initial Margin for the 0-3 bucket, from the exp_decomp
  -- 'Lines_Report - With IM' slice (per requirement: "IM is the line level IM for 0-3 bucket").
  -- exp_decomp grain is line × line_type × product_group × source (source = scenario).
  -- NOTE: pfe_exp_decomp_report has NO no_line_indicator column (unlike lines_report) — do NOT
  -- filter on it. The IM slice (product_group='Lines_Report - With IM' + source='CARTOR') is
  -- UNIQUE per line — confirmed: GROUP BY line,source,product_group HAVING COUNT(*)>1 = 0 rows.
  -- So it joins 1:1 to the line (no fan-out); no GROUP BY needed.
  -- (confirm with data owner): max_usage_0_3_mo varies by source/scenario (~doubles under
  -- stress) — unusual for a collateral term. Base (CARTOR) taken here; flag the definition.
  SELECT
    trim(upper(line))                                                  AS Line,
    try_cast(replace(CAST(max_usage_0_3_mo AS STRING),',','') AS DOUBLE) AS IM
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_exp_decomp_report`
  WHERE product_group = 'Lines_Report - With IM'
    AND source = 'CARTOR'
)
SELECT
  a.Line,
  -- Line_Class: CP (counterparty line, = counterparty_code) vs HC (agent/fund/house facility).
  -- Derived from the Line prefix. Drives the portfolio CP/HC selector; CP+HC are disjoint (no double-count).
  CASE WHEN a.Line LIKE 'CP%' THEN 'CP'
       WHEN a.Line LIKE 'HC%' THEN 'HC'
       ELSE 'Other' END                                                 AS Line_Class,
  a.Counterparty_Name,
  a.Booking_Entity,
  a.Industry,
  CASE
    WHEN a.sic_code = '7298'                       THEN 'Hedge Funds'
    WHEN upper(a.industry_coarse) LIKE 'BANK%'     THEN 'Banks'
    WHEN upper(a.industry_coarse) LIKE 'GOV%'      THEN 'Government'
    WHEN upper(a.industry_coarse) LIKE 'FINANC%'   THEN 'Financial'
    ELSE 'Corporates'
  END                                                                  AS Client_Type,
  a.Line_Worst_Rating,
  a.OTC_SFT,
  a.Stress_PFE,
  a.Standard_PFE,
  a.Limit_Amount,
  a.Stress_PFE / NULLIF(a.Limit_Amount, 0)                             AS Utilization,
  COALESCE(b.Is_Breached, 'N')                                         AS Is_Breached,
  a.Worst_Scenario,
  COALESCE(lc.IA, 0)                                                   AS IA,
  COALESCE(im.IM, 0)                                                   AS IM,
  lc.Line_MTM_Base,
  ls.Line_MTM_Stress,
  a.Line_Scn_Cartor_Base,
  a.Line_Scn_Zero,
  a.Line_Scn_25th,
  a.Line_Scn_75th,
  a.Line_Scn_Stress75,
  a.Line_Scn_Correlation_1,
  a.Line_Scn_Product,
  a.Line_Scn_Stress_MPR_025,
  a.Business_Date
FROM ats_clean a
LEFT JOIN breach       b  ON b.Line  = a.Line
LEFT JOIN lines_cartor lc ON lc.Line = a.Line
LEFT JOIN lines_stress ls ON ls.Line = a.Line
LEFT JOIN im              ON im.Line = a.Line
;

-- =====================================================================
-- VALIDATION  (run each; expected numbers in comments)
-- =====================================================================
-- V-GRAIN  one row per line (ats_summary is line grain; all joins 1:1 per line).
--   EXPECT rows_ = lines_ = 11,804 (no fan-out).
SELECT COUNT(*) AS rows_, COUNT(DISTINCT Line) AS lines_
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail;
-- V-CLASS  CP/HC split + exposure. EXPECT: CP 10,417 lines ~121.08bn ; HC 1,387 lines ~84.41bn.
--   (Confirms Line_Class populates and the CP+HC decomposition matches the portfolio total.)
SELECT Line_Class,
       COUNT(DISTINCT Line)  AS lines_,
       ROUND(SUM(Stress_PFE)/1e6, 0) AS stress_pfe_MM
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail
GROUP BY Line_Class ORDER BY Line_Class;
-- V-CPDIM  CP-dimension coverage. EXPECT: CP lines match counterparty_code; HC lines do not.
--   matched ~10,417 ; unmatched ~1,387 (the HC lines, self-attributed, null on CP dim by design).
SELECT
  SUM(CASE WHEN c.counterparty_code IS NOT NULL THEN 1 ELSE 0 END) AS cp_dim_matched,
  SUM(CASE WHEN c.counterparty_code IS NULL     THEN 1 ELSE 0 END) AS cp_dim_unmatched
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail d
LEFT JOIN (SELECT DISTINCT trim(upper(counterparty_code)) AS counterparty_code
           FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_clients_report`) c
  ON d.Line = c.counterparty_code;
-- V-BREACH  Is_Breached='Y' should reproduce the prior breach set (~132).
SELECT Is_Breached, COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail GROUP BY Is_Breached;
-- V-POP  measure NULLs = lines absent from those sources (LEFT JOIN misses).
--   Post-coalesce EXPECT: null_im=0, null_ia=0 (IA/IM coalesced to 0); null_mtm_base~107.
SELECT
  SUM(CASE WHEN IM              IS NULL THEN 1 ELSE 0 END) AS null_im,
  SUM(CASE WHEN IA              IS NULL THEN 1 ELSE 0 END) AS null_ia,
  SUM(CASE WHEN Line_MTM_Base   IS NULL THEN 1 ELSE 0 END) AS null_mtm_base,
  SUM(CASE WHEN Line_MTM_Stress IS NULL THEN 1 ELSE 0 END) AS null_mtm_stress
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail;
-- V-POP2  NULL-and-ZERO pattern for IA/IM/MTM by Line_Class (verifies coalesce + IA sparsity).
--   EXPECT (post-coalesce): ia_null=0, im_null=0 (all pushed to 0);
--   ia_zero ~10,536 (data reality — no independent amount posted on ~99% of lines);
--   mtm_base_null ~107 (CP lines absent from lines_report; HC fully covered -> 0).
SELECT
  Line_Class,
  COUNT(*)                                                  AS lines_,
  SUM(CASE WHEN IA = 0                THEN 1 ELSE 0 END)     AS ia_zero,
  SUM(CASE WHEN IA IS NULL            THEN 1 ELSE 0 END)     AS ia_null,
  SUM(CASE WHEN IM = 0                THEN 1 ELSE 0 END)     AS im_zero,
  SUM(CASE WHEN IM IS NULL            THEN 1 ELSE 0 END)     AS im_null,
  SUM(CASE WHEN Line_MTM_Base = 0     THEN 1 ELSE 0 END)     AS mtm_base_zero,
  SUM(CASE WHEN Line_MTM_Base IS NULL THEN 1 ELSE 0 END)     AS mtm_base_null
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail
GROUP BY Line_Class ORDER BY Line_Class;
-- V-ROLLUP  portfolio test: CP stress = GREATEST(SUM per scenario) vs naive SUM(Stress_PFE).
SELECT Counterparty_Name,
  GREATEST(SUM(Line_Scn_Cartor_Base),SUM(Line_Scn_Zero),SUM(Line_Scn_25th),SUM(Line_Scn_75th),
           SUM(Line_Scn_Stress75),SUM(Line_Scn_Correlation_1),SUM(Line_Scn_Product),SUM(Line_Scn_Stress_MPR_025)) AS correct_stress,
  SUM(Stress_PFE) AS naive_stress
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail
GROUP BY Counterparty_Name ORDER BY correct_stress DESC LIMIT 20;
