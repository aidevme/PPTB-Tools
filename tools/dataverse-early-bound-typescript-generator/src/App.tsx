import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { MessageBar, MessageBarBody, MessageBarTitle, ProgressBar, Text, makeStyles, tokens } from '@fluentui/react-components';
import { Footer, Header, LoadProjectDialog, NewProjectDialog, OptionsCard, PreviewCard, ProjectCard, SelectionCard, SettingsPanel, WorkflowProgress, computeWorkflowSteps, type NewProject, type ProjectOpenTarget, type SelectionKind } from './components';
import { buildSchemaModel, createDefaultConfig, generate, resolveConfig, resolveSelection, type DataverseGenConfig, type EntityMetadataInput } from './core';
import { DEFAULT_PROJECT_VERSION, applyProjectDefaults, mergeToolConfig, recordGeneration, toolConfig, type ProjectEntry, type ToolConfig } from './config';
import { useConnection } from './hooks';
import {
    PptbFileSink,
    PptbMetadataProvider,
    applyWritePlan,
    connectionKey,
    createWritePlan,
    getRememberedProjectFolder,
    getSolutionEntityIds,
    getSolutionMemberIds,
    isSamePath,
    listSolutions,
    loadProjectConfig,
    loadToolConfig,
    rememberProjectFolder,
    resolveOutputRoot,
    saveProjectConfig,
    saveToolConfig,
    type ProjectConfigState,
} from './services';
import type { EntitySummary, OperationSummary, Progress, SolutionSummary, WritePlan } from './types';

const useStyles = makeStyles({
    page: { display: 'flex', flexDirection: 'column', minHeight: '100vh' },
    main: {
        display: 'flex',
        flexDirection: 'column',
        gap: tokens.spacingVerticalM,
        padding: tokens.spacingHorizontalL,
        flexGrow: 1,
        maxWidth: '1400px',
        width: '100%',
        boxSizing: 'border-box',
        alignSelf: 'center',
    },
    progress: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalXS },
});

/** How long the "$metadata is too large" warning stays visible. */
const METADATA_FALLBACK_WARNING_MS = 5000;

const EMPTY_SELECTION: Record<SelectionKind, string[]> = { entities: [], actions: [], functions: [] };

function errorMessage(error: unknown): string {
    if (error instanceof Error) return error.message;
    if (typeof error === 'string') return error;
    try {
        return JSON.stringify(error);
    } catch {
        return String(error);
    }
}

/**
 * Top-level state and orchestration. Holds the project folder and its `.dataverse-gen.json`, the
 * environment's table / operation / solution lists, and the current write plan; the cards below are
 * presentational and receive everything as props.
 */
