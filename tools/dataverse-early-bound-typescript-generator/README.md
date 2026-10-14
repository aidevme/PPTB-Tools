# Dataverse Early-Bound TypeScript Generator (`tools/dataverse-early-bound-typescript-generator`)

A Power Platform ToolBox (PPTB) tool that generates early-bound TypeScript types and metadata for
Dataverse tables, actions and functions. The output is compatible with Scott Durow's
[dataverse-ify](https://github.com/scottdurow/dataverse-ify) runtime and the tool reads and writes the same
`.dataverse-gen.json` project file as his [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI, so a
project can be regenerated from either.

Implementation guide: [docs/pptb-tools/dataverse-early-bound-typescript-generator/dataverse-type-forge-implementation-guide.md](../../docs/pptb-tools/dataverse-early-bound-typescript-generator/dataverse-type-forge-implementation-guide.md).
User docs: [docs/pptb-tools/dataverse-early-bound-typescript-generator/index.md](../../docs/pptb-tools/dataverse-early-bound-typescript-generator/index.md).

## Why this tool exists

The dataverse-gen CLI signs in to Dataverse with its companion
[dataverse-auth](https://github.com/scottdurow/dataverse-auth) package. In some tenants that sign-in fails:
[dataverse-auth issue #48](https://github.com/scottdurow/dataverse-auth/issues/48) reports
`Authentication failed: InteractionRequiredAuthError: invalid_grant: AADSTS50076` ("you must use multi-factor
authentication"), without an MFA prompt ever appearing. The same account signs in with MFA everywhere else, other
tenants work with dataverse-auth, and device-code sign-in is blocked in those tenants too. The issue is still
open.

This tool generates the same output without signing in by itself: it uses the Dataverse connection you've
already opened in Power Platform ToolBox, so dataverse-auth isn't involved. If you can connect to an environment
in PPTB, with MFA or any other sign-in method PPTB supports, you can generate types for it. Because the tool
reads and writes the same `.dataverse-gen.json`, a project can keep using the dataverse-gen CLI where its sign-in
works.

## How it differs from the Early Bound Generator

The PPTB marketplace also has the
[Early Bound Generator](https://github.com/mbwilding/PPTB-Tools/tree/main/tools/early-bound-generator)
(`@mbwilding/tool-early-bound-generator`), which generates **C#** early-bound classes for .NET code such as
plug-ins and console apps. This tool generates **TypeScript** instead, for code that runs in the browser or in
Node:

| | This tool | Early Bound Generator |
| --- | --- | --- |
| Language | TypeScript | C# |
| Typical use | Form scripts and web resources, PCF controls, React and code apps, Node scripts | Plug-ins, custom workflow activities, .NET apps |
| Runtime the code is for | [dataverse-ify](https://github.com/scottdurow/dataverse-ify) over the Dataverse Web API | The Dataverse SDK for .NET |
| Output | Table interfaces and attribute constants, `const enum`s for choices, a metadata cache for dataverse-ify, optional typed `Xrm.FormContext` helpers, request types for actions and functions (including private custom APIs) | C# classes for tables, option sets and messages |
| Project file | `.dataverse-gen.json`, shared with the [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI | — |

Use this tool for client-side TypeScript, and the Early Bound Generator for server-side .NET code; a solution
with both can use both.

## Attribution

The generator logic and templates are a TypeScript port of `dataverse-gen` 2.0.17 (MIT, © Scott Durow).
`dataverse-auth` is not ported because PPTB owns connections and tokens. Generated code depends on the
unchanged `dataverse-ify` npm package. Contact the original author before publishing this tool to the PPTB
marketplace, as the implementation guide asks.

## Features

- Pick a project folder; `.dataverse-gen.json` is loaded if present and the folder is remembered per connection.
- Searchable table list with a solution filter and a "selected only" toggle; separate Actions and Functions tabs
  read from the environment's `$metadata` (CSDL) document.
- Options for output folder, entity interfaces, form context helpers and the `index.ts` barrel.
- Preview that diffs the generated files against the output folder (new / changed / unchanged / orphaned) with a
  file viewer.
- Generate writes only new and changed files, then saves `.dataverse-gen.json`.

## Commands (run from `tools/dataverse-type-gen/`)

```bash
npm install
npm run dev      # Vite dev server; PPTB APIs are absent so the UI shows a warning
npm run build    # tsc typecheck + vite build -> dist/ (single IIFE bundle)
npm run watch    # rebuild dist/ on change
npm test         # vitest: core snapshot tests + planner/config tests
```

To test inside PPTB: build, enable the Debug Menu in Settings, use Debug → Browse to load this folder, connect
to an environment, and reopen the tool tab after each rebuild.

The Vite config is the same PPTB-specific IIFE setup as the other tools in this repo. Don't reintroduce
code-splitting or ESM output.

## Architecture

```
src/
├── main.tsx                # theme; renders components/apps/App.tsx (top-level state and orchestration)
├── core/                   # pure TS, no DOM-UI, no PPTB, no I/O (DOMParser only for the CSDL)
│   ├── config.ts           # .dataverse-gen.json schema, defaults, parse/serialize
│   ├── csdl.ts             # $metadata (EDMX) parser
│   ├── model.ts            # selection + type mapping (port of SchemaModel.ts)
│   ├── templates.ts        # the 7 EJS templates as plain functions
│   ├── metadataSchema.ts   # fallback schema from table + relationship metadata (CSDL too large)
│   └── generator.ts        # SchemaModel -> GeneratedFile[] (deterministic)
├── services/               # PPTB adapters and file planning
│   ├── metadataProvider.ts # dataverseAPI: tables, CSDL, attributes, option sets (cached, throttled)
│   ├── fileSink.ts         # toolboxAPI.fileSystem adapter + in-memory sink for tests
│   ├── plan.ts             # diff against disk, casing reuse, orphans, write
│   ├── projectConfig.ts    # load/save .dataverse-gen.json
│   ├── solutions.ts        # solution list + solution table membership
│   ├── settings.ts         # remembered project folder per connection
│   └── paths.ts            # absolute host path helpers
├── components/             # apps/App.tsx (state and orchestration), plus presentational cards, dialogs, panels
└── types/
test/
├── fixtures/               # trimmed dataverse-gen test data (EDMX + entity metadata)
├── reference/              # output of the real dataverse-gen CLI for those fixtures (LF)
└── *.test.ts
```

The guide suggested a three-package monorepo (`core`, `pptb-tool`, `cli`). This repo's convention is one
self-contained package per tool, so `core/` is a folder with no PPTB or UI imports instead. It can be lifted
into its own package when the CLI is built.

## Design decisions

- **No EJS.** EJS compiles with `new Function`, which the PPTB iframe CSP normally blocks. The templates are
  TypeScript functions that reproduce the EJS output byte for byte, including its stray indentation, so
  regenerating with either tool causes no diff. `test/generator.test.ts` checks this against real
  `dataverse-gen` output.
- **Option sets in bulk.** For each entity the provider issues one
  `EntityDefinitions(...)/Attributes/Microsoft.Dynamics.CRM.<Type>AttributeMetadata?$expand=OptionSet,GlobalOptionSet`
  query per choice type through `queryData`. If the host rejects that URL shape it falls back to one request per
  attribute. This has not been verified against a live PPTB host yet.
- **Custom APIs missing from `$metadata`.** Private custom APIs, and ones the environment's metadata cache does not
  include yet, are still listed and selectable. Their definitions are built from the `customapi` record and its
  `customapirequestparameters`, mapped to the EDM types `$metadata` would publish.
- **`$metadata` too large for PPTB.** PPTB's `getCSDLDocument` rejects documents over 16 MiB, compressed or
  decompressed. On that error the provider rebuilds the schema from the table list (`createMetadataSchema`), and
  each selected table's navigation properties from its `ManyToOne`/`OneToMany`/`ManyToManyRelationships`
  (`navigationFromRelationships`); properties already come from attribute metadata. Custom APIs are still built
  from their records. Built-in actions and functions, custom process actions and CSDL complex types and enums have
  no metadata source, so they're unavailable, and the UI shows a warning. With the fixture CSDL's relationships,
  the fallback produces the same table files as the CSDL path (`test/metadataFallback.test.ts`), but it hasn't
  been checked against a live environment that hits the limit.
- **Concurrency.** Entity metadata is fetched four entities at a time, with progress shown.
- **File-name casing.** An existing file whose name differs only in casing is reused, and the module specifiers
  in `index.ts` and `metadata.ts` are rewritten to match.
- **Orphans are deleted only on opt-in.** By default they're only reported. With **Delete orphaned files** on
  (`deleteOrphanedFiles`, a switch in Preview and generate synced with the Settings switch), Generate asks for
  confirmation, writes the files and `.dataverse-gen.json`, then deletes the orphans. PPTB's file API has no
  delete, so `PptbFileSink.deleteFiles` runs `Remove-Item` (Windows paths) or `rm -f` (otherwise) in a hidden PPTB
  terminal, 20 paths per command, with every path single-quoted. Success is decided by checking with
  `fileSystem.exists` which files remain, not by terminal output. `deleteOrphanedFiles` in `services/plan.ts` only
  passes files with status `orphaned`, no `..` segment, and a path equal to the output root joined with the
  relative path. Leftover files are reported as an error; the writes still count as done.
- **Tool settings.** Besides `deleteOrphanedFiles`, the Settings panel saves `general` (three notification
  switches, `recentProjectCount` 0 to 10, `selectionRowLimit` 100 to 2000) and `confirmBeforeGenerate`. With the
  latter on, Generate asks first, naming the output folder and the created and overwritten counts; when orphans
  are deleted, that confirmation covers the writes. See [`src/config/README.md`](./src/config/README.md).
- **Line endings.** Generated files use LF. Comparison ignores CRLF vs LF, so a CRLF checkout shows as unchanged.

### Deliberate deviations from dataverse-gen output

These only affect cases where dataverse-gen emits code that does not compile:

- A property whose type is an entity outside the selection becomes `any` rather than the bare logical name.
- Form-context lines for attributes with no known Xrm type are skipped instead of emitting
  `Xrm.Attributes.undefinedAttribute`.
- Action/function parameters that are collections of enums or complex types get the right element type instead of
  `undefined[]`.
- An option label made only of symbols falls back to `_<value>` instead of an empty member name.

## Not implemented

- Custom (ejected) templates. The CLI can still use `_templates` EJS files; this tool ignores `templateRoot`.
- The optional Node CLI and the MCP/headless "regenerate" mode from the guide's later build steps.

## Known limitations

- Not yet validated against a live Dataverse environment inside PPTB. The full flow was exercised in a browser
  with mocked PPTB APIs fed by dataverse-gen's test fixtures.
- The CSDL is usually 1 to 5 MB and is fetched once per connection when Actions/Functions are opened or on first
  preview. Environments whose CSDL is over PPTB's 16 MiB limit use the metadata fallback above, without built-in
  actions/functions or custom process actions.
- The name is unique on npm. The closest marketplace tool is the C# Early Bound Generator; see
  [How it differs from the Early Bound Generator](#how-it-differs-from-the-early-bound-generator).
