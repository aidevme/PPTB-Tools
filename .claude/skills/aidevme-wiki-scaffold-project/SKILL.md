---
name: aidevme-wiki-scaffold-project
metadata:
  layer: meta
  scope: core
description: |
  Create the hybrid `agent/` wiki layout (four layers: `raw/`, `_inbox/`, `wiki/`, `work/`) in an
  existing repo, or fill in missing pieces of a partially-scaffolded one. Produces stub `README.md`,
  `index.md`, `log.md`, and `schema.md` at `agent/` root so the repo passes `aidevme-wiki-lint` from the
  first run. Idempotent — never overwrites existing files without asking. Use when:
  (1) User says "scaffold the wiki", "set up agent/", or "create the agent wiki"
  (2) Another skill refuses to run because `agent/` is missing
  (3) A partially-scaffolded `agent/` needs its missing folders/stubs filled in
  Does NOT create client subfolders (use `hso-wiki-scaffold-client` for multi-client repos) and NEVER
  overwrites an existing `agent/` root `.md` file without asking.
---

# Wiki Scaffold — Project

Create the hybrid `agent/` layout in a repo. This is the single-project scaffolder — for multi-client
repos, also run `hso-wiki-scaffold-client` afterward to add client subfolders under `wiki/clients/`.

The layout, frontmatter, and `log.md` / `index.md` conventions this skill produces are defined by
[`agent/schema.md`](../../../../agent/schema.md). This skill is the reference-not-copy scaffolder that
stamps a fresh repo into that shape.

## What this skill creates

```
agent/
├── README.md              ← overview + quickstart (valid frontmatter)
├── index.md               ← categorised catalog (valid frontmatter, empty sections)
├── log.md                 ← append-only chronological event stream (hand-appended, newest at top)
├── schema.md              ← conventions + invariants (copied from the inherited product tier)
│
├── raw/
│   ├── transcripts/  .gitkeep
│   ├── discovery/    .gitkeep
│   ├── screenshots/  .gitkeep
│   └── exports/      .gitkeep
│
├── _inbox/           .gitkeep
│
├── wiki/
│   ├── system/       .gitkeep
│   ├── digests/      .gitkeep
│   ├── topics/       .gitkeep   ← anchor pages (context-engineering entry points)
│   ├── sop/          .gitkeep   ← authored methodology
│   ├── reference/    .gitkeep   ← external authoritative material
│   ├── people/       .gitkeep
│   └── decisions/    .gitkeep
│
└── work/
    ├── analysis/     .gitkeep
    ├── specs/        .gitkeep
    ├── design/       .gitkeep
    ├── build/
    │   ├── implementation-notes/  .gitkeep
    │   └── changelog/             .gitkeep
    ├── testing/      .gitkeep
    └── deliverables/ .gitkeep
```

All `.gitkeep` files preserve empty folders in git. All four root `.md` files (`README.md`, `index.md`,
`log.md`, `schema.md`) include valid frontmatter so `aidevme-wiki-lint` passes immediately after scaffolding.

> **Hand-appended `log.md`.** This template keeps `log.md` and `index.md` as hand-appended / linter-audited
> files (see `agent/schema.md`), not generated-from-fragments. The scaffold seeds `log.md` with the single
> scaffolding entry at the top; new entries are appended by hand or by the wiki skills. There is **no**
> `agent/log/` fragment folder.

## Configuration

Read from `CLAUDE.local.md`: **Author Name** (for the initial `log.md` entry). Falls back to the Windows
display name when absent.

## Script usage (automation / wizard path)

The scaffold is implemented in [`scripts/New-HybridWikiScaffold.ps1`](scripts/New-HybridWikiScaffold.ps1).
Callers that already know the target repo and tier (e.g. an init driver) should invoke it directly instead
of walking the interactive workflow below:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass `
    -File "agent-src/skills/core/delivery/aidevme-wiki-scaffold-project/scripts/New-HybridWikiScaffold.ps1" `
    -RepoPath "C:\path\to\repo" `
    -Tier project `
    -AuthorName "Jane Doe"
