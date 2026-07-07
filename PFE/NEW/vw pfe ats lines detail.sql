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
--     • pfe_asts  -> the 5 breach flags -> Is_Breached (window-MAX OR, dedup-proof).
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
  Line              COMMENT 'The credit line, and the key every fact table joins on. For counterparty (CP) lines this value is also the counterparty code, so it links straight to the client dimension; for holding-company (HC) lines it''s a facility key that sits outside the client master.',
  Line_Class        COMMENT 'Marks each line as CP (a counterparty line) or HC (a holding-company facility) based on its code prefix. Lets the portfolio be split into its CP and HC halves, which are separate exposures that add up cleanly with no double-counting.',
  Counterparty_Name COMMENT 'The counterparty or line long name, as shown to users.',
  Booking_Entity    COMMENT 'The TD booking entity, pulled from the first bracketed token of the line code (e.g. CP_(TDBK)_(...) gives TDBK).',
  Industry          COMMENT 'The counterparty''s detailed industry (SIC), carried alongside the line and refreshed each load for easy slicing.',
  TD_Sub_Industry   COMMENT 'A Y/N flag from td_sub indicating whether the counterparty is a TD subsidiary / intragroup entity rather than an external third party. Relevant for separating external counterparty exposure from intragroup. Meaning to be confirmed with the data owner. (Alias retained as-is; not an industry classification.)',
  Client_Type       COMMENT 'A simplified client grouping rolled up from the SIC code into five buckets (e.g. SIC 7298 becomes Hedge Funds). It''s an industry-based classification, not a separate client-type field in the source.',
  Line_Worst_Rating COMMENT 'The worst rating among the clients associated with this line.',
  BRR               COMMENT 'The borrower / account risk rating for the line. Same rating concept as the deal fact''s Counterparty_Rating (td_account_rating); conform the two. Distinct from Line_Worst_Rating, which is the worst rating across the line''s clients.',
  OTC_SFT           COMMENT 'Whether the line is OTC derivatives or securities financing (SFT) — the main way the book is scoped.',
  Line_Type         COMMENT 'The line type (C2C or CONT).',
  Line_Currency     COMMENT 'The line''s currency.',
  Country_Of_Risk   COMMENT 'The country of risk, used for geographic slicing of the portfolio.',
  CIF_Country_Name  COMMENT 'The country name from the CIF record (for display).',
  Region            COMMENT 'The region, used to group the portfolio geographically.',
  Stress_PFE        COMMENT 'The line''s peak potential future exposure under stress, taken as the worst of its 8 scenario outcomes. Adds up across lines, but not across scenarios (each line already holds its own worst case).',
  Line_Standard_PFE      COMMENT 'The line''s base (unstressed) potential future exposure, taken from the cartor_max field — the maximum exposure under the Cartor (base) scenario. This is the unstressed counterpart to Stress_PFE. One value per line, additive across lines. Different from the scenario fact''s Standard_Exposure_Bucket, which is a per-scenario, bucket-level figure.',
  Stress_Over_Base  COMMENT 'How much the stress adds on top of the base exposure (stress minus base). Adds up across lines.',
  Impact_Pct        COMMENT 'How many times larger the stressed exposure is than the base (a ratio). Don''t sum it — it''s a per-line figure.',
  Limit_Amount      COMMENT 'The single largest limit across the line''s six tenor buckets — a coarse headline limit, not tied to where exposure actually sits. Effective_Limit is the preferred denominator for utilisation. (Being retired; hidden in the dashboard.)',
  Effective_Limit   COMMENT 'The limit of the specific tenor bucket where the line''s exposure peaks — the limit that actually governs that peak, so it is the correct denominator for utilisation. Falls back to the standard exposure where the peak bucket has no limit.',
  Max_Exp_Time_Bucket COMMENT 'The tenor bucket (e.g. 1-2yr) where the line''s exposure peaks. This is what selects the matching Effective_Limit.',
  Max_Scenario_Name COMMENT 'The scenario under which the line''s exposure peaks.',
  Utilization       COMMENT 'Stress_PFE divided by Effective_Limit — the line''s peak stressed exposure against the limit that governs it. A ratio: don''t sum it; roll it up as summed-exposure over summed-limit.',
  Utilization_Band  COMMENT 'Groups each line by how close it is to its limit (stress exposure over the bucket-matched limit): >=100%, 85-100%, 70-85%, <70%, or No Limit. Designed to catch lines approaching their limit before they actually breach.',
  Utilization_Band_Order COMMENT 'A simple 1-to-5 sort key so the bands display worst-first (>=100% down to No Limit) without needing number prefixes on the labels.',
  Is_Breached       COMMENT 'Whether the line has breached any of its tenor limits, shown as ''Breach'' / ''No Breach'' for readable filtering. Set to Breach if any of the six tenor buckets'' exposure exceeded its limit in any scenario. For lines close but not yet over, use the utilisation band.',
  Worst_Scenario    COMMENT 'The scenario that drove the line''s worst exposure (see vw_dim_scenario for the scenario names).',
  IM                COMMENT 'Initial margin held against the line (0 where none). A line-level collateral figure.',
  IA_IM_Total       COMMENT 'IA plus IM — total independent amount and initial margin held against the line, null-safe (each treated as 0 when absent). A combined collateral figure for business reporting.',
  IA                COMMENT 'Independent amount held against the line (0 where none). A line/agreement-level collateral figure.',
  Line_MTM_Base     COMMENT 'The line''s current mark-to-market, unstressed. Adds up across lines.',
  Line_MTM_Stress   COMMENT 'The line''s mark-to-market under the 75% market stress (the one scenario where MTM differs from base). Adds up across lines.',
  Line_Scn_Cartor_Base    COMMENT 'The line''s exposure under the Base / Cartor scenario (the unstressed baseline). Additive across lines; across scenarios take the worst.',
  Line_Scn_Zero           COMMENT 'The line''s exposure under the Zero scenario (zero-correlation stress). Additive across lines; across scenarios take the worst.',
  Line_Scn_25th           COMMENT 'The line''s exposure under the 25th-percentile correlation stress scenario. Additive across lines; across scenarios take the worst.',
  Line_Scn_75th           COMMENT 'The line''s exposure under the 75th-percentile correlation stress scenario. Additive across lines; across scenarios take the worst.',
  Line_Scn_Stress75       COMMENT 'The line''s exposure under the Stress 75 market scenario (75% market stress). Additive across lines; across scenarios take the worst.',
  Line_Scn_Correlation_1  COMMENT 'The line''s exposure under the Correlation 1.0 scenario (full-correlation stress, all risk factors moving together). Additive across lines; across scenarios take the worst.',
  Line_Scn_Product        COMMENT 'The line''s exposure under the Product scenario (the product-correlation stress). Additive across lines; across scenarios take the worst.',
  Line_Scn_Stress_MPR_025 COMMENT 'The line''s exposure under the Stress MPR 0.25 scenario (margin period of risk stress at 0.25). Additive across lines; across scenarios take the worst.',
  Business_Date     COMMENT 'The as-of date for the data.'
)
AS
WITH ats_clean AS (
  -- (folded-in vw_ats_summary) type-safe line-grain clean of pfe_ats_summary.
  SELECT
    trim(upper(line))                                                  AS Line,
    long_name                                                          AS Counterparty_Name,
    regexp_extract(line, '\\(([^)]+)\\)', 1)                           AS Booking_Entity,
    sic_industry                                                       AS Industry,
    td_sub                                                             AS TD_Sub_Industry,   -- (+) TD sub-industry/segment classifier from ats_summary (carry-all: was previously dropped)
    industry                                                           AS industry_coarse,   -- drives Client_Type
    sic_code                                                           AS sic_code,
    worst_rating_of_associated_clients                                AS Line_Worst_Rating,
    brr                                                               AS BRR,               -- (+) borrower risk rating (breach report used this as Rating)
    otc_sft                                                            AS OTC_SFT,
    line_type                                                         AS Line_Type,         -- (+) C2C / CONT
    line_currency                                                     AS Line_Currency,     -- (+)
    country_of_risk                                                   AS Country_Of_Risk,   -- (+) portfolio slicing
    cif_country_name                                                  AS CIF_Country_Name,  -- (+)
    region                                                           AS Region,            -- (+) regional grouping
    scenario_of_max                                                    AS Worst_Scenario,
    try_cast(replace(CAST(max_of_all AS STRING),',','') AS DOUBLE)     AS Stress_PFE,
    try_cast(replace(CAST(cartor_max AS STRING),',','') AS DOUBLE)     AS Line_Standard_PFE,
    try_cast(replace(CAST(max_all_less_cartor  AS STRING),',','') AS DOUBLE) AS Stress_Over_Base,   -- (+) incremental stress over baseline
    try_cast(replace(CAST(percentage_of_impact AS STRING),',','') AS DOUBLE) AS Impact_Pct,         -- (+) max_of_all / cartor_max ratio
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
  -- Is_Breached = ANY of the 6 flags TRUE across the line's scenario rows (window-MAX, dedup-proof).
  SELECT
    Line,
    CASE WHEN MAX(
      CASE WHEN `0_3_mo_Excess_Breach`  = 'TRUE' OR `3_12_mo_Excess_Breach`  = 'TRUE'
            OR `1_2_Yr_Excess_Breach`   = 'TRUE' OR `2_5_Yr_Excess_Breach`   = 'TRUE'
            OR `5_10_Yr_Excess_Breach`  = 'TRUE' OR `10_50_Yr_Excess_Breach` = 'TRUE'
           THEN 1 ELSE 0 END
    ) = 1 THEN 'Y' ELSE 'N' END                                        AS Is_Breached
  FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY Line, Scenario_Name, business_date ORDER BY report_run_at DESC) AS _run_rn
    FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_asts`
  ) pfe_asts
  WHERE _run_rn = 1
    AND COALESCE(CAST(No_Line_Indicator AS BOOLEAN), false) = false
  GROUP BY Line
),
eff_limit AS (
  -- BUCKET-MATCHED EFFECTIVE LIMIT (breach-report logic): for each line, take the
  -- worst-exposure scenario row (rn=1 by Max_Scenario_Exposure DESC), then pick the
  -- limit for the bucket that produced that max (Max_Exp_Time_Bucket). Fallback to
  -- Standard_Exposure if that bucket's limit is 0/null. This is the precise utilization
  -- denominator (vs GREATEST-of-all-limits). Also carries the driving bucket/scenario.
  SELECT Line, Max_Exp_Time_Bucket, Max_Scenario_Name, Effective_Limit
  FROM (
    SELECT
      Line,
      Max_Exp_Time_Bucket,
      Max_Scenario_Name,
      CASE
        WHEN Max_Exp_Time_Bucket = 'max_usage_0_3_mo'   AND try_cast(replace(CAST(Limit_3_mo  AS STRING),',','') AS DOUBLE) > 0 THEN try_cast(replace(CAST(Limit_3_mo  AS STRING),',','') AS DOUBLE)
        WHEN Max_Exp_Time_Bucket = 'max_usage_3_12_mo'  AND try_cast(replace(CAST(Limit_1_Yr  AS STRING),',','') AS DOUBLE) > 0 THEN try_cast(replace(CAST(Limit_1_Yr  AS STRING),',','') AS DOUBLE)
        WHEN Max_Exp_Time_Bucket = 'max_usage_1_2_yr'   AND try_cast(replace(CAST(Limit_2_Yr  AS STRING),',','') AS DOUBLE) > 0 THEN try_cast(replace(CAST(Limit_2_Yr  AS STRING),',','') AS DOUBLE)
        WHEN Max_Exp_Time_Bucket = 'max_usage_2_5_yr'   AND try_cast(replace(CAST(Limit_5_Yr  AS STRING),',','') AS DOUBLE) > 0 THEN try_cast(replace(CAST(Limit_5_Yr  AS STRING),',','') AS DOUBLE)
        WHEN Max_Exp_Time_Bucket = 'max_usage_5_10_yr'  AND try_cast(replace(CAST(Limit_10_Yr AS STRING),',','') AS DOUBLE) > 0 THEN try_cast(replace(CAST(Limit_10_Yr AS STRING),',','') AS DOUBLE)
        WHEN Max_Exp_Time_Bucket = 'max_usage_10_50_yr' AND try_cast(replace(CAST(Limit_50_Yr AS STRING),',','') AS DOUBLE) > 0 THEN try_cast(replace(CAST(Limit_50_Yr AS STRING),',','') AS DOUBLE)
        WHEN try_cast(replace(CAST(Standard_Exposure AS STRING),',','') AS DOUBLE) > 0 THEN try_cast(replace(CAST(Standard_Exposure AS STRING),',','') AS DOUBLE)
        ELSE NULL
      END                                                              AS Effective_Limit,
      ROW_NUMBER() OVER (PARTITION BY Line ORDER BY try_cast(replace(CAST(Max_Scenario_Exposure AS STRING),',','') AS DOUBLE) DESC) AS rn
    FROM (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY Line, Scenario_Name, business_date ORDER BY report_run_at DESC) AS _run_rn
      FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_asts`
    ) pfe_asts
    WHERE _run_rn = 1
      AND COALESCE(CAST(No_Line_Indicator AS BOOLEAN), false) = false
  ) z
  WHERE rn = 1
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
  a.TD_Sub_Industry,
  CASE
    WHEN a.sic_code = '7298'                       THEN 'Hedge Funds'
    WHEN upper(a.industry_coarse) LIKE 'BANK%'     THEN 'Banks'
    WHEN upper(a.industry_coarse) LIKE 'GOV%'      THEN 'Government'
    WHEN upper(a.industry_coarse) LIKE 'FINANC%'   THEN 'Financial'
    ELSE 'Corporates'
  END                                                                  AS Client_Type,
  a.Line_Worst_Rating,
  a.BRR,
  a.OTC_SFT,
  a.Line_Type,
  a.Line_Currency,
  a.Country_Of_Risk,
  a.CIF_Country_Name,
  a.Region,
  a.Stress_PFE,
  a.Standard_PFE,
  a.Stress_Over_Base,
  a.Impact_Pct,
  a.Limit_Amount,
  el.Effective_Limit,
  el.Max_Exp_Time_Bucket,
  el.Max_Scenario_Name,
  a.Stress_PFE / NULLIF(el.Effective_Limit, 0)                         AS Utilization,
  CASE
    WHEN el.Effective_Limit IS NULL OR el.Effective_Limit = 0 THEN 'No Limit'
    WHEN a.Stress_PFE / el.Effective_Limit >= 1.0  THEN '>=100%'
    WHEN a.Stress_PFE / el.Effective_Limit >= 0.85 THEN '85-100%'
    WHEN a.Stress_PFE / el.Effective_Limit >= 0.70 THEN '70-85%'
    ELSE '<70%'
  END                                                                  AS Utilization_Band,
  CASE
    WHEN el.Effective_Limit IS NULL OR el.Effective_Limit = 0 THEN 5
    WHEN a.Stress_PFE / el.Effective_Limit >= 1.0  THEN 1
    WHEN a.Stress_PFE / el.Effective_Limit >= 0.85 THEN 2
    WHEN a.Stress_PFE / el.Effective_Limit >= 0.70 THEN 3
    ELSE 4
  END                                                                  AS Utilization_Band_Order,
  CASE WHEN COALESCE(b.Is_Breached, 'N') = 'Y' THEN 'Breach' ELSE 'No Breach' END AS Is_Breached,
  a.Worst_Scenario,
  COALESCE(lc.IA, 0)                                                   AS IA,
  COALESCE(im.IM, 0)                                                   AS IM,
  COALESCE(lc.IA, 0) + COALESCE(im.IM, 0)                              AS IA_IM_Total,
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
LEFT JOIN eff_limit    el ON el.Line = a.Line
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
--   ia_zero ~10,536 (no independent amount posted on ~99% of lines);
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
