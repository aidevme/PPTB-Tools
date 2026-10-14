import { useMemo, useRef, useState, type KeyboardEvent, type PointerEvent as ReactPointerEvent } from 'react';
import {
    Button,
    MessageBar,
    MessageBarActions,
    MessageBarBody,
    SearchBox,
    Skeleton,
    SkeletonItem,
    Switch,
    Table,
    TableBody,
    TableCell,
    TableCellLayout,
    TableHeader,
    TableHeaderCell,
    TableRow,
    Text,
    Tooltip,
    mergeClasses,
    type SortDirection,
} from '@fluentui/react-components';
import {
    AddCircleRegular,
    ArrowSyncRegular,
    CheckmarkCircleRegular,
    CopyRegular,
    DatabaseRegular,
    DocumentQuestionMarkRegular,
    DocumentRegular,
    DocumentSearchRegular,
    EditRegular,
    FlashRegular,
    InfoRegular,
    MathFormulaRegular,
    SaveRegular,
    TableRegular,
    TextBulletListLtrRegular,
} from '@fluentui/react-icons';
import type { FileStatus, PlannedFile, WritePlan } from '../../types';
import { summarizePlan } from '../../services';
import { usePreviewCardStyles } from '../../styles';
import { formatRelativeTime, shortenPath } from '../shared/format';
import { STATUS_META, STATUS_ORDER, fileName, fileType, type GeneratedFileType } from '../shared/generatedFiles';
import { StepCard } from '../shared/StepCard';
import type { StepState } from '../shared/workflowSteps';
import { FileViewer } from '../viewers/FileViewer';

export { fileType } from '../shared/generatedFiles';
export { summarizePlan } from '../../services';

type SortColumn = 'name' | 'type' | 'status';

const textCompare = (a: string, b: string) => a.localeCompare(b, undefined, { sensitivity: 'base', numeric: true });

const COMPARERS: Record<SortColumn, (a: PlannedFile, b: PlannedFile) => number> = {
    name: (a, b) => textCompare(fileName(a.relativePath), fileName(b.relativePath)),
    type: (a, b) => textCompare(fileType(a.relativePath), fileType(b.relativePath)),
    status: (a, b) => STATUS_ORDER.indexOf(a.status) - STATUS_ORDER.indexOf(b.status),
};

/**
 * Files in the order to list them: the plan's own order (grouped by folder) until a column is sorted, then by
 * that column, with ties in name order.
 */
export function sortFiles(files: PlannedFile[], sort: { column: SortColumn; direction: SortDirection } | null): PlannedFile[] {
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
 * The files the table shows. By default, only what Generate acts on or reports (new, changed and orphaned);
 * unchanged files appear with `showUnchanged` or when their tile is selected.
 */
export function visibleFiles(files: PlannedFile[], filter: FileFilter): PlannedFile[] {
    const term = filter.search.trim().toLowerCase();
    return files.filter(
        (f) =>
            (filter.status ? f.status === filter.status : filter.showUnchanged || f.status !== 'unchanged') &&
            (!term || f.relativePath.toLowerCase().includes(term)),
    );
}

const plural = (count: number, one: string, many: string) => `${count} ${count === 1 ? one : many}`;

/** Explanations shown in the header cells' tooltips. */
const HEADER_HELP: Record<SortColumn, JSX.Element> = {
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
            </ul>
            Click to sort by status (new first).
        </>
    ),
};

/** Explanation shown in the Delete orphaned files switch's tooltip. */
const DELETE_ORPHANS_HELP = (
    <>
        <strong>Delete orphaned files:</strong> when on, Generate also deletes orphaned files: files in the output folders that the
        current selection no longer generates, such as a table you removed. You confirm the list first. Files are deleted permanently,
        not moved to the Recycle Bin or Trash. When off, orphaned files are only reported. Saved in the tool settings.
    </>
);

const TYPE_ICONS: Record<GeneratedFileType, JSX.Element> = {
    entities: <TableRegular />,
    enums: <TextBulletListLtrRegular />,
    actions: <FlashRegular />,
    functions: <MathFormulaRegular />,
    metadata: <DatabaseRegular />,
    other: <DocumentRegular />,
};

const STATUS_ICONS: Record<FileStatus, JSX.Element> = {
    new: <AddCircleRegular />,
    changed: <EditRegular />,
    unchanged: <CheckmarkCircleRegular />,
    orphaned: <DocumentQuestionMarkRegular />,
};

const MIN_LIST_WIDTH = 280;
const MIN_VIEWER_WIDTH = 320;
const DEFAULT_LIST_WIDTH = 480;

