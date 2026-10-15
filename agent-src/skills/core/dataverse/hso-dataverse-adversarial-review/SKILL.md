---
name: hso-dataverse-adversarial-review
layer: orchestration
scope: core
description: Delivery-time adversarial review of a built Dataverse feature — walks the requirements brief's scenarios as its personas against the live environment with an explicit mandate to BREAK the story, never confirm it. Use at feature close or wave close, or when asked to "adversarially review", "red-team the build", or "try to break the feature". Finds unreachable artifacts, missing command surfaces, meaningless demo data, and unverified promises; produces a routed findings report (md + json). Read-only by default; creates no work items.
---

# Dataverse Adversarial Review

Every standard delivery gate is **confirmatory**: executors prove acceptance lines true, orchestrators read back structure, env validation proves declared behaviors, unit suites stay green, PR review covers code. Nobody is tasked with *failing* the build — so gaps the contract forgot stay invisible until a human stumbles on them. This skill is that missing gate. It reviews one delivered feature against its requirements brief and spec, **as the brief's personas, against the live environment**, hunting for the classes of gap that confirmatory verification structurally cannot find:

1. **Unreachable artifacts** — built, published, registered… and invisible, because no navigation points at them.
2. **Missing command surfaces** — server operations a user is supposed to invoke, with no button/script path to invoke them.
3. **Meaningless demo semantics** — views, charts, and dashboards that are well-formed but return empty, flat, or degenerate data that cannot tell the story the brief promises.
4. **Unverified promises** — requirement-level claims that no acceptance line ever actually walked.
5. **Standards violations** — designs and builds that satisfy the spec's own promises while violating HSO's mandatory SOPs. The spec is NOT the only yardstick: a spec that is wrong-by-standards looks internally consistent, and every spec-anchored check passes right through it.

**Output is triage input for the architect** — a structured findings report (markdown + JSON). This skill NEVER auto-creates work items, and by default NEVER writes to the environment.

## When to use this skill

- A feature (or a wave of features) has passed its slice acceptance and someone must now try to break it.
- The user says "adversarial review", "red-team this feature", "try to break the build", "persona walk", or "what did we forget to verify?"
- Before a demo or UAT: "will this survive a real user?"

## When NOT to use

- Code review (use `hso-plugin-code-review`) or solution-diff analysis (`hso-analyze-dataverse-solution-changes`).
- Re-running slice acceptance — that is the executor's confirmatory job; this skill assumes acceptance already passed and asks what acceptance never covered.
- Design-time challenge of an unbuilt spec (use `hso-grill-architect`).

## Configuration and inputs

Read from `CLAUDE.md`: **Environment URL** · **Default solution** · **Publisher prefix**.
Read from `CLAUDE.local.md`: nothing required (auth is settings-resolved; never hardcode credentials).

**Model:** run this review on the best available frontier model (**Fable, else Opus**) at **high effort** — review correctness is load-bearing; a read gap produces a wrong verdict (ADR 0022 model policy; canonical table in [`hso-dataverse-delivery-pipeline`](../hso-dataverse-delivery-pipeline/SKILL.md)). **Harness translation ([ADR 0052](../../../agent/wiki/decisions/0052-copilot-custom-agents-artifact-class.md)):** on GitHub Copilot CLI this review is dispatched to the **`hso-adversarial-reviewer`** custom agent — "Fable, else Opus" = the strongest Claude in the harness's model picker, "high effort" approximated by model + prompt emphasis (no `reasoningEffort` frontmatter yet); the dispatcher verifies the pin took per the pipeline's Harness mapping section. Running this review on a mid-tier model is a contract violation, not a degraded mode.

Per-run inputs (all project specifics arrive HERE — none are baked into this skill):

| Input | Required | Description |
|---|---|---|
| `SpecPath` | yes | The feature's `spec.md` (design decisions, declared artifacts, slice register + acceptance column) |
| `BriefPath` | yes | The feature's requirements brief (`requirements.md` — FRs/NFRs, stakeholders/personas, requirement-level acceptance boxes) |
| `AppUniqueName` | yes | Unique name of the model-driven app the personas live in |
| `OutputDir` | yes | Where `findings.md` + `findings.json` land |
| `Mode` | no | `ReadOnly` (default) or `WriteProbes` (explicit opt-in — see Env discipline) |
| `KnownFixedLog` | no | List of one or more paths to remediation evidence (log entries, scripts) for gaps already fixed — used to suppress re-flagging, not to skip verification |

If a required input is missing, ask — never guess.

## Mindset — the rules of engagement

