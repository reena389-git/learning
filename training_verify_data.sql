SELECT trade_id, trade_date, booked_name, 
       source_system, exposure_amount, resolution_status
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades
WHERE resolution_status = 'UNMATCHED'
ORDER BY trade_date;


--- verify 2 , after resetting data
SELECT resolution_status, COUNT(*) AS trades, 
       SUM(exposure_amount) AS exposure
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades
GROUP BY resolution_status;
