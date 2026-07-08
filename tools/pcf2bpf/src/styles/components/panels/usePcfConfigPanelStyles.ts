import { makeStyles, tokens } from "@fluentui/react-components";

// Mirrors useFieldPropertiesPanelStyles' `root` card frame so the two panels stacked in App.tsx's
// middle column read as a matching pair.
export const usePcfConfigPanelStyles = makeStyles({
    root: {
        display: "flex",
        flexDirection: "column",
        gap: "12px",
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
    // Matches useFieldPropertiesPanelStyles' `eyebrow`, so the "Form Factors for ..." heading reads
    // as the same kind of label as "FIELD PROPERTIES" in the card above it.
    eyebrow: {
        display: "block",
        fontFamily: "monospace",
        fontSize: "10.5px",
        letterSpacing: "0.08em",
        textTransform: "uppercase",
        color: tokens.colorNeutralForeground3,
    },
    tabLabel: {
        display: "flex",
        alignItems: "center",
        gap: "4px",
    },
    assignedIcon: {
        color: tokens.colorStatusSuccessForeground1,
    },
});
