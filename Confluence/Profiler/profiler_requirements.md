# Metadata Profiler — Requirements Document

**Component:** Schema-level metadata profiler for the Risk Data Platform (Databricks / Unity Catalog)
**Owner:** Credit Risk Data team
**Status:** Draft for review — **v0.2**
**Reconciles:** the earlier "Risk Profiler v0.1" requirements list (model-free decision, conformance, embedded-entity detection) with this session's consolidated workbook and lineage/glossary/PowerDesigner additions.
**Related artifacts:** `metadata_workbook_consolidated.xlsx` (the metadata template the profiler fills), `credit_risk_abbreviations.csv` (the abbreviation/synonym dictionary), `semantic_profiler.py` (working prototype)

---

## 1. Purpose

Define the requirements for a **metadata profiler**: a Python component that inspects Databricks tables and **auto-populates as much of the metadata template as can be responsibly derived from data**, so that app teams enrich data with governed metadata (Unity Catalog comments, tags, constraints, ODCS data contracts) by *reviewing* proposals rather than typing everything by hand.

The profiler is the in-house, transparent equivalent of the automatic profiling/modelling hints a tool like Strategy One's Mosaic produces — but deterministic, explainable, air-gap-safe, and version-controllable.

## 2. Background

TD is moving data into Databricks from many legacy file systems, historically without consistent data-management hygiene. The strategic direction is to enrich datasets with metadata and publish governed **data products** (not bare datasets). Metadata is captured in a standard workbook and compiled into Unity Catalog comments/tags/constraints and ODCS v3 data contracts (YAML + DDL).

Filling that workbook by hand across an entire schema is slow and error-prone. A large fraction of the fields are *mechanical* (types, keys, relationships, enums, formats) and can be derived from the data and from Unity Catalog lineage. The profiler automates that fraction and leaves the business/governance judgement to humans.

## 3. Goals and non-goals

**Goals**
- Profile an entire **schema** (all tables) and propose metadata at column, table, and relationship level.
- Pre-fill the consolidated metadata workbook so app teams review-and-confirm.
- Operate inside an **air-gapped** environment with **no external AI** and only downloadable Python modules.
- Make every proposal **explainable** (carry a rationale, a provenance, and a confidence) and land it in a **draft/confirm** state.
- Support an **incremental** build: profile in waves, persist intermediate results, resolve cross-table dependencies against already-profiled tables.

**Non-goals**
- The profiler does **not** calculate any risk numbers; it describes existing data only.
- It does **not** publish metadata autonomously — a human confirms before anything becomes a public catalog description or an enforced constraint.
- It does **not** replace Databricks' PII auto-classification; it defers to it.
- It is **not** a connection to Mosaic/Strategy; it connects to the data (Databricks), and its output can later seed Mosaic.
- The **structural core is model-free** (types, keys, FKs-by-value, enums, formats need no model). An **optional semantic layer** (embeddings + FAISS) may be switched on to cover the residual *semantic* cases — see FR-16 — when an offline embedding source is available. FAISS is in scope as the search index; it is not required for the core to run.
- **Entity resolution is out of scope.** Deciding that the *values* "JPMC" and "JP Morgan Chase" are the same real-world entity is an MDM problem. Conformance here means structural sameness (shape + relationships + attribute identity), not value-level record matching.

## 4. Personas

- **Data engineer / app team** — runs the profiler, reviews proposals, confirms, applies to Unity Catalog.
- **Data product owner** — accountable for the published contract; signs off on public descriptions, classification, visibility.
- **Governance / platform team** — owns Unity Catalog, tags, ABAC, and the review workflow.

## 5. Definitions (brief)

Surrogate key, natural key, foreign key, alternate key, degenerate dimension — see §6.3. Semi-additive measure — a numeric measure that may be summed across some dimensions but not others (e.g. a balance sums across counterparties but not across `as_of_date`). ODCS — Open Data Contract Standard v3, the YAML contract format the workbook compiles to. Fingerprint — a compact sketch of a column's values (e.g. MinHash / top-N distinct + cardinality) used to detect joins without copying data.

---

## 6. Functional requirements

