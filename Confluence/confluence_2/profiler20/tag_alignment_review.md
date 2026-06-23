# Tag alignment review — standards doc vs templates vs consolidated workbook

Checked `unity_catalog_standards_restructured__3_.xlsx` against the two filled templates
(`star_fact_issuer_exposure.xlsx`, `star_dim_counterparty.xlsx`) and the consolidated workbook
I built (`metadata_workbook_consolidated.xlsx`). Covers three things you asked: do the tags
correspond, what can the profiler populate, and the date-tag fix.

---

## 1. The headline: the date tag

The profiler was emitting **`semantic_type:date`**. That key does **not** exist in any of the three
artifacts. All three use the same column-level governed tag:

> **`x-format_date_format`** — governed values `YYYY-MM-DD`, `YYYY-MM-DD HH:MM:SS`
> (standards doc → "Date format" row; both templates → "Date format" field; consolidated Automation sheet → `x-format_date_format`, profiler = **yes**)

**Fixed.** The profiler now emits `x-format_date_format` in apply mode, with the value chosen from the
detected format (`YYYY-MM-DD HH:MM:SS` if a time component, else `YYYY-MM-DD`). The *current storage*
format it detects (e.g. `YYYYMMDD` int for `line_expiry`) stays in the proposal/notes as current-state;
the **tag** carries the governed target format. The optional physical rename (`line_expiry → line_expiry_date`)
is still printed as a manual, never-executed suggestion.

So: the date tag did **not** need adding to the standards doc — it was already there as
`x-format_date_format`. The profiler simply had to speak that key, which it now does.

---

## 2. Column-tag correspondence + what the profiler can populate

Friendly name → standards tag key → can the profiler fill it. "Wired" = the profiler does it today;
"propose" = it prints/persists a proposal for your review; "future" = capability exists, not yet wired.

| Friendly (template) | Standards tag key | Governed values | Profiler |
|---|---|---|---|
| Column name | *(property)* | — | **read** |
| Data type | `logicalType` *(property)* | — | **read** + proposes corrected type |
| Column comment | *(COMMENT)* | free text | **wired** — business definition from glossary |
| Alias (business name) | `identity_alias` | free text | **wired** — canonical term |
| Glossary term link | `glossary_term` | free text | **wired** — matched token/term |
| Role (structural) | `column_role` | key, measure, dimension, audit | **wired** — proposed per column |
| Is primary key | *(PRIMARY KEY ddl)* | — | **wired** — key detection |
| Date format | `x-format_date_format` | YYYY-MM-DD, YYYY-MM-DD HH:MM:SS | **wired** |
| Allowed values | *(CHECK ddl)* | free text | **propose** (enum candidates; CHECK DDL emission = future) |
| Nullable | *(NOT NULL ddl)* | yes/no | future — currently assumes nullable, can propose NOT NULL where 0 nulls |
| Measure — aggregation | `x-measure_aggregation` | additive, semi-additive, non-additive | **propose** (printed, needs review) |
| Measure — unit | `x-measure_unit` | USD, EUR, native_currency, percent, count, bps *(+ratio, days — see §4)* | **propose** (printed, needs review) |
| Measure — methodology | `x-measure_methodology` | free text (engine+version) | no — human |
| Timezone | `x-format_timezone` | ungoverned | no — not reliably inferable |
| FK references | *(FOREIGN KEY ddl)* | — | future (cross-table, FR-15) |
| PII (column) | `class_pii` | true | no — leave to Databricks AI classification |

Table-level: the profiler can **read** the name/type, **propose** `shape` (dim/fact from structure)
and `contract_grain` (from the PK columns it validates), and flag `class_pii` candidates. Everything
else table-level (`src_app`, `src_domain`, `class_sensitivity`, `lifecycle`, `visible`, refresh/FX) is
a human/governance decision — the profiler does **not** populate those.

**One deliberate change:** the profiler no longer emits an `owner_domain` column tag (that key isn't in
the standard). Your glossary's `owner_domain` is still carried in `profiler_proposals` as context —
it's stewardship routing, and it informs the **table-level** `src_domain` rollup — but the column→glossary
bridge in the standard is `glossary_term`, which is what the profiler now writes.

---

## 3. The three artifacts agree on the core — with a few vocabulary drifts

The standards doc, both templates, and my consolidated workbook are **structurally consistent**: same
column fields, same `column_role` set (key/measure/dimension/audit), same date-format governed values,
same measure-tag shape. The drifts below are **controlled-vocabulary mismatches** to reconcile so the
profiler's governed values are unambiguous.

| Tag | Standards doc | Templates | Issue |
|---|---|---|---|
| `src_app` (Producing app) | xvala, cmos, vs, rcs | xvala, cmos, vs, rcs, **alfa, crs, tams, lrm** | **standards doc is missing 4 apps** the templates already use |
| `x-measure_unit` (Measure — unit) | USD, EUR, **native_currency**, percent, count, bps | USD, EUR, percent, count, bps, **ratio, days** | each has values the other lacks |
| `x-currency_fx_source` (FX source) | MIDAS, LAMP, Bloomberg, **core_fx_rate** | MIDAS, LAMP, Bloomberg | templates missing `core_fx_rate` |
| Measure — warning | *(no such tag)* | "Measure — warning" (non-additive) | template field has no standards tag — add `x-measure_warning` (ungoverned) |

My consolidated workbook also introduced three column attributes that are **not** in the standards doc:
`Base entity` (`baseEntity`), `Semantic role` (`x-column-role`, separate from structural `column_role`),
and `Key type` (`x-key-type` = natural/surrogate/alternate). These are useful (the profiler can fill
`Key type` and `Base entity`), but right now they're a fourth source of drift. Decide: adopt them into
the standard, or drop them from the consolidated workbook.

---

## 4. Recommended reconciliation (to keep everything aligned)

So that any tag the profiler emits is valid against both the standard and the templates:

1. **`x-measure_unit`** — adopt the **union** as the governed list:
   `USD, EUR, native_currency, percent, count, bps, ratio, days`. This is the one that matters most for
   you, because your stress metrics need `ratio`/`percent` (percentage_of_impact) and `native_currency`
   (pre-FX amounts), and the profiler proposes this tag.
2. **`src_app`** — add `alfa, crs, tams, lrm` to the standards doc so it matches the templates.
3. **`x-currency_fx_source`** — pick one: add `core_fx_rate` to the templates, or drop it from the standard.
4. **`x-measure_warning`** — add as an ungoverned column tag in the standards doc (the templates already
   ask for it).
5. **Consolidated extras** — either promote `Key type` / `Base entity` / `Semantic role` into the
   standards doc, or remove them from the consolidated workbook to avoid a fourth divergent source.

I can patch the standards `.xlsx` (items 1–4) and regenerate the governed-tag DDL from the updated
Allowed-values column whenever you want — just say which way you want each drift resolved.

---

## 5. Pre-existing tags on your live tables

Worth flagging: `ats_summary` in your catalog already carries `measure_type:amount` and
`semantic_type:scenario_n…`. **Neither key is in the new standard.** The standards equivalents:

- `measure_type:amount` → `column_role = measure` + `x-measure_unit = USD` (or `native_currency`) + `x-measure_aggregation = additive`
- `semantic_type:scenario` → `column_role = dimension` (+ `glossary_term = scenario`)

These were applied before this standard existed. They don't break anything, but to be conformant they
should be migrated to the standard keys. The profiler's apply mode will *propose* the correct
replacements (`column_role`, the measure tags) the next time it runs over those tables.
