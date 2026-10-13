import { useEffect, useMemo, useState } from 'react';
import {
    Button,
    Dialog,
    DialogActions,
    DialogBody,
    DialogContent,
    DialogSurface,
    DialogTitle,
    Link,
    MessageBar,
    MessageBarBody,
    Table,
    TableBody,
    TableCell,
    TableCellLayout,
    TableHeader,
    TableHeaderCell,
    TableRow,
    TableSelectionCell,
    Text,
    Tooltip,
    makeStyles,
    tokens,
    type SortDirection,
} from '@fluentui/react-components';
import { DeleteRegular } from '@fluentui/react-icons';
import type { ProjectEntry } from '../../config';

const useStyles = makeStyles({
    surface: { maxWidth: '1000px', width: '90vw' },
    tableWrapper: {
        maxHeight: '360px',
        overflow: 'auto',
        border: `1px solid ${tokens.colorNeutralStroke2}`,
        borderRadius: tokens.borderRadiusMedium,
    },
    row: { cursor: 'pointer' },
    headerCell: { fontWeight: tokens.fontWeightSemibold },
    actionsCell: { width: '48px' },
    path: { fontFamily: tokens.fontFamilyMonospace, fontSize: tokens.fontSizeBase200, wordBreak: 'break-all' },
    muted: { color: tokens.colorNeutralForeground3 },
    empty: { color: tokens.colorNeutralForeground3 },
});

export interface ILoadProjectDialogProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    /** Projects saved with the New Project dialog. */
    projects: ProjectEntry[];
    /**
     * Opens the chosen project. Resolves to `true` once it's being opened (the dialog closes), `false` when the
     * user cancelled (the dialog stays open), and rejects with an error to show.
     */
    onLoad: (project: ProjectEntry) => Promise<boolean>;
    /**
     * Removes the project from the saved list (its files are left alone). Called after the user confirms;
     * a rejection is shown as an error.
     */
    onDelete: (project: ProjectEntry) => Promise<void>;
}

function formatDateTime(iso: string): string {
    const date = new Date(iso);
    return Number.isNaN(date.getTime()) ? iso : date.toLocaleString(undefined, { dateStyle: 'short', timeStyle: 'short' });
}

type ColumnKey = 'name' | 'description' | 'version' | 'location' | 'createdOn' | 'modifiedOn';

const textCompare = (a: string, b: string) => a.localeCompare(b, undefined, { sensitivity: 'base', numeric: true });

/** `1.0.10` sorts after `1.0.9`; anything that isn't dotted numbers falls back to text order. */
function compareVersions(a: string, b: string): number {
    const parse = (v: string) => (/^\d+(\.\d+)*$/.test(v.trim()) ? v.trim().split('.').map(Number) : undefined);
    const pa = parse(a);
    const pb = parse(b);
    if (!pa || !pb) return textCompare(a, b);
    for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
        const diff = (pa[i] ?? 0) - (pb[i] ?? 0);
        if (diff !== 0) return diff;
    }
    return 0;
}

const compareDates = (a: string, b: string) => (Date.parse(a) || 0) - (Date.parse(b) || 0);

const COLUMNS: Array<{ key: ColumnKey; label: string; compare: (a: ProjectEntry, b: ProjectEntry) => number }> = [
    { key: 'name', label: 'Name', compare: (a, b) => textCompare(a.name, b.name) },
    { key: 'description', label: 'Description', compare: (a, b) => textCompare(a.description, b.description) },
    { key: 'version', label: 'Version', compare: (a, b) => compareVersions(a.version, b.version) },
    { key: 'location', label: 'Location', compare: (a, b) => textCompare(a.location, b.location) },
    { key: 'createdOn', label: 'Created On', compare: (a, b) => compareDates(a.createdOn, b.createdOn) },
    { key: 'modifiedOn', label: 'Modified On', compare: (a, b) => compareDates(a.modifiedOn, b.modifiedOn) },
];

const DEFAULT_SORT: { column: ColumnKey; direction: SortDirection } = { column: 'name', direction: 'ascending' };

