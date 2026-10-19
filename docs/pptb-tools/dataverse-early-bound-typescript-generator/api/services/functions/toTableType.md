# Function: toTableType()

> **toTableType**(`metadata`): [`TableType`](../../types/type-aliases/TableType.md)

Defined in: [services/metadataProvider.ts:553](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/metadataProvider.ts#L553)

A table's type from its metadata: Elastic or Virtual from `TableType`, Activity from `IsActivity` (activity
tables report `TableType: 'Standard'`), and Standard otherwise, including when `TableType` is missing.

## Parameters

### metadata

`object`

## Returns

[`TableType`](../../types/type-aliases/TableType.md)
