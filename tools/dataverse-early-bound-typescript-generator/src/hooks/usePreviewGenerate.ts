import { useCallback, useState } from 'react';
import type { ToolConfig } from '../config';
import { buildSchemaModel, generate, resolveConfig, resolveSelection, type DataverseGenConfig, type EntityMetadataInput } from '../core';
import {
    applyWritePlan,
    countStatuses,
    createWritePlan,
    dataverseGenTemplateFiles,
    deleteOrphanedFiles,
    notifyGenerationComplete,
    notifyPreviewReady,
    pendingWriteCount,
    reportError,
    saveProjectConfig,
    summarizeGeneration,
    willWrite,
    writeCounts,
    type FileSink,
    type PptbMetadataProvider,
} from '../services';
import type { Progress, WritePlan } from '../types';
import type { PlanState } from './usePlanState';

export interface UsePreviewGenerateOptions {
    /** The write plan and its status, from {@link usePlanState}. */
    planState: PlanState;
    projectRoot: string | null;
    config: DataverseGenConfig;
    provider: PptbMetadataProvider;
    sink: FileSink;
    toolSettings: ToolConfig;
    /** Updates the saved project after a Generate run (see `useToolSettings`). */
    recordProjectGeneration: (root: string, applied: WritePlan) => Promise<void>;
    /** Records that Generate saved `.dataverse-gen.json` at `path` (see `useProject`). */
    markConfigSaved: (path: string) => void;
    /** Shows the "$metadata is too large" warning if the provider fell back (see `useEnvironmentMetadata`). */
    noteMetadataFallback: () => void;
    /** Shows an error in the page (the error bar), or clears it with `null`. */
    setError: (message: string | null) => void;
}

/**
 * Preview and Generate: builds the write plan from the selection and the environment's metadata, writes it, and
 * asks for confirmation first when Generate deletes orphaned files or "Ask before generating" is on. `progress` is
 * set while either runs.
 */
export function usePreviewGenerate({
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
}: UsePreviewGenerateOptions) {
    const { plan, setPlan, setPreviewedAt, setLastResult, setPlanStale } = planState;
    const [progress, setProgress] = useState<Progress | null>(null);
    /** Whether the dialog confirming that Generate will delete orphaned files is open. */
    const [confirmDeleteOpen, setConfirmDeleteOpen] = useState(false);
    /** Whether the dialog confirming Generate (the "Ask before generating" setting) is open. */
    const [confirmGenerateOpen, setConfirmGenerateOpen] = useState(false);

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
        setError,
        setPlan,
        setPreviewedAt,
        setLastResult,
        setPlanStale,
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
        [
            projectRoot,
            config,
            sink,
            setError,
            setPlan,
            setLastResult,
            markConfigSaved,
            recordProjectGeneration,
            toolSettings.skipDuplicateIdentifiers,
            toolSettings.general.showGenerationCompleteNotification,
        ],
    );

    /**
     * Generate: deleting orphans always needs a confirmation, which also covers the writes; otherwise "Ask before
     * generating" asks first, or it writes straight away.
     */
    const startGenerate = () => {
        if (!plan) return;
        if (toolSettings.deleteOrphanedFiles && plan.counts.orphaned > 0) setConfirmDeleteOpen(true);
        else if (toolSettings.confirmBeforeGenerate && pendingWriteCount(plan, { skipDuplicates: toolSettings.skipDuplicateIdentifiers }) > 0) setConfirmGenerateOpen(true);
        else void runGenerate(plan, false);
    };

    return {
        progress,
        busy: progress !== null,
        runPreview,
        runGenerate,
        startGenerate,
        confirmDeleteOpen,
        setConfirmDeleteOpen,
        confirmGenerateOpen,
        setConfirmGenerateOpen,
    };
}
