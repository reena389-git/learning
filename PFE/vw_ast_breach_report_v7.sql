-- =====================================================================
-- vw_ast_breach_report   (v7 — + Limit_Amount column)
-- Databricks SQL.  Catalog: d4001-centralus-tdvip-creditrisk
--
-- =====================================================================
-- CHANGE LOG vs the ORIGINAL base view (the one shared by the team)
-- Every line added/changed relative to the original is marked inline with:
--     -- (+) ADDED   ... a new column / CTE not in the original
--     -- (~) CHANGED ... an existing element altered from the original
-- The original's column list & body are otherwise preserved, so a developer
-- can diff this against vw_ast_breach_report.sql and see exactly what moved.
--
-- Summary of differences from the original base view:
--   (~) source: xvala_xva.asts            -> xvala_core.asts            (open item a)
--   (~) test_ats_summary join: Line-only   -> Line + business_date filter (anti fan-out)
--   (+) Rating: was ats_summary.brr (empty) -> asts Worst_Rating, (NIG) stripped
--   (+) IM      = lines_report.initial_margin
--   (+) IA      = pfe_exp_decomp_report.max_usage_0_3_mo (product_group filter, deduped)
--   (+) Worst_Scenario      = asts.Max_Scenario_Name
--   (+) Recurring_New       = compares vs the prior business_date in asts
--   (+) Major_Risk_Driver   = STUB (NULL) — analyst write-back, ready join below
--   (+) Feedback            = STUB (NULL) — analyst write-back, ready join below
--   (+) Limit_Amount        = the bucket-matched limit, EXPOSED as its own column   <<< v7
--         In the original the bucket limit existed ONLY inside Stress_Credit_Utilization
--         (used as the denominator, then discarded). v7 emits it as a measure so the
--         BI layer can build the compound utilisation Sum(Stress_PFE)/Sum(Limit_Amount).
--         Uses the SAME bucket pick + Standard_Exposure fallback as the ratio, so the
--         stored ratio and Sum/Sum reconcile at line grain.
-- =====================================================================
--
-- CHANGES in v4:
--   + Worst_Scenario = asts.Max_Scenario_Name  (the model-native driver: the
--     scenario that produced the line's max exposure — the dashboard's
--     "which scenario hurts" tag, sourced for free)
--
-- CHANGES already in v3:
--   + IM  = lines_report.initial_margin            (already on the MTM join — free)
--   + IA  = pfe_exp_decomp_report.max_usage_0_3_mo
--             WHERE product_group = 'Lines_Report - With IM'
--           deduped to one row per Line (line+source unique, IM equal across
--           sources -> MAX over the line collapses it safely; no fan-out)
--   ~ asts now read from xvala_core.asts        (was xvala_xva.asts — your open
--                                                item (a); DDL confirms xvala_core)
--   ~ test_ats_summary join wrapped with a business_date filter to stop a
--     multi-load fan-out (the prior join was on Line only, no date) — see (!) note
--
-- (!) STILL TO CONFIRM:
--   b) test_ats_summary / test_lines_report — dev03 test_ tables vs prod
--      ats_summary / lines_report. IA below points at xvala_core-raw.pfe_exp_decomp_report
--      (the only copy in the DDL); repoint to a test_ copy if one exists in dev03.
--   c) sic_code — CONFIRMED present on test_ats_summary. brr still to verify
--      (prod ats_summary in the DDL has neither); if brr is absent, Rating is NULL.
--   d) IA date filter format: decomp business_date is STRING; I used '20260430'
--      to match asts. If decomp follows lines_report's '2026-04-30', flip it
--      (else IA silently returns NULL for every line — V-IA below catches that).
-- =====================================================================

CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.vw_ast_breach_report (
  Line,
  Counterparty_Name,
  Industry,
  Rating,
  Line_Type,
  Line_Currency,
  MTM_MM COMMENT 'Mark to market value as DOUBLE.',
  Stress_PFE_MM,
  Standard_PFE_MM,
  IM COMMENT 'Initial Margin from lines_report.initial_margin (DOUBLE).',
  IA COMMENT 'Independent Amount = exp_decomp max_usage_0_3_mo where product_group = Lines_Report - With IM.',
  SIC_Code,
  Stress_Credit_Utilization,
  Limit_Amount COMMENT '(+) v7 ADDED: bucket-matched limit (denominator of Stress_Credit_Utilization), exposed as its own measure so BI can build Sum(Stress_PFE_MM)/Sum(Limit_Amount). Standard_Exposure fallback applied, matching the ratio.',
  Product_Type,
  Worst_Scenario COMMENT 'Model-native driver: asts.Max_Scenario_Name — the scenario that produced the max exposure.',
  Recurring_New COMMENT 'Recurring = line also breached in the prior business_date; New = first breach this month.',
  Major_Risk_Driver COMMENT 'Analyst-entered (FX/IR/EQ/Metal) from ats_dshbd_breach_commentary.primary_risk_driver — distinct from Worst_Scenario.',
  Feedback COMMENT 'Analyst free-text from the breach commentary write-back table.'
)
WITH SCHEMA COMPENSATION
AS
WITH breach_lines AS (
    -- Step 1: lines with a breach in ANY of the six buckets (flags are STRING).
    SELECT
        Line,
        Long_Name,
        Worst_Rating_Of_Associated_Clients,   -- selected but no longer used downstream
        Line_Type,
        Line_Currency,
        Max_Exp_Time_Bucket,
        Max_Scenario_Name,
        CAST(REPLACE(Max_Scenario_Exposure, ',', '') AS DOUBLE) AS Max_Scenario_Exposure,
        CAST(REPLACE(Standard_Exposure,     ',', '') AS DOUBLE) AS Standard_Exposure,
        CAST(REPLACE(`Limit_3_mo`,  ',', '') AS DOUBLE) AS Limit_3_mo,
        CAST(REPLACE(`Limit_1_Yr`,  ',', '') AS DOUBLE) AS Limit_1_Yr,
        CAST(REPLACE(`Limit_2_Yr`,  ',', '') AS DOUBLE) AS Limit_2_Yr,
        CAST(REPLACE(`Limit_5_Yr`,  ',', '') AS DOUBLE) AS Limit_5_Yr,
        CAST(REPLACE(`Limit_10_Yr`, ',', '') AS DOUBLE) AS Limit_10_Yr,
        CAST(REPLACE(`Limit_50_Yr`, ',', '') AS DOUBLE) AS Limit_50_Yr
    FROM `d4001-centralus-tdvip-creditrisk`.xvala_core.asts AS ast      -- (~) was xvala_xva
    WHERE (
            ast.`0_3_mo_Excess_Breach`   = 'TRUE'
         OR ast.`3_12_mo_Excess_Breach`  = 'TRUE'
         OR ast.`1_2_Yr_Excess_Breach`   = 'TRUE'
         OR ast.`2_5_Yr_Excess_Breach`   = 'TRUE'
         OR ast.`5_10_Yr_Excess_Breach`  = 'TRUE'
         OR ast.`10_50_Yr_Excess_Breach` = 'TRUE'
          )
      AND ast.business_date     = '20260430'
      AND ast.No_Line_Indicator = 'False'
),
unique_breach_lines AS (
    -- "Take Unique Line": one row per Line, highest exposure wins.
    SELECT
        ast.*,
        ROW_NUMBER() OVER (PARTITION BY Line ORDER BY Max_Scenario_Exposure DESC) AS rn
    FROM breach_lines AS ast
),
-- (+) IA source: one row per Line. line+source is unique and IM is constant across
--     sources, so MAX over the line is a safe collapse (avoids a scenario fan-out).
ia_src AS (
    SELECT
        line,
        MAX(CAST(REPLACE(max_usage_0_3_mo, ',', '') AS DOUBLE)) AS ia
    FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.pfe_exp_decomp_report
    WHERE product_group = 'Lines_Report - With IM'
      AND business_date = '20260430'        -- (!) confirm format — see note (d)
    GROUP BY line
),
-- (+) prior_breached: lines that breached in the PRIOR load (one month back).
--     Drives Recurring_New. Robust to the pinned date: prior = max date < current.
prior_breached AS (
    SELECT DISTINCT Line
    FROM `d4001-centralus-tdvip-creditrisk`.xvala_core.asts
    WHERE business_date = (
            SELECT MAX(business_date)
            FROM `d4001-centralus-tdvip-creditrisk`.xvala_core.asts
            WHERE business_date < '20260430'
          )
      AND No_Line_Indicator = 'False'
      AND ( `0_3_mo_Excess_Breach`='TRUE' OR `3_12_mo_Excess_Breach`='TRUE'
         OR `1_2_Yr_Excess_Breach`='TRUE' OR `2_5_Yr_Excess_Breach`='TRUE'
         OR `5_10_Yr_Excess_Breach`='TRUE' OR `10_50_Yr_Excess_Breach`='TRUE' )
)
SELECT
    ast.Line                       AS Line,
    ast.Long_Name                  AS Counterparty_Name,
    ats_summary.sic_industry       AS Industry,          -- join key: Line
    regexp_replace(ast.Worst_Rating_Of_Associated_Clients, '\\s*\\(NIG\\)', '')
                                   AS Rating,            -- (~) from asts worst rating: breach-driving & 132/132.
                                                         --     swap to td_account_rating if the upstream Excess_Breach
                                                         --     buffer keys off it (then fix its coverage gap).
    ast.Line_Type                  AS Line_Type,
    ast.Line_Currency              AS Line_Currency,
    Lines_Report.`mark_to_market`  AS MTM_MM,            -- join key: Line
    ast.Max_Scenario_Exposure      AS Stress_PFE_MM,
    ast.Standard_Exposure          AS Standard_PFE_MM,
    Lines_Report.`initial_margin`  AS IM,                -- (+) IM
    ia_src.ia                      AS IA,                -- (+) IA (filtered decomp)
    ats_summary.sic_code           AS SIC_Code,          -- join key: Line  (see note c)
    -- Stress Credit Utilization: Max_Scenario_Exposure / (bucket-matched Limit,
    -- falling back to Standard_Exposure, then NULL).
    CASE ast.Max_Exp_Time_Bucket
        WHEN 'max_usage_0_3_mo'
            THEN ROUND(ast.Max_Scenario_Exposure / COALESCE(NULLIF(ast.Limit_3_mo,  0), NULLIF(ast.Standard_Exposure, 0)), 4)
        WHEN 'max_usage_3_12_mo'
            THEN ROUND(ast.Max_Scenario_Exposure / COALESCE(NULLIF(ast.Limit_1_Yr,  0), NULLIF(ast.Standard_Exposure, 0)), 4)
        WHEN 'max_usage_1_2_yr'
            THEN ROUND(ast.Max_Scenario_Exposure / COALESCE(NULLIF(ast.Limit_2_Yr,  0), NULLIF(ast.Standard_Exposure, 0)), 4)
        WHEN 'max_usage_2_5_yr'
            THEN ROUND(ast.Max_Scenario_Exposure / COALESCE(NULLIF(ast.Limit_5_Yr,  0), NULLIF(ast.Standard_Exposure, 0)), 4)
        WHEN 'max_usage_5_10_yr'
            THEN ROUND(ast.Max_Scenario_Exposure / COALESCE(NULLIF(ast.Limit_10_Yr, 0), NULLIF(ast.Standard_Exposure, 0)), 4)
        WHEN 'max_usage_10_50_yr'
            THEN ROUND(ast.Max_Scenario_Exposure / COALESCE(NULLIF(ast.Limit_50_Yr, 0), NULLIF(ast.Standard_Exposure, 0)), 4)
        ELSE
            ROUND(ast.Max_Scenario_Exposure / NULLIF(ast.Standard_Exposure, 0), 4)
    END                            AS Stress_Credit_Utilization,
    -- (+) v7 ADDED: the bucket-matched limit EXPOSED as its own column.
    --     Same bucket pick + Standard_Exposure fallback as Stress_Credit_Utilization
    --     above, so the stored ratio and Sum(Stress_PFE)/Sum(Limit_Amount) reconcile.
    --     (In the original this value lived only inside the ratio and was discarded.)
    CASE ast.Max_Exp_Time_Bucket
        WHEN 'max_usage_0_3_mo'   THEN COALESCE(NULLIF(ast.Limit_3_mo,  0), NULLIF(ast.Standard_Exposure, 0))
        WHEN 'max_usage_3_12_mo'  THEN COALESCE(NULLIF(ast.Limit_1_Yr,  0), NULLIF(ast.Standard_Exposure, 0))
        WHEN 'max_usage_1_2_yr'   THEN COALESCE(NULLIF(ast.Limit_2_Yr,  0), NULLIF(ast.Standard_Exposure, 0))
        WHEN 'max_usage_2_5_yr'   THEN COALESCE(NULLIF(ast.Limit_5_Yr,  0), NULLIF(ast.Standard_Exposure, 0))
        WHEN 'max_usage_5_10_yr'  THEN COALESCE(NULLIF(ast.Limit_10_Yr, 0), NULLIF(ast.Standard_Exposure, 0))
        WHEN 'max_usage_10_50_yr' THEN COALESCE(NULLIF(ast.Limit_50_Yr, 0), NULLIF(ast.Standard_Exposure, 0))
        ELSE NULLIF(ast.Standard_Exposure, 0)
    END                            AS Limit_Amount,
    ats_summary.otc_sft            AS Product_Type,      -- join key: Line
    ast.Max_Scenario_Name          AS Worst_Scenario,    -- (+) model-native driver (free from breach_lines)
    CASE WHEN pb.Line IS NOT NULL THEN 'Recurring' ELSE 'New' END AS Recurring_New,   -- (+) history compare
    CAST(NULL AS STRING)           AS Major_Risk_Driver, -- (+) STUB: analyst write-back — wire via block below
    CAST(NULL AS STRING)           AS Feedback           -- (+) STUB: analyst write-back — wire via block below
