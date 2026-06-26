-- =====================================================================
-- XVALA CREDIT-RISK : MASTER TABLE DEFINITIONS
-- Catalog: d4001-centralus-tdvip-creditrisk
-- Consolidated 2026-06-26 from all definitions provided to date.
-- Single source of truth for table DDL. (Views live in vw_*.sql files.)
-- =====================================================================
--
-- CONTENTS
--   Schema xvala_core
--     1. asts
--     2. ats_summary
--     3. test_ats_summary
--     4. test_clients_report
--   Schema xvala_core-raw
--     5. lines_report
--     6. pfe_deals_report
--     7. pfe_clients_report
--     8. pfe_exp_decomp_report
--     9. limits
--     10. limit_config
--   (pending) xvala_core.test_lines_report  -- full DDL still outstanding
-- =====================================================================


-- #####################################################################
-- ##  SCHEMA: xvala_core
-- #####################################################################

-- ---------------------------------------------------------------------
-- 1. xvala_core.asts
--    Stressed scenario detail per credit line. Limit_* and exposure cols are STRING; business_date STRING (yyyymmdd).
-- ---------------------------------------------------------------------
CREATE TABLE `d4001-centralus-tdvip-creditrisk`.xvala_core.asts (
  Scenario_Name STRING COLLATE UTF8_BINARY COMMENT 'Mapped scenario display name. BASE is excluded from final output.',
  Line STRING COLLATE UTF8_BINARY COMMENT 'Credit line identifier.',
  Long_Name STRING COLLATE UTF8_BINARY,
  Line_Type STRING COLLATE UTF8_BINARY,
  Line_Expiry INT,
  No_Line_Indicator BOOLEAN,
  Line_Currency STRING COLLATE UTF8_BINARY,
  Worst_Rating_Of_Associated_Clients STRING COLLATE UTF8_BINARY,
  Standard_Usage_0_3_mo STRING COLLATE UTF8_BINARY,
  Standard_Usage_3_12_mo STRING COLLATE UTF8_BINARY,
  Standard_Usage_1_2_Yr STRING COLLATE UTF8_BINARY,
  Standard_Usage_2_5_Yr STRING COLLATE UTF8_BINARY,
  Standard_Usage_5_10_Yr STRING COLLATE UTF8_BINARY,
  Standard_Usage_10_50_Yr STRING COLLATE UTF8_BINARY,
  Max_Usage_0_3_mo STRING COLLATE UTF8_BINARY,
  Max_Usage_3_12_mo STRING COLLATE UTF8_BINARY,
  Max_Usage_1_2_Yr STRING COLLATE UTF8_BINARY,
  Max_Usage_2_5_Yr STRING COLLATE UTF8_BINARY,
  Max_Usage_5_10_Yr STRING COLLATE UTF8_BINARY,
  Max_Usage_10_50_Yr STRING COLLATE UTF8_BINARY,
  Limit_3_mo STRING COLLATE UTF8_BINARY,
  Limit_1_Yr STRING COLLATE UTF8_BINARY,
  Limit_2_Yr STRING COLLATE UTF8_BINARY,
  Limit_5_Yr STRING COLLATE UTF8_BINARY,
  Limit_10_Yr STRING COLLATE UTF8_BINARY,
  Limit_50_Yr STRING COLLATE UTF8_BINARY,
  `3_12_mo_Excess_Breach` STRING COLLATE UTF8_BINARY,
  `1_2_Yr_Excess_Breach` STRING COLLATE UTF8_BINARY,
  `2_5_Yr_Excess_Breach` STRING COLLATE UTF8_BINARY,
  `5_10_Yr_Excess_Breach` STRING COLLATE UTF8_BINARY,
  `10_50_Yr_Excess_Breach` STRING COLLATE UTF8_BINARY,
  `0_3_mo_Excess_Percentage` DOUBLE,
  `3_12_mo_Excess_Percentage` DOUBLE,
  `1_2_Yr_Excess_Percentage` DOUBLE,
  `2_5_Yr_Excess_Percentage` DOUBLE,
  `5_10_Yr_Excess_Percentage` DOUBLE,
  `10_50_Yr_Excess_Percentage` DOUBLE,
  Gross_Max_Exposure STRING COLLATE UTF8_BINARY,
  Max_Scenario_Exposure STRING COLLATE UTF8_BINARY COMMENT 'Maximum exposure amount under stressed scenarios.',
  Max_Exp_Time_Bucket STRING COLLATE UTF8_BINARY,
  Max_Scenario_Name STRING COLLATE UTF8_BINARY,
  Scenario STRING COLLATE UTF8_BINARY COMMENT 'Scenario code from source system.',
  Timestep STRING COLLATE UTF8_BINARY COMMENT 'Scenario timestep / horizon bucket index.',
  Standard_Exposure STRING COLLATE UTF8_BINARY COMMENT 'Standard exposure aligned to the max exposure bucket from BASE scenario values.',
  Excess_Percentage STRING COLLATE UTF8_BINARY,
  Exposure_Percentage STRING COLLATE UTF8_BINARY,
  Exposure_Percentage_0_3_mo STRING COLLATE UTF8_BINARY,
  Exposure_Percentage_3_12_mo STRING COLLATE UTF8_BINARY,
  Exposure_Percentage_1_2_yr STRING COLLATE UTF8_BINARY,
  Exposure_Percentage_2_5_yr STRING COLLATE UTF8_BINARY,
  Exposure_Percentage_5_10_yr STRING COLLATE UTF8_BINARY,
  Exposure_Percentage_10_50_yr STRING COLLATE UTF8_BINARY,
  business_date STRING COLLATE UTF8_BINARY COMMENT 'Business date in yyyymmdd format.'
);


