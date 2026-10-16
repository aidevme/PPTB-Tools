import { useCallback, useEffect, useRef, useState } from 'react';
import type { ProjectOpenTarget, SelectionKind } from '../components';
import { applyProjectDefaults, type ProjectDefaults } from '../config';
import { createDefaultConfig, type DataverseGenConfig } from '../core';
import { getRememberedProjectFolder, loadProjectConfig, notifyProjectLoaded, rememberProjectFolder, reportError, technicalMessage, type FileSink, type ProjectConfigState } from '../services';

export interface UseProjectOptions {
    sink: FileSink;
    /** The active connection's key, for the folder remembered per connection. */
    connKey: string | undefined;
    /** Whether the PPTB APIs are available, and the active connection; the remembered folder is only read with both. */
    inPptb: boolean;
    connection: ToolBoxAPI.Connection | null;
    /** The Settings panel's Options, applied to every project that opens and whenever they change. */
    projectDefaults: ProjectDefaults;
    /** Whether to show the "project loaded" notification when a saved project opens. */
    showProjectLoaded: boolean;
    /** Shows an error in the page (the error bar), or clears it with `null`. */
    setError: (message: string | null) => void;
    /** Drops the write plan and its stale flag when another project opens. */
    resetPlan: () => void;
    /** Marks the write plan out of date after a config edit. */
    markPlanStale: () => void;
}

/**
 * The project folder and its `.dataverse-gen.json`: opening a folder or a saved project, the folder remembered per
 * connection, and edits to the config (selection and Options).
 */
