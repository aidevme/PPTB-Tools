---
name: hso-wiki-scaffold-client
layer: meta
scope: core
description: |
  Add a new client subfolder to a multi-client wiki layout under `agent/wiki/clients/<client>/`. Creates
  the client's `overview.md`, `projects/` folder, and `people/` folder with valid frontmatter, plus an
  optional first project skeleton. Assumes the hybrid `agent/` layout already exists. Use when:
  (1) User says "add a client", "scaffold a new client", or "set up a client folder"
  (2) Converting a single-project wiki into a multi-client one
  Does NOT create the top-level `agent/` structure (run `hso-wiki-scaffold-project` first) or a full project
  layout inside the client — just the client skeleton.
---

# Wiki Scaffold — Client

Add a client subfolder to a multi-client wiki. For consulting-style repos where one `agent/` tracks multiple
client engagements, this skill creates the per-client skeleton so content can be organised by client.

## Multi-client wiki shape

```
agent/wiki/clients/
├── <client-slug>/
│   ├── overview.md              ← client-level summary, contacts, history
│   ├── projects/
│   │   └── <project-slug>/      ← one folder per engagement
│   │       ├── system/          (per-project system snapshots)
│   │       ├── decisions/       (per-project ADRs)
│   │       ├── digests/         (per-project meeting digests)
│   │       └── topics/          (per-project anchor pages)
│   └── people/
│       └── <person-slug>.md     ← client-side stakeholders specific to this client
```

Client-wide people (a CIO who spans multiple engagements) live under the client's `people/`. Cross-client
anchors stay at the wiki root in `wiki/topics/`; cross-client SOPs live at the product tier in the shared
repo's `wiki/sop/`. Per-client or per-project SOPs — engagement-specific methodology that isn't portable —
can live under `clients/<slug>/projects/<project>/sop/` if needed, but this is unusual: most authored
methodology is product-tier.

## When this skill applies

Only in repos that are intentionally multi-client. For a single-project delivery repo (most engagements), the
flat `wiki/topics/`, `wiki/people/`, `wiki/decisions/` structure is correct — DON'T create `wiki/clients/`
unless you actually have more than one client in the same repo.

If the user isn't sure, ask: "Is this repo tracking one client or multiple?" If one, point them at the flat
layout and skip this skill.

## Configuration

Read from `CLAUDE.local.md`: **Author Name** (for attribution in stub files).

## Workflow

### 1. Verify the wiki layout exists

Check `agent/wiki/` exists. If not, point the user at `hso-wiki-scaffold-project` and stop.

### 2. Gather inputs

| Input | Required | Notes |
|---|---|---|
| `client_name` | Yes | Human-readable client name (kept internal — `wiki/clients/` is gitignored or private-tier) |
| `client_slug` | Yes | URL/filesystem-safe slug. Offer to derive from the name if not provided. |
| `client_industry` | No | e.g. "Manufacturing", "Field Service" |
| `engagement_type` | No | e.g. "Presales", "Implementation", "Support" |
| `first_project` | No | If yes, also scaffold a first project skeleton inside `projects/<project-slug>/` |

### 3. Check for name collision

If `agent/wiki/clients/<client_slug>/` already exists, stop and ask the user:

- Did they mean to add a new project to an existing client? If so, run this skill with `first_project` only.
- Or is the slug a genuine collision that needs a different name?

### 4. Create the client folder structure

```powershell
$client = "<client-slug>"  # from inputs
$base = "agent/wiki/clients/$client"
$dirs = @("projects", "people")
foreach ($d in $dirs) {
    $path = Join-Path $base $d
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $gitkeep = Join-Path $path ".gitkeep"
    if (-not (Test-Path $gitkeep)) { New-Item -ItemType File -Path $gitkeep -Force | Out-Null }
}
```

### 5. Write `clients/<slug>/overview.md`

Use this template:

````markdown
---
title: "<Client Name> — Client Overview"
type: system-state
status: active
scope: project
client: <client_slug>
project: —
topics: []
people: []
sources: []
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

# <Client Name>

