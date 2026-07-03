-- =====================================================================
-- vw_pfe_scenario_detail   (v2 — SCENARIO FACT; vw_asts unpivoted)
-- Catalog d4001-centralus-tdvip-creditrisk · Schema xvala_core
--
-- WHY THIS VIEW EXISTS (rationale)
--   The scenario fact of the constellation. Source vw_asts is line × scenario with
--   the 6 tenor BUCKETS held as COLUMN families. This view UNPIVOTS the buckets to
--   ROWS (stack) so bucket becomes an axis attribute — grain line × scenario × bucket.
--   Scenario is already a row dimension in vw_asts (Scenario_Name), so only the
--   buckets are exploded. Feeds the scenario/bucket exposure fingerprint.
--
--   COMPUTES: the stack (reshape) + the bucket→limit ladder mapping. Reads the
--   already-cleaned, already-conformed, already-DOUBLE vw_asts — so no re-casting
--   of exposures here (vw_asts did it). Business_Date already DATE from vw_asts.
--
-- GRAIN   line × scenario × bucket        KEY  Line + Scenario_Name + Bucket
-- BASE    kept in (no scenario filter).
-- CONFORMS to: Line (to line fact & deal fact), Scenario_Name (to line fact maxima
--   & dim_scenario — WITHIN the asts vocabulary only), Counterparty_Name.
-- SOURCE QUIRK: vw_asts has NO 0_3_mo_Excess_Breach (emits NULL there); the stack
--   carries that NULL for the 0_3_mo bucket breach slot.
-- =====================================================================
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_scenario_detail` (
  Line                COMMENT 'Credit line identifier. Conformed key (inherited from vw_asts). FK to the line grain.',
  Scenario_Name       COMMENT 'The stress scenario (already friendly). Conformed key. FK to dim_scenario. asts vocabulary — do NOT join to other facts on the raw label.',
  Bucket              COMMENT 'Tenor bucket, UNPIVOTED to rows: 0_3_mo / 3_12_mo / 1_2_Yr / 2_5_Yr / 5_10_Yr / 10_50_Yr.',
  Bucket_Order        COMMENT 'Integer 1..6 for sorting buckets shortest->longest on an axis.',
  Counterparty_Name   COMMENT 'Counterparty / line long name.',
  Max_Usage           COMMENT 'Per-bucket stressed exposure for this scenario. The scenario-graph measure. SEMI-ADDITIVE: sum across lines within a scenario/bucket; GREATEST across scenarios.',
  Standard_Usage      COMMENT 'Per-bucket standard (base) exposure. Semi-additive.',
  Bucket_Limit        COMMENT 'Per-bucket limit (asts Limit ladder mapped to the bucket). Additive.',
  Excess_Breach       COMMENT 'Per-bucket breach flag STRING TRUE/FALSE. NULL for 0_3_mo (no such column in asts).',
  Excess_Percentage   COMMENT 'Per-bucket excess percentage (DOUBLE). NON-additive ratio.',
  Max_Scenario_Exposure COMMENT 'Row-level peak exposure across buckets for this scenario. Same on every bucket row of the scenario — do not sum across buckets.',
  Max_Exp_Time_Bucket COMMENT 'Which bucket produced Max_Scenario_Exposure.',
  Business_Date       COMMENT 'As-of date (DATE, inherited from vw_asts).'
)
AS
WITH base AS (
  SELECT
    Line, Scenario_Name, Long_Name,
    Max_Scenario_Exposure, Max_Exp_Time_Bucket, Business_Date,
    Standard_Usage_0_3_mo, Standard_Usage_3_12_mo, Standard_Usage_1_2_Yr,
    Standard_Usage_2_5_Yr, Standard_Usage_5_10_Yr, Standard_Usage_10_50_Yr,
    Max_Usage_0_3_mo, Max_Usage_3_12_mo, Max_Usage_1_2_Yr,
    Max_Usage_2_5_Yr, Max_Usage_5_10_Yr, Max_Usage_10_50_Yr,
    Limit_3_mo, Limit_1_Yr, Limit_2_Yr, Limit_5_Yr, Limit_10_Yr, Limit_50_Yr,
    `0_3_mo_Excess_Breach`, `3_12_mo_Excess_Breach`, `1_2_Yr_Excess_Breach`,
    `2_5_Yr_Excess_Breach`, `5_10_Yr_Excess_Breach`, `10_50_Yr_Excess_Breach`,
    `0_3_mo_Excess_Percentage`, `3_12_mo_Excess_Percentage`, `1_2_Yr_Excess_Percentage`,
    `2_5_Yr_Excess_Percentage`, `5_10_Yr_Excess_Percentage`, `10_50_Yr_Excess_Percentage`
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts`
  WHERE No_Line_Indicator = false     -- match the line fact's population; BASE scenarios kept
)
SELECT
  b.Line,
  b.Scenario_Name,
  s.Bucket,
  s.Bucket_Order,
  b.Long_Name                       AS Counterparty_Name,
  s.Max_Usage,                       -- already DOUBLE from vw_asts
  s.Standard_Usage,
  s.Bucket_Limit,
  s.Excess_Breach,
  s.Excess_Percentage,
  b.Max_Scenario_Exposure,
  b.Max_Exp_Time_Bucket,
  b.Business_Date
