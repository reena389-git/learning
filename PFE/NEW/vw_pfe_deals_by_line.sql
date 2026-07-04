-- =============================================================================
-- vw_pfe_deals_by_line.sql   (LEVEL 3 — Individual Line / Deal detail)
-- Databricks SQL.  Catalog: d4001-centralus-tdvip-creditrisk
--
-- PURPOSE (Tia's email, Level 3 "Individual Line Tab"):
--   For a selected line/counterparty, show the underlying DEALS broken down by
--   asset class, with MTM / notional / maturity and the override flag, so an
--   analyst can drill Level 2 (facility/breach line) -> Level 3 (its deals).
--   The "historical max stress PFE" trend on that tab is a LINE-level series and
--   comes from asts/the portfolio view over history — NOT from this deal table
--   (see LIMITATIONS). This view supplies the deal/asset-class half.
--
-- GRAIN  : one row per DEAL (deal_id) per business_date, under a `line`.
-- SOURCE : `xvala_core`.pfe_deals_report  (consolidated schema, pfe_ prefix).
-- KEY    : `line`  (XX_(TDBK)_(ZZZZ)) — same key as the breach/facility view,
--          so this drills from a line. Entity parsed the same way.
--
-- LIMITATIONS (confirmed from sample — flag to business):
--   * NO deal-level stress PFE in this table. deal_m2m (MTM) is the only exposure
--     measure at deal grain. Stress PFE stays a LINE total (asts/ats_summary).
--     -> "deals by asset class" is summarised by MTM and deal COUNT, not stress PFE.
--   * principal_1 (notional) is MULTI-CURRENCY (USD/JPY/CLP/EUR/HUF...). It is
--     therefore NOT additive across deals without FX conversion. It is exposed
--     per-deal for reference, but DO NOT SUM it across mixed currencies. deal_m2m
--     is consistently USD and IS summable.
--   * "asset class" = deal_type as-is (Swap, Cross Currency Swap, FX Forward,
--     Equity Option, Repurchase Agreement, Commodity Forward...). A higher-level
--     asset_class_group map is provided as a CASE, <confirm> with business.
-- =============================================================================

CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` (
  Line                COMMENT 'EXPOSURE / DRILL key (= deals.line). The unified HC/CP exposure line: CP-format where the deal is direct (Line = Counterparty_Code), HC-format where it is an agent/facility. RELATES TO vw_ats_lines_detail.Line (deal->line-fact drill), matching 4,603 CP + 712 HC = 5,315 lines, no double-count. NOTE: this is the FACILITY/EXPOSURE key, NOT the counterparty — for counterparty attribution use Counterparty_Code (an HC line is a facility, not a counterparty).',
  Line_Class          COMMENT 'CP or HC. DERIVED from the Line prefix. CP = the line IS the counterparty (direct); HC = agent/fund/house facility whose trades post to a CP (Counterparty_Code). Matches the line/scenario facts Line_Class.',
  Facility_Line_Code  COMMENT 'Alias of Line — the HC/CP facility/exposure line code, named explicitly for the deal screen (the facility a deal is booked to).',
  Booking_Entity      COMMENT 'Parsed from the first parenthesised token of Line (e.g. CP_(TDBK)_(...) -> TDBK).',
  Counterparty_Name   COMMENT 'counterparty_long_name — the COUNTERPARTY''s name (tracks Counterparty_Code; varies by CP code, confirmed). NOT the facility name.',
  Counterparty_Code   COMMENT 'counterparty_code (always CP format) — the COUNTERPARTY the trade posts to. This is the CP-ATTRIBUTION key: RELATES TO pfe_clients_report.counterparty_code (deal->CP dimension). For HC facility deals this is the underlying CP; for CP deals it equals Line. NEVER relate the deal to the CP dimension on Line — only on Counterparty_Code.',
  Deal_Id             COMMENT 'deal_id — deal grain key.',
  Deal_Name           COMMENT 'name.',
  New_Deal_Flag       COMMENT 'new_deal_flag (Y/N) — new this load.',
  Line_Type           COMMENT 'line_type (C2C, CONT, ...).',
  Asset_Class         COMMENT 'deal_type as-is (the asset/product classifier).',
  Asset_Class_Group   COMMENT '<confirm> higher-level grouping of deal_type (Rates/FX/Equity/Repo-SFT/Commodity/Other).',
  ISDA_Indicator      COMMENT 'isda_indicator (Y/N).',
  Industry            COMMENT 'sic_industry (granular). CONFORMS with vw_ats_lines_detail.Industry (same counterparty reference attribute).',
  Counterparty_Rating COMMENT 'td_account_rating — the counterparty''s own account rating. DO NOT CONFORM with Line_Worst_Rating (worst across the line''s clients — different grain/concept).',
  MTM                 COMMENT 'deal_m2m, CAST to DOUBLE. Consistently USD -> SUMMABLE.',
  MTM_Currency        COMMENT 'deal_m2m_currency.',
  Notional_1          COMMENT 'principal_1, CAST to DOUBLE. MULTI-CURRENCY -> NOT summable across deals without FX.',
  Notional_1_Currency COMMENT 'principal_1_currency.',
  Notional_2          COMMENT 'principal_2, CAST to DOUBLE. Same FX caveat.',
  Notional_2_Currency COMMENT 'principal_2_currency.',
  Trade_Date          COMMENT 'trade_date.',
  Maturity_Date       COMMENT 'maturity_date.',
  Years_To_Maturity   COMMENT 'years_to_maturity, CAST to DOUBLE.',
  -- (+) LEVEL-3 EXPLORER LENSES (folded in — derived buckets for the deal screen)
  Maturity_Band       COMMENT 'SELECTOR LENS: <=90d / 90d-1Yr / 1-2Yr / 2-5Yr / 5Yr+ from Years_To_Maturity.',
  Tenor_Band          COMMENT 'RUNWAY COLOUR: Rolls off (<=1Yr) / Mid (1-5Yr) / Structural (>5Yr).',
  Margin_Call_Norm    COMMENT 'SELECTOR LENS: Daily / Not daily (N/A), normalized from margin_call_frequency.',
  New_Deal_Norm       COMMENT 'SELECTOR LENS: New / Existing from new_deal_flag.',
  Override_Norm       COMMENT 'FLAG: Overridden / Clean from override (audit marker).',
  -- (+) LINE BREACH CONTEXT (from vw_line_stress_spine, joined on Line)
  Line_Stress_PFE     COMMENT 'The deal''s LINE total stress PFE (line-level, not deal-level).',
  Line_Standard_PFE   COMMENT 'The line''s standard (base/cartor) PFE. Line-level, repeated on deals — do NOT sum.',
  Line_Limit          COMMENT 'The line''s limit amount. Line-level, repeated on deals — do NOT sum (use Max).',
  Line_Utilization    COMMENT 'The line''s utilization (stress/limit). RATIO.',
  Is_Breached         COMMENT 'Y/N — the line''s breach flag from vw_ats_lines_detail (window-MAX OR of the 5 tenor breach flags). Repeated on every deal of the line.',
  Line_Worst_Scenario COMMENT 'Which scenario drives the line (filter deals by scenario via this).',
  Line_IM             COMMENT 'The line''s Initial Margin (line/agreement level). Repeated on deals — do NOT sum.',
  Line_IA             COMMENT 'The line''s Independent Amount (line/agreement level). Repeated on deals — do NOT sum.',
  Line_MTM_Base       COMMENT 'The line''s base mark-to-market (CARTOR). Line-level, repeated on deals — do NOT sum.',
  Line_MTM_Stress     COMMENT 'The line''s MTM under 75% market stress (STRMARKETC75). Line-level, repeated on deals — do NOT sum.',
  -- (+) DEAL BEHAVIOUR WITHIN ITS LINE (window functions over the line partition)
  MTM_Share_Of_Line   COMMENT 'Abs(deal MTM) / line gross MTM. Concentration — which deals drive the line.',
  Is_Dominant_Deal    COMMENT 'Y when this deal is >= 25% of the line gross MTM (a whale).',
  Maturity_Position   COMMENT 'Longest / Long / Mid / Short — this deal''s tenor vs the line''s spread.',
  Is_Longest_In_Line  COMMENT 'Y when this deal has the max ytm in its line (the structural tail).',
  Direction_Vs_Line   COMMENT 'Adds / Hedges — deal MTM sign vs the line net MTM direction.',
  Line_New_MTM_Share  COMMENT 'Share of line gross MTM that is NEW this load (line-level, repeated).',
  Line_Override_Share COMMENT 'Share of line gross MTM under override (line-level, repeated).',
  Override            COMMENT 'override (Y/N) — ties to req-4 Override Function.',
  Override_Date       COMMENT 'override_date.',
  OES_Indicator       COMMENT 'oes_indicator.',
  QA_Number           COMMENT 'qa_number.',
  IM_Model            COMMENT 'im_model.',
  Margin_Call_Frequency COMMENT 'margin_call_frequency.',
  Agreement_Group_Code  COMMENT 'agreement_group_code.',
  Source              COMMENT 'source feed.',
  Business_Date       COMMENT 'business_date (yyyymmdd string here).'
)
AS
WITH base AS (
  SELECT
    d.*,
    -- numerics computed once so the band CASEs + behavioural windows below can reuse them
    CAST(NULLIF(REPLACE(d.`years_to_maturity`,',',''),'null') AS DOUBLE) AS ytm_num,
    CAST(NULLIF(REPLACE(d.`deal_m2m`,',',''),'null')         AS DOUBLE) AS mtm_num
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_deals_report` d
  WHERE COALESCE(CAST(d.`no_line_indicator` AS BOOLEAN), false) = false   -- (~) BOOLEAN-safe: real lines only (handles boolean or 'true'/'false' string, null-safe)
),
win AS (   -- line-partition aggregates: a deal's behaviour is relative to its line
  SELECT b.*,
    SUM(ABS(mtm_num)) OVER (PARTITION BY `line`, `business_date`)              AS line_gross_mtm,
    SUM(mtm_num)      OVER (PARTITION BY `line`, `business_date`)              AS line_net_mtm,
    COUNT(*)          OVER (PARTITION BY `line`, `business_date`)              AS line_deal_count,
    MAX(ytm_num)      OVER (PARTITION BY `line`, `business_date`)              AS line_max_ytm,
    AVG(ytm_num)      OVER (PARTITION BY `line`, `business_date`)              AS line_avg_ytm,
    SUM(CASE WHEN upper(`new_deal_flag`)='Y' THEN ABS(mtm_num) ELSE 0 END)
        OVER (PARTITION BY `line`, `business_date`)                           AS line_new_gross_mtm,
    SUM(CASE WHEN upper(`override`)='Y' THEN ABS(mtm_num) ELSE 0 END)
        OVER (PARTITION BY `line`, `business_date`)                           AS line_ovr_gross_mtm
  FROM base b
)
SELECT
  trim(upper(d.`line`))                                 AS Line,   -- conformed to the line fact's Line (trim(upper)) so Mosaic treats them as ONE attribute
  CASE WHEN trim(upper(d.`line`)) LIKE 'CP%' THEN 'CP'
       WHEN trim(upper(d.`line`)) LIKE 'HC%' THEN 'HC'
       ELSE 'Other' END                                 AS Line_Class,
  trim(upper(d.`line`))                                 AS Facility_Line_Code,   -- explicit alias of the facility/exposure line
  regexp_extract(d.`line`, '\\(([^)]+)\\)', 1)          AS Booking_Entity,
  d.`counterparty_long_name`                            AS Counterparty_Name,
  trim(upper(d.`counterparty_code`))                    AS Counterparty_Code,    -- conformed CP-attribution key -> clients_report.counterparty_code
  d.`deal_id`                                           AS Deal_Id,
  d.`name`                                              AS Deal_Name,
  d.`new_deal_flag`                                     AS New_Deal_Flag,
  d.`line_type`                                         AS Line_Type,
  d.`deal_type`                                         AS Asset_Class,
  -- <confirm> higher-level grouping. Mapped from the observed deal_type values.
  CASE
    WHEN d.`deal_type` IN ('Swap')                            THEN 'Rates'
    WHEN d.`deal_type` IN ('Cross Currency Swap','FX Forward')THEN 'FX'
    WHEN d.`deal_type` IN ('Equity Option')                  THEN 'Equity'
    WHEN d.`deal_type` IN ('Repurchase Agreement')           THEN 'Repo / SFT'
    WHEN d.`deal_type` IN ('Commodity Forward')              THEN 'Commodity'
    ELSE 'Other'
  END                                                   AS Asset_Class_Group,
  d.`isda_indicator`                                    AS ISDA_Indicator,
  d.`sic_industry`                                      AS Industry,
  d.`td_account_rating`                                 AS Counterparty_Rating,
  CAST(NULLIF(REPLACE(d.`deal_m2m`,    ',',''),'null') AS DOUBLE) AS MTM,
  d.`deal_m2m_currency`                                 AS MTM_Currency,
  CAST(NULLIF(REPLACE(d.`principal_1`, ',',''),'null') AS DOUBLE) AS Notional_1,
  d.`principal_1_currency`                              AS Notional_1_Currency,
  CAST(NULLIF(REPLACE(d.`principal_2`, ',',''),'null') AS DOUBLE) AS Notional_2,
  d.`principal_2_currency`                              AS Notional_2_Currency,
  d.`trade_date`                                        AS Trade_Date,
  d.`maturity_date`                                     AS Maturity_Date,
  d.ytm_num                                             AS Years_To_Maturity,

  -- (+) LENS 1 — maturity band (the runway as a pickable cut)
  CASE
    WHEN d.ytm_num IS NULL        THEN 'Unknown'
    WHEN d.ytm_num <= 0.25        THEN '<= 90d'
    WHEN d.ytm_num <= 1.0         THEN '90d - 1Yr'
    WHEN d.ytm_num <= 2.0         THEN '1 - 2Yr'
    WHEN d.ytm_num <= 5.0         THEN '2 - 5Yr'
    ELSE '5Yr +'
  END                                                   AS Maturity_Band,
  -- (+) runway colour band (relief / mid / structural)
  CASE
    WHEN d.ytm_num IS NULL        THEN 'Unknown'
    WHEN d.ytm_num <= 1.0         THEN 'Rolls off (<= 1Yr)'
    WHEN d.ytm_num <= 5.0         THEN 'Mid (1 - 5Yr)'
    ELSE 'Structural (> 5Yr)'
  END                                                   AS Tenor_Band,
  -- (+) LENS 2 — margin call (data is Daily / N/A -> daily-Y/N split)
  CASE WHEN upper(trim(d.`margin_call_frequency`)) = 'DAILY' THEN 'Daily'
       ELSE 'Not daily / N/A' END                       AS Margin_Call_Norm,
  -- (+) LENS 3 — new vs existing
  CASE WHEN upper(d.`new_deal_flag`) = 'Y' THEN 'New' ELSE 'Existing' END AS New_Deal_Norm,
  -- (+) FLAG — override audit
  CASE WHEN upper(d.`override`) = 'Y' THEN 'Overridden' ELSE 'Clean' END  AS Override_Norm,

  -- (+) LINE CONTEXT — joined from vw_ats_lines_detail on Line (was vw_pfe_line_detail/spine)
  ld.Stress_PFE                                         AS Line_Stress_PFE,     -- (~) new fact name (was Stress_PFE_MM)
  ld.Standard_PFE                                       AS Line_Standard_PFE,   -- (~) was Standard_PFE_MM
  ld.Limit_Amount                                       AS Line_Limit,
  ld.Utilization                                        AS Line_Utilization,    -- (~) was Stress_Credit_Utilization
  ld.Is_Breached                                        AS Is_Breached,         -- raw Y/N flag from the line fact
  ld.Worst_Scenario                                     AS Line_Worst_Scenario,
  ld.IM                                                 AS Line_IM,             -- (+) line collateral context
  ld.IA                                                 AS Line_IA,             -- (+)
  ld.Line_MTM_Base                                      AS Line_MTM_Base,       -- (+)
  ld.Line_MTM_Stress                                    AS Line_MTM_Stress,     -- (+)

  -- (+) DEAL BEHAVIOUR WITHIN ITS LINE
  ABS(d.mtm_num) / NULLIF(d.line_gross_mtm,0)            AS MTM_Share_Of_Line,
  -- NOTE: NOT rounded. With 100k+ deals per line each share is ~1e-6; ROUND(,4)
  -- would floor most to 0 and the shares would no longer sum to 1. Round at DISPLAY only.
  CASE WHEN ABS(d.mtm_num) / NULLIF(d.line_gross_mtm,0) >= 0.25 THEN 'Y' ELSE 'N' END AS Is_Dominant_Deal,
  CASE
    WHEN d.ytm_num IS NULL OR d.line_max_ytm IS NULL          THEN 'Unknown'
    WHEN d.ytm_num >= d.line_max_ytm                          THEN 'Longest'
    WHEN d.ytm_num >= d.line_avg_ytm                          THEN 'Long'
    WHEN d.ytm_num >= d.line_avg_ytm * 0.5                    THEN 'Mid'
    ELSE 'Short'
  END                                                    AS Maturity_Position,
  CASE WHEN d.ytm_num >= d.line_max_ytm THEN 'Y' ELSE 'N' END AS Is_Longest_In_Line,
  -- same sign as the line's net direction = adds to exposure; opposite = hedges it
  CASE
    WHEN d.mtm_num = 0 OR d.line_net_mtm = 0                  THEN 'Neutral'
    WHEN sign(d.mtm_num) = sign(d.line_net_mtm)              THEN 'Adds'
    ELSE 'Hedges'
  END                                                    AS Direction_Vs_Line,
  d.line_new_gross_mtm / NULLIF(d.line_gross_mtm,0)      AS Line_New_MTM_Share,
  d.line_ovr_gross_mtm / NULLIF(d.line_gross_mtm,0)      AS Line_Override_Share,

  d.`override`                                          AS Override,
  d.`override_date`                                     AS Override_Date,
  d.`oes_indicator`                                     AS OES_Indicator,
  d.`qa_number`                                         AS QA_Number,
  d.`im_model`                                          AS IM_Model,
  d.`margin_call_frequency`                             AS Margin_Call_Frequency,
  d.`agreement_group_code`                              AS Agreement_Group_Code,
  d.`source`                                            AS Source,
  to_date(regexp_replace(CAST(d.`business_date` AS STRING),'-',''),'yyyyMMdd') AS Business_Date
  -- (~) OUTPUT NORMALIZED: always a real DATE regardless of source datatype
  --     (string yyyymmdd / string yyyy-mm-dd / DATE all -> one canonical DATE).
