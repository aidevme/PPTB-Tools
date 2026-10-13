/**
 * Settings panel values: bundled defaults from the config JSON, with saved values from PPTB's per-tool
 * settings applied on top, edited on a draft and persisted by Save.
 */
import { act, createElement, useState } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { applyProjectDefaults, mergeToolConfig, toolConfig, toolConfigEquals, type ProjectEntry, type ToolConfig } from '../src/config';
import { createDefaultConfig } from '../src/core';
import { loadToolConfig, saveToolConfig } from '../src/services/settings';
import { SettingsPanel } from '../src/components/panels/SettingsPanel';
import { NewProjectDialog } from '../src/components/dialogs/NewProjectDialog';
import { LoadProjectDialog } from '../src/components/dialogs/LoadProjectDialog';

const PROJECT: ProjectEntry = { id: 'p1', name: 'Contoso', description: 'Sales app', location: '/src/contoso', version: '1.2.0', createdOn: '2026-10-12T00:00:00.000Z', modifiedOn: '2026-10-13T00:00:00.000Z' };
const settingsWith = (change: Partial<ToolConfig>): ToolConfig => ({ ...toolConfig, ...change });

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
// jsdom has no ResizeObserver; Fluent's MessageBar uses one to choose its layout.
window.ResizeObserver ??= class {
    observe() {}
    unobserve() {}
    disconnect() {}
};

function installSettingsStub(stored: Record<string, unknown> = {}) {
    const store = { ...stored };
    (window as unknown as { toolboxAPI: unknown }).toolboxAPI = {
        settings: {
            get: async (key: string) => store[key],
            set: async (key: string, value: unknown) => {
                store[key] = value;
            },
        },
    };
    return store;
}

afterEach(() => {
    delete (window as unknown as { toolboxAPI?: unknown }).toolboxAPI;
});

describe('tool config', () => {
    it('defaults come from the bundled JSON', () => {
        expect(toolConfig).toEqual({
            deleteOrphanedFiles: false,
            projectDefaults: { outputRoot: './src/dataverse-gen', generateEntityTypes: true, generateFormContext: false, generateIndex: true },
            projects: [],
        });
    });

    it('applies saved values over the defaults and ignores unknown or mistyped ones', () => {
        expect(mergeToolConfig({ deleteOrphanedFiles: true, other: 1 })).toEqual(settingsWith({ deleteOrphanedFiles: true }));
        expect(mergeToolConfig({ deleteOrphanedFiles: 'yes' })).toEqual(toolConfig);
        expect(mergeToolConfig(undefined)).toEqual(toolConfig);
        expect(mergeToolConfig({ projects: [PROJECT, { name: 'no id' }, 'x'] })).toEqual(settingsWith({ projects: [PROJECT] }));
        expect(mergeToolConfig({ projects: 'nope' })).toEqual(toolConfig);
    });

    it('merges project defaults key by key, ignoring mistyped values and a blank output folder', () => {
        const merged = mergeToolConfig({ projectDefaults: { outputRoot: '  ./types  ', generateFormContext: true, generateIndex: 'no' } });
        expect(merged.projectDefaults).toEqual({ ...toolConfig.projectDefaults, outputRoot: './types', generateFormContext: true });
        expect(mergeToolConfig({ projectDefaults: { outputRoot: '   ' } }).projectDefaults.outputRoot).toBe('./src/dataverse-gen');
        expect(mergeToolConfig({ projectDefaults: 'x' }).projectDefaults).toEqual(toolConfig.projectDefaults);
    });

    it('applies project defaults to a new project config, keeping everything else', () => {
        const base = { ...createDefaultConfig(), entities: ['account'], output: { outputRoot: './src/dataverse-gen', fileSuffix: '.d.ts' } };
        const applied = applyProjectDefaults(base, { outputRoot: './types', generateEntityTypes: false, generateFormContext: true, generateIndex: false });
        expect(applied).toEqual({
            ...base,
            generateEntityTypes: false,
            generateFormContext: true,
            generateIndex: false,
            output: { outputRoot: './types', fileSuffix: '.d.ts' },
        });
    });

    it('fills in fields that projects saved before versions were recorded lack', () => {
        const old = { id: 'p0', name: 'Old', location: '/src/old', createdOn: '2026-01-01T00:00:00.000Z' };
        expect(mergeToolConfig({ projects: [old] }).projects).toEqual([
            { ...old, description: '', version: '1.0.0', modifiedOn: '2026-01-01T00:00:00.000Z' },
        ]);
    });

    it('compares values', () => {
        expect(toolConfigEquals(settingsWith({ deleteOrphanedFiles: true }), settingsWith({ deleteOrphanedFiles: true }))).toBe(true);
        expect(toolConfigEquals(settingsWith({ deleteOrphanedFiles: true }), settingsWith({ deleteOrphanedFiles: false }))).toBe(false);
        expect(toolConfigEquals(settingsWith({ projects: [PROJECT] }), toolConfig)).toBe(false);
    });

    it('saves to and loads from PPTB settings', async () => {
        const store = installSettingsStub();
        expect(await loadToolConfig()).toEqual(toolConfig);
        await saveToolConfig(settingsWith({ deleteOrphanedFiles: true, projects: [PROJECT] }));
        expect(store.toolConfig).toEqual(settingsWith({ deleteOrphanedFiles: true, projects: [PROJECT] }));
        expect(await loadToolConfig()).toEqual(settingsWith({ deleteOrphanedFiles: true, projects: [PROJECT] }));
    });

    it('uses the defaults outside PPTB, where saving fails', async () => {
        expect(await loadToolConfig()).toEqual(toolConfig);
        await expect(saveToolConfig(toolConfig)).rejects.toThrow('inside Power Platform ToolBox');
    });
});

