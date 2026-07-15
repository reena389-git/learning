-- ============================================================================
-- COLLATERAL DOMAIN MODEL — DDL FOR POWERDESIGNER REVERSE-ENGINEERING  (v2)
-- Structure: 1) CREATE TABLEs (no inline FKs)  2) ALL relationships as
-- ALTER TABLE ADD CONSTRAINT at the end  3) COMMENT ON statements last.
-- Reverse engineer with:  File > Reverse Engineer > Database…
--   DBMS = PostgreSQL (any recent version) · "Using script files" · this file
-- Then: Tools > Generate Conceptual Data Model.
-- FK NOT NULL = exactly-one · FK NULL = zero-or-one (cardinality carrier).
-- ============================================================================

-- ================= 1. TABLES =================

CREATE TABLE td_entity (
  td_code            VARCHAR(20)  NOT NULL,
  legal_name         VARCHAR(200) NOT NULL,
  lei                CHAR(20),
  CONSTRAINT pk_td_entity PRIMARY KEY (td_code)
);

CREATE TABLE counterparty (
  cp_code            VARCHAR(20)  NOT NULL,
  legal_name         VARCHAR(200) NOT NULL,
  lei                CHAR(20),
  industry           VARCHAR(50),
  CONSTRAINT pk_counterparty PRIMARY KEY (cp_code)
);

CREATE TABLE credit_rating_snapshot (
  cp_code            VARCHAR(20)  NOT NULL,
  agency             VARCHAR(20)  NOT NULL,
  term               VARCHAR(5)   NOT NULL,
  as_of_date         DATE         NOT NULL,
  rating             VARCHAR(10)  NOT NULL,
  CONSTRAINT pk_rating PRIMARY KEY (cp_code, agency, term, as_of_date),
  CONSTRAINT chk_rating_term CHECK (term IN ('LT','ST'))
);

CREATE TABLE agreement_group (
  agreement_group_code VARCHAR(40) NOT NULL,
  group_name           VARCHAR(60),
  CONSTRAINT pk_agreement_group PRIMARY KEY (agreement_group_code)
);

CREATE TABLE legal_agreement (
  agreement_id       VARCHAR(20)  NOT NULL,
  agreement_group_code VARCHAR(40) NOT NULL,
  td_code            VARCHAR(20)  NOT NULL,
  cp_code            VARCHAR(20)  NOT NULL,
  agreement_type     VARCHAR(20)  NOT NULL,
  csa_id             VARCHAR(30),
  agreement_date     DATE,
  effective_date     DATE,
  status             VARCHAR(20),
  base_currency      CHAR(3),
  governing_law      VARCHAR(40),
  csa_direction      VARCHAR(20),
  td_rehypothecation VARCHAR(10),
  cp_rehypothecation VARCHAR(10),
  valuation_agent    VARCHAR(60),
  regulatory_regime  VARCHAR(60),
  CONSTRAINT pk_legal_agreement PRIMARY KEY (agreement_id),
  CONSTRAINT chk_agreement_type CHECK (agreement_type IN
    ('GENERAL_CSA','REG_VM','REG_IMC','REG_IMP','GMRA','GMSLA','PBA')),
  CONSTRAINT chk_agreement_status CHECK (status IN ('Active','Amended','Terminated'))
);

CREATE TABLE eligibility_entry (
  agreement_id        VARCHAR(20) NOT NULL,
  collateral_type     VARCHAR(80) NOT NULL,
  mutuality           VARCHAR(20) NOT NULL,
  eligible_cash       VARCHAR(10),
  eligible_security   VARCHAR(10),
  issuers             VARCHAR(200),
  maturity_term       VARCHAR(40),
  remaining_term      VARCHAR(40),
  valuation_percentage DECIMAL(6,3) NOT NULL,
  CONSTRAINT pk_eligibility PRIMARY KEY (agreement_id, collateral_type, mutuality)
);

CREATE TABLE threshold_entry (
  agreement_id        VARCHAR(20) NOT NULL,
  requirement_type    VARCHAR(20) NOT NULL,
  mutuality           VARCHAR(20) NOT NULL,
  margin_scope        VARCHAR(5)  NOT NULL,
  trigger_name        VARCHAR(60) NOT NULL,
  nav_or_rating       VARCHAR(10),
  rating_level_lt     VARCHAR(10),
  value_amount        DECIMAL(18,2),
  value_currency      CHAR(3),
  CONSTRAINT pk_threshold PRIMARY KEY (agreement_id, requirement_type, mutuality, margin_scope, trigger_name),
  CONSTRAINT chk_req_type CHECK (requirement_type IN ('THRESHOLD','MTA','IA','ROUNDING')),
  CONSTRAINT chk_thr_scope CHECK (margin_scope IN ('VM','IM')),
  CONSTRAINT chk_nav_or_rating CHECK (nav_or_rating IN ('RATING','NAV'))
);

