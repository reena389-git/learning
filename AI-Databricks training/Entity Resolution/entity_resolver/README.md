# Config-driven Entity Resolver

Resolves messy entity records (issuer / counterparty / security / customer) into golden
entities + a governed CROSSWALK. Source table is never modified (audit). Reusable across
entity types by changing CONFIG only.

## The cascade (each tier carries a confidence + is auditable)
1. **normalize** — uppercase, strip punctuation, collapse spaces
2. **standardize tokens** — LTD=LIMITED, &=AND, BK=BANK, AG=A.G., etc. (per-entity dictionary)
3. **exact** (normalized name equal) — 1.00
4. **parent_match** — same parent (even if names share nothing, e.g. 'BofA' <-> 'Bank of America') — 0.92
5. **address_match** — same address + name overlap — 0.88
6. **corroborated** — similar name AND (parent or address agree) — 0.93
7. **fuzzy** — Jaro-Winkler >= 0.92 on name (catches typos 'Duetsche'<->'Deutsche') — 0.80
8. **semantic** — embedding on the COMPOSITE field (your Solr concat trick), cosine >= 0.72 —
   0.70, PROPOSE-then-confirm only; last resort
- **VETO**: if country or parent CONTRADICT, never merge (stops 'Bank of America' <-> 'Bank of China')
- **QUARANTINE**: anything not joined by a resolve-grade tier -> held for human review (explicit)

## Composite field (embedding text) — your Solr insight
Concatenate the configured fields into one labeled string per row:
`issuer: <name> | parent: <parent> | city: <city> | country: <country>`
Robust to missing fields (just omit). The SAME composite feeds both the deterministic tiers
(raw columns) and the semantic tier (embed the composite). Swap TF-IDF stand-in -> a real
embedding model (Databricks AI Search index on the composite, or ai_query embedding endpoint).

## Reusability
Change CONFIG only: column roles + token synonym dict + which fields corroborate + thresholds.
That CONFIG is itself a GOVERNED, versioned artifact (your entity_alignment / resolution_for).

## Files
- resolver_demo.py           — sandbox pandas version (runs locally, proven on messy data)
- resolve_entities_pyspark.py — Databricks production version (blocking + GraphFrames CC)
- issuer_messy.csv           — the messy test data (missing parents, typos, near-collision, junk)
- crosswalk.csv              — output: record -> canonical + tier + confidence + status

## Proven result (on issuer_messy.csv)
45 spellings -> 6 entities, 100% cluster purity. Near-collision (BofA vs BoC) NOT merged.
Junk (Scot/JPM/D B) quarantined. Abbreviations linked via parent_match; typos via fuzzy.

## Notes / caveats
- GraphFrames requires the library + spark.sparkContext.setCheckpointDir(...).
- Blocking (block_on) is essential at scale; without it comparison is O(n^2).
- Semantic tier: propose-then-confirm; never auto-merge on similarity alone (regulated context).
- Feed the resolved crosswalk to Genie/metric views so 'distinct issuers' = COUNT(DISTINCT canonical).
