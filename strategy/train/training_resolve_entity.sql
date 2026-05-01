-- LIVE DEMO UPDATE — run during training exercise
-- Resolves Goldman and JPMC variants
-- Leaves TRD-028, TRD-029, TRD-030 still unmatched

UPDATE `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades
SET
  counterparty_code = 'GSCO',
  resolution_status = 'MATCHED_RESOLVED'
WHERE trade_id IN ('TRD-016','TRD-017','TRD-018','TRD-019');

UPDATE `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades
SET
  counterparty_code = 'JPMC',
  resolution_status = 'MATCHED_RESOLVED'
WHERE trade_id IN ('TRD-020','TRD-021','TRD-022','TRD-023');
