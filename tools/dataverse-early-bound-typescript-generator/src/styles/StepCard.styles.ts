import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `StepCard`: the card frame, the accent on the active step, and the step indicator. */
export const useStepCardStyles = makeStyles({
    card: {
        padding: tokens.spacingHorizontalL,
        gap: tokens.spacingVerticalM,
        boxShadow: tokens.shadow4,
        borderLeft: `${tokens.strokeWidthThick} solid transparent`,
        transitionProperty: 'border-color, box-shadow',
        transitionDuration: tokens.durationNormal,
        '@media (prefers-reduced-motion: reduce)': { transitionDuration: '0.01ms' },
    },
    // The step to work on next gets a brand accent on its left edge and a slightly stronger shadow.
    active: { borderLeftColor: tokens.colorBrandStroke1, boxShadow: tokens.shadow8 },
    header: {
        paddingBottom: tokens.spacingVerticalS,
        borderBottom: `1px solid ${tokens.colorNeutralStroke3}`,
    },
    indicator: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        width: '32px',
        height: '32px',
        borderRadius: tokens.borderRadiusCircular,
        fontWeight: tokens.fontWeightSemibold,
        fontSize: tokens.fontSizeBase300,
        backgroundColor: tokens.colorNeutralBackground3,
        color: tokens.colorNeutralForeground2,
        border: `1px solid ${tokens.colorNeutralStroke2}`,
        flexShrink: 0,
    },
    indicatorActive: {
        backgroundColor: tokens.colorBrandBackground,
        color: tokens.colorNeutralForegroundOnBrand,
        border: `1px solid ${tokens.colorBrandBackground}`,
    },
    indicatorComplete: {
        backgroundColor: tokens.colorPaletteGreenBackground3,
        color: tokens.colorNeutralForegroundOnBrand,
        border: `1px solid ${tokens.colorPaletteGreenBackground3}`,
    },
    // Keeps the status on one line; CardHeader's action slot otherwise squeezes it.
    status: { whiteSpace: 'nowrap', flexShrink: 0 },
    title: { margin: 0, fontWeight: tokens.fontWeightSemibold, fontSize: tokens.fontSizeBase400 },
});
