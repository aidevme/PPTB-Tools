import type { LabelProps } from "@fluentui/react-components";
import { Field, InfoLabel, SearchBox } from "@fluentui/react-components";
import { DEFAULT_PLACEHOLDER, INFO_TEXT_SEARCH, LABEL_SEARCH } from "../../consts";
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
export function XmlSearchBox({ value, onChange, placeholder = DEFAULT_PLACEHOLDER, className }: IXmlSearchBoxProps) {
    const styles = useXmlSearchBoxStyles();

    return (
        <Field
            className={className ? `${styles.root} ${className}` : styles.root}
            orientation="horizontal"
            label={{
                children: (_: unknown, slotProps: LabelProps) => (
                    <InfoLabel {...slotProps} info={INFO_TEXT_SEARCH}>
                        {LABEL_SEARCH}
                    </InfoLabel>
                ),
            }}
        >
            <SearchBox placeholder={placeholder} value={value} onChange={(_, data) => onChange(data.value)} />
        </Field>
    );
}
