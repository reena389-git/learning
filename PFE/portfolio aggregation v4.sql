-- =============================================================================
-- portfolio_aggregation_v4.sql   (PRODUCTION-SHAPED — one view, demo retired)
--
-- WHAT CHANGED vs v3
--   * vw_cp_stress_hist_demo is GONE. History now lives in the tables themselves
--     (ats_summary / asts carry multiple business_dates after the backfill), so
--     there is nothing to fabricate. One model, demo and live — identical shape.
--   * vw_asts_portfolio_cp_stress now carries the FULL column set, including
--     limit_amt + utilization (previously only on the demo view). Even where a
--     value is thin today (standard_pfe = 0 while Cartor is empty) the column is
--     present so the Strategy model never changes between now and go-live.
--   * limit is the asts bucket-matched limit (same basis as vw_ast_breach_report).
--   * utilization is a RATIO (1.94), matching the breach report.
--
--   catalog d4001-centralus-tdvip-creditrisk   schema xvala_core
--   GRAIN  : counterparty x otc_sft x entity x business_date   (unchanged from v3)
--   SOURCE : ats_summary (scenarios + dims) ; asts (bucket-matched limit)
--
-- STRATEGY AGGREGATION TYPES (set these in the model)
--   Sum  : stress_pfe, stress_pfe_excl_base, standard_pfe, the 8 cp_* scenarios,
--          AND limit_amt  (it is SUM(line bucket-limits) -> additive across grain)
--   Do NOT Sum utilization — it is a row-grain ratio. For any roll-up build a
--          COMPOUND metric  Sum(stress_pfe) / Sum(limit_amt)  (see R3 for the pattern).
--   Count Counterparty -> Count Distinct (a CP spans product x entity x month rows).
-- =============================================================================


CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts_portfolio_cp_stress` AS
WITH line_level AS (
  -- one row per LINE per load; NULL scenarios -> 0; entity parsed from the line
  SELECT
    `business_date`,
    `long_name`                          AS counterparty,
    `industry`, `sic_industry`, `country_of_risk`, `region`,
    `worst_rating_of_associated_clients` AS worst_rating,
    `otc_sft`,
    regexp_extract(`line`, '\\(([^)]+)\\)', 1)  AS entity,
    COALESCE(`cartor_max`,0)    AS cartor,  COALESCE(`zero_max`,0)   AS zero,
    COALESCE(`c_25_max`,0)      AS c_25,    COALESCE(`c_75_max`,0)   AS c_75,
    COALESCE(`str75_max`,0)     AS str75,   COALESCE(`one_max`,0)    AS one,
    COALESCE(`prod_max`,0)      AS prod,    COALESCE(`strmpr025_max`,0) AS strmpr025
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`ats_summary`
),
cp_scn AS (   -- STEP 1: SUM each scenario across the CP's lines (per product/entity/date)
  SELECT
    `business_date`, counterparty, otc_sft, entity,
    MAX(industry) industry, MAX(sic_industry) sic_industry,
    MAX(country_of_risk) country_of_risk, MAX(region) region, MAX(worst_rating) worst_rating,
    SUM(cartor) cp_cartor, SUM(zero) cp_zero, SUM(c_25) cp_c_25, SUM(c_75) cp_c_75,
    SUM(str75) cp_str75, SUM(one) cp_one, SUM(prod) cp_prod, SUM(strmpr025) cp_strmpr025
  FROM line_level
  GROUP BY `business_date`, counterparty, otc_sft, entity
),
cp_stress AS (   -- STEP 2: stress PFE = worst scenario among the sums
  SELECT *,
    GREATEST(cp_cartor,cp_zero,cp_c_25,cp_c_75,cp_str75,cp_one,cp_prod,cp_strmpr025) AS stress_pfe,
    GREATEST(cp_zero,cp_c_25,cp_c_75,cp_str75,cp_one,cp_prod,cp_strmpr025)            AS stress_pfe_excl_base,
    cp_cartor                                                                         AS standard_pfe
  FROM cp_scn
),
cp_named AS (   -- worst-scenario name (severity-ordered tie-break)
  SELECT *,
    CASE
      WHEN stress_pfe = cp_one THEN 'one'      WHEN stress_pfe = cp_str75 THEN 'str75'
      WHEN stress_pfe = cp_c_75 THEN 'c_75'    WHEN stress_pfe = cp_prod  THEN 'prod'
      WHEN stress_pfe = cp_strmpr025 THEN 'strmpr025'
      WHEN stress_pfe = cp_c_25 THEN 'c_25'    WHEN stress_pfe = cp_zero  THEN 'zero'
      ELSE 'cartor'
    END AS worst_scenario
  FROM cp_stress
),
asts_lim AS (   -- NEW: asts bucket-matched limit, summed to CP x otc x entity x date
                -- (same definition as vw_ast_breach_report; entity parsed like above)
  SELECT `business_date`, counterparty, otc_sft, entity, SUM(bucket_limit) AS limit_amt
  FROM (
    SELECT
      a.`business_date`,
      a.`Long_Name`                                  AS counterparty,
      regexp_extract(a.`Line`, '\\(([^)]+)\\)', 1)   AS entity,
      s.`otc_sft`,
      CASE a.`Max_Exp_Time_Bucket`
        WHEN 'max_usage_0_3_mo'   THEN CAST(REPLACE(a.`Limit_3_mo`, ',','') AS DOUBLE)
        WHEN 'max_usage_3_12_mo'  THEN CAST(REPLACE(a.`Limit_1_Yr`, ',','') AS DOUBLE)
        WHEN 'max_usage_1_2_yr'   THEN CAST(REPLACE(a.`Limit_2_Yr`, ',','') AS DOUBLE)
        WHEN 'max_usage_2_5_yr'   THEN CAST(REPLACE(a.`Limit_5_Yr`, ',','') AS DOUBLE)
        WHEN 'max_usage_5_10_yr'  THEN CAST(REPLACE(a.`Limit_10_Yr`,',','') AS DOUBLE)
        WHEN 'max_usage_10_50_yr' THEN CAST(REPLACE(a.`Limit_50_Yr`,',','') AS DOUBLE)
        ELSE NULL END AS bucket_limit,
      ROW_NUMBER() OVER (PARTITION BY a.`business_date`, a.`Line`
        ORDER BY CAST(REPLACE(a.`Max_Scenario_Exposure`,',','') AS DOUBLE) DESC) AS rn
    FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`asts` a
    LEFT JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`ats_summary` s
           ON s.`line` = a.`Line` AND s.`business_date` = a.`business_date`   -- both yyyymmdd
    WHERE a.`No_Line_Indicator` = 'False'
  ) z
  WHERE rn = 1
  GROUP BY `business_date`, counterparty, otc_sft, entity
)
SELECT
  n.`business_date`,
  n.counterparty, n.otc_sft, n.entity,
  n.industry, n.sic_industry, n.country_of_risk, n.region, n.worst_rating,
  CASE
    WHEN upper(n.worst_rating) LIKE '%NIG%' THEN 'NIG'
    WHEN n.worst_rating RLIKE '^[0-9]' THEN
      CASE WHEN CAST(regexp_extract(n.worst_rating,'^([0-9]+)',1) AS INT) >= 6
           THEN '5+' ELSE regexp_extract(n.worst_rating,'^([0-9]+)',1) END
    ELSE 'Unrated'
  END AS brr_bucket,
  n.cp_cartor, n.cp_zero, n.cp_c_25, n.cp_c_75, n.cp_str75, n.cp_one, n.cp_prod, n.cp_strmpr025,
  n.stress_pfe, n.stress_pfe_excl_base, n.standard_pfe,
  n.worst_scenario,
  CASE n.worst_scenario
    WHEN 'one' THEN 'Systemic / full-correlation'  WHEN 'str75' THEN 'Market stress'
    WHEN 'c_75' THEN 'Elevated correlation'         WHEN 'c_25'  THEN 'Low correlation'
    WHEN 'zero' THEN 'Diversified'                  WHEN 'prod'  THEN 'Name-specific / product'
    WHEN 'strmpr025' THEN 'Margin-period-of-risk'   ELSE 'Base case'
  END AS risk_driver,
  l.limit_amt,                                                    -- NEW (Sum-able)
  ROUND(n.stress_pfe / NULLIF(l.limit_amt,0), 4) AS utilization   -- NEW: RATIO (do NOT Sum)
FROM cp_named n
LEFT JOIN asts_lim l
  ON  l.`business_date` = n.`business_date`
  AND l.counterparty    = n.counterparty
  AND l.otc_sft         = n.otc_sft
  AND l.entity          = n.entity;


-- =============================================================================
-- RUNBOOK  (now reads REAL history off business_date — no demo view)
-- =============================================================================

-- R1  Trajectory + fingerprint : latest load, one row per CP x product x entity,
--     with MoM vs the immediately prior business_date.
WITH ranked AS (
  SELECT *, DENSE_RANK() OVER (ORDER BY `business_date` DESC) AS dr
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts_portfolio_cp_stress`
),
cur AS (SELECT * FROM ranked WHERE dr = 1),
prv AS (SELECT counterparty, otc_sft, entity, utilization AS u_prev FROM ranked WHERE dr = 2)
SELECT
  cur.counterparty, cur.otc_sft, cur.entity, cur.industry, cur.brr_bucket, cur.country_of_risk,
  cur.stress_pfe, cur.standard_pfe, cur.limit_amt, cur.utilization,
  prv.u_prev AS utilization_prev,
  ROUND(cur.utilization - prv.u_prev, 4) AS mom_delta,
  cur.cp_cartor, cur.cp_zero, cur.cp_c_25, cur.cp_c_75,
  cur.cp_str75, cur.cp_one, cur.cp_prod, cur.cp_strmpr025
