import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { MessageBar, MessageBarBody, MessageBarTitle, ProgressBar, Text } from '@fluentui/react-components';
import { DeleteRegular, SaveRegular } from '@fluentui/react-icons';
import { ConfirmationDialog, Footer, Header, LoadProjectDialog, NewProjectDialog, OptionsCard, PreviewCard, ProjectCard, SelectionCard, SettingsPanel, WorkflowProgress, computeWorkflowSteps, type NewProject, type ProjectOpenTarget, type SelectionKind } from '..';
import { buildSchemaModel, createDefaultConfig, generate, resolveConfig, resolveSelection, type DataverseGenConfig, type EntityMetadataInput } from '../../core';
import { DEFAULT_PROJECT_VERSION, applyProjectDefaults, mergeToolConfig, recordGeneration, toolConfig, type ProjectDefaults, type ProjectEntry, type ToolConfig } from '../../config';
import { useConnection, useStickyBarHeights } from '../../hooks';
import {
    PptbFileSink,
    PptbMetadataProvider,
    applyWritePlan,
    connectionKey,
    countStatuses,
    createWritePlan,
    dataverseGenTemplateFiles,
    deleteOrphanedFiles,
    getRememberedProjectFolder,
    getSolutionEntityIds,
    getSolutionMemberIds,
    isSamePath,
    listSolutions,
    loadProjectConfig,
    loadToolConfig,
    notifyGenerationComplete,
    notifyPreviewReady,
    notifyProjectLoaded,
    rememberProjectFolder,
    reportError,
    resolveOutputRoot,
    saveProjectConfig,
    saveToolConfig,
    summarizeGeneration,
    technicalMessage,
    willWrite,
    writeCounts,
    writeStatusOf,
    type ProjectConfigState,
} from '../../services';
import { useAppStyles } from '../../styles';
import type { EntitySummary, OperationSummary, Progress, SolutionSummary, WritePlan } from '../../types';

/** How long the "$metadata is too large" warning stays visible. */
const METADATA_FALLBACK_WARNING_MS = 5000;

const EMPTY_SELECTION: Record<SelectionKind, string[]> = { entities: [], actions: [], functions: [] };

/**
 * Top-level state and orchestration. Holds the project folder and its `.dataverse-gen.json`, the
 * environment's table / operation / solution lists, and the current write plan; the cards below are
 * presentational and receive everything as props.
 */
