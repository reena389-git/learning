# Risk Data — Jira Intake Template Spec

*A simple intake form raised by Business users when a needed data product doesn't yet exist in the Risk Warehouse. Routes to the relevant PG owner. The full contract is authored later by Risk Data after the PG owner conversation.*

## Where this lives

- **Form**: Jira project (TBD — coordinate with engineering / Atlassian admin)
- **Routing**: Auto-routes to PG owner if Field 6 ("Known PG involved") is populated; otherwise routed to a Risk Data triage queue
- **SLA**: First response within 5 working days
- **Status flow**: `New → Triaged → In Conversation → Contract Drafting → Published → Closed`

## Form fields

| # | Field | Type | Required | Notes |
|---|-------|------|----------|-------|
| 1 | Requesting team / business unit | Short text | Yes | The team or function raising the request |
| 2 | Brief description | Long text (3–4 sentences) | Yes | What the requester needs and why |
| 3 | Target consumer | Short text or dropdown | Yes | One of: Dashboard · Report · Model input · Regulatory feed · Ad-hoc analysis · Other |
| 4 | Indicative urgency / target date | Date or short text | Yes | When the requester needs this |
| 5 | Known source(s) | Long text | No | Source applications or tables if the requester knows them — may be discovered during PG owner conversation |
| 6 | Known PG involved | Dropdown | No | Credit Risk · Market Risk · Liquidity · Funding · Unknown — auto-routes if populated |
| 7 | Business approver name | Short text | Yes | The person sponsoring this request |

## What happens after submission

1. Ticket lands in the relevant PG owner's queue
2. PG owner triages, may request clarification via Jira comments
3. PG owner conversations:
   - With App team(s) — if data comes from apps within the PG
   - With other PG owners — if cross-PG conformance needed
4. Risk Data authors the data contract (Excel design source → JSON/YAML in Risk Warehouse Git)
5. Contract publishes to Unity Catalog (as tags) and Collibra (business catalog)
6. Data product becomes discoverable in `riskwh`
7. Ticket closed with link to the published data product
8. Requester subscribes via Collibra; if building a dashboard, registers it in `risk_governance.consumer_registry`

## What this form is NOT

This is the **intake** form, not the **contract**. The 25 detailed attributes that define a data product (grain, aggregation rules, allowed/blocked dimensions, SLA, etc.) live in the data contract, which Risk Data authors after the PG-owner conversation. The requester does not need to know any of those details to raise this intake.

## Engineering notes

- The form schema is intentionally generic. Engineering can extend with PG-specific custom fields if a PG wants additional triage data, but the seven fields above should remain the standard core.
- Implementation can be a Jira Service Management form, a Jira issue type, or a Smart Form — engineering choice.
- The form's submission webhook can populate the project roster automatically (see *Governance & Cadence* — Project Roster).
