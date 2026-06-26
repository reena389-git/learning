-- =====================================================================
-- vw_ast_breach_report  (transcribed from latest photo)
-- Databricks SQL.  Catalog: d4001-centralus-tdvip-creditrisk
--
-- *** ONLY CHANGE vs. the previous version: the view's HOME SCHEMA ***
--     was:  xvala_core.vw_ast_breach_report
--     now:  `xvala_core-raw`.vw_ast_breach_report
--     (The source doc wrote it unqualified as `xvala_core-raw`.vw_ast_breach_report,
--      i.e. relying on the current catalog context. Catalog added back below for safety.)
--     The entire query body is otherwise unchanged.
--
-- (?) Note: two query tabs were visible - "vw_ast_breach_report_orig" and
--     "vw_ast_breach_report_new_v...". Confirm which is canonical, and whether
--     this curated view is intentionally homed in the -raw schema (it reads
--     curated xvala_core tables).
--
-- (!) Still-open items (unchanged):
--     a) breach source reads xvala_xva.asts (you said it should be xvala_core.asts)
--     b) test_ats_summary / test_lines_report are append-only, DATE-keyed -> the
--        Line-only joins are not business_date / latest-run aware
--     c) date formats: '20260430' (asts, STRING) vs '2026-04-30' (test_lines_report, DATE)
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
  SIC_Code,
  Stress_Credit_Utilization,
  Product_Type
)
WITH SCHEMA COMPENSATION
AS
WITH breach_lines AS (
    -- Step 1: Criteria for Line with Breach
    SELECT
        Line,
        Long_Name,
        Worst_Rating_Of_Associated_Clients,
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
    FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.asts AS ast     -- (!) xvala_xva vs xvala_core
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
    -- "Take Unique Line": dedupe to one row per Line (highest exposure wins)
    SELECT
        ast.*,
        ROW_NUMBER() OVER (PARTITION BY Line ORDER BY Max_Scenario_Exposure DESC) AS rn
    FROM breach_lines AS ast
)
SELECT
    ast.Line                       AS Line,
    ast.Long_Name                  AS Counterparty_Name,
    ats_summary.sic_industry       AS Industry,          -- join key: Line
    ats_summary.brr                AS Rating,            -- join key: Line
    ast.Line_Type                  AS Line_Type,
    ast.Line_Currency              AS Line_Currency,
    Lines_Report.`mark_to_market`  AS MTM_MM,            -- join key: Line
    ast.Max_Scenario_Exposure      AS Stress_PFE_MM,
    ast.Standard_Exposure          AS Standard_PFE_MM,
    ats_summary.sic_code           AS SIC_Code,          -- join key: Line
    -- Stress Credit Utilization
    --   Step 1: pick the Limit matching Max_Exp_Time_Bucket
    --   Step 2: Max_Scenario_Exposure / Limit
    --           if Limit = 0/null -> / Standard_Exposure ; if that 0/null too -> NULL
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
    ats_summary.otc_sft            AS Product_Type       -- join key: Line
FROM unique_breach_lines AS ast
LEFT JOIN `d4001-centralus-tdvip-creditrisk`.xvala_core.test_ats_summary AS ats_summary
       ON ats_summary.Line = ast.Line
LEFT JOIN (
        SELECT *
        FROM `d4001-centralus-tdvip-creditrisk`.xvala_core.test_lines_report
        WHERE business_date = '2026-04-30'
          AND Source = 'CARTOR'
     ) AS Lines_Report
       ON Lines_Report.Line = ast.Line
WHERE ast.rn = 1
ORDER BY ast.Line;
