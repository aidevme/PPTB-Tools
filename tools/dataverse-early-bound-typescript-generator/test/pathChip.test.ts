/**
 * PathChip: the path shortened in the middle, and a copy button whose tooltip names the path and which reports
 * the full path with its label.
 */
import { act, createElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { PathChip } from '../src/components/shared/PathChip';
import { shortenPath } from '../src/components/shared/format';

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

let root: Root | undefined;
let container: HTMLElement | undefined;

afterEach(() => {
    act(() => root?.unmount());
    container?.remove();
    root = undefined;
});

const PATH = 'C:\\Users\\someone\\source\\repos\\Contoso\\Client\\clientjs\\src\\types\\generated';

async function render(props: { maxLength?: number; appearance?: 'plain' | 'filled' } = {}) {
    const onCopy = vi.fn();
    container = document.body.appendChild(document.createElement('div'));
    root = createRoot(container);
    await act(async () => {
        root!.render(createElement(FluentProvider, { theme: webLightTheme }, createElement(PathChip, { path: PATH, label: 'Output folder path', onCopy, ...props })));
    });
    return onCopy;
}

describe('PathChip', () => {
    it('shows the path shortened to the given length', async () => {
        await render({ maxLength: 64, appearance: 'filled' });
        expect(container!.textContent).toContain(shortenPath(PATH, 64));
        expect(container!.textContent).not.toContain(PATH);
    });

    it('copies the full path with its label from a button named after the label', async () => {
        const onCopy = await render();
        const button = document.querySelector('button[aria-label="Copy output folder path"]') as HTMLButtonElement;
        expect(button).not.toBeNull();
        await act(async () => button.click());
        expect(onCopy).toHaveBeenCalledWith(PATH, 'Output folder path');
    });
});
