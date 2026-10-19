/// <reference types="node" />
// Node types for reading the metadata fixtures from disk; tsconfig keeps them out of src/.
/**
 * The hooks that hold the app's state (extracted from App.tsx): plan state, tool settings, the project, the
 * environment's lists, and Preview / Generate. Rendered through a probe component with PPTB stubbed.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { act, createElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { toolConfig, type ProjectEntry, type ToolConfig } from '../src/config';
import { parseCsdl, resolveConfig, type DataverseGenConfig, type EntityMetadataInput } from '../src/core';
import {
    useAsyncAction,
    useAutoHideFooter,
    useCustomEnumTemplateConfirmation,
    useEnvironmentMetadata,
    usePlanState,
    usePreviewGenerate,
    useProject,
    useToolSettings,
    type PlanState,
} from '../src/hooks';
import { CUSTOM_ENUM_TEMPLATE, DATAVERSE_GEN_TEMPLATES, InMemoryFileSink, createWritePlan, dataverseGenTemplateFiles, type PptbMetadataProvider } from '../src/services';
import type { EntitySummary, OperationSummary, WritePlan } from '../src/types';

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

let root: Root | undefined;
let container: HTMLDivElement | undefined;

/** Renders `hook` in a probe component; `result.current` is its latest return value. */
function renderHook<T>(hook: () => T) {
    const result = { current: undefined as unknown as T };
    let renders = 0;
    function Probe() {
        // A render loop fails the test instead of exhausting the worker's memory.
        if (++renders > 200) throw new Error('renderHook: more than 200 renders, probably a render loop');
        result.current = hook();
        return null;
    }
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
    act(() => root?.render(createElement(Probe)));
    return { result, rerender: () => act(() => root?.render(createElement(Probe))) };
}

/** Lets pending promises (stubbed PPTB calls) settle and their state updates render. */
const flush = () => act(async () => new Promise<void>((resolve) => setTimeout(resolve, 0)));

function installSettingsStub(stored: Record<string, unknown> = {}, { failSet = false } = {}) {
    const store = { ...stored };
    (window as unknown as { toolboxAPI: unknown }).toolboxAPI = {
        settings: {
            get: async (key: string) => store[key],
            set: async (key: string, value: unknown) => {
                if (failSet) throw new Error('disk full');
                store[key] = value;
            },
        },
    };
    return store;
}

afterEach(() => {
    act(() => root?.unmount());
    container?.remove();
    root = undefined;
    delete (window as unknown as { toolboxAPI?: unknown }).toolboxAPI;
    delete (window as unknown as { dataverseAPI?: unknown }).dataverseAPI;
});

const PROJECT: ProjectEntry = { id: 'p1', name: 'Contoso', description: '', location: '/src/contoso', version: '1.0.0', createdOn: '2026-10-01T00:00:00.000Z', modifiedOn: '2026-10-01T00:00:00.000Z' };

describe('useAsyncAction', () => {
    it('is busy while the action runs, clears the error first, and returns the result', async () => {
        const setError = vi.fn();
        let finish: (value: string) => void = () => {};
        const { result } = renderHook(() => useAsyncAction(setError));
        let outcome: Promise<string | undefined> = Promise.resolve(undefined);
        act(() => {
            outcome = result.current.run('Could not save', () => new Promise<string>((resolve) => (finish = resolve)));
        });
        expect(result.current.busy).toBe(true);
        expect(setError).toHaveBeenCalledWith(null);
        await act(async () => finish('saved'));
        expect(await outcome).toBe('saved');
        expect(result.current.busy).toBe(false);
    });

    it('shows the friendly error and stops being busy when the action fails', async () => {
        vi.spyOn(console, 'error').mockImplementation(() => {});
        const setError = vi.fn();
        const { result } = renderHook(() => useAsyncAction(setError));
        let outcome: string | undefined = 'unset';
        await act(async () => {
            outcome = await result.current.run<string>('Could not save the project', async () => {
                throw new Error('disk full');
            });
        });
        expect(outcome).toBeUndefined();
        expect(setError).toHaveBeenLastCalledWith(expect.stringContaining('Could not save the project'));
        expect(result.current.busy).toBe(false);
        vi.restoreAllMocks();
    });
});

