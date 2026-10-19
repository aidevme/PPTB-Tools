import { useMemo, useState } from 'react';
import { Button, MessageBar, MessageBarActions, MessageBarBody, Skeleton, SkeletonItem, Switch, Text, mergeClasses, type SortDirection } from '@fluentui/react-components';
import { ArrowSyncRegular } from '@fluentui/react-icons';
import type { FileStatus, WritePlan } from '../../types';
import { summarizePlan, writeCounts } from '../../services';
import { usePreviewCardStyles } from '../../styles';
import { infoLabel } from '../shared/infoLabel';
import { MIN_LIST_WIDTH, sortFiles, isSearchActive, visibleFiles, type FileFilter, type FileSortColumn } from '../shared/previewFiles';
import { PathChip } from '../shared/PathChip';
import { nextSort } from '../shared/sorting';
import { StepCard } from '../shared/StepCard';
import { useResizableSplit } from '../shared/useResizableSplit';
import type { StepState } from '../shared/workflowSteps';
import { FileViewer } from '../viewers/FileViewer';
import { FileSearchBox } from '../shared/FileSearchBox';
import { FileTable } from '../tables/FileTable';
import { CustomEnumTemplateProposal, PreviewActionBar, StatusTiles } from './PreviewParts';

/** Explanation in the Show unchanged switch's info label. */
const SHOW_UNCHANGED_INFO = (
    <>
        By default the list shows only what needs attention: new, changed and orphaned files, and files with duplicate identifiers.
        Turn this on to list the unchanged files too: generated files identical to the ones in the output folder, which Generate
        doesn't rewrite. It only changes the list, not what Generate does, and isn't saved. It's disabled while a status tile
        filters the list (click the tile again to go back to the full list) and while a search is active, since a search
        includes unchanged files.
    </>
);

/** The Generate settings the Preview card shows as switches; each saves a tool-config key. */
export interface IPreviewGenerateOptions {
    /** Whether Generate leaves files with duplicate identifiers unwritten (the tool config's `skipDuplicateIdentifiers`). */
    skipDuplicates?: boolean;
    /** The Skip duplicated identifier(s) switch; saves `skipDuplicateIdentifiers`. The switch is hidden without it. */
    onSkipDuplicatesChange?: (checked: boolean) => void;
    /** Whether later duplicate enum members are renamed (the tool config's `renameDuplicateIdentifiers`). */
    renameDuplicates?: boolean;
    /** The Rename duplicated identifier(s) switch; saves `renameDuplicateIdentifiers`. The switch is hidden without it. */
    onRenameDuplicatesChange?: (checked: boolean) => void;
    /**
     * Whether the project uses the custom enum template (its `pptbEarlyBoundGenerator.customEnumTemplate`, or the
     * Settings default).
     * @defaultValue false
     */
    customEnumTemplate?: boolean;
    /**
     * Whether Generate writes the templates (the tool config's `generateTemplates`); the proposal mentions when it's off.
     * @defaultValue true
     */
    generateTemplates?: boolean;
    /**
     * Saves the project's custom enum template: called with `true` when the proposal is accepted. Without it, no
     * proposal is shown.
     */
    onCustomEnumTemplateChange?: (checked: boolean) => void;
    /** Whether Generate also deletes orphaned files (the tool config's `deleteOrphanedFiles`). */
    deleteOrphans: boolean;
    /** Called with the new value when the Delete orphaned files switch is toggled; saves `deleteOrphanedFiles`. */
    onDeleteOrphansChange: (checked: boolean) => void;
}

