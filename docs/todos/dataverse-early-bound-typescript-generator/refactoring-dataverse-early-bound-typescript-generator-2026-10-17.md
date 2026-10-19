# Refactoring: dataverse-early-bound-typescript-generator (2026-10-17)

<!-- cspell:ignore clientjs -->

| | |
| --- | --- |
| Tool | `tools/dataverse-early-bound-typescript-generator` (Dataverse Early-Bound TypeScript Generator, 1.0.0) |
| Date | 2026-10-17 |
| Skill | `aidevme-pptb-tool-refactoring` |
| Scope | `src/components/dialogs/` |
| Decision | Accepted selected steps: D1, D2, D3, D4, D5, D6, D7, D8 |
| Status | Executed |
| Proposal version | v1, reviewed at commit `9d0ebef` on `features/dataverse-early-bound-typescript-generator` |
| Branch and commits | `features/dataverse-early-bound-typescript-generator`, 12eba87..9d05243 |

Follows [refactoring-dataverse-early-bound-typescript-generator-2026-10-16-04.md](./refactoring-dataverse-early-bound-typescript-generator-2026-10-16-04.md).
D6 includes task A2 from the App.tsx analysis (the Generate confirmation dialogs).

## TODO

Execution order: D1 → D5 → D2 → D6 → D3 → D4 → D7 → D8.

- [x] D1: move `compareVersions`, `compareDates` and the column definitions to `dialogs/projectColumns.ts`, reuse
  the shared text comparison, move `formatDateTime` to `shared/format.ts`, add unit tests (files:
  `LoadProjectDialog.tsx`, `projectColumns.ts`, `shared/format.ts`, `shared/sorting.ts`, tests; effort S; risk
  Low). Approved. Done in 12eba87
- [x] D5: Fluent `Tooltip` on the location cell; remove the unused `checkboxIndicator` (files:
  `LoadProjectDialog.tsx`; effort S; risk Low). Approved. Done in 2f57c1a
- [x] D2: extract `ProjectsTable` and a `RowActionButton` (files: `LoadProjectDialog.tsx`, `ProjectsTable.tsx`;
  effort M; risk Low). Approved. Done in 9817f9c
- [x] D6: shared `plural` in `GenerateSummary`; the Generate dialogs' labels and confirm handlers move from App
  to `GenerateConfirmations.tsx` and `usePreviewGenerate` (files: `GenerateConfirmations.tsx`, `App.tsx`,
  `usePreviewGenerate.ts`, `hooks.test.ts`; effort M; risk Low). Approved. Done in edde758
- [x] D3: `useAsyncAction` hook for the busy-and-error pattern (files: `hooks/useAsyncAction.ts`, both dialogs,
  `useSettingsDraft.ts`, tests; effort M; risk Low–Medium). Approved. Done in 7d318ff
- [x] D4: reset by mounting the form only while the dialog is open, instead of reset effects (files: both
  dialogs; effort M; risk Medium). Approved. Done in aaa3dda, reset during render instead of mounting (approved change)
- [x] D7: label casing: "Project name", "Created on", "Modified on" (files: `NewProjectDialog.tsx`,
  `projectColumns.ts`, tests, docs; effort S; risk Low, visible text). Approved. Done in 6837145
- [x] D8: rename `NewProjectDialog` to `ProjectFormDialog`, keeping the old name as an alias (files: dialogs,
  barrel, App, tests, docs; effort S; risk Low). Approved. Done in 9d05243

## Analysis

Paths are relative to `tools/dataverse-early-bound-typescript-generator/src/components/dialogs/`.

### a) Current state

| File | Lines | Notes |
| --- | --- | --- |
| `ConfirmationDialog.tsx` | 57 | Generic yes/no alert dialog; clean |
| `GenerateConfirmations.tsx` | 53 | `OrphanList` and `GenerateSummary` (moved from App in S7) |
| `NewProjectDialog.tsx` | 133 | Creates and edits a project |
| `LoadProjectDialog.tsx` | 324 | Pure helpers, a 105-line table, and the load, delete and edit flows |

Tests: `confirmationDialog.test.ts`, `loadProjectDialog.test.ts`, `settings.test.ts` (including sorting by
version).

| Area | Finding | Evidence |
| --- | --- | --- |
| Size | `LoadProjectDialog` mixes pure helpers, the table and the flows | `LoadProjectDialog.tsx:59-92`, `:179-284` |
| Duplication | Busy-and-error pattern written five times | `NewProjectDialog.tsx:66-85`, `LoadProjectDialog.tsx:132-159`, `useSettingsDraft.save` |
| State reset | Forms reset in an effect after opening: an extra render, and possibly stale values in the first frame (not checked in PPTB) | `NewProjectDialog.tsx:50-57`, `LoadProjectDialog.tsx:122-130` |
| Duplication | `textCompare` repeats `shared/sorting.ts:24`; `formatDateTime` belongs in `shared/format.ts`; `GenerateSummary` has its own plural helper; Edit and Delete row buttons are copies | `LoadProjectDialog.tsx:59`, `:66`, `:252-277` |
| Accessibility | Location cell uses the native `title` (not keyboard reachable); unused `checkboxIndicator` on a radio cell | `LoadProjectDialog.tsx:245`, `:212` |
| Wording | "Project Name" (Title Case) beside sentence-case fields; "Created On" / "Modified On" | `NewProjectDialog.tsx:99`, `LoadProjectDialog.tsx:88-89` |
| Naming | `NewProjectDialog` also edits | `NewProjectDialog.tsx` |
| Placement | The Generate dialogs' labels and handlers are in App | `App.tsx:250-277` |

