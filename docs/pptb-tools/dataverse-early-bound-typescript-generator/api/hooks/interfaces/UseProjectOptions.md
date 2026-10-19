# Interface: UseProjectOptions

Defined in: [hooks/useProject.ts:7](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useProject.ts#L7)

## Properties

### connection

> **connection**: `Connection` \| `null`

Defined in: [hooks/useProject.ts:13](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useProject.ts#L13)

***

### connKey

> **connKey**: `string` \| `undefined`

Defined in: [hooks/useProject.ts:10](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useProject.ts#L10)

The active connection's key, for the folder remembered per connection.

***

### inPptb

> **inPptb**: `boolean`

Defined in: [hooks/useProject.ts:12](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useProject.ts#L12)

Whether the PPTB APIs are available, and the active connection; the remembered folder is only read with both.

***

### markPlanStale

> **markPlanStale**: () => `void`

Defined in: [hooks/useProject.ts:23](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useProject.ts#L23)

Marks the write plan out of date after a config edit.

#### Returns

`void`

***

### projectDefaults

> **projectDefaults**: [`ProjectDefaults`](../../config/interfaces/ProjectDefaults.md)

Defined in: [hooks/useProject.ts:15](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useProject.ts#L15)

The Settings panel's Options, applied to every project that opens and whenever they change.

***

### resetPlan

> **resetPlan**: () => `void`

Defined in: [hooks/useProject.ts:21](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useProject.ts#L21)

Drops the write plan and its stale flag when another project opens.

#### Returns

`void`

***

### setError

> **setError**: (`message`) => `void`

Defined in: [hooks/useProject.ts:19](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useProject.ts#L19)

Shows an error in the page (the error bar), or clears it with `null`.

#### Parameters

##### message

`string` \| `null`

#### Returns

`void`

***

### showProjectLoaded

> **showProjectLoaded**: `boolean`

Defined in: [hooks/useProject.ts:17](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useProject.ts#L17)

Whether to show the "project loaded" notification when a saved project opens.

***

### sink

> **sink**: [`FileSink`](../../services/interfaces/FileSink.md)

Defined in: [hooks/useProject.ts:8](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useProject.ts#L8)
