---
title: "Part 1 — Agent: Convergence"
author: maciejnowicki
type: analysis
status: active
created: 2026-09-10
scope: template-build
dimension: agent-tooling
---

# Part 1 — Agent layer, convergence

The agent layer is built and converged after 2 review iterations (r01 findings → r02 fix →
re-verify). This records what was built, what was ported vs catalogued, the verification evidence,
and residual risks.

## What was built

1. **Single-source → dual-tool mechanism.** `AGENTS.md` (committed source) → generated `CLAUDE.md` +
   `.github/copilot-instructions.md`, each with a tool-specific preamble prepended at sync time and a
   "GENERATED — do not hand-edit" banner. `agent-src/sync/sync.ps1` fans
   `agent-src/skills/{core,project}` into `.claude/skills` + `.github/skills`;
   `skills-manifest.json` records each skill's `scope` + tool targets;
   `verify-parity.ps1` is the MD5 drift/orphan/cross-tool/instruction backstop (fail on drift);
   `check-shared.ps1` is the fail-fast missing-`shared/` guard. HINT's model is **inverted**: the
   source is committed, `.claude`/`.github` are outputs. HINT's double-nesting bug is designed out
   (clean-then-copy into a fresh dest dir) and verified against; stray `.zip` files are pruned on sync
   and flagged by parity.

2. **Wiki = the live-delivery source's hybrid `agent/` wholesale.** Ported `schema.md` (4 layers, no numbering,
   anchors-not-content, captures + fidelity ceiling, strict frontmatter, the enumerated linter
   invariants — renumbered to fix a duplicate), `README.md`, a clean starter `index.md` + `log.md`,
   and short READMEs across every `wiki/`/`work/` subfolder (`.txt` in `raw/` to respect the
   capture-only rule). Added the in-repo **missing-`shared/` guard** that fails fast — closing the live-delivery source's
   dangling-inheritance gap.

3. **Core vs project split.** `agent-src/skills/core/` grouped (foundation dataverse server client
   pipelines delivery reference meta) + `agent-src/skills/project/`. The manifest carries the FULL §7
   classification of every skill (core | project | drop).

4. **Reusable behaviours encoded neutrally** in `AGENTS.md`: triage-first, env-safety (Dev-only
   writes / verify connection), worktree discipline, Template-First, and product/project/personal
   tiering — no client/ticket specifics.

## Skills: ported vs catalogued

**Ported in full (16 real SKILL.md folders):**

| Group | Skills |
|---|---|
| foundation | `hso-template-architecture`, `hso-architecture-map` (+ `topo-maintenance.md`, `templates/solution-map.topo`) |
| meta | `aidevme-skills-sync` (rewritten for the inverted model), `aidevme-skill-creator` (adds required `--scope core\|project`) |
| server | `hso-plugin-development` |
| client | `hso-formscript-development`, `hso-pcf-control-development` |
| pipelines | `hso-pipeline-generation` |
| dataverse | `hso-dataverse-data-modeling` |
| delivery | `aidevme-wiki-lint`, `aidevme-wiki-process-inbox`, `aidevme-wiki-capture`, `aidevme-wiki-write-decision`, `worklog` (+ `worklog.ps1`, neutralised ticket-key regex) |
| project (examples) | `deploy-solutions` (stub), `close-ticket` (stub) |

All ported skills are neutralised per ADR-0003 (tokens `HSO.Customer.*`, `hso_customer_`, `hso`;
no client/ticket names) and stamped with `scope:` frontmatter matching their manifest entry.

**Catalogued (classified in the manifest, not yet ported — 85):** the remaining core skills across
every group (e.g. `hso-project-upgrade`, `hso-generated-file-review`, `aidevme-dataverse-customapi`,
`hso-dataverse-ui-config`, `hso-server-framework`, `hso-functions-development`,
`hso-client-ruleengine`, the rest of the `hso-wiki-*` family, the reference skills, the diagram
skills) and the remaining project skills (`crm-deploy-uat`, `crm-env-status`,
`hso-conversationmap-development`, `hso-close-ticket`, `hso-jira-updates`, …). Each has a manifest
entry with `scope` + `source`, so a later sync can pull it from HINT/the live-delivery source. **Dropped (5, recorded):**
`hso-ingest-transcript` / `hso-ingest-discovery-artifact` (superseded by `hso-wiki-ingest-*`), the two
stray `.zip` "skills", and the double-nested `aidevme-skills-sync/aidevme-skills-sync/` bug artifact.

## Verification evidence

- `sync.ps1`: 16 skills → both tools; generated both instruction files; exit 0.
- `verify-parity.ps1`: PARITY OK — zero drift; exit 0. Negative test injected a hand-edit + a stray
  `.zip` → 5 issues detected (drift, stray-zip, cross-tool mismatch), exit 1; re-sync healed to exit 0.
- `check-shared.ps1 -Strict`: exit 3 (guard fires) with an actionable message.
- All three scripts pass `PSParser` syntax tokenisation.

## Residual risks / follow-ups

1. **Root `.gitignore` is outside this task's write scope.** A consuming repo must gitignore
   `Worklog/`, `.worktrees/`, `shared/`, and (if outputs are treated as pure build artifacts)
   `.claude/skills` + `.github/skills`. Recommended here: **commit** the generated outputs (so a fresh
   clone works with no build step) and gate every commit with `verify-parity.ps1`. Documented in
   `onboarding/agent.md`.
2. **85 catalogued skills are not yet real files.** They are classified, not ported; pulling them is a
   follow-up sync from HINT/the live-delivery source (respecting neutralisation).
3. **Per-skill `target` is reserved.** Today every skill serves both tools (dual-assistant principle);
   honouring a narrower target would require relaxing the cross-tool-identical parity invariant.
4. **The linter and most skills are specifications, not executable code.** `aidevme-wiki-lint` etc.
   describe the workflow an agent runs; only `sync`/`verify`/`check-shared`/`worklog` are runnable
   scripts. That matches the source repos' skill model.

## Status: converged.
