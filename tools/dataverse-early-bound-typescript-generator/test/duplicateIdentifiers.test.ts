/**
 * Choice labels that become the same enum member name (e.g. "Open" and "Open!") make a generated file TypeScript
 * rejects. The generator reports them, and the write plan gives the file the `duplicate` status while still
 * writing it.
 */
import { act, createElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { findDuplicateEnumMembers, generate, renameDuplicateEnumMembers, resolveConfig, type EnumModel } from '../src/core';
import { PreviewCard, type IPreviewCardProps, type IPreviewGenerateOptions } from '../src/components/cards/PreviewCard';
import { FileViewer, duplicateLineNotes } from '../src/components/viewers/FileViewer';
import { computeWorkflowSteps } from '../src/components/shared/workflowSteps';
import { InMemoryFileSink } from '../src/services/fileSink';
import { applyWritePlan, createWritePlan, summarizeGeneration, summarizePlan, writeCounts } from '../src/services/plan';
import type { PlannedFile } from '../src/types';

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
(globalThis as { ResizeObserver?: unknown }).ResizeObserver ??= class {
    observe() {}
    unobserve() {}
    disconnect() {}
};

const STATUS: EnumModel = {
    Name: 'account_statuscode',
    StringMembers: false,
    Members: [
        { Name: 'Open', Value: '1' },
        { Name: 'Closed', Value: '2' },
        { Name: 'Open', Value: '3' },
        { Name: 'AB', Value: '5' },
        { Name: 'AB', Value: '7' },
    ],
};

describe('findDuplicateEnumMembers', () => {
    it('lists each repeated member name with its values', () => {
        expect(findDuplicateEnumMembers(STATUS)).toEqual([
            { name: 'Open', values: ['1', '3'] },
            { name: 'AB', values: ['5', '7'] },
        ]);
    });

    it('is empty when every name is unique', () => {
        expect(findDuplicateEnumMembers({ ...STATUS, Members: STATUS.Members.slice(0, 2) })).toEqual([]);
    });
});

describe('renameDuplicateEnumMembers', () => {
    const SALES_ORDER: EnumModel = {
        Name: 'salesorder_salesorder_statuscode',
        StringMembers: false,
        Members: [
            { Name: 'New', Value: '1' },
            { Name: 'Pending', Value: '2' },
            { Name: 'InProgress', Value: '3' },
            { Name: 'NoMoney', Value: '4' },
            { Name: 'Complete', Value: '100001' },
            { Name: 'Partial', Value: '100002' },
            { Name: 'Invoiced', Value: '100003' },
            { Name: 'InProgress', Value: '700970000' },
        ],
    };

    it('keeps the first name and appends the value to later duplicates', () => {
        const renamed = renameDuplicateEnumMembers(SALES_ORDER);
        expect(renamed.Members.map((m) => `${m.Name} = ${m.Value}`)).toEqual([
            'New = 1',
            'Pending = 2',
            'InProgress = 3',
            'NoMoney = 4',
            'Complete = 100001',
            'Partial = 100002',
            'Invoiced = 100003',
            'InProgress_700970000 = 700970000',
        ]);
        expect(findDuplicateEnumMembers(renamed)).toEqual([]);
    });

    it('keeps appending the value while the new name is taken, and leaves enums without duplicates alone', () => {
        const taken: EnumModel = { ...STATUS, Members: [{ Name: 'A', Value: '1' }, { Name: 'A_2', Value: '9' }, { Name: 'A', Value: '2' }] };
        expect(renameDuplicateEnumMembers(taken).Members.map((m) => m.Name)).toEqual(['A', 'A_2', 'A_2_2']);
        const unique: EnumModel = { ...STATUS, Members: [{ Name: 'A', Value: '1' }] };
        expect(renameDuplicateEnumMembers(unique).Members[0]).toBe(unique.Members[0]);
    });

    it('is applied by generate with renameDuplicateIdentifiers, which then reports no duplicates', () => {
        const model = { entities: [], enums: [SALES_ORDER], complexTypes: [], actions: [], functions: [] };
        const [file] = generate(model, resolveConfig({}), { renameDuplicateIdentifiers: true });
        expect(file.content).toContain('  InProgress = 3,');
        expect(file.content).toContain('  InProgress_700970000 = 700970000,');
        expect(file).not.toHaveProperty('duplicateIdentifiers');
        // Off by default: dataverse-gen's output, reported.
        expect(generate(model, resolveConfig({}))[0].duplicateIdentifiers).toEqual([{ name: 'InProgress', values: ['3', '700970000'] }]);
    });
});

describe('generate', () => {
    it("flags the enum file and keeps dataverse-gen's output unchanged", () => {
        const config = resolveConfig({});
        const unique: EnumModel = { ...STATUS, Name: 'account_industrycode', Members: [{ Name: 'Retail', Value: '1' }] };
        const files = generate({ entities: [], enums: [STATUS, unique], complexTypes: [], actions: [], functions: [] }, config);

        const flagged = files.find((f) => f.path === 'enums/account_statuscode.ts');
        expect(flagged?.duplicateIdentifiers).toEqual([
            { name: 'Open', values: ['1', '3'] },
            { name: 'AB', values: ['5', '7'] },
        ]);
        expect(flagged?.content).toContain('Open = 1');
        expect(flagged?.content).toContain('Open = 3');
        expect(files.find((f) => f.path === 'enums/account_industrycode.ts')).not.toHaveProperty('duplicateIdentifiers');
    });
});

describe('write plan', () => {
    const config = resolveConfig({ output: { outputRoot: './gen' } });
    const duplicates = [{ name: 'Open', values: ['1', '3'] }];

    it('gives the file the duplicate status, keeps its write status, and still writes it', async () => {
        const sink = new InMemoryFileSink({ 'C:\\proj\\gen\\enums\\b.ts': 'B\n' });
        const plan = await createWritePlan(sink, 'C:\\proj', config, [
            { path: 'enums/a.ts', content: 'A\n', duplicateIdentifiers: duplicates },
            { path: 'enums/b.ts', content: 'B\n', duplicateIdentifiers: duplicates },
            { path: 'metadata.ts', content: 'M\n' },
        ]);

        const a = plan.files.find((f) => f.relativePath === 'enums/a.ts');
        expect(a).toMatchObject({ status: 'duplicate', writeStatus: 'new', duplicateIdentifiers: duplicates });
        expect(plan.files.find((f) => f.relativePath === 'enums/b.ts')).toMatchObject({ status: 'duplicate', writeStatus: 'unchanged' });
        expect(plan.counts).toEqual({ new: 1, changed: 0, unchanged: 0, orphaned: 0, duplicate: 2 });
        expect(writeCounts(plan)).toEqual({ created: 2, overwritten: 0 });

        const result = await applyWritePlan(sink, plan);
        expect(result.written).toBe(2);
        expect(sink.files.get('C:\\proj\\gen\\enums\\a.ts')).toBe('A\n');
    });

    it('leaves the files unwritten with skipDuplicates', async () => {
        const sink = new InMemoryFileSink();
        const plan = await createWritePlan(sink, 'C:\\proj', config, [
            { path: 'enums/a.ts', content: 'A\n', duplicateIdentifiers: duplicates },
            { path: 'metadata.ts', content: 'M\n' },
        ]);
        expect(writeCounts(plan, { skipDuplicates: true })).toEqual({ created: 1, overwritten: 0 });
        const result = await applyWritePlan(sink, plan, undefined, { skipDuplicates: true });
        expect(result.written).toBe(1);
        expect(sink.files.has('C:\\proj\\gen\\enums\\a.ts')).toBe(false);
        expect(sink.files.get('C:\\proj\\gen\\metadata.ts')).toBe('M\n');
    });

    it('mentions the files in the preview and generation summaries', () => {
        const counts = { new: 1, changed: 0, unchanged: 3, orphaned: 0, duplicate: 2 };
        expect(summarizePlan(counts, false, { created: 2, overwritten: 0 })).toBe(
            "2 new files will be created. 2 files declare duplicate identifiers and won't compile until the option labels are fixed in Dataverse.",
        );
        expect(summarizeGeneration(2, counts)).toBe('2 files written · 3 unchanged · 2 with duplicate identifiers · 0 orphaned · .dataverse-gen.json saved');
        // With Skip duplicated identifier(s) on.
        expect(summarizePlan(counts, false, { created: 1, overwritten: 0 }, true)).toBe(
            "1 new file will be created. 2 files declare duplicate identifiers and won't be written.",
        );
        expect(summarizeGeneration(1, counts, undefined, true)).toBe(
            '1 file written · 3 unchanged · 2 with duplicate identifiers skipped · 0 orphaned · .dataverse-gen.json saved',
        );
    });
});

let root: Root | undefined;
let container: HTMLElement | undefined;

afterEach(() => {
    act(() => root?.unmount());
    container?.remove();
    root = undefined;
});

async function mount(element: ReturnType<typeof createElement>) {
    container = document.body.appendChild(document.createElement('div'));
    root = createRoot(container);
    await act(async () => root!.render(createElement(FluentProvider, { theme: webLightTheme }, element)));
}

const DUPLICATE: PlannedFile = {
    relativePath: 'enums/account_statuscode.ts',
    absolutePath: 'C:/repo/gen/enums/account_statuscode.ts',
    status: 'duplicate',
    writeStatus: 'new',
    content: 'export const enum account_statuscode {}',
    existingContent: null,
    duplicateIdentifiers: [{ name: 'Open', values: ['1', '3'] }],
};

describe('PreviewCard', () => {
    const props = (files: PlannedFile[], duplicate: number, generateOptions: Partial<IPreviewGenerateOptions> = {}): IPreviewCardProps => ({
        step: computeWorkflowSteps({ hasProject: true, selectedCount: 1, plan: { pending: 1, stale: false } })[3],
        plan: { projectRoot: 'C:/repo', outputRoot: 'C:/repo/gen', files, counts: { new: 0, changed: 0, unchanged: files.length - duplicate, orphaned: 0, duplicate } },
        stale: false,
        canPreview: true,
        needsProject: false,
        busy: false,
        previewedAt: null,
        lastResult: null,
        generateOptions: { deleteOrphans: false, onDeleteOrphansChange: vi.fn(), ...generateOptions },
        onPreview: vi.fn(),
        onGenerate: vi.fn(),
        onCopyText: vi.fn(),
    });
    const tiles = () => Array.from(document.querySelectorAll('[aria-label="Filter by status"] button')).map((b) => b.textContent);

    it('shows a duplicate identifiers tile and row, and counts the file in Generate', async () => {
        await mount(createElement(PreviewCard, props([DUPLICATE], 1)));
        expect(tiles()[0]).toBe('1Duplicate identifiers');
        const row = document.querySelector('table[aria-label="Generated files"] tbody tr') as HTMLElement;
        expect(row.textContent).toContain('duplicate identifiers');
        expect(Array.from(document.querySelectorAll('button')).some((b) => b.textContent === 'Generate 1 file')).toBe(true);
    });

    it('hides the tile when no file has duplicate identifiers', async () => {
        const plain: PlannedFile = { ...DUPLICATE, status: 'unchanged', writeStatus: undefined, duplicateIdentifiers: undefined };
        await mount(createElement(PreviewCard, props([plain], 0)));
        expect(tiles().some((t) => t?.includes('Duplicate identifiers'))).toBe(false);
    });

    it('offers Skip duplicated identifier(s) next to Generate, which changes what Generate counts', async () => {
        const onSkipDuplicatesChange = vi.fn();
        await mount(createElement(PreviewCard, props([DUPLICATE], 1, { onSkipDuplicatesChange })));
        const label = Array.from(document.querySelectorAll('label')).find((l) => l.textContent === 'Skip duplicated identifier(s)');
        const input = document.getElementById(label?.getAttribute('for') ?? '') as HTMLInputElement;
        expect(input.checked).toBe(false);
        await act(async () => input.click());
        expect(onSkipDuplicatesChange).toHaveBeenCalledWith(true);

        act(() => root?.unmount());
        container?.remove();
        await mount(createElement(PreviewCard, props([DUPLICATE], 1, { onSkipDuplicatesChange, skipDuplicates: true })));
        expect(Array.from(document.querySelectorAll('button')).some((b) => b.textContent === 'Nothing to write')).toBe(true);
        expect(document.body.textContent).toContain("1 file declares duplicate identifiers and won't be written.");
    });

    it('enables the switch only after a preview', async () => {
        await mount(createElement(PreviewCard, { ...props([DUPLICATE], 1, { onSkipDuplicatesChange: vi.fn() }), plan: null }));
        const label = Array.from(document.querySelectorAll('label')).find((l) => l.textContent === 'Skip duplicated identifier(s)');
        expect((document.getElementById(label?.getAttribute('for') ?? '') as HTMLInputElement).disabled).toBe(true);
    });

    it("explains the switch in an info label with the Settings panel's text", async () => {
        await mount(createElement(PreviewCard, props([DUPLICATE], 1, { onSkipDuplicatesChange: vi.fn() })));
        const info = document.querySelector('button[aria-label="About Skip duplicated identifier(s)"]') as HTMLButtonElement;
        await act(async () => info.click());
        expect(document.body.textContent).toContain('Generate leaves them unwritten');
        expect(document.body.textContent).toContain('skipDuplicateIdentifiers');
    });

    it('disables the switch when the preview found no duplicates', async () => {
        const plain: PlannedFile = { ...DUPLICATE, status: 'new', writeStatus: undefined, duplicateIdentifiers: undefined };
        await mount(createElement(PreviewCard, props([plain], 0, { onSkipDuplicatesChange: vi.fn() })));
        const label = Array.from(document.querySelectorAll('label')).find((l) => l.textContent === 'Skip duplicated identifier(s)');
        expect((document.getElementById(label?.getAttribute('for') ?? '') as HTMLInputElement).disabled).toBe(true);
        const info = document.querySelector('button[aria-label="About Skip duplicated identifier(s)"]') as HTMLButtonElement;
        await act(async () => info.click());
        expect(document.body.textContent).toContain('Disabled: the last preview found no files with duplicate identifiers.');
    });

    it('offers Rename duplicated identifier(s), and keeps it usable once on so it can be turned off', async () => {
        const onRenameDuplicatesChange = vi.fn();
        await mount(createElement(PreviewCard, props([DUPLICATE], 1, { onRenameDuplicatesChange })));
        const renameInput = () => {
            const label = Array.from(document.querySelectorAll('label')).find((l) => l.textContent === 'Rename duplicated identifier(s)');
            return document.getElementById(label?.getAttribute('for') ?? '') as HTMLInputElement;
        };
        expect(renameInput().disabled).toBe(false);
        await act(async () => renameInput().click());
        expect(onRenameDuplicatesChange).toHaveBeenCalledWith(true);

        act(() => root?.unmount());
        container?.remove();
        const plain: PlannedFile = { ...DUPLICATE, status: 'new', writeStatus: undefined, duplicateIdentifiers: undefined };
        await mount(createElement(PreviewCard, props([plain], 0, { onRenameDuplicatesChange, renameDuplicates: true })));
        expect(renameInput().checked).toBe(true);
        expect(renameInput().disabled).toBe(false);
    });

    it('hides the switch without a handler', async () => {
        await mount(createElement(PreviewCard, props([DUPLICATE], 1)));
        // The duplicate status tooltip names the setting too, so look for the switch's label, not the text.
        expect(Array.from(document.querySelectorAll('label')).some((l) => l.textContent === 'Skip duplicated identifier(s)')).toBe(false);
    });
});

describe('FileViewer', () => {
    it('highlights the lines that declare a duplicated identifier', async () => {
        const content = [
            '/* eslint-disable*/',
            '// Enum quote_quote_statuscode',
            'export const enum quote_quote_statuscode {',
            '  InProgress = 1,',
            '  InProgress = 2,',
            '  Open = 3,',
            '  Won = 4,',
            '}',
            '',
        ].join('\n');
        const duplicates = [{ name: 'InProgress', values: ['1', '2'] }];
        expect([...duplicateLineNotes(content, duplicates)]).toEqual([
            [4, 'Duplicate identifier InProgress (values 1, 2)'],
            [5, 'Duplicate identifier InProgress (values 1, 2)'],
        ]);

        await mount(createElement(FileViewer, { file: { ...DUPLICATE, content, duplicateIdentifiers: duplicates }, onCopyText: vi.fn() }));
        const flagged = Array.from(document.querySelectorAll('[data-flagged]')) as HTMLElement[];
        expect(flagged.map((line) => line.textContent)).toEqual(['4  InProgress = 1,', '5  InProgress = 2,']);
        expect(flagged[0].title).toBe('Duplicate identifier InProgress (values 1, 2)');
    });

    it('highlights them in the Changes view too', async () => {
        const content = 'export const enum e {\n  A = 1,\n  A = 2,\n}\n';
        const file: PlannedFile = {
            ...DUPLICATE,
            writeStatus: 'changed',
            existingContent: 'export const enum e {\n  A = 1,\n}\n',
            content,
            duplicateIdentifiers: [{ name: 'A', values: ['1', '2'] }],
        };
        await mount(createElement(FileViewer, { file, onCopyText: vi.fn() }));
        const flagged = Array.from(document.querySelectorAll('[data-flagged]')) as HTMLElement[];
        expect(flagged).toHaveLength(2);
        expect(flagged.every((row) => row.title === 'Duplicate identifier A (values 1, 2)')).toBe(true);
    });

    it('says the file is skipped when Skip duplicated identifier(s) is on', async () => {
        await mount(createElement(FileViewer, { file: DUPLICATE, onCopyText: vi.fn(), skipDuplicates: true }));
        expect(document.body.textContent).toContain("Skip duplicated identifier(s) is on, so Generate doesn't write it.");
    });

    it('explains which names are duplicated', async () => {
        await mount(createElement(FileViewer, { file: DUPLICATE, onCopyText: vi.fn() }));
        expect(document.body.textContent).toContain("so TypeScript won't compile it: Open (values 1, 3).");
        expect(document.body.textContent).toContain('then preview again. Generate still writes this file.');
        expect(document.body.textContent).toContain('Duplicate identifiers');
    });
});
