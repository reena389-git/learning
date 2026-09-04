# Databricks notebook — STEP 1: create raw + silver schemas and silver tables
# %python  (set the cell language to Python)

CAT    = "workspace"          # <-- your catalog (private instance); e.g. "workspace" or your UC catalog
SILVER = "cmos_core"          # silver schema
RAW    = "cmos_core_raw"      # raw/bronze schema

spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CAT}.{RAW}")
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CAT}.{SILVER}")
# Volume for landing the CSV files
spark.sql(f"CREATE VOLUME IF NOT EXISTS {CAT}.{RAW}.landing")

DDLS = {}
DDLS["agreements"] = """CREATE TABLE {CAT}.{SILVER}.agreements (
  external_id                              STRING        COMMENT 'External Id defined in Party/Counterparty tab.',
  principal_lei                            STRING,
  principal                                STRING        COMMENT 'Principal of specific agreement.',
  principal_code                           STRING        COMMENT 'Principal Code defined in Organisation page.',
  counterparty                             STRING        COMMENT 'Counterparty of specific agreement.',
  counterparty_code                        STRING        COMMENT 'Counterparty Code defined in Organisation page.',
  counterparty_lei                         STRING,
  principal_rating                         STRING        COMMENT 'Principal Rating defined in Organisation tab.',
  counterparty_rating                      STRING        COMMENT 'Principal Rating defined in Organisation tab.',
  agreement_category                       STRING        COMMENT 'Category defined in Party/Counterparty tab.',
  groupname                                STRING        COMMENT 'Group defined in Party/Counterparty tab.',
  base_currency                            STRING        COMMENT 'Base currency defined in Documentation tab.',
  im_legal_review_frequency                STRING,
  legal_review_frequency                   STRING        COMMENT 'Legal Review Frequency defined in Call Schedule tab (Net and VM)',
  reciprocity                              STRING        COMMENT 'Reciprocity defined in Documentation tab.',
  counterparty_fixed_mta_values            DECIMAL(38,10),
  counterparty_fixed_mta_value_ccy         STRING,
  counterparty_im_fixed_mta_values         DECIMAL(38,10),
  counterparty_im_fixed_mta_value_ccy      STRING,
  counterparty_fixed_rounding_values       DECIMAL(38,10),
  counterparty_fixed_rounding_value_ccy    STRING,
  counterparty_fixed_threshold_value_ccy   STRING,
  counterparty_fixed_threshold_values      DECIMAL(38,10),
  counterparty_fixed_values                DECIMAL(38,10) COMMENT 'Fixed Values section defined in Fixed Trigger tab.',
  counterparty_im                          STRING,
  counterparty_im_fixed_rounding_value_ccy STRING,
  counterparty_im_fixed_rounding_values    DECIMAL(38,10),
  counterparty_im_fixed_threshold_value_ccy STRING,
  counterparty_im_fixed_threshold_values   DECIMAL(38,10),
  counterparty_im_fixed_values             DECIMAL(38,10),
  counterparty_im_rating_contingent_values STRING,
  counterparty_im_seg_type                 STRING        COMMENT 'Counterparty Seg Type for IM collateral',
  principal_fixed_mta_value_ccy            STRING,
  principal_fixed_mta_values               DECIMAL(38,10),
  principal_fixed_rounding_value_ccy       STRING,
  principal_fixed_rounding_values          DECIMAL(38,10),
  principal_fixed_threshold_value_ccy      STRING,
  principal_fixed_threshold_values         DECIMAL(38,10),
  principal_fixed_values                   DECIMAL(38,10) COMMENT 'Fixed Values section defined in Fixed Trigger tab.',
  principal_im                             STRING,
  principal_im_fixed_mta_value_ccy         STRING,
  principal_im_fixed_mta_values            DECIMAL(38,10),
  principal_im_fixed_rounding_value_ccy    STRING,
  principal_im_fixed_rounding_values       DECIMAL(38,10),
  principal_im_fixed_threshold_value_ccy   STRING,
  principal_im_fixed_threshold_values      DECIMAL(38,10),
  principal_im_fixed_values                DECIMAL(38,10),
  principal_im_rating_contingent_values    STRING,
  principal_im_seg_type                    STRING        COMMENT 'Principal Seg Type for IM collateral',
  principal_industry                       STRING,
  principal_agreement_ia                   STRING        COMMENT 'Agreement level IA excluding external fed IA',
  counterparty_agreement_ia                STRING        COMMENT 'Agreement level IA excluding external fed IA',
  agreement_date                           DATE          COMMENT 'Agreement Date defined in Documentation tab.',
  agreement_id                             STRING        COMMENT 'Primary key. Agreement Id in Statement page.',
  agreement_status                         STRING        COMMENT 'Agreement Status of specific agreement',
  agreement_description                    STRING        COMMENT 'Agreement Description defined in Party/Counterparty tab.',
  agreement_type                           STRING,
  agreementgroupcode                       STRING,
  counterparty_seg_type                    STRING        COMMENT 'Counterparty Seg Type for Net and VM collateral',
  principal_seg_type                       STRING        COMMENT 'Principal Seg Type for Net and VM collateral',
  segregation                              STRING        COMMENT 'Whether the collateral is segegated',
  linkage_set                              STRING        COMMENT 'A group of target agreements to which changes from original agreement will be copied.',
  assets                                   STRING        COMMENT 'Assets type selected in Collateral tab.',
  custodian                                STRING        COMMENT 'Custodian',
  simm_principal_calculation_currency      STRING,
  simm_cp_calculation_currency             STRING,
  rescued_data                             STRING,
  reporting_date                           DATE NOT NULL,
  agreement_name                           STRING,
  region                                   STRING,
  principal_termination_currency           STRING,
  counterparty_termination_currency        STRING
)
USING delta
PARTITIONED BY (reporting_date)
COMMENT 'CMOS silver: master legal agreement attributes -- principal/counterparty identifiers, VM and IM thresholds, MTAs, rounding values, segregation type, rating-contingent terms. Snapshot per reporting_day.'
TBLPROPERTIES (
  'catalog.schema.table'                = 'd4001-centralus-tdvip-creditrisk.cmos_core.agreements',
  'cmos.source_bronze_watermark'        = 'v=111;rows=1537155',
  'delta.columnMapping.mode'            = 'name',
  'delta.enableDeletionVectors'         = 'true',
  'delta.feature.appendOnly'            = 'supported',
  'delta.feature.changeDataFeed'        = 'supported',
  'delta.feature.checkConstraints'      = 'supported',
  'delta.feature.columnMapping'         = 'supported',
  'delta.feature.deletionVectors'       = 'supported',
  'delta.feature.generatedColumns'      = 'supported',
  'delta.feature.invariants'            = 'supported',
  'delta.minReaderVersion'              = '3',
  'delta.minWriterVersion'              = '7',
  'delta.parquet.compression.codec'     = 'zstd'
);"""

