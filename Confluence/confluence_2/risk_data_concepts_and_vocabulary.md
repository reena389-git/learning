# Risk Data — Concepts and Vocabulary

Reference document. Vocabulary, distinctions, and one-liners worth keeping. Scan, don't read end-to-end.

---

## Why this exists

**Without declared metadata, a dataset's schema lives in its consumers' inference.**

Consumers receive bytes. They guess types. They guess meanings from column names. They depend on those guesses. If the producer changes anything, consumers break silently.

The operating model exists to move the schema out of consumers' heads, into a declared, versioned, owned contract. Make the data **self-describing**.

That's the whole motivation. Everything else is implementation.

---

## The three sharp distinctions

The single most useful framing in this document:

> **A conformed entity is a business concept** (counterparty, agreement, issuer).
>
> **A fact is a measurement at the intersection of entities** (exposure, PFE, EAD).
>
> **They're at different layers — facts reference entities; they don't become entities.**

### Precise definition of a fact

> A fact is a derived measurement that only exists at the intersection of entities. It has a grain — the level of detail at which one row represents one measurement. It has no independent identity in the business; it exists *because* the entities it joins exist and *because* the measurement was computed at their intersection.

True facts: Issuer Exposure, PFE, EAD. You can't describe them without invoking the intersection.

---

## Two kinds of entity — event vs reference

Within "entity" there's a useful sub-distinction:

- **Reference entity** — a business *thing*. Persistent. Describes "who" or "what." Examples: counterparty, instrument, legal entity, currency.
- **Event entity** — a business *happening*. Has its own identity, attributes, and lifecycle. Examples: trade, payment, order, agreement amendment.

Both are entities. Both have their own identity. The difference is whether they're persistent participants or occurrences in time.

In dimensional implementations, reference entities typically become dimensions; event entities are typically physicalised as fact tables — but they remain entities at the logical layer.

### Trade — a worked example of an event entity

> **At the logical layer:** trade is a business event entity. It has its own identity (`trade_id`), its own lifecycle (booked → amended → settled → matured), its own attributes (price, quantity, dates).
>
> **At the analytical layer:** trade is typically implemented as a fact table — rows at the intersection of dimensions (counterparty, instrument, trader, book, date) with measures (notional, price, MTM, P&L) attached.
>
> Both framings are correct at their respective layers. The fact-table implementation doesn't change what trade is logically — it's still an entity. It just shares the physical pattern with true facts.

### Trade vs Issuer Exposure — the cleanest contrast

| | Trade | Issuer Exposure |
|---|---|---|
| Has its own identity in the business | Yes (`trade_id`) | No (only at the intersection) |
| Has its own lifecycle | Yes (booked / amended / cancelled / settled) | No (computed; refreshed daily) |
| Can be described independently | Yes — "the trade we booked on Tuesday" | No — always requires the intersection |
| Logical layer | **Event entity** | **Fact** |
| Analytical implementation | Often as a fact table | Always as a fact table |

*Trade is an entity that's often physicalised as a fact. Exposure is a fact through and through.*

---

## Five things people confuse

| Thing | What it is | Has rows? | Example |
|---|---|---|---|
| **Dataset** | Raw data flowing — column names but no formal metadata. What Risk produces today. | Yes | A CSV emitted by a service |
| **Entity** | A business concept (reference or event). | No | Counterparty, Trade |
| **Conformed Entity** | Entity with agreed definition across parties | No | Counterparty as agreed across Risk apps |
| **Data Product** | Dataset wrapped in metadata — contract, owner, SLA, discovery | Yes | `star_dim_counterparty` with the wrapper |
| **Report** | Consumer-facing view inheriting from upstream products | Yes | "Top 10 sovereign issuers, OSFI, daily" |

---

## Side-by-side — Dataset vs Conformed Entity vs Data Product vs Report

### Identity

| Property | Dataset | Conformed Entity | Data Product | Report |
|---|---|---|---|---|
| Has rows | Yes | No | Yes | Yes |
| Has a name | Yes — file or endpoint | Yes — entity name | Yes — qualified table name | Yes — report name |
| Status at TD today | Most outputs | Aspirational | Being built via workbooks | Mostly called "reports" already, no formal contract |

### Structure

