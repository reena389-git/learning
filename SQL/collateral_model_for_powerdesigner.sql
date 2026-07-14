-- ============================================================================
-- COLLATERAL DOMAIN MODEL — DDL FOR POWERDESIGNER REVERSE-ENGINEERING
-- Derived from: agreements/trades/repo/dailyexposure/disputes/settlement CSVs
--               + TAMS.json / tams_csa_bulk / tams_ruleengine / TAS / CMOS JSONs
-- Purpose: import into PowerDesigner (File > Reverse Engineer > Database,
--          DBMS = ANSI Level 2 or SQL Server, "Using script files"), then
--          Tools > Generate Conceptual Data Model. Attributes are trimmed to
--          the model-relevant set; this is a MODEL, not a physical design.
-- Cardinality encoding: FK NOT NULL = exactly-one; FK NULL = zero-or-one.
-- ============================================================================

-- ---------- PARTIES ---------------------------------------------------------
CREATE TABLE td_entity (
  td_code            VARCHAR(20)  NOT NULL PRIMARY KEY,   -- TDBK
  legal_name         VARCHAR(200) NOT NULL,
  lei                CHAR(20)
);
COMMENT ON TABLE td_entity IS 'Our legal entity on the agreement (tdEntity/tdCode in TAMS).';

CREATE TABLE counterparty (
  cp_code            VARCHAR(20)  NOT NULL PRIMARY KEY,   -- BCCU, INBL
  legal_name         VARCHAR(200) NOT NULL,
  lei                CHAR(20),
  industry           VARCHAR(50)                          -- Principal Industry
);
COMMENT ON TABLE counterparty IS 'External legal entity (cpCode/cpShortCode). Golden record: client master.';

CREATE TABLE credit_rating_snapshot (
  cp_code            VARCHAR(20)  NOT NULL REFERENCES counterparty(cp_code),
  agency             VARCHAR(20)  NOT NULL,               -- SP, MOODYS, DBRS, Fitch, Internal
  term               VARCHAR(5)   NOT NULL CHECK (term IN ('LT','ST')),
  rating             VARCHAR(10)  NOT NULL,
  as_of_date         DATE         NOT NULL,
  PRIMARY KEY (cp_code, agency, term, as_of_date)
);
COMMENT ON TABLE credit_rating_snapshot IS 'Multi-agency ratings (the packed rating strings in agreements CSV, unpacked). Thresholds are conditioned on these.';

-- ---------- LEGAL LAYER ------------------------------------------------------
CREATE TABLE agreement_group (
  agreement_group_code VARCHAR(40) NOT NULL PRIMARY KEY,  -- TDBK_BCCU_GEN
  group_name           VARCHAR(60)                        -- Desk8
);
COMMENT ON TABLE agreement_group IS 'NEW ENTITY (from agreementGroupCode): the umbrella grouping the VM CSA and the regulatory-IM agreements for one TD entity / counterparty pair.';

CREATE TABLE legal_agreement (
  agreement_id       VARCHAR(20)  NOT NULL PRIMARY KEY,   -- 1689, 1424, 7730
  agreement_group_code VARCHAR(40) NOT NULL REFERENCES agreement_group(agreement_group_code),
  td_code            VARCHAR(20)  NOT NULL REFERENCES td_entity(td_code),
  cp_code            VARCHAR(20)  NOT NULL REFERENCES counterparty(cp_code),
  agreement_type     VARCHAR(20)  NOT NULL CHECK (agreement_type IN
                     ('GENERAL_CSA','REG_VM','REG_IMC','REG_IMP','GMRA','GMSLA','PBA')),
  csa_id             VARCHAR(30),                          -- TAMS CSAId
  agreement_category VARCHAR(30),                          -- ISDA CSA
  agreement_date     DATE,
  effective_date     DATE,
  status             VARCHAR(20) CHECK (status IN ('Active','Amended','Terminated')),
  base_currency      CHAR(3),
  governing_law      VARCHAR(40),
  csa_direction      VARCHAR(20),                          -- Bilateral / one-way
  reciprocity        VARCHAR(20),
  td_rehypothecation VARCHAR(10),
  cp_rehypothecation VARCHAR(10),
  td_segregation     VARCHAR(20),
  cp_segregation     VARCHAR(20),
  valuation_agent    VARCHAR(60),
  exposure_calculation VARCHAR(200),
  dispute_resolution_time VARCHAR(20),
  regulatory_regime  VARCHAR(60)
);
COMMENT ON TABLE legal_agreement IS 'The agreement (subtype via agreement_type: VM CSA, reg-IM CSAs, GMRA, GMSLA, PBA). System of record TAMS; CSA header fields from tams_csa_bulk.';

