import { useEffect, useState } from 'react';
import {
    Body1,
    Button,
    Caption1,
    DrawerBody,
    DrawerFooter,
    DrawerHeader,
    DrawerHeaderTitle,
    Menu,
    MenuItem,
    MenuList,
    MenuPopover,
    MenuTrigger,
    MessageBar,
    MessageBarBody,
    OverlayDrawer,
    SearchBox,
    SplitButton,
    Tab,
    TabList,
    Text,
    Title3,
    mergeClasses,
    type MenuButtonProps,
    type SelectTabData,
    type SelectTabEvent,
} from '@fluentui/react-components';
import { ArrowResetRegular, DismissRegular, SettingsRegular } from '@fluentui/react-icons';
import type { ToolConfig } from '../../config';
import { useSettingsDraft } from '../../hooks';
import { useSettingsPanelStyles } from '../../styles';
import { SettingRow, SettingsSection } from './SettingsParts';
import { TABS, TAB_INTROS, type SettingsTab } from './SettingsPanel.const';
import type { SectionDefinition, SettingDefinition, SettingsTabContext } from './SettingsTab.shared';
import { generalTabSections } from './tabs/GeneralTab';
import { optionsTabSections } from './tabs/OptionsTab';
import { filesTabSections } from './tabs/FilesTab';
import { templatesTabSections } from './tabs/TemplatesTab';
import { advancedTabSections } from './tabs/AdvancedTab';

/** Whether a setting matches every word of the search, case-insensitively. */
function matchesSearch(setting: SettingDefinition, section: SectionDefinition, query: string): boolean {
    const words = query.toLowerCase().split(/\s+/).filter(Boolean);
    const haystack = [setting.title, setting.description, setting.keywords, section.title].join(' ').toLowerCase();
    return words.every((w) => haystack.includes(w));
}

/** Props for {@link SettingsPanel}. */
export interface SettingsPanelProps {
    /** Whether the drawer is open. Each time it opens, the draft starts again from `settings` and the search is cleared. */
    open: boolean;
    /**
     * Called with `false` when the panel should close: the Close or Cancel button, the drawer's own dismiss (for
     * example Escape), or a successful Save.
     */
    onOpenChange: (open: boolean) => void;
    /** The saved settings; edits are kept in a draft until Save. */
    settings: ToolConfig;
    /**
     * Called with the draft when Save is clicked, to persist it. The panel closes when it resolves and shows the error
     * when it rejects.
     */
    onSave: (settings: ToolConfig) => Promise<void>;
}

/**
 * Tool settings, in an overlay drawer that slides in from the right. A navigation column (search, then vertical
 * tabs with subtitles) sits beside section cards; each setting is a row with its title and description on the left
 * and its control on the right. Changes are made on a draft: a dot marks each changed value, the footer says when
 * there are unsaved changes, Save (enabled once something changed) persists them, and the Cancel split button
 * discards them; its menu also has Reset to defaults, which restores the bundled defaults (saved projects are kept).
 *
 * @remarks
 * Each tab's sections come from its own file (`GeneralTab`, `OptionsTab`, `FilesTab`, `TemplatesTab`, `AdvancedTab`);
 * the panel combines them, so search matches settings on every tab.
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

    const context: SettingsTabContext = { draft, settings, update, updateProjectDefaults, updateGeneral, styles };
    // Every tab's sections, so search can match across tabs.
    const sections: SectionDefinition[] = [
        ...generalTabSections(context),
        ...optionsTabSections(context),
        ...filesTabSections(context),
        ...templatesTabSections(),
        ...advancedTabSections(),
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
                        ) : searching ? (
                            <Body1 className={styles.empty}>No settings match "{query.trim()}".</Body1>
                        ) : (
                            // A tab without sections yet (Advanced).
                            <Body1 className={styles.empty}>No settings on this tab yet.</Body1>
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
                    <Button appearance="primary" disabled={!dirty || saving} onClick={() => void save()}>
                        {saving ? 'Saving…' : 'Save'}
                    </Button>
                    {/* Clicking Cancel closes the panel; the chevron opens the menu with Cancel (the default) and Reset to defaults. */}
                    <Menu positioning="above-end">
                        <MenuTrigger disableButtonEnhancement>
                            {(triggerProps: MenuButtonProps) => (
                                <SplitButton
                                    disabled={saving}
                                    menuButton={{ ...triggerProps, 'aria-label': 'More actions' }}
                                    primaryActionButton={{ onClick: () => onOpenChange(false) }}
                                >
                                    Cancel
                                </SplitButton>
                            )}
                        </MenuTrigger>
                        <MenuPopover>
                            <MenuList>
                                <MenuItem icon={<DismissRegular />} onClick={() => onOpenChange(false)}>
                                    Cancel
                                </MenuItem>
                                <MenuItem icon={<ArrowResetRegular />} disabled={atDefaults} onClick={resetToDefaults}>
                                    Reset to defaults
                                </MenuItem>
                            </MenuList>
                        </MenuPopover>
                    </Menu>
                </span>
            </DrawerFooter>
        </OverlayDrawer>
    );
}