FROM cur LEFT JOIN prv USING (counterparty, otc_sft, entity)
ORDER BY cur.utilization DESC;

-- R2  Sparkline : every load per CP x product x entity (oldest -> newest).
SELECT counterparty, otc_sft, entity, `business_date`, utilization
FROM   `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts_portfolio_cp_stress`
ORDER  BY counterparty, otc_sft, entity, `business_date`;

-- R3  Delta strip : New / Worsening / Improving / Cleared, per product.
--     NOTE the compound roll-up: entity is collapsed to CP with util = Sum(stress)/Sum(limit)
--     (this is the correct way to aggregate utilisation — never average the ratio).
WITH cp AS (
  SELECT `business_date`, counterparty, otc_sft,
         SUM(stress_pfe) AS s, SUM(limit_amt) AS l,
         SUM(stress_pfe) / NULLIF(SUM(limit_amt),0) AS util
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts_portfolio_cp_stress`
  GROUP BY `business_date`, counterparty, otc_sft
),
ranked AS (SELECT *, DENSE_RANK() OVER (ORDER BY `business_date` DESC) AS dr FROM cp),
cur AS (SELECT * FROM ranked WHERE dr = 1),
prv AS (SELECT counterparty, otc_sft, util AS u_prev FROM ranked WHERE dr = 2)
SELECT cur.otc_sft,
  SUM(CASE WHEN cur.util>=1.0 AND u_prev<1.0  THEN 1 ELSE 0 END) AS new_breaches,
  SUM(CASE WHEN cur.util>=1.0 AND cur.util>u_prev AND u_prev>=1.0 THEN 1 ELSE 0 END) AS worsening,
  SUM(CASE WHEN cur.util>=1.0 AND cur.util<u_prev THEN 1 ELSE 0 END) AS improving,
  SUM(CASE WHEN cur.util<1.0  AND u_prev>=1.0 THEN 1 ELSE 0 END) AS cleared
FROM cur LEFT JOIN prv USING (counterparty, otc_sft)
GROUP BY cur.otc_sft;


-- =============================================================================
-- VALIDATION
-- =============================================================================
-- V1  Fingerprint sanity: GREATEST of the 8 sums must equal stress_pfe.
SELECT COUNT(*) AS mismatched
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts_portfolio_cp_stress`
WHERE stress_pfe <> GREATEST(cp_cartor,cp_zero,cp_c_25,cp_c_75,cp_str75,cp_one,cp_prod,cp_strmpr025);

-- V2  History present: should show every business_date now in ats_summary.
SELECT `business_date`, COUNT(*) AS rows, ROUND(SUM(stress_pfe)) AS tot_stress,
       SUM(CASE WHEN limit_amt IS NULL THEN 1 ELSE 0 END) AS null_limit
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts_portfolio_cp_stress`
GROUP BY `business_date` ORDER BY `business_date`;

-- V3  Limit coverage: utilisation is NULL only where limit_amt is NULL.
SELECT COUNT(*) AS rows, COUNT(limit_amt) AS limit_pop, COUNT(utilization) AS util_pop
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts_portfolio_cp_stress`;


-- =============================================================================
-- RETIRE the demo view (history now lives in the tables; nothing reads it once
-- the dashboard points at vw_asts_portfolio_cp_stress).
-- =============================================================================
-- DROP VIEW IF EXISTS `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_cp_stress_hist_demo`;