FROM unique_breach_lines AS ast
LEFT JOIN (
        -- (~) date-filtered so a multi-load test_ats_summary can't fan out the grain.
        --     If test_ats_summary is single-load (or lacks business_date), drop the WHERE.
        SELECT Line, sic_industry, brr, sic_code, otc_sft
        FROM `d4001-centralus-tdvip-creditrisk`.xvala_core.test_ats_summary
        WHERE business_date = '20260430'
     ) AS ats_summary
       ON ats_summary.Line = ast.Line
LEFT JOIN (
        SELECT *
        FROM `d4001-centralus-tdvip-creditrisk`.xvala_core.test_lines_report
        WHERE business_date = '2026-04-30'
          AND Source = 'CARTOR'
     ) AS Lines_Report
       ON Lines_Report.Line = ast.Line
LEFT JOIN ia_src
       ON ia_src.line = ast.Line
LEFT JOIN prior_breached pb
       ON pb.Line = ast.Line                 -- (+) Recurring_New: did this line breach last month?
WHERE ast.rn = 1
ORDER BY ast.Line;


-- =====================================================================
-- TO WIRE Major_Risk_Driver + Feedback (analyst write-back) once the
-- ats_dshbd_breach_commentary schema is confirmed:
--   1) replace the two CAST(NULL AS STRING) stubs above with
--        c.primary_risk_driver AS Major_Risk_Driver,
--        c.feedback            AS Feedback
--   2) add this join (these are analyst-entered, so they're NULL until typed —
--      stubbing keeps the model structure complete in the meantime):
--
--   LEFT JOIN (
--     SELECT Line, primary_risk_driver, feedback
--     FROM `d4001-centralus-tdvip-creditrisk`.xvala_core.ats_dshbd_breach_commentary
--     WHERE business_date = '20260430'        -- IF date-keyed (else drop; if multi-date
--                                             -- and unfiltered it WILL fan out — same
--                                             -- lesson as test_ats_summary)
--   ) c ON c.Line = ast.Line
--
--   Confirm before wiring: (a) the table's key — Line? Line+business_date?,
--   (b) exact column names (primary_risk_driver / feedback), (c) its grain.
-- =====================================================================


