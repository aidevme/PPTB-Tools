/** The Load Project dialog: editing a saved project from its row, and the full description in a tooltip. */
import { act, createElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { LoadProjectDialog, type ILoadProjectDialogProps } from '../src/components/dialogs/LoadProjectDialog';
import { copyName } from '../src/components/dialogs/ProjectFormDialog';
import type { ProjectEntry } from '../src/config';

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

let root: Root | undefined;
let container: HTMLElement | undefined;

afterEach(() => {
    act(() => root?.unmount());
    container?.remove();
    root = undefined;
});

const project = (id: string, name: string, location: string): ProjectEntry => ({
    id,
    name,
    description: `${name} types`,
    location,
    version: '1.0.0',
    createdOn: '2026-10-01T10:00:00.000Z',
    modifiedOn: '2026-10-01T10:00:00.000Z',
});

const contoso = project('1', 'Contoso', 'C:\\src\\contoso');
const fabrikam = project('2', 'Fabrikam', 'C:\\src\\fabrikam');

async function render(props: Partial<ILoadProjectDialogProps> = {}) {
    const all: ILoadProjectDialogProps = {
        open: true,
        onOpenChange: vi.fn(),
        projects: [contoso, fabrikam],
        onLoad: vi.fn(async () => true),
        onDelete: vi.fn(async () => undefined),
        onEdit: vi.fn(async () => undefined),
        onCopy: vi.fn(async () => undefined),
        onBrowseLocation: vi.fn(async () => null),
        ...props,
    };
    container = document.body.appendChild(document.createElement('div'));
    root = createRoot(container);
    await act(async () => root!.render(createElement(FluentProvider, { theme: webLightTheme }, createElement(LoadProjectDialog, all))));
    return all;
}

/** The toolbar's button named `name` (Edit or Delete). */
const toolbarButton = (name: string) =>
    Array.from(document.querySelectorAll('[role="toolbar"] button')).find((b) => b.textContent === name) as HTMLButtonElement;
/** Selects the row of the project named `name`. */
const selectRow = (name: string) =>
    act(async () => (Array.from(document.querySelectorAll('tbody tr')).find((r) => r.textContent?.includes(name)) as HTMLElement).click());
const button = (name: string) => Array.from(document.querySelectorAll('button')).find((b) => b.textContent === name) as HTMLButtonElement;
const click = (element: HTMLElement) => act(async () => element.click());
const inputs = () => Array.from(document.querySelectorAll<HTMLInputElement | HTMLTextAreaElement>('input:not([type="radio"]), textarea'));

/** Sets a controlled input's value the way React sees a user's typing. */
async function type(element: HTMLInputElement | HTMLTextAreaElement, value: string) {
    const prototype = element instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(prototype, 'value')!.set!.call(element, value);
    await act(async () => element.dispatchEvent(new Event('input', { bubbles: true })));
}

describe('LoadProjectDialog editing', () => {
    it('has Edit and Delete in a toolbar above the table, disabled until a row is selected, and none in the rows', async () => {
        await render();
        const toolbar = document.querySelector('[role="toolbar"][aria-label="Project actions"]')!;
        expect(Array.from(toolbar.querySelectorAll('button')).map((b) => b.textContent)).toEqual(['Copy', 'Edit', 'Delete']);
        expect(toolbar.compareDocumentPosition(document.querySelector('table')!) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
        // The rows keep only the name link (a button without an href): no Edit or Delete buttons.
        expect(Array.from(document.querySelectorAll('tbody button')).map((b) => b.textContent)).toEqual(['Contoso', 'Fabrikam']);
        expect(toolbarButton('Copy').disabled).toBe(true);
        expect(toolbarButton('Edit').disabled).toBe(true);
        expect(toolbarButton('Delete').disabled).toBe(true);
        await selectRow('Contoso');
        expect(toolbarButton('Copy').disabled).toBe(false);
        expect(toolbarButton('Edit').disabled).toBe(false);
        expect(toolbarButton('Delete').disabled).toBe(false);
    });

    it('shows the project count, which project is selected, and closes from the title', async () => {
        const props = await render();
        expect(document.body.textContent).toContain('2 saved projects');
        expect(document.body.textContent).toContain('Select a project to load, copy, edit or delete it');
        await selectRow('Fabrikam');
        expect(document.querySelector('[role="toolbar"]')?.textContent).toContain('Selected: Fabrikam');
        await click(document.querySelector('button[aria-label="Close"]') as HTMLButtonElement);
        expect(props.onOpenChange).toHaveBeenCalledWith(false);
    });

    it("opens the form with the project's values and saves the changes", async () => {
        const props = await render();
        await selectRow('Contoso');
        await click(toolbarButton('Edit'));

        expect(document.body.textContent).toContain('Edit project');
        const [name, description, location] = inputs().slice(-3);
        expect([name.value, description.value, location.value]).toEqual(['Contoso', 'Contoso types', 'C:\\src\\contoso']);

        await type(description, 'Contoso web resources');
        await click(button('Save'));

        expect(props.onEdit).toHaveBeenCalledWith(contoso, { name: 'Contoso', description: 'Contoso web resources', location: 'C:\\src\\contoso' });
        expect(props.onLoad).not.toHaveBeenCalled();
    });

    it("rejects another project's name but keeps its own", async () => {
        await render();
        await selectRow('Contoso');
        await click(toolbarButton('Edit'));
        const [name] = inputs().slice(-3);

        await type(name, 'fabrikam');
        expect(document.body.textContent).toContain('A project with this name already exists.');
        expect(button('Save').disabled).toBe(true);

        await type(name, 'Contoso');
        expect(button('Save').disabled).toBe(false);
    });
});

describe('LoadProjectDialog copying', () => {
    it("opens the form filled in from the selected project, with a free name, and saves a new project", async () => {
        const props = await render();
        await selectRow('Contoso');
        await click(toolbarButton('Copy'));

        expect(document.body.textContent).toContain('Copy project');
        expect(document.body.textContent).toContain("Save a new project from Contoso's details");
        const [name, description, location] = inputs().slice(-3);
        expect([name.value, description.value, location.value]).toEqual(['Contoso (copy)', 'Contoso types', contoso.location]);
        // A copy has no version or dates yet.
        expect(document.body.textContent).not.toContain('· Created');

        await type(name, 'Contoso EU');
        await click(button('Save'));
        expect(props.onCopy).toHaveBeenCalledWith({ name: 'Contoso EU', description: 'Contoso types', location: contoso.location });
        expect(props.onEdit).not.toHaveBeenCalled();
        expect(props.onLoad).not.toHaveBeenCalled();
    });
});

describe('LoadProjectDialog copy selection', () => {
    it('selects the saved copy once it shows up in the list', async () => {
        const props = await render();
        await selectRow('Contoso');
        await click(toolbarButton('Copy'));
        await click(button('Save'));
        expect(props.onCopy).toHaveBeenCalledWith(expect.objectContaining({ name: 'Contoso (copy)' }));
        const copy = project('3', 'Contoso (copy)', contoso.location);
        await act(async () =>
            root!.render(createElement(FluentProvider, { theme: webLightTheme }, createElement(LoadProjectDialog, { ...props, projects: [contoso, fabrikam, copy] }))),
        );
        expect(document.querySelector('[role="toolbar"]')?.textContent).toContain('Selected: Contoso (copy)');
    });
});

describe('copyName', () => {
    it('adds (copy), then a number, skipping names in use regardless of case', () => {
        expect(copyName('Contoso', ['Contoso'])).toBe('Contoso (copy)');
        expect(copyName(' Contoso ', ['Contoso', 'contoso (COPY)'])).toBe('Contoso (copy 2)');
        expect(copyName('Contoso', ['Contoso', 'Contoso (copy)', 'Contoso (copy 2)'])).toBe('Contoso (copy 3)');
    });
});

describe('LoadProjectDialog description', () => {
    it('shows the full description in a tooltip', async () => {
        const long = 'Types for the Contoso web resources.\nUsed by the account and contact forms.';
        await render({ projects: [{ ...contoso, description: long }] });
        const cell = Array.from(document.querySelectorAll('td')).find((td) => td.textContent?.startsWith('Types for')) as HTMLElement;
        const trigger = cell.firstElementChild as HTMLElement;

        await act(async () => {
            trigger.dispatchEvent(new FocusEvent('focusin', { bubbles: true }));
            trigger.focus();
        });

        // The toolbar's buttons have description tooltips too, so look for this one among them.
        const tooltips = Array.from(document.querySelectorAll('[role="tooltip"]')).map((t) => t.textContent);
        expect(tooltips).toContain(long);
    });
});
