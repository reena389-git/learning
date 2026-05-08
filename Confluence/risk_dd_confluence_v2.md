# Risk Data — Confluence Content Source File · v2

*Build instructions for Reena: each `## PAGE: <name>` section below corresponds to one Confluence page. Create the page with that exact name, paste the content under that heading. Where you see `[/toc]` insert Confluence's Table of Contents macro (type `/toc` and select "Table of Contents"). Where you see `[IMAGE: ...]` paste the image from the source file noted.*

*Page hierarchy in your space:*

```
Risk Architecture (existing parent)
│
├── 🌟 Risk Analytics — North Star  ........................ [SIBLING page]
│
├── 🔧 Risk-Databricks Operating Model  ..................... [YOUR separate page; not in this file]
│
└── Risk Data — Operating Model & Standards  ............... [LANDING page]
    ├── 1. Operating Model
    ├── 2. Architecture & Design
    ├── 3. Standards & Artifacts Library
    ├── 4. Glossary & Terminology
    ├── 5. Worked Example — Counterparty 360 Product
    └── 6. Governance & Cadence
```

---

## PAGE: Risk Analytics — North Star

*Risk Architecture › Risk Analytics — North Star*

[/toc]

> **Page purpose:** A plain-language vision statement for where Risk Analytics is headed and why.
> **Read this if:** you want context on the strategic direction before going into operating-model details.

---

### Why current risk analytics feels difficult

Most risk organisations today are application-centric. Applications produce calculations, reports, and extracts — but business teams still spend large amounts of time reconstructing meaning before analytics can begin.

| Current experience | Typical result |
|--------------------|----------------|
| Different applications produce different formats | Manual reconciliation |
| Business teams merge spreadsheets repeatedly | Duplicated logic |
| Metrics interpreted differently across teams | Conflicting numbers |
| Users connect directly to app outputs | Fragile downstream dependencies |

### The core insight

Applications generate risk calculations. **They do not automatically generate reusable analytical meaning.**

> Modern risk analytics industrialises meaning so that business users consume trusted, reusable insights.

### The risk data journey

[IMAGE: Risk Data Journey (vision style) — paste from `north_star_visuals_v1.pptx`, Slide 1]

The same data evolves through six maturity stages before it becomes trusted self-service analytics. Each stage adds something specific. Skip a stage and that stage's value is missing.

### Same business question, two consumer experiences

[IMAGE: Today vs Future State — paste from `north_star_visuals_v1.pptx`, Slide 2]

The same business ask — *"Show total exposure, collateral, stress exposure, and breaches for ABC Bank"* — produces a very different consumer experience depending on whether the underlying data is application-centric or analytics-centric.

### Where this is heading

Applications continue to generate risk calculations.
Analytics products industrialise meaning.
Business consumes trusted, reusable insights.

The objective is not simply more reporting. The objective is **trusted, scalable, reusable analytics.**

---

**Where to next:**

- → For how this works in practice: **Risk Data — Operating Model & Standards** (landing)
- → For the technical platform: **Risk-Databricks Operating Model**

---

## PAGE: Risk Data — Operating Model & Standards

*Risk Architecture › Risk Data — Operating Model & Standards*

*Maintained by Risk Data Director · Audience: app teams, business, central, infra · Updated May 2026*

> **Page purpose:** Landing page for everything related to how Risk Data operates day-to-day.
> **Read this if:** you're an app owner, business stakeholder, central, or infra team interacting with Risk Analytics.

---

### What's in this space

This space documents **how Risk Data operates** — who does what, the standards everyone follows, the templates teams use, and the patterns that keep things consistent as more teams come on board.

| Page | What's there | Read this if you... |
|------|--------------|---------------------|
| **1. Operating Model** | Teams, roles, working relationships, federation model | want to know who does what |
| **2. Architecture & Design** | Data journey, artifact types, code & update behaviours, 360 pattern | want to understand how Risk Data is structured |
| **3. Standards & Artifacts Library** | Onboarding form, contract template, UC tag standards, schema standard, semantic layer template | are bringing data to analytics or building a data product |
| **4. Glossary & Terminology** | Core concepts, the 6 stages explained, common confusions resolved | hear a term and want to know what it means |
| **5. Worked Example — Counterparty 360 Product** | End-to-end walk-through of how a 360-style product works | want to see the patterns applied to a real example |
| **6. Governance & Cadence** | Meeting cadence, project roster, change management for these standards | want to know how decisions get made |

### How to engage

- **App teams:** Start with *Operating Model* to understand what's expected. Then *Standards & Artifacts Library* when bringing data to the analytics layer.
- **Business:** Start with *Operating Model* for who-does-what. *Worked Example* shows how analytics products serve business questions.
- **Central / Infra:** *Operating Model* explains where Risk fits in the federated picture.

### Quick links

- 🔗 [CDO Standards & Policies](URL_PLACEHOLDER)
- 🔗 [Enterprise Architecture wiki](URL_PLACEHOLDER)
- 🔗 [Data Sharing](URL_PLACEHOLDER)
- 🔗 [Enterprise Data Classification](URL_PLACEHOLDER)
- 🔗 [Risk Analytics — North Star](URL_PLACEHOLDER) *(sibling page)*
- 🔗 [Risk-Databricks Operating Model](URL_PLACEHOLDER) *(sibling page)*

### Contribution model

Public-readable, DD-write. Proposed changes from any team — please comment on the relevant page or message the DD directly. See *Governance & Cadence* for how change management works.

---

## PAGE: 1. Operating Model

*Risk Architecture › Risk Data — Operating Model & Standards › 1. Operating Model*

[/toc]

> **Page purpose:** Documents who does what in Risk Data — the eight roles, how they work together, and how decisions get made.
> **Read this if:** you need to know who to talk to, who owns what, or how Risk Data interacts with Central, Infra, and Business.

---

### Teams & roles

[IMAGE: Persona Map — paste from `dd_persona_rasci_v1.pptx`, Slide 1]

> **The BI tool layer** (MicroStrategy, Databricks Metric Views, dbt) sits on top of all this. DD defines what the metrics mean; the BI team builds the dashboards.

### Risk Data Director

[IMAGE: DD Working Relationships — paste from `dd_relationships_v1.pptx` or `.jpg`]

DD is **one person** — an individual contributor, working through the Tech Lead and through app teams. Authors the standards in this space. Convenes business + apps + central. Maintains a project roster reviewed weekly with PG Leaders. **DD is not in a vacuum.**

