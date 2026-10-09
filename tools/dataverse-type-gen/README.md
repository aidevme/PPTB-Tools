# Dataverse Type Forge (`dataverse-type-gen`)

A Power Platform ToolBox (PPTB) tool that generates early-bound TypeScript types and metadata for
Dataverse tables, actions and functions. The output is compatible with Scott Durow's
[dataverse-ify](https://github.com/scottdurow/dataverse-ify) runtime and the tool reads and writes the same
`.dataverse-gen.json` project file as his [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI, so a
project can be regenerated from either.

Implementation guide: [docs/pptb-tools/dataverse-type-gen/dataverse-type-forge-implementation-guide.md](../../docs/pptb-tools/dataverse-type-gen/dataverse-type-forge-implementation-guide.md).
User docs: [docs/pptb-tools/dataverse-type-gen/index.md](../../docs/pptb-tools/dataverse-type-gen/index.md).

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
- One-click **Regenerate** in the header (preview + generate).

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
├── main.tsx / App.tsx      # theme + top-level state and orchestration
├── core/                   # pure TS, no DOM-UI, no PPTB, no I/O (DOMParser only for the CSDL)
│   ├── config.ts           # .dataverse-gen.json schema, defaults, parse/serialize
│   ├── csdl.ts             # $metadata (EDMX) parser
│   ├── model.ts            # selection + type mapping (port of SchemaModel.ts)
│   ├── templates.ts        # the 7 EJS templates as plain functions
│   └── generator.ts        # SchemaModel -> GeneratedFile[] (deterministic)
├── services/               # PPTB adapters and file planning
│   ├── metadataProvider.ts # dataverseAPI: tables, CSDL, attributes, option sets (cached, throttled)
│   ├── fileSink.ts         # toolboxAPI.fileSystem adapter + in-memory sink for tests
│   ├── plan.ts             # diff against disk, casing reuse, orphans, write
│   ├── projectConfig.ts    # load/save .dataverse-gen.json
│   ├── solutions.ts        # solution list + solution table membership
│   ├── settings.ts         # remembered project folder per connection
│   └── paths.ts            # absolute host path helpers
├── components/             # presentational cards
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
- **Concurrency.** Entity metadata is fetched four entities at a time, with progress shown.
- **File-name casing.** An existing file whose name differs only in casing is reused, and the module specifiers
  in `index.ts` and `metadata.ts` are rewritten to match.
- **Orphans are reported, never deleted.** PPTB's file API has no delete.
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
- Deleting orphaned files.

## Known limitations

- Not yet validated against a live Dataverse environment inside PPTB. The full flow was exercised in a browser
  with mocked PPTB APIs fed by dataverse-gen's test fixtures.
- The CSDL is 1 to 5 MB and is fetched once per connection when Actions/Functions are opened or on first preview.
- The tool name has not been checked against the PPTB marketplace or npm.
