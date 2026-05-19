-- ================================================================
-- CCR POC — DATA VERIFICATION CHECKS  (run in Databricks SQL)
-- Run these BEFORE building the Mosaic model. Every check should
-- return the expected result described in its comment. If a check
-- fails, fix the data first — do not debug it in Mosaic.
-- Catalog/schema: d4001-centralus-tdvip-creditrisk.xvala_xva
-- ================================================================

-- Set these so you only type the path once per session.
USE CATALOG `d4001-centralus-tdvip-creditrisk`;
USE SCHEMA xvala_xva;

-- ================================================================
-- SECTION 1 — ROW COUNTS  (is everything loaded?)
-- ================================================================
SELECT 'star_dim_csa_type'              AS table_name, COUNT(*) AS rows FROM star_dim_csa_type
UNION ALL SELECT 'star_dim_counterparty',          COUNT(*) FROM star_dim_counterparty
UNION ALL SELECT 'star_dim_date',                  COUNT(*) FROM star_dim_date
UNION ALL SELECT 'star_dim_agreement',             COUNT(*) FROM star_dim_agreement
UNION ALL SELECT 'star_dim_collateral_eligibility',COUNT(*) FROM star_dim_collateral_eligibility
UNION ALL SELECT 'star_dim_legal_entity',          COUNT(*) FROM star_dim_legal_entity
UNION ALL SELECT 'star_dim_trade',                 COUNT(*) FROM star_dim_trade
UNION ALL SELECT 'star_fact_collateral_exposure',  COUNT(*) FROM star_fact_collateral_exposure
UNION ALL SELECT 'star_fact_issuer_exposure',      COUNT(*) FROM star_fact_issuer_exposure
ORDER BY table_name;
-- EXPECT roughly: csa_type 5, counterparty 10, date 6, agreement 12,
-- eligibility 13, legal_entity 19, trade 58, fact 72, issuer 48.
-- A 0 anywhere = that table was not loaded.

-- ================================================================
-- SECTION 2 — REFERENTIAL INTEGRITY  (do the joins hold?)
-- Each query should return ZERO rows. Any row = an orphan FK that
-- will smear or drop out in the model.
-- ================================================================

-- 2a. Agreement -> Counterparty
SELECT 'agreement.counterparty_code orphan' AS check, a.agreement_id, a.counterparty_code
FROM star_dim_agreement a
LEFT JOIN star_dim_counterparty c ON c.counterparty_code = a.counterparty_code
WHERE c.counterparty_code IS NULL;

-- 2b. Fact -> Agreement
SELECT 'fact.agreement_id orphan' AS check, f.event_id, f.agreement_id
FROM star_fact_collateral_exposure f
LEFT JOIN star_dim_agreement a ON a.agreement_id = f.agreement_id
WHERE a.agreement_id IS NULL;

-- 2c. Fact -> Counterparty
SELECT 'fact.counterparty_code orphan' AS check, f.event_id, f.counterparty_code
FROM star_fact_collateral_exposure f
LEFT JOIN star_dim_counterparty c ON c.counterparty_code = f.counterparty_code
WHERE c.counterparty_code IS NULL;

-- 2d. Fact -> Date
SELECT 'fact.as_of_date orphan' AS check, f.event_id, f.as_of_date
FROM star_fact_collateral_exposure f
LEFT JOIN star_dim_date d ON d.as_of_date = f.as_of_date
WHERE d.as_of_date IS NULL;

-- 2e. Trade -> Agreement  (this is the join the trade drill depends on)
SELECT 'trade.agreement_id orphan' AS check, t.trade_key, t.agreement_id
FROM star_dim_trade t
LEFT JOIN star_dim_agreement a ON a.agreement_id = t.agreement_id
WHERE a.agreement_id IS NULL;

-- 2f. Issuer exposure -> Agreement
SELECT 'issuer_exp.agreement_id orphan' AS check, i.issuer_exposure_key, i.agreement_id
FROM star_fact_issuer_exposure i
LEFT JOIN star_dim_agreement a ON a.agreement_id = i.agreement_id
WHERE a.agreement_id IS NULL;

-- 2g. Issuer exposure -> Date
SELECT 'issuer_exp.as_of_date orphan' AS check, i.issuer_exposure_key, i.as_of_date
FROM star_fact_issuer_exposure i
LEFT JOIN star_dim_date d ON d.as_of_date = i.as_of_date
WHERE d.as_of_date IS NULL;

-- 2h. Legal entity -> Counterparty
SELECT 'legal_entity.counterparty_code orphan' AS check, le.lei_code, le.counterparty_code
FROM star_dim_legal_entity le
LEFT JOIN star_dim_counterparty c ON c.counterparty_code = le.counterparty_code
WHERE c.counterparty_code IS NULL;

-- 2i. Legal entity self-reference: every ultimate_parent_lei must exist as a lei_code
SELECT 'legal_entity.ultimate_parent_lei orphan' AS check, le.lei_code, le.ultimate_parent_lei
FROM star_dim_legal_entity le
LEFT JOIN star_dim_legal_entity p ON p.lei_code = le.ultimate_parent_lei
WHERE p.lei_code IS NULL;

-- ================================================================
-- SECTION 3 — KEY UNIQUENESS  (any duplicate keys = smearing risk)
-- Each query should return ZERO rows.
-- ================================================================

SELECT 'dup counterparty_code' AS check, counterparty_code, COUNT(*) n
FROM star_dim_counterparty GROUP BY counterparty_code HAVING COUNT(*) > 1;

