# Document Templates

Read this file when creating analysis documents or feature specs. These templates ensure consistent structure across all architectural deliverables.

## HSO Standard: Every Component Has a Description

Every table, column, lookup, global choice, alternate key, form, view, model-driven app, and solution proposed in a spec **must** carry a non-empty `Description` field. The downstream build skills (`hso-dataverse-data-modeling`, `hso-dataverse-ui-config`) warn on creation when a component arrives without one. For columns the description renders as the **tooltip** in model-driven apps (the maker portal documents this explicitly: *"These descriptions appear as tooltips for the user in model-driven apps when they hover their mouse over the label of the column."*) — a missing description on the spec is a missing tooltip in production.

The component tables below all include an explicit `Description` column. Do not ship a spec with `(TBD)` or empty descriptions; resolve them before the spec is approved.

See [`shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md` §24](../../../../agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md), the form SOP §27, and the view SOP §16 for the methodology.

## Analysis Document (save to `agent/work/analysis/`)

```markdown
# [Feature Name] Analysis

## Executive Summary
## Current State
## Requirements Analysis
## Technical Evaluation
## Data Model Considerations

### Proposed Tables

| Schema Name | Display Name | Ownership | Description |
|-------------|--------------|-----------|-------------|
| `hso_<tablename>` | <Display Name> | UserOwned / OrgOwned | What this table represents in business terms; why it exists. |

### Proposed Columns (with naming suffixes)

| Table | Schema Name | Display Name | Type | Required | Description |
|-------|-------------|--------------|------|----------|-------------|
| `hso_<tablename>` | `hso_<fieldname>_<suffix>` | <Display Name> | <Type> | None / Recommended / Required | Tooltip text shown when users hover the column label in model-driven apps. Phrase as user-facing instruction. |

### Relationships and Cascade Settings

| Type | Parent → Child | Lookup Schema Name | Lookup Display Name | Cascade (Delete / Assign) | Description |
|------|----------------|---------------------|----------------------|----------------------------|-------------|
| 1:N | `hso_project` → `hso_task` | `hso_project_id` | Project | RemoveLink / NoCascade | Description on the lookup column — what the relationship represents from the child's perspective. |

### Global Choices Required

| Schema Name | Display Name | Description | Options (Label) |
|-------------|--------------|-------------|-----------------|
| `hso_<choicename>` | <Display Name> | What this choice classifies; what each option means at a high level. | Draft, In Progress, Completed |

## Risk Assessment
## Recommendations
## Sources, References, and Research Methodology
<!-- Required for every analysis. See guidance below. -->
```

## Feature Spec (save to `agent/work/specs/[FeatureName]/`)

The full feature-spec template is below. It builds on the upstream **Requirements Brief** (`requirements.md`) authored by `hso-requirements-author` — cite that brief in the spec's `sources:`. Key sections:

```markdown
---
title: "Spec — [Feature Name]"
type: spec
status: draft
scope: project
client: [client-id]
project: [project-id]
topics: []
people: [author-slug]
sources: [requirements.md]            # the Requirements Brief this spec builds on
supersedes:
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# [Feature Name]

**Status**: Not Started | **Last Updated**: [Date]
<!-- Two status axes (ADR 0023): frontmatter status: = document lifecycle; the **Status** line above
     = work lifecycle that executor skills gate on ("Completed → STOP"). The Requirements Brief carries
     frontmatter only; this spec carries BOTH. -->

## Purpose
## Business Value
## Requirements
### Functional Requirements
### Technical Requirements

## Data Model

> Every component table below carries a `Description` column. Descriptions are mandatory — they propagate into the Dataverse metadata at build time and (for columns) render as field tooltips in model-driven apps.

### Tables

| Schema Name | Display Name | Ownership | Activities / Notes | Description |
|-------------|--------------|-----------|---------------------|-------------|
| `hso_<tablename>` | <Display Name> | UserOwned | yes/no / yes/no | Business-meaning of the table; why it exists. |

### Columns

| Table | Schema Name | Display Name | Type | Required | Description |
|-------|-------------|--------------|------|----------|-------------|
| `hso_<tablename>` | `hso_<fieldname>_<suffix>` | <Display Name> | <Type> | None / Recommended / Required | Tooltip shown to users in model-driven apps. |

> **Rollup / formula columns are buildable headlessly ([ADR 0057](../../../../agent/wiki/decisions/0057-specialized-columns-via-formuladefinition-write.md))** — declare the full definition so the executor can compile it, never a bare `Type: Rollup`:
>
> - **Rollup:** state the child table, the 1:N relationship schema name, the child lookup column, the aggregate (`Count` default; `Sum`/`Min`/`Max`/`Avg` name the aggregated child column — the rollup's type mirrors it), and any filter as a **single Equal condition** on `statecode`/`statuscode`/a choice column (e.g. "Count of `hso_assetcoverage` via `hso_serviceagreement_assetcoverage` where `statuscode` = Covered"). Richer filters are still maker-portal — say so explicitly. Limits: ≤ 10 rollups per table, 1:N only, no rollup-over-rollup.
> - **Formula:** state the Power Fx expression verbatim and the result type (`String`/`Decimal`/`Boolean`/`DateTime`); e.g. `DateAdd(hso_enddate_date, -hso_renewalnoticeleadtime_num, TimeUnit.Days)`. Formula columns are computed at read time and are **not stored/audited** — keep them off audit lists.
> - **Classic `Calculated` is deprecated and not built** — author the same logic as a formula column.
> - **Acceptance phrasing:** value assertions are allowed again ("returns the count of covered assets"), but a rollup's initial mass-calc runs ~12 h out — the acceptance/test step must force a per-record recalc via the **unbound** `CalculateRollupField` function before asserting the value. A rollup declared *without* its definition degrades to the old `[MAKER-PORTAL-TODO]` skip, and then only "definition recorded" acceptance can pass.

### Relationships

| Type | Parent → Child (or Entities for N:N) | Lookup Schema Name | Lookup Display Name | Cascade | Description |
|------|---------------------------------------|---------------------|----------------------|---------|-------------|
| 1:N | `hso_project` → `hso_task` | `hso_project_id` | Project | RemoveLink / NoCascade | Description on the lookup column; what the relationship represents from the child side. |
| N:N | `hso_project` ↔ `hso_resource` | n/a (intersect: `hso_project_resource`) | n/a | n/a | Purpose of the association in business terms. (Note: N:N has no Description metadata field; document here for spec traceability.) |

### Global Choices

| Schema Name | Display Name | Description | Options |
|-------------|--------------|-------------|---------|
| `hso_<choicename>` | <Display Name> | What this choice classifies. | Draft, In Progress, Completed |

### Alternate Keys

| Table | Schema Name | Key Columns | Purpose / Description |
|-------|-------------|-------------|----------------------|
| `hso_<tablename>` | `hso_code_key` | `hso_code_text` | Why this key exists (integration upsert, natural-key lookup, etc.). |

## Technical Architecture

### Data Layer
### Business Logic Layer
- Plugin architecture (Composition Root pattern)
- Service/Repository structure

#### Status / completion gates — acceptance enumerates every mutation path

<!-- Any rule that gates a status transition (Draft → Approved → Executed) or protects gated columns
     on completed records is stated as a THREE-PATH contract, and its slice's acceptance walks all three.
     A gate whose acceptance only names the Update transition was bypassed in two consecutive rounds via
     Create-as-Executed and post-Complete clears (round-2 F-04 → round-3 F-04). -->

| Gate | Guarded transition / columns | Path 1 — Create with non-default status | Path 2 — Update transition | Path 3 — post-transition mutation of gated columns | Persona sees |
|------|------------------------------|------------------------------------------|----------------------------|-----------------------------------------------------|--------------|
| Contract completion | `statuscode` → Executed requires signed date + ≥1 line | Create with `statuscode=Executed` and no signed date → **refused** | Update Draft → Executed without lines → **refused** | Clear signed date / delete last line on an Executed contract → **refused** | synchronous plugin message on the form |

Acceptance phrasing (verbatim on the slice, one clause per path): *"Create-as-Executed without signed date is refused (message quoted); Draft→Executed without lines is refused; clearing signed date on an Executed record is refused."* An acceptance line that names only one path is a Definition-of-Ready failure.

### UI Layer

> Every form and view below carries a `Description` column. Descriptions surface in maker-portal Form Properties (forms) and the view picker tooltip (views), and they provide spec traceability.

#### Forms

| Table | Form Name | Form Type | Description |
|-------|-----------|-----------|-------------|
| `hso_<tablename>` | `Client \| Main` | Main / QuickCreate / QuickView / Card | Layout philosophy + what surfaces where + intended audience. |

> **Decide the timeline per form — it is a design decision the architect owns, not a default the implementer guesses at.** For every Main form, consciously decide whether it carries a timeline (activity / notes history) and state the verdict in the Description. **If yes** — note that it goes in its own dedicated section per the [Forms SOP §9](../../../shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md). **If no** — say why (e.g. Quick Create, a child / line-item table, a table with no Notes / Activities history, or a single-control workspace). A timeline is *not* mandatory and is *not* right on every form; what is mandatory is that its presence or absence is a recorded choice here, never left unstated for the downstream `hso-dataverse-ui-config` skill to silently inherit.

#### Views

| Table | View Name | View Type | Description |
|-------|-----------|-----------|-------------|
| `hso_<tablename>` | `Active <Records>` | PublicView / QuickFind / Associated / Lookup | Filter intent (what counts as "active") + sort + key columns. |

#### Model-Driven Apps

| App Unique Name | App Display Name | Description |
|-----------------|------------------|-------------|
| `hso_<appname>` | <Display Name> | Audience + scope + which tables/areas + sitemap philosophy. |

#### App Landing Experience (required — silence is not a valid state)

<!-- Declare the app's landing experience: the dashboards this feature ships (list them in
     the Dashboards table + spec.json dashboards[], routed to hso-dataverse-dashboards and
     the dashboard SOP), OR an explicit deferral naming the owning feature, e.g.
     "Landing dashboards deferred to <feature NN — name>". An app with no declared landing
     experience and no recorded deferral fails the Definition of Ready. -->

- PCF controls (Virtual only) or Web Resources
- Form scripts: `hso_/scripts/{entity}/{entity}_form.js` with `HSO.EntityName` namespace
- Fluent UI theming requirements (PCF)

### Integration Points

## Work Decomposition (Slice DAG)
<!-- Per ADR 0018: vertical slices on a dependency graph, NOT a sequential "Phase 1 → 2 → 3" plan
     (that bakes in horizontal layer-by-layer building and delays integrated feedback).
     Lead each feature area with a capability tracer-bullet; entity slices are the default grain;
     OOB tables use extension slices (new HSO form, NEVER edit the OOB form); shared HSO artifacts
     get one downstream single-writer assembly slice; relationships are owned by side-count
     (lookup → the introducing entity/extension slice; N:N → the consuming capability slice);
     tag every slice AFK|HITL; every slice carries env-validated acceptance assertions.
     See the architect skill's "Work Decomposition Contract (Slice DAG)" section for the full rules. -->

### Slice register
| ID | Type (capability / entity / extension / foundation / assembly / ui-invocation / design) | Mode (AFK/HITL) | Owner (architect/executor) | Blocked by | Touches | Spec ref | FR refs | ADO build type | Preconditions | Acceptance (env-validated) |
|----|------|------|------|-----------|---------|---------|---------|------|------|------|
| S0 | foundation | AFK | executor | — | global choices | §x | — | Extension | — | choices exist; no local option sets |
| S0x | entity | AFK | executor | S0 | `hsot_contracttype` config table + reference-data load (**curated go-forward set: 12 rows; legacy 1,268 retired — decision recorded**) | §x | FR-2 | Data Migration | — | table exists; 12 rows upserted via code alternate key; row count reconciles to the curated source list |
| TB | capability | AFK | executor | S0 | table, form, sample | §x | FR-1 | Extension | — | thin end-to-end outcome validated against env |
| SA | assembly | AFK | executor | S0x, TB, … (every table-creating slice) | **app + sitemap** (`BuildSiteMap`: renders declared sitemap, registers every declared table as an app component) | §x | — | Extension | — | sitemap read-back matches declared order; **`[OK] app-components read-back: all N declared table(s) are app components`**; **`[OK] ValidateApp: clean`** — every `newTables[]` / subArea / `unsurfacedTables` table ∈ `appmodulecomponents` (componenttype 1) |
| SP | capability | AFK | executor | TB | Power Pages web template + site setting exposing contracts to providers | §x | FR-7 | Extension | `power-pages-site`: DCFS Provider Portal | provider persona lists own contracts on the portal page (walked live) |

**Mode column: HITL is legal only on `design` rows, and a signed spec has none** — spec approval settles every design node (see the Open Questions table below for decisions that must be *recorded*, not *waited on*). **Preconditions column** mirrors `spec.json` `slices[].preconditions[]` (`kind: detail`; `—` when none): a runtime the slice needs beyond Dataverse metadata — a Power Pages site, a deployed plugin package, a connection reference, an environment variable — probed by the pipeline's Stage-0 preflight, so a missing site halts the run with a clear ask before any slice builds (round-3 s14). Portal touches **must** carry a `power-pages-site` precondition (validator-enforced).

`ADO build type` mirrors `spec.json` `adoProjection.buildType` ([ADR 0048](../../../agent/wiki/decisions/0048-build-slices-project-1-1-into-ado-build-management.md)):
one work item per slice (never split a slice to fit a type), classified by deterministic
precedence over the slice's touches — **Data Migration › Integration › Workflow › Report ›
Security role › Extension default** (Extension covers maker-portal configuration as well
as code); `design` slices project `none`. Column `—` when the engagement does not track
build work items. The classification is **profile-independent**
([ADR 0051](../../../agent/wiki/decisions/0051-ado-process-profile-abstraction.md)): what
WIT it becomes is resolved at creation time from the project's ADO process profile — a
native Build Management item on `hso-us-new-format`, a child Task tagged `build:<slug>` on
stock profiles (ruling O1).

`FR refs` names the brief's functional requirement(s) a slice implements; the brief's ADO Tracking
map resolves them to work items, which is what lets the delivery pipeline emit born-attributed
claims for the components it builds. Foundation/assembly slices serving several FRs list them all;
`—` only when the engagement has no FR/ADO tracking.

**BPC process lineage (ADR 0047 / ADR 0048).** When the brief carries a Process Mapping
section, copy its per-FR process tags verbatim into `spec.json` `frProcessMap` **and its
`catalogRelease` into `spec.json` `catalogRelease`** (do not re-map — the brief's
map-or-propose pass is authoritative). Per-slice work items then inherit BPC lineage through
`fr_refs`: tag each slice's work item with the union of its FRs' tags (`BPC:<ProcessSequenceId>`
verbatim padded, `BPC:proposed:<key>`, or `BPC:unmapped`). Linking is **profile-dependent**
(the project's ADO process profile rules it, ADR 0051): on stock profiles, slice Tasks
parent to the FR item realizing their primary `fr_ref` (`blocked_by` as Predecessor links);
on `hso-us-new-format`, build items live in the build tree and get **optional Related
links** per build-type lineage (`adoProjection.relatedTargets`: Requirement work items for
Extension-class, the process/process-area node for Data Migration-class) — parent/child to
Requirements is impossible across trees (template-owner ruling, 2026-07-22). Omit
`frProcessMap` when the brief has no process mapping.

### Dependency graph
<!-- Small ASCII DAG of blocked_by edges. Lead with the capability tracer-bullet; show the
     single-writer assembly slice(s) where multiple slices would otherwise edit one shared artifact. -->

### spec.json sidecar (machine-readable — every grader reads this)

Emit `spec.json` beside the markdown spec. It is **strict JSON** (no comments, no trailing commas) and must pass `scripts/Validate-SpecJson.ps1` before the spec is ready — the authoritative schema is [`references/spec.schema.json`](spec.schema.json). The `slices` array mirrors the register above row-for-row (same ids, types, modes, owners, `blocked_by`, `fr_refs`, and the **verbatim** acceptance text).

**Forms-as-contract.** The architect fully specifies each Main form's layout — `tabs → lanes → sections → fields` plus the KPI `header.fields` — and each public view's `columns`, directly in `spec.json`. A Main form's `tabs` block **is** the BuildForm LayoutSpec verbatim, so the spec a human reviews and confirms before any write is exactly what `BuildAllForms` renders deterministically (no executor guesswork). Lane widths in a tab sum to 100; a section's `timeline:true` requires the form's top-level `timeline:true`. Copy this skeleton and fill it:

```json
{
  "feature": "<feature name>",
  "solution": "<solution UNIQUE NAME the executor creates — the grader discovers the build by this>",
  "publisherPrefix": "<publisher customization prefix, e.g. hsot>",
  "columns": [
    { "table": "hsot_<table>", "name": "hsot_status" },
    { "table": "hsot_<table>", "name": "hsot_owner" },
    { "table": "hsot_<table>", "name": "hsot_duedate" }
  ],
  "newTables": ["hsot_<table>", "hsot_<child>"],
  "catalogRelease": "JUL 2026",
  "frProcessMap": {
    "FR-1": { "processSequenceId": "65.20.025.000", "processName": "Enter sales orders", "levelPath": "65 Order to cash › 65.20 Manage sales orders", "status": "mapped" },
    "FR-2": { "proposalKey": "loaner-equipment", "status": "proposed-custom" }
  },
  "forms": [
    {
      "table": "hsot_<table>", "type": "Main", "timeline": true, "layoutPattern": "B",
      "formDescription": "Two-lane KPI-header layout; timeline in its own section per Forms SOP §9.",
      "header": { "fields": ["hsot_status", "hsot_owner", "hsot_duedate"] },
      "tabs": [
        {
          "name": "tab_general", "label": "General",
          "lanes": [
            {
              "width": "60%",
              "sections": [
                { "name": "sec_summary", "label": "Summary", "columns": 2, "fields": ["hsot_name", "hsot_status", "hsot_owner", "hsot_duedate"] },
                { "name": "sec_detail", "label": "Detail", "columns": 1, "fields": ["hsot_description"] }
              ]
            },
            {
              "width": "40%",
              "sections": [
                { "name": "sec_timeline", "label": "Timeline", "timeline": true },
                { "name": "sec_children", "label": "Lines", "subgrid": { "target": "hsot_<child>", "relationship": "hsot_<table>_<child>", "view": "Active <child> for this <table>" } }
              ]
            }
          ]
        }
      ]
    }
  ],
  "views": [
    { "table": "hsot_<table>", "name": "Active <table>", "type": "PublicView", "isDefault": true, "activeFilter": true,
      "columns": ["hsot_name", "hsot_status", "hsot_owner", "hsot_duedate"], "floorMin": 4, "floorMax": 8 },
    { "table": "hsot_<table>", "name": "<table> Lookup View", "type": "Lookup",
      "columns": ["hsot_name", "hsot_status"] }
  ],
  "relationships": [
    { "parent": "hsot_<parent>", "child": "hsot_<child>", "lookupOnChild": "hsot_<lookup>", "cascadeDelete": "RemoveLink", "ownedBySlice": "S3" }
  ],
  "slices": [
    { "id": "S0", "type": "foundation", "mode": "AFK", "owner": "executor", "blocked_by": [], "touches": "global choices", "fr_refs": [], "acceptance": "choices exist; no local option sets",
      "adoProjection": { "buildType": "Extension", "relatedTargets": [] } },
    { "id": "TB", "type": "capability", "mode": "AFK", "owner": "executor", "blocked_by": ["S0"], "touches": "table, form, sample", "fr_refs": ["FR-1"], "acceptance": "thin end-to-end outcome validated against env",
      "adoProjection": { "buildType": "Extension", "relatedTargets": ["FR-1"] } },
    { "id": "SA", "type": "assembly", "mode": "AFK", "owner": "executor", "blocked_by": ["TB"], "touches": "app + sitemap (BuildSiteMap)", "fr_refs": [], "acceptance": "sitemap read-back matches declared order; [OK] app-components read-back: all declared tables are app components; [OK] ValidateApp: clean",
      "adoProjection": { "buildType": "Extension", "relatedTargets": [] } },
    { "id": "SP", "type": "capability", "mode": "AFK", "owner": "executor", "blocked_by": ["TB"], "touches": "Power Pages web template + site setting", "fr_refs": ["FR-7"], "acceptance": "provider persona lists own contracts on the portal page (walked live)",
      "preconditions": [ { "kind": "power-pages-site", "detail": "<site name>", "askIfMissing": "provision the Power Pages site <site name> in the target environment before dispatch" } ],
      "adoProjection": { "buildType": "Extension", "relatedTargets": ["FR-7"] } }
  ],
  "assemblies": [
    { "artifact": "hsot_<parent> Main form", "parentForm": "hsot_<parent>", "writerSlice": "S4", "addsSubgrid": true, "subgridTarget": "hsot_<child>" }
  ],
  "sampleData": { "inScope": false, "minRecords": 0, "writerSlice": "", "tables": [] },
  "choices": [
    { "name": "hsot_<choice>", "options": [
      { "label": "Draft", "value": 100000000 },
      { "label": "In Progress", "value": 100000001, "color": "#FFAA00" },
      { "label": "Completed", "value": 100000002, "color": "#107C10" }
    ] }
  ],
  "statusReasons": [
    { "table": "hsot_<table>", "options": [
      { "label": "Draft", "state": 0, "default": true },
      { "label": "Active", "state": 0 },
      { "label": "Archived", "state": 1 }
    ] }
  ],
  "app": {
    "mode": "create",
    "title": "<App Display Name>",
    "areas": [
      { "title": "<Area>", "groups": [
        { "title": "<Group>", "subAreas": [ { "title": "<table plural>", "entity": "hsot_<table>" } ] }
      ] }
    ],
    "unsurfacedTables": [ { "table": "hsot_<child>", "reason": "line-item table reached only via the <table> form subgrid" } ]
  }
}
```

- **`columns[]` is the declared data model** — one `{table, name}` entry per custom column the spec proposes, mirroring the markdown Columns table. Required whenever forms or views are declared: the validator cross-checks every `header.fields` / section `fields` / view `columns` entry against it (plus system columns and the table's `<prefix>_name` primary) and **fails any field reference that resolves to nothing**.
- **`newTables[]` names the net-new custom tables** this spec introduces (`[]` when every publisher-owned table already exists). A non-empty list requires the dedicated `semantic-research.md` skill-run artifact in the spec folder, mentioning every listed table — the validator refuses the spec otherwise.
- **Form/view field names == the data-model column logical names (exact match); the auto-number primary is `<prefix>_name`** (e.g. `hsot_name`, never `hsot_name_auto`) — every `header.fields` / section `fields` / `columns` entry must be a column logical name declared in the data model.
- `forms[].timeline` (boolean, **required**) and `layoutPattern` (required on a Main form) must match the verdict written in that form's Description. Every Main form also carries its full `tabs` LayoutSpec and (for Patterns A/B/C) a `header.fields` KPI list (≤4); every public view declares its `columns`.
- Every view declares its `type` (`PublicView`/`Lookup`/`QuickFind`/`Associated`); a **lookup view must be `type:Lookup`** so the executor updates the table's existing lookup view instead of building a duplicate Public view.
- `sampleData.inScope:true` requires `minRecords >= 1` and a non-empty `writerSlice`; otherwise set `inScope:false` (record-population is then n/a-by-design, not a fail).
- `app.mode` is `create` (default — a NEW app) or `extend` (add to an EXISTING app by `uniqueName`; the app must already exist) — use `extend` for a non-copyable OOB app like the Customer Service workspace, which must be extended in place, not recreated.
- `app` (sitemap), `choices[]` (global option sets with explicit `value`+`color` where stability matters), and `statusReasons[]` (statuscode lifecycle with `state` + exactly one `default:true` per table) are part of the reviewable-and-rendered contract too: the architect declares → the executor renders (`BuildSiteMap` / `SetLifecycle` / global-choice render) → the grader diffs. The validator fail-closes any dangling cross-reference (a `blocked_by` / `writerSlice` / `subgridTarget` / sitemap `entity` / `statusReasons.table` that resolves to nothing), duplicate choice values, or two default status reasons.
- Every component the spec proposes still carries a non-empty `Description` in the markdown tables above.
- **`slices[].preconditions[]`** (optional per slice; `{kind, detail, probe?, askIfMissing?}`) names the environment runtimes the slice needs beyond Dataverse metadata (`power-pages-site` · `plugin-package` · `connection-reference` · `environment-variable` · `app-module` · `other` with a mandatory `probe`). Stage-0 preflight probes each and halts with `askIfMissing` before any slice builds. Required (`power-pages-site`) on any slice whose touches name a portal / Power Pages surface.
- **`app.unsurfacedTables[]`** (`{table, reason}`) records the publisher-owned tables that deliberately get **no** sitemap sub-area (subgrid-only detail tables) — they are still registered as app components by `BuildSiteMap`. Every other publisher-owned table the spec declares must be a `subAreas[].entity`; the validator fails one that is neither.
- **`slices[].mode: HITL` only with `type: design`** (validator-enforced both ways); the pipeline validates a signed spec with `-Signed`, which refuses any remaining HITL/design slice and any open Open-Question row.

## Open Questions (required section — every row dispositioned at spec approval)

<!-- Decisions the author could not settle alone. The rule (E2E round-3, the HITL/OQ episode): an OQ's
     Disposition point is "at spec approval" — the grill gate answers it — NEVER "before slice
     sN is built" / "during build" (Validate-SpecJson fails such rows outright). A signed spec has no row with
     Status = Open (Validate-SpecJson -Signed refuses it): the answer is recorded here, or the item becomes a
     dispositioned deferral with an owner. Build slices never carry mode: HITL to "wait for" an OQ. -->

| ID | Question | Status (Open / Resolved / Dispositioned) | Disposition point | Answer / owner |
|----|----------|------------------------------------------|-------------------|----------------|
| OQ-1 | Is Contract Type a config table or a global choice? | Resolved | at spec approval | Config table — data-modeling SOP §9 Type-column pattern (approver: <name>, <date>) |
| OQ-2 | Retire the 1,256 legacy programs not in the go-forward set? | Dispositioned | at spec approval | Deferred to Feature 04 data-migration close-out; owner <name>; the load slice loads the curated 12 only |

State explicitly when there are none: "No open questions — every design decision is recorded above."

## Testing Strategy
## Deployment Plan
## Risks & Mitigations
## Sources, References, and Research Methodology
<!-- Required for every spec. See guidance below. -->
```

