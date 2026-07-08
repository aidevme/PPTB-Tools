import { makeStyles, tokens } from "@fluentui/react-components";

export const useFormXmlPanelStyles = makeStyles({
    root: {
        display: "flex",
        flexDirection: "column",
        gap: "12px",
        width: "100%",
        height: "100%",
        minHeight: 0,
    },
    toolbar: {
        display: "flex",
        alignItems: "center",
        flexWrap: "wrap",
        gap: "12px",
        flexShrink: 0,
    },
    columnsRow: {
        display: "flex",
        gap: "16px",
        width: "100%",
        flex: "1 1 auto",
        minHeight: 0,
    },
    column: {
        flex: "1 1 50%",
        minWidth: 0,
        display: "flex",
        flexDirection: "column",
        minHeight: 0,
    },
    label: {
        flexShrink: 0,
    },
    description: {
        marginBottom: "6px",
        color: tokens.colorNeutralForeground3,
        flexShrink: 0,
    },
});
