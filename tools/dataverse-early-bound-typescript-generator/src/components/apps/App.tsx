import { useCallback, useMemo, useRef, useState } from 'react';
import { MessageBar, MessageBarBody, MessageBarTitle, ProgressBar, Text } from '@fluentui/react-components';
import { Footer, GenerateConfirmationDialogs, Header, LoadProjectDialog, ProjectFormDialog, OptionsCard, PreviewCard, ProjectCard, SelectionCard, SettingsPanel, WorkflowProgress, computeWorkflowSteps, type NewProject, type ProjectOpenTarget, type SelectionKind } from '..';
import { useConnection, useEnvironmentMetadata, usePlanState, usePreviewGenerate, useProject, useStickyBarHeights, useToolSettings } from '../../hooks';
import { PptbFileSink, PptbMetadataProvider, connectionKey, pendingWriteCount, reportError } from '../../services';
import { useAppStyles } from '../../styles';

/**
 * Top-level orchestration. The state lives in hooks (`hooks/`): the tool config (`useToolSettings`), the project
 * folder and its `.dataverse-gen.json` (`useProject`), the environment's table / operation / solution lists
 * (`useEnvironmentMetadata`), and the write plan with Preview and Generate (`usePlanState`, `usePreviewGenerate`).
 * App wires them together; the cards below are presentational and receive everything as props.
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
    const [newProjectOpen, setNewProjectOpen] = useState(false);
    const [loadProjectOpen, setLoadProjectOpen] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const planState = usePlanState();
    const { plan, previewedAt, lastResult, planStale, clearPlan, resetPlan, markPlanStale } = planState;
    const { toolSettings, saveToolSettings, saveNewProject, deleteProject, editProject, recordProjectGeneration, changeSetting } = useToolSettings({
        onError: setError,
        onPlanStale: markPlanStale,
    });
    const { projectRoot, rememberedFolder, configState, config, loadProject, openSavedProject, pickProjectLocation, updateConfig, markConfigSaved, toggle, clear } = useProject({
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
    const { progress, busy, runPreview, startGenerate, confirmDeleteOpen, confirmDelete, cancelDelete, confirmGenerateOpen, confirmGenerate, cancelGenerate } = usePreviewGenerate({
        planState,
        projectRoot,
        config,
        provider,
        sink,
        toolSettings,
        recordProjectGeneration,
        markConfigSaved,
        noteMetadataFallback,
        setError,
    });

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
            <ProjectFormDialog
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
                    onCopyPath={(path, label) => void copyPath(path, label)}
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
            <GenerateConfirmationDialogs
                plan={plan}
                skipDuplicates={skipDuplicates}
                deleteOpen={confirmDeleteOpen}
                onConfirmDelete={confirmDelete}
                onCancelDelete={cancelDelete}
                generateOpen={confirmGenerateOpen}
                onConfirmGenerate={confirmGenerate}
                onCancelGenerate={cancelGenerate}
            />
            <div ref={footerRef} className={styles.stickyFooter}>
                <Footer />
            </div>
        </div>
    );
}
