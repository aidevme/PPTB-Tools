import { makeStyles, tokens } from "@fluentui/react-components";

// The card frame (border/radius/padding/background) mirrors useFieldPropertiesPanelStyles' and
// usePcfConfigPanelStyles' `root`, so all three panels in App.tsx's config tab read as a matching set.
export const useCopyFormFactorCardStyles = makeStyles({
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
        minWidth: "180px",
    },
    // Matches useFieldPropertiesPanelStyles' `eyebrow` / usePcfConfigPanelStyles' `eyebrow`, so this
    // title reads as the same kind of label as "FIELD PROPERTIES" in the card above it.
    title: {
        display: "block",
        fontFamily: "monospace",
        fontSize: "10.5px",
        letterSpacing: "0.08em",
        textTransform: "uppercase",
        color: tokens.colorNeutralForeground3,
        marginBottom: "8px",
    },
    fieldSpacing: {
        marginTop: "8px",
    },
    copyButton: {
        marginTop: "12px",
        width: "100%",
    },
    optionContent: {
        display: "flex",
        alignItems: "center",
        gap: "8px",
    },
});
