import { makeStyles, shorthands, tokens } from '@fluentui/react-components';

/**
 * Styles for `Header`: a brand-tinted band with the app icon, title and version on the left, and the connection
 * pill and Settings button on the right.
 */
export const useHeaderStyles = makeStyles({
    header: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: tokens.spacingHorizontalL,
        flexWrap: 'wrap',
        padding: `${tokens.spacingVerticalL} ${tokens.spacingHorizontalXL}`,
        // A soft brand wash fading into the page background.
        backgroundImage: `linear-gradient(120deg, ${tokens.colorBrandBackground2} 0%, ${tokens.colorNeutralBackground1} 70%)`,
        borderBottom: `1px solid ${tokens.colorNeutralStroke2}`,
        boxShadow: tokens.shadow2,
    },
    identity: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalM, minWidth: 0 },
    appIcon: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        width: '44px',
        height: '44px',
        flexShrink: 0,
        borderRadius: tokens.borderRadiusXLarge,
        fontSize: '24px',
        color: tokens.colorNeutralForegroundOnBrand,
        backgroundImage: `linear-gradient(135deg, ${tokens.colorBrandBackground} 0%, ${tokens.colorPaletteTealForeground2} 100%)`,
        boxShadow: tokens.shadow8,
    },
    titleBlock: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalXXS, minWidth: 0 },
    titleRow: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flexWrap: 'wrap' },
    title: {
        margin: 0,
        fontSize: tokens.fontSizeBase500,
        fontWeight: tokens.fontWeightSemibold,
        lineHeight: tokens.lineHeightBase500,
        color: tokens.colorNeutralForeground1,
    },
    subtitle: { color: tokens.colorNeutralForeground3 },
    right: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS },

    // Connection pill
    connection: {
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
    },
    connectionDisconnected: { backgroundColor: tokens.colorPaletteYellowBackground1, ...shorthands.borderColor(tokens.colorPaletteYellowBorder1) },
    statusDot: { width: '8px', height: '8px', flexShrink: 0, borderRadius: tokens.borderRadiusCircular },
    statusDotConnected: { backgroundColor: tokens.colorPaletteGreenForeground1, boxShadow: `0 0 0 3px ${tokens.colorPaletteGreenBackground1}` },
    statusDotDisconnected: { backgroundColor: tokens.colorPaletteMarigoldForeground1 },
    connectionIcon: { fontSize: '16px', color: tokens.colorNeutralForeground3, flexShrink: 0 },
    connectionText: { display: 'flex', flexDirection: 'column', minWidth: 0, lineHeight: tokens.lineHeightBase200 },
    connectionLabel: { fontSize: tokens.fontSizeBase100, color: tokens.colorNeutralForeground3, textTransform: 'uppercase', letterSpacing: '0.04em' },
    connectionName: {
        fontSize: tokens.fontSizeBase200,
        fontWeight: tokens.fontWeightSemibold,
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        whiteSpace: 'nowrap',
    },
});
