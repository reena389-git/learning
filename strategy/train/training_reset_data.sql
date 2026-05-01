-- Reset Group 2 trades back to UNMATCHED for demo start
UPDATE `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades
SET 
  counterparty_code = NULL,
  resolution_status = 'UNMATCHED'
WHERE trade_id IN (
  'TRD-016','TRD-017','TRD-018','TRD-019',  -- Goldman variants
  'TRD-020','TRD-021','TRD-022','TRD-023'   -- JPMC variants
);
