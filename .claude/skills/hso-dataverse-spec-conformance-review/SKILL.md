---
name: hso-dataverse-spec-conformance-review
layer: orchestration
scope: core
description: Fresh-context adversarial review of an UNBUILT Dataverse feature spec against HSO's standards — the mandatory SOPs, the semantic-research gate, the config/reference-data posture, and the party posture — before the human grill gate and before anything is built. Dispatched by hso-dataverse-architect as an independent subagent on every spec; also invocable directly ("review this spec for SOP conformance", "standards-check the spec"). Reviews the spec's DECISIONS against the STANDARDS, not against the spec's own promises — a spec that is wrong-by-standards looks internally consistent, which is exactly why the author cannot review it. Produces a findings report (md + json); never edits the spec.
---

# Dataverse Spec Conformance Review

A spec that violates the methodology's own standards can sail through every downstream
gate: the build faithfully implements it, the delivery-time adversarial review walks
personas against the spec's own promises, and every check passes — because the yardstick
at every stage is the spec itself. **This skill is the missing yardstick swap**: it reviews
the spec, pre-build and pre-grill, against the **standards** — the mandatory SOPs for every
area the spec touches — with a mandate to find the decisions the standards refute. A spec
that is not based on the SOPs is worthless, no matter how coherent it reads.

**Independence is structural, not aspirational.** The architect that authored the spec
must NOT run this review in its own context: the author reviewing its own output against
SOPs it may never have opened is the failure mode this skill exists to kill. The review
runs as a **fresh-context subagent** (or a separate session) that has seen none of the
authoring conversation.

## When to use this skill

- `hso-dataverse-architect` has drafted a spec and must clear it for the grill gate —
  the architect dispatches this review on every spec, without exception.
- The user says "review this spec for SOP conformance", "standards-check this design",
  "did this spec follow our best practices?"
- A spec authored outside the standard flow (imported, client-supplied, externally dispatched)
  needs a standards verdict before build.

## When NOT to use

- Reviewing a **built** feature against its spec/brief — that is
  `hso-dataverse-adversarial-review` (delivery-time, live environment).
- The human design interrogation — that is the human's spec review (the grill gate);
  this review runs **before** it and does not replace it.
- Mechanical schema validation alone — `Validate-SpecJson.ps1` runs standalone; this
  review runs it as its first step, then judges what a script cannot.

## Model

Best available frontier model (**Fable, else Opus**) at **high effort** — review judgment
is never downgraded (ADR 0022 model policy). **Harness translation (ADR 0052):** on
GitHub Copilot CLI, where a plain subagent launch does not
exist — this review is dispatched as a `task` to the **`hso-spec-conformance-reviewer`**
custom agent (`.github/agents/`, distributed from `agent-src/agents/`), or via the
child-process form `copilot -p --agent hso-spec-conformance-reviewer --model <model>`;
the dispatcher verifies the model pin took (the CLI logs the served model). "Fable, else
Opus" = the strongest Claude in the harness's picker; "high effort" is approximated by
model + prompt emphasis. Running this review on a mid-tier model is a contract
violation, not a degraded mode.

## Inputs

| Input | Required | Description |
|---|---|---|
| `SpecPath` | yes | The spec folder or `feature-spec.md` / `spec.md` (with its `spec.json` sidecar) |
| `BriefPath` | no | The requirements brief — used to judge allocation and coverage, not to re-litigate requirements |
| `OutputDir` | yes | Where `conformance-findings.md` + `conformance-findings.json` land |
| `Mode` | no | `full` (default) — the complete 11-dimension review below. `delta` — rounds 2+ only: verify the previous round's fail-level findings against the revised spec (see **Delta mode**) |
| `FindingsPath` | delta only | The failing round's `conformance-findings.json` — the findings to verify |

If a required input is missing, ask — never guess.

## Delta mode (rounds 2+) — verify the fixes, do not re-board the world

A full fresh review costs its whole boarding (every touched-area SOP, both spec
documents, the schema) every time it runs. Measured on the 2026-08-21 authoring run
(DCFS `02-Rates-and-Service-Plans`): **five full reviews in 100 minutes, 5.9–8.2M tokens
each (~34M total)** — the loop had no cap and re-paid full boarding per round. The build
leg already solved this: a remediation **verifier** checks only the fix, fresh-context,
default-fail, at ~1/8 the cost. Delta mode is that pattern for spec review.

In `Mode: delta`:

1. **Scope = the fail-level findings in `FindingsPath`, nothing else.** Load ONLY the SOP
   sections those findings cite (`sop_ref`) plus the spec sections they point at
   (`spec_ref`) as revised — not the full sop-index sweep. Independence is unchanged:
   fresh context, no authoring conversation, read-only on the spec.