-- =====================================================================
-- VALIDATION
-- =====================================================================
-- V-COUNT  rows == distinct breached lines (proves no fan-out from the joins)
SELECT COUNT(*) AS rows, COUNT(DISTINCT Line) AS distinct_lines
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.vw_ast_breach_report;

-- V-IA  IA coverage. If ia_pop = 0, the decomp date filter format is wrong (note d)
--       or the product_group string doesn't match verbatim.
SELECT COUNT(*) AS total, COUNT(IA) AS ia_pop, COUNT(IM) AS im_pop
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.vw_ast_breach_report;

-- V-RATING  brr/sic_code presence (note c). If both are ~all NULL, test_ats_summary
--           isn't exposing them.
SELECT COUNT(*) AS total, COUNT(Rating) AS rating_pop, COUNT(SIC_Code) AS sic_pop
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.vw_ast_breach_report;

-- V-RECUR  Recurring vs New split (needs >=2 loads in asts; flat 'New' = no prior month yet).
SELECT Recurring_New, COUNT(*) AS lines
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.vw_ast_breach_report
GROUP BY Recurring_New;

-- V-LIMIT  (+) v7: Limit_Amount must reconcile with the stored ratio at line grain:
--          Stress_PFE_MM / Limit_Amount should equal Stress_Credit_Utilization.
--          Expect 0 mismatched rows (allowing rounding + NULL limit lines).
SELECT COUNT(*) AS mismatched
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.vw_ast_breach_report
WHERE Limit_Amount IS NOT NULL
  AND ROUND(Stress_PFE_MM / NULLIF(Limit_Amount,0), 4) <> Stress_Credit_Utilization;
