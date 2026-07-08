import { makeStyles, tokens } from "@fluentui/react-components";

export const usePanelHeaderStyles = makeStyles({
    root: {
        display: "flex",
        flexDirection: "column",
        gap: "2px",
    },
    titleRow: {
        display: "flex",
        alignItems: "center",
        justifyContent: "flex-start",
        gap: "8px",
    },
    icon: {
        flexShrink: 0,
        alignSelf: "center",
        display: "block",
        fontSize: "20px",
        height: "20px",
        width: "20px",
    },
    title: {
        flexShrink: 0,
        // Match the 20px icon's box height so flex centering aligns them exactly, instead of
        // centering the icon against the text's taller line-box (which has extra leading above/
        // below the glyphs and would leave the icon looking off-center relative to the letters).
        lineHeight: "20px",
    },
    description: {
        color: tokens.colorNeutralForeground3,
    },
    success: { color: tokens.colorStatusSuccessForeground1 },
    info: { color: tokens.colorBrandForeground1 },
    warning: { color: tokens.colorStatusWarningForeground1 },
    error: { color: tokens.colorStatusDangerForeground1 },
});
