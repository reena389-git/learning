-- ================================================================
-- SYNTHETIC DATA V2 — CCR POC ENHANCED
-- Catalog: `d4001-centralus-tdvip-creditrisk`.xvala_xva
-- Changes from V1:
--   1. Extended time series — Jan to Jun 2026 (6 months)
--   2. Name anomaly tables with 10+ variants for GSCO and JPMC
--   3. Legal entity / ultimate parent hierarchy
--   4. Hidden exposure fact table (the "aha moment")
-- ================================================================

-- ================================================================
-- SECTION A: EXTEND EXISTING STAR SCHEMA
-- Add Apr, May, Jun 2026 dates + fact rows for time series
-- ================================================================

-- New dates
INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_date
  (as_of_date, day_num, month_num, month_name, quarter_name, year_num, is_month_end)
VALUES
  ('2026-04-15', 15, 4, 'April', 'Q2-2026', 2026, false),
  ('2026-04-30', 30, 4, 'April', 'Q2-2026', 2026, true),
  ('2026-05-15', 15, 5, 'May',   'Q2-2026', 2026, false),
  ('2026-05-30', 30, 5, 'May',   'Q2-2026', 2026, true),
  ('2026-06-13', 13, 6, 'June',  'Q2-2026', 2026, false),
  ('2026-06-30', 30, 6, 'June',  'Q2-2026', 2026, true);

-- New fact rows — April 2026
-- GSCO trending UP (worsening breach)
-- JPMC trending UP (approaching threshold)
-- BCCU trending UP
-- MSSF volatile
-- RBCS flat/declining (safe)
INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_collateral_exposure
  (event_id, agreement_id, counterparty_code, as_of_date, csa_type_key,
   margin_type, call_status, action, reporting_currency,
   base_total_exposure, itm_exposure, otm_exposure,
   base_call_amount, agreed_amount, im_requirement,
   threshold_principal, threshold_counterparty,
   min_transfer_principal, min_transfer_cp,
   dispute_amount, dispute_age, is_disputed)
VALUES
-- GSCO April — exposure climbing
  ('EVT-005-0415','AGR-005','GSCO','2026-04-15',1,'VM','Agreed',               'Call','USD', 33200000.00, 37500000.00,-4300000.00, 23200000.00,23200000.00,NULL,10000000.00,10000000.00,250000.00,250000.00,NULL,       0,false),
  ('EVT-005-0430','AGR-005','GSCO','2026-04-30',1,'VM','Margin Request Issued','Call','USD', 44800000.00, 50100000.00,-5300000.00, 34800000.00,32000000.00,NULL,10000000.00,10000000.00,250000.00,250000.00,2800000.00,7,true),
-- GSCO May — further climb
  ('EVT-005-0515','AGR-005','GSCO','2026-05-15',1,'VM','Agreed',               'Call','USD', 38600000.00, 43200000.00,-4600000.00, 28600000.00,28600000.00,NULL,10000000.00,10000000.00,250000.00,250000.00,NULL,       0,false),
  ('EVT-005-0530','AGR-005','GSCO','2026-05-30',1,'VM','Margin Request Issued','Call','USD', 51200000.00, 57000000.00,-5800000.00, 41200000.00,38500000.00,NULL,10000000.00,10000000.00,250000.00,250000.00,2700000.00,4,true),
-- GSCO June — peak exposure
  ('EVT-005-0613','AGR-005','GSCO','2026-06-13',1,'VM','Agreed',               'Call','USD', 46400000.00, 51800000.00,-5400000.00, 36400000.00,36400000.00,NULL,10000000.00,10000000.00,250000.00,250000.00,NULL,       0,false),
  ('EVT-005-0630','AGR-005','GSCO','2026-06-30',1,'VM','Margin Request Issued','Call','USD', 58900000.00, 65200000.00,-6300000.00, 48900000.00,45000000.00,NULL,10000000.00,10000000.00,250000.00,250000.00,3900000.00,8,true),

