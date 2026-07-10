import { makeStyles } from "@fluentui/react-components";

export const useDebuggerPanelStyles = makeStyles({
    body: {
        display: "flex",
        flexDirection: "column",
        gap: "12px",
    },
    entityLabel: {
        marginBottom: "-4px",
    },
    pagingRow: {
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        marginTop: "4px",
    },
    pagingControls: {
        display: "flex",
        alignItems: "center",
        gap: "8px",
    },
});
