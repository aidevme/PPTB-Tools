---
name: hso-dataverse-solution-map
layer: orchestration
scope: core
description: Chart a fog-bound engagement as a Solution Map — a file-based board of decision tickets under agent/work/design/solution-map/ — worked one per session until the Dataverse solution's shape is clear enough to write requirements and a Statement of Work. Use when discovery is ingested but the shape is not decidable in one sitting. Runs BEFORE hso-requirements-author and hso-dataverse-architect; decides shape, never design.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Skill, AskUserQuestion
argument-hint: "[chart|work|close] [effort-slug] [ticket-id]"
---

# Dataverse Solution Map

A loose engagement has arrived — a pile of digests, transcripts, screenshots, and a client who wants
a number. It is too big for one agent session and wrapped in fog: the way from *here* to a signable
**Statement of Work** is not visible yet. This skill charts that way as a **Solution Map** — a
file-based board of **decision tickets** — and works them one at a time until the solution's shape is
clear.

Adapted from Matt Pocock's `wayfinder`. The HSO version replaces the issue tracker with markdown
tickets in the project wiki, replaces freeform fog with an **SOP-anchored decision spine**, and ends
at a named destination — a Solution Map summary that `hso-requirements-author` and the SOW author
both consume.

## Where this sits

`ingest → ` **`solution map (this skill)`** ` → requirements (hso-requirements-author) → design + slice DAG (hso-dataverse-architect) → build → review → PR`

This skill is **upstream of requirements**. It answers *what solution are we even building, on what
platform footprint, with which boundaries* — the questions that make a requirements brief writable.
Per [ADR 0022](../../../agent/wiki/decisions/0022-review-findings-drive-build-remediation-loop.md)
the brief is step 2; this is step 1.5, and it exists because on a re-platforming or a fog-bound
greenfield, step 2 is not yet answerable.

In the presales arc it **is Stage 3 — Shape** of the
[Presales Playbook](../../../agent/wiki/sop/presales/presales-playbook.md) (§4): the stage between
Discover and Estimate whose exit is the **readiness-to-estimate gate**. The playbook owns that
standard — the fifteen decision areas, the disposition rule, and the five gate conditions. This skill
is how the stage is executed. Where the two disagree, the playbook wins and this skill is fixed.

## When to use this skill

- Discovery is ingested (`agent/wiki/digests/` populated) but nobody can yet state the solution in a
  paragraph.
- The engagement **re-platforms or replaces** an incumbent system and the target shape is open.
- A Statement of Work is due and the scope boundary, the OOB-vs-custom split, the integration
  surface, or the phasing is undecided.
- The user says: "we need a solution map", "what are we actually building", "chart this out",
  "work the next decision", "turn the map into a SOW".
- More than one session's worth of open decisions exist, and you keep re-deriving the same context.
- The Presales Playbook says you are at **Stage 3 — Shape**: discovery is ingested and someone wants
  an estimate. Run the spine sweep even if you expect no fog — the dispositioned spine is the gate
  record the estimate is allowed to stand on.

`context: fork` is deliberately **not** set: charting and working tickets are interview-style and the
human must see the exchange inline.

## When NOT to use this skill

| Situation | Use instead |
|---|---|
| The component topology of a solution **being built** — `[DE]`/`[SL]`/`[API]` blocks and dependency edges | [`hso-architecture-map`](../hso-architecture-map/SKILL.md) — the TOPO `architecture-map.topo`. That is the **architecture map** (current state of built components); this is the **solution map** (open decisions, pre-build). This skill *seeds* TOPO's §1 Solution Intent and §2 Platform Profile at handoff; it never edits `.topo`. |
| The shape is known; you need the WHAT/WHY written down | [`hso-requirements-author`](../hso-requirements-author/SKILL.md) |
| The requirements are known; you need tables, forms, and a slice DAG | [`hso-dataverse-architect`](../hso-dataverse-architect/SKILL.md) |
| One design is on the table and needs stress-testing in a single sitting | [`hso-grill-architect`](../hso-grill-architect/SKILL.md) — this skill *invokes* it per grilling ticket |
| Responding to an RFP or picking HSO IP for an opportunity | [`hso-presales-rfp-architect`](../hso-presales-rfp-architect/SKILL.md) |
| Assessing an **existing live** Dataverse org | [`hso-analyze-system-review`](../hso-analyze-system-review/SKILL.md) — its output is a *source* for this map |
| The whole journey fits in one session | Just do it. A map with two tickets is overhead, not wayfinding. |

