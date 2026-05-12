# PAGE: 2. Standards & Artifacts Library

*Standards, templates, and operational artefacts used to onboard, govern, and consume data products in the Risk Warehouse.*

*The architectural reference (where things live, who owns what) is on Architecture & Design. This page focuses on the operational artefacts.*

## How the artefacts connect

Business raises a Jira intake → routes to PG owner → PG owner converses with apps and other PGs → Risk Data authors the contract → contract publishes to Unity Catalog and Collibra → product becomes consumable.

*Image: Intake-to-Contract Flow — paste from `intake_to_contract_flow_v1.pptx`*

## Artefacts catalog

| # | Artefact | What it is | Owned / authored by | Format | Where |
|---|----------|------------|---------------------|--------|-------|
| **A** | Intake-to-Contract Flow | End-to-end flow from business need to consumable product | Risk Data | PowerPoint | Linked: `intake_to_contract_flow_v1.pptx` |
| **B** | Jira Intake Template | 7-field intake form spec for new data product requests | Risk Data | Markdown spec; form lives in Jira | Linked: `jira_intake_template_spec.md` |
| **C** | Data Contract Attribute Spec | 25 attributes per contract, mapped to UC tags · COMMENTs · CONSTRAINTs · Collibra · YAML | Risk Data | Excel (2 tabs: reference + worked example with SQL) | Linked: `data_contract_attribute_spec.xlsx` |
| **D** | Unity Catalog Tags — Unified Table | All UC tags in one place, showing who authors each tag | Risk Data | Excel | Linked: `uc_tags_unified_table.xlsx` |
| **E** | Schema & Catalog Design Standard | Catalog and schema layout for Risk in Databricks | Risk Data | Confluence section | Embedded below — Section E |
| **F** | Naming Convention Standard | Business name → physical name → short name → aliases | PG Leaders (authority) · Risk Data (technical) | Confluence section | Embedded below — Section F |
| **G** | Abbreviations Dictionary | Standard short-form abbreviations for physical and short names | PG Leaders (additions) · Risk Data (technical) | Excel | Linked: `abbreviations_dictionary.xlsx` |
| **H** | Semantic Layer Definition Template | dbt / Databricks Metric Views YAML template | Risk Data | Markdown / YAML spec | Linked: `semantic_layer_template.md` |
| **I** | Consumer Registry Schema | Schema for `risk_governance.consumer_registry` | Risk Data | Confluence section | Embedded below — Section I |

---

## Embedded standards

The sections below are reference standards rather than separate templates or files. They are kept on this page for ease of reference.

---

## E. Schema and Catalog Design Standard

The canonical layout of catalogs and schemas in Databricks for Risk.

### Catalogs

| Catalog | Purpose | Owner | Consumer access |
|---------|---------|-------|-----------------|
| `creditrisk`, `marketrisk`, `liquidity`, `finance` | One catalog per Product Group. Holds app schemas and the PG conformed schema. | PG Leaders | Internal to the PG; not the consumer entry point |
| `riskwh` | Risk Warehouse. Data products, star schemas, 360 patterns, semantic layer, sandbox. | Risk Data | Single point of consumption |
| `risk_governance` | Governance metadata. Contract registry, consumer registry, tag reference, lineage extensions. | Risk Data | Read-only for App teams, PG Leaders, Central |

### Schemas inside each PG catalog

```
<pg>.<app_name>           -- primary app schema (e.g., creditrisk.xvala)
<pg>.<app_name>_archive   -- archival
<pg>.<app_name>_quarantine -- DQ-failed records
<pg>.conformed            -- PG conformed schema (resolved dims, enriched CDM entities, cross-app products within the PG)
<pg>.sandbox              -- exploration
```

### Schemas inside `riskwh`

```
riskwh.silver       -- staging for analytics-layer build (pre-product)
riskwh.gold         -- curated data products (physical, contracted)
riskwh.sandbox      -- exploration; not contracted; not consumed by ops
riskwh.semantic     -- semantic layer definitions (dbt / Metric Views)
```

### Table naming inside the analytics layer

```
fact_<entity>_<measure>           -- atomic primary fact, e.g., fact_exposure
dim_<entity>                      -- dimension, e.g., dim_counterparty
<entity>_<purpose>_summary        -- curated summary, e.g., cp_risk_summary
<entity>_<purpose>_360            -- 360-style products, e.g., counterparty_risk_360
report_<consumer>_<purpose>       -- reporting, e.g., report_basel_sa_ccr
```

### Consumer access policy

Consumers (BI tools, dashboards, ad-hoc queries) connect to `riskwh` only. Direct consumer connections to app-zone catalogs (`creditrisk.<app>`, etc.) are not supported.

When a consumer is found connecting to an app schema:

1. Acknowledge the work
2. Identify what to promote into the analytics layer (raise via Jira intake — Section B)
3. Re-point the consumer to the analytics product once it exists

---

## F. Naming Convention Standard

*Authority: PG Leaders define names at the `<pg>.conformed` schema. Risk Data implements technically. Names carry up to the Risk Warehouse and down to apps via aliases.*

