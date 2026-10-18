/**
 * The Footer: the tool's name and version, the credits to dataverse-ify and dataverse-gen, and the project links,
 * all opening in a new window.
 */
import { act, createElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { version } from '../package.json';
import { Footer } from '../src/components/layout/Footer';

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

let root: Root | undefined;
let container: HTMLElement | undefined;

beforeEach(async () => {
    container = document.body.appendChild(document.createElement('div'));
    root = createRoot(container);
    await act(async () => {
        root!.render(createElement(FluentProvider, { theme: webLightTheme }, createElement(Footer)));
    });
});

afterEach(() => {
    act(() => root?.unmount());
    container?.remove();
    root = undefined;
});

const link = (text: string) => Array.from(document.querySelectorAll('footer a')).find((a) => a.textContent?.startsWith(text)) as HTMLAnchorElement;

describe('Footer', () => {
    it('shows the tool name and version', () => {
        expect(document.querySelector('footer')?.textContent).toContain(`v${version} · Part of PPTB Tools`);
    });

    it('credits dataverse-ify and dataverse-gen in new windows', () => {
        for (const [name, url] of [
            ['dataverse-ify', 'https://github.com/scottdurow/dataverse-ify'],
            ['dataverse-gen', 'https://github.com/scottdurow/dataverse-gen'],
        ]) {
            expect(link(name).href).toBe(url);
            expect(link(name).target).toBe('_blank');
            expect(link(name).rel).toBe('noreferrer');
        }
    });

    it('links the documentation and the repository in a labelled nav, marked as opening in a new window', () => {
        const nav = document.querySelector('nav[aria-label="Project links"]') as HTMLElement;
        expect(nav).not.toBeNull();
        expect(link('Documentation').href).toBe('https://aidevme.github.io/PPTB-Tools/pptb-tools/dataverse-early-bound-typescript-generator/getting-started/');
        expect(link('GitHub Repo').href).toBe('https://github.com/aidevme/PPTB-Tools');
        expect(nav.querySelectorAll('[aria-label="(opens in a new window)"]')).toHaveLength(2);
    });
});
