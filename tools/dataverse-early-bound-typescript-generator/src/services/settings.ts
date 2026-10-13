/**
 * Per-tool settings stored by PPTB (`toolboxAPI.settings`): the project folder last used with each
 * connection, so reopening the tool lands on the same project, and the values saved in the Settings panel.
 */
import { mergeToolConfig, toolConfig, type ToolConfig } from '../config';

const PROJECT_FOLDERS_KEY = 'projectFolders';
const LAST_PROJECT_FOLDER_KEY = 'lastProjectFolder';
const TOOL_CONFIG_KEY = 'toolConfig';

type ProjectFolders = Record<string, string>;

function settings(): ToolBoxAPI.SettingsAPI | undefined {
    return window.toolboxAPI?.settings;
}

/** Stable key for a connection: its id, falling back to the environment URL. */
export function connectionKey(connection: { id?: string; url?: string } | null | undefined): string | undefined {
    return connection?.id || connection?.url || undefined;
}

export async function getRememberedProjectFolder(key: string | undefined): Promise<string | undefined> {
    const api = settings();
    if (!api) return undefined;
    try {
        if (key) {
            const folders = ((await api.get(PROJECT_FOLDERS_KEY)) ?? {}) as ProjectFolders;
            if (folders[key]) return folders[key];
        }
        const last = (await api.get(LAST_PROJECT_FOLDER_KEY)) as string | undefined;
        return last || undefined;
    } catch (error) {
        console.warn('Could not read remembered project folder', error);
        return undefined;
    }
}

export async function rememberProjectFolder(key: string | undefined, folder: string): Promise<void> {
    const api = settings();
    if (!api) return;
    try {
        if (key) {
            const folders = ((await api.get(PROJECT_FOLDERS_KEY)) ?? {}) as ProjectFolders;
            folders[key] = folder;
            await api.set(PROJECT_FOLDERS_KEY, folders);
        }
        await api.set(LAST_PROJECT_FOLDER_KEY, folder);
    } catch (error) {
        console.warn('Could not remember project folder', error);
    }
}

/** Settings-panel values: the bundled defaults with any saved values applied. Defaults outside PPTB. */
export async function loadToolConfig(): Promise<ToolConfig> {
    const api = settings();
    if (!api) return { ...toolConfig };
    try {
        return mergeToolConfig(await api.get(TOOL_CONFIG_KEY));
    } catch (error) {
        console.warn('Could not read saved settings', error);
        return { ...toolConfig };
    }
}

/** Saves the Settings-panel values; throws when PPTB is unavailable or the save fails. */
export async function saveToolConfig(config: ToolConfig): Promise<void> {
    const api = settings();
    if (!api) throw new Error('Settings can only be saved inside Power Platform ToolBox.');
    await api.set(TOOL_CONFIG_KEY, { ...config });
}
