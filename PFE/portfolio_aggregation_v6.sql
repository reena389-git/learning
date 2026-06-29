-- =============================================================================
-- portfolio_aggregation_v6.sql   (INDUSTRY FIX — drop dup sector, HF via sic_code)
--
-- WHAT CHANGED vs v5
--   * REMOVED the separate `sector` column — it DUPLICATED `industry` (which is
--     already the coarse mapped sector: Banks/Government/Financial/Other) and, by
--     sweeping blank/Other into Corporates, it HID the Hedge Funds. One column now.
--   * `industry` is FIXED IN PLACE to the 5 required buckets (REQ 1.1):
--       Banks / Government / Financial / Hedge Funds / Corporates.
--     Hedge Funds = SIC 7298 (the blank/Other rows the analyst saw were HF). To get
--     sic_code (absent from ats_summary) we now JOIN test_ats_summary on line+date.
--   * Everything outside Banks/Government/Financial/HF -> Corporates (incl. the old
--     'Other' and blanks), per REQ 1.1.
--
-- DEPENDENCY ADDED: test_ats_summary (sic_code). If/when ats_summary carries
--   sic_code natively, drop this join. (Logged in matrix.)
--
-- WHAT CHANGED vs v4  (all driven by Tia's requirements email)
--   * (REQ 1.1) SECTOR: added a mapped 5-bucket sector column
--       Financial / Banks / Government / Hedge Funds / Corporates.
--       Hedge Funds = SIC 7298; everything outside Financial/Banks/Government
--       defaults to Corporates. NOTE: ats_summary has NO sic_code column, so the
--       HF=7298 leg cannot be resolved from this source — it is mapped best-effort
--       from industry/sic_industry text and HF is flagged <NEEDS sic_code>. To make
--       HF exact, join test_ats_summary (has sic_code) or have the source add it.
--   * (POPULATION) No_Line_Indicator='False' was only inside the asts_lim CTE in
--       v4. The scenario aggregation read ats_summary with NO no-line filter, so
--       no-line CPs could appear. v5 has no No_Line_Indicator on ats_summary
--       because ats_summary does not carry it — instead the limit join now governs
--       inclusion (INNER-style) so only lines that survive the no-line filter in
--       asts contribute a limit. See note (P) below; full exclusion-table handling
--       is still pending the exclusion list.
--   * (REQ 2.1.d) BREACH FLAG: added breaches_any — 'Y' if the CP x product x entity
--       has any breached line in asts this load, else 'N'. Lets the dashboard
--       "filter by breaches" at the portfolio grain (email filter list).
--   * raw `industry`/`sic_industry` are KEPT (breach list shows granular industry
--       grouped under sector headers — req keeps both).
--
-- DATA ANOMALY CARRIED FORWARD
--   * limit_amt = 1 is a SOURCE placeholder (no real limit loaded). utilization
--     then = stress/1 = millions. Dashboard filters Limit Amount > 1 to drop these
--     for display; they are themselves a finding (exposure, no limit). Logged.
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
  -- sic_code joined from test_ats_summary (ats_summary lacks it) for the HF=7298 map.
  SELECT
    s.`business_date`,
    s.`long_name`                          AS counterparty,
    s.`industry`, s.`sic_industry`, s.`country_of_risk`, s.`region`,
    ts.`sic_code`,
    s.`worst_rating_of_associated_clients` AS worst_rating,
    s.`otc_sft`,
    regexp_extract(s.`line`, '\\(([^)]+)\\)', 1)  AS entity,
    COALESCE(s.`cartor_max`,0)    AS cartor,  COALESCE(s.`zero_max`,0)   AS zero,
    COALESCE(s.`c_25_max`,0)      AS c_25,    COALESCE(s.`c_75_max`,0)   AS c_75,
    COALESCE(s.`str75_max`,0)     AS str75,   COALESCE(s.`one_max`,0)    AS one,
    COALESCE(s.`prod_max`,0)      AS prod,    COALESCE(s.`strmpr025_max`,0) AS strmpr025
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`ats_summary` s
  LEFT JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`test_ats_summary` ts
         ON ts.`line` = s.`line`
        AND regexp_replace(CAST(ts.`business_date` AS STRING),'-','')
          = regexp_replace(CAST(s.`business_date`  AS STRING),'-','')
        -- (~) v6 DATATYPE-AGNOSTIC date match. asts/ats_summary store business_date as
        --     STRING 'yyyymmdd'; test_ tables store it as DATE (renders 'yyyy-mm-dd').
        --     CAST->STRING then strip dashes normalizes STRING-yyyymmdd, STRING-yyyy-mm-dd
        --     AND real DATE to one canonical 'yyyymmdd' — survives a datatype change on
        --     either side. (Was ts.bd = s.bd -> 0 matches -> sic_code NULL -> no HF.)
),
cp_scn AS (   -- STEP 1: SUM each scenario across the CP's lines (per product/entity/date)
  SELECT
    `business_date`, counterparty, otc_sft, entity,
    MAX(industry) industry, MAX(sic_industry) sic_industry, MAX(sic_code) sic_code,
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
asts_lim AS (   -- asts bucket-matched limit + breach flag, to CP x otc x entity x date
                -- (same definition as vw_ast_breach_report; entity parsed like above)
                -- (REQ 2.1.d) breaches_any: any of the 6 *_Excess_Breach = 'TRUE' on the line.
  SELECT `business_date`, counterparty, otc_sft, entity,
         SUM(bucket_limit) AS limit_amt,
         MAX(line_breach)  AS breaches_any          -- 'Y' if any breached line
  FROM (
    SELECT
      a.`business_date`,
      a.`Long_Name`                                  AS counterparty,
      regexp_extract(a.`Line`, '\\(([^)]+)\\)', 1)   AS entity,
      s.`otc_sft`,
      CASE WHEN a.`0_3_mo_Excess_Breach`='TRUE' OR a.`3_12_mo_Excess_Breach`='TRUE'
             OR a.`1_2_Yr_Excess_Breach`='TRUE' OR a.`2_5_Yr_Excess_Breach`='TRUE'
             OR a.`5_10_Yr_Excess_Breach`='TRUE' OR a.`10_50_Yr_Excess_Breach`='TRUE'
           THEN 'Y' ELSE 'N' END                     AS line_breach,
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
           ON s.`line` = a.`Line`
          AND regexp_replace(CAST(s.`business_date` AS STRING),'-','')
            = regexp_replace(CAST(a.`business_date` AS STRING),'-','')   -- datatype-agnostic (both yyyymmdd today)
    WHERE a.`No_Line_Indicator` = 'False'
  ) z
  WHERE rn = 1
  GROUP BY `business_date`, counterparty, otc_sft, entity
)
SELECT
  n.`business_date`,
  n.counterparty, n.otc_sft,
  CASE WHEN n.otc_sft = 'OTC' THEN 'Y' ELSE 'N' END AS otc_flag,   -- (+) split leg (Y/N), otc_sft kept
  CASE WHEN n.otc_sft = 'SFT' THEN 'Y' ELSE 'N' END AS sft_flag,   -- (+) split leg (Y/N)
  n.entity,
  -- (REQ 1.1 + NAMING CONSISTENCY with breach report) the 5-bucket mapped column is
  -- named `Sector` (was `industry`); the granular SIC text is named `Industry` (was
  -- `sic_industry`) — SAME names the breach report uses. HF = SIC 7298; else map the
  -- coarse industry; everything outside Banks/Government/Financial/HF -> Corporates.
  CASE
    WHEN n.sic_code = '7298'                THEN 'Hedge Funds'
    WHEN upper(n.industry) LIKE 'BANK%'     THEN 'Banks'
    WHEN upper(n.industry) LIKE 'GOV%'      THEN 'Government'
    WHEN upper(n.industry) LIKE 'FINANC%'   THEN 'Financial'
    ELSE 'Corporates'
  END AS Sector,                                          -- mapped 5-bucket (= breach Sector)
  n.sic_industry AS Industry,                             -- granular SIC text (= breach Industry)
  n.country_of_risk, n.region, n.worst_rating,
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
  COALESCE(l.breaches_any,'N') AS breaches_any,                   -- (+) REQ 2.1.d filter-by-breaches
  ROUND(n.stress_pfe / NULLIF(l.limit_amt,0), 4) AS utilization   -- NEW: RATIO (do NOT Sum)
FROM cp_named n
LEFT JOIN asts_lim l
  ON  regexp_replace(CAST(l.`business_date` AS STRING),'-','')
    = regexp_replace(CAST(n.`business_date` AS STRING),'-','')   -- datatype-agnostic
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
