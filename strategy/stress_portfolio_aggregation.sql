-- =============================================================================
-- portfolio_aggregation.sql
-- Level-1 (Portfolio Stress Dashboard) aggregation, pushed into Databricks.
--
-- WHY THIS EXISTS
--   Strategy builds the visuals, but every Strategy visual has a matching SQL
--   query here that returns the SAME numbers. Databricks is the fallback (if
--   Strategy is down) and the auditable source of truth. Treat this file as a
--   runbook: each query below maps to one chart on the portfolio page.
--
--   catalog : d4001-centralus-tdvip-creditrisk
--   schema  : xvala_core
--   source  : vw_ats_summary  (ONE row per LINE)
--   output  : vw_portfolio_cp_stress  (ONE row per BORROWER x OTC/SFT x ENTITY)
--
-- THE AGGREGATION RULE (from the report footnote)
--   "max PFE across all stress batches at counterparty level before aggregation."
--   That is a TWO-STEP roll-up:
--     STEP 1  sum each scenario across a borrower's lines       (exposure is
--             additive across the lines of one borrower)
--     STEP 2  take the WORST (max) scenario of those sums       (you can only be
--             in one scenario at a time -> stress PFE is the worst case)
--   Then the charts SUM these borrower-level stress PFE values into buckets.
--
--   This is NOT the same as summing each line's own worst scenario: different
--   lines can peak in different scenarios, which overstates. We compute it the
--   correct way and keep the simpler version only as a debug column.
-- =============================================================================


-- =============================================================================
-- THE VIEW  (all logic is commented in-line, as requested)
-- =============================================================================
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_portfolio_cp_stress` AS
WITH line_level AS (
  -- ---------------------------------------------------------------------------
  -- One row per LINE, with the fields we need, cleaned. NULL scenario values
  -- become 0 so a missing scenario doesn't wipe out a borrower's whole total.
  -- ---------------------------------------------------------------------------
  SELECT
    -- Borrower key: use the CIF number when it is resolved, otherwise fall back
    -- to the borrower's long name. (cif_number can be the literal 'UNRESOLVED'.)
    COALESCE(NULLIF(TRIM(`cif_number`), 'UNRESOLVED'), `long_name`) AS counterparty,
    `long_name`,

    -- Borrower-level dimensions (constant across a borrower's lines)
    `industry`,
    `country_of_risk`,
    `region`,
    `worst_rating_of_associated_clients` AS worst_rating,  -- already worst-across-CP-codes

    -- Split dimensions that can VARY line to line (so they sit in the grain):
    `otc_sft_indicator`        AS otc_sft,   -- 'OTC' vs 'SFT' (every chart splits on this)
    `td_subsidiary_indicator`  AS entity,    -- booking entity: TDBK, TDSU, TDGF, ...

    -- Per-scenario PFE for THIS line (each column = one stress batch / scenario).
    -- These get SUMMED across the borrower's lines in STEP 1.
    COALESCE(`cartor_max`,    0) AS cartor,     -- Base scenario (Cartor = Base)
    COALESCE(`zero_max`,      0) AS zero,
    COALESCE(`c_25_max`,      0) AS c_25,
    COALESCE(`c_75_max`,      0) AS c_75,
    COALESCE(`str75_max`,     0) AS str75,
    COALESCE(`one_max`,       0) AS one_,
    COALESCE(`prod_max`,      0) AS prod,
    COALESCE(`strmpr025_max`, 0) AS strmpr025,

    -- The line's own worst-of-all-scenarios (used only for the debug measure).
    COALESCE(`max_of_all`,    0) AS line_max_of_all
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_ats_summary`
),

cp_scenario_totals AS (
  -- ---------------------------------------------------------------------------
  -- STEP 1: roll LINES up to BORROWER x OTC/SFT x ENTITY, summing EACH scenario
  -- separately. Dimensions that are constant per borrower are carried with MAX
  -- (just "pick the one value"); the worst rating is already pre-rolled upstream.
  --
  -- METHODOLOGY NOTE (please confirm with the methodology owner):
  --   The worst-scenario max in STEP 2 is taken at this grain
  --   (borrower x OTC/SFT x entity). If the methodology requires the worst
  --   scenario to be chosen at PURE borrower level and then distributed to
  --   entities, this needs a different shape -- flag before publishing.
  -- ---------------------------------------------------------------------------
  SELECT
    counterparty,
    MAX(`long_name`)       AS long_name,
    MAX(`industry`)        AS industry,
    MAX(`country_of_risk`) AS country_of_risk,
    MAX(`region`)          AS region,
    MAX(worst_rating)      AS worst_rating,
    otc_sft,
    entity,

    SUM(cartor)    AS cp_cartor,     -- borrower's Base-scenario total
    SUM(zero)      AS cp_zero,
    SUM(c_25)      AS cp_c_25,
    SUM(c_75)      AS cp_c_75,
    SUM(str75)     AS cp_str75,
    SUM(one_)      AS cp_one,
    SUM(prod)      AS cp_prod,
    SUM(strmpr025) AS cp_strmpr025,

    SUM(line_max_of_all) AS cp_sum_of_line_max  -- debug only (see final SELECT)
  FROM line_level
  GROUP BY counterparty, otc_sft, entity
)