describe('usePlanState', () => {
    it('clears the plan, resets it with its stale flag, or marks it stale', () => {
        const { result } = renderHook(() => usePlanState());
        act(() => {
            result.current.setPlan({ files: [] } as unknown as PlanState['plan']);
            result.current.markPlanStale();
        });
        expect(result.current.plan).not.toBeNull();
        expect(result.current.planStale).toBe(true);

        act(() => result.current.clearPlan());
        expect(result.current.plan).toBeNull();
        expect(result.current.planStale).toBe(true);

        act(() => result.current.resetPlan());
        expect(result.current.planStale).toBe(false);
    });
});

describe('useToolSettings', () => {
    it('starts from the bundled defaults and loads the saved values', async () => {
        installSettingsStub({ toolConfig: { ...toolConfig, confirmBeforeGenerate: !toolConfig.confirmBeforeGenerate } });
        const { result } = renderHook(() => useToolSettings({ onError: vi.fn(), onPlanStale: vi.fn() }));
        expect(result.current.toolSettings.confirmBeforeGenerate).toBe(toolConfig.confirmBeforeGenerate);
        await flush();
        expect(result.current.toolSettings.confirmBeforeGenerate).toBe(!toolConfig.confirmBeforeGenerate);
    });

    it('marks the plan stale only when Rename duplicated identifier(s) changes', async () => {
        installSettingsStub();
        const onPlanStale = vi.fn();
        const { result } = renderHook(() => useToolSettings({ onError: vi.fn(), onPlanStale }));
        await flush();
        await act(() => result.current.saveToolSettings({ ...result.current.toolSettings, confirmBeforeGenerate: true }));
        expect(onPlanStale).not.toHaveBeenCalled();
        await act(() => result.current.saveToolSettings({ ...result.current.toolSettings, renameDuplicateIdentifiers: true }));
        expect(onPlanStale).toHaveBeenCalledTimes(1);
    });

    it('saves the custom enum template from the Preview card and marks the plan stale, on and off', async () => {
        const store = installSettingsStub();
        const onPlanStale = vi.fn();
        const { result } = renderHook(() => useToolSettings({ onError: vi.fn(), onPlanStale }));
        await flush();
        await act(() => result.current.changeSetting('customEnumTemplate', true));
        expect(result.current.toolSettings.customEnumTemplate).toBe(true);
        expect((store.toolConfig as ToolConfig).customEnumTemplate).toBe(true);
        expect(onPlanStale).toHaveBeenCalledTimes(1);
        await act(() => result.current.changeSetting('customEnumTemplate', false));
        expect(result.current.toolSettings.customEnumTemplate).toBe(false);
        expect(onPlanStale).toHaveBeenCalledTimes(2);
    });

    it('adds, edits and deletes saved projects', async () => {
        const store = installSettingsStub();
        const { result } = renderHook(() => useToolSettings({ onError: vi.fn(), onPlanStale: vi.fn() }));
        await flush();
        await act(() => result.current.saveNewProject({ name: 'Contoso', description: '', location: '/src/contoso' }));
        const added = result.current.toolSettings.projects[0];
        expect(added).toMatchObject({ name: 'Contoso', location: '/src/contoso', version: '1.0.0' });
        expect((store.toolConfig as ToolConfig).projects).toHaveLength(1);

        await act(() => result.current.editProject(added, { name: 'Fabrikam', description: 'Renamed', location: '/src/fabrikam' }));
        expect(result.current.toolSettings.projects[0]).toMatchObject({ id: added.id, name: 'Fabrikam', location: '/src/fabrikam', version: added.version });

        await act(() => result.current.deleteProject(result.current.toolSettings.projects[0]));
        expect(result.current.toolSettings.projects).toEqual([]);
    });

    it('records a generation that added files on the matching saved project', async () => {
        installSettingsStub({ toolConfig: { ...toolConfig, projects: [PROJECT] } });
        const { result } = renderHook(() => useToolSettings({ onError: vi.fn(), onPlanStale: vi.fn() }));
        await flush();
        const applied = { files: [{ relativePath: 'entities/Account.ts', status: 'new' }] } as unknown as Parameters<typeof result.current.recordProjectGeneration>[1];
        await act(() => result.current.recordProjectGeneration('/src/other', applied));
        expect(result.current.toolSettings.projects[0].version).toBe('1.0.0');
        await act(() => result.current.recordProjectGeneration('/src/contoso', applied));
        expect(result.current.toolSettings.projects[0].version).toBe('1.0.1');
    });

    it('reports a Preview switch that could not be saved', async () => {
        installSettingsStub({}, { failSet: true });
        const onError = vi.fn();
        const { result } = renderHook(() => useToolSettings({ onError, onPlanStale: vi.fn() }));
        await flush();
        await act(() => result.current.changeSetting('deleteOrphanedFiles', true));
        expect(onError).toHaveBeenCalledWith(expect.stringContaining('Could not save the setting'));
        expect(result.current.toolSettings.deleteOrphanedFiles).toBe(toolConfig.deleteOrphanedFiles);
    });
});

