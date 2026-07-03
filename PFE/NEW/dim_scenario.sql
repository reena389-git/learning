-- =====================================================================
-- dim_scenario   (scenario dimension / crosswalk)
-- Catalog d4001-centralus-tdvip-creditrisk · Schema xvala_core
--
-- ROLE
--   The Scenario dimension for the Mosaic model. ACTIVE JOIN: vw_asts_scenario
--   joins this on friendly_name (= Scenario_Name) to enrich the scenario selector
--   with type / order / description. The crosswalk columns (asts_scenario_name,
--   lines_report_source) are REFERENCE/DOCUMENTATION — they record how the three
--   source vocabularies map, for risk to confirm; they are NOT active join keys.
--   (The line fact's Worst_Scenario stays a raw label — no join to this dim.)
--
-- GRAIN   one row per scenario (8)     PK  friendly_name
--
-- CONFIRMED column: Y = the cross-vocabulary pairing is data-verified; N = inferred,
--   needs risk sign-off. Only Base/Cartor (CARTOR identical) and Stress 75
--   (STRMARKETC75 identical across all three sources) are Y. The ats_summary_stem
--   pairing is certain for every row (it is where the friendly names derive from);
--   the asts / lines_report labels on the N rows are the ones to confirm.
--
-- OPEN ITEM for risk: the "025" mapping — strmpr025 (Stress MPR 0.25) vs c_25 (25th)
--   both relate to a "0.25" label. Resolve which of STRCORR025 / CORRELATION_0.25
--   belongs to which. Marked N.
-- =====================================================================
CREATE TABLE IF NOT EXISTS `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`dim_scenario` (
  friendly_name        STRING COMMENT 'Business-facing scenario name. PK. Matches vw_asts_scenario.Scenario_Name exactly (the selector join key).',
  ats_summary_stem     STRING COMMENT 'The *_max column stem in pfe_ats_summary this scenario derives from. CERTAIN (source of the friendly name).',
  asts_scenario_name   STRING COMMENT 'Label in asts.Scenario_Name for this scenario. REFERENCE (not an active join key). Confirm where confirmed=N.',
  lines_report_source  STRING COMMENT 'Label in pfe_lines_report.source for this scenario. REFERENCE (not an active join key). Confirm where confirmed=N.',
  scenario_type        STRING COMMENT 'Grouping: Base / Baseline / Percentile / Market / Correlation / MPR.',
  scenario_order       INT    COMMENT 'Display order for the selector / axis.',
  confirmed            STRING COMMENT 'Y = cross-vocabulary pairing data-verified; N = inferred, needs risk sign-off.'
) USING delta;

-- 8 scenario rows. asts_scenario_name / lines_report_source on the N rows are the
-- values to CONFIRM with risk (populated, not blank, so risk can confirm or correct).
INSERT OVERWRITE `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`dim_scenario` VALUES
  ('Base/Cartor',     'cartor_max',    NULL,               'CARTOR',        'Base',        1, 'Y'),
  ('Zero',            'zero_max',      'ZERO',             'STRZERO',       'Baseline',    2, 'N'),
  ('25th',            'c_25_max',      'CORRELATION_0.25', 'STRCORR025',    'Percentile',  3, 'N'),
  ('75th',            'c_75_max',      'CORRELATION_0.75', 'STRCORR075',    'Percentile',  4, 'N'),
  ('Stress 75',       'str75_max',     'STRMARKETC75',     'STRMARKETC75',  'Market',      5, 'Y'),
  ('Correlation 1.0', 'one_max',       'CORRELATION_1.0',  'STRCORRONE',    'Correlation', 6, 'N'),
  ('Product',         'prod_max',      'PRODCORRELATION',  'STRCORRPROD',   'Correlation', 7, 'N'),
  ('Stress MPR 0.25', 'strmpr025_max', 'CORRELATION_0.25', 'STRCORR025',    'MPR',         8, 'N');

-- Note the intentional duplication to flag for risk: both '25th' and 'Stress MPR 0.25'
-- currently carry CORRELATION_0.25 / STRCORR025. They cannot both be correct — this is
-- the "025" open item. Risk to assign STRCORR025 to one and find 25th's true label.

-- =====================================================================
-- VALIDATION
-- =====================================================================
-- V-PK  friendly_name unique; 8 rows.
SELECT COUNT(*) AS rows_, COUNT(DISTINCT friendly_name) AS distinct_names
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.dim_scenario;
-- V-JOIN  every scenario in the fact resolves to a dim row (no orphans).
SELECT sc.Scenario_Name, d.friendly_name
FROM (SELECT DISTINCT Scenario_Name FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_asts_scenario) sc
LEFT JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.dim_scenario d
  ON d.friendly_name = sc.Scenario_Name
WHERE d.friendly_name IS NULL;   -- expect 0 rows
-- V-025  surface the duplicate mapping for risk.
SELECT lines_report_source, COUNT(*) AS mapped_to
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.dim_scenario
WHERE lines_report_source IS NOT NULL
GROUP BY lines_report_source HAVING COUNT(*) > 1;   -- STRCORR025 will show (the open item)