CREATE TABLE eligibility_entry (
  agreement_id        VARCHAR(20) NOT NULL REFERENCES legal_agreement(agreement_id),
  collateral_type     VARCHAR(80) NOT NULL,               -- 'US Treasury', 'CAD CASH'
  mutuality           VARCHAR(20) NOT NULL,               -- who may post: TD / CP / Both
  eligible_cash       VARCHAR(10),
  eligible_security   VARCHAR(10),
  issuers             VARCHAR(200),
  maturity_term       VARCHAR(40),
  remaining_term      VARCHAR(40),
  valuation_percentage DECIMAL(6,3) NOT NULL,             -- NOTE: 100 - haircut
  PRIMARY KEY (agreement_id, collateral_type, mutuality)
);
COMMENT ON TABLE eligibility_entry IS 'CSA eligible-collateral schedule (assetEligibilityList). valuationPercentage = 100 minus haircut — do not double-convert.';

CREATE TABLE threshold_entry (
  agreement_id        VARCHAR(20) NOT NULL REFERENCES legal_agreement(agreement_id),
  requirement_type    VARCHAR(20) NOT NULL CHECK (requirement_type IN
                      ('THRESHOLD','MTA','IA','ROUNDING')),
  mutuality           VARCHAR(20) NOT NULL,               -- obligated party
  margin_scope        VARCHAR(5)  NOT NULL CHECK (margin_scope IN ('VM','IM')),
  trigger_name        VARCHAR(60),
  nav_or_rating       VARCHAR(10) CHECK (nav_or_rating IN ('RATING','NAV')),
  rating_level_lt     VARCHAR(10),
  value_amount        DECIMAL(18,2),
  value_currency      CHAR(3),
  PRIMARY KEY (agreement_id, requirement_type, mutuality, margin_scope, trigger_name)
);
COMMENT ON TABLE threshold_entry IS 'Threshold/MTA/IA/rounding schedule (thresholdList + the Fixed/IM columns in agreements CSV). Conditioned on RATING or NAV (navOrRating) — the trigger axiom.';

CREATE TABLE interest_rate_term (
  agreement_id        VARCHAR(20) NOT NULL REFERENCES legal_agreement(agreement_id),
  currency            CHAR(3)     NOT NULL,
  interest_rate_paid  VARCHAR(40),
  spread_bps          INT,
  rate_floor          VARCHAR(20),
  mutuality           VARCHAR(20),
  PRIMARY KEY (agreement_id, currency)
);
COMMENT ON TABLE interest_rate_term IS 'NEW ENTITY (interestRateList): interest paid on cash collateral per currency.';

