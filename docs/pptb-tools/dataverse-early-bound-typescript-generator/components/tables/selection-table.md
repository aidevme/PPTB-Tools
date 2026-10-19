# SelectionTable

The [SelectionCard](../cards/selection-card.md)'s table of tables, actions or functions: a checkbox per row and
sortable columns with help tooltips. Clicking a row, its checkbox, or Enter or Space on it toggles the item; nothing
toggles while the table is disabled. The SelectionCard builds the rows for the active tab, filters, sorts and limits
them; the table only renders them.

Source: [`src/components/tables/SelectionTable.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/SelectionTable.tsx); the columns per tab are in
[`selectionColumns.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/selectionColumns.tsx).

## Props (`ISelectionTableProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `ariaLabel` | `string` | The table's accessible name (Tables, Actions or Functions). |
| `columns` | `SelectionColumn[]` | The tab's columns, with their labels and help. |
| `rows` | `SelectionRow[]` | The rows to show, already filtered, sorted and limited. |
| `sort` | `SortState \| null` | The sorted column and direction, or `null` for the given order. |
| `onToggleSort` | `(column: number) => void` | A header click: sorts by the column, or flips the direction. |
| `selectedKeys` | `ReadonlySet<string>` | Keys of the selected rows. |
| `disabled` | `boolean` | Rows can't be toggled (not connected, or busy). |
| `onToggleRow` | `(key: string, checked: boolean) => void` | Selects (`true`) or clears (`false`) a row. |

A `SelectionRow` has the selection `key`, a `label` for the checkbox's accessible name, the `cells` after it,
and one `sortValues` entry per cell.

Styles: `useSelectionTableStyles` in `src/styles/SelectionTable.styles.ts`, plus the shared
`useSortableTableStyles`.
