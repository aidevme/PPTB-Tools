/**
 * The Header: the tool's title and version, the connection pill in both states, and the Settings button.
 */
import { act, createElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { version } from '../package.json';
import { Header } from '../src/components/layout/Header';

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

let root: Root | undefined;
let container: HTMLElement | undefined;

afterEach(() => {
    act(() => root?.unmount());
    container?.remove();
    root = undefined;
});

const CONNECTION: ToolBoxAPI.Connection = { id: 'c1', name: 'Contoso Dev', url: 'https://contoso-dev.crm.dynamics.com', environment: 'Dev' };

async function render(connection: ToolBoxAPI.Connection | null) {
    const onOpenSettings = vi.fn();
    container = document.body.appendChild(document.createElement('div'));
    root = createRoot(container);
    await act(async () => {
        root!.render(createElement(FluentProvider, { theme: webLightTheme }, createElement(Header, { connection, onOpenSettings })));
    });
    return onOpenSettings;
}

describe('Header', () => {
    it('shows the title as the page heading and the version', async () => {
        await render(null);
        expect(document.querySelector('h1')?.textContent).toBe('Dataverse Early-Bound TypeScript Generator');
        expect(document.querySelector('header')?.textContent).toContain(`v${version}`);
    });

    it('names the connected environment in the status pill', async () => {
        await render(CONNECTION);
        const status = document.querySelector('[role="status"]') as HTMLElement;
        expect(status.getAttribute('aria-label')).toBe('Connected to Contoso Dev');
        expect(status.textContent).toContain('Contoso Dev');
        // Focusable, so the URL tooltip also opens from the keyboard.
        expect(status.tabIndex).toBe(0);
    });

    it('says when there is no connection', async () => {
        await render(null);
        expect((document.querySelector('[role="status"]') as HTMLElement).textContent).toContain('Not connected');
    });

    it('opens the settings from the Settings button', async () => {
        const onOpenSettings = await render(null);
        const button = document.querySelector('button[aria-label="Settings"]') as HTMLButtonElement;
        await act(async () => button.click());
        expect(onOpenSettings).toHaveBeenCalledTimes(1);
    });
});
