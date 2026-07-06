-- =====================================================================
-- vw_pfe_asts_scenario   (v2 — SCENARIO FACT, rebuilt on vw_asts)
-- Catalog d4001-centralus-tdvip-creditrisk · Schema xvala_core
--
-- WHY THIS VIEW EXISTS (what it's for, in plain terms)
--   This is the scenario-level fact: one row for each credit line under each
--   stress scenario. It powers two things on the dashboard:
--     1. "Pick a line, see how its exposure behaves across the stress scenarios"
--        (the Line -> Scenario View drill), and
--     2. the tenor-BUCKET detail behind a line's headline number — the per-bucket
--        exposure, the per-bucket limit, and the per-bucket breach flag. This is
--        what explains cases where a line's overall utilisation looks moderate
--        (say 82% on its biggest bucket) yet the line is flagged breached because
--        a DIFFERENT, smaller tenor bucket went over its own limit.
--
-- WHAT CHANGED IN v2 (and why)
--   v1 was built from pfe_ats_summary by unpivoting its 8 scenario-total columns.
--   That gave one exposure number per scenario but carried NO bucket detail, and
--   it included an empty "Base/Cartor" scenario (cartor is unpopulated this load).
--   v2 is built from vw_asts — the cleaned scenario-level source where the bucket
--   exposures, bucket limits, and breach flags actually live. This is the source
--   this fact was always meant to use. Consequences, all intended:
--     - The bucket detail (6 exposures, 6 limits, 5 breach flags) is now carried
--       through, so the dashboard can show WHY a line breached.
--     - The empty Base/Cartor scenario is gone (vw_asts excludes it) — no real
--       exposure is lost; it was a hollow column.
--     - Scenario_Exposure is now vw_asts.Max_Scenario_Exposure (the peak exposure
--       for that line-scenario) — it still ties to the line fact's Stress_PFE via
--       GREATEST across a line's scenarios (see VALIDATION V-TIE).
--
-- SOURCE   vw_asts ONLY (no joins). Every column below is either native to
--          vw_asts or computed inline from its columns — nothing is fetched from
--          ats_summary. (Industry / Client_Type were dropped from this fact: they
--          are line-level attributes, already carried by the line fact, and add no
--          value at scenario grain.)
-- GRAIN    line × scenario   (~4 populated scenarios per line in this load)
-- KEY      Line + Scenario_Name
-- CONFORMS Line (to the line fact & deal fact), Scenario_Name (to vw_dim_scenario).
-- NOTE     Line-level attributes (Counterparty_Name, Booking_Entity, OTC_SFT,
--          Line_Worst_Rating, Limit_Amount, Line_Class) are the SAME on every one
--          of a line's scenario rows — do not SUM them across scenarios; use Max,
--          or better, take them from the line fact.
-- =====================================================================
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` (
  Line               COMMENT 'The credit line. Conformed key (already trim/upper-normalised in vw_asts), shared with the line fact and deal fact so a line selection drills across all three. For CP lines the Line value is also the counterparty_code; HC lines are agent/facility lines with no counterparty-dimension match.',
  Line_Class         COMMENT 'CP or HC, read from the start of the Line code. CP = a counterparty''s own line; HC = a house/agent/fund facility. Lets the scenario view be split CP vs HC. Same on every scenario row of a line.',
  Scenario_Name      COMMENT 'The stress scenario, shown as a business-friendly name (e.g. Stress 75, Correlation 1.0, Product, 25th) mapped from the raw asts scenario label. This is the scenario picker''s selectable value and the join to vw_dim_scenario. NOTE: the "0.25" correlation label is genuinely ambiguous in source (25th vs Stress MPR 0.25 share it) — flagged for the data owner; shown here as "25th (0.25)".',
  Scenario_Exposure  COMMENT 'This line''s peak exposure under this scenario (vw_asts.Max_Scenario_Exposure). The scenario view''s main measure. Adds up across lines WITHIN one scenario (portfolio-under-a-scenario = SUM within the chosen scenario); across scenarios for one line take the GREATEST (that peak equals the line fact''s Stress_PFE).',
  Counterparty_Name  COMMENT 'The line''s long name (vw_asts.Long_Name). A display label, repeated on each scenario row — not a join key.',
  Booking_Entity     COMMENT 'The booking entity (TDBK, TDSU, …), read from the first bracketed token of the Line code. Repeated on each scenario row.',
  Line_Worst_Rating  COMMENT 'The worst internal rating among the line''s associated clients. A line-level attribute, repeated on each scenario row.',
  OTC_SFT            COMMENT 'Whether the line is OTC derivatives or SFT (securities financing). Repeated on each scenario row; a common filter/split.',
  Limit_Amount       COMMENT 'The line''s headline limit — the largest limit across its six tenor buckets (computed inline as GREATEST of the bucket limits). A single reference limit; the per-bucket limits are also carried below for precise, bucket-matched utilisation. Repeated per scenario row — use Max, never Sum.',
  -- ---- TENOR-BUCKET DETAIL (the reason for the v2 rebuild) --------------------
  Max_Exp_Time_Bucket COMMENT 'The tenor bucket that produced this line-scenario''s peak exposure (e.g. max_usage_3_12_mo). Tells you which bucket drives the headline utilisation — useful when reconciling utilisation against a breach that sits in a different bucket.',
  Max_Usage_0_3_mo    COMMENT 'Stressed exposure in the 0–3 month tenor bucket. Money value.',
  Max_Usage_3_12_mo   COMMENT 'Stressed exposure in the 3–12 month tenor bucket.',
  Max_Usage_1_2_Yr    COMMENT 'Stressed exposure in the 1–2 year tenor bucket.',
  Max_Usage_2_5_Yr    COMMENT 'Stressed exposure in the 2–5 year tenor bucket.',
  Max_Usage_5_10_Yr   COMMENT 'Stressed exposure in the 5–10 year tenor bucket.',
  Max_Usage_10_50_Yr  COMMENT 'Stressed exposure in the 10–50 year tenor bucket.',
  Limit_3_mo          COMMENT 'The limit governing the 0–3 month bucket. Pair with Max_Usage_0_3_mo for that bucket''s utilisation.',
  Limit_1_Yr          COMMENT 'The limit governing the 3–12 month bucket.',
  Limit_2_Yr          COMMENT 'The limit governing the 1–2 year bucket.',
  Limit_5_Yr          COMMENT 'The limit governing the 2–5 year bucket.',
  Limit_10_Yr         COMMENT 'The limit governing the 5–10 year bucket.',
  Limit_50_Yr         COMMENT 'The limit governing the 10–50 year bucket.',
  `3_12_mo_Excess_Breach`  COMMENT 'Breach flag (TRUE/FALSE) for the 3–12 month bucket: TRUE means this bucket''s stressed exposure exceeded its limit in this scenario. A line''s overall Is_Breached is TRUE if ANY bucket flag is TRUE in ANY scenario — which is why a line can breach here while its headline utilisation sits on a different bucket.',
  `1_2_Yr_Excess_Breach`   COMMENT 'Breach flag (TRUE/FALSE) for the 1–2 year bucket.',
  `2_5_Yr_Excess_Breach`   COMMENT 'Breach flag (TRUE/FALSE) for the 2–5 year bucket.',
  `5_10_Yr_Excess_Breach`  COMMENT 'Breach flag (TRUE/FALSE) for the 5–10 year bucket.',
  `10_50_Yr_Excess_Breach` COMMENT 'Breach flag (TRUE/FALSE) for the 10–50 year bucket. (There is no 0–3 month breach flag in source — that bucket cannot raise a breach.)',
  Standard_Exposure   COMMENT 'The standard (unstressed) exposure aligned to the peak bucket, from base values. A comparison point against the stressed Scenario_Exposure.',
  Business_Date      COMMENT 'As-of date (normalised to a real date). Repeated on each scenario row.'
)
AS
SELECT
  a.Line,
  CASE WHEN a.Line LIKE 'CP%' THEN 'CP'
       WHEN a.Line LIKE 'HC%' THEN 'HC'
       ELSE 'Other' END                                                 AS Line_Class,
  -- Friendly scenario name mapped from the raw asts label (case-insensitive).
  -- Values observed in asts: STRMARKETC75, Correlation_1.0, ProdCorrelation,
  -- Correlation_0.25. The 0.25 label is ambiguous in source (25th vs MPR 0.25) —
  -- surfaced as "25th (0.25)" and flagged for the data owner.
  CASE
    WHEN upper(a.Scenario_Name) = 'STRMARKETC75'                 THEN 'Stress 75'
    WHEN upper(a.Scenario_Name) IN ('CORRELATION_1.0','CORRELATION1.0','STRCORRONE') THEN 'Correlation 1.0'
    WHEN upper(a.Scenario_Name) IN ('PRODCORRELATION','STRCORRPROD') THEN 'Product'
    WHEN upper(a.Scenario_Name) IN ('CORRELATION_0.25','STRCORR025') THEN '25th (0.25)'
    WHEN upper(a.Scenario_Name) IN ('CORRELATION_0.75','STRCORR075') THEN '75th'
    WHEN upper(a.Scenario_Name) IN ('ZERO','STRZERO')            THEN 'Zero'
    ELSE a.Scenario_Name
  END                                                                   AS Scenario_Name,
  a.Max_Scenario_Exposure                                               AS Scenario_Exposure,
  a.Long_Name                                                           AS Counterparty_Name,
  regexp_extract(a.Line, '\\(([^)]+)\\)', 1)                            AS Booking_Entity,
  a.Worst_Rating_Of_Associated_Clients                                  AS Line_Worst_Rating,
  a.otc_sft                                                             AS OTC_SFT,
  GREATEST(
    COALESCE(a.Limit_3_mo,0),  COALESCE(a.Limit_1_Yr,0),
    COALESCE(a.Limit_2_Yr,0),  COALESCE(a.Limit_5_Yr,0),
    COALESCE(a.Limit_10_Yr,0), COALESCE(a.Limit_50_Yr,0)
  )                                                                     AS Limit_Amount,
  -- ---- tenor-bucket detail (native to vw_asts) --------------------------------
  a.Max_Exp_Time_Bucket,
  a.Max_Usage_0_3_mo,
  a.Max_Usage_3_12_mo,
  a.Max_Usage_1_2_Yr,
  a.Max_Usage_2_5_Yr,
  a.Max_Usage_5_10_Yr,
  a.Max_Usage_10_50_Yr,
  a.Limit_3_mo,
  a.Limit_1_Yr,
  a.Limit_2_Yr,
  a.Limit_5_Yr,
  a.Limit_10_Yr,
  a.Limit_50_Yr,
  a.`3_12_mo_Excess_Breach`,
  a.`1_2_Yr_Excess_Breach`,
  a.`2_5_Yr_Excess_Breach`,
  a.`5_10_Yr_Excess_Breach`,
  a.`10_50_Yr_Excess_Breach`,
  a.Standard_Exposure,
  a.Business_Date
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_asts` a
WHERE a.No_Line_Indicator = false
;

-- =====================================================================
-- VALIDATION
-- =====================================================================
-- V-GRAIN  one row per line × scenario (no dup).
SELECT COUNT(*) AS rows_,
       COUNT(DISTINCT concat(Line,'|',Scenario_Name)) AS line_scn
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_asts_scenario;

-- V-TIE  scenario fact must still tie to the line fact: the GREATEST Scenario_Exposure
--        across a line's scenarios should equal that line's Stress_PFE.
--        NOTE: line fact covers all 11,804 lines incl. no-deal/limit-only ones; the
--        scenario fact (from asts) covers the lines asts scores. Expect ~0 rows where
--        both sides are present and disagree by > 1.
SELECT sc.Line,
       MAX(sc.Scenario_Exposure) AS scn_greatest,
       ld.Stress_PFE
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_asts_scenario sc
JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail ld ON ld.Line = sc.Line
GROUP BY sc.Line, ld.Stress_PFE
HAVING ABS(MAX(sc.Scenario_Exposure) - ld.Stress_PFE) > 1
LIMIT 20;

-- V-SCEN  scenarios present with friendly names + exposure (Base/Cartor should be ABSENT).
SELECT Scenario_Name, COUNT(*) AS lines_, ROUND(SUM(Scenario_Exposure)/1e9,3) AS exposure_b
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_asts_scenario
GROUP BY Scenario_Name ORDER BY exposure_b DESC;

-- V-BUCKET  the AMCQ_C2C worked example: 2-5yr breach TRUE while headline bucket is 3-12mo.
--   Confirms the bucket detail explains the "82% but breached" case.
SELECT Scenario_Name, Max_Exp_Time_Bucket,
       Max_Usage_3_12_mo, Limit_1_Yr,
       Max_Usage_2_5_Yr,  Limit_5_Yr, `2_5_Yr_Excess_Breach`
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_asts_scenario
WHERE Line = 'CP_(TDBK)_(AMCQ_C2C)'
ORDER BY Scenario_Exposure DESC;
