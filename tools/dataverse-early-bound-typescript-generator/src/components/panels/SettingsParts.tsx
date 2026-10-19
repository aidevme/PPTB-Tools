import { useCallback, useEffect, useId, useState, type ReactElement, type ReactNode } from 'react';
import {
    Badge,
    Button,
    Caption1,
    Card,
    InfoLabel,
    MessageBar,
    MessageBarBody,
    Spinner,
    Subtitle2,
    Tab,
    TabList,
    Text,
    mergeClasses,
    type BadgeProps,
} from '@fluentui/react-components';
import { ArrowClockwiseRegular } from '@fluentui/react-icons';
import type { ProjectDefaults } from '../../config';
import { DATAVERSE_GEN_TEMPLATES, DEFAULT_TEMPLATE_ROOT, loadStoredToolSettings } from '../../services';
import { useSettingsPanelStyles } from '../../styles';
import { CodeViewer } from '../viewers/CodeViewer';

/** A badge on a section header, e.g. where its values are saved. */
export interface SectionBadge {
    /** The badge text. */
    label: string;
    /**
     * The Fluent UI badge color, for example `danger` for a warning.
     * @defaultValue `informative`
     */
    color?: BadgeProps['color'];
}

/** Props for {@link SettingsSection}. */
export interface SettingsSectionProps {
    /** The section heading; it also labels the card for screen readers. */
    title: string;
    /** Shown before the heading. Decorative, so it's hidden from screen readers. */
    icon: ReactElement;
    /**
     * Badges after the heading, such as where the values apply.
     * @defaultValue `[]`
     */
    badges?: SectionBadge[];
    /** Red accent for settings that delete or can't be undone. */
    danger?: boolean;
    /** The section's rows, usually {@link SettingRow}s. */
    children: ReactNode;
    /** Shown under the rows, e.g. a preview. */
    extra?: ReactNode;
}

/** A card grouping related settings under a heading, with badges saying where the values apply. */
export function SettingsSection({ title, icon, badges = [], danger, children, extra }: SettingsSectionProps) {
    const styles = useSettingsPanelStyles();
    const headingId = useId();
    return (
        <Card className={mergeClasses(styles.section, danger && styles.sectionDanger)} role="group" aria-labelledby={headingId}>
            <div className={styles.sectionHeader}>
                <span className={mergeClasses(styles.sectionIcon, danger && styles.sectionIconDanger)} aria-hidden="true">
                    {icon}
                </span>
                <Subtitle2 id={headingId} className={styles.sectionTitle}>
                    {title}
                </Subtitle2>
                {badges.length > 0 && (
                    <span className={styles.sectionBadges}>
                        {badges.map((b) => (
                            <Badge key={b.label} appearance="tint" size="small" color={b.color ?? 'informative'}>
                                {b.label}
                            </Badge>
                        ))}
                    </span>
                )}
            </div>
            <div>{children}</div>
            {extra && <div className={styles.sectionExtra}>{extra}</div>}
        </Card>
    );
}

/** Props for {@link SettingRow}. */
export interface SettingRowProps {
    /** The setting's name, shown in semibold; with `info`, it gets an info button next to it. */
    title: string;
    /** One line shown under the title. */
    description: string;
    /** Longer explanation behind the info button. */
    info?: ReactNode;
    /** The value differs from the saved one. */
    changed?: boolean;
    /**
     * `stacked` puts the control under the text, for wide controls such as a text input.
     * @defaultValue `inline`
     */
    layout?: 'inline' | 'stacked';
    /**
     * Renders the control, labelled by the title and described by the description. Called on every render with the
     * ids of the row's title and description.
     */
    control: (ids: { labelledBy: string; describedBy: string }) => ReactNode;
}

/** One setting: title and description on the left, its control on the right (or below, when stacked). */
export function SettingRow({ title, description, info, changed, layout = 'inline', control }: SettingRowProps) {
    const styles = useSettingsPanelStyles();
    const titleId = useId();
    const descriptionId = useId();
    return (
        <div className={mergeClasses(styles.row, layout === 'stacked' && styles.rowStacked)}>
            <div className={styles.rowText}>
                <span className={styles.rowTitle}>
                    {info ? (
                        // Not inline: Fluent's Card clips overflow, so an inline popover is cut off at the card's edge.
                        <InfoLabel weight="semibold" info={info} label={{ id: titleId }} infoButton={{ 'aria-label': `About ${title}`, inline: false }}>
                            {title}
                        </InfoLabel>
                    ) : (
                        <Text id={titleId} weight="semibold">
                            {title}
                        </Text>
                    )}
                    {changed && <span className={styles.changedDot} role="img" aria-label="Changed, not saved yet" title="Changed, not saved yet" />}
                </span>
                <Caption1 id={descriptionId} className={styles.rowDescription}>
                    {description}
                </Caption1>
            </div>
            <div className={styles.rowControl}>{control({ labelledBy: titleId, describedBy: descriptionId })}</div>
        </div>
    );
}

/**
 * What a project with these options generates, as a small folder tree. Every table gets a file in `entities/`; the
 * two interface options add to those files rather than adding files, and `index.ts` is the only optional file.
 *
 * @remarks
 * `defaults` holds the project options to preview (the draft in the Settings panel); a blank output folder shows
 * `./src/dataverse-gen`.
 */