export default function App() {
    const styles = useStyles();
    const { connection, isLoading: connectionLoading } = useConnection();
    const inPptb = typeof window !== 'undefined' && !!window.toolboxAPI && !!window.dataverseAPI;
    const connKey = connectionKey(connection);

    // A fresh provider (and so a fresh metadata cache) per connection.
    const provider = useMemo(() => new PptbMetadataProvider(), [connKey]); // eslint-disable-line react-hooks/exhaustive-deps
    const sink = useMemo(() => new PptbFileSink(), []);
    const [settingsOpen, setSettingsOpen] = useState(false);
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

    /** Opens `folder` as the project and reads its `.dataverse-gen.json`; throws when it can't be read. */
    const openProjectFolder = useCallback(
        async (folder: string) => {
            const state = await loadProjectConfig(sink, folder);
            // A folder without .dataverse-gen.json starts from the Settings panel's project defaults.
            if (!state.exists) state.config = applyProjectDefaults(state.config, toolSettings.projectDefaults);
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
                const message = errorMessage(e);
                setError(
                    /access denied|permission/i.test(message)
                        ? `PPTB has not granted this tool access to ${folder}. Open it again with Load Existing Project to grant access.`
                        : `Could not load ${folder}: ${message}`,
                );
            }
        },
        [openProjectFolder],
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
            setNotice(null);
            try {
                // Listing the folder fails outright without access; a missing .dataverse-gen.json alone would
                // otherwise just look like a new project.
                await window.toolboxAPI.fileSystem.readDirectory(project.location);
                await openProjectFolder(project.location);
                return true;
            } catch (e) {
                if (!/access denied|permission|not allowed|not permitted/i.test(errorMessage(e))) throw e;
            }
            const folder = await window.toolboxAPI.fileSystem.selectPath({
                type: 'folder',
                title: `Open ${project.name}`,
                message: 'Confirm the project folder so Power Platform ToolBox lets the tool read it',
                defaultPath: project.location,
            });
            if (!folder) return false;
            await openProjectFolder(folder);
            return true;
        },
        [openProjectFolder],
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
    const saveToolSettings = useCallback(async (draft: ToolConfig) => {
        // Same normalization as on load, so e.g. a blank output folder saves as the default, not as "".
        const next = mergeToolConfig(draft);
        await saveToolConfig(next);
        setToolSettings(next);
    }, []);

    /** Adds a project from the New Project dialog to `projects` and saves the config. */
    const addProject = useCallback(
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

    /** Folder picker for the New Project dialog's Location; `null` when cancelled or outside PPTB. */
    const pickProjectLocation = useCallback(async (current: string) => {
        if (!window.toolboxAPI) return null;
        return window.toolboxAPI.fileSystem.selectPath({
            type: 'folder',
            title: 'Select the project location',
            defaultPath: current || undefined,
        });
    }, []);

    useEffect(() => {
        if (!inPptb || !connection) return;
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
            .catch((e) => !cancelled && setError(`Could not list tables: ${errorMessage(e)}`))
            .finally(() => !cancelled && setLoadingEntities(false));
        listSolutions()
            .then((list) => !cancelled && setSolutions(list))
            .catch((e) => console.warn('Could not list solutions', e));
        // PPTB only grants file access to folders picked with selectPath in the current session, so the
        // remembered folder cannot be read directly; it only pre-fills the folder picker.
        getRememberedProjectFolder(connKey).then((folder) => {
            if (!cancelled) setRememberedFolder(folder ?? null);
        });
        return () => {
            cancelled = true;
        };
        // Only re-run when the connection (and so the provider) changes.
    }, [provider, inPptb, connection]); // eslint-disable-line react-hooks/exhaustive-deps

    const ensureOperations = useCallback(() => {
        if (operations !== null || loadingOperations || !inPptb) return;
        setLoadingOperations(true);
        provider
            .listOperations()
            .then((list) => {
                setOperations(list);
                setMetadataFallback(provider.usesMetadataFallback);
            })
            .catch((e) => setError(`Could not load the $metadata document: ${errorMessage(e)}`))
            .finally(() => setLoadingOperations(false));
    }, [operations, loadingOperations, inPptb, provider]);

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
            setError(`Could not load the solution's tables: ${errorMessage(e)}`);
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
            .catch((e) => !cancelled && setError(`Could not load the solution's actions and functions: ${errorMessage(e)}`))
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
            setError(`Could not copy to the clipboard: ${errorMessage(e)}`);
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
            const files = generate(model, resolved);
            setProgress({ message: 'Comparing with the output folder…', completed: 0, total: 1 });
            const nextPlan = await createWritePlan(sink, projectRoot, resolved, files);
            setPlan(nextPlan);
            setPreviewedAt(new Date().toISOString());
            setLastResult(null);
            setPlanStale(false);
            return nextPlan;
        } catch (e) {
            setError(errorMessage(e));
            return null;
        } finally {
            setProgress(null);
        }
    }, [projectRoot, config, provider, sink]);

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
                    newFiles: applied.files.filter((f) => f.status === 'new').map((f) => f.relativePath),
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

    const runGenerate = useCallback(
        async (planToApply: WritePlan) => {
            if (!projectRoot) return;
            setError(null);
            try {
                setProgress({ message: 'Writing files…', completed: 0, total: planToApply.counts.new + planToApply.counts.changed });
                const result = await applyWritePlan(sink, planToApply, (completed, total, file) =>
                    setProgress({ message: `Wrote ${file.relativePath}`, completed, total }),
                );
                const configPath = await saveProjectConfig(sink, projectRoot, config);
                setConfigState((state) => ({ ...state, exists: true, path: configPath }));
                await recordProjectGeneration(projectRoot, planToApply);
                // Everything written is now unchanged.
                setPlan({
                    ...planToApply,
                    files: planToApply.files.map((f) => (f.status === 'new' || f.status === 'changed' ? { ...f, status: 'unchanged', existingContent: f.content } : f)),
                    counts: { new: 0, changed: 0, unchanged: planToApply.counts.unchanged + result.written, orphaned: planToApply.counts.orphaned },
                });
                const summary = `${result.written} file(s) written, ${planToApply.counts.unchanged} unchanged, ${planToApply.counts.orphaned} orphaned. Config saved to .dataverse-gen.json.`;
                setLastResult(
                    `${result.written} ${result.written === 1 ? 'file' : 'files'} written · ${planToApply.counts.unchanged} unchanged · ${planToApply.counts.orphaned} orphaned · .dataverse-gen.json saved`,
                );
                await window.toolboxAPI?.utils.showNotification({ title: 'Dataverse Early-Bound TypeScript Generator', body: summary, type: 'success' });
            } catch (e) {
                setError(`Generation failed: ${errorMessage(e)}`);
            } finally {
                setProgress(null);
            }
        },
        [projectRoot, config, sink, recordProjectGeneration],
    );

    // ----- derived --------------------------------------------------------------------------------

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
    const canSelect = inPptb && !!connection;
    const ready = canSelect && !!projectRoot;
    const steps = computeWorkflowSteps({
        hasProject: !!projectRoot,
        selectedCount: selected.entities.length + selected.actions.length + selected.functions.length,
        plan: plan ? { pending: plan.counts.new + plan.counts.changed, stale: planStale } : null,
    });

    /** Opens a project from the Project card's recent list; errors show in the page, a cancelled picker does nothing. */
    const openRecent = (target: ProjectOpenTarget) => {
        openSavedProject(target).catch((e: unknown) => setError(`Could not open ${target.name}: ${errorMessage(e)}`));
    };

    return (
        <div className={styles.page}>
            <Header connection={connection} onOpenSettings={() => setSettingsOpen(true)} />
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
                    onToggle={toggle}
                    onClear={clear}
                    onSolutionChange={changeSolution}
                    onEnsureOperations={ensureOperations}
                />
                <OptionsCard step={steps[2]} config={config} disabled={!canSelect || busy} onChange={updateConfig} />
                <PreviewCard
                    step={steps[3]}
                    plan={plan}
                    stale={planStale}
                    canPreview={ready && hasSelection}
                    needsProject={canSelect && !projectRoot}
                    busy={busy}
                    previewedAt={plan ? previewedAt : null}
                    lastResult={plan ? lastResult : null}
                    onPreview={() => void runPreview()}
                    onGenerate={() => plan && void runGenerate(plan)}
                    onCopyText={(text, label) => void copyPath(text, label)}
                />
            </main>
            <Footer />
        </div>
    );
}