| Property | Dataset | Conformed Entity | Data Product | Report |
|---|---|---|---|---|
| Column names | Descriptive but informal | Declared as attributes | Declared formally | Inherited |
| Data types | Inferred | Declared | Declared | Inherited |
| Allowed values | Not declared | Declared (enumeration) | Enforced (CHECK) | Inherited |
| Business meaning | Implicit | Authoritative | Inherited from entity | Inherited |
| Primary key | Not declared | Declared | Declared (NOT ENFORCED) | N/A |
| Foreign keys | Not declared | Declared as logical relationships | Declared (NOT ENFORCED) | N/A |
| Internal structure | Hidden | Declared if composite | Implemented (STRUCT/ARRAY or separate tables) | N/A |

### Contract and ownership

| Property | Dataset | Conformed Entity | Data Product | Report |
|---|---|---|---|---|
| Versioned contract | No | Yes | Yes | Yes (thin) |
| Stewardship of meaning | Informal | Yes (entity steward) | Inherited from entity | Inherited |
| Technical owner | Informal | Yes | Yes | Yes |
| Business owner | Informal | Yes | Yes | Yes |
| Sources declared | Hidden in code | No (logical) | Yes (with Contract IDs) | Yes (source product ref) |
| Lineage | Hidden | No (logical) | Yes | Yes |
| Includes / Excludes | Hidden | Yes — entity boundary | Yes — data scope | Yes — business filter |
| Approval flow for changes | None | Yes (entity-level) | Yes (implementation-level) | Yes |

### Operational and enforcement

| Property | Dataset | Conformed Entity | Data Product | Report |
|---|---|---|---|---|
| Refresh / SLA | Sometimes implicit | No (logical) | Yes | Inherited |
| Data classification | Not declared | Logical designation (may contain PII) | Enforced (column-level PII tags, sensitivity) | Inherited |
| Lifecycle status | Hidden | Yes | Yes | Yes |
| Access control on rows | None | No (logical) | Yes | Yes |
| Quality rules / DQ thresholds | None | No (logical) | Yes | Sometimes |
| Retention | Implicit | No | Yes | Yes |
| Measures | Sometimes | No | Yes if fact; no if dim | Inherited |

### Discovery

| Property | Dataset | Conformed Entity | Data Product | Report |
|---|---|---|---|---|
| Discoverable in catalog | No | Yes — entity page | Yes — table page | Yes — report page |
| Self-describing | No | Yes | Yes | Yes (inherited) |
| Conformable across parties | No | Yes | Yes if entity is conformed | Inherits |

**Reading the columns:** Dataset is TD today. Conformed Entity is logical only. Data Product is physical + wrapper. Report inherits almost everything from upstream and adds question-specific filters.

---

## Lookup tables vs enumerations

Two related but different things, both part of the foundational layer.

### Enumeration

A **fixed, small, stable set of allowed values** for a categorical attribute.

- Examples: `issuer_type` ∈ {Sovereign, Bank, Corporate, Supranational, Agency}; `regulatory_regime` ∈ {OSFI, EMIR, SEC, CBIRC, JFSA, CFTC}.
- Small (< ~50 values), stable, no associated data beyond the value itself.
- Lives in the column's metadata (`allowedValues: [...]`) and is enforced as a CHECK constraint.
- Doesn't get its own entity — it's part of the attribute's definition.

### Lookup table

A **small reference entity** that maps codes to descriptions or to other associated attributes.

- Examples: `dim_country` (country_code → name + region + ISO codes); `dim_currency` (currency_code → name + decimal_places); `dim_industry` (sic_code → industry_name + sector).
- Bigger than an enumeration (hundreds or thousands of values). Has multiple associated attributes.
- Lives as its own physical table — a small dim. Gets FK'd to.
- It's a lightweight reference entity in its own right.

### The rule of thumb

> **Enumeration when the value IS the data.**
> **Lookup table when the value is a key to other data.**

Don't over-engineer. If there's nothing else to store beyond the value itself, a CHECK constraint with allowed values is simpler than a dim table with one column. Conversely, don't hardcode a list (like all countries) as a CHECK constraint when it actually has associated attributes consumers will need.

Both enumerations and lookup tables sit at **Layer 1 (reference entity)** — they're reference, not measurement.

---

## Operational vs Analytical — same entity, two physical worlds

The architectural shift Risk is going through. The same conformed entity can have two implementations.

### Two consumption patterns, two implementations

