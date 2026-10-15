/** The Load Project dialog: editing a saved project from its row, and the full description in a tooltip. */
import { act, createElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { LoadProjectDialog, type ILoadProjectDialogProps } from '../src/components/dialogs/LoadProjectDialog';
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
        onBrowseLocation: vi.fn(async () => null),
        ...props,
    };
    container = document.body.appendChild(document.createElement('div'));
    root = createRoot(container);
    await act(async () => root!.render(createElement(FluentProvider, { theme: webLightTheme }, createElement(LoadProjectDialog, all))));
    return all;
}

const byLabel = (label: string) => document.querySelector(`button[aria-label="${label}"]`) as HTMLButtonElement;
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
    it('shows an Edit button before Delete on each row', async () => {
        await render();
        const labels = Array.from(document.querySelectorAll('button[aria-label]')).map((b) => b.getAttribute('aria-label'));
        expect(labels.indexOf('Edit Contoso')).toBeGreaterThan(-1);
        expect(labels.indexOf('Edit Contoso')).toBeLessThan(labels.indexOf('Delete Contoso'));
    });

    it("opens the form with the project's values and saves the changes", async () => {
        const props = await render();
        await click(byLabel('Edit Contoso'));

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
        await click(byLabel('Edit Contoso'));
        const [name] = inputs().slice(-3);

        await type(name, 'fabrikam');
        expect(document.body.textContent).toContain('A project with this name already exists.');
        expect(button('Save').disabled).toBe(true);

        await type(name, 'Contoso');
        expect(button('Save').disabled).toBe(false);
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

        const tooltip = document.querySelector('[role="tooltip"]');
        expect(tooltip?.textContent).toBe(long);
    });
});