### Making decisions — federated model

The single most important principle in this space:

**Three areas. One owner per area.**

| Context | Who owns it | What is implemented/stored |
|---------|-------------|---------------------------|
| **Applications** | App team | Logic, business rules, App Data Schema, Risk Generated Data |
| **Analytics** | DD / Risk Data Warehouse | Curated data products, Contracts, Semantic definitions, analytics dashboards |
| **Risk Domain Models** | Product Owner (PG Leader) | Conformed Dimensions / lookup tables, ERD, publish to CDM |
| **Upstream Domain Model** | CDO | Trades / reference data / etc. |

**Why this matters in practice:**

- App teams have **freedom to refactor** their app data without breaking downstream — because consumers don't connect there directly
- Analytics consumers all connect to **one place** (the Risk Warehouse), so they get **stable contracts**
- CDO drives **enterprise consistency** at the entity level; Risk implements within that framework

**Three principles that flow from this:**

1. **DD authors what's analytics-specific.** Apps own their raw data. Central owns canonical models. PG Leader owns Risk-domain modelling. DD owns the analytics layer specifically.
2. **DD and Tech Lead are peers.** DD = what the data means. Tech Lead = how it runs. Neither reports to the other; they collaborate on every product.
3. **Discovery is celebrated; promotion is the standard.** When an app team builds a quick dashboard on app data, that's good — it identifies real consumer needs. The standard is that **discovery dashboards graduate into governed analytics products**, not that discovery is forbidden.

### Data product ownership — three tiers

A "data product" isn't one thing. It's three things at three levels, with different owners at each.

| Tier | Example | Business owner | Technical owner |
|------|---------|----------------|-----------------|
| **App-level raw** | `xvala_exposure_raw` (in app schema) | App team | App team |
| **Atomic primary** *(conformed across apps in a PG)* | `fact_exposure` (CCR-wide, in `riskwh.gold`) | **PG Leader** | DD |
| **Curated / 360** *(cross-product within Risk)* | `cp_risk_summary` | DD | DD |

**What this means in practice:**

- The **app team** stays accountable for raw data their app produces (the source-of-truth question: *"is this number from the app correct?"*)
- The **PG Leader** stays accountable for the conformed business definition of cross-app products (the business question: *"does this dataset correctly represent CCR exposure?"*)
- **DD** stays accountable for technical implementation: contracts, UC tags, semantic layer enforcement, physical artifacts in `riskwh.gold` (the technical question: *"is this implemented correctly and consumable safely?"*)

Three accountabilities; each role speaks authoritatively to its own dimension. Friction emerges when these get conflated.

---

**Where to next:**

- → For how the technical pieces fit together: **2. Architecture & Design**
- → For the templates that operationalise this model: **3. Standards & Artifacts Library**
- ← Back to **landing page**

**Related:**

- Cadence and meetings → **6. Governance & Cadence**
- Glossary of terms used here (federation, conformed, etc.) → **4. Glossary & Terminology**

---

## PAGE: 2. Architecture & Design

*Risk Architecture › Risk Data — Operating Model & Standards › 2. Architecture & Design*

[/toc]

> **Page purpose:** Documents how Risk Data is structured — the journey data takes, the artifact types, how code and updates work, and the layered pattern for 360-style products.
> **Read this if:** you want to understand how Risk Data is shaped, or how your data fits into the bigger picture.

---

### The data journey — what your data goes through

[IMAGE: Data Journey — paste from `risk_data_visuals_v1.pptx`, Slide 1]

Same data. Evolving status. **Six canonical stages** from raw landing to consumption.

| Stage | Adds |
|-------|------|
| ① **Raw / Landed** | Risk-generated data lands in the app schema, schema-typed at ingestion |
| ② **Conformed** | Identity resolution + shared definitions across apps — same counterparty / trade / currency / time bucket means the same thing everywhere |
| ③ **Curated** | Shaped per a domain model — aggregated, joined, modelled (star / 360 / OBT) for analytical use |
| ④ **Data Product (Governed)** | Curated data + a contract. Contract embeds semantics: grain, aggregation rules, allowed/blocked dimensions, SLA, ownership, change policy, version |
| ⑤ **Semantic Layer** | Rules from the contract enforced at query time — wrong queries (e.g., `SUM(pfe)`) get blocked |
| ⑥ **Analytics** | Consumption — dashboards, ad-hoc, regulatory feeds, model inputs |

> **Note on terminology:** Authoritative and Certified are *attributes* a Data Product can have, not separate stages. A product is governed once it has a contract. Authoritative means formally designated as canonical for a class of decisions. Certified means validated for regulated use.

**Why each stage matters:** skipping a stage produces predictable problems.

- Skip **Conformed** → cross-product joins don't work; XVALA counterparty doesn't match CMOS counterparty.
- Skip **Curated** → consumers reinvent the same shape repeatedly.
- Skip **Data Product (Governed)** → no SLA, no change policy, no accountability.
- Skip **Semantic Layer** → consumers write unsafe queries; numbers come out wrong.

DD's role is to drive this progression — not just deliver one stage.

### Artifact types in the analytics layer

[IMAGE: Artifact Types side-by-side — paste from `risk_data_visuals_v1.pptx`, Slide 2]

Four kinds of artifact you'll encounter in `riskwh`. Each contributes independently to analytics:

- **Entity** — a real-world thing (a counterparty, a trade, an agreement). Foundation that everything else attaches to.
- **Data Product** — a curated, contracted dataset. Direct consumption — closed shape, stable contract.
- **Domain Model** — a blueprint of how entities relate. The structural rules data products are built on.
- **Star Schema** — facts joined to dimensions for self-service queries. Open shape; safe only with semantic layer enforcement.

Each is independent. A data product can rest on a domain model. A star schema is one way to shape data products. Entities are the foundation under all of them.

### Code & update behaviours

[IMAGE: Git + Update Behaviours — paste from `risk_data_visuals_v1.pptx`, Slide 3]

#### Where the code lives

**Git ownership follows the federation model.** Two separate repos, two separate deployment paths, two separate ownership boundaries:

- **App-zone Git** (one repo per app) — owned by App team. Contains the app's code, schema DDLs, app-internal dashboards. Deploys to (1) App PROD environment and (2) Databricks app schema (where raw output lands).
- **Risk Warehouse Git** (single repo) — owned by DD. Contains analytics product DDLs, contracts, UC tag definitions, semantic layer code, analytics dashboards. Deploys to the Databricks analytics catalog (`riskwh`).

