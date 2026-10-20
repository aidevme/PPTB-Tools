# Interface: IProjectsTableProps

Defined in: [components/tables/ProjectsTable.tsx:11](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L11)

Props for [ProjectsTable](../functions/ProjectsTable.md).

## Properties

### loading

> **loading**: `boolean`

Defined in: [components/tables/ProjectsTable.tsx:25](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L25)

A project is being opened: the name links are disabled.

***

### onLoad

> **onLoad**: (`project`) => `void`

Defined in: [components/tables/ProjectsTable.tsx:23](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L23)

Opens a project directly (a click on its name).

#### Parameters

##### project

[`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

#### Returns

`void`

***

### onSelect

> **onSelect**: (`project`) => `void`

Defined in: [components/tables/ProjectsTable.tsx:21](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L21)

Selects a row (a click or Enter/Space on it).

#### Parameters

##### project

[`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

#### Returns

`void`

***

### onToggleSort

> **onToggleSort**: (`column`) => `void`

Defined in: [components/tables/ProjectsTable.tsx:17](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L17)

Called with the column when its header is clicked, to sort by it or reverse its direction.

#### Parameters

##### column

`ProjectColumnKey`

#### Returns

`void`

***

### projects

> **projects**: [`ProjectEntry`](../../config/interfaces/ProjectEntry.md)[]

Defined in: [components/tables/ProjectsTable.tsx:13](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L13)

The saved projects, already sorted.

***

### selectedId

> **selectedId**: `string`

Defined in: [components/tables/ProjectsTable.tsx:19](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L19)

Id of the selected project, whose row is highlighted and its radio checked; an empty string selects none.

***

### sort

> **sort**: `ProjectSort`

Defined in: [components/tables/ProjectsTable.tsx:15](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L15)

The sorted column and direction, shown in the column headers.