describe('settings panel', () => {
    let root: Root | undefined;
    let container: HTMLElement | undefined;

    afterEach(() => {
        act(() => root?.unmount());
        container?.remove();
        root = undefined;
    });

    async function render(settings: ToolConfig, onSave: (s: ToolConfig) => Promise<void>, onOpenChange = vi.fn()) {
        container = document.body.appendChild(document.createElement('div'));
        root = createRoot(container);
        await act(async () => {
            root!.render(
                createElement(FluentProvider, { theme: webLightTheme }, createElement(SettingsPanel, { open: true, onOpenChange, settings, onSave })),
            );
        });
        return onOpenChange;
    }

    const button = (name: string) => Array.from(document.querySelectorAll('button')).find((b) => b.textContent === name) as HTMLButtonElement;
    const click = (element: HTMLElement) => act(async () => element.click());
    const openSchemaTab = () => click(Array.from(document.querySelectorAll('[role="tab"]')).find((t) => t.textContent?.includes('Schema Generation')) as HTMLElement);
    const checkbox = () => document.querySelector('input[type="checkbox"]') as HTMLInputElement;

    it('enables Save once a value changes, then saves the draft and closes', async () => {
        const onSave = vi.fn(async () => {});
        const onOpenChange = await render(toolConfig, onSave);
        expect(button('Save').disabled).toBe(true);

        await openSchemaTab();
        await click(checkbox());
        expect(button('Save').disabled).toBe(false);

        // Changing it back means nothing to save.
        await click(checkbox());
        expect(button('Save').disabled).toBe(true);

        await click(checkbox());
        await click(button('Save'));
        expect(onSave).toHaveBeenCalledWith(settingsWith({ deleteOrphanedFiles: true }));
        expect(onOpenChange).toHaveBeenCalledWith(false);
    });

    it('edits the project defaults on the Options tab', async () => {
        const onSave = vi.fn(async () => {});
        await render(toolConfig, onSave);
        await click(Array.from(document.querySelectorAll('[role="tab"]')).find((t) => t.textContent?.includes('Options')) as HTMLElement);
        const input = document.querySelector('input:not([type])') as HTMLInputElement ?? (document.querySelector('input[type="text"]') as HTMLInputElement);
        expect(input.value).toBe('./src/dataverse-gen');
        await act(async () => {
            Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, './types');
            input.dispatchEvent(new Event('input', { bubbles: true }));
        });
        const switches = Array.from(document.querySelectorAll('input[role="switch"]')) as HTMLInputElement[];
        expect(switches.map((s) => s.checked)).toEqual([true, false, true]);
        await click(switches[1]);
        expect(button('Save').disabled).toBe(false);
        await click(button('Save'));
        expect(onSave).toHaveBeenCalledWith(
            settingsWith({ projectDefaults: { outputRoot: './types', generateEntityTypes: true, generateFormContext: true, generateIndex: true } }),
        );
    });

    it('Cancel closes without saving', async () => {
        const onSave = vi.fn(async () => {});
        const onOpenChange = await render(toolConfig, onSave);
        await openSchemaTab();
        await click(checkbox());
        await click(button('Cancel'));
        expect(onSave).not.toHaveBeenCalled();
        expect(onOpenChange).toHaveBeenCalledWith(false);
    });

    it('stays open and shows the error when saving fails', async () => {
        const onSave = vi.fn(async () => {
            throw new Error('disk full');
        });
        const onOpenChange = await render(toolConfig, onSave);
        await openSchemaTab();
        await click(checkbox());
        await click(button('Save'));
        expect(onOpenChange).not.toHaveBeenCalledWith(false);
        expect(document.body.textContent).toContain('Could not save the settings: disk full');
    });
});

