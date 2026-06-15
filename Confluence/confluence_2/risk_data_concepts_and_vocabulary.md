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

---

## Five things people confuse

| Thing | What it is | Has rows? | Example |
|---|---|---|---|
| **Dataset** | Raw data flowing — column names but no formal metadata. What Risk produces today. | Yes | A CSV emitted by a service |
| **Entity** | A business concept. A noun. | No | Counterparty |
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
| Allowed values | Not declared | Declared | Enforced (CHECK) | Inherited |
| Business meaning | Implicit (consumers guess) | Authoritative | Inherited from entity | Inherited |
| Primary key | Not declared | Declared (entity identifier) | Declared (NOT ENFORCED) | N/A |
| Foreign keys | Not declared | Declared as logical relationships | Declared (NOT ENFORCED) | N/A |
| Internal structure | Hidden | Declared if composite | Implemented (STRUCT/ARRAY or separate tables) | N/A |

### Contract and ownership

| Property | Dataset | Conformed Entity | Data Product | Report |
|---|---|---|---|---|
| Versioned contract | No | Yes | Yes | Yes (thin) |
| Technical owner | Informal | Yes | Yes | Yes |
| Business owner | Informal | Yes | Yes | Yes |
| Sources declared | Hidden in code | No (logical) | Yes (with Contract IDs) | Yes (source product ref) |
| Lineage | Hidden | No (logical) | Yes | Yes |
| Includes / Excludes | Hidden | Yes — entity boundary | Yes — data scope | Yes — business filter on top |

### Operational

| Property | Dataset | Conformed Entity | Data Product | Report |
|---|---|---|---|---|
| Refresh / SLA | Sometimes implicit | No (logical) | Yes | Inherited |
| Data classification | Not declared | No (physical concern) | Yes | Inherited |
| Lifecycle status | Hidden | Yes | Yes | Yes |
| Measures | Sometimes | No | Yes if fact; no if dim | Inherited |

### Discovery

| Property | Dataset | Conformed Entity | Data Product | Report |
|---|---|---|---|---|
| Discoverable in catalog | No | Yes — entity page | Yes — table page | Yes — report page |
| Self-describing | No | Yes | Yes | Yes (inherited) |
| Conformable across parties | No | Yes (the point) | Yes if entity is conformed | Inherits |

**Reading the columns:** Dataset is TD today. Conformed Entity is logical only. Data Product is physical + wrapper. Report inherits almost everything from upstream and adds question-specific filters.

---

## Operational vs Analytical — same entity, two physical worlds

This is the architectural shift Risk is going through. The same conformed entity can have two implementations.

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
   │ Shaped for:       │            │ Shaped for:       │
   │ transactional     │            │ self-service      │
   │ reads             │            │ analytical query  │
   └───────────────────┘            └───────────────────┘

       Both honour the same conformed entity.
       Both have their own metadata wrapper.
       Neither is more correct than the other.