DDLS["organization"] = """CREATE TABLE {CAT}.{SILVER}.organization (
  parent_id        STRING,
  petrid           STRING,
  org_lei          STRING,
  parent_lei       STRING,
  parent_name      STRING,
  internal_rating  STRING,
  internal_flag    STRING,
  rescued_data     STRING,
  reporting_date   DATE NOT NULL
)
USING delta
PARTITIONED BY (reporting_date)
TBLPROPERTIES (
  'cmos.source_bronze_watermark'    = 'v=84;rows=1817542',
  'delta.columnMapping.mode'        = 'name',
  'delta.enableDeletionVectors'     = 'true',
  'delta.feature.appendOnly'        = 'supported',
  'delta.feature.changeDataFeed'    = 'supported',
  'delta.feature.checkConstraints'  = 'supported',
  'delta.feature.columnMapping'     = 'supported',
  'delta.feature.deletionVectors'   = 'supported',
  'delta.feature.generatedColumns'  = 'supported',
  'delta.feature.invariants'        = 'supported',
  'delta.minReaderVersion'          = '3',
  'delta.minWriterVersion'          = '7',
  'delta.parquet.compression.codec' = 'zstd'
);"""

DDLS["trades"] = """CREATE TABLE {CAT}.{SILVER}.trades (
  trade_identifier_party_a           STRING,
  trade_identifier_2_party_a         STRING,
  trade_date                         DATE,
  effective_date                     DATE,
  maturity_date                      DATE,
  party_a_branch_name                STRING,
  party_b_branch_name                STRING,
  strike_price                       DECIMAL(38,10),
  buy_or_sell                        STRING,
  put_or_call                        STRING,
  exchanged_notional_1_amount        DECIMAL(38,10),
  exchanged_notional_1_currency      STRING,
  exchanged_notional_2_amount        DECIMAL(38,10),
  exchanged_notional_2_currency      STRING,
  valuation_base_currency            STRING,
  valuation_date                     DATE,
  underlying                         STRING,
  external_id                        STRING,
  valuation_base_currency_amount_t_1 DECIMAL(38,10),
  margin_type                        STRING,
  settlement_date                    DATE,
  agreement_name                     STRING,
  ims_portfolio                      STRING,
  ims_desk                           STRING,
  model                              STRING,
  pai                                DECIMAL(38,10),
  pai_rate                           DECIMAL(18,8),
  source_system                      STRING,
  product_type                       STRING,
  trade_identifier_party_b           STRING,
  applicable_agreements              STRING,
  rescued_data                       STRING,
  reporting_date                     DATE NOT NULL
)
USING delta
PARTITIONED BY (reporting_date)
TBLPROPERTIES (
  'cmos.source_bronze_watermark'    = 'v=96;rows=19178515',
  'delta.columnMapping.mode'        = 'name',
  'delta.enableDeletionVectors'     = 'true',
  'delta.feature.appendOnly'        = 'supported',
  'delta.feature.changeDataFeed'    = 'supported',
  'delta.feature.checkConstraints'  = 'supported',
  'delta.feature.columnMapping'     = 'supported',
  'delta.feature.deletionVectors'   = 'supported',
  'delta.feature.generatedColumns'  = 'supported',
  'delta.feature.invariants'        = 'supported',
  'delta.minReaderVersion'          = '3',
  'delta.minWriterVersion'          = '7',
  'delta.parquet.compression.codec' = 'zstd'
);"""

