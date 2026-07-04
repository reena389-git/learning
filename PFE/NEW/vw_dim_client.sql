-- =====================================================================
-- vw_dim_client   (Counterparty dimension)
-- Catalog d4001-centralus-tdvip-creditrisk · Schema xvala_core
--
-- ROLE
--   THE Counterparty dimension for the Mosaic model. The model references THIS
--   VIEW, never raw pfe_clients_report — the view is self-sufficient (carries every
--   counterparty attribute v1 needs). Facts relate to it on the counterparty code:
--     · vw_pfe_ats_lines_detail.Line  = Counterparty_Code   (CP lines; HC lines null here by design)
--     · vw_pfe_asts_scenario.Line     = Counterparty_Code   (CP lines)
--     · vw_pfe_deals_by_line.Counterparty_Code = Counterparty_Code
--
-- GRAIN   one row per counterparty_code     PK  Counterparty_Code
--
-- WHY A VIEW (grain correction): pfe_clients_report is REPLICATED per source(scenario)
--   × business_date. Left raw, it is counterparty × scenario × date -> fan-out. This
--   view slices to ONE source (CARTOR) + the MAX(business_date) so it is exactly one
--   row per counterparty. Attributes are STABLE across sources (verified: 0 counterparties
--   have varying industry / rating / parent by source), so the source pick loses nothing.
--   MAX(business_date) auto-follows the latest load (reference data — current state).
--
-- HIERARCHY (data-owner confirmed): counterparties form a 3-level hierarchy —
--   Counterparty_Code (CP, leaf) -> Immediate_Parent (HC = Holding Company)
--   -> Ultimate_Parent (UP). HC lines in the facts map to their counterparty family
--   via Immediate_Parent (all 1,387 HC lines resolve). NOTE for v1: the parent columns
--   are CARRIED but the hierarchy is NOT wired as a join path — v1's HC drill comes from
--   the deal fact. The Immediate_Parent / Ultimate_Parent join + roll-up is the DEFERRED
--   secondary "parent" view/hierarchy (build in Mosaic later as a dimensional hierarchy).
--   HC exposure is INDEPENDENT of its children (not a roll-up) — CP+HC additive, no double-count.
--
-- SEARCH: users search by Counterparty_Name (long name) AND by Counterparty_Code /
--   line code. Name is a searchable/lookup attribute, NOT a join key (one name can map
--   to many codes) — joins stay on the codes.
-- =====================================================================
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`vw_dim_client` (
  Counterparty_Code     COMMENT 'Counterparty identifier (CP-format). PK of the Counterparty dimension; the conformed key facts join on (= the CP-format Line in ats_summary/asts). Leaf of the CP -> Immediate_Parent(HC) -> Ultimate_Parent(UP) hierarchy.',
  Counterparty_Name     COMMENT 'Counterparty long name. SEARCHABLE display attribute (users search by name). NOT a join key — one name can map to several codes.',
  Immediate_Parent      COMMENT 'Holding Company (HC-format) this counterparty rolls up to. The HC-level key: HC lines in the facts map to their counterparty family via this column (all 1,387 HC lines resolve). Carried for the DEFERRED hierarchy view; not a v1 join path. HC exposure is independent of children (not a roll-up).',
  Ultimate_Parent       COMMENT 'Ultimate Parent (UP-format) — top of the corporate hierarchy. Carried for the deferred parent roll-up view.',
  Industry              COMMENT 'Counterparty industry (sic_industry). Portfolio slicing attribute. Stable across sources.',
  SIC_Code              COMMENT 'SIC classification code (sic_code). Drives Client_Type buckets on the line fact (e.g. 7298 -> Hedge Funds).',
  Rating                COMMENT 'Counterparty credit rating (td_account_rating). The CP''s own rating. Slicing attribute.',
  Country_Of_Risk       COMMENT 'Country of risk. Portfolio slicing attribute.',
  Country_Risk_Rating   COMMENT 'TD country-of-risk rating (td_country_of_risk_rating).',
  BIS_Code              COMMENT 'BIS code (reference identifier).',
  CIF_Number            COMMENT 'CIF number (reference identifier).',
  Business_Date         COMMENT 'The MAX(business_date) slice this dimension row reflects (reference-data current state).'
)
AS
WITH latest AS (
  SELECT MAX(business_date) AS max_bd
  FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_clients_report`
)
SELECT
  trim(upper(cr.`counterparty_code`))                  AS Counterparty_Code,
  cr.`counterparty_long_name`                          AS Counterparty_Name,
  trim(upper(cr.`immediate_parent`))                   AS Immediate_Parent,
  trim(upper(cr.`ultimate_parent`))                    AS Ultimate_Parent,
  cr.`sic_industry`                                    AS Industry,
  cr.`sic_code`                                        AS SIC_Code,
  cr.`td_account_rating`                               AS Rating,
  cr.`country_of_risk`                                 AS Country_Of_Risk,
  cr.`td_country_of_risk_rating`                        AS Country_Risk_Rating,
  cr.`bis_code`                                        AS BIS_Code,
  cr.`cif_number`                                      AS CIF_Number,
  cr.`business_date`                                   AS Business_Date
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.`pfe_clients_report` cr
JOIN latest l ON cr.`business_date` = l.max_bd
WHERE upper(trim(cr.`source`)) = 'CARTOR'
  -- one row per counterparty_code: source+date slice makes it unique (attributes stable across sources).
;

-- =====================================================================
-- VALIDATION
-- =====================================================================
-- V-PK  one row per counterparty_code (expect 0 dup rows).
SELECT Counterparty_Code, COUNT(*) AS n
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_dim_client
GROUP BY Counterparty_Code HAVING COUNT(*) > 1 LIMIT 20;
-- V-COUNT  row count = distinct counterparties in the CARTOR/max-date slice.
SELECT COUNT(*) AS rows_, COUNT(DISTINCT Counterparty_Code) AS distinct_cp
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_dim_client;
-- V-CPLINE  CP exposure lines resolve to the dimension (line fact CP lines -> dim).
--   EXPECT ~10,417 CP lines matched.
SELECT COUNT(DISTINCT d.Line) AS cp_lines_matched
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail d
JOIN `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_dim_client c
  ON d.Line = c.Counterparty_Code
WHERE d.Line_Class = 'CP';
-- V-HCPARENT  HC lines resolve via Immediate_Parent (deferred path; expect ~1,387).
SELECT COUNT(DISTINCT d.Line) AS hc_lines_matched_via_parent
FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_pfe_ats_lines_detail d
JOIN (SELECT DISTINCT Immediate_Parent FROM `d4001-centralus-tdvip-creditrisk`.`xvala_core`.vw_dim_client) c
  ON d.Line = c.Immediate_Parent
WHERE d.Line_Class = 'HC';
