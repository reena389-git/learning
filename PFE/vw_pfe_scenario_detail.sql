-- =====================================================================
-- vw_pfe_scenario_detail   (v1 — the LONG scenario fact)
-- Databricks SQL.  Catalog: d4001-centralus-tdvip-creditrisk  Schema: xvala_core
--
-- PURPOSE / RATIONALE
--   The third fact in the Mosaic constellation, alongside:
--     vw_pfe_line_detail   (line grain — wide Line_Scn_* for the roll-up math)
--     vw_pfe_deals_by_line (deal grain)
--   This one is the SCENARIO fact: source asts is line × scenario × timestep with
--   the 6 tenor BUCKETS held as COLUMN families. Per the "model it once so no
--   remodel later" decision, this view UNPIVOTS the buckets to ROWS, giving a fully
--   long grain:  line × scenario × timestep × bucket.  Scenario is already a row
--   dimension in asts (Scenario_Name / Scenario code), so no scenario unpivot is
--   needed — only the buckets are exploded.
--
--   WHY A SEPARATE VIEW (computes vs joins): this is a RESHAPE (stack/unpivot) +
--   type-cast, not a join. Mosaic cannot unpivot column families into a scenario/
--   bucket axis; it must arrive already long. Real work here: (1) stack() 6 bucket
--   families into rows; (2) STRING-with-commas -> DOUBLE on every exposure/limit/pct;
--   (3) date normalize. Dimensions (Line, Scenario_Name, Bucket, Timestep) are then
--   conformed keys the model relates to the other facts — NEVER physically joined
--   fact-to-fact (that fans out; see vw_pfe_deals_by_line notes).
--
-- GRAIN         line × scenario × timestep × bucket  (fully long)
-- BASE          KEPT IN. No scenario filter — whatever scenarios asts carries
--               (incl. Base/Cartor) flow through; filter at the dashboard if wanted.
-- SOURCE QUIRKS (confirmed against xvala_create_tables.sql DDL):
--   * Excess_Breach exists for only 5 buckets — NO 0_3_mo_Excess_Breach in asts.
--     The 0-3mo bucket's breach slot is emitted as NULL (honest — no source value).
--   * Exposure_Percentage bucket cols use lowercase 'yr' (_1_2_yr) while Limit_/
--     Usage_ use 'Yr'. Names below are verbatim from DDL.
--   * All Usage/Limit/Exposure values are STRING with thousands commas -> cast.
--   * business_date is STRING 'yyyymmdd' here (unlike the DATE tables) -> normalized.
-- =====================================================================
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_scenario_detail (
  Line                COMMENT 'Credit line identifier. Conformed key to vw_pfe_line_detail / vw_pfe_deals_by_line.',
  Counterparty_Name   COMMENT 'asts.Long_Name — counterparty display name.',
  Line_Type           COMMENT 'asts.Line_Type.',
  Line_Currency       COMMENT 'asts.Line_Currency.',
  Worst_Rating        COMMENT 'asts.Worst_Rating_Of_Associated_Clients.',
  Scenario_Name       COMMENT 'Mapped scenario display name from asts.Scenario_Name (DDL note: BASE excluded upstream — but no filter applied here; whatever is present flows through). The scenario AXIS attribute for the graph. Friendly-name mapping deferred: rename in the dashboard for now.',
  Scenario_Code       COMMENT 'asts.Scenario — raw scenario code from source system (e.g. cartor/str75). Join key for a future pfe_scenario_names mapping table.',
  Timestep            COMMENT 'asts.Timestep — scenario timestep / horizon index. Kept (not collapsed) so no detail is lost; aggregate or ignore at the dashboard if not needed.',
  Bucket              COMMENT 'Tenor bucket, UNPIVOTED to rows: 0_3_mo / 3_12_mo / 1_2_Yr / 2_5_Yr / 5_10_Yr / 10_50_Yr. The bucket AXIS attribute.',
  Bucket_Order        COMMENT 'Integer 1..6 for sorting buckets shortest->longest on an axis (0_3_mo=1 ... 10_50_Yr=6).',
  Max_Usage           COMMENT 'Per-bucket stressed exposure for this scenario/timestep (asts.Max_Usage_{bucket}), STRING->DOUBLE. The scenario-graph measure.',
  Standard_Usage      COMMENT 'Per-bucket standard (base) exposure (asts.Standard_Usage_{bucket}), STRING->DOUBLE.',
  Bucket_Limit        COMMENT 'Per-bucket limit (asts.Limit_{bucket ladder}), STRING->DOUBLE.',
  Excess_Breach       COMMENT 'Per-bucket breach flag STRING TRUE/FALSE (asts.{bucket}_Excess_Breach). NULL for 0_3_mo — no such column in asts.',
  Excess_Percentage   COMMENT 'Per-bucket excess percentage (asts.{bucket}_Excess_Percentage), DOUBLE in source.',
  Exposure_Percentage COMMENT 'Per-bucket exposure percentage (asts.Exposure_Percentage_{bucket}), STRING->DOUBLE.',
  Max_Scenario_Exposure COMMENT 'Row-level peak exposure across buckets for this scenario (asts.Max_Scenario_Exposure), STRING->DOUBLE. Same on every bucket row of the scenario (do not sum across buckets).',
  Max_Exp_Time_Bucket COMMENT 'Which bucket produced Max_Scenario_Exposure (asts.Max_Exp_Time_Bucket).',
  Business_Date       COMMENT 'Normalized to real DATE from asts STRING yyyymmdd.'
)
AS
WITH base AS (
    SELECT
        Line,
        Long_Name,
        Line_Type,
        Line_Currency,
        Worst_Rating_Of_Associated_Clients,
        Scenario_Name,
        Scenario,
        Timestep,
        No_Line_Indicator,
        -- per-bucket families kept STRING here; cast AFTER the stack (stack needs
        -- consistent types per output slot, so cast downstream not inline).
        Standard_Usage_0_3_mo, Standard_Usage_3_12_mo, Standard_Usage_1_2_Yr,
        Standard_Usage_2_5_Yr, Standard_Usage_5_10_Yr, Standard_Usage_10_50_Yr,
        Max_Usage_0_3_mo, Max_Usage_3_12_mo, Max_Usage_1_2_Yr,
        Max_Usage_2_5_Yr, Max_Usage_5_10_Yr, Max_Usage_10_50_Yr,
        Limit_3_mo, Limit_1_Yr, Limit_2_Yr, Limit_5_Yr, Limit_10_Yr, Limit_50_Yr,
        -- NB: NO 0_3_mo_Excess_Breach column in asts -> NULL literal in the stack.
        `3_12_mo_Excess_Breach`, `1_2_Yr_Excess_Breach`, `2_5_Yr_Excess_Breach`,
        `5_10_Yr_Excess_Breach`, `10_50_Yr_Excess_Breach`,
        `0_3_mo_Excess_Percentage`, `3_12_mo_Excess_Percentage`, `1_2_Yr_Excess_Percentage`,
        `2_5_Yr_Excess_Percentage`, `5_10_Yr_Excess_Percentage`, `10_50_Yr_Excess_Percentage`,
        Exposure_Percentage_0_3_mo, Exposure_Percentage_3_12_mo, Exposure_Percentage_1_2_yr,
        Exposure_Percentage_2_5_yr, Exposure_Percentage_5_10_yr, Exposure_Percentage_10_50_yr,
        Max_Scenario_Exposure,
        Max_Exp_Time_Bucket,
        business_date
    FROM `d4001-centralus-tdvip-creditrisk`.xvala_core.vw_asts
    -- No scenario filter (BASE kept). No_Line filter kept to match the other facts'
    -- line population; drop this line if the scenario graph should include no-line rows.
    WHERE No_Line_Indicator = 'False'
),
unpivoted AS (
    -- stack() explodes the 6 bucket families into 6 rows per source row.
    -- Each output slot must be one consistent type across all 6 buckets:
    --   bucket(STRING), order(INT), max_usage(STRING), std_usage(STRING),
    --   limit(STRING), breach(STRING), excess_pct(DOUBLE), exposure_pct(STRING).
    -- 0_3_mo breach = NULL (no source col). Limits map on the tenor ladder
    -- (0_3_mo->Limit_3_mo, 3_12_mo->Limit_1_Yr, 1_2_Yr->Limit_2_Yr,
    --  2_5_Yr->Limit_5_Yr, 5_10_Yr->Limit_10_Yr, 10_50_Yr->Limit_50_Yr).
    SELECT
        b.Line, b.Long_Name, b.Line_Type, b.Line_Currency,
        b.Worst_Rating_Of_Associated_Clients,
        b.Scenario_Name, b.Scenario, b.Timestep,
        b.Max_Scenario_Exposure, b.Max_Exp_Time_Bucket, b.business_date,
        s.Bucket, s.Bucket_Order, s.Max_Usage_s, s.Standard_Usage_s,
        s.Bucket_Limit_s, s.Excess_Breach, s.Excess_Percentage, s.Exposure_Percentage_s
    FROM base b
    LATERAL VIEW stack(6,
        '0_3_mo',   1, b.Max_Usage_0_3_mo,   b.Standard_Usage_0_3_mo,   b.Limit_3_mo,  CAST(NULL AS STRING),          b.`0_3_mo_Excess_Percentage`,  b.Exposure_Percentage_0_3_mo,
        '3_12_mo',  2, b.Max_Usage_3_12_mo,  b.Standard_Usage_3_12_mo,  b.Limit_1_Yr,  b.`3_12_mo_Excess_Breach`,     b.`3_12_mo_Excess_Percentage`, b.Exposure_Percentage_3_12_mo,
        '1_2_Yr',   3, b.Max_Usage_1_2_Yr,   b.Standard_Usage_1_2_Yr,   b.Limit_2_Yr,  b.`1_2_Yr_Excess_Breach`,      b.`1_2_Yr_Excess_Percentage`,  b.Exposure_Percentage_1_2_yr,
        '2_5_Yr',   4, b.Max_Usage_2_5_Yr,   b.Standard_Usage_2_5_Yr,   b.Limit_5_Yr,  b.`2_5_Yr_Excess_Breach`,      b.`2_5_Yr_Excess_Percentage`,  b.Exposure_Percentage_2_5_yr,
        '5_10_Yr',  5, b.Max_Usage_5_10_Yr,  b.Standard_Usage_5_10_Yr,  b.Limit_10_Yr, b.`5_10_Yr_Excess_Breach`,     b.`5_10_Yr_Excess_Percentage`, b.Exposure_Percentage_5_10_yr,
        '10_50_Yr', 6, b.Max_Usage_10_50_Yr, b.Standard_Usage_10_50_Yr, b.Limit_50_Yr, b.`10_50_Yr_Excess_Breach`,    b.`10_50_Yr_Excess_Percentage`,b.Exposure_Percentage_10_50_yr
    ) s AS Bucket, Bucket_Order, Max_Usage_s, Standard_Usage_s, Bucket_Limit_s, Excess_Breach, Excess_Percentage, Exposure_Percentage_s
)
SELECT
    Line,
    Long_Name                                   AS Counterparty_Name,
    Line_Type,
    Line_Currency,
    Worst_Rating_Of_Associated_Clients          AS Worst_Rating,
    Scenario_Name,
    Scenario                                     AS Scenario_Code,
    Timestep,
    Bucket,
    Bucket_Order,
    -- STRING(commas) -> DOUBLE for every numeric slot
    CAST(REPLACE(Max_Usage_s,        ',', '') AS DOUBLE)  AS Max_Usage,
    CAST(REPLACE(Standard_Usage_s,   ',', '') AS DOUBLE)  AS Standard_Usage,
    CAST(REPLACE(Bucket_Limit_s,     ',', '') AS DOUBLE)  AS Bucket_Limit,
    Excess_Breach,                                                     -- STRING TRUE/FALSE (or NULL for 0_3_mo)
    Excess_Percentage,                                                 -- already DOUBLE in source
    CAST(REPLACE(Exposure_Percentage_s, ',', '') AS DOUBLE) AS Exposure_Percentage,
    CAST(REPLACE(Max_Scenario_Exposure, ',', '') AS DOUBLE) AS Max_Scenario_Exposure,
    Max_Exp_Time_Bucket,
    to_date(regexp_replace(CAST(business_date AS STRING),'-',''),'yyyyMMdd') AS Business_Date