export default function App() {
    const styles = useAppStyles();
    const headerRef = useRef<HTMLDivElement>(null);
    const footerRef = useRef<HTMLDivElement>(null);
    useStickyBarHeights(headerRef, footerRef);
    const { connection, isLoading: connectionLoading } = useConnection();
    const inPptb = typeof window !== 'undefined' && !!window.toolboxAPI && !!window.dataverseAPI;
    const connKey = connectionKey(connection);

    // A fresh provider (and so a fresh metadata cache) per connection.
    const provider = useMemo(() => new PptbMetadataProvider(), [connKey]); // eslint-disable-line react-hooks/exhaustive-deps
    const sink = useMemo(() => new PptbFileSink(), []);
    const [settingsOpen, setSettingsOpen] = useState(false);
    /** Whether the dialog confirming that Generate will delete orphaned files is open. */
    const [confirmDeleteOpen, setConfirmDeleteOpen] = useState(false);
    /** Whether the dialog confirming Generate (the "Ask before generating" setting) is open. */
    const [confirmGenerateOpen, setConfirmGenerateOpen] = useState(false);
    const [newProjectOpen, setNewProjectOpen] = useState(false);
    const [loadProjectOpen, setLoadProjectOpen] = useState(false);
    /** Settings-panel values: the bundled defaults until the saved values have loaded. */
    const [toolSettings, setToolSettings] = useState<ToolConfig>(toolConfig);
    /** The $metadata document is too large for PPTB, so the schema was rebuilt from table metadata. */
    const [metadataFallback, setMetadataFallback] = useState(false);
    /** The fallback warning is shown for a few seconds when the fallback starts, then hides itself. */
    const [showMetadataFallbackWarning, setShowMetadataFallbackWarning] = useState(false);

    const [projectRoot, setProjectRoot] = useState<string | null>(null);
    /** Folder used last time with this connection; shown as a hint and used as the picker's default. */
    const [rememberedFolder, setRememberedFolder] = useState<string | null>(null);
    // Until a project folder is picked this holds an in-memory draft, so tables, actions and functions
    // can be selected first; the draft selection is merged into the folder's config when it is loaded.
    const [configState, setConfigState] = useState<ProjectConfigState>(() => ({ path: '', exists: false, config: createDefaultConfig() }));
    const [entities, setEntities] = useState<EntitySummary[]>([]);
    const [operations, setOperations] = useState<OperationSummary[] | null>(null);
    const [solutions, setSolutions] = useState<SolutionSummary[]>([]);
    const [selectedSolutionId, setSelectedSolutionId] = useState<string | null>(null);
    const [solutionEntityIds, setSolutionEntityIds] = useState<Set<string> | null>(null);
    const [loadingEntities, setLoadingEntities] = useState(false);
    const [loadingOperations, setLoadingOperations] = useState(false);
    const [loadingSolution, setLoadingSolution] = useState(false);
    const [plan, setPlan] = useState<WritePlan | null>(null);
    /** When the current plan was computed (ISO), for the Preview card's "Previewed … ago". */
    const [previewedAt, setPreviewedAt] = useState<string | null>(null);
    /** Summary of the last Generate run, shown in the Preview card until the next preview. */
    const [lastResult, setLastResult] = useState<string | null>(null);
    const [planStale, setPlanStale] = useState(false);
    const [progress, setProgress] = useState<Progress | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [notice, setNotice] = useState<string | null>(null);
    const solutionCache = useRef(new Map<string, Set<string>>());
    /** Component ids (custom APIs, process actions) of the selected solution; `null` when not filtering. */
    const [solutionComponentIds, setSolutionComponentIds] = useState<Set<string> | null>(null);
    const [loadingSolutionOperations, setLoadingSolutionOperations] = useState(false);
    const solutionOperationCache = useRef(new Map<string, Set<string>>());

    const config = configState.config;
    const busy = progress !== null;

    // ----- project folder -------------------------------------------------------------------------

    /** Opens `folder` as the project and reads its `.dataverse-gen.json`; throws when it can't be read. Returns what was loaded. */
    const openProjectFolder = useCallback(
        async (folder: string) => {
            const state = await loadProjectConfig(sink, folder);
            // The Options (output folder, entity types, form context, index.ts) always start from Settings, also
            // over the values in an existing .dataverse-gen.json; the Options card can change them afterwards.
            state.config = applyProjectDefaults(state.config, toolSettings.projectDefaults);
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
            setPlan(null);
            setPlanStale(false);
            await rememberProjectFolder(connKey, folder);
            return state;
        },
        [sink, connKey, projectRoot, config, toolSettings.projectDefaults],
    );

    const loadProject = useCallback(
        async (folder: string) => {
            setError(null);
            setNotice(null);
            try {
                await openProjectFolder(folder);
            } catch (e) {
                setError(reportError(`Could not load ${folder}`, e, { folder }));
            }
        },
        [openProjectFolder],
    );

    /**
     * Opens a project saved with the New Project dialog: its location becomes the project folder and its
     * `.dataverse-gen.json` is read. If PPTB hasn't granted access to that folder in this session, the folder
     * picker opens there for the user to confirm instead. Resolves to `false` when that picker is cancelled.
     */
    const showProjectLoaded = toolSettings.general.showProjectLoadedNotification;
    const openSavedProject = useCallback(
        async (project: ProjectOpenTarget) => {
            if (!window.toolboxAPI) throw new Error('Projects can only be opened inside Power Platform ToolBox.');
            setError(null);
            setNotice(null);
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
        [openProjectFolder, showProjectLoaded],
    );

    // ----- environment lists ----------------------------------------------------------------------

    useEffect(() => {
        let cancelled = false;
        void loadToolConfig().then((loaded) => !cancelled && setToolSettings(loaded));
        return () => {
            cancelled = true;
        };
    }, []);

    useEffect(() => {
        if (!metadataFallback) {
            setShowMetadataFallbackWarning(false);
            return;
        }
        setShowMetadataFallbackWarning(true);
        const timer = window.setTimeout(() => setShowMetadataFallbackWarning(false), METADATA_FALLBACK_WARNING_MS);
        return () => window.clearTimeout(timer);
    }, [metadataFallback]);

    /** Saves the Settings-panel values; the panel stays open and shows the error if saving fails. */
    const saveToolSettings = useCallback(
        async (draft: ToolConfig) => {
            // Same normalization as on load, so e.g. a blank output folder saves as the default, not as "".
            const next = mergeToolConfig(draft);
            await saveToolConfig(next);
            setToolSettings(next);
            // Renaming duplicates changes the generated files, so the current preview no longer matches.
            if (next.renameDuplicateIdentifiers !== toolSettings.renameDuplicateIdentifiers) setPlanStale(true);
        },
        [toolSettings.renameDuplicateIdentifiers],
    );

    /**
     * Adds a project from the New Project dialog to `projects`, saves the config, and opens the project, which
     * also lists the tables. A failure to save stays in the dialog; a failure to open shows in the page, since
     * the project was saved.
     */
    const addProject = useCallback(
        async (project: NewProject) => {
            const now = new Date().toISOString();
            const next: ToolConfig = {
                ...toolSettings,
                projects: [...toolSettings.projects, { ...project, id: crypto.randomUUID(), version: DEFAULT_PROJECT_VERSION, createdOn: now, modifiedOn: now }],
            };
            await saveToolConfig(next);
            setToolSettings(next);
            openSavedProject(project).catch((e: unknown) => setError(reportError(`Could not open ${project.name}`, e, { location: project.location })));
        },
        [toolSettings, openSavedProject],
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

    /** Folder picker for the New Project and edit dialogs' Location; `null` when cancelled or outside PPTB. */
    const pickProjectLocation = useCallback(async (current: string) => {
        if (!window.toolboxAPI) return null;
        return window.toolboxAPI.fileSystem.selectPath({
            type: 'folder',
            title: 'Select the project location',
            defaultPath: current || undefined,
        });
    }, []);

    /** Tables, solutions and the selection are only listed once a project is open (created or loaded). */
    const hasProject = !!projectRoot;

    useEffect(() => {
        if (!inPptb || !connection || !hasProject) return;
        let cancelled = false;
        setEntities([]);
        setOperations(null);
        setMetadataFallback(false);
        setSolutions([]);
        setSelectedSolutionId(null);
        setSolutionEntityIds(null);
        setSolutionComponentIds(null);
        solutionCache.current.clear();
        solutionOperationCache.current.clear();
        setPlan(null);
        setLoadingEntities(true);
        provider
            .listEntities()
            .then((list) => !cancelled && setEntities(list))
            .catch((e) => !cancelled && setError(reportError(`Could not list tables`, e)))
            .finally(() => !cancelled && setLoadingEntities(false));
        listSolutions()
            .then((list) => !cancelled && setSolutions(list))
            .catch((e) => console.warn('Could not list solutions', e));
        return () => {
            cancelled = true;
        };
        // Only re-run when the connection (and so the provider) changes, or the first project is opened.
    }, [provider, inPptb, connection, hasProject]); // eslint-disable-line react-hooks/exhaustive-deps

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

    const ensureOperations = useCallback(() => {
        if (operations !== null || loadingOperations || !inPptb || !hasProject) return;
        setLoadingOperations(true);
        provider
            .listOperations()
            .then((list) => {
                setOperations(list);
                setMetadataFallback(provider.usesMetadataFallback);
            })
            .catch((e) => setError(reportError(`Could not load the $metadata document`, e)))
            .finally(() => setLoadingOperations(false));
    }, [operations, loadingOperations, inPptb, hasProject, provider]);

    const changeSolution = useCallback(async (solutionId: string | null) => {
        setSelectedSolutionId(solutionId);
        if (!solutionId) {
            setSolutionEntityIds(null);
            return;
        }
        const cached = solutionCache.current.get(solutionId);
        if (cached) {
            setSolutionEntityIds(cached);
            return;
        }
        setLoadingSolution(true);
        try {
            const ids = await getSolutionEntityIds(solutionId);
            solutionCache.current.set(solutionId, ids);
            setSolutionEntityIds(ids);
        } catch (e) {
            setError(reportError(`Could not load the solution's tables`, e));
            setSelectedSolutionId(null);
        } finally {
            setLoadingSolution(false);
        }
    }, []);

    // Solution membership of actions/functions: needs both a solution and the operation list.
    useEffect(() => {
        if (!selectedSolutionId || !operations) {
            setSolutionComponentIds(null);
            return;
        }
        const cached = solutionOperationCache.current.get(selectedSolutionId);
        if (cached) {
            setSolutionComponentIds(cached);
            return;
        }
        let cancelled = false;
        const solutionId = selectedSolutionId;
        const ids = operations.map((o) => o.componentId).filter((id): id is string => !!id);
        setLoadingSolutionOperations(true);
        getSolutionMemberIds(solutionId, ids)
            .then((members) => {
                solutionOperationCache.current.set(solutionId, members);
                if (!cancelled) setSolutionComponentIds(members);
            })
            .catch((e) => !cancelled && setError(reportError(`Could not load the solution's actions and functions`, e)))
            .finally(() => !cancelled && setLoadingSolutionOperations(false));
        return () => {
            cancelled = true;
        };
    }, [selectedSolutionId, operations]);

    // ----- config edits ---------------------------------------------------------------------------

    const updateConfig = useCallback((update: Partial<DataverseGenConfig>) => {
        setConfigState((state) => ({ ...state, config: { ...state.config, ...update } }));
        setPlanStale(true);
        setNotice(null);
    }, []);

    /**
     * Applies the Settings panel's Options to the current config when they change: once the saved settings load
     * (which may finish after a remembered project opened), and when the user saves different ones. Edits made in
     * the Options card are kept until then.
     */
    const configRef = useRef(config);
    configRef.current = config;
    const projectDefaultsKey = JSON.stringify(toolSettings.projectDefaults);
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

    const copyPath = useCallback(async (path: string, label: string) => {
        try {
            await window.toolboxAPI.utils.copyToClipboard(path);
            await window.toolboxAPI.utils.showNotification({ title: 'Copied', body: `${label} copied to the clipboard.`, type: 'info', duration: 2500 });
        } catch (e) {
            setError(reportError(`Could not copy to the clipboard`, e));
        }
    }, []);

    // ----- preview / generate ---------------------------------------------------------------------

    const runPreview = useCallback(async (): Promise<WritePlan | null> => {
        if (!projectRoot) return null;
        setError(null);
        setNotice(null);
        try {
            const resolved = resolveConfig(config);
            setProgress({ message: 'Loading the $metadata document…', completed: 0, total: 1 });
            const schema = await provider.getSchemaForSelection(resolved.actions, resolved.functions);
            setMetadataFallback(provider.usesMetadataFallback);
            const selection = resolveSelection(schema, resolved);
            const names = selection.entities.map((e) => e.Name);
            setProgress({ message: `Loading metadata for ${names.length} table(s)…`, completed: 0, total: names.length });
            const loaded = await provider.getEntities(names, (completed, total, name) =>
                setProgress({ message: `Loaded ${name}`, completed, total }),
            );
            const byName = new Map<string, EntityMetadataInput>(loaded.map((e) => [e.LogicalName, e]));
            setProgress({ message: 'Generating files…', completed: 0, total: 1 });
            const model = buildSchemaModel(schema, resolved, (name) => byName.get(name));
            const files = generate(model, resolved, { renameDuplicateIdentifiers: toolSettings.renameDuplicateIdentifiers });
            setProgress({ message: 'Comparing with the output folder…', completed: 0, total: 1 });
            // dataverse-gen's templates go into the project's templateRoot on every Generate, like `dataverse-gen eject`.
            const nextPlan = await createWritePlan(sink, projectRoot, resolved, files, dataverseGenTemplateFiles(resolved));
            setPlan(nextPlan);
            setPreviewedAt(new Date().toISOString());
            setLastResult(null);
            setPlanStale(false);
            if (toolSettings.general.showPreviewReadyNotification) void notifyPreviewReady(nextPlan, toolSettings.deleteOrphanedFiles, toolSettings.skipDuplicateIdentifiers);
            return nextPlan;
        } catch (e) {
            setError(reportError('Preview failed', e, { projectRoot }));
            return null;
        } finally {
            setProgress(null);
        }
    }, [
        projectRoot,
        config,
        provider,
        sink,
        toolSettings.deleteOrphanedFiles,
        toolSettings.skipDuplicateIdentifiers,
        toolSettings.renameDuplicateIdentifiers,
        toolSettings.general.showPreviewReadyNotification,
    ]);

    /**
     * After a Generate run, updates the saved project whose location is `root`: a patch version bump and a new
     * Modified On when the run added files or stopped producing ones the previous run did. Folders that
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
     * Writes the plan's new and changed files and saves the project config; with `deleteOrphans`, then deletes the
     * plan's orphaned files. A failed delete is reported on its own, since the files were already written.
     */
    const runGenerate = useCallback(
        async (planToApply: WritePlan, deleteOrphans: boolean) => {
            if (!projectRoot) return;
            setError(null);
            try {
                const writeOptions = { skipDuplicates: toolSettings.skipDuplicateIdentifiers };
                const writes = writeCounts(planToApply, writeOptions);
                setProgress({ message: 'Writing files…', completed: 0, total: writes.created + writes.overwritten });
                const result = await applyWritePlan(
                    sink,
                    planToApply,
                    (completed, total, file) => setProgress({ message: `Wrote ${file.relativePath}`, completed, total }),
                    writeOptions,
                );
                const configPath = await saveProjectConfig(sink, projectRoot, config);
                setConfigState((state) => ({ ...state, exists: true, path: configPath }));
                await recordProjectGeneration(projectRoot, planToApply);

                let deleted: Set<string> | undefined;
                if (deleteOrphans && planToApply.counts.orphaned > 0) {
                    setProgress({ message: 'Deleting orphaned files…', completed: 0, total: planToApply.counts.orphaned });
                    try {
                        const outcome = await deleteOrphanedFiles(sink, planToApply);
                        deleted = new Set(outcome.deleted);
                        if (outcome.failed.length > 0) {
                            setError(
                                reportError('Some orphaned files were not deleted', new Error(`Still in the output folder: ${outcome.failed.join(', ')}`), {
                                    outputRoot: planToApply.outputRoot,
                                }),
                            );
                        }
                    } catch (e) {
                        deleted = new Set();
                        setError(reportError('Could not delete the orphaned files', e, { outputRoot: planToApply.outputRoot }));
                    }
                }

                // Everything written is now unchanged (files with duplicate identifiers keep that status), and deleted
                // orphans are gone.
                const remainingFiles = planToApply.files
                    .filter((f) => !(f.status === 'orphaned' && deleted?.has(f.relativePath)))
                    .map((f) => {
                        if (!willWrite(f, writeOptions)) return f;
                        return f.status === 'duplicate'
                            ? { ...f, writeStatus: 'unchanged' as const, existingContent: f.content }
                            : { ...f, status: 'unchanged' as const, existingContent: f.content };
                    });
                setPlan({ ...planToApply, files: remainingFiles, counts: countStatuses(remainingFiles) });
                setLastResult(summarizeGeneration(result.written, planToApply.counts, deleted?.size, writeOptions.skipDuplicates));
                // Not awaited, and it never throws: a failed notification mustn't report a successful write as "Generation failed".
                if (toolSettings.general.showGenerationCompleteNotification) void notifyGenerationComplete(result.written, planToApply.counts, deleted?.size, writeOptions.skipDuplicates);
            } catch (e) {
                setError(reportError(`Generation failed`, e));
            } finally {
                setProgress(null);
            }
        },
        [projectRoot, config, sink, recordProjectGeneration, toolSettings.general.showGenerationCompleteNotification],
    );

    /**
     * Generate: deleting orphans always needs a confirmation, which also covers the writes; otherwise "Ask before
     * generating" asks first, or it writes straight away.
     */
    const startGenerate = () => {
        if (!plan) return;
        if (toolSettings.deleteOrphanedFiles && plan.counts.orphaned > 0) setConfirmDeleteOpen(true);
        else if (toolSettings.confirmBeforeGenerate && pendingWrites(plan, skipDuplicates) > 0) setConfirmGenerateOpen(true);
        else void runGenerate(plan, false);
    };

    /** The Delete orphaned files switch: saves `deleteOrphanedFiles` in the tool config, like the Settings panel. */
    const changeDeleteOrphans = async (checked: boolean) => {
        try {
            await saveToolSettings({ ...toolSettings, deleteOrphanedFiles: checked });
        } catch (e) {
            setError(reportError('Could not save the setting', e));
        }
    };

    /** The Skip duplicated identifier(s) switch: saves `skipDuplicateIdentifiers` in the tool config, like the Settings panel. */
    const changeSkipDuplicates = async (checked: boolean) => {
        try {
            await saveToolSettings({ ...toolSettings, skipDuplicateIdentifiers: checked });
        } catch (e) {
            setError(reportError('Could not save the setting', e));
        }
    };

    /** The Rename duplicated identifier(s) switch: saves `renameDuplicateIdentifiers`, like the Settings panel. */
    const changeRenameDuplicates = async (checked: boolean) => {
        try {
            await saveToolSettings({ ...toolSettings, renameDuplicateIdentifiers: checked });
        } catch (e) {
            setError(reportError('Could not save the setting', e));
        }
    };

    // ----- derived --------------------------------------------------------------------------------

    const skipDuplicates = toolSettings.skipDuplicateIdentifiers;

    const selected = useMemo<Record<SelectionKind, string[]>>(
        () => (config ? { entities: config.entities ?? [], actions: config.actions ?? [], functions: config.functions ?? [] } : EMPTY_SELECTION),
        [config],
    );
    const missing = useMemo<Record<SelectionKind, string[]>>(() => {
        const entityNames = new Set(entities.map((e) => e.logicalName));
        const actionNames = new Set((operations ?? []).filter((o) => o.kind === 'action').map((o) => o.name));
        const functionNames = new Set((operations ?? []).filter((o) => o.kind === 'function').map((o) => o.name));
        return {
            entities: entities.length ? selected.entities.filter((n) => !entityNames.has(n)) : [],
            actions: operations ? selected.actions.filter((n) => !actionNames.has(n)) : [],
            functions: operations ? selected.functions.filter((n) => !functionNames.has(n)) : [],
        };
    }, [entities, operations, selected]);

    const hasSelection = selected.entities.length + selected.actions.length + selected.functions.length > 0;
    /** Lists can be browsed and selected once connected; preview and generate also need a project folder. */
    const connected = inPptb && !!connection;
    const canSelect = connected && hasProject;
    const ready = canSelect;
    const steps = computeWorkflowSteps({
        hasProject: !!projectRoot,
        selectedCount: selected.entities.length + selected.actions.length + selected.functions.length,
        plan: plan ? { pending: pendingWrites(plan, skipDuplicates) + (toolSettings.deleteOrphanedFiles ? plan.counts.orphaned : 0), stale: planStale } : null,
    });

    /** Opens a project from the Project card's recent list; errors show in the page, a cancelled picker does nothing. */
    const openRecent = (target: ProjectOpenTarget) => {
        openSavedProject(target).catch((e: unknown) => setError(reportError(`Could not open ${target.name}`, e, { location: target.location })));
    };

    return (
        <div className={styles.page}>
            <div ref={headerRef} className={styles.stickyHeader}>
                <Header connection={connection} onOpenSettings={() => setSettingsOpen(true)} />
            </div>
            <SettingsPanel
                open={settingsOpen}
                onOpenChange={setSettingsOpen}
                settings={toolSettings}
                onSave={saveToolSettings}
            />
            <NewProjectDialog
                open={newProjectOpen}
                onOpenChange={setNewProjectOpen}
                existingNames={toolSettings.projects.map((p) => p.name)}
                onBrowseLocation={pickProjectLocation}
                onSave={addProject}
            />
            <LoadProjectDialog
                open={loadProjectOpen}
                onOpenChange={setLoadProjectOpen}
                projects={toolSettings.projects}
                onLoad={openSavedProject}
                onDelete={deleteProject}
                onEdit={editProject}
                onBrowseLocation={pickProjectLocation}
            />
            <main className={styles.main}>
                {!inPptb && (
                    <MessageBar intent="warning">
                        <MessageBarBody>
                            <MessageBarTitle>Not running inside Power Platform ToolBox</MessageBarTitle>
                            The PPTB APIs (connection, Dataverse metadata, file system) are not available in a plain browser tab. Build the
                            tool and load it through PPTB's Debug menu to use it.
                        </MessageBarBody>
                    </MessageBar>
                )}
                {inPptb && !connectionLoading && !connection && (
                    <MessageBar intent="info">
                        <MessageBarBody>Connect to a Dataverse environment in PPTB to list tables, actions and functions.</MessageBarBody>
                    </MessageBar>
                )}
                {showMetadataFallbackWarning && (
                    <MessageBar intent="warning">
                        <MessageBarBody>
                            <MessageBarTitle>$metadata is too large for Power Platform ToolBox</MessageBarTitle>
                            This environment's $metadata document is over the 16 MB PPTB allows, so types are built from table and
                            relationship metadata instead. Tables and custom APIs work; built-in actions and functions and custom process
                            actions are not available. Output can differ slightly from dataverse-gen's.
                        </MessageBarBody>
                    </MessageBar>
                )}
                {error && (
                    <MessageBar intent="error">
                        <MessageBarBody>
                            <MessageBarTitle>Error</MessageBarTitle>
                            {error}
                        </MessageBarBody>
                    </MessageBar>
                )}
                {notice && (
                    <MessageBar intent="success">
                        <MessageBarBody>{notice}</MessageBarBody>
                    </MessageBar>
                )}
                {progress && (
                    <div className={styles.progress}>
                        <Text size={200}>{progress.message}</Text>
                        <ProgressBar value={progress.total > 0 ? progress.completed / progress.total : undefined} />
                    </div>
                )}
                <WorkflowProgress steps={steps} />
                <ProjectCard
                    step={steps[0]}
                    projectRoot={projectRoot}
                    rememberedFolder={rememberedFolder}
                    configState={projectRoot ? configState : null}
                    projects={toolSettings.projects}
                    recentProjectCount={toolSettings.general.recentProjectCount}
                    busy={busy || !inPptb}
                    onNewProject={() => setNewProjectOpen(true)}
                    onLoadExistingProject={() => setLoadProjectOpen(true)}
                    onOpenRecent={openRecent}
                    onReload={() => projectRoot && loadProject(projectRoot)}
                    outputFolder={projectRoot ? resolveOutputRoot(projectRoot, resolveConfig(config)) : null}
                    hasSelection={hasSelection}
                    onCopyPath={(path, label) => void copyPath(path, label)}
                    onClearSelection={clearAll}
                />
                <SelectionCard
                    step={steps[1]}
                    entities={entities}
                    operations={operations}
                    solutions={solutions}
                    solutionEntityIds={solutionEntityIds}
                    solutionComponentIds={solutionComponentIds}
                    selectedSolutionId={selectedSolutionId}
                    loadingEntities={loadingEntities}
                    loadingOperations={loadingOperations}
                    loadingSolution={loadingSolution || loadingSolutionOperations}
                    selected={selected}
                    missing={missing}
                    disabled={!canSelect || busy}
                    needsProject={!projectRoot}
                    onToggle={toggle}
                    onClear={clear}
                    onSolutionChange={changeSolution}
                    onEnsureOperations={ensureOperations}
                    rowLimit={toolSettings.general.selectionRowLimit}
                />
                <OptionsCard step={steps[2]} config={config} disabled={!canSelect || busy} onChange={updateConfig} />
                <PreviewCard
                    step={steps[3]}
                    plan={plan}
                    stale={planStale}
                    canPreview={ready && hasSelection}
                    needsProject={connected && !projectRoot}
                    busy={busy}
                    previewedAt={plan ? previewedAt : null}
                    lastResult={plan ? lastResult : null}
                    onPreview={() => void runPreview()}
                    deleteOrphans={toolSettings.deleteOrphanedFiles}
                    skipDuplicates={skipDuplicates}
                    onSkipDuplicatesChange={(checked) => void changeSkipDuplicates(checked)}
                    renameDuplicates={toolSettings.renameDuplicateIdentifiers}
                    onRenameDuplicatesChange={(checked) => void changeRenameDuplicates(checked)}
                    onDeleteOrphansChange={(checked) => void changeDeleteOrphans(checked)}
                    onGenerate={startGenerate}
                    onCopyText={(text, label) => void copyPath(text, label)}
                />
            </main>
            <ConfirmationDialog
                open={confirmDeleteOpen && !!plan}
                title="Delete orphaned files?"
                message={plan && <OrphanList plan={plan} />}
                confirmLabel={
                    plan && pendingWrites(plan, skipDuplicates) > 0
                        ? `Generate and delete ${plan.counts.orphaned}`
                        : `Delete ${plan?.counts.orphaned ?? 0} ${plan?.counts.orphaned === 1 ? 'file' : 'files'}`
                }
                confirmIcon={<DeleteRegular />}
                onConfirm={() => {
                    setConfirmDeleteOpen(false);
                    if (plan) void runGenerate(plan, true);
                }}
                onCancel={() => setConfirmDeleteOpen(false)}
            />
            <ConfirmationDialog
                open={confirmGenerateOpen && !!plan}
                title="Generate files?"
                message={plan && <GenerateSummary plan={plan} skipDuplicates={skipDuplicates} />}
                confirmLabel={`Generate ${plan ? pendingWrites(plan, skipDuplicates) : 0} ${plan && pendingWrites(plan, skipDuplicates) === 1 ? 'file' : 'files'}`}
                confirmIcon={<SaveRegular />}
                onConfirm={() => {
                    setConfirmGenerateOpen(false);
                    if (plan) void runGenerate(plan, false);
                }}
                onCancel={() => setConfirmGenerateOpen(false)}
            />
            <div ref={footerRef} className={styles.stickyFooter}>
                <Footer />
            </div>
        </div>
    );
}

/** How many files Generate writes: new and changed, including files with duplicate identifiers unless they're skipped. */
function pendingWrites(plan: WritePlan, skipDuplicates: boolean): number {
    const { created, overwritten } = writeCounts(plan, { skipDuplicates });
    return created + overwritten;
}

/** How many orphans the confirmation names before summarizing the rest. */
const ORPHANS_LISTED = 10;

/** The confirmation's message: what will be deleted, from which folder, and that it can't be undone. */
function OrphanList({ plan }: { plan: WritePlan }) {
    const orphans = plan.files.filter((f) => f.status === 'orphaned');
    const more = orphans.length - ORPHANS_LISTED;
    return (
        <>
            <Text block>
                {orphans.length === 1 ? 'This file is' : `These ${orphans.length} files are`} in the output folder ({plan.outputRoot}) but no longer
                generated. {orphans.length === 1 ? 'It' : 'They'} will be permanently deleted, not moved to the Recycle Bin or Trash.
            </Text>
            <ul>
                {orphans.slice(0, ORPHANS_LISTED).map((f) => (
                    <li key={f.relativePath}>
                        <code>{f.relativePath}</code>
                    </li>
                ))}
                {more > 0 && <li>…and {more} more</li>}
            </ul>
        </>
    );
}

/** The "Ask before generating" confirmation's message: where files go, what's created and overwritten, and that it can't be undone. */
function GenerateSummary({ plan, skipDuplicates }: { plan: WritePlan; skipDuplicates: boolean }) {
    const { created, overwritten: changed } = writeCounts(plan, { skipDuplicates });
    const duplicates = plan.counts.duplicate;
    const files = (n: number) => `${n} ${n === 1 ? 'file' : 'files'}`;
    return (
        <>
            <Text block>
                Generate writes to <code>{plan.outputRoot}</code> and saves <code>.dataverse-gen.json</code>.
            </Text>
            <ul>
                {created > 0 && <li>{files(created)} will be created</li>}
                {changed > 0 && <li>{files(changed)} will be overwritten</li>}
            </ul>
            {duplicates > 0 && (
                <Text block>
                    {files(duplicates)} {duplicates === 1 ? 'declares' : 'declare'} duplicate identifiers and{' '}
                    {skipDuplicates ? "won't be written." : "won't compile until the option labels are fixed in Dataverse."}
                </Text>
            )}
            <Text block>Overwritten files can't be restored by the tool; use source control to undo changes.</Text>
        </>
    );
}
