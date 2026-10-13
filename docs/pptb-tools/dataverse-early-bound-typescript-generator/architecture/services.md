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
| `concurrency.ts` | `mapWithConcurrency` runs async work with a cap on how many run at once. |

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

## Write planning

`createWritePlan` follows two rules inherited from dataverse-gen:

- **Casing:** if a file already exists with different casing (`account.ts` vs `Account.ts`), it's reused
  under its existing name, and the imports in `index.ts` and `metadata.ts` are rewritten to match. This keeps
  imports working on case-sensitive file systems.
- **Unchanged files aren't rewritten.** Line endings are ignored when comparing, so a CRLF checkout doesn't
  show every file as changed. Generated files use LF.

Files in the output folders that this run wouldn't produce are marked `orphaned`. They're reported but never
deleted, because PPTB's file API has no delete.
