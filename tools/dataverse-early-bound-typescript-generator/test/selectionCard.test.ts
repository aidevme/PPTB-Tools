/**
 * The Select card lists tables, actions and functions in Fluent UI tables with a checkbox column; clicking a
 * row or its checkbox toggles the selection.
 */
import { act, createElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { SelectionCard, type SelectionKind } from '../src/components/cards/SelectionCard';
import { computeWorkflowSteps } from '../src/components/shared/workflowSteps';
import type { EntitySummary, OperationSummary } from '../src/types';

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

const ENTITIES: EntitySummary[] = [
    { logicalName: 'account', schemaName: 'Account', displayName: 'Account', description: 'Business that represents a customer or potential customer.', metadataId: 'a', isCustom: false, isManaged: true },
    { logicalName: 'contoso_project', schemaName: 'contoso_Project', displayName: 'Project', description: '', metadataId: 'b', isCustom: true, isManaged: false },
];

const OPERATIONS: OperationSummary[] = [
    { name: 'WinOpportunity', kind: 'action', isBound: false, parameterCount: 2, isCustomApi: false, isProcessAction: false, isPrivate: false, inMetadata: true },
    {
        name: 'contoso_Escalate',
        kind: 'action',
        isBound: true,
        boundTo: 'queueitem',
        parameterCount: 0,
        isCustomApi: true,
        isProcessAction: false,
        isPrivate: true,
        displayName: 'Escalate',
        inMetadata: false,
    },
];

let root: Root | undefined;
let container: HTMLElement | undefined;

afterEach(() => {
    act(() => root?.unmount());
    container?.remove();
    root = undefined;
});

async function render(overrides: { selected?: Partial<Record<SelectionKind, string[]>>; disabled?: boolean } = {}) {
    const onToggle = vi.fn();
    container = document.body.appendChild(document.createElement('div'));
    root = createRoot(container);
    await act(async () => {
        root!.render(
            createElement(
                FluentProvider,
                { theme: webLightTheme },
                createElement(SelectionCard, {
                    step: computeWorkflowSteps({ hasProject: true, selectedCount: 0, plan: null })[1],
                    entities: ENTITIES,
                    operations: OPERATIONS,
                    solutions: [],
                    solutionEntityIds: null,
                    solutionComponentIds: null,
                    selectedSolutionId: null,
                    loadingEntities: false,
                    loadingOperations: false,
                    loadingSolution: false,
                    selected: { entities: [], actions: [], functions: [], ...overrides.selected },
                    missing: { entities: [], actions: [], functions: [] },
                    disabled: overrides.disabled ?? false,
                    onToggle,
                    onClear: vi.fn(),
                    onSolutionChange: vi.fn(),
                    onEnsureOperations: vi.fn(),
                }),
            ),
        );
    });
    return onToggle;
}

const headers = () => Array.from(document.querySelectorAll('th')).map((th) => th.textContent).filter(Boolean);
const rows = () => Array.from(document.querySelectorAll('tbody tr')) as HTMLElement[];
const rowFor = (text: string) => rows().find((r) => r.textContent?.includes(text)) as HTMLElement;
const click = (element: HTMLElement) => act(async () => element.click());

describe('selection tables', () => {
    it('lists tables with their names and type', async () => {
        await render({ selected: { entities: ['account'] } });
        expect(headers()).toEqual(['Display Name', 'Logical Name', 'Schema Name', 'Description', 'Type']);
        const accountCells = Array.from(rowFor('account').querySelectorAll('td')).map((td) => td.textContent);
        expect(accountCells[4]).toBe('Business that represents a customer or potential customer.');
        expect(rowFor('account').querySelector('[title]')).toBeNull();
        expect(Array.from(rowFor('contoso_project').querySelectorAll('td'))[4].textContent).toBe('—');
        expect(rows()).toHaveLength(2);
        expect(rowFor('contoso_project').textContent).toContain('contoso_Project');
        expect(rowFor('contoso_project').textContent).toContain('Custom');
        expect(rowFor('account').getAttribute('aria-selected')).toBe('true');
        expect((rowFor('account').querySelector('input[type="checkbox"]') as HTMLInputElement).checked).toBe(true);
    });

    it('toggles a row from the row, its checkbox, or the keyboard, once each', async () => {
        const onToggle = await render({ selected: { entities: ['account'] } });
        await click(rowFor('contoso_project'));
        expect(onToggle).toHaveBeenLastCalledWith('entities', 'contoso_project', true);

        await click(rowFor('account').querySelector('input[type="checkbox"]') as HTMLElement);
        expect(onToggle).toHaveBeenLastCalledWith('entities', 'account', false);
        expect(onToggle).toHaveBeenCalledTimes(2);

        await act(async () => rowFor('contoso_project').dispatchEvent(new KeyboardEvent('keydown', { key: ' ', bubbles: true })));
        expect(onToggle).toHaveBeenCalledTimes(3);
    });

    it('does nothing while disabled', async () => {
        const onToggle = await render({ disabled: true });
        await click(rowFor('account'));
        expect(onToggle).not.toHaveBeenCalled();
    });

    it('lists actions with binding, parameters and type', async () => {
        await render();
        const actionsTab = Array.from(document.querySelectorAll('[role="tab"]')).find((t) => t.textContent?.includes('Actions')) as HTMLElement;
        await click(actionsTab);
        expect(headers()).toEqual(['Name', 'Binding', 'Parameters', 'Type']);
        expect(rows()).toHaveLength(2);

        const custom = rowFor('contoso_Escalate');
        expect(custom.textContent).toContain('Escalate');
        expect(custom.textContent).toContain('Bound to queueitem');
        expect(custom.textContent).toContain('From definition');
        expect(custom.textContent).toContain('Private custom API');

        const builtIn = rowFor('WinOpportunity');
        expect(builtIn.textContent).toContain('Unbound');
        expect(builtIn.textContent).toContain('Built-in');
        // Custom APIs are listed first.
        expect(rows()[0]).toBe(custom);
    });

    it('links the description cell to a Fluent tooltip with the full text', async () => {
        await render();
        const descriptionCell = Array.from(rowFor('account').querySelectorAll('td'))[4];
        // A description tooltip stays in the DOM (hidden until hover) and is referenced by aria-describedby.
        const trigger = descriptionCell.querySelector('[aria-describedby]') as HTMLElement;
        expect(trigger.textContent).toBe('Business that represents a customer or potential customer.');
        const tooltip = document.getElementById(trigger.getAttribute('aria-describedby') as string);
        expect(tooltip?.getAttribute('role')).toBe('tooltip');
        expect(tooltip?.textContent).toBe('Business that represents a customer or potential customer.');
        // Rows without a description get no tooltip.
        expect(Array.from(rowFor('contoso_project').querySelectorAll('td'))[4].querySelector('[aria-describedby]')).toBeNull();
    });
});
