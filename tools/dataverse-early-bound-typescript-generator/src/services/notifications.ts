/**
 * PPTB toast notifications (`toolboxAPI.utils.showNotification`). Notifications are best effort: a failure is
 * logged and never interrupts what the user was doing.
 */
import type { ProjectConfigState } from './projectConfig';

/** How long the "project loaded" notification stays up, in milliseconds. */
export const PROJECT_LOADED_DURATION = 5000;

const plural = (count: number, one: string, many: string) => `${count} ${count === 1 ? one : many}`;

/** Title and body for the notification shown after a saved project is opened. */
export function projectLoadedMessage(projectName: string, state: ProjectConfigState): { title: string; body: string } {
    if (!state.exists) {
        return { title: `${projectName} loaded`, body: 'No .dataverse-gen.json yet; it will be created on generate.' };
    }
    const { entities = [], actions = [], functions = [] } = state.config;
    return {
        title: `${projectName} loaded`,
        body: `.dataverse-gen.json loaded: ${plural(entities.length, 'table', 'tables')}, ${plural(actions.length, 'action', 'actions')}, ${plural(functions.length, 'function', 'functions')}.`,
    };
}

/** Shows an info notification that a saved project was opened. Does nothing outside PPTB. */
export async function notifyProjectLoaded(projectName: string, state: ProjectConfigState): Promise<void> {
    const utils = window.toolboxAPI?.utils;
    if (!utils) return;
    try {
        await utils.showNotification({ ...projectLoadedMessage(projectName, state), type: 'info', duration: PROJECT_LOADED_DURATION });
    } catch (error) {
        console.warn('Could not show the project loaded notification', error);
    }
}
