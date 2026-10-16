---
adr: 0008
title: Agent single-source → dual-tool sync mechanism
status: accepted
date: 2026-09-10
author: maciejnowicki
supersedes: []
---

# ADR-0008 — Agent single-source → dual-tool sync mechanism

## Context

The template must serve **both** Claude Code (`.claude/`) and GitHub Copilot (`.github/`) from one
authored source, with no hand-maintained mirror (ADR-0001 §4). HINT proved the dual-tool idea but
committed **two** hand-edited skill mirrors and two hand-edited instruction files, then spent a whole
governance apparatus (`aidevme-skills-sync`, `hso-repo-hygiene`) fighting the drift that design creates —
and still shipped a double-nested `aidevme-skills-sync/aidevme-skills-sync/` copy and stray `.zip` artifacts.
The live-delivery source avoided the drift by being Claude-only, but then has no Copilot path at all. We need the reach
of HINT without its drift surface.

## Options considered

1. **Commit two mirrors, reconcile with a skill (HINT).** Pros: tools read their native dirs
   directly. Cons: perpetual drift; two instruction files; the exact bugs HINT shipped.
2. **Symlink/junction one dir to the other.** Pros: no copy. Cons: fragile on Windows/CI, git treats
   symlinks poorly, Copilot/Claude discovery expects real files.
3. **Single committed source + generated outputs, with a parity gate (chosen).** Author skills once
   under `agent-src/skills/{core,project}` and instructions once in `AGENTS.md`; **generate**
   `.claude/skills`, `.github/skills`, `CLAUDE.md`, and `copilot-instructions.md`; verify byte-parity
   in CI/pre-commit. Pros: drift **cannot land** (one source; outputs regenerated + verified). Cons: a
   sync step must run after any source edit — enforced by the parity gate.

## Decision

Adopt option 3 — **invert HINT's model: the source is committed; `.claude`/`.github` and the two
instruction files are build outputs.**

- `agent-src/sync/sync.ps1` — fans the physical skills under `agent-src/skills/**` into both tool
  dirs (clean-then-copy into a fresh dest dir, so double-nesting is impossible; `.zip` pruned), and
  generates `CLAUDE.md` / `copilot-instructions.md` = tool preamble (`agent-src/sync/preambles/*.md`)
  + the `AGENTS.md` body. `-DryRun` and `-Target Claude|Copilot|Both`.
- `agent-src/sync/skills-manifest.json` — the registry: every skill's `scope` (core | project | drop),
  group, `ported` flag, and source repo. Core round-trips to `shared/`; project never does.
- `agent-src/sync/verify-parity.ps1` — the hard gate: MD5 every generated file against source; check
  skill-set parity (no orphan / none missing), cross-tool byte-identity, that each instruction file
  ends with the `AGENTS.md` body, and hygiene (no stray `.zip`, no `<name>/<name>/`). **Exit 1 on any
  drift.** Runs in CI and pre-commit.
- `agent-src/sync/check-shared.ps1` — fail-fast guard for the inherited `shared/` product tier
  (`-Strict` → exit 3 when absent); closes the live-delivery source's dangling-inheritance gap.

**Generated outputs are committed** (so a fresh clone works with no build step for either tool) and
their integrity is guaranteed by the `verify-parity` gate rather than by trust. A source edit that is
not followed by a sync fails the gate before it can be committed.

## Rationale

- **Drift is designed out, not policed.** With one source and a verified regeneration, the twin-mirror
  drift class and the double-nesting/stray-zip bugs cannot recur — demonstrated by a negative test
  (inject hand-edit + `.zip` → parity exit 1; re-sync → exit 0).
- **One instruction source** removes HINT's *other* drift surface (two near-duplicate CLAUDE.md /
  copilot files).
- **The core/project split is first-class** (manifest `scope`), replacing HINT's commented-out
  `$repoSpecificSkills` array, and only core round-trips upstream.
- **Reusability:** the mechanism is customer-neutral; skills are neutralised to the ADR-0003 tokens.

## Consequences

- Skills and instructions are edited ONLY under `agent-src/` / `AGENTS.md`; editing a generated file
  is a defect the gate catches.
- CI/pre-commit must run `verify-parity.ps1`; a non-zero exit blocks the commit.
- New skills are created via `aidevme-skill-creator` with a required `--scope`, registered in the
  manifest, then synced.
- A consuming repo must gitignore `Worklog/`, `.worktrees/`, and `shared/` (the junction), and provide
  the `shared/` junction (guarded by `check-shared.ps1 -Strict`). Root `.gitignore` was outside the
  Part-1 build scope; see `docs/onboarding/agent.md`.
