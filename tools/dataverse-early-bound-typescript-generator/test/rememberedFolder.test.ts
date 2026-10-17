/**
 * The project folder remembered per connection in PPTB's per-tool settings, which pre-fills the folder picker.
 */
import { afterEach, describe, expect, it, vi } from 'vitest';
import { connectionKey, getRememberedProjectFolder, rememberProjectFolder } from '../src/services/settings';

function installSettingsStub(stored: Record<string, unknown> = {}, { failGet = false } = {}) {
    const store = { ...stored };
    (window as unknown as { toolboxAPI: unknown }).toolboxAPI = {
        settings: {
            get: async (key: string) => {
                if (failGet) throw new Error('settings unavailable');
                return store[key];
            },
            set: async (key: string, value: unknown) => {
                store[key] = value;
            },
        },
    };
    return store;
}

afterEach(() => {
    delete (window as unknown as { toolboxAPI?: unknown }).toolboxAPI;
    vi.restoreAllMocks();
});

describe('connectionKey', () => {
    it("is the connection's id, then its URL", () => {
        expect(connectionKey({ id: 'c1', url: 'https://a' })).toBe('c1');
        expect(connectionKey({ url: 'https://a' })).toBe('https://a');
        expect(connectionKey(null)).toBeUndefined();
    });
});

describe('remembered project folder', () => {
    it('remembers the folder per connection and as the last one used', async () => {
        const store = installSettingsStub();
        await rememberProjectFolder('c1', '/src/contoso');
        await rememberProjectFolder(undefined, '/src/fabrikam');
        expect(store).toEqual({ projectFolders: { c1: '/src/contoso' }, lastProjectFolder: '/src/fabrikam' });
    });

    it("reads the connection's folder, falling back to the last one used", async () => {
        installSettingsStub({ projectFolders: { c1: '/src/contoso' }, lastProjectFolder: '/src/fabrikam' });
        expect(await getRememberedProjectFolder('c1')).toBe('/src/contoso');
        expect(await getRememberedProjectFolder('c2')).toBe('/src/fabrikam');
        expect(await getRememberedProjectFolder(undefined)).toBe('/src/fabrikam');
    });

    it('has nothing to read outside PPTB or when the settings fail', async () => {
        expect(await getRememberedProjectFolder('c1')).toBeUndefined();
        await expect(rememberProjectFolder('c1', '/src/contoso')).resolves.toBeUndefined();

        vi.spyOn(console, 'warn').mockImplementation(() => {});
        installSettingsStub({}, { failGet: true });
        expect(await getRememberedProjectFolder('c1')).toBeUndefined();
    });
});