2. **Default-fail per finding.** For each finding return `fixed` / `not-fixed` /
   `regressed` with the revised spec text quoted against the same SOP section. "The
   architect says it's fixed" is not evidence.
3. **Check the blast radius of the edits, not the whole spec.** Diff-read the revised
   sections the findings point at; a NEW violation introduced *by those edits* is filed
   as a new finding (normal schema). Untouched dimensions are out of scope — they passed
   the full round and nothing changed them.
4. **Verdict:** `pass` when every in-scope finding is `fixed` and no new finding was
   filed; else `fail` listing what stands.

Delta mode never substitutes for the round-1 full review, and a delta `pass` satisfies
the architect's Definition of Ready exactly as a full-review `pass` does.

## The foundation: load the standards FIRST

**A conformance review that did not load the SOPs is invalid — it is the honor-system
failure this skill replaces.** (`Mode: delta` narrows this boarding to the SOP sections
the in-scope findings cite — see **Delta mode**; everything below is the `full` contract.)
Before judging anything:

1. Resolve every area the spec touches (tables/columns/relationships/choices/lifecycle,
   forms/views/app, dashboards, Custom APIs, plugins, flows, security, migration/config
   data, naming) via the architect skill's routing index:
   [`hso-dataverse-architect/references/sop-index.md`](../hso-dataverse-architect/references/sop-index.md).
2. **Open and read every "Mandatory pre-read" SOP for every touched area** — actually
   read the governing sections, in this review's context. The spec's own Sources section
   is a claim to verify, never a substitute for your own read.
3. Record, in the findings report, **which SOPs (with sections) grounded the review** —
   a report without this list is an invalid review and must not be accepted by the
   dispatching architect.

## Review dimensions (all mandatory)

### 1. Mechanical preflight
Run `hso-dataverse-architect/scripts/Validate-SpecJson.ps1` against the spec's
`spec.json`. A non-zero exit is an automatic blocker finding (quote the violations).
This also covers the Sources-citation, declared-column, and semantic-research file gates
mechanically — your job in the dimensions below is what the script cannot judge.

### 2. Standards conformance per touched area
For every touched area, review the spec's **design decisions** against the loaded SOP —
not against the spec's own rationale. Classic findings this dimension exists to produce:
reference lists shipped as free-text columns, choice/ownership/cascade violations,
lifecycle modeled as custom flags instead of statecode/statuscode, forms authored without
the form SOP's patterns, missing config tables. Each finding cites the SOP section it
violates, verbatim.

### 3. Semantic-research process (not artifact)
A dedicated `semantic-research.md` (produced by running `hso-semantic-data-modeling`
BEFORE design) must exist in the spec folder and carry per-entity CDM research with
deprecation and restricted-table citations and dated provenance. An inline
architect-authored "Semantic Research Summary" does NOT satisfy this — the gate is proof
of process, not existence of prose. **No self-granted waivers**: a client constraint
narrows the decision space, it does not waive the research. Judge whether the research
actually defends each custom-vs-OOB call, not merely that the file exists.

### 4. Reference/config-data posture
Every coded/enumerable column must carry an explicit recorded classification —
**config-table lookup vs global choice vs free text** — per the posture rule in
[`data-modeling-best-practices.md` §9](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md)
and `hso-semantic-data-modeling`. Admin-maintained, values-change-without-deployment, or
behavior-carrying code sets default to an OrgOwned config **table** (Restrict lookup +
code alternate key + config-data load slice). "Current values unknown" while the legacy
extraction contains the values is a refuted premise, not a rationale — flag it. The
burden of proof is on NOT creating the config table.

### 5. Party posture
Any external legal/natural party (anything carrying tax id / FEIN / UEI / addresses)
defaults to **Account** (organization) / **Contact** (person) — **including secondary
parties** (subcontractors, sponsors), not just the primary. A custom party table without
a defended rejection of Account/Contact in `semantic-research.md` is a finding.

### 6. App landing experience
The spec must either declare dashboards (`dashboards[]`, per the dashboard SOP) or record
an explicit deferral naming the owning feature. Silence on the landing experience is a
finding, not a default.

### 7. Requirements allocation (when `BriefPath` supplied)
Configuration/reference-data establishment belongs to the feature whose entry behavior
depends on it — flag config requirements allocated to a migration/foundation feature
while this spec's entry behavior consumes them.

