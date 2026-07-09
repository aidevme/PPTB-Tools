import { makeStyles } from "@fluentui/react-components";

// The card frame and eyebrow heading live in `useGenericCardStyles`, applied via `GenericCard`.
export const useCopyFormFactorCardStyles = makeStyles({
    // Overrides `GenericCard`'s frame with a minimum width, so this card doesn't collapse when it's
    // the only content in `App.tsx`'s right column.
    minWidth: {
        minWidth: "180px",
    },
    fieldSpacing: {
        marginTop: "8px",
    },
    copyButton: {
        marginTop: "12px",
        width: "100%",
    },
    optionContent: {
        display: "flex",
        alignItems: "center",
        gap: "8px",
    },
});
