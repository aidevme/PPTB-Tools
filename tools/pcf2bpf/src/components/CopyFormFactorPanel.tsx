import { useState } from "react";
import { Button, Dropdown, Field, Option, Text, Tooltip } from "@fluentui/react-components";
import { FORM_FACTORS, FORM_FACTOR_LABELS } from "../lib";
import type { FormFactor } from "../lib";
import { useCopyFormFactorPanelStyles } from "../styles";

interface ICopyFormFactorPanelProps {
    onCopy: (from: FormFactor, to: FormFactor) => void;
}

export function CopyFormFactorPanel({ onCopy }: ICopyFormFactorPanelProps) {
    const styles = useCopyFormFactorPanelStyles();
    const [from, setFrom] = useState<FormFactor | "">("");
    const [to, setTo] = useState<FormFactor | "">("");

    const canCopy = from !== "" && to !== "" && from !== to;

    const disabledReason =
        from === "" && to === ""
            ? "Select a 'Copy from' and a 'Copy to' form factor to enable copying."
            : from === ""
              ? "Select a 'Copy from' form factor to enable copying."
              : to === ""
                ? "Select a 'Copy to' form factor to enable copying."
                : "Choose two different form factors — you can't copy a form factor onto itself.";

    return (
        <div className={styles.root}>
            <Text weight="semibold" block className={styles.title}>
                Copy PCF between form factors
            </Text>

            <Field label="Copy from">
                <Dropdown
                    value={from === "" ? "" : FORM_FACTOR_LABELS[from]}
                    selectedOptions={from === "" ? [] : [String(from)]}
                    onOptionSelect={(_, data) => setFrom(data.optionValue === undefined ? "" : (Number(data.optionValue) as FormFactor))}
                >
                    {FORM_FACTORS.map((ff) => (
                        <Option key={ff} value={String(ff)}>
                            {FORM_FACTOR_LABELS[ff]}
                        </Option>
                    ))}
                </Dropdown>
            </Field>

            <Field label="Copy to" className={styles.fieldSpacing}>
                <Dropdown
                    value={to === "" ? "" : FORM_FACTOR_LABELS[to]}
                    selectedOptions={to === "" ? [] : [String(to)]}
                    onOptionSelect={(_, data) => setTo(data.optionValue === undefined ? "" : (Number(data.optionValue) as FormFactor))}
                >
                    {FORM_FACTORS.filter((ff) => ff !== from).map((ff) => (
                        <Option key={ff} value={String(ff)}>
                            {FORM_FACTOR_LABELS[ff]}
                        </Option>
                    ))}
                </Dropdown>
            </Field>

            <Tooltip
                content={
                    canCopy
                        ? "Clones the currently selected field's PCF control assignment — the control and all its parameter values — from the 'Copy from' form factor onto the 'Copy to' form factor, overwriting whatever control (if any) is already configured there. This only affects the field you have selected; other fields and form factors are untouched, and nothing is saved to Dataverse until you click Update and Publish."
                        : disabledReason
                }
                relationship="description"
                positioning="below"
                withArrow
            >
                <Button
                    appearance="primary"
                    className={styles.copyButton}
                    disabledFocusable={!canCopy}
                    onClick={() => canCopy && onCopy(from, to)}
                >
                    Copy
                </Button>
            </Tooltip>
        </div>
    );
}