-- ---------------------------------------------------------------------
-- 2. xvala_core.ats_summary
--    Scenario-maxima rollup. NOTE: has NO brr / sic_code; business_date STRING. Superseded by test_ats_summary.
-- ---------------------------------------------------------------------
CREATE TABLE `d4001-centralus-tdvip-creditrisk`.xvala_core.ats_summary (
  line STRING COLLATE UTF8_BINARY COMMENT 'Credit line identifier.',
  long_name STRING COLLATE UTF8_BINARY,
  line_currency STRING COLLATE UTF8_BINARY,
  limit_3_mo DOUBLE,
  limit_1_yr DOUBLE,
  limit_2_yr DOUBLE,
  limit_5_yr DOUBLE,
  limit_10_yr DOUBLE,
  cartor_max DOUBLE,
  zero_max DOUBLE,
  c_25_max DOUBLE,
  c_75_max DOUBLE,
  str75_max DOUBLE,
  one_max DOUBLE,
  prod_max DOUBLE,
  strmpr025_max DOUBLE,
  max_of_all DOUBLE COMMENT 'Maximum value across scenario maxima.',
  max_all_less_cartor DOUBLE COMMENT 'Incremental stressed max over baseline (cartor_max).',
  scenario_of_max STRING COLLATE UTF8_BINARY COMMENT 'Scenario label that produced max_of_all.',
  percentage_of_impact DOUBLE COMMENT 'Ratio max_of_all / cartor_max.',
  worst_rating_of_associated_clients STRING COLLATE UTF8_BINARY,
  otc_sft STRING COLLATE UTF8_BINARY,
  line_type STRING COLLATE UTF8_BINARY,
  country_of_risk STRING COLLATE UTF8_BINARY,
  cif_country_name STRING COLLATE UTF8_BINARY,
  region STRING COLLATE UTF8_BINARY,
  sic_industry STRING COLLATE UTF8_BINARY,
  industry STRING COLLATE UTF8_BINARY,
  td_sub STRING COLLATE UTF8_BINARY,
  business_date STRING COLLATE UTF8_BINARY COMMENT 'Business date in yyyymmdd format.'
)
USING delta;


