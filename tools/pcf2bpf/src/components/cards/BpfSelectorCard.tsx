import { useEffect, useMemo, useRef, useState } from "react";
import { Combobox, Field, useComboboxFilter, type ComboboxProps } from "@fluentui/react-components";
import { useToolContext } from "../../services/pptbtoolservice";
import type { BpfProcess } from "../../services";
import { useBpfSelectorCardStyles } from "../../styles";
import { GenericCard } from "./GenericCard";

export interface IBpfSelectorCardProps {
    /** Selecting a BPF also loads its form XML, so this is an `App.tsx`-level orchestration callback
     * rather than just `ToolContext`'s `setSelectedBpfId`. */
    onSelect: (workflowId: string) => void;
}

function bpfLabel(bpf: BpfProcess): string {
    return `${bpf.name} (${bpf.primaryentity})`;
}

const BPF_COMBOBOX_ARIA_LABEL = "Business Process Flow";
const BPF_COMBOBOX_PLACEHOLDER = "Select a Business Process Flow";
const BPF_COMBOBOX_PLACEHOLDER_EMPTY = "Load Business Process Flows first";
const BPF_COMBOBOX_NO_OPTIONS_MESSAGE = "No Business Process Flows match your search.";

const CARD_TITLE = "Business Process Flow";
const CARD_DESCRIPTION = "Select a loaded Business Process Flow to browse its stages and fields.";

export function BpfSelectorCard({ onSelect }: IBpfSelectorCardProps) {
    const styles = useBpfSelectorCardStyles();
    const { bpfProcesses, selectedBpfId } = useToolContext();
    const comboboxRef = useRef<HTMLInputElement>(null);
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
        noOptionsMessage: BPF_COMBOBOX_NO_OPTIONS_MESSAGE,
        optionToText: (option) => option.children,
    });

    const handleOptionSelect: ComboboxProps["onOptionSelect"] = (_, data) => {
        onSelect(data.optionValue ?? "");
        setQuery(data.optionText ?? "");
        // Combobox's own listbox re-focuses the input on the same click's bubble phase (to keep
        // it usable for keyboard users), which would immediately undo a synchronous blur() here.
        // Deferring to the next tick lets that happen first, then blurs afterward.
        setTimeout(() => comboboxRef.current?.blur(), 0);
    };

    return (
        <GenericCard
            title={CARD_TITLE}
            description={CARD_DESCRIPTION}
        >
            <Field>
                <Combobox
                    ref={comboboxRef}
                    className={styles.fullWidth}
                    clearable
                    aria-label={BPF_COMBOBOX_ARIA_LABEL}
                    placeholder={bpfProcesses.length ? BPF_COMBOBOX_PLACEHOLDER : BPF_COMBOBOX_PLACEHOLDER_EMPTY}
                    value={query}
                    selectedOptions={selectedBpfId ? [selectedBpfId] : []}
                    onOptionSelect={handleOptionSelect}
                    onChange={(event) => setQuery(event.target.value)}
                    disabled={bpfProcesses.length === 0}
                >
                    {children}
                </Combobox>
            </Field>
        </GenericCard>
    );
}