FROM base b
LATERAL VIEW stack(6,
  '0_3_mo',   1, b.Max_Usage_0_3_mo,   b.Standard_Usage_0_3_mo,   b.Limit_3_mo,  b.`0_3_mo_Excess_Breach`,   b.`0_3_mo_Excess_Percentage`,
  '3_12_mo',  2, b.Max_Usage_3_12_mo,  b.Standard_Usage_3_12_mo,  b.Limit_1_Yr,  b.`3_12_mo_Excess_Breach`,  b.`3_12_mo_Excess_Percentage`,
  '1_2_Yr',   3, b.Max_Usage_1_2_Yr,   b.Standard_Usage_1_2_Yr,   b.Limit_2_Yr,  b.`1_2_Yr_Excess_Breach`,   b.`1_2_Yr_Excess_Percentage`,
  '2_5_Yr',   4, b.Max_Usage_2_5_Yr,   b.Standard_Usage_2_5_Yr,   b.Limit_5_Yr,  b.`2_5_Yr_Excess_Breach`,   b.`2_5_Yr_Excess_Percentage`,
  '5_10_Yr',  5, b.Max_Usage_5_10_Yr,  b.Standard_Usage_5_10_Yr,  b.Limit_10_Yr, b.`5_10_Yr_Excess_Breach`,  b.`5_10_Yr_Excess_Percentage`,
  '10_50_Yr', 6, b.Max_Usage_10_50_Yr, b.Standard_Usage_10_50_Yr, b.Limit_50_Yr, b.`10_50_Yr_Excess_Breach`, b.`10_50_Yr_Excess_Percentage`
) s AS Bucket, Bucket_Order, Max_Usage, Standard_Usage, Bucket_Limit, Excess_Breach, Excess_Percentage
;

-- =====================================================================
-- VALIDATION
-- =====================================================================
-- V-GRAIN  out_rows = (vw_asts rows, No_Line=false) × 6 exactly (stack fan-out check).
SELECT
  (SELECT COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_asts WHERE No_Line_Indicator=false) AS src_rows,
  (SELECT COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_scenario_detail) AS out_rows,
  (SELECT COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_scenario_detail) * 1.0 /
    NULLIF((SELECT COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_asts WHERE No_Line_Indicator=false),0) AS ratio_should_be_6;
-- V-BUCKET  all 6 buckets present; 0_3_mo breach is NULL.
SELECT Bucket, Bucket_Order, COUNT(*) AS rows_,
       SUM(CASE WHEN Excess_Breach IS NULL THEN 1 ELSE 0 END) AS null_breach
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_scenario_detail
GROUP BY Bucket, Bucket_Order ORDER BY Bucket_Order;
-- V-SCEN  scenarios present (confirms BASE kept; shows the friendly labels).
SELECT Scenario_Name, COUNT(*) AS rows_
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_scenario_detail
GROUP BY Scenario_Name ORDER BY rows_ DESC;
