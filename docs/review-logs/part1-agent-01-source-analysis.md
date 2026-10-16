---
title: "Part 1 — Agent / AI-Assistant Tooling: Source Analysis"
author: maciejnowicki
type: analysis
status: draft
created: 2026-09-10
scope: template-build
dimension: agent-tooling
sources:
  - "C:/Repos/HINT-Pipelines (HINT)"
  - "C:/Repos/workspace/NewHorizon-App-SalesAI-CRM (live-delivery source)"
  - "C:/Repos/HSO-Power Platform Pipeline Template - CDX (CDX)"
---

# Part 1 — Agent / AI-Assistant Tooling: Comparative Source Analysis

Read-only comparison of the **AI-agent tooling** dimension across three source
repositories, feeding the design of a new reusable "best-in-class" project
template. Nothing in the three sources was modified.

## TL;DR

- **HINT** is the most mature *agent-engineering* source: dual **Claude + Copilot**
  skill mirrors driven from a **`.shared/` git submodule** via `sync-shared.ps1`,
  a `layer:`-tagged skill taxonomy, a rich **meta/template/pipeline** skill family
  (template-architecture, skills-sync, skill-review, template-audit/impact/improve,
  project-upgrade, generated-file-review), and a `ProjectTemplate/` → `Project/`
  split with an init-time token-replacement engine. Its knowledge base is the older
  **`.agent/` numbered-lifecycle** model (`00_system`, `02_analysis`, …).
- **The live-delivery source** is the most mature *knowledge-base* source: the newer **hybrid `agent/`
  wiki** — four layers (`raw` / `_inbox` / `wiki` / `work`), **no lifecycle
  numbering**, anchor-page topics, external-source **captures**, an **aggressive
  linter** with enumerated invariants, and a **three-tier** product/project/personal
  split inherited via a `shared/dv/` junction. It is **Claude-only** (no `.github`
  mirror) and carries the best **delivery/ops** skills (worklog, timesheet, jira,
  close-ticket, TOPO architecture-map).
- **CDX** contributes **almost nothing** to the agent dimension — its `.claude/` is a
  single `settings.local.json` permission allow-list, no skills, no CLAUDE.md, no
  wiki. It is valuable only as the real **pipeline/project code** template (Client /
  Developer / Functions / Pipelines / PipelinesHelpers), i.e. the *target* the agent
  layer should drive, not a source of agent tooling.

The recommended template takes **the live-delivery source's wiki + delivery skills**, **HINT's dual-tool
sync + meta/template governance + template-architecture spine**, and adds an explicit
**`core/` (reusable) vs `project/` (engagement-specific) skill split** that neither
source has today.

---

## 1. How each source structures the AI agent

### 1.1 HINT — `C:/Repos/HINT-Pipelines`

**Skill locations (dual mirror).** Skills exist in **two parallel directories**:

- `.claude/skills/` — loaded by Claude Code (~72 skills)
- `.github/skills/` — identical mirror loaded by GitHub Copilot (same ~72 names)

Both are **generated** from a third source: the `.shared/` git submodule
(`.gitmodules` → Azure DevOps `Forge HINT - Original US verion`). `.shared/claude-code/skills`
is the canonical product-tier source; `sync-shared.ps1` fans it out:

```
.shared/claude-code/skills  ──sync-shared.ps1──►  .claude/skills/   (Claude)
                            └──────────────────►  .github/skills/   (Copilot)
```

`sync-shared.ps1` prompts for target (`Copilot` / `Claude` / `Both`), supports
`-Force`, `-DryRun`, and a `$repoSpecificSkills` exclusion list so locally
customised skills are not clobbered. Parity between the two generated mirrors is
then **governed** at runtime by the **`aidevme-skills-sync`** skill, which hashes each
`SKILL.md` (MD5), reports **orphans** (in one dir only) and **drift** (content
differs), and offers to reconcile — never auto-applying without confirmation. Its
own rule: *".github/skills/ is the canonical source … prefer it as source of truth."*

**Skill file format.** One folder per skill, `SKILL.md` inside, optional
`scripts/` and `references/` subfolders. Frontmatter carries a **`layer:`**
classification in addition to `name`/`description`:

```yaml
---
name: hso-template-architecture
layer: reference          # atomic | orchestration | governance | meta | reference | analysis | foundation | execution
description: |
  Master architectural reference for the HINT-Pipelines ProjectTemplate...
---
```