## Configuration

Read from `CLAUDE.md`: **Publisher prefix** · **Default solution** · **Environment URL** (may be TBD pre-sale)
Read from `CLAUDE.local.md`: **Author Name** — the ticket claimant and decision attributee.

If the Author Name is missing, ask. Never attribute a decision to Claude.

## Decide shape, don't design

This skill produces **decisions**, not deliverables. Each ticket resolves one question; the map is
done when nothing is left to decide before someone can write requirements. The pull to start
designing tables is the signal you have reached the edge of the map — hand off.

A resolution may name **that** a capability is custom rather than OOB, **that** a relationship is the
aggregate root, **that** integration is event-driven rather than batch. It may **not** declare a
table with eleven columns. Schema, forms, views, and the slice DAG belong to
`hso-dataverse-architect`, and producing them here strands them outside the spec pipeline where
`Validate-SpecJson.ps1` and the conformance review can see them. A map may override this in its
`## Notes`; absent that, decide shape.

## Refer by name

Every ticket has a title, and the title is a question. In everything the human reads — narration, the
map's Decisions-so-far, ticket cross-references — refer to a ticket **by its title**, never by a bare
`T-007`. A wall of ids is illegible; titles read at a glance. The id does not vanish — it wires
`blocked_by` edges and rides inside the link — but it never stands in for the name.

---

## Where the map lives

There is no ticketing system. The board is the filesystem, under the project's `work/` tier
(planning artifacts, not durable knowledge — `agent/schema.md`, "Wiki vs work"):

```
agent/work/design/solution-map/<effort-slug>/
├── map.md                     # the canonical artifact, loaded once per session
├── tickets/                   # T-001-<slug>.md, T-002-<slug>.md, …
└── assets/                    # prototypes, sketches, extracts produced while resolving
```

One folder per **effort**. Most engagements have exactly one; a second is warranted only when the
destination is genuinely different (a separate workstream with its own SOW).

**The map is an index, not a store.** It gists each closed decision in one line and links the ticket
that holds the detail. A decision lives in exactly one place — its ticket. The map never restates it.

**The map never lists open tickets.** Open tickets are found by query, not by a hand-maintained list
that drifts:

```powershell
# The frontier: open, unblocked, unclaimed tickets — what is takeable right now
& claude-code/skills/hso-dataverse-solution-map/scripts/Get-SolutionMapFrontier.ps1 `
    -MapPath agent/work/design/solution-map/<effort-slug>
```

The script is the authority on ticket state, not your reading of the folder — it resolves
`blocked_by` transitively, flags cycles, flags resolutions missing SOP citations, and reports
spine-area coverage. Run it at the start of every session (P19 — determinism over model judgment).

### The map body

Structure and worked example: [templates/map.md.template](templates/map.md.template).

```markdown
## Destination
<what reaching the end of this map looks like — the solution shape a SOW can be written from.
 One or two lines; every session orients to it before choosing a ticket.>

## Notes
<engagement domain; incumbent system; skills every session should consult; standing preferences>

## Decision spine
<the SOP-anchored checklist, each area dispositioned: resolved | ticketed | fog | out-of-scope | n/a>

## Decisions so far
- [<closed ticket title>](tickets/T-00n-<slug>.md) — <one-line gist of the answer>

## Not yet specified
<in-scope fog you cannot ticket yet; graduates as the frontier advances>

## Out of scope
<work ruled beyond the destination; closed, never graduates>

