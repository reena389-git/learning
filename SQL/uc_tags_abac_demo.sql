-- ============================================================================
-- GOVERNED TAGS + ABAC POLICIES — END-TO-END DEMO (Databricks / Unity Catalog)
-- Run top to bottom on a SQL warehouse (serverless) or DBR 16.4+.
-- Replace `sandbox` with a catalog you own.
-- ============================================================================

-- ============================================================================
-- STEP 0 — ONE-TIME, NOT SQL: create the governed tag keys
-- ----------------------------------------------------------------------------
-- Governed tags are ACCOUNT-LEVEL. An account admin creates them in:
--   Account console -> Catalog -> Tag policies  (or via the Tag Policies API)
-- Create these two for this demo:
--   key: class_pii   allowed values: true
--   key: visible     allowed values: yes, no
-- and grant ASSIGN on each to the group that will tag data (e.g. stewards).
--
-- NOTE: the SQL below runs even if the keys are not governed yet — the tags
-- are then ordinary (free-text). But ABAC POLICIES BIND TO GOVERNED TAGS ONLY,
-- so the policies in steps 4-5 take effect once the keys are governed.
-- ============================================================================

-- ============================================================================
-- STEP 1 — demo schema, table, sample rows
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS sandbox.tag_demo;

CREATE OR REPLACE TABLE sandbox.tag_demo.client_profile (
  client_id     STRING  NOT NULL,
  client_name   STRING,
  ssn           STRING,          -- the PII column we will mask
  net_exposure  DECIMAL(18,2)
);

INSERT INTO sandbox.tag_demo.client_profile VALUES
  ('CP-0091', 'Maple Corp',   '123-45-6789', 3200000.00),
  ('CP-0144', 'Birch Ltd',    '987-65-4321', 1150000.00);

-- ============================================================================
-- STEP 2 — APPLY tags (this is the SQL you asked about)
-- ----------------------------------------------------------------------------
-- Table-level tag:
ALTER TABLE sandbox.tag_demo.client_profile
  SET TAGS ('visible' = 'no');                    -- value checked against the
                                                  -- governed list (yes|no)

-- Column-level tag — note the ALTER COLUMN form, ONE column per statement
-- (you cannot tag multiple columns in a single ALTER TABLE):
ALTER TABLE sandbox.tag_demo.client_profile
  ALTER COLUMN ssn SET TAGS ('class_pii' = 'true');

-- (Removing looks like this — for reference, do not run now:)
-- ALTER TABLE sandbox.tag_demo.client_profile UNSET TAGS ('visible');
-- ALTER TABLE sandbox.tag_demo.client_profile ALTER COLUMN ssn UNSET TAGS ('class_pii');

-- ============================================================================
-- STEP 3 — VERIFY the tags landed (information_schema)
-- ============================================================================
SELECT * FROM sandbox.information_schema.table_tags
WHERE  schema_name = 'tag_demo';

SELECT * FROM sandbox.information_schema.column_tags
WHERE  schema_name = 'tag_demo';

-- ============================================================================
-- STEP 4 — COLUMN MASK policy: mask every column tagged class_pii = 'true'
-- ----------------------------------------------------------------------------
-- 4a. The masking function (what masked users see):
CREATE OR REPLACE FUNCTION sandbox.tag_demo.mask_value(v STRING)
RETURNS STRING
RETURN '***MASKED***';

-- 4b. The policy — attached at the SCHEMA, so it auto-covers every current
--     and FUTURE table in it whose columns carry the tag:
CREATE OR REPLACE POLICY mask_pii
ON SCHEMA sandbox.tag_demo
COMMENT 'Mask any column tagged class_pii=true'
COLUMN MASK sandbox.tag_demo.mask_value
TO `AD-RISK-DATA-CONSUMERS`
EXCEPT `AD-RISK-STEWARDS`                 -- your privileged group here
FOR TABLES
MATCH COLUMNS has_tag_value('class_pii','true') AS c
ON COLUMN c;

-- ============================================================================
-- STEP 5 — ROW FILTER policy: hide ALL rows of tables tagged visible = 'no'
--          (the "publish switch": unpublished tables return nothing)
-- ----------------------------------------------------------------------------
-- 5a. A filter function that admits no rows:
CREATE OR REPLACE FUNCTION sandbox.tag_demo.deny_all()
RETURNS BOOLEAN
RETURN FALSE;

-- 5b. The policy — WHEN reads the TABLE-level governed tag:
CREATE OR REPLACE POLICY hide_unpublished
ON SCHEMA sandbox.tag_demo
COMMENT 'Tables still tagged visible=no return no rows to consumers'
ROW FILTER sandbox.tag_demo.deny_all
TO `AD-RISK-DATA-CONSUMERS`
EXCEPT `AD-RISK-STEWARDS`
FOR TABLES
WHEN has_tag_value('visible','no');

-- ============================================================================
-- STEP 6 — SEE IT WORK
-- ----------------------------------------------------------------------------
-- As a member of `AD-RISK-DATA-CONSUMERS` (not excepted):
SELECT * FROM sandbox.tag_demo.client_profile;
--   -> 0 rows                      (row filter: visible = 'no')

-- Now "publish" the table — flip ONE tag:
ALTER TABLE sandbox.tag_demo.client_profile
  SET TAGS ('visible' = 'yes');

SELECT client_id, client_name, ssn, net_exposure
FROM   sandbox.tag_demo.client_profile;
--   -> 2 rows, and ssn shows ***MASKED***   (column-mask policy still applies)

-- As a member of `data-stewards` (EXCEPT list): full rows, real SSNs.

-- ============================================================================
-- STEP 7 — CLEANUP (optional)
-- ============================================================================
-- DROP POLICY hide_unpublished ON SCHEMA sandbox.tag_demo;
-- DROP POLICY mask_pii        ON SCHEMA sandbox.tag_demo;
-- Governed tags must be removed from a column BEFORE the column/table can be
-- dropped (a tagged column blocks DROP by design):
-- ALTER TABLE sandbox.tag_demo.client_profile ALTER COLUMN ssn UNSET TAGS ('class_pii');
-- ALTER TABLE sandbox.tag_demo.client_profile UNSET TAGS ('visible');
-- DROP TABLE sandbox.tag_demo.client_profile;
-- DROP SCHEMA sandbox.tag_demo;