Observed `layer:` distribution across `.claude/skills`: **atomic 42, orchestration 11,
governance 11, meta 6, reference 2, analysis 2, foundation 1, execution 1**. This is a
genuine, useful capability taxonomy (atomic = does one thing; orchestration = composes
atomics; governance/meta = act on the tooling itself).

**Claude vs Copilot.** Served identically from the mirror. Copilot reads
`.github/copilot-instructions.md` (the CLAUDE.md equivalent) + a gitignored
`.github/copilot-instructions.local.md`; Claude reads `CLAUDE.md` + `CLAUDE.local.md`.
The two instruction files are near-duplicates maintained in parallel (drift risk —
see §2).

**Knowledge base — `.agent/` (numbered lifecycle).** Dot-prefixed, phase-numbered:
`00_system`, `02_analysis`, `04_specs`, `05_design`, `06_build`, `07_testing`, plus
`PROJECT_STAGE.md`. This is the **older** model — lifecycle stages encoded as folder
number prefixes. Product-tier SOPs live separately in `.shared/SOP/` (PCFControls,
PluginDevelopment, CustomAPI, Testing, Dual-write, …) and `.shared/agent/`
(README/index/schema/wiki) — i.e. HINT *already contains a newer `agent/` wiki inside
`.shared/`*, but the live project root still uses `.agent/` numbered.

**Templates referenced by skills.** Skills reference a **blueprint pair**:
`ProjectTemplate/` (master, committed, never run live) and `Project/` (the active,
gitignored customer repo). `hso-template-architecture` is the master reference:
documents every layer (Server 4-layer C#, Client `clientjs` TypeScript RuleEngine,
PCFControls, Functions .NET 8, Solutions, Pipelines, PipelinesHelpers/config), the
**init-time token replacement** map (`HSO.Customer.` → `HSO.{CustomerName}.`,
`hso_customer_` → `hso_{prefix}_`, etc.), and **configuration dependency chains**
(publisher prefix → publisher record → solution names → web-resource paths →
`config.ts`). Config is **externalised to JSON blueprints** —
`pipeline-defaults.json`, `solution-organizer.json` — which `Update-PipelineDefaults.ps1`
stamps into all 13 pipeline YAMLs. Skills point at these config files rather than
hardcoding values. The **"Template First" principle** is enforced by dedicated skills
(`hso-skill-review`, `hso-template-improve`, `hso-generated-file-review`): every skill
path must resolve against `ProjectTemplate/`, and generated files are never hand-edited.

### 1.2 The live-delivery source — `C:/Repos/workspace/NewHorizon-App-SalesAI-CRM`

**Skill location (single tool).** `.claude/skills/` only (~75 skills). **No
`.github/skills` mirror, no `.gitmodules`.** The live-delivery source serves **Claude only** — it has
dropped the Copilot mirror that HINT maintains. Skills are the same
folder+`SKILL.md`+`layer:`-frontmatter format inherited from the same HSO lineage
(e.g. `hso-plugin-development` carries `layer: atomic`).

**Knowledge base — hybrid `agent/` wiki (4-layer, no numbering).** This is the
**newer, better** model and the live-delivery source's standout contribution. Documented authoritatively
in `agent/schema.md`:

- **Four layers:** `raw/` (immutable sources — LLM reads, never writes), `_inbox/`
  (transient triage), `wiki/` (compiled durable knowledge), `work/` (phase-oriented
  deliverables). No number prefixes — navigate by name.
- **`wiki/` folders:** `topics/` (anchor pages), `sop/` (HSO methodology),
  `reference/` (external, carries `last_validated`), `decisions/` (numbered ADRs),
  `digests/` (summaries of raw), `system/` (current-state snapshots), `people/`.
- **Anchors, not content** (ADR 0005): a `topics/` page is *navigation* — a short
  orientation paragraph then links out to SOPs/reference/decisions/skills. "Remove
  the links and there's nothing left." The linter flags topics that grow real content.
- **Captures** (ADR 0003): external sources that can't be synced locally (Teams
  meetings, SharePoint, ADO items) are frozen as timestamped `type: capture` markdown
  in `raw/`, with `fidelity: full-copy | excerpts | summary-only` and a re-fetch note.
  Updates create a *new* dated capture with `supersedes:` — never in-place edits.
