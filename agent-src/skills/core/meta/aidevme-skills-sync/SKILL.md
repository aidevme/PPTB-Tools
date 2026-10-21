---
name: aidevme-skills-sync
metadata:
  layer: governance
  scope: core
description: |
  Verification backstop for the single-source sync. Confirms the generated skill folders (.claude/skills,
  .github/skills) and instruction files (CLAUDE.md, .github/copilot-instructions.md) match the committed source
  (agent-src/skills/**, AGENTS.md): orphans, drift, cross-tool mismatch, stray artifacts, double-nesting. Also
  validates every source skill against the Agent Skills specification (skills-ref) and checks that every
  aidevme-* skill has a CHANGELOG.md updated with its last change.

  Use when:
  (1) User says "sync skills", "check skill parity", "are the skills in sync?"
  (2) After editing a skill under agent-src/skills/**
  (3) After adding or removing a skill
  (4) Before committing, or in CI
  (5) User asks whether the skills follow the Agent Skills specification
  (6) User asks whether the skills' changelogs are up to date

  Does NOT hand-edit the generated mirrors: drift is fixed by re-running sync.ps1, never by patching
  .claude/ or .github/.
---

# aidevme-skills-sync

This template **inverts** the old twin-mirror model. There is exactly one source of truth:

- `agent-src/skills/{core,project}/**` — committed skill source
- `AGENTS.md` — committed instruction source

`.claude/skills/`, `.github/skills/`, `CLAUDE.md`, and `.github/copilot-instructions.md` are
**build outputs** of `agent-src/sync/sync.ps1`. Because there is only one source, the classic drift
(edit one mirror, forget the other) and the double-nesting bug (`<name>/<name>/`) **cannot originate
here** — they can only appear if someone hand-edited a generated file or ran a bad copy. This skill
detects exactly that.

## Workflow

### 1. Validate the source skills against the Agent Skills specification

```powershell
pwsh -File agent-src/sync/validate-skills.ps1
```

It runs the specification's reference validator (skills-ref, pinned in the script) over every
`agent-src/skills/**/SKILL.md`: only the specification's top-level fields (plus `argument-hint`), `name`
equal to the folder name, and the length limits. Exit 1 lists each invalid skill and its problems: fix them
in the **source** `SKILL.md`. Exit 2 means skills-ref isn't installed: ask before running it with `-Install`,
which downloads the pinned version from PyPI into the gitignored `agent-src/sync/.venv-skills-ref`.

### 2. Run the parity check

```powershell
pwsh -File agent-src/sync/verify-parity.ps1
```

It checks, and **exits non-zero on any problem**:

| Check | Meaning |
|---|---|
| Skill-set parity | `.claude/skills` and `.github/skills` contain exactly the ported source skills — no orphan, none missing |
| Content parity | every file under each generated skill matches its source (MD5) |
| Cross-tool parity | `.claude/skills` and `.github/skills` are byte-identical to each other |
| Instruction parity | `CLAUDE.md` and `copilot-instructions.md` each end with the `AGENTS.md` body |
| Hygiene | no stray `*.zip` in a generated skill; no double-nested `<name>/<name>/` |

### 3. Check the changelogs

```powershell
pwsh -File agent-src/sync/check-changelogs.ps1
```

Every `aidevme-*` source skill must have a `CHANGELOG.md` (written to `docs/templates/CHANGELOG_STYLE.md`) with an
entry for its latest change. The script **exits non-zero** and lists each skill that:

| Problem | Meaning |
|---|---|
| `no CHANGELOG.md` | The skill has no changelog yet |
| `changed without a CHANGELOG.md entry` | Files in the skill are changed in the working tree, but its `CHANGELOG.md` isn't |
| `commit <sha> changed the skill after its last CHANGELOG.md entry` | A commit changed the skill without touching its changelog |

The fix is an entry in the skill's **source** `CHANGELOG.md` (see `aidevme-skill-creator`, Step 8), then sync.
`-Pattern '*'` checks every source skill, including the ones from elsewhere that don't keep a changelog.

### 4. If all three are clean

Report the validation count, "PARITY OK — zero drift" and "CHANGELOGS OK". Nothing to do.

### 5. If parity FAILS

The generated outputs are stale or were hand-edited. **Do not patch the mirrors.** Regenerate:

```powershell
pwsh -File agent-src/sync/sync.ps1            # regenerate both tools from source
pwsh -File agent-src/sync/verify-parity.ps1   # confirm clean
```

If a real intended change is missing, it belongs in the **source** (`agent-src/skills/**` or
`AGENTS.md`) — make it there, then sync. If a manifest/filesystem discrepancy is reported (a skill
on disk with no `ported=true` entry, a scope mismatch, or a `ported=true` entry with no folder),
fix `agent-src/sync/skills-manifest.json` or the folder location, then sync.

## Rules

- The **source** (`agent-src/`) is the only place a skill is edited. Full stop.
- Never resolve drift by editing `.claude/` or `.github/` — that re-creates the very problem this
  model removes.
- CI and pre-commit run `verify-parity.ps1`; a non-zero exit blocks the commit.
- Never silence a changelog problem by editing the check: add the missing entry to the skill's source
  `CHANGELOG.md`.
- A skill that fails `validate-skills.ps1` is fixed in the source, never by adding keys to the validator's
  allowlist; that list (`CLIENT_EXTENSION_KEYS` in `validate_skills.py`) holds only keys a client documents.

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | aidevme | Rewritten from HINT's twin-mirror reconciler into a verification backstop for the inverted (source-committed) model; the double-nesting bug is designed out. |
| 2026-10-18 | aidevme | New first step: validate every source skill against the Agent Skills specification with `agent-src/sync/validate-skills.ps1` (skills-ref); steps renumbered. |
| 2026-10-21 | aidevme | New [CHANGELOG.md](CHANGELOG.md): the skill's full history from its commits. |
| 2026-10-21 | aidevme | New Step 3: `agent-src/sync/check-changelogs.ps1` checks that every `aidevme-*` skill has a `CHANGELOG.md` updated with its last change; steps renumbered. |