/** Props for {@link PreviewCard}. */
export interface IPreviewCardProps {
    /** The card's step in the workflow: number, title and completion badge. */
    step: StepState;
    /** The last computed write plan, or `null` before the first preview (the list shows a placeholder). */
    plan: WritePlan | null;
    /** Whether the plan is stale because the selection or options changed since it was computed. */
    stale: boolean;
    /** Enables Preview and the stale warning's Preview again; the app sets it once connected, with a selection. */
    canPreview: boolean;
    /** True when everything is ready except the project folder; shows a hint next to the buttons. */
    needsProject: boolean;
    /** Work in progress: disables the buttons and switches, and shows a loading skeleton while there's no plan yet. */
    busy: boolean;
    /** When the current plan was computed (ISO), for "Previewed … ago". */
    previewedAt: string | null;
    /** Summary of the last Generate run, shown as a success message until the next preview. */
    lastResult: string | null;
    /** The Generate settings shown as switches in the action bar. */
    generateOptions: IPreviewGenerateOptions;
    /** Called when Preview or Preview again is clicked, to compute a new plan. */
    onPreview: () => void;
    /** Called when Generate is clicked; the caller confirms where needed, then writes (and deletes) the files. */
    onGenerate: () => void;
    /** Copies text (a file's content or a path) to the clipboard; `label` names it in the confirmation. */
    onCopyText: (text: string, label: string) => void;
    /** Current time for relative dates; a parameter so tests get stable output. */
    now?: number;
}

/**
 * Steps 4 and 5: preview what Generate would do, then write it. Status tiles summarise and filter the files;
 * the table lists them (changes only by default) beside a viewer showing each file's content or changes. The
 * action bar, tiles and table are in `PreviewParts.tsx`.
 */