```

(In a generated project the same script lives at `.claude/skills/aidevme-wiki-scaffold-project/scripts/`.)

Parameters:

- `-RepoPath` (required) — target repo root; `agent/` is created inside it.
- `-Tier` — `product` | `project` | `personal` | `auto` (default). Auto-detection uses the signals in §1 below.
- `-AuthorName` — seeds the initial `log.md` entry (defaults to the Windows display name).
- `-BestPracticesPath` — path to a clone of the shared product-tier repo used to source the canonical
  `schema.md`. If omitted the script looks for `$RepoPath/shared/dv/` and then walks up from its own location.
- `-Force` — overwrite existing `README.md` / `index.md` / `log.md` / `schema.md` at `agent/` root. Folder and
  `.gitkeep` creation is always idempotent.

The script is idempotent (rerun safely) and refuses to auto-migrate legacy numbered folders. For non-product
tiers it retargets the internal markdown links in `schema.md` so they resolve through the `shared/` junction
(or strips them to plain text where no junction is mounted); `aidevme-wiki-lint` passes cleanly as a result.

The interactive workflow below is the human-driven path and produces the same result.

## Workflow

### 1. Detect the tier

Determine the `scope:` this repo's wiki belongs to:

| Signal | Tier | Rationale |
|---|---|---|
| Repo is the template/product itself (contains `agent-src/skills/`) | `product` | This is the shared skill/product library |
| Repo has a `shared/dv/` (or other `shared/<slug>/`) junction with `agent/wiki/` | `project` | A consuming delivery repo that inherits the product wiki |
| Repo name ends in `-wiki` or the path contains `personal` | `personal` | A personal-tier wiki |
| None of the above — unclear | ASK | Present the three options to the user |

Record the detected tier — it goes into the frontmatter `scope:` field of every stub file (`product` |
`project` | `personal`).

### 2. Check what already exists

Before creating anything, enumerate what's already in `agent/` (if the folder exists at all). Three cases:

| Case | Action |
|---|---|
| `agent/` doesn't exist | Full scaffold — create everything from scratch |
| `agent/` exists but is empty (or only has `.gitkeep`) | Full scaffold — populate |
| `agent/` exists with content | Incremental mode — only create missing subfolders and stub files; never overwrite existing files without asking |

**Detect old numbered layouts.** If you find folders like `00_system`, `02_analysis`, `03_digests`,
`04_specs`, `05_design`, `06_build`, `07_testing`, or `09_deliverables`, the repo is using the pre-hybrid
layout. Do NOT auto-migrate. Instead:

1. Tell the user the repo has the old layout.
2. Offer to scaffold the new folders **alongside** the existing numbered ones (Phase 1 of the migration
   playbook — non-destructive because the new folders are empty and don't collide with anything).
3. Point the user at [references/legacy-migration.md](references/legacy-migration.md) for the full playbook.
4. Only proceed past Phase 1 with explicit per-file approval from the user.

### 3. Create the folder structure

Use a single PowerShell command to create all folders and `.gitkeep` files in one pass:

```powershell
$base = "agent"
$dirs = @(
    "raw/transcripts", "raw/discovery", "raw/screenshots", "raw/exports",
    "_inbox",
    "wiki/system", "wiki/digests", "wiki/topics", "wiki/sop", "wiki/reference", "wiki/people", "wiki/decisions",
    "work/analysis", "work/specs", "work/design",
    "work/build/implementation-notes", "work/build/changelog",
    "work/testing", "work/deliverables"
)
foreach ($d in $dirs) {
    $path = Join-Path $base $d
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    $gitkeep = Join-Path $path ".gitkeep"
    if (-not (Test-Path $gitkeep)) { New-Item -ItemType File -Path $gitkeep -Force | Out-Null }
}
```

### 4. Write `agent/README.md`

Overview + quickstart, adjusted for the detected tier. Frontmatter:

```yaml
---
title: agent — Project Wiki
type: system-state
status: active
scope: <detected tier>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---
```

Do NOT overwrite an existing `README.md` without asking.

### 5. Write `agent/index.md`

Empty categorised catalog with valid frontmatter. Every category section present but marked `_No pages yet._`:

```yaml
---
title: Wiki Index
type: system-state
status: active
scope: <detected tier>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---
```

Include every category the wiki supports (a **Knowledge** section for `wiki/` and a **Work products**
section for `work/`), per `agent/schema.md`.

### 6. Write `agent/log.md`

Seeded (hand-appended, newest at top) with the scaffolding event:

```markdown
---
title: Project Log
type: system-state
status: active
scope: <detected tier>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

