---
name: aidevme-pptb-tool-refactoring
metadata:
  layer: orchestration
  scope: project
description: |
  Analyze and refactor PPTB tools under tools/ in stages: a read-only analysis and proposal (state, plan, risks);
  a TODO file in the tool's folder under docs/todos/, written before any change; then only the approved steps, each
  built, tested and committed, with the report added to the TODO file. The plan can also be saved as a TODO only.
  Microsoft platform findings are checked in Microsoft Learn. Use when:
  (1) User says "refactor" a tool, "analyze it for refactoring", "propose a refactoring plan" or "clean up the tools"
  (2) User wants a code, dependency, UI or test-coverage review of a tool that ends in a plan
  (3) User wants a refactoring plan saved as a TODO list for later
  (4) An approved proposal should be executed step by step
  Does NOT change files before approval, touch unselected tools, make unapproved breaking changes, or overwrite
  files in docs/todos/. Does NOT do marketplace policy reviews (intake-policy-review) or
  Verified badge reviews (tool-verification).
allowed-tools: Bash, PowerShell, Read, Grep, Glob, Edit, Write, AskUserQuestion, mcp__microsoft-learn__microsoft_docs_search, mcp__microsoft-learn__microsoft_docs_fetch, mcp__microsoft-learn__microsoft_code_sample_search
argument-hint: "[tool-name ... | all]"
---

# aidevme-pptb-tool-refactoring

<!-- cspell:ignore lockfiles toplevel -->

Seven phases. Phases 1–3 change nothing. Phase 4 writes the TODO file and nothing else; it runs after an "accept" or
"Save as TODO only" answer. Phase 5 runs only after an "accept" answer, and Phases 6 and 7 follow it automatically.
Templates: [`references/proposal-template.md`](references/proposal-template.md) (Phases 2 and 3) and
[`references/todo-template.md`](references/todo-template.md) (Phases 4, 6 and 7).

## Microsoft Learn MCP Server

Findings and recommendations about Microsoft platforms (Dataverse Web API and metadata, Power Platform, Power Apps
code components, Fluent UI React v9 tokens and theming, TypeScript in Microsoft guidance) are checked against
Microsoft's documentation through the
[Microsoft Learn MCP Server](https://learn.microsoft.com/en-us/training/support/mcp), never from memory. It's a
public, remote MCP server (streamable HTTP, no authentication) at `https://learn.microsoft.com/api/mcp`, with three
tools:

| Tool | Use it for |
| --- | --- |
| `microsoft_docs_search` | Finding the relevant Learn content first, for example "Dataverse Web API paging" or "Fluent UI v9 tokens" |
| `microsoft_docs_fetch` | Reading a whole page that search found, when an excerpt isn't enough |
| `microsoft_code_sample_search` | Official code samples, for example a documented Web API query or a `makeStyles` pattern |

Each client prefixes the tool names with the server's configured name (in Claude Code, for example,
`mcp__microsoft-learn__microsoft_docs_search`); use whichever server in the session exposes these three tools. If
none does, tell the user how to add it, and don't add it yourself:

- **Claude Code:** `claude mcp add --transport http microsoft-learn https://learn.microsoft.com/api/mcp`
- **VS Code / GitHub Copilot** (`.vscode/mcp.json`, under `servers`):
  `"microsoft.docs.mcp": { "type": "http", "url": "https://learn.microsoft.com/api/mcp" }`

**How the skill uses it:**

- **Phase 2:** before a finding or step relies on how a Microsoft API or library behaves (a query option, a
  metadata property, a retry or throttling rule, a theming token), search Learn, fetch the page when needed, and
  cite the URL in the evidence column. A finding that contradicts Learn guidance is worth a step; one Learn
  doesn't cover stays a finding with its code evidence.
- **Phase 5:** when a step fails on a Microsoft API or library, look the error up before proposing a fix, and cite
  the page in the report.
- **Phase 6 and 7:** list the Learn pages the analysis and the fixes relied on.
- **Read-only:** the tools only read public documentation; they never touch the workspace, and they don't widen a
  step's scope.
- **When the server isn't available,** say so, mark the affected findings "Microsoft Learn not checked", and carry
  on; never present unverified API details as fact.
