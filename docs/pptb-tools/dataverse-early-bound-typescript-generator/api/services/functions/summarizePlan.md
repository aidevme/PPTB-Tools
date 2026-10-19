# Function: summarizePlan()

> **summarizePlan**(`counts`, `deleteOrphans?`, `writes?`, `skipDuplicates?`): `string`

Defined in: [services/plan.ts:87](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/plan.ts#L87)

One sentence saying what Generate would do with a plan; `deleteOrphans` when Delete orphaned files is on.
`writes` defaults to the new and changed counts; pass [writeCounts](writeCounts.md) so `duplicate` files are included.
`skipDuplicates` when Skip duplicated identifier(s) is on.

## Parameters

### counts

`Record`\<[`FileStatus`](../../types/type-aliases/FileStatus.md), `number`\>

### deleteOrphans?

`boolean` = `false`

### writes?

#### created

`number`

#### overwritten

`number`

### skipDuplicates?

`boolean` = `false`

## Returns

`string`