export function useProject({ sink, connKey, inPptb, connection, projectDefaults, showProjectLoaded, setError, resetPlan, markPlanStale }: UseProjectOptions) {
    const [projectRoot, setProjectRoot] = useState<string | null>(null);
    /** Folder used last time with this connection; shown as a hint and used as the picker's default. */
    const [rememberedFolder, setRememberedFolder] = useState<string | null>(null);
    // Until a project folder is picked this holds an in-memory draft, so tables, actions and functions
    // can be selected first; the draft selection is merged into the folder's config when it is loaded.
    const [configState, setConfigState] = useState<ProjectConfigState>(() => ({ path: '', exists: false, config: createDefaultConfig() }));
    const config = configState.config;

    /** Opens `folder` as the project and reads its `.dataverse-gen.json`; throws when it can't be read. Returns what was loaded. */
    const openProjectFolder = useCallback(
        async (folder: string) => {
            const state = await loadProjectConfig(sink, folder);
            // The Options (output folder, entity types, form context, index.ts) always start from Settings, also
            // over the values in an existing .dataverse-gen.json; the Options card can change them afterwards.
            state.config = applyProjectDefaults(state.config, projectDefaults);
            if (!projectRoot) {
                // Keep anything selected before the folder was picked.
                const merge = (loaded: string[] | undefined, draft: string[] | undefined) => [...new Set([...(loaded ?? []), ...(draft ?? [])])];
                state.config = {
                    ...state.config,
                    entities: merge(state.config.entities, config.entities),
                    actions: merge(state.config.actions, config.actions),
                    functions: merge(state.config.functions, config.functions),
                };
            }
            setProjectRoot(folder);
            setConfigState(state);
            resetPlan();
            await rememberProjectFolder(connKey, folder);
            return state;
        },
        [sink, connKey, projectRoot, config, projectDefaults, resetPlan],
    );

    const loadProject = useCallback(
        async (folder: string) => {
            setError(null);
            try {
                await openProjectFolder(folder);
            } catch (e) {
                setError(reportError(`Could not load ${folder}`, e, { folder }));
            }
        },
        [openProjectFolder, setError],
    );

    /**
     * Opens a project saved with the New Project dialog: its location becomes the project folder and its
     * `.dataverse-gen.json` is read. If PPTB hasn't granted access to that folder in this session, the folder
     * picker opens there for the user to confirm instead. Resolves to `false` when that picker is cancelled.
     */
    const openSavedProject = useCallback(
        async (project: ProjectOpenTarget) => {
            if (!window.toolboxAPI) throw new Error('Projects can only be opened inside Power Platform ToolBox.');
            setError(null);
            try {
                // Listing the folder fails outright without access; a missing .dataverse-gen.json alone would
                // otherwise just look like a new project.
                await window.toolboxAPI.fileSystem.readDirectory(project.location);
                const state = await openProjectFolder(project.location);
                if (showProjectLoaded) void notifyProjectLoaded(project.name, state);
                return true;
            } catch (e) {
                if (!/access denied|permission|not allowed|not permitted/i.test(technicalMessage(e))) throw e;
            }
            const folder = await window.toolboxAPI.fileSystem.selectPath({
                type: 'folder',
                title: `Open ${project.name}`,
                message: 'Confirm the project folder so Power Platform ToolBox lets the tool read it',
                defaultPath: project.location,
            });
            if (!folder) return false;
            const state = await openProjectFolder(folder);
            if (showProjectLoaded) void notifyProjectLoaded(project.name, state);
            return true;
        },
        [openProjectFolder, showProjectLoaded, setError],
    );

    /** Folder picker for the New Project and edit dialogs' Location; `null` when cancelled or outside PPTB. */
    const pickProjectLocation = useCallback(async (current: string) => {
        if (!window.toolboxAPI) return null;
        return window.toolboxAPI.fileSystem.selectPath({
            type: 'folder',
            title: 'Select the project location',
            defaultPath: current || undefined,
        });
    }, []);

    // PPTB only grants file access to folders picked with selectPath in the current session, so the
    // remembered folder cannot be read directly; it only pre-fills the folder picker.
    useEffect(() => {
        if (!inPptb || !connection) return;
        let cancelled = false;
        getRememberedProjectFolder(connKey).then((folder) => {
            if (!cancelled) setRememberedFolder(folder ?? null);
        });
        return () => {
            cancelled = true;
        };
    }, [inPptb, connection, connKey]);

    const updateConfig = useCallback(
        (update: Partial<DataverseGenConfig>) => {
            setConfigState((state) => ({ ...state, config: { ...state.config, ...update } }));
            markPlanStale();
        },
        [markPlanStale],
    );

    /** After Generate saved `.dataverse-gen.json` at `path`. */
    const markConfigSaved = useCallback((path: string) => setConfigState((state) => ({ ...state, exists: true, path })), []);

    /**
     * Applies the Settings panel's Options to the current config when they change: once the saved settings load
     * (which may finish after a remembered project opened), and when the user saves different ones. Edits made in
     * the Options card are kept until then.
     */
    const configRef = useRef(config);
    configRef.current = config;
    const projectDefaultsKey = JSON.stringify(projectDefaults);
    useEffect(() => {
        const current = configRef.current;
        const next = applyProjectDefaults(current, JSON.parse(projectDefaultsKey) as ProjectDefaults);
        const options = (c: DataverseGenConfig) => [c.output?.outputRoot, c.generateEntityTypes, c.generateFormContext, c.generateIndex];
        if (JSON.stringify(options(current)) === JSON.stringify(options(next))) return;
        updateConfig({ output: next.output, generateEntityTypes: next.generateEntityTypes, generateFormContext: next.generateFormContext, generateIndex: next.generateIndex });
    }, [projectDefaultsKey, updateConfig]);

    const toggle = useCallback(
        (kind: SelectionKind, name: string, checked: boolean) => {
            const current = config[kind] ?? [];
            const next = checked ? (current.includes(name) ? current : [...current, name]) : current.filter((n) => n !== name);
            updateConfig({ [kind]: next });
        },
        [config, updateConfig],
    );

    const clear = useCallback((kind: SelectionKind) => updateConfig({ [kind]: [] }), [updateConfig]);
    const clearAll = useCallback(() => updateConfig({ entities: [], actions: [], functions: [] }), [updateConfig]);

    return {
        projectRoot,
        rememberedFolder,
        configState,
        config,
        openProjectFolder,
        loadProject,
        openSavedProject,
        pickProjectLocation,
        updateConfig,
        markConfigSaved,
        toggle,
        clear,
        clearAll,
    };
}