- **Out of scope for Learn:** PPTB's own APIs (`toolboxAPI`, `dataverseAPI` wrapper, manifest; use `pptb-tool-dev`)
  and the output of third-party tools such as dataverse-gen, whose reference tests stay the source of truth.

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

Ground every finding in a file path and line, a command result, a measurement, or a Microsoft Learn page found
through the Microsoft Learn MCP Server (see above); say "not checked" rather than guess. Respect the repository's invariants in `AGENTS.md` (for example the generator's byte-for-byte output, the
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

1. Folder: `docs/todos/<tool-name>/` at the repository root (`git rev-parse --show-toplevel`; for example
   `C:\aidevme\PPTB-Tools\docs\todos\dataverse-early-bound-typescript-generator`). Create it if it doesn't exist.
2. One file per selected tool, in that tool's folder: `refactoring-<tool-name>-<YYYY-MM-DD>.md` (today's date).
   **Never overwrite an existing file:** if the name exists, use `-02`, `-03`, … (`refactoring-<tool-name>-<YYYY-MM-DD>-02.md`). Check
   with `Test-Path` before writing, and write with a create-only operation.
3. Content: [`references/todo-template.md`](references/todo-template.md) with status `Planned` (an "accept" answer)
   or `Saved as TODO, no changes made` ("Save as TODO only"): header (tool, date, skill, decision, proposal
   version), the full Phase 2 analysis, and a `## TODO` checklist with one `- [ ]` item per step (ID, change, files,
   effort, risk), marking which steps were approved.
4. Validate it with `aidevme-docs-maintenance` (Validate-Markdown on that file); fix markdownlint findings in the
   file and add one-off words to a `<!-- cspell:ignore … -->` comment after the H1.
5. Don't modify other files in `docs/todos/` or the tool folders under it (no index updates), and don't commit the
   file unless asked.
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
   turns out bigger or riskier than planned): stop, report what happened and the likely cause (for an error from a
   Microsoft API or library, check it with the Microsoft Learn MCP Server and cite the page), and ask whether to fix
   forward, revert the step (`git restore` / `git revert` of that step's commit), skip it, or stop.
5. **Commit each step** after it verifies, in Conventional Commits format (`CONTRIBUTING.md`):
   `refactor(<tool-name>): <subject>` (or `fix`, `test`, `chore(deps)` as fits), body with the step ID and the
   verification result. Stage only the step's files, never the TODO file. The user's approval of the plan is the
   approval for these commits; don't push.
6. **Docs move with code:** update the tool's README, docs pages and TSDoc in the same step when behavior or
   structure they describe changes. For TSDoc, hand off to `aidevme-tsdoc` ("After a code change") on the step's
   changed files and run `npm run lint:tsdoc` where the tool has it; for Markdown, run `aidevme-docs-maintenance`
   (Validate-Markdown).

## Phase 6 — Report

Per tool: steps completed, skipped and failed (with reasons), files changed (`git diff --stat` over the steps'
commits), verification results per step, commit SHAs, the Microsoft Learn pages the analysis and fixes relied on, and
recommended follow-ups. Say plainly what wasn't verified, for example behavior that needs a live PPTB host or the
dark theme.

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
- **Never overwrite an existing file in `docs/todos/<tool-name>/`.** Only the file created in this run may be edited later.
- **Stop on surprises** and ask; no workaround scripts.
- **Report what actually ran.** Quote exit codes and test counts; never call a check passed that wasn't run.
- **Check Microsoft platform behavior in Microsoft Learn** through its MCP Server and cite it; never invent API
  details.

## Changelog

| Date | Author | Description |
| --- | --- | --- |
| 2026-10-16 | aidevme | Created: selection, read-only analysis, approval gate, verified step-by-step execution, report, and the automatic `docs/todos/` record. |
| 2026-10-16 | aidevme | The TODO file is written before any change; new "Save as TODO only" answer; the execution report updates the same file. |
| 2026-10-17 | aidevme | Findings, failures and fixes that depend on Microsoft platforms are checked against Microsoft Learn through the Microsoft Learn MCP Server and cited; the report lists the pages used. |
| 2026-10-18 | aidevme | TODO files are saved per tool in `docs/todos/<tool-name>/` instead of directly in `docs/todos/`. |
| 2026-10-18 | aidevme | Each step's TSDoc goes through `aidevme-tsdoc` ("After a code change") and `npm run lint:tsdoc`. |
