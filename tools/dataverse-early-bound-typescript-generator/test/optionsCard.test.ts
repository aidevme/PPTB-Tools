/**
 * The Options card: the output folder and the three generated-file switches edit the project config, and nothing
 * can be edited while the card is disabled.
 */
import { act, createElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { DEFAULT_OUTPUT_ROOT, type DataverseGenConfig } from '../src/core';
import { OptionsCard } from '../src/components/cards/OptionsCard';
import { computeWorkflowSteps } from '../src/components/shared/workflowSteps';

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

let root: Root | undefined;
let container: HTMLElement | undefined;

afterEach(() => {
    act(() => root?.unmount());
    container?.remove();
    root = undefined;
});

async function render(config: DataverseGenConfig, disabled = false) {
    const onChange = vi.fn();
    const step = computeWorkflowSteps({ hasProject: true, selectedCount: 1, plan: null })[2];
    container = document.body.appendChild(document.createElement('div'));
    root = createRoot(container);
    await act(async () => {
        root!.render(createElement(FluentProvider, { theme: webLightTheme }, createElement(OptionsCard, { step, config, disabled, onChange })));
    });
    return onChange;
}

/** The input labelled by the Field or Switch whose label starts with `label`. */
const control = (label: string) => {
    const element = Array.from(document.querySelectorAll('label')).find((l) => l.textContent?.startsWith(label)) as HTMLLabelElement;
    return document.getElementById(element.htmlFor) as HTMLInputElement;
};

const type = (input: HTMLInputElement, value: string) =>
    act(async () => {
        Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, value);
        input.dispatchEvent(new Event('input', { bubbles: true }));
    });

describe('OptionsCard', () => {
    it('shows the defaults when the config leaves them out', async () => {
        await render({});
        expect(control('Output folder').value).toBe(DEFAULT_OUTPUT_ROOT);
        expect(control('Early-bound entity interfaces').checked).toBe(true);
        expect(control('Form context helpers').checked).toBe(false);
        expect(control('index.ts barrel file').checked).toBe(true);
    });

    it('reports a new output folder, keeping the other output settings', async () => {
        const onChange = await render({ output: { outputRoot: './src/types', templateRoot: './_templates' } });
        await type(control('Output folder'), './generated');
        expect(onChange).toHaveBeenLastCalledWith({ output: { outputRoot: './generated', templateRoot: './_templates' } });
    });

    it('reports each switch with its config key', async () => {
        const onChange = await render({ generateEntityTypes: true, generateFormContext: false, generateIndex: true });
        await act(async () => control('Early-bound entity interfaces').click());
        expect(onChange).toHaveBeenLastCalledWith({ generateEntityTypes: false });
        await act(async () => control('Form context helpers').click());
        expect(onChange).toHaveBeenLastCalledWith({ generateFormContext: true });
        await act(async () => control('index.ts barrel file').click());
        expect(onChange).toHaveBeenLastCalledWith({ generateIndex: false });
    });

    it('disables every control while disabled', async () => {
        await render({}, true);
        for (const label of ['Output folder', 'Early-bound entity interfaces', 'Form context helpers', 'index.ts barrel file']) {
            expect(control(label).disabled).toBe(true);
        }
    });
});
