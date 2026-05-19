-- ================================================================
-- CCR POC — SYNTHETIC DATA v2  (aligned to real star_dim_legal_entity)
-- Run AFTER synthetic_load.sql.  Replaces synthetic_extension_load.sql.
-- Ultimate parent now lives IN star_dim_legal_entity (self-referencing).
-- ================================================================

-- ── 1. star_dim_legal_entity ────────────────────────────────────
-- Self-referencing: operating entities point up to their ultimate parent.
-- is_ultimate_parent = true marks the top of each group.
TRUNCATE TABLE `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_legal_entity;
INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_legal_entity
  (lei_code, ultimate_parent_lei, ultimate_parent_name, legal_entity_name,
   counterparty_code, entity_type, incorporation_country,
   regulatory_jurisdiction, is_ultimate_parent)
VALUES
  ('LEI-BC-001', 'LEI-BC-000', 'Bank of China Limited', 'Bank of China Canada', 'BCCU', 'Operating Subsidiary', 'CA', 'OSFI', false),
  ('LEI-BC-000', 'LEI-BC-000', 'Bank of China Limited', 'Bank of China Limited', 'BCCU', 'Ultimate Parent', 'CN', 'CBIRC', true),
  ('LEI-IN-001', 'LEI-IN-000', 'ING Groep NV', 'ING Bank NV London Branch', 'INBL', 'Branch', 'GB', 'EMIR', false),
  ('LEI-IN-000', 'LEI-IN-000', 'ING Groep NV', 'ING Groep NV', 'INBL', 'Ultimate Parent', 'NL', 'EMIR', true),
  ('LEI-GS-001', 'LEI-GS-000', 'The Goldman Sachs Group Inc', 'Goldman Sachs & Co LLC', 'GSCO', 'Operating Subsidiary', 'US', 'SEC', false),
  ('LEI-GS-000', 'LEI-GS-000', 'The Goldman Sachs Group Inc', 'The Goldman Sachs Group Inc', 'GSCO', 'Ultimate Parent', 'US', 'SEC', true),
  ('LEI-JP-001', 'LEI-JP-000', 'JPMorgan Chase & Co', 'JPMorgan Chase Bank NA', 'JPMC', 'Operating Subsidiary', 'US', 'OSFI', false),
  ('LEI-JP-000', 'LEI-JP-000', 'JPMorgan Chase & Co', 'JPMorgan Chase & Co', 'JPMC', 'Ultimate Parent', 'US', 'SEC', true),
  ('LEI-HS-001', 'LEI-HS-000', 'HSBC Holdings PLC', 'HSBC Bank PLC', 'HSBC', 'Operating Subsidiary', 'GB', 'EMIR', false),
  ('LEI-HS-000', 'LEI-HS-000', 'HSBC Holdings PLC', 'HSBC Holdings PLC', 'HSBC', 'Ultimate Parent', 'GB', 'EMIR', true),
  ('LEI-CI-001', 'LEI-CI-000', 'Citigroup Inc', 'Citibank NA', 'CITB', 'Operating Subsidiary', 'US', 'SEC', false),
  ('LEI-CI-000', 'LEI-CI-000', 'Citigroup Inc', 'Citigroup Inc', 'CITB', 'Ultimate Parent', 'US', 'SEC', true),
  ('LEI-BN-001', 'LEI-BN-000', 'BNP Paribas SA', 'BNP Paribas SA London Branch', 'BNPP', 'Branch', 'GB', 'EMIR', false),
  ('LEI-BN-000', 'LEI-BN-000', 'BNP Paribas SA', 'BNP Paribas SA', 'BNPP', 'Ultimate Parent', 'FR', 'EMIR', true),
  ('LEI-MU-001', 'LEI-MU-000', 'Mitsubishi UFJ Financial Group', 'MUFG Bank Ltd', 'MUFG', 'Operating Subsidiary', 'JP', 'OSFI', false),
  ('LEI-MU-000', 'LEI-MU-000', 'Mitsubishi UFJ Financial Group', 'Mitsubishi UFJ Financial Group', 'MUFG', 'Ultimate Parent', 'JP', 'JFSA', true),
  ('LEI-MS-001', 'LEI-MS-000', 'Morgan Stanley', 'Morgan Stanley Smith Barney LLC', 'MSSF', 'Operating Subsidiary', 'US', 'SEC', false),
  ('LEI-MS-000', 'LEI-MS-000', 'Morgan Stanley', 'Morgan Stanley', 'MSSF', 'Ultimate Parent', 'US', 'SEC', true),
  ('LEI-RB-001', 'LEI-RB-001', 'Royal Bank of Canada', 'Royal Bank of Canada', 'RBCS', 'Ultimate Parent', 'CA', 'OSFI', true);

-- ── 2. star_dim_trade ───────────────────────────────────────────
TRUNCATE TABLE `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_trade;
INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_trade
  (trade_key, system_trade_id, agreement_id, source_system,
   product_type_isda, system_product_type, effective_date, maturity_date,
   im_model_td, im_model_cp, im_jurisdiction_td, im_jurisdiction_cp,
   is_isda_trade, is_discarded, discard_reason, valuation_amount, valuation_currency)
