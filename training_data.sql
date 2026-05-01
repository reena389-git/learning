-- ================================================================
-- MICROSTRATEGY HANDS-ON TRAINING — SYNTHETIC DATA
-- Catalog: d4001-centralus-tdvip-creditrisk.xvala_xva
-- 
-- 3 tables only:
--   training_dim_counterparty  — 6 counterparties
--   training_dim_date          — 6 months
--   training_fact_trades       — 30 trades
--
-- JOIN DESIGN (no ambiguity):
--   training_fact_trades.counterparty_code 
--     → training_dim_counterparty.counterparty_code
--   training_fact_trades.trade_date        
--     → training_dim_date.trade_date
--
-- COLUMN NAMES are unique across all tables — no merges needed
-- ================================================================


-- ================================================================
-- TABLE 1: training_dim_counterparty
-- 6 counterparties — 3 matched, used for before/after story
-- ================================================================

CREATE TABLE IF NOT EXISTS 
  `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_counterparty (
  counterparty_code       STRING,   -- PK — e.g. GSCO
  canonical_name          STRING,   -- Goldman Sachs & Co LLC
  ultimate_parent         STRING,   -- Goldman Sachs Group Inc
  regulatory_regime       STRING,   -- OSFI / EMIR / SEC
  threshold_amount        DECIMAL(18,2),  -- Credit limit
  entity_search_field     STRING    -- Concatenated variants for fuzzy search
);

INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_counterparty VALUES

('GSCO',
 'Goldman Sachs & Co LLC',
 'Goldman Sachs Group Inc',
 'SEC',
 60000000.00,
 'Goldman Sachs & Co LLC Goldman Sachs Group Inc GS & Co GS_CO Goldman Sachs Co LLC Goldmann Sachs GOLDMAN SACHS Goldman Sachs NY Goldman-Sachs G.S. & Co'),

('JPMC',
 'JPMorgan Chase Bank NA',
 'JPMorgan Chase & Co',
 'OSFI',
 90000000.00,
 'JPMorgan Chase Bank NA JPMorgan Chase & Co Chase JP Morgan JPMCB JP Morgan Chase Bank NA JPMorgon J.P. Morgan JPMorgan Chase London'),

('HSBC',
 'HSBC Bank PLC',
 'HSBC Holdings PLC',
 'EMIR',
 30000000.00,
 'HSBC Bank PLC HSBC Holdings PLC HSBC Bank HSBC PLC HSBC London'),

('BNPP',
 'BNP Paribas SA',
 'BNP Paribas SA',
 'EMIR',
 30000000.00,
 'BNP Paribas SA BNP Paribas BNPP BNP Paris'),

('BCCU',
 'Bank of China Canada',
 'Bank of China Limited',
 'OSFI',
 60000000.00,
 'Bank of China Canada Bank of China Limited BOC Canada Bank of China'),

('MSSF',
 'Morgan Stanley Smith Barney LLC',
 'Morgan Stanley',
 'SEC',
 60000000.00,
 'Morgan Stanley Smith Barney LLC Morgan Stanley MSSF Morgan Stanley NY MS Smith Barney');


-- ================================================================
-- TABLE 2: training_dim_date
-- 6 months Jan-Jun 2026
-- Simple columns — no overlap with other tables
-- ================================================================

CREATE TABLE IF NOT EXISTS 
  `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_date (
  trade_date      DATE,     -- PK — joins to fact table
  month_name      STRING,   -- January, February etc
  month_number    INT,      -- 1-6
  quarter_name    STRING,   -- Q1-2026, Q2-2026
  year_number     INT       -- 2026
);

INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_date VALUES
('2026-01-31', 'January',  1, 'Q1-2026', 2026),
('2026-02-28', 'February', 2, 'Q1-2026', 2026),
('2026-03-31', 'March',    3, 'Q1-2026', 2026),
('2026-04-30', 'April',    4, 'Q2-2026', 2026),
('2026-05-31', 'May',      5, 'Q2-2026', 2026),
('2026-06-30', 'June',     6, 'Q2-2026', 2026);