When a discovery dashboard graduates to a contracted analytics product, the queries get **re-implemented** in the Risk Warehouse repo. The original app dashboard can stay alive in the app-zone repo for app-internal use. Two artifacts now exist; consumers point at the analytics one.

#### How each artifact updates

Different artifacts in the analytics catalog have different update behaviours. Consumers need to know which they're getting:

| Artifact | Update behaviour | What this means |
|----------|------------------|-----------------|
| **Entity views** *(linked to app schemas)* | **REAL-TIME** | Views over app schema tables — when app data changes, the view shows new data immediately. No copy of data; pass-through query. |
| **Data Products** *(materialised in `riskwh.gold`)* | **SCHEDULED** | Built on a schedule per the contract (e.g., daily by 06:00). Consumers see data as of the last build. Physical copy; SLA-controlled. |
| **Star Schemas** *(facts + dimensions for self-service)* | **MIXED** | Often two flavours together — yesterday's snapshot (stable, materialised) plus today's live view (current, dynamic). Consumer chooses which to use. |

This matters because consumers might ask "is this data current?" — the answer depends on which artifact they're looking at.

### How a 360-style analytics product works

[IMAGE: 360 Layered Architecture — paste from `risk_data_visuals_v1.pptx`, Slide 4]

A 360-style product is **not one wide table.** It's a layered architecture:

- **Layer 1** — Summary product at the entity grain (e.g., one row per counterparty per date). Pre-aggregated headlines. Loads instantly.
- **Layer 2** — Atomic drill-down products, each at its native grain (trades, exposure by netting set, sensitivities, collateral, stress, limits, CVA). Linked by the entity key, but never row-joined to each other.
- **Layer 3** — BI tool orchestration. Summary panel loads from Layer 1; drill-down tabs load from Layer 2 on demand, filtered by the selected entity.

**Why not one wide table:** facts live at different grains. A single wide table would either Cartesian-multiply the data (wrong numbers) or lose detail. Layered architecture preserves grain end-to-end.

This pattern applies anywhere we need a unified entity view across many measures — counterparty 360, agreement 360, portfolio 360, etc.

For a worked walk-through, see *Worked Example — Counterparty 360 Product*.

---

**Where to next:**

- → To start onboarding data into analytics: **3. Standards & Artifacts Library**
- → For an end-to-end example: **5. Worked Example — Counterparty 360 Product**
- ← Back to **1. Operating Model**

**Related:**

- Definitions of terms used here (data product, grain, conformed) → **4. Glossary & Terminology**
- Who owns what → **1. Operating Model**

---

## PAGE: 3. Standards & Artifacts Library

*Risk Architecture › Risk Data — Operating Model & Standards › 3. Standards & Artifacts Library*

[/toc]

> **Page purpose:** The practical templates and standards. Forms to fill in. Standards to follow. Examples to copy.
> **Read this if:** you're bringing data to the analytics layer, building a data product, applying UC tags, or designing schemas.

---

> **All templates marked `[DRAFT v1 — feedback welcome]`** — starter content. Refine in place once teams begin using them.

### A. Data Product Onboarding Form

`[DRAFT v1 — feedback welcome]`

**Purpose:** When an App team or Business team has data they want to bring into the analytics layer as a contracted data product, this is the form they fill in. DD reviews and approves; once approved, DD authors the contract and the team registers the product.

#### Form fields

**Section A — Source**

```
1. Requesting team (App / Business / PG):
2. Source system (XVALA, CMOS, business spreadsheet, etc.):
3. Source location (app schema, file path, Confluence page):
4. Source data steward (name, contact):
5. Current Git repo for source artifacts (URL):
6. Stage of source data today (1–6 — see Architecture & Design):
```

**Section B — Data description**

```
7. Data domain (Counterparty risk, Liquidity, Market risk, Funding, etc.):
8. Brief description (3–5 sentences — what does this data represent?):
9. Native grain (e.g., "trade + valuation_date"):
10. Approximate volume (rows per refresh):
11. Refresh frequency (intraday / daily / weekly / on-demand):
12. Source-of-truth claim: ☐ Yes (authoritative source)  ☐ No (derived view)
```

**Section C — Schema & metadata**

```
13. DDL attached (Y / N — please attach):
14. Primary keys / business keys identified (Y / N):
15. Foreign keys to other domains identified (Y / N — list them):
16. Column-level descriptions provided for every column (Y / N):
17. Sensitive data classification done (PII / MNPI / restricted) (Y / N):
18. Existing UC tags on the source data (Y / N — list them):
```

**Section D — Consumer & contract**

```
19. Initial consumer(s) (dashboards, regulatory feed, model input, etc.):
20. Consumer-facing grain required (e.g., "counterparty + as_of_date"):
21. Aggregation behaviour for each measure (additive / non-additive / percentile / etc.):
22. Allowed dimensions for slicing:
23. Blocked dimensions / unsafe combinations:
24. SLA required (refresh by what time?):
25. Breaking-change policy preferred (e.g., 60 days notice for breaking, 14 days for additive):
```

**Section E — DD use only**

```
- Onboarding ID:
- DD reviewer:
- Reviewed date:
- Decision: ☐ Approve  ☐ Approve with conditions  ☐ Defer  ☐ Decline
- Conditions / notes:
- Target stage on intake:
- Target product name:
- Target Risk Warehouse repo path:
```

#### How to use

1. Requesting team fills in Sections A–D.
2. Submit via comment on this Confluence page or directly to DD.
3. DD reviews within 5 working days and either approves, asks for clarification, or defers (with reason).
4. Once approved, DD authors the Data Contract (next section); requesting team supports.
5. Product is registered in the Data Product Catalog (see *Governance & Cadence*).

---

### B. Data Contract Template

`[DRAFT v1 — feedback welcome]`

**Purpose:** Every analytics data product has a contract. The contract documents what the consumer can rely on. It is machine-readable (YAML, lives in the Risk Warehouse Git repo) and is the source of truth for what the data means and how it can be used.

#### Contract template (YAML)

