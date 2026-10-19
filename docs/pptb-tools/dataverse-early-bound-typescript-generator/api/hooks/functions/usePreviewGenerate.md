# Function: usePreviewGenerate()

> **usePreviewGenerate**(`__namedParameters`): `object`

Defined in: [hooks/usePreviewGenerate.ts:47](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/usePreviewGenerate.ts#L47)

Preview and Generate: builds the write plan from the selection and the environment's metadata, writes it, and
asks for confirmation first when Generate deletes orphaned files or "Ask before generating" is on. `progress` is
set while either runs.

## Parameters

### \_\_namedParameters

[`UsePreviewGenerateOptions`](../interfaces/UsePreviewGenerateOptions.md)

## Returns

### busy

> **busy**: `boolean`

### cancelDelete

> **cancelDelete**: () => `void`

#### Returns

`void`

### cancelGenerate

> **cancelGenerate**: () => `void`

#### Returns

`void`

### confirmDelete

> **confirmDelete**: () => `void`

The Delete orphaned files confirmation's Confirm: closes it and runs Generate with the deletion.

#### Returns

`void`

### confirmDeleteOpen

> **confirmDeleteOpen**: `boolean`

### confirmGenerate

> **confirmGenerate**: () => `void`

The "Ask before generating" confirmation's Confirm: closes it and runs Generate.

#### Returns

`void`

### confirmGenerateOpen

> **confirmGenerateOpen**: `boolean`

### progress

> **progress**: [`Progress`](../../types/interfaces/Progress.md) \| `null`

### runGenerate

> **runGenerate**: (`planToApply`, `deleteOrphans`) => `Promise`\<`void`\>

Writes the plan's new and changed files and saves the project config; with `deleteOrphans`, then deletes the
plan's orphaned files. A failed delete is reported on its own, since the files were already written.

#### Parameters

##### planToApply

[`WritePlan`](../../types/interfaces/WritePlan.md)

##### deleteOrphans

`boolean`

#### Returns

`Promise`\<`void`\>

### runPreview

> **runPreview**: () => `Promise`\<[`WritePlan`](../../types/interfaces/WritePlan.md) \| `null`\>

#### Returns

`Promise`\<[`WritePlan`](../../types/interfaces/WritePlan.md) \| `null`\>

### startGenerate

> **startGenerate**: () => `void`

Generate: deleting orphans always needs a confirmation, which also covers the writes; otherwise "Ask before
generating" asks first, or it writes straight away.

#### Returns

`void`
