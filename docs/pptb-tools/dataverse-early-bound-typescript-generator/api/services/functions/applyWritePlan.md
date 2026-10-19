# Function: applyWritePlan()

> **applyWritePlan**(`sink`, `plan`, `onProgress?`, `options?`): `Promise`\<[`WriteResult`](../../types/interfaces/WriteResult.md)\>

Defined in: [services/plan.ts:224](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/plan.ts#L224)

Write the new and changed files of a plan (including `duplicate` files that are new or changed, unless
`options.skipDuplicates`), creating folders as needed.

## Parameters

### sink

[`FileSink`](../interfaces/FileSink.md)

### plan

[`WritePlan`](../../types/interfaces/WritePlan.md)

### onProgress?

(`completed`, `total`, `file`) => `void`

### options?

[`WriteOptions`](../interfaces/WriteOptions.md) = `{}`

## Returns

`Promise`\<[`WriteResult`](../../types/interfaces/WriteResult.md)\>
