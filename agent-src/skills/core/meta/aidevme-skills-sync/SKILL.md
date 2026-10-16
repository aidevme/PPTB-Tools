---
name: aidevme-skills-sync
layer: governance
scope: core
description: |
  Verification backstop for the single-source → dual-tool sync. Confirms the GENERATED tool
  directories (.claude/skills, .github/skills) and the generated instruction files (CLAUDE.md,
  .github/copilot-instructions.md) exactly reflect the committed SOURCE (agent-src/skills/**,
  AGENTS.md). Reports orphans, drift, cross-tool mismatch, stray artifacts, and double-nesting.

  Use when:
  (1) User says "sync skills", "check skill parity", "are the skills in sync?"
  (2) After editing a skill under agent-src/skills/** — verify the outputs were regenerated
  (3) After adding/removing a skill — confirm the manifest and both tool dirs agree
  (4) Before committing / in CI — parity must be clean

  Does NOT: hand-edit the generated mirrors (that is what drift IS). The fix for any drift is to
  re-run the generator (sync.ps1), never to patch .claude/ or .github/ by hand.
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

### 1. Run the parity check

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

### 2. If parity is clean

Report "PARITY OK — zero drift". Nothing to do.

### 3. If parity FAILS

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

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | maciejnowicki | Rewritten from HINT's twin-mirror reconciler into a verification backstop for the inverted (source-committed) model; the double-nesting bug is designed out. |
