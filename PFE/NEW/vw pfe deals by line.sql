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
  Line                COMMENT 'The facility/exposure line the deal is booked to, and the key that ties deals back to the line and scenario views. For direct counterparty (CP) lines this equals the counterparty code; for house/agent (HC) lines it is a facility code whose trades post through to a counterparty. Deal grain is finer than line, so many deals share one Line.',
  Line_Class          COMMENT 'CP or HC — whether the line is a counterparty''s own line (direct) or a house/agent/fund facility whose trades post to a counterparty. Read from the Line code prefix; matches the line fact''s Line_Class.',
  Facility_Line_Code  COMMENT 'The same value as Line, named explicitly for the deal screen so it reads as ''the facility this deal sits on''. Use either name; they are identical.',
  Booking_Entity      COMMENT 'The TD booking entity (TDBK, TDSU, …), read from the first bracketed token of the Line code.',
  Counterparty_Name   COMMENT 'The counterparty''s name — the party the trade actually posts to. It follows the counterparty code (so it can differ between deals on the same HC facility line), and is NOT the facility''s own name.',
  Counterparty_Code   COMMENT 'The counterparty the trade posts to, always in CP format. This is the attribution key that links a deal to the client dimension (deal → counterparty), distinct from the facility Line the deal is booked under.',
  Deal_Id             COMMENT 'The unique deal identifier — the grain of this table (one row per deal).',
  Deal_Name           COMMENT 'The deal''s name/description.',
  New_Deal_Flag       COMMENT 'Whether the deal is new in this load (Y/N).',
  Line_Type           COMMENT 'The line type (e.g. C2C, CONT).',
  Asset_Class         COMMENT 'The asset/product type of the deal (from deal_type) — the specific product classifier (e.g. Swap, FX Forward, Repurchase Agreement). This is what the business calls "product type" (e.g. "trade notional by product type"); Asset_Class and product type are the same thing. See Asset_Class_Group for the higher-level rollup.',
  Asset_Class_Group   COMMENT 'A higher-level grouping of the asset class (Rates / FX / Equity / Repo-SFT / Commodity / Other) for easier slicing. (Grouping mapping pending final confirmation.)',
  ISDA_Indicator      COMMENT 'Whether the deal is under an ISDA agreement (Y/N).',
  Industry            COMMENT 'The counterparty''s detailed industry (SIC). Matches the line fact''s Industry — the same counterparty reference attribute — so deals and lines slice consistently by industry.',
  Counterparty_Rating COMMENT 'The counterparty''s own account rating. Deliberately kept separate from the line fact''s Line_Worst_Rating, which is the worst rating across all the line''s clients — a different concept and grain, so do not treat them as the same.',
  MTM                 COMMENT 'The deal''s mark-to-market value, in USD. Consistently USD, so it can be summed across deals.',
  MTM_Currency        COMMENT 'The currency of the deal''s mark-to-market (USD in this feed).',
  Notional_1          COMMENT 'The deal''s primary notional/principal. Multi-currency across deals, so do not sum without converting to a common currency first.',
  Notional_1_Currency COMMENT 'The currency of Notional_1.',
  Notional_2          COMMENT 'The deal''s secondary notional/principal (for two-legged trades). Same multi-currency caveat as Notional_1 — convert before summing.',
  Notional_2_Currency COMMENT 'The currency of Notional_2.',
  Trade_Date          COMMENT 'The date the deal was traded.',
  Maturity_Date       COMMENT 'The date the deal matures.',
  Years_To_Maturity   COMMENT 'Years remaining until the deal matures (numeric), used to derive the maturity bands.',
  -- (+) LEVEL-3 EXPLORER LENSES (folded in — derived buckets for the deal screen)
  Maturity_Band       COMMENT 'Groups each deal by remaining tenor: <=90d, 90d-1Yr, 1-2Yr, 2-5Yr, 5Yr+. A quick lens on how soon the book rolls off. Sort visuals by Maturity_Band_Order so the bands read in tenor order.',
  Maturity_Band_Order COMMENT 'A 1-to-6 sort key (1=<=90d … 5=5Yr+, 6=Unknown) so maturity bands display in tenor order rather than alphabetically.',
  Tenor_Band          COMMENT 'A simpler three-way runway view of tenor: Rolls off (<=1Yr) / Mid (1-5Yr) / Structural (>5Yr). A coarser companion to Maturity_Band.',
  Margin_Call_Norm    COMMENT 'A cleaned margin-call frequency for filtering: Daily vs Not daily, normalised from the raw frequency field.',
  New_Deal_Norm       COMMENT 'A cleaned new-vs-existing label (New / Existing) derived from the new-deal flag, for easy filtering.',
  Override_Norm       COMMENT 'A cleaned audit label (Overridden / Clean) derived from the override field, to spot manually-adjusted deals.',
  -- (+) LINE BREACH CONTEXT (from vw_line_stress_spine, joined on Line)
  -- ---------------------------------------------------------------------------
  -- LINE-LEVEL CONTEXT (Line_Stress_PFE, Line_Limit, Is_Breached, Line_IM/IA/MTM, etc.)
  -- REMOVED from this view: the deal fact no longer LEFT JOINs the line fact.
  -- These come through the MOSAIC MODEL instead — deal fact relates to
  -- vw_pfe_ats_lines_detail on Line (conformed key). Keeping the fact-to-fact join
  -- in SQL would hard-couple the views and duplicate line data on every deal row.
  -- The deal fact now exposes only its own deal attributes + the two conformed keys
  -- (Line for the exposure drill, Counterparty_Code for CP attribution).
  -- ---------------------------------------------------------------------------
  -- (+) DEAL BEHAVIOUR WITHIN ITS LINE (window functions over the line partition)
  MTM_Share_Of_Line   COMMENT 'This deal''s share of its line''s total mark-to-market activity — abs(deal MTM) divided by the sum of abs(MTM) across all the line''s deals. A concentration measure showing which deals drive the line; gross (absolute) basis is used so offsetting deals don''t distort it. Line-level denominator, so a deal''s shares across the line sum to 100%.',
  Is_Dominant_Deal    COMMENT 'Y when a single deal is 25% or more of its line''s gross mark-to-market — flags a line dominated by one large deal.',
  Maturity_Position   COMMENT 'Where this deal sits in its line''s tenor spread: Longest / Long / Mid / Short. Helps spot which deal forms the line''s long tail.',
  Is_Longest_In_Line  COMMENT 'Y when this deal has the longest remaining tenor on its line — the structural tail of the line.',
  Direction_Vs_Line   COMMENT 'Whether the deal adds to or hedges the line''s overall position — deal MTM sign compared with the line''s net MTM direction.',
  Line_New_MTM_Share  COMMENT 'The fraction of the line''s total (gross) mark-to-market that comes from deals newly added this load — flags lines whose exposure is being driven by new business. A line-level ratio, repeated on each of the line''s deal rows; do not sum it.',
  Line_Override_Share COMMENT 'The fraction of the line''s total (gross) mark-to-market that is under override — an audit signal for how much of the line is manually adjusted. Line-level, repeated per deal row; do not sum.',
  Override            COMMENT 'Whether the deal has been manually overridden (Y/N). Ties to the Override function in the requirements.',
  Override_Date       COMMENT 'The date the override was applied, if any.',
  OES_Indicator       COMMENT 'The OES indicator from source.',
  QA_Number           COMMENT 'The QA reference number from source.',
  IM_Model            COMMENT 'The initial-margin model associated with the deal.',
  Margin_Call_Frequency COMMENT 'The raw margin-call frequency from source (see Margin_Call_Norm for the cleaned filter version).',
  Agreement_Group_Code  COMMENT 'The agreement group code the deal belongs to.',
  Source              COMMENT 'The source feed the deal came from.',
  Non_Simulated_CONT  COMMENT 'The non-simulated contingent (CONT) amount for the deal — exposure not captured in the simulated figures. Reported in its own currency (see Non_Simulated_CONT_Currency); convert before summing across deals.',
  Non_Simulated_CONT_Currency COMMENT 'The currency of Non_Simulated_CONT.',
  C2C_Charge          COMMENT 'The counterparty-to-counterparty (C2C) charge on the deal. Reported in its own currency (see C2C_Charge_Cur); convert before summing across deals.',
  C2C_Charge_Cur      COMMENT 'The currency of C2C_Charge.',
  Product_Term_Exception COMMENT 'Any product-term exception recorded against the deal (source flag/description).',
  Value_Date          COMMENT 'The value date of the deal (when it settles/takes value), distinct from the trade date.',
  Line_Expiry         COMMENT 'The expiry date of the line the deal is booked to, as reported on the deal record.',
  Original_Location   COMMENT 'The original booking location recorded for the deal (source attribute).',
  Business_Date       COMMENT 'The as-of date of the data (stored as a yyyymmdd string in this view).'
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
    AND d.`line` IS NOT NULL AND trim(d.`line`) <> ''                     -- (~) exclude null/blank-line records: internal IM/cash stubs (e.g. USD_CASH deals in TCIM_IM_book, 50yr placeholder, no MTM, no line) — not counterparty deals-by-line. Removes the 6 'Other'-class rows.
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
  -- (+) numeric sort key so Maturity_Band displays in tenor order (not alphabetical)
  CASE
    WHEN d.ytm_num IS NULL        THEN 6
    WHEN d.ytm_num <= 0.25        THEN 1
    WHEN d.ytm_num <= 1.0         THEN 2
    WHEN d.ytm_num <= 2.0         THEN 3
    WHEN d.ytm_num <= 5.0         THEN 4
    ELSE 5
  END                                                   AS Maturity_Band_Order,
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

  -- (+) LINE CONTEXT — joined from vw_pfe_ats_lines_detail on Line (was vw_pfe_line_detail/spine)
  -- (line-level context columns removed — resolved via Mosaic relationship deal.Line -> line fact)

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
  try_cast(replace(CAST(d.`non_simulated_cont` AS STRING),',','') AS DOUBLE) AS Non_Simulated_CONT,
  d.`non_simulated_cont_currency`                       AS Non_Simulated_CONT_Currency,
  try_cast(replace(CAST(d.`c2c_charge` AS STRING),',','') AS DOUBLE) AS C2C_Charge,
  d.`c2c_charge_cur`                                     AS C2C_Charge_Cur,
  d.`product_term_exception`                            AS Product_Term_Exception,
  COALESCE(try_to_date(CAST(d.`value_date` AS STRING),'yyyyMMdd'),
           try_cast(CAST(d.`value_date` AS STRING) AS DATE))         AS Value_Date,
  COALESCE(try_to_date(CAST(d.`line_expiry` AS STRING),'yyyyMMdd'),
           try_cast(CAST(d.`line_expiry` AS STRING) AS DATE))        AS Line_Expiry,
  d.`original_location`                                  AS Original_Location,
  to_date(regexp_replace(CAST(d.`business_date` AS STRING),'-',''),'yyyyMMdd') AS Business_Date
  -- (~) OUTPUT NORMALIZED: always a real DATE regardless of source datatype
  --     (string yyyymmdd / string yyyy-mm-dd / DATE all -> one canonical DATE).
