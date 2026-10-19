import { makeStyles, shorthands, tokens } from '@fluentui/react-components';

/**
 * Styles for `PreviewCard`: the action bar, the status tiles, the file table beside the viewer, and the
 * resizable divider between them.
 */
export const usePreviewCardStyles = makeStyles({
    body: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalM },
    actionBar: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flexWrap: 'wrap' },
    muted: { color: tokens.colorNeutralForeground3 },
    hint: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalXS, color: tokens.colorNeutralForeground3 },

    // Summary and status tiles
    summary: { fontSize: tokens.fontSizeBase300, color: tokens.colorNeutralForeground1 },
    tiles: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: tokens.spacingHorizontalS },
    tile: {
        display: 'flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalM,
        padding: `${tokens.spacingVerticalS} ${tokens.spacingHorizontalM}`,
        borderRadius: tokens.borderRadiusLarge,
        backgroundColor: tokens.colorNeutralBackground1,
        ...shorthands.border('1px', 'solid', tokens.colorNeutralStroke2),
        borderLeftWidth: '4px',
        boxShadow: tokens.shadow2,
        cursor: 'pointer',
        textAlign: 'left',
        fontFamily: 'inherit',
        color: tokens.colorNeutralForeground1,
        transitionProperty: 'box-shadow, border-color, background-color',
        transitionDuration: tokens.durationFaster,
        ':hover': { boxShadow: tokens.shadow8, backgroundColor: tokens.colorNeutralBackground1Hover },
        ':focus-visible': { outline: `${tokens.strokeWidthThick} solid ${tokens.colorStrokeFocus2}` },
        '@media (prefers-reduced-motion: reduce)': { transitionDuration: '0.01ms' },
    },
    tileSelected: { backgroundColor: tokens.colorBrandBackground2, ...shorthands.borderColor(tokens.colorBrandStroke1), boxShadow: tokens.shadow8 },
    tileIcon: { fontSize: '24px', flexShrink: 0 },
    tileText: { display: 'flex', flexDirection: 'column', lineHeight: tokens.lineHeightBase200 },
    tileCount: { fontSize: tokens.fontSizeHero700, fontWeight: tokens.fontWeightSemibold, lineHeight: tokens.lineHeightHero700 },
    tileLabel: { fontSize: tokens.fontSizeBase200, color: tokens.colorNeutralForeground2 },
    accentNew: { borderLeftColor: tokens.colorPaletteGreenBorder2, color: tokens.colorPaletteGreenForeground1 },
    accentChanged: { borderLeftColor: tokens.colorPaletteMarigoldBorder2, color: tokens.colorPaletteMarigoldForeground1 },
    accentUnchanged: { borderLeftColor: tokens.colorNeutralStroke1, color: tokens.colorNeutralForeground3 },
    accentOrphaned: { borderLeftColor: tokens.colorPaletteRedBorder2, color: tokens.colorPaletteRedForeground1 },
    accentDuplicate: { borderLeftColor: tokens.colorPaletteDarkOrangeBorder2, color: tokens.colorPaletteDarkOrangeForeground1 },

    // Output folder
    outputRow: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalXS, minWidth: 0, flexWrap: 'wrap' },

    // Table filters
    filterBar: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalM, flexWrap: 'wrap' },

    // Table and viewer
    split: { display: 'flex', alignItems: 'stretch', minHeight: '360px', height: '540px' },
    panel: {
        minWidth: 0,
        overflow: 'auto',
        borderRadius: tokens.borderRadiusLarge,
        ...shorthands.border('1px', 'solid', tokens.colorNeutralStroke2),
        backgroundColor: tokens.colorNeutralBackground1,
        boxShadow: tokens.shadow2,
    },
    list: { flexShrink: 0 },
    viewer: { flexGrow: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' },
    splitter: {
        flex: '0 0 12px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: 'col-resize',
        touchAction: 'none',
        '::after': { content: '""', width: '4px', height: '40px', borderRadius: tokens.borderRadiusCircular, backgroundColor: tokens.colorNeutralStroke1 },
        ':hover::after': { backgroundColor: tokens.colorBrandStroke1 },
        ':focus-visible': { outline: `${tokens.strokeWidthThick} solid ${tokens.colorStrokeFocus2}`, borderRadius: tokens.borderRadiusMedium },
    },
    placeholder: { color: tokens.colorNeutralForeground3, padding: tokens.spacingVerticalXXL, textAlign: 'center' },
    skeleton: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalS, padding: tokens.spacingHorizontalM },
});