describe('useProject', () => {
    const CONNECTION = { id: 'conn-1', url: 'https://contoso.crm.dynamics.com' } as unknown as ToolBoxAPI.Connection;

    function renderProject(sink: InMemoryFileSink, overrides: { projectDefaults?: typeof toolConfig.projectDefaults } = {}) {
        const setError = vi.fn();
        const resetPlan = vi.fn();
        const markPlanStale = vi.fn();
        const hook = renderHook(() =>
            useProject({
                sink,
                connKey: 'conn-1',
                inPptb: true,
                connection: CONNECTION,
                projectDefaults: overrides.projectDefaults ?? toolConfig.projectDefaults,
                showProjectLoaded: false,
                setError,
                resetPlan,
                markPlanStale,
            }),
        );
        return { ...hook, setError, resetPlan, markPlanStale };
    }

    it("loads a folder's .dataverse-gen.json, keeps the draft selection, and resets the plan", async () => {
        installSettingsStub();
        const sink = new InMemoryFileSink({ '/src/contoso/.dataverse-gen.json': JSON.stringify({ entities: ['account'] }) });
        const { result, resetPlan, markPlanStale } = renderProject(sink);
        act(() => result.current.toggle('entities', 'contact', true));
        expect(markPlanStale).toHaveBeenCalled();

        await act(() => result.current.loadProject('/src/contoso'));
        expect(result.current.projectRoot).toBe('/src/contoso');
        expect(result.current.configState.exists).toBe(true);
        expect(result.current.config.entities).toEqual(['account', 'contact']);
        expect(resetPlan).toHaveBeenCalled();
    });

    it('applies the Settings Options to the loaded config', async () => {
        installSettingsStub();
        const sink = new InMemoryFileSink({ '/src/contoso/.dataverse-gen.json': JSON.stringify({ output: { outputRoot: './elsewhere' } }) });
        const { result } = renderProject(sink, { projectDefaults: { ...toolConfig.projectDefaults, outputRoot: './src/types' } });
        await act(() => result.current.loadProject('/src/contoso'));
        expect(result.current.config.output?.outputRoot).toBe('./src/types');
    });

    it('edits the selection and records where Generate saved the config', async () => {
        installSettingsStub();
        const { result } = renderProject(new InMemoryFileSink());
        await act(() => result.current.loadProject('/src/new'));
        expect(result.current.configState.exists).toBe(false);
        act(() => result.current.toggle('actions', 'WinOpportunity', true));
        act(() => result.current.toggle('functions', 'WhoAmI', true));
        act(() => result.current.clear('actions'));
        expect(result.current.config.actions).toEqual([]);
        expect(result.current.config.functions).toEqual(['WhoAmI']);
        act(() => result.current.clearAll());
        expect(result.current.config.functions).toEqual([]);
        act(() => result.current.markConfigSaved('/src/new/.dataverse-gen.json'));
        expect(result.current.configState).toMatchObject({ exists: true, path: '/src/new/.dataverse-gen.json' });
    });

    it('remembers the folder per connection and reads it back', async () => {
        const store = installSettingsStub({ projectFolders: { 'conn-1': '/src/remembered' } });
        const { result } = renderProject(new InMemoryFileSink());
        await flush();
        expect(result.current.rememberedFolder).toBe('/src/remembered');
        await act(() => result.current.loadProject('/src/contoso'));
        expect(store.projectFolders).toEqual({ 'conn-1': '/src/contoso' });
    });

    it('shows an error when the config cannot be read', async () => {
        installSettingsStub();
        const { result, setError } = renderProject(new InMemoryFileSink({ '/src/broken/.dataverse-gen.json': '{ not json' }));
        await act(() => result.current.loadProject('/src/broken'));
        expect(result.current.projectRoot).toBeNull();
        expect(setError).toHaveBeenLastCalledWith(expect.stringContaining('Could not load /src/broken'));
    });
});

