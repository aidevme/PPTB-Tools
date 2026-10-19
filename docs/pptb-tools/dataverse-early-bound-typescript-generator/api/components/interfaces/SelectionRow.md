# Interface: SelectionRow

Defined in: [components/tables/SelectionTable.tsx:13](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L13)

One table row: the selection key, a name for the checkbox's accessible label, the cells after it, and one sort
value per cell.

## Properties

### cells

> **cells**: `ReactNode`[]

Defined in: [components/tables/SelectionTable.tsx:19](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L19)

Content of the cells after the checkbox, one per column, in column order.

***

### key

> **key**: `string`

Defined in: [components/tables/SelectionTable.tsx:15](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L15)

Identifies the row in `selectedKeys` and is passed to `onToggleRow`; also the React key.

***

### label

> **label**: `string`

Defined in: [components/tables/SelectionTable.tsx:17](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L17)

Name used in the checkbox's accessible label, after "Select".

***

### sortValues

> **sortValues**: `SortValue`[]

Defined in: [components/tables/SelectionTable.tsx:21](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L21)

The value each cell sorts by, in column order; `undefined` sorts last.
