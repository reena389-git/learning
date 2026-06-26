-- =============================================================================
-- portfolio_aggregation_v2.sql
-- What changed vs v1, and why.
--
--   The trajectory dashboard needs three things the old Level-1 view didn't emit:
--     (A) the 8 per-scenario SUMS at counterparty grain  -> the FINGERPRINT
--     (B) business_date carried through                  -> the CHANGE layer (MoM)
--     (C) the worst-scenario name + driver text          -> Major Risk Driver, free
--
--   All three come straight out of `ats_summary` (wide: 8 *_max columns per line,
--   confirmed from the catalog screenshots). We do NOT touch the long `asts`
--   detail table. Source of truth is unchanged; we just stop discarding columns.
--
--   catalog : d4001-centralus-tdvip-creditrisk      schema : xvala_core
--   VIEW 1  : vw_asts_portfolio_cp_stress   (REPLACES the v1 view in place)
--   VIEW 2  : vw_cp_stress_hist_demo        (THROWAWAY - fabricates prior months
--                                            so the change layer works today;
--                                            retire once real history accrues)
--
--   NB naming: downstream (breach_list.sql, the dashboard) reads
--   `vw_asts_portfolio_cp_stress`. The v1 file shipped a twin named
--   `vw_portfolio_cp_stress`; standardising on the *_asts_* name here.
-- =============================================================================


