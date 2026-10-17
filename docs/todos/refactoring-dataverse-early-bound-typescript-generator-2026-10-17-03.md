# Refactoring: dataverse-early-bound-typescript-generator (2026-10-17)

<!-- cspell:ignore typechecks unpushed clientjs -->

| | |
| --- | --- |
| Tool | `tools/dataverse-early-bound-typescript-generator` (Dataverse Early-Bound TypeScript Generator, 1.0.0) |
| Date | 2026-10-17 |
| Skill | `aidevme-pptb-tool-refactoring` |
| Scope | The card components in `src/components/cards/` |
| Decision | Accepted all (C2: delete the hidden history menu) |
| Status | Executed |
| Branch | `features/dataverse-early-bound-typescript-generator` (not pushed) |
| Commits | `2e6bbfd`..`af441ed` (9 commits) |
| Proposal version | v1, reviewed at commit `eccded8` on `features/dataverse-early-bound-typescript-generator` |

Follows [refactoring-dataverse-early-bound-typescript-generator-2026-10-17-02.md](./refactoring-dataverse-early-bound-typescript-generator-2026-10-17-02.md).

## TODO

Execution order: C8 → C1 → C3 → C4 → C2 → C5 → C6 → C7.

- [x] C8 (`2e6bbfd`): add `optionsCard.test.ts` (switches and output folder call `onChange`; disabled while busy) (files: new
  test; effort S; risk Low). Approved
- [x] C1 (`b01859a`): move SelectionCard's row building into pure `buildEntityRows` / `buildOperationRows` in
  `cards/selectionRows.tsx`, with unit tests (files: `SelectionCard.tsx`, `selectionRows.tsx`, new test; effort M;
  risk Low). Approved
- [x] C3 (`36b1af7`): extract `RecentProjectsList` and move `recentProjects()` to its own module (files: `ProjectCard.tsx`, new
  files, `workflow.test.ts`; effort S; risk Low). Approved
- [x] C4 (`e7807a5`): one shared `PathChip` (shortened path, tooltip, copy button) for ProjectCard and PreviewCard (files: both
  cards, `shared/PathChip.tsx`, styles; effort S; risk Low). Approved
- [x] C2 (`ebf4bd7`): delete the hidden `HistoryMenu`, `SHOW_HISTORY_MENU` and the `outputFolder`, `hasSelection`,
  `onClearSelection` props (files: `ProjectCard.tsx`, `App.tsx`, tests, docs; effort S; risk Low). Approved
- [x] C5 (`473bc03`): a label for the solution Dropdown; recent items as Fluent buttons or with a confirmed focus ring (files:
  `SelectionCard.tsx`, `ProjectCard.tsx`; effort S; risk Low, visible). Approved
- [x] C6 (`ae48df7`): card props interfaces renamed to `I<Name>Props`, old names as deprecated aliases (files: 4 cards, barrel,
  docs; effort S; risk Low). Approved
- [x] C7 (`389756d`, `af441ed`): group the wide props of SelectionCard and PreviewCard into objects (files: 2 cards, App, tests, docs;
  effort M; risk Medium). Approved

## Analysis

Paths are relative to `tools/dataverse-early-bound-typescript-generator/src/components/`.

### a) Current state

| File | Lines | Notes |
| --- | --- | --- |
| `cards/OptionsCard.tsx` | 85 | Clean; no test |
| `cards/PreviewCard.tsx` | 196 | 20 props; path chip with copy button at `:138-141` |
| `cards/PreviewParts.tsx` | 194 | Action bar and status tiles |
| `cards/ProjectCard.tsx` | 291 | Hidden `HistoryMenu` (`SHOW_HISTORY_MENU = false`, `:36`, `:259-291`); recent list; `renderSummary`; pure `recentProjects()`; path chip with copy button at `~:212-218` |
| `cards/SelectionCard.tsx` | 273 | 19 props; ~90-line row builder in a `useMemo` (`:84-172`); solution `Dropdown` without a label (`:215`) |

Other findings: App computes `outputFolder` on every render and passes `hasSelection` and `onClearSelection` only
for the hidden menu (`apps/App.tsx:202-205`); the cards' props interfaces are `<Name>Props` while tables, dialogs and
preview parts use `I<Name>Props`; recent-project items are native `<button>`s (focus ring unchecked). Tests:
`selectionCard`, `previewCard`, `duplicateIdentifiers`, `workflow` (ProjectCard, `recentProjects`); none for
`OptionsCard`.

Baseline: no tool code change since `c098e53`, where `npm run build` passed and `npm test` passed 245 tests in 21
files.

