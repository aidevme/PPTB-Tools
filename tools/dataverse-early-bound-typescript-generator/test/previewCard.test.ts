/** The Preview card lists generated files in a table with Name, Type and Status columns. */
import { act, createElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { PreviewCard, fileType, sortFiles, summarizePlan, visibleFiles, type PreviewCardProps } from '../src/components/cards/PreviewCard';
import { computeWorkflowSteps } from '../src/components/shared/workflowSteps';
import type { PlannedFile, WritePlan } from '../src/types';

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

describe('fileType', () => {
    it('comes from the output folder, or the name for files at the root', () => {
        expect(fileType('entities/Account.ts')).toBe('entities');
        expect(fileType('enums/account_statuscode.ts')).toBe('enums');
        expect(fileType('actions/WinOpportunity.ts')).toBe('actions');
        expect(fileType('functions/WhoAmI.ts')).toBe('functions');
        expect(fileType('metadata.ts')).toBe('metadata');
        expect(fileType('metadata.d.ts')).toBe('metadata');
        expect(fileType('complextypes/WhoAmIResponse.ts')).toBe('other');
        expect(fileType('index.ts')).toBe('other');
    });
});

const file = (relativePath: string, status: PlannedFile['status']): PlannedFile => ({
    relativePath,
    absolutePath: `C:/repo/src/dataverse-gen/${relativePath}`,
    status,
    // Orphans exist on disk but aren't generated, so they have no content.
    content: status === 'orphaned' ? undefined : 'export {};',
});

const PLAN: WritePlan = {
    projectRoot: 'C:/repo',
    outputRoot: 'C:/repo/src/dataverse-gen',
    files: [file('entities/Account.ts', 'unchanged'), file('entities/Competitor.ts', 'changed'), file('metadata.ts', 'new'), file('enums/old.ts', 'orphaned')],
    counts: { new: 1, changed: 1, unchanged: 1, orphaned: 1 },
};

let root: Root | undefined;
let container: HTMLElement | undefined;

afterEach(() => {
    act(() => root?.unmount());
    container?.remove();
    root = undefined;
});

(globalThis as { ResizeObserver?: unknown }).ResizeObserver ??= class {
    observe() {}
    unobserve() {}
    disconnect() {}
};

async function render(overrides: Partial<PreviewCardProps> = {}, { showUnchanged = true } = {}) {
    container = document.body.appendChild(document.createElement('div'));
    root = createRoot(container);
    await act(async () =>
        root!.render(
            createElement(
                FluentProvider,
                { theme: webLightTheme },
                createElement(PreviewCard, {
                    step: computeWorkflowSteps({ hasProject: true, selectedCount: 1, plan: { pending: 2, stale: false } })[3],
                    plan: PLAN,
                    stale: false,
                    canPreview: true,
                    needsProject: false,
                    busy: false,
                    previewedAt: null,
                    lastResult: null,
                    deleteOrphans: false,
                    onDeleteOrphansChange: vi.fn(),
                    onPreview: vi.fn(),
                    onGenerate: vi.fn(),
                    onCopyText: vi.fn(),
                    ...overrides,
                } as PreviewCardProps),
            ),
        ),
    );
    // Most tests look at every file; unchanged files are hidden until this switch is on.
    if (showUnchanged) {
        const input = Array.from(document.querySelectorAll('input[role="switch"]')).find((i) =>
            document.querySelector(`label[for="${i.id}"]`)?.textContent?.includes('Show unchanged'),
        ) as HTMLInputElement | undefined;
        await act(async () => input?.click());
    }
}

const rows = () => Array.from(document.querySelectorAll('table[aria-label="Generated files"] tbody tr')) as HTMLElement[];
const cells = (row: HTMLElement) => Array.from(row.querySelectorAll('td')).map((td) => td.textContent);

describe('PreviewCard file table', () => {
    it('shows name, type and status for each file', async () => {
        await render();
        const headers = Array.from(document.querySelectorAll('table[aria-label="Generated files"] th')).map((th) => th.textContent);
        expect(headers).toEqual(['Name', 'Type', 'Status']);
        expect(rows().map(cells)).toEqual([
            ['Account.ts', 'entities', 'unchanged'],
            ['Competitor.ts', 'entities', 'changed'],
            ['metadata.ts', 'metadata', 'new'],
            ['old.ts', 'enums', 'orphaned'],
        ]);
    });

    it('selects a row to show the file, from a click or the keyboard', async () => {
        await render();
        await act(async () => rows()[1].click());
        expect(rows()[1].getAttribute('aria-selected')).toBe('true');
        expect(document.body.textContent).not.toContain('Select a file to view');

        await act(async () => rows()[3].dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true })));
        expect(rows()[3].getAttribute('aria-selected')).toBe('true');
        expect(document.body.textContent).toContain('no longer generates it');
    });
});

