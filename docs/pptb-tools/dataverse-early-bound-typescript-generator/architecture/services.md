# Services

[`src/services/`](https://github.com/aidevme/PPTB-Tools/tree/main/tools/dataverse-early-bound-typescript-generator/src/services)
connects the [core](./core.md) to PPTB. These modules call `window.dataverseAPI` and `window.toolboxAPI`
and turn the results into the inputs the core needs. Like the core, they don't import React.

## Modules

| Module | Responsibility |
| --- | --- |
| `metadataProvider.ts` | `PptbMetadataProvider`: the table list, the `$metadata` document, actions and functions, custom APIs, and per-table attribute and option-set metadata. |
| `solutions.ts` | Solution list and the tables, custom APIs and custom process actions in a solution, for the solution filter. |
| `fileSink.ts` | `FileSink` interface over the file system, with `PptbFileSink` (PPTB) and `InMemoryFileSink` (tests). |
| `plan.ts` | `createWritePlan` compares generated files with disk; `applyWritePlan` writes them. |
| `projectConfig.ts` | Reads and writes `.dataverse-gen.json` through a `FileSink`. |
| `settings.ts` | PPTB's per-tool settings: the project folder used with each connection, and the tool config: Settings-panel values and saved projects (`loadToolConfig` / `saveToolConfig`, applied over the defaults in `src/config/`). |
| `paths.ts` | Absolute host path helpers. PPTB's file API only accepts absolute paths in the host OS's format. |
| `errors.ts` | Error handling per PPTB's guide: `errorStatus` reads the HTTP status from PPTB's error messages and known Dataverse codes; `friendlyError` maps it to a user message; `reportError` logs with context, shows a persistent error notification and returns the error bar text; `withRetry` / `withRetries` retry 429, 502, 503 and 504 failures with growing delays. |
| `notifications.ts` | PPTB notifications. `NOTIFICATION_TYPES` defines the four presets (success 3 s, info 5 s, warning and error persistent), and `notificationOptions(kind, body, title?)` builds `showNotification` options from one. It also shows `notifyProjectLoaded` (info) after a saved project opens, `notifyPreviewReady` (info) after a preview succeeds, and `notifyGenerationComplete` (success) after Generate. Best effort: failures are only logged. |
| `concurrency.ts` | `mapWithConcurrency` runs async work with a cap on how many run at once. |
| `paging.ts` | `queryAllPages` reads every row of a `queryData` query, one page of 5,000 at a time, by key (see [Paging](#paging)). |

## Metadata provider

- **Caching:** everything is cached per instance. `App.tsx` creates a new provider whenever the active
  connection changes, so switching environments starts with an empty cache.
- **Throttling:** table metadata is loaded four tables at a time (`METADATA_CONCURRENCY`), with progress.
- **Option sets in bulk:** for each table, one query per choice attribute type loads the option sets
  (`EntityDefinitions(...)/Attributes/Microsoft.Dynamics.CRM.<Type>AttributeMetadata?$expand=OptionSet,GlobalOptionSet`).
  If the host rejects that URL shape, it falls back to one request per attribute.
- **The `$metadata` document** is 1 to 5 MB. It's only fetched when the Actions or Functions tab opens or
  on the first preview, and then cached.
- **`$metadata` over 16 MiB:** PPTB's `getCSDLDocument` rejects it. `getSchema` recognizes that error and
  switches to a schema rebuilt from the table list (`usesMetadataFallback` becomes true). From then on
  `fetchEntity` also loads each table's `ManyToOne`, `OneToMany` and `ManyToMany` relationships, which the core
  turns into navigation properties. Built-in actions and functions and custom process actions aren't available
  in this mode; custom APIs still are. Any other error still fails as before.
- **Private custom APIs** aren't in `$metadata`. `getSchemaForSelection` builds their definitions from the
  `customapi` record and its `customapirequestparameters`, mapped to the EDM types `$metadata` would use.

## Paging

`dataverseAPI.queryData` returns one page, at most 5,000 rows, and PPTB documents its result as just
`{ value }`, so `@odata.nextLink` can't be relied on. Queries that could return more than one page go through
`queryAllPages` (`paging.ts`) instead:

- **Keyset paging:** it orders by a unique key (`$orderby=<key> asc`), asks for 5,000 rows (`$top=5000`), and
  continues after the last key of each page (`$filter=… and <key> gt <last key>`) until a page comes back short.
  Only `$select`, `$filter`, `$orderby` and `$top` are used, which PPTB documents for `queryData`.
- **Bounded:** it stops with an error, rather than returning a partial list, if the key doesn't advance between
  pages or if more than 200 pages (1,000,000 rows) would be needed.
- **Used for** the two environment-wide lists: custom APIs (`customapis`, by `customapiid`) and custom process
  actions (`workflows`, by `workflowid`).
- **Not needed for** the other queries: solution membership of custom APIs and actions is queried 40 ids at a
  time; a solution's tables can't exceed the environment's table count; and each custom API's request
  parameters are a handful of rows. Metadata endpoints (`EntityDefinitions…`) aren't paged by Dataverse.

## Write planning

`createWritePlan` follows two rules inherited from dataverse-gen:

- **Casing:** if a file already exists with different casing (`account.ts` vs `Account.ts`), it's reused
  under its existing name, and the imports in `index.ts` and `metadata.ts` are rewritten to match. This keeps
  imports working on case-sensitive file systems.
- **Unchanged files aren't rewritten.** Line endings are ignored when comparing, so a CRLF checkout doesn't
  show every file as changed. Generated files use LF.

Files in the output folders that this run wouldn't produce are marked `orphaned`. They're reported by default.
With **Delete orphaned files** on (`deleteOrphanedFiles`) and the user's confirmation, Generate deletes them
after writing, through `FileSink.deleteFiles`.

- **Mechanism:** PPTB's file API has no delete, so `PptbFileSink.deleteFiles` opens a hidden PPTB terminal
  (PowerShell for Windows paths per `isWindowsPath`, `/bin/sh` otherwise) and runs the commands from
  `buildDeleteCommands`: `Remove-Item -LiteralPath … -Force` or `rm -f -- …`, every path single-quoted, 20 per
  command. It then checks with `fileSystem.exists` which files remain; that check, not terminal output,
  decides success.
- **Guard:** `deleteOrphanedFiles(sink, plan)` passes the sink only files with status `orphaned`, no `..`
  segment in `relativePath`, and an `absolutePath` equal to `joinPath(plan.outputRoot, relativePath)`. It
  returns `{ deleted, failed }` (`DeleteResult`).
- **Failures:** leftover files are reported as "Some orphaned files were not deleted"; a terminal that fails
  entirely as "Could not delete the orphaned files". The writes still count as done.
