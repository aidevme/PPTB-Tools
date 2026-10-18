/**
 * The Load Existing Project dialog's table columns and how each one sorts. Pure functions, so the order can be tested
 * without rendering the dialog.
 */
import type { SortDirection } from '@fluentui/react-components';
import type { ProjectEntry } from '../../config';
import { compareText } from '../shared/sorting';

/** The Load Existing Project table's columns, each named after the project entry field it shows. */
export type ProjectColumnKey = 'name' | 'description' | 'version' | 'location' | 'createdOn' | 'modifiedOn';

/** How the Load Existing Project table is sorted. */
export interface ProjectSort {
    /** The column the projects are sorted by. */
    column: ProjectColumnKey;
    /** Ascending or descending order of that column. */
    direction: SortDirection;
}

/**
 * Compares two project versions part by part as numbers, so `1.0.10` sorts after `1.0.9`.
 *
 * @remarks
 * Missing parts count as 0 (`1.0` equals `1.0.0`). When either value isn't dotted numbers, both are compared as
 * text.
 *
 * @param a - The first version.
 * @param b - The second version.
 * @returns A negative number when `a` sorts first, a positive number when `b` does, and 0 when they're equal.
 */
export function compareVersions(a: string, b: string): number {
    const parse = (v: string) => (/^\d+(\.\d+)*$/.test(v.trim()) ? v.trim().split('.').map(Number) : undefined);
    const pa = parse(a);
    const pb = parse(b);
    if (!pa || !pb) return compareText(a, b);
    for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
        const diff = (pa[i] ?? 0) - (pb[i] ?? 0);
        if (diff !== 0) return diff;
    }
    return 0;
}

/**
 * Compares ISO dates; a value that isn't a date counts as the earliest.
 *
 * @param a - The first date.
 * @param b - The second date.
 * @returns A negative number when `a` is earlier, a positive number when it's later, and 0 when they're equal.
 */
export const compareDates = (a: string, b: string): number => (Date.parse(a) || 0) - (Date.parse(b) || 0);

/** The table's columns in display order: each column's key, header label and how it compares two projects. */
export const PROJECT_COLUMNS: Array<{ key: ProjectColumnKey; label: string; compare: (a: ProjectEntry, b: ProjectEntry) => number }> = [
    { key: 'name', label: 'Name', compare: (a, b) => compareText(a.name, b.name) },
    { key: 'description', label: 'Description', compare: (a, b) => compareText(a.description, b.description) },
    { key: 'version', label: 'Version', compare: (a, b) => compareVersions(a.version, b.version) },
    { key: 'location', label: 'Location', compare: (a, b) => compareText(a.location, b.location) },
    { key: 'createdOn', label: 'Created on', compare: (a, b) => compareDates(a.createdOn, b.createdOn) },
    { key: 'modifiedOn', label: 'Modified on', compare: (a, b) => compareDates(a.modifiedOn, b.modifiedOn) },
];

/** The order the table opens with: by name, ascending. */
export const DEFAULT_PROJECT_SORT: ProjectSort = { column: 'name', direction: 'ascending' };

/**
 * The projects in table order; ties keep name order, so equal versions or dates still list predictably.
 *
 * @remarks
 * An unknown column sorts by name. The input array isn't changed.
 *
 * @param projects - The saved projects, in any order.
 * @param sort - The column and direction to sort by.
 * @returns A new array of the projects, sorted.
 */
export function sortProjects(projects: readonly ProjectEntry[], sort: ProjectSort): ProjectEntry[] {
    const column = PROJECT_COLUMNS.find((c) => c.key === sort.column) ?? PROJECT_COLUMNS[0];
    const sign = sort.direction === 'ascending' ? 1 : -1;
    return [...projects].sort((a, b) => sign * column.compare(a, b) || compareText(a.name, b.name));
}
