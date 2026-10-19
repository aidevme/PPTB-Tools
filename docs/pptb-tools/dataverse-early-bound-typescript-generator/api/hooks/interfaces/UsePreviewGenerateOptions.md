# Interface: UsePreviewGenerateOptions

Defined in: [hooks/usePreviewGenerate.ts:24](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/usePreviewGenerate.ts#L24)

## Properties

### config

> **config**: [`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)

Defined in: [hooks/usePreviewGenerate.ts:28](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/usePreviewGenerate.ts#L28)

***

### markConfigSaved

> **markConfigSaved**: (`path`) => `void`

Defined in: [hooks/usePreviewGenerate.ts:35](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/usePreviewGenerate.ts#L35)

Records that Generate saved `.dataverse-gen.json` at `path` (see `useProject`).

#### Parameters

##### path

`string`

#### Returns

`void`

***

### noteMetadataFallback

> **noteMetadataFallback**: () => `void`

Defined in: [hooks/usePreviewGenerate.ts:37](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/usePreviewGenerate.ts#L37)

Shows the "$metadata is too large" warning if the provider fell back (see `useEnvironmentMetadata`).

#### Returns

`void`

***

### planState

> **planState**: `object`

Defined in: [hooks/usePreviewGenerate.ts:26](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/usePreviewGenerate.ts#L26)

The write plan and its status, from [usePlanState](../functions/usePlanState.md).

#### clearPlan

> **clearPlan**: () => `void`

##### Returns

`void`

#### lastResult

> **lastResult**: `string` \| `null`

#### markPlanStale

> **markPlanStale**: () => `void`

##### Returns

`void`

#### plan

> **plan**: [`WritePlan`](../../types/interfaces/WritePlan.md) \| `null`

#### planStale

> **planStale**: `boolean`

#### previewedAt

> **previewedAt**: `string` \| `null`

#### resetPlan

> **resetPlan**: () => `void`

##### Returns

`void`

#### setLastResult

> **setLastResult**: `Dispatch`\<`SetStateAction`\<`string` \| `null`\>\>

#### setPlan

> **setPlan**: `Dispatch`\<`SetStateAction`\<[`WritePlan`](../../types/interfaces/WritePlan.md) \| `null`\>\>

#### setPlanStale

> **setPlanStale**: `Dispatch`\<`SetStateAction`\<`boolean`\>\>

#### setPreviewedAt

> **setPreviewedAt**: `Dispatch`\<`SetStateAction`\<`string` \| `null`\>\>

***

### projectRoot

> **projectRoot**: `string` \| `null`

Defined in: [hooks/usePreviewGenerate.ts:27](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/usePreviewGenerate.ts#L27)

***

### provider

> **provider**: [`PptbMetadataProvider`](../../services/classes/PptbMetadataProvider.md)

Defined in: [hooks/usePreviewGenerate.ts:29](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/usePreviewGenerate.ts#L29)

***

### recordProjectGeneration

> **recordProjectGeneration**: (`root`, `applied`) => `Promise`\<`void`\>

Defined in: [hooks/usePreviewGenerate.ts:33](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/usePreviewGenerate.ts#L33)

Updates the saved project after a Generate run (see `useToolSettings`).

#### Parameters

##### root

`string`

##### applied

[`WritePlan`](../../types/interfaces/WritePlan.md)

#### Returns

`Promise`\<`void`\>

***

### setError

> **setError**: (`message`) => `void`

Defined in: [hooks/usePreviewGenerate.ts:39](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/usePreviewGenerate.ts#L39)

Shows an error in the page (the error bar), or clears it with `null`.

#### Parameters

##### message

`string` \| `null`

#### Returns

`void`

***

### sink

> **sink**: [`FileSink`](../../services/interfaces/FileSink.md)

Defined in: [hooks/usePreviewGenerate.ts:30](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/usePreviewGenerate.ts#L30)

***

### toolSettings

> **toolSettings**: [`ToolConfig`](../../config/interfaces/ToolConfig.md)

Defined in: [hooks/usePreviewGenerate.ts:31](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/usePreviewGenerate.ts#L31)
