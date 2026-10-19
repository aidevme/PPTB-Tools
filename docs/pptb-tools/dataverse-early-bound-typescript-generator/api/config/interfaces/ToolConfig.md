# Interface: ToolConfig

Defined in: [config/index.ts:65](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L65)

Tool settings and projects, saved in PPTB's per-tool settings.

## Properties

### confirmBeforeGenerate

> **confirmBeforeGenerate**: `boolean`

Defined in: [config/index.ts:70](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L70)

Ask for confirmation before Generate writes new and changed files.

***

### deleteOrphanedFiles

> **deleteOrphanedFiles**: `boolean`

Defined in: [config/index.ts:68](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L68)

Delete files in the output folders that the current selection no longer generates.

***

### general

> **general**: [`GeneralSettings`](GeneralSettings.md)

Defined in: [config/index.ts:66](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L66)

***

### generateTemplates

> **generateTemplates**: `boolean`

Defined in: [config/index.ts:76](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L76)

Write dataverse-gen's EJS templates to the project's `templateRoot` on Generate, like `dataverse-gen eject`.

***

### projectDefaults

> **projectDefaults**: [`ProjectDefaults`](ProjectDefaults.md)

Defined in: [config/index.ts:77](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L77)

***

### projects

> **projects**: [`ProjectEntry`](ProjectEntry.md)[]

Defined in: [config/index.ts:78](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L78)

***

### renameDuplicateIdentifiers

> **renameDuplicateIdentifiers**: `boolean`

Defined in: [config/index.ts:74](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L74)

Rename later duplicate enum members to `<Name>_<Value>` so the generated files compile.

***

### skipDuplicateIdentifiers

> **skipDuplicateIdentifiers**: `boolean`

Defined in: [config/index.ts:72](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L72)

Don't write generated files that declare a name more than once (duplicate enum members).