-- JPMC April — creeping up toward threshold
  ('EVT-006-0415','AGR-006','JPMC','2026-04-15',1,'VM','Agreed',               'Call','CAD', 19600000.00, 23400000.00,-3800000.00,  4600000.00, 4600000.00,NULL,15000000.00,12000000.00,100000.00,100000.00,NULL,       0,false),
  ('EVT-006-0430','AGR-006','JPMC','2026-04-30',1,'VM','Margin Request Issued','Call','CAD', 23800000.00, 28200000.00,-4400000.00,  8800000.00, 8200000.00,NULL,15000000.00,12000000.00,100000.00,100000.00,600000.00, 2,true),
-- JPMC May — nudging threshold
  ('EVT-006-0515','AGR-006','JPMC','2026-05-15',1,'VM','Agreed',               'Call','CAD', 21400000.00, 25600000.00,-4200000.00,  6400000.00, 6400000.00,NULL,15000000.00,12000000.00,100000.00,100000.00,NULL,       0,false),
  ('EVT-006-0530','AGR-006','JPMC','2026-05-30',1,'VM','Margin Request Issued','Call','CAD', 26200000.00, 31000000.00,-4800000.00, 11200000.00,10500000.00,NULL,15000000.00,12000000.00,100000.00,100000.00,700000.00, 3,true),
-- JPMC June — at threshold
  ('EVT-006-0613','AGR-006','JPMC','2026-06-13',1,'VM','Agreed',               'Call','CAD', 24100000.00, 28800000.00,-4700000.00,  9100000.00, 9100000.00,NULL,15000000.00,12000000.00,100000.00,100000.00,NULL,       0,false),
  ('EVT-006-0630','AGR-006','JPMC','2026-06-30',1,'VM','Margin Request Issued','Call','CAD', 28900000.00, 34100000.00,-5200000.00, 13900000.00,13000000.00,NULL,15000000.00,12000000.00,100000.00,100000.00,900000.00, 5,true),

-- BCCU April-June — volatile upward
  ('EVT-001-0415','AGR-001','BCCU','2026-04-15',1,'VM','Agreed',               'Call','CAD', 21400000.00, 24800000.00,-3400000.00, 11400000.00,11400000.00,NULL,10000000.00, 8000000.00,100000.00,100000.00,NULL,       0,false),
  ('EVT-001-0430','AGR-001','BCCU','2026-04-30',1,'VM','Margin Request Issued','Call','CAD', 27300000.00, 31200000.00,-3900000.00, 17300000.00,16000000.00,NULL,10000000.00, 8000000.00,100000.00,100000.00,1300000.00,4,true),
  ('EVT-001-0515','AGR-001','BCCU','2026-05-15',1,'VM','Agreed',               'Call','CAD', 23800000.00, 27600000.00,-3800000.00, 13800000.00,13800000.00,NULL,10000000.00, 8000000.00,100000.00,100000.00,NULL,       0,false),
  ('EVT-001-0530','AGR-001','BCCU','2026-05-30',1,'VM','Margin Request Issued','Call','CAD', 29400000.00, 33800000.00,-4400000.00, 19400000.00,18000000.00,NULL,10000000.00, 8000000.00,100000.00,100000.00,1400000.00,6,true),
  ('EVT-001-0613','AGR-001','BCCU','2026-06-13',1,'VM','Agreed',               'Call','CAD', 26100000.00, 30200000.00,-4100000.00, 16100000.00,16100000.00,NULL,10000000.00, 8000000.00,100000.00,100000.00,NULL,       0,false),
  ('EVT-001-0630','AGR-001','BCCU','2026-06-30',1,'VM','Margin Request Issued','Call','CAD', 31800000.00, 36400000.00,-4600000.00, 21800000.00,20200000.00,NULL,10000000.00, 8000000.00,100000.00,100000.00,1600000.00,3,true),

