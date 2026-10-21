---
name: aidevme-skill-creator
metadata:
  layer: meta
  scope: core
description: |
  Create or update a skill following the template's conventions, placed correctly from birth by a REQUIRED
  scope choice (core | project) and validated against the Agent Skills specification with skills-ref. Use when:
  (1) User asks to "create a skill", "add a new skill", "build a skill"
  (2) A repeatable workflow should become a reusable capability
  (3) A project-level skill should be promoted to the reusable core
  (4) An existing skill's SKILL.md frontmatter changes (name, description, metadata, tools)
  (5) Any change to an existing skill under agent-src/skills/ (it adds the CHANGELOG.md entry)
  Enforces naming, the scope split, no-client-data rules, spec-valid frontmatter, the manifest registration,
  a CHANGELOG.md entry for every change, and a re-sync.
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
- Examples: `aidevme-docs-maintenance`, `aidevme-wiki-lint`, `aidevme-diagram-drawio`.

## Step 3 — Create the folder, SKILL.md and evals/

```powershell
$scope = "core"; $group = "delivery"; $name = "aidevme-your-skill"
$base = "agent-src/skills/$scope/$group/$name"        # same for project scope: agent-src/skills/project/<group>/<name>
New-Item -ItemType Directory -Force -Path $base, "$base/evals" | Out-Null                 # evals/ always
New-Item -ItemType Directory -Force -Path "$base/scripts","$base/references" | Out-Null   # only if used
```

Do NOT create a `README.md` — only files the skill actively uses, plus `evals/evals.json` (Step 4) and
`CHANGELOG.md` (Step 8), which every skill has.

### Frontmatter

```yaml
---
name: aidevme-your-skill   # MUST equal the folder name; lowercase letters, digits, single hyphens; max 64
metadata:
  layer: atomic            # foundation | atomic | orchestration | scenario | governance | meta | reference
  scope: core              # core | project — MUST match the folder it lives in
description: |             # max 1024 characters
  One-sentence summary. Use when:
  (1) trigger phrase 1
  (2) trigger phrase 2
  What it does NOT do.
# allowed-tools: Read, Grep, Glob      # OPTIONAL — set on INTERACTIVE skills to fence tool access
# argument-hint: <ticket-key>          # OPTIONAL — set on skills invoked with an argument
---
```

Only the [Agent Skills specification](https://agentskills.io/specification)'s fields go at the top level: `name`,
`description`, `license`, `allowed-tools`, `metadata` and `compatibility`, plus `argument-hint`, which Claude
Code reads there. Repository conventions (`layer`, `scope`) go under `metadata`. Step 7 checks this.

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

## Step 4 — Write evals/evals.json

Every skill ships test prompts in `evals/evals.json`, in the format all the repository's skills share (the
`skill-creator` skill runs and grades them):

```json
{
  "skill_name": "aidevme-your-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "A realistic request a user would type",
      "expected_output": "One or two sentences describing a good result",
      "files": [],
      "expectations": [
        "A specific, checkable behavior (which script or command is run, which file changes, what is asked first)",
        "Another one"
      ]
    }
  ]
}
```

- **At least three cases**, written as a user would ask, drawn from the description's "Use when" triggers.
- **Cover the risks:** at least one case for an edge or a "Does NOT" boundary (an ambiguous request, a refused
  shortcut, an action that needs approval first).
- **Checkable expectations:** name the exact script, parameter, file or question, so a grader can mark each one
  passed or failed. Avoid vague ones such as "does it well".
- `skill_name` must equal the folder name and the frontmatter `name`; `id`s count up from 1; `files` lists input
  files under `evals/files/`, or stays `[]`.

## Step 5 — No hardcoding (especially core)

Read project-specific values from config, never hardcode them:

- From `CLAUDE.md` / `AGENTS.md`: publisher prefix, default solution, environment URL, MCP server.
- From `CLAUDE.local.md`: author name, tool paths, ADO org/PAT.
- If a required value is missing, ASK — never guess. Use `<placeholder>` syntax in examples.

## Step 6 — Register in the manifest

Add an entry to `agent-src/sync/skills-manifest.json`:

```json
{ "name": "aidevme-your-skill", "scope": "core", "group": "delivery", "ported": true, "source": "authored" }
```

`ported: true` means the folder exists and the sync will fan it out.

## Step 7 — Validate against the Agent Skills specification

```powershell
pwsh -File agent-src/sync/validate-skills.ps1 agent-src/skills/<scope>/<group>/<name>   # must print "1 valid"
```

The script runs the specification's reference validator, [skills-ref](https://github.com/agentskills/agentskills)
(pinned in the script, installed in the gitignored `agent-src/sync/.venv-skills-ref`). It checks the allowed
fields, that `name` matches the folder, and the length limits (`name` 64, `description` 1024, `compatibility`
500), and sets aside only `argument-hint`. Exit 2 means skills-ref isn't installed: ask the user before running
`validate-skills.ps1 -Install`, which downloads it from PyPI. Fix every problem it reports in the source
`SKILL.md`, never in the generated copies, and re-run until it's clean.

