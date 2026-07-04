-- =====================================================================
-- vw_dim_scenario   (scenario dimension / crosswalk)  — VIEW form
-- Catalog d4001-centralus-tdvip-creditrisk · Schema xvala_core
--
-- ROLE
--   The Scenario dimension for the Mosaic model. ACTIVE JOIN: vw_pfe_asts_scenario
--   joins this on Scenario_Name to enrich the scenario selector with type / order /
--   description. The crosswalk columns (Source_Label_ASTS, Source_Label_LinesReport)
--   are REFERENCE/DOCUMENTATION — they record how the three source vocabularies map,
--   for risk to confirm; they are NOT active join keys.
--
--   VIEW form (no CREATE TABLE privilege needed): the 8 rows are emitted via
--   SELECT ... UNION ALL. Swap to a managed table later if desired — column
--   names/order are identical, so the Mosaic model will not need rewiring.
--
-- GRAIN   one row per scenario (8)     PK  Scenario_Name
--
-- Mapping_Confirmed: Y = the cross-vocabulary pairing is data-verified; N = inferred,
--   needs risk sign-off. Only Base/Cartor and Stress 75 are Y.
--
-- OPEN ITEM for risk: the "025" mapping — Stress MPR 0.25 vs 25th both currently carry
--   CORRELATION_0.25 / STRCORR025. They cannot both be correct. Also confirm what
--   "Product" (prod_max) denotes in the stress methodology.
-- =====================================================================
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_dim_scenario` (
  Scenario_Name             COMMENT 'Business-facing scenario name. PK. Matches vw_pfe_asts_scenario.Scenario_Name exactly (the selector join key).',
  Source_Column_ATS         COMMENT 'The *_max column stem in pfe_ats_summary this scenario derives from. CERTAIN (source of the name).',
  Source_Label_ASTS         COMMENT 'Label in pfe_asts.Scenario_Name for this scenario. REFERENCE (not an active join key). Confirm where Mapping_Confirmed=N.',
  Source_Label_LinesReport  COMMENT 'Label in pfe_lines_report.source for this scenario. REFERENCE (not an active join key). Confirm where Mapping_Confirmed=N.',
  Scenario_Type             COMMENT 'Grouping: Base / Baseline / Percentile / Market / Correlation / MPR.',
  Scenario_Order            COMMENT 'Display order for the selector / axis.',
  Mapping_Confirmed         COMMENT 'Y = cross-vocabulary pairing data-verified; N = inferred, needs risk sign-off.'
)
AS
SELECT 'Base/Cartor'     AS Scenario_Name, 'cartor_max'    AS Source_Column_ATS, CAST(NULL AS STRING) AS Source_Label_ASTS, 'CARTOR'       AS Source_Label_LinesReport, 'Base'        AS Scenario_Type, 1 AS Scenario_Order, 'Y' AS Mapping_Confirmed
UNION ALL SELECT 'Zero',            'zero_max',      'ZERO',             'STRZERO',       'Baseline',    2, 'N'
UNION ALL SELECT '25th',            'c_25_max',      'CORRELATION_0.25', 'STRCORR025',    'Percentile',  3, 'N'
UNION ALL SELECT '75th',            'c_75_max',      'CORRELATION_0.75', 'STRCORR075',    'Percentile',  4, 'N'
UNION ALL SELECT 'Stress 75',       'str75_max',     'STRMARKETC75',     'STRMARKETC75',  'Market',      5, 'Y'
UNION ALL SELECT 'Correlation 1.0', 'one_max',       'CORRELATION_1.0',  'STRCORRONE',    'Correlation', 6, 'N'
UNION ALL SELECT 'Product',         'prod_max',      'PRODCORRELATION',  'STRCORRPROD',   'Correlation', 7, 'N'
UNION ALL SELECT 'Stress MPR 0.25', 'strmpr025_max', 'CORRELATION_0.25', 'STRCORR025',    'MPR',         8, 'N';

-- =====================================================================
-- VALIDATION
-- =====================================================================
-- V-PK  Scenario_Name unique; 8 rows.  EXPECT rows_ = distinct_names = 8.
SELECT COUNT(*) AS rows_, COUNT(DISTINCT Scenario_Name) AS distinct_names
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_dim_scenario;
-- V-JOIN  every scenario in the fact resolves to a dim row (no orphans). EXPECT 0 rows.
SELECT sc.Scenario_Name
FROM (SELECT DISTINCT Scenario_Name FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_asts_scenario) sc
LEFT JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_dim_scenario d
  ON d.Scenario_Name = sc.Scenario_Name
WHERE d.Scenario_Name IS NULL;
-- V-025  surface the duplicate mapping for risk. STRCORR025 will show (the open item).
SELECT Source_Label_LinesReport, COUNT(*) AS mapped_to
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_dim_scenario
WHERE Source_Label_LinesReport IS NOT NULL
GROUP BY Source_Label_LinesReport HAVING COUNT(*) > 1;
