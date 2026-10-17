import type { ReactNode } from 'react';
import { TableHeaderCell, Tooltip, mergeClasses, type SortDirection } from '@fluentui/react-components';
import { useSortableTableStyles } from '../../styles';

export interface ISortableHeaderCellProps {
    /** Explanation of the column, shown in a tooltip above the header; no tooltip when omitted. */
    help?: ReactNode;
    /** Extra class, for example a column width. */
    className?: string;
    /** The column's sort direction, or `undefined` when another column (or none) is sorted. */
    sortDirection: SortDirection | undefined;
    onClick: () => void;
    children: ReactNode;
}

/** A semibold, clickable sort header for the tool's sortable tables, with an optional help tooltip. */
export function SortableHeaderCell({ help, className, sortDirection, onClick, children }: ISortableHeaderCellProps) {
    const styles = useSortableTableStyles();
    const cell = (
        <TableHeaderCell className={mergeClasses(styles.headerCell, className)} sortDirection={sortDirection} onClick={onClick}>
            {children}
        </TableHeaderCell>
    );
    if (help === undefined) return cell;
    return (
        // Wrapping the cell means the tooltip opens on hover and when its sort button gets focus.
        <Tooltip content={{ children: help, className: styles.headerTooltip }} relationship="description" positioning="above" withArrow>
            {cell}
        </Tooltip>
    );
}
