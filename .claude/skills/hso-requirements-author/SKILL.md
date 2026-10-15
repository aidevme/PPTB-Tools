---
name: hso-requirements-author
layer: orchestration
scope: core
description: |
  Author system-agnostic, BPC-aligned requirements (the WHAT/WHY) from transcripts, discovery artifacts, ADO items, or verbal asks — a signable Requirements Brief that hso-dataverse-architect then translates into a Dataverse design. Map-or-propose: every FR is mapped to a Business Process Catalog process, or a well-formed custom process is proposed where none fits (portable to the orchestration platform, ADR 0047). SOP-aware: surfaces licensing, security, data, and integration implications as requirements/assumptions without designing the implementation. Tracks ADO projection (BPC tags + parent links) and delegates it to hso-ado-work-items. Use when:
  - User says "write requirements", "create a requirements brief", "capture what the client needs"
  - Defining the WHAT/WHY before any technical design
  Does NOT design the implementation (no tables, columns, forms, plugins, or slice DAG) — that is hso-dataverse-architect's job — and does NOT own catalog storage, import, or scoping. Renamed from hso-task-creator; see ADR 0022 + 0023.
---

# Requirements Author

Turn raw inputs — transcripts, discovery artifacts, ADO items, verbal asks — into a **system-agnostic Requirements Brief**: the WHAT and WHY a client needs, stated in solution-neutral terms, ready to be signed off and handed to `hso-dataverse-architect` for the HOW.

This skill is **step 2** of the delivery flow ([ADR 0022](../../../shared/dv/agent/wiki/decisions/0022-review-findings-drive-build-remediation-loop.md)): `ingest → requirements (this skill) → design + slice DAG (architect) → build → review → fix → PR`.

## Role boundary (read first — this is the whole point of the split)

- **You author requirements, not design.** State outcomes, business rules, constraints, and acceptance in **solution-neutral language**. Do **not** specify tables, columns, relationships, forms, views, plugins, flows, security roles, or a slice DAG. Those are `hso-dataverse-architect`'s output ([ADR 0023 D1](../../../shared/dv/agent/wiki/decisions/0023-requirements-and-spec-separate-artifacts.md)).
- **You are SOP-aware, not SOP-applying.** HSO delivers primarily on Dataverse/Power Platform, so the SOPs below tell you *which requirement categories to probe and what implications to surface* — extract the **solution-neutral requirement or assumption**, never the Dataverse mechanic. (E.g. surface "users in two regions need isolated access to their own records" — not "use a business-unit-scoped security role.")
- **No horizontal phase plan.** Never emit an "Implementation Approach: Phase 1/2" section — that anti-pattern was replaced by the architect's slice DAG ([ADR 0018](../../../shared/dv/agent/wiki/decisions/0018-agentic-delivery-architect-builder-pipeline.md)).
- **AI-delivery disposition is allowed; the mechanic still is not.** When the engagement runs AI-leverage review, you may annotate *how much AI* delivers each requirement (`agent-built` / `agent-assisted` / `human-only`) and write acceptance criteria that encode the human-on-the-loop checkpoint. Disposition is a *delivery-method* annotation, orthogonal to solution-neutrality — it says nothing about tables/forms/plugins ([ADR 0035](../../../shared/dv/agent/wiki/decisions/0035-ai-leverage-review-and-spec-time-disposition.md)).

## Configuration

Read from `CLAUDE.local.md`:
- **Author Name** — for the brief's `Written By` / frontmatter `people:`. If missing, ask the user and create the Author Information section.
- **Azure DevOps settings** (org, project) — only needed if requirements are projected to ADO (see step 7). `hso-ado-work-items` resolves auth itself.

## Output

A **Requirements Brief** at `agent/work/specs/[Feature]/requirements.md`, using [references/requirements-brief-template.md](references/requirements-brief-template.md). It carries **wiki frontmatter only** (`type: spec`) — no `**Status**` work-status line, because the brief is an *input*, not a build target ([ADR 0023 D2](../../../shared/dv/agent/wiki/decisions/0023-requirements-and-spec-separate-artifacts.md)). The architect's `spec.md` (the build target) carries the work-status line.

## SOP awareness — authority map

