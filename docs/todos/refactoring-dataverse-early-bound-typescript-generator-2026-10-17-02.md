# Refactoring: dataverse-early-bound-typescript-generator (2026-10-17)

| | |
| --- | --- |
| Tool | `tools/dataverse-early-bound-typescript-generator` (Dataverse Early-Bound TypeScript Generator, 1.0.0) |
| Date | 2026-10-17 |
| Skill | `aidevme-pptb-tool-refactoring` |
| Scope | Extract the Fluent UI `Table` components into `src/components/tables/` |
| Decision | Accepted all |
| Status | Executed |
| Proposal version | v1, reviewed at commit `796ecb3` on `features/dataverse-early-bound-typescript-generator` |
| Branch and commits | `features/dataverse-early-bound-typescript-generator`, 53bd7ef..c098e53 |

Follows [refactoring-dataverse-early-bound-typescript-generator-2026-10-17.md](./refactoring-dataverse-early-bound-typescript-generator-2026-10-17.md).

## TODO

Execution order: T1 → T2 → T3 → T4 → T5 → T6.

- [x] T1: create `components/tables/` and move `ProjectsTable.tsx` into it; export it from the barrel (files:
  `dialogs/ProjectsTable.tsx`, `LoadProjectDialog.tsx`, `components/index.ts`; effort S; risk Low). Approved. Done in 53bd7ef
- [x] T2: move `FileTable` from `PreviewParts.tsx` to `tables/FileTable.tsx` with `TYPE_ICONS` and `STATUS_DOT`
  (files: `PreviewParts.tsx`, `tables/FileTable.tsx`, `PreviewCard.tsx`, barrel; effort S; risk Low). Approved. Done in 1b7334e
- [x] T3: extract the selection table from `SelectionCard` to `tables/SelectionTable.tsx`, with `SelectionRow`
  (files: `SelectionCard.tsx`, `tables/SelectionTable.tsx`, barrel; effort M; risk Low). Approved. Done in 2642924
- [x] T4: move the table-only helpers into `tables/`: `SortableHeaderCell`, `tableRows.ts`, `selectionColumns.tsx`,
  `projectColumns.ts`; `sorting.ts` stays in `shared/` (files: the 4 files, their importers, 2 tests; effort S;
  risk Low). Approved. Done in c6fc541
- [x] T5: a style file per table under the naming convention (`FileTable.styles.ts`, `ProjectsTable.styles.ts`,
  `SelectionTable.styles.ts`), moving the table-only classes out of the card and dialog styles (files:
  `styles/*`, the 3 tables; effort S; risk Low). Approved. Done in d1fcd97
- [x] T6: docs: update the code paths, add `components/tables/` pages and a Tables sidebar group (files: 3 docs
  pages, 3 new pages, `config.mts`, `components/index.md`; effort S; risk Low). Approved. Done in c098e53

## Analysis

Paths are relative to `tools/dataverse-early-bound-typescript-generator/src/components/`.

### a) Current state

| Table | Location | Depends on |
| --- | --- | --- |
| Selection table | Inline in `cards/SelectionCard.tsx:273-319`; `SelectionRow` type at `:40-48` | Rows, columns, sort, selected set, `disabled`, `onToggle`; `styles.rowDisabled` |
| `FileTable` | In `cards/PreviewParts.tsx` with `PreviewActionBar` and `StatusTiles` | `TYPE_ICONS`, `STATUS_DOT`, column and dot classes in `PreviewCard.styles.ts` |
| `ProjectsTable` | `dialogs/ProjectsTable.tsx` | `actionsCell`, `path`, `muted`, `descriptionTooltip` in `LoadProjectDialog.styles.ts` |

Table-only helpers: `shared/SortableHeaderCell.tsx`, `shared/tableRows.ts`, `cards/selectionColumns.tsx`,
`dialogs/projectColumns.ts`. `shared/sorting.ts` is wider (`nextSort` in `PreviewCard` and `LoadProjectDialog`).
Tests importing moved paths: `projectColumns.test.ts`, `selectionCard.test.ts`. Docs naming the paths:
`cards/preview-card.md`, `cards/selection-card.md`, `dialogs/load-project-dialog.md`.

Baseline: no tool code change since `9d05243`, where `npm run build` passed and `npm test` passed 245 tests in 21
files.

Microsoft Learn references: not needed; the steps move code and rely on no Microsoft API behavior.

### c) Risk analysis

All steps Low: code moves unchanged, so DOM and text stay the same; component tests cover the tables; import paths
are checked by the build. Generated output, saved config keys, the manifest and the IIFE build are untouched.
Breaking changes: none. Rollback: revert the step's commit.

## Execution report

### Steps

| ID | Step | Result | Commit | Notes |
| --- | --- | --- | --- | --- |
| T1 | `ProjectsTable` to `tables/` | Completed | 53bd7ef | Exported from the components barrel; `load-project-dialog.md` path updated |
| T2 | `FileTable` to `tables/FileTable.tsx` | Completed | 1b7334e | With `TYPE_ICONS` and `STATUS_DOT`; `PreviewParts.tsx` keeps the action bar and tiles (316 → 194 lines) |
| T3 | `SelectionTable` from `SelectionCard` | Completed | 2642924 | With the `SelectionRow` type; `SelectionCard.tsx` 330 → 273 lines |
| T4 | Table helpers to `tables/` | Completed | c6fc541 | `SortableHeaderCell`, `tableRows`, `selectionColumns`, `projectColumns`; `shared/sorting.ts` stays |
| T5 | A style file per table | Completed | d1fcd97 | `useFileTableStyles`, `useProjectsTableStyles`, `useSelectionTableStyles`; values unchanged |
| T6 | Docs | Completed | c098e53 | Four pages in `components/tables/` (including `SortableHeaderCell`), a Tables sidebar group, the overview rows |

`src/components/tables/` now holds `FileTable.tsx`, `ProjectsTable.tsx`, `SelectionTable.tsx`,
`SortableHeaderCell.tsx`, `projectColumns.ts`, `selectionColumns.tsx` and `tableRows.ts`.

### Files changed

```text
 29 files changed, 399 insertions(+), 240 deletions(-)
```

(`git diff --stat 53bd7ef~1 HEAD`.)

### Verification

| Step | Command | Exit code | Result |
| --- | --- | --- | --- |
| T1–T5 | `npm run build` / `npm test` after each step | 0 / 0 | OK / 245 passed in 21 files each time |
| T1–T4, T6 | Validate-Markdown on changed docs | 0 | Passed |
| T6 | `npm run docs:build` | 0 | Passed, including the dead-link check |

Not verified: a live PPTB host (the three tables: sort, select, keyboard, Edit/Delete), light and dark themes, and
how the new Tables sidebar group renders.

Microsoft Learn pages used: none (structural moves only).

## Follow-up TODOs

- [ ] Check the Select card, Preview card and Load existing project tables in PPTB, light and dark theme.
- [ ] Look at the Tables sidebar group with `npm run docs:dev`.