-- RBCS April-June — flat/declining (safe story)
  ('EVT-012-0415','AGR-012','RBCS','2026-04-15',1,'VM','No Call','None','CAD', 13200000.00, 16100000.00,-2900000.00,NULL,NULL,NULL,20000000.00,15000000.00,100000.00,100000.00,NULL,0,false),
  ('EVT-012-0430','AGR-012','RBCS','2026-04-30',1,'VM','No Call','None','CAD', 11800000.00, 14600000.00,-2800000.00,NULL,NULL,NULL,20000000.00,15000000.00,100000.00,100000.00,NULL,0,false),
  ('EVT-012-0515','AGR-012','RBCS','2026-05-15',1,'VM','No Call','None','CAD', 10400000.00, 13100000.00,-2700000.00,NULL,NULL,NULL,20000000.00,15000000.00,100000.00,100000.00,NULL,0,false),
  ('EVT-012-0530','AGR-012','RBCS','2026-05-30',1,'VM','No Call','None','CAD',  9200000.00, 11900000.00,-2700000.00,NULL,NULL,NULL,20000000.00,15000000.00,100000.00,100000.00,NULL,0,false),
  ('EVT-012-0613','AGR-012','RBCS','2026-06-13',1,'VM','No Call','None','CAD',  8100000.00, 10700000.00,-2600000.00,NULL,NULL,NULL,20000000.00,15000000.00,100000.00,100000.00,NULL,0,false),
  ('EVT-012-0630','AGR-012','RBCS','2026-06-30',1,'VM','No Call','None','CAD',  7400000.00,  9900000.00,-2500000.00,NULL,NULL,NULL,20000000.00,15000000.00,100000.00,100000.00,NULL,0,false),

-- MSSF April-June — volatile
  ('EVT-011-0415','AGR-011','MSSF','2026-04-15',1,'VM','Agreed',               'Call','USD', 22400000.00, 26100000.00,-3700000.00, 12400000.00,12400000.00,NULL,10000000.00,10000000.00,150000.00,150000.00,NULL,       0,false),
  ('EVT-011-0430','AGR-011','MSSF','2026-04-30',1,'VM','Margin Request Issued','Call','USD', 31600000.00, 36200000.00,-4600000.00, 21600000.00,19800000.00,NULL,10000000.00,10000000.00,150000.00,150000.00,1800000.00,5,true),
  ('EVT-011-0515','AGR-011','MSSF','2026-05-15',1,'VM','Agreed',               'Call','USD', 18900000.00, 22400000.00,-3500000.00,  8900000.00, 8900000.00,NULL,10000000.00,10000000.00,150000.00,150000.00,NULL,       0,false),
  ('EVT-011-0530','AGR-011','MSSF','2026-05-30',1,'VM','Margin Request Issued','Call','USD', 34200000.00, 39100000.00,-4900000.00, 24200000.00,22400000.00,NULL,10000000.00,10000000.00,150000.00,150000.00,1800000.00,3,true),
  ('EVT-011-0613','AGR-011','MSSF','2026-06-13',1,'VM','Agreed',               'Call','USD', 27800000.00, 32400000.00,-4600000.00, 17800000.00,17800000.00,NULL,10000000.00,10000000.00,150000.00,150000.00,NULL,       0,false),
  ('EVT-011-0630','AGR-011','MSSF','2026-06-30',1,'VM','Margin Request Issued','Call','USD', 38600000.00, 44100000.00,-5500000.00, 28600000.00,26400000.00,NULL,10000000.00,10000000.00,150000.00,150000.00,2200000.00,6,true);


-- ================================================================
-- SECTION B: star_dim_legal_entity
-- Ultimate Parent → Legal Entity → Counterparty hierarchy
-- ================================================================

