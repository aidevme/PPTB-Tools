# ProjectsTable

The [LoadProjectDialog](../dialogs/load-project-dialog.md)'s table of saved projects: a radio button per row, the
name as a link that opens the project, then description, version, location, created on and modified on. Every
column sorts; ties keep name order. Editing and deleting are on the dialog's toolbar and act on the selected row.

The header row stays visible while the list scrolls (`headerRow` from `useSortableTableStyles`). Each name has a
folder icon (`TableCellLayout`'s `media`), the version is a tinted `Badge`, the location is one monospace line cut
off with an ellipsis and the full path in its tooltip, and the dates are muted.

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
| `loading` | `boolean` | A project is being opened: the name links are disabled. |

Styles: `useProjectsTableStyles` in `src/styles/ProjectsTable.styles.ts`, plus the shared `useSortableTableStyles`.