---

## Sources, References, and Research Methodology — Guidance

**Every analysis document and feature spec MUST end with a Sources section.** This section provides a complete provenance trail so readers can trace every claim back to its origin and identify which assertions are assumptions.

### Structure

Open with a brief paragraph stating the date, source categories used, and scope of research.

Then organize references into categorized subsections. Common categories (use whichever apply):

- **Internal Discussions** — meeting digests, stakeholder conversations, email threads
- **Discovery Artifacts** — ingested documents, transcripts, client-provided materials
- **Microsoft Documentation** — official docs, guidance repos, SDK references
- **FastTrack Implementation Assets** — FastTrack patterns, reference architectures
- **HSO Internal Standards** — SOPs, skill references, best practices repo content
- **Online Research** — blog posts, community articles, third-party documentation

### Reference Table Format

Each category uses a two-column table:

```markdown
| Source | How It Informed This Document |
|--------|-------------------------------|
| `path/to/source.md` or description of source | Specific decisions, sections, or design elements this source contributed to. Be concrete — name the section or design choice. |
```

**Rules:**
- Every reference skill consulted (e.g., `hso-fieldservice-reference`, `hso-fasttrack-reference`) must appear with what it informed
- Every SOP or best-practices document referenced must appear
- Every discovery digest or transcript digest read must appear
- Every web search or online source consulted must appear
- If a source changed the direction of the design, call that out explicitly (e.g., "Critical — Changed the Architecture Direction")

