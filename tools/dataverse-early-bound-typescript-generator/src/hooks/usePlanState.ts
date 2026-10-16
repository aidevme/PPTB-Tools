import { useCallback, useState } from 'react';
import type { WritePlan } from '../types';

/**
 * The current write plan and its status. Kept apart from {@link usePreviewGenerate} so the project, settings and
 * environment hooks, which run before it, can invalidate the plan: `clearPlan` drops it, `resetPlan` also clears
 * the stale flag (a different project), and `markPlanStale` keeps it but asks for a new preview.
 */
export function usePlanState() {
    const [plan, setPlan] = useState<WritePlan | null>(null);
    /** When the current plan was computed (ISO), for the Preview card's "Previewed … ago". */
    const [previewedAt, setPreviewedAt] = useState<string | null>(null);
    /** Summary of the last Generate run, shown in the Preview card until the next preview. */
    const [lastResult, setLastResult] = useState<string | null>(null);
    const [planStale, setPlanStale] = useState(false);

    const clearPlan = useCallback(() => setPlan(null), []);
    const resetPlan = useCallback(() => {
        setPlan(null);
        setPlanStale(false);
    }, []);
    const markPlanStale = useCallback(() => setPlanStale(true), []);

    return { plan, setPlan, previewedAt, setPreviewedAt, lastResult, setLastResult, planStale, setPlanStale, clearPlan, resetPlan, markPlanStale };
}

export type PlanState = ReturnType<typeof usePlanState>;
