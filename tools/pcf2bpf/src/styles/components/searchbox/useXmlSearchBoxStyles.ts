import { makeStyles } from "@fluentui/react-components";

export const useXmlSearchBoxStyles = makeStyles({
    root: {
        flexShrink: 0,
        maxWidth: "260px",
        // Fluent's horizontal Field defaults to a 33%/1fr label/control split, which is meant for
        // full-width forms. In this narrow toolbar that squeezes the "Search" label into a sliver,
        // wrapping it badly. Size the label column to its own content instead.
        gridTemplateColumns: "auto 1fr",
        // The label column can still be squeezed below the label's natural (icon + text) width,
        // which wraps the info icon onto its own line. Keep it on one line instead.
        "& .fui-Field__label": {
            whiteSpace: "nowrap",
        },
    },
});
