# The Decision Spine

**This file is the authority for spine *routing* on a Solution Map** — which SOP governs each area,
the sections to read, the skill that owns depth, the questions each area must answer, and the traps.
The spine as a **standard** — the fifteen-area list, the disposition rule, and the
readiness-to-estimate gate — is owned by the
[Presales Playbook](../../../../agent/wiki/sop/presales/presales-playbook.md) §4 (Stage 3 — Shape);
this file must agree with it, and where it does not, the playbook wins. `SKILL.md` carries a
fifteen-row digest of both. Read this file before charting a map and before resolving any ticket.

The SOPs named below are themselves the authority for their subject matter — this file routes, it
does not restate. Where this file and a SOP disagree, the SOP wins.

---

## Why a spine at all

Matt Pocock's `wayfinder` lets fog be freeform: chart what you can see, leave the rest dim. That is
right for an open-ended engineering effort, and wrong for a Dataverse engagement heading for a
Statement of Work. The recurring failure is not a map that stopped too early — it is a map that never
asked. A solution map that never raised licensing produces a shape whose licence consequence is
discovered at true-up. One that never raised migration produces a SOW with a single underscoped
"data" line. One that never raised the security shape produces a phase-2 rebuild when the client
turns out to need record-level isolation across regions.

So the fog is bounded by a standing checklist. Fifteen areas, each dispositioned explicitly. Fog is
still allowed — an area may honestly be too dim to ticket — but it must be *named as fog*, which is
what makes it visible instead of absent.

## Disposition rules

Restated from the playbook §4.1 for use at the ticket face — the playbook is authoritative. Every
area carries exactly one disposition on the map:

| Disposition | Meaning | Required alongside |
|---|---|---|
| `resolved` | A closed ticket answered it | Link to the ticket |
| `ticketed` | An open ticket owns it | Link to the ticket |
| `fog` | In scope, not yet sharp enough to ticket | A line in **Not yet specified** |
| `out-of-scope` | Beyond this map's destination | A line in **Out of scope** with the reason |
| `n/a` | Genuinely does not apply to this engagement | A one-line reason |

**`n/a` is a claim that must survive challenge.** "No integrations" on a system that replaces an
incumbent is almost always wrong — the incumbent's data has to come from somewhere. "No analytics"
usually means "nobody asked yet", which is `fog`, not `n/a`. When you write `n/a`, write why.

**A map cannot be closed with any area at `fog`.** Close mode refuses it. Either it graduates to a
ticket and gets resolved, or it is ruled `out-of-scope` with a reason — which is a scoping decision
someone owns, and belongs in the SOW's exclusions.

---

## The fifteen areas

### 1. Business capability & process footprint

*What business processes does this solution carry, end to end?*