describe('sorting the file table', () => {
    const names = (files: PlannedFile[]) => files.map((f) => f.relativePath);

    it('keeps the plan order until a column is sorted', () => {
        expect(names(sortFiles(PLAN.files, null))).toEqual(names(PLAN.files));
    });

    it('sorts by name ignoring case and numbers naturally, by type, and by status in filter order', () => {
        const files = [file('entities/b10.ts', 'new'), file('enums/A.ts', 'orphaned'), file('entities/b9.ts', 'unchanged'), file('metadata.ts', 'changed')];
        expect(names(sortFiles(files, { column: 'name', direction: 'ascending' }))).toEqual(['enums/A.ts', 'entities/b9.ts', 'entities/b10.ts', 'metadata.ts']);
        expect(names(sortFiles(files, { column: 'type', direction: 'ascending' }))).toEqual(['entities/b9.ts', 'entities/b10.ts', 'enums/A.ts', 'metadata.ts']);
        expect(names(sortFiles(files, { column: 'status', direction: 'ascending' }))).toEqual(['entities/b10.ts', 'metadata.ts', 'entities/b9.ts', 'enums/A.ts']);
        expect(names(sortFiles(files, { column: 'status', direction: 'descending' }))).toEqual(['enums/A.ts', 'entities/b9.ts', 'metadata.ts', 'entities/b10.ts']);
    });

    it('sorts when a header is clicked and flips on a second click', async () => {
        await render();
        const header = (label: string) => Array.from(document.querySelectorAll('table[aria-label="Generated files"] th')).find((th) => th.textContent === label) as HTMLElement;
        const sortButton = (label: string) => (header(label).querySelector('button') ?? header(label)) as HTMLElement;
        const firstNames = () => rows().map((r) => cells(r)[0]);

        expect(header('Name').getAttribute('aria-sort')).toBe('none');
        await act(async () => sortButton('Status').click());
        expect(header('Status').getAttribute('aria-sort')).toBe('ascending');
        expect(firstNames()).toEqual(['metadata.ts', 'Competitor.ts', 'Account.ts', 'old.ts']);

        await act(async () => sortButton('Status').click());
        expect(header('Status').getAttribute('aria-sort')).toBe('descending');
        expect(firstNames()).toEqual(['old.ts', 'Account.ts', 'Competitor.ts', 'metadata.ts']);

        await act(async () => sortButton('Name').click());
        expect(firstNames()).toEqual(['Account.ts', 'Competitor.ts', 'metadata.ts', 'old.ts']);
    });

    it('explains each column in a tooltip on its header cell', async () => {
        await render();
        const headers = Array.from(document.querySelectorAll('table[aria-label="Generated files"] th')) as HTMLElement[];
        const help = headers.map((th) => document.getElementById(th.getAttribute('aria-describedby') ?? '')?.textContent ?? '');
        expect(help[0]).toContain('without its output folder');
        for (const type of ['entities', 'enums', 'actions', 'functions', 'metadata', 'other']) expect(help[1]).toContain(type);
        for (const status of ['new', 'changed', 'unchanged', 'orphaned']) expect(help[2]).toContain(status);
        for (const text of help) expect(text).toMatch(/Click to sort/);
    });
});