### FR-1 Inputs
- **FR-1.1** Accept a target at **schema** granularity (`catalog.schema`) and enumerate its tables from `information_schema.tables` (or `spark.catalog`).
- **FR-1.2** Read each table's **schema** (column names, types incl. `DECIMAL(p,s)`, declared nullability) directly — these are authoritative, not inferred.
- **FR-1.3** Read a **capped row sample** per table (configurable, default ≤ 200k) for cardinality/value-based inference; large tables are sampled, with exact checks optionally pushed to Spark SQL.
- **FR-1.4** Read **Unity Catalog column lineage** (`system.access.column_lineage` or the lineage REST API) to recover bronze→silver column mappings. Gracefully degrade when lineage is absent (see RISK-1).
- **FR-1.5** Load the **abbreviation/glossary dictionary** (`credit_risk_abbreviations.csv`) for name expansion and definition seeding.

### FR-2 Column profiling
For every column, produce: stored dtype; inferred semantic type (numeric / string / boolean / date / `YYYYMMDD`-int); null count and %; distinct count and cardinality ratio; numeric min/max/mean; sample values; and a numeric-parse fraction that flags **numbers stored as text** (so the team knows a `TRY_CAST(REPLACE(col,',',''))` is needed).

### FR-3 Key detection (drives `Role`, `Is primary key`, `Key type`, `FK references`)
The profiler proposes a **Key type** for each key column:
- **FR-3.1 surrogate** — a single-column, monotonic/unique `BIGINT`-like id with no value-overlap to any dimension. It is also the row's uniqueness key.
- **FR-3.2 natural** — the **minimal column set where `count(distinct) = count(*)`** that is made of business columns; this expresses the **grain**.
- **FR-3.3 foreign** — a column whose values are contained in another table's primary key (see FR-4); also fills `FK references`. A grain member may be both *foreign* and part of the *natural* key.
- **FR-3.4 alternate** — a column/set that is unique but is **not** the chosen primary key.
- **FR-3.5 degenerate** — a fact-resident identifier with no dimension of its own.
- **FR-3.6** Report the **surrogate PK and the natural grain separately** when both exist (a minimal-key search alone would return only the surrogate and miss the grain).

### FR-4 Relationship / dependency inference (schema-level)
- **FR-4.1** Across all table pairs in the schema, detect foreign-key relationships via **inclusion dependencies**: the fraction of a child column's distinct values present in a candidate parent's unique column, combined with name similarity.
- **FR-4.2** Emit each edge with parent/child, **cardinality** (`N:1` / `1:1` / flagged `N:N?`), containment, name similarity, and an overall **confidence**, plus a human-readable rationale.
- **FR-4.3** Normalise FK targets to canonical three-part names and **flag inconsistencies** (e.g. differing catalog prefixes for the same target).

### FR-5 Repeated-group (wide) detection
Detect families of columns sharing a stem with bucket/period suffixes (e.g. `*_0_3_mo … *_10_50_yr`) and flag them as **unpivot candidates** — one measure spread across a hidden dimension.

### FR-6 Aggregation suggestion (`Measure — aggregation`)
For numeric measures, propose **additive / semi-additive / non-additive**, including detection of the **semi-additive-across-dates** pattern (a measure unique per snapshot date ⇒ "do not sum across `as_of_date`"); seed `safe dims` and a `warning`. Ratios/percentages are never proposed as additive.

### FR-7 Definition and alias derivation (the air-gap-safe equivalent of Mosaic's comment generation)
- **FR-7.1 Alias** (`Alias (business name)`) — derive from the **bronze business-name header via UC column lineage**; fall back to a glossary-expanded, title-cased name when lineage is unavailable.
- **FR-7.2 Column comment (draft)** — compose deterministically from: name tokens expanded via the **glossary dictionary**, profile facts, the lineage business name, the `Allowed values` enum, and any matched glossary term. When the **semantic layer** (FR-16) is enabled, also retrieve the **nearest already-approved column comment** (FAISS nearest-neighbour over embeddings) as a draft seed — quality compounds as the catalog grows. Mark every derived comment as **"profiler-proposed — confirm"**; never publish without review.
- **FR-7.3 Optional internal-LLM hook (not part of the model-free core)** — a pluggable interface to an *approved internal* endpoint (e.g. firewalled Azure OpenAI / sanctioned Copilot API) for nicer comment prose only, **off by default**. It does **not** participate in conformance/matching (which is model-free per FR-16); it is a separately-approved enhancement to comment wording, never a dependency.