VALUES
  (5001, 'SYS-001-01', 'AGR-001', 'SUMMIT', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2022-12-28', '2029-12-26', 'GRID', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, 4300728.76, 'CAD'),
  (5002, 'SYS-001-02', 'AGR-001', 'CALYPSO', 'InterestRate:IRSwap', 'IRS_VANILLA', '2023-06-26', '2033-03-04', 'SCHEDULE', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, 12242657.07, 'CAD'),
  (5003, 'SYS-001-03', 'AGR-001', 'CALYPSO', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-11-12', '2032-03-06', 'SCHEDULE', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, 9293756.92, 'CAD'),
  (5004, 'SYS-001-04', 'AGR-001', 'MUREX', 'ForeignExchange:FXOption', 'FX_OPTION', '2022-02-13', '2027-01-12', 'SIMM', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, 4781677.26, 'CAD'),
  (5005, 'SYS-001-05', 'AGR-001', 'CALYPSO', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2022-08-01', '2025-11-26', 'SIMM', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, -1657293.16, 'CAD'),
  (5006, 'SYS-001-06', 'AGR-001', 'SUMMIT', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-01-18', '2032-01-04', 'SCHEDULE', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, 3070804.6, 'CAD'),
  (5007, 'SYS-002-01', 'AGR-002', 'MUREX', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-04-06', '2029-04-03', 'GRID', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, 6362737.04, 'USD'),
  (5008, 'SYS-002-02', 'AGR-002', 'MUREX', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-03-17', '2026-04-28', 'SCHEDULE', 'GRID', 'OSFI', 'OSFI', true, false, NULL, 10867159.94, 'USD'),
  (5009, 'SYS-002-03', 'AGR-002', 'SUMMIT', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-06-07', '2025-08-20', 'GRID', 'SIMM', 'OSFI', 'OSFI', true, false, NULL, -4203320.83, 'USD'),
  (5010, 'SYS-003-01', 'AGR-003', 'CALYPSO', 'Equity:EquityOption', 'EQ_OPTION', '2024-07-24', '2031-09-05', 'SCHEDULE', 'SCHEDULE', 'EMIR', 'EMIR', true, true, 'Novated out', 3624993.88, 'USD'),
  (5011, 'SYS-003-02', 'AGR-003', 'MUREX', 'Equity:EquityOption', 'EQ_OPTION', '2024-05-12', '2027-04-23', 'GRID', 'SCHEDULE', 'EMIR', 'EMIR', true, false, NULL, 9232012.56, 'USD'),
  (5012, 'SYS-003-03', 'AGR-003', 'CALYPSO', 'Equity:EquityOption', 'EQ_OPTION', '2023-09-16', '2030-08-22', 'GRID', 'GRID', 'EMIR', 'EMIR', true, false, NULL, 8040265.72, 'USD'),
  (5013, 'SYS-003-04', 'AGR-003', 'CALYPSO', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-11-16', '2024-11-03', 'SCHEDULE', 'GRID', 'EMIR', 'EMIR', true, false, NULL, 1455862.52, 'USD'),
  (5014, 'SYS-003-05', 'AGR-003', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2024-05-07', '2034-05-20', 'SIMM', 'SCHEDULE', 'EMIR', 'EMIR', true, true, 'Novated out', 3817093.38, 'USD'),
  (5015, 'SYS-003-06', 'AGR-003', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2024-01-04', '2034-12-03', 'SIMM', 'GRID', 'EMIR', 'EMIR', true, false, NULL, -7355977.35, 'USD'),
  (5016, 'SYS-004-01', 'AGR-004', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-07-23', '2028-09-26', 'SIMM', 'SIMM', 'EMIR', 'EMIR', true, false, NULL, -2107218.25, 'USD'),
  (5017, 'SYS-004-02', 'AGR-004', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2024-04-26', '2034-05-07', 'SIMM', 'GRID', 'EMIR', 'EMIR', true, false, NULL, 12891967.56, 'USD'),
  (5018, 'SYS-004-03', 'AGR-004', 'MUREX', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-01-12', '2027-05-07', 'SCHEDULE', 'SIMM', 'EMIR', 'EMIR', true, false, NULL, -7689918.94, 'USD'),
  (5019, 'SYS-004-04', 'AGR-004', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2024-02-26', '2031-11-08', 'SIMM', 'SIMM', 'EMIR', 'EMIR', true, false, NULL, -588638.58, 'USD'),
  (5020, 'SYS-004-05', 'AGR-004', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2022-06-18', '2029-03-18', 'SCHEDULE', 'GRID', 'EMIR', 'EMIR', true, false, NULL, -6505627.59, 'USD'),
  (5021, 'SYS-004-06', 'AGR-004', 'CALYPSO', 'InterestRate:IRSwap', 'IRS_VANILLA', '2024-01-21', '2026-04-23', 'SCHEDULE', 'SIMM', 'EMIR', 'EMIR', true, false, NULL, -5634570.88, 'USD'),
  (5022, 'SYS-005-01', 'AGR-005', 'SUMMIT', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2023-02-08', '2033-05-18', 'SCHEDULE', 'SIMM', 'SEC', 'CFTC', true, false, NULL, 2474948.7, 'USD'),
  (5023, 'SYS-005-02', 'AGR-005', 'CALYPSO', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2024-07-04', '2026-10-13', 'GRID', 'GRID', 'SEC', 'CFTC', true, false, NULL, 9520986.54, 'USD'),
  (5024, 'SYS-005-03', 'AGR-005', 'CALYPSO', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2024-01-21', '2026-10-23', 'SCHEDULE', 'GRID', 'SEC', 'CFTC', true, false, NULL, -8273362.85, 'USD'),
  (5025, 'SYS-006-01', 'AGR-006', 'SUMMIT', 'InterestRate:IRSwap', 'IRS_VANILLA', '2024-05-19', '2027-11-21', 'GRID', 'GRID', 'OSFI', 'OSFI', true, false, NULL, 82751.15, 'CAD'),
  (5026, 'SYS-006-02', 'AGR-006', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-07-04', '2026-09-03', 'SIMM', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, -8954657.02, 'CAD'),
  (5027, 'SYS-006-03', 'AGR-006', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-02-01', '2028-09-25', 'GRID', 'SCHEDULE', 'OSFI', 'OSFI', true, true, 'Novated out', 2584698.19, 'CAD'),
  (5028, 'SYS-007-01', 'AGR-007', 'SUMMIT', 'InterestRate:IRSwap', 'IRS_VANILLA', '2024-08-16', '2029-09-02', 'SIMM', 'SCHEDULE', 'EMIR', 'EMIR', true, false, NULL, -4102442.62, 'USD'),
  (5029, 'SYS-007-02', 'AGR-007', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-12-27', '2026-12-12', 'SCHEDULE', 'SIMM', 'EMIR', 'EMIR', true, false, NULL, -243535.65, 'USD'),
  (5030, 'SYS-007-03', 'AGR-007', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2022-12-02', '2027-12-02', 'SCHEDULE', 'SCHEDULE', 'EMIR', 'EMIR', true, true, 'Trade matured', 2258182.08, 'USD'),
  (5031, 'SYS-007-04', 'AGR-007', 'MUREX', 'InterestRate:BondForward', 'BOND_FWD', '2022-05-10', '2024-10-17', 'GRID', 'SCHEDULE', 'EMIR', 'EMIR', true, false, NULL, 2334.47, 'USD'),
  (5032, 'SYS-007-05', 'AGR-007', 'CALYPSO', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-09-10', '2025-06-17', 'GRID', 'GRID', 'EMIR', 'EMIR', true, false, NULL, 12827447.61, 'USD'),
  (5033, 'SYS-008-01', 'AGR-008', 'MUREX', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-11-10', '2025-03-01', 'SCHEDULE', 'SCHEDULE', 'SEC', 'CFTC', true, false, NULL, 13819585.17, 'USD'),
  (5034, 'SYS-008-02', 'AGR-008', 'CALYPSO', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2022-12-08', '2027-08-23', 'SIMM', 'SCHEDULE', 'SEC', 'CFTC', true, false, NULL, 1626053.31, 'USD'),
  (5035, 'SYS-008-03', 'AGR-008', 'CALYPSO', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2023-09-25', '2030-09-07', 'SCHEDULE', 'SCHEDULE', 'SEC', 'CFTC', true, false, NULL, 8713769.49, 'USD'),
  (5036, 'SYS-008-04', 'AGR-008', 'MUREX', 'ForeignExchange:FXOption', 'FX_OPTION', '2024-04-06', '2031-10-09', 'SCHEDULE', 'SIMM', 'SEC', 'CFTC', true, false, NULL, 1850360.95, 'USD'),
  (5037, 'SYS-009-01', 'AGR-009', 'CALYPSO', 'Equity:EquitySwap', 'EQ_SWAP', '2023-03-05', '2025-09-27', 'SCHEDULE', 'SIMM', 'EMIR', 'EMIR', true, false, NULL, 11021561.92, 'EUR'),
  (5038, 'SYS-009-02', 'AGR-009', 'CALYPSO', 'Equity:EquitySwap', 'EQ_SWAP', '2022-04-13', '2027-11-17', 'SIMM', 'GRID', 'EMIR', 'EMIR', true, false, NULL, 84297.93, 'EUR'),
  (5039, 'SYS-009-03', 'AGR-009', 'MUREX', 'ForeignExchange:FXOption', 'FX_OPTION', '2022-02-20', '2032-11-02', 'SIMM', 'SCHEDULE', 'EMIR', 'EMIR', true, false, NULL, -8753081.35, 'EUR'),
  (5040, 'SYS-010-01', 'AGR-010', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-12-20', '2025-03-24', 'SCHEDULE', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, -3889261.38, 'CAD'),
  (5041, 'SYS-010-02', 'AGR-010', 'CALYPSO', 'ForeignExchange:FXOption', 'FX_OPTION', '2024-03-23', '2029-03-09', 'GRID', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, -726028.23, 'CAD'),
  (5042, 'SYS-010-03', 'AGR-010', 'MUREX', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-05-04', '2029-03-10', 'GRID', 'GRID', 'OSFI', 'OSFI', true, false, NULL, -1580756.08, 'CAD'),
  (5043, 'SYS-010-04', 'AGR-010', 'SUMMIT', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-11-01', '2025-05-07', 'GRID', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, 7290320.29, 'CAD'),
  (5044, 'SYS-010-05', 'AGR-010', 'CALYPSO', 'InterestRate:IRSwap', 'IRS_VANILLA', '2024-11-14', '2034-04-02', 'SCHEDULE', 'GRID', 'OSFI', 'OSFI', true, false, NULL, 12235382.68, 'CAD'),
  (5045, 'SYS-010-06', 'AGR-010', 'MUREX', 'ForeignExchange:FXOption', 'FX_OPTION', '2023-01-18', '2025-03-24', 'SIMM', 'GRID', 'OSFI', 'OSFI', true, false, NULL, -5334425.6, 'CAD'),
  (5046, 'SYS-011-01', 'AGR-011', 'CALYPSO', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2024-07-28', '2027-08-24', 'SCHEDULE', 'SCHEDULE', 'SEC', 'CFTC', true, false, NULL, 8179123.21, 'USD'),
  (5047, 'SYS-011-02', 'AGR-011', 'MUREX', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2022-12-12', '2029-11-19', 'SIMM', 'GRID', 'SEC', 'CFTC', true, false, NULL, 167686.95, 'USD'),
  (5048, 'SYS-011-03', 'AGR-011', 'SUMMIT', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2023-07-02', '2025-11-17', 'SCHEDULE', 'SIMM', 'SEC', 'CFTC', true, false, NULL, -6866135.69, 'USD'),
  (5049, 'SYS-011-04', 'AGR-011', 'CALYPSO', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2024-11-03', '2029-02-03', 'SCHEDULE', 'SIMM', 'SEC', 'CFTC', true, false, NULL, 8763165.77, 'USD'),
  (5050, 'SYS-011-05', 'AGR-011', 'CALYPSO', 'InterestRate:IRSwap', 'IRS_VANILLA', '2022-06-10', '2027-06-28', 'SIMM', 'GRID', 'SEC', 'CFTC', true, false, NULL, -168005.08, 'USD'),
  (5051, 'SYS-011-06', 'AGR-011', 'MUREX', 'InterestRate:IRSwap', 'IRS_VANILLA', '2023-03-16', '2025-12-25', 'GRID', 'GRID', 'SEC', 'CFTC', true, false, NULL, 266313.39, 'USD'),
  (5052, 'SYS-012-01', 'AGR-012', 'MUREX', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2024-12-15', '2026-08-08', 'GRID', 'GRID', 'OSFI', 'OSFI', true, false, NULL, 12335055.33, 'CAD'),
  (5053, 'SYS-012-02', 'AGR-012', 'SUMMIT', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2022-02-14', '2029-02-17', 'SCHEDULE', 'SCHEDULE', 'OSFI', 'OSFI', true, false, NULL, 1572210.6, 'CAD'),
  (5054, 'SYS-012-03', 'AGR-012', 'MUREX', 'Credit:CreditDefaultSwap', 'CDS_SINGLE_NAME', '2022-12-28', '2029-02-19', 'SIMM', 'GRID', 'OSFI', 'OSFI', true, false, NULL, -7292599.7, 'CAD');

-- ── 3. star_fact_issuer_exposure  (NEW — indirect exposure) ─────
CREATE TABLE IF NOT EXISTS `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_issuer_exposure (
  issuer_exposure_key BIGINT, agreement_id STRING, counterparty_code STRING,
  as_of_date DATE, issuer_name STRING, issuer_type STRING, issuer_rating STRING,
  collateral_value DECIMAL(18,2), indirect_exposure DECIMAL(18,2),
  CONSTRAINT pk_star_fact_issuer_exp PRIMARY KEY (issuer_exposure_key) NOT ENFORCED
) USING DELTA COMMENT 'Indirect exposure: risk to issuers of pledged collateral.';
TRUNCATE TABLE `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_issuer_exposure;
INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_issuer_exposure
  (issuer_exposure_key, agreement_id, counterparty_code, as_of_date,
   issuer_name, issuer_type, issuer_rating, collateral_value, indirect_exposure)
VALUES
  (9001, 'AGR-001', 'BCCU', '2026-01-15', 'Government of Canada', 'SOVEREIGN', 'AAA', 4428544.98, 4276332.33),
  (9002, 'AGR-001', 'BCCU', '2026-01-30', 'Government of Canada', 'SOVEREIGN', 'AAA', 3479982.48, 3168241.98),
  (9003, 'AGR-001', 'BCCU', '2026-02-13', 'Government of Canada', 'SOVEREIGN', 'AAA', 4701328.8, 4287270.01),
  (9004, 'AGR-001', 'BCCU', '2026-02-27', 'Government of Canada', 'SOVEREIGN', 'AAA', 4536052.32, 4344190.86),
  (9005, 'AGR-001', 'BCCU', '2026-03-14', 'Government of Canada', 'SOVEREIGN', 'AAA', 3389048.79, 3138466.86),
  (9006, 'AGR-001', 'BCCU', '2026-03-31', 'Government of Canada', 'SOVEREIGN', 'AAA', 3456087.47, 3308061.46),
  (9007, 'AGR-001', 'BCCU', '2026-01-15', 'CMHC', 'AGENCY', 'AAA', 3111599.17, 2862054.99),
  (9008, 'AGR-001', 'BCCU', '2026-01-30', 'CMHC', 'AGENCY', 'AAA', 2978889.51, 2859464.71),
  (9009, 'AGR-001', 'BCCU', '2026-02-13', 'CMHC', 'AGENCY', 'AAA', 2618732.71, 2515111.08),
  (9010, 'AGR-001', 'BCCU', '2026-02-27', 'CMHC', 'AGENCY', 'AAA', 2829873.13, 2606689.32),
  (9011, 'AGR-001', 'BCCU', '2026-03-14', 'CMHC', 'AGENCY', 'AAA', 2501505.46, 2312103.23),
  (9012, 'AGR-001', 'BCCU', '2026-03-31', 'CMHC', 'AGENCY', 'AAA', 3330423.33, 3114637.29),
  (9013, 'AGR-002', 'BCCU', '2026-01-15', 'Government of Canada', 'SOVEREIGN', 'AAA', 8786976.32, 8128660.76),
  (9014, 'AGR-002', 'BCCU', '2026-01-30', 'Government of Canada', 'SOVEREIGN', 'AAA', 9355706.98, 8942322.54),
  (9015, 'AGR-002', 'BCCU', '2026-02-13', 'Government of Canada', 'SOVEREIGN', 'AAA', 8723287.39, 8032133.78),
  (9016, 'AGR-002', 'BCCU', '2026-02-27', 'Government of Canada', 'SOVEREIGN', 'AAA', 8619946.15, 7843434.43),
  (9017, 'AGR-002', 'BCCU', '2026-03-14', 'Government of Canada', 'SOVEREIGN', 'AAA', 8142628.68, 7887892.44),
  (9018, 'AGR-002', 'BCCU', '2026-03-31', 'Government of Canada', 'SOVEREIGN', 'AAA', 6795253.81, 6369654.62),
  (9019, 'AGR-003', 'INBL', '2026-01-15', 'HM Treasury', 'SOVEREIGN', 'AA', 8524847.26, 7726018.33),
  (9020, 'AGR-003', 'INBL', '2026-01-30', 'HM Treasury', 'SOVEREIGN', 'AA', 7265990.55, 6969153.65),
  (9021, 'AGR-003', 'INBL', '2026-02-13', 'HM Treasury', 'SOVEREIGN', 'AA', 7323162.31, 6596109.98),
  (9022, 'AGR-003', 'INBL', '2026-02-27', 'HM Treasury', 'SOVEREIGN', 'AA', 8471947.64, 8021107.51),
  (9023, 'AGR-003', 'INBL', '2026-03-14', 'HM Treasury', 'SOVEREIGN', 'AA', 7443203.0, 6766096.3),
  (9024, 'AGR-003', 'INBL', '2026-03-31', 'HM Treasury', 'SOVEREIGN', 'AA', 9359435.69, 8994736.76),
  (9025, 'AGR-003', 'INBL', '2026-01-15', 'US Government', 'SOVEREIGN', 'AA+', 6503746.99, 6098115.5),
  (9026, 'AGR-003', 'INBL', '2026-01-30', 'US Government', 'SOVEREIGN', 'AA+', 5575095.49, 5364692.89),
  (9027, 'AGR-003', 'INBL', '2026-02-13', 'US Government', 'SOVEREIGN', 'AA+', 5895968.81, 5696663.71),
  (9028, 'AGR-003', 'INBL', '2026-02-27', 'US Government', 'SOVEREIGN', 'AA+', 6510903.06, 6204553.7),
  (9029, 'AGR-003', 'INBL', '2026-03-14', 'US Government', 'SOVEREIGN', 'AA+', 6583665.74, 6339211.83),
  (9030, 'AGR-003', 'INBL', '2026-03-31', 'US Government', 'SOVEREIGN', 'AA+', 5863774.22, 5734892.13),
  (9031, 'AGR-005', 'GSCO', '2026-01-15', 'US Government', 'SOVEREIGN', 'AA+', 5529745.22, 5146634.66),
  (9032, 'AGR-005', 'GSCO', '2026-01-30', 'US Government', 'SOVEREIGN', 'AA+', 6165178.16, 5907451.09),
  (9033, 'AGR-005', 'GSCO', '2026-02-13', 'US Government', 'SOVEREIGN', 'AA+', 5829585.79, 5356491.44),
  (9034, 'AGR-005', 'GSCO', '2026-02-27', 'US Government', 'SOVEREIGN', 'AA+', 7002721.55, 6795004.19),
  (9035, 'AGR-005', 'GSCO', '2026-03-14', 'US Government', 'SOVEREIGN', 'AA+', 5277980.57, 5063881.95),
  (9036, 'AGR-005', 'GSCO', '2026-03-31', 'US Government', 'SOVEREIGN', 'AA+', 5695691.21, 5137889.27),
  (9037, 'AGR-005', 'GSCO', '2026-01-15', 'Freddie Mac / FNMA', 'AGENCY', 'AA+', 5901095.12, 5373743.17),
  (9038, 'AGR-005', 'GSCO', '2026-01-30', 'Freddie Mac / FNMA', 'AGENCY', 'AA+', 5939106.46, 5742833.73),
  (9039, 'AGR-005', 'GSCO', '2026-02-13', 'Freddie Mac / FNMA', 'AGENCY', 'AA+', 5906514.16, 5544698.34),
  (9040, 'AGR-005', 'GSCO', '2026-02-27', 'Freddie Mac / FNMA', 'AGENCY', 'AA+', 5723606.68, 5430262.55),
  (9041, 'AGR-005', 'GSCO', '2026-03-14', 'Freddie Mac / FNMA', 'AGENCY', 'AA+', 6329583.72, 6064533.38),
  (9042, 'AGR-005', 'GSCO', '2026-03-31', 'Freddie Mac / FNMA', 'AGENCY', 'AA+', 6891935.54, 6728678.83),
  (9043, 'AGR-007', 'HSBC', '2026-01-15', 'HM Treasury', 'SOVEREIGN', 'AA', 9552461.28, 8616949.54),
  (9044, 'AGR-007', 'HSBC', '2026-01-30', 'HM Treasury', 'SOVEREIGN', 'AA', 7795512.74, 7103505.61),
  (9045, 'AGR-007', 'HSBC', '2026-02-13', 'HM Treasury', 'SOVEREIGN', 'AA', 9471146.33, 8802032.09),
  (9046, 'AGR-007', 'HSBC', '2026-02-27', 'HM Treasury', 'SOVEREIGN', 'AA', 10226643.44, 9566872.05),
  (9047, 'AGR-007', 'HSBC', '2026-03-14', 'HM Treasury', 'SOVEREIGN', 'AA', 10249423.63, 9241383.58),
  (9048, 'AGR-007', 'HSBC', '2026-03-31', 'HM Treasury', 'SOVEREIGN', 'AA', 8462554.98, 8127614.38);

-- ================================================================
-- 4. LIVE-UPDATE DEMO
-- With the Strategy model connected in LIVE mode, run this UPDATE
-- and refresh the dossier — the new value appears immediately.
-- Target: Goldman Sachs 31-Mar event. Note the value first, run, refresh.
-- ================================================================
-- BEFORE: SELECT base_total_exposure FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_collateral_exposure WHERE event_id='EVT-005-0331';
UPDATE `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_collateral_exposure
  SET base_total_exposure = 75000000.00,
      base_call_amount    = 65000000.00,
      call_status         = 'Margin Request Issued',
      is_disputed         = true,
      dispute_amount      = 5000000.00,
      dispute_age         = 1
  WHERE event_id = 'EVT-005-0331';
-- AFTER: refresh dossier — Goldman 31-Mar exposure jumps to 75,000,000.

-- ================================================================
-- 5. DATA-MASKING DEMO  (Unity Catalog column mask, demo-controlled)
-- Masks lei_code on star_dim_legal_entity. Designed so the PRESENTER
-- can toggle masking on/off live with a single UPDATE — no group
-- membership or permission changes needed.
-- ================================================================

-- 5a. Control table — one row, one flag the presenter flips.
CREATE TABLE IF NOT EXISTS `d4001-centralus-tdvip-creditrisk`.xvala_xva.demo_mask_control (
  control_key   STRING  COMMENT 'Always MASK_LEI for this demo',
  masking_on    BOOLEAN COMMENT 'true = lei_code is masked for everyone',
  CONSTRAINT pk_demo_mask_control PRIMARY KEY (control_key) NOT ENFORCED
) USING DELTA COMMENT 'Demo control flag for the data-masking showcase.';
TRUNCATE TABLE `d4001-centralus-tdvip-creditrisk`.xvala_xva.demo_mask_control;
INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.demo_mask_control (control_key, masking_on)
VALUES ('MASK_LEI', true);

-- 5b. Masking function — reads the control flag.
-- When masking_on = true  -> everyone sees 'XXX-MASKED'.
-- When masking_on = false -> everyone sees the real LEI.
CREATE OR REPLACE FUNCTION `d4001-centralus-tdvip-creditrisk`.xvala_xva.mask_lei(lei STRING)
  RETURN CASE
    WHEN (SELECT masking_on FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.demo_mask_control
          WHERE control_key = 'MASK_LEI') = true
      THEN 'XXX-MASKED'
    ELSE lei
  END;

-- 5c. Apply the mask to the lei_code column (do this once, before the demo).
ALTER TABLE `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_legal_entity
  ALTER COLUMN lei_code SET MASK `d4001-centralus-tdvip-creditrisk`.xvala_xva.mask_lei;

-- 5d. Tag the column so it shows as governed/sensitive in Catalog Explorer.
ALTER TABLE `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_legal_entity
  ALTER COLUMN lei_code SET TAGS ('data_sensitivity' = 'confidential');

-- ----------------------------------------------------------------
-- DEMO SCRIPT — run these live, refreshing the dossier between steps.
-- ----------------------------------------------------------------
-- STEP 1  (masking ON — the starting state above): dashboard shows
--         lei_code as 'XXX-MASKED'. Show the audience.
--
-- STEP 2  Presenter UNMASKS — run this one statement, refresh dossier:
-- UPDATE `d4001-centralus-tdvip-creditrisk`.xvala_xva.demo_mask_control SET masking_on = false WHERE control_key = 'MASK_LEI';
--         -> real LEI codes (LEI-GS-001 etc.) now appear.
--
-- STEP 3  Presenter RE-MASKS — run this, refresh dossier:
-- UPDATE `d4001-centralus-tdvip-creditrisk`.xvala_xva.demo_mask_control SET masking_on = true  WHERE control_key = 'MASK_LEI';
--         -> back to 'XXX-MASKED'.
--
-- To remove the mask entirely after the session:
-- ALTER TABLE `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_legal_entity ALTER COLUMN lei_code DROP MASK;
-- ----------------------------------------------------------------

-- ── VERIFY ──────────────────────────────────────────────────────
SELECT 'star_dim_legal_entity' tbl, COUNT(*) rows FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_legal_entity
UNION ALL SELECT 'star_dim_trade', COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_trade
UNION ALL SELECT 'star_fact_issuer_exposure', COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_issuer_exposure;