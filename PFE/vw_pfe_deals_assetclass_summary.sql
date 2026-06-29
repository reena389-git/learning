-- =============================================================================
-- vw_pfe_deals_assetclass_summary.sql   (LEVEL 3 — asset-class breakdown metric)
-- Databricks SQL.  Catalog: d4001-centralus-tdvip-creditrisk
--
-- PURPOSE: the asset-class summary the Individual Line Tab shows — for each line,
--   the deal COUNT and SUMMED MTM (USD) per asset class. Built on
--   vw_pfe_deals_by_line so it inherits the population filter + parsing.
--
-- GRAIN  : line x asset_class x business_date.
-- MEASURES:
--   deal_count   = COUNT(deal_id)                 (always valid)
--   mtm_usd      = SUM(MTM)                        (deal_m2m is USD -> additive)
--   mtm_abs_usd  = SUM(ABS(MTM))                   (gross, for "size" without netting)
--   new_deals    = COUNT WHERE new_deal_flag='Y'
--   override_deals = COUNT WHERE override='Y'
--   notional is NOT summed here (multi-currency). Per-deal notional stays in
--   vw_pfe_deals_by_line; if a single-currency line, sum there with a currency filter.
-- =============================================================================

CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.`vw_pfe_deals_assetclass_summary` (
  Line              COMMENT 'Credit line / facility key (drill key).',
  Entity            COMMENT 'Parsed entity from Line.',
  Counterparty_Name COMMENT 'counterparty_long_name.',
  Asset_Class       COMMENT 'deal_type as-is.',
  Asset_Class_Group COMMENT '<confirm> higher-level grouping.',
  Deal_Count        COMMENT 'COUNT of deals in this line x asset_class.',
  New_Deal_Count    COMMENT 'COUNT where new_deal_flag = Y.',
  Override_Count    COMMENT 'COUNT where override = Y.',
  MTM_USD           COMMENT 'SUM(MTM) — net, USD, additive.',
  MTM_Abs_USD       COMMENT 'SUM(ABS(MTM)) — gross size without netting.',
  Business_Date     COMMENT 'business_date.'
)
AS
SELECT
  Line,
  MAX(Entity)                                              AS Entity,
  MAX(Counterparty_Name)                                   AS Counterparty_Name,
  Asset_Class,
  MAX(Asset_Class_Group)                                   AS Asset_Class_Group,
  COUNT(Deal_Id)                                           AS Deal_Count,
  SUM(CASE WHEN New_Deal_Flag = 'Y' THEN 1 ELSE 0 END)     AS New_Deal_Count,
  SUM(CASE WHEN Override      = 'Y' THEN 1 ELSE 0 END)     AS Override_Count,
  SUM(MTM)                                                 AS MTM_USD,
  SUM(ABS(MTM))                                            AS MTM_Abs_USD,
  Business_Date
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.`vw_pfe_deals_by_line`
GROUP BY Line, Asset_Class, Business_Date
;

-- =============================================================================
-- VALIDATION
-- V1  one line's asset-class profile (the Level-3 bar chart)
-- SELECT Asset_Class, Deal_Count, MTM_USD, MTM_Abs_USD
-- FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.vw_pfe_deals_assetclass_summary
-- WHERE Line = 'HC_(TDBK)_(LCH1)'
-- ORDER BY Deal_Count DESC;
--
-- V2  portfolio-wide asset-class mix (deal counts by group)
-- SELECT Asset_Class_Group, SUM(Deal_Count) AS deals, SUM(MTM_USD) AS net_mtm_usd
-- FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.vw_pfe_deals_assetclass_summary
-- GROUP BY Asset_Class_Group ORDER BY deals DESC;
-- =============================================================================
