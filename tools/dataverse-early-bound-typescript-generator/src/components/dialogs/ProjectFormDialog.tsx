import { useState } from 'react';
import {
    Button,
    Caption1,
    Dialog,
    DialogActions,
    DialogBody,
    DialogContent,
    DialogSurface,
    DialogTitle,
    DialogTrigger,
    Field,
    Input,
    MessageBar,
    MessageBarBody,
    Textarea,
} from '@fluentui/react-components';
import { AddRegular, CopyRegular, DismissRegular, EditRegular, FolderAddRegular, FolderOpenRegular, FolderRegular, HistoryRegular, RenameRegular, SaveRegular } from '@fluentui/react-icons';
import type { ProjectEntry } from '../../config';
import { useAsyncAction } from '../../hooks';
import { useProjectFormDialogStyles } from '../../styles';
import { reportError } from '../../services';
import { formatDateTime } from '../shared/format';

/** The values the dialog collects; the id and creation time are added when saving. */
export type NewProject = Pick<ProjectEntry, 'name' | 'description' | 'location'>;

/** Props for {@link ProjectFormDialog}. */
export interface IProjectFormDialogProps {
    /** Shows the dialog; each time it opens, the form starts empty or with `project`'s values. */
    open: boolean;
    /**
     * Called with `false` when the dialog asks to close (Cancel, Escape, or after a successful save); not called
     * while saving.
     */
    onOpenChange: (open: boolean) => void;
    /** Names of the other saved projects; the project can't reuse one (case-insensitive). */
    existingNames: string[];
    /** The saved project to edit. Omitted for a new project. */
    project?: ProjectEntry;
    /**
     * The saved project to copy, when `project` isn't set: the form starts with its description and location and a
     * name that isn't used yet (see {@link copyName}), and Save creates a new project.
     */
    copyOf?: ProjectEntry;
    /** Opens the folder picker for Location; resolves to the chosen folder, or `null` when cancelled. */
    onBrowseLocation: (current: string) => Promise<string | null>;
    /** Saves the project. The dialog closes when it resolves and shows the error when it rejects. */
    onSave: (project: NewProject) => Promise<void>;
}

/**
 * A name for a copy of the project named `name` that none of `existingNames` uses (ignoring case and surrounding
 * spaces): `<name> (copy)`, then `<name> (copy 2)`, `<name> (copy 3)` and so on.
 *
 * @param name - The copied project's name.
 * @param existingNames - The names already in use.
 * @returns The first free name.
 */
export function copyName(name: string, existingNames: readonly string[]): string {
    const taken = new Set(existingNames.map((n) => n.trim().toLowerCase()));
    const base = name.trim();
    for (let n = 1; ; n++) {
        const candidate = n === 1 ? `${base} (copy)` : `${base} (copy ${n})`;
        if (!taken.has(candidate.toLowerCase())) return candidate;
    }
}

/**
 * Modal dialog for a project's name, description and location, saved with Save. Creates a new project, edits
 * `project` when one is given, or creates a copy of `copyOf` (filled in from it, with a free name).
 *
 * @remarks
 * The title has an icon (a folder with a plus, a pencil when editing, two pages when copying), a subtitle saying what
 * the dialog does, and
 * a close button. The name and location inputs have icons and the location is monospace; when editing, a strip
 * under the fields shows the project's version, created and modified dates, which the dialog doesn't change.
 */
