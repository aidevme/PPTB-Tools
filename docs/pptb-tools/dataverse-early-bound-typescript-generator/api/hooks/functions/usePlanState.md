# Function: usePlanState()

> **usePlanState**(): `object`

Defined in: [hooks/usePlanState.ts:9](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/usePlanState.ts#L9)

The current write plan and its status. Kept apart from [usePreviewGenerate](usePreviewGenerate.md) so the project, settings and
environment hooks, which run before it, can invalidate the plan: `clearPlan` drops it, `resetPlan` also clears
the stale flag (a different project), and `markPlanStale` keeps it but asks for a new preview.

## Returns

`object`

### clearPlan

> **clearPlan**: () => `void`

#### Returns

`void`

### lastResult

> **lastResult**: `string` \| `null`

### markPlanStale

> **markPlanStale**: () => `void`

#### Returns

`void`

### plan

> **plan**: [`WritePlan`](../../types/interfaces/WritePlan.md) \| `null`

### planStale

> **planStale**: `boolean`

### previewedAt

> **previewedAt**: `string` \| `null`

### resetPlan

> **resetPlan**: () => `void`

#### Returns

`void`

### setLastResult

> **setLastResult**: `Dispatch`\<`SetStateAction`\<`string` \| `null`\>\>

### setPlan

> **setPlan**: `Dispatch`\<`SetStateAction`\<[`WritePlan`](../../types/interfaces/WritePlan.md) \| `null`\>\>

### setPlanStale

> **setPlanStale**: `Dispatch`\<`SetStateAction`\<`boolean`\>\>

### setPreviewedAt

> **setPreviewedAt**: `Dispatch`\<`SetStateAction`\<`string` \| `null`\>\>
