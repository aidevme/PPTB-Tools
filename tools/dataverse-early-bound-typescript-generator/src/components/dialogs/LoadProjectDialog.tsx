import { useMemo, useState } from 'react';
import {
    Button,
    Dialog,
    DialogActions,
    DialogBody,
    DialogContent,
    DialogSurface,
    DialogTitle,
    DialogTrigger,
    MessageBar,
    MessageBarBody,
    Text,
    Caption1,
    Toolbar,
    ToolbarButton,
    Tooltip,
} from '@fluentui/react-components';
import { CopyRegular, DeleteRegular, DismissRegular, EditRegular, FolderOpenRegular, FolderSearchRegular } from '@fluentui/react-icons';
import type { ProjectEntry } from '../../config';
import { useAsyncAction } from '../../hooks';
import { useLoadProjectDialogStyles } from '../../styles';
import { nextSort } from '../shared/sorting';
import { ConfirmationDialog } from './ConfirmationDialog';
import { DEFAULT_PROJECT_SORT, sortProjects, type ProjectColumnKey } from '../tables/projectColumns';
import { ProjectsTable } from '../tables/ProjectsTable';
import { ProjectFormDialog, type NewProject } from './ProjectFormDialog';

/** Props for {@link LoadProjectDialog}. */
export interface ILoadProjectDialogProps {
    /** Shows the dialog; each time it opens, the selection, error, sort and any pending delete or edit are reset. */
    open: boolean;
    /**
     * Called with `false` when the dialog asks to close (Cancel, Escape, or after a project is opened); ignored
     * while a project is loading.
     */
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
    /**
     * Saves a copy of a project as a new saved project, with the name, description and location from the copy form.
     * The form closes when it resolves (the copy is then selected) and shows the error when it rejects.
     */
    onCopy: (copy: NewProject) => Promise<void>;
    /** Opens the folder picker for the edited Location; resolves to the chosen folder, or `null` when cancelled. */
    onBrowseLocation: (current: string) => Promise<string | null>;
}

/**
 * Modal dialog listing the saved projects in a table with single-row selection. Load opens the selected
 * project; clicking a project's name opens it directly. The toolbar above the table copies, edits or deletes the
 * selected project; its buttons are disabled until a row is selected, and while a project is opening or being
 * deleted. Copy opens the project form filled in from the selected project, with a name that isn't used yet.
 *
 * @remarks
 * The title has an icon, the number of saved projects, and a close button; the toolbar says which project is
 * selected; with no saved projects, an empty state says to create one with New Project.
 */
export function LoadProjectDialog({ open, onOpenChange, projects, onLoad, onDelete, onEdit, onCopy, onBrowseLocation }: ILoadProjectDialogProps) {
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
    /** The project open in the copy form. */
    const [copying, setCopying] = useState<ProjectEntry | null>(null);
    /** The name of a copy just saved, selected once it shows up in `projects`. */
    const [selectName, setSelectName] = useState<string | null>(null);
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
            setCopying(null);
            setSelectName(null);
        }
    }

    if (selectName) {
        const saved = projects.find((p) => p.name === selectName);
        if (saved) {
            setSelectName(null);
            setSelectedId(saved.id);
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
                        <DialogTitle
                            action={
                                <DialogTrigger action="close">
                                    <Button appearance="subtle" aria-label="Close" icon={<DismissRegular />} disabled={loading} />
                                </DialogTrigger>
                            }
                        >
                            <span className={styles.titleRow}>
                                <span className={styles.titleIcon} aria-hidden="true">
                                    <FolderOpenRegular />
                                </span>
                                <span className={styles.titleText}>
                                    Load Existing Project
                                    <Caption1 className={styles.subtitle}>
                                        {projects.length === 0 ? 'No saved projects' : `${projects.length} saved project${projects.length === 1 ? '' : 's'}`}
                                    </Caption1>
                                </span>
                            </span>
                        </DialogTitle>
                        <DialogContent className={styles.content}>
                            {sorted.length === 0 ? (
                                <div className={styles.empty}>
                                    <FolderSearchRegular className={styles.emptyIcon} aria-hidden="true" />
                                    <Text weight="semibold">No saved projects yet</Text>
                                    <Text className={styles.muted}>Create one with New Project, and it shows up here.</Text>
                                </div>
                            ) : (
                                <>
                                    <Toolbar aria-label="Project actions" size="small" className={styles.toolbar}>
                                        <Tooltip content={selected ? `Copy ${selected.name}` : 'Select a project to copy it'} relationship="description" withArrow>
                                            <ToolbarButton icon={<CopyRegular />} disabled={!selected || busy} onClick={() => selected && setCopying(selected)}>
                                                Copy
                                            </ToolbarButton>
                                        </Tooltip>
                                        <Tooltip content={selected ? `Edit ${selected.name}` : 'Select a project to edit it'} relationship="description" withArrow>
                                            <ToolbarButton icon={<EditRegular />} disabled={!selected || busy} onClick={() => selected && setEditing(selected)}>
                                                Edit
                                            </ToolbarButton>
                                        </Tooltip>
                                        <Tooltip content={selected ? `Delete ${selected.name}` : 'Select a project to delete it'} relationship="description" withArrow>
                                            <ToolbarButton icon={<DeleteRegular />} disabled={!selected || busy} onClick={() => selected && setPendingDelete(selected)}>
                                                Delete
                                            </ToolbarButton>
                                        </Tooltip>
                                        <Caption1 className={styles.selection} aria-live="polite">
                                            {selected ? (
                                                <>
                                                    Selected: <span className={styles.selectionName}>{selected.name}</span>
                                                </>
                                            ) : (
                                                'Select a project to load, copy, edit or delete it'
                                            )}
                                        </Caption1>
                                    </Toolbar>
                                    <div className={styles.tableWrapper}>
                                        <ProjectsTable
                                            projects={sorted}
                                            sort={sort}
                                            onToggleSort={toggleSort}
                                            selectedId={selectedId}
                                            onSelect={select}
                                            onLoad={(project) => void load(project)}
                                            loading={loading}
                                        />
                                    </div>
                                </>
                            )}
                            {loadError && (
                                <MessageBar intent="error">
                                    <MessageBarBody>{loadError}</MessageBarBody>
                                </MessageBar>
                            )}
                        </DialogContent>
                        <DialogActions>
                            <Button appearance="primary" icon={<FolderOpenRegular />} disabled={!selected || loading} onClick={() => selected && void load(selected)}>
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
            <ProjectFormDialog
                open={editing !== null}
                onOpenChange={(isOpen) => !isOpen && setEditing(null)}
                project={editing ?? undefined}
                existingNames={projects.filter((p) => p.id !== editing?.id).map((p) => p.name)}
                onBrowseLocation={onBrowseLocation}
                onSave={(changes) => (editing ? onEdit(editing, changes) : Promise.resolve())}
            />
            <ProjectFormDialog
                open={copying !== null}
                onOpenChange={(isOpen) => !isOpen && setCopying(null)}
                copyOf={copying ?? undefined}
                existingNames={projects.map((p) => p.name)}
                onBrowseLocation={onBrowseLocation}
                onSave={async (copy) => {
                    await onCopy(copy);
                    setSelectName(copy.name);
                }}
            />
        </>
    );
}
