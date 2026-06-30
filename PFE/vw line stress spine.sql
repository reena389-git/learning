-- =============================================================================
-- vw_line_stress_spine.sql   (LINE-GRAIN SPINE — all lines, breached + approaching)
-- Databricks SQL.  Catalog: d4001-centralus-tdvip-creditrisk · schema xvala_core
--
-- PURPOSE: the missing line-grain layer. ONE row per line per business_date with
--   stress PFE, limit, utilization, breach STATUS (Breached / Approaching / OK),
--   and the line's worst scenario. Covers ALL lines (not just breached ones), so
--   "approaching breach" lines — which are absent from the breach view — appear.
--
--   This is the spine the breach view SHOULD filter from, and the source the deal
--   view joins to for per-deal breach context. Same stress/limit logic as
--   portfolio_aggregation_v6, but stopped at LINE grain (no CP rollup).
--
-- GRAIN  : line x business_date.
-- SOURCE : ats_summary (8 scenario maxima per line) + asts (bucket limit + No_Line).
-- STATUS bands: Breached util>=1.0 · Approaching 0.8-1.0 · OK <0.8 · (No Limit when
--   limit is a 1/2 source placeholder or null -> exposure without a real limit).
-- =============================================================================

CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_line_stress_spine` (
  Line              COMMENT 'Credit line / facility key. Join key for deals + breach.',
  Entity            COMMENT 'Parsed first parenthesised token of Line.',
  Counterparty_Name COMMENT 'counterparty (long name) from ats_summary.',
  OTC_SFT           COMMENT 'otc_sft product family.',
  Stress_PFE        COMMENT 'GREATEST across the 8 scenario maxima for this line.',
  Standard_PFE      COMMENT 'cartor (base) scenario maximum.',
  Worst_Scenario    COMMENT 'which of the 8 scenarios drives Stress_PFE (line-level fact).',
  Worst_Scenario_Label COMMENT 'human label of Worst_Scenario.',
  Limit_Amount      COMMENT 'bucket-matched limit from asts (Sum-able).',
  Utilization       COMMENT 'Stress_PFE / Limit_Amount (RATIO — do NOT Sum).',
  Breach_Status     COMMENT 'Breached (>=1.0) / Approaching (0.8-1.0) / OK (<0.8) / No Limit.',
  Is_Breaching      COMMENT 'Y when Utilization >= 1.0 else N.',
  Sector            COMMENT '5-bucket mapped sector (Banks/Government/Financial/Hedge Funds/Corporates).',
  Industry          COMMENT 'granular sic_industry.',
  Worst_Rating      COMMENT 'worst_rating_of_associated_clients.',
  Business_Date     COMMENT 'business_date.'
)
AS
WITH line_scn AS (   -- 8 scenario maxima per line (ats_summary is already line grain)
  SELECT
    s.`business_date`, s.`line` AS Line,
    regexp_extract(s.`line`, '\\(([^)]+)\\)', 1) AS Entity,
    s.`counterparty` AS Counterparty_Name, s.`otc_sft` AS OTC_SFT,
    s.`industry` AS industry_coarse, s.`sic_industry` AS Industry,
    s.`worst_rating_of_associated_clients` AS Worst_Rating,
    s.`sic_code` AS sic_code,
    s.`cartor_max` AS cartor, s.`zero_max` AS zero_, s.`c_25_max` AS c_25, s.`c_75_max` AS c_75,
    s.`str75_max` AS str75, s.`one_max` AS one_, s.`prod_max` AS prod, s.`strmpr025_max` AS strmpr025
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_ats_summary` s
),
line_named AS (
  SELECT *,
    GREATEST(cartor,zero_,c_25,c_75,str75,one_,prod,strmpr025) AS Stress_PFE,
    cartor AS Standard_PFE
  FROM line_scn
),
line_scn2 AS (
  SELECT *,
    CASE
      WHEN Stress_PFE = one_      THEN 'one'      WHEN Stress_PFE = str75 THEN 'str75'
      WHEN Stress_PFE = c_75      THEN 'c_75'     WHEN Stress_PFE = prod  THEN 'prod'
      WHEN Stress_PFE = strmpr025 THEN 'strmpr025'
      WHEN Stress_PFE = c_25      THEN 'c_25'     WHEN Stress_PFE = zero_ THEN 'zero'
      ELSE 'cartor'
    END AS Worst_Scenario
  FROM line_named
),
line_lim AS (   -- bucket-matched limit per line from asts (same logic as portfolio asts_lim)
  SELECT `business_date`, Line, bucket_limit AS Limit_Amount
  FROM (
    SELECT
      a.`business_date`,
      a.`Line` AS Line,
      CASE a.`Max_Exp_Time_Bucket`
        WHEN 'max_usage_0_3_mo'   THEN CAST(REPLACE(a.`Limit_3_mo`,',','') AS DOUBLE)
        WHEN 'max_usage_3_12_mo'  THEN CAST(REPLACE(a.`Limit_1_Yr`,',','') AS DOUBLE)
        WHEN 'max_usage_1_2_yr'   THEN CAST(REPLACE(a.`Limit_2_Yr`,',','') AS DOUBLE)
        WHEN 'max_usage_2_5_yr'   THEN CAST(REPLACE(a.`Limit_5_Yr`,',','') AS DOUBLE)
        WHEN 'max_usage_5_10_yr'  THEN CAST(REPLACE(a.`Limit_10_Yr`,',','') AS DOUBLE)
        WHEN 'max_usage_10_50_yr' THEN CAST(REPLACE(a.`Limit_50_Yr`,',','') AS DOUBLE)
        ELSE NULL END AS bucket_limit,
      ROW_NUMBER() OVER (PARTITION BY a.`business_date`, a.`Line`
        ORDER BY CAST(REPLACE(a.`Max_Scenario_Exposure`,',','') AS DOUBLE) DESC) AS rn
    FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_asts` a
    WHERE a.`No_Line_Indicator` = 'False'
  ) z
  WHERE rn = 1
)
SELECT
  n.Line, n.Entity, n.Counterparty_Name, n.OTC_SFT,
  n.Stress_PFE, n.Standard_PFE,
  n.Worst_Scenario,
  CASE n.Worst_Scenario
    WHEN 'cartor' THEN 'Base (Cartor)'      WHEN 'zero'  THEN 'Zero'
    WHEN 'c_25'   THEN '25th Percentile'    WHEN 'c_75'  THEN '75th Percentile'
    WHEN 'str75'  THEN 'Stress 75'          WHEN 'one'   THEN 'Correlation 1.0'
    WHEN 'prod'   THEN 'Product'            WHEN 'strmpr025' THEN 'Stress MPR 0.25'
    ELSE n.Worst_Scenario END                                AS Worst_Scenario_Label,
  l.Limit_Amount,
  ROUND(n.Stress_PFE / NULLIF(l.Limit_Amount,0), 4)          AS Utilization,
  -- STATUS: limit 1/2 = source placeholder -> 'No Limit' (exposure, no real limit)
  CASE
    WHEN l.Limit_Amount IS NULL OR l.Limit_Amount <= 2        THEN 'No Limit'
    WHEN n.Stress_PFE / l.Limit_Amount >= 1.0                 THEN 'Breached'
    WHEN n.Stress_PFE / l.Limit_Amount >= 0.8                 THEN 'Approaching'
    ELSE 'OK'
  END                                                         AS Breach_Status,
  CASE WHEN l.Limit_Amount > 2 AND n.Stress_PFE / l.Limit_Amount >= 1.0
       THEN 'Y' ELSE 'N' END                                 AS Is_Breaching,
  -- 5-bucket sector (aligned to portfolio/breach: HF via sic_code 7298)
  CASE
    WHEN n.sic_code = '7298'                 THEN 'Hedge Funds'
    WHEN upper(n.industry_coarse) LIKE 'BANK%'   THEN 'Banks'
    WHEN upper(n.industry_coarse) LIKE 'GOV%'    THEN 'Government'
    WHEN upper(n.industry_coarse) LIKE 'FINANC%' THEN 'Financial'
    ELSE 'Corporates'
  END                                                         AS Sector,
  n.Industry, n.Worst_Rating,
  to_date(regexp_replace(CAST(n.`business_date` AS STRING),'-',''),'yyyyMMdd') AS Business_Date
  -- (~) OUTPUT NORMALIZED: always a real DATE regardless of source datatype.
FROM line_scn2 n
LEFT JOIN line_lim l
  ON l.Line = n.Line
 AND regexp_replace(CAST(l.`business_date` AS STRING),'-','')
   = regexp_replace(CAST(n.`business_date` AS STRING),'-','')   -- datatype-agnostic
;

-- =============================================================================
-- VALIDATION
-- S1  status distribution (do approaching lines appear?)
-- SELECT Breach_Status, COUNT(*) lines, SUM(Stress_PFE) stress
-- FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_line_stress_spine
-- WHERE Business_Date='20260430' GROUP BY Breach_Status ORDER BY 2 DESC;
--
-- S2  breached lines should reconcile to the breach view's line count
-- SELECT COUNT(*) FROM ... WHERE Breach_Status='Breached' AND Business_Date='20260430';
--   -- compare to: SELECT COUNT(*) FROM vw_ast_breach_report WHERE ...
--
-- S3  worst-scenario spread across lines
-- SELECT Worst_Scenario_Label, COUNT(*) FROM ... GROUP BY 1 ORDER BY 2 DESC;
-- =============================================================================