## Solution Map Summary
<written in Close mode only — the SOW-shaped synthesis>
```

### Tickets

Each ticket is one markdown file, sized to **one agent session**. Frontmatter carries what a tracker
would carry; the body is the question. Contract and worked example:
[templates/ticket.md.template](templates/ticket.md.template).

| Field | Values | Notes |
|---|---|---|
| `ticket_id` | `T-001`… | Allocated by the map, zero-padded, never reused |
| `ticket_type` | `research` `grilling` `prototype` `fit-gap` `task` | See [Ticket types](#ticket-types) |
| `mode` | `AFK` `HITL` | HITL resolves only through live exchange with a human |
| `ticket_state` | `open` `claimed` `closed` `out-of-scope` | |
| `claimed_by` | person-slug | **The claim.** Set it *first*, before any work |
| `blocked_by` | `[T-002, T-003]` | Unblocked = every listed ticket is `closed` |
| `spine` | `[licensing, integration]` | Which decision-spine areas this ticket resolves |

Wiki `status:` tracks the decision's lifecycle, not the ticket's: `draft` while open or claimed,
`active` once closed (the decision is now live), `archived` when ruled out of scope. `agent/schema.md`
governs the rest of the frontmatter; `type: design`.

**Claiming is not optional.** Concurrent sessions are normal on an engagement; an open, unclaimed
ticket is takeable by anyone, so write `claimed_by` and `ticket_state: claimed` to the file before
you read a single SOP.

The answer is **not** part of the body when the ticket is written — it is appended as a
`## Resolution` section on closing, together with the SOP citations (see [Mode: work](#mode-work-resolve-one-ticket)).
Assets are linked from the ticket, never pasted into it.

**A ticket carries its own briefing.** Two optional, date-stamped sections (contract in the
template) make tickets workable asynchronously — piloted on the first consuming engagement, where
they cut session time visibly:

- **`## Session prep`** — everything already known: settled facts from closed tickets, the
  pre-filled recommendation, the exact missing inputs each with a named owner. A session opens on
  the decision, not on research.
- **`## Grill script`** — for decision tickets: the numbered questions, each with a sourced
  recommendation, a scenario probe, and an inline `> Answer:` slot. Humans answer in the file
  whenever they have the input; an answer typed by the named human **is** the human side of the
  exchange. The script is the opening, not the session — the resolving session reads the answers,
  chases the follow-ups no script predicts (the highest-value findings on the pilot were
  script-breaking overrides), and still writes the full five-part Resolution.

Both sections are **maintained, not archived**: every resolution that changes another ticket's
inputs updates that ticket's prep and script (work mode step 7). A stale prep misleads faster than
no prep.

## Ticket types

Every ticket is **HITL** — worked *with* a human who speaks for themselves — or **AFK**, driven by
the agent alone. A HITL ticket resolves only through that live exchange; the agent never answers the
human's side of it. Full playbooks, including which skill each type invokes and what a good
resolution looks like: [references/ticket-types.md](references/ticket-types.md).

| Type | Mode | What it is | Resolves via |
|---|---|---|---|
| **research** | AFK | Surface a fact a decision waits on — an SOP position, a platform limit, a vendor capability, what the incumbent system actually does | `hso-wiki-query`, the SOP library, `hso-dataverse-sdk-reference`, `hso-fasttrack-reference`, `hso-d365-guidance-reference` |
| **fit-gap** | AFK → HITL | Does the platform already do this? OOB / CDM / first-party app / reusable IP versus custom. The most load-bearing type on a re-platforming, and P1 is the standard it answers to | `hso-semantic-data-modeling`, `hso-ce-apps-sdk-reference`, `hso-d365-licensing` |
| **grilling** | HITL | Conversation. **The default type.** One question at a time until a fuzzy branch is resolved and sourced | `hso-grill-architect` |
| **prototype** | HITL | Raise the fidelity of the argument with something cheap and concrete to react to — a conceptual ERD, a process map, a demo moment | `hso-diagram-excalidraw` (conceptual ERD), `hso-diagram-drawio` (process/sequence), `hso-presales-demo-architect` |
| **task** | HITL or AFK | Manual work that must happen before a *decision* can be made — ingest a missing artifact, obtain a data extract, get environment access, establish the licensing baseline. The one type that *does* rather than decides, and it earns its place by unblocking a decision | `hso-wiki-ingest-*`, `hso-d365-licensing`, `hso-analyze-system-review` |

