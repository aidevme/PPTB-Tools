/** The reusable confirmation dialog only reports the user's choice; the caller performs the action. */
import { act, createElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ConfirmationDialog, type IConfirmationDialogProps } from '../src/components/dialogs/ConfirmationDialog';

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

let root: Root | undefined;
let container: HTMLElement | undefined;

afterEach(() => {
    act(() => root?.unmount());
    container?.remove();
    root = undefined;
});

async function render(props: Partial<IConfirmationDialogProps> = {}) {
    const all: IConfirmationDialogProps = {
        open: true,
        title: 'Delete project?',
        message: 'Contoso will be removed.',
        confirmLabel: 'Delete',
        busyLabel: 'Deleting…',
        onConfirm: vi.fn(),
        onCancel: vi.fn(),
        ...props,
    };
    container = document.body.appendChild(document.createElement('div'));
    root = createRoot(container);
    await act(async () => root!.render(createElement(FluentProvider, { theme: webLightTheme }, createElement(ConfirmationDialog, all))));
    return all;
}

const button = (name: string) => Array.from(document.querySelectorAll('button')).find((b) => b.textContent === name) as HTMLButtonElement;
const click = (element: HTMLElement) => act(async () => element.click());

describe('ConfirmationDialog', () => {
    it('shows the title and message as an alert dialog', async () => {
        await render();
        expect(document.querySelector('[role="alertdialog"]')).not.toBeNull();
        expect(document.body.textContent).toContain('Delete project?');
        expect(document.body.textContent).toContain('Contoso will be removed.');
    });

    it('reports Confirm and Cancel', async () => {
        const props = await render();
        await click(button('Delete'));
        expect(props.onConfirm).toHaveBeenCalledTimes(1);
        await click(button('Cancel'));
        expect(props.onCancel).toHaveBeenCalledTimes(1);
    });

    it('cancels on Escape', async () => {
        const props = await render();
        const surface = document.querySelector('[role="alertdialog"]') as HTMLElement;
        await act(async () => surface.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true })));
        expect(props.onCancel).toHaveBeenCalled();
    });

    it('disables both buttons and ignores Escape while busy', async () => {
        const props = await render({ busy: true });
        expect(button('Deleting…').disabled).toBe(true);
        expect(button('Cancel').disabled).toBe(true);
        const surface = document.querySelector('[role="alertdialog"]') as HTMLElement;
        await act(async () => surface.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true })));
        expect(props.onCancel).not.toHaveBeenCalled();
    });

    it('renders nothing while closed', async () => {
        await render({ open: false });
        expect(document.querySelector('[role="alertdialog"]')).toBeNull();
    });
});