### FR-8 Glossary / abbreviation usage
- **FR-8.1** Tokenise physical column names and expand abbreviations using the dictionary (e.g. `cpty`→counterparty, `agrmnt`→agreement, `lei`→Legal Entity Identifier) to produce business names and seed definitions and `Glossary term link` matches.
- **FR-8.2** The dictionary is a maintained, version-controlled asset (CSV/Delta) seeded with credit-risk / derivatives industry terms and extensible by the team.
- **FR-8.3** *(optional semantic layer)* When enabled, embed each column's name + context and nearest-neighbour search the **glossary-term embeddings** (FAISS) to propose a **Glossary term link** even when neither spelling nor values match — the field steps 1–3 cannot populate.

### FR-9 PII
Do **not** rely on heuristics to assert PII. Run an optional name-regex first pass (`*_email`, `*_name`, `lei`) only as a hint; defer the authoritative call to the **Databricks classifier**, with the data product owner confirming. Align column-level PII with the table-level `PII present` flag.

### FR-10 Outputs
- **FR-10.1 Workbook emitter** — write the **consolidated metadata workbook** sheets (Schema / Table / Column / Glossary / Automation), pre-filled with the propose-able fields and blanks elsewhere, one row per column grouped by table, including `Key type` and (for facts) `Base entity` and `Semantic role`.
- **FR-10.2 Provenance per cell** — every auto-filled cell is marked **observed** (a fact read from schema/data) vs **suggested** (an inference), carries provenance (`read-from-schema` / `profiler-proposed` / `lineage-derived`) and a confidence, and — for suggestions — **support/exception counts** (e.g. the null count behind a nullability call, per-value support behind an enum, matched/unmatched value counts behind an FK or conformance match). Surfaced via a cell comment or a parallel `_source` column so reviewers see exactly what to check.
- **FR-10.3 Output is the human-approved form; downstream is separate** — the profiler's deliverable is the **filled workbook**, not YAML or catalog writes. ODCS v3 YAML, DDL, and the Unity Catalog push are **separate downstream automations that run off the approved form**, so a human gate always sits between profiling and anything governed. The profiler may *additionally* emit draft `COMMENT ON COLUMN` / constraint SQL for convenience, but it never applies them.

### FR-11 Intermediate profile store
- **FR-11.1** Persist results to a **Delta-backed store** in the team's own catalog (e.g. a `…_metadata` schema): (a) column profiles, (b) compact **value fingerprints** for key-ish columns only, (c) the proposed metadata rows with provenance, confidence, and timestamp.
- **FR-11.2** Store **metadata and sketches, never raw data**; hash values for sensitive columns. Fingerprints exist solely to test cross-table value overlap for relationship inference.
- **FR-11.3** Enable cross-run, cross-table FK inference (profile table A today, table B later, still find A↔B edges) and run-to-run diffs of proposals.

### FR-12 Schema-level, incremental operation
Support profiling a schema in **waves** (a logical group of tables at a time), accumulating into the profile store, so Unity Catalog metadata is built up table-by-table after review until the schema is complete.

### FR-13 Field automation matrix
The component's behaviour per field must match the **Automation** tab of the workbook (auto-read / propose / human). See Appendix A.

### FR-14 Intra-table functional dependencies → embedded entities (normalisation)
- **FR-14.1** Discover functional dependencies within a table (determinant → dependent columns) to surface **embedded entities** in denormalised/OBT tables — e.g. `issuer_name`, `issuer_type`, `issuer_rating` all determined by an issuer key reveal an embedded **Issuer** dimension.
- **FR-14.2** Classify the embedded relationship: 1-to-many via a determinant→grain dependency; many-to-many via a junction/bridge signature.
- **FR-14.3** Report embedded-entity candidates in a **separate section** of the output; they feed the `Base entity` field and the star-schema/PowerDesigner step. (Does not auto-split tables — proposal only.)

### FR-15 Cross-table conformance & entity clustering (Phase 3)
- **FR-15.1** Detect that **differently-named columns are the same attribute** (conformance), using — in priority order — **value-overlap** (the primary signal, computed in Spark SQL), then **lexical** name similarity (`rapidfuzz`), then the **curated synonym dictionary** (e.g. `iss_id` ↔ `obligor_identifier` match on values; `cpty` ↔ `counterparty` via the dictionary).
- **FR-15.2** Cluster matched columns/embedded entities across the schema into **candidate conformed dimensions** (e.g. a single conformed Counterparty appearing in many facts), optionally using `networkx` for the clustering, and dedupe embedded entities across tables.
- **FR-15.3** Conformance is **shape + relationships + attribute identity only**; value-level entity resolution is out of scope (see §3, MDM).

