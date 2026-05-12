# F. Naming Convention Standard

*Authority: PG Leaders define names at the `<pg>.conformed` schema. Risk Data implements technically. Names carry up to the Risk Warehouse and down to apps via aliases.*

*Companion artefacts: Naming Convention Flow diagram (Section A of this page) · Abbreviations Dictionary (Section G).*

## Scope

Every column in every analytics-layer table has four name forms:

| Form | What it is | Where it lives |
|------|------------|----------------|
| **Business name** | Plain-English label (e.g., *Counterparty Internal Rating*) | UC column tag `business_name` · Collibra |
| **Physical name** | The actual column name in SQL (e.g., `counterparty_internal_rating`) | The table itself |
| **Short name** | Derived abbreviated form for length-constrained consumers (e.g., `cp_int_rating`) | UC column tag `short_name` — only if derived |
| **App aliases** | Original column names from source apps (e.g., XVALA's `cpIntRtg`) | UC column tag `aliases` — multi-value, one entry per source app |

All four names point to the same logical column. The mapping is recorded once at the conformance step.

## Authority

Names are defined and owned by the **PG Leader** at the PG conformed schema (`creditrisk.conformed`, `marketrisk.conformed`, etc.). New names entering the analytics layer pass through PG-level review.

- **Risk Warehouse** (`riskwh.*`) uses the same canonical physical names defined at the PG layer
- **App schemas** keep their original names; the conformance step records app names as aliases against the canonical column
- **Legacy app names are not forced to rename.** Translation happens at the conformance step

## Rules for physical names

1. **Lowercase only.** `counterparty` not `Counterparty` or `COUNTERPARTY`.
2. **snake_case for compound names.** Words separated by underscores: `counterparty_internal_rating`.
3. **No special characters.** Letters, digits, underscores only. No spaces, dots, dashes, slashes.
4. **Standard suffixes** carry semantic meaning (see table below).
5. **No SQL reserved words** as bare column names: avoid `date`, `time`, `user`, `table`, `order`, `group`, `type`. Use `valuation_date`, `event_time`, `user_id`, `record_type`.
6. **Maximum 30 characters** for cross-system portability. Above 30, derive a short form via the abbreviations dictionary.
7. **Short forms (when needed) use the abbreviations dictionary.** No inventing new abbreviations ad hoc.

## Standard suffixes

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

## When to derive a short name

The physical name is the default. A short name is derived **only** when a specific downstream consumer requires length-constrained columns:

- Regulatory feeds with fixed column-header length limits
- BI tool column headers with display-width constraints
- Legacy system integrations with character-length limits
- File format constraints (some flat-file specs)

If no such consumer exists for the column, no short name is needed.

## Derivation algorithm

```
Business name → Physical name (canonical)

1. Trim and lowercase the business name
2. Replace spaces with underscores
3. Strip any remaining special characters
4. Check length ≤ 30 characters
5. Apply correct suffix from the standard suffix table
6. Validate uniqueness within the schema
```

```
Physical name → Short name (only if needed)

1. Tokenise the physical name on underscores
2. For each token, look up the abbreviation in the Abbreviations Dictionary
3. If no abbreviation exists, the token is kept as-is
4. Rejoin tokens with underscores
5. Validate the short name is ≤ 12-15 characters (typical consumer limit)
```

The PG Leader is the final arbiter when the algorithm produces an ambiguous result.

## Worked examples

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

## App aliases — preserving the mapping back

When data enters the PG conformed schema from a source app, the original app column name is recorded as an alias against the canonical column.

Aliases are stored in the UC column tag `aliases` as a multi-value tag, with each entry in the form `app_name:original_column_name`. Multiple aliases are supported (a canonical column may have aliases from several source apps).

### Worked example — `counterparty_internal_rating`

| App | Original column name | Recorded as |
|-----|----------------------|-------------|
| XVALA | `cpIntRtg` | `xvala:cpIntRtg` |
| CMOS | `internal_rating_cd` | `cmos:internal_rating_cd` |
| REGDS | `ctp_irating` | `regds:ctp_irating` |

All three are stored as multi-value entries in the `aliases` tag on `creditrisk.conformed.dim_counterparty.counterparty_internal_rating`.

### Reverse lookup

To answer *"which canonical column does XVALA's `cpIntRtg` map to?"*:

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

## Rationalising legacy names

When an app's existing columns don't match the standard, three options:

| Option | When to use | Trade-off |
|--------|-------------|-----------|
| **Translate at conformance** (default) | Most cases — apps keep their names; canonical names start at the PG conformed schema; aliases preserve the mapping back | Apps unchanged; conformance layer carries the translation |
| **Rename in place** | Only when the app team is independently refactoring or when a regulatory driver requires it | Heavy migration; coordinate with App team |
| **Accept legacy** | Edge cases where naming doesn't matter (deprecated schemas, sandbox-only data) | Document explicitly; not the long-term answer |

**The default is translate-at-conformance.** Apps are not pressured to rename. The PG conformed schema is where standards take effect.

## Where UC tags carry the naming metadata

| Tag key | Value | Example |
|---------|-------|---------|
| `business_name` | The plain-English business name | `Counterparty Internal Rating` |
| `short_name` | The derived short form (only if derived) | `cp_int_rating` |
| `aliases` | Multi-value: comma-separated `app:colname` entries | `xvala:cpIntRtg,cmos:internal_rating_cd,regds:ctp_irating` |

These three tags are applied at the column level (not the table level) and are populated from the contract YAML. See *Data Contract Attribute Spec* for the full attribute set.

## Automation

The naming convention is enforced through three mechanisms:

1. **Pre-contract validation.** A linter validates contract YAML against the rules above before the contract is committed to Git.
2. **UC tag application.** The contract YAML drives the `ALTER TABLE SET TAGS` and `ALTER COLUMN SET TAGS` statements.
3. **Reverse-lookup utility.** A Python helper (in the Risk Warehouse Git repo) provides `find_canonical_column(app, original_name)` and `find_aliases(canonical_name)` functions for engineering use.

---

*See Section G — Abbreviations Dictionary for the canonical list of short-form abbreviations.*