describe('new project dialog', () => {
    let root: Root | undefined;
    let container: HTMLElement | undefined;

    afterEach(() => {
        act(() => root?.unmount());
        container?.remove();
        root = undefined;
    });

    async function render(props: Partial<Parameters<typeof NewProjectDialog>[0]> = {}) {
        const all = {
            open: true,
            onOpenChange: vi.fn(),
            existingNames: ['Contoso'],
            onBrowseLocation: vi.fn(async () => '/projects/picked'),
            onSave: vi.fn(async () => {}),
            ...props,
        };
        container = document.body.appendChild(document.createElement('div'));
        root = createRoot(container);
        await act(async () => {
            root!.render(createElement(FluentProvider, { theme: webLightTheme }, createElement(NewProjectDialog, all)));
        });
        return all;
    }

    const button = (name: string) => Array.from(document.querySelectorAll('button')).find((b) => b.textContent === name) as HTMLButtonElement;
    const click = (element: HTMLElement) => act(async () => element.click());
    const field = (label: string) => {
        const labelElement = Array.from(document.querySelectorAll('label')).find((l) => l.textContent?.startsWith(label)) as HTMLLabelElement;
        return document.getElementById(labelElement.htmlFor) as HTMLInputElement | HTMLTextAreaElement;
    };
    const type = (element: HTMLInputElement | HTMLTextAreaElement, value: string) =>
        act(async () => {
            const setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(element), 'value')!.set!;
            setter.call(element, value);
            element.dispatchEvent(new Event('input', { bubbles: true }));
        });

    it('enables Save once name and location are set, then saves trimmed values and closes', async () => {
        const props = await render();
        expect(button('Save').disabled).toBe(true);
        await type(field('Project Name') as HTMLInputElement, '  Fabrikam  ');
        expect(button('Save').disabled).toBe(true);
        await click(button('Browse…'));
        expect(props.onBrowseLocation).toHaveBeenCalledWith('');
        expect((field('Location') as HTMLInputElement).value).toBe('/projects/picked');
        await type(field('Description'), 'Field service');
        expect(button('Save').disabled).toBe(false);

        await click(button('Save'));
        expect(props.onSave).toHaveBeenCalledWith({ name: 'Fabrikam', description: 'Field service', location: '/projects/picked' });
        expect(props.onOpenChange).toHaveBeenCalledWith(false);
    });

    it('rejects a name that is already used', async () => {
        await render();
        await type(field('Project Name') as HTMLInputElement, 'contoso');
        await type(field('Location') as HTMLInputElement, '/projects/x');
        expect(button('Save').disabled).toBe(true);
        expect(document.body.textContent).toContain('A project with this name already exists.');
    });

    it('Cancel closes without saving, and a failed save keeps the dialog open', async () => {
        const failing = await render({ onSave: vi.fn(async () => Promise.reject(new Error('quota'))) });
        await type(field('Project Name') as HTMLInputElement, 'Fabrikam');
        await type(field('Location') as HTMLInputElement, '/projects/x');
        await click(button('Save'));
        expect(failing.onOpenChange).not.toHaveBeenCalledWith(false);
        expect(document.body.textContent).toContain('Could not save the project: quota');

        await click(button('Cancel'));
        expect(failing.onOpenChange).toHaveBeenCalledWith(false);
        expect(failing.onSave).toHaveBeenCalledTimes(1);
    });
});