describe('useEnvironmentMetadata', () => {
    const ENTITIES = [
        { logicalName: 'account', displayName: 'Account', metadataId: 'A1' },
        { logicalName: 'contact', displayName: 'Contact', metadataId: 'C1' },
    ] as unknown as EntitySummary[];
    const OPERATIONS = [{ name: 'WinOpportunity', kind: 'action', componentId: 'X1' }] as unknown as OperationSummary[];

    function stubProvider(fallback = false) {
        return {
            listEntities: vi.fn(async () => ENTITIES),
            listOperations: vi.fn(async () => OPERATIONS),
            get usesMetadataFallback() {
                return fallback;
            },
        } as unknown as PptbMetadataProvider;
    }

    function installDataverseStub() {
        const queryData = vi.fn(async (query: string) => ({ value: query.includes('componenttype eq 1') ? [{ objectid: 'A1' }] : [{ objectid: 'x1' }] }));
        (window as unknown as { dataverseAPI: unknown }).dataverseAPI = {
            getSolutions: async () => ({ value: [{ solutionid: 's1', uniquename: 'core', friendlyname: 'Core', version: '1.0', ismanaged: false, isvisible: true }] }),
            queryData,
        };
        return queryData;
    }

    const selection = { entities: ['account', 'gone'], actions: ['WinOpportunity', 'Missing'], functions: [] };
    // Stable, like App's state: the effects depend on them, so a new object or function every render would loop.
    const setError = vi.fn();
    const CONNECTION = {} as ToolBoxAPI.Connection;

    it('lists tables and solutions once a project is open, clears the plan, and flags missing names', async () => {
        installDataverseStub();
        const provider = stubProvider();
        const clearPlan = vi.fn();
        const { result } = renderHook(() =>
            useEnvironmentMetadata({ provider, inPptb: true, connection: CONNECTION, hasProject: true, selected: selection, setError, clearPlan }),
        );
        await flush();
        expect(result.current.entities).toEqual(ENTITIES);
        expect(result.current.solutions.map((s) => s.uniqueName)).toEqual(['core']);
        expect(clearPlan).toHaveBeenCalled();
        expect(result.current.missing.entities).toEqual(['gone']);
        // Actions aren't loaded yet, so nothing is reported missing for them.
        expect(result.current.missing.actions).toEqual([]);
    });

    it('lists nothing before a project is open', async () => {
        installDataverseStub();
        const provider = stubProvider();
        const clearPlan = vi.fn();
        renderHook(() =>
            useEnvironmentMetadata({ provider, inPptb: true, connection: CONNECTION, hasProject: false, selected: selection, setError, clearPlan }),
        );
        await flush();
        expect(provider.listEntities).not.toHaveBeenCalled();
    });

    it('loads actions and functions on demand and shows the fallback warning when the provider fell back', async () => {
        installDataverseStub();
        const provider = stubProvider(true);
        const clearPlan = vi.fn();
        const { result } = renderHook(() =>
            useEnvironmentMetadata({ provider, inPptb: true, connection: CONNECTION, hasProject: true, selected: selection, setError, clearPlan }),
        );
        await flush();
        act(() => result.current.ensureOperations());
        await flush();
        expect(result.current.operations).toEqual(OPERATIONS);
        expect(result.current.missing.actions).toEqual(['Missing']);
        expect(result.current.showMetadataFallbackWarning).toBe(true);
    });

    it("filters by a solution's tables and components, caching each solution", async () => {
        const queryData = installDataverseStub();
        const provider = stubProvider();
        const clearPlan = vi.fn();
        const { result } = renderHook(() =>
            useEnvironmentMetadata({ provider, inPptb: true, connection: CONNECTION, hasProject: true, selected: selection, setError, clearPlan }),
        );
        await flush();
        act(() => result.current.ensureOperations());
        await act(() => result.current.changeSolution('s1'));
        await flush();
        expect([...(result.current.solutionEntityIds ?? [])]).toEqual(['a1']);
        expect([...(result.current.solutionComponentIds ?? [])]).toEqual(['x1']);
        const calls = queryData.mock.calls.length;

        await act(() => result.current.changeSolution(null));
        expect(result.current.solutionEntityIds).toBeNull();
        await act(() => result.current.changeSolution('s1'));
        await flush();
        expect(queryData.mock.calls.length).toBe(calls);
        expect([...(result.current.solutionEntityIds ?? [])]).toEqual(['a1']);
    });
});

