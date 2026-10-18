import type { ReactNode } from 'react';
import { Table, TableBody, TableCell, TableCellLayout, TableHeader, TableRow, TableSelectionCell } from '@fluentui/react-components';
import { useSelectionTableStyles, useSortableTableStyles } from '../../styles';
import type { SelectionColumn } from './selectionColumns';
import { SortableHeaderCell } from './SortableHeaderCell';
import type { SortState, SortValue } from '../shared/sorting';
import { activateRowOnKey } from './tableRows';

/**
 * One table row: the selection key, a name for the checkbox's accessible label, the cells after it, and one sort
 * value per cell.
 */
export interface SelectionRow {
    /** Identifies the row in `selectedKeys` and is passed to `onToggleRow`; also the React key. */
    key: string;
    /** Name used in the checkbox's accessible label, after "Select". */
    label: string;
    /** Content of the cells after the checkbox, one per column, in column order. */
    cells: ReactNode[];
    /** The value each cell sorts by, in column order; `undefined` sorts last. */
    sortValues: SortValue[];
}

/** Props for {@link SelectionTable}. */
export interface ISelectionTableProps {
    /** The table's accessible name, for example "Tables". */
    ariaLabel: string;
    /** The column headers, with their help tooltips, in the same order as each row's `cells`. */
    columns: SelectionColumn[];
    /** The rows to show, already filtered, sorted and limited. */
    rows: SelectionRow[];
    /** The sorted column (an index into `columns`) and direction, or `null` when no column is sorted. */
    sort: SortState | null;
    /** Called with the column's index when its header is clicked, to sort by it or reverse its direction. */
    onToggleSort: (column: number) => void;
    /** Keys of the selected rows. */
    selectedKeys: ReadonlySet<string>;
    /** Rows can't be toggled (not connected, or busy). */
    disabled: boolean;
    /** A row's checkbox, click, Enter or Space selects (`true`) or clears (`false`) it. */
    onToggleRow: (key: string, checked: boolean) => void;
}

/** The Select card's table: a checkbox per row, sortable columns with help tooltips. */
export function SelectionTable({ ariaLabel, columns, rows, sort, onToggleSort, selectedKeys, disabled, onToggleRow }: ISelectionTableProps) {
    const styles = useSelectionTableStyles();
    const tableStyles = useSortableTableStyles();
    return (
        <Table aria-label={ariaLabel} size="small" sortable>
            <TableHeader>
                <TableRow className={tableStyles.headerRow}>
                    <TableSelectionCell type="checkbox" invisible />
                    {columns.map((column, index) => (
                        <SortableHeaderCell
                            key={column.label}
                            help={column.help}
                            sortDirection={sort?.column === index ? sort.direction : undefined}
                            onClick={() => onToggleSort(index)}
                        >
                            {column.label}
                        </SortableHeaderCell>
                    ))}
                </TableRow>
            </TableHeader>
            <TableBody>
                {rows.map((row) => {
                    const checked = selectedKeys.has(row.key);
                    const toggleRow = () => {
                        if (!disabled) onToggleRow(row.key, !checked);
                    };
                    return (
                        <TableRow
                            key={row.key}
                            className={disabled ? styles.rowDisabled : tableStyles.row}
                            aria-selected={checked}
                            appearance={checked ? 'brand' : 'none'}
                            tabIndex={0}
                            onClick={toggleRow}
                            onKeyDown={(e) => activateRowOnKey(e, toggleRow)}
                        >
                            <TableSelectionCell type="checkbox" checked={checked} checkboxIndicator={{ 'aria-label': `Select ${row.label}`, disabled }} />
                            {row.cells.map((cell, index) => (
                                <TableCell key={index}>
                                    <TableCellLayout truncate>{cell}</TableCellLayout>
                                </TableCell>
                            ))}
                        </TableRow>
                    );
                })}
            </TableBody>
        </Table>
    );
}
