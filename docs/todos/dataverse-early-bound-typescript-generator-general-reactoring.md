# Refactoring plan

Status: **to do**. Tool: [Dataverse Early-Bound TypeScript Generator](../pptb-tools/dataverse-early-bound-typescript-generator/index.md).
Code: `tools/dataverse-early-bound-typescript-generator/src/`.

Refactoring steps found by reviewing the code on 2026-10-14 (tool 1.0.0, 163 tests). Rows 6 and 7 were done the
same day (165 tests). Every step is meant to
**keep behaviour unchanged**: the generated output, the UI and the saved settings stay the same. Paths below are
relative to `src/`.

## Overview

Status values: **To do**, **In progress**, **Done**, **Not recommended**.

| # | Component | Component Location | Refactoring Steps | Risk Analysis | Status |
| --- | --- | --- | --- | --- | --- |
| 1 | App (orchestrator) | `components/apps/App.tsx` (777 lines: 29 `useState`, 18 `useCallback`, 7 `useEffect`) | Split the state and handlers into custom hooks in `hooks/`: `useProject` (open, load, new, recent, reload), `useEnvironmentLists` (tables, solutions, operations, solution filter), `usePreviewGenerate` (plan, preview, generate, orphan deletion, confirmations), `useToolSettings` (load, save, change). App then only wires hooks to components. One hook per pull request. | **High.** Central state shared by every card. Risks: stale closures and missing hook dependencies; changed timing of effects (for example the settings-to-options effect, or table loading once a project opens). There are **no tests for App itself**, so add tests that render App with a mocked PPTB first (see [App](#1-app)). | To do |
| 2 | PPTB calls from UI code | `components/apps/App.tsx` (`readDirectory`, two `selectPath` calls, `copyToClipboard`) | Move them into services: `services/projectAccess.ts` (check folder access, pick a folder) and a `copyToClipboard` helper next to the notifications. App calls the services only, matching the rule that `services/` is the PPTB adapter layer. | **Low–medium.** Small moves, but the access check decides when PPTB shows a folder picker; keep its error matching (`access denied`, `permission`, …) unchanged. Covered by testing a saved project opening with and without access. | To do |
| 3 | "Copied" notification | `components/apps/App.tsx` (`copyPath`) | Use `notificationOptions('info', …)` from `services/notifications.ts` instead of an inline `{ type: 'info', duration: 2500 }`, so every notification uses the `NOTIFICATION_TYPES` presets (or add a `copied` preset if 2.5 s matters). | **Low.** Only the notification's duration may change (2.5 s → 5 s with the info preset). | To do |
| 4 | Confirmation messages | `components/apps/App.tsx` (`OrphanList`, `GenerateSummary`, `ORPHANS_LISTED`) | Move the two message components to `components/dialogs/` (for example `GenerateConfirmation.tsx`, `DeleteOrphansConfirmation.tsx`) and export them through the barrel. | **Low.** Presentational only; check the confirmation texts with the existing Preview and settings tests, plus a new render test. | To do |
| 5 | Settings panel | `components/panels/SettingsPanel.tsx` (567 lines) | Move the section definitions (`sections`, `SettingDefinition`, `SectionDefinition`, `TABS`, scopes) to `components/panels/settingsSections.tsx` as a builder function that takes the draft, the saved settings and the update callbacks. The panel keeps layout, search and saving. | **Low–medium.** The definitions close over the draft and update functions, so the builder needs the same inputs. Tests find controls by title, so they keep working unchanged. | To do |
| 6 | Select card | `components/cards/SelectionCard.tsx` (was 501 lines, now 346) | Moved `ENTITY_COLUMNS`, `CUSTOMAPI_COLUMNS` (renamed `ACTION_COLUMNS`, since it covers all actions), `FUNCTION_COLUMNS`, the `SelectionColumn` type and `TABLE_TYPE_COLORS` to `components/cards/selectionColumns.tsx`. Moved `sortSelectionRows`, `compareSortValues`, `SortValue` and `SortState` to the new `components/shared/sorting.ts` (the start of row 9). `test/selectionCard.test.ts` now imports `sortSelectionRows` from `shared/sorting`. | **Low**, as expected. No behaviour change: all 14 Select card tests pass unchanged apart from the import, and the bundle size is the same. | Done (2026-10-14) |
| 7 | Preview card | `components/cards/PreviewCard.tsx` (was 490 lines, now 415) | Moved `sortFiles`, `visibleFiles`, `FileFilter`, the sort comparers, `HEADER_HELP` and the list-width constants to `components/shared/previewFiles.tsx`; the sort column type is now `FileSortColumn`. Turned the width calculation into a pure `clampListWidth(width, total)` (the card still measures the split with `clientWidth`). Removed the card's re-exports of `fileType` and `summarizePlan`, which only the tests used; `test/previewCard.test.ts` imports them from `shared/generatedFiles` and `services`. Still to do with rows 9 and 10: use the shared `plural` and sorting helpers. | **Low**, as expected. No behaviour change: all Preview tests pass; two tests added for `clampListWidth`; bundle size unchanged (965.9 kB). | Done (2026-10-14) |
| 8 | Load Existing Project dialog | `components/dialogs/LoadProjectDialog.tsx` (288 lines) | Use the shared sorting helper (row 9) instead of its own `textCompare` and comparer list. | **Low.** Keep its tie-break (name, then location) and date sorting (`Date.parse`, invalid dates as text). Covered by the existing sort tests in `test/settings.test.ts`. | To do |
| 9 | Table sorting (shared) | `components/shared/sorting.ts` (created with row 6; holds the Select card's sorting so far) | One module with `textCompare` (case-insensitive, numeric), a direction-aware comparer with "missing values last", and a `toggleSort` state helper. The three tables keep their own column lists. | **Medium.** The three implementations differ slightly: Select lists rows without a value last in both directions; Preview and Load break ties by name. Write the shared helper's tests first, then switch one table at a time and run its tests. | In progress |
| 10 | `plural` helper | `components/cards/PreviewCard.tsx`, `services/notifications.ts`, `services/plan.ts` (three copies) | Keep one copy in a module both layers may import, for example `core/text.ts` (core is pure TypeScript), and import it everywhere. | **Low.** Identical implementations; summary and notification tests check the wording. | To do |
| 11 | Dataverse API access | `services/metadataProvider.ts` and `services/solutions.ts` (two copies of `api()`) | Move `api()` (the PPTB check plus `withRetries`) to `services/dataverseApi.ts` and import it in both. | **Low.** Same behaviour; the retry wrapper must still be applied once per call. | To do |
| 12 | Metadata provider | `services/metadataProvider.ts` (509 lines) | Move custom APIs and process actions (`listCustomApis`, `buildCustomApiOperation`, `customApiParameterType`, `listProcessActions`, their record types) to `services/customApis.ts`. The provider keeps tables, the CSDL and caching. | **Medium.** Private custom API generation depends on this code; `test/customApi.test.ts` and `test/metadataFallback.test.ts` cover it and must pass unchanged. Import the new file directly, not through the barrel, to avoid cycles. | To do |
| 13 | Default limits | `components/cards/ProjectCard.tsx` (`MAX_RECENT = 3`), `components/cards/SelectionCard.tsx` (`MAX_ROWS = 500`) | Take the defaults from `toolConfig.general` (`recentProjectCount`, `selectionRowLimit`) instead of repeating 3 and 500, so the bundled config is the only source. | **Low.** Same values today; a test could assert the card defaults equal the config defaults. | To do |
| 14 | Theme handling | `main.tsx` | Move the theme logic into a `useHostTheme` hook in `hooks/`, and also listen for PPTB's `settings:updated` event so the tool follows theme changes while open (also an open marketplace intake finding). | **Low–medium.** New behaviour (live switching). The event's `data.theme` shape isn't documented in detail; ignore events without it, and test both themes in PPTB ([TESTING.md](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/TESTING.md)). | To do |
| 15 | Empty `tables` folder | `components/tables/` | Remove it, or use it for a shared sortable table if row 9 grows into one. | **None** (empty folder). | To do |
| 16 | Generator core | `core/model.ts` (589 lines), `core/templates.ts` | Leave as is. | **High.** A port of dataverse-gen whose output must match byte for byte (`test/generator.test.ts` against `test/reference/`); restructuring gains little and risks output changes. | Not recommended |
| 17 | Developer docs | `CLAUDE.md`, `components/index.ts` | `CLAUDE.md` says `useConnection` "polls" for the connection; it subscribes to `connection:*` events. It also links `docs/agents/index.md`, which doesn't exist. Update both, and the folder trees after rows 1–12. | **None** (docs only). | To do |
| 18 | Style hooks | `styles/*.styles.ts` | All `makeStyles` hooks live in `styles/`, one file per component (including `App.styles.ts` and `CodeViewer.styles.ts`), exported from `styles/index.ts`. | — | Done |
| 19 | App location | `components/apps/App.tsx` | Moved from `src/App.tsx`; imports and docs updated. | — | Done |
| 20 | Query paging | `services/paging.ts` | `queryAllPages` for the custom API and process action lists, with tests. | — | Done |

## Order of work

Do the low-risk moves first; they shrink the large files and make the App refactoring easier to review.

1. **Clean-up:** rows 15, 17, 10, 11, 3.
2. **Move helpers out of components:** rows 6 and 7 are done; next row 9 (with tests first, now that
   `shared/sorting.ts` exists), then 8, 4, 13.
3. **Services:** rows 2 and 12.
4. **Panel:** row 5.
5. **App:** row 1, one hook at a time, after adding App tests.
6. **Behaviour change:** row 14 (separate from the refactoring, because it's a fix).

## Rules for every step

- **No behaviour change** unless the row says so (rows 3 and 14). Generated output must stay byte-for-byte equal.
- **One row per pull request**, so each can be reviewed and reverted alone.
- **Barrels:** add new modules to the folder's `index.ts`. Inside `services/`, import files directly, not through
  the barrel. Never export `App` from `components/index.ts` (App imports that barrel).
- **Verify each step** in the tool folder:

  ```bash
  npx tsc --noEmit -p .   # typecheck, including tests
  npm test                # all tests pass, none skipped
  npm run build           # one IIFE bundle in dist/
  npm run validate        # pptb-validate
  ```

  For rows 1, 2, 5 and 14, also load the build in PPTB and run the relevant TESTING.md checks.
- **Docs:** update `tools/dataverse-early-bound-typescript-generator/README.md` (architecture tree) and
  `docs/pptb-tools/dataverse-early-bound-typescript-generator/architecture/` when files move.

## Details for the riskier rows

### 1. App

**Tests to add first** (`test/app.test.ts`), rendering App with a mocked `window.toolboxAPI` and
`window.dataverseAPI`:

- with no project: the Select card is disabled and no tables are requested;
- opening a saved project: tables load, the "Project loaded" notification shows (or not, per the setting);
- Preview then Generate on an in-memory file system: files written, result line shown;
- with Delete orphaned files on: the confirmation opens and only orphans are deleted;
- saving Settings Options while a project is open: the Options card picks them up.

**Then extract hooks in this order**, running the tests after each:

1. `useToolSettings`: `toolSettings`, `saveToolSettings`, `changeDeleteOrphans`, and the load effect.
2. `useEnvironmentLists`: tables, solutions, operations, solution filter state and their effects.
3. `useProject`: project folder, config state, open, load, recent, new project, the settings-to-options effect.
4. `usePreviewGenerate`: plan, preview, generate, orphan deletion, the two confirmation states, progress.

Each hook returns state plus callbacks; App passes them to the components as today. Keep `useCallback`
dependency lists complete; the code relies on them (for example `runPreview` depends on the
notification settings).

### 9. Shared sorting

Write `test/sorting.test.ts` first, covering what each table relies on today:

- text compared case-insensitively with numbers in order (`id2` before `id10`);
- missing values last in both directions (Select);
- ties broken by name (Preview, Load Existing Project);
- dates compared as dates, invalid dates as text (Load Existing Project).

Switch one table per commit and run its existing tests.

### 12. Metadata provider

Before moving the code, record the queries the provider sends for a project with private and public custom APIs
(the mocks in `test/customApi.test.ts` show them); after the move, the same queries must be sent in the same
order.