export function ProjectFormDialog({ open, onOpenChange, existingNames, project, copyOf, onBrowseLocation, onSave }: IProjectFormDialogProps) {
    const styles = useProjectFormDialogStyles();
    const [name, setName] = useState('');
    const [description, setDescription] = useState('');
    const [location, setLocation] = useState('');
    const [saveError, setSaveError] = useState<string | null>(null);
    const saveAction = useAsyncAction(setSaveError);
    const saving = saveAction.busy;

    const copy = project ? undefined : copyOf;
    // Start every visit with an empty form, or with the edited or copied project's values. Reset while rendering, when
    // `open`, `project` or `copyOf` changes, so the first frame never shows the previous visit's values (no reset effect).
    const [visit, setVisit] = useState<{ open: boolean; project: ProjectEntry | undefined; copy: ProjectEntry | undefined } | null>(null);
    if (!visit || visit.open !== open || visit.project !== project || visit.copy !== copy) {
        setVisit({ open, project, copy });
        if (open) {
            const source = project ?? copy;
            setName(project?.name ?? (copy ? copyName(copy.name, existingNames) : ''));
            setDescription(source?.description ?? '');
            setLocation(source?.location ?? '');
            setSaveError(null);
        }
    }

    const trimmedName = name.trim();
    const duplicate = trimmedName !== '' && existingNames.some((n) => n.trim().toLowerCase() === trimmedName.toLowerCase());
    const valid = trimmedName !== '' && !duplicate && location.trim() !== '';

    const browse = async () => {
        try {
            const folder = await onBrowseLocation(location);
            if (folder) setLocation(folder);
        } catch (error) {
            setSaveError(reportError(`Could not open the folder picker`, error, undefined, { notify: false }));
        }
    };

    const save = () =>
        saveAction.run(`Could not save the project`, async () => {
            await onSave({ name: trimmedName, description: description.trim(), location: location.trim() });
            onOpenChange(false);
        });

    return (
        <Dialog open={open} onOpenChange={(_, data) => !saving && onOpenChange(data.open)}>
            <DialogSurface className={styles.surface}>
                <DialogBody>
                    <DialogTitle
                        action={
                            <DialogTrigger action="close">
                                <Button appearance="subtle" aria-label="Close" icon={<DismissRegular />} disabled={saving} />
                            </DialogTrigger>
                        }
                    >
                        <span className={styles.titleRow}>
                            <span className={styles.titleIcon} aria-hidden="true">
                                {project ? <EditRegular /> : copy ? <CopyRegular /> : <FolderAddRegular />}
                            </span>
                            <span className={styles.titleText}>
                                {project ? 'Edit project' : copy ? 'Copy project' : 'New project'}
                                <Caption1 className={styles.subtitle}>
                                    {project
                                        ? `Change the name, description or folder of ${project.name}.`
                                        : copy
                                          ? `Save a new project from ${copy.name}'s details; change what you need.`
                                          : 'Save a project folder so you can open it again later.'}
                                </Caption1>
                            </span>
                        </span>
                    </DialogTitle>
                    <DialogContent className={styles.form}>
                        <Field
                            label="Project name"
                            required
                            validationState={duplicate ? 'error' : 'none'}
                            validationMessage={duplicate ? 'A project with this name already exists.' : undefined}
                        >
                            <Input
                                value={name}
                                onChange={(_, data) => setName(data.value)}
                                disabled={saving}
                                placeholder="For example Contoso Sales"
                                contentBefore={<RenameRegular className={styles.inputIcon} />}
                            />
                        </Field>
                        <Field label="Description">
                            <Textarea
                                value={description}
                                onChange={(_, data) => setDescription(data.value)}
                                disabled={saving}
                                resize="vertical"
                                placeholder="What the project is for (optional)"
                            />
                        </Field>
                        <Field label="Location" required hint="The folder for the project, usually the one with your package.json.">
                            <div className={styles.location}>
                                <Input
                                    className={styles.locationInput}
                                    input={{ className: styles.locationText }}
                                    value={location}
                                    onChange={(_, data) => setLocation(data.value)}
                                    disabled={saving}
                                    placeholder="C:\repos\my-project"
                                    contentBefore={<FolderRegular className={styles.inputIcon} />}
                                />
                                <Button icon={<FolderOpenRegular />} onClick={() => void browse()} disabled={saving}>
                                    Browse…
                                </Button>
                            </div>
                        </Field>
                        {project && (
                            <div className={styles.details}>
                                <HistoryRegular className={styles.detailsIcon} aria-hidden="true" />
                                <Caption1>
                                    Version <span className={styles.detailsValue}>{project.version}</span> · Created{' '}
                                    <span className={styles.detailsValue}>{formatDateTime(project.createdOn)}</span> · Modified{' '}
                                    <span className={styles.detailsValue}>{formatDateTime(project.modifiedOn)}</span>
                                </Caption1>
                            </div>
                        )}
                        {saveError && (
                            <MessageBar intent="error">
                                <MessageBarBody>{saveError}</MessageBarBody>
                            </MessageBar>
                        )}
                    </DialogContent>
                    <DialogActions>
                        <Button appearance="primary" icon={project ? <SaveRegular /> : <AddRegular />} disabled={!valid || saving} onClick={() => void save()}>
                            {saving ? 'Saving…' : 'Save'}
                        </Button>
                        <Button appearance="secondary" disabled={saving} onClick={() => onOpenChange(false)}>
                            Cancel
                        </Button>
                    </DialogActions>
                </DialogBody>
            </DialogSurface>
        </Dialog>
    );
}

/** @deprecated Renamed to `ProjectFormDialog` (it also edits projects); kept so existing imports keep working. */
export const NewProjectDialog = ProjectFormDialog;
/** @deprecated Renamed to `IProjectFormDialogProps`. */
export type INewProjectDialogProps = IProjectFormDialogProps;
