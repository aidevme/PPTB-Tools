# Function: deleteOrphanedFiles()

> **deleteOrphanedFiles**(`sink`, `plan`): `Promise`\<[`DeleteResult`](../interfaces/DeleteResult.md)\>

Defined in: [services/plan.ts:258](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/plan.ts#L258)

Deletes a plan's orphaned files. As a guard, only files the plan lists as orphaned, whose absolute path is
exactly their relative path inside the output root (no `..` segments), are passed to the sink; nothing else in
the project can be deleted.

## Parameters

### sink

[`FileSink`](../interfaces/FileSink.md)

### plan

[`WritePlan`](../../types/interfaces/WritePlan.md)

## Returns

`Promise`\<[`DeleteResult`](../interfaces/DeleteResult.md)\>