describe('summary and filtering', () => {
    it('describes what Generate would do', () => {
        expect(summarizePlan({ new: 1, changed: 2, unchanged: 5, orphaned: 3 })).toBe(
            '1 new file will be created and 2 files will be updated, and 3 orphaned files will be left untouched.',
        );
        expect(summarizePlan({ new: 0, changed: 0, unchanged: 5, orphaned: 0 })).toBe('Everything is up to date; nothing will be written.');
        expect(summarizePlan({ new: 0, changed: 1, unchanged: 5, orphaned: 1 }, true)).toBe('1 file will be updated, and 1 orphaned file will be deleted.');
    });

    it('hides unchanged files by default, and filters by status and search', () => {
        const paths = (filter: Parameters<typeof visibleFiles>[1]) => visibleFiles(PLAN.files, filter).map((f) => f.relativePath);
        expect(paths({ status: null, showUnchanged: false, search: '' })).toEqual(['entities/Competitor.ts', 'metadata.ts', 'enums/old.ts']);
        expect(paths({ status: null, showUnchanged: true, search: '' })).toHaveLength(4);
        expect(paths({ status: 'unchanged', showUnchanged: false, search: '' })).toEqual(['entities/Account.ts']);
        expect(paths({ status: null, showUnchanged: true, search: 'ENTITIES/' })).toEqual(['entities/Account.ts', 'entities/Competitor.ts']);
    });
});

describe('PreviewCard layout', () => {
    const button = (text: string) => Array.from(document.querySelectorAll('button')).find((b) => b.textContent?.includes(text)) as HTMLButtonElement;
    const tile = (label: string) =>
        Array.from(document.querySelectorAll('[aria-label="Filter by status"] button')).find((b) => b.textContent?.endsWith(label)) as HTMLButtonElement;

    it('shows the summary, the tiles and the Generate count', async () => {
        await render({ previewedAt: '2026-10-13T11:58:00.000Z', now: Date.parse('2026-10-13T12:00:00.000Z') }, { showUnchanged: false });
        const text = document.body.textContent ?? '';
        expect(text).toContain('1 new file will be created and 1 file will be updated, and 1 orphaned file will be left untouched.');
        expect(text).toContain('Previewed 2 minutes ago');
        expect(button('Generate 2 files').disabled).toBe(false);
        expect(tile('Unchanged').textContent).toBe('1Unchanged');
        expect(rows()).toHaveLength(3);
        expect(text).toContain('Showing 3 of 4 files');
    });

    it('filters by a tile, and clears the filter on a second click', async () => {
        await render({}, { showUnchanged: false });
        await act(async () => tile('Unchanged').click());
        expect(tile('Unchanged').getAttribute('aria-pressed')).toBe('true');
        expect(rows().map((r) => cells(r)[0])).toEqual(['Account.ts']);
        await act(async () => tile('Unchanged').click());
        expect(rows()).toHaveLength(3);
    });

    it('says when nothing needs writing, and offers to preview again when stale', async () => {
        const onPreview = vi.fn();
        const upToDate: WritePlan = { ...PLAN, files: [file('entities/Account.ts', 'unchanged')], counts: { new: 0, changed: 0, unchanged: 1, orphaned: 0 } };
        await render({ plan: upToDate, stale: true, onPreview }, { showUnchanged: false });
        expect(button('Nothing to write').disabled).toBe(true);
        expect(document.body.textContent).toContain('Nothing to write. Turn on Show unchanged to list every file.');
        await act(async () => button('Preview again').click());
        expect(onPreview).toHaveBeenCalled();
    });

    it('shows the last Generate result', async () => {
        await render({ lastResult: '2 files written · .dataverse-gen.json saved' });
        expect(document.body.textContent).toContain('2 files written · .dataverse-gen.json saved');
    });

    it('moves the selection with the arrow keys', async () => {
        await render();
        await act(async () => rows()[0].click());
        await act(async () => rows()[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true })));
        expect(rows()[1].getAttribute('aria-selected')).toBe('true');
        expect(document.activeElement).toBe(rows()[1]);
        await act(async () => rows()[1].dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowUp', bubbles: true })));
        expect(rows()[0].getAttribute('aria-selected')).toBe('true');
    });

    it('resizes the file list from the keyboard', async () => {
        await render();
        const splitter = document.querySelector('[role="separator"]') as HTMLElement;
        const before = Number(splitter.getAttribute('aria-valuenow'));
        await act(async () => splitter.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true })));
        expect(Number(splitter.getAttribute('aria-valuenow'))).toBe(before + 32);
    });
});

