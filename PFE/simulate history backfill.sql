-- =====================================================================
-- simulate_history_backfill.sql   (v2 — asts-led, multi-table)
--
-- WHAT THIS DOES
--   Lands 5 synthetic prior month-ends (Nov 2025 .. Mar 2026) into the tables the
--   LIVE views actually read, in dependency order, so that:
--     (1) the demo dashboard has real history to move against, and
--     (2) a 2nd+ business_date exercises every date-sensitive join -> FIRE DRILL.
--
--   Backfill order (asts is the source; ats_summary is normally built FROM it):
--     1. asts               <- detail/source; the BREACH REPORT reads this
--     2. ats_summary        <- drifted directly (no build in dev — see CAVEAT)
--     3. test_ats_summary   <- breach report join partner
--     4. test_lines_report  <- breach report MTM/IM/CARTOR partner
--
--   (vw_clients_lines / pfe_clients_report are NOT in scope: the current breach
--    report doesn't use them — they belonged to the retired vw_breach_list_cp.)
--
--   catalog d4001-centralus-tdvip-creditrisk   schema xvala_core
--
-- CAVEATS (by design — demo + fan-out test, NOT reconciliation)
--   * ats_summary's prior months are drifted directly, NOT rebuilt from the
--     backfilled asts, so the two tables' histories will NOT tie to each other.
--   * Breach flags are VARIED across months (lines breach/clear) for a livelier
--     New/Cleared demo, so a line's flag won't perfectly track its own drifted
--     exposure. Fine for demo; do not treat synthetic months as real.
--   * April (20260430) is NEVER modified. Removal is purely by date (TEARDOWN).
-- =====================================================================

USE CATALOG `d4001-centralus-tdvip-creditrisk`;
USE SCHEMA  `xvala_core`;

-- ---------------------------------------------------------------------
-- PRE-CHECK — expect ONE date in each before starting.
-- ---------------------------------------------------------------------
SELECT 'asts' t, business_date, COUNT(*) rows FROM `asts` GROUP BY business_date
UNION ALL SELECT 'ats_summary', business_date, COUNT(*) FROM `ats_summary` GROUP BY business_date
UNION ALL SELECT 'test_ats_summary', business_date, COUNT(*) FROM `test_ats_summary` GROUP BY business_date
UNION ALL SELECT 'test_lines_report', business_date, COUNT(*) FROM `test_lines_report` GROUP BY business_date
ORDER BY t, business_date;


-- =====================================================================
-- 1) asts  — detail/source. Money & limits are STRING-with-commas, so we
--    strip+cast, drift, and cast BACK to string to preserve the column type.
--    Scenario / Timestep / dims carried unchanged. Breach flags are VARIED:
--    ~30% of line-months get their six flags TOGGLED, so older months show
--    breaches appearing and clearing (livelier New/Cleared demo).
-- =====================================================================
INSERT INTO `asts`
SELECT
  Scenario_Name, Line, Long_Name, Line_Type, Line_Expiry, No_Line_Indicator, Line_Currency,
  Worst_Rating_Of_Associated_Clients,
  Standard_Usage_0_3_mo, Standard_Usage_3_12_mo, Standard_Usage_1_2_Yr,
  Standard_Usage_2_5_Yr, Standard_Usage_5_10_Yr, Standard_Usage_10_50_Yr,
  CAST(ROUND(CAST(REPLACE(Max_Usage_0_3_mo ,',','') AS DOUBLE)*drift) AS STRING),
  CAST(ROUND(CAST(REPLACE(Max_Usage_3_12_mo,',','') AS DOUBLE)*drift) AS STRING),
  CAST(ROUND(CAST(REPLACE(Max_Usage_1_2_Yr ,',','') AS DOUBLE)*drift) AS STRING),
  CAST(ROUND(CAST(REPLACE(Max_Usage_2_5_Yr ,',','') AS DOUBLE)*drift) AS STRING),
  CAST(ROUND(CAST(REPLACE(Max_Usage_5_10_Yr,',','') AS DOUBLE)*drift) AS STRING),
  CAST(ROUND(CAST(REPLACE(Max_Usage_10_50_Yr,',','') AS DOUBLE)*drift) AS STRING),
  Limit_3_mo, Limit_1_Yr, Limit_2_Yr, Limit_5_Yr, Limit_10_Yr, Limit_50_Yr,   -- limits unchanged
  -- six breach flags, TOGGLED when flip is true:
  CASE WHEN flip THEN CASE WHEN `0_3_mo_Excess_Breach`  ='TRUE' THEN 'FALSE' ELSE 'TRUE' END ELSE `0_3_mo_Excess_Breach`   END,
  CASE WHEN flip THEN CASE WHEN `3_12_mo_Excess_Breach` ='TRUE' THEN 'FALSE' ELSE 'TRUE' END ELSE `3_12_mo_Excess_Breach`  END,
  CASE WHEN flip THEN CASE WHEN `1_2_Yr_Excess_Breach`  ='TRUE' THEN 'FALSE' ELSE 'TRUE' END ELSE `1_2_Yr_Excess_Breach`   END,
  CASE WHEN flip THEN CASE WHEN `2_5_Yr_Excess_Breach`  ='TRUE' THEN 'FALSE' ELSE 'TRUE' END ELSE `2_5_Yr_Excess_Breach`   END,
  CASE WHEN flip THEN CASE WHEN `5_10_Yr_Excess_Breach` ='TRUE' THEN 'FALSE' ELSE 'TRUE' END ELSE `5_10_Yr_Excess_Breach`  END,
  CASE WHEN flip THEN CASE WHEN `10_50_Yr_Excess_Breach`='TRUE' THEN 'FALSE' ELSE 'TRUE' END ELSE `10_50_Yr_Excess_Breach` END,
  `0_3_mo_Excess_Percentage`, `3_12_mo_Excess_Percentage`, `1_2_Yr_Excess_Percentage`,
  `2_5_Yr_Excess_Percentage`, `5_10_Yr_Excess_Percentage`, `10_50_Yr_Excess_Percentage`,
  Gross_Max_Exposure,
  CAST(ROUND(CAST(REPLACE(Max_Scenario_Exposure,',','') AS DOUBLE)*drift) AS STRING),
  Max_Exp_Time_Bucket, Max_Scenario_Name, Scenario, Timestep,
  CAST(ROUND(CAST(REPLACE(Standard_Exposure,',','') AS DOUBLE)*drift) AS STRING),
  Excess_Percentage, Exposure_Percentage,
  Exposure_Percentage_0_3_mo, Exposure_Percentage_3_12_mo, Exposure_Percentage_1_2_yr,
  Exposure_Percentage_2_5_yr, Exposure_Percentage_5_10_yr, Exposure_Percentage_10_50_yr,
  prior_date AS business_date
