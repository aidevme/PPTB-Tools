---
name: aidevme-skill-creator
layer: meta
scope: core
description: |
  Create a new skill following the template's conventions, placed correctly from birth by a REQUIRED
  scope choice (core | project). Use when:
  (1) User asks to "create a skill", "add a new skill", "build a skill"
  (2) A repeatable workflow should become a reusable capability
  (3) A project-level skill should be promoted to the reusable core
  Enforces naming, the scope split, no-client-data rules, the manifest registration, and a re-sync.
---

# aidevme-skill-creator

Guide for authoring a new skill in the single-source layout. Every new skill is placed under
`agent-src/skills/<scope>/<group>/<name>/` and registered in the manifest — never dropped straight
into a generated `.claude/`/`.github/` directory.

## Step 1 — Choose SCOPE (required)

`--scope` is mandatory. It decides where the skill lives and whether it round-trips to the shared
product tier.

| Scope | Lives in | Round-trips to `shared/` | Use for |
|---|---|---|---|
| `core` | `agent-src/skills/core/<group>/` | Yes | Reusable, customer-agnostic capability |
| `project` | `agent-src/skills/project/<group>/` | No | Anything naming a client, pipeline ID, env URL, or sprint convention |

**Rule:** if the skill would contain a real customer name, a hardcoded environment URL, a specific
pipeline ID, or an engagement-specific workflow, it is `project` until those are externalised to
config. Default to `core` for genuinely reusable workflows.

Core groups: `foundation dataverse server client pipelines delivery reference meta`.

## Step 2 — Name

- Prefix `aidevme-` for product skills (core). Format `aidevme-<domain>-<purpose>` in hyphen-case.
- Examples: `aidevme-dataverse-data`, `aidevme-wiki-lint`, `aidevme-diagram-drawio`.

## Step 3 — Create the folder + SKILL.md

```powershell
$scope = "core"; $group = "delivery"; $name = "aidevme-your-skill"
$base = "agent-src/skills/$scope/$group/$name"        # same for project scope: agent-src/skills/project/<group>/<name>
New-Item -ItemType Directory -Force -Path $base | Out-Null
New-Item -ItemType Directory -Force -Path "$base/scripts","$base/references" | Out-Null   # only if used
```

Do NOT create `README.md`/`CHANGELOG.md` files — only files the skill actively uses.

### Frontmatter

```yaml
---
name: aidevme-your-skill
layer: atomic          # foundation | atomic | orchestration | scenario | governance | meta | reference
scope: core            # core | project — MUST match the folder it lives in
description: |
  One-sentence summary. Use when:
  (1) trigger phrase 1
  (2) trigger phrase 2
  What it does NOT do.
# allowed-tools: Read, Grep, Glob      # OPTIONAL — set on INTERACTIVE skills to fence tool access
# argument-hint: <ticket-key>          # OPTIONAL — set on skills invoked with an argument
---
```

The `description` IS the trigger mechanism — make it comprehensive and include an explicit **"Use
when"** list and a **"Does NOT"** clause so the router picks between sibling skills correctly; the
body loads only after the skill fires. Keep SKILL.md under ~400 lines; push detail into `references/`.

On an **interactive** skill (one the user invokes directly, often with an argument), add
`allowed-tools:` and `argument-hint:` frontmatter — the Anthropic skill-frontmatter conventions —
so the tool surface and expected argument are declared up front.

### Layer taxonomy

| Layer | What it is |
|---|---|
| `foundation` | Bedrock a project stands on (architecture map, init, **shared-scripts / atlassian-auth libraries**) |
| `atomic` | A single self-contained capability |
| `orchestration` | Chains atomic skills to do a larger job. **References** the atomic skills — it never copies their content |
| `scenario` | A thin entry-point above orchestration that delegates immediately to a chain of skills (e.g. an end-to-end conductor). Same "reference, never copy" rule as orchestration |
| `governance` | A gate/policy check |
| `meta` | A skill about skills/the template |
| `reference` | Read-only knowledge lookup |

**Rule (orchestration & scenario):** these layers *reference* atomic skills by name and invoke them;
they must not paste an atomic skill's steps inline. Duplicated content drifts — point at the source.

## Step 4 — No hardcoding (especially core)

Read project-specific values from config, never hardcode them:

- From `CLAUDE.md` / `AGENTS.md`: publisher prefix, default solution, environment URL, MCP server.
- From `CLAUDE.local.md`: author name, tool paths, ADO org/PAT.
- If a required value is missing, ASK — never guess. Use `<placeholder>` syntax in examples.

## Step 5 — Register in the manifest

Add an entry to `agent-src/sync/skills-manifest.json`:

```json
{ "name": "aidevme-your-skill", "scope": "core", "group": "delivery", "ported": true, "source": "authored" }
```

`ported: true` means the folder exists and the sync will fan it out.

## Step 6 — Sync + verify

```powershell
pwsh -File agent-src/sync/sync.ps1
pwsh -File agent-src/sync/verify-parity.ps1     # must be clean
```

Never place skill files directly in `.claude/skills` or `.github/skills` — they are generated.

## Critical rules

- NEVER put client names, environment URLs, org/PAT, or secrets in a `core` skill.
- ALWAYS register in the manifest with the correct scope, then sync.
- ALWAYS include a `Changelog` section (date · author · description).

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | aidevme | Ported from HINT; added the required core|project scope selector, manifest registration, and the sync/verify step for the inverted model. |
