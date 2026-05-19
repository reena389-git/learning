-- ================================================================
-- CCR POC — TRADE DATA  (exposure-reconciling)
-- Loads star_dim_trade only. Touches no other table.
-- Each VM-agreement trade carries trade_exposure_contribution; per
-- agreement these sum EXACTLY to direct exposure on 2026-03-31,
-- so the direct-exposure drill into trades reconciles to the headline.
-- ================================================================

-- NOTE: star_dim_trade needs one extra column for the reconciling
-- contribution. Run this ALTER once (safe if column already exists):
ALTER TABLE `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_trade
  ADD COLUMNS (trade_exposure_contribution DECIMAL(18,2)
    COMMENT 'Share of counterparty direct exposure (as-of 2026-03-31). Sums to base_total_exposure per agreement.');

TRUNCATE TABLE `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_trade;
INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_trade
  (trade_key, system_trade_id, agreement_id, source_system,
   product_type_isda, system_product_type, effective_date, maturity_date,
   im_model_td, im_model_cp, im_jurisdiction_td, im_jurisdiction_cp,
   is_isda_trade, is_discarded, discard_reason, valuation_amount,
   valuation_currency, trade_exposure_contribution)
VALUES
  (5001, 'SYS-001-01', 'AGR-001', 'SUMMIT', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2022-03-04', '2027-12-04', 'GRID', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, 1292328.0, 'CAD', 4248122.6),
  (5002, 'SYS-001-02', 'AGR-001', 'SUMMIT', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-03-06', '2032-09-02', 'SIMM', 'GRID', 'OSFI', 'OSFI', true, false, NULL, 4804317.4, 'CAD', 4440452.89),
  (5003, 'SYS-001-03', 'AGR-001', 'MUREX', 'ForeignExchange:FXOption', 'FX_OPTION', '2022-07-01', '2027-06-07', 'SCHEDULE', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, -5712370.8, 'CAD', 4872434.23),
  (5004, 'SYS-001-04', 'AGR-001', 'MUREX', 'InterestRate:IRSwap', 'IRS_VANILLA', '2023-08-03', '2033-12-15', 'SIMM', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, 5670605.9, 'CAD', 3310544.78),
  (5005, 'SYS-001-05', 'AGR-001', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2022-10-25', '2027-04-12', 'SIMM', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, 8123729.48, 'CAD', 4084499.59),
  (5006, 'SYS-001-06', 'AGR-001', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2022-12-20', '2024-01-02', 'SIMM', 'GRID', 'OSFI', 'OSFI', true, false, NULL, 3446716.65, 'CAD', 4643945.91),
  (5007, 'SYS-002-01', 'AGR-002', 'SUMMIT', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-03-13', '2029-02-06', 'SCHEDULE', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, -2206722.19, 'USD', NULL),
  (5008, 'SYS-002-02', 'AGR-002', 'CALYPSO', 'InterestRate:IRSwap', 'IRS_VANILLA', '2024-09-25', '2031-12-01', 'SIMM', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, 11306544.43, 'USD', NULL),
  (5009, 'SYS-002-03', 'AGR-002', 'SUMMIT', 'InterestRate:IRSwap', 'IRS_VANILLA', '2023-04-07', '2028-07-19', 'GRID', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, 2058993.05, 'USD', NULL),
  (5010, 'SYS-002-04', 'AGR-002', 'SUMMIT', 'InterestRate:IRSwap', 'IRS_VANILLA', '2024-12-17', '2031-03-24', 'SCHEDULE', 'GRID', 'OSFI', 'OSFI', true, true, 'Trade matured', 3660979.44, 'USD', NULL),
  (5011, 'SYS-003-01', 'AGR-003', 'SUMMIT', 'InterestRate:IRSwap', 'IRS_VANILLA', '2023-04-03', '2030-01-10', 'SCHEDULE', 'SCHEDULE', 'EMIR', 'EMIR', true, false, NULL, 54064.63, 'USD', 2656445.22),
  (5012, 'SYS-003-02', 'AGR-003', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2024-08-15', '2031-09-17', 'SIMM', 'SCHEDULE', 'EMIR', 'EMIR', true, false, NULL, 8409696.48, 'USD', 2911413.27),
  (5013, 'SYS-003-03', 'AGR-003', 'MUREX', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-11-10', '2026-09-24', 'GRID', 'SCHEDULE', 'EMIR', 'EMIR', true, false, NULL, -1454901.12, 'USD', 3098782.32),
  (5014, 'SYS-003-04', 'AGR-003', 'CALYPSO', 'InterestRate:IRSwap', 'IRS_VANILLA', '2024-02-08', '2031-05-03', 'SCHEDULE', 'GRID', 'EMIR', 'EMIR', true, false, NULL, 11986179.93, 'USD', 1981753.7),
  (5015, 'SYS-003-05', 'AGR-003', 'CALYPSO', 'Equity:EquityOption', 'EQ_OPTION', '2024-07-23', '2031-09-26', 'SIMM', 'SIMM', 'EMIR', 'EMIR', true, false, NULL, 4294322.16, 'USD', 3411765.03),
  (5016, 'SYS-003-06', 'AGR-003', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-04-26', '2030-05-07', 'SIMM', 'GRID', 'EMIR', 'EMIR', true, false, NULL, 3581778.2, 'USD', 2639840.46),
  (5017, 'SYS-004-01', 'AGR-004', 'CALYPSO', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-01-02', '2024-09-11', 'SCHEDULE', 'GRID', 'EMIR', 'EMIR', true, false, NULL, 11148093.7, 'USD', NULL),
  (5018, 'SYS-004-02', 'AGR-004', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2022-04-07', '2025-04-12', 'SCHEDULE', 'GRID', 'EMIR', 'EMIR', true, false, NULL, -4469045.68, 'USD', NULL),
  (5019, 'SYS-004-03', 'AGR-004', 'CALYPSO', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-03-18', '2029-11-28', 'GRID', 'SIMM', 'EMIR', 'EMIR', true, false, NULL, 6562498.66, 'USD', NULL),
  (5020, 'SYS-004-04', 'AGR-004', 'SUMMIT', 'InterestRate:IRSwap', 'IRS_VANILLA', '2023-10-02', '2025-11-07', 'SCHEDULE', 'SCHEDULE', 'EMIR', 'EMIR', true, false, NULL, -5155880.88, 'USD', NULL),
  (5021, 'SYS-005-01', 'AGR-005', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2022-05-21', '2025-02-08', 'GRID', 'SCHEDULE', 'SEC', 'CFTC', true, false, NULL, 5155336.56, 'USD', 13396980.3),
  (5022, 'SYS-005-02', 'AGR-005', 'SUMMIT', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2023-05-22', '2025-01-06', 'SCHEDULE', 'SCHEDULE', 'SEC', 'CFTC', true, false, NULL, 10071884.18, 'USD', 17657092.5),
  (5023, 'SYS-005-03', 'AGR-005', 'MUREX', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-09-04', '2032-10-05', 'SCHEDULE', 'GRID', 'SEC', 'CFTC', true, false, NULL, -215969.54, 'USD', 10445927.2),
  (5024, 'SYS-006-01', 'AGR-006', 'MUREX', 'ForeignExchange:FXOption', 'FX_OPTION', '2024-10-25', '2026-11-03', 'SIMM', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, 575409.29, 'CAD', 5068626.86),
  (5025, 'SYS-006-02', 'AGR-006', 'MUREX', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-12-25', '2028-12-12', 'GRID', 'GRID', 'OSFI', 'OSFI', true, false, NULL, -72462.66, 'CAD', 7436683.2),
  (5026, 'SYS-006-03', 'AGR-006', 'MUREX', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-11-07', '2030-10-15', 'GRID', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, -5041489.02, 'CAD', 4611266.38),
  (5027, 'SYS-006-04', 'AGR-006', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-12-08', '2025-07-08', 'GRID', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, 8673068.23, 'CAD', 2814452.12),
  (5028, 'SYS-006-05', 'AGR-006', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-01-18', '2025-12-27', 'SIMM', 'GRID', 'OSFI', 'OSFI', true, false, NULL, 7349614.31, 'CAD', 2468971.44),
  (5029, 'SYS-007-01', 'AGR-007', 'MUREX', 'InterestRate:IRSwap', 'IRS_VANILLA', '2023-11-18', '2030-05-12', 'SCHEDULE', 'GRID', 'EMIR', 'EMIR', true, false, NULL, -4243994.5, 'USD', 2958451.02),
  (5030, 'SYS-007-02', 'AGR-007', 'MUREX', 'InterestRate:IRSwap', 'IRS_VANILLA', '2023-04-11', '2033-07-04', 'SCHEDULE', 'GRID', 'EMIR', 'EMIR', true, false, NULL, 10870951.49, 'USD', 6083075.31),
  (5031, 'SYS-007-03', 'AGR-007', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2022-11-01', '2024-12-12', 'GRID', 'SIMM', 'EMIR', 'EMIR', true, false, NULL, 6966937.91, 'USD', 3758473.67),
  (5032, 'SYS-008-01', 'AGR-008', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2024-09-25', '2034-10-28', 'GRID', 'SCHEDULE', 'SEC', 'CFTC', true, false, NULL, -2419810.08, 'USD', 2556611.27),
  (5033, 'SYS-008-02', 'AGR-008', 'MUREX', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2023-10-09', '2028-09-04', 'GRID', 'SCHEDULE', 'SEC', 'CFTC', true, true, 'Trade matured', 9663859.14, 'USD', 3132961.35),
  (5034, 'SYS-008-03', 'AGR-008', 'MUREX', 'InterestRate:IRSwap', 'IRS_VANILLA', '2024-03-17', '2029-09-01', 'SCHEDULE', 'SCHEDULE', 'SEC', 'CFTC', true, false, NULL, 6255253.26, 'USD', 3261390.25),
  (5035, 'SYS-008-04', 'AGR-008', 'MUREX', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2022-07-21', '2027-09-04', 'GRID', 'GRID', 'SEC', 'CFTC', true, false, NULL, 11515970.79, 'USD', 4249037.13),
  (5036, 'SYS-009-01', 'AGR-009', 'MUREX', 'InterestRate:IRSwap', 'IRS_VANILLA', '2023-10-09', '2033-12-20', 'SIMM', 'SCHEDULE', 'EMIR', 'EMIR', true, false, NULL, -1024829.53, 'EUR', 1172260.81),
  (5037, 'SYS-009-02', 'AGR-009', 'CALYPSO', 'Equity:EquitySwap', 'EQ_SWAP', '2024-05-24', '2034-05-23', 'GRID', 'SCHEDULE', 'EMIR', 'EMIR', true, false, NULL, 3355078.69, 'EUR', 3202626.57),
  (5038, 'SYS-009-03', 'AGR-009', 'MUREX', 'Equity:EquitySwap', 'EQ_SWAP', '2022-01-08', '2025-08-20', 'GRID', 'SIMM', 'EMIR', 'EMIR', true, false, NULL, 4736265.56, 'EUR', 4422236.46),
  (5039, 'SYS-009-04', 'AGR-009', 'SUMMIT', 'Equity:EquitySwap', 'EQ_SWAP', '2023-08-13', '2025-01-28', 'SCHEDULE', 'GRID', 'EMIR', 'EMIR', true, false, NULL, 2028070.78, 'EUR', 1334013.55),
  (5040, 'SYS-009-05', 'AGR-009', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2024-11-08', '2026-12-20', 'SCHEDULE', 'GRID', 'EMIR', 'EMIR', true, false, NULL, 1493299.47, 'EUR', 1168862.61),
  (5041, 'SYS-010-01', 'AGR-010', 'MUREX', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-10-13', '2029-08-24', 'SCHEDULE', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, 6281707.97, 'CAD', 2920912.6),
  (5042, 'SYS-010-02', 'AGR-010', 'MUREX', 'InterestRate:IRSwap', 'IRS_VANILLA', '2024-12-12', '2031-11-19', 'SIMM', 'GRID', 'OSFI', 'OSFI', true, false, NULL, 7147215.54, 'CAD', 1640116.84),
  (5043, 'SYS-010-03', 'AGR-010', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-07-02', '2030-11-17', 'SCHEDULE', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, 8932249.65, 'CAD', 1236106.33),
  (5044, 'SYS-010-04', 'AGR-010', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2022-07-06', '2025-11-22', 'SIMM', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, 6032776.9, 'CAD', 2582256.19),
  (5045, 'SYS-010-05', 'AGR-010', 'MUREX', 'ForeignExchange:FXOption', 'FX_OPTION', '2022-05-16', '2032-10-11', 'GRID', 'GRID', 'OSFI', 'OSFI', true, false, NULL, -1487253.58, 'CAD', 3105780.93),
  (5046, 'SYS-010-06', 'AGR-010', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2022-12-21', '2027-11-21', 'SIMM', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, -4220650.85, 'CAD', 2114827.11),
  (5047, 'SYS-011-01', 'AGR-011', 'SUMMIT', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-10-01', '2029-07-24', 'GRID', 'SIMM', 'SEC', 'CFTC', true, false, NULL, -177109.39, 'USD', 3715049.2),
  (5048, 'SYS-011-02', 'AGR-011', 'SUMMIT', 'InterestRate:IRSwap', 'IRS_VANILLA', '2023-11-01', '2025-08-18', 'SIMM', 'SIMM', 'SEC', 'CFTC', true, false, NULL, 6317554.25, 'USD', 6253081.24),
  (5049, 'SYS-011-03', 'AGR-011', 'MUREX', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2024-11-09', '2026-01-26', 'GRID', 'SIMM', 'SEC', 'CFTC', true, false, NULL, 10121831.59, 'USD', 2234830.37),
  (5050, 'SYS-011-04', 'AGR-011', 'MUREX', 'Equity:TotalReturnSwap', 'TRS_EQUITY', '2024-02-24', '2027-05-01', 'SIMM', 'GRID', 'SEC', 'CFTC', true, false, NULL, 10742156.64, 'USD', 6715352.14),
  (5051, 'SYS-011-05', 'AGR-011', 'SUMMIT', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2022-12-13', '2024-04-26', 'SCHEDULE', 'SCHEDULE', 'SEC', 'CFTC', true, false, NULL, 6591535.29, 'USD', 4857869.63),
  (5052, 'SYS-011-06', 'AGR-011', 'MUREX', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2024-05-19', '2027-02-23', 'GRID', 'SIMM', 'SEC', 'CFTC', true, false, NULL, 4965566.41, 'USD', 3023817.42),
  (5053, 'SYS-012-01', 'AGR-012', 'SUMMIT', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2022-04-03', '2027-01-01', 'SCHEDULE', 'GRID', 'OSFI', 'OSFI', true, false, NULL, 10728024.41, 'CAD', 1610275.94),
  (5054, 'SYS-012-02', 'AGR-012', 'MUREX', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2022-01-04', '2024-09-23', 'SIMM', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, -3315934.95, 'CAD', 3714251.3),
  (5055, 'SYS-012-03', 'AGR-012', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2024-03-01', '2031-03-14', 'SCHEDULE', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, 6039762.63, 'CAD', 1317436.46),
  (5056, 'SYS-012-04', 'AGR-012', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-03-06', '2025-07-13', 'SCHEDULE', 'GRID', 'OSFI', 'OSFI', true, false, NULL, -3634929.06, 'CAD', 1137912.25),
  (5057, 'SYS-012-05', 'AGR-012', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2024-01-17', '2029-12-10', 'SIMM', 'SCHEDULE', 'OSFI', 'OSFI', true, true, 'Trade matured', 7224827.06, 'CAD', 3469454.51),
  (5058, 'SYS-012-06', 'AGR-012', 'SUMMIT', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2022-08-27', '2032-11-08', 'SIMM', 'GRID', 'OSFI', 'OSFI', true, false, NULL, 2894650.63, 'CAD', 3550669.54);

-- ── VERIFY: trade contributions reconcile to direct exposure ──
SELECT t.agreement_id,
       ROUND(SUM(t.trade_exposure_contribution),2) AS trades_sum,
       f.base_total_exposure AS direct_exposure_0331
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_trade t
JOIN `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_collateral_exposure f
  ON f.agreement_id = t.agreement_id AND f.as_of_date = '2026-03-31'
WHERE t.trade_exposure_contribution IS NOT NULL
GROUP BY t.agreement_id, f.base_total_exposure
ORDER BY t.agreement_id;