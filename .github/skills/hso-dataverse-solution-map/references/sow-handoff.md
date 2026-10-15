# Solution Map Summary → Statement of Work

**This file is the authority for the Solution Map Summary's contents and its mapping onto SOW
sections.** Read it before writing the summary in Close mode.

The summary is the map's destination artifact. It is written **once**, into `map.md`, when every
ticket is closed and no spine area remains at `fog`. It is not a new document — putting it in `map.md`
keeps the synthesis one click from the decisions that produced it.

> **Authority for the presales arc the summary feeds — read
> [`presales/presales-playbook.md`](../../../../agent/wiki/sop/presales/presales-playbook.md) §§4–7
> before writing.** §4.2 is the readiness-to-estimate gate this summary is the fifth condition of;
> §5 holds the estimate anchors (topology, cutover/hypercare, migration) the summary must supply and
> names the summary as the estimate's input; §6 holds the pre-quote checklist and the five cost
> traps; §7 holds the Stage-6 handoff package the closed map becomes part of.

---

## Preconditions (Close mode refuses without them)

- Zero open or claimed tickets.
- Zero spine areas dispositioned `fog`. Every one is `resolved`, `ticketed`-and-now-closed,
  `out-of-scope` with a reason, or `n/a` with a reason.
- Zero closed tickets whose `spine` areas carry no SOP citation.
- The licensing baseline exists and reflects the shape the map landed on.

`Get-SolutionMapFrontier.ps1` reports all four. **Do not synthesize over a gap** — a summary written
across an area still at `fog` reads as complete and is not, which is the most expensive failure this
skill has.

---

## Required sections

Every section derives from closed tickets. Where a section has no ticket behind it, say so — an
honest "not assessed" beats an invented paragraph.

| # | Section | Contents | Derived from |
|---|---|---|---|
| 1 | **Solution shape** | One paragraph a non-technical stakeholder can read: what is being built, for whom, replacing what. | Destination + areas 1, 3 |
| 2 | **Product & module footprint** | The confirmed Microsoft products, apps, and modules, with the deployment type where one applies. | Area 2 (mirrors `solution-scope.md`) |
| 3 | **Capability workstreams** | The business capabilities the solution carries, as named workstreams. These become SOW scope lines. | Areas 1, 15 |
| 4 | **Platform fit — OOB, IP, and custom** | Per capability: delivered by OOB/first-party, by HSO IP, or by custom build — with the fit-gap verdict behind each. The single biggest driver of the number. | Areas 3, 15 |
| 5 | **Conceptual data model** | The core entities and their relationships, at conceptual fidelity, linking the ERD asset. | Area 4 |
| 6 | **Personas & access shape** | Persona inventory with headcounts, the ownership model, and whether record-level isolation is required. | Area 5 |
| 7 | **Integration surface** | One row per **interface** (not per system): direction, pattern, latency class, owning party. | Area 7 |
| 8 | **Data migration & master data** | What comes across, from where, at what fidelity; the config / migration / sample split; post-go-live master-data ownership. | Area 8 |
| 9 | **Reporting & analytics** | In-app vs embedded vs lake, and the RLS consequence. | Area 9 |
| 10 | **Extensibility posture** | How much custom code, of what kind, and the ladder rationale. Drives the staffing mix. | Area 10 |
| 11 | **Environments, topology & ALM** | Tier count with the size-mapping rationale, region (and any residency constraint), the ALM approach. | Area 11 |
| 12 | **AI scope** | Product AI, delivery-side AI leverage, or neither — with the credit budget where either applies. | Area 12 |
| 13 | **Non-functional targets** | Volumes, concurrency, and the performance targets **quoted from the SOP**, never invented. | Area 13 |
| 14 | **Delivery shape & phasing** | Delivery phases with boundaries, cutover approach, rehearsal count, hypercare duration. | Area 14 |
| 15 | **Assumptions** | Every assumption from every resolution, consolidated. Each falsifiable, each owned. | All |
| 16 | **Dependencies** | What HSO needs from the client and by when. | All, especially `task` tickets |
| 17 | **Risks** | What could move the number, with the decision that would settle each. | All |
| 18 | **Exclusions** | **Verbatim from the map's Out of scope section.** | Out of scope |

---

## Section → SOW mapping

The SOW is authored separately — this skill does not write it. The mapping below tells the SOW author
which summary section feeds which SOW section, so nothing is re-derived (and re-derived differently).

| SOW section | Fed by summary section(s) |
|---|---|
| Background / Objectives | 1 |
| Scope of Services | 3, 4 |
| Solution Overview | 1, 2, 5 |
| Technical Approach | 4, 7, 10, 11 |
| Data Migration | 8 |
| Reporting | 9 |
| Project Approach & Phasing | 14 |
| Deliverables | 3, 14 |
| Client Responsibilities | 16 |
| Assumptions | 15 |
| Out of Scope / Exclusions | 18 |
| Risks | 17 |
| Licensing (or licence-assumption note) | 2, 6, 12 — plus the licensing baseline itself |

**The SOW never restates a decision the map already holds.** It states the commitment; the map holds
the reasoning. When a client challenges a scope line, the answer is the ticket.

---

## Handoff obligations

Close mode does not end at the summary. Four things must happen, in this order:

1. **Upsert the scope surfaces.** Every confirmed product/module row into
   `agent/wiki/system/solution-scope.md` (or `PROJECT_CONTEXT.md`) per
   [`solution-scope-contribution.md`](../../../../agent/wiki/sop/presales/solution-scope-contribution.md).
   `hso-dataverse-architect` reads that file as a hard prerequisite — an unupserted decision is a
   decision the architect will not see.
2. **Re-verify the licensing baseline** against the shape the map landed on. If the shape moved after
   the baseline was set, the baseline is stale and the quote is wrong. Route to `hso-d365-licensing`.
3. **Seed the architecture map.** Hand sections 1 and 2 to
   [`hso-architecture-map`](../../hso-architecture-map/SKILL.md) SOP-1 as the `.topo` map's §1 *Solution
   Intent* and §2 *Platform Profile*. That skill owns the write; this one never touches `.topo`.
4. **Name both next steps** to the user:
   - [`hso-requirements-author`](../../hso-requirements-author/SKILL.md) — the Requirements Brief (the
     WHAT/WHY), which consumes this summary and the closed tickets as sources.
   - The SOW itself, built from the summary via
     [`hso-engagement-deliverables`](../../hso-engagement-deliverables/SKILL.md) on the HSO template,
     per [`client-deliverables/hso-client-deliverable-standards.md`](../../../../agent/wiki/sop/client-deliverables/hso-client-deliverable-standards.md).

Then set `map_status: closed` and add the log fragment. The map stays in the repo — it is the
provenance trail for every number in the SOW, and the first thing to re-open when scope moves.
