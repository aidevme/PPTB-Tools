import { useCallback, useEffect, useState } from 'react';
import type { NewProject } from '../components';
import { DEFAULT_PROJECT_VERSION, mergeToolConfig, recordGeneration, toolConfig, type ProjectEntry, type ToolConfig } from '../config';
import { isSamePath, loadToolConfig, reportError, saveToolConfig, writeStatusOf } from '../services';
import type { WritePlan } from '../types';

/** The tool-config switches the Preview card changes directly. */
export type PreviewSettingKey = 'deleteOrphanedFiles' | 'skipDuplicateIdentifiers' | 'renameDuplicateIdentifiers';

export interface UseToolSettingsOptions {
    /** Shows an error in the page (the error bar). */
    onError: (message: string) => void;
    /** Called when a saved setting makes the current preview out of date. */
    onPlanStale: () => void;
}

/**
 * The tool config: Settings-panel values and saved projects. Holds the bundled defaults until the saved values
 * have loaded, and saves every change through PPTB's settings.
 */
export function useToolSettings({ onError, onPlanStale }: UseToolSettingsOptions) {
    const [toolSettings, setToolSettings] = useState<ToolConfig>(toolConfig);

    useEffect(() => {
        let cancelled = false;
        void loadToolConfig().then((loaded) => !cancelled && setToolSettings(loaded));
        return () => {
            cancelled = true;
        };
    }, []);

    /** Saves the Settings-panel values; the panel stays open and shows the error if saving fails. */
    const saveToolSettings = useCallback(
        async (draft: ToolConfig) => {
            // Same normalization as on load, so e.g. a blank output folder saves as the default, not as "".
            const next = mergeToolConfig(draft);
            await saveToolConfig(next);
            setToolSettings(next);
            // Renaming duplicates changes the generated files, so the current preview no longer matches.
            if (next.renameDuplicateIdentifiers !== toolSettings.renameDuplicateIdentifiers) onPlanStale();
        },
        [toolSettings.renameDuplicateIdentifiers, onPlanStale],
    );

    /** Adds a project from the New Project dialog to `projects` and saves the config. Throws if saving fails. */
    const saveNewProject = useCallback(
        async (project: NewProject) => {
            const now = new Date().toISOString();
            const next: ToolConfig = {
                ...toolSettings,
                projects: [...toolSettings.projects, { ...project, id: crypto.randomUUID(), version: DEFAULT_PROJECT_VERSION, createdOn: now, modifiedOn: now }],
            };
            await saveToolConfig(next);
            setToolSettings(next);
        },
        [toolSettings],
    );

    /** Removes a saved project from `projects` and saves the config; files in its folder are left alone. */
    const deleteProject = useCallback(
        async (project: ProjectEntry) => {
            const next: ToolConfig = { ...toolSettings, projects: toolSettings.projects.filter((p) => p.id !== project.id) };
            await saveToolConfig(next);
            setToolSettings(next);
        },
        [toolSettings],
    );

    /**
     * Saves the name, description and location edited in the Load Project dialog and saves the config. The version
     * and dates are left alone; they track generation. A project that's open stays open at its current folder.
     */
    const editProject = useCallback(
        async (project: ProjectEntry, changes: NewProject) => {
            const next: ToolConfig = { ...toolSettings, projects: toolSettings.projects.map((p) => (p.id === project.id ? { ...p, ...changes } : p)) };
            await saveToolConfig(next);
            setToolSettings(next);
        },
        [toolSettings],
    );

    /**
     * After a Generate run, updates the saved project whose location is `root`: a patch version bump and a new
     * Modified on when the run added files or stopped producing ones the previous run did. Folders that
     * aren't saved projects are left alone; a failure to save is logged, since the files were written.
     */
    const recordProjectGeneration = useCallback(
        async (root: string, applied: WritePlan) => {
            const index = toolSettings.projects.findIndex((p) => isSamePath(p.location, root));
            if (index === -1) return;
            const updated = recordGeneration(
                toolSettings.projects[index],
                {
                    files: applied.files.filter((f) => f.status !== 'orphaned').map((f) => f.relativePath),
                    newFiles: applied.files.filter((f) => writeStatusOf(f) === 'new').map((f) => f.relativePath),
                },
                new Date().toISOString(),
            );
            if (!updated) return;
            const next: ToolConfig = { ...toolSettings, projects: toolSettings.projects.map((p, i) => (i === index ? updated : p)) };
            try {
                await saveToolConfig(next);
                setToolSettings(next);
            } catch (e) {
                console.warn('Could not update the project after generating', e);
            }
        },
        [toolSettings],
    );

    /**
     * The Preview card's switches (Delete orphaned files, Skip and Rename duplicated identifier(s)): each saves
     * its key in the tool config, like the Settings panel.
     */
    const changeSetting = async (key: PreviewSettingKey, checked: boolean) => {
        try {
            await saveToolSettings({ ...toolSettings, [key]: checked } satisfies ToolConfig);
        } catch (e) {
            onError(reportError('Could not save the setting', e));
        }
    };

    return { toolSettings, saveToolSettings, saveNewProject, deleteProject, editProject, recordProjectGeneration, changeSetting };
}