CREATE TABLE IF NOT EXISTS `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_legal_entity (
  lei_code                STRING,
  ultimate_parent_lei     STRING,
  ultimate_parent_name    STRING,
  legal_entity_name       STRING,
  counterparty_code       STRING,
  entity_type             STRING,
  incorporation_country   STRING,
  regulatory_jurisdiction STRING,
  is_ultimate_parent      BOOLEAN
);

INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_legal_entity VALUES
-- Goldman Sachs
('LEI-GS-001','LEI-GS-000','Goldman Sachs Group Inc',        'Goldman Sachs & Co LLC',             'GSCO','Broker Dealer',  'US','SEC', false),
('LEI-GS-000','LEI-GS-000','Goldman Sachs Group Inc',        'Goldman Sachs Group Inc',            'GSCO','Holding Company','US','SEC', true),
-- JPMorgan
('LEI-JP-001','LEI-JP-000','JPMorgan Chase & Co',            'JPMorgan Chase Bank NA',             'JPMC','Bank',           'US','OSFI',false),
('LEI-JP-000','LEI-JP-000','JPMorgan Chase & Co',            'JPMorgan Chase & Co',                'JPMC','Holding Company','US','OSFI',true),
-- BNPP
('LEI-BN-001','LEI-BN-000','BNP Paribas SA',                 'BNP Paribas SA',                     'BNPP','Bank',           'FR','EMIR',false),
('LEI-BN-000','LEI-BN-000','BNP Paribas SA',                 'BNP Paribas SA',                     'BNPP','Holding Company','FR','EMIR',true),
-- HSBC
('LEI-HS-001','LEI-HS-000','HSBC Holdings PLC',              'HSBC Bank PLC',                      'HSBC','Bank',           'GB','EMIR',false),
('LEI-HS-000','LEI-HS-000','HSBC Holdings PLC',              'HSBC Holdings PLC',                  'HSBC','Holding Company','GB','EMIR',true),
-- Morgan Stanley
('LEI-MS-001','LEI-MS-000','Morgan Stanley',                 'Morgan Stanley Smith Barney LLC',    'MSSF','Broker Dealer',  'US','SEC', false),
('LEI-MS-000','LEI-MS-000','Morgan Stanley',                 'Morgan Stanley',                     'MSSF','Holding Company','US','SEC', true),
-- Bank of China
('LEI-BC-001','LEI-BC-000','Bank of China Limited',          'Bank of China Canada',               'BCCU','Bank',           'CA','OSFI',false),
('LEI-BC-000','LEI-BC-000','Bank of China Limited',          'Bank of China Limited',              'BCCU','Holding Company','CN','OSFI',true),
-- Citibank
('LEI-CI-001','LEI-CI-000','Citigroup Inc',                  'Citibank NA',                        'CITB','Bank',           'US','SEC', false),
('LEI-CI-000','LEI-CI-000','Citigroup Inc',                  'Citigroup Inc',                      'CITB','Holding Company','US','SEC', true),
-- ING
('LEI-IN-001','LEI-IN-000','ING Groep NV',                   'ING Bank NV London Branch',          'INBL','Bank',           'NL','EMIR',false),
('LEI-IN-000','LEI-IN-000','ING Groep NV',                   'ING Groep NV',                       'INBL','Holding Company','NL','EMIR',true),
-- MUFG
('LEI-MU-001','LEI-MU-000','Mitsubishi UFJ Financial Group', 'MUFG Bank Ltd',                      'MUFG','Bank',           'JP','OSFI',false),
('LEI-MU-000','LEI-MU-000','Mitsubishi UFJ Financial Group', 'Mitsubishi UFJ Financial Group',     'MUFG','Holding Company','JP','OSFI',true),
-- RBC
('LEI-RB-001','LEI-RB-000','Royal Bank of Canada',           'Royal Bank of Canada',               'RBCS','Bank',           'CA','OSFI',false),
('LEI-RB-000','LEI-RB-000','Royal Bank of Canada',           'Royal Bank of Canada',               'RBCS','Holding Company','CA','OSFI',true);


-- ================================================================
-- SECTION C: star_dim_name_variants
-- 10+ variants per counterparty for GSCO and JPMC
-- Shows how names appear across different booking systems
-- ================================================================

CREATE TABLE IF NOT EXISTS `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_name_variants (
  variant_id        STRING,
  counterparty_code STRING,
  variant_name      STRING,
  source_system     STRING,
  variant_type      STRING,
  is_canonical      BOOLEAN,
  canonical_name    STRING,
  risk_impact       STRING   -- HIGH = large exposure under this variant
);

INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_name_variants VALUES