```

### What's actually happening

- **Operational world (today)**: Apps exchange data via services or CSVs. Result sets are wrapped. Consumers receive complete prepared answers. Schema lives in consumers' inference.
- **Analytical world (where Risk is going)**: Data is queried directly. Consumers ask their own questions, slice their own ways. Self-service requires structure that allows querying.

### Three principles

1. **Conformity is at the logical level, not the physical level.**
The conformed entity is platform-agnostic. Operational JSON and analytical star schema can both be conformant by honouring the same logical definition.

2. **Conformity does NOT mean everyone uses the same physical structure.**
Don't ask the operational app to flatten its JSON. Don't ask the analytical platform to nest its tables. Both can honour the conformed entity in their own platform-appropriate way.

3. **The conformity work isn't about the dataset surface — it's about the entities underneath.**
When today's CSV reports get decomposed for analytics, what surfaces is the entities that came together to produce them. Those entities are what need conforming. Not the CSV. Not the JSON. The entities underneath.

### What a data product is, precisely

- A **foundational data product** = physical implementation of a conformed entity + metadata wrapper
- A **risk-owned data product (fact)** = physical implementation of measures at the intersection of conformed entities + metadata wrapper
- A **consumer-aligned data product** = curated view derived from upstream products + metadata wrapper

In all cases: **data product = physical implementation + metadata contract.**

The implementation can be operational or analytical. Different platforms, different wrappers, same underlying conformed entities.

---

## Consumer types

Who consumes what, with what expectations:

| Consumer | What they consume | Their expectation | What they need from metadata |
|---|---|---|---|
| **Operational app consumers** | Other apps' services / CSVs | A complete prepared answer for a transactional request | Service contracts (JSON Schema, OpenAPI) |
| **Analytical SQL consumers** | Data products in Databricks | Queryable structure they can slice their own way | Declared schema, FK relationships, allowed values, measure semantics |
| **Report consumers** | Dashboards, scheduled extracts | A pre-built answer to a known question | Business descriptions, units, refresh timing |
| **AI / agentic consumers** | Metadata of data products | Enough context to generate queries on their own | Full declared metadata — column meanings, allowed values, FKs, measure methodology |

**The AI consumer is the strongest test of metadata quality.** If an LLM with only the metadata can generate a correct query, the metadata is rich enough. If it has to guess, the metadata is incomplete.

---

## The four-layer model

Four layers of products in the operating model:

| Layer | What it is | Industry term | Examples |
|---|---|---|---|
| **1 — Foundational** | Conformed entities from source domains. Risk consumes. | Source-aligned data product | Counterparty, Agreement, Issuer |
| **2 — Risk-owned** | Risk's facts and measures at the intersection of entities | Aggregate data product | `fact_issuer_exposure`, `fact_pfe` |
| **3 — Consumer-aligned** | Curated, contracted view for a specific use case | Consumer-aligned data product | "Sovereign Exposure OSFI Daily" |
| **4 — Reports** | Rendered output — dashboards, extracts | Report / presentation artifact | Daily exposure dashboard |

**Each layer down inherits more, declares less.**

**Foundational includes both CDM-owned and Risk-owned entities.** Risk owns the foundational layer for entities CDM doesn't yet cover (netting set, CSA terms, regulatory regime).

---

## Two pushback flows from Risk to the enterprise

```
   ┌──────────────────────────────────────────────────────┐
   │                                                      │
   │  RISK                                                │
   │                                                      │
   │  ┌──────────────┐         ┌──────────────────┐       │
   │  │ Entity       │ Flow A  │ Risk-owned       │       │
   │  │ expertise    │────────▶│ data products    │       │
   │  └──────────────┘         │ (Layer 2)        │       │
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

- **Flow A — Definition flow:** Risk contributes entity expertise to CDM. The entity becomes a Layer 1 foundational product owned by CDM.
- **Flow B — Consumption flow:** Risk publishes its Layer 2 data products. The bank consumes them; Risk owns them.

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
| Entity with agreed definition | **Conformed Entity** | "CDM entity" |
| Measurement at intersection of entities | **Fact** | "entity" |
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

> *"PKs and FKs are logical, not physical. Codd defined them in 1970 as model-level concepts."*

> *"The metadata wrapper makes the dataset a data product, makes the data model visible, and makes conformity possible. Three things at once."*

> *"A data product is not a renaming. It's a graduation."*

> *"Conformed entities are documented once. Facts link to those documents — they do not re-explain."*

> *"Two facts with identical schema but different filter scopes are different facts."*

> *"The same physical table can graduate. The rows don't change. The understanding around them gets formalised."*

> *"Each layer down inherits more, declares less."*

> *"Risk contributes entity expertise to CDM; Risk publishes data products to the enterprise. Two different flows."*

> *"Self-service requires structure that allows querying."*

> *"Conformity is what makes both implementation styles trustworthy."*

> *"The conformity work isn't about the dataset surface — it's about the entities underneath."*

> *"Conformity does NOT mean everyone uses the same physical structure."*

> *"A data product is the physical implementation of a conformed entity (or measures at their intersection) with a contract wrapped around it."*

> *"The AI consumer is the strongest test of metadata quality. If an LLM with only the metadata can generate a correct query, the metadata is rich enough."*

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
│   exchanges)       Layer 1-2-3-4)                                       │
│                                        ──▶ BI dashboards & reports      │
│                                                                         │
│   Both worlds have declared metadata. Both honour the same              │
│   conformed entities. Schema is published, not inferred.                │
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
