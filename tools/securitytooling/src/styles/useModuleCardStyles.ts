import { makeStyles, tokens } from "@fluentui/react-components";

export const useModuleCardStyles = makeStyles({
    card: {
        display: "flex",
        flexDirection: "column",
        gap: tokens.spacingVerticalXS,
        backgroundColor: "var(--card-bg)",
        border: "1px solid var(--card-border)",
        borderRadius: tokens.borderRadiusLarge,
        padding: tokens.spacingHorizontalL,
        transitionProperty: "transform, box-shadow, border",
        transitionDuration: tokens.durationNormal,
        transitionTimingFunction: tokens.curveEasyEase,
        ":hover": {
            transform: "translateY(-4px)",
            border: "1px solid var(--accent)",
            boxShadow: "0 16px 36px -6px var(--accent)",
        },
    },
    topRow: {
        display: "flex",
        alignItems: "flex-start",
        justifyContent: "space-between",
        marginBottom: tokens.spacingVerticalXS,
    },
    iconBadge: {
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        width: "40px",
        height: "40px",
        borderRadius: tokens.borderRadiusMedium,
        backgroundColor: "var(--card-icon-bg)",
        color: "var(--accent)",
        fontSize: "20px",
    },
    tag: {
        fontFamily: tokens.fontFamilyMonospace,
        fontSize: tokens.fontSizeBase200,
        fontWeight: tokens.fontWeightSemibold,
        letterSpacing: "0.05em",
        textTransform: "uppercase",
        color: "var(--accent)",
    },
    eyebrow: {
        fontFamily: tokens.fontFamilyMonospace,
        fontSize: tokens.fontSizeBase200,
        fontWeight: tokens.fontWeightSemibold,
        letterSpacing: "0.08em",
        textTransform: "uppercase",
        color: "var(--accent)",
    },
    title: {
        color: "var(--card-title)",
        fontSize: tokens.fontSizeBase500,
        fontWeight: tokens.fontWeightSemibold,
    },
    description: {
        color: "var(--card-description)",
        fontSize: tokens.fontSizeBase300,
        lineHeight: tokens.lineHeightBase300,
        // CardPreview strips the card's own horizontal padding to allow edge-to-edge media, so
        // this restores it for the text content actually rendered inside it.
        paddingLeft: tokens.spacingHorizontalL,
        paddingRight: tokens.spacingHorizontalL,
    },
    launchLink: {
        fontFamily: tokens.fontFamilyMonospace,
        fontWeight: tokens.fontWeightSemibold,
        fontSize: tokens.fontSizeBase200,
        letterSpacing: "0.04em",
        textTransform: "uppercase",
        color: "var(--accent)",
        marginTop: tokens.spacingVerticalS,
    },
    path: {
        fontFamily: tokens.fontFamilyMonospace,
        fontSize: tokens.fontSizeBase100,
        color: "var(--card-path)",
        wordBreak: "break-all",
    },
});
