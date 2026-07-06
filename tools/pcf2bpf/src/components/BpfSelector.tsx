import { useEffect, useMemo, useState } from "react";
import { Button, Combobox, Field, Tooltip, useComboboxFilter, useId, type ComboboxProps } from "@fluentui/react-components";
import type { BpfProcess } from "../lib";
import { useBpfSelectorStyles } from "../styles";

interface IBpfSelectorProps {
    bpfProcesses: BpfProcess[];
    selectedBpfId: string;
    isLoading: boolean;
    onLoad: () => void;
    onSelect: (workflowId: string) => void;
}

function bpfLabel(bpf: BpfProcess): string {
    return `${bpf.name} (${bpf.primaryentity})`;
}

export function BpfSelector({ bpfProcesses, selectedBpfId, isLoading, onLoad, onSelect }: IBpfSelectorProps) {
    const styles = useBpfSelectorStyles();
    const comboId = useId();
    const selected = bpfProcesses.find((b) => b.workflowid === selectedBpfId);
    const selectedLabel = selected ? bpfLabel(selected) : "";

    const [query, setQuery] = useState(selectedLabel);

    // Keep the input text in sync when the selection changes from outside (e.g. after reloading the list).
    useEffect(() => {
        setQuery(selectedLabel);
    }, [selectedLabel]);

    const options = useMemo(
        () => bpfProcesses.map((bpf) => ({ children: bpfLabel(bpf), value: bpf.workflowid })),
        [bpfProcesses],
    );

    const children = useComboboxFilter(query, options, {
        noOptionsMessage: "No Business Process Flows match your search.",
        optionToText: (option) => option.children,
    });

    const handleOptionSelect: ComboboxProps["onOptionSelect"] = (_, data) => {
        onSelect(data.optionValue ?? "");
        setQuery(data.optionText ?? "");
    };

    return (
        <Field label="Business Process Flow">
            <div className={styles.column}>
                <Tooltip
                    content="Loads every active Business Process Flow (workflow records with category = Business Process Flow) from the connected environment, along with all PCF controls currently registered in that environment and their manifest parameters. Run this again after importing a solution that adds a new Business Process Flow or PCF control, since the list is only fetched on click."
                    relationship="description"
                    withArrow
                >
                    <Button className={styles.fullWidth} appearance="primary" onClick={onLoad} disabled={isLoading}>
                        {isLoading ? "Loading..." : bpfProcesses.length > 0 ? "Reload BPFs" : "Load BPFs"}
                    </Button>
                </Tooltip>
                <Combobox
                    className={styles.fullWidth}
                    clearable
                    aria-labelledby={comboId}
                    placeholder={bpfProcesses.length ? "Select a Business Process Flow" : "Load Business Process Flows first"}
                    value={query}
                    selectedOptions={selectedBpfId ? [selectedBpfId] : []}
                    onOptionSelect={handleOptionSelect}
                    onChange={(event) => setQuery(event.target.value)}
                    disabled={bpfProcesses.length === 0}
                >
                    {children}
                </Combobox>
            </div>
        </Field>
    );
}
