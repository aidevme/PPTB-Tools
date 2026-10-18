import { useEffect, useState, type ReactElement, type ReactNode } from 'react';
import {
    Body1,
    Button,
    Caption1,
    DrawerBody,
    DrawerFooter,
    DrawerHeader,
    DrawerHeaderTitle,
    Input,
    MessageBar,
    MessageBarBody,
    OverlayDrawer,
    SearchBox,
    SpinButton,
    Switch,
    Tab,
    TabList,
    Text,
    Title3,
    mergeClasses,
    type SelectTabData,
    type SelectTabEvent,
} from '@fluentui/react-components';
import {
    AlertRegular,
    ArrowResetRegular,
    CodeRegular,
    CodeTextRegular,
    DeleteRegular,
    DismissRegular,
    DocumentCheckmarkRegular,
    FolderRegular,
    ListRegular,
    OptionsRegular,
    SettingsRegular,
    WarningRegular,
    WrenchRegular,
} from '@fluentui/react-icons';
import {
    DELETE_ORPHANS_INFO,
    DELETE_ORPHANS_TITLE,
    RENAME_DUPLICATES_INFO,
    RENAME_DUPLICATES_TITLE,
    SKIP_DUPLICATES_INFO,
    SKIP_DUPLICATES_TITLE,
} from '../shared/settingsInfo';
import { RECENT_PROJECT_COUNT_RANGE, SELECTION_ROW_LIMIT_RANGE, type ToolConfig } from '../../config';
import { useSettingsDraft } from '../../hooks';
import { DEFAULT_TEMPLATE_ROOT } from '../../services';
import { useSettingsPanelStyles } from '../../styles';
import { version } from '../../../package.json';
import { OutputPreview, SettingRow, SettingsSection, TemplatesViewer, type SectionBadge } from './SettingsParts';

type SettingsTab = 'general' | 'options' | 'files' | 'templates';

const TABS: Array<{ value: SettingsTab; label: string; subtitle: string; icon: ReactElement }> = [
    { value: 'general', label: 'General', subtitle: 'Notifications and lists', icon: <OptionsRegular /> },
    { value: 'options', label: 'Options', subtitle: 'What every project generates', icon: <WrenchRegular /> },
    { value: 'files', label: 'Generate & files', subtitle: 'Confirmations and orphans', icon: <CodeRegular /> },
    { value: 'templates', label: 'Templates', subtitle: 'EJS templates', icon: <CodeTextRegular /> },
];

/** One-line explanation at the top of each tab. */
const TAB_INTROS: Record<SettingsTab, string> = {
    general: 'How the tool itself behaves.',
    options: 'Applied whenever a project opens; you can still change them per project on the Options card.',
    files: 'How Generate treats files in the output folders, for every project.',
    templates: 'The EJS templates Generate writes to each project. For reference only; nothing to change here.',
};

const SCOPE_INSTALLATION: SectionBadge = { label: 'This PPTB installation' };
const SCOPE_PROJECTS: SectionBadge = { label: 'Default for every project', color: 'brand' };
const SCOPE_CONFIG_FILE: SectionBadge = { label: '.dataverse-gen.json' };
const SCOPE_ALL_PROJECTS: SectionBadge = { label: 'All projects' };

type ControlIds = { labelledBy: string; describedBy: string };

/** A setting as listed in a section; also what search matches against. */
interface SettingDefinition {
    id: string;
    title: string;
    description: string;
    info?: ReactNode;
    /** Extra words search should match, beyond the title and description. */
    keywords?: string;
    changed: boolean;
    layout?: 'inline' | 'stacked';
    control: (ids: ControlIds) => ReactNode;
    /** Shown under the row, e.g. a warning while the setting is on. */
    note?: ReactNode;
}

interface SectionDefinition {
    id: string;
    tab: SettingsTab;
    title: string;
    icon: ReactElement;
    badges: SectionBadge[];
    danger?: boolean;
    settings: SettingDefinition[];
    extra?: ReactNode;
}

/** Whether a setting matches every word of the search, case-insensitively. */
function matchesSearch(setting: SettingDefinition, section: SectionDefinition, query: string): boolean {
    const words = query.toLowerCase().split(/\s+/).filter(Boolean);
    const haystack = [setting.title, setting.description, setting.keywords, section.title].join(' ').toLowerCase();
    return words.every((w) => haystack.includes(w));
}

/**
 * A SpinButton's new value: the stepped value, or the typed text when the user typed one. Out-of-range or
 * fractional values are clamped and rounded when the settings are saved (`mergeToolConfig`).
 */
