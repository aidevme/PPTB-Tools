import { useEffect, useState } from 'react';
import { toolConfig, toolConfigEquals, type GeneralSettings, type ProjectDefaults, type ToolConfig } from '../config';
import { useAsyncAction } from './useAsyncAction';

/** The settings with every value Reset puts back to the bundled default; saved projects are kept. */
function withDefaults(config: ToolConfig): ToolConfig {
    return {
        ...config,
        general: { ...toolConfig.general },
        deleteOrphanedFiles: toolConfig.deleteOrphanedFiles,
        confirmBeforeGenerate: toolConfig.confirmBeforeGenerate,
        skipDuplicateIdentifiers: toolConfig.skipDuplicateIdentifiers,
        renameDuplicateIdentifiers: toolConfig.renameDuplicateIdentifiers,
        generateTemplates: toolConfig.generateTemplates,
        customEnumTemplate: toolConfig.customEnumTemplate,
        projectDefaults: { ...toolConfig.projectDefaults },
    };
}

export interface UseSettingsDraftOptions {
    /** Whether the Settings panel is open; the draft starts from the saved settings every time it opens. */
    open: boolean;
    /** The saved settings. */
    settings: ToolConfig;
    /** Persists the settings; rejects when saving fails. */
    onSave: (settings: ToolConfig) => Promise<void>;
    onOpenChange: (open: boolean) => void;
}

/**
 * The Settings panel's draft: edits are made on a copy of the saved settings, which is reset to them every time
 * the panel opens and only persisted by `save` (which closes the panel, or keeps it open with `saveError`).
 */
export function useSettingsDraft({ open, settings, onSave, onOpenChange }: UseSettingsDraftOptions) {
    const [draft, setDraft] = useState<ToolConfig>(settings);
    const [saveError, setSaveError] = useState<string | null>(null);
    const saveAction = useAsyncAction(setSaveError);
    const saving = saveAction.busy;

    // Start every visit from the saved values.
    useEffect(() => {
        if (open) {
            setDraft(settings);
            setSaveError(null);
        }
    }, [open, settings]);

    const dirty = !toolConfigEquals(draft, settings);
    const atDefaults = toolConfigEquals(withDefaults(draft), draft);
    const update = (change: Partial<ToolConfig>) => setDraft((current) => ({ ...current, ...change }));
    const updateProjectDefaults = (change: Partial<ProjectDefaults>) =>
        setDraft((current) => ({ ...current, projectDefaults: { ...current.projectDefaults, ...change } }));
    const updateGeneral = (change: Partial<GeneralSettings>) => setDraft((current) => ({ ...current, general: { ...current.general, ...change } }));
    /** Reset to defaults: the bundled defaults, keeping the saved projects. */
    const resetToDefaults = () => setDraft(withDefaults);

    const save = () =>
        saveAction.run(`Could not save the settings`, async () => {
            await onSave(draft);
            onOpenChange(false);
        });

    return { draft, dirty, atDefaults, saving, saveError, update, updateProjectDefaults, updateGeneral, resetToDefaults, save };
}