- **Frontmatter schema** is strict and enumerated (`type`, `status`, `scope`,
  `topics[]`, `people[]`, `sources[]`, `supersedes`, `last_validated`, `created`,
  `updated`).
- **Aggressive linter** (`aidevme-wiki-lint`): 16 enumerated invariants (frontmatter
  present, digests cite sources, links resolve, no orphans, no duplicate topic slugs,
  `raw/` write-once, fidelity ceiling respected, reference pages validated within
  180d, topics-are-anchors, `index.md` canonical). Auto-corrects where safe and
  commits each correction as a reviewable `chore(wiki-lint):` commit.
- **`log.md`** append-only event stream (newest on top); **`index.md`** a categorised
  catalog (regenerated by the linter).

**Three-tier inheritance.** `schema.md` defines **Product / Project / Personal** tiers.
This repo is the **project tier**; it inherits the **product tier** live via a
`shared/dv/` submodule/junction (`shared/dv/agent/wiki/…`), and personal notes live in
a separate per-human repo. **ADR 0007** mandates *visible scaffolding* — `agent/` and
`shared/` sit at the root with **no dot prefix** (browsable in Obsidian/VS Code/Explorer);
`agent/` is committed, `shared/` is gitignored with OS junctions per a slug registry.
**Note:** in the current checkout the `shared/` junction is **absent** — every CLAUDE.md
pointer to `shared/dv/agent/wiki/sop/…` currently dangles locally (see §2 weaknesses).

**Templates referenced by skills.** The live-delivery source is a *live client engagement*, not a template
repo, so it has no `ProjectTemplate/`/`Project/` split. Config is expressed in
**CLAUDE.md tables** (publisher prefix, solution placement rules, wave aggregators,
env URLs) and consumed by skills. A few skills hardcode this project's specifics —
`crm-deploy-uat` (pipeline IDs 773/802/803, UAT default), `hso-architecture-map` (writes
`agent/wiki/system/solution-map.topo`), `hso-conversationmap-development` (the live-delivery source's chat
estate). The **TOPO map** (`hso-architecture-map`) is a notable addition: a living
`.topo` topology of every solution component, its intent and bidirectional
`depends_on`/`depended_on_by` edges, updated as a mandatory sub-step of every build skill.

**Delivery/ops skills** are the live-delivery source's other strength: `worklog` + `timesheet-report` +
`hso-timesheet-builder` (customer-agnostic, config-driven off `CLAUDE.local.md` maps),
`hso-jira-updates` / `hso-jira-business-summary`, `hso-close-ticket` (commit → integrate
Sprint → build → deploy Dev → merge → push → verify), `crm-env-status`, and a mature
**worktree-per-ticket** branching discipline in CLAUDE.md.

### 1.3 CDX — `C:/Repos/HSO-Power Platform Pipeline Template - CDX`

**Agent layer: effectively none.** `.claude/` contains only `settings.local.json` — a
permission allow-list (Bash/Read entries, mermaid render commands). **No `.claude/skills`,
no `.github`, no CLAUDE.md, no `.agent`/`agent` wiki, no `.shared`.** The repository's
value is the **actual pipeline/project template code** in its nested folder: `Client/`,
`Developer/`, `Functions/`, `Pipelines/`, `PipelinesHelpers/`, `InitializeProjectScript/`,
`HANDOVER-RUNBOOK.md`, and lint scripts (`Test-PipelineTasksUsePwsh.ps1`,
`Assert-NoMojibake.ps1`). For the agent dimension, CDX is a **negative example** (what a
repo looks like with pipeline maturity but zero agent scaffolding) and a reference for
the **project structure the agent layer must operate on**.

---

## 2. Strengths & weaknesses (concrete)

### HINT

**Strengths**
- **One-source-of-truth → dual-tool fan-out.** `.shared/` submodule +
  `sync-shared.ps1` + `aidevme-skills-sync` is a complete, working answer to "serve Claude
  and Copilot from one source." (`.shared/sync-shared.ps1`, `.claude/skills/aidevme-skills-sync/SKILL.md`).
- **Skill `layer:` taxonomy** gives an at-a-glance capability map and a natural
  ordering (atomic → orchestration → governance/meta).
- **Meta/template governance is unmatched:** `hso-template-architecture` (the spine),
  `hso-template-audit` / `-impact-analysis` / `-improve`, `hso-project-upgrade`
  (diff live Project against template, apply safe updates), `hso-generated-file-review`
  (detect hand-edited generated files), `hso-skill-review` (path alignment),
  `hso-skill-path-migration` (bulk path fixes), `hso-repo-hygiene`.