FROM win d
LEFT JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_ats_lines_detail` ld   -- (~) was vw_pfe_line_detail
  ON ld.Line = trim(upper(d.`line`))   -- (~) conformed key: line fact's Line is trim(upper); match it here
  -- date condition intentionally omitted: the line fact is single-date and emits its
  -- own Business_Date; joining on the conformed Line alone is 1:1 (no fan-out).
;

-- =============================================================================
-- VALIDATION  (JOIN-RESOLUTION checks — run these; expected numbers in comments)
-- =============================================================================
-- VJ-CLASS  deal Line_Class split. EXPECT: CP 4,604 distinct lines · HC 712 distinct lines.
SELECT Line_Class, COUNT(*) AS deal_rows, COUNT(DISTINCT Line) AS distinct_lines
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_deals_by_line
GROUP BY Line_Class ORDER BY Line_Class;
-- VJ-DRILL  deal -> line fact on Line (exposure). EXPECT most deals match a line-fact row;
--   Line_Stress_PFE non-null. matched distinct lines ~5,315 (4,603 CP + 712 HC).
SELECT
  COUNT(DISTINCT d.Line)                                              AS deal_lines,
  COUNT(DISTINCT CASE WHEN d.Line_Stress_PFE IS NOT NULL THEN d.Line END) AS lines_matched_to_line_fact
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_deals_by_line d;
-- VJ-CPDIM  deal -> CP dimension on Counterparty_Code (attribution). EXPECT high match to clients_report.
SELECT
  COUNT(DISTINCT d.Counterparty_Code)                                AS deal_cp_codes,
  COUNT(DISTINCT c.counterparty_code)                                AS matched_in_clients
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_deals_by_line d
LEFT JOIN (SELECT DISTINCT trim(upper(counterparty_code)) AS counterparty_code
           FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_clients_report`) c
  ON d.Counterparty_Code = c.counterparty_code;
