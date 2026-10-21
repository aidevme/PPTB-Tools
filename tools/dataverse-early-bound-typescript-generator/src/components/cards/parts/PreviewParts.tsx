/**
 * Parts of the Preview card: the action bar (Preview, Generate, the switches and Custom Templates, from
 * `popovers/CustomTemplatesPopover.tsx`), the custom enum template proposal
 * and the status tiles. They're presentational; `PreviewCard` holds the state. The file table is
 * `tables/FileTable.tsx`.
 */
import { Button, MessageBar, MessageBarActions, MessageBarBody, MessageBarTitle, Switch, Text, Tooltip, mergeClasses } from '@fluentui/react-components';
import { AddCircleRegular, CheckmarkCircleRegular, DocumentQuestionMarkRegular, DocumentSearchRegular, EditRegular, InfoRegular, SaveRegular, WarningRegular } from '@fluentui/react-icons';
import { CUSTOM_TEMPLATE_KINDS, type CustomTemplateSelection } from '../../../core';
import type { FileStatus, WritePlan } from '../../../types';
import { plural } from '../../../services';
import { usePreviewCardStyles } from '../../../styles';
import { formatRelativeTime } from '../../shared/format';
import { STATUS_META, STATUS_ORDER } from '../../shared/generatedFiles';
import { infoLabel } from '../../shared/infoLabel';
import { CustomTemplatesPopover } from '../../popovers/CustomTemplatesPopover';
import {
    CUSTOM_ENUM_TEMPLATE_INFO,
    CUSTOM_ENUM_TEMPLATE_TITLE,
    DELETE_ORPHANS_INFO,
    DELETE_ORPHANS_TITLE,
    RENAME_DUPLICATES_INFO,
    RENAME_DUPLICATES_TITLE,
    SKIP_DUPLICATES_INFO,
    SKIP_DUPLICATES_TITLE,
} from '../../shared/settingsInfo';

type PreviewCardStyles = ReturnType<typeof usePreviewCardStyles>;

const STATUS_ICONS: Record<FileStatus, JSX.Element> = {
    new: <AddCircleRegular />,
    changed: <EditRegular />,
    unchanged: <CheckmarkCircleRegular />,
    orphaned: <DocumentQuestionMarkRegular />,
    duplicate: <WarningRegular />,
};

/** The status tile's accent class, per status. */
const STATUS_ACCENT: Record<FileStatus, keyof PreviewCardStyles> = {
    new: 'accentNew',
    changed: 'accentChanged',
    unchanged: 'accentUnchanged',
    orphaned: 'accentOrphaned',
    duplicate: 'accentDuplicate',
};

/**
 * A Preview switch's explanation, plus why it's disabled: before the first preview nobody knows which files it
 * affects, and after one it stays disabled while the preview found none.
 */
const switchInfo = (info: JSX.Element, previewed: boolean, found: number, what: string) =>
    !previewed ? (
        <>
            {info} Available after Preview, once {what} are known.
        </>
    ) : found === 0 ? (
        <>
            {info} Disabled: the last preview found no {what}.
        </>
    ) : (
        info
    );

/** The Generate button's label: what it will write, or delete when there's nothing to write. */
function generateLabel(plan: WritePlan | null, writable: number, deletable: number): string {
    if (!plan) return 'Generate';
    if (writable > 0) return `Generate ${plural(writable, 'file', 'files')}`;
    if (deletable > 0) return `Delete ${plural(deletable, 'orphaned file', 'orphaned files')}`;
    return 'Nothing to write';
}

/** The Generate button's tooltip. */
function generateHelp(plan: WritePlan | null, writable: number, deletable: number): string {
    if (!plan) return 'Run Preview first';
    if (writable === 0 && deletable === 0) return 'Every generated file is already up to date';
    return [
        writable > 0 && 'Write the new and changed files and save .dataverse-gen.json',
        deletable > 0 && `${writable > 0 ? 'then delete' : 'Delete'} the orphaned files (asks for confirmation first)`,
    ]
        .filter(Boolean)
        .join(', ');
}