- **Config as blueprint, not hardcode:** `pipeline-defaults.json` + `solution-organizer.json`
  stamped by `Update-PipelineDefaults.ps1`; skills read config.
- **Init token-replacement engine** makes the template genuinely reusable per customer.
- **Full framework skills** for server (`hso-server-framework`, 4-layer),
  client (`hso-client-ruleengine`, JSON-driven RuleEngine), and Functions
  (`hso-functions-development`).

**Weaknesses**
- **Two mirrors = perpetual drift risk.** The whole `aidevme-skills-sync` + `hso-repo-hygiene`
  apparatus exists *only* to fight drift the dual-directory design creates. Duplicated
  `copilot-instructions.md` vs `CLAUDE.md` compounds it.
- **Sync artifacts leak:** `.claude/skills/aidevme-skills-sync/aidevme-skills-sync/SKILL.md`
  is a **double-nested** copy — exactly the kind of bug a naive recursive copy
  produces.
- **Older `.agent/` numbered wiki** — lifecycle numbering (`00_`,`02_`,`04_`) is
  rigid, forces artificial phase ordering, and is inconsistent with the newer `agent/`
  wiki HINT *already ships inside `.shared/agent/`*. Two wiki models coexist in one repo.
- **No captures / no linter invariants** at the project tier — knowledge integrity is
  by convention, not enforced.

### The live-delivery source

**Strengths**
- **Best-in-class knowledge base:** hybrid `agent/` wiki, anchors, captures, strict
  frontmatter, **enforced** invariants via an aggressive self-committing linter,
  three-tier inheritance, visible scaffolding (`agent/schema.md`, ADR 0005/0007).
- **Best delivery/ops skills:** worklog/timesheet, jira drafting (approval-gated),
  `hso-close-ticket`, TOPO architecture-map with bidirectional dependency invariant.
- **Single-tool simplicity:** no `.github` mirror to keep in sync — zero drift surface.
- **Triage-first discipline** baked into CLAUDE.md (is it a bug or agreed behaviour?)
  and reinforced by memory — a genuinely valuable agent behaviour.
- **Strong env-safety model:** Dev-only writes, UAT/Prod read-only, connection check
  before any deploy — encoded in CLAUDE.md and repeated in skill preambles.

**Weaknesses**
- **Claude-only.** No Copilot path at all — if the template must serve both tools,
  The live-delivery source offers no mechanism.
- **No template/meta governance:** no `ProjectTemplate`/`Project` split, no
  template-architecture spine, no skill-review/path-migration/generated-file-review.
  Skills that hardcode project specifics (`crm-deploy-uat` pipeline IDs, conversationmap)
  can't be lifted cleanly.
- **Dangling `shared/` inheritance:** CLAUDE.md's mandatory pre-implementation reads
  point at `shared/dv/agent/wiki/sop/…`, but `shared/` is **absent** in this checkout —
  the junction is a per-machine setup step with no in-repo guard. New sessions silently
  read nothing.
- **Stray artifacts:** `hso-dataverse-bpf.zip`, `hso-pcf-control-development.zip` sit
  next to their skill folders in `.claude/skills/`.
- **No `core` vs `project` skill separation** — reusable and live-delivery-source-specific skills are
  intermixed in one flat `.claude/skills/`.

### CDX

**Strengths**
- Real, working **pipeline/project template** (Client/Developer/Functions/Pipelines) +
  init script + handover runbook + pipeline-lint scripts — the concrete artifact the
  agent layer should manage.

**Weaknesses**
- **No agent tooling whatsoever** beyond a permissions file. No skills, CLAUDE.md, or
  wiki. Any agent working here starts cold.

---

## 3. Gaps each has that the others cover

| Gap in… | …covered by |
|---|---|
| **HINT**: modern non-numbered wiki, captures, enforced linter invariants, delivery/worklog/jira skills, TOPO map, single-tool simplicity | **live-delivery source** |
| **live-delivery source**: dual-tool (Copilot) serving + sync, template/meta governance family, `ProjectTemplate/Project` split + init token engine, config-blueprint JSON, server/client/functions framework skills, `core` vs `project` separation | **HINT** |
| **CDX**: essentially the entire agent layer (skills, CLAUDE.md, wiki, sync) | **HINT** and **live-delivery source** both |
| **All three**: an explicit **reusable-core vs project-specific** skill boundary; a single instruction file that generates both tools' instructions; an in-repo guard that fails fast when inherited `shared/` is missing | *(none — new in the template)* |

