---
title: "Part 1 — Agent: Expert self-review (r01)"
author: aidevme
type: analysis
status: draft
created: 2026-09-10
scope: template-build
dimension: agent-tooling
---

# Part 1 — Agent layer, expert self-review r01

Reviewer stance: top agent-tooling architect. Scope reviewed: the built agent layer —
`AGENTS.md`, `agent-src/sync/{sync,verify-parity,check-shared}.ps1` +
`skills-manifest.json`, the 16 ported skills, the `agent/` wiki spine, and the generated outputs
(`.claude/`, `.github/`, `CLAUDE.md`). Bar: one source of truth serving both tools with **zero drift
possible**, the live-delivery source's wiki fidelity, and a clean core/project split.

## Verification evidence (this iteration)

| Check | Command | Result |
|---|---|---|
| Script syntax | `PSParser.Tokenize` on all three scripts | OK (951 / 766 / 116 tokens) |
| Dry-run | `sync.ps1 -DryRun` | 16 skills discovered, manifest agrees, guard warns |
| Real sync | `sync.ps1` | 16 → `.claude` + `.github`; generated `CLAUDE.md` + `copilot-instructions.md`; exit 0 |
| Parity | `verify-parity.ps1` | PARITY OK — zero drift; exit 0 |
| Drift backstop (negative test) | inject hand-edit + stray `.zip` | detected DRIFT + stray-zip + cross-tool mismatch; exit 1 |
| Heal | re-run `sync.ps1` → `verify-parity.ps1` | PARITY OK; exit 0 |
| Missing-shared guard | `check-shared.ps1 -Strict` | exit 3 (fires) |

The core claim ("drift cannot land") is demonstrated, not asserted.

## Findings

| # | Sev | File | Finding | Action |
|---|---|---|---|---|
| 1 | minor | `AGENTS.md` (top comment) | The source file's top HTML comment ("Edit THIS file…") is copied verbatim into the GENERATED `CLAUDE.md`/`copilot-instructions.md`, where it reads as self-contradictory next to the "GENERATED — do not hand-edit" preamble. | **Fixed in r02** — reworded the comment to be embedding-safe ("the single SOURCE is AGENTS.md at the repo root…"). Re-synced + re-verified (PARITY OK). |
| 2 | minor | `skills-manifest.json` / `sync.ps1` | Per-skill `target` (claude/copilot) is in the schema but sync fans every skill to BOTH tools; a narrower target is not honoured. | **Accepted as designed** — the dual-assistant principle (ADR-0001 §4) means every skill serves both tools, and `verify-parity` asserts the two trees are byte-identical. `target` is documented as a reserved/future extension in convergence; narrowing it would require relaxing the cross-tool-identical invariant. No code change. |
| 3 | minor | repo root | Generated outputs (`.claude/`, `.github/`, `CLAUDE.md`) and `Worklog/` need explicit git treatment, but the root `.gitignore` is outside this task's write scope. | Documented in `onboarding/agent.md` + ADR-0008 (outputs are committed and gated by `verify-parity`; `Worklog/`, `.worktrees/`, `shared/` must be gitignored). Flagged as a residual setup step. |
| 4 | nit | `sync.ps1` | Manifest/filesystem discrepancies (skill on disk with no `ported=true` entry; scope mismatch) only **warn**, they do not fail. | Accepted — `verify-parity.ps1` is the hard CI gate; sync stays permissive so a half-added skill can still be iterated. |
| 5 | info | `aidevme-wiki-lint` port | The live-delivery source had two invariants numbered "14". | **Fixed on port** — renumbered to 14/15/16 in both the skill and `agent/schema.md`. |
| 6 | info | `agent/raw/` READMEs | A `README.md` under `raw/` would violate the linter's "every `.md` in raw/ is a capture" invariant. | **Fixed on port** — `raw/` folder notes use `.txt`, not `.md`. |

## Blocker / major count: 0

No blockers or majors. One minor (finding 1) warranted a code change; the rest are accepted decisions
or already handled on port. Proceed to r02 apply → converge.
