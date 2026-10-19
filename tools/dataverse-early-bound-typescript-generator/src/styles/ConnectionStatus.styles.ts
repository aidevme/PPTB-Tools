import { makeStyles, shorthands, tokens } from '@fluentui/react-components';

/** Styles for `ConnectionStatus`: the pill, its status dot, icon and two lines of text. */
export const useConnectionStatusStyles = makeStyles({
    pill: {
        display: 'flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalS,
        padding: `${tokens.spacingVerticalXS} ${tokens.spacingHorizontalM}`,
        borderRadius: tokens.borderRadiusCircular,
        backgroundColor: tokens.colorNeutralBackground1,
        ...shorthands.border('1px', 'solid', tokens.colorNeutralStroke2),
        boxShadow: tokens.shadow2,
        maxWidth: '320px',
        minWidth: 0,
        ':focus-visible': { outline: `${tokens.strokeWidthThick} solid ${tokens.colorStrokeFocus2}`, outlineOffset: '2px' },
    },
    pillDisconnected: { backgroundColor: tokens.colorPaletteYellowBackground1, ...shorthands.borderColor(tokens.colorPaletteYellowBorder1) },
    dot: { width: '8px', height: '8px', flexShrink: 0, borderRadius: tokens.borderRadiusCircular },
    dotConnected: { backgroundColor: tokens.colorPaletteGreenForeground1, boxShadow: `0 0 0 3px ${tokens.colorPaletteGreenBackground1}` },
    dotDisconnected: { backgroundColor: tokens.colorPaletteMarigoldForeground1 },
    icon: { fontSize: '16px', color: tokens.colorNeutralForeground3, flexShrink: 0 },
    text: { display: 'flex', flexDirection: 'column', minWidth: 0, lineHeight: tokens.lineHeightBase200 },
    label: { fontSize: tokens.fontSizeBase100, color: tokens.colorNeutralForeground3, textTransform: 'uppercase', letterSpacing: '0.04em' },
    name: {
        fontSize: tokens.fontSizeBase200,
        fontWeight: tokens.fontWeightSemibold,
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        whiteSpace: 'nowrap',
    },
});