-- ================================================================
-- TABLE 3: training_fact_trades
-- 30 trades across 3 groups:
--   MATCHED_ORIGINAL  — always matched, canonical name used
--   MATCHED_RESOLVED  — matched via entity search field lookup
--   UNMATCHED         — new exceptions, not yet resolved
--
-- FK columns only — no descriptive columns
-- counterparty_code is NULL for UNMATCHED trades
-- ================================================================

CREATE TABLE IF NOT EXISTS 
  `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades (
  trade_id              STRING,        -- PK
  trade_date            DATE,          -- FK → training_dim_date
  counterparty_code     STRING,        -- FK → training_dim_counterparty (NULL if unmatched)
  booked_name           STRING,        -- How name was entered in booking system
  source_system         STRING,        -- MUREX / SUMMIT / EXCEL / LEGACY
  margin_type           STRING,        -- VM / IM
  exposure_amount       DECIMAL(18,2), -- Trade exposure
  call_amount           DECIMAL(18,2), -- Margin call amount
  resolution_status     STRING         -- MATCHED_ORIGINAL / MATCHED_RESOLVED / UNMATCHED
);

INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades VALUES

-- ── GROUP 1: MATCHED_ORIGINAL (15 trades) ────────────────────
-- Canonical names used — always counted correctly

-- Goldman Sachs — 4 trades
('TRD-001','2026-01-31','GSCO','Goldman Sachs & Co LLC',        'MUREX', 'VM', 18500000.00, 12800000.00,'MATCHED_ORIGINAL'),
('TRD-002','2026-02-28','GSCO','Goldman Sachs & Co LLC',        'MUREX', 'VM', 21200000.00, 15400000.00,'MATCHED_ORIGINAL'),
('TRD-003','2026-03-31','GSCO','Goldman Sachs & Co LLC',        'MUREX', 'VM', 24600000.00, 18100000.00,'MATCHED_ORIGINAL'),
('TRD-004','2026-04-30','GSCO','Goldman Sachs & Co LLC',        'MUREX', 'VM', 28300000.00, 21200000.00,'MATCHED_ORIGINAL'),

-- JPMorgan — 3 trades
('TRD-005','2026-01-31','JPMC','JPMorgan Chase Bank NA',        'MUREX', 'VM',  9800000.00,  6200000.00,'MATCHED_ORIGINAL'),
('TRD-006','2026-02-28','JPMC','JPMorgan Chase Bank NA',        'MUREX', 'VM', 11400000.00,  7800000.00,'MATCHED_ORIGINAL'),
('TRD-007','2026-03-31','JPMC','JPMorgan Chase Bank NA',        'MUREX', 'VM', 13200000.00,  9400000.00,'MATCHED_ORIGINAL'),

-- HSBC — 3 trades
('TRD-008','2026-01-31','HSBC','HSBC Bank PLC',                 'MUREX', 'VM',  8200000.00,  5600000.00,'MATCHED_ORIGINAL'),
('TRD-009','2026-02-28','HSBC','HSBC Bank PLC',                 'MUREX', 'VM',  9100000.00,  6400000.00,'MATCHED_ORIGINAL'),
('TRD-010','2026-03-31','HSBC','HSBC Bank PLC',                 'MUREX', 'VM', 10400000.00,  7200000.00,'MATCHED_ORIGINAL'),

-- BNP Paribas — 3 trades
('TRD-011','2026-01-31','BNPP','BNP Paribas SA',                'MUREX', 'VM',  7600000.00,  5100000.00,'MATCHED_ORIGINAL'),
('TRD-012','2026-02-28','BNPP','BNP Paribas SA',                'MUREX', 'VM',  8400000.00,  5800000.00,'MATCHED_ORIGINAL'),
('TRD-013','2026-03-31','BNPP','BNP Paribas SA',                'MUREX', 'VM',  9200000.00,  6400000.00,'MATCHED_ORIGINAL'),

-- Bank of China — 2 trades
('TRD-014','2026-02-28','BCCU','Bank of China Canada',          'MUREX', 'VM',  6800000.00,  4600000.00,'MATCHED_ORIGINAL'),
('TRD-015','2026-03-31','BCCU','Bank of China Canada',          'MUREX', 'VM',  7900000.00,  5400000.00,'MATCHED_ORIGINAL'),

-- ── GROUP 2: MATCHED_RESOLVED (8 trades) ─────────────────────
-- Variant names — exist in entity_search_field
-- Resolved via lookup — counted after resolution

-- Goldman variants
('TRD-016','2026-03-31','GSCO','GS & Co',                       'EXCEL',  'VM',  8400000.00,  5900000.00,'MATCHED_RESOLVED'),
('TRD-017','2026-04-30','GSCO','GS & Co',                       'EXCEL',  'VM',  9600000.00,  6800000.00,'MATCHED_RESOLVED'),
('TRD-018','2026-04-30','GSCO','Goldman Sachs Co LLC',          'SUMMIT', 'VM', 11200000.00,  7900000.00,'MATCHED_RESOLVED'),
('TRD-019','2026-05-31','GSCO','Goldman Sachs Co LLC',          'SUMMIT', 'VM', 12800000.00,  9100000.00,'MATCHED_RESOLVED'),

-- JPMC variants
('TRD-020','2026-03-31','JPMC','Chase',                         'EXCEL',  'VM',  5200000.00,  3600000.00,'MATCHED_RESOLVED'),
('TRD-021','2026-04-30','JPMC','Chase',                         'EXCEL',  'VM',  5900000.00,  4100000.00,'MATCHED_RESOLVED'),
('TRD-022','2026-04-30','JPMC','JP Morgan Chase Bank NA',       'SUMMIT', 'VM',  7100000.00,  4900000.00,'MATCHED_RESOLVED'),
('TRD-023','2026-05-31','JPMC','JP Morgan Chase Bank NA',       'SUMMIT', 'VM',  8200000.00,  5700000.00,'MATCHED_RESOLVED'),

-- ── GROUP 3: UNMATCHED (7 trades) ────────────────────────────
-- New variants — NOT in entity_search_field yet
-- counterparty_code is NULL — system cannot resolve
-- These are the exceptions queue

('TRD-024','2026-04-30', NULL,'GoldmanSachs LLC',               'LEGACY', 'VM',  4200000.00,  2900000.00,'UNMATCHED'),
('TRD-025','2026-05-31', NULL,'GoldmanSachs LLC',               'LEGACY', 'VM',  4800000.00,  3400000.00,'UNMATCHED'),
('TRD-026','2026-04-30', NULL,'G.S. & Co LLC',                  'EXCEL',  'VM',  3600000.00,  2500000.00,'UNMATCHED'),
('TRD-027','2026-05-31', NULL,'G.S. & Co LLC',                  'EXCEL',  'VM',  4100000.00,  2900000.00,'UNMATCHED'),
('TRD-028','2026-05-31', NULL,'JP Morgan Chase N.A.',           'WORD',   'VM',  3900000.00,  2700000.00,'UNMATCHED'),
('TRD-029','2026-06-30', NULL,'JP Morgan Chase N.A.',           'WORD',   'VM',  4400000.00,  3100000.00,'UNMATCHED'),
('TRD-030','2026-06-30', NULL,'JPMorgon',                       'LEGACY', 'VM',  2800000.00,  1900000.00,'UNMATCHED');


-- ================================================================
-- VERIFICATION QUERIES
-- ================================================================

-- Row counts
SELECT 'training_dim_counterparty' AS tbl, COUNT(*) AS rows 
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_counterparty
UNION ALL
SELECT 'training_dim_date',               COUNT(*) 
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_date
UNION ALL
SELECT 'training_fact_trades',            COUNT(*) 
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades;

-- Check resolution status breakdown
SELECT
  resolution_status,
  COUNT(*)                    AS trade_count,
  SUM(exposure_amount)        AS total_exposure
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades
GROUP BY resolution_status
ORDER BY resolution_status;

-- Before resolution exposure (MATCHED_ORIGINAL only)
SELECT
  cp.canonical_name,
  cp.regulatory_regime,
  cp.threshold_amount,
  SUM(f.exposure_amount)      AS before_resolution_exposure,
  COUNT(f.trade_id)           AS trade_count
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades f
JOIN `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_counterparty cp
  ON f.counterparty_code = cp.counterparty_code