```
                    CONFORMED ENTITY: Counterparty
                    (logical, platform-agnostic)
                              │
              ┌───────────────┴────────────────┐
              │                                │
              ▼                                ▼
   ┌───────────────────┐            ┌───────────────────┐
   │   OPERATIONAL     │            │     ANALYTICAL    │
   │   implementation  │            │   implementation  │
   ├───────────────────┤            ├───────────────────┤
   │ JSON document     │            │ star_dim_         │
   │ Wrapped service   │            │ counterparty      │
   │ CSV / flat file   │            │ (decomposed,      │
   │                   │            │  flat, joinable)  │
   ├───────────────────┤            ├───────────────────┤
   │ Wrapper:          │            │ Wrapper:          │
   │ JSON Schema /     │            │ YAML / ODCS /     │
   │ OpenAPI / service │            │ UC tags /         │
   │ contract          │            │ Confluence        │
   ├───────────────────┤            ├───────────────────┤
   │ SLA: real-time    │            │ SLA: daily        │
   │ or near-real-time │            │ batch refresh     │
   ├───────────────────┤            ├───────────────────┤
   │ Shaped for:       │            │ Shaped for:       │
   │ transactional     │            │ self-service      │
   │ reads             │            │ analytical query  │
   └───────────────────┘            └───────────────────┘

       Both honour the same conformed entity.
       Both are data products in their own right.
       Both have their own metadata wrapper.
       Neither is more correct than the other.
```

### What's actually happening

**Operational world (today)**: Apps call services for EOD batch processing. They pass filter parameters (`trade_id`, date range, cancelled-only, by counterparty, by book). Services return result sets. The column names are descriptive enough that consumers can guess what they mean. The rest of the metadata — data types, nullability, allowed values, lineage, calculation behind `mtm` — is not shared. The consumer infers what they can from column names and rows.

This works for transactional consumption. It does not work for self-service analytics.

**Analytical world (where Risk is going)**: Data is queried directly in Databricks. Consumers ask their own questions, slice their own ways. Self-service requires structure that allows querying.

### Three principles

1. **The conformed entity is the shared foundation.** Both operational and analytical implementations honour the same logical entity. The entity definition is platform-agnostic.

2. **Each physical implementation is its own data product.** Operational JSON service = one data product. Analytical star schema = another data product. Both are data products. The shared substrate is the entity definition; the add-ons per implementation are SLA, refresh, access pattern, and platform-specific wrapper.

3. **Conformity is at the logical level, not the physical level.** Don't ask the operational app to flatten its JSON. Don't ask the analytical platform to nest its tables. Both can honour the conformed entity in their own platform-appropriate way.

### The deeper insight

**The conformity work isn't about the dataset surface — it's about the entities underneath.** When today's CSV reports get decomposed for analytics, what surfaces is the entities that came together to produce them. Those entities are what need conforming. Not the CSV. Not the JSON. The entities underneath.

### What a data product is, precisely

- **Reference entity data product (Layer 1)** = physical implementation of a conformed entity + metadata wrapper
- **Blended reference data product (Layer 2)** = blended reference entities + metadata wrapper
- **Risk-calculated data product (Layer 3)** = physical implementation of measures at the intersection of conformed entities + metadata wrapper
- **Consumer-aligned data product (Layer 4)** = curated view derived from upstream products + metadata wrapper

In all cases: **data product = physical implementation + metadata contract.**

The implementation can be operational or analytical. Same conformed entity can have both. They're not in conflict.

---

## Producing domain owns both surfaces

A practical ownership pattern. Industry consensus (data mesh literature is most explicit) is:

> The producing domain that owns the data also owns how it's surfaced — in both worlds.
>
> The same team that knows what counterparty means owns:
> - The operational publishing layer (service / API / batch feed contracts)
> - The analytical publishing layer (Databricks table contracts)
>
> Both publishing layers reference the same canonical entity definition. The publishing patterns differ by surface; the ownership is consistent.

### Why this matters

If a separate services team shapes data for operational consumers without coordinating with the producing app, two failure modes appear:

1. **The services layer encodes assumptions the producing app didn't know about.** Consumers depend on those assumptions. When the producing app changes its data, the services layer keeps the old contract — and producer and consumer diverge.

2. **The nested structure is convenient for one consumer's transactional pattern but unworkable for analytical use.** When analytics tries to pull from the same source, it has to reverse-engineer the nesting to flatten it. Metadata is lost in translation.