DDLS["repo_trades"] = """CREATE TABLE {CAT}.{SILVER}.repo_trades (
  trade_identifier_party_a    STRING,
  trade_identifier_2_party_a  STRING,
  trade_date                  DATE,
  start_date                  DATE,
  end_date                    DATE,
  party_a_branch_name         STRING,
  party_b_branch_name         STRING,
  valuation_date              DATE,
  underlying                  STRING,
  external_id                 STRING,
  settlement_date             DATE,
  ims_portfolio               STRING,
  ims_desk                    STRING,
  source_system               STRING,
  product_type                STRING,
  rescued_data                STRING,
  reporting_date              DATE NOT NULL
)
USING delta
PARTITIONED BY (reporting_date)
TBLPROPERTIES (
  'cmos.source_bronze_watermark'    = 'v=82;rows=154916',
  'delta.columnMapping.mode'        = 'name',
  'delta.enableDeletionVectors'     = 'true',
  'delta.feature.appendOnly'        = 'supported',
  'delta.feature.changeDataFeed'    = 'supported',
  'delta.feature.checkConstraints'  = 'supported',
  'delta.feature.columnMapping'     = 'supported',
  'delta.feature.deletionVectors'   = 'supported',
  'delta.feature.generatedColumns'  = 'supported',
  'delta.feature.invariants'        = 'supported',
  'delta.minReaderVersion'          = '3',
  'delta.minWriterVersion'          = '7',
  'delta.parquet.compression.codec' = 'zstd'
);"""

