import { makeStyles, tokens } from "@fluentui/react-components";

export const useCopyFormFactorPanelStyles = makeStyles({
    root: {
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
        borderRadius: tokens.borderRadiusMedium,
        padding: "12px",
        minWidth: "180px",
    },
    title: {
        marginBottom: "8px",
    },
    fieldSpacing: {
        marginTop: "8px",
    },
    copyButton: {
        marginTop: "12px",
        width: "100%",
    },
});