CREATE TABLE interest_rate_term (
  agreement_id        VARCHAR(20) NOT NULL,
  currency            CHAR(3)     NOT NULL,
  interest_rate_paid  VARCHAR(40),
  spread_bps          INT,
  rate_floor          VARCHAR(20),
  mutuality           VARCHAR(20),
  CONSTRAINT pk_interest PRIMARY KEY (agreement_id, currency)
);

CREATE TABLE trade (
  trade_id            VARCHAR(40) NOT NULL,
  source_system       VARCHAR(20) NOT NULL,
  product_type        VARCHAR(40) NOT NULL,
  cp_code             VARCHAR(20),
  trade_date          DATE,
  effective_date      DATE,
  maturity_date       DATE,
  buy_sell            VARCHAR(4),
  notional_amount     DECIMAL(18,2),
  notional_currency   CHAR(3),
  pv_base_amount      DECIMAL(18,2),
  pv_base_currency    CHAR(3),
  valuation_date      DATE,
  underlying          VARCHAR(60),
  CONSTRAINT pk_trade PRIMARY KEY (trade_id, source_system)
);

CREATE TABLE trade_agreement_applicability (
  trade_id            VARCHAR(40) NOT NULL,
  source_system       VARCHAR(20) NOT NULL,
  agreement_id        VARCHAR(20) NOT NULL,
  margin_scope        VARCHAR(10) NOT NULL,
  im_model            VARCHAR(20),
  im_jurisdiction     VARCHAR(40),
  is_isda_trade       CHAR(1),
  has_exception       CHAR(1),
  has_override        CHAR(1),
  discard_reason      VARCHAR(100),
  CONSTRAINT pk_taa PRIMARY KEY (trade_id, source_system, agreement_id, margin_scope),
  CONSTRAINT chk_taa_scope CHECK (margin_scope IN ('VM','IM_COLLECT','IM_POST','CLEARED'))
);

CREATE TABLE margin_event (
  event_id            VARCHAR(20) NOT NULL,
  agreement_id        VARCHAR(20) NOT NULL,
  event_date          TIMESTAMP   NOT NULL,
  margin_scope        VARCHAR(5)  NOT NULL,
  reporting_currency  CHAR(3),
  CONSTRAINT pk_margin_event PRIMARY KEY (event_id),
  CONSTRAINT chk_event_scope CHECK (margin_scope IN ('VM','IM'))
);

CREATE TABLE exposure (
  event_id            VARCHAR(20) NOT NULL,
  itm_exposure        DECIMAL(18,2),
  otm_exposure        DECIMAL(18,2),
  total_exposure      DECIMAL(18,2) NOT NULL,
  applied_threshold   DECIMAL(18,2),
  applied_mta         DECIMAL(18,2),
  applied_ia          DECIMAL(18,2),
  applied_rounding    DECIMAL(18,2),
  CONSTRAINT pk_exposure PRIMARY KEY (event_id)
);

CREATE TABLE margin_call (
  event_id            VARCHAR(20) NOT NULL,
  action              VARCHAR(20) NOT NULL,
  call_amount         DECIMAL(18,2) NOT NULL,
  agreed_amount       DECIMAL(18,2),
  booked_first_leg    DECIMAL(18,2),
  booked_second_leg   DECIMAL(18,2),
  call_status         VARCHAR(30) NOT NULL,
  CONSTRAINT pk_margin_call PRIMARY KEY (event_id)
);

CREATE TABLE dispute (
  event_id            VARCHAR(20) NOT NULL,
  description         VARCHAR(200),
  dispute_amount      DECIMAL(18,2) NOT NULL,
  dispute_age_days    INT,
  action              VARCHAR(30),
  raised_time         TIMESTAMP,
  CONSTRAINT pk_dispute PRIMARY KEY (event_id)
);

