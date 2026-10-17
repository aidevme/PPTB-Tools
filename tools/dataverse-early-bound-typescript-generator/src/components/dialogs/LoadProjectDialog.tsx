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
} from '@fluentui/react-components';
import { DeleteRegular, EditRegular } from '@fluentui/react-icons';
import type { ProjectEntry } from '../../config';
import { useLoadProjectDialogStyles, useSortableTableStyles } from '../../styles';
import { SortableHeaderCell } from '../shared/SortableHeaderCell';
import { formatDateTime } from '../shared/format';
import { nextSort } from '../shared/sorting';
import { activateRowOnKey } from '../shared/tableRows';
import { ConfirmationDialog } from './ConfirmationDialog';
import { DEFAULT_PROJECT_SORT, PROJECT_COLUMNS, sortProjects, type ProjectColumnKey } from './projectColumns';
import { NewProjectDialog, type NewProject } from './NewProjectDialog';
import { reportError } from '../../services';

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
    /**
     * Saves the name, description and location edited for the project. The edit dialog closes when it resolves
     * and shows the error when it rejects.
     */
    onEdit: (project: ProjectEntry, changes: NewProject) => Promise<void>;
    /** Opens the folder picker for the edited Location; resolves to the chosen folder, or `null` when cancelled. */
    onBrowseLocation: (current: string) => Promise<string | null>;
}

/**
 * Modal dialog listing the saved projects in a table with single-row selection. Load opens the selected
 * project; clicking a project's name opens it directly. Each row can be edited or deleted.
 */
export function LoadProjectDialog({ open, onOpenChange, projects, onLoad, onDelete, onEdit, onBrowseLocation }: ILoadProjectDialogProps) {
    const styles = useLoadProjectDialogStyles();
    const tableStyles = useSortableTableStyles();
    const [selectedId, setSelectedId] = useState<string>('');
    const [loading, setLoading] = useState(false);
    const [loadError, setLoadError] = useState<string | null>(null);
    /** The project waiting for the user to confirm its deletion. */
    const [pendingDelete, setPendingDelete] = useState<ProjectEntry | null>(null);
    const [deleting, setDeleting] = useState(false);
    /** The project open in the edit dialog. */
    const [editing, setEditing] = useState<ProjectEntry | null>(null);
    const [sort, setSort] = useState(DEFAULT_PROJECT_SORT);

    const sorted = useMemo(() => sortProjects(projects, sort), [projects, sort]);

    const toggleSort = (column: ProjectColumnKey) => setSort((current) => nextSort(current, column));
    const selected = projects.find((p) => p.id === selectedId);

    // Start every visit with nothing selected.
    useEffect(() => {
        if (open) {
            setSelectedId('');
            setLoadError(null);
            setSort(DEFAULT_PROJECT_SORT);
            setPendingDelete(null);
            setEditing(null);
        }
    }, [open]);

    const load = async (project: ProjectEntry) => {
        setSelectedId(project.id);
        setLoading(true);
        setLoadError(null);
        try {
            if (await onLoad(project)) onOpenChange(false);
        } catch (error) {
            setLoadError(reportError(`Could not open ${project.name}`, error, undefined, { notify: false }));
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
            setLoadError(reportError(`Could not delete ${project.name}`, error, undefined, { notify: false }));
        } finally {
            setDeleting(false);
            setPendingDelete(null);
        }
    };

    const busy = loading || deleting;

    const select = (project: ProjectEntry) => {
        if (!loading) setSelectedId(project.id);
    };

    // The confirmation and edit dialogs are siblings, not children: a Dialog with two children treats the first as its
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
                                                {PROJECT_COLUMNS.map((column) => (
                                                    <SortableHeaderCell
                                                        key={column.key}
                                                        sortDirection={sort.column === column.key ? sort.direction : undefined}
                                                        onClick={() => toggleSort(column.key)}
                                                    >
                                                        {column.label}
                                                    </SortableHeaderCell>
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
                                                        className={tableStyles.row}
                                                        aria-selected={isSelected}
                                                        appearance={isSelected ? 'brand' : 'none'}
                                                        tabIndex={0}
                                                        onClick={() => select(project)}
                                                        onKeyDown={(e) => activateRowOnKey(e, () => select(project))}
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
                                                            {project.description ? (
                                                                <Tooltip
                                                                    content={{ children: project.description, className: styles.descriptionTooltip }}
                                                                    relationship="description"
                                                                    withArrow
                                                                >
                                                                    <TableCellLayout truncate>{project.description}</TableCellLayout>
                                                                </Tooltip>
                                                            ) : (
                                                                <TableCellLayout truncate>
                                                                    <span className={styles.muted}>—</span>
                                                                </TableCellLayout>
                                                            )}
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
                                                            <Tooltip content="Edit project" relationship="label" withArrow>
                                                                <Button
                                                                    appearance="subtle"
                                                                    icon={<EditRegular />}
                                                                    aria-label={`Edit ${project.name}`}
                                                                    disabled={busy}
                                                                    onClick={(e) => {
                                                                        e.stopPropagation();
                                                                        setEditing(project);
                                                                    }}
                                                                    onKeyDown={(e) => e.stopPropagation()}
                                                                />
                                                            </Tooltip>
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
            <ConfirmationDialog
                open={pendingDelete !== null}
                title="Delete project?"
                message={`${pendingDelete?.name ?? ''} will be removed from your saved projects. Files in ${pendingDelete?.location ?? ''} aren't touched.`}
                confirmLabel="Delete"
                busyLabel="Deleting…"
                confirmIcon={<DeleteRegular />}
                busy={deleting}
                onConfirm={() => void confirmDelete()}
                onCancel={() => setPendingDelete(null)}
            />
            <NewProjectDialog
                open={editing !== null}
                onOpenChange={(isOpen) => !isOpen && setEditing(null)}
                project={editing ?? undefined}
                existingNames={projects.filter((p) => p.id !== editing?.id).map((p) => p.name)}
                onBrowseLocation={onBrowseLocation}
                onSave={(changes) => (editing ? onEdit(editing, changes) : Promise.resolve())}
            />
        </>
    );
}