/** Every kind off: the Custom Templates choices of a project that has none. */
const NO_CUSTOM_TEMPLATES = Object.fromEntries(CUSTOM_TEMPLATE_KINDS.map((kind) => [kind, false])) as CustomTemplateSelection;

/** Props for {@link PreviewActionBar}. */
export interface IPreviewActionBarProps {
    /** The last computed write plan; `null` before the first preview disables Generate and the switches. */
    plan: WritePlan | null;
    /** The selection or options changed since the plan was computed; disables Generate until the next preview. */
    stale: boolean;
    /** Enables the Preview button (unless `busy`). */
    canPreview: boolean;
    /** Shows the "Open a project (step 1)" hint after the buttons. */
    needsProject: boolean;
    /** Work in progress: disables both buttons and the switches. */
    busy: boolean;
    /** When the plan was computed (ISO), shown as "Previewed … ago"; nothing is shown while `null`. */
    previewedAt: string | null;
    /** How many files Generate writes. */
    writable: number;
    /** Whether Generate also deletes the orphaned files; the Delete orphaned files switch shows it. */
    deleteOrphans: boolean;
    /** Called with the new value when the Delete orphaned files switch is toggled. */
    onDeleteOrphansChange: (checked: boolean) => void;
    /** Whether Generate leaves files with duplicate identifiers unwritten; the Skip switch shows it. */
    skipDuplicates: boolean;
    /** The switch is hidden without it. */
    onSkipDuplicatesChange?: (checked: boolean) => void;
    /**
     * Whether later duplicate enum members are renamed; the Rename switch shows it.
     * @defaultValue false
     */
    renameDuplicates?: boolean;
    /** The switch is hidden without it. */
    onRenameDuplicatesChange?: (checked: boolean) => void;
    /**
     * Whether the custom enum template is on; the Custom enum template switch shows it, and while it's on the Rename
     * switch shows on and disabled, since the custom template renames too.
     * @defaultValue false
     */
    customEnumTemplate?: boolean;
    /** Called with the new value when the Custom enum template switch is toggled; the switch is hidden without it. */
    onCustomEnumTemplateChange?: (checked: boolean) => void;
    /**
     * The project's Custom Templates choices, shown as checkboxes in the Custom Templates popover.
     * @defaultValue every kind off
     */
    customTemplates?: CustomTemplateSelection;
    /** Called with every kind's value when a Custom Templates checkbox changes; the button is hidden without it. */
    onCustomTemplatesChange?: (selection: CustomTemplateSelection) => void;
    /**
     * Disables the Custom Templates button (no project open); it's also disabled while `busy`.
     * @defaultValue false
     */
    customTemplatesDisabled?: boolean;
    /** Called when Preview is clicked. */
    onPreview: () => void;
    /** Called when Generate (or Delete orphaned files, when there's nothing to write) is clicked. */
    onGenerate: () => void;
    /** Current time for the "Previewed … ago" text; a parameter so tests get stable output. */
    now?: number;
}

/**
 * Preview and Generate with the "Previewed … ago" text and hints on one row, and below them the Delete orphaned files,
 * Rename duplicated identifier(s), Custom enum template and Skip duplicated identifier(s) switches and the Custom
 * Templates button on their own row.
 */