### 8. Dispatch readiness — no decision left for the build to wait on
Spec approval is the authorization for every slice. Flag (S1): a build slice tagged
`mode: HITL` (only `design` slices may be HITL, and none survive approval); an Open
Question whose disposition point is "before slice sN is built" / "during build" rather
than "at spec approval"; an OQ still `Open` in a spec presented as ready. Flag (S2): a
slice whose touches name a portal / Power Pages surface (or a plugin package, connection
reference, environment variable) with no `preconditions[]` entry naming it — the pipeline
must probe it at Stage 0, not discover it mid-build. `Validate-SpecJson.ps1` catches the
mechanical half (HITL⇔design, portal precondition, OQ-gates-a-slice; `-Signed` for the
rest); you judge whether the design decisions the spec *claims* are settled actually are.

### 9. App membership and reachability
Every publisher-owned table the spec declares (`newTables[]`, form/view tables) is a
sitemap `subArea` entity or is in `app.unsurfacedTables[]` with a reason a persona still
reaches it; the spec carries **one** app/sitemap assembly slice (single writer,
`BuildSiteMap`) blocked by every table-creating slice, whose acceptance quotes the
`appmodulecomponents` + `ValidateApp` read-back. Flag (S1) a table that is neither, and
(S2) entity slices whose touches include "add to app" / `AddTableToApp` (per-slice app
writes clobber; round-3 F-02).

### 10. Security posture of added columns (security SOP §11 / §14)
Flag (S1) a sensitive-identifier column (SSN / tax id / bank / DOB / health id) the spec
adds without `IsSecured` + an FSP, or placed on Quick Find / a general public view; (S2)
an aggregate root (the table the approval / financial process transitions on) with
auditing off and no recorded exception; (S2) a required (`ApplicationRequired` /
`SystemRequired`) column added to an OOB table whose spec does not name the persona's
form it lands on. Cite the SOP §11 *Sensitive-identifier columns* subsection verbatim.

### 11. Status / completion gates enumerate every mutation path
Every gate the spec's business-logic section states carries acceptance naming all three
paths — Create with non-default status, Update transition, post-transition mutation of
gated columns (document-templates "Status / completion gates"). Flag (S2) a gate whose
acceptance names only the Update transition — the two-round F-04 bypass.

## Report

Write `conformance-findings.md` + `conformance-findings.json` to `OutputDir`:

- **Verdict** — `pass` | `pass-with-findings` | `fail`. Any S1/S2 finding ⇒ `fail`.
- **Findings** — id, severity (S1 blocker / S2 major / S3 minor / S4 advisory), dimension
  (1–11 above), the spec decision at issue (verbatim quote + location), the **SOP section
  violated (verbatim quote)**, and a one-line suggested correction.
- **Standards grounding** — the list of SOPs read, with sections, per dimension. **A
  report without this section is invalid.**
- **Pass evidence** — one line per dimension checked clean, citing the SOP sections that
  grounded the clean verdict.

JSON mirrors the markdown (`findings[]` with `severity`, `dimension`, `spec_ref`,
`sop_ref`, `quote`; `standards_grounding[]`; `verdict`).

Delta mode writes `conformance-delta-<n>.md` + `.json` instead: per-finding
`{ id, verdict: fixed|not-fixed|regressed, quote }`, any new findings (normal schema,
scoped to the edits), the narrowed standards grounding, and the overall verdict.

## Contract with the dispatching architect

- The architect dispatches this review **after the spec drafts and BEFORE declaring the
  spec ready for the grill gate**. The spec's Definition of Ready is not satisfiable
  without a `pass` / `pass-with-findings` verdict from a review whose report carries a
  non-empty Standards grounding section.
- On `fail`: the architect revises the spec and re-dispatches **in `delta` mode**, scoped
  to the failed findings (never negotiates with the old report, never edits the findings).
  **The loop is capped: one full review + at most two delta rounds.** Findings still
  standing after the cap go to a **human disposition** (a recorded decision with an owner,
  never silence) — never another automatic round. Five uncapped full reviews on one spec
  (2026-08-21) is the failure this cap exists to prevent.
- This review is **read-only on the spec**: it fixes nothing, files everything.

## Critical rules

**ALWAYS:**
- Load and read the mandatory SOPs for every touched area before judging — and list them
  (with sections) in the report.
- Judge decisions against the standards, quoting both sides (spec text + SOP text).
- Run `Validate-SpecJson.ps1` first; treat its failures as blocker findings.
- Produce the report even on a clean pass — pass evidence, grounded in SOP sections.

**NEVER:**
- Review in the authoring context — independence is the point.
- Accept the spec's Sources section as proof the SOPs were followed — it proves at most
  that they were cited.
- Accept an inline semantic-research summary, or a waiver the spec granted itself.
- Edit the spec, the brief, or anything outside `OutputDir`.
- Substitute this review for the human grill gate, or vice versa.

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