-- =============================================================================
-- VIEW 1  —  vw_asts_portfolio_cp_stress   (grain: CP x OTC/SFT x entity x date)
-- =============================================================================
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts_portfolio_cp_stress` AS
WITH line_level AS (
  -- One row per LINE (per load). NULL scenarios -> 0 so a missing batch doesn't
  -- wipe a borrower's total. business_date now travels with the row.
  SELECT
    `business_date`,                                   -- (B) NEW: keep the load date
    `long_name`                          AS counterparty,
    `industry`,                                        -- coarse mapped sector ("Other"/...)
    `sic_industry`,                                    -- granular ("NO_INDUSTRY"/...)
    `country_of_risk`,
    `region`,
    `worst_rating_of_associated_clients` AS worst_rating,
    `otc_sft`,
    regexp_extract(`line`, '\\(([^)]+)\\)', 1)  AS entity,   -- CP_(TDBK)_... -> TDBK
    COALESCE(`cartor_max`,    0) AS cartor,
    COALESCE(`zero_max`,      0) AS zero,
    COALESCE(`c_25_max`,      0) AS c_25,
    COALESCE(`c_75_max`,      0) AS c_75,
    COALESCE(`str75_max`,     0) AS str75,
    COALESCE(`one_max`,       0) AS one,
    COALESCE(`prod_max`,      0) AS prod,
    COALESCE(`strmpr025_max`, 0) AS strmpr025
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`ats_summary`
  -- (repoint to vw_ats_summary if that is the governed read wrapper)
),

-- STEP 1 : SUM each scenario across the borrower's lines (exposure is additive
-- across one borrower's lines). These 8 sums ARE the fingerprint.
cp_scn AS (
  SELECT
    `business_date`, counterparty, otc_sft, entity,
    MAX(industry)        AS industry,
    MAX(sic_industry)    AS sic_industry,
    MAX(country_of_risk) AS country_of_risk,
    MAX(region)          AS region,
    MAX(worst_rating)    AS worst_rating,
    SUM(cartor)    AS cp_cartor,
    SUM(zero)      AS cp_zero,
    SUM(c_25)      AS cp_c_25,
    SUM(c_75)      AS cp_c_75,
    SUM(str75)     AS cp_str75,
    SUM(one)       AS cp_one,
    SUM(prod)      AS cp_prod,
    SUM(strmpr025) AS cp_strmpr025
  FROM line_level
  GROUP BY `business_date`, counterparty, otc_sft, entity
),

-- STEP 2 : stress PFE = worst (max) scenario among those per-scenario sums.
cp_stress AS (
  SELECT *,
    GREATEST(cp_cartor, cp_zero, cp_c_25, cp_c_75,
             cp_str75, cp_one, cp_prod, cp_strmpr025) AS stress_pfe,
    GREATEST(cp_zero, cp_c_25, cp_c_75,
             cp_str75, cp_one, cp_prod, cp_strmpr025) AS stress_pfe_excl_base,
    cp_cartor                                         AS standard_pfe
  FROM cp_scn
),

-- (C) worst-scenario NAME at CP grain. Severity-ordered so a tie resolves to the
-- more punitive scenario. stress_pfe is literally one of the sums (GREATEST), so
-- equality is exact.
cp_named AS (
  SELECT *,
    CASE
      WHEN stress_pfe = cp_one       THEN 'one'
      WHEN stress_pfe = cp_str75     THEN 'str75'
      WHEN stress_pfe = cp_c_75      THEN 'c_75'
      WHEN stress_pfe = cp_prod      THEN 'prod'
      WHEN stress_pfe = cp_strmpr025 THEN 'strmpr025'
      WHEN stress_pfe = cp_c_25      THEN 'c_25'
      WHEN stress_pfe = cp_zero      THEN 'zero'
      ELSE 'cartor'
    END AS worst_scenario
  FROM cp_stress
)

SELECT
  `business_date`,
  counterparty, otc_sft, entity,
  industry, sic_industry, country_of_risk, region, worst_rating,

  -- BRR bucket (NIG wins, else leading digit, 6+ -> '5+')
  CASE
    WHEN upper(worst_rating) LIKE '%NIG%' THEN 'NIG'
    WHEN worst_rating RLIKE '^[0-9]' THEN
      CASE WHEN CAST(regexp_extract(worst_rating,'^([0-9]+)',1) AS INT) >= 6
           THEN '5+' ELSE regexp_extract(worst_rating,'^([0-9]+)',1) END
    ELSE 'Unrated'
  END AS brr_bucket,

  -- the 8 sums (fingerprint) + the headline measures
  cp_cartor, cp_zero, cp_c_25, cp_c_75, cp_str75, cp_one, cp_prod, cp_strmpr025,
  stress_pfe, stress_pfe_excl_base, standard_pfe,

  worst_scenario,
  CASE worst_scenario
    WHEN 'one'       THEN 'Systemic / full-correlation'
    WHEN 'str75'     THEN 'Market stress'
    WHEN 'c_75'      THEN 'Elevated correlation'
    WHEN 'c_25'      THEN 'Low correlation'
    WHEN 'zero'      THEN 'Diversified'
    WHEN 'prod'      THEN 'Name-specific / product'
    WHEN 'strmpr025' THEN 'Margin-period-of-risk'
    ELSE 'Base case'
  END AS risk_driver
FROM cp_named;


-- =============================================================================
-- VIEW 2  —  vw_cp_stress_hist_demo   (TEMPORARY: fabricates 6 month-ends so the
--   trajectory / sparkline / New-Worsening-Improving-Cleared strip work TODAY.
--   Only the LATEST month is real; prior months are deterministic drift of it.
--   RETIRE when SDS has >=2 real business_date loads -> then just read VIEW 1
--   across dates and delete this.)
--
--   Also: collapses entity -> CP (sums the 8 scenario sums, then re-GREATESTs, so
--   the two-step stays correct), filters OTC, and joins the limit so the radar's
--   utilisation axis has a denominator for every name (not just breached ones).
-- =============================================================================
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_cp_stress_hist_demo` AS
WITH cur AS (   -- collapse entity, OTC only, re-sum scenarios across entity
  SELECT
    counterparty,
    MAX(industry)        AS industry,
    MAX(country_of_risk) AS country_of_risk,
    MAX(region)          AS region,
    MAX(worst_rating)    AS worst_rating,
    MAX(brr_bucket)      AS brr_bucket,
    MAX(`business_date`) AS business_date,
    SUM(cp_cartor)    AS s_cartor,
    SUM(cp_zero)      AS s_zero,
    SUM(cp_c_25)      AS s_c_25,
    SUM(cp_c_75)      AS s_c_75,
    SUM(cp_str75)     AS s_str75,
    SUM(cp_one)       AS s_one,
    SUM(cp_prod)      AS s_prod,
    SUM(cp_strmpr025) AS s_strmpr025
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts_portfolio_cp_stress`
  WHERE otc_sft = 'OTC'
  GROUP BY counterparty
),
cur2 AS (
  SELECT *,
    GREATEST(s_cartor,s_zero,s_c_25,s_c_75,s_str75,s_one,s_prod,s_strmpr025) AS stress_pfe,
    s_cartor AS standard_pfe
  FROM cur
),
lim AS (   -- limit via the CLEAN notch of the worst rating ((NIG) stripped)
  SELECT c.*, lc.`limit` AS limit_amt
  FROM cur2 c
  LEFT JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_limit_config` lc
    ON lc.`cp_internal_rating` = regexp_replace(c.worst_rating, '\\s*\\(NIG\\)', '')
),
months AS ( SELECT explode(array(0,1,2,3,4,5)) AS m_back ),   -- 0=current(real)..5
gen AS (
  SELECT l.*, mb.m_back,
    -- per-CP monthly slope ~ +/-0.12 ; +noise ; current month forced to 1.0 (real)
    CASE WHEN mb.m_back = 0 THEN 1.0
         ELSE greatest(0.2,
                1.0
                - mb.m_back * ((pmod(xxhash64(l.counterparty), 240) - 120) / 1000.0)
                + ((pmod(xxhash64(l.counterparty, CAST(mb.m_back AS STRING)), 60) - 30) / 1000.0))
    END AS drift
  FROM lim l CROSS JOIN months mb
)
SELECT
  counterparty, industry, country_of_risk, region, worst_rating, brr_bucket,
  date_format(add_months(to_date(business_date,'yyyyMMdd'), -m_back), 'yyyyMMdd') AS business_date,
  m_back,
  ROUND(stress_pfe   * drift) AS stress_pfe,
  ROUND(standard_pfe * drift) AS standard_pfe,
  ROUND(s_cartor*drift) AS cp_cartor, ROUND(s_zero*drift)  AS cp_zero,
  ROUND(s_c_25*drift)   AS cp_c_25,   ROUND(s_c_75*drift)  AS cp_c_75,
  ROUND(s_str75*drift)  AS cp_str75,  ROUND(s_one*drift)   AS cp_one,
  ROUND(s_prod*drift)   AS cp_prod,   ROUND(s_strmpr025*drift) AS cp_strmpr025,
  limit_amt,
  ROUND(100.0 * stress_pfe * drift / NULLIF(limit_amt,0), 1) AS utilization_pct
