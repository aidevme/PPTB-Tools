import { useMemo, useRef, useState, type KeyboardEvent, type PointerEvent as ReactPointerEvent } from 'react';
import {
    Button,
    MessageBar,
    MessageBarActions,
    MessageBarBody,
    Skeleton,
    SkeletonItem,
    Switch,
    Table,
    TableBody,
    TableCell,
    TableCellLayout,
    TableHeader,
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
    CodeTextRegular,
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
    WarningRegular,
} from '@fluentui/react-icons';
import type { FileStatus, WritePlan } from '../../types';
import { summarizePlan, writeCounts } from '../../services';
import { infoLabel } from '../shared/infoLabel';
import {
    DELETE_ORPHANS_INFO,
    DELETE_ORPHANS_TITLE,
    RENAME_DUPLICATES_INFO,
    RENAME_DUPLICATES_TITLE,
    SKIP_DUPLICATES_INFO,
    SKIP_DUPLICATES_TITLE,
} from '../shared/settingsInfo';
import { usePreviewCardStyles, useSortableTableStyles } from '../../styles';
import { formatRelativeTime, shortenPath } from '../shared/format';
import { STATUS_META, STATUS_ORDER, fileName, fileType, type GeneratedFileType } from '../shared/generatedFiles';
import { SortableHeaderCell } from '../shared/SortableHeaderCell';
import { nextSort } from '../shared/sorting';
import { StepCard } from '../shared/StepCard';
import { activateRowOnKey } from '../shared/tableRows';
import type { StepState } from '../shared/workflowSteps';
import { FileViewer } from '../viewers/FileViewer';
import { FileSearchBox } from '../shared/FileSearchBox';
import {
    DEFAULT_LIST_WIDTH,
    HEADER_HELP,
    MIN_LIST_WIDTH,
    clampListWidth,
    sortFiles,
    isSearchActive,
    visibleFiles,
    type FileFilter,
    type FileSortColumn,
} from '../shared/previewFiles';



const plural = (count: number, one: string, many: string) => `${count} ${count === 1 ? one : many}`;


/**
 * A Preview switch's explanation, plus why it's disabled: before the first preview nobody knows which files it
 * affects, and after one it stays disabled while the preview found none.
 */
const switchInfo = (info: JSX.Element, previewed: boolean, found: number, what: string) =>
    !previewed ? (
        <>
            {info} Available after Preview, once {what} are known.
        </>
    ) : found === 0 ? (
        <>
            {info} Disabled: the last preview found no {what}.
        </>
    ) : (
        info
    );

/** Explanation in the Show unchanged switch's info label. */
const SHOW_UNCHANGED_INFO = (
    <>
        By default the list shows only what needs attention: new, changed and orphaned files, and files with duplicate identifiers.
        Turn this on to list the unchanged files too: generated files identical to the ones in the output folder, which Generate
        doesn't rewrite. It only changes the list, not what Generate does, and isn't saved. It's disabled while a status tile
        filters the list (click the tile again to go back to the full list) and while a search is active, since a search
        includes unchanged files.
    </>
);

const TYPE_ICONS: Record<GeneratedFileType, JSX.Element> = {
    entities: <TableRegular />,
    enums: <TextBulletListLtrRegular />,
    actions: <FlashRegular />,
    functions: <MathFormulaRegular />,
    metadata: <DatabaseRegular />,
    templates: <CodeTextRegular />,
    other: <DocumentRegular />,
};

