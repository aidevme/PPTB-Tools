import { makeStyles, tokens } from "@fluentui/react-components";

export const usePcfDetailsPanelStyles = makeStyles({
    body: {
        display: "flex",
        flexDirection: "column",
        gap: "16px",
    },
    mono: {
        fontFamily: tokens.fontFamilyMonospace,
    },

    // Title block
    titleBlock: {
        display: "flex",
        flexDirection: "column",
        gap: "2px",
    },
    eyebrow: {
        color: tokens.colorBrandForeground1,
        textTransform: "uppercase",
        letterSpacing: "0.04em",
    },
    badgeRow: {
        display: "flex",
        gap: "8px",
        marginTop: "6px",
    },

    // Hero row
    heroRow: {
        display: "grid",
        gridTemplateColumns: "1.3fr 1fr",
        gap: "12px",
    },
    heroCard: {
        minWidth: 0,
    },
    factsGrid: {
        display: "grid",
        gridTemplateColumns: "1fr 1fr",
        gap: "12px 16px",
    },
    factLabel: {
        color: tokens.colorNeutralForeground3,
        textTransform: "uppercase",
        letterSpacing: "0.04em",
        marginBottom: "2px",
    },

    tableHeaderCell: {
        fontWeight: tokens.fontWeightSemibold,
    },

    // Properties tab toolbar
    toolbar: {
        display: "flex",
        alignItems: "center",
        gap: "10px",
        flexWrap: "wrap",
    },
    search: {
        flex: "1 1 auto",
        minWidth: "200px",
    },
    filterRow: {
        display: "flex",
        gap: "6px",
    },
    typeTag: {
        display: "inline-flex",
        alignItems: "center",
        gap: "6px",
    },
    typeSwatch: {
        width: "8px",
        height: "8px",
        borderRadius: "2px",
        flexShrink: 0,
    },
    requiredYes: {
        color: tokens.colorPaletteGreenForeground1,
    },
    requiredNo: {
        color: tokens.colorNeutralForeground3,
    },
    typeGroupPopover: {
        display: "flex",
        flexDirection: "column",
        gap: "4px",
        maxWidth: "320px",
    },

    // Resources tab
    resourceGrid: {
        display: "grid",
        gridTemplateColumns: "1fr 1fr",
        gap: "12px",
    },
    listRow: {
        display: "flex",
        alignItems: "center",
        gap: "12px",
        padding: "10px 0",
        borderBottomWidth: "1px",
        borderBottomStyle: "solid",
        borderBottomColor: tokens.colorNeutralStroke2,
        ":last-child": {
            borderBottomStyle: "none",
        },
    },
    listIcon: {
        width: "30px",
        height: "30px",
        borderRadius: tokens.borderRadiusMedium,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flexShrink: 0,
        fontSize: "10px",
        fontWeight: 700,
        color: tokens.colorNeutralForegroundOnBrand,
        backgroundColor: tokens.colorBrandBackground,
    },
    listTitle: {
        fontSize: "13px",
        fontWeight: 600,
    },
    listSub: {
        fontSize: "11.5px",
        color: tokens.colorNeutralForeground3,
        fontFamily: tokens.fontFamilyMonospace,
    },
    sectionTitle: {
        marginTop: "18px",
        marginBottom: "4px",
    },

    // Feature usage tab
    chipCloud: {
        display: "flex",
        flexWrap: "wrap",
        gap: "8px",
    },
    featureChip: {
        display: "flex",
        alignItems: "center",
        gap: "8px",
        padding: "6px 10px",
        borderRadius: tokens.borderRadiusMedium,
        border: `1px solid ${tokens.colorNeutralStroke2}`,
        backgroundColor: tokens.colorNeutralBackground2,
        fontSize: "12.5px",
        fontWeight: 600,
    },
});