describe('load existing project dialog', () => {
    let root: Root | undefined;
    let container: HTMLElement | undefined;
    const OTHER: ProjectEntry = { ...PROJECT, id: 'p2', name: 'Adventure Works', description: '', location: '/src/aw' };

    afterEach(() => {
        act(() => root?.unmount());
        container?.remove();
        root = undefined;
    });

    async function render(props: Partial<Parameters<typeof LoadProjectDialog>[0]> = {}) {
        const all = { open: true, onOpenChange: vi.fn(), projects: [PROJECT, OTHER], onLoad: vi.fn(async () => true), onDelete: vi.fn(async () => {}), ...props };
        container = document.body.appendChild(document.createElement('div'));
        root = createRoot(container);
        await act(async () => {
            root!.render(createElement(FluentProvider, { theme: webLightTheme }, createElement(LoadProjectDialog, all)));
        });
        return all;
    }

    const button = (name: string) => Array.from(document.querySelectorAll('button')).find((b) => b.textContent === name) as HTMLButtonElement;
    const click = (element: HTMLElement) => act(async () => element.click());
    const radios = () => Array.from(document.querySelectorAll('input[type="radio"]')) as HTMLInputElement[];

    it('lists saved projects by name and loads the chosen one', async () => {
        const props = await render();
        const text = document.body.textContent ?? '';
        expect(text.indexOf('Adventure Works')).toBeLessThan(text.indexOf('Contoso'));
        expect(text).toContain('/src/contoso');
        expect(text).toContain('1.2.0');
        const headers = Array.from(document.querySelectorAll('th')).map((th) => th.textContent).filter(Boolean);
        expect(headers).toEqual(['Name', 'Description', 'Version', 'Location', 'Created On', 'Modified On']);
        expect(button('Load').disabled).toBe(true);

        await click(radios()[1]);
        expect(button('Load').disabled).toBe(false);
        await click(button('Load'));
        expect(props.onLoad).toHaveBeenCalledWith(PROJECT);
        expect(props.onOpenChange).toHaveBeenCalledWith(false);
    });

    it('stays open when the folder picker is cancelled, and shows load errors', async () => {
        const cancelled = await render({ onLoad: vi.fn(async () => false) });
        await click(radios()[0]);
        await click(button('Load'));
        expect(cancelled.onOpenChange).not.toHaveBeenCalledWith(false);
        act(() => root?.unmount());

        await render({ onLoad: vi.fn(async () => Promise.reject(new Error('no access'))) });
        await click(radios()[0]);
        await click(button('Load'));
        expect(document.body.textContent).toContain('Could not open Adventure Works: no access');
    });

    it('explains when there are no saved projects', async () => {
        await render({ projects: [] });
        expect(document.body.textContent).toContain('No saved projects yet.');
        expect(button('Load').disabled).toBe(true);
    });

    it('opens a project directly from its name link', async () => {
        const props = await render();
        const link = Array.from(document.querySelectorAll('button, a')).find((el) => el.textContent === 'Contoso') as HTMLElement;
        await click(link);
        expect(props.onLoad).toHaveBeenCalledWith(PROJECT);
        expect(props.onOpenChange).toHaveBeenCalledWith(false);
    });

    it('sorts by a column when its header is clicked, and flips on a second click', async () => {
        const older: ProjectEntry = { ...PROJECT, id: 'a', name: 'Alpha', version: '1.0.10', createdOn: '2026-01-01T00:00:00.000Z' };
        const newer: ProjectEntry = { ...PROJECT, id: 'b', name: 'Beta', version: '1.0.9', createdOn: '2026-06-01T00:00:00.000Z' };
        await render({ projects: [newer, older] });
        const names = () => Array.from(document.querySelectorAll('tbody tr')).map((tr) => tr.querySelectorAll('td')[1]?.textContent);
        const header = (label: string) => Array.from(document.querySelectorAll('th')).find((th) => th.textContent === label) as HTMLElement;
        const sortButton = (label: string) => (header(label).querySelector('button') ?? header(label)) as HTMLElement;

        expect(names()).toEqual(['Alpha', 'Beta']);
        expect(header('Name').getAttribute('aria-sort')).toBe('ascending');

        // Versions compare numerically: 1.0.9 < 1.0.10.
        await click(sortButton('Version'));
        expect(names()).toEqual(['Beta', 'Alpha']);
        expect(header('Version').getAttribute('aria-sort')).toBe('ascending');
        expect(header('Name').getAttribute('aria-sort')).toBe('none');

        await click(sortButton('Version'));
        expect(names()).toEqual(['Alpha', 'Beta']);
        expect(header('Version').getAttribute('aria-sort')).toBe('descending');

        await click(sortButton('Created On'));
        expect(names()).toEqual(['Alpha', 'Beta']);
    });

    it('deletes a project after confirmation, without selecting or loading it', async () => {
        const props = await render();
        const deleteButton = document.querySelector('button[aria-label="Delete Contoso"]') as HTMLButtonElement;
        expect(deleteButton).not.toBeNull();
        await click(deleteButton);
        // Nothing happens until the user confirms.
        expect(props.onDelete).not.toHaveBeenCalled();
        expect(props.onLoad).not.toHaveBeenCalled();
        expect(document.body.textContent).toContain("Contoso will be removed from your saved projects. Files in /src/contoso aren't touched.");
        expect(button('Load').disabled).toBe(true);

        await click(button('Delete'));
        expect(props.onDelete).toHaveBeenCalledWith(PROJECT);
        expect(props.onOpenChange).not.toHaveBeenCalledWith(false);
    });

    it('cancels a deletion, and shows an error when it fails', async () => {
        const failing = await render({ onDelete: vi.fn(async () => Promise.reject(new Error('locked'))) });
        await click(document.querySelector('button[aria-label="Delete Contoso"]') as HTMLButtonElement);
        const cancelButtons = () => Array.from(document.querySelectorAll('button')).filter((b) => b.textContent === 'Cancel');
        await click(cancelButtons()[cancelButtons().length - 1]);
        expect(failing.onDelete).not.toHaveBeenCalled();
        expect(document.body.textContent).not.toContain('will be removed');

        await click(document.querySelector('button[aria-label="Delete Contoso"]') as HTMLButtonElement);
        await click(button('Delete'));
        expect(document.body.textContent).toContain('Could not delete Contoso: locked');
    });

    it('actually leaves the screen on Cancel, also after a delete confirmation was used', async () => {
        // Keeps the real open state, so this checks what's rendered rather than only the callback.
        function Host() {
            const [open, setOpen] = useState(true);
            return createElement(LoadProjectDialog, { open, onOpenChange: setOpen, projects: [PROJECT], onLoad: async () => true, onDelete: async () => {} });
        }
        container = document.body.appendChild(document.createElement('div'));
        root = createRoot(container);
        await act(async () => root!.render(createElement(FluentProvider, { theme: webLightTheme }, createElement(Host))));
        const settle = () => act(async () => new Promise((resolve) => setTimeout(resolve, 400)));

        await click(document.querySelector('button[aria-label="Delete Contoso"]') as HTMLButtonElement);
        const cancelButtons = () => Array.from(document.querySelectorAll('button')).filter((b) => b.textContent === 'Cancel');
        await click(cancelButtons()[cancelButtons().length - 1]);
        await settle();
        expect(document.body.textContent).toContain('Load existing project');

        await click(button('Cancel'));
        await settle();
        expect(document.body.textContent).not.toContain('Load existing project');
    });
});
