-- =====================================================================
-- Unity Catalog: PK/FK constraints + semantic tags for the PFE views
-- Aligned to unity_catalog_standards_v4.xlsx (launch-tier structural items).
-- SCOPE (per your direction): grain (contract_grain), PK/FK, column_role,
--   measure_aggregation, measure_unit, measure_methodology. OWNERSHIP / PII /
--   sensitivity deferred. Tags set with plain SET TAGS (governed-tag creation
--   not assumed). Constraints are RELY (informational) — they help Mosaic infer
--   joins and avoid the accidental cross-fact relationships seen during build.
-- NOTE: PK/FK on VIEWS require the columns to be NOT NULL / unique in practice;
--   if ALTER VIEW ... ADD CONSTRAINT is unsupported in your DBR, apply the PK/FK
--   block to the underlying BASE TABLES instead and keep the tag block on views.
-- =====================================================================

-- ---------- TABLE-LEVEL: contract_grain + lifecycle + methodology ----------
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` SET TAGS ('contract_grain' = 'line', 'lifecycle' = 'active', 'measure_methodology' = 'ATS/ASTS PFE engine — 2026-04-30 load');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` SET TAGS ('contract_grain' = 'deal_id', 'lifecycle' = 'active', 'measure_methodology' = 'ATS/ASTS PFE engine — 2026-04-30 load');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` SET TAGS ('contract_grain' = 'line+scenario_name', 'lifecycle' = 'active', 'measure_methodology' = 'ATS/ASTS PFE engine — 2026-04-30 load');

-- ---------- PRIMARY KEYS (RELY, informational) ----------
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ADD CONSTRAINT pk_line PRIMARY KEY (Line) RELY;
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line`   ADD CONSTRAINT pk_deal PRIMARY KEY (Deal_Id) RELY;
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario`    ADD CONSTRAINT pk_line_scn PRIMARY KEY (Line, Scenario_Name) RELY;

-- ---------- FOREIGN KEYS (conformance to the line fact on Line) ----------
-- Scenario fact and deal fact both attach to the line world on the conformed Line key.
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ADD CONSTRAINT fk_scn_line FOREIGN KEY (Line) REFERENCES `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail`(Line) RELY;
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ADD CONSTRAINT fk_deal_line FOREIGN KEY (Line) REFERENCES `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail`(Line) RELY;
-- ---------- COLUMN-LEVEL: column_role (always) + measure_aggregation/unit (measures) ----------

-- vw_pfe_ats_lines_detail
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line SET TAGS ('column_role' = 'key');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Counterparty_Name SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Booking_Entity SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Industry SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN TD_Sub_Industry SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Client_Type SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line_Worst_Rating SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN OTC_SFT SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Stress_PFE SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Standard_PFE SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Limit_Amount SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Utilization SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'ratio');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Is_Breached SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Worst_Scenario SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN IM SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN IA SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line_MTM_Base SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line_MTM_Stress SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Business_Date SET TAGS ('column_role' = 'audit');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line_Scn_Cartor_Base SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line_Scn_Zero SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line_Scn_25th SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line_Scn_75th SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line_Scn_Stress75 SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line_Scn_Correlation_1 SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line_Scn_Product SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line_Scn_Stress_MPR_025 SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN BRR SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line_Type SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Line_Currency SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Country_Of_Risk SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN CIF_Country_Name SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Region SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Stress_Over_Base SET TAGS ('column_role' = 'measure');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Impact_Pct SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'ratio');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Effective_Limit SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Max_Exp_Time_Bucket SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Max_Scenario_Name SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Utilization_Band SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_ats_lines_detail` ALTER COLUMN Utilization_Band_Order SET TAGS ('column_role' = 'dimension');

