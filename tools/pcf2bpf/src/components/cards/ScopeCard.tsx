import { useMemo, useState } from "react";
import {
    Button,
    Combobox,
    Field,
    Option,
    OptionGroup,
    Radio,
    RadioGroup,
    Tooltip,
    useId,
    type ComboboxProps,
    type RadioGroupProps,
} from "@fluentui/react-components";
import { useToolContext } from "../../services/pptbtoolservice";
import type { FilterMode, PublisherInfo, SolutionInfo } from "../../services";
import { useScopeCardStyles } from "../../styles";
import { GenericCard } from "./GenericCard";

function matchesQuery(text: string, query: string): boolean {
    return !query || text.toLowerCase().includes(query.toLowerCase());
}

const RADIO_BUTTON_SOLUTIONS_LABEL = "Solutions";
const RADIO_BUTTON_PUBLISHERS_LABEL = "Publishers";
const RADIO_BUTTON_NO_FILTERING_LABEL = "No Filtering";

// Shared across both comboboxes' placeholder-while-loading state and the "Load BPFs" button's
// loading state — literally the same text in every case, so one constant rather than three.
const LOADING_TEXT = "Loading...";

const SOLUTION_FIELD_HINT = "Only one solution can be selected.";
const SOLUTION_COMBOBOX_ARIA_LABEL = "Solution";
const SOLUTION_COMBOBOX_PLACEHOLDER = "Select a solution...";
const SOLUTION_OPTION_LOADING_TEXT = "Loading solutions...";
const SOLUTION_OPTION_NO_ACCESS_TEXT =
    "No solutions were returned — you may not have read access to Solution records in this environment.";
const SOLUTION_OPTION_NO_MATCH_TEXT = "No solutions match your search.";
const SOLUTION_OPTION_GROUP_NOT_RECOMMENDED_LABEL = "Not Recommended";
const SOLUTION_WORD = "solution";

const PUBLISHER_FIELD_HINT = "Only one publisher can be selected.";
const PUBLISHER_COMBOBOX_ARIA_LABEL = "Publisher";
const PUBLISHER_COMBOBOX_PLACEHOLDER = "Select a publisher...";
const PUBLISHER_OPTION_LOADING_TEXT = "Loading publishers...";
const PUBLISHER_OPTION_NO_ACCESS_TEXT =
    "No publishers were returned — you may not have read access to Publisher records in this environment.";
const PUBLISHER_OPTION_NO_MATCH_TEXT = "No publishers match your search.";
const PUBLISHER_OPTION_PREFIX_LABEL = "Prefix:";
const PUBLISHER_WORD = "publisher";

const TOOLTIP_SCOPE_SOLUTION_FRAGMENT = "in the selected solution";
const TOOLTIP_SCOPE_PUBLISHER_FRAGMENT = "in the selected publisher's solutions";
const TOOLTIP_SCOPE_UNFILTERED_FRAGMENT = "in the environment, unfiltered";
const TOOLTIP_ENABLED_PREFIX = "Loads every Business Process Flow";
const TOOLTIP_ENABLED_SUFFIX =
    ", along with all PCF controls currently registered in the connected environment and their manifest parameters. Run this again after importing a solution that adds a new Business Process Flow or PCF control, since the list is only fetched on click.";
const TOOLTIP_DISABLED_PREFIX = "Select a";
const TOOLTIP_DISABLED_SUFFIX = "above to enable loading Business Process Flows.";

const BUTTON_RELOAD_BPFS_LABEL = "Reload BPFs";
const BUTTON_LOAD_BPFS_LABEL = "Load BPFs";

const CARD_TITLE = "Scope";
const CARD_DESCRIPTION = "Choose how to scope which Business Process Flows can be loaded — by solution, by publisher, or unfiltered.";

// Documents this card's ToolContext dependency — solutions/selectedSolutionId/publishers/
// selectedPublisherId aren't received as real props (the component reads live values from
// useToolContext() itself, see below); they're listed here purely as typing/documentation of what
// ToolContext must provide, not as an actual parameter the caller passes in.
export interface IScopeCardProps {
    solutions?: SolutionInfo[];
    selectedSolutionId?: string;
    publishers?: PublisherInfo[];
    selectedPublisherId?: string;
}

/**
 * Solution and publisher pickers (a radio toggle switches which one is shown, or hides both for
 * unfiltered loading), plus the "Load BPFs" action. Solution/publisher lists and selections, the BPF
 * list, and PCF controls all live in `ToolContext` — solutions/publishers are fetched once when the
 * tool starts; `loadBpfs` (triggered here) loads Business Process Flows scoped to the selected solution
 * or the selected publisher's solutions via `solutioncomponent` (see
 * `docs/pcf2bpf/dataverse/solution-component.md`), or every BPF in the environment when "No Filtering"
 * is selected — consumed by `BpfSelectorCard`'s combobox elsewhere in the left column.
 */
