# FileTable

The [PreviewCard](../cards/preview-card.md)'s file table: one row per generated file with its name (and a type
icon), type and status. Clicking a row, or Enter or Space on it, selects the file for the
[FileViewer](../viewers/file-viewer.md); ↑ and ↓ move the selection. The PreviewCard keeps the selection, the filter
and the sort; the table only renders them.

Source: [`src/components/tables/FileTable.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/FileTable.tsx)

## Props (`IFileTableProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `files` | `PlannedFile[]` | The files to list, already filtered and sorted. |
| `selectedPath` | `string \| null` | The selected file's relative path. |
| `onSelect` | `(relativePath: string) => void` | Selects a file. |
| `sortDirection` | `(column: FileSortColumn) => SortDirection \| undefined` | The sort direction of a column, or `undefined` when it isn't the sorted column. |
| `onToggleSort` | `(column: FileSortColumn) => void` | A header click: sorts by the column, or flips the direction. |

The columns' help tooltips are `HEADER_HELP` in `components/shared/previewFiles.tsx`, and the order comes from
`sortFiles` there. Headers are [SortableHeaderCell](./sortable-header-cell.md)s.

Styles: `useFileTableStyles` in `src/styles/FileTable.styles.ts`, plus the shared `useSortableTableStyles`.
