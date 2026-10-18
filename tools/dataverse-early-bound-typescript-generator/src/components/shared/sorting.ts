/**
 * Sorting helpers for the tool's sortable tables: the Select card, the Preview card and the Load Existing Project
 * dialog all toggle their sort with `nextSort`; the Select card's rows are also ordered here.
 */
import type { SortDirection } from '@fluentui/react-components';

/**
 * First click on a column sorts ascending; clicking the sorted column again flips the direction.
 *
 * @typeParam C - The column identifier (a name or an index).
 * @param current - The current sort, or `null` when no column is sorted.
 * @param column - The column whose header was clicked.
 * @returns `column` descending when it was already sorted ascending, otherwise `column` ascending.
 */
export function nextSort<C>(current: { column: C; direction: SortDirection } | null, column: C): { column: C; direction: SortDirection } {
    return current?.column === column && current.direction === 'ascending' ? { column, direction: 'descending' } : { column, direction: 'ascending' };
}

/** A value to sort a column by; `undefined` (no value) is always listed last. */
export type SortValue = string | number | undefined;

/** The sorted column of a Select card table, for {@link sortSelectionRows}. */
export interface SortState {
    /** Index into the tab's columns. */
    column: number;
    /** `ascending` or `descending`; rows without a value stay last either way. */
    direction: SortDirection;
}

/**
 * Case-insensitive text order with numbers compared by value (`item2` before `item10`).
 *
 * @param a - The first text.
 * @param b - The second text.
 * @returns A negative number when `a` sorts first, a positive one when `b` does, and 0 when they're equal.
 */
export function compareText(a: string, b: string): number {
    return a.localeCompare(b, undefined, { sensitivity: 'base', numeric: true });
}

/**
 * Compares two sort values in `direction`; `undefined` (no value) sorts last in both directions.
 *
 * @remarks
 * Two numbers are compared numerically; any other pair is compared as text with {@link compareText}.
 *
 * @param a - The first value.
 * @param b - The second value.
 * @param direction - The sort direction; descending negates the result, except for `undefined` values.
 * @returns A negative number when `a` is listed first, a positive one when `b` is, and 0 when they're equal.
 */
export function compareSortValues(a: SortValue, b: SortValue, direction: SortDirection): number {
    if (a === undefined || b === undefined) return a === b ? 0 : a === undefined ? 1 : -1;
    const result = typeof a === 'number' && typeof b === 'number' ? a - b : compareText(String(a), String(b));
    return direction === 'ascending' ? result : -result;
}

/**
 * Rows in the order to list them: their given order until a column is sorted, then by that column, with ties in
 * their given order. Rows without a value for the column come last in either direction.
 *
 * @typeParam T - The row type; each row carries one sort value per column.
 * @param rows - The rows in their given order; not modified.
 * @param sort - The sorted column and direction, or `null` when no column is sorted.
 * @returns `rows` itself when `sort` is `null`, otherwise a sorted copy (a stable sort).
 */
export function sortSelectionRows<T extends { sortValues: SortValue[] }>(rows: T[], sort: SortState | null): T[] {
    if (!sort) return rows;
    return rows
        .map((row, index) => ({ row, index }))
        .sort((a, b) => compareSortValues(a.row.sortValues[sort.column], b.row.sortValues[sort.column], sort.direction) || a.index - b.index)
        .map(({ row }) => row);
}
