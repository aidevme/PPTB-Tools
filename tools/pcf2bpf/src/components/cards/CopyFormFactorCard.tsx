import { useState } from "react";
import { Button, Dropdown, Field, Option, Tooltip } from "@fluentui/react-components";
import { Desktop20Regular, Phone20Regular, Tablet20Regular } from "@fluentui/react-icons";
import { FORM_FACTORS, FORM_FACTOR_LABELS } from "../../services";
import type { FormFactor } from "../../services";
import { useCopyFormFactorCardStyles } from "../../styles";
import { GenericCard } from "./GenericCard";

export interface ICopyFormFactorCardProps {
    onCopy: (from: FormFactor, to: FormFactor) => void;
}

/** Icon shown before each form factor's label in the "Copy from"/"Copy to" dropdowns. */
const FORM_FACTOR_ICONS: Record<FormFactor, JSX.Element> = {
    0: <Desktop20Regular />,
    1: <Phone20Regular />,
    2: <Tablet20Regular />,
};

const FIELD_COPY_FROM_LABEL = "Copy from";
const FIELD_COPY_TO_LABEL = "Copy to";

const DISABLED_REASON_BOTH_MISSING = "Select a 'Copy from' and a 'Copy to' form factor to enable copying.";
const DISABLED_REASON_FROM_MISSING = "Select a 'Copy from' form factor to enable copying.";
const DISABLED_REASON_TO_MISSING = "Select a 'Copy to' form factor to enable copying.";
const DISABLED_REASON_SAME_FORM_FACTOR = "Choose two different form factors — you can't copy a form factor onto itself.";

const TOOLTIP_ENABLED_TEXT =
    "Clones the currently selected field's PCF control assignment — the control and all its parameter values — from the 'Copy from' form factor onto the 'Copy to' form factor, overwriting whatever control (if any) is already configured there. This only affects the field you have selected; other fields and form factors are untouched, and nothing is saved to Dataverse until you click Update and Publish.";

const BUTTON_COPY_LABEL = "Copy";

const CARD_TITLE = "Copy PCF between form factors";
const CARD_DESCRIPTION = "Clone the selected field's PCF configuration from one form factor to another.";

export function CopyFormFactorCard({ onCopy }: ICopyFormFactorCardProps) {
    const styles = useCopyFormFactorCardStyles();
    const [from, setFrom] = useState<FormFactor | "">("");
    const [to, setTo] = useState<FormFactor | "">("");

    const canCopy = from !== "" && to !== "" && from !== to;

    const disabledReason =
        from === "" && to === ""
            ? DISABLED_REASON_BOTH_MISSING
            : from === ""
              ? DISABLED_REASON_FROM_MISSING
              : to === ""
                ? DISABLED_REASON_TO_MISSING
                : DISABLED_REASON_SAME_FORM_FACTOR;

    return (
        <GenericCard className={styles.minWidth} title={CARD_TITLE} description={CARD_DESCRIPTION}>
            <Field label={FIELD_COPY_FROM_LABEL}>
                <Dropdown
                    value={from === "" ? "" : FORM_FACTOR_LABELS[from]}
                    selectedOptions={from === "" ? [] : [String(from)]}
                    onOptionSelect={(_, data) => setFrom(data.optionValue === undefined ? "" : (Number(data.optionValue) as FormFactor))}
                    button={
                        from === ""
                            ? undefined
                            : {
                                  children: (
                                      <span className={styles.optionContent}>
                                          {FORM_FACTOR_ICONS[from]}
                                          {FORM_FACTOR_LABELS[from]}
                                      </span>
                                  ),
                              }
                    }
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

            <Field label={FIELD_COPY_TO_LABEL} className={styles.fieldSpacing}>
                <Dropdown
                    value={to === "" ? "" : FORM_FACTOR_LABELS[to]}
                    selectedOptions={to === "" ? [] : [String(to)]}
                    onOptionSelect={(_, data) => setTo(data.optionValue === undefined ? "" : (Number(data.optionValue) as FormFactor))}
                    button={
                        to === ""
                            ? undefined
                            : {
                                  children: (
                                      <span className={styles.optionContent}>
                                          {FORM_FACTOR_ICONS[to]}
                                          {FORM_FACTOR_LABELS[to]}
                                      </span>
                                  ),
                              }
                    }
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
                content={canCopy ? TOOLTIP_ENABLED_TEXT : disabledReason}
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
                    {BUTTON_COPY_LABEL}
                </Button>
            </Tooltip>
        </GenericCard>
    );
}