The clean architecture: **producing domain owns the canonical entity data + a publishing module per consumption mode.** Operational publishing produces what services need; analytical publishing produces what Databricks needs. Both reference the same canonical definition.

---

## Where governance lives

Governance isn't a separate layer or wrapper. It's the discipline of declaring and enforcing rules. Different rules live at different layers:

- **Rules about meaning** live with the conformed entity — who stewards the definition, what attributes are allowed, what changes need approval, what the canonical business glossary term is.
- **Rules about physical data** live with the data product — who can access the rows, how sensitive they are, how long they're retained, what DQ checks run, what gets audited.

Both sets of rules are part of the metadata wrapper at their respective layer. Governance isn't an add-on; **it's what the wrapper enforces.**

### How governance properties distribute

| Governance dimension | Lives at | Why |
|---|---|---|
| Stewardship of meaning | Conformed entity | Definition is logical |
| Approval flow for definition changes | Conformed entity | Changes the entity, not the data |
| Business glossary term | Conformed entity | Canonical reference |
| PII / regulatory designation (logical) | Conformed entity | "Counterparty may contain PII" — true regardless of platform |
| Access control on rows | Data product | Physical concern |
| Column-level PII tagging and enforcement | Data product | Per-implementation |
| Data classification (confidential / restricted / MNPI) | Data product | Applies to physical rows |
| Quality rules / DQ thresholds | Data product | Run against physical data |
| Retention / lifecycle of rows | Data product | Physical concern |
| Audit logging of access | Data product | Physical event |

Putting governance into a separate document — divorced from the entity and the data product — is how governance debt accumulates. Tie each rule to the thing it governs.

---

## Consumer types

Who consumes what, with what expectations:

| Consumer | What they consume | Their expectation | What they need from metadata |
|---|---|---|---|
| **Operational app consumers** | Other apps' services / CSVs | Complete prepared answer for a transactional request | Service contracts (JSON Schema, OpenAPI) |
| **Analytical SQL consumers** | Data products in Databricks | Queryable structure they can slice their own way | Declared schema, FK relationships, allowed values, measure semantics |
| **Report consumers** | Dashboards, scheduled extracts | Pre-built answer to a known question | Business descriptions, units, refresh timing |
| **AI / agentic consumers** | Metadata of data products | Enough context to generate queries on their own | Full declared metadata — column meanings, allowed values, FKs, measure methodology |

**The AI consumer is the strongest test of metadata quality.** If an LLM with only the metadata can generate a correct query, the metadata is rich enough. If it has to guess, the metadata is incomplete.

---

## The five-layer model

Five layers of products in the operating model:

| Layer | What it is | Industry term | Examples |
|---|---|---|---|
| **1 — Reference entity data product** | Foundational conformed entity published as a data product. Risk consumes (from CDM) or produces it. Includes lookup tables and enumerations. | Source-aligned data product | `star_dim_counterparty`, `star_dim_agreement`, `star_dim_issuer` |
| **2 — Blended reference data product** | Reference entities blended with other reference entities. No measures — just enriched reference data. | Source-aligned (enriched) | Counterparty + Legal Entity + Jurisdiction joined view |
| **3 — Risk-calculated data product** | Primary Risk output. Calculated at the intersection of reference entities. Carries measures. Has a grain. | Aggregate data product | `fact_issuer_exposure`, `fact_pfe`, `fact_ead` |
| **4 — Consumer-aligned data product** | Built on top of risk-calculated products. Narrower scope, filtered and projected. May be a star schema for self-service. | Consumer-aligned data product | A curated `sovereign_exposure_osfi_daily` view filtering `fact_issuer_exposure` |
| **5 — Report** | Rendered output — dashboards, extracts | Report / presentation artifact | Daily exposure dashboard |

**Each layer down inherits more, declares less.**

**The foundational layer (Layers 1 and 2) includes both CDM-owned and Risk-owned entities.** Risk owns foundational entities CDM doesn't yet cover (netting set, CSA terms, regulatory regime).

**Layer 2 is a useful intermediate.** Today's data products often aren't pure facts — they're enriched reference data that combines multiple reference entities. Recognising this layer keeps Layer 1 (single conformed entities) and Layer 3 (intersection + measures) clean.

---

## Two pushback flows from Risk to the enterprise