DDLS["daily_exposure"] = """CREATE TABLE {CAT}.{SILVER}.daily_exposure (
  principal_agreement_level_ia      DECIMAL(38,10),
  counterparty_agreement_level_ia   DECIMAL(38,10),
  base_threshold_principal          DECIMAL(38,10),
  base_threshold_principal_im       DECIMAL(38,10),
  base_threshold_counterparty       DECIMAL(38,10),
  base_threshold_counterparty_im    DECIMAL(38,10),
  base_min_transfer_principal       DECIMAL(38,10),
  base_min_transfer_principal_im    DECIMAL(38,10),
  base_min_transfer_counterparty    DECIMAL(38,10),
  base_min_transfer_counterparty_im DECIMAL(38,10),
  base_principal_i_a                DECIMAL(38,10),
  base_counterparty_external_ia     DECIMAL(38,10),
  base_counterparty_i_a             DECIMAL(38,10),
  counterparty_rounding             DECIMAL(38,10),
  principal_rounding                DECIMAL(38,10),
  itm_exposure                      DECIMAL(38,10),
  otm_exposure                      DECIMAL(38,10),
  base_total_exposure_amount        DECIMAL(38,10),
  action                            STRING,
  agreed_amount                     DECIMAL(38,10),
  base_call_amount                  DECIMAL(38,10),
  booked_amount_first_leg           DECIMAL(38,10),
  booked_amount_second_leg          DECIMAL(38,10),
  call_status                       STRING,
  counterparty_amount               DECIMAL(38,10),
  reporting_call_amount             DECIMAL(38,10),
  model                             STRING,
  agreement_id                      STRING,
  event_id                          STRING,
  external_id                       STRING,
  instrument_id                     STRING,
  margin_type                       STRING,
  reporting_currency                STRING,
  counterparty_im_rounding          DECIMAL(38,10),
  principal_im_rounding             DECIMAL(38,10),
  im_requirement                    DECIMAL(38,10),
  event_date                        DATE,
  counterparty                      STRING,
  agreement_description             STRING,
  rescued_data                      STRING,
  reporting_date                    DATE NOT NULL
)
USING delta
PARTITIONED BY (reporting_date)
TBLPROPERTIES (
  'cmos.source_bronze_watermark'    = 'v=83;rows=2755138',
  'delta.columnMapping.mode'        = 'name',
  'delta.enableDeletionVectors'     = 'true',
  'delta.feature.appendOnly'        = 'supported',
  'delta.feature.changeDataFeed'    = 'supported',
  'delta.feature.checkConstraints'  = 'supported',
  'delta.feature.columnMapping'     = 'supported',
  'delta.feature.deletionVectors'   = 'supported',
  'delta.feature.generatedColumns'  = 'supported',
  'delta.feature.invariants'        = 'supported',
  'delta.minReaderVersion'          = '3',
  'delta.minWriterVersion'          = '7',
  'delta.parquet.compression.codec' = 'zstd'
);"""

DDLS["repo_daily_exposure"] = """CREATE TABLE {CAT}.{SILVER}.repo_daily_exposure (
  base_threshold_principal        DECIMAL(38,10),
  base_threshold_counterparty     DECIMAL(38,10),
  base_min_transfer_principal     DECIMAL(38,10),
  base_min_transfer_counterparty  DECIMAL(38,10),
  counterparty_rounding           DECIMAL(38,10),
  principal_rounding              DECIMAL(38,10),
  base_total_exposure_amount      DECIMAL(38,10),
  action                          STRING,
  agreed_amount                   DECIMAL(38,10),
  base_call_amount                DECIMAL(38,10),
  booked_amount_first_leg         DECIMAL(38,10),
  booked_amount_second_leg        DECIMAL(38,10),
  call_status                     STRING,
  counterparty_amount             DECIMAL(38,10),
  reporting_call_amount           DECIMAL(38,10),
  agreement_id                    STRING,
  event_id                        STRING,
  external_id                     STRING,
  instrument_id                   STRING,
  margin_type                     STRING,
  reporting_currency              STRING,
  dispute_age                     INT,
  rescued_data                    STRING,
  reporting_date                  DATE NOT NULL
)
USING delta
PARTITIONED BY (reporting_date)
TBLPROPERTIES (
  'cmos.source_bronze_watermark'    = 'v=82;rows=465650',
  'delta.columnMapping.mode'        = 'name',
  'delta.enableDeletionVectors'     = 'true',
  'delta.feature.appendOnly'        = 'supported',
  'delta.feature.changeDataFeed'    = 'supported',
  'delta.feature.checkConstraints'  = 'supported',
  'delta.feature.columnMapping'     = 'supported',
  'delta.feature.deletionVectors'   = 'supported',
  'delta.feature.generatedColumns'  = 'supported',
  'delta.feature.invariants'        = 'supported',
  'delta.minReaderVersion'          = '3',
  'delta.minWriterVersion'          = '7',
  'delta.parquet.compression.codec' = 'zstd'
);"""