Read the relevant SOP **to surface requirement-level implications**, then write the solution-neutral requirement/assumption into the brief. These are digests-as-pointers — the linked SOP is authoritative; you are not applying it, only mining it for requirement categories.

| Requirement area to probe | Authority — read to surface implications | Surface as |
|---|---|---|
| Licensing & cost | [`d365-and-power-platform-licensing-best-practices.md`](../../../shared/dv/agent/wiki/sop/licensing/d365-and-power-platform-licensing-best-practices.md) | a cost/licensing **assumption** or constraint |
| Access & data isolation | [`security-best-practices.md`](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md) | a security/access **requirement** |
| Data governance, MDM, migration | [`migration-strategy-and-tooling-best-practices.md`](../../../shared/dv/agent/wiki/sop/data-migration/migration-strategy-and-tooling-best-practices.md), [`master-data-management-best-practices.md`](../../../shared/dv/agent/wiki/sop/master-data-management/master-data-management-best-practices.md) | a data **requirement**/assumption |
| Integrations | [`dv-fo-integration-best-practices.md`](../../../shared/dv/agent/wiki/sop/dv-fo-integration/dv-fo-integration-best-practices.md), [`m365-integration`](../../../shared/dv/agent/wiki/sop/m365-integration/) | an integration **requirement** |
| Environments & ALM | [`environment-strategy-best-practices.md`](../../../shared/dv/agent/wiki/sop/environment-strategy/environment-strategy-best-practices.md) | a constraint/assumption |
| Operations & go-live | [`go-live-and-operate-best-practices.md`](../../../shared/dv/agent/wiki/sop/go-live-and-operate/go-live-and-operate-best-practices.md) | an operational/non-functional **requirement** |
| **Who said it, and how well is it backed** — the source of every FR | [`source-authority-and-evidence-grading-best-practices.md`](../../../shared/dv/agent/wiki/sop/requirements-engineering/source-authority-and-evidence-grading-best-practices.md) — **authority for step 3a; read § 2 (authority register), § 4 (roll-up + decision table) and § 5.1 (recording) before extracting FRs** | the Stakeholders table's *Authority* column; each FR's `*Source:*` line with `origin` + `confidence`; partner-originated ideas as proposals, never FRs |

## Workflow

