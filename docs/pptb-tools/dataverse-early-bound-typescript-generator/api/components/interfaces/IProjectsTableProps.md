# Interface: IProjectsTableProps

Defined in: [components/tables/ProjectsTable.tsx:12](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L12)

Props for [ProjectsTable](../functions/ProjectsTable.md).

## Properties

### busy

> **busy**: `boolean`

Defined in: [components/tables/ProjectsTable.tsx:32](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L32)

Opening or deleting: the row actions are disabled.

***

### loading

> **loading**: `boolean`

Defined in: [components/tables/ProjectsTable.tsx:30](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L30)

A project is being opened: the name links are disabled.

***

### onDelete

> **onDelete**: (`project`) => `void`

Defined in: [components/tables/ProjectsTable.tsx:28](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L28)

Called with the row's project when its Delete button is clicked; the row isn't selected.

#### Parameters

##### project

[`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

#### Returns

`void`

***

### onEdit

> **onEdit**: (`project`) => `void`

Defined in: [components/tables/ProjectsTable.tsx:26](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L26)

Called with the row's project when its Edit button is clicked; the row isn't selected.

#### Parameters

##### project

[`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

#### Returns

`void`

***

### onLoad

> **onLoad**: (`project`) => `void`

Defined in: [components/tables/ProjectsTable.tsx:24](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L24)

Opens a project directly (a click on its name).

#### Parameters

##### project

[`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

#### Returns

`void`

***

### onSelect

> **onSelect**: (`project`) => `void`

Defined in: [components/tables/ProjectsTable.tsx:22](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L22)

Selects a row (a click or Enter/Space on it).

#### Parameters

##### project

[`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

#### Returns

`void`

***

### onToggleSort

> **onToggleSort**: (`column`) => `void`

Defined in: [components/tables/ProjectsTable.tsx:18](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L18)

Called with the column when its header is clicked, to sort by it or reverse its direction.

#### Parameters

##### column

`ProjectColumnKey`

#### Returns

`void`

***

### projects

> **projects**: [`ProjectEntry`](../../config/interfaces/ProjectEntry.md)[]

Defined in: [components/tables/ProjectsTable.tsx:14](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L14)

The saved projects, already sorted.

***

### selectedId

> **selectedId**: `string`

Defined in: [components/tables/ProjectsTable.tsx:20](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L20)

Id of the selected project, whose row is highlighted and its radio checked; an empty string selects none.

***

### sort

> **sort**: `ProjectSort`

Defined in: [components/tables/ProjectsTable.tsx:16](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L16)

The sorted column and direction, shown in the column headers.