export interface PreviewCardProps {
    step: StepState;
    plan: WritePlan | null;
    /** Whether the plan is stale because the selection or options changed since it was computed. */
    stale: boolean;
    canPreview: boolean;
    /** True when everything is ready except the project folder; shows a hint next to the buttons. */
    needsProject: boolean;
    busy: boolean;
    /** When the current plan was computed (ISO), for "Previewed … ago". */
    previewedAt: string | null;
    /** Summary of the last Generate run, shown as a success message until the next preview. */
    lastResult: string | null;
    /** Whether Generate also deletes orphaned files (the tool config's `deleteOrphanedFiles`). */
    deleteOrphans: boolean;
    onDeleteOrphansChange: (checked: boolean) => void;
    onPreview: () => void;
    onGenerate: () => void;
    /** Copies text (a file's content or a path) to the clipboard; `label` names it in the confirmation. */
    onCopyText: (text: string, label: string) => void;
    /** Current time for relative dates; a parameter so tests get stable output. */
    now?: number;
}

/**
 * Steps 4 and 5: preview what Generate would do, then write it. Status tiles summarise and filter the files;
 * the table lists them (changes only by default) beside a viewer showing each file's content or changes.
 */
export function PreviewCard(props: PreviewCardProps) {
    const { step, plan, stale, canPreview, needsProject, busy, previewedAt, lastResult, deleteOrphans, onDeleteOrphansChange, onPreview, onGenerate, onCopyText } = props;
    const styles = usePreviewCardStyles();
    const [selectedPath, setSelectedPath] = useState<string | null>(null);
    const [filter, setFilter] = useState<FileFilter>({ status: null, showUnchanged: false, search: '' });
    const [sort, setSort] = useState<{ column: SortColumn; direction: SortDirection } | null>(null);
    const [listWidth, setListWidth] = useState(DEFAULT_LIST_WIDTH);
    const splitRef = useRef<HTMLDivElement>(null);
    const tableRef = useRef<HTMLTableElement>(null);

    const files = useMemo(() => (plan ? sortFiles(visibleFiles(plan.files, filter), sort) : []), [plan, filter, sort]);
    const selected = plan?.files.find((f) => f.relativePath === selectedPath) ?? null;
    const writable = plan ? plan.counts.new + plan.counts.changed : 0;

    const toggleSort = (column: SortColumn) =>
        setSort((current) =>
            current?.column === column ? { column, direction: current.direction === 'ascending' ? 'descending' : 'ascending' } : { column, direction: 'ascending' },
        );
    const sortDirection = (column: SortColumn) => (sort?.column === column ? sort.direction : undefined);
    const toggleStatus = (status: FileStatus) => setFilter((f) => ({ ...f, status: f.status === status ? null : status }));

    /** ↑/↓ move the selection to the neighbouring row and focus it. */
    const onRowKeyDown = (e: KeyboardEvent, index: number) => {
        const target = e.key === 'ArrowDown' ? index + 1 : e.key === 'ArrowUp' ? index - 1 : -1;
        if (e.key === ' ' || e.key === 'Enter') {
            e.preventDefault();
            setSelectedPath(files[index].relativePath);
        } else if (target >= 0 && target < files.length) {
            e.preventDefault();
            setSelectedPath(files[target].relativePath);
            tableRef.current?.querySelectorAll<HTMLElement>('tbody tr')[target]?.focus();
        }
    };

    const clampWidth = (width: number) => {
        const total = splitRef.current?.clientWidth ?? 0;
        const max = total > 0 ? total - MIN_VIEWER_WIDTH : Number.MAX_SAFE_INTEGER;
        return Math.max(MIN_LIST_WIDTH, Math.min(width, max));
    };
    const startResize = (e: ReactPointerEvent<HTMLDivElement>) => {
        const startX = e.clientX;
        const startWidth = listWidth;
        const move = (ev: PointerEvent) => setListWidth(clampWidth(startWidth + ev.clientX - startX));
        const stop = () => {
            window.removeEventListener('pointermove', move);
            window.removeEventListener('pointerup', stop);
        };
        window.addEventListener('pointermove', move);
        window.addEventListener('pointerup', stop);
    };
    const onSplitterKeyDown = (e: KeyboardEvent) => {
        const delta = e.key === 'ArrowLeft' ? -32 : e.key === 'ArrowRight' ? 32 : 0;
        if (delta) {
            e.preventDefault();
            setListWidth((w) => clampWidth(w + delta));
        }
    };

    const deletable = plan && deleteOrphans ? plan.counts.orphaned : 0;
    const generateLabel = !plan
        ? 'Generate'
        : writable > 0
          ? `Generate ${plural(writable, 'file', 'files')}`
          : deletable > 0
            ? `Delete ${plural(deletable, 'orphaned file', 'orphaned files')}`
            : 'Nothing to write';
    const generateHelp = !plan
        ? 'Run Preview first'
        : writable === 0 && deletable === 0
          ? 'Every generated file is already up to date'
          : [
                writable > 0 && 'Write the new and changed files and save .dataverse-gen.json',
                deletable > 0 && `${writable > 0 ? 'then delete' : 'Delete'} the orphaned files (asks for confirmation first)`,
            ]
                .filter(Boolean)
                .join(', ');

    return (
        <StepCard
            step={step}
            description={
                deleteOrphans
                    ? 'Preview compares the generated files with the output folder; Generate writes only new and changed files, then deletes orphaned files after you confirm.'
                    : 'Preview compares the generated files with the output folder; Generate writes only new and changed files and never deletes anything.'
            }
        >
            <div className={styles.body}>
                {plan && stale && (
                    <MessageBar intent="warning">
                        <MessageBarBody>The selection or options changed since this preview.</MessageBarBody>
                        <MessageBarActions>
                            <Button size="small" icon={<ArrowSyncRegular />} disabled={!canPreview || busy} onClick={onPreview}>
                                Preview again
                            </Button>
                        </MessageBarActions>
                    </MessageBar>
                )}
                {lastResult && (
                    <MessageBar intent="success">
                        <MessageBarBody>{lastResult}</MessageBarBody>
                    </MessageBar>
                )}

                <div className={styles.actionBar}>
                    <Button icon={<DocumentSearchRegular />} disabled={!canPreview || busy} onClick={onPreview}>
                        Preview
                    </Button>
                    <Tooltip content={generateHelp} relationship="description" withArrow>
                        <Button appearance="primary" icon={<SaveRegular />} disabled={!plan || stale || busy || writable + deletable === 0} onClick={onGenerate}>
                            {generateLabel}
                        </Button>
                    </Tooltip>
                    <Tooltip
                        content={{
                            children: plan ? DELETE_ORPHANS_HELP : <>{DELETE_ORPHANS_HELP} Available after Preview, once the orphaned files are known.</>,
                            className: styles.headerTooltip,
                        }}
                        relationship="description"
                        withArrow
                    >
                        {/* Only after a preview: until then nobody knows which files would be deleted. */}
                        <Switch
                            label="Delete orphaned files"
                            checked={deleteOrphans}
                            disabled={!plan || busy}
                            onChange={(_, data) => onDeleteOrphansChange(data.checked)}
                        />
                    </Tooltip>
                    {previewedAt && (
                        <Text size={200} className={styles.muted}>
                            Previewed {formatRelativeTime(previewedAt, props.now)}
                        </Text>
                    )}
                    {needsProject && (
                        <span className={styles.hint}>
                            <InfoRegular aria-hidden="true" />
                            <Text size={200}>Open a project (step 1) to preview and generate.</Text>
                        </span>
                    )}
                </div>

                {plan && (
                    <>
                        <Text className={styles.summary}>{summarizePlan(plan.counts, deleteOrphans)}</Text>
                        <div className={styles.tiles} role="group" aria-label="Filter by status">
                            {STATUS_ORDER.map((status) => {
                                const accent = { new: styles.accentNew, changed: styles.accentChanged, unchanged: styles.accentUnchanged, orphaned: styles.accentOrphaned }[status];
                                const pressed = filter.status === status;
                                return (
                                    <Tooltip key={status} content={`${STATUS_META[status].meaning} Click to ${pressed ? 'show all changes' : 'show only these'}.`} relationship="description" withArrow>
                                        <button
                                            type="button"
                                            className={mergeClasses(styles.tile, accent, pressed && styles.tileSelected)}
                                            aria-pressed={pressed}
                                            onClick={() => toggleStatus(status)}
                                        >
                                            <span className={styles.tileIcon} aria-hidden="true">
                                                {STATUS_ICONS[status]}
                                            </span>
                                            <span className={styles.tileText}>
                                                <span className={styles.tileCount}>{plan.counts[status]}</span>
                                                <span className={styles.tileLabel}>{STATUS_META[status].label}</span>
                                            </span>
                                        </button>
                                    </Tooltip>
                                );
                            })}
                        </div>
                        <div className={styles.outputRow}>
                            <Text size={200} className={styles.muted}>
                                Output folder
                            </Text>
                            <Tooltip content={plan.outputRoot} relationship="description" withArrow>
                                <span className={styles.pathChip}>{shortenPath(plan.outputRoot, 64)}</span>
                            </Tooltip>
                            <Tooltip content="Copy output folder path" relationship="label" withArrow>
                                <Button appearance="subtle" size="small" icon={<CopyRegular />} onClick={() => onCopyText(plan.outputRoot, 'Output folder path')} />
                            </Tooltip>
                        </div>
                        <div className={styles.filterBar}>
                            <SearchBox
                                className={styles.search}
                                placeholder="Search files"
                                value={filter.search}
                                onChange={(_, data) => setFilter((f) => ({ ...f, search: data.value }))}
                                aria-label="Search files"
                            />
                            <Switch
                                label="Show unchanged"
                                checked={filter.showUnchanged}
                                disabled={filter.status !== null}
                                onChange={(_, data) => setFilter((f) => ({ ...f, showUnchanged: data.checked }))}
                            />
                            <Text size={200} className={styles.muted} aria-live="polite">
                                Showing {files.length} of {plan.files.length} files
                            </Text>
                        </div>
                    </>
                )}

                <div className={styles.split} ref={splitRef}>
                    <div className={mergeClasses(styles.panel, styles.list)} style={{ width: listWidth }}>
                        {!plan && busy ? (
                            <Skeleton className={styles.skeleton} aria-label="Loading the preview">
                                {Array.from({ length: 8 }, (_, i) => (
                                    <SkeletonItem key={i} size={20} />
                                ))}
                            </Skeleton>
                        ) : !plan ? (
                            <div className={styles.placeholder}>No preview yet. Click Preview to see what Generate would write.</div>
                        ) : files.length === 0 ? (
                            <div className={styles.placeholder}>
                                {filter.search ? 'No files match the search.' : filter.status ? 'No files with this status.' : 'Nothing to write. Turn on Show unchanged to list every file.'}
                            </div>
                        ) : (
                            <Table aria-label="Generated files" size="extra-small" sortable ref={tableRef}>
                                <TableHeader>
                                    <TableRow className={styles.headerRow}>
                                        {(
                                            [
                                                ['name', 'Name', undefined],
                                                ['type', 'Type', styles.typeColumn],
                                                ['status', 'Status', styles.statusColumn],
                                            ] as const
                                        ).map(([column, label, widthClass]) => (
                                            // Wrapping the cell means the tooltip opens on hover and when its sort button gets focus.
                                            <Tooltip
                                                key={column}
                                                content={{ children: HEADER_HELP[column], className: styles.headerTooltip }}
                                                relationship="description"
                                                positioning="above"
                                                withArrow
                                            >
                                                <TableHeaderCell
                                                    className={mergeClasses(styles.headerCell, widthClass)}
                                                    sortDirection={sortDirection(column)}
                                                    onClick={() => toggleSort(column)}
                                                >
                                                    {label}
                                                </TableHeaderCell>
                                            </Tooltip>
                                        ))}
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {files.map((file, index) => {
                                        const isSelected = file.relativePath === selectedPath;
                                        const type = fileType(file.relativePath);
                                        const dot = { new: styles.dotNew, changed: styles.dotChanged, unchanged: styles.dotUnchanged, orphaned: styles.dotOrphaned }[file.status];
                                        return (
                                            <TableRow
                                                key={file.relativePath}
                                                className={styles.row}
                                                aria-selected={isSelected}
                                                appearance={isSelected ? 'brand' : 'none'}
                                                tabIndex={0}
                                                onClick={() => setSelectedPath(file.relativePath)}
                                                onKeyDown={(e) => onRowKeyDown(e, index)}
                                            >
                                                <TableCell>
                                                    <TableCellLayout truncate media={<span className={styles.typeIcon}>{TYPE_ICONS[type]}</span>}>
                                                        <Tooltip content={file.absolutePath} relationship="description" withArrow>
                                                            <span className={styles.fileName}>
                                                                {fileName(file.relativePath)}
                                                                {file.generatedName ? ` (generated as ${file.generatedName})` : ''}
                                                            </span>
                                                        </Tooltip>
                                                    </TableCellLayout>
                                                </TableCell>
                                                <TableCell className={styles.typeColumn}>{type}</TableCell>
                                                <TableCell className={styles.statusColumn}>
                                                    <span className={styles.status}>
                                                        <span className={mergeClasses(styles.dot, dot)} aria-hidden="true" />
                                                        {file.status}
                                                    </span>
                                                </TableCell>
                                            </TableRow>
                                        );
                                    })}
                                </TableBody>
                            </Table>
                        )}
                    </div>
                    <div
                        className={styles.splitter}
                        role="separator"
                        aria-orientation="vertical"
                        aria-label="Resize the file list"
                        aria-valuenow={listWidth}
                        aria-valuemin={MIN_LIST_WIDTH}
                        tabIndex={0}
                        onPointerDown={startResize}
                        onKeyDown={onSplitterKeyDown}
                    />
                    <div className={mergeClasses(styles.panel, styles.viewer)}>
                        <FileViewer file={selected} onCopyText={onCopyText} />
                    </div>
                </div>
            </div>
        </StepCard>
    );
}
