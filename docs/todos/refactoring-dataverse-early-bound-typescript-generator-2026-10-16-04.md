# Refactoring: dataverse-early-bound-typescript-generator (2026-10-16)

<!-- cspell:ignore iife -->

| | |
| --- | --- |
| Tool | `tools/dataverse-early-bound-typescript-generator` (Dataverse Early-Bound TypeScript Generator, 1.0.0) |
| Date | 2026-10-16 |
| Skill | `aidevme-pptb-tool-refactoring` |
| Decision | Accepted selected steps: S6, S7, S8, S9, S10, S11, S13 |
| Status | Planned |
| Proposal version | v3 (v1 without S1–S5), reviewed at commit `5e076e6` on `features/dataverse-early-bound-typescript-generator` |

Follows [refactoring-dataverse-early-bound-typescript-generator-2026-10-16-03.md](./refactoring-dataverse-early-bound-typescript-generator-2026-10-16-03.md),
which completed S2–S5 (S1 was completed in -02). The analysis below is from v1 (`adcc2d6`); since then only S1–S5
changed the tool, so line numbers in the analysis have moved.
Related: [the 2026-10-14 refactoring plan](./dataverse-early-bound-typescript-generator-general-reactoring.md)
plans part of S7: its row 1 is the App.tsx split, and its row 4 overlaps S7's dialog move.

## TODO

Execution order: S1 → S2 → S3 → S4 → S5 → S6 → S12 → S7 → S8 → S9 → S10 → S11 → S13. S7 needs S2 and S3; S11
needs S7.

- [x] S1: fix: clear the custom API cache when the listing fails, and warn the user when a selected custom API can't
  be built instead of skipping it silently; add a test (files: `services/metadataProvider.ts`,
  `test/customApi.test.ts`; effort S; risk Medium). Done earlier in 7e5bd05
- [x] S2: fix: complete `runGenerate`'s dependency list; remove the dead `notice` state and message bar, the dead
  `config ?:` branch and the `ready` alias (files: `components/apps/App.tsx`; effort S; risk Low). Done earlier in f241b0e
- [x] S3: merge the three settings handlers into one `changeSetting(key)` (files: `components/apps/App.tsx`;
  effort S; risk Low). Done earlier in 02f4497
- [x] S4: remove services duplication: one `api()` accessor, one `plural()`, reuse `technicalMessage` and core's
  `labelText` (files: `services/metadataProvider.ts`, `solutions.ts`, `plan.ts`, `notifications.ts`, `errors.ts`;
  effort S; risk Low). Done earlier in 12d38c4
- [x] S5: remove the six unused exports and drop internal-only constants from the barrels (files:
  `services/paths.ts`, `services/dataverseGenTemplates.ts`, `services/index.ts`, `types/index.ts`,
  `components/index.ts`; effort S; risk Low). Done earlier in 5e076e6
- [ ] S6: typed Web API row reader (`str`/`num`/`bool`) to replace the `row.x as string` casts and the two `!`
  assertions (files: `services/metadataProvider.ts`, `services/solutions.ts`, a new helper; effort M; risk
  Low). Approved
- [ ] S7: split `App.tsx` into `useToolSettings`, `useProject`, `useEnvironmentMetadata`, `usePreviewGenerate`
  plus a shared `invalidatePlan()`; move `OrphanList`/`GenerateSummary` to `dialogs/`; move `pendingWrites` into
  a `plan.ts` helper (files: `App.tsx`, `hooks/*`, `dialogs/*`, `services/plan.ts`, the app-state docs page;
  effort L; risk Medium). Approved
- [ ] S8: shared table helpers: sortable header cell, `useSortState`, selectable-row keyboard handler, shared
  header and row styles (files: `PreviewCard`, `SelectionCard`, `LoadProjectDialog` and their styles,
  `components/shared/*`; effort M; risk Low). Approved
- [ ] S9: SettingsPanel switch helper, `useSettingsDraft`, setting titles shared in `settingsInfo.tsx` (makes the
  label casing consistent) (files: `SettingsPanel.tsx`, `shared/settingsInfo.tsx`, `PreviewCard.tsx`; effort M;
  risk Low). Approved
- [ ] S10: split PreviewCard into `StatusTiles`, `FileTable`, `PreviewActionBar` and `useResizableSplit`; make the
  color and dot maps module-level constants (files: `PreviewCard.tsx`, its styles, `components/index.ts`; effort M;
  risk Low). Approved
- [ ] S11: tests for the S7 hooks, `services/solutions.ts` and the remembered-folder settings functions (files:
  `test/*`; effort M; risk Low). Approved