-- ---------- TRADES & APPLICABILITY ------------------------------------------
CREATE TABLE trade (
  trade_id            VARCHAR(40) NOT NULL,
  source_system       VARCHAR(20) NOT NULL,               -- MUREXFXO, CALYPSOCPG, CALYPSOIFI
  product_type        VARCHAR(40) NOT NULL,               -- FX Option, CDS, Repo
  cp_code             VARCHAR(20) REFERENCES counterparty(cp_code),
  trade_date          DATE,
  effective_date      DATE,
  maturity_date       DATE,
  buy_sell            VARCHAR(4),
  notional_amount     DECIMAL(18,2),
  notional_currency   CHAR(3),
  pv_base_amount      DECIMAL(18,2),                      -- Valuation Base Ccy Amount
  pv_base_currency    CHAR(3),
  valuation_date      DATE,
  underlying          VARCHAR(60),
  margin_treatment    VARCHAR(10),                        -- Net / Not-Net
  PRIMARY KEY (trade_id, source_system)
);
COMMENT ON TABLE trade IS 'A transaction from the TMS layer (trades + repo CSVs; repo = product_type Repo under a GMRA). PV feeds exposure.';

CREATE TABLE trade_agreement_applicability (
  trade_id            VARCHAR(40) NOT NULL,
  source_system       VARCHAR(20) NOT NULL,
  agreement_id        VARCHAR(20) NOT NULL REFERENCES legal_agreement(agreement_id),
  margin_scope        VARCHAR(10) NOT NULL CHECK (margin_scope IN
                      ('VM','IM_COLLECT','IM_POST','CLEARED')),
  im_model            VARCHAR(20),                        -- SIMM / Schedule (ruleengine)
  im_jurisdiction     VARCHAR(40),
  is_isda_trade       CHAR(1),
  has_exception       CHAR(1),
  has_override        CHAR(1),
  discard_reason      VARCHAR(100),
  PRIMARY KEY (trade_id, source_system, agreement_id, margin_scope),
  FOREIGN KEY (trade_id, source_system) REFERENCES trade(trade_id, source_system)
);
COMMENT ON TABLE trade_agreement_applicability IS 'NEW ASSOCIATIVE ENTITY: resolves the many-to-many between Trade and Agreement (trades CSV: 1424:REG_VM|7730:REG_IMC|7729:REG_IMP). Populated by the TAMS rule engine (tams_ruleengine_bulk) — IM model, jurisdiction, exceptions, overrides live here.';

-- ---------- DAILY MARGIN CYCLE ----------------------------------------------
CREATE TABLE margin_event (
  event_id            VARCHAR(20) NOT NULL PRIMARY KEY,   -- 390066
  agreement_id        VARCHAR(20) NOT NULL REFERENCES legal_agreement(agreement_id),
  event_date          TIMESTAMP   NOT NULL,
  margin_scope        VARCHAR(5)  NOT NULL CHECK (margin_scope IN ('VM','IM')),
  reporting_currency  CHAR(3)
);
COMMENT ON TABLE margin_event IS 'NEW ENTITY (Event Id in dailyexposure + disputes): one daily margin cycle per agreement — exposure, call and any dispute all hang off it.';

CREATE TABLE exposure (
  event_id            VARCHAR(20) NOT NULL PRIMARY KEY REFERENCES margin_event(event_id),
  itm_exposure        DECIMAL(18,2),
  otm_exposure        DECIMAL(18,2),
  total_exposure      DECIMAL(18,2) NOT NULL,
  applied_threshold   DECIMAL(18,2),
  applied_mta         DECIMAL(18,2),
  applied_ia          DECIMAL(18,2),
  applied_rounding    DECIMAL(18,2)
);
COMMENT ON TABLE exposure IS 'The valued exposure for the event (dailyexposure CSV): ITM/OTM/total plus the schedule values as applied that day.';

CREATE TABLE margin_call (
  event_id            VARCHAR(20) NOT NULL PRIMARY KEY REFERENCES margin_event(event_id),
  action              VARCHAR(20) NOT NULL,               -- Call / Recall / Return
  call_amount         DECIMAL(18,2) NOT NULL,
  agreed_amount       DECIMAL(18,2),
  booked_first_leg    DECIMAL(18,2),
  booked_second_leg   DECIMAL(18,2),
  call_status         VARCHAR(30) NOT NULL                -- Margin Request Issued / Pending Review / Agreed / Disputed
);
COMMENT ON TABLE margin_call IS 'The demand produced by the event: amounts and lifecycle status.';

