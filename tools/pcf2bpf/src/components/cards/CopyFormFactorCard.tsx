import { useState } from "react";
import { Button, Dropdown, Field, Option, Tooltip } from "@fluentui/react-components";
import { FORM_FACTOR_LABELS, FORM_FACTOR_TAB_ORDER } from "../../services";
import type { FormFactor } from "../../services";
import { useCopyFormFactorCardStyles } from "../../styles";
import { FORM_FACTOR_ICONS } from "../../consts/Cards.Common.const";
import { GenericCard } from "./GenericCard";
import {
    BUTTON_COPY_LABEL,
    CARD_DESCRIPTION,
    CARD_TITLE,
    DISABLED_REASON_BOTH_MISSING,
    DISABLED_REASON_FROM_MISSING,
    DISABLED_REASON_SAME_FORM_FACTOR,
    DISABLED_REASON_TO_MISSING,
    FIELD_COPY_FROM_LABEL,
    FIELD_COPY_TO_LABEL,
    TOOLTIP_ENABLED_TEXT,
} from "../../consts/CopyFormFactorCard.const";

export interface ICopyFormFactorCardProps {
    onCopy: (from: FormFactor, to: FormFactor) => void;
    /** Whether each form factor currently has a PCF control assigned on the selected field — the
     * "Copy from" dropdown disables the option for any form factor with nothing to copy. */
    assignedByFormFactor: Partial<Record<FormFactor, boolean>>;
}

export function CopyFormFactorCard({ onCopy, assignedByFormFactor }: ICopyFormFactorCardProps) {
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
                    {FORM_FACTOR_TAB_ORDER.map((ff) => (
                        <Option key={ff} value={String(ff)} text={FORM_FACTOR_LABELS[ff]} disabled={!assignedByFormFactor[ff]}>
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
                    {FORM_FACTOR_TAB_ORDER.filter((ff) => ff !== from).map((ff) => (
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
