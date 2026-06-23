# Stress PFE Counterparty Tearsheet — End-to-End Build Notes

*A learning + reference document covering the business context, the data, and the Strategy One implementation.*

**How to read this:** This document is written for two readers at once — the **business reader** who wants to understand counterparty credit risk, limits, and stress PFE (what they are, why TD measures them, what decisions they drive), and the **technical reader** who wants to understand how we built the dashboard. Every technical choice is tied back to the business reason for it, and each concept is illustrated with a concrete example. If a section gets technical, the "Why it matters" note brings it back to the business.

A running example threads through the whole document: the counterparty **AGNC Investment Corp.**, whose line in our system is `CP_(TDBK)_(AMCQ_C2C)` (TD Bank facing AGNC, counterparty code **AMCQ**).

---

## Table of Contents

1. [The Business Problem — What and Why](#1-the-business-problem)
2. [The Core Concepts (with examples)](#2-the-core-concepts)
3. [The Data Landscape](#3-the-data-landscape)
4. [The `asts` Table in Detail](#4-the-asts-table-in-detail)
5. [Data-Quality Realities We Found](#5-data-quality-realities)
6. [The Semantic Model](#6-the-semantic-model)
7. [The Dashboard / Tearsheet, Visual by Visual](#7-the-dashboard-tearsheet)
8. [The Views — Logic and Construction](#8-the-views)
9. [Parked Items and Notes for the Rebuild Team](#9-parked-items)
10. [Glossary](#10-glossary)

---

## 1. The Business Problem

### What we're building
We are rebuilding a legacy per-counterparty **"PFE Stress Testing" tearsheet** — historically a static report produced from the **SCREAM** risk engine and assembled in Word/Excel — as a **live, governed dashboard in Strategy One**, sitting on a **Mosaic semantic model** over **Databricks**.

A "tearsheet" is a one-page summary for a single counterparty: who they are, how much potential exposure TD has to them, how that exposure behaves under stress, where it breaches limits, and a space for the analyst's commentary.

### Why it matters (the business drivers)
- **Counterparty credit risk is a real loss channel.** When TD trades derivatives or financing with a counterparty, TD can end up *owed money* by that counterparty. If the counterparty defaults while owing TD, TD takes a loss. Credit Risk's job is to measure and limit that exposure *before* it becomes a loss.
- **Stress testing reveals the tail.** Normal-market exposure can look modest, but a 2008-style shock can multiply it. The business needs to see "how bad could this get" — not just today's number.
- **Limits are how the bank controls appetite.** Each counterparty/line has limits. A **breach** (exposure over limit) is a signal that requires attention, escalation, or action (reduce positions, demand collateral, etc.).
- **Governance.** The legacy report was assembled in spreadsheets — ungoverned calculations that can't be audited or trusted as a single source of truth. The thesis here: *any calculation outside the registered semantic model is ungoverned.* By moving the logic into a Databricks → Mosaic semantic model → Strategy stack, the numbers become governed, versioned, and self-service.

**Who reads it:** a credit-risk analyst (like the person these notes are for), reviewing a counterparty, deciding whether a stressed breach needs action, and recording why.

---

## 2. The Core Concepts

This is the heart of the business understanding. Read this section even if you skip the rest.

### 2.1 Counterparty Credit Risk (CCR)
**Plain version:** the risk that someone TD trades with fails to pay what they owe.

**Real-life analogy:** lending a friend money is *credit risk*. But CCR is subtler — it's like co-signing a deal whose value swings. You might be *owed* money one month and *owe* money the next, depending on the market. You only lose if (a) they owe you *and* (b) they default at that moment.

**Example:** TD enters a 5-year interest-rate swap with AGNC. At inception it's worth ~$0 to both sides. Six months later, rates have moved and the swap is worth **+$10M to TD** (AGNC owes TD $10M of mark-to-market value). If AGNC defaults right then, TD loses that $10M. That $10M is TD's *exposure* at that moment.

### 2.2 Potential Future Exposure (PFE) — the key metric
Exposure today is knowable. Exposure *in the future* is not — it depends on where the market goes. **PFE** is a **simulated estimate of how large the exposure could plausibly become** over the life of the trades.

**How it's produced:** the SCREAM engine runs a **Monte Carlo simulation** — thousands of possible future market paths — revalues TD's positions on each path, and takes a high percentile of the exposure distribution. That percentile is the PFE.

**Real-life analogy:** a weather forecast doesn't say "it will rain 4mm." It says "90th-percentile rainfall could be 30mm." PFE is the 90th-percentile (or similar) of *future exposure*, not the average.

**Why the business cares:** TD sets limits against PFE, not today's tiny exposure, because the *potential* is what can hurt.

### 2.3 Tenor / Time Buckets — exposure has a maturity profile
Exposure isn't a single number; it changes over the life of the trades. So PFE is measured across **time buckets**:

`0–3 Mo` · `3–12 Mo` · `1–2 Yr` · `2–5 Yr` · `5–10 Yr` · `10–50 Yr`

**Real-life analogy:** a mortgage's risk profile changes over 30 years. Likewise, a swap's potential exposure might be small near-term and peak years out.

**Example (AGNC):** AGNC's potential exposure is small in `0–3 Mo` but **balloons in the `2–5 Yr` bucket** — which, as we'll see, is exactly where its largest breach sits.

### 2.4 Max Usage and Limits — utilization
- **Limit:** the maximum exposure TD is willing to carry on a line, set per tenor bucket. It encodes credit appetite.
- **Max Usage:** the peak PFE within a bucket under a scenario — i.e. **how much of the limit the exposure consumes**.

**Real-life analogy:** a **credit card**. The limit is your credit line; usage is what you've charged. Go over the limit → a breach.

**Example:** if AGNC's `2–5 Yr` limit is \$10M and the stressed Max Usage is \$12.3M, the line is **over limit in that bucket** — a breach.

### 2.5 Standard / Current Exposure vs Stressed Exposure
- **Standard / Current Exposure:** PFE under *normal* market assumptions (the unstressed base case).
- **Stressed Exposure:** PFE after re-running the simulation under a **stress scenario**.

**Example (AGNC, `2–5 Yr`):** Current Exposure ≈ **\$296,801**; Stressed Exposure ≈ **\$12,278,413**. Stress makes the potential exposure roughly **40× larger** — that gap is the whole point of stress testing.

### 2.6 Stress Scenarios — why correlation and volatility
Stress scenarios re-run the simulation with **stressed correlations and volatilities**. The most punishing ones crank **correlation toward 1.0**.

**Why correlation matters (real-life analogy):** a diversified stock portfolio is safe *because* its holdings don't all move together — some rise while others fall. But in a crash (2008, March 2020), **"all correlations go to 1"**: everything falls at once, diversification evaporates, and losses spike. Stress scenarios deliberately simulate that breakdown.

The scenarios in our data (engine codes, then the descriptive names from the tearsheet legend):

| Engine code | Summary shorthand | Descriptive name (tearsheet legend)* |
|---|---|---|
| `BASE` | Cartor / Base | Base (≈ Current Exposure) |
| `ZeroCorrelation` | Zero | Volatility & Correlation-0 |
| `Correlation_0.25` | 25 | Volatility & Intermediate-Market-0 Correlation* |
| `Correlation_0.75` | 75 | Volatility & Intermediate-Market-1 Correlation* |
| `Correlation_1.0` | One | Volatility & Correlation-1 |
| `STRMARKETC75` | STR75 | STRMARKETC75 |
| `ProdCorrelation` | Prod | Volatility & Market Correlation* |
| `STRMPR025` | STRMPR025 | STRMPR025 |

\* The descriptive-name mapping for the three starred rows is a **blueprint placeholder** read off the sample legend and **not yet validated** against a scenario dictionary — see §8.3 and §9.

**Why `Correlation_1.0` is often the binding scenario:** it removes all diversification benefit, so offsetting positions stop offsetting and exposure is maximised.

### 2.7 Breach — and why it's not just "over the limit"
A **breach** is not simply Max Usage > Limit. The business rule (from the spec, pre-computed in our data) requires **both**:

1. Max Usage > Limit × (Excess% + 1), **and**
2. Max Usage > Limit + a rating-based buffer.

The `Excess%` and buffer come from the **Credit Limit Threshold** table, keyed on the counterparty's **worst rating** (use the leading number only — e.g. rating `"4A"` → `4`):

| Worst Rating | Limit | Excess % |
|---|---|---|
| 0 | 300M | 50% |
| 1 | 300M | 50% |
| 2 | 100M | 40% |
| 3 | 50M | 30% |
| 4 or worse | 10M | 30% |

**Worked example (AGNC, rating `4A` → 4):** limit band \$10M, excess 30%. A bucket breaches only if stressed Max Usage exceeds **\$10M × 1.30 = \$13M** *and* exceeds \$10M + buffer. This two-part test prevents trivial, just-barely-over noise from being flagged as a breach — the business only wants *material* breaches escalated.

**Why two conditions (business intent):** the percentage test scales with limit size (a 5% overshoot on a huge limit can be large in dollars); the buffer test guards small limits. Together they define a *meaningful* breach.

### 2.8 Gross vs Net, Netting, and Collateral (CSA)
- **Gross exposure:** the sum of what TD is owed, ignoring offsets — the worst case before any mitigation.
- **Netting:** under an **ISDA master agreement**, TD's many trades with one counterparty offset. *Example:* trades worth **+\$20M** and **−\$15M** net to **\$5M** of exposure, not \$20M.
- **Collateral / CSA (Credit Support Annex):** an agreement to post collateral as exposure grows.
  - **CSA Direction** (e.g. **2-Way CSA**): both sides post collateral.
  - **CP Threshold:** how far the counterparty's owing can grow before *they* must post collateral to TD. *Example:* CP threshold \$5M, MTA \$1M → once AGNC owes TD more than \$5M, AGNC posts collateral (in \$1M increments), capping TD's *uncollateralized* exposure near \$5M.
  - **TD Threshold:** the mirror — how far TD's owing can grow before *TD* posts collateral.
  - **MTA (Minimum Transfer Amount):** collateral only moves in chunks ≥ MTA, to avoid tiny daily transfers.

**Why it matters:** netting and collateral are the main reasons real exposure is far below gross. The tearsheet's CSA section (annotation #2) tells the analyst what mitigation is in place.

### 2.9 TD Sub (intragroup carve-out)
Some lines face **TD's own entities** (e.g. *TD Securities (USA) LLC*). That's TD lending to itself — **not external credit risk** — so those lines are flagged **TD Sub = Y** and **carved out of external breach reporting**.

**Analogy:** moving money between your own checking and savings accounts isn't "lending" — no credit risk to track.

### 2.10 OTC vs SFT
- **OTC** = over-the-counter derivatives (swaps, options).
- **SFT** = Securities Financing Transactions (repo, securities lending).
The line/branch naming flags it: a code containing `_DBL`, `_EBL`, or `_BSB` → **SFT**; otherwise **OTC**. They have different risk dynamics, so the tearsheet distinguishes them.

---

## 3. The Data Landscape

### 3.1 Where exposure is actually calculated
The **SCREAM engine** is the upstream Monte-Carlo simulator. **This is where PFE is computed.** Everything downstream (the AST tables, our views, Strategy) is **business aggregation and presentation** — choosing maxima across scenarios, flagging breaches, drawing charts. *No risk is re-calculated downstream.* This separation matters for governance: the risk number has one authoritative source.

### 3.2 The source feeds (SCREAM outputs, schema `xvala_core-raw`)
| Feed | Role | What it is, in business terms |
|---|---|---|
| `lines_report.csv` | **Fact** | The published exposure-vs-limit numbers at line grain: Max Usage ×6 buckets, Limit ×6, Gross Max Exposure, worst rating. |
| `clients_report.csv` | **Dimension** | The counterparty reference: code, name, BIS code, country, industry, ratings, and the **netting/CSA agreement block** (ISDA/CSA/NET flags, Agreement ID/Type) — the gross-vs-net and collateral story. |
| `exp_decomp_report.csv` | **Lineage** | A tall reconciliation feed that ties decomposed exposure back to `lines_report` (a `Difference` row = 0 proves the tie). Not a headline source. |
| `Line_Exclusion_Table.csv` | **Governed exclusions** | An approval-workflow list removing internal test lines ("DESKTOP SCREAM CP"). |
| `limits.csv` | **Reference** | The live Credit Limit Threshold table (rating → limit, excess %). |

### 3.3 The AST output tables (schema `xvala_xva`, catalog `d4001-centralus-tdvip-creditrisk`)
The "AST" process consumes the SCREAM feeds and produces two tables that the tearsheet is built on:
- **`asts`** — the **detailed** table. Grain ≈ **line × scenario**, with the six time buckets laid out **wide** (one column per bucket). This is the workhorse for our build.
- **`ats_summary`** — the **summary** table, **one row per line**, carrying the per-scenario maxima (Cartor/Base Max, Zero Max, … STRMPR025 Max), Max of All, Scenario of Max, Percentage of Impact, and enrichment (rating, country/region, industry, OTC/SFT, TD Sub).

**Why two tables:** the summary answers "what's the worst across everything for this line" (one number per line — great for KPIs and the scenario-maxima bars), while the detailed table holds the full bucket × scenario grid (needed for the maturity-profile charts and breach detail).

---

## 4. The `asts` Table in Detail

54 columns. Grouped by family so the structure is legible:

**Identity / line attributes**
`Scenario_Name`, `Line`, `Long_Name`, `Line_Type`, `Line_Expiry` (int, **YYYYMMDD** — e.g. `20180531` = 2018-05-31), `No_Line_Indicator`, `Line_Currency`, `Worst_Rating_Of_Associated_Clients`.

**Current (unstressed) usage — 6 wide buckets**
`Standard_Usage_0_3_mo` … `Standard_Usage_10_50_Yr`.

**Stressed max usage — 6 wide buckets**
`Max_Usage_0_3_mo` … `Max_Usage_10_50_Yr`. *This is the per-scenario stressed PFE per bucket.*

**Limits — 6 wide buckets, named by tenor ENDPOINT (not range)**
`Limit_3_mo`, `Limit_1_Yr`, `Limit_2_Yr`, `Limit_5_Yr`, `Limit_10_Yr`, `Limit_50_Yr`.
> ⚠️ **Trap:** usage columns are named by *range* (`_0_3_mo`, `_3_12_mo`, …) but limits by their *endpoint*. They map **positionally**: `Limit_3_mo` → `0–3 Mo`, `Limit_1_Yr` → `3–12 Mo`, `Limit_2_Yr` → `1–2 Yr`, `Limit_5_Yr` → `2–5 Yr`, `Limit_10_Yr` → `5–10 Yr`, `Limit_50_Yr` → `10–50 Yr`. Get this wrong and the limit line sits against the wrong buckets.

**Breach flags — 6 wide buckets** (`TRUE`/`FALSE`, stored as strings)
`0_3_mo_Excess_Breach` … `10_50_Yr_Excess_Breach`. *Already encode the two-condition breach rule — we don't re-derive it.*

**Excess % — 6 wide buckets** (double)
`0_3_mo_Excess_Percentage` … `10_50_Yr_Excess_Percentage`.

**Line-level summary fields**
`Gross_Max_Exposure`, `Max_Scenario_Exposure`, `Max_Exp_Time_Bucket`, `Max_Scenario_Name`, `Standard_Exposure`, `Excess_Percentage`, `Exposure_Percentage` (+ per-bucket variants), `business_date`.

**Lineage leftovers** `Scenario`, `Timestep` — fields carried from an exp_decomp-style merge; a likely source of duplicate-looking rows.

> **Important:** every dollar/usage/limit column is typed **`string`**, not numeric (only the Excess_Percentage columns are `double`). So anything that plots them must **cast** (`TRY_CAST(REPLACE(col, ',', '') AS DOUBLE)`). This shows up all over the view logic.

---

## 5. Data-Quality Realities

These are real wrinkles in `asts` we discovered and worked around. They're flagged for the rebuild team to fix at source.

1. **35 exact-duplicate rows.** Removed in every view with `SELECT DISTINCT *` (the `asts0` CTE).
2. **`Long_Name` has variants per line** (stray spaces / truncation). Including it in a `GROUP BY` split a line into two → doubled the Limit/Current series (12 rows instead of 6). *Fix:* group only on the true key `(Line, business_date)` and pull `Long_Name` in via `MAX()`.
3. **The `BASE` row can have null Limit/Usage.** Our first dedup picked the alphabetically-first scenario row (`BASE`), which for some lines has null limits — so Limit came back empty. *Fix:* use `MAX()` across the line's rows (MAX ignores nulls and limits are constant per line, so it grabs the populated value).
4. **`Line_Type` appeared multi-valued for some lines** — investigated; tied to the duplicate/lineage rows, not a true composite key.
5. **All-string dollar columns** and **`Line_Expiry` as a YYYYMMDD int** — handled with casts.

**Why we proceeded anyway:** these are blueprint-acceptable. The summary rebuild is another team's process; our job was to prove the end-to-end tearsheet works on current data, with the wrinkles documented.

---

## 6. The Semantic Model

### 6.1 Why a semantic model at all (business driver)
The model (**Mosaic**, inside Strategy One — "Stress PFE Data Model") is where raw Databricks columns become **governed business objects**: *Borrower*, *Line*, *Worst Rating*, *Time Bucket*, *Scenario*, *Limit*, *Excess %*. Defining them once, centrally, means every chart and every analyst uses the *same* definition — the opposite of everyone rolling their own spreadsheet formula. **Governance thesis: any calc outside this model is ungoverned.**

### 6.2 What's in it
- **~29 attributes, ~52 metrics.**
- **Line** is the central hub — everything joins to it.
- **Hierarchies** (so analysts can drill): `Region → CIF Country Name → Country Of Risk`, and `Industry → SIC Industry`.
- **Breach indicators kept as attributes** (text `TRUE`/`FALSE`) rather than metrics — because their job is **filtering** ("show me only breaching lines"), not arithmetic.

### 6.3 Aggregation rules — tied to business meaning
A subtle but important point:
- **Dollar amounts → Sum** when rolling up across lines (a portfolio total is the sum of line exposures). Within a single line the bucket max is already baked in, so the "Maximum" in a metric name refers to that pre-computed within-line max.
- **Ratios / percentages → Max, never Sum.** *Why:* summing percentages is meaningless. *Example:* two lines at 80% and 90% utilization don't make 170% — you want the max (90%) or an average, not a sum. Excess % and Exposure % are set to **MAX**.

### 6.4 Renaming for the business
Raw engine columns (`Cartor Maximum`, `STR MPR 025 Maximum`) were relabeled to friendlier names on the visuals (Base, 0.25, STR75, Prod, …) so a credit analyst reads scenarios, not engine codes. (The full *descriptive* names — "Volatility & Correlation-1" etc. — are handled via a mapping table; see §8.3.)

### 6.5 Time Bucket sorting (a worked gotcha)
Time Bucket initially sorted **alphabetically** (`0-3 Mo, 1-2 Yr, 10-50 Yr, 2-5 Yr, …`) — nonsensical for a maturity axis. *Fix:* the view emits a numeric **`bucket_order`** (1–6); we added it as a **form of the Time Bucket attribute** and set the attribute's **sort criterion to Bucket Order ascending**. Key lesson: the sort must live on the *attribute on the axis* (Time Bucket), sorted *by* bucket_order — sorting a separate Bucket Order attribute does nothing to the axis.

---

## 7. The Dashboard / Tearsheet

Dashboard: **"Stress PFE | Chapter 1 | Page 1."** Each visual below is paired with the **business question it answers**.

### 7.1 Header card — *"Who and what am I looking at?"*
Borrower Name, Line, Rating, Exposure Type, Line Currency. Built as a card and **transposed (Swap Rows/Columns)** into a vertical, tearsheet-style block.
> Note: the dashboard is **per-line**, not per-borrower. AGNC (AMCQ) has three lines — `CP_(TDBK)_(AMCQ_C2C)`, `CP_(TDSU)_(AMCQ_C2C)`, `CP_(TDSU)_(AMCQ_DBL)` — so cascading **Borrower ↔ Line** filters let the analyst pick the borrower then the specific line.

### 7.2 Scenario-maxima bar chart (Visualization 1) — *"Which stress scenario is worst for this line?"*
Eight scenario-max metrics as eight bars (metric names on the horizontal axis). The tallest bar = the binding scenario.
> **Honest limitation:** because each bar is a *separate metric* (not one metric split by a Scenario attribute), Strategy can't auto-sort the bars by value or auto-highlight the max — bar order follows the metric order, coloring is fixed. Fine for a single-line tearsheet; true dynamic sort/highlight would need the long (attribute) shape.

### 7.3 KPI tile — *"The headline numbers."*
Max of All, Scenario of Max, Percentage of Impact.
> Note: *Max of All* and *Max Scenario Exposure* are the **same number by definition** (the peak across scenarios) — showing both is redundant; swap one for *Scenario of Max* (the binding scenario's name) so the tile tells a story. **Percentage of Impact** example: **1,489%** means the stressed peak is ~**15× the base** — i.e. a tiny ~\$1.1M base blowing out to ~\$16.4M under stress. Format it as `1,489%` (or `14.9×`), not a raw `1489.46…`.

### 7.4 Multi-Factor Stress Results (Visualization 3) — the hero — *"How does exposure behave across the maturity curve, per scenario, vs the limit?"*
A clustered bar chart: **x = Time Bucket**, **y = Value**, **color = Series** (Limit, Current Exposure, and each scenario). This is the tearsheet's centrepiece. Building it required the **wide → long unpivot** (§8.1) so that Time Bucket and Series exist as *attributes*.

### 7.5 Exposure Change, Stressed vs Current (line chart) — *"Where does stress add the most exposure?"*
**x = Time Bucket**, **one line per scenario**, **y = `change_vs_current`** ( = stressed − current). Filtered to scenario series only (Current Exposure's delta is 0; Limit's isn't meaningful). Rising lines show where along the maturity curve stress bites hardest.

### 7.6 Breach summary grid — *"What's the single worst breach, and what drives it?"*
The "Bucket of Largest Breach" table: Bucket of Largest Breach (+ line expiry date), Limit, Current Exposure, Stressed Exposure, Scenario of Largest Breach. Built from a dedicated view (§8.2) that finds, per line, the breaching (scenario, bucket) with the biggest excess. Beneath it sits the **commentary block** (Primary/Secondary Risk Drivers, Products Driving Exposure, Notes) — manual, see §8.4.

### 7.7 The legend as a shared box (annotation #3)
The auto-generated chart legend *is* the scenario color key. To present it as a separate box like the sample: first **lock Series colors page-wide** (so one legend validly describes every chart), then either keep one chart's legend positioned to the side (simplest) or build a tiny dummy bar-chart "legend" viz. Cosmetic, but the color-locking is worth doing anyway so scenarios are one color across the whole page.

---

## 8. The Views

The hard work lived in SQL views over `asts`. The recurring principle: **do the data shaping in governed views so the dashboard stays simple and single-table** (which also avoids Cartesian/fan-out joins).

### 8.1 `vw_asts_bucket_pivot` — wide → long, the engine of the charts

**The business need that drove it:** the hero chart and the exposure-change chart both need **Time Bucket** and **Series** as *dimensions you can put on an axis / color by*. But `asts` stores buckets **wide** (each bucket is a separate column) and has no single "series" column. You cannot put a column name on an axis. So we **unpivot**.

**Before (wide) — one row:**
```
line                 scenario        Max_Usage_0_3_mo  Max_Usage_3_12_mo  ...  Limit_3_mo  ...
CP_(TDBK)_(AMCQ_C2C) Correlation_1.0 1,100,000         3,400,000          ...  10,000,000  ...
```
**After (long) — many rows, one per (series, bucket):**
```
line                 series            time_bucket  bucket_order  value
CP_(TDBK)_(AMCQ_C2C) Correlation_1.0   0-3 Mo       1             1,100,000
CP_(TDBK)_(AMCQ_C2C) Correlation_1.0   3-12 Mo      2             3,400,000
CP_(TDBK)_(AMCQ_C2C) Limit             0-3 Mo       1             10,000,000
CP_(TDBK)_(AMCQ_C2C) Current Exposure  0-3 Mo       1             280,000
...
```
Now Time Bucket and Series are real columns → real attributes → axis + color.

**Construction logic, CTE by CTE:**
- **`asts0`** — `SELECT DISTINCT *` to drop the 35 exact-duplicate rows.
- **`line_rep`** — one row per `(Line, business_date)` using `MAX()` on every Limit and Standard_Usage column. *Why MAX:* Limit and Current are the **same across all scenario rows**, so we need exactly one copy per line; `MAX` both de-duplicates *and* grabs the **non-null** value (solving the empty-`BASE`-row problem). Grouping on `(Line, business_date)` only (not `Long_Name`) avoids the variant-driven doubling.
- **`current_long`** — Standard_Usage unpivoted to one `current_value` per `(line, bucket)`, used to compute the stressed-vs-current delta.
- **`base_long`** — three `UNION ALL` blocks, each unpivoting six wide columns via Spark `stack(6, …)`:
  1. **Scenario usage** from `Max_Usage_*` (series = the scenario), read from all rows.
  2. **Current Exposure** from `Standard_Usage_*` (series = `'Current Exposure'`), from `line_rep`.
  3. **Limit** from `Limit_*` (series = `'Limit'`), from `line_rep`, using the **positional** column→bucket map.
- **Final SELECT** — joins `current_long` (adds `current_value` and `change_vs_current = value − current_value`) and maps raw scenario codes to descriptive names with an **inline CASE** (formerly the separate `scenario_display_xref` view, now folded in here; `COALESCE` leaves Limit/Current untouched). Each value is `TRY_CAST(REPLACE(value_str, ',', '') AS DOUBLE)` — handling the all-string columns. A numeric `bucket_order` rides along for correct sorting.

```sql
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_xva`.`vw_asts_bucket_pivot` AS
WITH asts0 AS (
  SELECT DISTINCT * FROM `d4001-centralus-tdvip-creditrisk`.`xvala_xva`.`asts`
),
line_rep AS (
  SELECT Line, business_date, MAX(Long_Name) AS Long_Name,
         MAX(Limit_3_mo) AS Limit_3_mo,  MAX(Limit_1_Yr) AS Limit_1_Yr,
         MAX(Limit_2_Yr) AS Limit_2_Yr,  MAX(Limit_5_Yr) AS Limit_5_Yr,
         MAX(Limit_10_Yr) AS Limit_10_Yr, MAX(Limit_50_Yr) AS Limit_50_Yr,
         MAX(Standard_Usage_0_3_mo)  AS Standard_Usage_0_3_mo,
         MAX(Standard_Usage_3_12_mo) AS Standard_Usage_3_12_mo,
         MAX(Standard_Usage_1_2_Yr)  AS Standard_Usage_1_2_Yr,
         MAX(Standard_Usage_2_5_Yr)  AS Standard_Usage_2_5_Yr,
         MAX(Standard_Usage_5_10_Yr) AS Standard_Usage_5_10_Yr,
         MAX(Standard_Usage_10_50_Yr) AS Standard_Usage_10_50_Yr
  FROM asts0 GROUP BY Line, business_date
),
current_long AS (
  SELECT line, business_date, bucket_order,
         TRY_CAST(REPLACE(value_str, ',', '') AS DOUBLE) AS current_value
  FROM (
    SELECT Line AS line, business_date,
      stack(6, 1,Standard_Usage_0_3_mo, 2,Standard_Usage_3_12_mo, 3,Standard_Usage_1_2_Yr,
               4,Standard_Usage_2_5_Yr, 5,Standard_Usage_5_10_Yr, 6,Standard_Usage_10_50_Yr
      ) AS (bucket_order, value_str)
    FROM line_rep
  )
),
base_long AS (
  -- 1) stressed usage per scenario
  SELECT line, long_name, business_date, scenario, series, time_bucket, bucket_order,
         TRY_CAST(REPLACE(value_str, ',', '') AS DOUBLE) AS value
  FROM (
    SELECT Line AS line, Long_Name AS long_name, business_date,
           Scenario_Name AS scenario, Scenario_Name AS series,
           stack(6, '0-3 Mo',1,Max_Usage_0_3_mo, '3-12 Mo',2,Max_Usage_3_12_mo,
                    '1-2 Yr',3,Max_Usage_1_2_Yr, '2-5 Yr',4,Max_Usage_2_5_Yr,
                    '5-10 Yr',5,Max_Usage_5_10_Yr,'10-50 Yr',6,Max_Usage_10_50_Yr
           ) AS (time_bucket, bucket_order, value_str)
    FROM asts0
  )
  UNION ALL  -- 2) current exposure
  SELECT line, long_name, business_date, CAST(NULL AS STRING), 'Current Exposure', time_bucket, bucket_order,
         TRY_CAST(REPLACE(value_str, ',', '') AS DOUBLE)
  FROM (
    SELECT Line AS line, Long_Name AS long_name, business_date,
           stack(6, '0-3 Mo',1,Standard_Usage_0_3_mo, '3-12 Mo',2,Standard_Usage_3_12_mo,
                    '1-2 Yr',3,Standard_Usage_1_2_Yr, '2-5 Yr',4,Standard_Usage_2_5_Yr,
                    '5-10 Yr',5,Standard_Usage_5_10_Yr,'10-50 Yr',6,Standard_Usage_10_50_Yr
           ) AS (time_bucket, bucket_order, value_str)
    FROM line_rep
  )
  UNION ALL  -- 3) limit (positional column -> bucket mapping)
  SELECT line, long_name, business_date, CAST(NULL AS STRING), 'Limit', time_bucket, bucket_order,
         TRY_CAST(REPLACE(value_str, ',', '') AS DOUBLE)
  FROM (
    SELECT Line AS line, Long_Name AS long_name, business_date,
           stack(6, '0-3 Mo',1,Limit_3_mo, '3-12 Mo',2,Limit_1_Yr,
                    '1-2 Yr',3,Limit_2_Yr, '2-5 Yr',4,Limit_5_Yr,
                    '5-10 Yr',5,Limit_10_Yr,'10-50 Yr',6,Limit_50_Yr
           ) AS (time_bucket, bucket_order, value_str)
    FROM line_rep
  )
)
SELECT b.line, b.long_name, b.business_date, b.scenario,
       -- scenario display names are built in here (formerly the scenario_display_xref view).
       -- Non-scenario rows (Limit, Current Exposure) fall through to the original label.
       COALESCE(
         CASE b.series
           WHEN 'BASE'             THEN 'Base'
           WHEN 'ZeroCorrelation'  THEN 'Volatility & Correlation-0'
           WHEN 'Correlation_1.0'  THEN 'Volatility & Correlation-1'
           WHEN 'Correlation_0.25' THEN 'Volatility & Intermediate-Market-0 Correlation'
           WHEN 'Correlation_0.75' THEN 'Volatility & Intermediate-Market-1 Correlation'
           WHEN 'ProdCorrelation'  THEN 'Volatility & Market Correlation'
           WHEN 'STRMARKETC75'     THEN 'STRMARKETC75'
           WHEN 'STRMPR025'        THEN 'STRMPR025'
         END,
         b.series
       ) AS series,
       b.time_bucket, b.bucket_order, b.value,
       c.current_value,
       b.value - c.current_value AS change_vs_current
FROM base_long b
LEFT JOIN current_long c
  ON b.line = c.line AND b.business_date = c.business_date AND b.bucket_order = c.bucket_order;
```

### 8.2 `vw_asts_largest_breach` — the breach summary, done properly

**Business need:** the breach grid must show *the single worst breach* for a line — which bucket, which scenario, how big. The tearsheet says "largest **breach**," so we use the **pre-computed breach flags** (which already encode the two-condition rule) and rank the breaching cells by severity.

**Logic:**
- `ref` — Limit & Current per `(line, bucket)`, non-null via `MAX` (same pattern as above).
- `breaches` — per `(line, scenario, bucket)`: stressed usage, breach flag, excess % (unpivoted together).
- **Final** — keep only `breach_flag = 'TRUE'`, rank per line by **excess amount** (`stressed − limit`) descending, take the top row. *Ranking choice:* by dollar excess; switch the `ORDER BY` to `excess_pct` if the methodology defines "largest" by percentage.
- One row per line, **single-table** → the grid reads everything from here (no fan-out).

> **Line Expiry Date is intentionally NOT in this view.** It is modelled as an attribute/form of **Line** sourced from the `asts` table, so the Line relationship carries one expiry per line onto the grid (see README §2.3). Keeping it out of the view avoids the old cross-grain Cartesian without baking a date conversion into the breach SQL.

```sql
CREATE OR REPLACE VIEW `d4001-centralus-tdvip-creditrisk`.`xvala_xva`.`vw_asts_largest_breach` AS
WITH asts0 AS (
  SELECT DISTINCT * FROM `d4001-centralus-tdvip-creditrisk`.`xvala_xva`.`asts`
),
ref AS (
  SELECT line, business_date, bucket_order,
         TRY_CAST(REPLACE(limit_str,  ',','') AS DOUBLE) AS limit_value,
         TRY_CAST(REPLACE(current_str,',','') AS DOUBLE) AS current_value
  FROM (
    SELECT Line AS line, business_date,
      stack(6, 1,Limit_3_mo,Standard_Usage_0_3_mo,   2,Limit_1_Yr,Standard_Usage_3_12_mo,
               3,Limit_2_Yr,Standard_Usage_1_2_Yr,   4,Limit_5_Yr,Standard_Usage_2_5_Yr,
               5,Limit_10_Yr,Standard_Usage_5_10_Yr, 6,Limit_50_Yr,Standard_Usage_10_50_Yr
      ) AS (bucket_order, limit_str, current_str)
    FROM (
      SELECT Line, business_date,
        MAX(Limit_3_mo) Limit_3_mo, MAX(Limit_1_Yr) Limit_1_Yr, MAX(Limit_2_Yr) Limit_2_Yr,
        MAX(Limit_5_Yr) Limit_5_Yr, MAX(Limit_10_Yr) Limit_10_Yr, MAX(Limit_50_Yr) Limit_50_Yr,
        MAX(Standard_Usage_0_3_mo) Standard_Usage_0_3_mo, MAX(Standard_Usage_3_12_mo) Standard_Usage_3_12_mo,
        MAX(Standard_Usage_1_2_Yr) Standard_Usage_1_2_Yr, MAX(Standard_Usage_2_5_Yr) Standard_Usage_2_5_Yr,
        MAX(Standard_Usage_5_10_Yr) Standard_Usage_5_10_Yr, MAX(Standard_Usage_10_50_Yr) Standard_Usage_10_50_Yr
      FROM asts0 GROUP BY Line, business_date
    )
  )
),
breaches AS (
  SELECT line, business_date, scenario, time_bucket, bucket_order,
         TRY_CAST(REPLACE(usage_str,',','') AS DOUBLE) AS stressed_exposure,
         UPPER(TRIM(breach_str)) AS breach_flag, excess_pct
  FROM (
    SELECT Line AS line, business_date, Scenario_Name AS scenario,
      stack(6,
        '0-3 Mo',1,Max_Usage_0_3_mo,  `0_3_mo_Excess_Breach`,  `0_3_mo_Excess_Percentage`,
        '3-12 Mo',2,Max_Usage_3_12_mo, `3_12_mo_Excess_Breach`, `3_12_mo_Excess_Percentage`,
        '1-2 Yr',3,Max_Usage_1_2_Yr,  `1_2_Yr_Excess_Breach`,  `1_2_Yr_Excess_Percentage`,
        '2-5 Yr',4,Max_Usage_2_5_Yr,  `2_5_Yr_Excess_Breach`,  `2_5_Yr_Excess_Percentage`,
        '5-10 Yr',5,Max_Usage_5_10_Yr, `5_10_Yr_Excess_Breach`, `5_10_Yr_Excess_Percentage`,
        '10-50 Yr',6,Max_Usage_10_50_Yr,`10_50_Yr_Excess_Breach`,`10_50_Yr_Excess_Percentage`
      ) AS (time_bucket, bucket_order, usage_str, breach_str, excess_pct)
    FROM asts0
  )
)
SELECT * FROM (
  SELECT b.line, b.business_date,
         b.scenario    AS scenario_of_largest_breach,
         b.time_bucket AS bucket_of_largest_breach,
         b.stressed_exposure,
         r.limit_value   AS limit,
         r.current_value AS current_exposure,
         (b.stressed_exposure - r.limit_value) AS excess_amount,
         b.excess_pct,
         ROW_NUMBER() OVER (PARTITION BY b.line, b.business_date
                            ORDER BY (b.stressed_exposure - r.limit_value) DESC) AS rn
  FROM breaches b
  JOIN ref r        ON b.line=r.line  AND b.business_date=r.business_date AND b.bucket_order=r.bucket_order
  WHERE b.breach_flag = 'TRUE'
) WHERE rn = 1;
```
> Lines with **no breach** return no row (correct — nothing to show). Confirm the breach-flag string is literally `TRUE` for your data.

### 8.3 `breach_commentary` — write-back table (blueprint)

**Business need:** the analyst's narrative (#4–6: Primary/Secondary Risk Drivers, Products Driving Exposure, Notes) has **no source feed** — a human types it. Strategy's **SQL Transaction Forms** turn a dashboard grid into an editable form that writes back to this table; the breach grid then `LEFT JOIN`s it (1:1 by line+date, no fan-out) to display the commentary.

```sql
CREATE TABLE IF NOT EXISTS `d4001-centralus-tdvip-creditrisk`.`xvala_xva`.`breach_commentary` (
  line STRING, business_date STRING,
  primary_risk_driver STRING, secondary_risk_driver STRING,
  products_driving_exposure STRING, notes STRING,
  updated_by STRING, updated_at TIMESTAMP
) USING DELTA;
```
> Edits should be permission-scoped and audited (`updated_by`/`updated_at`) — breach commentary is sensitive. Confirm Transaction-Forms write-back is enabled for the Databricks SQL warehouse connection (a newer capability).

---

## 9. Parked Items

For the rebuild team and future iterations:

**Data quality (fix at source in `asts`):**
- 35 duplicate rows · `Long_Name` variants · null Limit on the `BASE` row · grain is line × scenario but not perfectly clean.

**Dashboard polish:**
- **Limit as a line** on the hero chart — needs a `limit_value` column + a derived Limit metric (combo chart), because shape is set *per metric* and Limit is currently a *series element*.
- **Color-lock** scenarios page-wide so they're one color everywhere (also enables the shared legend box).
- Validate the **scenario display-name dictionary** (§8.3) and finalize the standalone legend box layout.

**External / manual feeds (annotations):**
- **#1 Lending Manager** → IHMS (Rita's query).
- **#2 CSA Direction + CP/TD Thresholds** → `clients_report` (agreement block) and SCREAM `netting_xref.csv` / `client_info_nova.csv`; CSA is per **counterparty**, joined Line → Counterparty (the line name embeds the CP code, e.g. AMCQ).
- **#4–6 Risk Drivers / Products / Notes** → manual write-back via `breach_commentary` + Transaction Forms.
- **#7 "Number"** → a derived rank of breaches by stressed PFE (a portfolio/ranked-list view).

**Versioning:** the views and model can be exported to **YAML and stored in Git** (Strategy's March 2026 capability) so the whole stack is version-controlled and auditable.

---

## 10. Glossary

| Term | Meaning |
|---|---|
| **CCR** | Counterparty Credit Risk — risk a trading counterparty defaults while owing TD. |
| **PFE** | Potential Future Exposure — simulated high-percentile estimate of future exposure. |
| **Max Usage** | Peak PFE within a tenor bucket under a scenario; how much of the limit is consumed. |
| **Limit** | Max exposure TD will carry on a line, per tenor bucket; encodes credit appetite. |
| **Breach** | Max Usage over limit per the two-condition rule (excess % *and* rating buffer). |
| **Standard / Current Exposure** | PFE under normal (unstressed) market assumptions. |
| **Stressed Exposure** | PFE after re-simulating under a stress scenario. |
| **Gross Max Exposure** | Peak exposure before netting/collateral. |
| **Netting (ISDA)** | Offsetting positive and negative trade values into one net exposure. |
| **CSA** | Credit Support Annex — the collateral agreement. |
| **CP / TD Threshold** | How far one side's owing can grow before that side posts collateral. |
| **MTA** | Minimum Transfer Amount — collateral moves only in chunks ≥ MTA. |
| **Tenor / Time Bucket** | Maturity band (0–3 Mo … 10–50 Yr) over which exposure is measured. |
| **TD Sub** | Intragroup line (faces a TD entity); carved out of external breach reporting. |
| **OTC / SFT** | Over-the-counter derivatives vs Securities Financing Transactions. |
| **SCREAM** | The upstream Monte-Carlo engine where PFE is actually calculated. |
| **AST tables** | `asts` (detailed, line × scenario, wide buckets) and `ats_summary` (one row per line). |
| **Percentage of Impact** | Max of All ÷ Base — how many times worse stress is than the base case. |
| **Semantic model (Mosaic)** | The governed layer turning Databricks columns into business objects. |

---

*End of build notes. These are living notes — extend them as the parked items get implemented and as the scenario dictionary and CSA feeds are confirmed.*