DDLS["disputes"] = """CREATE TABLE {CAT}.{SILVER}.disputes (
  counterparty              STRING,
  description               STRING,
  action                    STRING,
  time                      TIMESTAMP,
  base_currency             STRING,
  reporting_dispute_amount  DECIMAL(38,10),
  dispute_age               INT,
  dispute_amount            DECIMAL(38,10),
  agreement_id              STRING,
  event_id                  STRING,
  rescued_data              STRING,
  reporting_date            DATE NOT NULL
)
USING delta
PARTITIONED BY (reporting_date)
TBLPROPERTIES (
  'cmos.source_bronze_watermark'    = 'v=82;rows=19055',
  'delta.columnMapping.mode'        = 'name',
  'delta.enableDeletionVectors'     = 'true',
  'delta.feature.appendOnly'        = 'supported',
  'delta.feature.changeDataFeed'    = 'supported',
  'delta.feature.checkConstraints'  = 'supported',
  'delta.feature.columnMapping'     = 'supported',
  'delta.feature.deletionVectors'   = 'supported',
  'delta.feature.generatedColumns'  = 'supported',
  'delta.minReaderVersion'          = '3',
  'delta.minWriterVersion'          = '7',
  'delta.parquet.compression.codec' = 'zstd'
);"""

DDLS["settlement_instructions"] = """CREATE TABLE {CAT}.{SILVER}.settlement_instructions (
  agreement_id            STRING,
  bucket                  STRING,
  type                    STRING,
  asset                   STRING,
  prc_account_number      STRING,
  prc_beneficiary_bank    STRING,
  prc_ultimate_custodian  STRING,
  cpty_account_number     STRING,
  cpty_beneficiary_bank   STRING,
  cpty_ultimate_custodian STRING,
  agreement_description   STRING,
  business_line           STRING,
  counterparty            STRING,
  principal               STRING,
  rescued_data            STRING,
  reporting_date          DATE NOT NULL
)
USING delta
PARTITIONED BY (reporting_date)
TBLPROPERTIES (
  'cmos.source_bronze_watermark'    = 'v=72;rows=1083757',
  'delta.columnMapping.mode'        = 'name',
  'delta.enableDeletionVectors'     = 'true',
  'delta.feature.appendOnly'        = 'supported',
  'delta.feature.changeDataFeed'    = 'supported',
  'delta.feature.checkConstraints'  = 'supported',
  'delta.feature.columnMapping'     = 'supported',
  'delta.feature.deletionVectors'   = 'supported',
  'delta.feature.generatedColumns'  = 'supported',
  'delta.feature.invariants'        = 'supported',
  'delta.minReaderVersion'          = '3',
  'delta.minWriterVersion'          = '7',
  'delta.parquet.compression.codec' = 'zstd'
);"""

DDLS["collateral_eligibility"] = """CREATE TABLE {CAT}.{SILVER}.collateral_eligibility (
  agreement_external_id  STRING         COMMENT 'Agreement External Id defined in Party/Counterparty tab. Identifies the agreement this eligibility rule applies to.',
  asset_class            STRING         COMMENT 'Eligible asset class for this agreement (e.g. CASH, Sovereign, Agency).',
  asset_type             STRING         COMMENT 'Eligible asset type within the asset class (e.g. USD CASH, US Treasury Bond).',
  maturity_term_from     DECIMAL(38,10) COMMENT 'Lower bound (inclusive) of the maturity term band the rule applies to, in years. Sourced from the Maturity Term From header.',
  maturity_term_to       DECIMAL(38,10) COMMENT 'Upper bound of the maturity term band the rule applies to, in years. Sourced from the Maturity Term To header.',
  from_rating_level      STRING         COMMENT 'Lower credit-rating bound of the eligibility band, as a slash-delimited multi-agency rating string.',
  to_rating_level        STRING         COMMENT 'Upper credit-rating bound of the eligibility band, as a slash-delimited multi-agency rating string.',
  valuation_haircut      DECIMAL(38,10) COMMENT 'Valuation / haircut percentage applied to eligible collateral in this band.',
  rescued_data           STRING,
  reporting_day          DATE NOT NULL
)
USING delta
PARTITIONED BY (reporting_day)
COMMENT 'CMOS silver: Colline collateral eligibility and haircut schedule per agreement -- eligible asset class/type, maturity term band, credit-rating band, and valuation/haircut percentage. Snapshot per reporting_day.'
TBLPROPERTIES (
  'catalog.schema.table'          = 'd4001-centralus-tdvip-creditrisk.cmos_core.collateral_eligibility',
  'cmos.source_bronze_watermark'  = 'v=5;rows=863865',
  'delta.enableDeletionVectors'   = 'true',
  'delta.feature.deletionVectors' = 'supported',
  'delta.feature.invariants'      = 'supported',
  'delta.minReaderVersion'        = '3',
  'delta.minWriterVersion'        = '7'
);"""

