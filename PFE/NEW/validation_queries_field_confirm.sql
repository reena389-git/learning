-- =====================================================================
-- FIELD-EQUIVALENCE VALIDATIONS (run in Databricks)
-- Purpose: confirm suspected same-fields before conforming in Mosaic.
-- =====================================================================

-- V1. Counterparty_Rating (deal.td_account_rating) vs BRR (line.brr)
--     Are they the same rating for the same line/counterparty?
--     Join deal->line on Line; compare the two rating fields.
SELECT
  COUNT(*)                                             AS pairs_compared,
  SUM(CASE WHEN trim(upper(d.Counterparty_Rating)) = trim(upper(l.BRR)) THEN 1 ELSE 0 END) AS matches,
  SUM(CASE WHEN trim(upper(d.Counterparty_Rating)) <> trim(upper(l.BRR)) THEN 1 ELSE 0 END) AS differ,
  SUM(CASE WHEN d.Counterparty_Rating IS NULL OR l.BRR IS NULL THEN 1 ELSE 0 END)            AS either_null
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_deals_by_line d
JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail l
  ON l.Line = d.Line
WHERE d.Counterparty_Rating IS NOT NULL AND l.BRR IS NOT NULL;
-- Interpretation: if differ = 0 (or ~0), they are the same rating -> conform.
-- If BRR is largely null (test-only column), prefer deal's Counterparty_Rating.

-- V1b. Is BRR even populated in the line fact?
SELECT COUNT(*) total_lines, COUNT(BRR) brr_nonnull, COUNT(DISTINCT BRR) brr_distinct_vals
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail;

-- V2. Industry: deal (sic_industry) vs line (sic_industry) — same source column,
--     confirm values agree per line.
SELECT
  COUNT(*)                                             AS pairs_compared,
  SUM(CASE WHEN trim(upper(d.Industry)) = trim(upper(l.Industry)) THEN 1 ELSE 0 END) AS matches,
  SUM(CASE WHEN trim(upper(d.Industry)) <> trim(upper(l.Industry)) THEN 1 ELSE 0 END) AS differ
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_deals_by_line d
JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail l
  ON l.Line = d.Line
WHERE d.Industry IS NOT NULL AND l.Industry IS NOT NULL;
-- Interpretation: differ should be ~0 (same source column). Confirms they conform.

-- V3. Override vs Override_Norm are redundant (Override_Norm is just a relabel of Override).
--     Confirm 1:1 mapping so we can drop one.
SELECT `override` AS raw_override, COUNT(*) n
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.pfe_deals_report
GROUP BY `override`;
-- Interpretation: raw is Y/N; Override_Norm maps Y->Overridden, else->Clean. Keep ONE.
