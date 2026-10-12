# Core

[`src/core/`](https://github.com/aidevme/PPTB-Tools/tree/main/tools/dataverse-early-bound-typescript-generator/src/core)
is the generator itself. It touches no PPTB API, network or file system, and imports no React, so the
same code can later back a Node CLI. Its only browser dependency is `DOMParser` for reading the CSDL, and
a caller can pass its own parser instead.

The modules are ports of dataverse-gen's source and keep its naming, so the two code bases can be compared
side by side.

## Modules

| Module | Ports | Responsibility |
| --- | --- | --- |
| `config.ts` | `MetadataGeneratorConfig.ts` | The `.dataverse-gen.json` shape and defaults: `createDefaultConfig`, `resolveConfig`, `parseConfig`, `serializeConfig`. Unknown keys are kept when the file is saved again. |
| `csdl.ts` | `EdmxTypes.ts` | `parseCsdl` reads entity types, entity sets, complex types, enum types, actions and functions from the `$metadata` EDMX document. |
| `model.ts` | `SchemaModel.ts` | `resolveSelection` expands the selection; `buildSchemaModel` combines the CSDL with attribute metadata and maps everything to TypeScript types. |
| `templates.ts` | `_templates/*.ejs` | One render function per file kind: entity, enum, action/function, complex type, `metadata.ts` and `index.ts`. |
| `generator.ts` | `TypescriptGenerator.ts` | `generate` turns a `SchemaModel` into `GeneratedFile[]`. |
| `types.ts` | — | Input types (`Edmx*`, `*Input`) and model types (`*Model`) shared by the modules above. |

## Why the templates are code

dataverse-gen renders with EJS, which compiles templates with `new Function`. PPTB's iframe Content Security
Policy normally blocks that, so `templates.ts` reimplements each template as a plain TypeScript function. The
whitespace, including some odd indents and trailing tabs inherited from the EJS files, is reproduced on
purpose. That way, regenerating with `npx dataverse-gen` or with this tool produces no diff.

## Deterministic output

`generate` is synchronous and produces the same files in the same order every time:

- entities, then enums, actions, functions, complex types and `metadata.ts`
- `index.ts` re-exports the files in that order, matching the CLI

That's what makes it possible to test the output against the CLI's reference files (see
[Build and testing](./build-and-testing.md)).

## Deliberate deviations

The core deviates from dataverse-gen only where the CLI emits code that doesn't compile, for example
`Xrm.Attributes.undefinedAttribute` or `undefined[]` parameter types. The tool's
[README](https://github.com/aidevme/PPTB-Tools/tree/main/tools/dataverse-early-bound-typescript-generator#deliberate-deviations-from-dataverse-gen-output)
lists each one.