1. **Verify author config** (see Configuration). Do not proceed without an Author Name.
2. **Gather context.** Check `agent/wiki/digests/` (ingested transcripts/artifacts), `agent/work/analysis/` (prior analysis), and `agent/work/specs/` (existing/related requirements — avoid duplicates). If the source is a raw transcript or document not yet ingested, route it through `hso-wiki-ingest-transcript` / `hso-wiki-ingest-discovery-artifact` first, then cite the digest.
2a. **Is the solution shape decided?** A brief needs a shape to be written against — which processes, which product footprint, OOB vs custom, the integration surface, the phasing. If `agent/work/design/solution-map/<effort>/map.md` exists and is closed, read its **Solution Map Summary** first and cite it as the brief's context. If no map exists **and** the digests do not let you state the solution in one paragraph — `agent/wiki/system/solution-scope.md` still carries `❔ TBD` rows, OOB-vs-custom is open, the incumbent's replacement boundary is undecided — **stop and route to `hso-dataverse-solution-map`** (Presales Playbook Stage 3 — Shape) before authoring. Writing requirements over an undecided shape produces a brief that reads as complete and prices wrong. On a small engagement whose shape is plainly decidable, proceed — but say so in the brief's assumptions.
3. **Extract requirement elements** from the input: purpose, business value, stakeholders, functional requirements (outcomes + business rules), non-functional/technical requirements (performance, security, compliance, integration, data, volume), constraints, assumptions, and requirement-level acceptance.
3a. **Grade the source of every FR** per [the source-authority SOP](../../../shared/dv/agent/wiki/sop/requirements-engineering/source-authority-and-evidence-grading-best-practices.md). First fill the Stakeholders table's *Authority* column (one level per person per area: `approver` / `expert` / `contributor` / `consultant` / `unknown`, keyed on `wiki/people/` slugs, with the artifact that named them) — that table is the engagement's authority register. Then give every FR a `*Source:*` line (originator slug or `unknown` + organisation, derived authority, artifact + locator) and set `origin` (`stated` / `derived` / `proposed` / `inherited`) and `confidence` (`high` / `medium` / `low`, weakest link) per the SOP's § 4. An idea HSO or another partner floated is `proposed` — it goes under Assumptions/Proposals, never under Functional Requirements, unless the client has asked for a decision on it. Only `expert` or `approver` statements ground a `stated` FR; a `contributor`- or `unknown`-only FR carries an open question "confirm with <approver>".
4. **Ask clarifying questions** when the input is thin — but keep them **system-agnostic**: outcomes, rules, who does what, data volumes, success metrics, compliance needs. **Not** "which tables/forms" (that's the architect's interview, driven by `hso-grill-architect`).
5. **Surface SOP-driven implications** (see authority map) as requirements/assumptions. Flag, don't design.
5c. **Allocation rule — configuration/reference data belongs to the feature whose ENTRY BEHAVIOR depends on it.** When partitioning requirements into features: requirements for establishing and admin-maintaining configuration/reference data (code lists, descriptor/type catalogs, rate tables, template mappings) are allocated to the feature whose data entry or behavior **consumes** them — stated as requirement-level outcomes ("administrators maintain X without deployment", "each code set exists exactly once as a single authoritative list", "configuration determines entry behavior declaratively"). A **data-migration/foundation feature owns the LOADING of historical data — never the existence or maintenance of reference tables**. Mis-allocating configuration to migration leaves the core feature with no configuration requirement at all, and the design then defaults the codes to free text; seam-level partitioning review does not catch this — check the allocation explicitly.
5a. **AI-delivery disposition pass** *(optional — when the engagement runs AI-leverage review, per [ADR 0035](../../../shared/dv/agent/wiki/decisions/0035-ai-leverage-review-and-spec-time-disposition.md))*. For each functional requirement, obtain an AI-disposition (`agent-built` / `agent-assisted` / `human-only`) from **`hso-ai-leverage-review`** (design mode). Record them in the brief's **AI delivery disposition** section. For every `agent-built` requirement, write requirement-level acceptance that encodes the **human-on-the-loop checkpoint** — the "no X commits without explicit human approval" clause is what makes it testable rather than aspirational. Stay system-neutral: disposition is the delivery method, not the Dataverse mechanic.
5b. **Map-or-propose pass (BPC alignment)** — per [ADR 0047](../../../shared/dv/agent/wiki/decisions/0047-bpc-aligned-portable-requirements.md); mechanics in [references/bpc-process-mapping.md](references/bpc-process-mapping.md). Resolve the catalog input (engagement-supplied export wins; local standard-catalog clone as fallback), then tag **every FR** with a Business Process Catalog process (`ProcessSequenceId` + name + level path, status `mapped`) or **propose a custom process** where none fits (verb–noun name, parent scenario, level, rationale, originating FRs — the proposal block mirrors the orchestration platform `PendingCatalogAddition`). `unmapped` only with a written reason. Batch-review proposals with the user — they are sign-off items, like the FRs themselves. Fill the brief's Process Mapping section + frontmatter `processes:` rollup.
6. **Write the Requirements Brief** to `agent/work/specs/[Feature]/requirements.md` from the template, with valid wiki frontmatter (`type: spec`, status/scope/client/project/created/updated). Solution-neutral throughout.
7. **Resolve the ADO process profile, then project per its mapping** *(standalone-Forge path —
   in an orchestration-platform engagement (a `publish_requirements` tool on your session, or the orchestration platform provenance
   in the repo) this step is **replaced entirely** by § Publishing to the orchestration platform; Forge never
   talks to ADO directly there)*. Resolve the profile
   per [ADR 0051](../../../agent/wiki/decisions/0051-ado-process-profile-abstraction.md):
   read the consumer repo's `agent/wiki/system/ado-projection-profile.md`; if absent, run
   the resolution procedure in `hso-ado-work-items` (§ "Process-profile resolution":
   `Get-AdoProcessProfile.ps1` detection → interview → chip question) and **record the
   answer** (profile file + `CLAUDE.md` marker row) before projecting — detected, never
   assumed. Profile `none` = not ADO-tracked (opt-in per engagement, [ADR 0018](../../../shared/dv/agent/wiki/decisions/0018-agentic-delivery-architect-builder-pipeline.md)):
   note "Not tracked in ADO" in the brief and skip the rest of this step.
   The canonical profile (`hso-ado-work-items/references/process-profiles/<id>.md`) answers
   every type question — do not hard-code types:
   - **FR → one work item of the profile's `requirement.workItemType`** (User Story /
     Product Backlog Item / Requirement / Issue / custom `Requirement`), created via
     **`hso-ado-work-items`**. Record the returned IDs in the brief's **ADO Tracking**
     section as the **FR → work-item map** (one row per FR, per the template) — triage
     Bug-parenting and the delivery pipeline's attribution claims both resolve through
     that map, so a flat ID list is not enough.
   - **Acceptance criteria land where the profile says** (`acceptanceCriteria`): the AC
     field (Agile/Scrum), Description bullets (CMMI/Basic), or **Test Case children**
     created before build via Create + `AddTestSteps` (test-case-as-AC on
     `hso-us-new-format`; record their IDs in the map's Test-cases column).
   - **Rule-FRs may fold n:1** into the parent capability's acceptance wherever the
     profile allows (`ruleFrFold`) — the map records `FR-n → AC of #id` so no FR silently
     disappears.
   - **BPC projection is profile-independent** ([references/bpc-process-mapping.md](references/bpc-process-mapping.md) §6):
     tag each work item `BPC:<ProcessSequenceId>` (or `BPC:proposed:<key>` /
     `BPC:unmapped`); parent per the profile (`requirement.parent` — Feature/Epic, or the
     BPC Process node when the catalog is hydrated in the ADO project).
   - **Shared fields:** populate the profile's `sharedFields` where reference names are
     discovered; while a name is `TBD`, **skip and note it in the brief** — never guess.
8. **Add a log fragment** under `agent/log/` (`## [YYYY-MM-DD] spec | <feature> | Requirements brief authored` — ADR 0062; append to `agent/log.md` only in pre-0062 repos). Do **not** hand-edit `index.md` or any README — `index.md` is generated (schema invariant #19).
9. **Hand off.** Tell the user the next step is **`hso-dataverse-architect`**, which consumes `requirements.md` and produces `spec.md` (the HOW + slice DAG), citing this brief.

## Publishing to the orchestration platform (the projection) — ONLY for engagements that run within the orchestration platform

> **This section is conditional, and the condition is hard: it applies ONLY when this project is
> actually run within the orchestration platform.** **Forge is used standalone on many engagements, and nothing in
> this skill requires the orchestration platform.**
>
> **The condition is your own tool list, not a probe of the environment** (the orchestration platform
> §2, which considered and rejected marker-file/env detection — a probe can be wrong; tool
> presence is a fact the harness guarantees):
>
> > An engagement is running within the orchestration platform **if and only if a `publish_requirements` tool is
> > registered on your session.** The orchestration platform registers it on the code sessions it dispatches,
> > and says so in your system prompt.
>
> - **Tool present ⇒ the orchestration platform engagement ⇒ orchestrated-mode.** This section **replaces step 7
>   entirely**. Do not resolve an ADO projection profile; do not create ADO work items.
> - **Tool absent, and the repo carries no orchestration-platform provenance ⇒ standalone engagement ⇒ this
>   entire section is inert.** Do not publish, do not stamp frontmatter, do not name the orchestration platform
>   in the brief. Step 7 (the ADO projection profile,
>   [ADR 0051](../../../agent/wiki/decisions/0051-ado-process-profile-abstraction.md)) is the
>   whole story and no orchestration-platform dependency exists. **Do not ask the user whether they use
>   the orchestration platform** — the silent tool list already answered.
> - **Tool absent, but the repo shows the orchestration platform provenance** — a brief stamped `orch_brief_id`,
>   a brief marked "Tracked in the orchestration platform", or the user has said this engagement runs in
>   the orchestration platform — **a human is running the skill outside an orchestration-platform session on an orchestration-platform engagement.**
>   Follow "If there is no `publish_requirements` tool" below; do **not** fall back to step 7.

**In an orchestration-platform engagement, Forge never communicates with Azure DevOps directly.** Work items
are published to the orchestration platform only; the platform → DevOps sync owns everything downstream — which is
also what lets the orchestration platform target other trackers (Jira, etc.) later without any Forge-side
change. A repo-side ADO projection in an orchestration-platform engagement forks the review and bypasses that sync —
never do it, not even as a fallback when the tool is missing.

A brief authored in this repo is a file; the orchestration platform has no work-item rows for it, so its Analyze
surface has nothing for the consultant to review and the existing the orchestration platform → ADO sync has nothing to
ship. **Publication is a projection, not a handover** — the deliberate divergence from
`hso-dataverse-architect`'s spec publication (the orchestration platform's ownership transfer): each
publish stores the brief verbatim as a searchable knowledge source and creates one Draft
**Feature** work item plus one Draft **Requirement** work item per FR (parented under it) on the
the orchestration platform Analyze surface, where a consultant reviews and confirms; confirmed items flow to ADO through
the orchestration platform publish pass. **The brief file stays repo-owned**: its `draft → active` sign-off
lifecycle is untouched — only the review-and-sync records move to the orchestration platform.

**When.** Publish each **finished feature brief** — FRs settled, map-or-propose pass done — and
**before you open the pull request**, so the stamp and the recorded map ride the authoring PR.
**Skip briefs with no FRs** (e.g. an `00-Overview` brief): the tool refuses them
(`kind: invalid`).

### If a `publish_requirements` tool is available — use it, and skip step 7 entirely

Its presence means you are running **inside** an platform-hosted session, which publishes
in-process: no sign-in, no token, no script. (the orchestration platform also states this in your system
prompt.) **In orchestrated-mode no ADO projection profile is resolved or required** — the repo-side
profile (ADR 0051) is the standalone path only; ADO ids are assigned later by the orchestration platform publish
pass, after consultant review.

One call publishes one brief:

```
publish_requirements(
  briefPath: "agent/work/specs/<Feature>/requirements.md",  // repo-relative, must resolve under agent/
  featureTitle: "Order Intake & Fulfillment",               // the FEATURE NAME — never the brief's title: frontmatter verbatim (rule below)
  requirements: [                                           // one entry per FR in the brief
    { frId: "FR-1",                                         // the brief's own identifier — the idempotency key
      title: "<solution-neutral outcome>",                  // ≤500 chars
      description: "<FR body>",
      processTag: "BPC:65.20.025.000",                      // the FR's BPC tag, verbatim (step 5b)
      sourcePaths: ["<traceability target>"] } ],
  rationale: "<optional one line>"
)
```

- **`featureTitle` is the feature's name, not the document's title.** The brief's `title:`
  frontmatter reads `"Requirements Brief — <Feature Name>"` (the template scaffolds it that way);
  passed verbatim, it titles the orchestration platform Feature work item — and every ADO Feature the orchestration platform publish
  pass later creates — "Requirements Brief — …". Derive it from the brief: take the `title:` frontmatter's
  text **after the `"Requirements Brief — "` prefix** (equivalently, after the first ` — `
  separator), verbatim — ampersands, commas, and intra-word hyphens intact. No separator in the
  title → use the whole title; no usable title at all → humanize the containing folder name
  (`01-Order-Intake-and-Fulfillment` → "Order Intake and Fulfillment") as the lossy last resort
  (slugs drop `&`/commas and flatten hyphens in words like "Multi-Year"). Never add a new
  frontmatter key for this — existing briefs already encode the name.
- You do not pass a project id, the markdown, or the repo path — the session already knows them,
  which is also why the tool cannot publish to any project but this one's. `processTag` carries
  the FR's BPC tag verbatim (`BPC:<ProcessSequenceId>` / `BPC:proposed:<key>` / `BPC:unmapped`).
- Every `frId` must appear **verbatim** in the brief markdown — the tool refuses
  (`kind: invalid`) a payload that diverges from the committed file. Publish the brief as
  written; never invent or renumber FR ids in the call.
- **Create your working branch first.** A freshly bootstrapped workspace sits on a detached HEAD;
  the tool refuses there (`kind: invalid`) because a stamp committed onto a detached HEAD is
  unreachable.
- On success the tool stamps `orch_brief_id: <id>` into the brief's frontmatter (bumping
  `updated:`; **`status` is NOT flipped** — the sign-off lifecycle stays repo-owned) and commits
  that stamp **path-scoped**, leaving your other staged and in-flight work exactly as it was.