const STATUS_ICONS: Record<FileStatus, JSX.Element> = {
    new: <AddCircleRegular />,
    changed: <EditRegular />,
    unchanged: <CheckmarkCircleRegular />,
    orphaned: <DocumentQuestionMarkRegular />,
    duplicate: <WarningRegular />,
};


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
    /** Whether Generate leaves files with duplicate identifiers unwritten (the tool config's `skipDuplicateIdentifiers`). */
    skipDuplicates?: boolean;
    /** The Skip duplicated identifier(s) switch; saves `skipDuplicateIdentifiers`. The switch is hidden without it. */
    onSkipDuplicatesChange?: (checked: boolean) => void;
    /** Whether later duplicate enum members are renamed (the tool config's `renameDuplicateIdentifiers`). */
    renameDuplicates?: boolean;
    /** The Rename duplicated identifier(s) switch; saves `renameDuplicateIdentifiers`. The switch is hidden without it. */
    onRenameDuplicatesChange?: (checked: boolean) => void;
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
    const skipDuplicates = props.skipDuplicates ?? false;
    const styles = usePreviewCardStyles();
    const tableStyles = useSortableTableStyles();
    const [selectedPath, setSelectedPath] = useState<string | null>(null);
    const [filter, setFilter] = useState<FileFilter>({ status: null, showUnchanged: false, search: '' });
    const [sort, setSort] = useState<{ column: FileSortColumn; direction: SortDirection } | null>(null);
    const [listWidth, setListWidth] = useState(DEFAULT_LIST_WIDTH);
    const splitRef = useRef<HTMLDivElement>(null);
    const tableRef = useRef<HTMLTableElement>(null);

    const files = useMemo(() => (plan ? sortFiles(visibleFiles(plan.files, filter), sort) : []), [plan, filter, sort]);
    const selected = plan?.files.find((f) => f.relativePath === selectedPath) ?? null;
    const writes = useMemo(() => (plan ? writeCounts(plan, { skipDuplicates }) : { created: 0, overwritten: 0 }), [plan, skipDuplicates]);
    const writable = writes.created + writes.overwritten;

    const toggleSort = (column: FileSortColumn) => setSort((current) => nextSort(current, column));
    const sortDirection = (column: FileSortColumn) => (sort?.column === column ? sort.direction : undefined);
    const toggleStatus = (status: FileStatus) => setFilter((f) => ({ ...f, status: f.status === status ? null : status }));

    /** ↑/↓ move the selection to the neighbouring row and focus it. */
    const onRowKeyDown = (e: KeyboardEvent, index: number) => {
        if (activateRowOnKey(e, () => setSelectedPath(files[index].relativePath))) return;
        const target = e.key === 'ArrowDown' ? index + 1 : e.key === 'ArrowUp' ? index - 1 : -1;
        if (target >= 0 && target < files.length) {
            e.preventDefault();
            setSelectedPath(files[target].relativePath);
            tableRef.current?.querySelectorAll<HTMLElement>('tbody tr')[target]?.focus();
        }
    };

    const clampWidth = (width: number) => clampListWidth(width, splitRef.current?.clientWidth ?? 0);
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
                    {/* Both switches only apply to files a preview found: they're disabled before a preview and while it found
                        none. Their info labels show the same explanation as the Settings panel, plus the reason when disabled. */}
                    <Switch
                        label={infoLabel(DELETE_ORPHANS_TITLE, switchInfo(DELETE_ORPHANS_INFO, !!plan, plan?.counts.orphaned ?? 0, 'orphaned files'))}
                        checked={deleteOrphans}
                        disabled={!plan || plan.counts.orphaned === 0 || busy}
                        onChange={(_, data) => onDeleteOrphansChange(data.checked)}
                    />
                    {props.onRenameDuplicatesChange && (
                        <Switch
                            label={infoLabel(
                                RENAME_DUPLICATES_TITLE,
                                // Once on, the preview has no duplicates left, but the switch must stay usable to turn it off.
                                switchInfo(RENAME_DUPLICATES_INFO, !!plan, (plan?.counts.duplicate ?? 0) + (props.renameDuplicates ? 1 : 0), 'files with duplicate identifiers'),
                            )}
                            checked={props.renameDuplicates ?? false}
                            disabled={!plan || (plan.counts.duplicate === 0 && !props.renameDuplicates) || busy}
                            onChange={(_, data) => props.onRenameDuplicatesChange?.(data.checked)}
                        />
                    )}
                    {props.onSkipDuplicatesChange && (
                        <Switch
                            label={infoLabel(
                                SKIP_DUPLICATES_TITLE,
                                switchInfo(SKIP_DUPLICATES_INFO, !!plan, plan?.counts.duplicate ?? 0, 'files with duplicate identifiers'),
                            )}
                            checked={skipDuplicates}
                            disabled={!plan || plan.counts.duplicate === 0 || busy}
                            onChange={(_, data) => props.onSkipDuplicatesChange?.(data.checked)}
                        />
                    )}
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
                        <Text className={styles.summary}>{summarizePlan(plan.counts, deleteOrphans, writes, skipDuplicates)}</Text>
                        <div className={styles.tiles} role="group" aria-label="Filter by status">
                            {/* The duplicate identifiers tile only appears when there are some. */}
                            {STATUS_ORDER.filter((status) => status !== 'duplicate' || plan.counts.duplicate > 0).map((status) => {
                                const accent = {
                                    new: styles.accentNew,
                                    changed: styles.accentChanged,
                                    unchanged: styles.accentUnchanged,
                                    orphaned: styles.accentOrphaned,
                                    duplicate: styles.accentDuplicate,
                                }[status];
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
                            <FileSearchBox value={filter.search} onChange={(search) => setFilter((f) => ({ ...f, search }))} />
                            <Switch
                                label={infoLabel('Show unchanged', SHOW_UNCHANGED_INFO)}
                                checked={filter.showUnchanged}
                                // A status tile or an active search already decides whether unchanged files are listed.
                                disabled={filter.status !== null || isSearchActive(filter.search)}
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
                                    <TableRow className={tableStyles.headerRow}>
                                        {(
                                            [
                                                ['name', 'Name', undefined],
                                                ['type', 'Type', styles.typeColumn],
                                                ['status', 'Status', styles.statusColumn],
                                            ] as const
                                        ).map(([column, label, widthClass]) => (
                                            <SortableHeaderCell
                                                key={column}
                                                help={HEADER_HELP[column]}
                                                className={widthClass}
                                                sortDirection={sortDirection(column)}
                                                onClick={() => toggleSort(column)}
                                            >
                                                {label}
                                            </SortableHeaderCell>
                                        ))}
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {files.map((file, index) => {
                                        const isSelected = file.relativePath === selectedPath;
                                        const type = fileType(file.relativePath);
                                        const dot = {
                                            new: styles.dotNew,
                                            changed: styles.dotChanged,
                                            unchanged: styles.dotUnchanged,
                                            orphaned: styles.dotOrphaned,
                                            duplicate: styles.dotDuplicate,
                                        }[file.status];
                                        return (
                                            <TableRow
                                                key={file.relativePath}
                                                className={tableStyles.row}
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
                                                        {STATUS_META[file.status].label.toLowerCase()}
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
                        <FileViewer file={selected} onCopyText={onCopyText} skipDuplicates={skipDuplicates} />
                    </div>
                </div>
            </div>
        </StepCard>
    );
}
