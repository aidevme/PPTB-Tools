# ProjectsTable

The [LoadProjectDialog](../dialogs/load-project-dialog.md)'s table of saved projects: a radio button per row, the
name as a link that opens the project, then description, version, location, created on and modified on, and Edit and
Delete buttons. Every column sorts; ties keep name order.

Source: [`src/components/tables/ProjectsTable.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx); the columns and their sort order are
in [`projectColumns.ts`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/projectColumns.ts).

## Props (`IProjectsTableProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `projects` | `ProjectEntry[]` | The saved projects, already sorted. |
| `sort` | `ProjectSort` | The sorted column and direction. |
| `onToggleSort` | `(column: ProjectColumnKey) => void` | A header click: sorts by the column, or flips the direction. |
| `selectedId` | `string` | The selected project's id. |
| `onSelect` | `(project: ProjectEntry) => void` | Selects a row (a click, Enter or Space on it). |
| `onLoad` | `(project: ProjectEntry) => void` | Opens a project directly (a click on its name). |
| `onEdit` | `(project: ProjectEntry) => void` | The row's Edit button. |
| `onDelete` | `(project: ProjectEntry) => void` | The row's Delete button. |
| `loading` | `boolean` | A project is being opened: the name links are disabled. |
| `busy` | `boolean` | Opening or deleting: the Edit and Delete buttons are disabled. |

The Edit and Delete buttons stop their click and keys from reaching the row, so they don't select it.

Styles: `useProjectsTableStyles` in `src/styles/ProjectsTable.styles.ts`, plus the shared `useSortableTableStyles`.