FROM (
  SELECT a.*, m.prior_date,
    greatest(0.2, 1.0
      - m.m_back * ((pmod(xxhash64(a.Line), 240) - 120) / 1000.0)
      + ((pmod(xxhash64(a.Line, CAST(m.m_back AS STRING)), 60) - 30) / 1000.0)) AS drift,
    (pmod(xxhash64(a.Line, CAST(m.m_back AS STRING), 'brch'), 10) < 3) AS flip   -- ~30% toggle
  FROM `asts` a
  CROSS JOIN (SELECT m_back, date_format(add_months(to_date('20260430','yyyyMMdd'), -m_back),'yyyyMMdd') AS prior_date
              FROM (SELECT explode(array(1,2,3,4,5)) AS m_back)) m
  WHERE a.business_date = '20260430'
);


-- =====================================================================
-- 2) ats_summary — drifted DIRECTLY (no build in dev). Won't tie to asts.
-- =====================================================================
INSERT INTO `ats_summary`
SELECT
  line, long_name, line_currency,
  limit_3_mo, limit_1_yr, limit_2_yr, limit_5_yr, limit_10_yr,   -- limits unchanged
  ROUND(cartor_max*drift), ROUND(zero_max*drift), ROUND(c_25_max*drift), ROUND(c_75_max*drift),
  ROUND(str75_max*drift), ROUND(one_max*drift), ROUND(prod_max*drift), ROUND(strmpr025_max*drift),
  ROUND(max_of_all*drift), ROUND(max_all_less_cartor*drift),
  scenario_of_max, percentage_of_impact,
  worst_rating_of_associated_clients, otc_sft, line_type,
  country_of_risk, cif_country_name, region, sic_industry, industry, td_sub,
  prior_date AS business_date
FROM (
  SELECT s.*, m.prior_date,
    greatest(0.2, 1.0
      - m.m_back * ((pmod(xxhash64(s.line), 240) - 120) / 1000.0)
      + ((pmod(xxhash64(s.line, CAST(m.m_back AS STRING)), 60) - 30) / 1000.0)) AS drift
  FROM `ats_summary` s
  CROSS JOIN (SELECT m_back, date_format(add_months(to_date('20260430','yyyyMMdd'), -m_back),'yyyyMMdd') AS prior_date
              FROM (SELECT explode(array(1,2,3,4,5)) AS m_back)) m
  WHERE s.business_date = '20260430'
);


