# Interface: ISelectionTableProps

Defined in: [components/tables/SelectionTable.tsx:25](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L25)

Props for [SelectionTable](../functions/SelectionTable.md).

## Properties

### ariaLabel

> **ariaLabel**: `string`

Defined in: [components/tables/SelectionTable.tsx:27](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L27)

The table's accessible name, for example "Tables".

***

### columns

> **columns**: `SelectionColumn`[]

Defined in: [components/tables/SelectionTable.tsx:29](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L29)

The column headers, with their help tooltips, in the same order as each row's `cells`.

***

### disabled

> **disabled**: `boolean`

Defined in: [components/tables/SelectionTable.tsx:39](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L39)

Rows can't be toggled (not connected, or busy).

***

### onToggleRow

> **onToggleRow**: (`key`, `checked`) => `void`

Defined in: [components/tables/SelectionTable.tsx:41](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L41)

A row's checkbox, click, Enter or Space selects (`true`) or clears (`false`) it.

#### Parameters

##### key

`string`

##### checked

`boolean`

#### Returns

`void`

***

### onToggleSort

> **onToggleSort**: (`column`) => `void`

Defined in: [components/tables/SelectionTable.tsx:35](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L35)

Called with the column's index when its header is clicked, to sort by it or reverse its direction.

#### Parameters

##### column

`number`

#### Returns

`void`

***

### rows

> **rows**: [`SelectionRow`](SelectionRow.md)[]

Defined in: [components/tables/SelectionTable.tsx:31](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L31)

The rows to show, already filtered, sorted and limited.

***

### selectedKeys

> **selectedKeys**: `ReadonlySet`\<`string`\>

Defined in: [components/tables/SelectionTable.tsx:37](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L37)

Keys of the selected rows.

***

### sort

> **sort**: `SortState` \| `null`

Defined in: [components/tables/SelectionTable.tsx:33](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx#L33)

The sorted column (an index into `columns`) and direction, or `null` when no column is sorted.
