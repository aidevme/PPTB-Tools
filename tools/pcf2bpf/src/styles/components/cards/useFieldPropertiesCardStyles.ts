import { makeStyles, tokens } from "@fluentui/react-components";

// The card frame and eyebrow heading live in `useGenericCardStyles`, applied via `GenericCard`.
export const useFieldPropertiesCardStyles = makeStyles({
    // `App.tsx`'s middle column stacks this card directly above `FormFactorsCard` with plain block
    // flow (no flex gap), so this card supplies its own spacing below it.
    spacing: {
        marginBottom: "12px",
    },
    stageBadge: {
        display: "inline-block",
        fontSize: "11px",
        fontWeight: 600,
        color: "#ffffff",
        backgroundColor: "var(--stage-color)",
        paddingTop: "3px",
        paddingBottom: "3px",
        paddingLeft: "10px",
        paddingRight: "10px",
        borderRadius: "20px",
        marginBottom: "14px",
    },
    fieldName: {
        display: "block",
        fontSize: "18px",
        fontWeight: 700,
        marginBottom: "2px",
    },
    fieldLogical: {
        display: "block",
        fontFamily: "monospace",
        fontSize: "12px",
        color: tokens.colorNeutralForeground3,
        marginBottom: "14px",
        wordBreak: "break-all",
    },
    row: {
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        gap: "12px",
        paddingTop: "10px",
        paddingBottom: "10px",
        borderTopWidth: "1px",
        borderTopStyle: "solid",
        borderTopColor: tokens.colorNeutralStroke2,
        fontSize: "13px",
    },
    firstRow: {
        borderTopWidth: 0,
        borderTopStyle: "none",
    },
    rowLabel: {
        color: tokens.colorNeutralForeground3,
        flexShrink: 0,
    },
    rowValue: {
        fontWeight: 500,
        textAlign: "right",
    },
});
