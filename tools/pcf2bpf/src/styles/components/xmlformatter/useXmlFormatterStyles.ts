import { makeStyles, tokens } from "@fluentui/react-components";

// Colors come from the resolved XmlTheme at runtime (see XmlFormatter.tsx), so the structural
// classes below reference CSS custom properties set inline on the root element instead of
// compile-time Fluent color tokens.
export const useXmlFormatterStyles = makeStyles({
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
        backgroundColor: "var(--xml-background)",
        color: "var(--xml-text)",
        borderRadius: tokens.borderRadiusMedium,
        borderTopWidth: "1px",
        borderTopStyle: "solid",
        borderTopColor: "var(--xml-border)",
        borderRightWidth: "1px",
        borderRightStyle: "solid",
        borderRightColor: "var(--xml-border)",
        borderBottomWidth: "1px",
        borderBottomStyle: "solid",
        borderBottomColor: "var(--xml-border)",
        borderLeftWidth: "1px",
        borderLeftStyle: "solid",
        borderLeftColor: "var(--xml-border)",
        paddingTop: "8px",
        paddingBottom: "8px",
    },
    lineRow: {
        display: "flex",
        paddingLeft: "10px",
        paddingRight: "10px",
    },
    lineRowAdded: {
        backgroundColor: "var(--xml-diff-added)",
    },
    lineRowRemoved: {
        backgroundColor: "var(--xml-diff-removed)",
    },
    lineNumber: {
        flexShrink: 0,
        minWidth: "2.5em",
        textAlign: "right",
        marginRight: "10px",
        userSelect: "none",
        color: "var(--xml-line-number)",
    },
    chevron: {
        flexShrink: 0,
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        width: "16px",
        height: "16px",
        marginRight: "2px",
        padding: 0,
        border: "none",
        background: "none",
        cursor: "pointer",
        color: "var(--xml-punctuation)",
    },
    chevronPlaceholder: {
        flexShrink: 0,
        display: "inline-block",
        width: "18px",
    },
    lineContent: {
        flex: "1 1 auto",
        // No wrapping and no min-width shrink: long lines keep their natural width, so `root`'s
        // `overflow: auto` produces a horizontal scrollbar instead of wrapping text to fit.
        whiteSpace: "pre",
    },
    text: { color: "var(--xml-text)" },
    tag: { color: "var(--xml-tag)" },
    attrName: { color: "var(--xml-attr-name)" },
    attrValue: { color: "var(--xml-attr-value)" },
    comment: { color: "var(--xml-comment)", fontStyle: "italic" },
    punctuation: { color: "var(--xml-punctuation)" },
    highlight: {
        backgroundColor: "var(--xml-highlight)",
        color: "#1a1a1a",
        borderRadius: "2px",
    },
    placeholder: {
        display: "block",
        paddingLeft: "10px",
        paddingRight: "10px",
        color: "var(--xml-placeholder)",
        fontStyle: "italic",
    },
    // Two nested `position: sticky` elements, rather than the simpler `position: absolute`, so the
    // corner buttons stay pinned to the visible top-right of `root`'s scrollport on both axes —
    // `root` scrolls both horizontally (long XML lines) and vertically (many lines), and an
    // absolutely positioned child is anchored to root's full (unscrolled) content box, so it scrolls
    // out of view exactly like the surrounding text. The anchor is zero-height and non-interactive so
    // it doesn't take up layout space or block clicks on the content below it; only the inner flex
    // row (sized to its buttons) receives pointer events.
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
