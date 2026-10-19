# Function: pendingWriteCount()

> **pendingWriteCount**(`plan`, `options?`): `number`

Defined in: [services/plan.ts:70](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/plan.ts#L70)

How many files Generate writes: new and changed, including files with duplicate identifiers unless they're skipped.

## Parameters

### plan

`Pick`\<[`WritePlan`](../../types/interfaces/WritePlan.md), `"files"`\>

### options?

[`WriteOptions`](../interfaces/WriteOptions.md) = `{}`

## Returns

`number`
