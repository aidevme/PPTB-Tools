---
name: aidevme-pptb-tool-refactoring
layer: orchestration
scope: project
description: |
  Analyze and refactor one or more PPTB tools under tools/ in stages: a read-only analysis that produces a
  refactoring proposal (current state, plan, risks, summary), a TODO file in docs/todos/ written before any change,
  then execution of only the steps the user approves, with a build and test check after each step and the report
  added to the same TODO file. The user can also save the plan as a TODO file only, without any code change. Use when:
  (1) User says "refactor <tool>", "analyze <tool> for refactoring", "propose a refactoring plan", "clean up the tools"
  (2) User wants a code-quality, dependency, UI consistency or test-coverage review of a tool that ends in a plan
  (3) User wants a refactoring plan saved as a TODO list to do later
  (4) An approved refactoring proposal should be executed step by step
  Does NOT modify any file before explicit approval, touch tools the user didn't select, make breaking changes
  without approval, or overwrite existing files in docs/todos/. Does NOT do marketplace policy reviews
  (intake-policy-review) or Verified badge reviews (tool-verification).
allowed-tools: Bash, PowerShell, Read, Grep, Glob, Edit, Write, AskUserQuestion
argument-hint: "[tool-name ... | all]"
---

# aidevme-pptb-tool-refactoring

<!-- cspell:ignore lockfiles toplevel -->

Seven phases. Phases 1–3 change nothing. Phase 4 writes the TODO file and nothing else; it runs after an "accept" or
"Save as TODO only" answer. Phase 5 runs only after an "accept" answer, and Phases 6 and 7 follow it automatically.
Templates: [`references/proposal-template.md`](references/proposal-template.md) (Phases 2 and 3) and
[`references/todo-template.md`](references/todo-template.md) (Phases 4, 6 and 7).

## Phase 1 — Selection

1. **Discover the tools:** every `tools/<name>/` folder with a `package.json`. A folder without one isn't a tool;
   mention it but don't offer it. Show each tool's `displayName`, `version` and which of `build`, `test` and
   `validate` scripts it has.
2. **Ask which tools to analyze** (AskUserQuestion, multi-select, plus an "All tools" option). Tool names passed as
   arguments count as the answer, but confirm any that don't match a discovered tool.
3. **Scope is fixed from here.** Read shared files (root `package.json`, `AGENTS.md`, other tools for comparison)
   only to inform the selected tools; never analyze or propose changes for an unselected tool.

## Phase 2 — Analysis (read-only)

**No file may be created or modified in this phase**, including lockfiles, `dist/`, caches you control and
`docs/todos/`. Allowed commands are read-only ones: `git log`/`git status`, `npm outdated`, `npm ls`,
`npm audit --json`, and `npm run build` / `npm test` only when they write nothing tracked (`dist/` is gitignored;
check `git status` before and after and report any change). Never run `npm install`, `npm audit fix` or a formatter.

For each selected tool, produce the proposal in [`references/proposal-template.md`](references/proposal-template.md):

- **a) Current state:**
  - structure, architecture and key components;
  - code quality (duplication, complexity, typing gaps such as `any` or `as` casts, dead code, naming, error
    handling);
  - dependencies (outdated, vulnerable, unused; check imports before calling one unused);
  - UI/UX consistency with the other AIDevMe tools (Fluent UI v9 usage, theming, layout, notifications);
  - performance and maintainability;
  - test coverage (which modules have tests, which don't; run coverage only if the tool is configured for it).
- **b) Refactoring plan:**
  - prioritized steps, each with a rationale, the expected benefit and an effort of S, M or L;
  - grouped into small, reviewable units in execution order;
  - each step lists the files it touches.
- **c) Risk analysis:**
  - a risk level per step (Low, Medium or High);
  - breaking changes to behavior or public interfaces (exports, the manifest, saved config keys, generated
    output, file formats);
  - impact on users, dependencies and other tools;
  - mitigation and rollback for every Medium or High step.
- **d) Summary:** an overall recommendation and a short overview of all proposed changes.

Ground every finding in a file path and line, a command result or a measurement; say "not checked" rather than
guess. Respect the repository's invariants in `AGENTS.md` (for example the generator's byte-for-byte output, the
IIFE build in `vite.config.ts`, LF reference files): a step that would break one is a breaking change.

## Phase 3 — Approval

Present the proposal(s), then ask (AskUserQuestion) for one of:

- **Accept all proposed changes**
- **Accept selected steps only:** ask which step IDs, per tool; note any step that depends on an unselected one.
- **Save as TODO only (no changes):** Phase 4 writes the TODO file, then the skill ends. No code, config or docs
  file is changed and nothing is committed.
- **Reject:** end. Nothing is written, not even a TODO file.

**Request changes to the plan** comes through the question's free-text "Other" answer: revise, re-present, ask again.

