import { makeStyles, tokens } from "@fluentui/react-components";

export const usePcfConfiguratorTableStyles = makeStyles({
    tableHeaderCell: {
        fontWeight: tokens.fontWeightSemibold,
    },
    usageCell: {
        display: "flex",
        alignItems: "center",
        gap: "4px",
    },
    colName: {
        flexGrow: 1,
        flexBasis: "160px",
        minWidth: 0,
    },
    colUsage: {
        flexGrow: 0,
        flexShrink: 0,
        width: "100px",
    },
    colRequired: {
        flexGrow: 0,
        flexShrink: 0,
        width: "60px",
    },
    colType: {
        flexGrow: 0,
        flexShrink: 0,
        width: "110px",
    },
    colIsStatic: {
        flexGrow: 0,
        flexShrink: 0,
        width: "70px",
    },
    colValue: {
        flexGrow: 1.5,
        flexBasis: "200px",
        minWidth: 0,
    },
    valueControl: {
        width: "100%",
        minWidth: 0,
    },
});