CREATE TABLE asset (
  asset_id            VARCHAR(20) NOT NULL,
  asset_type          VARCHAR(60) NOT NULL,
  issuer              VARCHAR(100),
  currency            CHAR(3),
  CONSTRAINT pk_asset PRIMARY KEY (asset_id)
);

CREATE TABLE settlement_instruction (
  agreement_id        VARCHAR(20) NOT NULL,
  asset_type          VARCHAR(80) NOT NULL,
  bucket              VARCHAR(20) NOT NULL,
  instruction_type    VARCHAR(120) NOT NULL,
  prc_account_no      VARCHAR(40),
  prc_beneficiary_bank VARCHAR(80),
  prc_ultimate_custodian VARCHAR(80),
  cpty_account_no     VARCHAR(40),
  cpty_beneficiary_bank VARCHAR(80),
  cpty_ultimate_custodian VARCHAR(80),
  business_line       VARCHAR(20),
  CONSTRAINT pk_ssi PRIMARY KEY (agreement_id, asset_type, bucket, instruction_type)
);

CREATE TABLE collateral_movement (
  movement_id         VARCHAR(30) NOT NULL,
  agreement_id        VARCHAR(20) NOT NULL,
  event_id            VARCHAR(20),
  asset_id            VARCHAR(20) NOT NULL,
  movement_type       VARCHAR(20) NOT NULL,
  margin_scope        VARCHAR(5)  NOT NULL,
  amount              DECIMAL(18,2) NOT NULL,
  currency            CHAR(3),
  settlement_date     DATE,
  status              VARCHAR(20) NOT NULL,
  CONSTRAINT pk_movement PRIMARY KEY (movement_id),
  CONSTRAINT chk_mv_scope CHECK (margin_scope IN ('VM','IM'))
);

CREATE TABLE collateral_holding (
  agreement_id        VARCHAR(20) NOT NULL,
  asset_id            VARCHAR(20) NOT NULL,
  as_of_date          DATE        NOT NULL,
  position_type       VARCHAR(20) NOT NULL,
  reported_collateral_value DECIMAL(18,2) NOT NULL,
  CONSTRAINT pk_holding PRIMARY KEY (agreement_id, asset_id, as_of_date, position_type)
);

-- ================= 2. RELATIONSHIPS (all of them, table-level) =================

ALTER TABLE credit_rating_snapshot ADD CONSTRAINT fk_rating_cpty
  FOREIGN KEY (cp_code) REFERENCES counterparty (cp_code);

ALTER TABLE legal_agreement ADD CONSTRAINT fk_agr_group
  FOREIGN KEY (agreement_group_code) REFERENCES agreement_group (agreement_group_code);
ALTER TABLE legal_agreement ADD CONSTRAINT fk_agr_td
  FOREIGN KEY (td_code) REFERENCES td_entity (td_code);
ALTER TABLE legal_agreement ADD CONSTRAINT fk_agr_cpty
  FOREIGN KEY (cp_code) REFERENCES counterparty (cp_code);

ALTER TABLE eligibility_entry ADD CONSTRAINT fk_elig_agr
  FOREIGN KEY (agreement_id) REFERENCES legal_agreement (agreement_id);

ALTER TABLE threshold_entry ADD CONSTRAINT fk_thr_agr
  FOREIGN KEY (agreement_id) REFERENCES legal_agreement (agreement_id);

ALTER TABLE interest_rate_term ADD CONSTRAINT fk_int_agr
  FOREIGN KEY (agreement_id) REFERENCES legal_agreement (agreement_id);

ALTER TABLE trade ADD CONSTRAINT fk_trade_cpty
  FOREIGN KEY (cp_code) REFERENCES counterparty (cp_code);

ALTER TABLE trade_agreement_applicability ADD CONSTRAINT fk_taa_trade
  FOREIGN KEY (trade_id, source_system) REFERENCES trade (trade_id, source_system);
ALTER TABLE trade_agreement_applicability ADD CONSTRAINT fk_taa_agr
  FOREIGN KEY (agreement_id) REFERENCES legal_agreement (agreement_id);

ALTER TABLE margin_event ADD CONSTRAINT fk_event_agr
  FOREIGN KEY (agreement_id) REFERENCES legal_agreement (agreement_id);

ALTER TABLE exposure ADD CONSTRAINT fk_exp_event
  FOREIGN KEY (event_id) REFERENCES margin_event (event_id);

ALTER TABLE margin_call ADD CONSTRAINT fk_call_event
  FOREIGN KEY (event_id) REFERENCES margin_event (event_id);