-- ── GOLDMAN SACHS — 11 variants ──────────────────────────────
('VAR-GS-01','GSCO','Goldman Sachs & Co LLC',         'MUREX',      'Canonical',       true, 'Goldman Sachs & Co LLC','NONE'),
('VAR-GS-02','GSCO','Goldman Sachs Co LLC',           'SUMMIT',     'Missing ampersand',false,'Goldman Sachs & Co LLC','HIGH'),
('VAR-GS-03','GSCO','GS & Co',                        'EXCEL',      'Abbreviated',     false,'Goldman Sachs & Co LLC','HIGH'),
('VAR-GS-04','GSCO','Goldman',                        'EMAIL',      'Truncated',       false,'Goldman Sachs & Co LLC','MEDIUM'),
('VAR-GS-05','GSCO','GOLDMAN SACHS & CO LLC',         'LEGACY_CRM', 'Uppercase',       false,'Goldman Sachs & Co LLC','HIGH'),
('VAR-GS-06','GSCO','Goldman Sachs & Company',        'WORD_DOC',   'Expanded',        false,'Goldman Sachs & Co LLC','MEDIUM'),
('VAR-GS-07','GSCO','Goldmann Sachs & Co LLC',        'SCANNED_DOC','OCR misspelling', false,'Goldman Sachs & Co LLC','HIGH'),
('VAR-GS-08','GSCO','G0ldman Sachs & Co LLC',         'SCANNED_DOC','OCR zero-for-o',  false,'Goldman Sachs & Co LLC','MEDIUM'),
('VAR-GS-09','GSCO','Goldman-Sachs',                  'BLOOMBERG',  'Hyphenated',      false,'Goldman Sachs & Co LLC','LOW'),
('VAR-GS-10','GSCO','GS_CO',                          'LEGACY_DB',  'Legacy system code',false,'Goldman Sachs & Co LLC','HIGH'),
('VAR-GS-11','GSCO','Goldman Sachs NY',               'INTERNAL',   'Geographic suffix',false,'Goldman Sachs & Co LLC','MEDIUM'),

-- ── JPMORGAN — 11 variants ───────────────────────────────────
('VAR-JP-01','JPMC','JPMorgan Chase Bank NA',         'MUREX',      'Canonical',       true, 'JPMorgan Chase Bank NA','NONE'),
('VAR-JP-02','JPMC','JP Morgan Chase Bank NA',        'SUMMIT',     'Space in name',   false,'JPMorgan Chase Bank NA','HIGH'),
('VAR-JP-03','JPMC','JPMorgan',                       'EXCEL',      'Truncated',       false,'JPMorgan Chase Bank NA','HIGH'),
('VAR-JP-04','JPMC','Chase',                          'EMAIL',      'Brand name only', false,'JPMorgan Chase Bank NA','HIGH'),
('VAR-JP-05','JPMC','JPMORGAN CHASE BANK NA',         'LEGACY_CRM', 'Uppercase',       false,'JPMorgan Chase Bank NA','HIGH'),
('VAR-JP-06','JPMC','J.P. Morgan Chase Bank',         'WORD_DOC',   'Punctuation',     false,'JPMorgan Chase Bank NA','MEDIUM'),
('VAR-JP-07','JPMC','JP Morgon Chase Bank NA',        'SCANNED_DOC','OCR misspelling', false,'JPMorgan Chase Bank NA','HIGH'),
('VAR-JP-08','JPMC','JPMorgan Chase & Co',            'BLOOMBERG',  'Parent name used',false,'JPMorgan Chase Bank NA','MEDIUM'),
('VAR-JP-09','JPMC','JPMCB',                          'LEGACY_DB',  'Legacy system code',false,'JPMorgan Chase Bank NA','HIGH'),
('VAR-JP-10','JPMC','JPMorgan Chase London',          'INTERNAL',   'Geographic suffix',false,'JPMorgan Chase Bank NA','MEDIUM'),
('VAR-JP-11','JPMC','J P Morgan Chase Bank National Association','LEGAL_DOC','Full legal name',false,'JPMorgan Chase Bank NA','LOW');


-- ================================================================
-- SECTION D: star_fact_name_anomaly_exposure
-- Hidden exposure booked under variant names
-- NOT in main fact table — the "missed" exposure
-- ================================================================