| | |
|---|---|
| **Authority** | The matching [`crm-processes/`](../../../../agent/wiki/sop/crm-processes/) peer — [customer-management](../../../../agent/wiki/sop/crm-processes/customer-management-best-practices.md), [lead-management](../../../../agent/wiki/sop/crm-processes/lead-management-best-practices.md), [opportunity-management](../../../../agent/wiki/sop/crm-processes/opportunity-management-best-practices.md), [quote-to-cash](../../../../agent/wiki/sop/crm-processes/quote-to-cash-best-practices.md), [case-management](../../../../agent/wiki/sop/crm-processes/case-management-best-practices.md), [sales-forecasting](../../../../agent/wiki/sop/crm-processes/sales-forecasting-best-practices.md) — **read before deciding a process is custom.** |
| **Also** | BPC alignment per [ADR 0047](../../../../agent/wiki/decisions/0047-bpc-aligned-portable-requirements.md). The map does not do the map-or-propose pass (that is `hso-requirements-author`'s), but it decides which **process areas** are in play, which is what makes that pass tractable. |
| **Decides** | The capability workstreams the SOW prices. |
| **Trap** | Naming a process custom because the client's *vocabulary* is unfamiliar. Read the OOB process SOP before concluding the platform has no answer. |

### 2. Product & module footprint

*Which Microsoft products, apps, and modules are in play?*

| | |
|---|---|
| **Authority** | [`presales/solution-scope-contribution.md`](../../../../agent/wiki/sop/presales/solution-scope-contribution.md) — **read before writing any scope row.** It owns the status ladder (`candidate → recommended → confirmed`), the upsert rule, and the per-skill contribution points. |
| **Surface** | `agent/wiki/system/solution-scope.md` (delivery repo) or the **Solution Scope** table in `PROJECT_CONTEXT.md` (consulting workspace) — [ADR 0030](../../../../agent/wiki/decisions/0030-per-project-solution-scope-definition.md) / [ADR 0031](../../../../agent/wiki/decisions/0031-solution-scope-lifecycle-in-consulting-workspaces.md). |
| **Decides** | Which first-party SOP families are even eligible downstream — this is the area `hso-dataverse-architect` reads as a hard prerequisite. |
| **Obligation** | Every resolution that moves the footprint **upserts the scope row**. The map is a contribution point, not a private notebook. |
| **Trap** | Deciding Project Operations is in scope without deciding the **deployment type** — the load-bearing kickoff choice. |

### 3. Fit-gap: OOB vs custom

*Does the platform already do this?*

| | |
|---|---|
| **Authority** | [`model-driven-apps/data-modeling-best-practices.md`](../../../../agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md) — **read before concluding a concept has no OOB or CDM home.** |
| **Principle** | [P1 — semantic modeling first; OOB and CDM before custom; extend, never replace](../../../../agent/wiki/sop/dataverse-implementation-architecture-principles.md). The burden of proof is on *custom*, not on OOB. |
| **Skill** | `hso-semantic-data-modeling` is the **research gate** — it runs before any new-table decision. `hso-ce-apps-sdk-reference` for first-party app capability; reusable IP / accelerators (see area 15). |
| **Decides** | The single biggest SOW cost driver on a re-platforming. |
| **Trap** | A one-to-one port of the incumbent's schema. The incumbent's model encodes the incumbent's constraints; re-deciding each concept against CDM is the whole point of this area. |

### 4. Conceptual data model & core entities

*What are the six-to-eight nouns, and how do they relate?*

| | |
|---|---|
| **Authority** | As area 3 — [`data-modeling-best-practices.md`](../../../../agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md), plus [P2 (first-time-right schema)](../../../../agent/wiki/sop/dataverse-implementation-architecture-principles.md) for the choices that are expensive to reverse: ownership type, primary name, relationship cardinality, table-vs-choice for coded values. |
| **Artifact** | A **conceptual** ERD via `hso-diagram-excalidraw` (its conceptual-ERD mode is built for exactly this: 6–8 entities, one screen, client-facing). |
| **Decides** | The aggregate roots and the ownership boundaries — enough for requirements, not enough to build. |
| **Boundary** | Conceptual only. No column lists, no logical names, no suffixes. The moment you are typing `_yn` you have left the map. |

### 5. Personas, security & access shape

*Who uses it, and what may each of them see?*

| | |
|---|---|
| **Authority** | [`security/security-best-practices.md`](../../../../agent/wiki/sop/security/security-best-practices.md) — **read before deciding the access shape.** Business-unit strategy, ownership model, sharing, field-level security, and the performance consequences of each. |
| **Principle** | [P12 — least privilege everywhere](../../../../agent/wiki/sop/dataverse-implementation-architecture-principles.md). |
| **Decides** | The persona inventory (which also seeds area 6), the ownership model, and whether record-level isolation is required — a decision that is structural, not a late configuration. |
| **Trap** | Deferring the BU/ownership decision to build. It changes the data model and it changes the licence. |

### 6. Licensing & cost baseline

*What does this shape cost, per persona, per year?*

| | |
|---|---|
| **Authority** | [`licensing/d365-and-power-platform-licensing-best-practices.md`](../../../../agent/wiki/sop/licensing/d365-and-power-platform-licensing-best-practices.md) — **read before quoting or assuming any SKU.** |
| **Also** | [`presales/presales-playbook.md`](../../../../agent/wiki/sop/presales/presales-playbook.md) §6 — the **five cost traps** every quote is checked against: seeded-app → Dataverse flip, symmetric CE+F&O licensing, Team Members over-scope, F&O role duty inheritance, unmetered AI. |
| **Skill** | `hso-d365-licensing` owns depth. This skill never invents a licensing assumption. |
| **Surface** | `agent/wiki/system/licensing-baseline.md`. Missing ⇒ a `task` ticket, not a guess. |
| **Trap** | Every one of the five above. The seeded-app flip in particular is a single custom table away from repricing the deal. |

### 7. Integration landscape

*What else must this talk to, in which direction, at what latency?*

| | |
|---|---|
| **Authority** | The matching family — [`azure-integration/`](../../../../agent/wiki/sop/azure-integration/azure-integration-best-practices.md) (Service Bus, Functions, Logic Apps, SPN), [`dv-fo-integration/`](../../../../agent/wiki/sop/dv-fo-integration/dv-fo-integration-best-practices.md), [`m365-integration/`](../../../../agent/wiki/sop/m365-integration/m365-integration-best-practices.md), [`virtual-tables/`](../../../../agent/wiki/sop/virtual-tables/virtual-tables-best-practices.md), [`dual-write/`](../../../../agent/wiki/sop/dual-write/dual-write-best-practices.md) — **read the one that matches before deciding a pattern.** |
| **Principle** | [P13 — asynchronous, event-driven integration; messages are notifications, not payloads](../../../../agent/wiki/sop/dataverse-implementation-architecture-principles.md). |
| **Decides** | The integration count — one of the four inputs the presales playbook says every quote depends on — and the topology tier count that follows from it. |
| **Trap** | Counting integrations by *system* rather than by *interface*. Three interfaces to one ERP is three integrations' worth of work. |

### 8. Data migration, configuration data & MDM

*What data comes across, from where, at what fidelity?*

| | |
|---|---|
| **Authority** | [`data-migration/migration-strategy-and-tooling-best-practices.md`](../../../../agent/wiki/sop/data-migration/migration-strategy-and-tooling-best-practices.md) (tooling threshold, reconciliation, mock cutovers), [`configuration-data/configuration-data-strategy.md`](../../../../agent/wiki/sop/configuration-data/configuration-data-strategy.md) §1 (the config / migration / sample taxonomy), [`master-data-management/master-data-management-best-practices.md`](../../../../agent/wiki/sop/master-data-management/master-data-management-best-practices.md) — **read before sizing a migration line.** |
| **Principle** | [P15 — governed data lifecycle; stewardship before tooling, migration with reconciliation](../../../../agent/wiki/sop/dataverse-implementation-architecture-principles.md). |
| **Decides** | The migration workstream, and — separately — who owns master data after go-live. |
| **Trap** | Conflating the three workstreams the taxonomy separates. **Configuration data is not migration data**: reference/code lists belong to the feature whose entry behavior consumes them, and a migration line that swallows them leaves the core capability with no configuration requirement at all. |

### 9. Reporting & analytics

*What does the business need to see, and where does it come from?*

| | |
|---|---|
| **Authority** | [`analytics-integration/power-bi-on-dataverse-best-practices.md`](../../../../agent/wiki/sop/analytics-integration/power-bi-on-dataverse-best-practices.md) (its §1 opening question — *does the customer use record-level security?* — is the decision this area turns on), [`synapse-fabric-link-best-practices.md`](../../../../agent/wiki/sop/analytics-integration/synapse-fabric-link-best-practices.md), [`tds-endpoint-best-practices.md`](../../../../agent/wiki/sop/analytics-integration/tds-endpoint-best-practices.md) — **read before deciding in-platform vs external analytics.** |
| **Decides** | In-app dashboards vs embedded Power BI vs a lake — a capacity and licence decision, not a late nice-to-have. |
| **Trap** | `n/a` because nobody asked. Reporting is the most reliably under-elicited area in discovery. |

### 10. Extensibility posture (the technology ladder)

*How much custom code will this solution carry, and of what kind?*

| | |
|---|---|
| **Authority** | [`dataverse-implementation-architecture-principles.md`](../../../../agent/wiki/sop/dataverse-implementation-architecture-principles.md) **P7 — the technology-selection ladder: the lowest code that solves the problem** — plus P3 (platform-native over parallel constructs), P5 (layered server-side), P6 (Custom API as the contract surface), P9 (supported extensibility only). **Read P3, P5–P9 before setting the posture.** |
| **Also** | [`hso-dataverse-architect/references/technology-decisions.md`](../../hso-dataverse-architect/references/technology-decisions.md) — the concrete decision matrix (web resource vs PCF, plugin vs flow). Used here at the *posture* level only. |
| **Decides** | The build-effort profile the estimate rests on, and the skill mix the SOW staffs. |
| **Boundary** | Posture, not selection. "This solution is configuration-first with two plugin-bearing capabilities" is a map decision; "this button calls a Custom API named X" is the architect's. |

### 11. Environment strategy, topology & ALM

*How many environments, and how does code get between them?*

| | |
|---|---|
| **Authority** | [`environment-strategy/environment-strategy-best-practices.md`](../../../../agent/wiki/sop/environment-strategy/environment-strategy-best-practices.md) §1.2 (the size → tier-count mapping) and §4 (capacity), [`dataverse-solutions/dataverse-solutions-best-practices.md`](../../../../agent/wiki/sop/dataverse-solutions/dataverse-solutions-best-practices.md) + [`solution-segmentation-best-practices.md`](../../../../agent/wiki/sop/dataverse-solutions/solution-segmentation-best-practices.md), [`alm-best-practices/alm-best-practices.md`](../../../../agent/wiki/sop/alm-best-practices/alm-best-practices.md) — **read §1.2 before assuming a tier count.** |
| **Principle** | [P11 — environment strategy and governance from day one](../../../../agent/wiki/sop/dataverse-implementation-architecture-principles.md); P16 (solution segmentation and layering). |
| **Decides** | Tier count → capacity cost → ALM effort. All three are estimate lines. |
| **Trap** | **Region is irreversible at provision.** Data-residency constraints surfaced in discovery lock it; discovering the constraint after provisioning means a rebuild. |

### 12. AI / Copilot leverage

*Where does AI belong in the product, and where in the delivery?*

| | |
|---|---|
| **Authority** | [`copilot/copilot-in-d365-best-practices.md`](../../../../agent/wiki/sop/copilot/copilot-in-d365-best-practices.md) §7 (licensing, capacity, Copilot Credits) and [`copilot/copilot-studio-best-practices.md`](../../../../agent/wiki/sop/copilot/copilot-studio-best-practices.md) §11 — **read before putting AI in scope.** |
| **Skill** | `hso-ai-leverage-review` per [ADR 0035](../../../../agent/wiki/decisions/0035-ai-leverage-review-and-spec-time-disposition.md) — it covers both product AI and the AI-delivery disposition the requirements brief later carries. |
| **Decides** | Whether AI is a product capability, a delivery method, both, or neither — and the credit budget if either. |
| **Trap** | Unmetered agents. Credits are consumed without user-visible activity; a cap and a budget line belong in the quote. |

### 13. Non-functional: performance, volume, availability

*How much data, how many users, how fast?*

| | |
|---|---|
| **Authority** | [`platform-performance/platform-performance-best-practices.md`](../../../../agent/wiki/sop/platform-performance/platform-performance-best-practices.md) §3.1 — the HSO performance targets. **Read before writing any number into a proposal.** |
| **Rule** | A performance commitment made in a proposal is *tested* at the pre-go-live review. Quote the SOP's targets; never invent a per-deal number. |
| **Decides** | Volume assumptions that drive the data model and the migration tooling threshold. |
| **Trap** | Record volumes taken from the incumbent's row counts without asking how much of it is retained. |

### 14. Delivery shape: phasing, testing, go-live

*How is this delivered, and what does "done" look like?*

| | |
|---|---|
| **Authority** | [`presales/presales-playbook.md`](../../../../agent/wiki/sop/presales/presales-playbook.md) §§5–7 — the estimate anchors, the pre-quote checklist, and the Stage-6 handoff package. [`go-live-and-operate/go-live-and-operate-best-practices.md`](../../../../agent/wiki/sop/go-live-and-operate/go-live-and-operate-best-practices.md) §1.3 (cutover plan, rehearsals, hypercare by engagement size) and [`testing/testing-best-practices.md`](../../../../agent/wiki/sop/testing/testing-best-practices.md). **Read §1.3 before quoting a go-live.** |
| **Decides** | Phase boundaries, the cutover approach, hypercare duration — all SOW lines. |
| **Boundary** | Phases here are **delivery phases** for the SOW, not a build plan. The build's decomposition is the architect's vertical slice DAG ([ADR 0018](../../../../agent/wiki/decisions/0018-agentic-delivery-architect-builder-pipeline.md)); never emit a horizontal "Phase 1: all tables" plan. |
| **Trap** | Hypercare defaulting in as an afterthought. It is staffed and quoted at presales. |

### 15. HSO IP & accelerator fit

*Does HSO already own part of this?*

| | |
|---|---|
| **Authority** | The reusable IP / accelerator catalog for your delivery organisation, plus the matching industry accelerator in play — **read the relevant accelerator before scoping a capability as custom.** |
| **Skill** | `hso-presales-rfp-architect` where the engagement is still an opportunity. |
| **Decides** | The IP-vs-custom split — a margin decision as much as an architecture one. |
| **Trap** | Scoping custom build for a capability an accelerator already ships. This area exists to make that check non-optional. |

---

## Citation format

Every resolution cites the SOP sections actually read, per area:

```markdown
**Standards grounding:**
- `security-best-practices.md` §§4, 11, 16 — business-unit strategy and the POA performance consequence
- `d365-and-power-platform-licensing-best-practices.md` §6 — asymmetric CE/F&O design
```

`Get-SolutionMapFrontier.ps1` reports a closed ticket whose `spine` areas carry no citation as an
error. The check is mechanical because the observed failure mode is that SOPs get read when the
prompt happens to name the technology, never because a routing table said to — the same failure
`hso-dataverse-architect` addresses with its Sources-section check.