```yaml
# Data Contract for an analytics data product
# Lives in: risk-warehouse/contracts/<domain>/<product_name>.yaml

product:
  name: <product_name>                 # e.g., "ccr_exposure"
  display_name: <human-friendly>       # e.g., "CCR Exposure Product"
  domain: <domain>                     # e.g., "counterparty_risk"
  type: <atomic_primary | curated | reporting>
  business_owner: <PG Leader name>     # business accountability
  technical_owner: <team>              # technical accountability (DD team)
  steward: <person>                    # responsible individual
  contract_version: <semver>           # e.g., "1.2.0"
  last_changed: <YYYY-MM-DD>
  collibra_ref: <id>                   # e.g., "CCR-EXP-001"

description: |
  <3–5 sentence business description of what this product represents.>

grain:
  level: <e.g., "counterparty + netting_set + time_bucket + scenario + valuation_date">
  granularity_note: |
    <explain what one row means>

dimensions:
  allowed:
    - counterparty
    - netting_set
    - bucket
    - scenario
    - valuation_date
  blocked:
    - product       # cannot slice exposure by product (would require allocation)
    - trade         # exposure does not exist at trade level

measures:
  - name: ee
    description: Expected Exposure
    aggregation: sum_with_rules        # additive within a netting set
    unit: USD
  - name: pfe
    description: Potential Future Exposure (97.5th percentile)
    aggregation: non_additive_percentile
    safe_combinations: [time_bucket]   # OK to take MAX across time buckets
    unsafe_combinations: [counterparty, netting_set]
    unit: USD

quality:
  constraints:
    - name: pfe_non_negative
      check: pfe >= 0
    - name: ee_le_pfe
      check: ee <= pfe
  tests:
    - name: row_count_within_band
      schedule: daily
      threshold: ±5% vs prior business day

sla:
  refresh: daily_by_06:00_EST
  freshness_alert: 07:00_EST
  contact_on_breach: <pager>

change_policy:
  breaking_change_notice: 60_days
  additive_change_notice: 14_days
  deprecation_notice: 90_days
  notification_channel: <Confluence page or distribution list>

lineage:
  upstream:
    - source: creditrisk.xvala.exposure_raw
      transformation: aggregate_to_netting_set
    - source: creditrisk.cmos.collateral
      transformation: join_for_net_exposure
  downstream:
    - cp_risk_summary
    - microstrategy.dossier.counterparty_360

git:
  repo: risk-warehouse
  path: products/counterparty_risk/exposure/
```

#### Workflow for a new contract

1. DD authors initial contract during onboarding (form above).
2. App team / Business reviews and confirms grain, measures, aggregation rules.
3. PG Leader (business owner) signs off.
4. DD commits to Risk Warehouse repo.
5. UC tags applied (next section).
6. Product registered in Catalog.

#### Workflow for a contract change

- **Additive change** (new column, new tag): 14 days notice via Confluence change log.
- **Breaking change** (grain change, removed column, semantic redefinition): 60 days notice; consumers acknowledged via comment on the change page.
- **Deprecation**: 90 days notice; replacement product identified.

---

### C. UC Tag Standards (Raw-zone vs Analytics-zone)

`[DRAFT v1 — feedback welcome]`

**Purpose:** Unity Catalog tags carry the rules in the technical catalog. Different tags apply at different zones, and ownership splits accordingly.

#### Principle

> Whoever owns the data owns its tags. App teams own raw-zone tags. DD owns analytics-zone tags. DD reviews app-zone tag practices for compliance with enterprise standards (which Central sets).

#### Raw-zone tags (App team authors)

Applied to tables in app schemas (e.g., `creditrisk.xvala.*`). Required tags:

| Tag | Allowed values | Purpose |
|-----|---------------|---------|
| `data_zone` | `raw` | Identifies as raw-zone data |
| `source_app` | `xvala`, `cmos`, `regds`, etc. | Source application |
| `source_system_owner` | team name | Operational owner |
| `data_classification` | `public`, `internal`, `confidential`, `restricted`, `mnpi` | Sensitivity classification |
| `pii_present` | `true`, `false` | Personal data flag |
| `refresh_frequency` | `intraday`, `daily`, `weekly`, `monthly`, `on_demand` | Refresh cadence |
| `landing_pattern` | `cdc`, `full_load`, `streaming`, `file_drop` | How data lands |

#### Analytics-zone tags (DD authors)

Applied to tables in `riskwh.gold.*` (the Risk Warehouse). Required tags:

| Tag | Allowed values | Purpose |
|-----|---------------|---------|
| `data_zone` | `analytics` | Identifies as analytics-zone data |
| `data_product` | `true`, `false` | Recognises as a contracted data product |
| `product_name` | string | Name from contract |
| `product_type` | `atomic_primary`, `curated`, `reporting` | Type per Glossary |
| `contract_version` | semver | Matches contract YAML |
| `business_owner` | PG Leader name | Business accountability |
| `technical_owner` | team name | DD team / Risk Warehouse |
| `grain` | composite key string | e.g., `cp+netting_set+bucket+scn+date` |
| `allowed_dims` | comma-separated | Dimensions safe to slice by |
| `blocked_dims` | comma-separated | Dimensions that are unsafe |
| `aggregation_<measure>` | rule per measure | e.g., `aggregation_pfe = non_additive_percentile` |
| `refresh_sla` | string | e.g., `daily_by_06:00_EST` |
| `change_policy` | string | e.g., `breaking_60d_additive_14d` |
| `collibra_ref` | id | Collibra registration |
| `stage` | `4_governed`, `5_semantic`, `6_analytics` | Stage from Architecture & Design |

#### Worked example — Exposure product

```sql
-- Make the table recognised as a data product
ALTER TABLE riskwh.gold.fact_exposure SET TAGS (
  'data_zone'        = 'analytics',
  'data_product'     = 'true',
  'product_name'     = 'CCR Exposure',
  'product_type'     = 'atomic_primary',
  'contract_version' = '1.2.0',
  'business_owner'   = 'pg_credit_risk',
  'technical_owner'  = 'risk_data_platform',
  'grain'            = 'cp+netting_set+bucket+scn+date',
  'allowed_dims'     = 'cp,netting_set,bucket,scn,date',
  'blocked_dims'     = 'product,trade',
  'aggregation_pfe'  = 'non_additive_percentile',
  'aggregation_ee'   = 'sum_with_rules',
  'refresh_sla'      = 'daily_by_06:00_EST',
  'change_policy'    = 'breaking_60d_additive_14d',
  'collibra_ref'     = 'CCR-EXP-001',
  'stage'            = '4_governed'
);

-- Business meaning
COMMENT ON TABLE riskwh.gold.fact_exposure IS
  'CCR exposure metrics at counterparty + netting set + time bucket + scenario.
   Atomic primary product. PFE is non-additive; see contract for aggregation rules.';

-- Quality constraint enforced at runtime
ALTER TABLE riskwh.gold.fact_exposure
  ADD CONSTRAINT pfe_non_negative CHECK (pfe >= 0);

-- Ownership
ALTER TABLE riskwh.gold.fact_exposure
  OWNER TO `risk_data_platform`;
```