describe('FileViewer in the Preview card', () => {
    const select = async (name: string) => act(async () => rows().find((r) => cells(r)[0] === name)!.click());

    it('starts with an empty state', async () => {
        await render();
        expect(document.body.textContent).toContain('Select a file to preview it');
    });

    it('shows a header, copies content, and shows the changes for a changed file', async () => {
        const onCopyText = vi.fn();
        const changed: PlannedFile = { ...file('entities/Competitor.ts', 'changed'), content: 'a\nB\nc', existingContent: 'a\nb\nc' };
        await render({ plan: { ...PLAN, files: [changed], counts: { new: 0, changed: 1, unchanged: 0, orphaned: 0 } }, onCopyText });
        await select('Competitor.ts');
        const region = document.querySelector('[role="region"]') as HTMLElement;
        expect(document.body.textContent).toContain('3 lines');
        // Fluent tabs repeat their label in a hidden span (reserving space for the bold selected style).
        const tabs = Array.from(document.querySelectorAll('[role="tab"]')).map((t) => t.textContent ?? '');
        expect(tabs).toHaveLength(2);
        expect(tabs[0]).toContain('Changes');
        expect(tabs[1]).toContain('Generated content');
        expect(region.querySelector('[aria-label="Changes: 1 added, 1 removed"]')).not.toBeNull();

        await act(async () => (document.querySelector('button[aria-label="Copy the generated content"]') as HTMLButtonElement).click());
        expect(onCopyText).toHaveBeenCalledWith('a\nB\nc', 'Competitor.ts content');

        await act(async () => (Array.from(document.querySelectorAll('[role="tab"]')).find((t) => t.textContent?.includes('Generated content')) as HTMLElement).click());
        expect(region.querySelector('[aria-label^="Changes:"]')).toBeNull();
    });

    it('explains an orphaned file', async () => {
        await render();
        await select('old.ts');
        expect(document.body.textContent).toContain('no longer generates it');
        expect(document.querySelector('[role="tab"]')).toBeNull();
    });
});

describe('Delete orphaned files switch', () => {
    const button = (text: string) => Array.from(document.querySelectorAll('button')).find((b) => b.textContent?.includes(text)) as HTMLButtonElement;
    const deleteSwitch = () =>
        Array.from(document.querySelectorAll('input[role="switch"]')).find((input) =>
            document.querySelector(`label[for="${input.id}"]`)?.textContent?.includes('Delete orphaned files'),
        ) as HTMLInputElement;

    it('reflects the setting, reports changes, and explains itself in a tooltip', async () => {
        const onDeleteOrphansChange = vi.fn();
        await render({ onDeleteOrphansChange });
        const input = deleteSwitch();
        expect(input.checked).toBe(false);
        await act(async () => input.click());
        expect(onDeleteOrphansChange).toHaveBeenCalledWith(true);
        const tooltip = document.getElementById(input.closest('[aria-describedby]')?.getAttribute('aria-describedby') ?? input.getAttribute('aria-describedby') ?? '');
        expect(tooltip?.textContent).toMatch(/permanently/);
    });

    it('says orphans will be deleted, and lets Generate run when only deletions are pending', async () => {
        const orphansOnly = {
            ...PLAN,
            files: PLAN.files.filter((f) => f.status === 'orphaned' || f.status === 'unchanged'),
            counts: { new: 0, changed: 0, unchanged: 1, orphaned: 1 },
        };
        await render({ plan: orphansOnly, deleteOrphans: true });
        expect(document.body.textContent).toContain('1 orphaned file will be deleted.');
        expect(deleteSwitch().checked).toBe(true);
        expect(button('Delete 1 orphaned file').disabled).toBe(false);
    });

    it('is disabled until a preview exists', async () => {
        await render({ plan: null }, { showUnchanged: false });
        const input = deleteSwitch();
        expect(input.disabled).toBe(true);
        const tooltip = document.getElementById(input.closest('[aria-describedby]')?.getAttribute('aria-describedby') ?? input.getAttribute('aria-describedby') ?? '');
        expect(tooltip?.textContent).toMatch(/Available after Preview/);
    });

    it('keeps Generate disabled with nothing to write while the switch is off', async () => {
        const orphansOnly = {
            ...PLAN,
            files: PLAN.files.filter((f) => f.status === 'orphaned' || f.status === 'unchanged'),
            counts: { new: 0, changed: 0, unchanged: 1, orphaned: 1 },
        };
        await render({ plan: orphansOnly });
        expect(button('Nothing to write').disabled).toBe(true);
    });
});