describe('usePreviewGenerate', () => {
    const CONFIG: DataverseGenConfig = { entities: ['account'] };
    const settings = (change: Partial<ToolConfig> = {}): ToolConfig => ({
        ...toolConfig,
        general: { ...toolConfig.general, showGenerationCompleteNotification: false, showPreviewReadyNotification: false },
        ...change,
    });

    async function planFor(sink: InMemoryFileSink) {
        return createWritePlan(sink, '/src/contoso', resolveConfig(CONFIG), [{ path: 'entities/Account.ts', content: 'export interface Account {}\n' }]);
    }

    function renderPreview(sink: InMemoryFileSink, toolSettings: ToolConfig) {
        const markConfigSaved = vi.fn();
        const recordProjectGeneration = vi.fn(async () => undefined);
        const noteMetadataFallback = vi.fn();
        const setError = vi.fn();
        const hook = renderHook(() => {
            const planState = usePlanState();
            const preview = usePreviewGenerate({
                planState,
                projectRoot: '/src/contoso',
                config: CONFIG,
                provider: {} as PptbMetadataProvider,
                sink,
                toolSettings,
                recordProjectGeneration,
                markConfigSaved,
                noteMetadataFallback,
                setError,
            });
            return { planState, preview };
        });
        return { ...hook, markConfigSaved, recordProjectGeneration };
    }

    it('writes the plan, saves the config, and marks the written files unchanged', async () => {
        const sink = new InMemoryFileSink();
        const plan = await planFor(sink);
        const { result, markConfigSaved, recordProjectGeneration } = renderPreview(sink, settings());
        await act(() => result.current.preview.runGenerate(plan, false));
        expect(sink.files.get('/src/contoso/src/dataverse-gen/entities/Account.ts')).toBe('export interface Account {}\n');
        expect(markConfigSaved).toHaveBeenCalledWith('/src/contoso/.dataverse-gen.json');
        expect(recordProjectGeneration).toHaveBeenCalledWith('/src/contoso', plan);
        expect(result.current.planState.plan?.counts).toMatchObject({ new: 0, unchanged: 1 });
        expect(result.current.planState.lastResult).toContain('1 file written');
        expect(result.current.preview.busy).toBe(false);
    });

    it('asks before generating when the setting is on, and writes straight away when it is off', async () => {
        const sink = new InMemoryFileSink();
        const plan = await planFor(sink);
        const asking = renderPreview(sink, settings({ confirmBeforeGenerate: true }));
        act(() => asking.result.current.planState.setPlan(plan));
        act(() => asking.result.current.preview.startGenerate());
        expect(asking.result.current.preview.confirmGenerateOpen).toBe(true);
        expect(sink.files.size).toBe(0);

        act(() => root?.unmount());
        container?.remove();
        const direct = renderPreview(sink, settings({ confirmBeforeGenerate: false }));
        act(() => direct.result.current.planState.setPlan(plan));
        await act(async () => direct.result.current.preview.startGenerate());
        await flush();
        expect(direct.result.current.preview.confirmGenerateOpen).toBe(false);
        expect(sink.files.has('/src/contoso/src/dataverse-gen/entities/Account.ts')).toBe(true);
    });

    it('puts the dataverse-gen templates in the preview only when Generate templates is on', async () => {
        const empty = { entityTypes: [], complexTypes: [], enumTypes: [], actions: [], functions: [] };
        const provider = { getSchemaForSelection: vi.fn(async () => empty), getEntities: vi.fn(async () => []) } as unknown as PptbMetadataProvider;
        const templatesIn = async (generateTemplates: boolean) => {
            const hook = renderHook(() =>
                usePreviewGenerate({
                    planState: usePlanState(),
                    projectRoot: '/src/contoso',
                    config: {},
                    provider,
                    sink: new InMemoryFileSink(),
                    toolSettings: settings({ generateTemplates }),
                    recordProjectGeneration: vi.fn(async () => undefined),
                    markConfigSaved: vi.fn(),
                    noteMetadataFallback: vi.fn(),
                    setError: vi.fn(),
                }),
            );
            let plan: Awaited<ReturnType<typeof hook.result.current.runPreview>> = null;
            await act(async () => {
                plan = await hook.result.current.runPreview();
            });
            act(() => root?.unmount());
            container?.remove();
            return (plan as WritePlan | null)?.files.filter((f) => f.relativePath.includes('_templates/')).length ?? -1;
        };
        expect(await templatesIn(true)).toBe(DATAVERSE_GEN_TEMPLATES.length);
        expect(await templatesIn(false)).toBe(0);
    });

    describe('with duplicate identifiers (custom enum template, spec 001)', () => {
        const fixtures = path.join(__dirname, 'fixtures');
        const edmx = parseCsdl(fs.readFileSync(path.join(fixtures, 'edmx.xml'), 'utf8'));
        /** The account fixture with accountcategorycode's second option relabelled like its first, so both become PreferredCustomer. */
        const account = (() => {
            const json = JSON.parse(fs.readFileSync(path.join(fixtures, 'account-metadata.json'), 'utf8')) as { EntityMetadata: EntityMetadataInput[] };
            const entity = json.EntityMetadata[0];
            const attribute = (entity.Attributes as Array<{ LogicalName: string; OptionSet?: { Options: Array<{ Label: { UserLocalizedLabel: { Label: string } } }> } }>).find(
                (a) => a.LogicalName === 'accountcategorycode',
            )!;
            attribute.OptionSet!.Options[1].Label.UserLocalizedLabel.Label = attribute.OptionSet!.Options[0].Label.UserLocalizedLabel.Label;
            return entity;
        })();
        const provider = { getSchemaForSelection: vi.fn(async () => edmx), getEntities: vi.fn(async () => [account]) } as unknown as PptbMetadataProvider;

        async function previewWith(change: Partial<ToolConfig>): Promise<WritePlan> {
            const hook = renderHook(() =>
                usePreviewGenerate({
                    planState: usePlanState(),
                    projectRoot: '/src/contoso',
                    config: { entities: ['account'] },
                    provider,
                    sink: new InMemoryFileSink(),
                    toolSettings: settings(change),
                    recordProjectGeneration: vi.fn(async () => undefined),
                    markConfigSaved: vi.fn(),
                    noteMetadataFallback: vi.fn(),
                    setError: vi.fn(),
                }),
            );
            let plan: WritePlan | null = null;
            await act(async () => {
                plan = await hook.result.current.runPreview();
            });
            act(() => root?.unmount());
            container?.remove();
            root = undefined;
            return plan!;
        }
        const enumFile = (plan: WritePlan) => plan.files.find((f) => f.relativePath.endsWith('account_accountcategorycode.ts'))!;
        const enumTemplate = (plan: WritePlan) => plan.files.find((f) => f.relativePath.endsWith('_templates/enum.ejs'));

        it("keeps dataverse-gen's names and enum.ejs by default, flagging the duplicate", async () => {
            const plan = await previewWith({});
            expect(enumFile(plan).status).toBe('duplicate');
            expect(enumFile(plan).content).not.toContain('PreferredCustomer_2');
            expect(enumTemplate(plan)?.content).toBe(DATAVERSE_GEN_TEMPLATES.find((t) => t.name === 'enum.ejs')!.content);
        });

        it('plans exactly the default output when the custom enum template is declined (off) (US2)', async () => {
            const byDefault = await previewWith({});
            const declined = await previewWith({ customEnumTemplate: false });
            const contents = (plan: WritePlan) => plan.files.map((f) => [f.relativePath, f.status, f.content]);
            expect(contents(declined)).toEqual(contents(byDefault));
            expect(declined.counts.duplicate).toBeGreaterThan(0);
        });

        it('renames the duplicate and plans the custom enum.ejs when the custom enum template is on', async () => {
            const plan = await previewWith({ customEnumTemplate: true });
            expect(plan.counts.duplicate).toBe(0);
            expect(enumFile(plan).content).toContain('  PreferredCustomer = 1,\n  PreferredCustomer_2 = 2,');
            expect(enumTemplate(plan)?.content).toBe(CUSTOM_ENUM_TEMPLATE);
            expect(enumTemplate(plan)?.status).toBe('new');
            // Every other template stays dataverse-gen's.
            const others = plan.files.filter((f) => f.relativePath.includes('_templates/') && !f.relativePath.endsWith('enum.ejs'));
            expect(others.map((f) => f.content)).toEqual(DATAVERSE_GEN_TEMPLATES.filter((t) => t.name !== 'enum.ejs').map((t) => t.content));
        });

        it('still renames, but writes no templates, when Generate templates is off', async () => {
            const plan = await previewWith({ customEnumTemplate: true, generateTemplates: false });
            expect(plan.counts.duplicate).toBe(0);
            expect(enumFile(plan).content).toContain('PreferredCustomer_2');
            expect(enumTemplate(plan)).toBeUndefined();
        });
    });

    it('asks before deleting orphaned files', async () => {
        const sink = new InMemoryFileSink({ '/src/contoso/src/dataverse-gen/entities/Old.ts': 'old\n' });
        const plan = await planFor(sink);
        expect(plan.counts.orphaned).toBe(1);
        const { result } = renderPreview(sink, settings({ deleteOrphanedFiles: true }));
        act(() => result.current.planState.setPlan(plan));
        act(() => result.current.preview.startGenerate());
        expect(result.current.preview.confirmDeleteOpen).toBe(true);

        // Confirming closes the dialog, writes the new file and deletes the orphan.
        await act(async () => result.current.preview.confirmDelete());
        await flush();
        expect(result.current.preview.confirmDeleteOpen).toBe(false);
        expect(sink.files.has('/src/contoso/src/dataverse-gen/entities/Account.ts')).toBe(true);
    });

    it('closes a confirmation without generating on Cancel, and generates on Confirm', async () => {
        const sink = new InMemoryFileSink();
        const plan = await planFor(sink);
        const { result } = renderPreview(sink, settings({ confirmBeforeGenerate: true }));
        act(() => result.current.planState.setPlan(plan));
        act(() => result.current.preview.startGenerate());
        act(() => result.current.preview.cancelGenerate());
        expect(result.current.preview.confirmGenerateOpen).toBe(false);
        expect(sink.files.size).toBe(0);

        act(() => result.current.preview.startGenerate());
        await act(async () => result.current.preview.confirmGenerate());
        await flush();
        expect(result.current.preview.confirmGenerateOpen).toBe(false);
        expect(sink.files.has('/src/contoso/src/dataverse-gen/entities/Account.ts')).toBe(true);
    });
});