- **Then record the returned FR → work-item map** in the brief's **ADO Tracking** section, as its
  own commit: mark the brief "**Tracked in the orchestration platform** — consultant review pending; ADO ids
  assigned by the orchestration platform publish pass", one map row per FR with the returned the orchestration platform work-item id.
  Triage and attribution resolve through that map, same as standalone.
- **Re-publication is legal any time** — just call the tool again after editing the brief. Draft
  rows in the orchestration platform are refreshed in place; rows a consultant has already decided (Confirmed /
  Rejected / Published / PublishFailed) are **never touched** — the payload reports them `held` —
  and FRs removed from the brief are reported `orphaned` (their rows kept, never deleted). If a
  held row matters, tell the user: the consultant reopens it in the orchestration platform; do not try to force it from
  the repo side. A byte-identical re-publish is a no-op — zero rows, zero bytes, zero commits.
- Refusals come back as `{ error, kind }` with `kind` one of `conflict`, `notFound`, or `invalid`
  (bad path, missing `type: spec` frontmatter, no FRs, unknown `frId`, detached HEAD). If the
  response reports the stamp was written but **not** committed, commit that file yourself — do
  **not** call `publish_requirements` again to "fix" it, or you risk a duplicate publication.

### If there is no `publish_requirements` tool — but this is an orchestration-platform engagement

