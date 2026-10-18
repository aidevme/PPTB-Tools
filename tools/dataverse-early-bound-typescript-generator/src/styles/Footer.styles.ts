import { makeStyles, shorthands, tokens } from '@fluentui/react-components';

/**
 * Styles for `Footer`: a brand-tinted band (the header's gradient, mirrored) with the tool's identity on the left,
 * credits and a reminder in the middle, and documentation and repository links on the right.
 */
export const useFooterStyles = makeStyles({
    footer: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: `${tokens.spacingVerticalM} ${tokens.spacingHorizontalXL}`,
        flexWrap: 'wrap',
        padding: `${tokens.spacingVerticalL} ${tokens.spacingHorizontalXL}`,
        backgroundImage: `linear-gradient(300deg, ${tokens.colorBrandBackground2} 0%, ${tokens.colorNeutralBackground1} 65%)`,
        borderTop: `1px solid ${tokens.colorNeutralStroke2}`,
        boxShadow: `0 -1px 2px ${tokens.colorNeutralShadowAmbient}`,
    },

    // Identity
    identity: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flexShrink: 0 },
    identityText: { display: 'flex', flexDirection: 'column', lineHeight: tokens.lineHeightBase200 },
    toolName: { fontSize: tokens.fontSizeBase200, fontWeight: tokens.fontWeightSemibold, color: tokens.colorNeutralForeground1 },
    toolMeta: { fontSize: tokens.fontSizeBase100, color: tokens.colorNeutralForeground3 },

    // Credits and reminder
    middle: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalXS, flex: '1 1 380px', minWidth: 0 },
    credits: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flexWrap: 'wrap', color: tokens.colorNeutralForeground2 },
    creditChip: {
        display: 'inline-flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalXS,
        padding: `${tokens.spacingVerticalXXS} ${tokens.spacingHorizontalS}`,
        borderRadius: tokens.borderRadiusCircular,
        backgroundColor: tokens.colorNeutralBackground1,
        ...shorthands.border('1px', 'solid', tokens.colorNeutralStroke2),
        textDecorationLine: 'none',
        fontSize: tokens.fontSizeBase200,
        fontWeight: tokens.fontWeightSemibold,
        ':hover': { textDecorationLine: 'none', backgroundColor: tokens.colorNeutralBackground1Hover, ...shorthands.borderColor(tokens.colorBrandStroke2) },
    },
    license: {
        fontSize: tokens.fontSizeBase100,
        fontWeight: tokens.fontWeightRegular,
        color: tokens.colorNeutralForeground3,
        textTransform: 'uppercase',
        letterSpacing: '0.04em',
    },
    reminder: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalXS, color: tokens.colorNeutralForeground3, fontSize: tokens.fontSizeBase200 },
    reminderIcon: { flexShrink: 0, fontSize: '14px' },

    // Links
    links: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalXS, flexShrink: 0 },
    externalIcon: { fontSize: '12px', marginLeft: tokens.spacingHorizontalXXS, color: tokens.colorNeutralForeground3 },
});
