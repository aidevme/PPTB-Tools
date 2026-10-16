import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { SelectionKind } from '../components';
import { getSolutionEntityIds, getSolutionMemberIds, listSolutions, reportError, type PptbMetadataProvider } from '../services';
import type { EntitySummary, OperationSummary, SolutionSummary } from '../types';

/** How long the "$metadata is too large" warning stays visible. */
const METADATA_FALLBACK_WARNING_MS = 5000;

export interface UseEnvironmentMetadataOptions {
    /** The connection's metadata provider; a new one per connection. */
    provider: PptbMetadataProvider;
    inPptb: boolean;
    connection: ToolBoxAPI.Connection | null;
    /** Tables, solutions and the selection are only listed once a project is open (created or loaded). */
    hasProject: boolean;
    /** The project's selection, to tell which selected names the environment doesn't have. */
    selected: Record<SelectionKind, string[]>;
    /** Shows an error in the page (the error bar), or clears it with `null`. Must be stable (a state setter): effects depend on it. */
    setError: (message: string | null) => void;
    /** Drops the write plan when the environment's lists reload. Must be stable. */
    clearPlan: () => void;
}

/**
 * The environment's lists for the Select step: tables, actions and functions (loaded on demand), solutions and the
 * solution filter, plus the warning shown when `$metadata` is too large and the schema comes from table metadata.
 */
