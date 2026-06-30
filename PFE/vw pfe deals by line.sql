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
-- SOURCE : `xvala_core-raw`.pfe_deals_report  (note the hyphenated schema).
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

CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.`vw_pfe_deals_by_line` (
  Line                COMMENT 'Credit line / facility key. Drill key from the Level-2 facility/breach view.',
  Entity              COMMENT 'Parsed from the first parenthesised token of Line (e.g. CP_(TDBK)_(...) -> TDBK).',
  Counterparty_Name   COMMENT 'counterparty_long_name.',
  Counterparty_Code   COMMENT 'counterparty_code.',
  Deal_Id             COMMENT 'deal_id — deal grain key.',
  Deal_Name           COMMENT 'name.',
  New_Deal_Flag       COMMENT 'new_deal_flag (Y/N) — new this load.',
  Line_Type           COMMENT 'line_type (C2C, CONT, ...).',
  Asset_Class         COMMENT 'deal_type as-is (the asset/product classifier).',
  Asset_Class_Group   COMMENT '<confirm> higher-level grouping of deal_type (Rates/FX/Equity/Repo-SFT/Commodity/Other).',
  ISDA_Indicator      COMMENT 'isda_indicator (Y/N).',
  Industry            COMMENT 'sic_industry (granular, as on deals).',
  Rating              COMMENT 'td_account_rating (deal-level account rating).',
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
    -- numeric ytm computed once so the band CASEs below can reuse it
    CAST(NULLIF(REPLACE(d.`years_to_maturity`,',',''),'null') AS DOUBLE) AS ytm_num
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.`pfe_deals_report` d
  WHERE upper(d.`no_line_indicator`) = 'FALSE'            -- population: real lines only
)
SELECT
  d.`line`                                              AS Line,
  regexp_extract(d.`line`, '\\(([^)]+)\\)', 1)          AS Entity,
  d.`counterparty_long_name`                            AS Counterparty_Name,
  d.`counterparty_code`                                 AS Counterparty_Code,
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
  d.`td_account_rating`                                 AS Rating,
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

  d.`override`                                          AS Override,
  d.`override_date`                                     AS Override_Date,
  d.`oes_indicator`                                     AS OES_Indicator,
  d.`qa_number`                                         AS QA_Number,
  d.`im_model`                                          AS IM_Model,
  d.`margin_call_frequency`                             AS Margin_Call_Frequency,
  d.`agreement_group_code`                              AS Agreement_Group_Code,
  d.`source`                                            AS Source,
  d.`business_date`                                     AS Business_Date
FROM base d
;

-- =============================================================================
-- VALIDATION
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
-- =============================================================================
