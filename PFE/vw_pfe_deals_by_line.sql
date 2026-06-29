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
  CAST(NULLIF(REPLACE(d.`years_to_maturity`,',',''),'null') AS DOUBLE) AS Years_To_Maturity,
  d.`override`                                          AS Override,
  d.`override_date`                                     AS Override_Date,
  d.`oes_indicator`                                     AS OES_Indicator,
  d.`qa_number`                                         AS QA_Number,
  d.`im_model`                                          AS IM_Model,
  d.`margin_call_frequency`                             AS Margin_Call_Frequency,
  d.`agreement_group_code`                              AS Agreement_Group_Code,
  d.`source`                                            AS Source,
  d.`business_date`                                     AS Business_Date
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.`pfe_deals_report` d
WHERE upper(d.`no_line_indicator`) = 'FALSE'            -- population: real lines only
;

-- =============================================================================
-- VALIDATION
-- V1  deal grain (one row per deal per date) — expect dupes = 0
-- SELECT Deal_Id, Business_Date, COUNT(*) c
-- FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.vw_pfe_deals_by_line
-- GROUP BY Deal_Id, Business_Date HAVING COUNT(*) > 1;
--
-- V2  asset-class spread for one line (the Level-3 breakdown)
-- SELECT Asset_Class, COUNT(*) AS deals, SUM(MTM) AS mtm_usd
-- FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.vw_pfe_deals_by_line
-- WHERE Line = 'HC_(TDBK)_(LCH1)'
-- GROUP BY Asset_Class ORDER BY deals DESC;
--
-- V3  FX caveat check — notional currencies present (must NOT be summed blindly)
-- SELECT Notional_1_Currency, COUNT(*) FROM ... GROUP BY 1 ORDER BY 2 DESC;
-- =============================================================================