-- =====================================================================
-- 3) test_ats_summary — breach report join partner. It's a lookup, so values
--    are carried UNCHANGED and only re-dated (enough to exercise the JOIN).
--    * EXCEPT(business_date) carries every column incl. brr + sic_code.
-- =====================================================================
INSERT INTO `test_ats_summary`
SELECT * EXCEPT(business_date), prior_date AS business_date
FROM (
  SELECT s.*, date_format(add_months(to_date('20260430','yyyyMMdd'), -m_back),'yyyyMMdd') AS prior_date
  FROM `test_ats_summary` s
  CROSS JOIN (SELECT explode(array(1,2,3,4,5)) AS m_back) m
  WHERE s.business_date = '20260430'
);


-- =====================================================================
-- 4) test_lines_report — breach MTM/IM/CARTOR partner. Re-date all source rows;
--    drift mark_to_market / initial_margin so MTM trends. Date is 'yyyy-mm-dd'.
-- =====================================================================
INSERT INTO `test_lines_report`
SELECT
  * EXCEPT(business_date, mark_to_market, initial_margin),
  ROUND(mark_to_market * drift, 2) AS mark_to_market,
  ROUND(initial_margin * drift, 2) AS initial_margin,
  prior_date AS business_date
FROM (
  SELECT l.*,
    date_format(add_months(to_date('2026-04-30','yyyy-MM-dd'), -m_back),'yyyy-MM-dd') AS prior_date,
    greatest(0.2, 1.0
      - m_back * ((pmod(xxhash64(l.Line), 240) - 120) / 1000.0)
      + ((pmod(xxhash64(l.Line, CAST(m_back AS STRING)), 60) - 30) / 1000.0)) AS drift
  FROM `test_lines_report` l
  CROSS JOIN (SELECT explode(array(1,2,3,4,5)) AS m_back) m
  WHERE l.business_date = '2026-04-30'
);


-- =====================================================================
-- POST-CHECK — every table should now show 6 dates.
-- =====================================================================
SELECT 'asts' t, business_date, COUNT(*) rows FROM `asts` GROUP BY business_date
UNION ALL SELECT 'ats_summary', business_date, COUNT(*) FROM `ats_summary` GROUP BY business_date
UNION ALL SELECT 'test_ats_summary', business_date, COUNT(*) FROM `test_ats_summary` GROUP BY business_date
UNION ALL SELECT 'test_lines_report', business_date, COUNT(*) FROM `test_lines_report` GROUP BY business_date
ORDER BY t, business_date;


-- =====================================================================
-- FIRE DRILL — does anything break / fan out now that 6 dates exist?
-- =====================================================================
-- F1  Level-1 view: business_date is a grain key -> ~6x CP rows. PASS = 6 dates,
--     April's count unchanged.
SELECT business_date, COUNT(*) cp_rows
FROM `vw_asts_portfolio_cp_stress` GROUP BY business_date ORDER BY business_date;

-- F2  Breach report: asts read is pinned to '20260430' and the test_ats_summary
--     join is date-filtered. PASS = STILL 132 rows / 132 distinct lines.
--     FAIL (>132) = a join lost its date.
SELECT COUNT(*) rows, COUNT(DISTINCT Line) distinct_lines
FROM `xvala_core-raw`.vw_ast_breach_report;

-- F3  The join that would fan out without its date filter — see the danger number.
WITH b AS (SELECT DISTINCT Line FROM `xvala_core-raw`.vw_ast_breach_report)
SELECT
  (SELECT COUNT(*) FROM b) breach_lines,
  (SELECT COUNT(*) FROM b JOIN `test_ats_summary` t ON t.Line=b.Line) join_no_date,        -- danger
  (SELECT COUNT(*) FROM b JOIN `test_ats_summary` t ON t.Line=b.Line
        AND t.business_date='20260430') join_dated;                                         -- what the view uses

-- F4  Livelier-demo proof: breach line counts should now MOVE month to month.
SELECT business_date,
       SUM(CASE WHEN `0_3_mo_Excess_Breach`='TRUE' OR `3_12_mo_Excess_Breach`='TRUE'
                  OR `1_2_Yr_Excess_Breach`='TRUE' OR `2_5_Yr_Excess_Breach`='TRUE'
                  OR `5_10_Yr_Excess_Breach`='TRUE' OR `10_50_Yr_Excess_Breach`='TRUE'
                THEN 1 ELSE 0 END) AS breached_lines
FROM `asts` WHERE No_Line_Indicator='False'
GROUP BY business_date ORDER BY business_date;


-- =====================================================================
-- TEARDOWN — remove ALL synthetic history (reset / go-live). Run per table.
-- =====================================================================
-- DELETE FROM `asts`              WHERE business_date <  '20260430';
-- DELETE FROM `ats_summary`       WHERE business_date <  '20260430';
-- DELETE FROM `test_ats_summary`  WHERE business_date <  '20260430';
-- DELETE FROM `test_lines_report` WHERE business_date <  '2026-04-30';   -- dash format
