import { useEffect, useState } from 'react';
import {
    Button,
    Dialog,
    DialogActions,
    DialogBody,
    DialogContent,
    DialogSurface,
    DialogTitle,
    Field,
    Input,
    MessageBar,
    MessageBarBody,
    Textarea,
} from '@fluentui/react-components';
import { FolderOpenRegular } from '@fluentui/react-icons';
import type { ProjectEntry } from '../../config';
import { useNewProjectDialogStyles } from '../../styles';
import { reportError } from '../../services';

/** The values the dialog collects; the id and creation time are added when saving. */
export type NewProject = Pick<ProjectEntry, 'name' | 'description' | 'location'>;

export interface INewProjectDialogProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    /** Names of the other saved projects; the project can't reuse one (case-insensitive). */
    existingNames: string[];
    /** The saved project to edit. Omitted for a new project. */
    project?: ProjectEntry;
    /** Opens the folder picker for Location; resolves to the chosen folder, or `null` when cancelled. */
    onBrowseLocation: (current: string) => Promise<string | null>;
    /** Saves the project. The dialog closes when it resolves and shows the error when it rejects. */
    onSave: (project: NewProject) => Promise<void>;
}

/**
 * Modal dialog for a project's name, description and location, saved with Save. Creates a new project, or edits
 * `project` when one is given.
 */
export function NewProjectDialog({ open, onOpenChange, existingNames, project, onBrowseLocation, onSave }: INewProjectDialogProps) {
    const styles = useNewProjectDialogStyles();
    const [name, setName] = useState('');
    const [description, setDescription] = useState('');
    const [location, setLocation] = useState('');
    const [saving, setSaving] = useState(false);
    const [saveError, setSaveError] = useState<string | null>(null);

    // Start every visit with an empty form, or with the edited project's values.
    useEffect(() => {
        if (open) {
            setName(project?.name ?? '');
            setDescription(project?.description ?? '');
            setLocation(project?.location ?? '');
            setSaveError(null);
        }
    }, [open, project]);

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

    const save = async () => {
        setSaving(true);
        setSaveError(null);
        try {
            await onSave({ name: trimmedName, description: description.trim(), location: location.trim() });
            onOpenChange(false);
        } catch (error) {
            setSaveError(reportError(`Could not save the project`, error, undefined, { notify: false }));
        } finally {
            setSaving(false);
        }
    };

    return (
        <Dialog open={open} onOpenChange={(_, data) => !saving && onOpenChange(data.open)}>
            <DialogSurface>
                <DialogBody>
                    <DialogTitle>{project ? 'Edit project' : 'New project'}</DialogTitle>
                    <DialogContent className={styles.form}>
                        <Field
                            label="Project Name"
                            required
                            validationState={duplicate ? 'error' : 'none'}
                            validationMessage={duplicate ? 'A project with this name already exists.' : undefined}
                        >
                            <Input value={name} onChange={(_, data) => setName(data.value)} disabled={saving} />
                        </Field>
                        <Field label="Description">
                            <Textarea value={description} onChange={(_, data) => setDescription(data.value)} disabled={saving} resize="vertical" />
                        </Field>
                        <Field label="Location" required hint="The folder for the project, usually the one with your package.json.">
                            <div className={styles.location}>
                                <Input
                                    className={styles.locationInput}
                                    value={location}
                                    onChange={(_, data) => setLocation(data.value)}
                                    disabled={saving}
                                />
                                <Button icon={<FolderOpenRegular />} onClick={() => void browse()} disabled={saving}>
                                    Browse…
                                </Button>
                            </div>
                        </Field>
                        {saveError && (
                            <MessageBar intent="error">
                                <MessageBarBody>{saveError}</MessageBarBody>
                            </MessageBar>
                        )}
                    </DialogContent>
                    <DialogActions>
                        <Button appearance="primary" disabled={!valid || saving} onClick={() => void save()}>
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
