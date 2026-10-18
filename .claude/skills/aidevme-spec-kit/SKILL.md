---
name: aidevme-spec-kit
metadata:
  layer: orchestration
  scope: core
description: |
  Spec-driven development (SDD) with GitHub Spec Kit, one entry point: detects which phase the repository is in,
  runs the matching installed /speckit-* command, checks the file it produced, and stops for review before the next
  phase. Wraps Spec Kit; never re-implements or edits its prompts. Use when:
  (1) User says "spec this feature", "start SDD", or "set up spec kit"
  (2) User asks to write the constitution, a spec, a plan or tasks
  (3) User says "implement the tasks" or "do the whole thing"
  (4) User asks "does the code still match the spec"
  Does NOT write code before the tasks are approved; commit, push, branch or open pull requests (handed to
  aidevme-github); overwrite .specify/, the constitution or existing specs without asking; or edit Spec Kit's own
  skills or templates (use presets or project-local overrides).
allowed-tools: Bash, PowerShell, Read, Write, Edit, Grep, Glob, AskUserQuestion
argument-hint: "[feature description | phase]"
---

# aidevme-spec-kit: spec-driven development with Spec Kit

<!-- cspell:ignore speckit taskstoissues -->

One entry point for the [Spec Kit](https://github.com/github/spec-kit) SDD process in Claude Code. This file holds
the phase detection, the shared rules and the routing; each phase is in a reference file under `references/`. Load
only the reference the current phase needs. Checked against Spec Kit **v1.2.1** (2026-10-17).

## Phase detection (run first)

Check in this order and stop at the first match. Say the detected phase and the next action before doing anything.

| Check | Phase |
| --- | --- |
| No `.specify/` folder | setup |
| `.specify/memory/constitution.md` missing, or still has template placeholders such as `[PROJECT_NAME]` or `[PRINCIPLE_1_NAME]` | constitution |
| No current feature: `.specify/feature.json` missing and no `specs/NNN-*/spec.md` for the requested feature | specify |
| `spec.md` but no `plan.md` in the feature folder | plan |
| `plan.md` but no `tasks.md` | tasks |
| `tasks.md` has open items (`- [ ] T…`) | implement |
| All tasks ticked (`- [x]`) | converge |

The current feature is the folder in `.specify/feature.json` (`feature_directory`). If the request names another
feature, or several `specs/NNN-*` folders could match, ask which one.

## Shared rules (every phase)

- **One phase per step, then stop** for the user's approval. "Do the whole thing" chains the phases but still stops
  at every review gate.
- **Every phase ends with a file to review** (constitution, `spec.md`, `plan.md`, `tasks.md`, code and tests, the
  converge result). Name the file and summarize what changed.
- **No guessing.** Unclear requirements become `[NEEDS CLARIFICATION: …]` markers in the spec or questions to the
  user.
- **No code before the tasks are approved.** Asked to "build it" earlier, say which phase is waiting and why.
- **Use the installed version's command names.** v1.2.1 uses `/speckit-<command>` for Claude Code skills; check
  `.claude/skills/speckit-*` when unsure.
- **Never edit Spec Kit's files** (`.claude/skills/speckit-*`, `.specify/templates/`, `.specify/scripts/`). Customize
  through presets or `.specify/templates/overrides/` (see [troubleshooting.md](references/troubleshooting.md)).
- **Never overwrite** `.specify/`, the constitution or an existing spec, plan or tasks file without asking.
- **No git or GitHub writes.** Commits, branches, pushes, issues and pull requests go through aidevme-github
  ([github-handoff.md](references/github-handoff.md)).
- Follow the repository's own rules (`AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`) where they're stricter.

## Routing

| Request or detected phase | Load |
| --- | --- |
| setup: install or initialize Spec Kit, check the version | [references/setup.md](references/setup.md) |
| constitution: write or change the project principles | [references/constitution.md](references/constitution.md) |
| Choose principles for a Power Platform project | [references/profiles/power-platform.md](references/profiles/power-platform.md) |
| Choose principles for a TypeScript web project | [references/profiles/typescript-web.md](references/profiles/typescript-web.md) |
| specify: write or clarify a feature spec | [references/specify.md](references/specify.md) |
| plan: technical plan, consistency check | [references/plan.md](references/plan.md) |
| tasks: break the plan into tasks, optional issues | [references/tasks.md](references/tasks.md) |
| implement: work through the tasks | [references/implement.md](references/implement.md) |
| converge: "does the code still match the spec", before a pull request | [references/converge.md](references/converge.md) |
| Commits, branches, issues, pull requests, CI | [references/github-handoff.md](references/github-handoff.md) |
| Errors, renamed flags, upgrades, "command not found" | [references/troubleshooting.md](references/troubleshooting.md) |

### "Do the whole thing"

Run the phases from the detected one onward (constitution, specify, plan, tasks, implement, converge), each through
its reference, and stop at each review gate until the user approves. Never skip a gate because the user asked for
speed; say which gate is waiting instead.

## Changelog

| Date | Author | Description |
| --- | --- | --- |
| 2026-10-17 | aidevme | Created: phase detection, review gates, routing to per-phase references, `power-platform` and `typescript-web` profiles, and the handoff to aidevme-github; checked against Spec Kit v1.2.1. |
