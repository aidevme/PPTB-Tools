# Interface: ProjectDefaults

Defined in: [config/index.ts:32](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L32)

Options a new project starts with: applied when a project folder without `.dataverse-gen.json` is opened.
Projects that already have the file keep their own values. Same meaning as the matching
`.dataverse-gen.json` keys.

## Properties

### customEnumTemplate

> **customEnumTemplate**: `boolean`

Defined in: [config/index.ts:42](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L42)

Default for the project's custom enum template (`pptbEarlyBoundGenerator.customEnumTemplate`): unlike the other
options, it only fills in a project whose `.dataverse-gen.json` has no value, and never replaces one.

***

### generateEntityTypes

> **generateEntityTypes**: `boolean`

Defined in: [config/index.ts:35](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L35)

***

### generateFormContext

> **generateFormContext**: `boolean`

Defined in: [config/index.ts:36](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L36)

***

### generateIndex

> **generateIndex**: `boolean`

Defined in: [config/index.ts:37](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L37)

***

### outputRoot

> **outputRoot**: `string`

Defined in: [config/index.ts:34](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L34)

`output.outputRoot`: output folder, relative to the project folder.