SELECT 'dup agreement_id' AS check, agreement_id, COUNT(*) n
FROM star_dim_agreement GROUP BY agreement_id HAVING COUNT(*) > 1;

SELECT 'dup trade_key' AS check, trade_key, COUNT(*) n
FROM star_dim_trade GROUP BY trade_key HAVING COUNT(*) > 1;

SELECT 'dup lei_code' AS check, lei_code, COUNT(*) n
FROM star_dim_legal_entity GROUP BY lei_code HAVING COUNT(*) > 1;

SELECT 'dup as_of_date' AS check, as_of_date, COUNT(*) n
FROM star_dim_date GROUP BY as_of_date HAVING COUNT(*) > 1;

-- ================================================================
-- SECTION 4 — GRAIN CHECK  (confirm the fact grain you assume)
-- ================================================================
-- The fact should be one row per agreement per date. This returns
-- any (agreement, date) pair that appears more than once.
SELECT 'fact grain violation' AS check, agreement_id, as_of_date, COUNT(*) n
FROM star_fact_collateral_exposure
GROUP BY agreement_id, as_of_date
HAVING COUNT(*) > 1;
-- ZERO rows = grain is clean (one row per agreement per date).

-- ================================================================
-- SECTION 5 — DIRECT EXPOSURE RECONCILIATION
-- The whole direct-exposure drill depends on this. Trade
-- contributions per agreement must equal direct exposure on 31-Mar.
-- ================================================================
SELECT
  t.agreement_id,
  ROUND(SUM(t.trade_exposure_contribution), 2) AS trades_sum,
  f.base_total_exposure                        AS direct_exposure_0331,
  ROUND(SUM(t.trade_exposure_contribution) - f.base_total_exposure, 2) AS difference
FROM star_dim_trade t
JOIN star_fact_collateral_exposure f
  ON f.agreement_id = t.agreement_id
 AND f.as_of_date   = DATE'2026-03-31'
WHERE t.trade_exposure_contribution IS NOT NULL
GROUP BY t.agreement_id, f.base_total_exposure
ORDER BY t.agreement_id;
-- EXPECT: difference = 0.00 on every VM agreement.
-- Agreements with NULL direct exposure (IM-only) will not appear — that is fine.

-- ================================================================
-- SECTION 6 — NULL / COMPLETENESS CHECKS  (eyeball these)
-- ================================================================

-- 6a. Counterparties with NO direct exposure on any date (expected: the IM-only ones)
SELECT c.counterparty_code, c.counterparty_legal_name,
       COUNT(f.event_id)                              AS fact_rows,
       SUM(CASE WHEN f.base_total_exposure IS NULL THEN 1 ELSE 0 END) AS null_exposure_rows
FROM star_dim_counterparty c
LEFT JOIN star_fact_collateral_exposure f ON f.counterparty_code = c.counterparty_code
GROUP BY c.counterparty_code, c.counterparty_legal_name
ORDER BY c.counterparty_code;

-- 6b. Agreements that have NO trades (drill would land empty for these)
SELECT a.agreement_id, a.counterparty_code
FROM star_dim_agreement a
LEFT JOIN star_dim_trade t ON t.agreement_id = a.agreement_id
WHERE t.trade_key IS NULL;
-- EXPECT zero rows — every agreement should have trades.

-- 6c. Counterparties with indirect exposure (expected: only the 5 with collateral schedules)
SELECT counterparty_code, COUNT(*) issuer_rows,
       ROUND(SUM(indirect_exposure),2) total_indirect
FROM star_fact_issuer_exposure
GROUP BY counterparty_code
ORDER BY counterparty_code;

-- 6d. product_type_isda format check — must contain a colon so Asset Class can be derived
SELECT 'product_type_isda missing colon' AS check, trade_key, product_type_isda
FROM star_dim_trade
WHERE product_type_isda NOT LIKE '%:%';
-- ZERO rows = every trade can have Asset Class derived from the prefix.

-- 6e. Ultimate parent coverage — every counterparty should have at least one
--     legal entity flagged is_ultimate_parent = true
SELECT c.counterparty_code,
       SUM(CASE WHEN le.is_ultimate_parent THEN 1 ELSE 0 END) AS parent_rows
FROM star_dim_counterparty c
LEFT JOIN star_dim_legal_entity le ON le.counterparty_code = c.counterparty_code
GROUP BY c.counterparty_code
HAVING SUM(CASE WHEN le.is_ultimate_parent THEN 1 ELSE 0 END) = 0;
-- ZERO rows = every counterparty has an ultimate parent.

-- ================================================================
-- SECTION 7 — SPOT-CHECK THE DRILL JOIN END TO END
-- Simulates exactly what the dashboard does: counterparty -> agreement
-- -> trade, with asset class. Pick one counterparty and eyeball it.
-- ================================================================
SELECT
  c.counterparty_legal_name,
  SPLIT(t.product_type_isda, ':')[0] AS asset_class,
  COUNT(t.trade_key)                 AS trade_count,
  ROUND(SUM(t.trade_exposure_contribution),2) AS exposure_contribution
FROM star_dim_counterparty c
JOIN star_dim_agreement   a ON a.counterparty_code = c.counterparty_code
JOIN star_dim_trade       t ON t.agreement_id      = a.agreement_id
WHERE c.counterparty_code = 'GSCO'           -- change to any counterparty
  AND t.trade_exposure_contribution IS NOT NULL
GROUP BY c.counterparty_legal_name, SPLIT(t.product_type_isda, ':')[0]
ORDER BY asset_class;
-- The exposure_contribution values should sum to Goldman's direct
-- exposure on 31-Mar. This is the Page-2 drill, previewed in SQL.
