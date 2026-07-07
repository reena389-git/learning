-- =====================================================================
-- vw_pfe_asts_scenario   (v3 — SCENARIO FACT, built DIRECTLY on pfe_asts)
-- Catalog d4001-centralus-tdvip-creditrisk · Schema xvala_core
--
-- WHY THIS VIEW EXISTS
--   The scenario-level fact: one row per credit line per stress scenario. It powers
--   (1) the "pick a line, see how its exposure behaves across scenarios" drill, and
--   (2) the tenor-BUCKET detail behind a line's headline number — per-bucket exposure,
--       per-bucket limit, and per-bucket breach flag — which explains cases where a
--       line's overall utilisation looks moderate yet the line is flagged breached
--       because a DIFFERENT tenor bucket went over its own limit.
--
-- SOURCE   pfe_asts ONLY. The base-table cleaning (type-safe casts, date/normalisation,
--          conformed Line key) is folded in HERE — this view does not depend on any
--          other view. Every base column of pfe_asts is carried through (nothing dropped),
--          under the project's friendly PascalCase naming, plus a small number of derived
--          convenience columns (friendly Scenario_Name in place, Booking_Entity, Line_Class).
-- GRAIN    line × scenario   (~4 populated scenarios per line in this load)
-- KEY      Line + Scenario_Name
-- CONFORMS Line (to the line fact & deal fact). Base excludes Base/Cartor (empty this load).
-- TYPING   pfe_asts stores money/usage/limit values as STRING; they are cleaned to DOUBLE
--          via try_cast(replace(...,',','')) — null on garbage, never errors the view.
--          Breach flags stay STRING literal 'TRUE'/'FALSE'. Dates normalised to DATE.
-- NOTE     Line-level attributes (Long_Name, Line_Currency, Worst_Rating, and the derived
--          Booking_Entity / Line_Class) repeat on every one of a line's scenario rows —
--          do not SUM them across scenarios.
-- =====================================================================
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` (
  Scenario_Name      COMMENT 'The stress scenario, shown as a business-friendly name (e.g. Stress 75, Correlation 1.0, Product, 25th) mapped in place from the raw pfe_asts label. This is the scenario picker''s selectable value and the join to vw_dim_scenario. NOTE: the "0.25" correlation label is ambiguous in source (25th vs Stress MPR 0.25 share it) — flagged for the data owner; shown as "25th (0.25)".',
  Line               COMMENT 'The credit line. Conformed key (trim/upper-normalised here) shared with the line fact and deal fact, so a line selection drills across all three. For CP lines the Line value is also the counterparty_code; HC lines are agent/facility lines with no counterparty-dimension match.',
  Line_Class         COMMENT 'CP or HC — whether the line is a counterparty''s own line or a house/agent/fund facility. Derived here from the Line code prefix. Same on every scenario row of a line.',
  Booking_Entity     COMMENT 'The TD booking entity (TDBK, TDSU, …), derived here from the first bracketed token of the Line code. Repeated on each scenario row.',
  Long_Name          COMMENT 'The line''s long / counterparty name (pfe_asts.Long_Name). A display label, repeated on each scenario row — not a join key.',
  Line_Type          COMMENT 'The line type (e.g. C2C, CONT). Repeated on each scenario row.',
  Line_Expiry        COMMENT 'The line''s expiry date (normalised to a real date).',
  No_Line_Indicator  COMMENT 'Whether the row has no real line (boolean). Rows with no line are excluded from this fact.',
  Line_Currency      COMMENT 'The currency of the line. Repeated on each scenario row.',
  Worst_Rating_Of_Associated_Clients COMMENT 'The worst internal rating among the line''s associated clients. Line-level, repeated on each scenario row.',
  Standard_Usage_0_3_mo   COMMENT 'Standard (unstressed) usage in the 0–3 month tenor bucket. Money value.',
  Standard_Usage_3_12_mo  COMMENT 'Standard (unstressed) usage in the 3–12 month tenor bucket.',
  Standard_Usage_1_2_Yr   COMMENT 'Standard (unstressed) usage in the 1–2 year tenor bucket.',
  Standard_Usage_2_5_Yr   COMMENT 'Standard (unstressed) usage in the 2–5 year tenor bucket.',
  Standard_Usage_5_10_Yr  COMMENT 'Standard (unstressed) usage in the 5–10 year tenor bucket.',
  Standard_Usage_10_50_Yr COMMENT 'Standard (unstressed) usage in the 10–50 year tenor bucket.',
  Max_Usage_0_3_mo   COMMENT 'Stressed (max) exposure in the 0–3 month tenor bucket. Money value.',
  Max_Usage_3_12_mo  COMMENT 'Stressed (max) exposure in the 3–12 month tenor bucket.',
  Max_Usage_1_2_Yr   COMMENT 'Stressed (max) exposure in the 1–2 year tenor bucket.',
  Max_Usage_2_5_Yr   COMMENT 'Stressed (max) exposure in the 2–5 year tenor bucket.',
  Max_Usage_5_10_Yr  COMMENT 'Stressed (max) exposure in the 5–10 year tenor bucket.',
  Max_Usage_10_50_Yr COMMENT 'Stressed (max) exposure in the 10–50 year tenor bucket.',
  Limit_3_mo         COMMENT 'The limit governing the 0–3 month bucket. Pair with Max_Usage_0_3_mo for that bucket''s utilisation.',
  Limit_1_Yr         COMMENT 'The limit governing the 3-12 month bucket. Pair with Max_Usage_3_12_mo for that bucket''s utilisation.',
  Limit_2_Yr         COMMENT 'The limit governing the 1-2 year bucket. Pair with Max_Usage_1_2_Yr for that bucket''s utilisation.',
  Limit_5_Yr         COMMENT 'The limit governing the 2-5 year bucket. Pair with Max_Usage_2_5_Yr for that bucket''s utilisation.',
  Limit_10_Yr        COMMENT 'The limit governing the 5-10 year bucket. Pair with Max_Usage_5_10_Yr for that bucket''s utilisation.',
  Limit_50_Yr        COMMENT 'The limit governing the 10-50 year bucket. Pair with Max_Usage_10_50_Yr for that bucket''s utilisation.',
  `3_12_mo_Excess_Breach`  COMMENT 'Breach flag (TRUE/FALSE) for the 3–12 month bucket: TRUE means this bucket''s stressed exposure exceeded its limit in this scenario. A line''s overall Is_Breached is TRUE if ANY bucket flag is TRUE in ANY scenario — why a line can breach here while its headline utilisation sits on a different bucket.',
  `1_2_Yr_Excess_Breach`   COMMENT 'Breach flag (TRUE/FALSE) for the 1–2 year bucket.',
  `2_5_Yr_Excess_Breach`   COMMENT 'Breach flag (TRUE/FALSE) for the 2–5 year bucket.',
  `5_10_Yr_Excess_Breach`  COMMENT 'Breach flag (TRUE/FALSE) for the 5–10 year bucket.',
  `10_50_Yr_Excess_Breach` COMMENT 'Breach flag (TRUE/FALSE) for the 10–50 year bucket. (There is no 0–3 month breach flag in source — that bucket cannot raise a breach.)',
  `0_3_mo_Excess_Percentage`   COMMENT 'By how much the 0-3 month bucket''s exposure exceeds its limit, as a percentage. Source column from pfe_asts.',
  `3_12_mo_Excess_Percentage`  COMMENT 'By how much the 3-12 month bucket''s exposure exceeds its limit, as a percentage. Source column from pfe_asts.',
  `1_2_Yr_Excess_Percentage`   COMMENT 'By how much the 1-2 year bucket''s exposure exceeds its limit, as a percentage. Source column from pfe_asts.',
  `2_5_Yr_Excess_Percentage`   COMMENT 'By how much the 2-5 year bucket''s exposure exceeds its limit, as a percentage. Source column from pfe_asts.',
  `5_10_Yr_Excess_Percentage`  COMMENT 'By how much the 5-10 year bucket''s exposure exceeds its limit, as a percentage. Source column from pfe_asts.',
  `10_50_Yr_Excess_Percentage` COMMENT 'By how much the 10-50 year bucket''s exposure exceeds its limit, as a percentage. Source column from pfe_asts.',
  Gross_Max_Exposure COMMENT 'Gross maximum exposure across buckets for this line-scenario (money value).',
  Max_Scenario_Exposure COMMENT 'This line''s peak exposure under this scenario — the scenario view''s main measure. Adds up across lines WITHIN one scenario; across a line''s scenarios take the GREATEST (that peak equals the line fact''s Stress_PFE).',
  Max_Exp_Time_Bucket COMMENT 'The tenor bucket that produced this line-scenario''s peak exposure (e.g. max_usage_3_12_mo). Shows which bucket drives the headline utilisation — useful when reconciling utilisation against a breach in a different bucket.',
  Max_Scenario_Name  COMMENT 'The scenario that produced the row-level maximum exposure (raw source label).',
  Scenario_Code      COMMENT 'The raw scenario code from the source system (pfe_asts.Scenario). Kept for provenance; the friendly Scenario_Name above is the one to display/join.',
  Timestep           COMMENT 'Scenario timestep / horizon index from source. Not a grain dimension (typically null).',
  Standard_Exposure  COMMENT 'The standard (unstressed) exposure aligned to the peak bucket, from base values. A comparison point against the stressed Max_Scenario_Exposure.',
  Excess_Percentage  COMMENT 'Row-level excess percentage (how far the line-scenario is over its governing limit overall).',
  Exposure_Percentage COMMENT 'The line''s exposure as a percentage of its limit in this scenario. A source column from pfe_asts (not computed here).',
  Exposure_Percentage_0_3_mo   COMMENT 'Exposure as a percentage of the limit for the 0-3 month bucket. Source column from pfe_asts.',
  Exposure_Percentage_3_12_mo  COMMENT 'Exposure as a percentage of the limit for the 3-12 month bucket. Source column from pfe_asts.',
  Exposure_Percentage_1_2_yr   COMMENT 'Exposure as a percentage of the limit for the 1-2 year bucket. Source column from pfe_asts.',
  Exposure_Percentage_2_5_yr   COMMENT 'Exposure as a percentage of the limit for the 2-5 year bucket. Source column from pfe_asts.',
  Exposure_Percentage_5_10_yr  COMMENT 'Exposure as a percentage of the limit for the 5-10 year bucket. Source column from pfe_asts.',
  Exposure_Percentage_10_50_yr COMMENT 'Exposure as a percentage of the limit for the 10-50 year bucket. Source column from pfe_asts.',
  Business_Date      COMMENT 'The as-of date of the data (normalised to a real date).'
)
AS
SELECT
  -- Friendly scenario name mapped IN PLACE from the raw pfe_asts label (case-insensitive).
  -- Observed raw values: STRMARKETC75, Correlation_1.0, ProdCorrelation, Correlation_0.25.
  -- The 0.25 label is ambiguous in source (25th vs MPR 0.25) — surfaced as "25th (0.25)".
  CASE
    WHEN upper(Scenario_Name) = 'STRMARKETC75'                      THEN 'Stress 75'
    WHEN upper(Scenario_Name) IN ('CORRELATION_1.0','CORRELATION1.0','STRCORRONE') THEN 'Correlation 1.0'
    WHEN upper(Scenario_Name) IN ('PRODCORRELATION','STRCORRPROD')  THEN 'Product'
    WHEN upper(Scenario_Name) IN ('CORRELATION_0.25','STRCORR025')  THEN '25th (0.25)'
    WHEN upper(Scenario_Name) IN ('CORRELATION_0.75','STRCORR075')  THEN '75th'
    WHEN upper(Scenario_Name) IN ('ZERO','STRZERO')                 THEN 'Zero'
    ELSE Scenario_Name
  END                                                                   AS Scenario_Name,
  trim(upper(Line))                                                     AS Line,
  CASE WHEN Line LIKE 'CP%' THEN 'CP'
       WHEN Line LIKE 'HC%' THEN 'HC'
       ELSE 'Other' END                                                 AS Line_Class,
  regexp_extract(Line, '\\(([^)]+)\\)', 1)                              AS Booking_Entity,
  Long_Name,
  Line_Type,
  COALESCE(try_to_date(CAST(Line_Expiry AS STRING),'yyyyMMdd'),
           try_cast(CAST(Line_Expiry AS STRING) AS DATE))               AS Line_Expiry,
  CAST(No_Line_Indicator AS BOOLEAN)                                    AS No_Line_Indicator,
  Line_Currency,
  Worst_Rating_Of_Associated_Clients,
  try_cast(replace(CAST(Standard_Usage_0_3_mo   AS STRING),',','') AS DOUBLE) AS Standard_Usage_0_3_mo,
  try_cast(replace(CAST(Standard_Usage_3_12_mo  AS STRING),',','') AS DOUBLE) AS Standard_Usage_3_12_mo,
  try_cast(replace(CAST(Standard_Usage_1_2_Yr   AS STRING),',','') AS DOUBLE) AS Standard_Usage_1_2_Yr,
  try_cast(replace(CAST(Standard_Usage_2_5_Yr   AS STRING),',','') AS DOUBLE) AS Standard_Usage_2_5_Yr,
  try_cast(replace(CAST(Standard_Usage_5_10_Yr  AS STRING),',','') AS DOUBLE) AS Standard_Usage_5_10_Yr,
  try_cast(replace(CAST(Standard_Usage_10_50_Yr AS STRING),',','') AS DOUBLE) AS Standard_Usage_10_50_Yr,
  try_cast(replace(CAST(Max_Usage_0_3_mo   AS STRING),',','') AS DOUBLE) AS Max_Usage_0_3_mo,
  try_cast(replace(CAST(Max_Usage_3_12_mo  AS STRING),',','') AS DOUBLE) AS Max_Usage_3_12_mo,
  try_cast(replace(CAST(Max_Usage_1_2_Yr   AS STRING),',','') AS DOUBLE) AS Max_Usage_1_2_Yr,
  try_cast(replace(CAST(Max_Usage_2_5_Yr   AS STRING),',','') AS DOUBLE) AS Max_Usage_2_5_Yr,
  try_cast(replace(CAST(Max_Usage_5_10_Yr  AS STRING),',','') AS DOUBLE) AS Max_Usage_5_10_Yr,
  try_cast(replace(CAST(Max_Usage_10_50_Yr AS STRING),',','') AS DOUBLE) AS Max_Usage_10_50_Yr,
  try_cast(replace(CAST(Limit_3_mo  AS STRING),',','') AS DOUBLE) AS Limit_3_mo,
  try_cast(replace(CAST(Limit_1_Yr  AS STRING),',','') AS DOUBLE) AS Limit_1_Yr,
  try_cast(replace(CAST(Limit_2_Yr  AS STRING),',','') AS DOUBLE) AS Limit_2_Yr,
  try_cast(replace(CAST(Limit_5_Yr  AS STRING),',','') AS DOUBLE) AS Limit_5_Yr,
  try_cast(replace(CAST(Limit_10_Yr AS STRING),',','') AS DOUBLE) AS Limit_10_Yr,
  try_cast(replace(CAST(Limit_50_Yr AS STRING),',','') AS DOUBLE) AS Limit_50_Yr,
  `3_12_mo_Excess_Breach`,
  `1_2_Yr_Excess_Breach`,
  `2_5_Yr_Excess_Breach`,
  `5_10_Yr_Excess_Breach`,
  `10_50_Yr_Excess_Breach`,
  `0_3_mo_Excess_Percentage`,
  `3_12_mo_Excess_Percentage`,
  `1_2_Yr_Excess_Percentage`,
  `2_5_Yr_Excess_Percentage`,
  `5_10_Yr_Excess_Percentage`,
  `10_50_Yr_Excess_Percentage`,
  try_cast(replace(CAST(Gross_Max_Exposure    AS STRING),',','') AS DOUBLE) AS Gross_Max_Exposure,
  try_cast(replace(CAST(Max_Scenario_Exposure AS STRING),',','') AS DOUBLE) AS Max_Scenario_Exposure,
  Max_Exp_Time_Bucket,
  Max_Scenario_Name,
  Scenario                                                             AS Scenario_Code,
  Timestep,
  try_cast(replace(CAST(Standard_Exposure AS STRING),',','') AS DOUBLE) AS Standard_Exposure,
  Excess_Percentage,
  Exposure_Percentage,
  Exposure_Percentage_0_3_mo,
  Exposure_Percentage_3_12_mo,
  Exposure_Percentage_1_2_yr,
  Exposure_Percentage_2_5_yr,
  Exposure_Percentage_5_10_yr,
  Exposure_Percentage_10_50_yr,
  COALESCE(try_to_date(CAST(business_date AS STRING),'yyyyMMdd'),
           try_cast(CAST(business_date AS STRING) AS DATE))            AS Business_Date
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_asts`
WHERE COALESCE(CAST(No_Line_Indicator AS BOOLEAN), false) = false
;

