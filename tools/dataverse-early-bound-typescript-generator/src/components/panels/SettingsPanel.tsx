import { useEffect, useState } from 'react';
import {
    Button,
    Checkbox,
    Field,
    Input,
    DrawerBody,
    DrawerFooter,
    DrawerHeader,
    DrawerHeaderTitle,
    MessageBar,
    MessageBarBody,
    OverlayDrawer,
    Switch,
    Tab,
    TabList,
    Text,
    type SelectTabData,
    type SelectTabEvent,
} from '@fluentui/react-components';
import { CodeRegular, DismissRegular, OptionsRegular, WrenchRegular } from '@fluentui/react-icons';
import { toolConfigEquals, type ProjectDefaults, type ToolConfig } from '../../config';
import { infoLabel } from '../shared/infoLabel';
import { useSettingsPanelStyles } from '../../styles';

type SettingsTab = 'general' | 'options' | 'schemaGeneration';

export interface SettingsPanelProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    /** The saved settings; edits are kept in a draft until Save. */
    settings: ToolConfig;
    /** Persists the settings. The panel closes when it resolves and shows the error when it rejects. */
    onSave: (settings: ToolConfig) => Promise<void>;
}

/**
 * Tool settings, shown in an overlay drawer that slides in from the right edge, with vertical tabs. Changes
 * are made on a draft: Save (enabled once something changed) persists them, Cancel discards them.
 */
export function SettingsPanel({ open, onOpenChange, settings, onSave }: SettingsPanelProps) {
    const styles = useSettingsPanelStyles();
    const [tab, setTab] = useState<SettingsTab>('general');
    const [draft, setDraft] = useState<ToolConfig>(settings);
    const [saving, setSaving] = useState(false);
    const [saveError, setSaveError] = useState<string | null>(null);

    // Start every visit from the saved values.
    useEffect(() => {
        if (open) {
            setDraft(settings);
            setSaveError(null);
        }
    }, [open, settings]);

    const dirty = !toolConfigEquals(draft, settings);
    const update = (change: Partial<ToolConfig>) => setDraft((current) => ({ ...current, ...change }));
    const updateProjectDefaults = (change: Partial<ProjectDefaults>) =>
        setDraft((current) => ({ ...current, projectDefaults: { ...current.projectDefaults, ...change } }));

    const save = async () => {
        setSaving(true);
        setSaveError(null);
        try {
            await onSave(draft);
            onOpenChange(false);
        } catch (error) {
            setSaveError(`Could not save the settings: ${error instanceof Error ? error.message : String(error)}`);
        } finally {
            setSaving(false);
        }
    };

    return (
        <OverlayDrawer position="end" size="large" open={open} onOpenChange={(_, data) => onOpenChange(data.open)}>
            <DrawerHeader>
                <DrawerHeaderTitle
                    action={<Button appearance="subtle" aria-label="Close" icon={<DismissRegular />} onClick={() => onOpenChange(false)} />}
                >
                    Settings
                </DrawerHeaderTitle>
            </DrawerHeader>
            <DrawerBody>
                <div className={styles.body}>
                    <TabList
                        vertical
                        className={styles.tabs}
                        selectedValue={tab}
                        onTabSelect={(_: SelectTabEvent, data: SelectTabData) => setTab(data.value as SettingsTab)}
                    >
                        <Tab value="general" icon={<OptionsRegular />}>
                            General
                        </Tab>
                        <Tab value="options" icon={<WrenchRegular />}>
                            Options
                        </Tab>
                        <Tab value="schemaGeneration" icon={<CodeRegular />}>
                            Schema Generation
                        </Tab>
                    </TabList>
                    <div className={styles.content} role="tabpanel">
                        {tab === 'general' && <Text size={200}>No general settings yet.</Text>}
                        {tab === 'options' && (
                            <>
                                <Text size={200} className={styles.intro}>
                                    Defaults for new projects: used when a project folder without .dataverse-gen.json is opened. Projects
                                    that already have one keep their own options, set on the Options card.
                                </Text>
                                <Field
                                    label={infoLabel(
                                        'Output folder',
                                        <>
                                            Where generated files go, relative to the project folder. Saved to a new project's{' '}
                                            <code>output.outputRoot</code>. A blank value keeps the previous default.
                                        </>,
                                    )}
                                >
                                    <Input
                                        value={draft.projectDefaults.outputRoot}
                                        onChange={(_, data) => updateProjectDefaults({ outputRoot: data.value })}
                                    />
                                </Field>
                                <Switch
                                    label={infoLabel(
                                        'Early-bound entity interfaces (dataverse-ify)',
                                        <>
                                            An interface per table with a typed property per column, for dataverse-ify. Saved to a new
                                            project's <code>generateEntityTypes</code>.
                                        </>,
                                    )}
                                    checked={draft.projectDefaults.generateEntityTypes}
                                    onChange={(_, data) => updateProjectDefaults({ generateEntityTypes: data.checked })}
                                />
                                <Switch
                                    label={infoLabel(
                                        'Form context helpers (Xrm.FormContext)',
                                        <>
                                            A typed <code>&lt;Table&gt;FormContext</code> interface per table for form scripts. Saved to a
                                            new project's <code>generateFormContext</code>.
                                        </>,
                                    )}
                                    checked={draft.projectDefaults.generateFormContext}
                                    onChange={(_, data) => updateProjectDefaults({ generateFormContext: data.checked })}
                                />
                                <Switch
                                    label={infoLabel(
                                        'index.ts barrel file',
                                        <>
                                            An <code>index.ts</code> that re-exports every generated file. Saved to a new project's{' '}
                                            <code>generateIndex</code>.
                                        </>,
                                    )}
                                    checked={draft.projectDefaults.generateIndex}
                                    onChange={(_, data) => updateProjectDefaults({ generateIndex: data.checked })}
                                />
                            </>
                        )}
                        {tab === 'schemaGeneration' && (
                            <>
                                <Checkbox
                                    label="Delete Orphaned Files"
                                    checked={draft.deleteOrphanedFiles}
                                    onChange={(_, data) => update({ deleteOrphanedFiles: data.checked === true })}
                                />
                                <Text size={200} className={styles.hint}>
                                    Files in the output folders that the current selection no longer generates. Not applied yet: Power
                                    Platform ToolBox can't delete files, so orphaned files are still only reported.
                                </Text>
                            </>
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
                <Button appearance="primary" disabled={!dirty || saving} onClick={() => void save()}>
                    {saving ? 'Saving…' : 'Save'}
                </Button>
                <Button disabled={saving} onClick={() => onOpenChange(false)}>
                    Cancel
                </Button>
            </DrawerFooter>
        </OverlayDrawer>
    );
}