---

## 4. Best-in-class recommendation — the new template's agent layer

**Design goals:** one source of truth serving **both Claude and Copilot**; the live-delivery source's
wiki + delivery excellence; HINT's template/meta governance and config-blueprint
discipline; and a **hard separation of reusable product skills from project-specific
skills** (explicitly requested).

### 4.1 One source, two tools (no hand-maintained mirror)

Author skills and agent instructions **once** under a canonical `agent-src/` tree, and
**generate** the tool-specific directories (`.claude/skills`, `.github/skills`, and the
two instruction files) with a single `sync` script run in CI + a pre-commit hook.
Critically, invert HINT's model: **do not commit two hand-edited mirrors** — commit the
*source*, treat `.claude/` and `.github/` as **build outputs** (or at minimum, make the
sync a required pre-commit gate so drift can never land). Keep HINT's `aidevme-skills-sync`
as the **verification** backstop (fail CI on orphan/drift), and fix its double-nesting
bug. A single `AGENTS.md` source generates both `CLAUDE.md` and
`.github/copilot-instructions.md` (tool-specific preambles injected at sync time), so the
two instruction files can never drift.

### 4.2 Wiki model: adopt the live-delivery source's hybrid `agent/` wholesale

Take the live-delivery source's four-layer, non-numbered `agent/` wiki, `schema.md`, the anchor rule,
captures, the strict frontmatter, and the aggressive `aidevme-wiki-lint` with its 16
invariants. Keep **visible scaffolding** (`agent/`, `shared/` un-dotted, ADR 0007) and
the **three-tier product/project/personal** inheritance. Retire HINT's `.agent/`
numbered folders entirely. **Add** an in-repo guard (a lint check / first-run script)
that **fails fast with a clear message when the inherited `shared/` junction is absent**
— closing the live-delivery source's dangling-inheritance gap.

### 4.3 Template spine + config blueprints: adopt HINT's

Keep the `ProjectTemplate/` → `Project/` split, the init token-replacement engine, the
`hso-template-architecture` master reference, the JSON config blueprints
(`pipeline-defaults.json`, `solution-organizer.json`) stamped into pipeline YAML, and
the **Template-First** governance skills. The concrete project structure to template is
**CDX's** (Client / Developer / Functions / Pipelines / PipelinesHelpers).

### 4.4 Reusable core vs project-specific skills (the key structural change)

Split skills into **two source trees**, synced independently:

- **`agent-src/skills/core/`** — reusable, product-tier, customer-agnostic skills
  (inherited via `shared/`, versioned centrally). Grouped by `layer:` and domain.
- **`agent-src/skills/project/`** — engagement-specific skills authored in the
  consuming repo (hardcoded pipeline IDs, client estate, ticket workflow). Never
  synced upstream; the sync script's exclusion list protects them (HINT's
  `$repoSpecificSkills` idea, made first-class).

The sync fans **both** into `.claude/skills` and `.github/skills`, but only `core/`
round-trips to the shared submodule. `aidevme-skill-creator` gains a required `--scope
core|project` choice so every new skill is placed correctly from birth.

### 4.5 Skill inventory for the reusable core (grouped)

- **Foundation / meta / template governance:** `hso-template-architecture`,
  `aidevme-skill-creator`, `aidevme-skills-sync`, `hso-skill-review`, `hso-skill-path-migration`,
  `hso-skill-update-shared-skill`, `hso-template-audit`, `hso-template-impact-analysis`,
  `hso-template-improve`, `hso-project-upgrade`, `hso-generated-file-review`,
  `hso-repo-hygiene`, `hso-init-project`, `hso-provision-environment`,
  `hso-dataverse-init-repo`, `hso-agent-help`, `hso-architecture-map` (TOPO).
