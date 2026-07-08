import { makeStyles } from "@fluentui/react-components";

export const useCompareXmlsCheckBoxStyles = makeStyles({
    root: {
        flexShrink: 0,
        // See useXmlSearchBoxStyles: override Fluent's 33%/1fr horizontal Field split so the
        // "Show differences" label sizes to its own content instead of wrapping when squeezed.
        gridTemplateColumns: "auto auto",
        // Extra breathing room so the label doesn't crowd the search box next to it.
        marginLeft: "16px",
    },
});
