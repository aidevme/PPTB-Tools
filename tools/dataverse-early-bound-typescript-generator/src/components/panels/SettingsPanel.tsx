import { useEffect, useState } from 'react';
import {
    Button,
    Checkbox,
    DrawerBody,
    DrawerFooter,
    DrawerHeader,
    DrawerHeaderTitle,
    MessageBar,
    MessageBarBody,
    OverlayDrawer,
    Tab,
    TabList,
    Text,
    makeStyles,
    tokens,
    type SelectTabData,
    type SelectTabEvent,
} from '@fluentui/react-components';
import { CodeRegular, DismissRegular, OptionsRegular } from '@fluentui/react-icons';
import { toolConfigEquals, type ToolConfig } from '../../config';

type SettingsTab = 'general' | 'schemaGeneration';

const useStyles = makeStyles({
    body: { display: 'flex', gap: tokens.spacingHorizontalL, alignItems: 'flex-start' },
    tabs: { flexShrink: 0 },
    content: { flexGrow: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalS },
    hint: { color: tokens.colorNeutralForeground3, paddingLeft: tokens.spacingHorizontalXXL },
    footer: { justifyContent: 'flex-end' },
});

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
    const styles = useStyles();
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
        <OverlayDrawer position="end" size="medium" open={open} onOpenChange={(_, data) => onOpenChange(data.open)}>
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
                        <Tab value="schemaGeneration" icon={<CodeRegular />}>
                            Schema Generation
                        </Tab>
                    </TabList>
                    <div className={styles.content} role="tabpanel">
                        {tab === 'general' ? (
                            <Text size={200}>No general settings yet.</Text>
                        ) : (
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