describe('useAutoHideFooter', () => {
    /** Makes the page `height` pixels tall, so it scrolls when that's more than the window. */
    const setPageHeight = (height: number) => Object.defineProperty(document.documentElement, 'scrollHeight', { configurable: true, value: height });
    const advance = (ms: number) => act(() => vi.advanceTimersByTime(ms));

    afterEach(() => {
        vi.useRealTimers();
        delete (document.documentElement as { scrollHeight?: number }).scrollHeight;
    });

    it('pins the footer, then slides it out and docks it', () => {
        vi.useFakeTimers();
        setPageHeight(window.innerHeight + 2000);
        const { result } = renderHook(() => useAutoHideFooter(5000, 250));
        expect(result.current).toBe('pinned');
        advance(4999);
        expect(result.current).toBe('pinned');
        advance(1);
        expect(result.current).toBe('sliding');
        advance(250);
        expect(result.current).toBe('docked');
    });

    it('docks straight away when the page is already at its end', () => {
        vi.useFakeTimers();
        setPageHeight(window.innerHeight);
        const { result } = renderHook(() => useAutoHideFooter(5000, 250));
        advance(5000);
        expect(result.current).toBe('docked');
    });

    it('clears its timers on unmount', () => {
        vi.useFakeTimers();
        setPageHeight(window.innerHeight + 2000);
        renderHook(() => useAutoHideFooter(5000, 250));
        act(() => root?.unmount());
        root = undefined;
        expect(vi.getTimerCount()).toBe(0);
    });
});