## Overview

_TODO: one-paragraph description of the client — industry, size, geographical footprint, the nature of the engagement._

## Engagements

- _TODO: list projects in `projects/` here as they're created, with one-line descriptions._

## Key contacts

See [people/](people/) for per-person pages. Summary:

- _TODO: who to contact for what_

## History

_TODO: brief timeline of the relationship with this client — when engagements started, major milestones, renewals._

## Related

- [../../topics/](../../topics/) — cross-client topics
- [../../decisions/](../../decisions/) — firm-level decisions that apply to this client
````

### 6. Optionally scaffold a first project

If the user requested `first_project`, also create:

```
projects/<project_slug>/
├── system/       .gitkeep
├── digests/      .gitkeep
├── topics/       .gitkeep       (project-specific topics — cross-client stay at wiki/topics/)
└── decisions/    .gitkeep       (project-specific ADRs)
```

Note: for the per-project phase folders (analysis/specs/design/build/testing/deliverables), those live at the
wiki root under `work/<phase>/<client>/<project>/` rather than nested inside `clients/`, keeping `work/` a
unified phase view across all clients. Alternatively, nest them under
`clients/<client>/projects/<project>/work/` for strict per-client isolation. **Ask the user which model they
prefer** before creating `work/` subfolders.

### 7. Add a log entry

Append a single entry to the top of `agent/log.md` (hand-appended, newest at top — this template does not use
a generated fragment log):

```
## [<YYYY-MM-DD>] milestone | wiki | Client scaffolded: <client_name>
Created by `hso-wiki-scaffold-client`. Path: agent/wiki/clients/<client_slug>/
<if first_project: "First project scaffolded: <project_slug>">
```

### 8. Run `hso-wiki-lint`

Expected: 0 findings. If the `overview.md` stub doesn't pass lint, the stub template is broken — report and stop.

### 9. Report to the user

- Client slug created
- Where the overview lives
- Whether a first project was also scaffolded
- Suggested next steps:
  - Fill in the `overview.md` TODO sections
  - Add client stakeholders via `people/`
  - Start capturing content via `hso-wiki-capture` or `hso-wiki-ingest-transcript`

## Critical rules

### DO:
- **Confirm multi-client intent.** If the user isn't sure they need a multi-client layout, recommend the flat single-project layout instead.
- **Require a slug.** The slug is the filesystem identity — ask for it explicitly or derive it and confirm.
- **Be idempotent.** If the client folder already exists, stop and ask.
- **Ask about the work/ model** (shared across clients vs per-client) before creating `work/` folders.
- **Verify with `hso-wiki-lint`** after scaffolding.

### DO NOT:
- **Auto-create `wiki/clients/` in a flat single-project repo.** The flat layout is the default; only create `clients/` when the user explicitly wants multi-client.
- **Overwrite an existing client's `overview.md`.** If the client exists, the user is adding a project, not re-scaffolding.
- **Create per-client `topics/` or `decisions/` that duplicate the wiki-root ones.** Per-client topics are for concepts *specific* to that client.
- **Hardcode client names in trigger descriptions.** The description uses placeholders, not real client names (ADR-0003 neutrality).
- **Write a generated log fragment.** Append to the hand-appended `agent/log.md` instead.

## Related

- [`agent/schema.md`](../../../../agent/schema.md) — frontmatter schema the stub files follow
- `hso-wiki-scaffold-project` — sibling skill; scaffolds the `agent/` root layout before this skill runs
- `hso-wiki-lint` — runs after scaffolding to verify the result
- `hso-wiki-capture`, `hso-wiki-write-decision`, `hso-wiki-ingest-transcript` — populate the scaffolded client with real content

## Changelog

- Ported from the ForgeUSA `hso-wiki-scaffold-client` skill and reconciled to this template's model: dropped
  the `license:` header (ADR-0003 neutral template); replaced the ADR-0062 log-fragment step with a
  hand-appended `agent/log.md` entry; neutralised Forge-specific ADR cross-links to `agent/schema.md`.
  `scope: core`.