FROM win d
-- (~) LINE-FACT JOIN REMOVED: the deal fact no longer LEFT JOINs vw_pfe_ats_lines_detail.
--     Line context is resolved in the MOSAIC MODEL via the deal.Line -> line-fact.Line
--     relationship (conformed key). This keeps the views decoupled and avoids duplicating
--     line data on every deal row. The deal fact stands alone: deal attributes + the two
--     conformed keys (Line for exposure drill, Counterparty_Code for CP attribution).
;

-- =============================================================================
-- VALIDATION  (JOIN-RESOLUTION checks — run these; expected numbers in comments)
-- =============================================================================
-- VJ-CLASS  deal Line_Class split. EXPECT: CP 4,604 distinct lines · HC 712 distinct lines. NO 'Other' (null/blank-line IM/cash stubs now excluded).
SELECT Line_Class, COUNT(*) AS deal_rows, COUNT(DISTINCT Line) AS distinct_lines
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_deals_by_line
GROUP BY Line_Class ORDER BY Line_Class;
-- VJ-DRILL  deal -> line fact on Line (the Mosaic exposure-drill relationship).
--   Tests the join explicitly (the deal view no longer pre-joins the line fact).
--   EXPECT deal_lines ~5,318 · matched ~5,315 (4,603 CP + 712 HC).
SELECT
  COUNT(DISTINCT d.Line)                                              AS deal_lines,
  COUNT(DISTINCT ld.Line)                                             AS lines_matched_to_line_fact
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_deals_by_line d
LEFT JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail ld
  ON ld.Line = d.Line;
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
JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail ld ON ld.Line = d.Counterparty_Code
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