describe('useCustomEnumTemplateConfirmation (spec 001, FR-012)', () => {
    /** A preview plan of a project whose `_templates/enum.ejs` on disk is `onDisk`. */
    const planWith = async (onDisk: string) => {
        const config = resolveConfig({});
        const sink = new InMemoryFileSink({ '/src/contoso/_templates/enum.ejs': onDisk });
        return createWritePlan(sink, '/src/contoso', config, [], dataverseGenTemplateFiles(config));
    };
    const original = DATAVERSE_GEN_TEMPLATES.find((t) => t.name === 'enum.ejs')!.content;

    it('asks before turning it on over an edited enum.ejs, and saves only on confirm', async () => {
        const plan = await planWith('// my own enum template\n');
        const save = vi.fn();
        const { result } = renderHook(() => useCustomEnumTemplateConfirmation(plan, true, save));
        act(() => result.current.request(true));
        expect(save).not.toHaveBeenCalled();
        expect(result.current.pendingPath).toBe('/src/contoso/_templates/enum.ejs');
        act(() => result.current.confirm());
        expect(save).toHaveBeenCalledWith(true);
        expect(result.current.pendingPath).toBeNull();
    });

    it('saves nothing on cancel', async () => {
        const plan = await planWith('// my own enum template\n');
        const save = vi.fn();
        const { result } = renderHook(() => useCustomEnumTemplateConfirmation(plan, true, save));
        act(() => result.current.request(true));
        act(() => result.current.cancel());
        expect(save).not.toHaveBeenCalled();
        expect(result.current.pendingPath).toBeNull();
    });

    it("saves straight away without an edited enum.ejs, with Generate templates off, when turning off, or before a preview", async () => {
        const save = vi.fn();
        const unedited = await planWith(original);
        const edited = await planWith('// mine\n');
        for (const [plan, generateTemplates, checked] of [
            [unedited, true, true],
            [edited, false, true],
            [edited, true, false],
            [null, true, true],
        ] as const) {
            const { result } = renderHook(() => useCustomEnumTemplateConfirmation(plan, generateTemplates, save));
            act(() => result.current.request(checked));
            expect(result.current.pendingPath).toBeNull();
            act(() => root?.unmount());
            container?.remove();
            root = undefined;
        }
        expect(save.mock.calls).toEqual([[true], [true], [false], [true]]);
    });
});