SELECT
  counterparty, long_name, industry, country_of_risk, region, otc_sft, entity,
  worst_rating,

  -- ---------------------------------------------------------------------------
  -- BRR bucket: NIG wins. Otherwise bucket by the leading digit of the rating
  -- (e.g. '2B' -> '2', '4A(NIG)' -> 'NIG'), with anything 6+ collapsed to '5+'.
  -- ---------------------------------------------------------------------------
  CASE
    WHEN upper(worst_rating) LIKE '%NIG%'      THEN 'NIG'
    WHEN worst_rating RLIKE '^[0-9]'           THEN
         CASE WHEN CAST(regexp_extract(worst_rating, '^([0-9]+)', 1) AS INT) >= 6
              THEN '5+'
              ELSE regexp_extract(worst_rating, '^([0-9]+)', 1)
         END
    ELSE 'Unrated'
  END AS brr_bucket,

  -- ---------------------------------------------------------------------------
  -- STEP 2: STRESS PFE = the worst (max) scenario among the borrower's
  -- per-scenario totals. This is "max PFE across all stress batches".
  -- ---------------------------------------------------------------------------
  GREATEST(cp_cartor, cp_zero, cp_c_25, cp_c_75,
           cp_str75, cp_one, cp_prod, cp_strmpr025) AS stress_pfe,

  -- Same, but EXCLUDING the Base (Cartor) scenario -- i.e. the worst STRESSED
  -- scenario. Use this if "Stress PFE" is defined as stressed-only (mirrors the
  -- max_all_less_cartor column). Confirm which definition the report uses.
  GREATEST(cp_zero, cp_c_25, cp_c_75,
           cp_str75, cp_one, cp_prod, cp_strmpr025) AS stress_pfe_excl_base,

  -- Standard / base PFE = the Base (Cartor) scenario total for the borrower.
  cp_cartor AS standard_pfe,

  -- DEBUG ONLY: sum of each line's own worst scenario. Tends to OVERSTATE vs
  -- stress_pfe (each line may peak in a different scenario). Not used by charts;
  -- kept so you can see the gap between the correct and the naive roll-up.
  cp_sum_of_line_max AS stress_pfe_naive
FROM cp_scenario_totals;


-- =============================================================================
-- LEVEL-1 RUNBOOK QUERIES  (one per portfolio chart)
-- Each returns OTC and SFT rows together; read the half you need. The pct_share
-- column reproduces the pie/area percentages (share within OTC or within SFT).
-- All amounts are raw; divide by 1e6 for the "MM" presentation if you prefer.
-- =============================================================================

-- 2.2a / 2.2b  STRESS PFE BY INDUSTRY  (OTC and SFT area/stacked charts)
SELECT
  otc_sft,
  industry,
  SUM(stress_pfe)                                            AS stress_pfe,
  ROUND(100.0 * SUM(stress_pfe)
        / SUM(SUM(stress_pfe)) OVER (PARTITION BY otc_sft), 2) AS pct_share
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_portfolio_cp_stress`
GROUP BY otc_sft, industry
ORDER BY otc_sft, stress_pfe DESC;


-- 2.2c / 2.2d  STRESS PFE BY ENTITY  (OTC and SFT pies: TDBK, TDSU, ...)
SELECT
  otc_sft,
  entity,
  SUM(stress_pfe)                                            AS stress_pfe,
  ROUND(100.0 * SUM(stress_pfe)
        / SUM(SUM(stress_pfe)) OVER (PARTITION BY otc_sft), 2) AS pct_share
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_portfolio_cp_stress`
GROUP BY otc_sft, entity
ORDER BY otc_sft, stress_pfe DESC;


-- 2.2e / 2.2f  STRESS PFE BY BRR  (OTC and SFT pies: 0,1,2,3,4,5,5+,NIG)
SELECT
  otc_sft,
  brr_bucket,
  SUM(stress_pfe)                                            AS stress_pfe,
  ROUND(100.0 * SUM(stress_pfe)
        / SUM(SUM(stress_pfe)) OVER (PARTITION BY otc_sft), 2) AS pct_share
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_portfolio_cp_stress`
GROUP BY otc_sft, brr_bucket
ORDER BY otc_sft,
         -- order the buckets naturally: NIG last, then by number
         CASE WHEN brr_bucket = 'NIG' THEN 99
              WHEN brr_bucket = '5+'  THEN 6
              WHEN brr_bucket = 'Unrated' THEN 98
              ELSE CAST(brr_bucket AS INT) END;


-- 2.2g / 2.2h  STRESS PFE BY COUNTRY OF RISK  (OTC and SFT pies)
SELECT
  otc_sft,
  country_of_risk,
  SUM(stress_pfe)                                            AS stress_pfe,
  ROUND(100.0 * SUM(stress_pfe)
        / SUM(SUM(stress_pfe)) OVER (PARTITION BY otc_sft), 2) AS pct_share
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_portfolio_cp_stress`
GROUP BY otc_sft, country_of_risk
ORDER BY otc_sft, stress_pfe DESC;


-- =============================================================================
-- VALIDATION / RECONCILIATION
-- =============================================================================

-- V1  Portfolio totals by OTC/SFT. Every chart above must sum back to these.
SELECT otc_sft,
       COUNT(DISTINCT counterparty) AS counterparties,
       SUM(stress_pfe)              AS total_stress_pfe,
       SUM(standard_pfe)            AS total_standard_pfe
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_portfolio_cp_stress`
GROUP BY otc_sft;

-- V2  Correct vs naive roll-up gap. If stress_pfe_naive is much larger than
--     stress_pfe, it confirms why summing each line's own worst scenario
--     overstates -- and that the two-step rule is doing its job.
SELECT otc_sft,
       SUM(stress_pfe)       AS stress_pfe_correct,
       SUM(stress_pfe_naive) AS stress_pfe_naive,
       ROUND(100.0 * (SUM(stress_pfe_naive) - SUM(stress_pfe))
             / NULLIF(SUM(stress_pfe), 0), 1) AS overstatement_pct
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_portfolio_cp_stress`
GROUP BY otc_sft;
