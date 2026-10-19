# Function: toTableType()

> **toTableType**(`metadata`): [`TableType`](../../types/type-aliases/TableType.md)

Defined in: [services/metadataProvider.ts:553](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/metadataProvider.ts#L553)

A table's type from its metadata: Elastic or Virtual from `TableType`, Activity from `IsActivity` (activity
tables report `TableType: 'Standard'`), and Standard otherwise, including when `TableType` is missing.

## Parameters

### metadata

`object`

## Returns

[`TableType`](../../types/type-aliases/TableType.md)