#### Column-level requirements

**Every column in an analytics product must have a column comment.** No exceptions. Where a column's meaning is non-obvious, the comment must be specific:

```sql
COMMENT ON COLUMN riskwh.gold.fact_exposure.pfe IS
  'Potential Future Exposure (97.5th percentile, daily Monte Carlo, non-additive across counterparties)';

COMMENT ON COLUMN riskwh.gold.fact_collateral.collateral_rating IS
  'Collateral issuer rating. Composite from S&P, Moody, Fitch (highest of three). For sovereign collateral, internal sovereign override applies.';
```

#### Why both column comments AND tags

- **Column comments** are human-readable — show up in catalog UIs, query autocomplete
- **Tags** are machine-readable — enable governance automation, lineage, semantic layer to enforce rules
- Both are required.

---

### D. Schema & Catalog Design Standard

`[DRAFT v1 — feedback welcome]`

**Purpose:** How catalogs, schemas, and tables are organised in Databricks. DD authors the design; Tech Lead implements with Infra.

#### Catalog structure

Three top-level catalogs in the Risk space:

| Catalog | Purpose | Owner | Consumer access |
|---------|---------|-------|-----------------|
| `creditrisk` (and other PG-equivalents: `liquidity`, `marketrisk`, `funding`) | App-zone raw data per PG. One schema per app. | App teams | **Internal app use only.** Consumers MUST NOT connect directly. |
| `riskwh` | Analytics-zone. Curated data products, semantic layer, lookup tables, sandbox. | DD / Risk Warehouse | **Single point of consumption** for all consumers and BI tools. |
| `risk_governance` | Governance metadata, contract registry, lineage, tags reference | DD | Read-only for App Teams, PG Leaders, Central |

#### Schema naming convention within catalogs

**App-zone catalogs (`creditrisk`, `liquidity`, etc.):**

```
<pg_catalog>.<app_name>           — primary app schema
<pg_catalog>.<app_name>_archive   — archival
<pg_catalog>.<app_name>_quarantine — DQ-failed records
```

Examples: `creditrisk.xvala`, `creditrisk.cmos`, `liquidity.alfa`

**Analytics-zone catalog (`riskwh`):**

```
riskwh.silver       — conformed, enriched (views or physical)
riskwh.gold         — curated data products (physical, contracted)
riskwh.lookup       — risk-derived dimensions and lookup tables
riskwh.sandbox      — exploration; not contracted; not consumed by ops
riskwh.semantic     — semantic layer definitions (dbt / Metric Views)
```

#### Table naming convention

**Atomic primary products in `riskwh.gold`:**

```
fact_<entity>_<measure>         e.g., fact_exposure, fact_collateral, fact_mtm
dim_<entity>                    e.g., dim_counterparty, dim_netting_set
```

**Curated / 360 products in `riskwh.gold`:**

```
<entity>_<purpose>_summary      e.g., cp_risk_summary, liquidity_dashboard_summary
<entity>_<purpose>_360          for explicitly 360-style products
```

**Reporting products in `riskwh.gold`:**

```
report_<consumer>_<purpose>     e.g., report_basel_sa_ccr, report_fed_ccar
```

#### Critical principle — Consumer access

**Consumers MUST NOT connect directly to app-zone catalogs.**

Every BI tool, dashboard, MicroStrategy dossier, ad-hoc consumer query points at `riskwh` only. Reasons:

- App teams need freedom to refactor their app schemas without breaking downstream
- Analytics zone provides contracts, SLAs, and stable semantics that app schemas don't
- Single point of consumption simplifies governance, access, and lineage

When a consumer is found connecting to an app schema, the response is:

1. Acknowledge the work they've done
2. Identify what needs to be promoted into the analytics layer (use the Onboarding Form)
3. Help re-point the consumer to the analytics product once it exists

---

### E. Semantic Layer Definition Template

`[DRAFT v1 — feedback welcome]`

**Purpose:** Semantic layer enforces the rules from the data contract at query time. Whether implemented in dbt, Databricks Metric Views, or a BI-tool semantic model, the same definitions apply.

#### Definition template (dbt-style YAML)

```yaml
# Semantic definition for a measure
# Lives in: risk-warehouse/semantic/<domain>/<measure>.yaml

semantic_models:
  - name: ccr_exposure_metrics
    description: Counterparty credit risk exposure metrics
    model: ref('fact_exposure')
    contract_ref: contracts/counterparty_risk/exposure.yaml

    entities:
      - name: counterparty
        type: foreign
        expr: counterparty_id
      - name: netting_set
        type: foreign
        expr: netting_set_id
      - name: valuation_date
        type: time
        type_params:
          time_granularity: day

    dimensions:
      - name: bucket
        type: categorical
      - name: scenario
        type: categorical
        allowed_values: [base, stress_2008, stress_covid, regulatory]

    measures:
      - name: ee
        agg: sum
        expr: ee
        agg_params:
          required_grain: [netting_set, time_bucket, scenario]

      - name: pfe
        agg: max                          # default: take max across whatever's left
        expr: pfe
        agg_params:
          safe_aggregation_levels: [time_bucket, scenario]
          unsafe_aggregation_levels: [counterparty, netting_set]
          on_unsafe_query: error
          error_message: |
            PFE cannot be summed across counterparties or netting sets.
            Use cp_risk_summary for pre-baked counterparty-level PFE,
            or restrict your query to a single counterparty + netting set.
```

#### Two implementation places — same definitions

The semantic layer can be implemented in two places:

- **In Databricks** (dbt Metric Views, or Databricks Metric Views) — central definitions enforced at SQL level
- **In the BI tool** (e.g., MicroStrategy level metrics) — definitions enforced at BI-tool level

**Recommended pattern:** define semantics **once, centrally**, and have the BI tool **mirror** those definitions. Otherwise you get drift — one place says PFE-non-additive, another says PFE-additive, and the same dashboard returns different numbers depending on who built it.

#### Worked example — safe vs unsafe queries

**Safe** — aggregate-then-combine:

