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
import { DATAVERSE_GEN_TEMPLATES } from '../src/services/dataverseGenTemplates';
import { version as toolVersion } from '../package.json';
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
            general: {
                showProjectLoadedNotification: true,
                showPreviewReadyNotification: true,
                showGenerationCompleteNotification: true,
                recentProjectCount: 3,
                selectionRowLimit: 500,
            },
            deleteOrphanedFiles: false,
            confirmBeforeGenerate: false,
            skipDuplicateIdentifiers: false,
            renameDuplicateIdentifiers: false,
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

    it('merges the General settings key by key, clamping and rounding numbers to their range', () => {
        const merged = mergeToolConfig({ general: { showPreviewReadyNotification: false, recentProjectCount: 7.6, selectionRowLimit: 99999, other: true } });
        expect(merged.general).toEqual({ ...toolConfig.general, showPreviewReadyNotification: false, recentProjectCount: 8, selectionRowLimit: 2000 });
        expect(mergeToolConfig({ general: { recentProjectCount: -3, selectionRowLimit: 5 } }).general).toMatchObject({ recentProjectCount: 0, selectionRowLimit: 100 });
        expect(mergeToolConfig({ general: { recentProjectCount: '5', showProjectLoadedNotification: 'no' } }).general).toEqual(toolConfig.general);
        expect(mergeToolConfig({ general: 'x' }).general).toEqual(toolConfig.general);
        // Settings saved before these keys existed load with the defaults.
        expect(mergeToolConfig({ deleteOrphanedFiles: true })).toEqual(settingsWith({ deleteOrphanedFiles: true }));
    });

    it('reads confirmBeforeGenerate only when it is a boolean', () => {
        expect(mergeToolConfig({ confirmBeforeGenerate: true }).confirmBeforeGenerate).toBe(true);
        expect(mergeToolConfig({ confirmBeforeGenerate: 'yes' }).confirmBeforeGenerate).toBe(false);
    });

    it('reads renameDuplicateIdentifiers only when it is a boolean', () => {
        expect(mergeToolConfig({ renameDuplicateIdentifiers: true }).renameDuplicateIdentifiers).toBe(true);
        expect(mergeToolConfig({ renameDuplicateIdentifiers: 'yes' }).renameDuplicateIdentifiers).toBe(false);
    });

    it('reads skipDuplicateIdentifiers only when it is a boolean', () => {
        expect(mergeToolConfig({ skipDuplicateIdentifiers: true }).skipDuplicateIdentifiers).toBe(true);
        expect(mergeToolConfig({ skipDuplicateIdentifiers: 'yes' }).skipDuplicateIdentifiers).toBe(false);
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
    const openTab = (name: string) =>
        click(Array.from(document.querySelectorAll('[role="tab"]')).find((t) => t.textContent?.startsWith(name)) as HTMLElement);
    /** The control of the setting row titled `title` (found through its aria-labelledby). */
    const control = (title: string) =>
        Array.from(document.querySelectorAll('input')).find((input) => {
            const id = input.getAttribute('aria-labelledby');
            return !!id && document.getElementById(id)?.textContent?.trim().startsWith(title);
        }) as HTMLInputElement;
    const typeInto = (input: HTMLInputElement, value: string) =>
        act(async () => {
            Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, value);
            input.dispatchEvent(new Event('input', { bubbles: true }));
        });

    it('enables Save once a value changes, then saves the draft and closes', async () => {
        const onSave = vi.fn(async () => {});
        const onOpenChange = await render(toolConfig, onSave);
        expect(button('Save').disabled).toBe(true);
        expect(document.body.textContent).toContain('No unsaved changes');

        await openTab('Generate & files');
        await click(control('Delete orphaned files'));
        expect(button('Save').disabled).toBe(false);
        expect(document.body.textContent).toContain('Unsaved changes');

        // Changing it back means nothing to save.
        await click(control('Delete orphaned files'));
        expect(button('Save').disabled).toBe(true);

        await click(control('Delete orphaned files'));
        await click(button('Save'));
        expect(onSave).toHaveBeenCalledWith(settingsWith({ deleteOrphanedFiles: true }));
        expect(onOpenChange).toHaveBeenCalledWith(false);
    });

    it('edits the project defaults on the Options tab, with a live preview of the output', async () => {
        const onSave = vi.fn(async () => {});
        await render(toolConfig, onSave);
        await openTab('Options');
        const input = control('Output folder');
        expect(input.value).toBe('./src/dataverse-gen');
        await typeInto(input, './types');
        expect(control('Early-bound entity interfaces').checked).toBe(true);
        expect(control('Form context helpers').checked).toBe(false);
        expect(control('index.ts barrel file').checked).toBe(true);

        const preview = () => document.querySelector('pre[aria-label="Preview of the generated folder structure"]')?.textContent ?? '';
        expect(preview()).toContain('./types/');
        expect(preview()).not.toContain('FormContext');
        await click(control('Form context helpers'));
        expect(preview()).toContain('FormContext');
        await click(control('index.ts barrel file'));
        expect(preview()).toContain('index.ts       (off)');
        await click(control('index.ts barrel file'));

        await click(button('Save'));
        expect(onSave).toHaveBeenCalledWith(
            settingsWith({ projectDefaults: { outputRoot: './types', generateEntityTypes: true, generateFormContext: true, generateIndex: true } }),
        );
    });

    it('edits the General settings: notification switches and the two limits', async () => {
        const onSave = vi.fn(async () => {});
        await render(toolConfig, onSave);
        // General is the first tab.
        expect(['Project loaded', 'Preview ready', 'Generation complete'].map((t) => control(t).checked)).toEqual([true, true, true]);
        await click(control('Preview ready'));
        expect(control('Recent projects').value).toBe('3');
        expect(control('Rows in the Select tables').value).toBe('500');
        // Increment the recent projects count with the arrow key.
        await act(async () => control('Recent projects').dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowUp', bubbles: true })));
        await click(button('Save'));
        expect(onSave).toHaveBeenCalledWith(
            settingsWith({ general: { ...toolConfig.general, showPreviewReadyNotification: false, recentProjectCount: 4 } }),
        );
    });

    it('groups settings into sections with scope badges, and marks changed values', async () => {
        await render(toolConfig, vi.fn(async () => {}));
        const sections = () => Array.from(document.querySelectorAll('[role="group"]')).map((g) => g.querySelector('h2, h3, [id]')?.textContent);
        expect(sections()).toEqual(['Notifications', 'Lists & startup']);
        expect(document.body.textContent).toContain('This PPTB installation');
        expect(document.querySelectorAll('[aria-label="Changed, not saved yet"]')).toHaveLength(0);
        await click(control('Project loaded'));
        expect(document.querySelectorAll('[aria-label="Changed, not saved yet"]')).toHaveLength(1);
    });

    it('offers Ask before generating, and warns while orphaned files are deleted', async () => {
        const onSave = vi.fn(async () => {});
        await render(toolConfig, onSave);
        await openTab('Generate & files');
        expect(document.body.textContent).toContain('Permanent');
        const warning = 'Files are deleted permanently';
        expect(document.body.textContent).not.toContain(warning);
        await click(control('Delete orphaned files'));
        expect(document.body.textContent).toContain(warning);
        await click(control('Delete orphaned files'));

        await click(control('Ask before generating'));
        await click(button('Save'));
        expect(onSave).toHaveBeenCalledWith(settingsWith({ confirmBeforeGenerate: true }));
    });

    it('shows the dataverse-gen templates, read-only, on the Templates tab', async () => {
        await render(toolConfig, vi.fn(async () => {}));
        await openTab('Templates');
        // Fluent repeats an unselected tab's label as hidden spacing text, so tabs are matched by value.
        const templateTabs = Array.from(document.querySelectorAll('[role="tablist"][aria-label="Templates"] [role="tab"]')).map((t) => t.getAttribute('value'));
        expect(templateTabs).toEqual(DATAVERSE_GEN_TEMPLATES.map((t) => t.name));
        const region = () => document.querySelector('[role="region"][aria-label$=" template"]') as HTMLElement;
        expect(region().getAttribute('aria-label')).toBe('action.ejs template');
        expect(document.body.textContent).toContain("Generate writes them to your project's templateRoot");
        expect(document.body.textContent).toContain('dataverse-early-bound-typescript-generator templates');
        expect(document.body.textContent).toContain(`Version ${toolVersion}`);
        expect(document.querySelector('[role="tabpanel"]')?.textContent).not.toContain('dataverse-gen ');

        const enumTab = document.querySelector('[role="tab"][value="enum.ejs"]') as HTMLElement;
        await click(enumTab);
        expect(region().textContent).toContain('// Enum <%- locals.Name %>');
        // CodeViewer: one numbered row per line, highlighted as TypeScript, with the CRLF line endings shown as plain breaks.
        const enumTemplate = DATAVERSE_GEN_TEMPLATES.find((t) => t.name === 'enum.ejs')!.content;
        const rows = Array.from(region().querySelectorAll('pre > div')) as HTMLElement[];
        expect(rows).toHaveLength(enumTemplate.replace(/\r\n$/, '').split('\r\n').length);
        expect(rows[0].firstElementChild?.textContent).toBe('1');
        expect(rows[2].querySelectorAll('span span').length).toBeGreaterThan(1);
        expect(region().textContent).not.toContain('\r');
        // Nothing to change: Save stays disabled.
        expect(button('Save').disabled).toBe(true);
    });

    it('offers Rename duplicated identifier(s) on the Generate & files tab', async () => {
        const onSave = vi.fn(async () => {});
        await render(toolConfig, onSave);
        await openTab('Generate & files');
        await click(control('Rename duplicated identifier(s)'));
        await click(button('Save'));
        expect(onSave).toHaveBeenCalledWith(settingsWith({ renameDuplicateIdentifiers: true }));
    });

    it('offers Skip duplicated identifier(s) on the Generate & files tab', async () => {
        const onSave = vi.fn(async () => {});
        await render(toolConfig, onSave);
        await openTab('Generate & files');
        await click(control('Skip duplicated identifier(s)'));
        await click(button('Save'));
        expect(onSave).toHaveBeenCalledWith(settingsWith({ skipDuplicateIdentifiers: true }));
    });

    it('searches across all tabs', async () => {
        await render(toolConfig, vi.fn(async () => {}));
        const search = document.querySelector('input[aria-label="Search settings"]') as HTMLInputElement;
        await typeInto(search, 'orphan');
        // The setting from the third tab shows while General is still the selected tab.
        expect(control('Delete orphaned files')).toBeTruthy();
        expect(control('Project loaded')).toBeUndefined();
        expect(document.body.textContent).toContain('Orphaned files · Generate & files');

        await typeInto(search, 'nothing like this');
        expect(document.body.textContent).toContain('No settings match');
    });

    it('resets to the defaults but keeps saved projects', async () => {
        const onSave = vi.fn(async () => {});
        const custom = settingsWith({
            deleteOrphanedFiles: true,
            general: { ...toolConfig.general, recentProjectCount: 7 },
            projects: [PROJECT],
        });
        await render(custom, onSave);
        expect(button('Reset to defaults').disabled).toBe(false);
        await click(button('Reset to defaults'));
        expect(button('Reset to defaults').disabled).toBe(true);
        await click(button('Save'));
        expect(onSave).toHaveBeenCalledWith(settingsWith({ projects: [PROJECT] }));
    });

    it('Cancel closes without saving', async () => {
        const onSave = vi.fn(async () => {});
        const onOpenChange = await render(toolConfig, onSave);
        await openTab('Generate & files');
        await click(control('Delete orphaned files'));
        await click(button('Cancel'));
        expect(onSave).not.toHaveBeenCalled();
        expect(onOpenChange).toHaveBeenCalledWith(false);
    });

    it('stays open and shows the error when saving fails', async () => {
        const onSave = vi.fn(async () => {
            throw new Error('disk full');
        });
        const onOpenChange = await render(toolConfig, onSave);
        await openTab('Generate & files');
        await click(control('Delete orphaned files'));
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
        const all = { open: true, onOpenChange: vi.fn(), projects: [PROJECT, OTHER], onLoad: vi.fn(async () => true), onDelete: vi.fn(async () => {}), onEdit: vi.fn(async () => {}), onBrowseLocation: vi.fn(async () => null), ...props };
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
            return createElement(LoadProjectDialog, { open, onOpenChange: setOpen, projects: [PROJECT], onLoad: async () => true, onDelete: async () => {}, onEdit: async () => {}, onBrowseLocation: async () => null });
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