### FR-16 Matching strategy — model-free core + optional semantic layer
Matching runs as a **cascade**, cheapest-and-most-certain first:
1. **Value-overlap** (primary, Spark SQL) — same values ⇒ same attribute, regardless of name.
2. **Lexical** (`rapidfuzz`) — name similarity for near-spellings.
3. **Curated synonym dictionary** — abbreviations/synonyms (`cpty`↔counterparty).
4. **Semantic layer (optional, embeddings + FAISS)** — for the residual cases that share neither values nor spelling (`obligor` vs `legal_entity`): embed each column's name+context and nearest-neighbour search against (a) the **glossary terms**, (b) the corpus of **already-approved column comments**, and (c) **other columns** for conformance. FAISS is the ANN index; the embedding vectors come from an **offline source** (an internal model registry, the **Databricks Foundation Model API**, or staged `sentence-transformers`/`fastText` weights). The layer is **off by default** and degrades gracefully to steps 1–3 when no embedding source is available.

**Why include it:** the semantic layer is what lets the profiler populate **Glossary term link**, seed a real **Column comment** draft by retrieving the nearest already-documented column, and resolve the conformance/`Base entity` residual — fields that steps 1–3 cannot reach. Below a few thousand searchable items, brute-force cosine (numpy) suffices; **FAISS earns its place once the searchable corpus (all columns + glossary + accumulated comments) is large.**

### FR-17 Physical data model / visualisation (PowerDesigner, Phase 4)
- **FR-17.1** After the form is approved, the downstream DDL generator produces a script that **SAP PowerDesigner 16.x** reverse-engineers into a **Physical Data Model (PDM)** and ER diagram (`File ▸ Reverse Engineer ▸ Database`, choosing a generic/ANSI DBMS — 16.x predates Databricks and has no native profile).
- **FR-17.2** The DDL must put **primary keys, foreign keys, and CHECK constraints INLINE in each `CREATE TABLE`**, because PowerDesigner reverse-engineering reads `CREATE` statements and **skips `ALTER TABLE … ADD CONSTRAINT`** (only add-column ALTERs are honoured). Confirmed FK relationships then render as relationship lines; column comments render as descriptions (use an inline-`COMMENT` dialect so they import).
- **FR-17.3** PowerDesigner is a desktop modelling tool, not a Python dependency; it consumes the generated DDL. (Live JDBC reverse-engineering from Databricks is possible but needs a generic driver and auth, so the DDL-script path is preferred and air-gap-friendly.)


---

## 7. Non-functional requirements

- **NFR-1 Air-gap / offline.** No external AI or internet calls in the core. Dependencies limited to downloadable modules: `pandas`, `numpy`, and (for laptop runs) `databricks-sql-connector`, `databricks-sdk`. Any LLM hook targets an approved internal endpoint only and is off by default.
- **NFR-2 Deployment modes.** (a) **Inside Databricks** (notebook/job) — preferred; `spark` is pre-authenticated, no keys, data stays on-platform. (b) **From a workstation** — via OAuth **U2M** (browser SSO, no stored key); PAT only as a fallback; OAuth **M2M** (service principal) for scheduled jobs.
- **NFR-3 Data minimisation.** Only schema + a capped sample are read; only sketches are persisted; PII values are hashed, never copied.
- **NFR-4 Governance & explainability.** Every proposal carries rationale + provenance + confidence and lands in draft state; humans confirm before publish. Outputs are exportable to YAML for Git version control.
- **NFR-5 Performance & scale.** Use sampling and `approx_count_distinct` for large tables; bound the pairwise relationship search (key-ish columns only, capped distinct sets); profile big schemas in waves. State the pairwise cost growth and mitigate it.
- **NFR-6 Security & permissions.** Honour Unity Catalog permissions (BROWSE/SELECT); lineage system tables require enablement and appropriate grants; the profile store is permission-scoped.
- **NFR-7 Auditability.** Persist `updated_by` / timestamp on proposals; keep a history for review and rollback.

## 8. Deployment modes (summary)

| Mode | Auth | Keys? | When |
|---|---|---|---|
| In-Databricks notebook/job | Cluster identity | None | Preferred — schema profiling, scheduled builds |
| Workstation (interactive) | OAuth U2M (browser SSO) | None (auto-refresh) | Ad-hoc profiling from a laptop |
| Workstation fallback | PAT | One stored token | Only if OAuth U2M unavailable |
| Scheduled (unattended) | OAuth M2M (service principal) | Client secret (platform-managed) | Automated re-profiling |

