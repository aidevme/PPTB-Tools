import { makeStyles, tokens } from "@fluentui/react-components";

// The card frame (border/radius/padding/background) mirrors useCopyFormFactorCardStyles' and
// usePcfConfigPanelStyles' `root`, so this reads as the same kind of card as the rest of the config tab.
export const useBpfSelectorCardStyles = makeStyles({
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
    // Matches useCopyFormFactorCardStyles'/usePcfConfigPanelStyles' `eyebrow`, so this label reads
    // as the same kind of title as "COPY PCF BETWEEN FORM FACTORS".
    eyebrow: {
        display: "block",
        fontFamily: "monospace",
        fontSize: "10.5px",
        letterSpacing: "0.08em",
        textTransform: "uppercase",
        color: tokens.colorNeutralForeground3,
    },
    fullWidth: {
        width: "100%",
    },
});
