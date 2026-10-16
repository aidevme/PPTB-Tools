/**
 * Parts of the Preview card: the action bar (Preview, Generate and the switches), the status tiles, and the file
 * table. They're presentational; `PreviewCard` holds the state.
 */
import { useRef, type KeyboardEvent } from 'react';
import { Button, Switch, Table, TableBody, TableCell, TableCellLayout, TableHeader, TableRow, Text, Tooltip, mergeClasses, type SortDirection } from '@fluentui/react-components';
import {
    AddCircleRegular,
    CheckmarkCircleRegular,
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
import type { FileStatus, PlannedFile, WritePlan } from '../../types';
import { plural } from '../../services';
import { usePreviewCardStyles, useSortableTableStyles } from '../../styles';
import { formatRelativeTime } from '../shared/format';
import { STATUS_META, STATUS_ORDER, fileName, fileType, type GeneratedFileType } from '../shared/generatedFiles';
import { infoLabel } from '../shared/infoLabel';
import { HEADER_HELP, type FileSortColumn } from '../shared/previewFiles';
import {
    DELETE_ORPHANS_INFO,
    DELETE_ORPHANS_TITLE,
    RENAME_DUPLICATES_INFO,
    RENAME_DUPLICATES_TITLE,
    SKIP_DUPLICATES_INFO,
    SKIP_DUPLICATES_TITLE,
} from '../shared/settingsInfo';
import { SortableHeaderCell } from '../shared/SortableHeaderCell';
import { activateRowOnKey } from '../shared/tableRows';

type PreviewCardStyles = ReturnType<typeof usePreviewCardStyles>;

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

/** The status tile's accent class, per status. */
const STATUS_ACCENT: Record<FileStatus, keyof PreviewCardStyles> = {
    new: 'accentNew',
    changed: 'accentChanged',
    unchanged: 'accentUnchanged',
    orphaned: 'accentOrphaned',
    duplicate: 'accentDuplicate',
};

/** The file table's status dot class, per status. */
const STATUS_DOT: Record<FileStatus, keyof PreviewCardStyles> = {
    new: 'dotNew',
    changed: 'dotChanged',
    unchanged: 'dotUnchanged',
    orphaned: 'dotOrphaned',
    duplicate: 'dotDuplicate',
};

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

/** The Generate button's label: what it will write, or delete when there's nothing to write. */
function generateLabel(plan: WritePlan | null, writable: number, deletable: number): string {
    if (!plan) return 'Generate';
    if (writable > 0) return `Generate ${plural(writable, 'file', 'files')}`;
    if (deletable > 0) return `Delete ${plural(deletable, 'orphaned file', 'orphaned files')}`;
    return 'Nothing to write';
}

/** The Generate button's tooltip. */
function generateHelp(plan: WritePlan | null, writable: number, deletable: number): string {
    if (!plan) return 'Run Preview first';
    if (writable === 0 && deletable === 0) return 'Every generated file is already up to date';
    return [
        writable > 0 && 'Write the new and changed files and save .dataverse-gen.json',
        deletable > 0 && `${writable > 0 ? 'then delete' : 'Delete'} the orphaned files (asks for confirmation first)`,
    ]
        .filter(Boolean)
        .join(', ');
}

export interface IPreviewActionBarProps {
    plan: WritePlan | null;
    stale: boolean;
    canPreview: boolean;
    needsProject: boolean;
    busy: boolean;
    previewedAt: string | null;
    /** How many files Generate writes. */
    writable: number;
    deleteOrphans: boolean;
    onDeleteOrphansChange: (checked: boolean) => void;
    skipDuplicates: boolean;
    /** The switch is hidden without it. */
    onSkipDuplicatesChange?: (checked: boolean) => void;
    renameDuplicates?: boolean;
    /** The switch is hidden without it. */
    onRenameDuplicatesChange?: (checked: boolean) => void;
    onPreview: () => void;
    onGenerate: () => void;
    now?: number;
}

/** Preview and Generate, the Delete orphaned files, Rename and Skip duplicated identifier(s) switches, and hints. */
export function PreviewActionBar(props: IPreviewActionBarProps) {
    const { plan, stale, canPreview, needsProject, busy, previewedAt, writable, deleteOrphans, onDeleteOrphansChange, skipDuplicates, onPreview, onGenerate } = props;
    const styles = usePreviewCardStyles();
    const deletable = plan && deleteOrphans ? plan.counts.orphaned : 0;
    return (
        <div className={styles.actionBar}>
            <Button icon={<DocumentSearchRegular />} disabled={!canPreview || busy} onClick={onPreview}>
                Preview
            </Button>
            <Tooltip content={generateHelp(plan, writable, deletable)} relationship="description" withArrow>
                <Button appearance="primary" icon={<SaveRegular />} disabled={!plan || stale || busy || writable + deletable === 0} onClick={onGenerate}>
                    {generateLabel(plan, writable, deletable)}
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
                    label={infoLabel(SKIP_DUPLICATES_TITLE, switchInfo(SKIP_DUPLICATES_INFO, !!plan, plan?.counts.duplicate ?? 0, 'files with duplicate identifiers'))}
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
    );
}

export interface IStatusTilesProps {
    plan: WritePlan;
    /** The status the list is filtered to, or `null`. */
    selectedStatus: FileStatus | null;
    onToggleStatus: (status: FileStatus) => void;
}

/** One tile per status with its count; clicking a tile filters the list to it, clicking it again shows all changes. */
export function StatusTiles({ plan, selectedStatus, onToggleStatus }: IStatusTilesProps) {
    const styles = usePreviewCardStyles();
    return (
        <div className={styles.tiles} role="group" aria-label="Filter by status">
            {/* The duplicate identifiers tile only appears when there are some. */}
            {STATUS_ORDER.filter((status) => status !== 'duplicate' || plan.counts.duplicate > 0).map((status) => {
                const pressed = selectedStatus === status;
                return (
                    <Tooltip key={status} content={`${STATUS_META[status].meaning} Click to ${pressed ? 'show all changes' : 'show only these'}.`} relationship="description" withArrow>
                        <button
                            type="button"
                            className={mergeClasses(styles.tile, styles[STATUS_ACCENT[status]], pressed && styles.tileSelected)}
                            aria-pressed={pressed}
                            onClick={() => onToggleStatus(status)}
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
    );
}

export interface IFileTableProps {
    /** The files to list, already filtered and sorted. */
    files: PlannedFile[];
    selectedPath: string | null;
    onSelect: (relativePath: string) => void;
    /** The sort direction of `column`, or `undefined` when it isn't the sorted column. */
    sortDirection: (column: FileSortColumn) => SortDirection | undefined;
    onToggleSort: (column: FileSortColumn) => void;
}

/** The sortable file table: name (with type icon), type and status; a row selects its file for the viewer. */
export function FileTable({ files, selectedPath, onSelect, sortDirection, onToggleSort }: IFileTableProps) {
    const styles = usePreviewCardStyles();
    const tableStyles = useSortableTableStyles();
    const tableRef = useRef<HTMLTableElement>(null);

    /** ↑/↓ move the selection to the neighbouring row and focus it. */
    const onRowKeyDown = (e: KeyboardEvent, index: number) => {
        if (activateRowOnKey(e, () => onSelect(files[index].relativePath))) return;
        const target = e.key === 'ArrowDown' ? index + 1 : e.key === 'ArrowUp' ? index - 1 : -1;
        if (target >= 0 && target < files.length) {
            e.preventDefault();
            onSelect(files[target].relativePath);
            tableRef.current?.querySelectorAll<HTMLElement>('tbody tr')[target]?.focus();
        }
    };

    return (
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
                        <SortableHeaderCell key={column} help={HEADER_HELP[column]} className={widthClass} sortDirection={sortDirection(column)} onClick={() => onToggleSort(column)}>
                            {label}
                        </SortableHeaderCell>
                    ))}
                </TableRow>
            </TableHeader>
            <TableBody>
                {files.map((file, index) => {
                    const isSelected = file.relativePath === selectedPath;
                    const type = fileType(file.relativePath);
                    return (
                        <TableRow
                            key={file.relativePath}
                            className={tableStyles.row}
                            aria-selected={isSelected}
                            appearance={isSelected ? 'brand' : 'none'}
                            tabIndex={0}
                            onClick={() => onSelect(file.relativePath)}
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
                                    <span className={mergeClasses(styles.dot, styles[STATUS_DOT[file.status]])} aria-hidden="true" />
                                    {STATUS_META[file.status].label.toLowerCase()}
                                </span>
                            </TableCell>
                        </TableRow>
                    );
                })}
            </TableBody>
        </Table>
    );
}
