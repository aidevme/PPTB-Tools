import { makeStyles, shorthands, tokens } from '@fluentui/react-components';

/** Styles for `CustomTemplatesPopover`: the button's count badge, the popover surface, its header, the tiles and the footer. */
export const useCustomTemplatesPopoverStyles = makeStyles({
    count: { marginLeft: tokens.spacingHorizontalXS },
    surface: { borderRadius: tokens.borderRadiusXLarge, boxShadow: tokens.shadow16, padding: tokens.spacingHorizontalL },
    body: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalM, width: '380px', maxWidth: 'calc(100vw - 48px)' },
    header: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS },
    headerIcon: {
        display: 'inline-flex',
        padding: tokens.spacingHorizontalXS,
        borderRadius: tokens.borderRadiusMedium,
        backgroundColor: tokens.colorBrandBackground2,
        color: tokens.colorBrandForeground1,
        fontSize: '20px',
    },
    title: { flexGrow: 1 },
    list: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalXS },
    tile: {
        display: 'flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalS,
        padding: `${tokens.spacingVerticalXXS} ${tokens.spacingHorizontalM}`,
        borderRadius: tokens.borderRadiusLarge,
        backgroundColor: tokens.colorNeutralBackground1,
        ...shorthands.border('1px', 'solid', tokens.colorNeutralStroke2),
        cursor: 'pointer',
        transitionProperty: 'background-color, border-color',
        transitionDuration: tokens.durationFaster,
        ':hover': { backgroundColor: tokens.colorNeutralBackground1Hover },
        '@media (prefers-reduced-motion: reduce)': { transitionDuration: '0.01ms' },
    },
    tileSelected: {
        backgroundColor: tokens.colorBrandBackground2,
        ...shorthands.borderColor(tokens.colorBrandStroke1),
        ':hover': { backgroundColor: tokens.colorBrandBackground2Hover },
    },
    tileIcon: { display: 'inline-flex', fontSize: '20px', color: tokens.colorBrandForeground1 },
    tileText: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: tokens.spacingHorizontalS, flexGrow: 1, minWidth: 0 },
    location: { color: tokens.colorNeutralForeground3, fontFamily: tokens.fontFamilyMonospace, whiteSpace: 'nowrap' },
    actions: { display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: tokens.spacingHorizontalS },
    muted: { color: tokens.colorNeutralForeground3 },
});