## 9. Assumptions and dependencies

- Tables are registered in Unity Catalog (not raw paths) so that lineage and `information_schema` work.
- Bronze→silver transformations are plain projections/renames (not hidden in UDFs) where lineage-based alias recovery is expected.
- The ODCS YAML/DDL generator already exists in the workbook tooling.
- The abbreviation dictionary is seeded and maintained by the team.

## 10. Risks and limitations

- **RISK-1 Lineage gaps.** Column lineage is not captured when the source/target is referenced by **path** rather than table name, or when a **UDF** obscures the mapping; the system tables hold only a rolling 1-year window (the lineage API/Catalog Explorer retain longer). Mitigation: fall back to fuzzy name matching via the glossary; use the lineage API for older history.
- **RISK-2 Sample-based false positives.** A column unique in a sample may not be a key across the full table; absence of nulls in a sample is not `NOT NULL`. Mitigation: never assert `NOT NULL` or a key from a sample — propose only; confirm with a Spark full-table check before enforcing a constraint.
- **RISK-3 Coincidental relationships.** In large schemas, value overlap can imply spurious FKs. Mitigation: confidence + containment thresholds and human pruning.
- **RISK-4 Enum completeness.** `Allowed values` reflects observed values only; humans close the domain before it becomes a CHECK.
- **RISK-5 PII.** Heuristic PII detection is unreliable; defer to the Databricks classifier + human confirm.

## 11. Acceptance criteria

- **AC-1** Given a schema, the profiler emits a pre-filled consolidated workbook with one row per column across all tables, every auto-filled cell carrying provenance + confidence, and all human/governance fields left blank.
- **AC-2** Keys are reported with correct `Key type` (surrogate vs natural vs foreign vs alternate), and surrogate PK and natural grain are surfaced separately on a fact.
- **AC-3** Cross-table FK edges are produced with cardinality + confidence, FK targets normalised, and inconsistencies flagged.
- **AC-4** Numbers-as-text, `YYYYMMDD`-int dates, and wide repeated groups are detected and flagged.
- **AC-5** Aliases and draft comments are derived (lineage where available, glossary otherwise) and clearly marked "confirm".
- **AC-6** The component runs unchanged inside a Databricks notebook with no stored credentials, and the profile store contains sketches — not raw data.
- **AC-7** No external network/AI calls occur in the default configuration.
- **AC-8** Embedded entities (intra-table functional dependencies) and cross-table conformance candidates are detected model-free (value-overlap + rapidfuzz + dictionary) and reported in a separate section with support/exception counts; no value-level entity resolution is attempted.
- **AC-9** The downstream DDL (inline PK/FK/CHECK + inline comments, no ALTER constraints) reverse-engineers cleanly into a PowerDesigner 16.x PDM, with FKs as relationship lines and comments as descriptions.

## 12. Open questions / future scope

- Enable the internal-LLM hook once an approved firewalled endpoint exists.
- A `to_mosaic_yaml()` emitter to seed the Strategy/Mosaic model from reviewed metadata.
- Auto-generation of informational `ALTER TABLE … ADD CONSTRAINT` for confirmed PK/FK.
- "Bring your own lineage" for upstream file systems outside Databricks.

---

## Appendix A — Field automation matrix

Legend: **read** = taken from the live schema (authoritative) · **propose** = profiler suggests, human confirms · **human** = business/governance judgement, profiler leaves blank.

### Table-level
| Field | Mode | Basis |
|---|---|---|
| Table name | read | UC |
| Data type / column list | read | UC schema |
| Table shape (dim/fact) | propose | cardinality + measure/FK/date patterns |
| PII present | propose | column-level PII (classifier) |
| Table description, ownership, classification, lifecycle, visibility, refresh, FX, precedence, scope | human | governance |

