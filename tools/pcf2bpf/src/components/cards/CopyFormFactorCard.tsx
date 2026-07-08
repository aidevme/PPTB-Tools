import { useState } from "react";
import { Button, Dropdown, Field, Option, Text, Tooltip } from "@fluentui/react-components";
import { Desktop20Regular, Phone20Regular, Tablet20Regular } from "@fluentui/react-icons";
import { FORM_FACTORS, FORM_FACTOR_LABELS } from "../../services";
import type { FormFactor } from "../../services";
import { useCopyFormFactorCardStyles } from "../../styles";

interface ICopyFormFactorCardProps {
    onCopy: (from: FormFactor, to: FormFactor) => void;
}

/** Icon shown before each form factor's label in the "Copy from"/"Copy to" dropdowns. */
const FORM_FACTOR_ICONS: Record<FormFactor, JSX.Element> = {
    0: <Desktop20Regular />,
    1: <Phone20Regular />,
    2: <Tablet20Regular />,
};

export function CopyFormFactorCard({ onCopy }: ICopyFormFactorCardProps) {
    const styles = useCopyFormFactorCardStyles();
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
            <Text block className={styles.title}>
                Copy PCF between form factors
            </Text>

            <Field label="Copy from">
                <Dropdown
                    value={from === "" ? "" : FORM_FACTOR_LABELS[from]}
                    selectedOptions={from === "" ? [] : [String(from)]}
                    onOptionSelect={(_, data) => setFrom(data.optionValue === undefined ? "" : (Number(data.optionValue) as FormFactor))}
                >
                    {FORM_FACTORS.map((ff) => (
                        <Option key={ff} value={String(ff)} text={FORM_FACTOR_LABELS[ff]}>
                            <span className={styles.optionContent}>
                                {FORM_FACTOR_ICONS[ff]}
                                {FORM_FACTOR_LABELS[ff]}
                            </span>
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
                        <Option key={ff} value={String(ff)} text={FORM_FACTOR_LABELS[ff]}>
                            <span className={styles.optionContent}>
                                {FORM_FACTOR_ICONS[ff]}
                                {FORM_FACTOR_LABELS[ff]}
                            </span>
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
