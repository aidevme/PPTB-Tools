import { useEffect, useMemo, useState } from "react";
import { Button, Combobox, Field, Option, Text, Tooltip, type ComboboxProps } from "@fluentui/react-components";
import { loadPublishers, loadSolutions } from "../../lib";
import type { BpfProcess, PublisherInfo, SolutionInfo } from "../../lib";
import { useSolutionsPublishersCardStyles } from "../../styles";

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
    onLoadBpfs: () => void;
}

/**
 * Solution and publisher pickers, loaded once on mount, plus the "Load BPFs" action (loads Business
 * Process Flows and PCF controls, consumed by `BpfSelectorCard`'s combobox elsewhere in the left
 * column). Solutions/publishers are purely informational for now: selecting one here doesn't yet
 * filter the BPF/PCF control lists elsewhere in the tool (see
 * `docs/pcf2bpf/dataverse/solution-component.md` for the Dataverse-side groundwork that would make
 * that possible).
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
    const matchingPublishers = useMemo(
        () => publishers.filter((p) => matchesQuery(p.friendlyname, publisherQuery)),
        [publishers, publisherQuery],
    );

    const canLoadBpfs = selectedSolutionId !== "" || selectedPublisherId !== "";

    const handleSolutionSelect: ComboboxProps["onOptionSelect"] = (_, data) => {
        setSelectedSolutionId(data.optionValue ?? "");
        setSolutionQuery(data.optionText ?? "");
    };
    const handlePublisherSelect: ComboboxProps["onOptionSelect"] = (_, data) => {
        setSelectedPublisherId(data.optionValue ?? "");
        setPublisherQuery(data.optionText ?? "");
    };

    return (
        <div className={styles.root}>
            <Text className={styles.eyebrow}>Solutions &amp; Publishers</Text>

            <Field hint="Only one solution can be selected.">
                <Combobox
                    clearable
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
                        matchingSolutions.map((solution) => (
                            <Option key={solution.solutionid} value={solution.solutionid} text={solution.friendlyname}>
                                <div className={styles.optionContent}>
                                    <span className={styles.optionName}>{solution.friendlyname}</span>
                                    <span className={styles.optionSecondary}>
                                        v{solution.version} | {solution.uniquename}
                                    </span>
                                </div>
                            </Option>
                        ))
                    )}
                </Combobox>
            </Field>

            <Field className={styles.fieldSpacing} hint="Only one publisher can be selected.">
                <Combobox
                    clearable
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

            <Tooltip
                content={
                    canLoadBpfs
                        ? "Loads every active Business Process Flow (workflow records with category = Business Process Flow) from the connected environment, along with all PCF controls currently registered in that environment and their manifest parameters. Run this again after importing a solution that adds a new Business Process Flow or PCF control, since the list is only fetched on click."
                        : "Select a solution or publisher above to enable loading Business Process Flows."
                }
                relationship="description"
                withArrow
            >
                <Button
                    className={styles.loadBpfsButton}
                    appearance="primary"
                    onClick={() => canLoadBpfs && !isLoadingBpfs && onLoadBpfs()}
                    disabledFocusable={!canLoadBpfs || isLoadingBpfs}
                >
                    {isLoadingBpfs ? "Loading..." : bpfProcesses.length > 0 ? "Reload BPFs" : "Load BPFs"}
                </Button>
            </Tooltip>
        </div>
    );
}
