# Interface: ProjectToolSettings

Defined in: [core/config.ts:140](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/config.ts#L140)

This tool's per-project settings, stored under [TOOL\_CONFIG\_KEY](../variables/TOOL_CONFIG_KEY.md) in `.dataverse-gen.json`.

## Indexable

> \[`key`: `string`\]: `unknown`

Keys a later version of the tool may add are kept as-is.

## Properties

### customEnumTemplate?

> `optional` **customEnumTemplate?**: `boolean`

Defined in: [core/config.ts:142](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/config.ts#L142)

Use the custom enum template for this project (spec 001): rename duplicates and write the custom `enum.ejs`.
