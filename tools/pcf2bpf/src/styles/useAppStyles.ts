import { makeStyles } from "@fluentui/react-components";

export const useAppStyles = makeStyles({
    root: {
        display: "flex",
        flexDirection: "column",
        gap: "12px",
        height: "100%",
        minHeight: 0,
    },
    // Fills whatever vertical space is left between the TabList and the Footer, scrolling
    // internally so the Footer always sits flush at the bottom regardless of content length.
    contentArea: {
        flex: "1 1 auto",
        minHeight: 0,
        overflow: "auto",
    },
    configRow: {
        display: "flex",
        gap: "24px",
        alignItems: "flex-start",
    },
    leftColumn: {
        width: "420px",
        flexShrink: 0,
        display: "flex",
        flexDirection: "column",
        gap: "12px",
    },
    middleColumn: {
        flex: "1 1 auto",
        minWidth: 0,
    },
    rightColumn: {
        flex: "0 0 220px",
    },
    fullWidth: {
        width: "100%",
    },
    loadingOverlay: {
        position: "fixed",
        top: 0,
        right: 0,
        bottom: 0,
        left: 0,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: "rgba(211, 211, 211, 0.6)",
        zIndex: 1000,
    },
});