**Never start Phase 5 without one of the two "accept" answers.** Breaking changes need their own explicit approval:
a step flagged as breaking is only executed if the user accepted it knowing that. Silence, "looks good" about the
analysis, "Save as TODO only", or approval of a different plan version isn't approval to execute.

## Phase 4 — TODO file (before any change)

Runs right after an "accept" or "Save as TODO only" answer, before any other file is touched. It's the only write
allowed before execution.

1. Folder: `docs/todos/` at the repository root (`git rev-parse --show-toplevel`; here
   `C:\aidevme\PPTB-Tools\docs\todos`). Create it if it doesn't exist.
2. One file per selected tool: `refactoring-<tool-name>-<YYYY-MM-DD>.md` (today's date). **Never overwrite an
   existing file:** if the name exists, use `-02`, `-03`, … (`refactoring-<tool-name>-<YYYY-MM-DD>-02.md`). Check
   with `Test-Path` before writing, and write with a create-only operation.
3. Content: [`references/todo-template.md`](references/todo-template.md) with status `Planned` (an "accept" answer)
   or `Saved as TODO, no changes made` ("Save as TODO only"): header (tool, date, skill, decision, proposal
   version), the full Phase 2 analysis, and a `## TODO` checklist with one `- [ ]` item per step (ID, change, files,
   effort, risk), marking which steps were approved.
4. Validate it with `aidevme-docs-maintenance` (Validate-Markdown on that file); fix markdownlint findings in the
   file and add one-off words to a `<!-- cspell:ignore … -->` comment after the H1.
5. Don't modify other files in `docs/todos/` (no index updates) and don't commit the file unless asked.
6. Tell the user the saved path(s). After "Save as TODO only", end here and say plainly that nothing else changed.

## Phase 5 — Execution

1. **Before the first step:** confirm the working tree is clean (`git status`) apart from the TODO file Phase 4
   just wrote; if it isn't, stop and ask. If on the default branch (`main`), create a branch first
   (`refactor/<tool-name>`).
2. **One tool at a time, one approved step at a time, in the agreed order.** Execute only approved steps; don't widen
   a step's scope or fix unrelated issues you notice (record them as follow-ups).
3. **After each step, verify** from the tool's folder: `npm run build` and, when defined, `npm test` (also
   `npm run validate` when the step touches the manifest). Record the command, exit code and test counts.
4. **On failure or an unexpected issue** (build or test failure, a changed snapshot or reference output, a step that
   turns out bigger or riskier than planned): stop, report what happened and the likely cause, and ask whether to fix
   forward, revert the step (`git restore` / `git revert` of that step's commit), skip it, or stop.
5. **Commit each step** after it verifies, in Conventional Commits format (`CONTRIBUTING.md`):
   `refactor(<tool-name>): <subject>` (or `fix`, `test`, `chore(deps)` as fits), body with the step ID and the
   verification result. Stage only the step's files, never the TODO file. The user's approval of the plan is the
   approval for these commits; don't push.
6. **Docs move with code:** update the tool's README, docs pages and TSDoc in the same step when behavior or
   structure they describe changes. Run `aidevme-docs-maintenance` (Validate-Markdown) on changed Markdown.

## Phase 6 — Report

Per tool: steps completed, skipped and failed (with reasons), files changed (`git diff --stat` over the steps'
commits), verification results per step, commit SHAs, and recommended follow-ups. Say plainly what wasn't verified,
for example behavior that needs a live PPTB host or the dark theme.

## Phase 7 — Update the TODO file (automatic)

Runs right after Phase 6, without asking. Edit only the TODO file(s) Phase 4 wrote in this run:

1. Set the status to `Executed` (or `Partially executed` when a step failed or was stopped) and add the branch and
   commit range.
2. Tick the completed steps (`- [x]`, with the commit SHA); leave skipped and failed steps open with the reason.
3. Append the Phase 5 report as `## Execution report`, then a `## Follow-up TODOs` checklist (`- [ ] …`) with the
   recommended next actions.
4. Re-run Validate-Markdown on the file, don't commit it unless asked, and end by listing the saved file path(s).

## Rules

- **Read-only until approved.** Phases 1–3 modify nothing; Phase 4 writes only the new TODO file.
- **Only selected tools, only approved steps.** Preserve behavior and public interfaces unless a breaking change was
  explicitly approved.
- **Never overwrite an existing file in `docs/todos/`.** Only the file created in this run may be edited later.
- **Stop on surprises** and ask; no workaround scripts.
- **Report what actually ran.** Quote exit codes and test counts; never call a check passed that wasn't run.

## Changelog

| Date | Author | Description |
| --- | --- | --- |
| 2026-10-16 | aidevme | Created: selection, read-only analysis, approval gate, verified step-by-step execution, report, and the automatic `docs/todos/` record. |
| 2026-10-16 | aidevme | The TODO file is written before any change; new "Save as TODO only" answer; the execution report updates the same file. |