function spinValue(data: { value?: number | null; displayValue?: string }, current: number): number {
    if (typeof data.value === 'number') return data.value;
    const typed = Number(data.displayValue);
    return data.displayValue !== undefined && data.displayValue.trim() !== '' && Number.isFinite(typed) ? typed : current;
}

export interface SettingsPanelProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    /** The saved settings; edits are kept in a draft until Save. */
    settings: ToolConfig;
    /** Persists the settings. The panel closes when it resolves and shows the error when it rejects. */
    onSave: (settings: ToolConfig) => Promise<void>;
}

/**
 * Tool settings, in an overlay drawer that slides in from the right. A navigation column (search, then vertical
 * tabs with subtitles) sits beside section cards; each setting is a row with its title and description on the left
 * and its control on the right. Changes are made on a draft: a dot marks each changed value, the footer says when
 * there are unsaved changes, Save (enabled once something changed) persists them, Cancel discards them, and Reset
 * to defaults restores the bundled defaults (saved projects are kept).
 */
export function SettingsPanel({ open, onOpenChange, settings, onSave }: SettingsPanelProps) {
    const styles = useSettingsPanelStyles();
    const [tab, setTab] = useState<SettingsTab>('general');
    const [query, setQuery] = useState('');
    const { draft, dirty, atDefaults, saving, saveError, update, updateProjectDefaults, updateGeneral, resetToDefaults, save } = useSettingsDraft({
        open,
        settings,
        onSave,
        onOpenChange,
    });

    // Start every visit with an empty search.
    useEffect(() => {
        if (open) setQuery('');
    }, [open, settings]);

    const general = draft.general;
    const savedGeneral = settings.general;
    /** A setting row's Switch, labelled and described by the row's title and description. */
    const switchControl =
        (checked: boolean, onChange: (checked: boolean) => void) =>
        ({ labelledBy, describedBy }: ControlIds) => (
            <Switch checked={checked} aria-labelledby={labelledBy} aria-describedby={describedBy} onChange={(_, data) => onChange(data.checked)} />
        );
    const notificationSwitch = (key: 'showProjectLoadedNotification' | 'showPreviewReadyNotification' | 'showGenerationCompleteNotification') =>
        switchControl(general[key], (checked) => updateGeneral({ [key]: checked }));

    const sections: SectionDefinition[] = [
        {
            id: 'notifications',
            tab: 'general',
            title: 'Notifications',
            icon: <AlertRegular />,
            badges: [SCOPE_INSTALLATION],
            settings: [
                {
                    id: 'projectLoaded',
                    title: 'Project loaded',
                    description: 'When a project opens.',
                    info: (
                        <>
                            Says whether the project's .dataverse-gen.json was found. Saved as{' '}
                            <code>general.showProjectLoadedNotification</code>.
                        </>
                    ),
                    keywords: 'notification toast open',
                    changed: general.showProjectLoadedNotification !== savedGeneral.showProjectLoadedNotification,
                    control: notificationSwitch('showProjectLoadedNotification'),
                },
                {
                    id: 'previewReady',
                    title: 'Preview ready',
                    description: 'When a preview finishes.',
                    info: (
                        <>
                            Summarizes what Generate would do. Saved as <code>general.showPreviewReadyNotification</code>.
                        </>
                    ),
                    keywords: 'notification toast',
                    changed: general.showPreviewReadyNotification !== savedGeneral.showPreviewReadyNotification,
                    control: notificationSwitch('showPreviewReadyNotification'),
                },
                {
                    id: 'generationComplete',
                    title: 'Generation complete',
                    description: 'When Generate finishes.',
                    info: (
                        <>
                            Lists the files written. The result also shows on the Preview card either way, and error notifications are
                            always shown. Saved as <code>general.showGenerationCompleteNotification</code>.
                        </>
                    ),
                    keywords: 'notification toast generate',
                    changed: general.showGenerationCompleteNotification !== savedGeneral.showGenerationCompleteNotification,
                    control: notificationSwitch('showGenerationCompleteNotification'),
                },
            ],
        },
        {
            id: 'lists',
            tab: 'general',
            title: 'Lists & startup',
            icon: <ListRegular />,
            badges: [SCOPE_INSTALLATION],
            settings: [
                {
                    id: 'recentProjects',
                    title: 'Recent projects',
                    description: 'Offered on the Project card; 0 hides the list.',
                    info: (
                        <>
                            From {RECENT_PROJECT_COUNT_RANGE.min} to {RECENT_PROJECT_COUNT_RANGE.max}. Saved as{' '}
                            <code>general.recentProjectCount</code>.
                        </>
                    ),
                    keywords: 'recent projects shown',
                    changed: general.recentProjectCount !== savedGeneral.recentProjectCount,
                    control: ({ labelledBy, describedBy }) => (
                        <>
                            <SpinButton
                                className={styles.number}
                                min={RECENT_PROJECT_COUNT_RANGE.min}
                                max={RECENT_PROJECT_COUNT_RANGE.max}
                                value={general.recentProjectCount}
                                aria-labelledby={labelledBy}
                                aria-describedby={describedBy}
                                onChange={(_, data) => updateGeneral({ recentProjectCount: spinValue(data, general.recentProjectCount) })}
                            />
                            <Caption1 className={styles.unit}>{general.recentProjectCount === 1 ? 'project' : 'projects'}</Caption1>
                        </>
                    ),
                },
                {
                    id: 'rowLimit',
                    title: 'Rows in the Select tables',
                    description: 'The most each table lists; search to find others.',
                    info: (
                        <>
                            From {SELECTION_ROW_LIMIT_RANGE.min} to {SELECTION_ROW_LIMIT_RANGE.max}, for tables, actions and functions.
                            Higher values can make large environments slower. Saved as <code>general.selectionRowLimit</code>.
                        </>
                    ),
                    keywords: 'rows shown limit select tables',
                    changed: general.selectionRowLimit !== savedGeneral.selectionRowLimit,
                    control: ({ labelledBy, describedBy }) => (
                        <>
                            <SpinButton
                                className={styles.number}
                                min={SELECTION_ROW_LIMIT_RANGE.min}
                                max={SELECTION_ROW_LIMIT_RANGE.max}
                                step={100}
                                value={general.selectionRowLimit}
                                aria-labelledby={labelledBy}
                                aria-describedby={describedBy}
                                onChange={(_, data) => updateGeneral({ selectionRowLimit: spinValue(data, general.selectionRowLimit) })}
                            />
                            <Caption1 className={styles.unit}>rows</Caption1>
                        </>
                    ),
                },
            ],
        },
        {
            id: 'output',
            tab: 'options',
            title: 'Output',
            icon: <FolderRegular />,
            badges: [SCOPE_PROJECTS, SCOPE_CONFIG_FILE],
            settings: [
                {
                    id: 'outputRoot',
                    title: 'Output folder',
                    description: 'Where generated files go, relative to the project folder.',
                    info: (
                        <>
                            Sets the project's <code>output.outputRoot</code>. A blank value keeps the previous default.
                        </>
                    ),
                    keywords: 'output root path directory',
                    changed: draft.projectDefaults.outputRoot !== settings.projectDefaults.outputRoot,
                    layout: 'stacked',
                    control: ({ labelledBy, describedBy }) => (
                        <Input
                            className={styles.search}
                            value={draft.projectDefaults.outputRoot}
                            aria-labelledby={labelledBy}
                            aria-describedby={describedBy}
                            onChange={(_, data) => updateProjectDefaults({ outputRoot: data.value })}
                        />
                    ),
                },
            ],
        },
        {
            id: 'generatedFiles',
            tab: 'options',
            title: 'Generated files',
            icon: <DocumentCheckmarkRegular />,
            badges: [SCOPE_PROJECTS, SCOPE_CONFIG_FILE],
            extra: <OutputPreview defaults={draft.projectDefaults} />,
            settings: (
                [
                    ['generateEntityTypes', 'Early-bound entity interfaces', 'A typed interface per table, for dataverse-ify.', 'dataverse-ify entity types'],
                    ['generateFormContext', 'Form context helpers', 'A typed FormContext per table, for form scripts.', 'xrm formcontext form scripts'],
                    ['generateIndex', 'index.ts barrel file', 'An index.ts that re-exports every generated file.', 'barrel index exports'],
                ] as const
            ).map(
                ([key, title, description, keywords]): SettingDefinition => ({
                    id: key,
                    title,
                    description,
                    info: (
                        <>
                            Sets the project's <code>{key}</code>.
                        </>
                    ),
                    keywords,
                    changed: draft.projectDefaults[key] !== settings.projectDefaults[key],
                    control: switchControl(draft.projectDefaults[key], (checked) => updateProjectDefaults({ [key]: checked })),
                }),
            ),
        },
        {
            id: 'beforeGenerating',
            tab: 'files',
            title: 'Before generating',
            icon: <DocumentCheckmarkRegular />,
            badges: [SCOPE_ALL_PROJECTS],
            settings: [
                {
                    id: 'confirmBeforeGenerate',
                    title: 'Ask before generating',
                    description: 'Confirm before new and changed files are written.',
                    info: (
                        <>
                            The confirmation names the output folder and how many files will be created and overwritten. Overwrites
                            can't be undone, so use source control. When orphaned files are deleted too, their confirmation covers both.
                            Saved as <code>confirmBeforeGenerate</code>.
                        </>
                    ),
                    keywords: 'confirm confirmation overwrite',
                    changed: draft.confirmBeforeGenerate !== settings.confirmBeforeGenerate,
                    control: switchControl(draft.confirmBeforeGenerate, (checked) => update({ confirmBeforeGenerate: checked })),
                },
            ],
        },
        {
            id: 'templateFiles',
            tab: 'files',
            title: 'Templates',
            icon: <CodeTextRegular />,
            badges: [SCOPE_ALL_PROJECTS],
            settings: [
                {
                    id: 'generateTemplates',
                    title: 'Generate templates',
                    description: "Write dataverse-gen's EJS templates to the project's templateRoot.",
                    info: (
                        <>
                            Generate writes the templates to <code>templateRoot</code> (<code>{DEFAULT_TEMPLATE_ROOT}</code> by default),
                            overwriting edited copies, like <code>dataverse-gen eject</code>. When off, they aren't written and
                            existing copies are left as they are. The tool itself always uses its built-in templates. Saved as{' '}
                            <code>generateTemplates</code>.
                        </>
                    ),
                    keywords: 'templates ejs eject templateRoot dataverse-gen write',
                    changed: draft.generateTemplates !== settings.generateTemplates,
                    control: switchControl(draft.generateTemplates, (checked) => update({ generateTemplates: checked })),
                },
            ],
        },
        {
            id: 'duplicates',
            tab: 'files',
            title: 'Duplicate identifiers',
            icon: <WarningRegular />,
            badges: [SCOPE_ALL_PROJECTS],
            settings: [
                {
                    id: 'renameDuplicateIdentifiers',
                    title: RENAME_DUPLICATES_TITLE,
                    description: 'Give later duplicate enum members their value as a suffix, so the files compile.',
                    info: RENAME_DUPLICATES_INFO,
                    keywords: 'duplicate duplicated identifier identifiers enum label rename suffix compile',
                    changed: draft.renameDuplicateIdentifiers !== settings.renameDuplicateIdentifiers,
                    control: switchControl(draft.renameDuplicateIdentifiers, (checked) => update({ renameDuplicateIdentifiers: checked })),
                },
                {
                    id: 'skipDuplicateIdentifiers',
                    title: SKIP_DUPLICATES_TITLE,
                    description: "Don't write generated files that declare the same name more than once.",
                    info: SKIP_DUPLICATES_INFO,
                    keywords: 'duplicate duplicated identifier identifiers enum label skip compile',
                    changed: draft.skipDuplicateIdentifiers !== settings.skipDuplicateIdentifiers,
                    control: switchControl(draft.skipDuplicateIdentifiers, (checked) => update({ skipDuplicateIdentifiers: checked })),
                },
            ],
        },
        {
            id: 'templates',
            tab: 'templates',
            title: 'dataverse-early-bound-typescript-generator templates',
            icon: <CodeTextRegular />,
            // The tool's own version, as in the header.
            badges: [{ label: `Version ${version}` }, { label: 'Read-only' }],
            // Nothing to set: the card only shows the templates.
            settings: [],
            extra: <TemplatesViewer />,
        },
        {
            id: 'orphans',
            tab: 'files',
            title: 'Orphaned files',
            icon: <DeleteRegular />,
            badges: [SCOPE_ALL_PROJECTS, { label: 'Permanent', color: 'danger' }],
            danger: true,
            settings: [
                {
                    id: 'deleteOrphanedFiles',
                    title: DELETE_ORPHANS_TITLE,
                    description: 'Delete generated files the selection no longer produces.',
                    info: DELETE_ORPHANS_INFO,
                    keywords: 'orphan orphaned delete remove cleanup',
                    changed: draft.deleteOrphanedFiles !== settings.deleteOrphanedFiles,
                    control: switchControl(draft.deleteOrphanedFiles, (checked) => update({ deleteOrphanedFiles: checked })),
                    note: draft.deleteOrphanedFiles ? (
                        <MessageBar intent="warning" className={styles.warning}>
                            <MessageBarBody>Files are deleted permanently, not moved to the Recycle Bin or Trash.</MessageBarBody>
                        </MessageBar>
                    ) : undefined,
                },
            ],
        },
    ];

    const searching = query.trim().length > 0;
    const visibleSections = searching
        ? sections
              .map((section) => ({ ...section, settings: section.settings.filter((s) => matchesSearch(s, section, query)) }))
              .filter((section) => section.settings.length > 0)
        : sections.filter((section) => section.tab === tab);
    const tabLabel = (value: SettingsTab) => TABS.find((t) => t.value === value)?.label ?? value;

    const renderSection = (section: SectionDefinition) => (
        <SettingsSection
            key={section.id}
            title={searching ? `${section.title} · ${tabLabel(section.tab)}` : section.title}
            icon={section.icon}
            badges={section.badges}
            danger={section.danger}
            extra={searching ? undefined : section.extra}
        >
            {section.settings.map((setting) => (
                <div key={setting.id}>
                    <SettingRow
                        title={setting.title}
                        description={setting.description}
                        info={setting.info}
                        changed={setting.changed}
                        layout={setting.layout}
                        control={setting.control}
                    />
                    {setting.note && <div className={styles.sectionExtra}>{setting.note}</div>}
                </div>
            ))}
        </SettingsSection>
    );

    return (
        <OverlayDrawer className={styles.drawer} position="end" open={open} onOpenChange={(_, data) => onOpenChange(data.open)}>
            <DrawerHeader>
                <DrawerHeaderTitle
                    action={<Button appearance="subtle" aria-label="Close" icon={<DismissRegular />} onClick={() => onOpenChange(false)} />}
                >
                    <span className={styles.headerTitle}>
                        <span className={styles.headerIcon} aria-hidden="true">
                            <SettingsRegular />
                        </span>
                        <span className={styles.headerText}>
                            <Title3>Settings</Title3>
                            <Caption1 className={styles.headerSubtitle}>Dataverse Early-Bound TypeScript Generator</Caption1>
                        </span>
                    </span>
                </DrawerHeaderTitle>
            </DrawerHeader>
            <DrawerBody>
                <div className={styles.body}>
                    <nav className={styles.nav} aria-label="Settings sections">
                        <SearchBox
                            className={styles.search}
                            placeholder="Search settings"
                            aria-label="Search settings"
                            value={query}
                            onChange={(_, data) => setQuery(data.value)}
                        />
                        <TabList
                            vertical
                            selectedValue={searching ? null : tab}
                            onTabSelect={(_: SelectTabEvent, data: SelectTabData) => {
                                setTab(data.value as SettingsTab);
                                setQuery('');
                            }}
                        >
                            {TABS.map((t) => (
                                <Tab key={t.value} value={t.value} icon={t.icon}>
                                    <span className={styles.tabLabel}>
                                        <span>{t.label}</span>
                                        <Caption1 className={styles.tabSubtitle}>{t.subtitle}</Caption1>
                                    </span>
                                </Tab>
                            ))}
                        </TabList>
                    </nav>
                    {/* Re-keyed on every tab or search change so the fade-in plays. */}
                    <div
                        key={searching ? 'search' : tab}
                        className={styles.content}
                        role="tabpanel"
                        aria-label={searching ? 'Search results' : tabLabel(tab)}
                    >
                        {searching ? (
                            visibleSections.length > 0 && <Body1 className={styles.resultsHeading}>Settings matching "{query.trim()}"</Body1>
                        ) : (
                            <Text size={200} className={styles.intro}>
                                {TAB_INTROS[tab]}
                            </Text>
                        )}
                        {visibleSections.length > 0 ? (
                            visibleSections.map(renderSection)
                        ) : (
                            <Body1 className={styles.empty}>No settings match "{query.trim()}".</Body1>
                        )}
                        {saveError && (
                            <MessageBar intent="error">
                                <MessageBarBody>{saveError}</MessageBarBody>
                            </MessageBar>
                        )}
                    </div>
                </div>
            </DrawerBody>
            <DrawerFooter className={styles.footer}>
                <span className={mergeClasses(styles.footerStatus, dirty && styles.footerStatusDirty)} aria-live="polite">
                    {dirty ? '● Unsaved changes' : 'No unsaved changes'}
                </span>
                <span className={styles.footerActions}>
                    <Button appearance="subtle" icon={<ArrowResetRegular />} disabled={atDefaults || saving} onClick={resetToDefaults}>
                        Reset to defaults
                    </Button>
                    <Button appearance="primary" disabled={!dirty || saving} onClick={() => void save()}>
                        {saving ? 'Saving…' : 'Save'}
                    </Button>
                    <Button disabled={saving} onClick={() => onOpenChange(false)}>
                        Cancel
                    </Button>
                </span>
            </DrawerFooter>
        </OverlayDrawer>
    );
}
