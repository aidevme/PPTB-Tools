/** The info notification shown after a saved project is opened. */
import { afterEach, describe, expect, it, vi } from 'vitest';
import { notifyProjectLoaded, projectLoadedMessage } from '../src/services/notifications';
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