```
   ┌──────────────────────────────────────────────────────┐
   │                                                      │
   │  RISK                                                │
   │                                                      │
   │  ┌──────────────┐         ┌──────────────────┐       │
   │  │ Entity       │ Flow A  │ Risk-calculated  │       │
   │  │ expertise    │────────▶│ data products    │       │
   │  └──────────────┘         │ (Layer 3)        │       │
   │         │                 └──────────────────┘       │
   │         │                          │                 │
   │         │                          │ Flow B          │
   │         ▼                          ▼                 │
   └─────────│──────────────────────────│─────────────────┘
             │                          │
             ▼                          ▼
   ┌──────────────────┐         ┌──────────────────┐
   │ CDM team         │         │ Enterprise       │
   │ (adopts entity   │         │ consumers        │
   │  definition)     │         │ (use Risk's      │
   │                  │         │  products)       │
   └──────────────────┘         └──────────────────┘
```

- **Flow A — Definition flow:** Risk contributes entity expertise to CDM. The entity becomes a Layer 1 reference data product owned by CDM.
- **Flow B — Consumption flow:** Risk publishes its Layer 3 risk-calculated data products. The bank consumes them; Risk owns them.

Different operations. Different ownership patterns. Keep them distinct.

---

## How a dataset becomes a data product

```
Dataset                          ← raw data flowing today
   ↓ Phase 1 conformity work (declare entities, sources, rules)
App-conformed dataset            ← local conformity, contract forming
   ↓ Phase 2 product-group reconciliation
Product-group conformed dataset  ← cross-app definitions agreed
   ↓ Phase 3 Risk-level reconciliation + wrapper applied
DATA PRODUCT                     ← contracted, owned, discoverable
```

**The rows don't change. The understanding around them gets formalised.**

### The six things in the metadata wrapper

| Wrapper layer | Captures |
|---|---|
| Data model | Which entities, how related, what rules |
| Sources & lineage | What feeds it, which Contract IDs |
| Ownership | Who fixes it, who decides what it should be |
| SLA & lifecycle | When consumers can expect it, current state |
| Consumer description | What it's for, what columns mean |
| Discovery | How consumers find it |

**The wrapper does three things at once:** makes the dataset a data product, makes the data model visible, makes conformity possible.

---

## Composite entities

Entities can be flat or composite. Composite = aggregate with internal structure (a root with sub-parts).

Three patterns:
1. **Strict relational decomposition** — break into separate entities with FKs
2. **Aggregate (DDD)** — cluster treated as one unit
3. **Nested attributes** — STRUCT/ARRAY columns

Decide by asking:
1. Does the sub-part have independent identity? (No → aggregate)
2. Does it share lifecycle with the parent? (Yes → aggregate)
3. Do other entities reference it directly? (Yes → separate entity)

**Default for Risk:** aggregate, unless a fact needs to FK to the sub-part. For Agreement with nested schedules and parties, decomposition into multiple physical tables is the pragmatic choice — but the conformed model declares the conceptual relationship.

---

## Conformity vs Resolution

- **Conformity** agrees the entity's *shape* — attributes, PK, allowed values, meaning
- **Resolution** agrees the entity's *value* — recognising "JP Morgan Chase" and "JPMC" refer to the same counterparty

This work is conformity. Resolution is a separate capability (master data management) that operates on top.

---

## Vocabulary discipline

Say which layer you're at:
- *"At the entity level, we agree counterparty exists."*
- *"At the data model level, your model is 3NF and ours is dimensional."*
- *"At the table level, we have different implementations."*
- *"At the dataset level, the schema is undeclared today."*

That phrase — *"at the X level"* — forces precision.

---

## Vocabulary map