---

## The decision spine (SOP anchoring)

Wayfinder's fog is freeform. Ours is not: a Dataverse solution map that never asked about licensing,
or migration, or the security shape, is not "still foggy" — it is **wrong**, and it produces a SOW
that gets repriced. The spine is the standing checklist of decision areas a Dataverse solution map
must dispose of before requirements begin.

> **Authority for the decision spine as a standard — the fifteen areas, the disposition rule, and the
> readiness-to-estimate gate — read
> [`presales/presales-playbook.md`](../../../agent/wiki/sop/presales/presales-playbook.md) §4 before
> charting a map.** That SOP owns *what must be true* for a shape to be decided; a map that closes
> against a different area list or a looser gate is non-conforming.
>
> **Authority for spine routing — which SOP governs each area, the sections to read, the questions
> each must answer, and the traps — read [references/decision-spine.md](references/decision-spine.md)
> before charting a map or resolving any ticket.** The table below is a **digest/pointer only** — the
> playbook, the reference file, and the SOPs it names are authoritative.

| # | Spine area | Governing authority (read before deciding in this area) |
|---|---|---|
| 1 | Business capability & process footprint | `crm-processes/` peers; BPC mapping ([ADR 0047](../../../agent/wiki/decisions/0047-bpc-aligned-portable-requirements.md)) |
| 2 | Product & module footprint | [`presales/solution-scope-contribution.md`](../../../agent/wiki/sop/presales/solution-scope-contribution.md) |
| 3 | Fit-gap: OOB vs custom | [`model-driven-apps/data-modeling-best-practices.md`](../../../agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md); `hso-semantic-data-modeling` |
| 4 | Conceptual data model & core entities | same as #3, plus `hso-diagram-excalidraw` for the ERD |
| 5 | Personas, security & access shape | [`security/security-best-practices.md`](../../../agent/wiki/sop/security/security-best-practices.md) |
| 6 | Licensing & cost baseline | [`licensing/d365-and-power-platform-licensing-best-practices.md`](../../../agent/wiki/sop/licensing/d365-and-power-platform-licensing-best-practices.md) |
| 7 | Integration landscape | `azure-integration/`, `dv-fo-integration/`, `m365-integration/`, `virtual-tables/`, `dual-write/` |
| 8 | Data migration, config data & MDM | `data-migration/`, `configuration-data/`, `master-data-management/` |
| 9 | Reporting & analytics | `analytics-integration/` |
| 10 | Extensibility posture (technology ladder) | [`dataverse-implementation-architecture-principles.md`](../../../agent/wiki/sop/dataverse-implementation-architecture-principles.md) P7; [`hso-dataverse-architect/references/technology-decisions.md`](../hso-dataverse-architect/references/technology-decisions.md) |
| 11 | Environment strategy, topology & ALM | `environment-strategy/`, `dataverse-solutions/`, `alm-best-practices/` |
| 12 | AI / Copilot leverage | `copilot/`; `hso-ai-leverage-review` ([ADR 0035](../../../agent/wiki/decisions/0035-ai-leverage-review-and-spec-time-disposition.md)) |
| 13 | Non-functional: performance, volume, availability | [`platform-performance/platform-performance-best-practices.md`](../../../agent/wiki/sop/platform-performance/platform-performance-best-practices.md) |
| 14 | Delivery shape: phasing, testing, go-live | [`presales/presales-playbook.md`](../../../agent/wiki/sop/presales/presales-playbook.md); `go-live-and-operate/`, `testing/` |
| 15 | Reusable IP & accelerator fit | first-party app + accelerator capability review (see the fit-gap ticket type) |

**Every area gets a disposition on the map — no area may be silently absent.** `resolved` (links its
ticket) · `ticketed` · `fog` (in scope, not yet sharp enough to ticket) · `out-of-scope` (with the
reason) · `n/a` (with the reason). "Nobody mentioned it" is not a disposition; it is the omission the
spine exists to catch.

