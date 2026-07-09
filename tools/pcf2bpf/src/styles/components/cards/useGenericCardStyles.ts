import { makeStyles, tokens } from "@fluentui/react-components";

// The card frame (border/radius/padding/background) and eyebrow heading shared by every card in the
// config tab's columns (`BpfSelectorCard`, `CopyFormFactorCard`, `SolutionsPublishersCard`), via `GenericCard`.
export const useGenericCardStyles = makeStyles({
    root: {
        backgroundColor: tokens.colorNeutralBackground1,
        borderTopWidth: "1px",
        borderTopStyle: "solid",
        borderTopColor: tokens.colorNeutralStroke2,
        borderRightWidth: "1px",
        borderRightStyle: "solid",
        borderRightColor: tokens.colorNeutralStroke2,
        borderBottomWidth: "1px",
        borderBottomStyle: "solid",
        borderBottomColor: tokens.colorNeutralStroke2,
        borderLeftWidth: "1px",
        borderLeftStyle: "solid",
        borderLeftColor: tokens.colorNeutralStroke2,
        borderRadius: tokens.borderRadiusLarge,
        paddingTop: "18px",
        paddingBottom: "18px",
        paddingLeft: "18px",
        paddingRight: "18px",
    },
    headerBlock: {
        marginBottom: "10px",
    },
    titleRow: {
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        gap: "8px",
    },
    titleRowWithDescription: {
        marginBottom: "4px",
    },
    eyebrow: {
        display: "block",
        fontFamily: "monospace",
        fontSize: "10.5px",
        letterSpacing: "0.08em",
        textTransform: "uppercase",
        color: tokens.colorNeutralForeground3,
    },
    description: {
        color: tokens.colorNeutralForeground3,
    },
    moreButton: {
        minWidth: "auto",
        flexShrink: 0,
    },
});
