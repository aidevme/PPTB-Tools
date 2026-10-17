/**
 * PPTB toast notifications (`toolboxAPI.utils.showNotification`). Notifications are best effort: a failure is
 * logged and never interrupts what the user was doing.
 */
import type { WritePlan } from '../types';
import { plural, summarizeGeneration, summarizePlan, writeCounts } from './plan';
import type { ProjectConfigState } from './projectConfig';

/** The notification types PPTB supports. */
export type NotificationType = NonNullable<ToolBoxAPI.NotificationOptions['type']>;

/**
 * The four notification presets: PPTB's type, a default title, and how long it stays up in milliseconds
 * (`0` = until the user dismisses it). Warnings and errors stay up so they aren't missed.
 */
export const NOTIFICATION_TYPES = {
    /** Operation completed successfully. */
    success: { type: 'success', title: 'Success', duration: 3000 },
    /** Informational message. */
    info: { type: 'info', title: 'Info', duration: 5000 },
    /** Non-critical issue. */
    warning: { type: 'warning', title: 'Warning', duration: 0 },
    /** Critical failure. */
    error: { type: 'error', title: 'Error', duration: 0 },
} as const satisfies Record<NotificationType, { type: NotificationType; title: string; duration: number }>;

/** Options for `showNotification` from a preset; `title` defaults to the preset's ("Success", "Info", …). */
export function notificationOptions(kind: NotificationType, body: string, title?: string): ToolBoxAPI.NotificationOptions {
    const preset = NOTIFICATION_TYPES[kind];
    return { title: title ?? preset.title, body, type: preset.type, duration: preset.duration };
}

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

/** Shows a notification using a preset's type and duration; logs and ignores failures, and does nothing outside PPTB. */
async function show(message: { title: string; body: string }, kind: NotificationType, what: string): Promise<void> {
    const utils = window.toolboxAPI?.utils;
    if (!utils) return;
    try {
        await utils.showNotification(notificationOptions(kind, message.body, message.title));
    } catch (error) {
        console.warn(`Could not show the ${what} notification`, error);
    }
}

/** Shows an info notification that a saved project was opened. */
export async function notifyProjectLoaded(projectName: string, state: ProjectConfigState): Promise<void> {
    await show(projectLoadedMessage(projectName, state), 'info', 'project loaded');
}

/** Shows an info notification that a preview finished, with what Generate would do. */
export async function notifyPreviewReady(plan: WritePlan, deleteOrphans = false, skipDuplicates = false): Promise<void> {
    const body = summarizePlan(plan.counts, deleteOrphans, writeCounts(plan, { skipDuplicates }), skipDuplicates);
    await show({ title: 'Preview ready', body }, 'info', 'preview ready');
}

/** Shows a success notification after Generate wrote the files and saved the config; `deleted` when it deleted orphans. */
export async function notifyGenerationComplete(written: number, counts: WritePlan['counts'], deleted?: number, skipDuplicates = false): Promise<void> {
    await show({ title: 'Generation complete', body: summarizeGeneration(written, counts, deleted, skipDuplicates) }, 'success', 'generation complete');
}