> **Authority for the architecture principles every decision must conform to — read
> [`dataverse-implementation-architecture-principles.md`](../../../agent/wiki/sop/dataverse-implementation-architecture-principles.md)
> before charting a map.** P1 (semantic modeling first), P2 (first-time-right schema), P3
> (platform-native over parallel constructs), P7 (the technology-selection ladder), and P22
> (divergence from Microsoft is explicit and evidence-gated) are the standards a shape decision is
> right or wrong against.

> **Authority for the presales arc this map sits inside — read
> [`presales/presales-playbook.md`](../../../agent/wiki/sop/presales/presales-playbook.md) §§3–7
> before writing the Solution Map Summary.** It defines the discovery inputs a quote depends on (§3),
> the readiness gate this skill closes against (§4), the estimate anchors the summary must supply
> (§5), the two licensing gates and five cost traps (§6), and the Stage-6 handoff package the closed
> map becomes part of (§7).

**Citations are checked, not trusted.** Every closed ticket's `## Resolution` cites the SOP sections
actually read, in the form `` `security-best-practices.md` §§4,11 ``.
`Get-SolutionMapFrontier.ps1` reports a resolution whose ticket carries a `spine` area with no
citation as an error. A citation you cannot honestly write means the pre-read did not happen — go
read the SOP, then decide. Never cite a SOP you did not open.

## Prerequisites

Same four checks `hso-dataverse-architect` runs, at lower resolution — the map is where an unresolved
one becomes a `task` ticket rather than a silent assumption.

1. **Discovery context.** `agent/wiki/digests/` populated and read; `agent/raw/` captured. If thin,
   the first tickets are `task` tickets routed to `hso-wiki-ingest-discovery-artifact` /
   `hso-wiki-ingest-transcript`. **A map charted over un-ingested discovery is fog you created
   yourself.**
2. **Solution scope.** `agent/wiki/system/solution-scope.md` (delivery repo) or the **Solution Scope**
   table in `PROJECT_CONTEXT.md` (consulting workspace). Rows still reading `TBD` are exactly spine
   area #2 — ticket them. When a ticket resolves a product/module question, **upsert the scope row**
   per [`solution-scope-contribution.md`](../../../agent/wiki/sop/presales/solution-scope-contribution.md)
   (status ladder `candidate → recommended → confirmed`); the map is a contribution point, not a
   private notebook.
3. **Licensing baseline.** `agent/wiki/system/licensing-baseline.md`. Missing ⇒ a `task` ticket routed
   to `hso-d365-licensing`. Do not invent licensing assumptions, and do not let the SOW quote a shape
   whose licence consequence was never priced.
4. **Governance & overrides.** §1b *Inherited tiers* of `solution-scope.md` names the tiers; resolve
   positions with `Resolve-Policy` from [`hso-shared-scripts`](../hso-shared-scripts/SKILL.md). A
   declared-but-unmounted tier means program rules are invisible — **stop and fix the wiring**, do not
   chart past it. Every applied non-product position is named with its rule ID and governing tier in
   the resolution that applied it ([ADR 0061](../../../agent/wiki/decisions/0061-tier-precedence-specificity-plus-binding.md)).

## Fog of war

The map is *deliberately* incomplete. Beyond the live tickets lies fog: decisions you can tell are
coming but cannot yet pin down, because they hang on questions still open. Resolving a ticket clears
the fog ahead of it, graduating whatever is now specifiable into fresh tickets — one at a time, until
the way to the destination is clear.

**Fog or ticket?** The test is whether you can state the question precisely *now* — **not** whether
you can answer it now.

- **Ticket** when the question is already sharp, even if blocked.
- **Not yet specified** when you cannot phrase it that sharply. Do not pre-slice fog into
  ticket-sized pieces; one patch may graduate into several tickets, or none.

Spine areas dispositioned `fog` live here by name, so the omission is visible rather than absent.

## Out of scope

