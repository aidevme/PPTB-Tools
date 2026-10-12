/**
 * Per-tool settings stored by PPTB (`toolboxAPI.settings`): the project folder last used with each
 * connection, so reopening the tool lands on the same project.
 */

const PROJECT_FOLDERS_KEY = 'projectFolders';
const LAST_PROJECT_FOLDER_KEY = 'lastProjectFolder';

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