export function PreviewActionBar(props: IPreviewActionBarProps) {
    const { plan, stale, canPreview, needsProject, busy, previewedAt, writable, deleteOrphans, onDeleteOrphansChange, skipDuplicates, onPreview, onGenerate } = props;
    const styles = usePreviewCardStyles();
    const deletable = plan && deleteOrphans ? plan.counts.orphaned : 0;
    const customEnumTemplate = props.customEnumTemplate ?? false;
    // The custom enum template renames too, so while it's on renaming is on and its own switch can't turn it off.
    const renaming = (props.renameDuplicates ?? false) || customEnumTemplate;
    return (
        <div className={styles.actionArea}>
            <div className={styles.actionBar}>
                <Button icon={<DocumentSearchRegular />} disabled={!canPreview || busy} onClick={onPreview}>
                    Preview
                </Button>
                <Tooltip content={generateHelp(plan, writable, deletable)} relationship="description" withArrow>
                    <Button appearance="primary" icon={<SaveRegular />} disabled={!plan || stale || busy || writable + deletable === 0} onClick={onGenerate}>
                        {generateLabel(plan, writable, deletable)}
                    </Button>
                </Tooltip>
                {previewedAt && (
                    <Text size={200} className={styles.muted}>
                        Previewed {formatRelativeTime(previewedAt, props.now)}
                    </Text>
                )}
                {needsProject && (
                    <span className={styles.hint}>
                        <InfoRegular aria-hidden="true" />
                        <Text size={200}>Open a project (step 1) to preview and generate.</Text>
                    </span>
                )}
            </div>
            <div className={styles.switchRow}>
                {/* The switches only apply to files a preview found: they're disabled before a preview and while it found none
                    of their kind (orphaned files, or files with duplicate identifiers). Rename and Custom enum template stay
                    usable while on, since they remove the duplicates they act on; Rename is disabled while Custom enum template
                    is on. Their info labels show the same explanation as the Settings panel, plus the reason when disabled. */}
                <Switch
                    label={infoLabel(DELETE_ORPHANS_TITLE, switchInfo(DELETE_ORPHANS_INFO, !!plan, plan?.counts.orphaned ?? 0, 'orphaned files'))}
                    checked={deleteOrphans}
                    disabled={!plan || plan.counts.orphaned === 0 || busy}
                    onChange={(_, data) => onDeleteOrphansChange(data.checked)}
                />
                {props.onRenameDuplicatesChange && (
                    <Switch
                        label={infoLabel(
                            RENAME_DUPLICATES_TITLE,
                            customEnumTemplate ? (
                                <>
                                    {RENAME_DUPLICATES_INFO} On because {CUSTOM_ENUM_TEMPLATE_TITLE} is on.
                                </>
                            ) : (
                                // Once on, the preview has no duplicates left, but the switch must stay usable to turn it off.
                                switchInfo(RENAME_DUPLICATES_INFO, !!plan, (plan?.counts.duplicate ?? 0) + (props.renameDuplicates ? 1 : 0), 'files with duplicate identifiers')
                            ),
                        )}
                        checked={renaming}
                        disabled={customEnumTemplate || !plan || (plan.counts.duplicate === 0 && !props.renameDuplicates) || busy}
                        onChange={(_, data) => props.onRenameDuplicatesChange?.(data.checked)}
                    />
                )}
                {props.onCustomEnumTemplateChange && (
                    <Switch
                        label={infoLabel(
                            CUSTOM_ENUM_TEMPLATE_TITLE,
                            // Like Rename: usable once a preview found duplicates, and always while on, so it can be turned off.
                            switchInfo(CUSTOM_ENUM_TEMPLATE_INFO, !!plan, (plan?.counts.duplicate ?? 0) + (customEnumTemplate ? 1 : 0), 'files with duplicate identifiers'),
                        )}
                        checked={customEnumTemplate}
                        disabled={!plan || (plan.counts.duplicate === 0 && !customEnumTemplate) || busy}
                        onChange={(_, data) => props.onCustomEnumTemplateChange?.(data.checked)}
                    />
                )}
                {props.onCustomTemplatesChange && (
                    <CustomTemplatesPopover selection={props.customTemplates ?? NO_CUSTOM_TEMPLATES} disabled={busy || (props.customTemplatesDisabled ?? false)} onChange={props.onCustomTemplatesChange} />
                )}
                {props.onSkipDuplicatesChange && (
                    <Switch
                        label={infoLabel(SKIP_DUPLICATES_TITLE, switchInfo(SKIP_DUPLICATES_INFO, !!plan, plan?.counts.duplicate ?? 0, 'files with duplicate identifiers'))}
                        checked={skipDuplicates}
                        disabled={!plan || plan.counts.duplicate === 0 || busy}
                        onChange={(_, data) => props.onSkipDuplicatesChange?.(data.checked)}
                    />
                )}
            </div>
        </div>
    );
}

