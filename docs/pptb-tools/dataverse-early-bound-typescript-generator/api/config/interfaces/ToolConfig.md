# Interface: ToolConfig

Defined in: [config/index.ts:60](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L60)

Tool settings and projects, saved in PPTB's per-tool settings.

## Properties

### confirmBeforeGenerate

> **confirmBeforeGenerate**: `boolean`

Defined in: [config/index.ts:65](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L65)

Ask for confirmation before Generate writes new and changed files.

***

### deleteOrphanedFiles

> **deleteOrphanedFiles**: `boolean`

Defined in: [config/index.ts:63](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L63)

Delete files in the output folders that the current selection no longer generates.

***

### general

> **general**: [`GeneralSettings`](GeneralSettings.md)

Defined in: [config/index.ts:61](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L61)

***

### generateTemplates

> **generateTemplates**: `boolean`

Defined in: [config/index.ts:71](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L71)

Write dataverse-gen's EJS templates to the project's `templateRoot` on Generate, like `dataverse-gen eject`.

***

### projectDefaults

> **projectDefaults**: [`ProjectDefaults`](ProjectDefaults.md)

Defined in: [config/index.ts:72](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L72)

***

### projects

> **projects**: [`ProjectEntry`](ProjectEntry.md)[]

Defined in: [config/index.ts:73](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L73)

***

### renameDuplicateIdentifiers

> **renameDuplicateIdentifiers**: `boolean`

Defined in: [config/index.ts:69](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L69)

Rename later duplicate enum members to `<Name>_<Value>` so the generated files compile.

***

### skipDuplicateIdentifiers

> **skipDuplicateIdentifiers**: `boolean`

Defined in: [config/index.ts:67](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L67)

Don't write generated files that declare a name more than once (duplicate enum members).
