-- ######################################################################
-- # DDL Generated from UC Metadata Enrichment Workbook
-- # Source: UC_Metadata_Enrichment_Workbook.xlsx
-- ######################################################################

-- ======================================================================
-- DDL for d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
-- Generated from UC Metadata Enrichment workbook
-- ======================================================================

-- 1. Table comment
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  SET TBLPROPERTIES ('comment' = 'Master list of counterparty entities facing TD across all trading and lending activity. One row per counterparty.');

-- 2. Table-level tags
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  SET TAGS (
  'product_name' = 'counterparty_master',
  'product_version' = '1.4.0',
  'product_owner' = 'counterparty_reference_team',
  'product_owner_contact' = 'cpty-ref@td.com',
  'grain_keys' = 'counterparty_code',
  'source_system' = 'GoldenSource_CDM v3.1',
  'source_table' = 'gs.cdm.party_master',
  'refresh_frequency' = 'daily',
  'attested_by' = 'j.smith',
  'attested_on' = '2026-05-01',
  'contract_status' = 'published_v1.4.0',
  'expected_row_count' = '10 — 50',
  'data_classification' = 'Confidential — Internal'
  );

-- 3. Primary key (informational, NOT ENFORCED)
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ADD CONSTRAINT pk_dim_counterparty PRIMARY KEY (counterparty_code) NOT ENFORCED;

-- 4. Foreign keys (informational, NOT ENFORCED)
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ADD CONSTRAINT fk_dim_counterparty_ultimate_parent_lei
    FOREIGN KEY (ultimate_parent_lei)
    REFERENCES d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_legal_entity(lei_code)
    NOT ENFORCED;

-- 5a. Check constraints — allowed values
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ADD CONSTRAINT chk_regulatory_regime_values
    CHECK (regulatory_regime IN ('OSFI', 'EMIR', 'SEC', 'CBIRC', 'JFSA', 'CFTC'));

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ADD CONSTRAINT chk_td_entity_name_values
    CHECK (td_entity_name IN ('TD Securities Inc', 'TD Bank NA', 'TD Securities International'));

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ADD CONSTRAINT chk_counterparty_rating_values
    CHECK (counterparty_rating IN ('AAA', 'AA+', 'AA', 'AA-', 'A+', 'A', 'A-', 'BBB+', 'BBB', 'BBB-', 'BB+', 'BB', 'BB-', 'NR'));

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ADD CONSTRAINT chk_governing_law_values
    CHECK (governing_law IN ('English', 'New York', 'Ontario', 'French', 'German', 'Japanese'));

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ADD CONSTRAINT chk_organisation_type_values
    CHECK (organisation_type IN ('Bank', 'Broker-Dealer', 'Asset Manager', 'Corporate', 'Sovereign', 'Insurance', 'Pension Fund', 'Hedge Fund'));

-- 5b. Check constraints — format / regex
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ADD CONSTRAINT chk_counterparty_code_format
    CHECK (counterparty_code RLIKE '^[A-Z]{4}$');

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ADD CONSTRAINT chk_ultimate_parent_lei_format
    CHECK (ultimate_parent_lei RLIKE '^[0-9A-Z]{20}$');

-- 6. Column comments
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN counterparty_code COMMENT 'Internal alphanumeric code uniquely identifying a counterparty.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN counterparty_legal_name COMMENT 'Full legal name as registered with regulators.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN regulatory_regime COMMENT 'Margin regulator governing this counterparty.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN td_entity_name COMMENT 'TD legal entity facing this counterparty.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN counterparty_rating COMMENT 'External credit rating, mapped to internal scale.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN governing_law COMMENT 'Governing law jurisdiction of the master agreement.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN organisation_type COMMENT 'Type of organisation.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN ultimate_parent_lei COMMENT 'LEI of the ultimate parent legal entity.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN primary_contact_email COMMENT 'Primary relationship-manager email on the TD side.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN load_timestamp COMMENT 'When the row was loaded.';

