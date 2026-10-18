import { makeStyles, tokens } from '@fluentui/react-components';

/**
 * Styles for `Header`: a brand-tinted band with the app icon, title and version on the left, and the connection
 * pill (`ConnectionStatus`) and Settings button on the right.
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
});