CREATE TABLE IF NOT EXISTS `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_name_anomaly_exposure (
  anomaly_id          STRING,
  variant_id          STRING,
  counterparty_code   STRING,
  booked_name         STRING,
  as_of_date          DATE,
  margin_type         STRING,
  base_total_exposure DECIMAL(18,2),
  base_call_amount    DECIMAL(18,2),
  im_requirement      DECIMAL(18,2),
  source_system       STRING,
  is_resolved         BOOLEAN
);

INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_name_anomaly_exposure VALUES

-- ── GOLDMAN SACHS hidden exposure ────────────────────────────
-- VAR-GS-02: "Goldman Sachs Co LLC" in SUMMIT — large exposure
('ANO-GS-001','VAR-GS-02','GSCO','Goldman Sachs Co LLC',   '2026-01-30','VM', 11200000.00, 8100000.00, 0.00,'SUMMIT',   false),
('ANO-GS-002','VAR-GS-02','GSCO','Goldman Sachs Co LLC',   '2026-02-27','VM', 12400000.00, 9200000.00, 0.00,'SUMMIT',   false),
('ANO-GS-003','VAR-GS-02','GSCO','Goldman Sachs Co LLC',   '2026-03-31','VM', 13800000.00,10400000.00, 0.00,'SUMMIT',   false),
('ANO-GS-004','VAR-GS-02','GSCO','Goldman Sachs Co LLC',   '2026-04-30','VM', 15200000.00,11600000.00, 0.00,'SUMMIT',   false),

-- VAR-GS-03: "GS & Co" in Excel spreadsheet
('ANO-GS-005','VAR-GS-03','GSCO','GS & Co',                '2026-01-30','VM',  7800000.00, 5600000.00, 0.00,'EXCEL',    false),
('ANO-GS-006','VAR-GS-03','GSCO','GS & Co',                '2026-02-27','VM',  8400000.00, 6100000.00, 0.00,'EXCEL',    false),
('ANO-GS-007','VAR-GS-03','GSCO','GS & Co',                '2026-03-31','VM',  9100000.00, 6700000.00, 0.00,'EXCEL',    false),
('ANO-GS-008','VAR-GS-03','GSCO','GS & Co',                '2026-04-30','VM',  9900000.00, 7300000.00, 0.00,'EXCEL',    false),

-- VAR-GS-05: "GOLDMAN SACHS & CO LLC" in legacy CRM — IM exposure
('ANO-GS-009','VAR-GS-05','GSCO','GOLDMAN SACHS & CO LLC', '2026-01-30','IM',  6400000.00, 0.00, 3800000.00,'LEGACY_CRM',false),
('ANO-GS-010','VAR-GS-05','GSCO','GOLDMAN SACHS & CO LLC', '2026-02-27','IM',  6900000.00, 0.00, 4100000.00,'LEGACY_CRM',false),
('ANO-GS-011','VAR-GS-05','GSCO','GOLDMAN SACHS & CO LLC', '2026-03-31','IM',  7500000.00, 0.00, 4400000.00,'LEGACY_CRM',false),
('ANO-GS-012','VAR-GS-05','GSCO','GOLDMAN SACHS & CO LLC', '2026-04-30','IM',  8200000.00, 0.00, 4800000.00,'LEGACY_CRM',false),

-- VAR-GS-07: "Goldmann Sachs" OCR error from scanned docs
('ANO-GS-013','VAR-GS-07','GSCO','Goldmann Sachs & Co LLC','2026-02-27','VM',  4200000.00, 3100000.00, 0.00,'SCANNED_DOC',false),
('ANO-GS-014','VAR-GS-07','GSCO','Goldmann Sachs & Co LLC','2026-03-31','VM',  4600000.00, 3400000.00, 0.00,'SCANNED_DOC',false),

-- VAR-GS-10: "GS_CO" legacy database code
('ANO-GS-015','VAR-GS-10','GSCO','GS_CO',                  '2026-03-31','VM',  5100000.00, 3800000.00, 0.00,'LEGACY_DB', false),
('ANO-GS-016','VAR-GS-10','GSCO','GS_CO',                  '2026-04-30','VM',  5600000.00, 4200000.00, 0.00,'LEGACY_DB', false),

-- ── JPMORGAN hidden exposure ─────────────────────────────────
-- VAR-JP-02: "JP Morgan Chase Bank NA" (space in name) — SUMMIT
('ANO-JP-001','VAR-JP-02','JPMC','JP Morgan Chase Bank NA','2026-01-30','VM',  9200000.00, 6800000.00, 0.00,'SUMMIT',   false),
('ANO-JP-002','VAR-JP-02','JPMC','JP Morgan Chase Bank NA','2026-02-27','VM',  9800000.00, 7300000.00, 0.00,'SUMMIT',   false),
('ANO-JP-003','VAR-JP-02','JPMC','JP Morgan Chase Bank NA','2026-03-31','VM', 10600000.00, 7900000.00, 0.00,'SUMMIT',   false),
('ANO-JP-004','VAR-JP-02','JPMC','JP Morgan Chase Bank NA','2026-04-30','VM', 11400000.00, 8600000.00, 0.00,'SUMMIT',   false),

-- VAR-JP-04: "Chase" — brand name used in emails
('ANO-JP-005','VAR-JP-04','JPMC','Chase',                  '2026-01-30','VM',  5800000.00, 4200000.00, 0.00,'EMAIL',    false),
('ANO-JP-006','VAR-JP-04','JPMC','Chase',                  '2026-02-27','VM',  6200000.00, 4600000.00, 0.00,'EMAIL',    false),
('ANO-JP-007','VAR-JP-04','JPMC','Chase',                  '2026-03-31','VM',  6800000.00, 5100000.00, 0.00,'EMAIL',    false),
('ANO-JP-008','VAR-JP-04','JPMC','Chase',                  '2026-04-30','VM',  7400000.00, 5600000.00, 0.00,'EMAIL',    false),

-- VAR-JP-07: "JP Morgon" OCR misspelling
('ANO-JP-009','VAR-JP-07','JPMC','JP Morgon Chase Bank NA','2026-02-27','VM',  3800000.00, 2800000.00, 0.00,'SCANNED_DOC',false),
('ANO-JP-010','VAR-JP-07','JPMC','JP Morgon Chase Bank NA','2026-03-31','VM',  4100000.00, 3100000.00, 0.00,'SCANNED_DOC',false),

-- VAR-JP-09: "JPMCB" legacy database code
('ANO-JP-011','VAR-JP-09','JPMC','JPMCB',                  '2026-03-31','VM',  3600000.00, 2700000.00, 0.00,'LEGACY_DB', false),
('ANO-JP-012','VAR-JP-09','JPMC','JPMCB',                  '2026-04-30','VM',  3900000.00, 2900000.00, 0.00,'LEGACY_DB', false),

-- VAR-JP-06: "J.P. Morgan Chase Bank" from Word documents
('ANO-JP-013','VAR-JP-06','JPMC','J.P. Morgan Chase Bank', '2026-01-30','VM',  4100000.00, 3000000.00, 0.00,'WORD_DOC', false),
('ANO-JP-014','VAR-JP-06','JPMC','J.P. Morgan Chase Bank', '2026-02-27','VM',  4400000.00, 3300000.00, 0.00,'WORD_DOC', false),
('ANO-JP-015','VAR-JP-06','JPMC','J.P. Morgan Chase Bank', '2026-03-31','VM',  4800000.00, 3600000.00, 0.00,'WORD_DOC', false),
('ANO-JP-016','VAR-JP-06','JPMC','J.P. Morgan Chase Bank', '2026-04-30','VM',  5200000.00, 3900000.00, 0.00,'WORD_DOC', false);


-- ================================================================
-- SECTION E: obt_name_anomaly_summary
-- Pre-aggregated summary for dashboard — Before vs After
-- This is the "aha moment" table
-- ================================================================

CREATE TABLE IF NOT EXISTS `d4001-centralus-tdvip-creditrisk`.xvala_xva.obt_name_anomaly_summary AS
WITH known_exposure AS (
  SELECT
    counterparty_code,
    as_of_date,
    SUM(base_total_exposure) AS known_exposure
  FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_collateral_exposure
  WHERE counterparty_code IN ('GSCO','JPMC')
  GROUP BY counterparty_code, as_of_date
),
hidden_exposure AS (
  SELECT
    ae.counterparty_code,
    ae.as_of_date,
    SUM(ae.base_total_exposure)  AS hidden_exposure,
    COUNT(DISTINCT ae.variant_id) AS variant_count,
    COUNT(DISTINCT nv.source_system) AS source_system_count
  FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_name_anomaly_exposure ae
  JOIN `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_name_variants nv
    ON ae.variant_id = nv.variant_id
  GROUP BY ae.counterparty_code, ae.as_of_date
)
SELECT
  k.counterparty_code,
  cp.counterparty_legal_name,
  le.ultimate_parent_name,
  k.as_of_date,
  k.known_exposure,
  COALESCE(h.hidden_exposure, 0)       AS hidden_exposure,
  k.known_exposure +
    COALESCE(h.hidden_exposure, 0)     AS true_total_exposure,
  cp.threshold_principal               AS threshold,
  COALESCE(h.variant_count, 0)         AS name_variants_found,
  COALESCE(h.source_system_count, 0)   AS source_systems_affected,
  -- Breach BEFORE name resolution
  CASE
    WHEN k.known_exposure > cp.threshold_principal
    THEN 'BREACH'
    ELSE 'Within Threshold'
  END                                  AS status_before_resolution,
  -- Breach AFTER name resolution
  CASE
    WHEN k.known_exposure +
         COALESCE(h.hidden_exposure,0) > cp.threshold_principal
    THEN 'BREACH'
    ELSE 'Within Threshold'
  END                                  AS status_after_resolution,
  -- Was there a status CHANGE?
  CASE
    WHEN k.known_exposure <= cp.threshold_principal
     AND k.known_exposure +
         COALESCE(h.hidden_exposure,0) > cp.threshold_principal
    THEN 'NEW BREACH DETECTED'
    WHEN k.known_exposure > cp.threshold_principal
     AND k.known_exposure +
         COALESCE(h.hidden_exposure,0) > cp.threshold_principal
    THEN 'BREACH WORSENED'
    ELSE 'NO CHANGE'
  END                                  AS resolution_impact
