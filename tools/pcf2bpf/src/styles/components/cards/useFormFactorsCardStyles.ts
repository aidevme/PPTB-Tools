import { makeStyles, tokens } from "@fluentui/react-components";

// The card frame and eyebrow heading live in `useGenericCardStyles`, applied via `GenericCard`.
export const useFormFactorsCardStyles = makeStyles({
    // `GenericCard`'s children are plain block flow; this reproduces the panel's original
    // `display: flex; flexDirection: column; gap: 12px` root so the TabList/Field/param rows keep
    // their original spacing.
    content: {
        display: "flex",
        flexDirection: "column",
        gap: "12px",
    },
    tabLabel: {
        display: "flex",
        alignItems: "center",
        gap: "4px",
    },
    assignedIcon: {
        color: tokens.colorStatusSuccessForeground1,
    },
});