| Concept | Use | Avoid |
|---|---|---|
| Raw data, no declared metadata | **Dataset** | "report," "product," "table" |
| Business concept | **Entity** | "table," "dim" |
| Persistent business thing | **Reference entity** | "lookup" (unless it's actually a small lookup table) |
| Discrete business happening | **Event entity** | "fact" (when at the logical layer) |
| Entity with agreed definition | **Conformed Entity** | "CDM entity" |
| Measurement at intersection of entities | **Fact** | "entity" |
| Fixed allowed-value set in metadata | **Enumeration** | "lookup" |
| Small reference dim with associated attributes | **Lookup table** | "enumeration" |
| Design organising conformed entities | **Conformed Data Model** | bare "CDM" |
| Enterprise canonical entities (central CDM team) | **Enterprise CDM** | "the data model" |
| Risk's conformed entities | **Risk Confirmed Entity (RCE)** | "Risk CDM" |
| The work of aligning entity definitions | **Entity conformity** | "doing CDM" |
| Dataset with contract + owner + SLA | **Data product** | "report" |
| Curated, contracted view for a use case | **Consumer-aligned data product** | overloaded "report" |
| BI dashboards / extracts | **Report** | "data product" |

---

## One-liners

> *"Without declared metadata, a dataset's schema lives in its consumers' inference."*

> *"A conformed entity is a business concept. A fact is a measurement at the intersection of entities. They're at different layers."*

> *"Trade is an entity that's often physicalised as a fact. Exposure is a fact through and through."*

> *"PKs and FKs are logical, not physical. Codd defined them in 1970 as model-level concepts."*

> *"The metadata wrapper makes the dataset a data product, makes the data model visible, and makes conformity possible. Three things at once."*

> *"A data product is not a renaming. It's a graduation."*

> *"A data product is the physical implementation of a conformed entity (or measures at their intersection) with a contract wrapped around it."*

> *"The conformed entity is the shared foundation. Each physical implementation is its own data product."*

> *"Conformed entities are documented once. Facts link to those documents — they do not re-explain."*

> *"Two facts with identical schema but different filter scopes are different facts."*

> *"The same physical table can graduate. The rows don't change. The understanding around them gets formalised."*

> *"Each layer down inherits more, declares less."*

> *"Risk contributes entity expertise to CDM; Risk publishes data products to the enterprise. Two different flows."*

> *"Self-service requires structure that allows querying."*

> *"Conformity is what makes both implementation styles trustworthy."*

> *"The conformity work isn't about the dataset surface — it's about the entities underneath."*

> *"Conformity does NOT mean everyone uses the same physical structure."*

> *"The producing domain owns the data and its surfaces — both operational and analytical."*

> *"Governance isn't an add-on; it's what the wrapper enforces."*

> *"Enumeration when the value IS the data. Lookup table when the value is a key to other data."*

> *"The AI consumer is the strongest test of metadata quality."*

---

## The honest test

Does it have rows? **No** → entity / conformed entity / model
Does it have rows AND stable shape independent of any question? **Yes** → table or data product
Does it have rows AND was produced to answer a question? **Yes** → report
Does it have rows AND no declared metadata? **Yes** → dataset (the starting condition)

Or by what's declared:

- Nothing declared → dataset
- Logical definition agreed → conformed entity
- Physical rows + wrapper → data product
- Source product + filter logic → report

---

## Synthesis — where Risk is and where it's going

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│   TODAY                                                                 │
│   ──────                                                                │
│   Operational application world                                         │
│                                                                         │
│   App A ──┐                                                             │
│           ├──▶ Service / CSV ──▶ App B (consumer infers schema)         │
│   App C ──┘                                                             │
│                                                                         │
│   Schema lives in consumers' inference. Datasets, not products.         │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   GOING                                                                 │
│   ─────                                                                 │
│   Same operational world + new analytical world                         │
│                                                                         │
│   Conformed Entities (logical, platform-agnostic)                       │
│              │                                                          │
│      ┌───────┴────────┐                                                 │
│      ▼                ▼                                                 │
│   Operational      Analytical                                           │
│   data products    data products       ──▶ Self-service analytics       │
│   (JSON, CSV,      (Databricks                                          │
│   APIs, batch      star schema,        ──▶ AI / Genie / ChatGPT         │
│   exchanges,       Layer 1-2-3-4-5)                                     │
│   declared!)                           ──▶ BI dashboards & reports      │
│                                                                         │
│   Both worlds have declared metadata. Both honour the same              │
│   conformed entities. Schema is published, not inferred.                │
│                                                                         │
│   Producing domain owns both surfaces.                                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**The shift is twofold:**

1. **Metadata moves from inference to declaration.** Consumers stop guessing.
2. **Implementations diversify by consumption pattern.** Operational batch / service exchange continues, but with declared structure. Analytical takes a different shape — decomposed, joinable, queryable — for self-service.

A richer version of this synthesis is in `risk_data_synthesis.html`.

---

## The bigger picture

Everything above exists in service of one outcome: **data that is self-describing — to humans, to tools, and to AI.**

Without the metadata, every consumer does detective work. With the metadata, they just use it.
