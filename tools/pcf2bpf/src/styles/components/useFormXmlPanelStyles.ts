import { makeStyles } from "@fluentui/react-components";

export const useFormXmlPanelStyles = makeStyles({
    root: {
        display: "flex",
        gap: "16px",
        width: "100%",
        height: "100%",
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
        marginBottom: "4px",
        flexShrink: 0,
    },
});