-- 7. Column-level tags
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN counterparty_code SET TAGS (
  'role' = 'key',
  'business_name' = 'Counterparty Code',
  'source_of_truth' = 'GoldenSource party_id'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN counterparty_legal_name SET TAGS (
  'role' = 'property',
  'business_name' = 'Counterparty Legal Name',
  'source_of_truth' = 'GoldenSource party_name'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN regulatory_regime SET TAGS (
  'role' = 'classifier',
  'business_name' = 'Regulatory Regime',
  'source_of_truth' = 'GoldenSource regulatory_jurisdiction'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN td_entity_name SET TAGS (
  'role' = 'classifier',
  'business_name' = 'TD Entity Name',
  'source_of_truth' = 'TD Legal Entity Registry'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN counterparty_rating SET TAGS (
  'role' = 'classifier',
  'business_name' = 'Counterparty Rating',
  'source_of_truth' = 'Internal Credit Ratings DB'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN governing_law SET TAGS (
  'role' = 'classifier',
  'business_name' = 'Governing Law',
  'source_of_truth' = 'Legal Docs system'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN organisation_type SET TAGS (
  'role' = 'classifier',
  'business_name' = 'Organisation Type',
  'source_of_truth' = 'GoldenSource org_type'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN ultimate_parent_lei SET TAGS (
  'role' = 'foreign_key',
  'business_name' = 'Ultimate Parent LEI',
  'fk_references' = 'd4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_legal_entity.lei_code',
  'fk_cardinality' = 'many_to_one',
  'referential_integrity' = 'best_effort',
  'source_of_truth' = 'GLEIF'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN primary_contact_email SET TAGS (
  'role' = 'property',
  'business_name' = 'Primary Contact Email',
  'source_of_truth' = 'TD Salesforce CRM'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty
  ALTER COLUMN load_timestamp SET TAGS (
  'role' = 'audit',
  'business_name' = 'Load Timestamp',
  'source_of_truth' = 'ETL pipeline'
  );

-- ======================================================================
-- Verify — read back the metadata that was applied
-- ======================================================================

-- Table-level tags
SELECT * FROM system.information_schema.table_tags
WHERE catalog_name = 'd4001_centralus_tdvip_creditrisk' AND schema_name = 'xvala_xva'
  AND table_name = 'star_dim_counterparty';

-- Column-level tags
SELECT * FROM system.information_schema.column_tags
WHERE catalog_name = 'd4001_centralus_tdvip_creditrisk' AND schema_name = 'xvala_xva'
  AND table_name = 'star_dim_counterparty';

-- Constraints
SELECT * FROM system.information_schema.table_constraints
WHERE table_catalog = 'd4001_centralus_tdvip_creditrisk' AND table_schema = 'xvala_xva'
  AND table_name = 'star_dim_counterparty';


-- ======================================================================
-- DDL for d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
-- Generated from UC Metadata Enrichment workbook
-- ======================================================================

-- 1. Table comment
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  SET TBLPROPERTIES ('comment' = 'Daily snapshot of indirect issuer exposure from collateral postings. One row per (agreement, counterparty, as-of-date, issuer).');

-- 2. Table-level tags
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  SET TAGS (
  'product_name' = 'issuer_exposure',
  'product_version' = '3.2.1',
  'product_owner' = 'ccr_engine_team',
  'product_owner_contact' = 'ccr-eng@td.com',
  'grain_keys' = 'agreement_id, counterparty_code, as_of_date, issuer_name',
  'default_measure_grain' = 'agreement_id, counterparty_code, as_of_date, issuer_name',
  'source_system' = 'CCR_ENGINE v4.2',
  'source_table' = 'ccr.outputs.issuer_exposure_daily',
  'refresh_frequency' = 'daily',
  'as_of_date_column' = 'as_of_date',
  'attested_by' = 'm.patel',
  'attested_on' = '2026-04-15',
  'contract_status' = 'published_v3.2.1',
  'expected_row_count' = '30 — 100 per as_of_date',
  'data_classification' = 'Confidential — Internal'
  );

-- 3. Primary key (informational, NOT ENFORCED)
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ADD CONSTRAINT pk_fact_issuer_exposure PRIMARY KEY (issuer_exposure_key) NOT ENFORCED;

-- 4. Foreign keys (informational, NOT ENFORCED)
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ADD CONSTRAINT fk_fact_issuer_exposure_agreement_id
    FOREIGN KEY (agreement_id)
    REFERENCES d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_agreement(agreement_id)
    NOT ENFORCED;
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ADD CONSTRAINT fk_fact_issuer_exposure_counterparty_code
    FOREIGN KEY (counterparty_code)
    REFERENCES d4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty(counterparty_code)
    NOT ENFORCED;

-- 5a. Check constraints — allowed values
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ADD CONSTRAINT chk_issuer_type_values
    CHECK (issuer_type IN ('Sovereign', 'Bank', 'Corporate', 'Supranational', 'Agency'));

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ADD CONSTRAINT chk_issuer_rating_values
    CHECK (issuer_rating IN ('AAA', 'AA+', 'AA', 'AA-', 'A+', 'A', 'A-', 'BBB+', 'BBB', 'BBB-', 'BB+', 'BB', 'BB-', 'NR'));

-- 5b. Check constraints — format / regex
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ADD CONSTRAINT chk_agreement_id_format
    CHECK (agreement_id RLIKE '^AGR-[0-9]{3}$');

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ADD CONSTRAINT chk_counterparty_code_format
    CHECK (counterparty_code RLIKE '^[A-Z]{4}$');

-- 6. Column comments
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN issuer_exposure_key COMMENT 'Synthetic unique identifier for each issuer exposure row.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN agreement_id COMMENT 'Identifier of the collateral agreement under which exposure arose.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN counterparty_code COMMENT 'Counterparty facing TD under this exposure.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN as_of_date COMMENT 'Calculation snapshot date.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN issuer_name COMMENT 'Name of the issuer of the collateral instrument.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN issuer_type COMMENT 'Type of issuer.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN issuer_rating COMMENT 'External credit rating of the issuer at as_of_date.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN collateral_value COMMENT 'Market value of collateral posted, USD-equivalent at as_of_date FX.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN indirect_exposure COMMENT 'Indirect exposure to the issuer arising from the collateral, USD-equivalent.';
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN load_timestamp COMMENT 'When this row was loaded.';

-- 7. Column-level tags
ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN issuer_exposure_key SET TAGS (
  'role' = 'key',
  'business_name' = 'Issuer Exposure Key',
  'source_of_truth' = 'Generated by CCR engine'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN agreement_id SET TAGS (
  'role' = 'foreign_key',
  'business_name' = 'Agreement ID',
  'fk_references' = 'd4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_agreement.agreement_id',
  'fk_cardinality' = 'many_to_one',
  'referential_integrity' = 'guaranteed',
  'source_of_truth' = 'CCR engine input'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN counterparty_code SET TAGS (
  'role' = 'foreign_key',
  'business_name' = 'Counterparty Code',
  'fk_references' = 'd4001_centralus_tdvip_creditrisk.xvala_xva.star_dim_counterparty.counterparty_code',
  'fk_cardinality' = 'many_to_one',
  'referential_integrity' = 'guaranteed',
  'source_of_truth' = 'GoldenSource party_id'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN as_of_date SET TAGS (
  'role' = 'key',
  'business_name' = 'As Of Date',
  'source_of_truth' = 'CCR engine run date'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN issuer_name SET TAGS (
  'role' = 'classifier',
  'business_name' = 'Issuer Name',
  'source_of_truth' = 'Collateral instrument reference data'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN issuer_type SET TAGS (
  'role' = 'classifier',
  'business_name' = 'Issuer Type',
  'source_of_truth' = 'Collateral instrument reference data'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN issuer_rating SET TAGS (
  'role' = 'classifier',
  'business_name' = 'Issuer Rating',
  'source_of_truth' = 'External ratings feed'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN collateral_value SET TAGS (
  'role' = 'measure',
  'business_name' = 'Collateral Value',
  'source_of_truth' = 'CCR engine output',
  'measure_grain' = 'agreement_id, counterparty_code, as_of_date, issuer_name',
  'measure_unit' = 'USD',
  'measure_methodology' = 'CCR_ENGINE_v4.2',
  'agg_across_counterparty' = 'sum',
  'agg_across_agreement' = 'sum',
  'agg_across_issuer' = 'sum',
  'agg_across_date' = 'latest'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN indirect_exposure SET TAGS (
  'role' = 'measure',
  'business_name' = 'Indirect Exposure',
  'source_of_truth' = 'CCR engine output',
  'measure_grain' = 'agreement_id, counterparty_code, as_of_date, issuer_name',
  'measure_unit' = 'USD',
  'measure_methodology' = 'CCR_ENGINE_v4.2',
  'agg_across_counterparty' = 'sum',
  'agg_across_agreement' = 'sum',
  'agg_across_issuer' = 'sum',
  'agg_across_date' = 'latest'
  );

ALTER TABLE d4001_centralus_tdvip_creditrisk.xvala_xva.star_fact_issuer_exposure
  ALTER COLUMN load_timestamp SET TAGS (
  'role' = 'audit',
  'business_name' = 'Load Timestamp',
  'source_of_truth' = 'ETL pipeline'
  );

-- ======================================================================
-- Verify — read back the metadata that was applied
-- ======================================================================

-- Table-level tags
SELECT * FROM system.information_schema.table_tags
WHERE catalog_name = 'd4001_centralus_tdvip_creditrisk' AND schema_name = 'xvala_xva'
  AND table_name = 'star_fact_issuer_exposure';

-- Column-level tags
SELECT * FROM system.information_schema.column_tags
WHERE catalog_name = 'd4001_centralus_tdvip_creditrisk' AND schema_name = 'xvala_xva'
  AND table_name = 'star_fact_issuer_exposure';

-- Constraints
SELECT * FROM system.information_schema.table_constraints
WHERE table_catalog = 'd4001_centralus_tdvip_creditrisk' AND table_schema = 'xvala_xva'
  AND table_name = 'star_fact_issuer_exposure';
