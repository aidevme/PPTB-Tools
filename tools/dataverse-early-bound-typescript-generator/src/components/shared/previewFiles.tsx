/**
 * The Preview card's file table logic: sorting, filtering, the header tooltips and the list/viewer split widths.
 * Kept out of `PreviewCard` so the card stays presentational and this can be tested on its own.
 */
import type { SortDirection } from '@fluentui/react-components';
import type { FileStatus, PlannedFile } from '../../types';
import { STATUS_ORDER, fileName, fileType } from './generatedFiles';

/** Columns the file table can be sorted by. */
export type FileSortColumn = 'name' | 'type' | 'status';

const textCompare = (a: string, b: string) => a.localeCompare(b, undefined, { sensitivity: 'base', numeric: true });

const COMPARERS: Record<FileSortColumn, (a: PlannedFile, b: PlannedFile) => number> = {
    name: (a, b) => textCompare(fileName(a.relativePath), fileName(b.relativePath)),
    type: (a, b) => textCompare(fileType(a.relativePath), fileType(b.relativePath)),
    status: (a, b) => STATUS_ORDER.indexOf(a.status) - STATUS_ORDER.indexOf(b.status),
};

/**
 * Files in the order to list them: the plan's own order (grouped by folder) until a column is sorted, then by
 * that column, with ties in name order.
 */
export function sortFiles(files: PlannedFile[], sort: { column: FileSortColumn; direction: SortDirection } | null): PlannedFile[] {
    if (!sort) return files;
    const sign = sort.direction === 'ascending' ? 1 : -1;
    return [...files].sort((a, b) => sign * COMPARERS[sort.column](a, b) || COMPARERS.name(a, b) || textCompare(a.relativePath, b.relativePath));
}

export interface FileFilter {
    /** Only files with this status; `null` for the default view. */
    status: FileStatus | null;
    /** In the default view, also list unchanged files. */
    showUnchanged: boolean;
    /** Case-insensitive text matched against the file's path. */
    search: string;
}

/**
 * The files the table shows. By default, only what Generate acts on or reports (new, changed, orphaned and
 * duplicate-identifier files); unchanged files appear with `showUnchanged` or when their tile is selected. From
 * {@link MIN_SEARCH_LENGTH} characters, the search lists the files whose name or path starts with it, unchanged ones
 * included, still within a selected status tile.
 */
export function visibleFiles(files: PlannedFile[], filter: FileFilter): PlannedFile[] {
    const searching = isSearchActive(filter.search);
    return files.filter(
        (f) =>
            (filter.status ? f.status === filter.status : searching || filter.showUnchanged || f.status !== 'unchanged') &&
            (!searching || matchesSearch(f, filter.search)),
    );
}

/** The search filters the table once more than two characters are typed. */
export const MIN_SEARCH_LENGTH = 3;

/** Whether the search box holds enough text to filter the table. */
export function isSearchActive(search: string): boolean {
    return search.trim().length >= MIN_SEARCH_LENGTH;
}

/** Whether a file's name, or its path, starts with the search text (case-insensitive). */
export function matchesSearch(file: PlannedFile, search: string): boolean {
    const term = search.trim().toLowerCase();
    return fileName(file.relativePath).toLowerCase().startsWith(term) || file.relativePath.toLowerCase().startsWith(term);
}

/** Explanations shown in the header cells' tooltips. */
export const HEADER_HELP: Record<FileSortColumn, JSX.Element> = {
    name: (
        <>
            <strong>Name:</strong> the file name, without its output folder. "(generated as …)" means a file with the same name in
            different casing already exists and is reused, so imports elsewhere keep working. Hover over a name for its full
            path. Click to sort by name.
        </>
    ),
    type: (
        <>
            <strong>Type:</strong> what the file contains, from its output folder.
            <ul>
                <li><strong>entities</strong>: a table's interface, attribute constants and metadata</li>
                <li><strong>enums</strong>: choice (option set) values</li>
                <li><strong>actions</strong>, <strong>functions</strong>: request types for Dataverse messages</li>
                <li><strong>metadata</strong>: metadata.ts, the cache passed to dataverse-ify</li>
                <li><strong>templates</strong>: dataverse-gen's EJS templates, written to the project's _templates folder for the dataverse-gen CLI</li>
                <li><strong>other</strong>: complex types and the index.ts barrel</li>
            </ul>
            Click to sort by type.
        </>
    ),
    status: (
        <>
            <strong>Status:</strong> how the generated file compares with the output folder.
            <ul>
                <li><strong>new</strong>: doesn't exist yet; Generate creates it</li>
                <li><strong>changed</strong>: content differs; Generate overwrites it</li>
                <li><strong>unchanged</strong>: identical; not rewritten</li>
                <li><strong>orphaned</strong>: in the output folder but no longer generated; only reported, unless Delete orphaned files is on</li>
                <li>
                    <strong>duplicate identifiers</strong>: declares the same name more than once (two choice labels that become the same
                    enum member), so it won't compile; fix the labels in Dataverse. Generate still writes it when it's new or changed
                </li>
            </ul>
            Click to sort by status (duplicate identifiers first, then new).
        </>
    ),
};

/** Narrowest the file list can be dragged to, in px. */
export const MIN_LIST_WIDTH = 280;
/** Narrowest the viewer beside the list can become, in px. */
export const MIN_VIEWER_WIDTH = 320;
/** The file list's starting width, in px. */
export const DEFAULT_LIST_WIDTH = 480;

/**
 * A file-list width kept within bounds: at least {@link MIN_LIST_WIDTH}, and leaving {@link MIN_VIEWER_WIDTH} for the
 * viewer when the split's total width is known (`total` > 0).
 */
export function clampListWidth(width: number, total: number): number {
    const max = total > 0 ? total - MIN_VIEWER_WIDTH : Number.MAX_SAFE_INTEGER;
    return Math.max(MIN_LIST_WIDTH, Math.min(width, max));
}
