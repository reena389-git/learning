# Tag consolidation — decisions (v4)

A critical pass over the tag set, organized by the questions you raised. The single source of
truth is now the **Glossary** sheet in `unity_catalog_standards_v4.xlsx`; the template
(`metadata_workbook_consolidated_v2.xlsx`) and the profiler both read from the same registry.

## 1. Tag key names — simplified
- Dropped the **`x-` prefix** from UC tag keys. It encoded "ODCS extension," but that already lives
  in the ODCS-path column, so the key doesn't need to repeat it. Keys are now clean and uniform.
- Fixed the doubled word: **`x-format_date_format` → `format_date`**.
- All-underscore convention (no more mixed hyphen+underscore in one key).
- 17 keys renamed in total (see "Removed & renamed" sheet); the ODCS paths are unchanged, so the
  contract generator still knows where each value lands. `old_key` is kept in the Glossary for traceability.

## 2. Mandatory — now three states, not yes/no
`always` / `conditional` / `optional` (plus `derived` for rolled-up tags). The insight: most genuinely-needed
tags are **conditional**, not universal.
- **always (13):** table name/description/comment, column name/type/comment, `visible`, `class_sensitivity`,
  `lifecycle`, `src_app`, `src_domain`, `own_technical`, `column_role`.
- **conditional (19):** only when the condition holds — `format_date` (date cols), `measure_unit` +
  `measure_aggregation` (measures), `class_pii` (PII cols), `currency_*` (FX applied), `pipeline`
  (intermediate tables), PK/FK/enum/NOT NULL, `glossary_term`.
- **optional (24)** and **derived (2):** `contract_grain` and table-level `class_pii` are computed, not authored.

## 3. Date vs timestamp — one key, not two
Kept a single `format_date` with two governed values (`YYYY-MM-DD`, `YYYY-MM-DD HH:MM:SS`). A column is a
date **or** a datetime, never both — that's one attribute with two values, not two keys. Once columns are
typed `DATE`/`TIMESTAMP`, the tag is largely redundant with the type; its value is mainly *now*, while dates
are still stored as ints/strings. **Timezone** stays a separate (soon-tier) tag — it's only meaningful for
timestamps and is orthogonal.

## 4. `shape` — kept, but slimmed
Restricted to the modeling archetypes UC doesn't already know: **`dim, fact, obt, lookup`**.
Dropped `view, materialized_view, table` — those are physical types Unity Catalog already exposes via
`information_schema.tables.table_type`, so tagging them duplicates catalog metadata.

## 5. Cut list — removed 5 redundant tags
- `x-issue` → removed (implied by presence of `issue_tracker`).
- `x-currency_applied` → removed (implied by presence of `currency_reporting`).
- `x-currency_native_kept` → removed (discoverable from the schema).
- `src_owner` → merged into `own_technical` (the doc itself said "often the same").
- `identity_alias` → removed as a stored tag (the business alias derives from the linked `glossary_term`;
  the profiler was literally setting them to the same string). Re-add only as a per-column override if needed.

## 6. Tiering — so launch isn't overwhelming
- **launch (~14 author-now tag keys):** `visible, class_sensitivity, class_pii, lifecycle, src_app,
  src_domain, own_technical, shape, column_role, glossary_term, format_date, measure_aggregation,
  measure_unit, pipeline` (+ the always-on properties). Most of the column-level ones the profiler proposes.
- **soon (phase 2):** refresh/load, the `currency_*` FX block, `timezone`, `measure_safe_dims/methodology/warning`,
  `issue_tracker`, schema precedence/calendar.
- **later:** the entire product/marketplace/contract/collibra block, `dependencies`, `source_precedence_override`.

## 7. Drift fixes folded in
- `measure_unit` governed list = **union** of standard + template: `USD, EUR, native_currency, percent, count, bps, ratio, days`.
- `src_app` gains `alfa, crs, tams, lrm` (to match the templates).
- `measure_warning` added as an (ungoverned, soon) tag — the templates asked for it but the standard had no key.
- `currency_fx_source` standardized to include `core_fx_rate`.

## Still pending your decision
`Base entity`, `Semantic role`, and `Key type` — three column attributes my consolidated workbook added that
aren't in the standard. Flagged as **EXTENSION** in the v2 template's Tag registry. Adopt them into the
standard (the profiler can fill Key type and Base entity) or drop them. Your call.

## What now emits aligned keys
The profiler's apply mode writes `format_date`, `column_role`, `glossary_term` (governed/standard keys),
proposes `measure_aggregation` / `measure_unit`, and no longer writes `identity_alias` or `owner_domain`.
