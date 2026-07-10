import type { LabelProps } from "@fluentui/react-components";
import { Field, InfoLabel, SearchBox } from "@fluentui/react-components";
import { useXmlSearchBoxStyles } from "../../styles";

export interface IXmlSearchBoxProps {
    /** Current search text. */
    value: string;
    /** Called with the new search text on every keystroke. */
    onChange: (value: string) => void;
    placeholder?: string;
    className?: string;
}

/**
 * Search input whose value drives text highlighting within one or more {@link XmlFormatter}
 * instances (via their `highlightQuery` prop).
 *
 * @remarks
 * Only highlights matches — it does not filter or hide non-matching lines.
 */
export function XmlSearchBox({ value, onChange, placeholder = "Search...", className }: IXmlSearchBoxProps) {
    const styles = useXmlSearchBoxStyles();

    return (
        <Field
            className={className ? `${styles.root} ${className}` : styles.root}
            orientation="horizontal"
            label={{
                children: (_: unknown, slotProps: LabelProps) => (
                    <InfoLabel
                        {...slotProps}
                        info="Highlights matching text in the Before/After XML preview panes below. It does not filter out non-matching lines."
                    >
                        Search
                    </InfoLabel>
                ),
            }}
        >
            <SearchBox placeholder={placeholder} value={value} onChange={(_, data) => onChange(data.value)} />
        </Field>
    );
}