Fog gathers only *toward* the destination. Work beyond it is **out of scope** — not fog — and gets its
own map section: one line with the gist and the reason, linking the closed ticket if one existed.
Out-of-scope work never graduates; it returns only if the destination is redrawn, and then as a fresh
effort.

When an existing ticket turns out to sit past the destination, **close it** (`ticket_state:
out-of-scope`, `status: archived`) and record the line. It stays out of **Decisions so far**, which
records the route actually walked — a scope boundary is not a step on it. On a SOW-bound map this
section is load-bearing: it becomes the SOW's exclusions.

---

## Mode: chart (create the map)

Invoked with a loose idea. Charting is one session's work and hand-resolves nothing.

1. **Run the prerequisites.** Anything unresolved becomes a `task` ticket, not an assumption.
2. **Name the destination.** Invoke `hso-grill-architect` to pin down what this map is finding its way
   to — the solution shape a SOW can be written from. The destination fixes the scope, so settle it
   first. Write it in one or two lines.
3. **Sweep the spine, breadth-first.** Walk all fifteen areas with the user, fanning out rather than
   going deep on any one. Each area lands as `resolved` / `ticketed` / `fog` / `out-of-scope` / `n/a`.
   **If the sweep surfaces no fog** — every area lands `resolved` / `out-of-scope` / `n/a` — the way
   is already clear and you do not need a ticket board. You still need the **gate record**: write
   `map.md` with the Destination and the dispositioned spine, go straight to Close mode, and say so.
   The playbook (§1, "skippable only by evidence") requires the spine record either way; the tickets
   are what a clear engagement skips.
4. **Create `map.md`** from [templates/map.md.template](templates/map.md.template): Destination,
   Notes, the dispositioned spine, empty Decisions-so-far, fog in **Not yet specified**.
5. **Create the tickets you can specify now**, then wire `blocked_by` in a **second pass** — ids must
   exist before they can be referenced. Wiring sorts them into the frontier and the blocked. Seed
   each decision ticket's `## Grill script` (and `## Session prep` where facts already exist) while
   the charting context is loaded — the questions are cheapest to write now, and they let answers
   arrive asynchronously before any working session.
6. **Run the research tickets.** Every `research` ticket is AFK and independent; resolve them now
   rather than burning a session each. They are the one type exempt from one-per-session.
7. **Add a log fragment** under `agent/log/` ([ADR 0062](../../../agent/wiki/decisions/0062-log-fragments-and-generated-index.md)):
   `## [YYYY-MM-DD] design | <effort> | Solution map charted`. Never hand-edit `index.md` or `log.md`.
8. **Stop.** Report the frontier by ticket title and hand back.

## Mode: work (resolve one ticket)

Invoked with a map, optionally a ticket. Without one, **you** pick the next decision, not the user.

**Never resolve more than one ticket per session** — research tickets excepted. The cadence is the
value: a session that resolves four tickets resolved none of them at depth.

1. **Load `map.md`** — the low-resolution view. Not every ticket body.
2. **Run `Get-SolutionMapFrontier.ps1`.** Take the ticket the user named, else the first frontier
   ticket in order.
3. **Claim it** — `claimed_by` + `ticket_state: claimed`, written to the file **before any work**.
4. **Read the governing SOP** for every area in the ticket's `spine`, per
   [references/decision-spine.md](references/decision-spine.md). This is the read-before-doing step
   the whole skill exists to enforce; a resolution written without it is the plausible-looking,
   non-conforming output that costs the most, because it looks finished.
5. **Resolve it** by its type ([references/ticket-types.md](references/ticket-types.md)). Zoom as
   needed: fetch any closed ticket's full body on demand; invoke whichever skills the map's `## Notes`
   and the ticket's type name. Default to `hso-grill-architect` when in doubt.
6. **Record the resolution** — append `## Resolution` to the ticket (the answer, the SOP citations
   with sections, the alternatives rejected and why, any assumption it rests on), set
   `ticket_state: closed` / `status: active`, and **append one gist line to the map's Decisions-so-far**.
