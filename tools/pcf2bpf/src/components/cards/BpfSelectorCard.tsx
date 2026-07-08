import { useEffect, useMemo, useRef, useState } from "react";
import { Combobox, Field, useComboboxFilter, useId, type ComboboxProps } from "@fluentui/react-components";
import type { BpfProcess } from "../../services";
import { useBpfSelectorCardStyles } from "../../styles";

interface IBpfSelectorCardProps {
    bpfProcesses: BpfProcess[];
    selectedBpfId: string;
    onSelect: (workflowId: string) => void;
}

function bpfLabel(bpf: BpfProcess): string {
    return `${bpf.name} (${bpf.primaryentity})`;
}

export function BpfSelectorCard({ bpfProcesses, selectedBpfId, onSelect }: IBpfSelectorCardProps) {
    const styles = useBpfSelectorCardStyles();
    const comboId = useId();
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
        noOptionsMessage: "No Business Process Flows match your search.",
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
        <Field className={styles.root} label={{ children: "Business Process Flow", className: styles.eyebrow }}>
            <Combobox
                ref={comboboxRef}
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
        </Field>
    );
}
