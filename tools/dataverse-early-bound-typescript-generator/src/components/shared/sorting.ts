/**
 * Sorting helpers for the tool's sortable tables: the Select card, the Preview card and the Load Existing Project
 * dialog all toggle their sort with `nextSort`; the Select card's rows are also ordered here.
 */
import type { SortDirection } from '@fluentui/react-components';

/** First click on a column sorts ascending; clicking the sorted column again flips the direction. */
export function nextSort<C>(current: { column: C; direction: SortDirection } | null, column: C): { column: C; direction: SortDirection } {
    return current?.column === column && current.direction === 'ascending' ? { column, direction: 'descending' } : { column, direction: 'ascending' };
}

/** A value to sort a column by; `undefined` (no value) is always listed last. */
export type SortValue = string | number | undefined;

export interface SortState {
    /** Index into the tab's columns. */
    column: number;
    direction: SortDirection;
}

/** Case-insensitive text order with numbers compared by value (`item2` before `item10`). */
export function compareText(a: string, b: string): number {
    return a.localeCompare(b, undefined, { sensitivity: 'base', numeric: true });
}

/** Compares two sort values in `direction`; `undefined` (no value) sorts last in both directions. */
export function compareSortValues(a: SortValue, b: SortValue, direction: SortDirection): number {
    if (a === undefined || b === undefined) return a === b ? 0 : a === undefined ? 1 : -1;
    const result = typeof a === 'number' && typeof b === 'number' ? a - b : compareText(String(a), String(b));
    return direction === 'ascending' ? result : -result;
}

/**
 * Rows in the order to list them: their given order until a column is sorted, then by that column, with ties in
 * their given order. Rows without a value for the column come last in either direction.
 */
export function sortSelectionRows<T extends { sortValues: SortValue[] }>(rows: T[], sort: SortState | null): T[] {
    if (!sort) return rows;
    return rows
        .map((row, index) => ({ row, index }))
        .sort((a, b) => compareSortValues(a.row.sortValues[sort.column], b.row.sortValues[sort.column], sort.direction) || a.index - b.index)
        .map(({ row }) => row);
}