### Column-level
| Field | Mode | Basis |
|---|---|---|
| Column name, Data type | read | UC schema |
| Nullable | propose | nulls observed ⇒ yes; never assert NOT NULL from a sample |
| Role (structural) | propose | identifier-like / numeric-varying / timestamp |
| Is primary key | propose | minimal set where distinct = count |
| Key type | propose | surrogate / natural / foreign / alternate / degenerate |
| FK references | propose | inclusion dependency vs other PKs |
| Base entity (fact) | propose | FK target dimension |
| Allowed values | propose | observed distinct (low-cardinality strings) |
| Date format | propose | ISO pattern detection |
| Measure — aggregation | propose | additive / semi-additive / non-additive |
| Alias (business name) | propose | UC column lineage (bronze header) → glossary fallback |
| Column comment | propose (draft) | lineage + heuristics + enum + glossary |
| Glossary term link | propose | token match to dictionary |
| PII (column) | propose | Databricks classifier; owner confirms |
| Semantic role, Timezone, Measure unit/methodology, Internal notes | human | judgement |

## Appendix B — Key-type definitions
surrogate · natural · foreign · alternate · degenerate — see FR-3. A column may be both *foreign* and part of the *natural* key; the enforced primary key (marked `Is primary key`) may be the surrogate, while the natural grain is the set of business key columns.

## Appendix C — Consolidated libraries / dependencies

**Core (offline, model-free):**
- `pandas`, `numpy` — profiling.
- `rapidfuzz` — lexical name matching (Levenshtein / Jaro-Winkler / token-set). Pure, no internet.
- `openpyxl` — read/write the metadata workbook (populate the template in place).
- `PyYAML` — downstream ODCS YAML emission.
- `networkx` *(optional)* — entity clustering for conformance (Phase 3).
- **Value-overlap profiling** — the primary conformance signal — is computed in **Spark SQL**, no library.

**Connectivity (workstation runs only; not needed inside Databricks):**
- `databricks-sql-connector`, `databricks-sdk` — OAuth U2M/M2M to a SQL warehouse.

**Optional / later:**
- `mstrio-py` — only if/when seeding the Strategy/Mosaic model.

**Optional semantic layer (FR-16) — improves coverage; requires an offline embedding source:**
- `faiss-cpu` — the ANN index (pip wheel, **no model weights**).
- An **embedding source**, one of: the **Databricks Foundation Model API** (no pip, no weights to manage — preferred if available); or `sentence-transformers` (pulls `torch`/`transformers`, needs a staged model file e.g. `all-MiniLM-L6-v2`); or `fastText` (lighter; needs a staged `.bin` vectors file).
- Below a few thousand searchable items, `numpy` brute-force cosine replaces FAISS.

**Desktop tool (not a Python dependency):** SAP PowerDesigner 16.x — consumes the generated DDL to build the PDM/ERD (FR-17).

All core Python packages are pip-standard and available from an internal mirror; confirm the mirror carries `rapidfuzz`, `networkx`, and `faiss-cpu`. **Model weights are not on PyPI** — stage them separately or use the Databricks Foundation Model API.

### Coverage impact (of the original 19 column fields)
Structural + lineage work already takes auto-coverage from ~9 to ~12 (adds Key type, Base entity, lineage-derived Alias, aggregation). The **semantic layer adds Glossary term link and a retrieval-seeded Column comment draft**, and strengthens Alias/Base entity/Semantic role on the residual — reaching ~13–15 proposable, with Measure safe-dims/warning auto-seeded from the aggregation call. Genuinely human regardless of FAISS: **Timezone, Measure unit, Measure methodology, Internal notes** (and PII, which is the classifier's call).

## Appendix D — Install / availability commands

**Online install (mirror reachable):**
```bash
# core (offline, model-free)
pip install pandas numpy rapidfuzz openpyxl pyyaml networkx
# Databricks connectivity (workstation runs only)
pip install databricks-sql-connector databricks-sdk
# optional: seed Strategy/Mosaic later
pip install mstrio-py
# optional semantic layer
pip install faiss-cpu
pip install sentence-transformers     # OR: pip install fasttext   (OR use the Databricks FM API)
```

**Databricks notebook:** prefix each with `%pip install …` (then `dbutils.library.restartPython()`), or attach as cluster/workspace libraries.

**Check availability on the mirror (no install):**
```bash
pip index versions faiss-cpu          # repeat per package
```

**Stage wheels for offline upload (the air-gapped pattern):**
```bash
pip download pandas numpy rapidfuzz openpyxl pyyaml networkx \
  databricks-sql-connector databricks-sdk mstrio-py faiss-cpu \
  -d ./wheels
# install later, fully offline:
pip install --no-index --find-links ./wheels <package>
```
Note: `pip download` fetches **wheels only, not model weights** — `sentence-transformers`/`fastText` model files must be staged separately (or use the Databricks FM API).