- **Break the story.** Your mandate is to make the feature fail a real user. A run that finds nothing must prove it earned that verdict (the pass-evidence appendix), not assume it.
- **The standards outrank the spec.** The spec and brief define what was promised; the mandatory SOPs define what is *right*. Family F judges both the spec's design decisions and the built artifacts against the SOPs — a build that faithfully implements a standards-violating spec is a finding (owner `spec-gap`), not a pass. **This is the review's foundation: a review that did not load the mandatory SOPs is invalid**, no matter how many spec-anchored checks it ran.
- **Every walk starts at "where do I click?"** A persona starts at the app's landing page, not at a record URL. If you cannot navigate to the artifact through the sitemap/forms/commands a persona sees, the artifact is not delivered — no matter what exists in metadata.
- **Personas come from the brief.** Derive them from the Stakeholders table and FR wording (e.g. case analyst, finance-office user, approver, external-party steward, admin). Walk each FR as the persona the FR names, including the failure paths: when the system blocks the action, does the persona *see* the blocking message?
- **The environment is the truth.** Specs say what was intended; the env says what is. A gap that has already been fixed in the env is NOT a finding (record it under Accepted/Fixed). A spec promise the env doesn't honor IS a finding even if every acceptance line passed.
- **Evidence or it didn't happen.** Every finding carries the exact query/script invocation, the relevant response excerpt, and a UTC timestamp. Every clean check is recorded too (pass-evidence appendix) — "no findings" without evidence of the search is itself the anti-pattern this skill exists to kill.
- **Concurrent lanes may be moving the env.** Timestamp all evidence and RE-VERIFY every finding against fresh state immediately before it goes in the report; drop anything that no longer reproduces.

## Workflow

### Phase 0 — Intake: build the claim register

1. Read the brief: extract personas (Stakeholders table), every FR/NFR, and the requirement-level acceptance boxes.
2. Read the spec: extract every **declared artifact** (tables, columns, views, charts, dashboards, forms, Custom APIs, flows, web resources), every **user-invocable operation**, the slice register's **acceptance column**, and every **explicitly recorded boundary/deferral** (e.g. "deferred to upgrade X", "deliberately unsurfaced because Y") with its rationale.
3. Produce the **claim register**: one row per user-visible claim — `claim | source (FR/KD/slice) | persona | artifact(s) | acceptance line that covered it (or NONE)`.

### Phase 1 — Env inventory (read-only)

Inventory what actually exists, scoped to the app: app components, sitemap XML, views, charts, dashboards, forms (+ event wiring), Custom APIs, modern commands (`appaction`), classic ribbon customizations, web resources, flows. **Authority for every query in Phases 1–5: [references/check-recipes.md](references/check-recipes.md) — read it before executing checks.** Capture the inventory as JSON snapshot files under `OutputDir/evidence/` in as few batch script invocations as practical (the recipes' mandatory execution pattern); analyze from the files, and hit the env live again only for data probes and finding re-verification.

### Phase 2 — Check family A: Surfacing

Every user-visible artifact in the claim register must be reachable: a sitemap subarea (entity, URL, or dashboard-hub), a form tab/subgrid, a dashboard component, or a spec-recorded "deliberately unsurfaced + why". Built-but-unreachable = finding.

**A-0 — App-membership sweep (table-level, mandatory, independent of the claim register).** Before walking claims, diff **every table the spec declares** — `spec.json` `newTables[]` ∪ every sitemap `subAreas[].entity` ∪ every `app.unsurfacedTables[].table` — against the app's `appmodulecomponents` rows of `componenttype eq 1` (Entity; `objectid` = the entity table's `entityid`), and run `ValidateApp()`. A spec table absent from the app is an **S1 family-A finding, owner `build-gap`, routed to the app/sitemap assembly slice** — regardless of whether any FR claim names that table (config/reference tables rarely appear in an FR, which is how 13 of them stayed absent through round 3 and a failed remediation). Record the sweep as one pass-evidence row listing the count checked. Recipe in [references/check-recipes.md](references/check-recipes.md) § A-0.

### Phase 3 — Check family B: Command surface

Every user-invocable Custom API / bound operation must have a click path for its persona: a modern command (`appaction`) or classic ribbon button, wired to a **deployed** web resource whose function actually calls the API, visible on the form/grid the persona uses. A runtime invoker (flow, admin script) does NOT satisfy a *user-facing* operation. If the brief/spec declare no user-invocable operations, record one pass-evidence line — "Family B vacuously passed — no user-invocable operations declared" — and continue.

### Phase 4 — Check family C: Demo/data semantics

For every view, chart, and dashboard cell: execute its actual query and judge the dataset **meaningful, not just well-formed**. Empty result sets, single-group "distributions", count-only measures where the FR promises amounts, trend datasets spanning fewer periods than promised, and all-identical values are findings (severity per the rubric). The per-chart **measure audit table** in the recipes is mandatory output — every chart gets a measures-vs-promise row in pass evidence; degeneracy probes never substitute for it.