- **Dataverse:** `hso-dataverse-data-modeling`, `aidevme-dataverse-data`,
  `aidevme-dataverse-customapi` (a.k.a. `hso-create-custom-api`), `hso-dataverse-ui-config`
  (a.k.a. `hso-dataverse-form-config`), `hso-dataverse-securityrole`,
  `hso-dataverse-naming-conventions`, `hso-dataverse-bpf`, `hso-dataverse-dashboards`,
  `hso-dataverse-flow-docs`, `aidevme-fetchxml-queries`, `hso-dataverse-deployment-settings`,
  `hso-dataverse-pipelines`, `hso-semantic-data-modeling`.
- **Server:** `hso-plugin-development`, `hso-plugin-code-review`, `hso-server-framework`,
  `hso-functions-development`, `hso-powerautomate-writer`.
- **Client:** `hso-formscript-development`, `hso-client-ruleengine`,
  `hso-pcf-control-development`, `hso-canvasapp-development`, `hso-claude-design-handoff`.
- **Pipelines / ALM:** `hso-pipeline-architecture`, `hso-pipeline-generation`,
  `hso-pipeline-diagnostics`, `hso-update-pipeline-config`, `hso-deployment-parameters`,
  `hso-ado-deploymenthistory`, `hso-alm-architect`, `hso-production-readiness`,
  `hso-analyze-dataverse-solution-changes`, `hso-architecture-validation`,
  `hso-solution-design-review`, `hso-repository-decision`.
- **Delivery / wiki / ops:** all `hso-wiki-*` (`-process-inbox`, `-ingest-transcript`,
  `-ingest-discovery-artifact`, `-capture`, `-write-decision`, `-update-topic`, `-lint`,
  `-query`, `-scaffold-client`, `-scaffold-project`), `hso-ado-work-items`,
  `hso-task-creator`, `hso-work-planner`, `hso-solution-documentation`,
  `hso-update-solution-docs`, `hso-engagement-deliverables`, `hso-jira-business-summary`,
  `hso-timesheet-builder`, `worklog`, `timesheet-report`, `status`, plus the diagram
  skills (`hso-diagram-drawio/-excalidraw/-plotly/-reference-architecture`) and
  `hso-revealjs-presentation`, `hso-presales-demo-architect`.
- **Reference:** `aidevme-dataverse-sdk-reference`, `hso-dataverse-ui-reference`,
  `hso-ce-apps-sdk-reference`, `hso-fieldservice-reference`, `hso-d365-guidance-reference`,
  `hso-fasttrack-reference`, `hso-msaccess-extractor`, `playwright-cli`.
- **Meta scaffolder:** `skill-creator` / `anthropic-skills:skill-creator` (upstream base).

### 4.6 Project-specific (stay in `skills/project/`, not core)

