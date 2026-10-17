# Build and testing

## Commands

Run from `tools/dataverse-early-bound-typescript-generator/`:

```bash
npm install
npm run dev      # Vite dev server; PPTB APIs are absent, so the UI shows a warning
npm run build    # tsc typecheck + vite build -> dist/
npm run watch    # rebuild dist/ on change
npm test         # vitest suite
```

## Single-script bundle

PPTB loads tools from a local folder, often over `file://` or in an iframe `srcdoc`, where
`<script type="module">` can fail to run. So `vite.config.ts`:

- outputs one IIFE script (`format: 'iife'`, `inlineDynamicImports: true`), with no code splitting
- uses a custom `fixHtmlForPPTB` plugin that strips `type="module"` and `crossorigin` from the built HTML and
  moves the script tags to the end of `<body>`

Don't reintroduce code splitting or ESM output. `npm run dev` would still work, but the tool would break
inside PPTB. For the same reason, dependencies must bundle without lazy loading or WebAssembly.

## Tests

The vitest suite runs in a jsdom environment, because the CSDL parser needs `DOMParser`. Test files are
`test/**/*.test.ts`.

| File | Covers |
| --- | --- |
| `errors.test.ts` | Error handling: reading the status from each PPTB error format and Dataverse code, friendly messages, logging and the error notification, and retries |
| `generator.test.ts` | CSDL parsing, selection expansion, and generated output compared file by file with the real dataverse-gen CLI's output |
| `dataverseGenTemplates.test.ts` | dataverse-gen's seven EJS templates: byte for byte, written under the `templateRoot` on Generate, and never counted as orphans |
| `duplicateIdentifiers.test.ts` | Duplicate enum member names: finding and renaming them, the `duplicate` status in the write plan, Skip duplicated identifier(s), the summaries, and how the Preview card and FileViewer show them |
| `optionsCard.test.ts` | The Options card: defaults, the output folder and the three switches reporting their config keys, and the disabled state |
| `projectColumns.test.ts` | The saved-project table's order: versions by number, dates by time, ties by name, plus `formatDateTime` and `compareText` |
| `loadProjectDialog.test.ts` | The Load Existing Project dialog: editing a saved project from its row, name validation, and the full description in a tooltip |
| `confirmationDialog.test.ts` | The reusable confirmation dialog: alert role, Confirm and Cancel, Escape, and the busy state |
| `customApi.test.ts` | Private custom APIs missing from `$metadata`: listed, selectable, and generated from their definitions; an unreadable `customapi` table fails Preview and isn't cached |
| `metadataFallback.test.ts` | The `$metadata`-too-large fallback: navigation rebuilt from relationships matches the CSDL's, table files match the reference output, and the provider switches only on PPTB's size-limit errors |
| `settings.test.ts` | Tool config: defaults from the config JSON, saved values and projects merged over them, the `general` settings (defaults, merge, rounding and clamping, mistyped values) and `confirmBeforeGenerate`, the Settings panel's General and Generate & files controls and Save/Cancel, and the New Project dialog's validation and saving |
| `notifications.test.ts` | The "project loaded", "preview ready" and "generation complete" notifications: message wording, type and duration, and that failures or a missing PPTB don't throw |
| `previewCard.test.ts` | The Preview card and `previewFiles.tsx`: the summary sentence, tiles as filters, changes-only default and search (`visibleFiles`), Generate label, the Delete orphaned files switch (setting, tooltip, summary and button wording), stale and success messages, the file table (columns, `fileType`, sorting, header tooltips, selecting with click and arrow keys), the resizable divider, and the FileViewer (header, copy, Changes tab, orphan notice) |
| `lineDiff.test.ts` | The line diff: 500 random cases that must rebuild both texts, line numbering, context and collapsing, line endings, and the size limit |
| `projectVersion.test.ts` | Project version bumps and Modified on after a Generate run, saved file lists, and matching the open folder to a saved project |
| `selectionRows.test.ts` | The Select card's row builders: search, solution and selected-only filters, the Custom only switch, custom APIs first then case-insensitive by name, sort values, and `operationType` |
| `selectionCard.test.ts` | The Select card's tables: columns per tab, toggling from the row, checkbox or keyboard, the disabled state, and the row limit |
| `workflow.test.ts` | Step states, relative times, shortened paths, recent projects (including the recent project count), the Project card's empty and open states, and the progress bar |
| `pathChip.test.ts` | PathChip: the shortened path, and the copy button named after the label reporting the full path |
| `paging.test.ts` | Keyset paging over `queryData`: the page query (key selected, ordered, `gt` the last key, caller filter kept), combining pages without gaps or duplicates, stopping on a short or empty page, and stopping with an error when the key doesn't advance or the page limit is reached |
| `services.test.ts` | Path helpers, config round-trip, and write planning (statuses, casing reuse, first-time folder creation), deleting orphaned files (only plan orphans, the output-folder guard, failure reporting, summaries), and the delete commands (PowerShell and POSIX quoting, batching) |
| `hooks.test.ts` | The state hooks: plan invalidation (`usePlanState`); loading, saving and recording generations in the tool config (`useToolSettings`); opening a project, keeping the draft selection, applying the Settings Options and remembering the folder (`useProject`); listing tables, solutions and operations, the solution filter cache and missing names (`useEnvironmentMetadata`); and Generate with its confirmations (`usePreviewGenerate`) |
| `solutions.test.ts` | The solution filter's reads: visible unmanaged solutions, a solution's tables, and component membership queried in chunks |
| `rememberedFolder.test.ts` | The project folder remembered per connection, with the last one used as the fallback |

Test data:

- `test/fixtures/` holds trimmed dataverse-gen test data: an EDMX document and entity metadata.
- `test/reference/` holds the real dataverse-gen CLI's output for those fixtures, with LF line endings.

When a change to the core alters generated output on purpose, the reference files need updating too, and the
change should be listed as a deliberate deviation in the tool's README.

## Continuous integration

`.github/workflows/dataverse-early-bound-typescript-generator-build.yml` runs on pushes and pull requests to
`main` that touch the tool. It has three jobs, each starting only after the previous one passes:

- **Validate:** `npm ci`, then `npm run validate` (`pptb-validate`, from `@pptb/types`). It checks `package.json`
  against PPTB's tool requirements: required fields such as `configurations` and `features.connections`,
  the icon path's format, and that the repository and readme URLs respond. It doesn't need the build output,
  so it runs first. Errors fail the job; warnings don't.
- **Test:** `npm ci`, then `npm test`.
- **Build:** runs only after Test passes (`needs: test`). `npm ci`, then `npm run build` (typecheck and bundle),
  then uploads `dist/` as a build artifact for 14 days.

Each job runs on a fresh runner, so each installs dependencies; the npm cache keeps that fast. The repo-wide
`build-tool.yml` workflow also builds every tool after CodeQL finishes.

## Testing inside PPTB

Build, enable the Debug Menu in PPTB's Settings, use Debug → Browse to load the tool's folder, connect to an
environment, and reopen the tool tab after each rebuild.
