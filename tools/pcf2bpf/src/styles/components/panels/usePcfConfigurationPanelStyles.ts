import { makeStyles } from "@fluentui/react-components";

export const usePcfConfigurationPanelStyles = makeStyles({
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
});