*(You only reach this case through repo provenance or the user's say-so — see the gate above;
with no tool and no orchestration-platform provenance, this section never applied and step 7 governs.)*

There is **deliberately no script or HTTP fallback** for requirements (unlike spec publication's
vendored `Publish-SpecToPlatform.ps1`): the only publisher is the dispatch-authorized in-session tool.
Note each finished brief as **unpublished to the orchestration platform** and hand the list to the operator —
the next the orchestration platform-dispatched session over this repo publishes them. Do **not** resolve an ADO
projection profile as a workaround: the review surface is the orchestration platform, and a repo-side ADO
projection would fork the review and bypass the platform → DevOps sync.

**After.** The rows land in the orchestration platform as Draft under your feature; Project Home counts them immediately
("0 of N work items confirmed") and the consultant reviews and confirms on the Analyze surface.
Confirmation and the ADO publish (with feature → FR parent links) happen in the orchestration platform — nothing
further to do from the repo.

## Critical rules

### DO
- ✅ Write **system-agnostic** requirements (outcomes, rules, constraints, acceptance).
- ✅ **Map or propose** a BPC process for every FR — an untagged FR without a written reason is a defect (ADR 0047).
- ✅ Allocate configuration/reference-data establishment and admin maintenance to the feature whose **entry behavior depends on it** (step 5c) — migration features own only the loading of history.
- ✅ Surface SOP implications as **requirements/assumptions**, with the source noted.
- ✅ Grade every FR on **two independent axes** — source authority (from the Stakeholders/authority register) and corroboration confidence (weakest link) — and write the `*Source:*` line (step 3a). A partner-floated idea is a **proposal**, never an FR.
- ✅ Emit **wiki frontmatter** (`type: spec`) on the brief and **add a log fragment under `agent/log/`**.
- ✅ Track ADO projection and delegate it to **`hso-ado-work-items`**; record work-item IDs.
- ✅ In an orchestration-platform engagement (a `publish_requirements` tool registered on your session), publish each finished feature brief in-session and record the returned FR → work-item map — no ADO projection profile in orchestrated-mode.
- ✅ Hand off to `hso-dataverse-architect`.

