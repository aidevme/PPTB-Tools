# Function: ProjectsTable()

> **ProjectsTable**(`__namedParameters`): `Element`

Defined in: [components/tables/ProjectsTable.tsx:36](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx#L36)

The Load Existing Project dialog's table: one selectable row per saved project, sortable by every column. Editing
and deleting act on the selected row from the dialog's toolbar.

## Parameters

### \_\_namedParameters

[`IProjectsTableProps`](../interfaces/IProjectsTableProps.md)

## Returns

`Element`

## Remarks

The header stays visible while the list scrolls. Each name has a folder icon, the version is a badge, the location
is one line cut short with the full path in a tooltip, and the dates are muted.
