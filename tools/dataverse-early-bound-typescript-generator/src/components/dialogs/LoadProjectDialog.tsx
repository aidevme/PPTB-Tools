import { useMemo, useState } from 'react';
import { Button, Dialog, DialogActions, DialogBody, DialogContent, DialogSurface, DialogTitle, MessageBar, MessageBarBody, Text } from '@fluentui/react-components';
import { DeleteRegular } from '@fluentui/react-icons';
import type { ProjectEntry } from '../../config';
import { useAsyncAction } from '../../hooks';
import { useLoadProjectDialogStyles } from '../../styles';
import { nextSort } from '../shared/sorting';
import { ConfirmationDialog } from './ConfirmationDialog';
import { DEFAULT_PROJECT_SORT, sortProjects, type ProjectColumnKey } from './projectColumns';
import { ProjectsTable } from './ProjectsTable';
import { NewProjectDialog, type NewProject } from './NewProjectDialog';

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
    const [selectedId, setSelectedId] = useState<string>('');
    const [loadError, setLoadError] = useState<string | null>(null);
    const opening = useAsyncAction(setLoadError);
    const deletion = useAsyncAction(setLoadError);
    const loading = opening.busy;
    const deleting = deletion.busy;
    /** The project waiting for the user to confirm its deletion. */
    const [pendingDelete, setPendingDelete] = useState<ProjectEntry | null>(null);
    /** The project open in the edit dialog. */
    const [editing, setEditing] = useState<ProjectEntry | null>(null);
    const [sort, setSort] = useState(DEFAULT_PROJECT_SORT);

    const sorted = useMemo(() => sortProjects(projects, sort), [projects, sort]);

    const toggleSort = (column: ProjectColumnKey) => setSort((current) => nextSort(current, column));
    const selected = projects.find((p) => p.id === selectedId);

    // Start every visit with nothing selected. Reset while rendering when `open` changes, so the first frame never
    // shows the previous visit's selection (no reset effect).
    const [wasOpen, setWasOpen] = useState(open);
    if (open !== wasOpen) {
        setWasOpen(open);
        if (open) {
            setSelectedId('');
            setLoadError(null);
            setSort(DEFAULT_PROJECT_SORT);
            setPendingDelete(null);
            setEditing(null);
        }
    }

    const load = async (project: ProjectEntry) => {
        setSelectedId(project.id);
        await opening.run(`Could not open ${project.name}`, async () => {
            if (await onLoad(project)) onOpenChange(false);
        });
    };

    const confirmDelete = async () => {
        if (!pendingDelete) return;
        const project = pendingDelete;
        await deletion.run(`Could not delete ${project.name}`, async () => {
            await onDelete(project);
            if (selectedId === project.id) setSelectedId('');
        });
        setPendingDelete(null);
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
                                    <ProjectsTable
                                        projects={sorted}
                                        sort={sort}
                                        onToggleSort={toggleSort}
                                        selectedId={selectedId}
                                        onSelect={select}
                                        onLoad={(project) => void load(project)}
                                        onEdit={setEditing}
                                        onDelete={setPendingDelete}
                                        loading={loading}
                                        busy={busy}
                                    />
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
