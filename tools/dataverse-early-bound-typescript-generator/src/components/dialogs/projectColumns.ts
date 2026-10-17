/**
 * The Load Existing Project dialog's table columns and how each one sorts. Pure functions, so the order can be tested
 * without rendering the dialog.
 */
import type { SortDirection } from '@fluentui/react-components';
import type { ProjectEntry } from '../../config';
import { compareText } from '../shared/sorting';

export type ProjectColumnKey = 'name' | 'description' | 'version' | 'location' | 'createdOn' | 'modifiedOn';

export interface ProjectSort {
    column: ProjectColumnKey;
    direction: SortDirection;
}

/** `1.0.10` sorts after `1.0.9`; anything that isn't dotted numbers falls back to text order. */
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

/** Compares ISO dates; a value that isn't a date counts as the earliest. */
export const compareDates = (a: string, b: string): number => (Date.parse(a) || 0) - (Date.parse(b) || 0);

export const PROJECT_COLUMNS: Array<{ key: ProjectColumnKey; label: string; compare: (a: ProjectEntry, b: ProjectEntry) => number }> = [
    { key: 'name', label: 'Name', compare: (a, b) => compareText(a.name, b.name) },
    { key: 'description', label: 'Description', compare: (a, b) => compareText(a.description, b.description) },
    { key: 'version', label: 'Version', compare: (a, b) => compareVersions(a.version, b.version) },
    { key: 'location', label: 'Location', compare: (a, b) => compareText(a.location, b.location) },
    { key: 'createdOn', label: 'Created On', compare: (a, b) => compareDates(a.createdOn, b.createdOn) },
    { key: 'modifiedOn', label: 'Modified On', compare: (a, b) => compareDates(a.modifiedOn, b.modifiedOn) },
];

export const DEFAULT_PROJECT_SORT: ProjectSort = { column: 'name', direction: 'ascending' };

/** The projects in table order; ties keep name order, so equal versions or dates still list predictably. */
export function sortProjects(projects: readonly ProjectEntry[], sort: ProjectSort): ProjectEntry[] {
    const column = PROJECT_COLUMNS.find((c) => c.key === sort.column) ?? PROJECT_COLUMNS[0];
    const sign = sort.direction === 'ascending' ? 1 : -1;
    return [...projects].sort((a, b) => sign * column.compare(a, b) || compareText(a.name, b.name));
}