/**
 * Modal dialog listing the saved projects in a table with single-row selection. Load opens the selected
 * project; clicking a project's name opens it directly.
 */
export function LoadProjectDialog({ open, onOpenChange, projects, onLoad, onDelete }: ILoadProjectDialogProps) {
    const styles = useStyles();
    const [selectedId, setSelectedId] = useState<string>('');
    const [loading, setLoading] = useState(false);
    const [loadError, setLoadError] = useState<string | null>(null);
    /** The project waiting for the user to confirm its deletion. */
    const [pendingDelete, setPendingDelete] = useState<ProjectEntry | null>(null);
    const [deleting, setDeleting] = useState(false);
    const [sort, setSort] = useState(DEFAULT_SORT);

    const sorted = useMemo(() => {
        const column = COLUMNS.find((c) => c.key === sort.column) ?? COLUMNS[0];
        const sign = sort.direction === 'ascending' ? 1 : -1;
        // Ties keep name order, so equal versions or dates still list predictably.
        return [...projects].sort((a, b) => sign * column.compare(a, b) || textCompare(a.name, b.name));
    }, [projects, sort]);

    /** First click on a column sorts ascending; clicking the sorted column again flips the direction. */
    const toggleSort = (column: ColumnKey) =>
        setSort((current) =>
            current.column === column ? { column, direction: current.direction === 'ascending' ? 'descending' : 'ascending' } : { column, direction: 'ascending' },
        );
    const selected = projects.find((p) => p.id === selectedId);

    // Start every visit with nothing selected.
    useEffect(() => {
        if (open) {
            setSelectedId('');
            setLoadError(null);
            setSort(DEFAULT_SORT);
            setPendingDelete(null);
        }
    }, [open]);

    const load = async (project: ProjectEntry) => {
        setSelectedId(project.id);
        setLoading(true);
        setLoadError(null);
        try {
            if (await onLoad(project)) onOpenChange(false);
        } catch (error) {
            setLoadError(`Could not open ${project.name}: ${error instanceof Error ? error.message : String(error)}`);
        } finally {
            setLoading(false);
        }
    };

    const confirmDelete = async () => {
        if (!pendingDelete) return;
        const project = pendingDelete;
        setDeleting(true);
        setLoadError(null);
        try {
            await onDelete(project);
            if (selectedId === project.id) setSelectedId('');
        } catch (error) {
            setLoadError(`Could not delete ${project.name}: ${error instanceof Error ? error.message : String(error)}`);
        } finally {
            setDeleting(false);
            setPendingDelete(null);
        }
    };

    const busy = loading || deleting;

    const select = (project: ProjectEntry) => {
        if (!loading) setSelectedId(project.id);
    };

    // The confirmation dialog is a sibling, not a child: a Dialog with two children treats the first as its
    // trigger, which would keep the main surface on screen regardless of `open`.
    return (
        <>
            <Dialog open={open} onOpenChange={(_, data) => !loading && onOpenChange(data.open)}>
                <DialogSurface className={styles.surface}>
                    <DialogBody>
                        <DialogTitle>Load existing project</DialogTitle>
                        <DialogContent>
                            {sorted.length === 0 ? (
                                <Text className={styles.empty}>No saved projects yet. Create one with New Project.</Text>
                            ) : (
                                <div className={styles.tableWrapper}>
                                    <Table aria-label="Saved projects" size="small" sortable>
                                        <TableHeader>
                                            <TableRow>
                                                <TableSelectionCell type="radio" invisible />
                                                {COLUMNS.map((column) => (
                                                    <TableHeaderCell
                                                        key={column.key}
                                                        className={styles.headerCell}
                                                        sortDirection={sort.column === column.key ? sort.direction : undefined}
                                                        onClick={() => toggleSort(column.key)}
                                                    >
                                                        {column.label}
                                                    </TableHeaderCell>
                                                ))}
                                                <TableHeaderCell className={styles.actionsCell} aria-label="Actions" />
                                            </TableRow>
                                        </TableHeader>
                                        <TableBody>
                                            {sorted.map((project) => {
                                                const isSelected = project.id === selectedId;
                                                return (
                                                    <TableRow
                                                        key={project.id}
                                                        className={styles.row}
                                                        aria-selected={isSelected}
                                                        appearance={isSelected ? 'brand' : 'none'}
                                                        tabIndex={0}
                                                        onClick={() => select(project)}
                                                        onKeyDown={(e) => {
                                                            if (e.key === ' ' || e.key === 'Enter') {
                                                                e.preventDefault();
                                                                select(project);
                                                            }
                                                        }}
                                                    >
                                                        <TableSelectionCell
                                                            type="radio"
                                                            checked={isSelected}
                                                            checkboxIndicator={{ 'aria-label': `Select ${project.name}` }}
                                                            radioIndicator={{ 'aria-label': `Select ${project.name}` }}
                                                        />
                                                        <TableCell>
                                                            <TableCellLayout truncate>
                                                                <Link
                                                                    disabled={loading}
                                                                    onClick={(e) => {
                                                                        e.stopPropagation();
                                                                        void load(project);
                                                                    }}
                                                                >
                                                                    {project.name}
                                                                </Link>
                                                            </TableCellLayout>
                                                        </TableCell>
                                                        <TableCell>
                                                            <TableCellLayout truncate>
                                                                {project.description || <span className={styles.muted}>—</span>}
                                                            </TableCellLayout>
                                                        </TableCell>
                                                        <TableCell>{project.version}</TableCell>
                                                        <TableCell>
                                                            <span className={styles.path} title={project.location}>
                                                                {project.location}
                                                            </span>
                                                        </TableCell>
                                                        <TableCell>{formatDateTime(project.createdOn)}</TableCell>
                                                        <TableCell>{formatDateTime(project.modifiedOn)}</TableCell>
                                                        <TableCell className={styles.actionsCell}>
                                                            <Tooltip content="Delete project" relationship="label" withArrow>
                                                                <Button
                                                                    appearance="subtle"
                                                                    icon={<DeleteRegular />}
                                                                    aria-label={`Delete ${project.name}`}
                                                                    disabled={busy}
                                                                    onClick={(e) => {
                                                                        e.stopPropagation();
                                                                        setPendingDelete(project);
                                                                    }}
                                                                    onKeyDown={(e) => e.stopPropagation()}
                                                                />
                                                            </Tooltip>
                                                        </TableCell>
                                                    </TableRow>
                                                );
                                            })}
                                        </TableBody>
                                    </Table>
                                </div>
                            )}
                            {loadError && (
                                <MessageBar intent="error">
                                    <MessageBarBody>{loadError}</MessageBarBody>
                                </MessageBar>
                            )}
                        </DialogContent>
                        <DialogActions>
                            <Button appearance="primary" disabled={!selected || loading} onClick={() => selected && void load(selected)}>
                                {loading ? 'Loading…' : 'Load'}
                            </Button>
                            <Button appearance="secondary" disabled={loading} onClick={() => onOpenChange(false)}>
                                Cancel
                            </Button>
                        </DialogActions>
                    </DialogBody>
                </DialogSurface>
            </Dialog>
            <Dialog open={pendingDelete !== null} onOpenChange={(_, data) => !data.open && !deleting && setPendingDelete(null)}>
                <DialogSurface>
                    <DialogBody>
                        <DialogTitle>Delete project?</DialogTitle>
                        <DialogContent>
                            <Text>
                                {pendingDelete?.name} will be removed from your saved projects. Files in {pendingDelete?.location} aren't
                                touched.
                            </Text>
                        </DialogContent>
                        <DialogActions>
                            <Button appearance="primary" icon={<DeleteRegular />} disabled={deleting} onClick={() => void confirmDelete()}>
                                {deleting ? 'Deleting…' : 'Delete'}
                            </Button>
                            <Button appearance="secondary" disabled={deleting} onClick={() => setPendingDelete(null)}>
                                Cancel
                            </Button>
                        </DialogActions>
                    </DialogBody>
                </DialogSurface>
            </Dialog>
        </>
    );
}
