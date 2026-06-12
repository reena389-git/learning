# Live Demo Script — Data vs Metadata with ChatGPT (M365)

## Setup before the meeting

Have these four files ready in a folder you can drag from:

1. `star_fact_issuer_exposure_DEMO.xlsx` — fact table with full metadata
2. `star_dim_counterparty_DEMO.xlsx` — counterparty dim with full metadata
3. `star_fact_issuer_exposure_STRIPPED.xlsx` — same fact table, descriptions/allowed-values/units wiped
4. `star_dim_counterparty_STRIPPED.xlsx` — same dim, stripped

Open ChatGPT in M365 (Copilot Chat or the standalone ChatGPT-Enterprise tab).

Have the slide deck `data_vs_metadata_v2.html` open in the browser as a backdrop.

---

## Part A — The "with metadata" demo (the win)

### Step 1 — Upload the two DEMO workbooks

Drag both files into ChatGPT. Wait a beat for it to acknowledge.

### Step 2 — Give it the framing prompt

Paste this into the chat:

```
I've shared two Excel workbooks. Each contains metadata for one Databricks
table in our credit risk platform.

  Important instructions:
- These workbooks contain ONLY metadata. There is no actual row-level data.
- Use the "Columns" sheet and "Table properties" sheet only.
- Ignore the "Automation" and "Source catalog" sheets unless I ask about them.
- The "Allowed values" column on the Columns sheet tells you what literal string values each column can take. Use these exact strings in any SQL.
- The "FK references" column tells you how tables join.
- Treat the "Column comment" as the authoritative business meaning.
- Always use the fully-qualified table name from the "Table name" field in Table properties.

Use metadata only.
Do not guess or infer.
Do not invent columns, tables, joins, filter values, or business meanings.

If any information required to answer the question is not explicitly present in the metadata, do not generate SQL. Instead explain what metadata is missing.

Confirm you've read both workbooks and tell me the table names.
```

### Step 3 — Ask the business question

```
Give me a Databricks SQL query that returns the top 10 sovereign issuers
by total indirect exposure across counterparties under the OSFI regulatory
regime, as of the latest snapshot date.

Use the metadata only. Do not invent column names. Use the exact
allowed-values strings from the metadata.  Do not Guess or infer . If metadata is missing do not generate SQL
```

**What should happen:** ChatGPT generates a query that:
- joins fact and dim on `counterparty_code`
- filters `issuer_type = 'Sovereign'` (from the allowed values)
- filters `regulatory_regime = 'OSFI'` (from the allowed values)
- picks the latest `as_of_date` via subquery
- aggregates `SUM(indirect_exposure)` (which it knows is semi-additive in USD)
- groups by `issuer_name`, orders desc, limits 10

### Step 4 — Optional follow-ups that show off

If you want to push further:

```
Refine the query: only include sovereign issuers rated AA or higher.
```

ChatGPT will use the `issuer_rating` allowed values (AAA, AA+, AA, AA-)
because they're in the metadata. Without metadata, it would have to guess
the rating notation.

```
What's the grain of the fact table?
```

It should answer from the primary key columns
(`agreement_id, counterparty_code, as_of_date, issuer_name`).

```
What other tables would I need to extend this analysis to include the
ultimate parent legal entity?
```

It will spot the `ultimate_parent_lei` FK in `star_dim_counterparty` and
suggest joining `star_dim_legal_entity`.

### Step 5 — Take the SQL to Databricks

Copy the generated SQL, paste into a Databricks notebook, run it.
The point is the engineers can SEE the metadata becoming a real query
becoming a real result — without ever exposing data to ChatGPT.

---

## Part B — The A/B comparison (the kill shot)

This is optional but very powerful for skeptics.

### Step 1 — Start a NEW ChatGPT chat (clean context)

### Step 2 — Upload the STRIPPED workbooks

Drag `star_fact_issuer_exposure_STRIPPED.xlsx` and
`star_dim_counterparty_STRIPPED.xlsx` into the chat.

### Step 3 — Ask the same question

Paste the same framing prompt + the same business question from Part A
Step 3.

**What will happen:** ChatGPT can see the column names and types, but it
doesn't know:
- What `issuer_type` values are valid (no "Sovereign" string)
- What `regulatory_regime` values exist (no "OSFI" string)
- That `counterparty_code` joins between the tables (no FK)
- What `indirect_exposure` represents or what unit it's in
- That the table contains "indirect" vs "direct" exposure at all

It will either:
- Refuse to answer ("I don't know the allowed values...")
- Guess wrong (write `issuer_type = 'SOVEREIGN'` or `regulatory_regime = 'IM'`)
- Generate a query that runs but returns garbage

That's the kill shot. **Same data. Same question. Without metadata, the
answer is unreliable.**

---

## What to say while demoing

**Opening line:**
> "I'm going to ask ChatGPT a real business question. But first — notice
> what I'm uploading. It's metadata only. No actual data leaves our
> environment. ChatGPT cannot see a single trade."

**After the SQL appears:**
> "ChatGPT got every column name right. Every join right. Every literal
> value right. Why? Because the metadata told it. The descriptions, the
> allowed values, the FK references — that's what makes data
> self-describing."

**Before the A/B:**
> "Now let's see what happens when we don't have the metadata. Same
> tables. Same question. But the descriptions and allowed values are
> blank. Watch."

**Closing:**
> "Every column you describe — every allowed value you write down,
> every FK you declare — is what makes this possible. Not just for
> ChatGPT. For every BI tool, every analytics consumer, every onboarding
> engineer who has to use your data."

---

## Things that can go wrong (be ready)

**ChatGPT might just generate Sample YAML/Sample DDL content** —
that's why the DEMO version has those sheets removed. If you're using a
workbook with them in, tell ChatGPT explicitly:
> "Do not use the Sample YAML or Sample DDL sheets. Synthesise from
> Columns and Table properties only."

**ChatGPT might invent fake column names** —
prompt it firmly:
> "Only use column names that appear in the Columns sheet. If you cannot
> answer with the columns present, say so."

**Numbers might not look realistic in Databricks if the synthetic data
isn't loaded** —
if you don't have synthetic data populated, the query will run with zero
rows. Either pre-populate synthetic data using the seeded synthetic_load
SQL, or just show the query landing in Databricks without executing.

**Audience asks "is this safe? are we sending real data to ChatGPT?"** —
this is the most important question. Answer:
> "No. We are sending metadata only — column names, descriptions, allowed
> values, types. No actual rows. This is the same metadata that's already
> in Unity Catalog and the Risk Data Catalog — already declared to be
> shared inside the bank. Nothing sensitive leaves."

If your organisation has explicit M365 ChatGPT data policies, mention
those by name. ("Per the TD M365 Copilot policy, metadata uploads are
permitted; trade data uploads are not.")
