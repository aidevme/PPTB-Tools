import { useEffect, useMemo, useState } from "react";
import {
    Button,
    Combobox,
    Field,
    Option,
    OptionGroup,
    Radio,
    RadioGroup,
    Tooltip,
    type ComboboxProps,
    type RadioGroupProps,
} from "@fluentui/react-components";
import { loadPublishers, loadSolutions } from "../../services";
import type { BpfProcess, BpfScope, PublisherInfo, SolutionInfo } from "../../services";
import { useSolutionsPublishersCardStyles } from "../../styles";
import { GenericCard } from "./GenericCard";

function matchesQuery(text: string, query: string): boolean {
    return !query || text.toLowerCase().includes(query.toLowerCase());
}

async function notify(title: string, body: string, type: "success" | "error") {
    try {
        await window.toolboxAPI.utils.showNotification({ title, body, type });
    } catch {
        // Notifications are best-effort.
    }
}

interface ISolutionsPublishersCardProps {
    /** Reports loading start/end so `App.tsx` can show the same full-screen loading overlay it uses
     * while loading BPFs and PCF controls. */
    onLoadingChange: (isLoading: boolean) => void;
    bpfProcesses: BpfProcess[];
    isLoadingBpfs: boolean;
    onLoadBpfs: (scope: BpfScope) => void;
}

/**
 * Solution and publisher pickers (a radio toggle switches which one is shown), loaded once on mount,
 * plus the "Load BPFs" action. Loads Business Process Flows scoped to the selected solution (or the
 * selected publisher's solutions), via `solutioncomponent` (see
 * `docs/pcf2bpf/dataverse/solution-component.md`) — consumed by `BpfSelectorCard`'s combobox elsewhere
 * in the left column, alongside every registered PCF control (unscoped).
 */
