# Requirements Brief Template

Copy the structure below into `agent/work/specs/[Feature]/requirements.md`. Keep every requirement **system-agnostic** — outcomes, rules, and constraints, not a Dataverse design. The brief carries **wiki frontmatter only** (no `**Status**` work-status line — that lives on the architect's `spec.md`).

````markdown
---
title: "Requirements Brief — [Feature Name]"
type: spec
status: draft            # draft until signed off, then active
scope: project           # product | project | personal
client: [client-id]
project: [project-id]
topics: []
people: [author-slug]
processes: []            # BPC rollup — every mapped ProcessSequenceId + "proposal:<key>" entries, e.g. ["65.20.025.000", "proposal:loaner-equipment"]
catalogRelease: ""       # BPC release mapped against, e.g. "JUL 2026" (or the engagement export's version) — see bpc-process-mapping.md §2
sources: [../../wiki/digests/<source-digest>.md]   # the transcript/artifact digest(s) this is built from
supersedes:
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Requirements Brief — [Feature Name]

**Written By:** [Author Name]   ·   **Source(s):** [transcript/artifact/ADO item]

> System-agnostic requirements (WHAT/WHY). Translated into a Dataverse design by `hso-dataverse-architect`.

## Purpose
2–3 sentences: the business problem and the desired outcome. No solution mechanics.

## Business Value
- Quantified benefit / outcome
- User or operational impact

## Stakeholders
| Role | Name (people-page slug) | Interest | Authority (per this area: approver / expert / contributor / consultant / unknown) | Source of the assignment |
|---|---|---|---|---|

## Functional Requirements
Outcomes and business rules, solution-neutral. Each testable and uniquely identified, and each carrying a BPC process tag (map-or-propose — see [bpc-process-mapping.md](bpc-process-mapping.md) §3).
- **FR-1** — <capability/outcome the system must provide>
  - *Source:* `<originator-slug>` (<authority level>) — <digest § or transcript speaker + HH:MM:SS> — origin `stated` · confidence `high` (corroborated by <second artifact>)
  - *Process:* `<ProcessSequenceId>` <process name> — <L1 scenario> › <L2 area> — `mapped`
- **FR-2** — <business rule that must hold>
  - *Process:* proposal `<key>` — under `<parent id>` <parent name> — `proposed-custom`

## Non-Functional / Technical Requirements
System-agnostic quality + constraint requirements.
- **NFR-1 (Security/Access)** — <who may see/do what; isolation needs>
- **NFR-2 (Data)** — <retention, volume, quality, governance>
- **NFR-3 (Integration)** — <external systems, direction, frequency>
- **NFR-4 (Performance/Scale)** — <volumes, response expectations>
- **NFR-5 (Compliance/Operations)** — <regulatory, audit, go-live needs>

## Process Mapping (BPC)
Map-or-propose result for every FR ([bpc-process-mapping.md](bpc-process-mapping.md)). Catalog input used: <export path / Forge reference copy / standard-catalog clone / summary-only>. **Catalog release:** <e.g. JUL 2026 — must match frontmatter `catalogRelease`>. Fit-gap column only when the orchestration platform or a catalog export supplied verdicts — never authored here.

| FR | Process | Level path | Status | Fit-gap |
|----|---------|-----------|--------|---------|
| FR-1 | `65.20.025.000` Enter sales orders | 65 › 65.20 | mapped | — |
| FR-2 | proposal `loaner-equipment` | under 95 | proposed-custom | — |

### Custom-process proposals
<!-- Machine-readable; mirrors the orchestration platform PendingCatalogAddition. Omit the block when every FR maps. Proposals are sign-off items — batch-review with the client. Customs are NUMBERED at approval in the HSO namespace (ADR 0050 draft; shapes provisional, e.g. HSO100.INS.ACME.007): the key is the temporary handle while proposed; the minted ID is the permanent identity (names are labels, never identity). Never mint numeric-band ids. -->
```yaml
proposals:
  - key: <kebab-key>
    name: "<Verb–noun process name>"
    level: L3
    underProcessSequenceId: "<parent id>"
    underKey:
    rationale: "<why no standard process fits>"
    frIds: [FR-2]
    status: proposed
    assignedProcessId:
```

## Constraints
- <timeline, budget, environment, platform, or organizational constraint>

## Assumptions
- <assumption, with the source noted — incl. SOP-surfaced implications, e.g. "Licensing: assumes per-user Dynamics 365 licenses (per licensing SOP)">

## AI delivery disposition
<!-- Optional — include only when the engagement runs AI-leverage review (ADR 0035). Populated from hso-ai-leverage-review (design mode). Delivery-method annotation, NOT solution design. -->
| Requirement | Disposition | Human checkpoint | AI-feasibility |
|---|---|---|---|
| FR-1 | agent-built | consultant approves flagged exceptions before commit | High |
| FR-2 | human-only | — | Low |

## Acceptance (requirement-level)
Solution-neutral, testable conditions for sign-off — NOT build acceptance (the architect derives per-slice build acceptance from these). For any `agent-built` requirement, encode the human-on-the-loop checkpoint so it is testable:
- [ ] <observable outcome that proves a requirement is met>
- [ ] *(agent-built pattern)* GIVEN the agent produces <output>, WHEN a <role> reviews <the exception/queue>, THEN <quality threshold> AND no <record/change> takes effect without explicit human approval.

## Out of Scope
- <explicitly excluded items>

## Open Questions
- <unresolved item needing client/stakeholder input>

## SOP-Surfaced Implications
Requirement-level concerns surfaced from HSO SOPs (licensing, security, data, integration, environment, operations), each pointing at its source. These are requirements/assumptions, not design.
- <implication> — source: [<sop>](../../wiki/sop/<path>.md)

## ADO Tracking
- **Tracked in Azure DevOps:** Yes / No — or **Tracked in the orchestration platform** — consultant review pending; ADO ids assigned by the orchestration platform publish pass (orchestrated-mode, `publish_requirements` — see SKILL.md § Publishing to the orchestration platform)
- **Format profile:** stock (User Story + AC field) / **new-format** (`Requirement` + Test Case children) — read from the engagement's conventions ledger, never assumed (ADR 0049); "n/a" in orchestrated-mode (no profile is resolved)
- **Feature:** #id — title (or "n/a"; on new-format projects Epic/Feature are disabled — grouping comes from the BPC process nodes). In orchestrated-mode: the orchestration platform Feature work-item id returned by `publish_requirements`.
- **Work-item map** (created via `hso-ado-work-items`; in orchestrated-mode, from the `publish_requirements` payload) — one row per FR. Downstream consumers resolve FR → work item through this table: triage parents Bugs by it, and the delivery pipeline emits its attribution claims from it (slice `fr_refs` → FR → work item). Each work item carries its BPC tag (`BPC:<ProcessSequenceId>`, `BPC:proposed:<key>`, or `BPC:unmapped`) and, when the catalog hierarchy exists as work items, a parent link to its process node ([bpc-process-mapping.md](bpc-process-mapping.md) §6). On new-format projects: a rule-FR folded into a capability's acceptance criteria records `AC of #id` instead of its own item (no FR silently disappears), and the Test-cases column lists the Test Case children created from the FR's acceptance (`—` on stock projects). In orchestrated-mode the Work item column carries the orchestration platform work-item id per FR (Test cases `—`). Write "n/a" if not tracked.

| FR | Work item | Test cases | BPC tag |
|----|-----------|------------|---------|
| FR-1 | #id — title | #id, #id | `BPC:65.20.025.000` |
| FR-2 | AC of #id (rule-FR fold) | — | `BPC:proposed:loaner-equipment` |

## Handoff
Next: `hso-dataverse-architect` consumes this brief → produces `spec.md` (data model, technical architecture, slice DAG) citing this file.

## Sources, References, and Research Methodology
- [<digest or capture>](../../wiki/digests/<source>.md) — what it contributed
````