-- ---------------------------------------------------------------------
-- 3. xvala_core.test_ats_summary
--    Append-only typed rollup ACTUALLY joined by vw_ast_breach_report. HAS brr & sic_code. business_date DATE (PK1), line (PK2), report_run_at.
-- ---------------------------------------------------------------------
CREATE TABLE `d4001-centralus-tdvip-creditrisk`.xvala_core.test_ats_summary (
  line                                STRING COLLATE UTF8_BINARY COMMENT 'Primary key part 2: credit line identifier.',
  long_name                           STRING COLLATE UTF8_BINARY,
  line_currency                       STRING COLLATE UTF8_BINARY,
  limit_3_mo                          DOUBLE,
  limit_1_yr                          DOUBLE,
  limit_2_yr                          DOUBLE,
  limit_5_yr                          DOUBLE,
  limit_10_yr                         DOUBLE,
  cartor_max                          DOUBLE,
  zero_max                            DOUBLE,
  c_25_max                            DOUBLE,
  c_75_max                            DOUBLE,
  str75_max                           DOUBLE,
  one_max                             DOUBLE,
  prod_max                            DOUBLE,
  strmpr025_max                       DOUBLE,
  max_of_all                          DOUBLE,
  max_all_less_cartor                 DOUBLE,
  scenario_of_max                     STRING COLLATE UTF8_BINARY,
  percentage_of_impact                DOUBLE,
  worst_rating_of_associated_clients  STRING COLLATE UTF8_BINARY,
  otc_sft                             STRING COLLATE UTF8_BINARY,
  line_type                           STRING COLLATE UTF8_BINARY,
  country_of_risk                     STRING COLLATE UTF8_BINARY,
  cif_country_name                    STRING COLLATE UTF8_BINARY,
  region                              STRING COLLATE UTF8_BINARY,
  sic_industry                        STRING COLLATE UTF8_BINARY,
  sic_code                            STRING COLLATE UTF8_BINARY,   -- used by view -> SIC_Code
  brr                                 STRING COLLATE UTF8_BINARY,   -- used by view -> Rating
  industry                            STRING COLLATE UTF8_BINARY,
  td_sub                              STRING COLLATE UTF8_BINARY,
  business_date                       DATE COMMENT 'Primary key part 1: business date as DATE.',
  report_run_at                       TIMESTAMP COMMENT 'Timestamp when this run was written;


-- ---------------------------------------------------------------------
-- 4. xvala_core.test_clients_report
--    Append-only typed variant of pfe_clients_report. counterparty_code (PK1), business_date DATE (PK2), ingested_at.
-- ---------------------------------------------------------------------
CREATE TABLE `d4001-centralus-tdvip-creditrisk`.xvala_core.test_clients_report (
  counterparty_code              STRING COLLATE UTF8_BINARY COMMENT 'Primary key part 1: counterparty identifier from source client file.',
  counterparty_long_name         STRING COLLATE UTF8_BINARY COMMENT 'Client long name as STRING from clients_report.csv.',
  c2c_line                       STRING COLLATE UTF8_BINARY COMMENT 'Client to client line identifier as STRING.',
  c2c_line_expiry                DATE   COMMENT 'C2C line expiry date as DATE.',
  c2c_no_line_indicator          BOOLEAN COMMENT 'No line indicator for C2C line as BOOLEAN.',
  cont_line                      STRING COLLATE UTF8_BINARY COMMENT 'Contingent line identifier as STRING.',
  cont_line_expiry               DATE   COMMENT 'Contingent line expiry date as DATE.',
  cont_no_line_indicator         BOOLEAN COMMENT 'No line indicator for contingent line as BOOLEAN.',
  immediate_parent               STRING COLLATE UTF8_BINARY COMMENT 'Immediate parent client code as STRING.',
  ultimate_parent                STRING COLLATE UTF8_BINARY COMMENT 'Ultimate parent client code as STRING.',
  bis_code                       STRING COLLATE UTF8_BINARY COMMENT 'BIS code as STRING.',
  cif_number                     STRING COLLATE UTF8_BINARY COMMENT 'CIF number as STRING.',
  country_of_risk                STRING COLLATE UTF8_BINARY COMMENT 'Country of risk code as STRING.',
  td_country_of_risk_rating      STRING COLLATE UTF8_BINARY COMMENT 'Country of risk rating as STRING.',
  location_of_residence          STRING COLLATE UTF8_BINARY COMMENT 'Location of residence as STRING.',
  td_account_rating              STRING COLLATE UTF8_BINARY COMMENT 'Account rating as STRING.',
  sic_class                      STRING COLLATE UTF8_BINARY COMMENT 'SIC class as STRING.',
  sic_code                       STRING COLLATE UTF8_BINARY COMMENT 'SIC code as STRING.',
  sic_segment                    STRING COLLATE UTF8_BINARY COMMENT 'SIC segment as STRING.',
  sic_group                      STRING COLLATE UTF8_BINARY COMMENT 'SIC group as STRING.',
  sic_industry                   STRING COLLATE UTF8_BINARY COMMENT 'SIC industry as STRING.',
  td_industry_risk_rating        STRING COLLATE UTF8_BINARY COMMENT 'Industry risk rating as STRING.',
  bloomberg_ticker               STRING COLLATE UTF8_BINARY COMMENT 'Bloomberg ticker as STRING.',
  bloomberg_industry_sector      STRING COLLATE UTF8_BINARY COMMENT 'Bloomberg industry sector as STRING.',
  bloomberg_industry_group       STRING COLLATE UTF8_BINARY COMMENT 'Bloomberg industry group as STRING.',
  bloomberg_industry_subgroup    STRING COLLATE UTF8_BINARY COMMENT 'Bloomberg industry subgroup as STRING.',
  s_p_rating                     STRING COLLATE UTF8_BINARY COMMENT 'S and P rating as STRING.',
  moody_s_rating                 STRING COLLATE UTF8_BINARY COMMENT 'Moodys rating as STRING.',
  composite_secured_rating       STRING COLLATE UTF8_BINARY COMMENT 'Composite secured rating as STRING.',
  composite_unsecured_rating     STRING COLLATE UTF8_BINARY COMMENT 'Composite unsecured rating as STRING.',
  composite_subordinated_rating  STRING COLLATE UTF8_BINARY COMMENT 'Composite subordinated rating as STRING.',
  composite_preferred_rating     STRING COLLATE UTF8_BINARY COMMENT 'Composite preferred rating as STRING.',
  bis_eligible                   STRING COLLATE UTF8_BINARY COMMENT 'BIS eligibility flag as STRING.',
  multibranch_netting            STRING COLLATE UTF8_BINARY COMMENT 'Multibranch netting indicator as STRING.',
  isda                           STRING COLLATE UTF8_BINARY COMMENT 'ISDA indicator as STRING.',
  ifema                          STRING COLLATE UTF8_BINARY COMMENT 'IFEMA indicator as STRING.',
  csa                            STRING COLLATE UTF8_BINARY COMMENT 'CSA indicator as STRING.',
  net_fx                         STRING COLLATE UTF8_BINARY COMMENT 'Netting flag for FX as STRING.',
  net_fxo                        STRING COLLATE UTF8_BINARY COMMENT 'Netting flag for FXO as STRING.',
  net_derv                       STRING COLLATE UTF8_BINARY COMMENT 'Netting flag for derivatives as STRING.',
  xnet_all                       STRING COLLATE UTF8_BINARY COMMENT 'Cross netting all products indicator as STRING.',
  csa_irs                        STRING COLLATE UTF8_BINARY COMMENT 'CSA flag for IRS as STRING.',
  csa_ccs                        STRING COLLATE UTF8_BINARY COMMENT 'CSA flag for CCS as STRING.',
  csa_iro                        STRING COLLATE UTF8_BINARY COMMENT 'CSA flag for IRO as STRING.',
  csa_fx                         STRING COLLATE UTF8_BINARY COMMENT 'CSA flag for FX as STRING.',
  csa_fxo                        STRING COLLATE UTF8_BINARY COMMENT 'CSA flag for FXO as STRING.',
  csa_bo                         STRING COLLATE UTF8_BINARY COMMENT 'CSA flag for BO as STRING.',
  csa_eqd                        STRING COLLATE UTF8_BINARY COMMENT 'CSA flag for EQD as STRING.',
  csa_crd                        STRING COLLATE UTF8_BINARY COMMENT 'CSA flag for CRD as STRING.',
  csa_com                        STRING COLLATE UTF8_BINARY COMMENT 'CSA flag for COM as STRING.',
  csa_pm                         STRING COLLATE UTF8_BINARY COMMENT 'CSA flag for PM as STRING.',
  up_cif                         STRING COLLATE UTF8_BINARY COMMENT 'Ultimate parent CIF as STRING.',
  agreement_id                   STRING COLLATE UTF8_BINARY COMMENT 'Agreement identifier as STRING.',
  agreement_type                 STRING COLLATE UTF8_BINARY COMMENT 'Agreement type as STRING.',
  agreement_group_code           STRING COLLATE UTF8_BINARY COMMENT 'Agreement group code as STRING.',
  business_date                  DATE   COMMENT 'Primary key part 2: business date as DATE.',
  source                         STRING COLLATE UTF8_BINARY COMMENT 'Source file path used for ingest (for example .../CARTOR/clients_report.csv).',
  ingested_at                    TIMESTAMP COMMENT 'Ingestion timestamp as TIMESTAMP for append-only loads;


-- #####################################################################
-- ##  SCHEMA: xvala_core-raw   (back-tick the schema: `xvala_core-raw`)
-- #####################################################################

-- ---------------------------------------------------------------------
-- 5. xvala_core-raw.lines_report
--    Line limits/usage/availability (typed: INT/BIGINT/DOUBLE). Has mark_to_market.
-- ---------------------------------------------------------------------
CREATE TABLE `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.lines_report (
  line STRING COLLATE UTF8_BINARY,
  long_name STRING COLLATE UTF8_BINARY,
  line_type STRING COLLATE UTF8_BINARY,
  line_expiry INT,
  days_since_expiry INT,
  no_line_indicator BOOLEAN,
  line_currency STRING COLLATE UTF8_BINARY,
  parent_line_name STRING COLLATE UTF8_BINARY,
  branch_locations STRING COLLATE UTF8_BINARY,
  number_of_associated_clients INT,
  worst_rating_of_associated_clients STRING COLLATE UTF8_BINARY,
  number_of_associated_clients_with_no_isda INT,
  excess_flag STRING COLLATE UTF8_BINARY,
  roll_off_limit STRING COLLATE UTF8_BINARY,
  min_availability_0_3_mo DOUBLE,
  min_availability_3_12_mo DOUBLE,
  min_availability_1_2_yr DOUBLE,
  min_availability_2_5_yr DOUBLE,
  min_availability_5_10_yr DOUBLE,
  min_availability_10_50_yr DOUBLE,
  max_usage_0_3_mo DOUBLE,
  max_usage_3_12_mo DOUBLE,
  max_usage_1_2_yr DOUBLE,
  max_usage_2_5_yr DOUBLE,
  max_usage_5_10_yr DOUBLE,
  max_usage_10_50_yr DOUBLE,
  usage_3_mo DOUBLE,
  usage_1_yr DOUBLE,
  usage_2_yr DOUBLE,
  usage_3_yr DOUBLE,
  usage_10_yr DOUBLE,
  usage_50_yr DOUBLE,
  limit_3_mo BIGINT,
  limit_1_yr BIGINT,
  limit_2_yr BIGINT,
  limit_5_yr BIGINT,
  limit_10_yr BIGINT,
  limit_50_yr BIGINT,
  ccs_term_limit INT,
  comm_term_limit INT,
  crd_term_limit INT,
  eqd_term_limit INT,
  fx_term_limit DOUBLE,
  ir_term_limit INT,
  ngas_term_limit INT,
  other_term_limit DOUBLE,
  oes_term_limit INT,
  initial_margin DOUBLE,
  gross_max_exposure STRING COLLATE UTF8_BINARY,
  threshold STRING COLLATE UTF8_BINARY,
  mark_to_market DOUBLE,
  variation_margin DOUBLE,
  mc_frequency STRING COLLATE UTF8_BINARY,
  facility_id STRING COLLATE UTF8_BINARY,
  frr STRING COLLATE UTF8_BINARY,
  negative_mtm STRING COLLATE UTF8_BINARY,
  secured_limit STRING COLLATE UTF8_BINARY,
  source STRING COLLATE UTF8_BINARY,
  business_date STRING COLLATE UTF8_BINARY
)
USING delta;


-- ---------------------------------------------------------------------
-- 6. xvala_core-raw.pfe_deals_report
--    Deal-level PFE report.
-- ---------------------------------------------------------------------
CREATE TABLE `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.pfe_deals_report (
  name STRING COLLATE UTF8_BINARY,
  deal_id STRING COLLATE UTF8_BINARY,
  new_deal_flag STRING COLLATE UTF8_BINARY,
  line STRING COLLATE UTF8_BINARY,
  line_type STRING COLLATE UTF8_BINARY,
  line_expiry STRING COLLATE UTF8_BINARY,
  no_line_indicator STRING COLLATE UTF8_BINARY,
  product_term_exception STRING COLLATE UTF8_BINARY,
  counterparty_code STRING COLLATE UTF8_BINARY,
  counterparty_long_name STRING COLLATE UTF8_BINARY,
  isda_indicator STRING COLLATE UTF8_BINARY,
  td_account_rating STRING COLLATE UTF8_BINARY,
  sic_industry STRING COLLATE UTF8_BINARY,
  site STRING COLLATE UTF8_BINARY,
  book STRING COLLATE UTF8_BINARY,
  deal_type STRING COLLATE UTF8_BINARY,
  trade_date STRING COLLATE UTF8_BINARY,
  value_date STRING COLLATE UTF8_BINARY,
  maturity_date STRING COLLATE UTF8_BINARY,
  years_to_maturity STRING COLLATE UTF8_BINARY,
  deal_m2m STRING COLLATE UTF8_BINARY,
  deal_m2m_currency STRING COLLATE UTF8_BINARY,
  principal_1 STRING COLLATE UTF8_BINARY,
  principal_1_currency STRING COLLATE UTF8_BINARY,
  principal_2 STRING COLLATE UTF8_BINARY,
  principal_2_currency STRING COLLATE UTF8_BINARY,
  non_simulated_cont STRING COLLATE UTF8_BINARY,
  non_simulated_cont_currency STRING COLLATE UTF8_BINARY,
  oes_indicator STRING COLLATE UTF8_BINARY,
  override STRING COLLATE UTF8_BINARY,
  override_date STRING COLLATE UTF8_BINARY,
  qa_number STRING COLLATE UTF8_BINARY,
  c2c_charge STRING COLLATE UTF8_BINARY,
  c2c_charge_cur STRING COLLATE UTF8_BINARY,
  margin_call_frequency STRING COLLATE UTF8_BINARY,
  original_location STRING COLLATE UTF8_BINARY,
  agreement_group_code STRING COLLATE UTF8_BINARY,
  im_model STRING COLLATE UTF8_BINARY,
  business_date STRING COLLATE UTF8_BINARY,
  source STRING COLLATE UTF8_BINARY,
  ingested_at TIMESTAMP
)
USING delta;


-- ---------------------------------------------------------------------
-- 7. xvala_core-raw.pfe_clients_report
--    Counterparty / ratings / CSA netting. (Tail was cut off in the photo; confirmed via test_clients_report.)
-- ---------------------------------------------------------------------
CREATE TABLE `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.pfe_clients_report (
  counterparty_code STRING COLLATE UTF8_BINARY,
  counterparty_long_name STRING COLLATE UTF8_BINARY,
  c2c_line STRING COLLATE UTF8_BINARY,
  c2c_line_expiry STRING COLLATE UTF8_BINARY,
  c2c_no_line_indicator STRING COLLATE UTF8_BINARY,
  cont_line STRING COLLATE UTF8_BINARY,
  cont_line_expiry STRING COLLATE UTF8_BINARY,
  cont_no_line_indicator STRING COLLATE UTF8_BINARY,
  immediate_parent STRING COLLATE UTF8_BINARY,
  ultimate_parent STRING COLLATE UTF8_BINARY,
  bis_code STRING COLLATE UTF8_BINARY,
  cif_number STRING COLLATE UTF8_BINARY,
  country_of_risk STRING COLLATE UTF8_BINARY,
  td_country_of_risk_rating STRING COLLATE UTF8_BINARY,
  location_of_residence STRING COLLATE UTF8_BINARY,
  td_account_rating STRING COLLATE UTF8_BINARY,
  sic_class STRING COLLATE UTF8_BINARY,
  sic_code STRING COLLATE UTF8_BINARY,
  sic_segment STRING COLLATE UTF8_BINARY,
  sic_group STRING COLLATE UTF8_BINARY,
  sic_industry STRING COLLATE UTF8_BINARY,
  td_industry_risk_rating STRING COLLATE UTF8_BINARY,
  bloomberg_ticker STRING COLLATE UTF8_BINARY,
  bloomberg_industry_sector STRING COLLATE UTF8_BINARY,
  bloomberg_industry_group STRING COLLATE UTF8_BINARY,
  bloomberg_industry_subgroup STRING COLLATE UTF8_BINARY,
  s_p_rating STRING COLLATE UTF8_BINARY,
  moody_s_rating STRING COLLATE UTF8_BINARY,
  composite_secured_rating STRING COLLATE UTF8_BINARY,
  composite_unsecured_rating STRING COLLATE UTF8_BINARY,
  composite_subordinated_rating STRING COLLATE UTF8_BINARY,
  composite_preferred_rating STRING COLLATE UTF8_BINARY,
  bis_eligible STRING COLLATE UTF8_BINARY,
  multibranch_netting STRING COLLATE UTF8_BINARY,
  isda STRING COLLATE UTF8_BINARY,
  ifema STRING COLLATE UTF8_BINARY,
  csa STRING COLLATE UTF8_BINARY,
  net_fx STRING COLLATE UTF8_BINARY,
  net_fxo STRING COLLATE UTF8_BINARY,
  net_derv STRING COLLATE UTF8_BINARY,
  xnet_all STRING COLLATE UTF8_BINARY,
  csa_irs STRING COLLATE UTF8_BINARY,
  csa_ccs STRING COLLATE UTF8_BINARY,
  csa_iro STRING COLLATE UTF8_BINARY,
  csa_fx STRING COLLATE UTF8_BINARY,
  csa_fxo STRING COLLATE UTF8_BINARY,
  csa_bo STRING COLLATE UTF8_BINARY,
  csa_eqd STRING COLLATE UTF8_BINARY,
  csa_crd STRING COLLATE UTF8_BINARY,
  csa_com STRING COLLATE UTF8_BINARY,
  csa_pm STRING COLLATE UTF8_BINARY,
  up_cif STRING COLLATE UTF8_BINARY,
  agreement_id STRING COLLATE UTF8_BINARY,
  agreement_type STRING COLLATE UTF8_BINARY,
  agreement_group_code STRING COLLATE UTF8_BINARY,
  business_date STRING COLLATE UTF8_BINARY,   -- (partially cut off in photo)
  source STRING COLLATE UTF8_BINARY,
  ingested_at TIMESTAMP
)
USING delta;


-- ---------------------------------------------------------------------
-- 8. xvala_core-raw.pfe_exp_decomp_report
--    Exposure decomposition by product group.
-- ---------------------------------------------------------------------
CREATE TABLE `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.pfe_exp_decomp_report (
  line STRING COLLATE UTF8_BINARY,
  long_name STRING COLLATE UTF8_BINARY,
  line_type STRING COLLATE UTF8_BINARY,
  line_currency STRING COLLATE UTF8_BINARY,
  product_group STRING COLLATE UTF8_BINARY,
  max_usage_0_3_mo STRING COLLATE UTF8_BINARY,
  max_usage_3_12_mo STRING COLLATE UTF8_BINARY,
  max_usage_1_2_yr STRING COLLATE UTF8_BINARY,
  max_usage_2_5_yr STRING COLLATE UTF8_BINARY,
  max_usage_5_10_yr STRING COLLATE UTF8_BINARY,
  max_usage_10_50_yr STRING COLLATE UTF8_BINARY,
  agreement_group_code STRING COLLATE UTF8_BINARY,
  source STRING COLLATE UTF8_BINARY,
  business_date STRING COLLATE UTF8_BINARY,
  ingested_at TIMESTAMP
)
USING delta;


-- ---------------------------------------------------------------------
-- 9. xvala_core-raw.limits
--    Rating(INT) -> limit reference. 'limit' is a reserved word (back-tick it).
-- ---------------------------------------------------------------------
CREATE TABLE `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.limits (
  credit_rating       INT,
  `limit`             INT,
  excess_percent      STRING,   -- stored as text incl. the '%' sign, e.g. '50.00%'
  last_modified_date  STRING    -- ⚠️ mixed formats: 'MM/DD/YYYY HH:MM' and ISO w/ microseconds
)
USING delta;


-- ---------------------------------------------------------------------
-- 10. xvala_core-raw.limit_config
--    Rating(STRING, e.g. 1A/_NA_) -> limit reference. 'limit' is reserved.
-- ---------------------------------------------------------------------
CREATE TABLE `d4001-centralus-tdvip-creditrisk`.`xvala_core-raw`.limit_config (
  cpinternalrating  STRING,   -- alphanumeric rating bucket: '1A','2B','_NA_', etc.
  `limit`           INT
)
USING delta;


-- #####################################################################
-- ##  PENDING / INCOMPLETE
-- #####################################################################

-- ---------------------------------------------------------------------
-- 11. xvala_core.test_lines_report   (FULL DDL OUTSTANDING)
--    Only the tail of this table was visible in the photo. Known so far:
--      * append-only, same pattern as the other test_ tables
--      * business_date DATE  and  report_run_at TIMESTAMP
--      * referenced by vw_ast_breach_report for mark_to_market (filtered Source='CARTOR')
--    >> Resend the full column list to complete this entry.
-- ---------------------------------------------------------------------
-- CREATE TABLE `d4001-centralus-tdvip-creditrisk`.xvala_core.test_lines_report (
--   line STRING COLLATE UTF8_BINARY,
--   ... ,
--   mark_to_market <type>,
--   business_date DATE,
--   source STRING COLLATE UTF8_BINARY,
--   report_run_at TIMESTAMP
-- ) USING delta;