export function SolutionsPublishersCard({ onLoadingChange, bpfProcesses, isLoadingBpfs, onLoadBpfs }: ISolutionsPublishersCardProps) {
    const styles = useSolutionsPublishersCardStyles();
    const [solutions, setSolutions] = useState<SolutionInfo[]>([]);
    const [publishers, setPublishers] = useState<PublisherInfo[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [selectedSolutionId, setSelectedSolutionId] = useState("");
    const [selectedPublisherId, setSelectedPublisherId] = useState("");
    const [solutionQuery, setSolutionQuery] = useState("");
    const [publisherQuery, setPublisherQuery] = useState("");
    const [filterMode, setFilterMode] = useState<"solutions" | "publishers">("solutions");

    useEffect(() => {
        let cancelled = false;
        onLoadingChange(true);

        void (async () => {
            try {
                const [loadedSolutions, loadedPublishers] = await Promise.all([loadSolutions(), loadPublishers()]);
                if (cancelled) return;
                setSolutions(loadedSolutions);
                setPublishers(loadedPublishers);
                void notify("Success", `Loaded ${loadedSolutions.length} solution(s) and ${loadedPublishers.length} publisher(s)`, "success");
            } catch (error) {
                console.error("Error loading solutions/publishers:", error);
                void notify("Error", `Failed to load solutions/publishers: ${(error as Error).message}`, "error");
            } finally {
                if (!cancelled) {
                    setIsLoading(false);
                    onLoadingChange(false);
                }
            }
        })();

        return () => {
            cancelled = true;
        };
    }, [onLoadingChange]);

    const matchingSolutions = useMemo(
        () => solutions.filter((s) => matchesQuery(s.friendlyname, solutionQuery)),
        [solutions, solutionQuery],
    );
    const recommendedSolutions = useMemo(() => matchingSolutions.filter((s) => !s.isDefaultSolution), [matchingSolutions]);
    const notRecommendedSolutions = useMemo(() => matchingSolutions.filter((s) => s.isDefaultSolution), [matchingSolutions]);
    const matchingPublishers = useMemo(
        () => publishers.filter((p) => matchesQuery(p.friendlyname, publisherQuery)),
        [publishers, publisherQuery],
    );

    const canLoadBpfs = filterMode === "solutions" ? selectedSolutionId !== "" : selectedPublisherId !== "";

    const handleSolutionSelect: ComboboxProps["onOptionSelect"] = (_, data) => {
        setSelectedSolutionId(data.optionValue ?? "");
        setSolutionQuery(data.optionText ?? "");
    };
    const handlePublisherSelect: ComboboxProps["onOptionSelect"] = (_, data) => {
        setSelectedPublisherId(data.optionValue ?? "");
        setPublisherQuery(data.optionText ?? "");
    };
    const handleLoadBpfsClick = () => {
        if (!canLoadBpfs || isLoadingBpfs) return;
        onLoadBpfs(filterMode === "solutions" ? { solutionId: selectedSolutionId } : { publisherId: selectedPublisherId });
    };
    const handleFilterModeChange: RadioGroupProps["onChange"] = (_, data) => {
        const mode = data.value as "solutions" | "publishers";
        setFilterMode(mode);
        // Only one criterion is active at a time, so clear the one being hidden — otherwise a
        // stale hidden selection would keep `canLoadBpfs` true even after switching modes.
        if (mode === "solutions") {
            setSelectedPublisherId("");
            setPublisherQuery("");
        } else {
            setSelectedSolutionId("");
            setSolutionQuery("");
        }
    };

    return (
        <GenericCard title="Solutions & Publishers">
            <RadioGroup
                className={styles.filterModeRadioGroup}
                layout="horizontal"
                value={filterMode}
                onChange={handleFilterModeChange}
            >
                <Radio value="solutions" label="Solutions" />
                <Radio value="publishers" label="Publishers" />
            </RadioGroup>

            {filterMode === "solutions" ? (
                <Field hint="Only one solution can be selected.">
                    <Combobox
                        clearable
                        aria-label="Solution"
                        placeholder={isLoading ? "Loading..." : "Select a solution..."}
                        disabled={isLoading}
                        selectedOptions={selectedSolutionId ? [selectedSolutionId] : []}
                        onOptionSelect={handleSolutionSelect}
                        value={solutionQuery}
                        onChange={(event) => setSolutionQuery(event.target.value)}
                    >
                        {matchingSolutions.length === 0 ? (
                            <Option key="no-results" value="" disabled>
                                {isLoading
                                    ? "Loading solutions..."
                                    : solutions.length === 0
                                      ? "No solutions were returned — you may not have read access to Solution records in this environment."
                                      : "No solutions match your search."}
                            </Option>
                        ) : (
                            <>
                                {recommendedSolutions.map((solution) => (
                                    <Option key={solution.solutionid} value={solution.solutionid} text={solution.friendlyname}>
                                        <div className={styles.optionContent}>
                                            <span className={styles.optionName}>{solution.friendlyname}</span>
                                            <span className={styles.optionSecondary}>
                                                v{solution.version} | {solution.uniquename}
                                            </span>
                                        </div>
                                    </Option>
                                ))}
                                {notRecommendedSolutions.length > 0 && (
                                    <OptionGroup label="Not Recommended">
                                        {notRecommendedSolutions.map((solution) => (
                                            <Option key={solution.solutionid} value={solution.solutionid} text={solution.friendlyname}>
                                                <div className={styles.optionContent}>
                                                    <span className={styles.optionName}>{solution.friendlyname}</span>
                                                    <span className={styles.optionSecondary}>
                                                        v{solution.version} | {solution.uniquename}
                                                    </span>
                                                </div>
                                            </Option>
                                        ))}
                                    </OptionGroup>
                                )}
                            </>
                        )}
                    </Combobox>
                </Field>
            ) : (
                <Field hint="Only one publisher can be selected.">
                    <Combobox
                        clearable
                        aria-label="Publisher"
                        placeholder={isLoading ? "Loading..." : "Select a publisher..."}
                        disabled={isLoading}
                        selectedOptions={selectedPublisherId ? [selectedPublisherId] : []}
                        onOptionSelect={handlePublisherSelect}
                        value={publisherQuery}
                        onChange={(event) => setPublisherQuery(event.target.value)}
                    >
                        {matchingPublishers.length === 0 ? (
                            <Option key="no-results" value="" disabled>
                                {isLoading
                                    ? "Loading publishers..."
                                    : publishers.length === 0
                                      ? "No publishers were returned — you may not have read access to Publisher records in this environment."
                                      : "No publishers match your search."}
                            </Option>
                        ) : (
                            matchingPublishers.map((publisher) => (
                                <Option key={publisher.publisherid} value={publisher.publisherid} text={publisher.friendlyname}>
                                    <div className={styles.optionContent}>
                                        <span className={styles.optionName}>{publisher.friendlyname}</span>
                                        <span className={styles.optionSecondary}>Prefix: {publisher.customizationprefix}</span>
                                    </div>
                                </Option>
                            ))
                        )}
                    </Combobox>
                </Field>
            )}

            <Tooltip
                content={
                    canLoadBpfs
                        ? `Loads every Business Process Flow in the selected ${
                              filterMode === "solutions" ? "solution" : "publisher's solutions"
                          }, along with all PCF controls currently registered in the connected environment and their manifest parameters. Run this again after importing a solution that adds a new Business Process Flow or PCF control, since the list is only fetched on click.`
                        : `Select a ${filterMode === "solutions" ? "solution" : "publisher"} above to enable loading Business Process Flows.`
                }
                relationship="description"
                withArrow
            >
                <Button
                    className={styles.loadBpfsButton}
                    appearance="primary"
                    onClick={handleLoadBpfsClick}
                    disabledFocusable={!canLoadBpfs || isLoadingBpfs}
                >
                    {isLoadingBpfs ? "Loading..." : bpfProcesses.length > 0 ? "Reload BPFs" : "Load BPFs"}
                </Button>
            </Tooltip>
        </GenericCard>
    );
}
