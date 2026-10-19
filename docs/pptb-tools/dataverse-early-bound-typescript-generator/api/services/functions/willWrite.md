# Function: willWrite()

> **willWrite**(`file`, `options?`): `boolean`

Defined in: [services/plan.ts:51](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/plan.ts#L51)

Whether Generate writes the file: it's new or changed, whatever its status, unless it has duplicate identifiers
and `skipDuplicates` is on.

## Parameters

### file

[`PlannedFile`](../../types/interfaces/PlannedFile.md)

### options?

[`WriteOptions`](../interfaces/WriteOptions.md) = `{}`

## Returns

`boolean`
