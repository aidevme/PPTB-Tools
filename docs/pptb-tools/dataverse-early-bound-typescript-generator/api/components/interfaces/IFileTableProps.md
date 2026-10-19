# Interface: IFileTableProps

Defined in: [components/tables/FileTable.tsx:34](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/FileTable.tsx#L34)

Props for [FileTable](../functions/FileTable.md).

## Properties

### files

> **files**: [`PlannedFile`](../../types/interfaces/PlannedFile.md)[]

Defined in: [components/tables/FileTable.tsx:36](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/FileTable.tsx#L36)

The files to list, already filtered and sorted.

***

### onSelect

> **onSelect**: (`relativePath`) => `void`

Defined in: [components/tables/FileTable.tsx:43](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/FileTable.tsx#L43)

Called with a file's relative path when its row is clicked, activated with Enter or Space, or reached with the
Up or Down arrow key.

#### Parameters

##### relativePath

`string`

#### Returns

`void`

***

### onToggleSort

> **onToggleSort**: (`column`) => `void`

Defined in: [components/tables/FileTable.tsx:47](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/FileTable.tsx#L47)

Called with the column when its header is clicked, to sort by it or reverse its direction.

#### Parameters

##### column

`FileSortColumn`

#### Returns

`void`

***

### selectedPath

> **selectedPath**: `string` \| `null`

Defined in: [components/tables/FileTable.tsx:38](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/FileTable.tsx#L38)

Relative path of the file shown in the viewer, whose row is highlighted; `null` when none is selected.

***

### sortDirection

> **sortDirection**: (`column`) => `SortDirection` \| `undefined`

Defined in: [components/tables/FileTable.tsx:45](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/FileTable.tsx#L45)

The sort direction of `column`, or `undefined` when it isn't the sorted column.

#### Parameters

##### column

`FileSortColumn`

#### Returns

`SortDirection` \| `undefined`