- [ ] S12: `engines.node` to `>=22.12.0`, a `.gitattributes` LF rule for `test/reference/**` and
  `test/fixtures/**`, remove `manualChunks: undefined`; run `npm run validate` (files: `package.json`,
  `package-lock.json`, `/.gitattributes`, `vite.config.ts`; effort S; risk Low). Not approved
- [ ] S13: docs: add `src/config` to the architecture layers, the three missing test files to the testing table,
  orphan deletion and `_templates` to the Generate flow; fix `src/config/README.md:17`; add `src/config/` to the
  AGENTS.md tree and re-sync (files: the tool's architecture and build-and-testing docs pages,
  `src/config/README.md`, `AGENTS.md`; effort S; risk Low). Approved

## Analysis

Paths are relative to `tools/dataverse-early-bound-typescript-generator/src/` unless they start with `test/` or
the repository root.

### a) Current state

#### Baseline

- `npm run build`: exit 0; one IIFE bundle of 989 kB (280 kB gzipped). The chunk-size warning is expected.
- `npm test`: exit 0; 203 of 203 tests passed in 17 files.
- `npm audit`: 0 vulnerabilities.
- `git status` was the same before and after the build and test run.

#### Structure and architecture

- The folders match AGENTS.md: `core/` imports only within itself, and `services/` imports no React or Fluent UI.
- The barrels are complete; `services/` files import each other directly, as required.
- No `any`, no `@ts-ignore`, no TODO comments. Colors come from Fluent tokens, so the dark theme is safe. Every
  icon-only button has an accessible label.
- `src/config/` holds the tool's own settings (`ToolConfig`), is used at runtime, and works as its own layer, but
  the docs don't list it.

#### Code quality

| Area | Finding | Evidence |
| --- | --- | --- |
| Bug | A failed custom API listing is cached as `[]` for the whole connection; selected private custom APIs then drop out of the output with no error | `services/metadataProvider.ts:193-196`, `:215-216`, `:397-399` |
| Fragile dependency list | `runGenerate` reads `toolSettings.skipDuplicateIdentifiers`, but its dependency list leaves it out | `components/apps/App.tsx:510`, `:562` |
| Dead code | `notice` is only ever set to `null`; its message bar never renders | `App.tsx:100`, `:698` |
| Dead code | `config ? … : EMPTY_SELECTION` is always true; `ready` aliases `canSelect` | `App.tsx:608`, `:626` |
| Dead code | Unused exports: `isAbsolutePath`, `DATAVERSE_GEN_TEMPLATES_VERSION`, `LogEntry`, `RecentProject`, `WorkflowInput`, `StepKey` | grep over `src/` and `test/` |
| Complexity | `App.tsx`: 858 lines, 28 `useState`, 6 `useEffect`, 18 `useCallback` | `App.tsx` |
| Complexity | `SettingsPanel.tsx` 621 lines; `PreviewCard.tsx` 474 lines and 20 props | |
| Complexity | Long `core` functions: `buildSchemaModel` (about 130 lines), `getTypeScriptType` (about 119); not proposed because of the byte-for-byte output | `core/model.ts:459-589`, `:169-287` |
| Duplication | Three settings handlers differ only in the key | `App.tsx:577-601` |
| Duplication | `api()` copied twice; `plural()` copied twice | `metadataProvider.ts:32`, `solutions.ts:9`; `plan.ts:32`, `notifications.ts:33` |
| Duplication | `technicalMessage` re-implemented; `label` duplicates core's `labelText` | `metadataProvider.ts:43`, `:358`, `:26`; `core/model.ts:405` |
| Duplication | Sortable header cell, sort toggle, Enter/Space row selection and header styles repeated | `PreviewCard.tsx:385-408`, `SelectionCard.tsx:245-263`, `LoadProjectDialog.tsx:184-193` |
| Duplication | Six near-identical Switch controls | `SettingsPanel.tsx:192, 372, 403, 428, 444, 481` |
| Inconsistent labels | "Rename Duplicated Identifier(s)" vs "Rename duplicated identifier(s)" | `SettingsPanel.tsx:422`, `PreviewCard.tsx:265` |
| Typing | About 39 `as` casts on Web API rows (27 in `metadataProvider.ts`, five `as unknown as`) and 2 `!` assertions | `metadataProvider.ts:82-85, 276, 316, 342` |
| Error handling | Any error on the first bulk option-set query turns the bulk path off for the session, including 403 and network errors | `metadataProvider.ts:326-330` |

#### Dependencies