export function ScopeCard(_props: IScopeCardProps) {
    const styles = useScopeCardStyles();
    const solutionComboboxId = useId("scope-card-solution");
    const publisherComboboxId = useId("scope-card-publisher");
    const {
        solutions,
        publishers,
        isLoadingSolutionsPublishers,
        selectedSolutionId,
        setSelectedSolutionId,
        selectedPublisherId,
        setSelectedPublisherId,
        bpfProcesses,
        isLoadingBpfs,
        loadBpfs,
    } = useToolContext();

    const [solutionQuery, setSolutionQuery] = useState("");
    const [publisherQuery, setPublisherQuery] = useState("");
    const [filterMode, setFilterMode] = useState<FilterMode>("solutions");

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

    const canLoadBpfs =
        filterMode === "solutions" ? selectedSolutionId !== "" : filterMode === "publishers" ? selectedPublisherId !== "" : true;

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
        void loadBpfs(
            filterMode === "solutions"
                ? { solutionId: selectedSolutionId }
                : filterMode === "publishers"
                  ? { publisherId: selectedPublisherId }
                  : undefined,
        );
    };
    const handleFilterModeChange: RadioGroupProps["onChange"] = (_, data) => {
        const mode = data.value as FilterMode;
        setFilterMode(mode);
        // Only one criterion (at most) is active at a time, so clear whichever selection(s) are being
        // hidden — otherwise a stale hidden selection would keep `canLoadBpfs` true even after
        // switching modes, or get sent along with the next load.
        if (mode !== "solutions") {
            setSelectedSolutionId("");
            setSolutionQuery("");
        }
        if (mode !== "publishers") {
            setSelectedPublisherId("");
            setPublisherQuery("");
        }
    };

    return (
        <GenericCard
            title={CARD_TITLE}
            description={CARD_DESCRIPTION}
        >
            <RadioGroup
                className={styles.filterModeRadioGroup}
                layout="horizontal"
                value={filterMode}
                onChange={handleFilterModeChange}
            >
                <Radio value="solutions" label={RADIO_BUTTON_SOLUTIONS_LABEL} />
                <Radio value="publishers" label={RADIO_BUTTON_PUBLISHERS_LABEL} />
                <Radio value="noFiltering" label={RADIO_BUTTON_NO_FILTERING_LABEL} />
            </RadioGroup>

            {filterMode === "noFiltering" ? null : filterMode === "solutions" ? (
                <Field hint={SOLUTION_FIELD_HINT} label={{ children: SOLUTION_COMBOBOX_ARIA_LABEL, htmlFor: solutionComboboxId }}>
                    <Combobox
                        id={solutionComboboxId}
                        clearable
                        placeholder={isLoadingSolutionsPublishers ? LOADING_TEXT : SOLUTION_COMBOBOX_PLACEHOLDER}
                        disabled={isLoadingSolutionsPublishers}
                        selectedOptions={selectedSolutionId ? [selectedSolutionId] : []}
                        onOptionSelect={handleSolutionSelect}
                        value={solutionQuery}
                        onChange={(event) => setSolutionQuery(event.target.value)}
                    >
                        {matchingSolutions.length === 0 ? (
                            <Option key="no-results" value="" disabled>
                                {isLoadingSolutionsPublishers
                                    ? SOLUTION_OPTION_LOADING_TEXT
                                    : solutions.length === 0
                                      ? SOLUTION_OPTION_NO_ACCESS_TEXT
                                      : SOLUTION_OPTION_NO_MATCH_TEXT}
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
                                    <OptionGroup label={SOLUTION_OPTION_GROUP_NOT_RECOMMENDED_LABEL}>
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
                <Field hint={PUBLISHER_FIELD_HINT} label={{ children: PUBLISHER_COMBOBOX_ARIA_LABEL, htmlFor: publisherComboboxId }}>
                    <Combobox
                        id={publisherComboboxId}
                        clearable
                        placeholder={isLoadingSolutionsPublishers ? LOADING_TEXT : PUBLISHER_COMBOBOX_PLACEHOLDER}
                        disabled={isLoadingSolutionsPublishers}
                        selectedOptions={selectedPublisherId ? [selectedPublisherId] : []}
                        onOptionSelect={handlePublisherSelect}
                        value={publisherQuery}
                        onChange={(event) => setPublisherQuery(event.target.value)}
                    >
                        {matchingPublishers.length === 0 ? (
                            <Option key="no-results" value="" disabled>
                                {isLoadingSolutionsPublishers
                                    ? PUBLISHER_OPTION_LOADING_TEXT
                                    : publishers.length === 0
                                      ? PUBLISHER_OPTION_NO_ACCESS_TEXT
                                      : PUBLISHER_OPTION_NO_MATCH_TEXT}
                            </Option>
                        ) : (
                            matchingPublishers.map((publisher) => (
                                <Option key={publisher.publisherid} value={publisher.publisherid} text={publisher.friendlyname}>
                                    <div className={styles.optionContent}>
                                        <span className={styles.optionName}>{publisher.friendlyname}</span>
                                        <span className={styles.optionSecondary}>
                                            {PUBLISHER_OPTION_PREFIX_LABEL} {publisher.customizationprefix}
                                        </span>
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
                        ? `${TOOLTIP_ENABLED_PREFIX} ${
                              filterMode === "solutions"
                                  ? TOOLTIP_SCOPE_SOLUTION_FRAGMENT
                                  : filterMode === "publishers"
                                    ? TOOLTIP_SCOPE_PUBLISHER_FRAGMENT
                                    : TOOLTIP_SCOPE_UNFILTERED_FRAGMENT
                          }${TOOLTIP_ENABLED_SUFFIX}`
                        : `${TOOLTIP_DISABLED_PREFIX} ${filterMode === "solutions" ? SOLUTION_WORD : PUBLISHER_WORD} ${TOOLTIP_DISABLED_SUFFIX}`
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
                    {isLoadingBpfs ? LOADING_TEXT : bpfProcesses.length > 0 ? BUTTON_RELOAD_BPFS_LABEL : BUTTON_LOAD_BPFS_LABEL}
                </Button>
            </Tooltip>
        </GenericCard>
    );
}