### DO NOT
- ❌ Design the implementation — no tables, columns, forms, views, plugins, flows, roles, or slice DAG (that's the architect).
- ❌ Emit a horizontal "Implementation Approach / Phase 1–2" plan (ADR 0018 anti-pattern).
- ❌ Use the retired numbered layout (`agent/04_specs/`, `agent/02_analysis/`, `agent/03_digests/`).
- ❌ Hand-edit `index.md`/README (linter-owned, invariant #14).
- ❌ Add the `**Status**: Not Started` work-status line to the brief — that belongs on the architect's `spec.md`, not the brief.
- ❌ Create ADO work items without confirming the engagement uses ADO; let `hso-ado-work-items` determine the type.
- ❌ Build catalog storage, an import UI, or a scoping surface — you carry or propose mappings against a supplied catalog; the catalog machinery lives in the orchestration platform (ADR 0047 non-goal).
- ❌ Author or overwrite fit-gap verdicts — carry them read-only when the orchestration platform or a catalog export supplies them (the fit-gap ladder is the orchestration platform Stage 3).
- ❌ Number a custom-process proposal at proposal time — proposals are unnumbered; the permanent HSO-namespace id is minted at approval/ratification ([ADR 0050](../../../agent/wiki/decisions/0050-custom-processes-numbered-hso-namespace.md)); never mint numeric-band ids.
- ❌ Assume a project's work-item format or hard-code a type — the ADO process profile is read from (or recorded into) `agent/wiki/system/ado-projection-profile.md` per [ADR 0051](../../../agent/wiki/decisions/0051-ado-process-profile-abstraction.md); every projection dimension (FR type, AC home, parenting) comes from the canonical profile ([ADR 0049](../../../agent/wiki/decisions/0049-new-format-consumer-project-profile.md) remains the authority on the `hso-us-new-format` profile's content).
- ❌ Communicate with Azure DevOps directly in an orchestration-platform engagement — work items go to the orchestration platform only; the platform → DevOps sync owns the tracker (and is what will let the orchestration platform support Jira and others without Forge changes).

## Reference Files

| Reference | Read when | File |
|---|---|---|
| Requirements Brief template | Writing any brief | [references/requirements-brief-template.md](references/requirements-brief-template.md) |
| BPC map-or-propose contract | The map-or-propose pass (step 5b) and ADO projection | [references/bpc-process-mapping.md](references/bpc-process-mapping.md) |

## Related

- [ADR 0022](../../../shared/dv/agent/wiki/decisions/0022-review-findings-drive-build-remediation-loop.md) — the delivery flow this skill is step 2 of.
- [ADR 0023](../../../shared/dv/agent/wiki/decisions/0023-requirements-and-spec-separate-artifacts.md) — requirements brief vs design spec; the two status axes.
- [ADR 0015](../../../shared/dv/agent/wiki/decisions/0015-skill-sop-reference-contract.md) — the SOP-reference contract this skill follows.
- [ADR 0047](../../../shared/dv/agent/wiki/decisions/0047-bpc-aligned-portable-requirements.md) — requirements are BPC-aligned and portable across Forge and the orchestration platform (the map-or-propose contract).
- the orchestration platform (repo "the orchestration platform") — in-session publication is authorized by the dispatch; **tool presence is the detection contract** that gates § Publishing to the orchestration platform (marker-file detection was rejected there; Forge [ADR 0056](../../../agent/wiki/decisions/0056-project-marker-defines-an-engagement.md)'s `agent/orchestration-project.json` was never written by the orchestration platform provisioning and is not this skill's gate).
- `hso-dataverse-architect` — consumes the brief, produces the spec + slice DAG (the HOW).
- `hso-dataverse-solution-map` — the upstream step (Presales Playbook Stage 3 — Shape) when the solution shape is not decidable in one sitting; its Solution Map Summary is this brief's context (workflow step 2a).
- [Source Authority and Evidence Grading SOP](../../../shared/dv/agent/wiki/sop/requirements-engineering/source-authority-and-evidence-grading-best-practices.md) — the authority register, the two grades, and the recording contract this skill applies in step 3a (rows `DV-REQUIREMENTS-ENGINEERING-001..003` in the override registry, `PROPOSED`).
- `hso-grill-architect` — the design-gate interview (architect side), distinct from this skill's system-agnostic clarifying questions.
- `hso-ado-work-items` — projects the requirements into Azure DevOps when the engagement tracks them there.
- `hso-wiki-ingest-transcript`, `hso-wiki-ingest-discovery-artifact` — produce the digests this skill consumes.
- `hso-ai-leverage-review` — supplies the per-requirement AI-disposition consumed in step 5a ([ADR 0035](../../../shared/dv/agent/wiki/decisions/0035-ai-leverage-review-and-spec-time-disposition.md)).

<!-- Change history lives in the sibling CHANGELOG.md (local ADR 0021), never in this file. Creation recorded in agent/log.md (2026-06-05). -->