export function OutputPreview({ defaults }: { defaults: ProjectDefaults }) {
    const styles = useSettingsPanelStyles();
    const root = (defaults.outputRoot.trim() || './src/dataverse-gen').replace(/[\\/]+$/, '');
    const tableContents = ['attributes & metadata', defaults.generateEntityTypes && 'interface', defaults.generateFormContext && 'FormContext']
        .filter(Boolean)
        .join(' + ');
    return (
        <>
            <pre className={styles.preview} aria-label="Preview of the generated folder structure">
                {`${root}/\n`}
                {`├─ entities/      Account.ts  (${tableContents})\n`}
                {`├─ enums/         one file per choice\n`}
                {`├─ actions/  functions/  complextypes/\n`}
                {`├─ metadata.ts\n`}
                {defaults.generateIndex ? (
                    '└─ index.ts       re-exports everything'
                ) : (
                    <span className={styles.previewOff}>└─ index.ts       (off)</span>
                )}
            </pre>
            <Caption1 className={styles.previewNote}>Preview for a project with an account table; updates as you change the options.</Caption1>
        </>
    );
}

const lineCount = (text: string) => text.replace(/\r\n?/g, '\n').replace(/\n$/, '').split('\n').length;

/**
 * The Templates tab: the EJS templates Generate writes to each project, read-only, one tab per file. The tool
 * generates with built-in copies (EJS can't run in PPTB), so editing the written files doesn't change its output.
 */
export function TemplatesViewer() {
    const styles = useSettingsPanelStyles();
    const [selected, setSelected] = useState(DATAVERSE_GEN_TEMPLATES[0].name);
    const template = DATAVERSE_GEN_TEMPLATES.find((t) => t.name === selected) ?? DATAVERSE_GEN_TEMPLATES[0];
    return (
        <div className={styles.templates}>
            <MessageBar intent="info">
                <MessageBarBody>
                    The templates behind the generated files. Generate writes them to your project's <code>templateRoot</code> (
                    <code>{DEFAULT_TEMPLATE_ROOT}</code> by default), overwriting edited copies, unless <strong>Generate templates</strong> is
                    off on the Generate &amp; files tab. The tool generates with built-in copies of the same templates, so editing the
                    written files doesn't change its output.
                </MessageBarBody>
            </MessageBar>
            <TabList size="small" selectedValue={selected} onTabSelect={(_, data) => setSelected(data.value as string)} aria-label="Templates">
                {DATAVERSE_GEN_TEMPLATES.map((t) => (
                    <Tab key={t.name} value={t.name}>
                        {t.name}
                    </Tab>
                ))}
            </TabList>
            <Caption1 className={styles.templateMeta}>
                {DEFAULT_TEMPLATE_ROOT.replace(/^\.\//, '')}/{template.name} · {lineCount(template.content)} lines · read-only
            </Caption1>
            <div className={styles.templateCode} role="region" aria-label={`${template.name} template`}>
                <CodeViewer code={template.content} path={template.name} />
            </div>
        </div>
    );
}

/** What {@link StoredSettingsViewer} is showing. */
type StoredSettingsState =
    | { status: 'loading' }
    | { status: 'ready'; settings: Record<string, unknown> }
    | { status: 'unavailable' }
    | { status: 'error'; message: string };

/**
 * The Advanced tab's view of what PPTB has stored for this tool (`toolboxAPI.settings.getAll()`), as read-only JSON.
 * It loads when shown and again on **Refresh**. It shows the saved values only, not unsaved changes in the panel.
 * PPTB doesn't expose where the file is, so no path is shown.
 */
export function StoredSettingsViewer() {
    const styles = useSettingsPanelStyles();
    const [state, setState] = useState<StoredSettingsState>({ status: 'loading' });
    const load = useCallback(async () => {
        setState({ status: 'loading' });
        try {
            const stored = await loadStoredToolSettings();
            setState(stored ? { status: 'ready', settings: stored } : { status: 'unavailable' });
        } catch (error) {
            setState({ status: 'error', message: error instanceof Error ? error.message : String(error) });
        }
    }, []);
    useEffect(() => {
        void load();
    }, [load]);
    const keys = state.status === 'ready' ? Object.keys(state.settings).length : 0;
    return (
        <div className={styles.templates}>
            <MessageBar intent="info">
                <MessageBarBody>
                    Everything Power Platform ToolBox has saved for this tool in this installation: the saved settings (
                    <code>toolConfig</code>), your projects, and the project folder last used with each connection. Unsaved changes in
                    this panel aren't included. PPTB doesn't show where it stores the file.
                </MessageBarBody>
            </MessageBar>
            <div className={styles.storedSettingsBar}>
                <Caption1 className={styles.templateMeta}>
                    {state.status === 'ready' ? `${keys} ${keys === 1 ? 'key' : 'keys'} · JSON · read-only` : 'JSON · read-only'}
                </Caption1>
                <Button size="small" appearance="subtle" icon={<ArrowClockwiseRegular />} disabled={state.status === 'loading'} onClick={() => void load()}>
                    Refresh
                </Button>
            </div>
            {state.status === 'loading' && <Spinner size="tiny" label="Reading the stored settings…" />}
            {state.status === 'unavailable' && (
                <MessageBar intent="warning">
                    <MessageBarBody>The stored settings can only be read inside Power Platform ToolBox.</MessageBarBody>
                </MessageBar>
            )}
            {state.status === 'error' && (
                <MessageBar intent="error">
                    <MessageBarBody>Could not read the stored settings: {state.message}</MessageBarBody>
                </MessageBar>
            )}
            {state.status === 'ready' && (
                <div className={styles.templateCode} role="region" aria-label="Stored tool settings">
                    <CodeViewer code={JSON.stringify(state.settings, null, 2)} path="settings.json" />
                </div>
            )}
        </div>
    );
}
