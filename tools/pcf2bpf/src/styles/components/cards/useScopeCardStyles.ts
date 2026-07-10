import { makeStyles, tokens } from "@fluentui/react-components";

// The card frame and eyebrow heading live in `useGenericCardStyles`, applied via `GenericCard`.
export const useScopeCardStyles = makeStyles({
    loadBpfsButton: {
        marginTop: "12px",
        width: "100%",
    },
    filterModeRadioGroup: {
        marginBottom: "12px",
    },
    optionContent: {
        display: "flex",
        flexDirection: "column",
        gap: "2px",
        paddingTop: "4px",
        paddingBottom: "4px",
    },
    optionName: {
        fontWeight: tokens.fontWeightRegular,
    },
    optionSecondary: {
        fontSize: "12px",
        color: tokens.colorNeutralForeground3,
    },
});