WHERE f.resolution_status = 'MATCHED_ORIGINAL'
GROUP BY cp.canonical_name, cp.regulatory_regime, cp.threshold_amount
ORDER BY before_resolution_exposure DESC;

-- After resolution exposure (MATCHED_ORIGINAL + MATCHED_RESOLVED)
SELECT
  cp.canonical_name,
  cp.regulatory_regime,
  cp.threshold_amount,
  SUM(f.exposure_amount)      AS after_resolution_exposure,
  COUNT(f.trade_id)           AS trade_count
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades f
JOIN `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_counterparty cp
  ON f.counterparty_code = cp.counterparty_code
WHERE f.resolution_status IN ('MATCHED_ORIGINAL','MATCHED_RESOLVED')
GROUP BY cp.canonical_name, cp.regulatory_regime, cp.threshold_amount
ORDER BY after_resolution_exposure DESC;

-- Unmatched exceptions queue
SELECT
  trade_id,
  trade_date,
  booked_name,
  source_system,
  exposure_amount,
  call_amount,
  'Requires Investigation' AS action_required
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades
WHERE resolution_status = 'UNMATCHED'
ORDER BY exposure_amount DESC;

-- Entity search test — "GS" should return Goldman
SELECT
  cp.counterparty_code,
  cp.canonical_name,
  cp.entity_search_field
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_counterparty cp
WHERE UPPER(cp.entity_search_field) LIKE '%GS%';

-- Entity search test — "Chase" should return JPMC
SELECT
  cp.counterparty_code,
  cp.canonical_name,
  cp.entity_search_field
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_counterparty cp
WHERE UPPER(cp.entity_search_field) LIKE '%CHASE%';

-- Entity search test — "Morgan" should return JPMC and MSSF
SELECT
  cp.counterparty_code,
  cp.canonical_name,
  cp.entity_search_field
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_counterparty cp
WHERE UPPER(cp.entity_search_field) LIKE '%MORGAN%';

-- ================================================================
-- DATABRICKS UPDATE SCRIPT — RUN DURING LIVE DEMO
-- Resolves 3 unmatched trades (TRD-024, TRD-026, TRD-028)
-- Run this during Exercise 6 to show live refresh
-- ================================================================

-- Step 1: Resolve GoldmanSachs LLC → GSCO
UPDATE `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades
SET
  counterparty_code  = 'GSCO',
  resolution_status  = 'MATCHED_RESOLVED'
WHERE booked_name = 'GoldmanSachs LLC';

-- Step 2: Resolve G.S. & Co LLC → GSCO
UPDATE `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades
SET
  counterparty_code  = 'GSCO',
  resolution_status  = 'MATCHED_RESOLVED'
WHERE booked_name = 'G.S. & Co LLC';

-- Step 3: Resolve JP Morgan Chase N.A. → JPMC
UPDATE `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades
SET
  counterparty_code  = 'JPMC',
  resolution_status  = 'MATCHED_RESOLVED'
WHERE booked_name = 'JP Morgan Chase N.A.';

-- Step 4: Update entity_search_field to include new variants
UPDATE `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_counterparty
SET entity_search_field = entity_search_field || ' GoldmanSachs LLC G.S. & Co LLC'
WHERE counterparty_code = 'GSCO';

UPDATE `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_counterparty
SET entity_search_field = entity_search_field || ' JP Morgan Chase N.A.'
WHERE counterparty_code = 'JPMC';

-- Verify after update
SELECT
  resolution_status,
  COUNT(*)             AS trade_count,
  SUM(exposure_amount) AS total_exposure
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades
GROUP BY resolution_status
ORDER BY resolution_status;
