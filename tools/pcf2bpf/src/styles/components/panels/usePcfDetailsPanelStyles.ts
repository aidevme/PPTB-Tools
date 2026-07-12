import { makeStyles, tokens } from "@fluentui/react-components";

export const usePcfDetailsPanelStyles = makeStyles({
    body: {
        display: "flex",
        flexDirection: "column",
        gap: "12px",
    },
    row: {
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        gap: "12px",
        paddingTop: "8px",
        paddingBottom: "8px",
        borderTopWidth: "1px",
        borderTopStyle: "solid",
        borderTopColor: tokens.colorNeutralStroke2,
        fontSize: "13px",
    },
    parametersLabel: {
        marginTop: "8px",
        marginBottom: "-4px",
    },
    rawTextarea: {
        width: "100%",
    },
    rawTextareaField: {
        fontFamily: tokens.fontFamilyMonospace,
        fontSize: "12px",
        minHeight: "160px",
    },
});