### Mandatory-pre-read citations (checked by Validate-SpecJson)

For a **feature spec**, the HSO Internal Standards table is not optional garnish — it is the verifiable trace that the mandatory pre-reads actually happened. For **every area the spec touches**, cite the mandatory SOP as a bare backticked filename **with the sections used**:

```markdown
### HSO Internal Standards
| Source | How It Informed This Document |
|--------|-------------------------------|
| `dataverse-naming-conventions.md` (SOP) | Every schema name (tables, column suffixes, global choices) |
| `data-modeling-best-practices.md` §§4,5,9,10,15 | Primary-name rules, column types, config-table-vs-choice posture, statuscode lifecycle, alternate keys |
| `form-configuration-best-practices.md` §6 | Pattern selection and lane structures per form |
```

`scripts/Validate-SpecJson.ps1` **fails the spec** when a touched area's mandatory SOP is uncited, or cited without sections (naming-conventions excepted — it is read whole). The map is mechanical: tables/columns/relationships/choices/lifecycle ⇒ `data-modeling-best-practices.md` · forms ⇒ `form-configuration-best-practices.md` · views ⇒ `view-configuration-best-practices.md` · app/sitemap ⇒ `app-module-configuration-best-practices.md` · dashboards ⇒ `dashboard-configuration-best-practices.md` · Custom APIs ⇒ `custom-api-best-practices.md` · plugin touches ⇒ `plugin-development.md` · flow touches ⇒ `power-automate-cloud-flow-best-practices.md` · security touches ⇒ `security-best-practices.md` · always ⇒ `dataverse-naming-conventions.md`. Citing a SOP you did not open is a falsified trace, not a passed gate.

### Assumptions Table (Required)

After all reference categories, include an explicit assumptions table:

```markdown
### Assumptions Not Backed by Source (Require Validation)

| Assumption | Where Used | Basis | Validation Needed |
|------------|-----------|-------|-------------------|
| Description of the assumption | Section(s) where it appears | Reasoning or inference that led to the assumption | Who or what can validate it |
```

This table captures:
- Design decisions made without a concrete source (inference, experience, general knowledge)
- Interpretations of ambiguous requirements
- Estimates or projections not derived from data
- Any claim that could reasonably be challenged by a stakeholder

**If there are no assumptions, state that explicitly:** "All design decisions in this document are backed by the sources listed above."