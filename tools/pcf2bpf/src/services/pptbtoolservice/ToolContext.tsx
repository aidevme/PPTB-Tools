import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import { loadBpfProcesses, loadEntityMetadata, loadPcfControls, loadPublishers, loadSolutions } from "..";
import type { BpfProcess, BpfScope, EntityMetadataInfo, PcfControl, PublisherInfo, SolutionInfo } from "..";
import { ToolContextService } from "./ToolContextService";

interface IToolContext {
    solutions: SolutionInfo[];
    selectedSolutionId: string;
    setSelectedSolutionId: (solutionId: string) => void;

    publishers: PublisherInfo[];
    selectedPublisherId: string;
    setSelectedPublisherId: (publisherId: string) => void;

    /** `true` until the initial solutions/publishers fetch (kicked off on mount) settles. */
    isLoadingSolutionsPublishers: boolean;

    bpfProcesses: BpfProcess[];
    selectedBpfId: string;
    setSelectedBpfId: (workflowId: string) => void;
    isLoadingBpfs: boolean;

    /** Every registered PCF control, loaded alongside BPFs (unscoped — not filtered by solution/publisher). */
    pcfControls: PcfControl[];

    entityMetadataInfos: EntityMetadataInfo[];

    /** Loads BPFs (optionally scoped to a solution or publisher) and every registered PCF control. */
    loadBpfs: (scope: BpfScope | undefined) => Promise<void>;

    /** Loads full entity metadata (one {@link EntityMetadataInfo} per logical name) for the given
     * entities and stores the result as `entityMetadataInfos` — one entry for a single-entity BPF,
     * one per distinct entity for a multi-entity BPF (e.g. Lead → Opportunity). */
    loadEntityMetadataInfos: (entityLogicalNames: string[]) => Promise<void>;

    /** Whether the `DebuggerPanel` overlay drawer (opened from `Footer`'s "Debugger" button) is open. */
    isDebuggerOpen: boolean;
    setIsDebuggerOpen: (open: boolean) => void;
}

const ToolContext = createContext<IToolContext | null>(null);
const PcfServiceContext = createContext<ToolContextService | null>(null);

interface ToolContextProviderProps {
    toolcontext: ToolContextService;
    children: ReactNode;
}

/**
 * Initializes and owns solution/publisher/BPF picker state (lists + current selections) plus every
 * registered PCF control, for the whole tool. Solutions and publishers are fetched once an active
 * Dataverse connection is confirmed via the injected `ToolContextService` (`window.dataverseAPI` isn't
 * reliably callable before that); BPFs (and PCF controls) are fetched on demand via `loadBpfs`,
 * mirroring the "Load BPFs" action in `ScopeCard`.
 */
export const ToolContextProvider = ({ toolcontext, children }: ToolContextProviderProps) => {
    const [solutions, setSolutions] = useState<SolutionInfo[]>([]);
    const [publishers, setPublishers] = useState<PublisherInfo[]>([]);
    const [selectedSolutionId, setSelectedSolutionId] = useState("");
    const [selectedPublisherId, setSelectedPublisherId] = useState("");
    const [isLoadingSolutionsPublishers, setIsLoadingSolutionsPublishers] = useState(true);

    const [bpfProcesses, setBpfProcesses] = useState<BpfProcess[]>([]);
    const [pcfControls, setPcfControls] = useState<PcfControl[]>([]);
    const [entityMetadataInfos, setEntityMetadataInfos] = useState<EntityMetadataInfo[]>([]);
    const [selectedBpfId, setSelectedBpfId] = useState("");
    const [isLoadingBpfs, setIsLoadingBpfs] = useState(false);
    const [isDebuggerOpen, setIsDebuggerOpen] = useState(false);

    // Kicked off once an active connection is confirmed, rather than unconditionally on mount —
    // this provider sits above App.tsx's own connection check, so without this guard the fetch would
    // race ahead of window.dataverseAPI being usable and silently come back empty.
    useEffect(() => {
        let cancelled = false;

        void (async () => {
            let connection: Awaited<ReturnType<typeof toolcontext.getActiveConnection>> = null;
            try {
                connection = await toolcontext.getActiveConnection();
            } catch (error) {
                console.error("Error checking active connection:", error);
            }
            if (cancelled || !connection) return;

            setIsLoadingSolutionsPublishers(true);
            try {
                const [loadedSolutions, loadedPublishers] = await Promise.all([loadSolutions(), loadPublishers()]);
                if (cancelled) return;
                setSolutions(loadedSolutions);
                setPublishers(loadedPublishers);
                void toolcontext.notify(
                    "Success",
                    `Loaded ${loadedSolutions.length} solution(s) and ${loadedPublishers.length} publisher(s)`,
                    "success",
                );
            } catch (error) {
                console.error("Error loading solutions/publishers:", error);
                void toolcontext.notify("Error", `Failed to load solutions/publishers: ${(error as Error).message}`, "error");
            } finally {
                if (!cancelled) setIsLoadingSolutionsPublishers(false);
            }
        })();

        return () => {
            cancelled = true;
        };
    }, [toolcontext]);

    const loadBpfs = useCallback(
        async (scope: BpfScope | undefined) => {
            setIsLoadingBpfs(true);
            try {
                const [processes, controls] = await Promise.all([loadBpfProcesses(scope), loadPcfControls()]);
                setBpfProcesses(processes);
                setPcfControls(controls);
                await toolcontext.notify(
                    "Success",
                    `Loaded ${processes.length} Business Process Flow(s) and ${controls.length} PCF control(s)`,
                    "success",
                );
            } catch (error) {
                console.error("Error loading BPFs:", error);
                await toolcontext.notify("Error", `Failed to load Business Process Flows: ${(error as Error).message}`, "error");
            } finally {
                setIsLoadingBpfs(false);
            }
        },
        [toolcontext],
    );

    const loadEntityMetadataInfos = useCallback(async (entityLogicalNames: string[]) => {
        const infos = await Promise.all(entityLogicalNames.map((entity) => loadEntityMetadata(entity)));
        setEntityMetadataInfos(infos);
    }, []);

    const value: IToolContext = {
        solutions,
        selectedSolutionId,
        setSelectedSolutionId,
        publishers,
        selectedPublisherId,
        setSelectedPublisherId,
        isLoadingSolutionsPublishers,
        bpfProcesses,
        selectedBpfId,
        setSelectedBpfId,
        pcfControls,
        entityMetadataInfos,
        isLoadingBpfs,
        loadBpfs,
        loadEntityMetadataInfos,
        isDebuggerOpen,
        setIsDebuggerOpen,
    };

    return (
        <PcfServiceContext.Provider value={toolcontext}>
            <ToolContext.Provider value={value}>{children}</ToolContext.Provider>
        </PcfServiceContext.Provider>
    );
};

/** Reads solution/publisher/BPF picker state and PCF controls from the nearest `ToolContextProvider`. */
export function useToolContext(): IToolContext {
    const ctx = useContext(ToolContext);
    if (!ctx) {
        throw new Error("useToolContext must be used within a ToolContextProvider");
    }
    return ctx;
}

/** Reads the raw `ToolContextService` (host-API access: connection, theme, notifications) from the
 * nearest `ToolContextProvider`, for call sites that just need the service itself rather than the
 * app-state it's used to populate. */
export function usePcfContextService(): ToolContextService {
    const ctx = useContext(PcfServiceContext);
    if (!ctx) {
        throw new Error("usePcfContextService must be used within a ToolContextProvider");
    }
    return ctx;
}
