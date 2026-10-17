# SortableHeaderCell

The header cell all three tables use: a semibold Fluent UI `TableHeaderCell` that sorts on click, with an optional
help tooltip above it (wrapping the cell, so it opens on hover and when the sort button gets focus).

Source: [`src/components/tables/SortableHeaderCell.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/SortableHeaderCell.tsx). The tables share
`activateRowOnKey` (Enter and Space act like a click on a row) in [`tableRows.ts`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/tableRows.ts), and
`nextSort` (first click ascending, then flip) in `components/shared/sorting.ts`.

## Props (`ISortableHeaderCellProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `help` | `ReactNode` (optional) | The column's explanation, in a tooltip; no tooltip when omitted. |
| `className` | `string` (optional) | Extra class, for example a column width. |
| `sortDirection` | `SortDirection \| undefined` | The column's sort direction, or `undefined` when another column (or none) is sorted. |
| `onClick` | `() => void` | Sorts by the column. |
| `children` | `ReactNode` | The header label. |

Styles: the shared `useSortableTableStyles` in `src/styles/SortableTable.styles.ts`.