*Companion artefacts: Naming Convention Flow diagram (linked in Section A of the catalog) · Abbreviations Dictionary (Section G).*

### Scope

Every column in every analytics-layer table has four name forms:

| Form | What it is | Where it lives |
|------|------------|----------------|
| **Business name** | Plain-English label (e.g., *Counterparty Internal Rating*) | UC column tag `business_name` · Collibra |
| **Physical name** | The actual column name in SQL (e.g., `counterparty_internal_rating`) | The table itself |
| **Short name** | Derived abbreviated form for length-constrained consumers (e.g., `cp_int_rating`) | UC column tag `short_name` — only if derived |
| **App aliases** | Original column names from source apps (e.g., XVALA's `cpIntRtg`) | UC column tag `aliases` — multi-value, one entry per source app |

All four names point to the same logical column. The mapping is recorded once at the conformance step.

### Authority and carry-over

Names are defined and owned by the **PG Leader** at the PG conformed schema (`creditrisk.conformed`, `marketrisk.conformed`, etc.). New names entering the analytics layer pass through PG-level review.

- **Risk Warehouse** (`riskwh.*`) uses the same canonical physical names defined at the PG layer
- **App schemas** keep their original names; the conformance step records app names as aliases against the canonical column
- **Legacy app names are not forced to rename.** Translation happens at the conformance step

### Rules for physical names

1. **Lowercase only.** `counterparty` not `Counterparty` or `COUNTERPARTY`.
2. **snake_case for compound names.** Words separated by underscores: `counterparty_internal_rating`.
3. **No special characters.** Letters, digits, underscores only. No spaces, dots, dashes, slashes.
4. **Standard suffixes** carry semantic meaning (see table below).
5. **No SQL reserved words** as bare column names: avoid `date`, `time`, `user`, `table`, `order`, `group`, `type`. Use `valuation_date`, `event_time`, `user_id`, `record_type`.
6. **Maximum 30 characters** for cross-system portability. Above 30, derive a short form via the abbreviations dictionary.
7. **Short forms (when needed) use the abbreviations dictionary.** No inventing new abbreviations ad hoc.

### Standard suffixes

| Suffix | Use for | Example |
|--------|---------|---------|
| `_id` | Unique identifier | `counterparty_id`, `trade_id` |
| `_date` | Date (no time component) | `valuation_date`, `effective_date` |
| `_time` | Datetime or timestamp | `created_time`, `event_time` |
| `_amount` or `_amt` | Monetary amount | `notional_amount`, `mtm_amt` |
| `_pct` | Percentage | `coverage_pct` |
| `_flag` | Boolean indicator | `breach_flag`, `active_flag` |
| `_code` or `_cd` | Categorical code | `currency_code`, `risk_class_cd` |
| `_count` or `_cnt` | Count | `trade_count`, `breach_cnt` |
| `_ratio` | Ratio | `coverage_ratio` |
| `_name` or `_nm` | Text name field | `counterparty_name`, `legal_entity_nm` |
| `_desc` or `_descr` | Description text | `product_desc`, `event_descr` |
| `_type` | Type / category | `product_type`, `agreement_type` |

### When to derive a short name

The physical name is the default. A short name is derived **only** when a specific downstream consumer requires length-constrained columns:

- Regulatory feeds with fixed column-header length limits
- BI tool column headers with display-width constraints
- Legacy system integrations with character-length limits
- File format constraints (some flat-file specs)

If no such consumer exists for the column, no short name is needed.

### Derivation algorithms

**Business name → Physical name (canonical)**

1. Trim and lowercase the business name
2. Replace spaces with underscores
3. Strip any remaining special characters
4. Check length ≤ 30 characters
5. Apply correct suffix from the standard suffix table
6. Validate uniqueness within the schema

**Physical name → Short name (only if needed)**

1. Tokenise the physical name on underscores
2. For each token, look up the abbreviation in the Abbreviations Dictionary (Section G)
3. If no abbreviation exists, the token is kept as-is
4. Rejoin tokens with underscores
5. Validate the short name is ≤ 12-15 characters (typical consumer limit)

The PG Leader is the final arbiter when the algorithm produces an ambiguous result.

### Worked examples

| Business name | Physical name | Short name (if needed) | Notes |
|---------------|--------------|------------------------|-------|
| Counterparty Internal Rating | `counterparty_internal_rating` | `cp_int_rating` | Standard case |
| Potential Future Exposure | `potential_future_exposure` | `pfe` | Industry-standard short form |
| Expected Exposure | `expected_exposure` | `ee` | Industry-standard short form |
| Netting Set Identifier | `netting_set_id` | `ns_id` | `_id` suffix preserved in short form |
| Valuation Date | `valuation_date` | `val_dt` | `_date` → `_dt` standard abbreviation |
| Mark to Market | `mark_to_market_amount` | `mtm_amt` | "Mark to Market" is itself an established short form |
| Credit Spread Sensitivity at 01 bps | `credit_spread_sensitivity_01` | `cs01` | Industry-standard short form |
| Counterparty Name | `counterparty_name` | `cp_nm` | Both forms valid; `_name`/`_nm` is the standard suffix pair |

See the Abbreviations Dictionary (Section G) Tab 2 for 15 worked examples including aliases.

### App aliases — preserving the mapping back

When data enters the PG conformed schema from a source app, the original app column name is recorded as an alias against the canonical column.

Aliases are stored in the UC column tag `aliases` as a multi-value tag, with each entry in the form `app_name:original_column_name`. Multiple aliases are supported (a canonical column may have aliases from several source apps).

**Worked example — `counterparty_internal_rating`:**

| App | Original column name | Recorded as |
|-----|----------------------|-------------|
| XVALA | `cpIntRtg` | `xvala:cpIntRtg` |
| CMOS | `internal_rating_cd` | `cmos:internal_rating_cd` |
| REGDS | `ctp_irating` | `regds:ctp_irating` |

All three are stored as multi-value entries in the `aliases` tag on `creditrisk.conformed.dim_counterparty.counterparty_internal_rating`.

**Reverse lookup** — to answer *"which canonical column does XVALA's `cpIntRtg` map to?"*:

```sql
SELECT
  table_catalog,
  table_schema,
  table_name,
  column_name
FROM system.information_schema.column_tags
WHERE tag_name = 'aliases'
  AND tag_value LIKE '%xvala:cpIntRtg%';
```

### Rationalising legacy names

When an app's existing columns don't match the standard, three options:

| Option | When to use | Trade-off |
|--------|-------------|-----------|
| **Translate at conformance** (default) | Most cases — apps keep their names; canonical names start at the PG conformed schema; aliases preserve the mapping back | Apps unchanged; conformance layer carries the translation |
| **Rename in place** | Only when the app team is independently refactoring or when a regulatory driver requires it | Heavy migration; coordinate with App team |
| **Accept legacy** | Edge cases where naming doesn't matter (deprecated schemas, sandbox-only data) | Document explicitly; not the long-term answer |

**The default is translate-at-conformance.** Apps are not pressured to rename. The PG conformed schema is where standards take effect.

### Where UC tags carry the naming metadata

| Tag key | Value | Example |
|---------|-------|---------|
| `business_name` | The plain-English business name | `Counterparty Internal Rating` |
| `short_name` | The derived short form (only if derived) | `cp_int_rating` |
| `aliases` | Multi-value: `app:colname` entries | `xvala:cpIntRtg,cmos:internal_rating_cd,regds:ctp_irating` |

These tags are applied at the **column level** (not the table level) and are populated from the contract YAML. See the Data Contract Attribute Spec (Section C) for the full attribute set.

### Automation

The naming convention is enforced through three mechanisms:

1. **Pre-contract validation.** A linter validates contract YAML against the rules above before the contract is committed to Git.
2. **UC tag application.** The contract YAML drives the `ALTER TABLE SET TAGS` and `ALTER COLUMN SET TAGS` statements.
3. **Reverse-lookup utility.** A Python helper in the Risk Warehouse Git repo provides `find_canonical_column(app, original_name)` and `find_aliases(canonical_name)` functions for engineering use.

---

## I. Consumer Registry Schema

The consumer registry captures persistent consumers (dashboards, models, regulatory feeds) of Risk Warehouse data products. Lives as a physical table in `risk_governance` and is synchronised to Collibra.

### Table: `risk_governance.consumer_registry`

| Column | Type | Description |
|--------|------|-------------|
| `consumer_id` | string | Unique identifier (e.g., `ccr_executive_dashboard_v3`) |
| `consumer_type` | string | One of: `dashboard`, `model`, `report`, `feed`, `api` |
| `consumer_owner` | string | Named team or person responsible for the consumer |
| `consumer_platform` | string | Where it runs: `microstrategy`, `power_bi`, `python_model`, `informatica`, etc. |
| `producer_product` | string | Fully-qualified data product (e.g., `riskwh.gold.fact_exposure`) |
| `producer_version` | string | Contract version consumed (e.g., `1.2.0`) |
| `registered_date` | date | When the registration was made |
| `last_validated_date` | date | When the registration was last confirmed still active |
| `business_critical` | boolean | True if deprecating the producer would break a business-critical workflow |

### Who writes to it

| Action | Who |
|--------|-----|
| Register a new consumer | The consumer's owner team |
| Update / re-validate | Annually by consumer owner; quarterly review by Risk Data |
| Deprecate | Consumer owner on retirement of the consumer |

### Reverse lookup — who consumes a product

```sql
SELECT consumer_id, consumer_owner, business_critical
FROM risk_governance.consumer_registry
WHERE producer_product = 'riskwh.gold.fact_exposure'
  AND last_validated_date >= current_date - INTERVAL 365 DAYS;
```

### Relationship to other tracking patterns

The consumer registry is one of four consumer-tracking mechanisms. See the Intake-to-Contract Flow diagram (Section A) for the full picture:

| Pattern | What it captures |
|---------|------------------|
| Collibra subscription | Individuals formalise as known consumers |
| Query-log lineage | UC audit logs capture actual usage |
| Consumer registry (this) | Persistent consumers (dashboards, models, feeds) declare their producer dependencies |
| AD-group inheritance | BI tool AD group membership + registered dashboard = implicit subscription chain |

---
