import type { LabelProps } from "@fluentui/react-components";
import { Checkbox, Field, InfoLabel } from "@fluentui/react-components";
import { useCompareXmlsCheckBoxStyles } from "../../styles";

interface ICompareXmlsCheckBoxProps {
    /** Whether the Before/After panes should highlight their differences. */
    checked: boolean;
    /** Called with the new checked state when the user toggles the checkbox. */
    onChange: (checked: boolean) => void;
    className?: string;
}

/**
 * Checkbox that toggles whether the Before/After XML panes highlight their differences.
 */
export function CompareXmlsCheckBox({ checked, onChange, className }: ICompareXmlsCheckBoxProps) {
    const styles = useCompareXmlsCheckBoxStyles();

    return (
        <Field
            className={className ? `${styles.root} ${className}` : styles.root}
            orientation="horizontal"
            label={{
                children: (_: unknown, slotProps: LabelProps) => (
                    <InfoLabel
                        {...slotProps}
                        info="Highlights the differences between the Before and After XML preview panes below."
                    >
                        Show differences
                    </InfoLabel>
                ),
            }}
        >
            <Checkbox checked={checked} onChange={(_, data) => onChange(!!data.checked)} />
        </Field>
    );
}