-- =====================================================================
-- VALIDATION
-- =====================================================================
-- V-GRAIN  one row per line × scenario (no dup).
SELECT COUNT(*) AS rows_,
       COUNT(DISTINCT concat(Line,'|',Scenario_Name)) AS line_scn
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_asts_scenario;

-- V-TIE  scenario fact ties to line fact: GREATEST Max_Scenario_Exposure across a line's
--        scenarios should equal that line's Stress_PFE.
SELECT sc.Line, MAX(sc.Max_Scenario_Exposure) AS scn_greatest, ld.Stress_PFE
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_asts_scenario sc
JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail ld ON ld.Line = sc.Line
GROUP BY sc.Line, ld.Stress_PFE
HAVING ABS(MAX(sc.Max_Scenario_Exposure) - ld.Stress_PFE) > 1
LIMIT 20;

-- V-SCEN  scenarios present with friendly names (Base/Cartor absent).
SELECT Scenario_Name, COUNT(*) AS lines_, ROUND(SUM(Max_Scenario_Exposure)/1e9,3) AS exposure_b
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_asts_scenario
GROUP BY Scenario_Name ORDER BY exposure_b DESC;

-- V-BUCKET  AMCQ_C2C worked example: 2-5yr breach TRUE while headline bucket is 3-12mo.
SELECT Scenario_Name, Max_Exp_Time_Bucket,
       Max_Usage_3_12_mo, Limit_1_Yr,
       Max_Usage_2_5_Yr,  Limit_5_Yr, `2_5_Yr_Excess_Breach`
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_asts_scenario
WHERE Line = 'CP_(TDBK)_(AMCQ_C2C)'
ORDER BY Max_Scenario_Exposure DESC;