export function useEnvironmentMetadata({ provider, inPptb, connection, hasProject, selected, setError, clearPlan }: UseEnvironmentMetadataOptions) {
    /** The $metadata document is too large for PPTB, so the schema was rebuilt from table metadata. */
    const [metadataFallback, setMetadataFallback] = useState(false);
    /** The fallback warning is shown for a few seconds when the fallback starts, then hides itself. */
    const [showMetadataFallbackWarning, setShowMetadataFallbackWarning] = useState(false);
    const [entities, setEntities] = useState<EntitySummary[]>([]);
    const [operations, setOperations] = useState<OperationSummary[] | null>(null);
    const [solutions, setSolutions] = useState<SolutionSummary[]>([]);
    const [selectedSolutionId, setSelectedSolutionId] = useState<string | null>(null);
    const [solutionEntityIds, setSolutionEntityIds] = useState<Set<string> | null>(null);
    const [loadingEntities, setLoadingEntities] = useState(false);
    const [loadingOperations, setLoadingOperations] = useState(false);
    const [loadingSolution, setLoadingSolution] = useState(false);
    const solutionCache = useRef(new Map<string, Set<string>>());
    /** Component ids (custom APIs, process actions) of the selected solution; `null` when not filtering. */
    const [solutionComponentIds, setSolutionComponentIds] = useState<Set<string> | null>(null);
    const [loadingSolutionOperations, setLoadingSolutionOperations] = useState(false);
    const solutionOperationCache = useRef(new Map<string, Set<string>>());

    useEffect(() => {
        if (!metadataFallback) {
            setShowMetadataFallbackWarning(false);
            return;
        }
        setShowMetadataFallbackWarning(true);
        const timer = window.setTimeout(() => setShowMetadataFallbackWarning(false), METADATA_FALLBACK_WARNING_MS);
        return () => window.clearTimeout(timer);
    }, [metadataFallback]);

    useEffect(() => {
        if (!inPptb || !connection || !hasProject) return;
        let cancelled = false;
        setEntities([]);
        setOperations(null);
        setMetadataFallback(false);
        setSolutions([]);
        setSelectedSolutionId(null);
        setSolutionEntityIds(null);
        setSolutionComponentIds(null);
        solutionCache.current.clear();
        solutionOperationCache.current.clear();
        clearPlan();
        setLoadingEntities(true);
        provider
            .listEntities()
            .then((list) => !cancelled && setEntities(list))
            .catch((e) => !cancelled && setError(reportError(`Could not list tables`, e)))
            .finally(() => !cancelled && setLoadingEntities(false));
        listSolutions()
            .then((list) => !cancelled && setSolutions(list))
            .catch((e) => console.warn('Could not list solutions', e));
        return () => {
            cancelled = true;
        };
        // Only re-run when the connection (and so the provider) changes, or the first project is opened.
    }, [provider, inPptb, connection, hasProject]); // eslint-disable-line react-hooks/exhaustive-deps

    /** Records whether the provider fell back to building the schema from table metadata (shows the warning). */
    const noteMetadataFallback = useCallback(() => setMetadataFallback(provider.usesMetadataFallback), [provider]);

    const ensureOperations = useCallback(() => {
        if (operations !== null || loadingOperations || !inPptb || !hasProject) return;
        setLoadingOperations(true);
        provider
            .listOperations()
            .then((list) => {
                setOperations(list);
                setMetadataFallback(provider.usesMetadataFallback);
            })
            .catch((e) => setError(reportError(`Could not load the $metadata document`, e)))
            .finally(() => setLoadingOperations(false));
    }, [operations, loadingOperations, inPptb, hasProject, provider, setError]);

    const changeSolution = useCallback(
        async (solutionId: string | null) => {
            setSelectedSolutionId(solutionId);
            if (!solutionId) {
                setSolutionEntityIds(null);
                return;
            }
            const cached = solutionCache.current.get(solutionId);
            if (cached) {
                setSolutionEntityIds(cached);
                return;
            }
            setLoadingSolution(true);
            try {
                const ids = await getSolutionEntityIds(solutionId);
                solutionCache.current.set(solutionId, ids);
                setSolutionEntityIds(ids);
            } catch (e) {
                setError(reportError(`Could not load the solution's tables`, e));
                setSelectedSolutionId(null);
            } finally {
                setLoadingSolution(false);
            }
        },
        [setError],
    );

    // Solution membership of actions/functions: needs both a solution and the operation list.
    useEffect(() => {
        if (!selectedSolutionId || !operations) {
            setSolutionComponentIds(null);
            return;
        }
        const cached = solutionOperationCache.current.get(selectedSolutionId);
        if (cached) {
            setSolutionComponentIds(cached);
            return;
        }
        let cancelled = false;
        const solutionId = selectedSolutionId;
        const ids = operations.map((o) => o.componentId).filter((id): id is string => !!id);
        setLoadingSolutionOperations(true);
        getSolutionMemberIds(solutionId, ids)
            .then((members) => {
                solutionOperationCache.current.set(solutionId, members);
                if (!cancelled) setSolutionComponentIds(members);
            })
            .catch((e) => !cancelled && setError(reportError(`Could not load the solution's actions and functions`, e)))
            .finally(() => !cancelled && setLoadingSolutionOperations(false));
        return () => {
            cancelled = true;
        };
    }, [selectedSolutionId, operations, setError]);

    /** Selected names the environment doesn't have (once the matching list has loaded). */
    const missing = useMemo<Record<SelectionKind, string[]>>(() => {
        const entityNames = new Set(entities.map((e) => e.logicalName));
        const actionNames = new Set((operations ?? []).filter((o) => o.kind === 'action').map((o) => o.name));
        const functionNames = new Set((operations ?? []).filter((o) => o.kind === 'function').map((o) => o.name));
        return {
            entities: entities.length ? selected.entities.filter((n) => !entityNames.has(n)) : [],
            actions: operations ? selected.actions.filter((n) => !actionNames.has(n)) : [],
            functions: operations ? selected.functions.filter((n) => !functionNames.has(n)) : [],
        };
    }, [entities, operations, selected]);

    return {
        showMetadataFallbackWarning,
        noteMetadataFallback,
        entities,
        operations,
        solutions,
        selectedSolutionId,
        solutionEntityIds,
        solutionComponentIds,
        loadingEntities,
        loadingOperations,
        loadingSolution: loadingSolution || loadingSolutionOperations,
        ensureOperations,
        changeSolution,
        missing,
    };
}
