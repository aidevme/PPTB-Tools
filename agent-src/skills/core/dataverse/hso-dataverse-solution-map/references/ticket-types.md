# Ticket Types — Playbooks

**This file is the authority for how each ticket type is worked and what a valid resolution looks
like.** `SKILL.md` carries a five-row digest; this file carries the playbooks. Read the row for a
ticket's type before resolving it.

Every ticket is **HITL** (worked *with* a human who speaks for themselves) or **AFK** (driven by the
agent alone). **A HITL ticket resolves only through live exchange.** An agent that answers the
human's side of a grilling has not resolved the ticket — it has written down its own guess and
labelled it a decision. If the human is unavailable, the ticket stays claimed and open.

---

## Common to every type

A resolution is valid only if it carries all five:

1. **The answer**, stated as a decision — "X, because Y" — not a summary of the discussion.
2. **Standards grounding** — the SOP sections actually read, per the ticket's `spine` areas, in the
   format `` `sop-file.md` §§4,11 `` (see [decision-spine.md](decision-spine.md), *Citation format*).
3. **Alternatives rejected**, with why. A decision with no rejected alternative was not a decision.
4. **Assumptions** the answer rests on, each one falsifiable. These flow to the SOW's assumptions.
5. **Consequences** — what this unblocks, what it constrains, what fog it clears.

Then: set `ticket_state: closed` and `status: active`, append one gist line to the map's
Decisions-so-far, and propagate (graduate fog, wire new tickets, upsert scope).

---

## research (AFK)

**Use when** a decision waits on a fact that is not in this working directory: an SOP position, a
platform limit, a vendor capability, a licence rule, or what the incumbent system actually does.

**Do not use** for a question whose answer is a judgment call. "What is the Dataverse alternate-key
limit" is research; "should this be an alternate key" is a grilling.

**Work it:**

1. Search the wiki first — `hso-wiki-query` covers `agent/wiki/`, `agent/work/`, and every inherited
   tier. A cited answer from an existing digest or ADR beats a fresh read.
2. Then the SOP library, routed by the ticket's `spine` areas.
3. Then the vendor reference skills, in this order of authority for *Microsoft facts*:
   `hso-dataverse-sdk-reference`, `hso-ce-apps-sdk-reference`, `hso-fieldservice-reference`,
   `hso-fasttrack-reference`, `hso-d365-guidance-reference`. These are clean vendor windows — do not
   let a delivery-org position be reported as a Microsoft fact, or the reverse.
4. The reusable IP / accelerator catalog for your delivery organisation (area 15).

**Exempt from one-per-session.** Research tickets are independent and AFK; resolve every open one in
a charting session rather than burning a session each.

**Resolution shape:** the fact, its source with enough precision to re-find it, its freshness, and —
explicitly — what it does *not* establish. A research ticket that concludes "and therefore we should
do X" has overstepped; the decision belongs to the ticket it unblocks.

---

## fit-gap (AFK → HITL)

**Use when** the question is *does the platform already do this?* This is the highest-value type on a
re-platforming, and the one most often skipped, because the incumbent system's vocabulary makes every
concept feel bespoke.

**Standard it answers to:** [P1 — semantic modeling first; OOB and CDM before custom; extend, never
replace](../../../../agent/wiki/sop/dataverse-implementation-architecture-principles.md). **The burden
of proof is on custom.**

**Work it — in this order, and do not skip forward:**

1. **CDM / OOB Dataverse.** Invoke `hso-semantic-data-modeling` — it is the research gate that runs
   before any new-table decision, and it covers CDM, industry standards, and how the major platforms
   model the same concept.
2. **First-party app.** `hso-ce-apps-sdk-reference` (Sales, Customer Service, Field Service, Project
   Operations, Marketing) — does an app in the confirmed footprint already carry this capability?
3. **Reusable IP.** The reusable IP / accelerator catalog for your delivery organisation and the matching
   accelerator SOP for the industry in play.
4. **Only then, custom** — and the resolution must say what specifically the platform could not do.

**The AFK→HITL handoff:** steps 1–3 are AFK research. The *verdict* — accept the OOB shape, extend
it, or go custom — is a human call, because it trades platform conformance against how far the
client's process must bend. Present the finding, then get the verdict.

