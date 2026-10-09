import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { MessageBar, MessageBarBody, MessageBarTitle, ProgressBar, Text, makeStyles, tokens } from '@fluentui/react-components';
import { Footer } from './components/Footer';
import { Header } from './components/Header';
import { OptionsCard } from './components/OptionsCard';
import { PreviewCard } from './components/PreviewCard';
import { ProjectCard } from './components/ProjectCard';
import { SelectionCard, type SelectionKind } from './components/SelectionCard';
import { buildSchemaModel, generate, resolveConfig, resolveSelection, type DataverseGenConfig, type EntityMetadataInput } from './core';
import { useConnection } from './hooks/useConnection';
import { PptbFileSink } from './services/fileSink';
import { PptbMetadataProvider } from './services/metadataProvider';
import { applyWritePlan, createWritePlan } from './services/plan';
import { loadProjectConfig, saveProjectConfig, type ProjectConfigState } from './services/projectConfig';
import { connectionKey, getRememberedProjectFolder, rememberProjectFolder } from './services/settings';
import { getSolutionEntityIds, listSolutions } from './services/solutions';
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

    const [projectRoot, setProjectRoot] = useState<string | null>(null);
    /** Folder used last time with this connection; shown as a hint and used as the picker's default. */
    const [rememberedFolder, setRememberedFolder] = useState<string | null>(null);
    const [configState, setConfigState] = useState<ProjectConfigState | null>(null);
    const [entities, setEntities] = useState<EntitySummary[]>([]);
    const [operations, setOperations] = useState<OperationSummary[] | null>(null);
    const [solutions, setSolutions] = useState<SolutionSummary[]>([]);
    const [selectedSolutionId, setSelectedSolutionId] = useState<string | null>(null);
    const [solutionEntityIds, setSolutionEntityIds] = useState<Set<string> | null>(null);
    const [loadingEntities, setLoadingEntities] = useState(false);
    const [loadingOperations, setLoadingOperations] = useState(false);
    const [loadingSolution, setLoadingSolution] = useState(false);
    const [plan, setPlan] = useState<WritePlan | null>(null);
    const [planStale, setPlanStale] = useState(false);
    const [progress, setProgress] = useState<Progress | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [notice, setNotice] = useState<string | null>(null);
    const solutionCache = useRef(new Map<string, Set<string>>());

    const config = configState?.config;
    const busy = progress !== null;

    // ----- project folder -------------------------------------------------------------------------

    const loadProject = useCallback(
        async (folder: string) => {
            setError(null);
            setNotice(null);
            try {
                const state = await loadProjectConfig(sink, folder);
                setProjectRoot(folder);
                setConfigState(state);
                setPlan(null);
                setPlanStale(false);
                await rememberProjectFolder(connKey, folder);
            } catch (e) {
                const message = errorMessage(e);
                setError(
                    /access denied|permission/i.test(message)
                        ? `PPTB has not granted this tool access to ${folder}. Click Browse… and select the folder again to grant access.`
                        : `Could not load ${folder}: ${message}`,
                );
            }
        },
        [sink, connKey],
    );

    const browse = useCallback(async () => {
        if (!window.toolboxAPI) return;
        try {
            // selectPath is also what grants this tool file-system access to the chosen folder.
            const folder = await window.toolboxAPI.fileSystem.selectPath({
                type: 'folder',
                title: 'Select the project folder',
                message: 'Pick the folder that contains (or should contain) .dataverse-gen.json',
                defaultPath: projectRoot ?? rememberedFolder ?? undefined,
            });
            if (folder) await loadProject(folder);
        } catch (e) {
            setError(`Could not open the folder picker: ${errorMessage(e)}`);
        }
    }, [loadProject, projectRoot, rememberedFolder]);

    // ----- environment lists ----------------------------------------------------------------------

    useEffect(() => {
        if (!inPptb || !connection) return;
        let cancelled = false;
        setEntities([]);
        setOperations(null);
        setSolutions([]);
        setSelectedSolutionId(null);
        setSolutionEntityIds(null);
        solutionCache.current.clear();
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
            .then(setOperations)
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

    // ----- config edits ---------------------------------------------------------------------------

    const updateConfig = useCallback((update: Partial<DataverseGenConfig>) => {
        setConfigState((state) => (state ? { ...state, config: { ...state.config, ...update } } : state));
        setPlanStale(true);
        setNotice(null);
    }, []);

    const toggle = useCallback(
        (kind: SelectionKind, name: string, checked: boolean) => {
            const current = config?.[kind] ?? [];
            const next = checked ? (current.includes(name) ? current : [...current, name]) : current.filter((n) => n !== name);
            updateConfig({ [kind]: next });
        },
        [config, updateConfig],
    );

    const clear = useCallback((kind: SelectionKind) => updateConfig({ [kind]: [] }), [updateConfig]);

    // ----- preview / generate ---------------------------------------------------------------------

    const runPreview = useCallback(async (): Promise<WritePlan | null> => {
        if (!projectRoot || !config) return null;
        setError(null);
        setNotice(null);
        try {
            const resolved = resolveConfig(config);
            setProgress({ message: 'Loading the $metadata document…', completed: 0, total: 1 });
            const schema = await provider.getSchema();
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
            setPlanStale(false);
            return nextPlan;
        } catch (e) {
            setError(errorMessage(e));
            return null;
        } finally {
            setProgress(null);
        }
    }, [projectRoot, config, provider, sink]);

    const runGenerate = useCallback(
        async (planToApply: WritePlan) => {
            if (!projectRoot || !config) return;
            setError(null);
            try {
                setProgress({ message: 'Writing files…', completed: 0, total: planToApply.counts.new + planToApply.counts.changed });
                const result = await applyWritePlan(sink, planToApply, (completed, total, file) =>
                    setProgress({ message: `Wrote ${file.relativePath}`, completed, total }),
                );
                const configPath = await saveProjectConfig(sink, projectRoot, config);
                setConfigState((state) => (state ? { ...state, exists: true, path: configPath } : state));
                // Everything written is now unchanged.
                setPlan({
                    ...planToApply,
                    files: planToApply.files.map((f) => (f.status === 'new' || f.status === 'changed' ? { ...f, status: 'unchanged', existingContent: f.content } : f)),
                    counts: { new: 0, changed: 0, unchanged: planToApply.counts.unchanged + result.written, orphaned: planToApply.counts.orphaned },
                });
                const summary = `${result.written} file(s) written, ${planToApply.counts.unchanged} unchanged, ${planToApply.counts.orphaned} orphaned. Config saved to .dataverse-gen.json.`;
                setNotice(summary);
                await window.toolboxAPI?.utils.showNotification({ title: 'Dataverse Type Forge', body: summary, type: 'success' });
            } catch (e) {
                setError(`Generation failed: ${errorMessage(e)}`);
            } finally {
                setProgress(null);
            }
        },
        [projectRoot, config, sink],
    );

    const regenerate = useCallback(async () => {
        const nextPlan = await runPreview();
        if (nextPlan) await runGenerate(nextPlan);
    }, [runPreview, runGenerate]);

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
    const ready = inPptb && !!connection && !!projectRoot && !!config;

    return (
        <div className={styles.page}>
            <Header connection={connection} canRegenerate={ready && hasSelection} busy={busy} onRegenerate={regenerate} />
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
                <ProjectCard projectRoot={projectRoot} rememberedFolder={rememberedFolder} configState={configState} busy={busy || !inPptb} onBrowse={browse} onReload={() => projectRoot && loadProject(projectRoot)} />
                <SelectionCard
                    entities={entities}
                    operations={operations}
                    solutions={solutions}
                    solutionEntityIds={solutionEntityIds}
                    selectedSolutionId={selectedSolutionId}
                    loadingEntities={loadingEntities}
                    loadingOperations={loadingOperations}
                    loadingSolution={loadingSolution}
                    selected={selected}
                    missing={missing}
                    disabled={!ready || busy}
                    onToggle={toggle}
                    onClear={clear}
                    onSolutionChange={changeSolution}
                    onEnsureOperations={ensureOperations}
                />
                {config && <OptionsCard config={config} disabled={!ready || busy} onChange={updateConfig} />}
                <PreviewCard plan={plan} stale={planStale} canPreview={ready && hasSelection} busy={busy} onPreview={() => void runPreview()} onGenerate={() => plan && void runGenerate(plan)} />
            </main>
            <Footer />
        </div>
    );
}