FROM unpivoted
;

-- =====================================================================
-- VALIDATION
-- =====================================================================
-- V-GRAIN  fan-out check: rows should = (source asts rows after No_Line filter) x 6.
--          Confirms the stack produced exactly 6 bucket rows per source row.
SELECT
  (SELECT COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.xvala_core.vw_asts
     WHERE No_Line_Indicator='False') AS src_rows,
  (SELECT COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_scenario_detail) AS out_rows,
  (SELECT COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_scenario_detail) * 1.0 /
    NULLIF((SELECT COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.xvala_core.vw_asts
      WHERE No_Line_Indicator='False'),0) AS ratio_should_be_6;

-- V-SCEN  which scenarios are present (confirms BASE/Cartor is in, per decision).
--         Also surfaces whether Scenario_Name is already business-friendly (if so,
--         the deferred mapping table may be unnecessary).
SELECT Scenario_Name, Scenario AS scenario_code, COUNT(*) AS rows_
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_scenario_detail
GROUP BY Scenario_Name, Scenario
ORDER BY rows_ DESC;

-- V-BUCKET  all 6 buckets present with the right order; 0_3_mo breach is NULL.
SELECT Bucket, Bucket_Order,
       COUNT(*) AS rows_,
       SUM(CASE WHEN Excess_Breach IS NULL THEN 1 ELSE 0 END) AS null_breach
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_scenario_detail
GROUP BY Bucket, Bucket_Order
ORDER BY Bucket_Order;

-- V-TIE  scenario fact should tie to the line fact's wide columns: for a given line,
--        MAX(Max_Usage) across a scenario's buckets ~ that scenario's Line_Scn_* value
--        in vw_pfe_line_detail (both are the scenario's peak-bucket max at line grain).
--        Spot-check one line/scenario before trusting the model to relate them.
--   SELECT Line, Scenario_Name, MAX(Max_Usage)
--   FROM vw_pfe_scenario_detail WHERE Line = '<pick one>' GROUP BY Line, Scenario_Name;
--   -- compare to Line_Scn_* for that line in vw_pfe_line_detail.