CREATE TABLE dispute (
  event_id            VARCHAR(20) NOT NULL PRIMARY KEY REFERENCES margin_event(event_id),
  description         VARCHAR(200),
  dispute_amount      DECIMAL(18,2) NOT NULL,
  dispute_age_days    INT,
  action              VARCHAR(30),                        -- Pending Review / Under Investigation
  raised_time         TIMESTAMP
);
COMMENT ON TABLE dispute IS 'NEW FIRST-CLASS ENTITY (disputes CSV): a disagreement on the call — the object the exception agent investigates. Zero-or-one per event.';

-- ---------- ASSETS, MOVEMENTS, HOLDINGS, SETTLEMENT --------------------------
CREATE TABLE asset (
  asset_id            VARCHAR(20) NOT NULL PRIMARY KEY,   -- ISIN / CASH-CCY
  asset_type          VARCHAR(60) NOT NULL,
  issuer              VARCHAR(100),
  currency            CHAR(3)
);
COMMENT ON TABLE asset IS 'The security or cash posted (assetHoldings/assetMovements; SecMaster reference).';

CREATE TABLE settlement_instruction (
  agreement_id        VARCHAR(20) NOT NULL REFERENCES legal_agreement(agreement_id),
  asset_type          VARCHAR(80) NOT NULL,
  bucket              VARCHAR(20) NOT NULL,               -- Standard
  instruction_type    VARCHAR(120) NOT NULL,              -- NET Call/Return; NET Delivery/Recall...
  prc_account_no      VARCHAR(40),
  prc_beneficiary_bank VARCHAR(80),
  prc_ultimate_custodian VARCHAR(80),
  cpty_account_no     VARCHAR(40),
  cpty_beneficiary_bank VARCHAR(80),
  cpty_ultimate_custodian VARCHAR(80),
  business_line       VARCHAR(20),
  PRIMARY KEY (agreement_id, asset_type, bucket, instruction_type)
);
COMMENT ON TABLE settlement_instruction IS 'NEW FIRST-CLASS ENTITY (settlementinstructions CSV): standing SSIs per agreement x asset type — where movements physically settle (accounts, banks, custodians).';

CREATE TABLE collateral_movement (
  movement_id         VARCHAR(30) NOT NULL PRIMARY KEY,   -- Colline reference
  agreement_id        VARCHAR(20) NOT NULL REFERENCES legal_agreement(agreement_id),
  event_id            VARCHAR(20)     NULL REFERENCES margin_event(event_id),
  asset_id            VARCHAR(20) NOT NULL REFERENCES asset(asset_id),
  movement_type       VARCHAR(20) NOT NULL,               -- Delivery / Return / Recall
  margin_scope        VARCHAR(5)  NOT NULL CHECK (margin_scope IN ('VM','IM')),
  amount              DECIMAL(18,2) NOT NULL,
  currency            CHAR(3),
  settlement_date     DATE,
  status              VARCHAR(20) NOT NULL                -- Instructed / Settled / Failed
);
COMMENT ON TABLE collateral_movement IS 'One transfer of one asset under one agreement (assetMovements). event_id NULL = movements answering no call (excess return, substitution) — the at-most-one cardinality.';

CREATE TABLE collateral_holding (
  agreement_id        VARCHAR(20) NOT NULL REFERENCES legal_agreement(agreement_id),
  asset_id            VARCHAR(20) NOT NULL REFERENCES asset(asset_id),
  as_of_date          DATE        NOT NULL,
  position_type       VARCHAR(20) NOT NULL,               -- Posted / Received
  reported_collateral_value DECIMAL(18,2) NOT NULL,       -- post-valuation-% value
  PRIMARY KEY (agreement_id, asset_id, as_of_date, position_type)
);
COMMENT ON TABLE collateral_holding IS 'The reported position snapshot (assetHoldings). AXIOM: derivable from settled movements — reported and derived must reconcile; a difference is a break.';
