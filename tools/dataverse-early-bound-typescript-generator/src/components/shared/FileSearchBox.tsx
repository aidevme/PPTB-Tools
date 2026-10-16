import { SearchBox, mergeClasses } from '@fluentui/react-components';
import { useFileSearchBoxStyles } from '../../styles';

export interface IFileSearchBoxProps {
    /** The search text. */
    value: string;
    /** Called with the new text on every keystroke, and with `''` when the clear button is clicked. */
    onChange: (value: string) => void;
    className?: string;
}

/**
 * The Preview card's file search: a Fluent UI `SearchBox`. The filtering itself (names or paths that start with the
 * text, from `MIN_SEARCH_LENGTH` characters) is `visibleFiles` in `previewFiles.tsx`.
 */
export function FileSearchBox({ value, onChange, className }: IFileSearchBoxProps) {
    const styles = useFileSearchBoxStyles();
    return (
        <SearchBox
            className={mergeClasses(styles.root, className)}
            placeholder="Search files"
            aria-label="Search files"
            value={value}
            onChange={(_, data) => onChange(data.value)}
        />
    );
}
