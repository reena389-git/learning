SELECT trade_id, trade_date, booked_name, 
       source_system, exposure_amount, resolution_status
FROM `d4001-centralus-tdvip-creditrisk`.xvala_xva.training_fact_trades
WHERE resolution_status = 'UNMATCHED'
ORDER BY trade_date;