**Updating an existing skill:** run the same command after any change to its `SKILL.md` frontmatter, add the
change to its `CHANGELOG.md` (Step 8), then sync.

## Step 8 — Record the change in CHANGELOG.md

Every skill has a `CHANGELOG.md` next to its `SKILL.md`, written to the repository's changelog style guide,
`docs/templates/CHANGELOG_STYLE.md`. Every change to a skill (its
`SKILL.md`, references, scripts, assets or evals) adds an entry **in the same commit as the change**:

- **New skill:** `CHANGELOG.md` is created automatically from the style guide's template, filled in from
  `SKILL.md`, with an **Added** entry for the skill itself: by the Claude Code hook as soon as the skill's first
  file is written, or by `sync.ps1` for any `aidevme-*` skill without one. Rewrite that first entry so it says what
  the skill ships with (modes, references, scripts, what it was checked against). To create it yourself:

  ```powershell
  pwsh -File agent-src/sync/update-changelog.ps1 -Skill aidevme-your-skill
  ```

- **Update:** after every change, add the entry with `update-changelog.ps1`. It puts the entry under
  `## <today>` (created at the top when missing) in the category's section, in the style guide's order, and
  skips an entry that's already there. In Claude Code, the hook reminds you after the first edit to a skill whose
  changelog isn't changed yet.

  ```powershell
  pwsh -File agent-src/sync/update-changelog.ps1 -Skill aidevme-your-skill -Category Changed `
    -Entry '**<The change, in a short phrase>.** <What it means for the person using the skill, naming the file or option.>'
  ```

  Categories: **Added**, **Changed**, **Deprecated**, **Removed**, **Fixed**, **Security**. Lead with the change in
  bold and say what it means for the reader. Breaking changes start with `**Breaking:**`.
- **The commit:** entries end with the commit's short SHA. The SHA doesn't exist until you commit, so leave it off
  in the commit that adds the entry; it's added the next time the file changes, or by the next entry's author.
- **`SKILL.md`:** add a one-line row for the change to its **Changelog** table as well.

Write what changed for the reader, not how; the reasoning stays in the commit message. Internal-only edits (a typo,
re-wrapped lines) still get a short **Changed** or **Fixed** entry, so the check in Step 9 stays meaningful.

## Step 9 — Sync + verify

```powershell
pwsh -File agent-src/sync/sync.ps1
pwsh -File agent-src/sync/verify-parity.ps1     # must be clean
pwsh -File agent-src/sync/check-changelogs.ps1  # must print "CHANGELOGS OK"
```

The sync copies the whole folder, `evals/` and `CHANGELOG.md` included, to `.claude/skills` and `.github/skills`.
Never place skill files directly there — they are generated. `check-changelogs.ps1` fails when an `aidevme-*`
skill has no `CHANGELOG.md`, or was changed (in the working tree or a commit) without its `CHANGELOG.md`.

## Critical rules

- NEVER put client names, environment URLs, org/PAT, or secrets in a `core` skill.
- ALWAYS register in the manifest with the correct scope, then sync.
- ALWAYS include a `Changelog` section (date · author · description).
- ALWAYS give a skill a `CHANGELOG.md`, and add an entry to it in the same commit as every change to the skill
  (Step 8); `check-changelogs.ps1` must pass.
- ALWAYS create `evals/evals.json` with at least three test cases, one of them an edge or boundary case.
- ALWAYS run `agent-src/sync/validate-skills.ps1` on the skill after creating or changing it, and fix what it reports
  before syncing.

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | aidevme | Ported from HINT; added the required core\|project scope selector, manifest registration, and the sync/verify step for the inverted model. |
| 2026-10-16 | aidevme | New skills always get `evals/evals.json` (new Step 4 with the shared format and guidance; critical rule); steps renumbered. |
| 2026-10-18 | aidevme | Skills are validated against the Agent Skills specification with skills-ref (new Step 7, `agent-src/sync/validate-skills.ps1`, also after updates); `layer` and `scope` move under `metadata`; sync is now Step 8. |
| 2026-10-21 | aidevme | New [CHANGELOG.md](CHANGELOG.md): the skill's full history from its commits. |
| 2026-10-21 | aidevme | Every skill has a `CHANGELOG.md`, and every change adds an entry in the same commit (new Step 8, critical rule, trigger 5); `check-changelogs.ps1` joins the sync step, now Step 9. Replaces the rule against `CHANGELOG.md` files. |
| 2026-10-21 | aidevme | Changelogs are created and placed automatically: `update-changelog.ps1` (from the style guide's template), `sync.ps1` for missing ones, and a Claude Code PostToolUse hook; Step 8 shows the commands. |