export function PreviewCard(props: IPreviewCardProps) {
    const { step, plan, stale, canPreview, busy, lastResult, generateOptions, onPreview, onCopyText } = props;
    const { deleteOrphans } = generateOptions;
    const skipDuplicates = generateOptions.skipDuplicates ?? false;
    const styles = usePreviewCardStyles();
    const [selectedPath, setSelectedPath] = useState<string | null>(null);
    const [filter, setFilter] = useState<FileFilter>({ status: null, showUnchanged: false, search: '' });
    const [sort, setSort] = useState<{ column: FileSortColumn; direction: SortDirection } | null>(null);
    const { listWidth, splitRef, startResize, onSplitterKeyDown } = useResizableSplit();
    // The preview (by its time) the custom enum template proposal was dismissed for; a new preview shows it again.
    const [proposalDismissedFor, setProposalDismissedFor] = useState<string | null>(null);
    const showProposal =
        !!plan &&
        plan.counts.duplicate > 0 &&
        !generateOptions.customEnumTemplate &&
        !!generateOptions.onCustomEnumTemplateChange &&
        proposalDismissedFor !== props.previewedAt;

    const files = useMemo(() => (plan ? sortFiles(visibleFiles(plan.files, filter), sort) : []), [plan, filter, sort]);
    const selected = plan?.files.find((f) => f.relativePath === selectedPath) ?? null;
    const writes = useMemo(() => (plan ? writeCounts(plan, { skipDuplicates }) : { created: 0, overwritten: 0 }), [plan, skipDuplicates]);

    const toggleSort = (column: FileSortColumn) => setSort((current) => nextSort(current, column));
    const sortDirection = (column: FileSortColumn) => (sort?.column === column ? sort.direction : undefined);
    const toggleStatus = (status: FileStatus) => setFilter((f) => ({ ...f, status: f.status === status ? null : status }));

    return (
        <StepCard
            step={step}
            description={
                deleteOrphans
                    ? 'Preview compares the generated files with the output folder; Generate writes only new and changed files, then deletes orphaned files after you confirm.'
                    : 'Preview compares the generated files with the output folder; Generate writes only new and changed files and never deletes anything.'
            }
        >
            <div className={styles.body}>
                {plan && stale && (
                    <MessageBar intent="warning">
                        <MessageBarBody>The selection or options changed since this preview.</MessageBarBody>
                        <MessageBarActions>
                            <Button size="small" icon={<ArrowSyncRegular />} disabled={!canPreview || busy} onClick={onPreview}>
                                Preview again
                            </Button>
                        </MessageBarActions>
                    </MessageBar>
                )}
                {lastResult && (
                    <MessageBar intent="success">
                        <MessageBarBody>{lastResult}</MessageBarBody>
                    </MessageBar>
                )}
                {showProposal && (
                    <CustomEnumTemplateProposal
                        duplicateFiles={plan.counts.duplicate}
                        generateTemplates={generateOptions.generateTemplates ?? true}
                        onAccept={() => generateOptions.onCustomEnumTemplateChange?.(true)}
                        onDismiss={() => setProposalDismissedFor(props.previewedAt)}
                        busy={busy}
                    />
                )}

                <PreviewActionBar
                    plan={plan}
                    stale={stale}
                    canPreview={canPreview}
                    needsProject={props.needsProject}
                    busy={busy}
                    previewedAt={props.previewedAt}
                    writable={writes.created + writes.overwritten}
                    {...generateOptions}
                    skipDuplicates={skipDuplicates}
                    onPreview={onPreview}
                    onGenerate={props.onGenerate}
                    now={props.now}
                />

                {plan && (
                    <>
                        <Text className={styles.summary}>{summarizePlan(plan.counts, deleteOrphans, writes, skipDuplicates)}</Text>
                        <StatusTiles plan={plan} selectedStatus={filter.status} onToggleStatus={toggleStatus} />
                        <div className={styles.outputRow}>
                            <Text size={200} className={styles.muted}>
                                Output folder
                            </Text>
                            <PathChip path={plan.outputRoot} label="Output folder path" onCopy={onCopyText} maxLength={64} appearance="filled" />
                        </div>
                        <div className={styles.filterBar}>
                            <FileSearchBox value={filter.search} onChange={(search) => setFilter((f) => ({ ...f, search }))} />
                            <Switch
                                label={infoLabel('Show unchanged', SHOW_UNCHANGED_INFO)}
                                checked={filter.showUnchanged}
                                // A status tile or an active search already decides whether unchanged files are listed.
                                disabled={filter.status !== null || isSearchActive(filter.search)}
                                onChange={(_, data) => setFilter((f) => ({ ...f, showUnchanged: data.checked }))}
                            />
                            <Text size={200} className={styles.muted} aria-live="polite">
                                Showing {files.length} of {plan.files.length} files
                            </Text>
                        </div>
                    </>
                )}

                <div className={styles.split} ref={splitRef}>
                    <div className={mergeClasses(styles.panel, styles.list)} style={{ width: listWidth }}>
                        {!plan && busy ? (
                            <Skeleton className={styles.skeleton} aria-label="Loading the preview">
                                {Array.from({ length: 8 }, (_, i) => (
                                    <SkeletonItem key={i} size={20} />
                                ))}
                            </Skeleton>
                        ) : !plan ? (
                            <div className={styles.placeholder}>No preview yet. Click Preview to see what Generate would write.</div>
                        ) : files.length === 0 ? (
                            <div className={styles.placeholder}>
                                {filter.search ? 'No files match the search.' : filter.status ? 'No files with this status.' : 'Nothing to write. Turn on Show unchanged to list every file.'}
                            </div>
                        ) : (
                            <FileTable files={files} selectedPath={selectedPath} onSelect={setSelectedPath} sortDirection={sortDirection} onToggleSort={toggleSort} />
                        )}
                    </div>
                    <div
                        className={styles.splitter}
                        role="separator"
                        aria-orientation="vertical"
                        aria-label="Resize the file list"
                        aria-valuenow={listWidth}
                        aria-valuemin={MIN_LIST_WIDTH}
                        tabIndex={0}
                        onPointerDown={startResize}
                        onKeyDown={onSplitterKeyDown}
                    />
                    <div className={mergeClasses(styles.panel, styles.viewer)}>
                        <FileViewer file={selected} onCopyText={onCopyText} skipDuplicates={skipDuplicates} />
                    </div>
                </div>
            </div>
        </StepCard>
    );
}

/** @deprecated Renamed to `IPreviewCardProps`. */
export type PreviewCardProps = IPreviewCardProps;