DDLS["asset_holdings"] = """CREATE TABLE {CAT}.{SILVER}.asset_holdings (
  issuer                          STRING         COMMENT 'Issuer for the asset type with collateral bookings.',
  description                     STRING,
  maturity_date                   DATE,
  classification                  STRING,
  rating                          STRING,
  clean_price                     DECIMAL(38,10) COMMENT 'Clean Price for asset type with collateral bookings.',
  coupon_accrual                  DECIMAL(38,10),
  factor                          DECIMAL(38,10),
  dirty_price                     DECIMAL(38,10) COMMENT 'Dirty Price for asset type with collateral bookings.',
  valuation_date                  DATE           COMMENT 'Price Valuation Date set for the asset type with collateral booking.',
  lock_up_margin                  DECIMAL(38,10),
  par_amount                      DECIMAL(38,10),
  booking_currency                STRING,
  booking_market_value            DECIMAL(38,10),
  booking_collateral_value        DECIMAL(38,10),
  haircut                         DECIMAL(18,8),
  internal_policy_reuse           STRING,
  reporting_currency              STRING,
  reported_market_value           DECIMAL(38,10),
  reported_collateral_value       DECIMAL(38,10),
  issue_date                      DATE,
  agreement_ext_id                STRING,
  additional_info_1               STRING,
  additional_info_2               STRING,
  additional_info_3               STRING,
  additional_info_4               STRING,
  notation                        STRING,
  region                          STRING,
  `group`                         STRING,
  counterparty_contact            STRING,
  telephone_number                STRING,
  fax_number                      STRING,
  email_address                   STRING,
  custodian                       STRING,
  fx_rate                         DECIMAL(38,10),
  margin_type                     STRING,
  asset_notes1                    STRING,
  asset_notes2                    STRING,
  asset_notes3                    STRING,
  base_ccy                        STRING,
  base_market_value               DECIMAL(38,10),
  base_adjusted_collateral_value  DECIMAL(38,10),
  cpty_country_of_risk            STRING,
  instrument_id_type              STRING,
  prc_payment_instruction_bucket  STRING,
  cpty_payment_instruction_bucket STRING,
  segregation                     STRING,
  segregation_type                STRING,
  gross_calc                      STRING,
  issuer_country_of_risk          STRING,
  prc_account_number              STRING,
  prc_beneficiary_bank            STRING,
  prc_ultimate_custodian_code     STRING,
  prc_ultimate_custodian          STRING,
  cpty_account_number             STRING,
  cpty_beneficiary_bank           STRING,
  cpty_ultimate_custodian_code    STRING,
  cpty_ultimate_custodian         STRING,
  agreement                       STRING,
  agreement_category              STRING,
  agreement_name                  STRING,
  asset_class                     STRING,
  asset_owner                     STRING,
  asset_type                      STRING,
  booking_type                    STRING,
  business_line                   STRING,
  ccp                             STRING,
  cqs                             STRING,
  collateral_status               STRING,
  counterparty                    STRING,
  counterparty_lei                STRING,
  counterpartycode                STRING,
  counterpartywithcpcode          STRING,
  cpty_petrid                     STRING,
  cpty_jurisdiction               STRING,
  cpty_cif_number                 STRING,
  cpty_internal_flag              STRING,
  cpty_internal_rating            STRING,
  cpty_bloomberg_ticker           STRING,
  cpty_bloomberg_company_id       STRING,
  im_rehypothecation_rights       STRING,
  instrument_id                   STRING,
  issue_country_of_risk           STRING,
  issuer_code                     STRING,
  issuer_long_name                STRING,
  issuer_rating                   STRING,
  linkage_set                     STRING,
  market                          STRING,
  model                           STRING,
  pd                              DECIMAL(18,8),
  position                        STRING,
  prc_petrid                      STRING,
  prc_jurisdiction                STRING,
  prc_cif_number                  STRING,
  prc_internal_flag               STRING,
  prc_bloomberg_ticker            STRING,
  prc_bloomberg_company_id        STRING,
  price_factor                    DECIMAL(38,10),
  price_source                    STRING,
  principal                       STRING,
  principal_lei                   STRING,
  principalcode                   STRING,
  rehypothecated                  STRING,
  rehypothecation_rights          STRING,
  rescued_data                    STRING,
  reporting_date                  DATE NOT NULL,
  usd_to_cad_rate                 DECIMAL(38,10)
)
USING delta
PARTITIONED BY (reporting_date)
COMMENT 'CMOS silver: daily snapshot of collateral asset holdings per agreement -- valuations (clean/dirty price, market/collateral value), haircuts, FX, counterparty / issuer enrichment, segregation. Partitioned by reporting_day.'
TBLPROPERTIES (
  'cmos.source_bronze_watermark'    = 'v=84;rows=727115',
  'delta.columnMapping.mode'        = 'name',
  'delta.enableDeletionVectors'     = 'true',
  'delta.feature.appendOnly'        = 'supported',
  'delta.feature.changeDataFeed'    = 'supported',
  'delta.feature.checkConstraints'  = 'supported',
  'delta.feature.columnMapping'     = 'supported',
  'delta.feature.deletionVectors'   = 'supported',
  'delta.feature.generatedColumns'  = 'supported',
  'delta.feature.invariants'        = 'supported',
  'delta.minReaderVersion'          = '3',
  'delta.minWriterVersion'          = '7',
  'delta.parquet.compression.codec' = 'zstd'
);"""

