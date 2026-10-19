# Function: notifyGenerationComplete()

> **notifyGenerationComplete**(`written`, `counts`, `deleted?`, `skipDuplicates?`): `Promise`\<`void`\>

Defined in: [services/notifications.ts:68](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/notifications.ts#L68)

Shows a success notification after Generate wrote the files and saved the config; `deleted` when it deleted orphans.

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

`Promise`\<`void`\>
