import { makeStyles, tokens } from "@fluentui/react-components";

export const useFooterStyles = makeStyles({
    // A normal flex child at the end of #root's column (see index.css / useAppStyles), not an
    // overlay: the contentArea above it fills+scrolls internally, so this always sits flush at
    // the bottom without needing position: fixed or reserved padding on its siblings.
    root: {
        flexShrink: 0,
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        gap: tokens.spacingHorizontalM,
        paddingTop: "6px",
        paddingBottom: "6px",
        paddingLeft: "12px",
        paddingRight: "12px",
        backgroundColor: tokens.colorNeutralBackground1,
        borderTopWidth: "1px",
        borderTopStyle: "solid",
        borderTopColor: tokens.colorNeutralStroke2,
    },
    text: {
        color: tokens.colorNeutralForeground3,
        fontSize: tokens.fontSizeBase200,
    },
    iconLink: {
        display: "inline-flex",
        alignItems: "center",
        gap: tokens.spacingHorizontalXS,
        color: tokens.colorNeutralForeground3,
        fontSize: tokens.fontSizeBase200,
        textDecorationLine: "none",
        ":hover": {
            color: tokens.colorBrandForeground1,
            textDecorationLine: "underline",
        },
    },
});