# Log

Append-only chronological event stream. Newest entries at the top.

## [<YYYY-MM-DD>] milestone | wiki | `agent/` scaffolded
Created by `aidevme-wiki-scaffold-project`. Tier: <detected tier>. See `agent/schema.md` for conventions.
```

### 7. Write `agent/schema.md`

For `project` and `personal` tiers, copy the schema from the inherited product wiki at
`shared/dv/agent/schema.md` if present. If not present, write a minimal stub that points at the product
tier and adjust the `scope:` field. For `product` tier, use the canonical schema that already exists in the
repo as the authoritative source. Always include valid frontmatter (`title`, `type`, `status`, `scope`,
`created`, `updated`).

### 8. Verify with `aidevme-wiki-lint`

Run the linter against the freshly scaffolded `agent/`. Expected result: `0 findings`. If there are
findings, the scaffold is broken — report the findings and stop.

### 9. Report to the user

- Path of the scaffolded `agent/`
- Tier detected (and whether it was auto-detected or asked)
- Count of folders created, stub files created
- Lint result (should be clean)
- Suggested next steps:
  - Drop artifacts into `_inbox/` and run `aidevme-wiki-process-inbox`
  - Capture a meeting or doc via `aidevme-wiki-capture`
  - Record a decision via `aidevme-wiki-write-decision`
  - If multi-client: run `hso-wiki-scaffold-client` to add client folders under `wiki/clients/`

## Critical rules

### DO:
- **Be idempotent.** Safe to run multiple times; never overwrite existing files without asking.
- **Detect tier before scaffolding.** `scope:` is load-bearing for cross-tier queries; get it right.
- **Stop on detection of the old numbered layout.** Migration is a separate concern — don't silently overwrite numbered folders.
- **Verify with `aidevme-wiki-lint`** after scaffolding. Clean lint is the success signal.
- **Seed `log.md` with the scaffold event** so the log's history starts at repo birth.
- **Use `.gitkeep` on every empty folder** so git preserves the structure.

### DO NOT:
- **Overwrite existing `.md` files at `agent/` root without asking.** `README.md`, `index.md`, `log.md`, `schema.md` may have been customised.
- **Auto-migrate from the old numbered layout.** If `00_system/`, `03_digests/`, etc. are present, stop and point the user at the migration flow.
- **Scaffold `wiki/clients/` in single-project mode.** That's the multi-client shape — use `hso-wiki-scaffold-client`.
- **Guess the tier silently.** If detection is ambiguous, ask the user.
- **Create an `agent/log/` fragment folder or a generated `log.md`.** This template uses a hand-appended `log.md` (see `agent/schema.md`).
- **Write any content that references client names or project-specific details** in the stub files. Stubs are tier-aware but otherwise generic (ADR-0003 neutrality).

## Related

- [`agent/schema.md`](../../../../agent/schema.md) — the layout, frontmatter, and log/index conventions this skill stamps
- [references/legacy-migration.md](references/legacy-migration.md) — playbook for migrating a repo from the old numbered `agent/` layout to the hybrid layout
- `hso-wiki-scaffold-client` — adds client subfolders for multi-client repos
- `aidevme-wiki-lint` — runs after scaffolding to verify the result
- `aidevme-wiki-capture`, `aidevme-wiki-write-decision`, `aidevme-wiki-process-inbox` — populate the scaffolded wiki with real content

## Changelog

- Ported from the ForgeUSA `aidevme-wiki-scaffold-project` skill and **reconciled to this template's model**:
  dropped the `license:` header (ADR-0003 neutral template); reconciled to the hand-appended `log.md`
  (removed the ADR-0062 fragment-log `log/` folder and the `Update-WikiLog`/`Update-WikiIndex` generators);
  removed the governance/program-tier apparatus (`tier.md`/`policies.md`, `-TierSlug`) not adopted here;
  neutralised `Forge-USA` / `claude-code/skills/` path assumptions to this template's `agent-src` /
  `shared/dv` layout. `scope: core`.

The full history is in **[CHANGELOG.md](CHANGELOG.md)**.