```sql
WITH exp_at_cp AS (
  SELECT counterparty, MAX(pfe) AS pfe
  FROM fact_exposure WHERE valuation_date = '2026-05-04'
  GROUP BY counterparty
),
mtm_at_cp AS (
  SELECT counterparty, SUM(mtm) AS mtm
  FROM fact_mtm WHERE valuation_date = '2026-05-04'
  GROUP BY counterparty
)
SELECT * FROM exp_at_cp JOIN mtm_at_cp USING (counterparty);
```

**Unsafe** — row-joining facts at different grains:

```sql
-- DO NOT DO THIS — Cartesian explosion + double-counting
SELECT counterparty, SUM(pfe), SUM(mtm)
FROM fact_exposure JOIN fact_mtm
  ON fact_exposure.counterparty = fact_mtm.counterparty
GROUP BY counterparty;
```

The semantic layer should refuse the unsafe query before it runs.

---

**Where to next:**

- → For terminology used in these templates: **4. Glossary & Terminology**
- → For an end-to-end example using these templates: **5. Worked Example — Counterparty 360 Product**
- ← Back to **2. Architecture & Design**

**Related:**

- Who owns what (business vs technical) → **1. Operating Model**
- Change management for these standards → **6. Governance & Cadence**

---

## PAGE: 4. Glossary & Terminology

*Risk Architecture › Risk Data — Operating Model & Standards › 4. Glossary & Terminology*

[/toc]

> **Page purpose:** Shared vocabulary so we're not talking past each other.
> **Read this if:** you hear a term and want to know what it means in the context of Risk Data.

---

### Core concepts

#### Data product

A **governed, contracted dataset** designed for consumption. Has an owner, a contract, an SLA, and a change policy. Discoverable via Unity Catalog (technical) and Collibra (business). May be atomic, curated, or reporting in nature (see types below).

#### Star schema (and galaxy schema)

A **modelling pattern** where one or more fact tables connect to shared (conformed) dimension tables. A **galaxy schema** (a.k.a. fact constellation) is the multi-fact version — multiple facts at different grains sharing dimensions. This is the right pattern when many analytics need to share counterparties, netting sets, dates, etc.

#### Grain

The **level of detail one row represents** in a fact table. Critical to specify because the grain determines what you can and can't aggregate. Examples:

| Fact | Grain | One row = |
|------|-------|-----------|
| `fact_trade` | trade + valuation_date | one trade as of a date |
| `fact_exposure` | counterparty + netting_set + time_bucket + scenario + valuation_date | exposure for a netting set, in a time bucket, under a scenario, on a date |
| `fact_sensitivities` | trade + risk_factor + tenor + valuation_date | sensitivity of one trade to one risk factor at one tenor on a date |

#### Three types of data products

- **Atomic primary** — exists at a native source grain. e.g., `fact_exposure`. Source of truth for one specific kind of metric. Stable, contracted, foundational.
- **Curated / 360** — derived view across multiple atomic products, shaped for a consumption purpose. e.g., `cp_risk_summary`. Layered on top of atomic products.
- **Reporting** — purpose-built for a specific report or regulator. e.g., `report_basel_sa_ccr`. Often a denormalised view of curated/atomic products with reporting-specific structure.

#### Three concepts often confused

| Term | Meaning | What it implies |
|------|---------|-----------------|
| **Governed** | Subject to rules, ownership, change management, quality controls. | The verb. Someone is responsible. Rules apply. Changes are managed. |
| **Curated** | Deliberately shaped, selected, refined for a purpose. | The artifact characteristic. This dataset has been arranged for a use case. |
| **Conformed** | Aligned to a shared definition across multiple uses or contexts. | Cross-context agreement. The same entity, same keys, same hierarchies wherever this data is used. |

You can have governed-but-not-curated, curated-but-not-conformed, or conformed-but-not-curated. **A data product fit for analytics needs all three.**

#### Conformance — explained

**Conformance is identity resolution.** When the same real-world thing is represented differently in different applications, conformance creates one canonical representation that all the apps map to.

> XVALA records a counterparty as `"ABC BANK NA"`. CMOS records the same legal entity as `"ABC Bank N.A."`. REGDS uses internal code `"X-1023"`. Same real-world counterparty, three different representations.
>
> Conformance creates one canonical `cp_id = 'CP000123'` and maps all three back to it. Now exposure from XVALA can be joined to collateral from CMOS to regulatory positions from REGDS — and the answer is correct.

The same applies to currencies, time buckets, trade IDs, risk factors. Without conformance, cross-app joins either don't work or produce wrong answers silently.

#### Contract

A **machine-readable specification** of what a data product means and how it can be used. Includes grain, allowed/blocked dimensions, aggregation rules, quality constraints, SLA, change policy, ownership. Lives as YAML in Git; expressed as UC tags + column comments in Databricks; registered as a business asset in Collibra.

**Semantics are embedded in the contract.** Specifically: the rules about how each metric can and cannot be aggregated are written into the contract. So *"PFE is non-additive across counterparties"* is a semantic rule, declared in the contract, that lives with the data product.

#### Semantic layer

A **definition layer that enforces the contract at query time.** Implemented in dbt Metric Views, Databricks Metric Views, or BI-tool semantic models. Refuses unsafe queries (e.g., summing PFE across netting sets). Gives consumers safe self-service.

A star schema **does not carry semantics by itself.** For star schemas to be safe, semantic rules must be declared and implemented separately. Without that, a user can drag PFE onto a canvas, slice it by counterparty, see SUM(PFE), and get a number that looks plausible but is mathematically meaningless.

### The 6 stages — what each adds

| Stage | Name | What it adds |
|-------|------|--------------|
| ① | **Raw / Landed** | The data lands, schema-typed at ingestion |
| ② | **Conformed** | Identity resolution + shared definitions across apps |
| ③ | **Curated** | Shaped per a domain model — modelled, joined, aggregated for analytical use |
| ④ | **Data Product (Governed)** | Curated data + a contract. Contract embeds semantics |
| ⑤ | **Semantic Layer** | Rules from the contract enforced at query time |
| ⑥ | **Analytics** | Consumption — dashboards, ad-hoc, regulatory feeds, model inputs |

> **Note:** Authoritative and Certified are *attributes* a Data Product (stage ④) can have, not separate stages. A new Data Product is governed on day 1. It becomes authoritative when a governance body formally designates it as canonical for a class of decisions. It becomes certified after model risk validates it for regulated use.

### Common confusions resolved

