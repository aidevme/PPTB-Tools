/**
 * The workflow UI: step states, the progress bar, relative times and shortened paths, and the Project card's
 * empty state, recent projects and open-project summary.
 */
import { act, createElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ProjectEntry } from '../src/config';
import { ProjectCard, type IProjectCardProps } from '../src/components/cards/ProjectCard';
import { recentProjects } from '../src/components/cards/parts/recentProjects';
import { formatRelativeTime, shortenPath } from '../src/components/shared/format';
import { WorkflowProgress } from '../src/components/shared/WorkflowProgress';
import { computeWorkflowSteps, stepElementId } from '../src/components/shared/workflowSteps';

(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

const NOW = Date.parse('2026-10-13T12:00:00.000Z');
const project = (id: string, name: string, location: string, modifiedOn: string, version = '1.0.0'): ProjectEntry => ({
    id,
    name,
    description: '',
    location,
    version,
    createdOn: '2026-10-01T00:00:00.000Z',
    modifiedOn,
});
const CONTOSO = project('c', 'Contoso Sales', 'C:\\repos\\nexus-d365\\d365-ce\\Project\\Client\\clientjs', '2026-10-13T09:00:00.000Z', '1.0.2');
const FABRIKAM = project('f', 'Fabrikam', 'C:\\repos\\fabrikam', '2026-10-11T12:00:00.000Z');
const ADVENTURE = project('a', 'Adventure Works', 'C:\\repos\\aw', '2026-09-01T12:00:00.000Z');
const NORTHWIND = project('n', 'Northwind', 'C:\\repos\\nw', '2026-10-12T12:00:00.000Z');

describe('computeWorkflowSteps', () => {
    it('starts with only the project step active', () => {
        const steps = computeWorkflowSteps({ hasProject: false, selectedCount: 0, plan: null });
        expect(steps.map((s) => [s.key, s.complete, s.active, s.status])).toEqual([
            ['project', false, true, 'Not selected'],
            ['select', false, false, 'Nothing selected'],
            ['options', false, false, 'Needs a project'],
            ['preview', false, false, 'Not run'],
        ]);
    });

    it('moves to the first incomplete step', () => {
        const steps = computeWorkflowSteps({ hasProject: true, selectedCount: 3, plan: null });
        expect(steps.map((s) => s.complete)).toEqual([true, true, true, false]);
        expect(steps.find((s) => s.active)?.key).toBe('preview');
        expect(steps[1].status).toBe('3 selected');
    });

    it('reports the preview state', () => {
        const preview = (plan: { pending: number; stale: boolean }) => computeWorkflowSteps({ hasProject: true, selectedCount: 1, plan })[3];
        expect(preview({ pending: 0, stale: true })).toMatchObject({ complete: false, status: 'Out of date', statusColor: 'warning' });
        expect(preview({ pending: 4, stale: false })).toMatchObject({ complete: false, status: '4 to write', statusColor: 'brand' });
        expect(preview({ pending: 0, stale: false })).toMatchObject({ complete: true, status: 'Up to date', active: false });
    });
});

describe('formatRelativeTime', () => {
    it('describes past times in words', () => {
        expect(formatRelativeTime('2026-10-13T11:59:40.000Z', NOW, 'en')).toBe('just now');
        expect(formatRelativeTime('2026-10-13T09:00:00.000Z', NOW, 'en')).toBe('3 hours ago');
        expect(formatRelativeTime('2026-10-12T12:00:00.000Z', NOW, 'en')).toBe('yesterday');
        expect(formatRelativeTime('2026-09-01T12:00:00.000Z', NOW, 'en')).toBe('last month');
    });

    it('returns text that is not a date unchanged', () => {
        expect(formatRelativeTime('yesterday-ish', NOW)).toBe('yesterday-ish');
    });
});

describe('shortenPath', () => {
    it('keeps the root and last two segments of long paths', () => {
        expect(shortenPath('C:\\repos\\nexus-d365\\d365-ce\\Project\\Client\\clientjs', 30)).toBe('C:\\…\\Client\\clientjs');
        expect(shortenPath('/home/me/repos/nexus/d365-ce/Project/Client/clientjs', 30)).toBe('/home/…/Client/clientjs');
    });

    it('leaves short paths alone', () => {
        expect(shortenPath('C:\\repos\\aw')).toBe('C:\\repos\\aw');
    });
});

describe('recentProjects', () => {
    it('lists the last-used folder first, then saved projects by last modified, up to three', () => {
        const list = recentProjects([ADVENTURE, FABRIKAM, CONTOSO, NORTHWIND], null, 'D:\\scratch\\demo-app', NOW);
        expect(list.map((r) => [r.name, r.meta])).toEqual([
            ['demo-app', 'Last used'],
            ['Contoso Sales', 'Modified 3 hours ago'],
            ['Northwind', 'Modified yesterday'],
        ]);
    });

    it('shows a saved last-used folder under its project name, once, and skips the open project', () => {
        const list = recentProjects([CONTOSO, FABRIKAM, NORTHWIND], 'c:/repos/nw', 'c:\\repos\\fabrikam\\', NOW);
        expect(list.map((r) => [r.name, r.isLastUsed])).toEqual([
            ['Fabrikam', true],
            ['Contoso Sales', false],
        ]);
    });
});

let root: Root | undefined;
let container: HTMLElement | undefined;

afterEach(() => {
    act(() => root?.unmount());
    container?.remove();
    root = undefined;
});

async function renderInto(element: ReturnType<typeof createElement>) {
    container = document.body.appendChild(document.createElement('div'));
    root = createRoot(container);
    await act(async () => root!.render(createElement(FluentProvider, { theme: webLightTheme }, element)));
}

async function renderProjectCard(overrides: Partial<IProjectCardProps> = {}) {
    const props: IProjectCardProps = {
        step: computeWorkflowSteps({ hasProject: !!overrides.projectRoot, selectedCount: 0, plan: null })[0],
        projectRoot: null,
        rememberedFolder: null,
        configState: null,
        projects: [CONTOSO, FABRIKAM],
        busy: false,
        onNewProject: vi.fn(),
        onLoadExistingProject: vi.fn(),
        onOpenRecent: vi.fn(),
        onReload: vi.fn(),
        onCopyPath: vi.fn(),
        now: NOW,
        ...overrides,
    };
    await renderInto(createElement(ProjectCard, props));
    return props;
}

const buttonByText = (text: string) => Array.from(document.querySelectorAll('button')).find((b) => b.textContent === text) as HTMLButtonElement;
const click = (element: HTMLElement) => act(async () => element.click());

describe('ProjectCard', () => {
    it('shows an empty state with Load Existing Project as the primary action', async () => {
        const props = await renderProjectCard();
        expect(document.body.textContent).toContain('Open a project to get started');
        // Load Existing Project comes first (it's the primary action); there's no Reload without a project.
        const labels = Array.from(document.querySelectorAll('button')).map((b) => b.textContent);
        expect(labels.indexOf('Load Existing Project')).toBeLessThan(labels.indexOf('New Project'));
        expect(document.body.textContent).not.toContain('Reload');
        await click(buttonByText('Load Existing Project'));
        await click(buttonByText('New Project'));
        expect(props.onLoadExistingProject).toHaveBeenCalled();
        expect(props.onNewProject).toHaveBeenCalled();
    });

    it('opens a recent project directly', async () => {
        const props = await renderProjectCard();
        const recent = document.querySelector('button[aria-label^="Open Contoso Sales"]') as HTMLButtonElement;
        expect(recent.textContent).toContain('Modified 3 hours ago');
        await click(recent);
        expect(props.onOpenRecent).toHaveBeenCalledWith({ name: 'Contoso Sales', location: CONTOSO.location });
    });

    it('summarizes an open saved project', async () => {
        const props = await renderProjectCard({
            projectRoot: CONTOSO.location,
            configState: { path: '', exists: true, config: { entities: ['account', 'contact'], actions: ['WinOpportunity'], functions: [] } },
        });
        const text = document.body.textContent ?? '';
        expect(text).toContain('Contoso Sales');
        expect(text).toContain('v1.0.2');
        expect(text).toContain('C:\\…\\Client\\clientjs');
        expect(text).toContain('.dataverse-gen.json found');
        expect(text).toContain('2 tables');
        expect(text).toContain('1 actions');
        expect(text).toContain('Modified 3 hours ago');
        expect(text).not.toContain('Open a project to get started');
        // The open project isn't offered as a recent one.
        expect(document.querySelector('button[aria-label^="Open Contoso Sales"]')).toBeNull();

        await click(document.querySelector('button[aria-label="Copy project folder path"]') as HTMLButtonElement);
        expect(props.onCopyPath).toHaveBeenCalledWith(CONTOSO.location, 'Project folder path');
        await click(document.querySelector('button[aria-label="Reload .dataverse-gen.json from disk"]') as HTMLButtonElement);
        expect(props.onReload).toHaveBeenCalled();
    });

    it('uses the folder name for a folder that is not a saved project', async () => {
        await renderProjectCard({ projectRoot: 'C:\\work\\scratch-app', configState: { path: '', exists: false, config: {} } });
        expect(document.body.textContent).toContain('scratch-app');
        expect(document.body.textContent).toContain('New project: created on generate');
        expect(document.body.textContent).not.toMatch(/v\d+\.\d+\.\d+/);
    });
});

describe('WorkflowProgress', () => {
    it('marks the active step and scrolls to a step card when clicked', async () => {
        const steps = computeWorkflowSteps({ hasProject: true, selectedCount: 0, plan: null });
        const target = document.body.appendChild(document.createElement('div'));
        target.id = stepElementId('preview');
        target.scrollIntoView = vi.fn();
        await renderInto(createElement(WorkflowProgress, { steps }));

        const current = document.querySelector('[aria-current="step"]') as HTMLButtonElement;
        expect(current.textContent).toContain('Select');
        expect(document.querySelectorAll('nav[aria-label="Workflow progress"] li')).toHaveLength(4);

        await click(document.querySelector('button[aria-label^="Step 4"]') as HTMLButtonElement);
        expect(target.scrollIntoView).toHaveBeenCalled();
        target.remove();
    });
});

describe('recent project count', () => {
    it('honours the General setting, and 0 offers none', () => {
        expect(recentProjects([ADVENTURE, FABRIKAM, CONTOSO, NORTHWIND], null, null, NOW, 2)).toHaveLength(2);
        expect(recentProjects([ADVENTURE, FABRIKAM, CONTOSO, NORTHWIND], null, 'D:\\scratch\\demo-app', NOW, 0)).toEqual([]);
    });
});