FROM gen;


-- =============================================================================
-- RUNBOOK  (the three feeds the dashboard reads; each is a Strategy-visual twin)
-- =============================================================================

-- R1  Trajectory + fingerprint feed : current month, one row per CP, with MoM.
WITH h AS (SELECT * FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_cp_stress_hist_demo`),
mx AS (SELECT MAX(business_date) d FROM h)
SELECT
  cur.counterparty, cur.industry, cur.brr_bucket, cur.country_of_risk,
  cur.stress_pfe, cur.standard_pfe, cur.limit_amt, cur.utilization_pct,
  prev.utilization_pct AS utilization_prev_pct,
  ROUND(cur.utilization_pct - prev.utilization_pct, 1) AS mom_pp,
  cur.cp_cartor, cur.cp_zero, cur.cp_c_25, cur.cp_c_75,
  cur.cp_str75, cur.cp_one, cur.cp_prod, cur.cp_strmpr025   -- fingerprint
FROM h cur JOIN mx ON cur.business_date = mx.d
LEFT JOIN h prev
  ON prev.counterparty = cur.counterparty AND prev.m_back = 1
ORDER BY cur.utilization_pct DESC;

-- R2  Sparkline feed : 6-month utilisation per CP (oldest -> newest).
SELECT counterparty, business_date, utilization_pct
FROM   `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_cp_stress_hist_demo`
ORDER  BY counterparty, business_date;

-- R3  Delta strip : New / Worsening / Improving / Cleared (current vs prior).
WITH h AS (SELECT * FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_cp_stress_hist_demo`),
cur AS (SELECT * FROM h WHERE m_back = 0),
prv AS (SELECT counterparty, utilization_pct AS u_prev FROM h WHERE m_back = 1)
SELECT
  SUM(CASE WHEN cur.utilization_pct>=100 AND u_prev<100  THEN 1 ELSE 0 END) AS new_breaches,
  SUM(CASE WHEN cur.utilization_pct>=100 AND cur.utilization_pct>u_prev AND u_prev>=100 THEN 1 ELSE 0 END) AS worsening,
  SUM(CASE WHEN cur.utilization_pct>=100 AND cur.utilization_pct<u_prev THEN 1 ELSE 0 END) AS improving,
  SUM(CASE WHEN cur.utilization_pct<100  AND u_prev>=100 THEN 1 ELSE 0 END) AS cleared
FROM cur LEFT JOIN prv USING (counterparty);


-- =============================================================================
-- VALIDATION
-- =============================================================================
-- V1  Fingerprint sanity: GREATEST of the 8 sums must equal stress_pfe (no row off).
SELECT COUNT(*) AS mismatched
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts_portfolio_cp_stress`
WHERE stress_pfe <> GREATEST(cp_cartor,cp_zero,cp_c_25,cp_c_75,cp_str75,cp_one,cp_prod,cp_strmpr025);

-- V2  Driver distribution — eyeball that 'one'/'str75' dominate, not 'cartor'.
SELECT worst_scenario, risk_driver, COUNT(*) cps
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts_portfolio_cp_stress`
GROUP BY worst_scenario, risk_driver ORDER BY cps DESC;

-- V3  History demo: exactly 6 dates, current month equals the real VIEW-1 totals.
SELECT business_date, COUNT(*) cps, ROUND(SUM(stress_pfe)) tot_stress
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_cp_stress_hist_demo`
GROUP BY business_date ORDER BY business_date;

-- V4  Industry column check — is `industry` the mapped 5-sector, or still coarse?
SELECT industry, COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`ats_summary`
GROUP BY industry ORDER BY 2 DESC;
