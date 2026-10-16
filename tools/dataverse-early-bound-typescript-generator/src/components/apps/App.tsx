import { useCallback, useMemo, useRef, useState } from 'react';
import { MessageBar, MessageBarBody, MessageBarTitle, ProgressBar, Text } from '@fluentui/react-components';
import { DeleteRegular, SaveRegular } from '@fluentui/react-icons';
import { ConfirmationDialog, Footer, GenerateSummary, Header, LoadProjectDialog, OrphanList, NewProjectDialog, OptionsCard, PreviewCard, ProjectCard, SelectionCard, SettingsPanel, WorkflowProgress, computeWorkflowSteps, type NewProject, type ProjectOpenTarget, type SelectionKind } from '..';
import { buildSchemaModel, generate, resolveConfig, resolveSelection, type EntityMetadataInput } from '../../core';
import { useConnection, useEnvironmentMetadata, usePlanState, useProject, useStickyBarHeights, useToolSettings } from '../../hooks';
import {
    PptbFileSink,
    PptbMetadataProvider,
    applyWritePlan,
    connectionKey,
    countStatuses,
    createWritePlan,
    dataverseGenTemplateFiles,
    deleteOrphanedFiles,
    notifyGenerationComplete,
    notifyPreviewReady,
    pendingWriteCount,
    reportError,
    resolveOutputRoot,
    saveProjectConfig,
    summarizeGeneration,
    willWrite,
    writeCounts,
} from '../../services';
import { useAppStyles } from '../../styles';
import type { Progress, WritePlan } from '../../types';

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
    const [progress, setProgress] = useState<Progress | null>(null);
    const [error, setError] = useState<string | null>(null);
    const { plan, setPlan, previewedAt, setPreviewedAt, lastResult, setLastResult, planStale, setPlanStale, clearPlan, resetPlan, markPlanStale } = usePlanState();
    const { toolSettings, saveToolSettings, saveNewProject, deleteProject, editProject, recordProjectGeneration, changeSetting } = useToolSettings({
        onError: setError,
        onPlanStale: markPlanStale,
    });
    const { projectRoot, rememberedFolder, configState, config, loadProject, openSavedProject, pickProjectLocation, updateConfig, markConfigSaved, toggle, clear, clearAll } = useProject({
        sink,
        connKey,
        inPptb,
        connection,
        projectDefaults: toolSettings.projectDefaults,
        showProjectLoaded: toolSettings.general.showProjectLoadedNotification,
        setError,
        resetPlan,
        markPlanStale,
    });
    const selected = useMemo<Record<SelectionKind, string[]>>(
        () => ({ entities: config.entities ?? [], actions: config.actions ?? [], functions: config.functions ?? [] }),
        [config],
    );
    /** Tables, solutions and the selection are only listed once a project is open (created or loaded). */
    const hasProject = !!projectRoot;
    const {
        showMetadataFallbackWarning,
        noteMetadataFallback,
        entities,
        operations,
        solutions,
        selectedSolutionId,
        solutionEntityIds,
        solutionComponentIds,
        loadingEntities,
        loadingOperations,
        loadingSolution,
        ensureOperations,
        changeSolution,
        missing,
    } = useEnvironmentMetadata({ provider, inPptb, connection, hasProject, selected, setError, clearPlan });

    const busy = progress !== null;

    /**
     * Adds a project from the New Project dialog, saves the config, and opens the project, which also lists the
     * tables. A failure to save stays in the dialog; a failure to open shows in the page, since the project was saved.
     */
    const addProject = useCallback(
        async (project: NewProject) => {
            await saveNewProject(project);
            openSavedProject(project).catch((e: unknown) => setError(reportError(`Could not open ${project.name}`, e, { location: project.location })));
        },
        [saveNewProject, openSavedProject],
    );

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
        try {
            const resolved = resolveConfig(config);
            setProgress({ message: 'Loading the $metadata document…', completed: 0, total: 1 });
            const schema = await provider.getSchemaForSelection(resolved.actions, resolved.functions);
            noteMetadataFallback();
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
        noteMetadataFallback,
        sink,
        toolSettings.deleteOrphanedFiles,
        toolSettings.skipDuplicateIdentifiers,
        toolSettings.renameDuplicateIdentifiers,
        toolSettings.general.showPreviewReadyNotification,
    ]);

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
                markConfigSaved(configPath);
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
        [projectRoot, config, sink, markConfigSaved, recordProjectGeneration, toolSettings.skipDuplicateIdentifiers, toolSettings.general.showGenerationCompleteNotification],
    );

    /**
     * Generate: deleting orphans always needs a confirmation, which also covers the writes; otherwise "Ask before
     * generating" asks first, or it writes straight away.
     */
    const startGenerate = () => {
        if (!plan) return;
        if (toolSettings.deleteOrphanedFiles && plan.counts.orphaned > 0) setConfirmDeleteOpen(true);
        else if (toolSettings.confirmBeforeGenerate && pendingWriteCount(plan, { skipDuplicates }) > 0) setConfirmGenerateOpen(true);
        else void runGenerate(plan, false);
    };

    // ----- derived --------------------------------------------------------------------------------

    const skipDuplicates = toolSettings.skipDuplicateIdentifiers;

    const hasSelection = selected.entities.length + selected.actions.length + selected.functions.length > 0;
    /** Lists can be browsed and selected once connected; preview and generate also need a project folder. */
    const connected = inPptb && !!connection;
    const canSelect = connected && hasProject;
    const steps = computeWorkflowSteps({
        hasProject: !!projectRoot,
        selectedCount: selected.entities.length + selected.actions.length + selected.functions.length,
        plan: plan ? { pending: pendingWriteCount(plan, { skipDuplicates }) + (toolSettings.deleteOrphanedFiles ? plan.counts.orphaned : 0), stale: planStale } : null,
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
                    loadingSolution={loadingSolution}
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
                    canPreview={canSelect && hasSelection}
                    needsProject={connected && !projectRoot}
                    busy={busy}
                    previewedAt={plan ? previewedAt : null}
                    lastResult={plan ? lastResult : null}
                    onPreview={() => void runPreview()}
                    deleteOrphans={toolSettings.deleteOrphanedFiles}
                    skipDuplicates={skipDuplicates}
                    onSkipDuplicatesChange={(checked) => void changeSetting('skipDuplicateIdentifiers', checked)}
                    renameDuplicates={toolSettings.renameDuplicateIdentifiers}
                    onRenameDuplicatesChange={(checked) => void changeSetting('renameDuplicateIdentifiers', checked)}
                    onDeleteOrphansChange={(checked) => void changeSetting('deleteOrphanedFiles', checked)}
                    onGenerate={startGenerate}
                    onCopyText={(text, label) => void copyPath(text, label)}
                />
            </main>
            <ConfirmationDialog
                open={confirmDeleteOpen && !!plan}
                title="Delete orphaned files?"
                message={plan && <OrphanList plan={plan} />}
                confirmLabel={
                    plan && pendingWriteCount(plan, { skipDuplicates }) > 0
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
                confirmLabel={`Generate ${plan ? pendingWriteCount(plan, { skipDuplicates }) : 0} ${plan && pendingWriteCount(plan, { skipDuplicates }) === 1 ? 'file' : 'files'}`}
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
