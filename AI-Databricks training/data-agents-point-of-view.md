# Data Agents on a Governed Mesh — A Point of View

*Compiled from working discussion, September 2026. Context: Senior Architect – Data Agents role (Borrowers, Investors, Facilities, Sponsors); background is the CDM/data-mesh architecture programme — contracts at application boundaries, domain-owned products, governed aggregation, vocabulary-driven conformance. This document states the position; a prototype on sample datasets follows separately.*

---

## 1. What a data agent is — and is not

A data agent is not a catalog that talks. A catalog answers *what exists and who owns it* — that is discovery. An agent answers questions *with the data*: "what is our total facility exposure to sponsor X?" requires querying, joining, and aggregating, not looking something up in a registry. The catalog is the agent's phone book; the thing the agent actually runs on is the semantic layer.

The correct placement is this: **the agent is a consumer — an automated analyst sitting in exactly the consumer seat of the data mesh.** That placement does real work, because everything the mesh already demands of a consumer applies to the agent verbatim: query certified products in place, respect contracts, cite the versions consumed. Nothing about the agent is architecturally novel; what is novel is that this consumer speaks natural language and cannot exercise human judgment. Both facts have consequences.

## 2. The semantic layer already exists — expose it, don't rebuild it

The single largest institutional risk in a data-agent programme is that the "agent semantic layer" gets built as its own artifact — a second ontology for Borrowers, Facilities, and Sponsors, divorced from the enterprise canonical model, maintained by a different team, drifting from day one. Two competing definitions of the same entities is precisely the disease the canonical model exists to cure; an agent programme must not reintroduce it one layer up.

The semantic layer the agent needs is the one the governance programme is already producing, exposed machine-readably rather than re-authored: the **vocabulary** (each term carrying both a business definition — what the number means — and a technical definition — type, unit, sign convention, governed enumeration), the **declared relationships** (the logical model acting as dictionary: how collateral joins to facility joins to sponsor), the **contracts** (which columns carry which terms, at which version), and the **classification rules** (domain-owned, versioned decision tables — so "eligible collateral" or "high-risk industry" resolves identically for the agent and for every report). The brief for the architecture is one line: *build the exposure, not a rival model.*

## 3. Hallucination risk is a semantics problem, not a model problem

The sharpest line in the role definition is the requirement that cross-dataset relationships be *explicitly defined and governed in the semantic layer* rather than dynamically inferred by the agent. That is an architectural statement worth taking fully seriously: the language model contributes the interface; every ounce of trustworthiness comes from governed metadata underneath.

The reason is that an agent is the first consumer in the building that **cannot compensate for missing semantics with judgment**. A human analyst who meets an ambiguous column asks a colleague. An agent answers anyway — fluently, confidently, to a business user, with no error bars. Ask "what is our T-bill exposure?" over an estate where two reporting systems classify the same bond differently, and the agent silently inherits the divergence and speaks one answer with unearned confidence. The failure is not a hallucination in the model; it is an ambiguity in the estate, surfaced at conversational speed.

The operational rule that follows: **every join the agent constructs must be a declared edge; every term it resolves must be a governed definition; every filter it applies must trace to an owned rule.** Where the semantic layer is silent, the agent must decline rather than infer. This converts the domains' obligation to explain their data from documentation debt into a runtime prerequisite — a blank row in the metadata standard is now, exactly, a question the agent cannot answer.

## 4. Agent topology inherits data topology

The tempting design for multi-desk questions is federated answering: each desk or domain runs an agent over its own context, and an aggregation agent compiles the responses. This recreates, at answer level, the self-served union that governed aggregation exists to prevent. If an aggregator polls five desk agents for collateral and compiles the replies, then one timeout produces a plausible wrong total with no manifest to catch it; two desks' slightly different readings of "eligible" merge invisibly; and prose-level compilation carries no row provenance at all.

The rule is that **agents federate only where the data legitimately federates.** Where governance has already unified the data — the aggregated collateral product: union across desks with provenance, completeness manifest, source stamping, done once — a single agent queries the unified product. The aggregation agent's job was done by the aggregation layer. Where a question genuinely spans domains that are deliberately not pre-joined (collateral coverage against exposure, by counterparty), an orchestrating agent may decompose and route — but composition happens at **data level, never prose level**: sub-agents return structured results keyed on conformed identifiers, and the orchestrator joins rows on those keys. Merging text loses provenance and cannot reconcile; joining results on conformed keys is just a distributed query, and it is only possible because everything conformed to the contract. Interoperability-by-conformed-keys, executed by software.

## 5. Answers must cite their manifest

A number spoken in natural language is an aggregation like any other, and it earns trust the same way: by declaring what sits underneath it. An agent's answer must be able to cite the products it queried, the contract versions in force, the classification-rule versions applied, and the run identifiers of the computed metrics it consumed — which official end-of-day run, which engine. This is the completeness-and-provenance discipline of the data platform surfacing at the conversational layer, and it is the difference between a governed consumer and a fluent liability. The infrastructure for these citations is not agent-specific; it is the vocabulary, the catalog, the contracts, and the calculation-run linkage — the same artifacts the platform needs anyway, now with one more consumer.

## 6. Why this is demand-side pressure for the governance programme

Every hard dependency of the agent programme is an artifact the governance programme already produces:

| Agent requirement | Existing artifact |
|---|---|
| Resolve business terms to columns | Vocabulary: business + technical definition per term, versioned |
| Construct joins safely | Declared relationships (logical model as dictionary); contracts naming keys |
| Apply classifications consistently | Rules-as-data: domain-owned, versioned decision tables |
| Answer across desks/domains | Aggregated products (union with provenance) and conformed keys |
| Cite what an answer stands on | Catalog registration, contract versions, calculation-run identifiers |
| Know what it cannot answer | Coverage of the metadata standard — blank rows are unanswerable questions |

The consequence runs in both directions. The agent cannot be trusted without the governed semantic layer; and the semantic layer acquires, in the agent, the best enforcement mechanism it will ever have — teams that resisted filling in metadata for a standards document will fill it in to make their data speakable.

## 7. Seed for the prototype

The minimum credible prototype demonstrates the whole argument on sample data: a small conformed estate (positions and metrics for two or three source systems; a collateral product aggregated across desks with a completeness manifest; one classification overlay such as country groupings), a machine-readable vocabulary sheet and relationship declarations, and an agent that (a) constructs queries only through declared edges and governed terms, (b) answers a cross-desk question from the aggregated product rather than by polling sources, (c) declines a question the semantic layer cannot support, and (d) attaches a manifest to every answer — products, versions, runs. Success is not eloquence; it is the decline in (c) and the citations in (d).

---

*One-line summary: a data agent is a governed consumer that talks — standing on the catalog for discovery, the vocabulary and declared relationships for meaning, and the contracts for trust; agent topology inherits data topology; and every answer carries its manifest.*
