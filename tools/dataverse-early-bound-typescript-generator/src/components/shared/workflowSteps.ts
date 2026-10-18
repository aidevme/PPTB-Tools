import type { BadgeProps } from '@fluentui/react-components';

/** Identifies one of the four workflow steps; also used in its card's element id ({@link stepElementId}). */
export type StepKey = 'project' | 'select' | 'options' | 'preview';

/** What a card's step header and the workflow progress bar show for one step. */
export interface StepState {
    /** Which step this is. */
    key: StepKey;
    /** The step's 1-based position, shown in its indicator until the step is done. */
    number: number;
    /** The step's name, shown in its card header and the progress bar, for example "Preview and generate". */
    title: string;
    /** The step is done: shown as a check mark. */
    complete: boolean;
    /** The first step that isn't done yet: highlighted as the one to work on. */
    active: boolean;
    /** Short status for the step's badge, e.g. "Ready" or "12 selected". */
    status: string;
    /**
     * The status badge's color: `success` when done, `informative` when not started, and `warning` (out of date) or
     * `brand` (files to write) for the preview step.
     */
    statusColor: NonNullable<BadgeProps['color']>;
}

/** The app state {@link computeWorkflowSteps} derives the steps from. */
export interface WorkflowInput {
    /** A project folder is open. */
    hasProject: boolean;
    /** Number of selected tables, actions and functions together. */
    selectedCount: number;
    /**
     * The last preview, or `null` before the first one: `pending` is how many changes Generate would still make,
     * and `stale` means the preview is out of date and needs to be run again.
     */
    plan: { pending: number; stale: boolean } | null;
}

/**
 * Element id of a step's card, used by the progress bar to scroll to it.
 *
 * @param key - The step.
 * @returns `workflow-step-` followed by `key`.
 */
export const stepElementId = (key: StepKey) => `workflow-step-${key}`;

/**
 * The four workflow steps with their completion, the step to work on next, and a status for each.
 *
 * - **Project** is done once a project folder is open.
 * - **Select** is done once anything is selected.
 * - **Options** is done once a project is open: its options then exist, with defaults if never changed.
 * - **Preview** is done when an up-to-date preview has nothing left to write.
 *
 * @param input - Whether a project is open, the selection count and the last preview; see {@link WorkflowInput}.
 * @returns The four steps in order, with exactly one `active` (the first not done), or none when all are done.
 */
export function computeWorkflowSteps({ hasProject, selectedCount, plan }: WorkflowInput): StepState[] {
    const steps: Array<Omit<StepState, 'active'>> = [
        {
            key: 'project',
            number: 1,
            title: 'Project',
            complete: hasProject,
            status: hasProject ? 'Ready' : 'Not selected',
            statusColor: hasProject ? 'success' : 'informative',
        },
        {
            key: 'select',
            number: 2,
            title: 'Select',
            complete: selectedCount > 0,
            status: selectedCount > 0 ? `${selectedCount} selected` : 'Nothing selected',
            statusColor: selectedCount > 0 ? 'success' : 'informative',
        },
        {
            key: 'options',
            number: 3,
            title: 'Options',
            complete: hasProject,
            status: hasProject ? 'Ready' : 'Needs a project',
            statusColor: hasProject ? 'success' : 'informative',
        },
        previewStep(plan),
    ];
    const activeIndex = steps.findIndex((s) => !s.complete);
    return steps.map((s, i) => ({ ...s, active: i === activeIndex }));
}

function previewStep(plan: WorkflowInput['plan']): Omit<StepState, 'active'> {
    const base = { key: 'preview' as const, number: 4, title: 'Preview and generate' };
    if (!plan) return { ...base, complete: false, status: 'Not run', statusColor: 'informative' };
    if (plan.stale) return { ...base, complete: false, status: 'Out of date', statusColor: 'warning' };
    if (plan.pending > 0) return { ...base, complete: false, status: `${plan.pending} to write`, statusColor: 'brand' };
    return { ...base, complete: true, status: 'Up to date', statusColor: 'success' };
}
