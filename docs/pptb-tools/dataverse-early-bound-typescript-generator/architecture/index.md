# Architecture

The tool is one self-contained React + TypeScript package in
[`tools/dataverse-early-bound-typescript-generator/`](https://github.com/aidevme/PPTB-Tools/tree/main/tools/dataverse-early-bound-typescript-generator).
It ports Scott Durow's [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI to PPTB, and its
output must stay byte-identical to the CLI's.

## Layers

The code is split so that the generator itself has no dependency on PPTB, React or the file system:

| Layer | Folder | Depends on | Page |
| --- | --- | --- | --- |
| UI | `src/components/` | React, Fluent UI | [Components](../components/) |
| App state | `src/App.tsx`, `src/hooks/` | UI, services, core | [App state and hooks](./app-state.md) |
| Services | `src/services/` | `window.dataverseAPI`, `window.toolboxAPI`, core | [Services](./services.md) |
| Core | `src/core/` | Nothing (only `DOMParser`) | [Core](./core.md) |
| Shared types | `src/types/` | — | — |

Dependencies only point downward. Core can't import services, and neither core nor services import React.
That keeps the core testable without PPTB and reusable later by a Node CLI.

Each folder has an `index.ts` barrel, and other folders import from the barrel (`./services`, `./core`). Files
inside `services/` import each other directly to avoid import cycles.

## Data flow

**Preview** (`runPreview` in `App.tsx`):

1. `resolveConfig` fills in defaults for `.dataverse-gen.json`.
2. `PptbMetadataProvider.getSchemaForSelection` loads and parses the `$metadata` (CSDL) document. Private
   custom APIs missing from it are added from their `customapi` records.
3. `resolveSelection` expands the selection, adding tables, enums and complex types that the selected
   actions and functions use.
4. `PptbMetadataProvider.getEntities` loads attribute and option-set metadata for each table, four tables at
   a time, with progress.
5. `buildSchemaModel` combines the CSDL and attribute metadata into a `SchemaModel`.
6. `generate` renders that model into a list of files.
7. `createWritePlan` compares each file with disk and marks it `new`, `changed`, `unchanged` or `orphaned`.

**Generate** (`runGenerate`): `applyWritePlan` writes only new and changed files, then `saveProjectConfig`
saves `.dataverse-gen.json`.

**Regenerate** (the header button) runs Preview and then Generate in one step.

## Further reading

- [Core](./core.md), [Services](./services.md), [App state and hooks](./app-state.md),
  [Build and testing](./build-and-testing.md)
- The [implementation guide](../dataverse-early-bound-typescript-generator.md) for the original design
- The tool's [README](https://github.com/aidevme/PPTB-Tools/tree/main/tools/dataverse-early-bound-typescript-generator#readme)
  for design decisions and deliberate deviations from dataverse-gen output