`hso-conversationmap-development` (the live-delivery source's chat estate), `crm-deploy-uat`,
`crm-cancel-deploy`, `crm-env-status` (hardcoded pipeline IDs + env), `hso-close-ticket`
(Sprint/worktree/AP-ticket workflow — *generalise into core later*), `hso-jira-updates`
(Keith-assignment specifics — pattern is reusable, config is not), `hso-user-setup-audit`,
`hso-vs360-docmix-template`, `hso-grill-architect`. Rule: a skill that names a client,
a pipeline ID, an environment URL, or a sprint convention is project-scoped until those
are externalised to config.

### 4.7 Drop / dedupe

Stray zips (`hso-dataverse-bpf.zip`, `hso-pcf-control-development.zip`); the
double-nested `aidevme-skills-sync/aidevme-skills-sync/`; and HINT's pre-wiki duplicates
`hso-ingest-transcript` / `hso-ingest-discovery-artifact` (superseded by the
`hso-wiki-ingest-*` versions).

---

## 5. Things the user may have missed (valuable, easy to overlook)

1. **The `layer:` skill taxonomy** (HINT frontmatter). A cheap, powerful way to reason
   about skill composition (atomic vs orchestration vs governance/meta). Carry it into
   the template's `SKILL.md` schema and lint it.
2. **HINT's `$repoSpecificSkills` exclusion list** in `sync-shared.ps1` — the seed of
   the core/project split. Make it a first-class manifest, not a commented-out array.
3. **`hso-generated-file-review` + `hso-project-upgrade`** — the machinery that keeps a
   *template-derived* repo upgradable (detect hand-edits to generated files; diff live
   Project against latest template and apply safe updates). Essential for a reusable
   template but rarely in a brief.
4. **The live-delivery source's capture model + fidelity ceiling** (ADR 0003) — the only robust way to
   pull ephemeral Teams/SharePoint/ADO knowledge into the repo without lying about
   provenance. The linter's fidelity-ceiling invariant prevents digests over-claiming.
5. **The aggressive, self-committing linter** (`chore(wiki-lint):` per correction) —
   knowledge integrity by enforcement, reviewable and one `git revert` away. Most
   templates ship a linter that only warns.
6. **TOPO architecture-map** (`hso-architecture-map`) with the **bidirectional
   dependency invariant** (every `depends_on` has a mirror `depended_on_by`) — a living
   component topology that is updated as a mandatory sub-step of every build skill.
7. **Triage-first / agreed-behaviour discipline** (the live-delivery source's CLAUDE.md + memory) — "is it a
   bug or the designed behaviour?" as a mandatory first step. A behaviour worth encoding
   template-wide, not just a habit of the live-delivery source.
8. **Env-safety pattern** (Dev-only writes; verify active connection before any deploy;
   near-miss postmortem baked into CLAUDE.md). Reusable safety scaffolding.
9. **AGENTS.md convergence** — generating both `CLAUDE.md` and `copilot-instructions.md`
   from one source removes the *other* drift surface HINT still has (the two instruction
   files, not just the skills).
10. **Worklog/timesheet automation** wired to a commit hook — low-glamour but high-value
    ops tooling already customer-agnostic in the live-delivery source (`CLAUDE.local.md` maps).

---

## 6. Recommended structure (directory tree)

```
NewTemplate/
├── AGENTS.md                     ← single instruction SOURCE (generates the two below)
├── CLAUDE.md                     ← generated (Claude) — do not hand-edit
├── CLAUDE.local.md               ← gitignored, per-developer
├── .github/
│   ├── copilot-instructions.md   ← generated (Copilot) — do not hand-edit
│   ├── copilot-instructions.local.md
│   └── skills/                   ← generated mirror (sync output)
├── .claude/
│   ├── settings.json             ← permissions (from CDX pattern)
│   └── skills/                   ← generated mirror (sync output)
│
├── agent-src/                    ← CANONICAL SOURCE (edit here only)
│   ├── AGENTS.md.tmpl
│   ├── sync/
│   │   ├── sync.ps1              ← fans core+project → .claude + .github (+ AGENTS→CLAUDE/copilot)
│   │   ├── skills-manifest.json ← per-skill scope (core|project) + tool targets
│   │   └── verify-parity.ps1    ← aidevme-skills-sync backstop (CI-gated, drift = fail)
│   └── skills/
│       ├── core/                 ← reusable product skills (round-trip to shared/)
│       │   ├── foundation/  dataverse/  server/  client/
│       │   ├── pipelines/   delivery/   reference/  meta/
│       └── project/              ← engagement-specific skills (never synced upstream)
│
├── agent/                        ← PROJECT-tier wiki (live-delivery source hybrid, visible, committed)
│   ├── README.md  index.md  log.md  schema.md
│   ├── raw/  _inbox/
│   ├── wiki/  (system topics sop reference decisions digests people)
│   └── work/  (analysis specs design build testing deliverables)
│
├── shared/                       ← PRODUCT-tier inheritance (gitignored junction)
│   └── dv/agent/…  + dv/skills/core/…   ← guard fails fast if absent
│
├── ProjectTemplate/              ← master template (HINT spine, CDX project shape)
│   ├── Client/ Developer/ Functions/ PCFControls/ Server/
│   ├── Solutions/ Pipelines/ PipelinesHelpers/config/{pipeline-defaults,solution-organizer}.json
│   └── InitializeProjectScript/  (token-replacement engine)
└── Project/                      ← active customer repo (gitignored)
```

---

## 7. Skill inventory decision table

Representative — grouped; "…-family" rows stand for every member. **KEEP-CORE** =
reusable `skills/core/`; **PROJECT** = `skills/project/`; **DROP** = remove/dedupe.

| Skill (or family) | Group | Decision | Why |
|---|---|---|---|
| hso-template-architecture | foundation/meta | KEEP-CORE | Master template spine; every dev skill reads it first |
| aidevme-skills-sync | meta | KEEP-CORE | Dual-tool parity backstop (fix double-nest bug) |
| aidevme-skill-creator / skill-creator | meta | KEEP-CORE | Add required `--scope core\|project` |
| hso-skill-review / -path-migration / -update-shared-skill | meta | KEEP-CORE | Skill/path governance |
| hso-template-audit / -impact-analysis / -improve | governance | KEEP-CORE | Template-First change control |
| hso-project-upgrade / hso-generated-file-review | governance | KEEP-CORE | Keeps template-derived repos upgradable |
| hso-repo-hygiene / hso-agent-help | governance/foundation | KEEP-CORE | Repo health + onboarding |
| hso-init-project / hso-provision-environment / hso-dataverse-init-repo | foundation | KEEP-CORE | Project bootstrap |
| hso-architecture-map (TOPO) | foundation | KEEP-CORE | Living component topology + bidirectional deps |
| hso-dataverse-* (data-modeling, data, customapi, ui-config, securityrole, naming, bpf, dashboards, flow-docs, deployment-settings, pipelines) | dataverse | KEEP-CORE | Platform-agnostic Dataverse capability |
| aidevme-fetchxml-queries / hso-semantic-data-modeling | dataverse | KEEP-CORE | Reusable query/model tooling |
| hso-plugin-development / -code-review | server | KEEP-CORE | 4-layer plugin methodology |
| hso-server-framework / hso-functions-development | server | KEEP-CORE | Template server + Functions framework |
| hso-powerautomate-writer | server | KEEP-CORE | Flow authoring (Dataverse connector) |
| hso-formscript-development / hso-client-ruleengine | client | KEEP-CORE | Form logic (JS + JSON RuleEngine) |
| hso-pcf-control-development / hso-canvasapp-development / hso-claude-design-handoff | client | KEEP-CORE | PCF / canvas / design handoff |
| hso-pipeline-architecture / -generation / -diagnostics / hso-update-pipeline-config / hso-deployment-parameters | pipelines | KEEP-CORE | 13-pipeline framework tooling |
| hso-ado-deploymenthistory / hso-alm-architect / hso-production-readiness | pipelines | KEEP-CORE | ALM + release readiness |
| hso-analyze-dataverse-solution-changes / hso-architecture-validation / hso-solution-design-review / hso-repository-decision | pipelines/review | KEEP-CORE | Solution/architecture review |
| hso-wiki-* family (process-inbox, ingest-transcript, ingest-discovery-artifact, capture, write-decision, update-topic, lint, query, scaffold-client, scaffold-project) | delivery/wiki | KEEP-CORE | The live-delivery source's wiki engine — adopt wholesale |
| hso-ado-work-items / hso-task-creator / hso-work-planner | delivery | KEEP-CORE | Work tracking |
| hso-solution-documentation / hso-update-solution-docs / hso-engagement-deliverables | delivery | KEEP-CORE | Doc/deliverable generation |
| hso-jira-business-summary / hso-timesheet-builder / worklog / timesheet-report / status | delivery/ops | KEEP-CORE | Customer-agnostic ops (config-driven) |
| hso-diagram-* / hso-revealjs-presentation / hso-presales-demo-architect | delivery | KEEP-CORE | Reusable visual/deliverable tooling |
| aidevme-dataverse-sdk-reference / -ui-reference / hso-ce-apps-sdk-reference / hso-fieldservice-reference / hso-d365-guidance-reference / hso-fasttrack-reference | reference | KEEP-CORE | Read-only knowledge references |
| hso-msaccess-extractor / playwright-cli | reference/testing | KEEP-CORE | General-purpose utilities |
| hso-conversationmap-development | project (live-delivery source) | PROJECT | the live-delivery source's chat estate — client-specific |
| crm-deploy-uat / crm-cancel-deploy / crm-env-status | project | PROJECT | Hardcoded pipeline IDs (773/802/803) + UAT env |
| hso-close-ticket | project | PROJECT | Sprint/worktree/AP-ticket workflow (generalise later) |
| hso-jira-updates | project | PROJECT | Keith-assignment + AP-project specifics |
| hso-user-setup-audit / hso-vs360-docmix-template / hso-grill-architect | project | PROJECT | Client/engagement-specific |
| hso-ingest-transcript / hso-ingest-discovery-artifact (HINT, non-wiki) | — | DROP | Superseded by hso-wiki-ingest-* |
| hso-dataverse-bpf.zip / hso-pcf-control-development.zip | — | DROP | Stray build artifacts, not skills |
| aidevme-skills-sync/aidevme-skills-sync/ (nested copy) | — | DROP | Sync double-nesting bug artifact |

---

*End of Part 1 — Agent tooling source analysis.*