/** Props for {@link CustomEnumTemplateProposal}. */
export interface ICustomEnumTemplateProposalProps {
    /** How many files in the preview declare an enum member name more than once. */
    duplicateFiles: number;
    /** Whether Generate writes the templates (the tool config's `generateTemplates`); off, the CLI won't get the fix. */
    generateTemplates: boolean;
    /** Called when **Use custom enum template** is clicked; the caller turns the setting on and marks the preview stale. */
    onAccept: () => void;
    /** Called when **Not now** is clicked; the caller hides the proposal until the next preview, without saving anything. */
    onDismiss: () => void;
    /** Disables both buttons while work is in progress. */
    busy: boolean;
}

/**
 * The proposal a preview shows when files have duplicate identifiers: use the custom enum template, which renames the
 * later duplicates in the generated files and gives the dataverse-gen CLI an `enum.ejs` that does the same. Accepting
 * writes nothing; the files change on the next preview and Generate.
 */
export function CustomEnumTemplateProposal({ duplicateFiles, generateTemplates, onAccept, onDismiss, busy }: ICustomEnumTemplateProposalProps) {
    return (
        <MessageBar intent="warning" layout="multiline">
            <MessageBarBody>
                <MessageBarTitle>Duplicate identifiers found</MessageBarTitle>
                {plural(duplicateFiles, 'file declares', 'files declare')} an enum member name twice and won't compile. With the custom
                enum template, each later duplicate gets its value appended (for example <code>InProgress_700970000</code>), and the
                project's <code>enum.ejs</code> is replaced so the dataverse-gen CLI renames them the same way. Nothing changes until you
                preview again and generate. Renaming the labels in Dataverse is the lasting fix.
                {!generateTemplates && " Generate templates is off, so the CLI won't get the fix until it's turned on."}
            </MessageBarBody>
            <MessageBarActions>
                <Button size="small" appearance="primary" disabled={busy} onClick={onAccept}>
                    Use custom enum template
                </Button>
                <Button size="small" disabled={busy} onClick={onDismiss}>
                    Not now
                </Button>
            </MessageBarActions>
        </MessageBar>
    );
}

/** Props for {@link StatusTiles}. */
export interface IStatusTilesProps {
    /** The write plan whose per-status counts the tiles show; the duplicate tile appears only when it has some. */
    plan: WritePlan;
    /** The status the list is filtered to, or `null`. */
    selectedStatus: FileStatus | null;
    /** Called with the tile's status when a tile is clicked; the caller toggles the filter on or off. */
    onToggleStatus: (status: FileStatus) => void;
}

/** One tile per status with its count; clicking a tile filters the list to it, clicking it again shows all changes. */
export function StatusTiles({ plan, selectedStatus, onToggleStatus }: IStatusTilesProps) {
    const styles = usePreviewCardStyles();
    return (
        <div className={styles.tiles} role="group" aria-label="Filter by status">
            {/* The duplicate identifiers tile only appears when there are some. */}
            {STATUS_ORDER.filter((status) => status !== 'duplicate' || plan.counts.duplicate > 0).map((status) => {
                const pressed = selectedStatus === status;
                return (
                    <Tooltip key={status} content={`${STATUS_META[status].meaning} Click to ${pressed ? 'show all changes' : 'show only these'}.`} relationship="description" withArrow>
                        <button
                            type="button"
                            className={mergeClasses(styles.tile, styles[STATUS_ACCENT[status]], pressed && styles.tileSelected)}
                            aria-pressed={pressed}
                            onClick={() => onToggleStatus(status)}
                        >
                            <span className={styles.tileIcon} aria-hidden="true">
                                {STATUS_ICONS[status]}
                            </span>
                            <span className={styles.tileText}>
                                <span className={styles.tileCount}>{plan.counts[status]}</span>
                                <span className={styles.tileLabel}>{STATUS_META[status].label}</span>
                            </span>
                        </button>
                    </Tooltip>
                );
            })}
        </div>
    );
}