| Package | Current | Latest | Issue | Evidence |
| --- | --- | --- | --- | --- |
| `engines.node` | `>=18.0.0` | — | Wrong: vite 7 and vitest 5 need Node 22.12 or later | `package.json` |
| `prism-react-renderer` | 2.4.1 (exact pin) | — | Pin not explained | `package.json` |
| react, react-dom | 18.3.1 | 19.3.1 | Outdated (major) | `npm outdated` |
| vite | 7.3.7 | 8.3.4 | Outdated (major) | `npm outdated` |
| typescript | 5.9.3 | 7.0.2 | Outdated (major) | `npm outdated` |
| @vitejs/plugin-react | 4.7.0 | 6.1.2 | Outdated (major) | `npm outdated` |
| jsdom | 26.1.0 | 30.1.3 | Outdated (major) | `npm outdated` |
| @fluentui/react-icons, vitest | 2.0.343, 5.0.4 | 2.0.344, 5.0.5 | Patch updates | `npm outdated` |

Every dependency is used. `npm audit`: 0 vulnerabilities. Major upgrades aren't part of this plan.

#### UI/UX consistency

There is no other AIDevMe tool to compare against (`tools/power-pages-blueprint-generator/` is empty). Within the
tool:

- The theme is read once on mount; nothing listens for a theme change (`main.tsx:16-19`).
- Every page error shows twice, as a toast and as the error banner (`services/errors.ts:105`).
- The solution Dropdown has no label (`SelectionCard.tsx`, about line 229).

#### Performance and maintainability

- `setProgress` runs once per loaded table and re-renders the whole tree, including tables of up to 500 rows that
  aren't virtualized; there is no `React.memo`.
- jsdom startup takes 78% of the test time.

#### Test coverage

Coverage isn't configured, so there are no numbers. No direct tests: `App.tsx`, `services/solutions.ts`,
`services/concurrency.ts`, the remembered-folder functions in `services/settings.ts`, `hooks/useConnection.ts`,
`hooks/useStickyBarHeights.ts`, OptionsCard, Header, Footer, StepCard, CodeViewer, DiffViewer.

#### Docs and repository drift

- `src/config/` is missing from the architecture docs and the AGENTS.md tree.
- `dataverseGenTemplates.test.ts`, `duplicateIdentifiers.test.ts` and `loadProjectDialog.test.ts` are missing from
  the testing table.
- The Generate data flow doesn't mention orphan deletion or the `_templates` output.
- `src/config/README.md:17` says `index.ts` imports only the default JSON; it also imports a type from `../core`.
- The root `.gitattributes` has no LF rule for `test/reference` and `test/fixtures`, which AGENTS.md requires.

### b) Refactoring plan

The steps are the checklist in [TODO](#todo).

Deliberately not proposed (follow-ups):

- Major dependency upgrades (React 19, Vite 8, TypeScript 7): a separate project.
- Restructuring `core/model.ts` and `core/templates.ts`, or sharing the sort comparator in `core/`: risk to the
  byte-for-byte output for little gain.
- A theme-change listener: needs testing in live PPTB.
- The double error display: a UX decision.
- Bulk option-set error handling and memoizing the large tables: better after S7.

### c) Risk analysis

| ID | Risk | What could break | Mitigation | Rollback |
| --- | --- | --- | --- | --- |
| S1 | Medium | A new warning can appear for a custom API that's gone from the environment but still selected | Warning, not an error, so Generate still runs; new test; `customApi.test` and `metadataFallback.test` must pass | Revert the commit |
| S7 | Medium | Hook ordering, stale values, missed plan invalidation | S2 first; one hook per commit with build and tests; `invalidatePlan()` called from the same four places; tests in S11; live PPTB check (open, Preview, Generate, change a setting) | Revert the S7 commits |
| Others | Low | DOM queries in existing component tests (S8–S10) | Keep roles, labels and text, apart from the S9 casing change | Revert the commit |

Breaking changes: none. Generated output, `.dataverse-gen.json`, saved tool-config keys and the IIFE build are
unchanged, and `test/reference` isn't touched. S9 changes visible label casing; S12 changes the `engines` metadata.

### d) Summary

The tool is in good shape: strict TypeScript, clean layering, 203 passing tests and no vulnerabilities. S1 (silent
loss of custom APIs) and S2 (a dependency list that would break during a refactor) are the real defects and are
worth doing first. S7 is the main structural gain. S3–S6 and S8–S10 are low-risk cleanups, and S11–S13 add test
coverage and fix build and docs drift. A smaller first pass is S1–S6, S12 and S13.