**Resolution shape:** the OOB/CDM/first-party/IP candidate that came closest, exactly where it falls
short, the verdict, and — when the verdict is custom — the divergence recorded per
[P22 (divergence from Microsoft is explicit and evidence-gated)](../../../../agent/wiki/sop/dataverse-implementation-architecture-principles.md).

---

## grilling (HITL) — the default

**Use when** the question is a judgment call and the human holds the context. This is most tickets.

**Work it:** invoke [`hso-grill-architect`](../../hso-grill-architect/SKILL.md). Its core rules apply
unchanged and are the reason to use it rather than freestyling:

- **One question at a time.** Never batch. Wait for the answer. The cadence is the value.
- Every question carries a **recommended answer** sourced from the relevant SOP, the live schema, or
  a prior project decision — so the human is reacting, not generating from nothing.
- Drive every fuzzy branch to a resolved, sourced, scenario-tested answer.

**Scope it to the ticket.** A grilling ticket is one question's worth of interview, not the whole
design. When the grilling opens a genuinely separate question, that is a new ticket, not a longer
session.

**Pre-seeded scripts and async answers.** Where the ticket carries a `## Grill script` (template
contract), answers the named human typed under `> Answer:` are the human's side of the exchange —
start from them, do not re-ask them. The session's job is then the part no script does: classify
each answer (accepted / overridden-with-reason / contradicts-earlier), chase the follow-ups the
answers open, scenario-probe, and write the Resolution. An unanswered script is just a faster
opening; an answered one is a half-finished interview — never a finished decision.

**Resolution shape:** the decision in the human's terms, the scenario that tested it, the SOP
position that backed or contradicted it, and — where the human chose against the SOP — the divergence
recorded with its rationale and owner.

---

## prototype (HITL)

**Use when** "how should this look" or "how should this behave" is the blocking question, and the
discussion has stalled at prose. A cheap concrete artifact raises the fidelity of the argument.

**Work it:**

| The question | Build |
|---|---|
| What are the core entities and how do they relate? | Conceptual ERD — `hso-diagram-excalidraw`, conceptual-ERD mode (6–8 entities, one screen, client-facing) |
| What does the process actually look like end to end? | Process / sequence diagram — `hso-diagram-drawio` |
| Would the client recognize this as their world? | Demo moment — `hso-presales-demo-architect` |
| What would the target architecture look like at a glance? | `hso-diagram-reference-architecture` |

**Cheap and rough is the point.** A prototype exists to be reacted to and thrown away. If you are
polishing it, you are building a deliverable, and the map is not the place for that.

**Assets go in `assets/`** beside the map and are **linked** from the ticket, never pasted into it.

**Resolution shape:** what the artifact was, what the human's reaction actually decided, and the link
to the asset. The artifact is not the resolution — the reaction to it is.

---

## task (HITL or AFK)

**Use when** manual work must happen before a *decision* can be made. Nothing to decide, prototype,
or research — the discussion is simply blocked until it is done.

This is the one type that **does** rather than decides, and it earns its place only by unblocking a
decision. A task that unblocks nothing is not a map ticket; it is work, and it belongs in the plan
the SOW produces.

**Common tasks on a Dataverse solution map:**

| Task | Route to | Unblocks |
|---|---|---|
| Discovery artifact or transcript not yet ingested | `hso-wiki-ingest-discovery-artifact` / `hso-wiki-ingest-transcript` | Almost everything — an un-ingested source is fog you created yourself |
| A batch drop sitting in `agent/_inbox/` | `hso-wiki-process-inbox` | As above |
| No licensing baseline exists | `hso-d365-licensing` | Spine area 6, and every quote line |
| The incumbent Dataverse org has never been assessed | `hso-analyze-system-review` | Areas 3, 7, 8 — you cannot fit-gap against an unknown as-is |
| A data extract is needed to see the real shape | `hso-msaccess-extractor` / `hso-salesforce-extractor` / the client | Areas 4, 8 |
| Environment or tenant access is missing | The human, with a precise checklist | Anything requiring live metadata |
| A declared inherited tier is not mounted | `Initialize-SharedJunction.ps1 -FromDeclaration` | **Everything** — invisible governance means every decision is provisionally wrong |

**AFK where the agent can drive it; HITL otherwise** — and a HITL task means handing the human a
precise checklist, not a vague ask.

**Resolution shape:** what was done, plus **any resulting fact later tickets depend on** — where the
extract landed, what the row counts were, which digest now exists, where credentials live. The next
session cannot re-derive these.