### Phase 5 — Check family D: Persona scenario walks

FR by FR, walk the scenario as its persona from app navigation to completion — structurally (sitemap → view/form → fields/commands → outcome read-back) in `ReadOnly` mode; behaviorally (actually invoke the operation) only in `WriteProbes` mode. Include failure paths: trigger (or trace) the blocking condition and verify the persona would SEE the refusal, not just that the server refused.

**D-gates — every status / completion gate is probed on all three mutation paths.** For each rule the spec or brief states as gating a status transition or protecting gated columns on completed records, probe (`WriteProbes`) or trace (`ReadOnly`: the plugin steps' messages + filtering attributes + stage, business-rule scope, and any Custom API the form calls) **three** paths — **(1) Create with the non-default / terminal status**, **(2) the Update transition without prerequisites**, **(3) post-transition mutation of gated columns / deletion of a required child on a record already in the terminal status**. A gate registered on `Update` alone, or whose filtering attributes exclude the gated columns, is bypassable on paths 1 and 3 — an **S2 family-D finding** (`build-gap` when the spec named the path, `spec-gap` when the spec's acceptance omitted it). Round-2 F-04 → round-3 F-04 was this exact bypass twice; the executor now walks all three (slice-consumption contract), and this probe is the independent check.

### Phase 6 — Check family E: Acceptance-gap analysis

Diff the brief's promises against what any acceptance line **ever actually verified**. Three sub-checks: (1) promises with NO acceptance line; (2) acceptance lines that were never walkable (the artifacts the line presupposes — e.g. a scoped test user — never existed); (3) acceptance lines that verified existence where the promise is behavior. Cite the acceptance text verbatim in each finding.

### Phase 6b — Check family F: Standards conformance (MANDATORY — the review's foundation)

Families A–E judge the build against the spec/brief. Family F swaps the yardstick: judge **both the spec's design decisions and the built artifacts** against **HSO's mandatory SOPs** — because a spec that is wrong-by-standards is internally consistent, and only this family can catch it.

1. **Resolve the mandatory SOPs** for every area the feature touches (data modeling, forms/views/app, dashboards, Custom API, plugin, security, flows, naming, config/migration data) from the architect skill's index: [`hso-dataverse-architect/references/sop-index.md`](../hso-dataverse-architect/references/sop-index.md).
2. **Load and read them** — in this review's context. The spec's Sources section is a claim to verify, never a substitute for your own read.
3. **Review against them.** The defect classes this family exists to produce: admin-maintained reference lists shipped as free-text columns instead of config tables (data-modeling SOP §9 posture rule), custom party tables where Account/Contact was owed, missing config tables and their load slices, choice/ownership/cascade violations, lifecycle modeled as custom flags, forms authored outside the form SOP's patterns. A spec decision that violates a mandatory SOP is a finding with owner `spec-gap` even when the build implements it perfectly.
   **F-security — three explicit checks, every run, whenever the feature adds columns to any table** (security SOP [§11 *Sensitive-identifier columns — the default posture*](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md), [§14 *Auditing*](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md); form SOP §7; data-modeling SOP §5 required level). Recipes in [references/check-recipes.md](references/check-recipes.md) § F-security:
   - **F-sec-1 Sensitive identifier exposed.** Any column whose name/description/type carries SSN / national id / tax id / FEIN / bank / routing / DOB / passport / licence / health id that is **not** `IsSecured = true` with an FSP, **or** appears as a Quick Find find-column (`isquickfindfields`) / Quick Find display column / a general public view column ⇒ **S1**, owner `spec-gap` when the spec never secured it, `build-gap` when it did. Round-3 shipped an SSN column readable org-wide and on Quick Find.
   - **F-sec-2 Auditing off on the aggregate root.** The table the feature's approval / financial process lives on (the spec's aggregate root — Contract, Application, Case) has `IsAuditEnabled = false` and no recorded exception ⇒ **S2**, `spec-gap`. Children audited while the root is not is the smell.
   - **F-sec-3 Required column added to an OOB table absent from the persona's form.** Every `RequiredLevel = ApplicationRequired | SystemRequired` column the feature added to `account` / `contact` / any OOB table is present in the `formxml` of the form the persona saves from (the HSO extension form, or the OOB form the app uses) ⇒ absent = **S2**, `build-gap` (`spec-gap` when the spec never named the form). Silent un-enforcement, or a save the persona cannot complete — both are the finding.
