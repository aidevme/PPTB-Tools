# Interface: ISortableHeaderCellProps

Defined in: [components/tables/SortableHeaderCell.tsx:6](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SortableHeaderCell.tsx#L6)

Props for [SortableHeaderCell](../functions/SortableHeaderCell.md).

## Properties

### children

> **children**: `ReactNode`

Defined in: [components/tables/SortableHeaderCell.tsx:16](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SortableHeaderCell.tsx#L16)

The header's label.

***

### className?

> `optional` **className?**: `string`

Defined in: [components/tables/SortableHeaderCell.tsx:10](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SortableHeaderCell.tsx#L10)

Extra class, for example a column width.

***

### help?

> `optional` **help?**: `ReactNode`

Defined in: [components/tables/SortableHeaderCell.tsx:8](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SortableHeaderCell.tsx#L8)

Explanation of the column, shown in a tooltip above the header; no tooltip when omitted.

***

### onClick

> **onClick**: () => `void`

Defined in: [components/tables/SortableHeaderCell.tsx:14](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SortableHeaderCell.tsx#L14)

Called when the header is clicked (or its sort button activated from the keyboard).

#### Returns

`void`

***

### sortDirection

> **sortDirection**: `SortDirection` \| `undefined`

Defined in: [components/tables/SortableHeaderCell.tsx:12](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SortableHeaderCell.tsx#L12)

The column's sort direction, or `undefined` when another column (or none) is sorted.