FROM known_exposure k
JOIN `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_counterparty cp
  ON k.counterparty_code = cp.counterparty_code
JOIN `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_legal_entity le
  ON k.counterparty_code = le.counterparty_code
  AND le.is_ultimate_parent = false
LEFT JOIN hidden_exposure h
  ON k.counterparty_code = h.counterparty_code
  AND k.as_of_date = h.as_of_date
ORDER BY k.counterparty_code, k.as_of_date;


-- ================================================================
-- VERIFICATION QUERIES
-- Run these to confirm data loaded correctly
-- ================================================================

-- Check row counts
SELECT 'star_dim_legal_entity'       AS tbl, COUNT(*) AS rows FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_legal_entity
UNION ALL
SELECT 'star_dim_name_variants',             COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_name_variants
UNION ALL
SELECT 'star_fact_name_anomaly_exposure',    COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_name_anomaly_exposure
UNION ALL
SELECT 'obt_name_anomaly_summary',          COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.obt_name_anomaly_summary
UNION ALL
SELECT 'star_dim_date (total)',              COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_dim_date
UNION ALL
SELECT 'star_fact_collateral_exposure (total)', COUNT(*) FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.star_fact_collateral_exposure;

-- The "aha moment" query — JPMC status change
SELECT
  counterparty_legal_name,
  ultimate_parent_name,
  as_of_date,
  known_exposure,
  hidden_exposure,
  true_total_exposure,
  threshold,
  name_variants_found,
  source_systems_affected,
  status_before_resolution,
  status_after_resolution,
  resolution_impact
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.obt_name_anomaly_summary
WHERE resolution_impact IN ('NEW BREACH DETECTED','BREACH WORSENED')
ORDER BY as_of_date, counterparty_code;
