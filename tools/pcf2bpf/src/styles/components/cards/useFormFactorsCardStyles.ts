import { makeStyles, tokens } from "@fluentui/react-components";

// The card frame and eyebrow heading live in `useGenericCardStyles`, applied via `GenericCard`.
export const useFormFactorsCardStyles = makeStyles({
    // `GenericCard`'s children are plain block flow; this reproduces the panel's original
    // `display: flex; flexDirection: column; gap: 12px` root so the TabList/Field/param rows keep
    // their original spacing.
    content: {
        display: "flex",
        flexDirection: "column",
        gap: "12px",
    },
    tabLabel: {
        display: "flex",
        alignItems: "center",
        gap: "4px",
    },
    pcfSelectRow: {
        display: "flex",
        alignItems: "flex-end",
        gap: "4px",
    },
    pcfSelectField: {
        flexGrow: 1,
        minWidth: 0,
    },
    assignedIcon: {
        color: tokens.colorStatusSuccessForeground1,
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
