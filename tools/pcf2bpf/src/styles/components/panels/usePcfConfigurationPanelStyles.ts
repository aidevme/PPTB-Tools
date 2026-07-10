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
    // Holds the top row (field properties + copy-form-factor side by side) and, below it,
    // FormFactorsCard spanning their combined width — so the param table gets the full width
    // instead of being squeezed into just the field-properties column.
    rightArea: {
        flex: "1 1 auto",
        minWidth: 0,
        display: "flex",
        flexDirection: "column",
        gap: "12px",
    },
    topRow: {
        display: "flex",
        gap: "24px",
        alignItems: "flex-start",
    },
    fieldPropertiesColumn: {
        flex: "1 1 auto",
        minWidth: 0,
    },
    copyColumn: {
        flex: "0 0 220px",
    },
    fullWidth: {
        width: "100%",
    },
});