7. **Propagate.** Add newly-surfaced tickets (create, then wire). Graduate any fog the answer made
   specifiable, **clearing that patch from Not yet specified** so it lives only as its ticket. Upsert
   `solution-scope.md` if the answer moved the product footprint. If the answer invalidates other
   tickets, update or delete them; if it reveals a ticket sits past the destination, rule it out of
   scope rather than resolving it. **Update the `## Session prep` and `## Grill script` sections of
   every open ticket this resolution feeds** — new facts, changed recommendations, retired
   questions — so the next session (or an async answerer) never works from a stale brief.
8. **Durable decisions get an ADR.** A resolution whose *rationale* would otherwise be lost — a
   trade-off, a ruling, a convention that binds the build — is recorded via
   [`hso-wiki-write-decision`](../hso-wiki-write-decision/SKILL.md) at the project tier, and the ticket
   links it. The ticket is the working record; the ADR is the durable one.
9. **Log fragment**, then stop.

## Mode: close (map → Statement of Work)

Invoked when the frontier is empty and no tickets remain open.

> **Authority for what the summary must contain and how it maps to SOW sections — read
> [references/sow-handoff.md](references/sow-handoff.md) before writing it.**

1. **Verify closure against the playbook's gate (§4.2 — five conditions).**
   `Get-SolutionMapFrontier.ps1` reports zero open tickets, zero spine areas dispositioned `fog`, and
   zero uncited resolutions (conditions 1–2). Check by hand that the Solution Scope carries no `TBD`
   row the shape depends on (3) and that the licensing baseline exists and matches the shape (4);
   condition 5 is the summary you are about to write. Any `fog` remaining means the map is not
   closed — say so rather than synthesizing over a gap. If the gate says "not enough", the playbook
   names the three permitted responses (gather more / decide with the client / rule it out) — pick
   one per area and record it; do not estimate over the fog.
2. **Write the Solution Map Summary** into `map.md`: solution shape in a paragraph; the product and
   module footprint; capability workstreams; the OOB-vs-custom split; integration surface; data
   migration posture; security and persona shape; the phasing; assumptions; dependencies; risks; and
   **explicit exclusions drawn verbatim from Out of scope**.
3. **Feed the scope surfaces.** Upsert every confirmed row into `solution-scope.md` /
   `PROJECT_CONTEXT.md` per the contribution protocol. Confirm the licensing baseline still matches
   the shape the map landed on — if the shape moved, the baseline is stale and the quote is wrong.
4. **Seed the architecture map.** Hand the summary's solution shape and platform footprint to
   [`hso-architecture-map`](../hso-architecture-map/SKILL.md) SOP-1 as §1 Solution Intent and §2
   Platform Profile. Do not write `.topo` yourself.
5. **Hand off**, naming both next steps: `hso-requirements-author` for the Requirements Brief (the
   WHAT/WHY), and — where the engagement produces one — the SOW, built from the summary via
   [`hso-engagement-deliverables`](../hso-engagement-deliverables/SKILL.md).
6. **Set `map_status: closed`** and add the log fragment.

---

## Critical rules

**ALWAYS**
- Claim a ticket before working it. Concurrent sessions are the norm.
- One ticket per session (research excepted).
- Read the governing SOP for the ticket's spine areas, then cite the sections in the resolution.
- Refer to tickets by title in everything a human reads.
- Disposition every spine area. `n/a` with a reason beats silence.
- Attribute decisions to the human in `CLAUDE.local.md`.

**NEVER**
- Design. No table, column, form, view, plugin, flow, or slice DAG comes out of this skill.
- Answer a HITL ticket's human side yourself. A grilling that grills itself has resolved nothing.
- Restate a decision on the map. The map gists and links; the ticket holds it.
- List open tickets on the map. Query them.
- Edit `architecture-map.topo` (`solution-map.topo` in repos seeded before 2026-08-18) — that is
  `hso-architecture-map`'s artifact and its writer.
- Write client data into this skill or any shared skill.
- Synthesize a Solution Map Summary over an area still dispositioned `fog`.

## Changelog

See **[CHANGELOG.md](CHANGELOG.md)** ([ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md)).