Microsoft Learn references: not needed; nothing depends on Microsoft platform behavior.

### c) Risk analysis

| ID | Risk | What could break | Mitigation | Rollback |
| --- | --- | --- | --- | --- |
| C1 | Low | Row order and filtering | Code moved unchanged; new unit tests; `selectionCard.test` | Revert the commit |
| C2 | Low | Removes a hidden feature (approved) | Tests and docs updated in the same commit | Revert the commit |
| C3, C4 | Low | Recent list and path chip text, tooltips, copy | Same JSX and labels; existing tests | Revert the commit |
| C5 | Low | Visible label and button styling | Check light and dark themes in PPTB | Revert the commit |
| C6 | Low | Imports | Deprecated aliases; build | Revert the commit |
| C7 | Medium | App-to-card wiring, test fixtures | Last, one card per commit, tests updated in the same commit, live check in PPTB | Revert the commits |
| C8 | Low | Nothing (test only) | — | Delete the test |

Breaking changes: none for users; generated output, saved config keys, the manifest and the IIFE build are untouched.
C5 and C2 change what a user sees (a label, and nothing visible for the hidden menu).

## Execution report

All eight approved steps ran in the agreed order; none was skipped or failed. Each step was verified from the tool
folder with `npm run build` (tsc, which also typechecks `test/`, then vite) and `npm test`, then committed.

| Step | Commit | Result | Verification |
| --- | --- | --- | --- |
| C8 | `2e6bbfd` | `test/optionsCard.test.ts` (4 tests) | build 0; 249 tests in 22 files |
| C1 | `b01859a` | `cards/selectionRows.tsx` (`buildEntityRows`, `buildOperationRows`, `operationType`); `test/selectionRows.test.ts` (7 tests) | build 0; 256 tests in 23 files |
| C3 | `36b1af7` | `cards/recentProjects.ts`, `cards/RecentProjectsList.tsx`, `styles/RecentProjectsList.styles.ts` | build 0; 256 tests in 23 files |
| C4 | `e7807a5` | `shared/PathChip.tsx` (`plain` and `filled` appearances), `styles/PathChip.styles.ts`, `test/pathChip.test.ts` (2 tests), docs page and sidebar entry | build 0; 258 tests in 24 files; docs:build 0 |
| C2 | `ebf4bd7` | `HistoryMenu`, `SHOW_HISTORY_MENU` and the `outputFolder`, `hasSelection`, `onClearSelection` props removed | build 0; 258 tests in 24 files |
| C5 | `473bc03` | Solution Dropdown named "Filter by solution"; recent tiles kept as native buttons, their existing `:focus-visible` ring documented | build 0; 258 tests in 24 files |
| C6 | `ae48df7` | `I<Name>Props` for the four cards, old names as deprecated aliases | build 0; 258 tests in 24 files |
| C7 | `389756d` | SelectionCard: `solutionFilter` and `loading` groups (19 to 14 props) | build 0; 258 tests in 24 files |
| C7 | `af441ed` | PreviewCard: `generateOptions` group (20 to 15 props) | build 0; 258 tests in 24 files |

Files changed since `eccded8`: 30 files, 768 insertions, 414 deletions. `npm run docs:build` passed after the last
step. Microsoft Learn pages used: none (no step depended on Microsoft platform behavior).

Deviations from the plan:

- C4 also added a `path-chip.md` docs page, its sidebar entry and a component index row, so the new shared component
  is documented like the others.
- C6's first commit left three tests on the deprecated aliases (a script regex didn't apply); they were renamed and
  folded into the same unpushed commit (`--amend`), now `ae48df7`.
- C5 used an `aria-label` rather than a visible label, so the toolbar layout is unchanged.

Not verified: none of the steps was tested live in PPTB, in the light or dark theme. That matters most for C5 (the
focus ring), C4 (the two path chip styles) and C7 (the App-to-card wiring).

## Follow-up TODOs

- [ ] Test live in PPTB, light and dark themes: the Project card (recent tiles, focus ring, path chip and copy), the
  Select card (solution filter, loading spinners, Custom only), and the Preview card (the three switches, output
  folder chip), then record the results in `contributing/testing.md`.
- [ ] Give the Select card's SearchBox an accessible name too; it only has a placeholder (found during C5, left out
  of scope).
- [ ] Remove the deprecated `*CardProps` aliases (and `NewProjectDialog`) in a later major version.
- [ ] Fix the pre-existing cspell finding "clientjs" in `components/cards/project-card.md`.
- [ ] Push the branch when ready (needs your confirmation).
