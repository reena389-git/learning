-- ================================================================
-- AUDIT TRAIL — ENTITY RESOLUTION IMPROVEMENT OVER TIME
-- Adds Group 4 rows to training_fact_trades
-- Shows gradual improvement Jan → Jun 2026
-- ================================================================

-- ================================================================
-- ADDITIONAL TRADES — GROUP 4: AUDIT TRAIL
-- Shows resolution improving month by month
-- Each month has mix of matched and unmatched
-- By June almost everything is resolved
-- ================================================================

INSERT INTO `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades VALUES

-- ── JANUARY 2026 — Starting point, many unmatched ─────────────
-- 5 matched, 4 unmatched — 56% resolution rate

('TRD-031','2026-01-31','GSCO','Goldman Sachs & Co LLC',        'MUREX','VM', 14200000.00, 9800000.00, 'MATCHED_ORIGINAL'),
('TRD-032','2026-01-31','JPMC','JPMorgan Chase Bank NA',        'MUREX','VM',  8600000.00, 5900000.00, 'MATCHED_ORIGINAL'),
('TRD-033','2026-01-31','HSBC','HSBC Bank PLC',                 'MUREX','VM',  7400000.00, 5100000.00, 'MATCHED_ORIGINAL'),
('TRD-034','2026-01-31','BNPP','BNP Paribas SA',                'MUREX','VM',  6200000.00, 4300000.00, 'MATCHED_ORIGINAL'),
('TRD-035','2026-01-31','BCCU','Bank of China Canada',          'MUREX','VM',  5800000.00, 4000000.00, 'MATCHED_ORIGINAL'),

-- January unmatched — new exceptions discovered
('TRD-036','2026-01-31', NULL,'GS & Co',                        'EXCEL', 'VM',  9200000.00, 6400000.00, 'UNMATCHED'),
('TRD-037','2026-01-31', NULL,'Goldman Sachs Co LLC',           'SUMMIT','VM',  8400000.00, 5800000.00, 'UNMATCHED'),
('TRD-038','2026-01-31', NULL,'Chase',                          'EXCEL', 'VM',  6100000.00, 4200000.00, 'UNMATCHED'),
('TRD-039','2026-01-31', NULL,'JP Morgan Chase Bank NA',        'SUMMIT','VM',  5600000.00, 3900000.00, 'UNMATCHED'),

-- ── FEBRUARY 2026 — Team resolves 2 variants ──────────────────
-- GS & Co and Goldman Sachs Co LLC resolved
-- 7 matched, 2 unmatched — 78% resolution rate

('TRD-040','2026-02-28','GSCO','Goldman Sachs & Co LLC',        'MUREX','VM', 16400000.00,11200000.00, 'MATCHED_ORIGINAL'),
('TRD-041','2026-02-28','JPMC','JPMorgan Chase Bank NA',        'MUREX','VM',  9800000.00, 6700000.00, 'MATCHED_ORIGINAL'),
('TRD-042','2026-02-28','HSBC','HSBC Bank PLC',                 'MUREX','VM',  8200000.00, 5600000.00, 'MATCHED_ORIGINAL'),
('TRD-043','2026-02-28','BNPP','BNP Paribas SA',                'MUREX','VM',  7100000.00, 4900000.00, 'MATCHED_ORIGINAL'),
('TRD-044','2026-02-28','BCCU','Bank of China Canada',          'MUREX','VM',  6400000.00, 4400000.00, 'MATCHED_ORIGINAL'),

-- Now resolved after team updated variants table
('TRD-045','2026-02-28','GSCO','GS & Co',                       'EXCEL', 'VM',  9800000.00, 6800000.00, 'MATCHED_RESOLVED'),
('TRD-046','2026-02-28','GSCO','Goldman Sachs Co LLC',          'SUMMIT','VM',  8900000.00, 6200000.00, 'MATCHED_RESOLVED'),

-- Still unmatched in February
('TRD-047','2026-02-28', NULL,'Chase',                          'EXCEL', 'VM',  6400000.00, 4400000.00, 'UNMATCHED'),
('TRD-048','2026-02-28', NULL,'JP Morgan Chase Bank NA',        'SUMMIT','VM',  5900000.00, 4100000.00, 'UNMATCHED'),

-- ── MARCH 2026 — Team resolves 2 more variants ────────────────
-- Chase and JP Morgan Chase Bank NA now resolved
-- 9 matched, 1 unmatched — 90% resolution rate

('TRD-049','2026-03-31','GSCO','Goldman Sachs & Co LLC',        'MUREX','VM', 18600000.00,12800000.00, 'MATCHED_ORIGINAL'),
('TRD-050','2026-03-31','JPMC','JPMorgan Chase Bank NA',        'MUREX','VM', 11200000.00, 7700000.00, 'MATCHED_ORIGINAL'),
('TRD-051','2026-03-31','HSBC','HSBC Bank PLC',                 'MUREX','VM',  9100000.00, 6300000.00, 'MATCHED_ORIGINAL'),
('TRD-052','2026-03-31','BNPP','BNP Paribas SA',                'MUREX','VM',  7800000.00, 5400000.00, 'MATCHED_ORIGINAL'),
('TRD-053','2026-03-31','BCCU','Bank of China Canada',          'MUREX','VM',  7100000.00, 4900000.00, 'MATCHED_ORIGINAL'),
('TRD-054','2026-03-31','GSCO','GS & Co',                       'EXCEL', 'VM', 10400000.00, 7200000.00, 'MATCHED_RESOLVED'),
('TRD-055','2026-03-31','GSCO','Goldman Sachs Co LLC',          'SUMMIT','VM',  9600000.00, 6600000.00, 'MATCHED_RESOLVED'),
('TRD-056','2026-03-31','JPMC','Chase',                         'EXCEL', 'VM',  6800000.00, 4700000.00, 'MATCHED_RESOLVED'),
('TRD-057','2026-03-31','JPMC','JP Morgan Chase Bank NA',       'SUMMIT','VM',  6200000.00, 4300000.00, 'MATCHED_RESOLVED'),

-- One new exception discovered in March
('TRD-058','2026-03-31', NULL,'GoldmanSachs LLC',               'LEGACY','VM',  5200000.00, 3600000.00, 'UNMATCHED'),

-- ── APRIL 2026 — Team resolves GoldmanSachs LLC ───────────────
-- 11 matched, 0 unmatched — 100% resolution rate for known variants
-- But new exception appears

('TRD-059','2026-04-30','GSCO','Goldman Sachs & Co LLC',        'MUREX','VM', 21400000.00,14800000.00, 'MATCHED_ORIGINAL'),
('TRD-060','2026-04-30','JPMC','JPMorgan Chase Bank NA',        'MUREX','VM', 12800000.00, 8800000.00, 'MATCHED_ORIGINAL'),
('TRD-061','2026-04-30','HSBC','HSBC Bank PLC',                 'MUREX','VM', 10200000.00, 7100000.00, 'MATCHED_ORIGINAL'),
('TRD-062','2026-04-30','BNPP','BNP Paribas SA',                'MUREX','VM',  8600000.00, 5900000.00, 'MATCHED_ORIGINAL'),
('TRD-063','2026-04-30','BCCU','Bank of China Canada',          'MUREX','VM',  7800000.00, 5400000.00, 'MATCHED_ORIGINAL'),
('TRD-064','2026-04-30','GSCO','GS & Co',                       'EXCEL', 'VM', 11200000.00, 7800000.00, 'MATCHED_RESOLVED'),
('TRD-065','2026-04-30','GSCO','Goldman Sachs Co LLC',          'SUMMIT','VM', 10400000.00, 7200000.00, 'MATCHED_RESOLVED'),
('TRD-066','2026-04-30','JPMC','Chase',                         'EXCEL', 'VM',  7400000.00, 5100000.00, 'MATCHED_RESOLVED'),
('TRD-067','2026-04-30','JPMC','JP Morgan Chase Bank NA',       'SUMMIT','VM',  6900000.00, 4800000.00, 'MATCHED_RESOLVED'),
('TRD-068','2026-04-30','GSCO','GoldmanSachs LLC',              'LEGACY','VM',  5600000.00, 3900000.00, 'MATCHED_RESOLVED'),

-- New exception in April
('TRD-069','2026-04-30', NULL,'G.S. & Co LLC',                  'EXCEL', 'VM',  4800000.00, 3300000.00, 'UNMATCHED'),

-- ── MAY 2026 — G.S. & Co LLC resolved ────────────────────────
-- 12 matched, 0 unmatched — full resolution

('TRD-070','2026-05-31','GSCO','Goldman Sachs & Co LLC',        'MUREX','VM', 24200000.00,16700000.00, 'MATCHED_ORIGINAL'),
('TRD-071','2026-05-31','JPMC','JPMorgan Chase Bank NA',        'MUREX','VM', 14400000.00, 9900000.00, 'MATCHED_ORIGINAL'),
('TRD-072','2026-05-31','HSBC','HSBC Bank PLC',                 'MUREX','VM', 11400000.00, 7900000.00, 'MATCHED_ORIGINAL'),
('TRD-073','2026-05-31','BNPP','BNP Paribas SA',                'MUREX','VM',  9400000.00, 6500000.00, 'MATCHED_ORIGINAL'),
('TRD-074','2026-05-31','BCCU','Bank of China Canada',          'MUREX','VM',  8600000.00, 5900000.00, 'MATCHED_ORIGINAL'),
('TRD-075','2026-05-31','GSCO','GS & Co',                       'EXCEL', 'VM', 12100000.00, 8400000.00, 'MATCHED_RESOLVED'),
('TRD-076','2026-05-31','GSCO','Goldman Sachs Co LLC',          'SUMMIT','VM', 11200000.00, 7700000.00, 'MATCHED_RESOLVED'),
('TRD-077','2026-05-31','JPMC','Chase',                         'EXCEL', 'VM',  7900000.00, 5500000.00, 'MATCHED_RESOLVED'),
('TRD-078','2026-05-31','JPMC','JP Morgan Chase Bank NA',       'SUMMIT','VM',  7400000.00, 5100000.00, 'MATCHED_RESOLVED'),
('TRD-079','2026-05-31','GSCO','GoldmanSachs LLC',              'LEGACY','VM',  6100000.00, 4200000.00, 'MATCHED_RESOLVED'),
('TRD-080','2026-05-31','GSCO','G.S. & Co LLC',                 'EXCEL', 'VM',  5200000.00, 3600000.00, 'MATCHED_RESOLVED'),
('TRD-081','2026-05-31','MSSF','Morgan Stanley Smith Barney LLC','MUREX','VM',  9800000.00, 6800000.00, 'MATCHED_ORIGINAL'),

-- ── JUNE 2026 — Fully resolved, platform mature ───────────────
-- All variants known, zero unmatched

('TRD-082','2026-06-30','GSCO','Goldman Sachs & Co LLC',        'MUREX','VM', 27400000.00,18900000.00, 'MATCHED_ORIGINAL'),
('TRD-083','2026-06-30','JPMC','JPMorgan Chase Bank NA',        'MUREX','VM', 16200000.00,11200000.00, 'MATCHED_ORIGINAL'),
('TRD-084','2026-06-30','HSBC','HSBC Bank PLC',                 'MUREX','VM', 12800000.00, 8800000.00, 'MATCHED_ORIGINAL'),
('TRD-085','2026-06-30','BNPP','BNP Paribas SA',                'MUREX','VM', 10600000.00, 7300000.00, 'MATCHED_ORIGINAL'),
('TRD-086','2026-06-30','BCCU','Bank of China Canada',          'MUREX','VM',  9600000.00, 6600000.00, 'MATCHED_ORIGINAL'),
('TRD-087','2026-06-30','MSSF','Morgan Stanley Smith Barney LLC','MUREX','VM', 11200000.00, 7700000.00, 'MATCHED_ORIGINAL'),
('TRD-088','2026-06-30','GSCO','GS & Co',                       'EXCEL', 'VM', 13400000.00, 9200000.00, 'MATCHED_RESOLVED'),
('TRD-089','2026-06-30','GSCO','Goldman Sachs Co LLC',          'SUMMIT','VM', 12200000.00, 8400000.00, 'MATCHED_RESOLVED'),
('TRD-090','2026-06-30','JPMC','Chase',                         'EXCEL', 'VM',  8600000.00, 5900000.00, 'MATCHED_RESOLVED'),
('TRD-091','2026-06-30','JPMC','JP Morgan Chase Bank NA',       'SUMMIT','VM',  8100000.00, 5600000.00, 'MATCHED_RESOLVED'),
('TRD-092','2026-06-30','GSCO','GoldmanSachs LLC',              'LEGACY','VM',  6800000.00, 4700000.00, 'MATCHED_RESOLVED'),
('TRD-093','2026-06-30','GSCO','G.S. & Co LLC',                 'EXCEL', 'VM',  5900000.00, 4100000.00, 'MATCHED_RESOLVED');


-- ================================================================
-- AUDIT SUMMARY QUERY
-- Shows resolution improvement month by month
-- This drives the trend visualisation in MicroStrategy
-- ================================================================

SELECT
  d.month_name,
  d.month_number,
  d.year_number,

  -- Trade counts
  COUNT(f.trade_id)                                          AS total_trades,

  COUNT(CASE WHEN f.resolution_status IN
    ('MATCHED_ORIGINAL','MATCHED_RESOLVED')
    THEN 1 END)                                             AS matched_trades,

  COUNT(CASE WHEN f.resolution_status = 'UNMATCHED'
    THEN 1 END)                                             AS unmatched_trades,

  -- Exposure amounts
  ROUND(SUM(CASE WHEN f.resolution_status IN
    ('MATCHED_ORIGINAL','MATCHED_RESOLVED')
    THEN f.exposure_amount ELSE 0 END) / 1000000, 1)       AS matched_exposure_m,

  ROUND(SUM(CASE WHEN f.resolution_status = 'UNMATCHED'
    THEN f.exposure_amount ELSE 0 END) / 1000000, 1)       AS lost_exposure_m,

  ROUND(SUM(f.exposure_amount) / 1000000, 1)               AS total_exposure_m,

  -- Resolution rate %
  ROUND(COUNT(CASE WHEN f.resolution_status IN
    ('MATCHED_ORIGINAL','MATCHED_RESOLVED')
    THEN 1 END) * 100.0 / COUNT(f.trade_id), 1)            AS resolution_rate_pct,

  -- Lost exposure %
  ROUND(SUM(CASE WHEN f.resolution_status = 'UNMATCHED'
    THEN f.exposure_amount ELSE 0 END) * 100.0 /
    SUM(f.exposure_amount), 1)                              AS lost_exposure_pct

FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades f
JOIN `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_dim_date d
  ON f.trade_date = d.trade_date
GROUP BY
  d.month_name,
  d.month_number,
  d.year_number
ORDER BY
  d.month_number;