ALTER TABLE dispute ADD CONSTRAINT fk_disp_event
  FOREIGN KEY (event_id) REFERENCES margin_event (event_id);

ALTER TABLE settlement_instruction ADD CONSTRAINT fk_ssi_agr
  FOREIGN KEY (agreement_id) REFERENCES legal_agreement (agreement_id);

ALTER TABLE collateral_movement ADD CONSTRAINT fk_mv_agr
  FOREIGN KEY (agreement_id) REFERENCES legal_agreement (agreement_id);
ALTER TABLE collateral_movement ADD CONSTRAINT fk_mv_event
  FOREIGN KEY (event_id) REFERENCES margin_event (event_id);
ALTER TABLE collateral_movement ADD CONSTRAINT fk_mv_asset
  FOREIGN KEY (asset_id) REFERENCES asset (asset_id);

ALTER TABLE collateral_holding ADD CONSTRAINT fk_hold_agr
  FOREIGN KEY (agreement_id) REFERENCES legal_agreement (agreement_id);
ALTER TABLE collateral_holding ADD CONSTRAINT fk_hold_asset
  FOREIGN KEY (asset_id) REFERENCES asset (asset_id);

-- ================= 3. COMMENTS (entity descriptions in PD) =================

COMMENT ON TABLE td_entity IS 'Our legal entity on the agreement (tdEntity/tdCode in TAMS).';
COMMENT ON TABLE counterparty IS 'External legal entity (cpCode). Golden record: client master. Example: BCCU / Central 1 Credit Union.';
COMMENT ON TABLE credit_rating_snapshot IS 'Multi-agency ratings over time. Threshold tiers are conditioned on these (rating OR NAV).';
COMMENT ON TABLE agreement_group IS 'The umbrella grouping the VM CSA and regulatory-IM agreements for one party pair (e.g. TDBK_BCCU_GEN).';
COMMENT ON TABLE legal_agreement IS 'The agreement. Subtypes via agreement_type: GENERAL_CSA, REG_VM, REG_IMC, REG_IMP, GMRA (repo), GMSLA (stock lending), PBA (prime). Build the inheritance from this list in the CDM. System of record: TAMS.';
COMMENT ON TABLE eligibility_entry IS 'CSA eligible-collateral schedule. valuationPercentage = 100 minus haircut — do not double-convert. Dependent on agreement.';
COMMENT ON TABLE threshold_entry IS 'Threshold / MTA / IA / rounding schedule, per requirement x party x scope, conditioned on RATING or NAV. Dependent on agreement.';
COMMENT ON TABLE interest_rate_term IS 'Interest paid on cash collateral, per currency. Dependent on agreement.';
COMMENT ON TABLE trade IS 'A transaction from the trading systems (Murex, Calypso). PV feeds exposure.';
COMMENT ON TABLE trade_agreement_applicability IS 'ASSOCIATIVE ENTITY: resolves the many-to-many Trade-Agreement (trade 1424 maps to REG_VM + REG_IMC + REG_IMP). Output of the TAMS rule engine: margin scope, IM model, jurisdiction, exceptions.';
COMMENT ON TABLE margin_event IS 'One daily margin cycle per agreement (event 390066). The spine: exposure, call and dispute all hang off it.';
COMMENT ON TABLE exposure IS 'The valued exposure for the event: ITM/OTM/total plus the schedule values as applied that day. Dependent on margin_event (1:1).';
COMMENT ON TABLE margin_call IS 'The demand produced by the event: amounts and lifecycle status. Dependent on margin_event (0..1 per event).';
COMMENT ON TABLE dispute IS 'FIRST-CLASS ENTITY: a disagreement on the call — what the exception agent investigates. Dependent on margin_event (0..1 per event).';
COMMENT ON TABLE asset IS 'The security or cash posted (SecMaster reference).';
COMMENT ON TABLE settlement_instruction IS 'Standing SSIs per agreement x asset type: accounts, banks, custodians for both parties. Dependent on agreement.';
COMMENT ON TABLE collateral_movement IS 'One transfer of one asset under EXACTLY ONE agreement. event_id NULL = answers no call (excess return, substitution) — the at-most-one cardinality. Purpose codes VM/IM/EXS/SUB.';
COMMENT ON TABLE collateral_holding IS 'Reported position snapshot. AXIOM: must reconcile to the sum of settled movements — a difference is a break. Dependent on agreement + asset.';
