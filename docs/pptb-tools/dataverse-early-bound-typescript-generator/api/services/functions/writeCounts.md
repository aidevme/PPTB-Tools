# Function: writeCounts()

> **writeCounts**(`plan`, `options?`): `object`

Defined in: [services/plan.ts:58](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/plan.ts#L58)

How many files Generate would create and overwrite, counting `duplicate` files by their write status.

## Parameters

### plan

`Pick`\<[`WritePlan`](../../types/interfaces/WritePlan.md), `"files"`\>

### options?

[`WriteOptions`](../interfaces/WriteOptions.md) = `{}`

## Returns

`object`

### created

> **created**: `number`

### overwritten

> **overwritten**: `number`