-- vw_pfe_deals_by_line
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Line SET TAGS ('column_role' = 'key');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Line_Class SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Facility_Line_Code SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Booking_Entity SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Counterparty_Name SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Counterparty_Code SET TAGS ('column_role' = 'key');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Deal_Id SET TAGS ('column_role' = 'key');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Deal_Name SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN New_Deal_Flag SET TAGS ('column_role' = 'audit');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Line_Type SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Asset_Class SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Asset_Class_Group SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN ISDA_Indicator SET TAGS ('column_role' = 'audit');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Industry SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Counterparty_Rating SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN MTM SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN MTM_Currency SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Notional_1 SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'native_currency');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Notional_1_Currency SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Notional_2 SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'native_currency');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Notional_2_Currency SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Trade_Date SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Maturity_Date SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Years_To_Maturity SET TAGS ('column_role' = 'measure');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Maturity_Band SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Maturity_Band_Order SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Tenor_Band SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Margin_Call_Norm SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN New_Deal_Norm SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN MTM_Share_Of_Line SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'ratio');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Is_Dominant_Deal SET TAGS ('column_role' = 'audit');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Maturity_Position SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Is_Longest_In_Line SET TAGS ('column_role' = 'audit');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Direction_Vs_Line SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Line_New_MTM_Share SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'ratio');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Line_Override_Share SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'ratio');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Override SET TAGS ('column_role' = 'audit');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Override_Date SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN OES_Indicator SET TAGS ('column_role' = 'audit');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN QA_Number SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN IM_Model SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Margin_Call_Frequency SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Agreement_Group_Code SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Source SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Non_Simulated_CONT SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'native_currency');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Non_Simulated_CONT_Currency SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN C2C_Charge SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'native_currency');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN C2C_Charge_Cur SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Product_Term_Exception SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Value_Date SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Line_Expiry SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Original_Location SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_deals_by_line` ALTER COLUMN Business_Date SET TAGS ('column_role' = 'dimension');

-- vw_pfe_asts_scenario
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Scenario_Name SET TAGS ('column_role' = 'key');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Scenario_Order SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Line SET TAGS ('column_role' = 'key');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Line_Class SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Booking_Entity SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Long_Name SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Line_Type SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Line_Expiry SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN No_Line_Indicator SET TAGS ('column_role' = 'audit');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Line_Currency SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Worst_Rating_Of_Associated_Clients SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Standard_Usage_0_3_mo SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Standard_Usage_3_12_mo SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Standard_Usage_1_2_Yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Standard_Usage_2_5_Yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Standard_Usage_5_10_Yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Standard_Usage_10_50_Yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Max_Usage_0_3_mo SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Max_Usage_3_12_mo SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Max_Usage_1_2_Yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Max_Usage_2_5_Yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Max_Usage_5_10_Yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Max_Usage_10_50_Yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Limit_3_mo SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Limit_1_Yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Limit_2_Yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Limit_5_Yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Limit_10_Yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Limit_50_Yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'semi-additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN `3_12_mo_Excess_Breach` SET TAGS ('column_role' = 'audit');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN `1_2_Yr_Excess_Breach` SET TAGS ('column_role' = 'audit');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN `2_5_Yr_Excess_Breach` SET TAGS ('column_role' = 'audit');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN `5_10_Yr_Excess_Breach` SET TAGS ('column_role' = 'audit');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN `10_50_Yr_Excess_Breach` SET TAGS ('column_role' = 'audit');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN `0_3_mo_Excess_Percentage` SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN `3_12_mo_Excess_Percentage` SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN `1_2_Yr_Excess_Percentage` SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN `2_5_Yr_Excess_Percentage` SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN `5_10_Yr_Excess_Percentage` SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN `10_50_Yr_Excess_Percentage` SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Gross_Max_Exposure SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Max_Scenario_Exposure SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Max_Exp_Time_Bucket SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Max_Scenario_Name SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Scenario_Code SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Timestep SET TAGS ('column_role' = 'dimension');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Standard_Exposure SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'additive', 'measure_unit' = 'USD');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Excess_Percentage SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Exposure_Percentage SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Exposure_Percentage_0_3_mo SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Exposure_Percentage_3_12_mo SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Exposure_Percentage_1_2_yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Exposure_Percentage_2_5_yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Exposure_Percentage_5_10_yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Exposure_Percentage_10_50_yr SET TAGS ('column_role' = 'measure', 'measure_aggregation' = 'non-additive', 'measure_unit' = 'percent');
ALTER VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_pfe_asts_scenario` ALTER COLUMN Business_Date SET TAGS ('column_role' = 'dimension');
