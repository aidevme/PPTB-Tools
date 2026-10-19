# Interface: OutputConfig

Defined in: [core/config.ts:8](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/config.ts#L8)

`.dataverse-gen.json` — the project configuration file shared with Scott Durow's `dataverse-gen` CLI.

The shape and defaults mirror `MetadataGeneratorConfig.ts` in dataverse-gen so a project can be
generated from either tool interchangeably. Unknown keys are preserved on round-trip.

## Properties

### fileSuffix?

> `optional` **fileSuffix?**: `string`

Defined in: [core/config.ts:14](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/config.ts#L14)

File extension for generated files (default `.ts`).

***

### outputRoot?

> `optional` **outputRoot?**: `string`

Defined in: [core/config.ts:10](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/config.ts#L10)

Folder the generated files go to, relative to the project root.

***

### templateRoot?

> `optional` **templateRoot?**: `string`

Defined in: [core/config.ts:12](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/config.ts#L12)

Ejected EJS templates folder — honoured by the CLI only; this tool uses built-in templates.

***

### useCache?

> `optional` **useCache?**: `boolean`

Defined in: [core/config.ts:16](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/config.ts#L16)

CLI-only: cache the EDMX document on disk.