### c) Risk analysis

| ID | Risk | What could break | Mitigation | Rollback |
| --- | --- | --- | --- | --- |
| D1 | Low | Project table order | Existing sort test plus new unit tests; ties keep name order | Revert the commit |
| D2 | Low | Row click versus Edit/Delete (`stopPropagation`), keyboard order | Move the JSX unchanged; `loadProjectDialog.test` | Revert the commit |
| D3 | Low–Medium | Error text, busy not resetting after an error | Same `reportError` operation strings; hook tests | Revert the commit |
| D4 | Medium | State kept or lost across opens; switching the edited project; focus restore | Last of the structural steps; tests for opening empty, opening with values, error cleared; check focus in PPTB | Revert the commit |
| D5 | Low | Hover text on the location cell | Same content | Revert the commit |
| D6 | Low | Dialog labels and confirm behavior | Hook tests for both confirm paths | Revert the commit |
| D7 | Low | Visible labels; header test | Tests and docs in the same commit | Revert the commit |
| D8 | Low | Imports | Old name kept as an alias | Revert the commit |

Breaking changes: none. Generated output, saved config keys, the manifest and the IIFE build are unchanged.
D7 changes visible text.

## Execution report

### Steps

| ID | Step | Result | Commit | Notes |
| --- | --- | --- | --- | --- |
| D1 | Project table sorting to `projectColumns.ts` | Completed | 12eba87 | `compareText` exported from `shared/sorting.ts`; `formatDateTime` in `shared/format.ts`; 7 new tests in `projectColumns.test.ts` |
| D5 | Fluent tooltip on the location cell | Completed | 2f57c1a | It opens on hover only (the cell isn't focusable), so this is consistency and `aria-describedby`, not keyboard access |
| D2 | `ProjectsTable` and `RowActionButton` | Completed | 9817f9c | `LoadProjectDialog.tsx` 290 → 169 lines |
| D6 | Generate confirmations out of App | Completed | edde758 | `confirmDelete`/`confirmGenerate`/`cancelDelete`/`cancelGenerate` in `usePreviewGenerate`; `GenerateConfirmationDialogs`; labels unchanged |
| D3 | `useAsyncAction` | Completed | 7d318ff | The caller owns the error, so open and delete share one message; the folder picker keeps its own handling |
| D4 | Reset when a dialog opens | Completed | aaa3dda | Changed with approval: React's "adjust state when a prop changes" pattern instead of mounting, which would have needed the busy flag lifted to the parent |
| D7 | Sentence-case labels | Completed | 6837145 | Fixtures and reference output, where "Created On" is a Dataverse label, unchanged |
| D8 | Rename to `ProjectFormDialog` | Completed | 9d05243 | Styles renamed too (`ProjectFormDialog.styles.ts`); old names exported as deprecated aliases; docs page keeps its URL |

### Files changed

```text
 29 files changed, 564 insertions(+), 306 deletions(-)
```

(`git diff --stat 55df029..HEAD`.) `components/dialogs/` is now six files, 629 lines: `ConfirmationDialog` 57,
`GenerateConfirmations` 105, `LoadProjectDialog` 162, `ProjectFormDialog` 136, `ProjectsTable` 121, `projectColumns`
48.

### Verification

| Step | Command | Exit code | Result |
| --- | --- | --- | --- |
| D1 | `npm run build` / `npm test` | 0 / 0 | OK / 240 passed in 21 files |
| D5 | `npm run build` / `npm test` | 0 / 0 | OK / 240 passed in 21 files |
| D2 | `npm run build` / `npm test` | 0 / 0 | OK / 240 passed in 21 files |
| D6 | `npm run build` / `npm test` | 0 / 0 | OK / 241 passed in 21 files |
| D3 | `npm run build` / `npm test` | 0 / 1, then 0 / 0 twice | One run timed out (5 s) in an existing settings test under heavy load; it passes alone and in two full reruns: 243 passed |
| D4 | `npm run build` / `npm test` | 0 / 0 | OK / 245 passed in 21 files |
| D7 | `npm run build` / `npm test` | 0 / 0 | OK / 245 passed in 21 files |
| D8 | `npm run build` / `npm test` | 0 / 0 | OK / 245 passed in 21 files |
| All | Validate-Markdown on changed docs | 0 | Passed, except a cspell finding ("clientjs") already on `components/project-card.md:42` |

Not verified: a live PPTB host (opening, editing and deleting saved projects, the confirmations, focus when the
dialogs close), light and dark themes, and `npm run docs:build` (already broken by two unrelated files).

## Follow-up TODOs

- [ ] Test the dialogs in PPTB, light and dark theme: New project, Load existing project (sort, select, open,
  edit, delete), both Generate confirmations, and that reopening a dialog starts fresh.
- [ ] Watch the settings test "stays open when the folder picker is cancelled" for timeouts on slow runs; raise
  its timeout if it recurs.
- [ ] Add "clientjs" to the cspell word list, or reword `components/project-card.md:42`.
- [ ] Remove the deprecated `NewProjectDialog` / `INewProjectDialogProps` aliases once nothing outside the tool
  uses them.