| Term | What people often mean | What it actually means |
|------|------------------------|------------------------|
| **Cleansed** | "We did a quality pass" | Quality issues fixed (dedup, null handling, format errors). In modern lakehouse ingestion this happens at the same time as Raw landing. |
| **Standardised** | Same as cleansed | Values aligned to common formats (ISO codes, etc.). Often folded under "cleansed". |
| **Normalised** | Same as standardised | Different! Normalised = structured to eliminate redundancy (3NF, BCNF). A modelling discipline, not a values discipline. |
| **Reconciled** | "We checked the numbers" | Discrepancies between sources resolved. Critical for regulatory products. |
| **Harmonised** | Same as conformed | The act of getting to conformance. "Harmonisation" is the verb; "conformance" is the result. |
| **Enriched** | "We added stuff" | Augmented with derived attributes or external data (LEI, industry classification). Different from curated — enrichment adds attributes; curation arranges them. |
| **Trusted** | "It's the official version" | Cultural attribute earned through use. Not a stage on the journey. |
| **Authoritative** | Same as trusted | A formal organisational designation applied to a Data Product. Stronger than trusted. |
| **Certified** | "Approved for use" | Has passed a formal validation process (often regulatory or model-risk). Highest tier; specific to regulated use. |
| **Source of truth** | "The real one" | Colloquial. Loosely equivalent to Authoritative. |
| **Golden source** | Same as source of truth | Common in banking. Synonym. |

### Status / lifecycle attributes

These can apply to any artifact at any stage:

| Term | Meaning |
|------|---------|
| **Discoverable** | Findable in the catalog with searchable metadata |
| **Observable** | Monitored — quality, freshness, lineage instrumented in real time |
| **Versioned** | Has explicit version history — schema, content, contract |
| **Lineage-tracked** | Upstream and downstream relationships explicitly captured |
| **Federated** | Available across platforms via federation, without copying |
| **Materialised** | Physically stored as a result table |
| **Virtual** | Computed at query time as a view |
| **Replicated** | Physically copied to another location |
| **Deprecated** | End-of-life signalled; consumers should migrate |

---

**Where to next:**

- → To apply these terms in templates: **3. Standards & Artifacts Library**
- → To see how they fit together: **2. Architecture & Design**
- ← Back to **landing page**

---

## PAGE: 5. Worked Example — Counterparty 360 Product

*Risk Architecture › Risk Data — Operating Model & Standards › 5. Worked Example — Counterparty 360 Product*

[/toc]

> **Page purpose:** End-to-end walk-through of how a 360-style analytics product works in TDS Risk. Generic example showing the layered pattern.
> **Read this if:** you want to see the architecture concepts applied to a concrete product.

---

### The consumer ask

A consumer wants a single counterparty inquiry experience. They type the counterparty name and expect to see:

- **Counterparty profile** — name, LEI, industry classification, parent entity, ratings
- **Trade list** at trade grain — with MtM, notional, product type, underlying, trading desk
- **Exposure metrics** — EE, PFE, stressed PFE — with drill-down by netting set, time bucket, scenario
- **Sensitivities** — CS01 by trade, by risk factor, by tenor
- **Collateral** — IA, VM, IM (differentiated), by agreement
- **Stress testing** — exposure under defined stress scenarios
- **Limits and breach status** — comparator against PFE
- **CVA and CVA CS01** — at counterparty grain
- **Trending** — YTD, QoQ, MoM, DoD movement on headline metrics
- **Watchlist signals** — top exposures, breach proximity, day-over-day movers

### Why this isn't one wide table

[IMAGE: 360 Layered Architecture — paste from `risk_data_visuals_v1.pptx`, Slide 4]

The natural temptation is to build one wide table — Counterparty 360 — that has everything in it. One row per counterparty. **This doesn't work.**

If you tried to build a single wide table, you'd have to choose one grain. Three options exist; all are bad:

| Choice of grain | What happens | Why it fails |
|-----------------|--------------|--------------|
| **Trade-level** (trade + valuation_date) | Each row is a trade. Exposure metrics (which live at netting-set grain) get duplicated across every trade in the netting set. Collateral (which lives at agreement grain) gets duplicated across every trade in the agreement. | Summing PFE across the table multiplies it by the number of trades per netting set. **The numbers are wrong — silently and badly.** |
| **Netting-set-level** (counterparty + netting_set + valuation_date) | Each row is a netting set. Loses trade-level detail. Sensitivities (per trade, per risk factor) can no longer be represented. | Loses the trade and sensitivity drill-down the consumer needs. |
| **Counterparty-level** (counterparty + valuation_date) | Each row is one counterparty per date. Loses netting-set, trade, sensitivity, scenario detail entirely. | Useful as a summary — but it isn't a 360. It's just headlines, with no drill-down. |

**Conclusion:** there is no single grain that supports the full ask.

### The correct architecture — three layers

#### Layer 1 — Summary product (`cp_risk_summary`)

- Grain: counterparty + valuation_date
- ~30–50 columns, 1 row per counterparty per date
- Contains: counterparty profile, total notional, total MtM, IA/VM/IM totals, PFE (max across buckets), CVA, limit, breach flag, trade count, top movers
- This is what loads instantly when a user types a counterparty name.

#### Layer 2 — Atomic drill-down products (each at native grain)

| Product | Grain |
|---------|-------|
| `fact_trade` | trade + valuation_date |
| `fact_exposure` | counterparty + netting_set + time_bucket + scenario + valuation_date |
| `fact_mtm` | trade + valuation_date |
| `fact_sensitivities` | trade + risk_factor + tenor + valuation_date |
| `fact_collateral` | counterparty + agreement + collateral_type + as_of_date (IA, VM, IM differentiated) |
| `fact_stress` | netting_set + scenario + time_bucket + valuation_date |
| `fact_limits` | counterparty + facility + limit_type + effective_date |

Each is its own data product with its own contract, SLA, owner. Linked by counterparty_id (and where appropriate, valuation_date, netting_set_id, agreement_id) — but **never row-joined to each other**; only aggregated to a common grain when needed.

#### Layer 3 — BI / Semantic orchestration (the user experience)

When a user opens the dossier and types a counterparty name, the BI tool:

1. Loads `cp_risk_summary` for that counterparty — instant, one row, populates the summary panel.
2. Renders tabs — Trades / Exposure / Sensitivities / Collateral / Stress / Limits / CVA. Initially empty.
3. User clicks Trades — loads `fact_trade WHERE counterparty_id = X` (~hundreds of rows).
4. User clicks Exposure — loads `fact_exposure WHERE counterparty_id = X` (~hundreds of rows).
5. User clicks Sensitivities — loads `fact_sensitivities WHERE counterparty_id = X`. Pre-aggregated by risk_factor + tenor in the chart; drill to trade level on demand.
6. User clicks Collateral — loads `fact_collateral WHERE counterparty_id = X`. Shows IA/VM/IM split by agreement.

Each tab loads only what's asked for. Each respects native grain. User perceives one unified counterparty experience.

### Three concrete grain examples

**PFE for a counterparty (from Layer 1):**

```sql
SELECT pfe FROM riskwh.gold.cp_risk_summary
WHERE counterparty_id = 'ABC' AND valuation_date = '2026-05-04';
-- Returns one number — the pre-baked MAX across time buckets and netting sets
```

**Collateral by type for a counterparty (Layer 2):**

```sql
SELECT agreement_id, collateral_type, SUM(amount) AS amt
FROM riskwh.gold.fact_collateral
WHERE counterparty_id = 'ABC' AND as_of_date = '2026-05-04'
GROUP BY agreement_id, collateral_type;
-- Preserves IA/VM/IM distinction; never combined into one "collateral" number
```

**CS01 by tenor for a counterparty (Layer 2):**

```sql
SELECT tenor, SUM(cs01) AS cs01_total
FROM riskwh.gold.fact_sensitivities
WHERE counterparty_id = 'ABC' AND valuation_date = '2026-05-04'
GROUP BY tenor;
-- Semantic layer permits SUM because CS01 is additive
```

### Bottom line

A 360-style analytics product cannot be served by a single wide table. It requires:

- One curated **summary** product at the entity grain (Layer 1)
- Several **atomic** products at their native grains (Layer 2)
- A BI **orchestration** layer that ties them as a single user experience (Layer 3)

This is how every counterparty risk dashboard at every major bank is built.

---

**Where to next:**

- → To onboard your own data following this pattern: **3. Standards & Artifacts Library**
- ← Back to **2. Architecture & Design**

**Related:**

- Why grain matters → **4. Glossary & Terminology**
- Three-tier ownership for layered products → **1. Operating Model**

---

## PAGE: 6. Governance & Cadence

*Risk Architecture › Risk Data — Operating Model & Standards › 6. Governance & Cadence*

[/toc]

> **Page purpose:** How decisions get made, how meetings work, how changes to these standards get managed.
> **Read this if:** you want to know when meetings happen, how to propose changes, or how to track what's in flight.

---

### Meeting cadence

| Cadence | Who | Subject | Owner |
|---------|-----|---------|-------|
| Daily (operational) | DD ↔ TDVIP / Infra | Working contact via Tech Lead | Tech Lead drives |
| Weekly | DD ↔ Product Group Leaders | PG needs, roster, DD ask | DD chairs |
| Weekly | PG Leader ↔ Business | Requirements, Path 1 | PG Leader chairs |
| Bi-weekly | DD ↔ CDO / Enterprise Architecture | Standards, templates, enterprise news | CDO/EA chairs; DD attends |
| As-needed | DD ↔ Tech Lead / Apps | Deliver to spec | Per project |
| As-needed | DD ↔ Business | Path 1 + semantic alignment | DD initiates |
| As-needed | Strategy alignment (Vendor / TDVIP-Infra) | Architecture, capacity, federation | DD contributes when involved |

#### Standing items

**DD ↔ Product Group Leaders (weekly)** — agenda always includes:

1. Roster review (what's in flight per PG)
2. New asks from PG
3. Dependencies and blockers
4. Standards changes from CDO

**DD ↔ CDO / EA (bi-weekly)** — agenda always includes:

1. Risk's implementation status against enterprise standards
2. Risk contributions to canonical models
3. Changes to standards that Risk needs to adopt
4. Cross-domain concerns

### DD project roster

`[DRAFT v1 — feedback welcome]`

**Purpose:** Single tracker of every active ask. Maintained by DD. Reviewed weekly with PG Leaders, monthly with Risk leadership.

#### Roster structure

| ID | Requesting team | PG | Artifact | Description | Stage | Dependencies | Target date | Status |
|----|----------------|----|----|--------|----|--------------|-------------|--------|
| 001 | _example_ | _example_ | _example_ | per onboarding form | 4 → 5 | Contract sign-off | 2026-Q3 | IN-FLIGHT |

#### How items get added

- App team / Business team / PG Leader requests via the Onboarding Form (see *Standards & Artifacts Library*) or direct message to DD
- DD assigns ID, adds to roster, books review slot
- Status updated weekly

#### Status definitions

- **REQUESTED** — newly raised, not yet reviewed
- **PLANNED** — reviewed and on roadmap, not yet started
- **IN-FLIGHT** — work has started
- **BLOCKED** — dependency unresolved (note dependency)
- **DONE** — delivered; product registered
- **DEFERRED** — deprioritised; revisit date noted

### Change management for these standards

`[DRAFT v1 — feedback welcome]`

**Purpose:** This space is a living document. Standards will evolve. Here's how changes are proposed, reviewed, and communicated.

#### Change types

| Type | Examples | Notice period | Approver |
|------|----------|--------------|----------|
| **Editorial** | Typo, clarification, link fix | None — just edit | DD |
| **Additive** | New optional tag, new template field | 14 days | DD; informed: PG Leaders, Tech Lead |
| **Substantive** | New required tag, change to onboarding form, new mandated naming pattern | 30 days | DD with PG Leader sign-off |
| **Breaking** | Change to schema standards, change to UC tag taxonomy that affects existing products | 60 days | DD with CDO + PG Leader sign-off |

#### Change proposal workflow

1. Anyone (App team, Business, Central, Tech Lead, PG Leader) can propose a change via comment on the relevant page
2. DD logs the proposal in the change log (below)
3. DD assigns change type and notice period
4. Proposal posted with notice period; comment window open
5. After notice period and addressing comments, change is committed
6. Change announced in next applicable meeting cadence

#### Change log

| Date | Section | Change | Type | Status |
|------|---------|--------|------|--------|
| 2026-05-07 | All | Initial publication | – | PUBLISHED |
| | | | | |

*(To be appended as changes are made.)*

---

**Where to next:**

- ← Back to **landing page**

**Related:**

- Who attends each meeting → **1. Operating Model**
- Templates that get governed by these processes → **3. Standards & Artifacts Library**

---

*End of Confluence content source file.*
