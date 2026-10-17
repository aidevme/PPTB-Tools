/**
 * The Select card lists tables, actions and functions in Fluent UI tables with a checkbox column; clicking a
 * row or its checkbox toggles the selection.
 */
import { act, createElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { SelectionCard, type SelectionKind } from '../src/components/cards/SelectionCard';
import { sortSelectionRows } from '../src/components/shared/sorting';
import { computeWorkflowSteps } from '../src/components/shared/workflowSteps';
import { toTableType } from '../src/services/metadataProvider';
import type { EntitySummary, OperationSummary } from '../src/types';

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

const ENTITIES: EntitySummary[] = [
    { logicalName: 'account', schemaName: 'Account', displayName: 'Account', description: 'Business that represents a customer or potential customer.', metadataId: 'a', isCustom: false, isManaged: true, tableType: 'Standard' },
    { logicalName: 'contoso_project', schemaName: 'contoso_Project', displayName: 'Project', description: '', metadataId: 'b', isCustom: true, isManaged: false, tableType: 'Activity' },
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

async function render(overrides: { selected?: Partial<Record<SelectionKind, string[]>>; disabled?: boolean; needsProject?: boolean } = {}) {
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
                    solutionFilter: { solutions: [], selectedId: null, entityIds: null, componentIds: null },
                    loading: { entities: false, operations: false, solution: false },
                    selected: { entities: [], actions: [], functions: [], ...overrides.selected },
                    missing: { entities: [], actions: [], functions: [] },
                    disabled: overrides.disabled ?? false,
                    needsProject: overrides.needsProject ?? false,
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
        expect(Array.from(rowFor('contoso_project').querySelectorAll('td'))[5].textContent).toBe('Activity');
        expect(Array.from(rowFor('account').querySelectorAll('td'))[5].textContent).toBe('Standard');
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

    it('lists nothing until a project is created or opened', async () => {
        await render({ disabled: true, needsProject: true });
        expect(document.querySelector('table')).toBeNull();
        expect(document.body.textContent).toContain('Create a new project or open an existing one (step 1)');
        expect(document.body.textContent).not.toContain('shown.');
        // Tabs, search, solution filter, switches and Clear are all disabled.
        for (const t of Array.from(document.querySelectorAll('[role="tab"]'))) expect((t as HTMLButtonElement).disabled).toBe(true);
        expect((document.querySelector('input[type="search"]') as HTMLInputElement).disabled).toBe(true);
        for (const input of Array.from(document.querySelectorAll('input[role="switch"]'))) expect((input as HTMLInputElement).disabled).toBe(true);
        const dropdown = document.querySelector('[role="combobox"]') as HTMLElement;
        expect(dropdown.hasAttribute('disabled') || dropdown.getAttribute('aria-disabled') === 'true').toBe(true);
        const clear = Array.from(document.querySelectorAll('button')).find((b) => b.textContent?.startsWith('Clear')) as HTMLButtonElement;
        expect(clear.disabled).toBe(true);
    });

    it('enables the controls once a project is open', async () => {
        await render();
        expect(document.querySelector('[role="combobox"]')?.getAttribute('aria-label')).toBe('Filter by solution');
        for (const t of Array.from(document.querySelectorAll('[role="tab"]'))) expect((t as HTMLButtonElement).disabled).toBe(false);
        expect((document.querySelector('input[type="search"]') as HTMLInputElement).disabled).toBe(false);
        for (const input of Array.from(document.querySelectorAll('input[role="switch"]'))) expect((input as HTMLInputElement).disabled).toBe(false);
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

    it('sorts by a column when its header is clicked, toggling the direction', async () => {
        await render();
        const header = (label: string) => Array.from(document.querySelectorAll('th')).find((th) => th.textContent === label) as HTMLElement;
        const sortButton = (label: string) => (header(label).querySelector('button') ?? header(label)) as HTMLElement;
        const firstRowKey = () => rows()[0].querySelectorAll('td')[2].textContent;

        expect(header('Logical Name').getAttribute('aria-sort')).toBe('none');
        await click(sortButton('Logical Name'));
        expect(header('Logical Name').getAttribute('aria-sort')).toBe('ascending');
        expect(rows().map((r) => r.querySelectorAll('td')[2].textContent)).toEqual(['account', 'contoso_project']);

        await click(sortButton('Logical Name'));
        expect(header('Logical Name').getAttribute('aria-sort')).toBe('descending');
        expect(firstRowKey()).toBe('contoso_project');

        // Tables without a description are listed last in either direction.
        await click(sortButton('Description'));
        expect(firstRowKey()).toBe('account');
        await click(sortButton('Description'));
        expect(firstRowKey()).toBe('account');
        expect(header('Logical Name').getAttribute('aria-sort')).toBe('none');
    });

    it('explains each column in a Fluent tooltip on its header cell', async () => {
        await render();
        for (const th of Array.from(document.querySelectorAll('th')).filter((cell) => cell.textContent)) {
            const describedBy = th.getAttribute('aria-describedby');
            expect(describedBy, th.textContent ?? '').toBeTruthy();
            const tooltip = document.getElementById(describedBy as string);
            expect(tooltip?.getAttribute('role')).toBe('tooltip');
            expect(tooltip?.textContent).toContain(`${th.textContent}:`);
        }
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

describe('sortSelectionRows', () => {
    const row = (key: string, ...sortValues: Array<string | number | undefined>) => ({ key, sortValues });
    const keys = (list: Array<{ key: string }>) => list.map((r) => r.key);

    it('keeps the given order until a column is sorted', () => {
        const list = [row('b', 'b'), row('a', 'a')];
        expect(sortSelectionRows(list, null)).toBe(list);
    });

    it('sorts text case-insensitively and numbers numerically, keeping ties in order', () => {
        const list = [row('x', 'beta', 10), row('y', 'Alpha', 2), row('z', 'alpha', 2)];
        expect(keys(sortSelectionRows(list, { column: 0, direction: 'ascending' }))).toEqual(['y', 'z', 'x']);
        expect(keys(sortSelectionRows(list, { column: 1, direction: 'descending' }))).toEqual(['x', 'y', 'z']);
    });

    it('lists rows without a value last in both directions', () => {
        const list = [row('none', undefined), row('one', 1), row('two', 2)];
        expect(keys(sortSelectionRows(list, { column: 0, direction: 'ascending' }))).toEqual(['one', 'two', 'none']);
        expect(keys(sortSelectionRows(list, { column: 0, direction: 'descending' }))).toEqual(['two', 'one', 'none']);
    });
});

describe('toTableType', () => {
    it('maps Dataverse metadata to the table types Power Apps shows', () => {
        expect(toTableType({ TableType: 'Elastic', IsActivity: false })).toBe('Elastic');
        expect(toTableType({ TableType: 'Virtual', IsActivity: false })).toBe('Virtual');
        // Activity tables report TableType "Standard"; IsActivity identifies them.
        expect(toTableType({ TableType: 'Standard', IsActivity: true })).toBe('Activity');
        expect(toTableType({ TableType: 'Standard', IsActivity: false })).toBe('Standard');
        // Missing properties fall back to Standard.
        expect(toTableType({})).toBe('Standard');
    });
});

describe('row limit', () => {
    it('lists at most rowLimit rows and says how many matched', async () => {
        const many: EntitySummary[] = Array.from({ length: 5 }, (_, i) => ({ ...ENTITIES[0], logicalName: `t${i}`, schemaName: `T${i}`, displayName: `Table ${i}`, metadataId: `m${i}` }));
        container = document.body.appendChild(document.createElement('div'));
        root = createRoot(container);
        await act(async () => {
            root!.render(
                createElement(
                    FluentProvider,
                    { theme: webLightTheme },
                    createElement(SelectionCard, {
                        step: computeWorkflowSteps({ hasProject: true, selectedCount: 0, plan: null })[1],
                        entities: many,
                        operations: [],
                        solutionFilter: { solutions: [], selectedId: null, entityIds: null, componentIds: null },
                        loading: { entities: false, operations: false, solution: false },
                        selected: { entities: [], actions: [], functions: [] },
                        missing: { entities: [], actions: [], functions: [] },
                        disabled: false,
                        onToggle: vi.fn(),
                        onClear: vi.fn(),
                        onSolutionChange: vi.fn(),
                        onEnsureOperations: vi.fn(),
                        rowLimit: 3,
                    }),
                ),
            );
        });
        expect(rows()).toHaveLength(3);
        expect(document.body.textContent).toContain('Showing the first 3 of 5 matches');
    });
});