-- VJ-NODOUBLE  the CP codes HC deals attribute to must NOT be their own line-fact lines.
--   EXPECT 0 (proves CP+HC additive, no double-count at the deal-attribution level too).
SELECT COUNT(DISTINCT d.Counterparty_Code) AS hc_cp_codes_that_are_also_lines
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_deals_by_line d
JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_ats_lines_detail ld ON ld.Line = d.Counterparty_Code
WHERE d.Line_Class = 'HC';
--
-- ---- ORIGINAL VALIDATION / RUNBOOK TWINS (commented) -----------------------
-- V1  deal grain (one row per deal per date) — expect dupes = 0
-- SELECT Deal_Id, Business_Date, COUNT(*) c FROM ... GROUP BY 1,2 HAVING COUNT(*)>1;
--
-- V2  asset-class spread for one line
-- SELECT Asset_Class, COUNT(*) deals, SUM(MTM) mtm_usd FROM ...
-- WHERE Line='HC_(TDBK)_(LCH1)' GROUP BY Asset_Class ORDER BY deals DESC;
--
-- V3  FX caveat — notional currencies present (must NOT be summed)
-- SELECT Notional_1_Currency, COUNT(*) FROM ... GROUP BY 1 ORDER BY 2 DESC;
--
-- ---- LEVEL-3 EXPLORER LENS TWINS (folded-in buckets) -----------------------
-- L1  Maturity-band lens (whole book): MTM + count per band
-- SELECT Maturity_Band, COUNT(Deal_Id) deals, SUM(MTM) net_mtm, SUM(ABS(MTM)) gross_mtm
-- FROM ... WHERE Business_Date='20260430' GROUP BY Maturity_Band ORDER BY 1;
--
-- L2  Margin-call lens (unmargined concentration)
-- SELECT Margin_Call_Norm, COUNT(Deal_Id) deals, SUM(ABS(MTM)) gross_mtm
-- FROM ... WHERE Business_Date='20260430' GROUP BY Margin_Call_Norm;
--
-- L3  Runway for ONE line (tearsheet centerpiece)
-- SELECT Deal_Id, Asset_Class, Years_To_Maturity, MTM, Tenor_Band, Maturity_Date
-- FROM ... WHERE Line='HC_(TDBK)_(LCH1)' AND Business_Date='20260430'
-- ORDER BY Years_To_Maturity;
--
-- L4  Roll-off % + weighted maturity for a line (self-curing vs structural)
-- SELECT Line,
--   ROUND(100.0*SUM(CASE WHEN Years_To_Maturity<=1 THEN ABS(MTM) ELSE 0 END)
--             /NULLIF(SUM(ABS(MTM)),0),0)                              AS rolloff_1yr_pct,
--   ROUND(SUM(Years_To_Maturity*ABS(MTM))/NULLIF(SUM(ABS(MTM)),0),1)   AS wtd_maturity_yrs
-- FROM ... WHERE Line='HC_(TDBK)_(LCH1)' AND Business_Date='20260430' GROUP BY Line;
--
-- ---- DEAL-BEHAVIOUR TWINS --------------------------------------------------
-- B1  which deals dominate a line (concentration)
-- SELECT Deal_Id, Asset_Class, MTM, MTM_Share_Of_Line, Is_Dominant_Deal,
--        Maturity_Position, Direction_Vs_Line
-- FROM ... WHERE Line='HC_(TDBK)_(LCH1)' AND Business_Date='20260430'
-- ORDER BY MTM_Share_Of_Line DESC;
--
-- B2  shares must sum to ~1.0 per line (sanity on the window denominator)
-- SELECT Line, ROUND(SUM(MTM_Share_Of_Line),3) AS share_sum
-- FROM ... WHERE Business_Date='20260430' GROUP BY Line HAVING share_sum NOT BETWEEN 0.99 AND 1.01;
--   -- expect 0 rows (every line's deal shares sum to 1)
--
-- B3  hedge vs add split for a line
-- SELECT Direction_Vs_Line, COUNT(*) deals, SUM(ABS(MTM)) gross
-- FROM ... WHERE Line='HC_(TDBK)_(LCH1)' GROUP BY Direction_Vs_Line;
-- =============================================================================
