import { makeStyles, tokens } from "@fluentui/react-components";

// The card frame (border/radius/padding/background) mirrors useBpfSelectorCardStyles'/
// useCopyFormFactorCardStyles'/usePcfConfigPanelStyles'/useStagesFieldsStyles' `root`, so this reads
// as the same kind of card as the rest of the config tab.
export const useSolutionsPublishersCardStyles = makeStyles({
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
    // Matches the other cards' `eyebrow`, so this title reads as the same kind of label as
    // "BUSINESS PROCESS FLOW".
    eyebrow: {
        display: "block",
        fontFamily: "monospace",
        fontSize: "10.5px",
        letterSpacing: "0.08em",
        textTransform: "uppercase",
        color: tokens.colorNeutralForeground3,
        marginBottom: "10px",
    },
    fieldSpacing: {
        marginTop: "8px",
    },
    loadBpfsButton: {
        marginTop: "12px",
        width: "100%",
    },
    optionContent: {
        display: "flex",
        flexDirection: "column",
        gap: "2px",
        paddingTop: "4px",
        paddingBottom: "4px",
    },
    optionName: {
        fontWeight: 600,
    },
    optionSecondary: {
        fontSize: "12px",
        color: tokens.colorNeutralForeground3,
    },
});
