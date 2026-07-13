import { makeStyles, tokens } from "@fluentui/react-components";

// Colors come from the resolved JsonTheme at runtime (see JsonFormatter.tsx), so the structural
// classes below reference CSS custom properties set inline on the root element instead of
// compile-time Fluent color tokens.
export const useJsonFormatterStyles = makeStyles({
    root: {
        position: "relative",
        display: "block",
        width: "100%",
        flex: "1 1 auto",
        minHeight: 0,
        boxSizing: "border-box",
        overflow: "auto",
        fontFamily: "monospace",
        fontSize: "11px",
        lineHeight: "1.6",
        backgroundColor: "var(--json-background)",
        color: "var(--json-text)",
        borderRadius: tokens.borderRadiusMedium,
        borderTopWidth: "1px",
        borderTopStyle: "solid",
        borderTopColor: "var(--json-border)",
        borderRightWidth: "1px",
        borderRightStyle: "solid",
        borderRightColor: "var(--json-border)",
        borderBottomWidth: "1px",
        borderBottomStyle: "solid",
        borderBottomColor: "var(--json-border)",
        borderLeftWidth: "1px",
        borderLeftStyle: "solid",
        borderLeftColor: "var(--json-border)",
        paddingTop: "8px",
        paddingBottom: "8px",
    },
    lineRow: {
        display: "flex",
        paddingLeft: "10px",
        paddingRight: "10px",
    },
    lineNumber: {
        flexShrink: 0,
        minWidth: "2.5em",
        textAlign: "right",
        marginRight: "10px",
        userSelect: "none",
        color: "var(--json-line-number)",
    },
    lineContent: {
        flex: "1 1 auto",
        // No wrapping and no min-width shrink: long lines keep their natural width, so `root`'s
        // `overflow: auto` produces a horizontal scrollbar instead of wrapping text to fit.
        whiteSpace: "pre",
    },
    text: { color: "var(--json-text)" },
    key: { color: "var(--json-key)" },
    string: { color: "var(--json-string)" },
    number: { color: "var(--json-number)" },
    boolean: { color: "var(--json-boolean)" },
    null: { color: "var(--json-null)" },
    punctuation: { color: "var(--json-punctuation)" },
    highlight: {
        backgroundColor: "var(--json-highlight)",
        color: "#1a1a1a",
        borderRadius: "2px",
    },
    placeholder: {
        display: "block",
        paddingLeft: "10px",
        paddingRight: "10px",
        color: "var(--json-placeholder)",
        fontStyle: "italic",
    },
    // Two nested `position: sticky` elements, rather than `position: absolute`, so the copy button
    // stays pinned to the visible top-right of `root`'s scrollport on both axes — see the matching
    // comment in `useXmlFormatterStyles.ts` for why `absolute` scrolls out of view here.
    cornerActionsAnchor: {
        position: "sticky",
        top: 0,
        height: 0,
        zIndex: 1,
        pointerEvents: "none",
    },
    cornerActions: {
        position: "sticky",
        right: "6px",
        marginTop: "6px",
        display: "flex",
        justifyContent: "flex-end",
        gap: "4px",
        pointerEvents: "auto",
    },
});
