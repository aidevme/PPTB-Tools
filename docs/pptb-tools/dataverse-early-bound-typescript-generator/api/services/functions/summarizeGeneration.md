# Function: summarizeGeneration()

> **summarizeGeneration**(`written`, `counts`, `deleted?`, `skipDuplicates?`): `string`

Defined in: [services/plan.ts:111](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/plan.ts#L111)

One line saying what a finished Generate run did, for example
`2 files written · 279 unchanged · 9 orphaned · .dataverse-gen.json saved`. With `deleted` (the run deleted
orphans), orphans read `9 deleted` and any left over `1 orphaned`.

## Parameters

### written

`number`

### counts

`Record`\<[`FileStatus`](../../types/type-aliases/FileStatus.md), `number`\>

### deleted?

`number`

### skipDuplicates?

`boolean` = `false`

## Returns

`string`