4. **Ground the verdict.** Every family-F finding cites the SOP section violated (verbatim); the report's **Standards grounding** section lists every SOP loaded, with sections, per area. **A findings report without a non-empty Standards grounding section is an invalid review** — the dispatching orchestrator must reject it and re-dispatch, and the pipeline ledger records the SOP list with the Stage-2 entry.

### Phase 7 — Report

1. Dedupe by root cause (one finding per cause, all affected FRs listed on it).
2. Severity + owner routing per the rubric — **authority for report structure, JSON schema, severity rubric, and routing: [references/report-template.md](references/report-template.md) — read it before writing the report.**
3. Re-verify every finding — and every Fixed-before-review confirmation — with a **fresh live query at report time** (new timestamps); same-run snapshots never count as re-verification. Drop non-reproducers.
4. Write `findings.md` + `findings.json` to `OutputDir`, including the **Accepted boundaries** section (spec-recorded deferrals confirmed as recorded, not flagged) and the **pass-evidence appendix**.

## Task → primary authority

| Task | Authority (read before doing) |
|---|---|
| Executing any env check (Phases 1–5) | [references/check-recipes.md](references/check-recipes.md) |
| Writing findings, severity, routing, JSON (Phase 7) | [references/report-template.md](references/report-template.md) |
| Running record-data queries | `hso-dataverse-data` skill's `Invoke-DataverseDataOperation.ps1` (the only sanctioned data path) |

## Env discipline

- **Read-only by default.** All checks in `ReadOnly` mode are GET/queries via the shared scripts. No create, update, delete, publish, or settings change — ever — in this mode.
- **`WriteProbes` is an explicit opt-in** (the user or orchestrator must request it by name). Every write probe follows **create → assert → delete → read back the absence** (audit-enabled orgs retain history; leave no test residue). Announce write probes in the project's coordination log before running them if the project runs concurrent lanes.
- **NEVER touch security configuration** — no role, privilege, BU, or team writes, in any mode. Scope verification is read-only analysis (role privileges + BU placement read-back), or routed to a manual finding.
- **NEVER flag empty `executeprivilegename` on Custom APIs.** Architect ruling: table privileges govern; the platform has no real per-API privilege model. Review checklists must not raise it.
- Invoke all skill scripts **in-process with the `&` call operator** (never `powershell -File` — it hangs, flattens arrays, and stringifies booleans).
- Retry-wrap metadata reads for transient 429s; honor `Retry-After`.

## False-positive guards (noise ban list)

A finding survives only if a named persona hits it on a promised path. Do NOT flag:

- Spec-recorded deferrals/boundaries with rationale (record under Accepted boundaries instead — but DO flag when the env fails even the recorded boundary).
- **In-flight slices.** A slice the project's tracking (work items, coordination log) shows as open/not-yet-delivered is work in progress, not a gap — record it under Accepted boundaries as "in-flight" with the tracking evidence. The review targets delivered scope.
- Already-fixed gaps (env is the truth; cite the fix under Accepted/Fixed). `KnownFixedLog` lists candidates; verify the fix live rather than re-flagging.
- Empty `executeprivilegename` (see above).
- Admin/runtime-only artifacts that no persona path uses (flows, plugin steps) for *surfacing* — they are checked under behavior, not navigation.
- Style/naming/internal-structure nits — out of scope; route to code review.
- Anything you could not reproduce on re-verification.

## Outputs

- `OutputDir/findings.md` — human triage report (structure per [references/report-template.md](references/report-template.md)).
- `OutputDir/findings.json` — machine-readable findings (schema per the same reference).
- No work items, no log entries, no env writes (unless `WriteProbes`), no commits — the invoking orchestrator owns all of those.

**Delivery-flow handoff:** when this review runs as part of the end-to-end delivery flow (ADR 0022), hand `findings.json` to [`hso-dataverse-triage-remediation`](../hso-dataverse-triage-remediation/SKILL.md) — it triages, dispatches conformance fixes, owns the ADO Bug lifecycle, and presents only escalations to a human.

## Critical rules

**ALWAYS:**
- Walk every FR as its persona, starting from app navigation.
- Load the mandatory SOPs for every area the feature touches (family F) and list them, with sections, in the report's Standards grounding section — a review without it is invalid.
- Record evidence (query + excerpt + UTC timestamp) for findings AND passes.
- Re-verify findings against fresh state before reporting.
- Route every finding to exactly one owner class (spec-gap / build-gap / data-gap / manual-followup).
- Use settings-resolved auth via the shared scripts; headless only.

**NEVER:**
- Confirm the story — your job is to break it.
- Write to the env in `ReadOnly` mode, or touch security config in any mode.
- Flag `executeprivilegename`, recorded deferrals, or fixed gaps.
- Auto-create PBIs/work items.
- Echo secrets, tokens, or connection strings into commands or output.

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
