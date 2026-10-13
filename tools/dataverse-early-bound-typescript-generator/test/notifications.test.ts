/** The notifications shown after a saved project is opened, a preview finishes, and Generate completes. */
import { afterEach, describe, expect, it, vi } from 'vitest';
import { NOTIFICATION_TYPES, notificationOptions, notifyGenerationComplete, notifyPreviewReady, notifyProjectLoaded, projectLoadedMessage } from '../src/services/notifications';
import { summarizeGeneration } from '../src/services/plan';
import type { ProjectConfigState } from '../src/services/projectConfig';

const existing = (config: ProjectConfigState['config']): ProjectConfigState => ({ path: '/p/.dataverse-gen.json', exists: true, config });

afterEach(() => {
    delete (window as unknown as { toolboxAPI?: unknown }).toolboxAPI;
    vi.restoreAllMocks();
});

describe('projectLoadedMessage', () => {
    it('summarises the loaded .dataverse-gen.json', () => {
        expect(projectLoadedMessage('Contoso', existing({ entities: ['account', 'contact'], actions: ['WinOpportunity'], functions: [] }))).toEqual({
            title: 'Contoso loaded',
            body: '.dataverse-gen.json loaded: 2 tables, 1 action, 0 functions.',
        });
    });

    it('says when the project has no .dataverse-gen.json yet', () => {
        expect(projectLoadedMessage('Fabrikam', { path: '/p/.dataverse-gen.json', exists: false, config: {} }).body).toBe(
            'No .dataverse-gen.json yet; it will be created on generate.',
        );
    });
});

describe('notifyProjectLoaded', () => {
    it('shows an info notification for five seconds', async () => {
        const showNotification = vi.fn(async () => {});
        (window as unknown as { toolboxAPI: unknown }).toolboxAPI = { utils: { showNotification } };
        await notifyProjectLoaded('Contoso', existing({ entities: ['account'] }));
        expect(showNotification).toHaveBeenCalledWith({
            title: 'Contoso loaded',
            body: '.dataverse-gen.json loaded: 1 table, 0 actions, 0 functions.',
            type: 'info',
            duration: 5000,
        });
    });

    it('is best effort: nothing outside PPTB, and a failure is only logged', async () => {
        await expect(notifyProjectLoaded('Contoso', existing({}))).resolves.toBeUndefined();

        const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
        (window as unknown as { toolboxAPI: unknown }).toolboxAPI = { utils: { showNotification: async () => Promise.reject(new Error('host closed')) } };
        await expect(notifyProjectLoaded('Contoso', existing({}))).resolves.toBeUndefined();
        expect(warn).toHaveBeenCalled();
    });
});

describe('notifyPreviewReady', () => {
    it('summarises what Generate would do', async () => {
        const showNotification = vi.fn(async () => {});
        (window as unknown as { toolboxAPI: unknown }).toolboxAPI = { utils: { showNotification } };
        await notifyPreviewReady({ projectRoot: '/p', outputRoot: '/p/out', files: [], counts: { new: 1, changed: 1, unchanged: 279, orphaned: 9 } });
        expect(showNotification).toHaveBeenCalledWith({
            title: 'Preview ready',
            body: '1 new file will be created and 1 file will be updated, and 9 orphaned files will be left untouched.',
            type: 'info',
            duration: 5000,
        });
    });
});

describe('notifyGenerationComplete', () => {
    it('reports what was written as a success', async () => {
        const showNotification = vi.fn(async () => {});
        (window as unknown as { toolboxAPI: unknown }).toolboxAPI = { utils: { showNotification } };
        await notifyGenerationComplete(2, { new: 1, changed: 1, unchanged: 279, orphaned: 9 });
        expect(showNotification).toHaveBeenCalledWith({
            title: 'Generation complete',
            body: '2 files written · 279 unchanged · 9 orphaned · .dataverse-gen.json saved',
            type: 'success',
            duration: 3000,
        });
    });

    it('uses the singular for one file', () => {
        expect(summarizeGeneration(1, { new: 0, changed: 1, unchanged: 0, orphaned: 0 })).toBe('1 file written · 0 unchanged · 0 orphaned · .dataverse-gen.json saved');
    });
});

describe('NOTIFICATION_TYPES', () => {
    it('defines a preset per PPTB type, with warnings and errors persistent', () => {
        expect(NOTIFICATION_TYPES).toEqual({
            success: { type: 'success', title: 'Success', duration: 3000 },
            info: { type: 'info', title: 'Info', duration: 5000 },
            warning: { type: 'warning', title: 'Warning', duration: 0 },
            error: { type: 'error', title: 'Error', duration: 0 },
        });
    });

    it('builds notification options, with the preset title unless one is given', () => {
        expect(notificationOptions('error', 'Failed to connect to Dataverse')).toEqual({
            title: 'Error',
            body: 'Failed to connect to Dataverse',
            type: 'error',
            duration: 0,
        });
        expect(notificationOptions('warning', 'Some records were skipped', 'Partial preview')).toMatchObject({ title: 'Partial preview', duration: 0 });
    });
});