DDLS["asset_settlements"] = """CREATE TABLE {CAT}.{SILVER}.asset_settlements (
  instrument_id                STRING,
  currency                     STRING,
  creation_date                DATE,
  settlement_date              DATE,
  actual_settlement_date       DATE,
  nominal_amount               DECIMAL(38,10),
  reported_collateral_value    DECIMAL(38,10),
  reporting_currency           STRING,
  payment_instructions_bucket  STRING,
  external_id                  STRING,
  instrument_id_type           STRING,
  issuer                       STRING,
  issued_amount                DECIMAL(38,10),
  asset_class                  STRING,
  asset_type                   STRING,
  booking_market_value         DECIMAL(38,10),
  booking_type                 STRING,
  collateral_status            STRING,
  movement                     STRING,
  rescued_data                 STRING,
  reporting_date               DATE NOT NULL
)
USING delta
PARTITIONED BY (reporting_date)
TBLPROPERTIES (
  'cmos.source_bronze_watermark'    = 'v=83;rows=1318192',
  'delta.columnMapping.mode'        = 'name',
  'delta.enableDeletionVectors'     = 'true',
  'delta.feature.appendOnly'        = 'supported',
  'delta.feature.changeDataFeed'    = 'supported',
  'delta.feature.checkConstraints'  = 'supported',
  'delta.feature.columnMapping'     = 'supported',
  'delta.feature.deletionVectors'   = 'supported',
  'delta.feature.generatedColumns'  = 'supported',
  'delta.feature.invariants'        = 'supported',
  'delta.minReaderVersion'          = '3',
  'delta.minWriterVersion'          = '7',
  'delta.parquet.compression.codec' = 'zstd'
);"""

DDLS["fx_rates"] = """CREATE TABLE {CAT}.{SILVER}.fx_rates (
  date         DATE,
  bid_rate     DECIMAL(38,10),
  offer_rate   DECIMAL(38,10),
  ccy          STRING,
  rate_type    STRING,
  fx_rate_set  STRING
)
USING delta
TBLPROPERTIES (
  'delta.enableDeletionVectors'     = 'true',
  'delta.feature.appendOnly'        = 'supported',
  'delta.feature.deletionVectors'   = 'supported',
  'delta.feature.invariants'        = 'supported',
  'delta.minReaderVersion'          = '3',
  'delta.minWriterVersion'          = '7',
  'delta.parquet.compression.codec' = 'zstd'
);"""

for t, ddl in DDLS.items():
    spark.sql(f"DROP TABLE IF EXISTS {CAT}.{SILVER}.{t}")
    spark.sql(ddl.format(CAT=CAT, SILVER=SILVER))
    print("created silver", t)
