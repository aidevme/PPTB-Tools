import { makeStyles, tokens } from '@fluentui/react-components';

/**
 * Styles for `SettingsPanel`: a navigation column (search + vertical tabs with subtitles) beside the content, and
 * settings grouped into section cards whose rows put the title and description on the left and the control on the
 * right. Colours come from Fluent tokens, so both PPTB themes work.
 */
export const useSettingsPanelStyles = makeStyles({
    // Wider than Fluent's "medium" (592 px) so the navigation and right-aligned controls fit, but narrower than
    // "large" so rows aren't stretched across the screen.
    drawer: { width: 'min(780px, 100vw)' },
    headerTitle: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalM },
    headerIcon: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        width: '36px',
        height: '36px',
        flexShrink: 0,
        borderRadius: tokens.borderRadiusLarge,
        backgroundColor: tokens.colorBrandBackground2,
        color: tokens.colorBrandForeground2,
        fontSize: '20px',
    },
    headerText: { display: 'flex', flexDirection: 'column' },
    headerSubtitle: { color: tokens.colorNeutralForeground3 },

    body: { display: 'flex', gap: tokens.spacingHorizontalXL, alignItems: 'flex-start' },
    nav: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalM, width: '200px', flexShrink: 0, position: 'sticky', top: 0 },
    search: { width: '100%' },
    tabLabel: { display: 'flex', flexDirection: 'column', alignItems: 'flex-start', textAlign: 'start' },
    tabSubtitle: { color: tokens.colorNeutralForeground3, fontWeight: tokens.fontWeightRegular },

    content: {
        flexGrow: 1,
        minWidth: 0,
        maxWidth: '560px',
        display: 'flex',
        flexDirection: 'column',
        gap: tokens.spacingVerticalL,
        // A short fade-and-rise whenever the tab (or the search results) change; the element is re-keyed.
        animationName: { from: { opacity: 0, transform: 'translateY(4px)' }, to: { opacity: 1, transform: 'translateY(0)' } },
        animationDuration: tokens.durationNormal,
        animationTimingFunction: tokens.curveDecelerateMid,
        '@media (prefers-reduced-motion: reduce)': { animationName: 'none' },
    },
    intro: { color: tokens.colorNeutralForeground3 },
    resultsHeading: { color: tokens.colorNeutralForeground2 },
    empty: { color: tokens.colorNeutralForeground3, paddingBlock: tokens.spacingVerticalXXL, textAlign: 'center' },

    section: { padding: 0, gap: 0, overflow: 'hidden' },
    // Fluent cards outline themselves with a shadow, so the red accent is an inset stripe on the left edge.
    sectionDanger: { boxShadow: `inset 3px 0 0 ${tokens.colorPaletteRedBorder2}, ${tokens.shadow4}` },
    sectionHeader: {
        display: 'flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalS,
        flexWrap: 'wrap',
        padding: `${tokens.spacingVerticalM} ${tokens.spacingHorizontalL}`,
        borderBottom: `1px solid ${tokens.colorNeutralStroke2}`,
    },
    sectionIcon: { display: 'flex', fontSize: '18px', color: tokens.colorBrandForeground1 },
    sectionIconDanger: { color: tokens.colorPaletteRedForeground1 },
    sectionTitle: { flexGrow: 1 },
    sectionBadges: { display: 'flex', gap: tokens.spacingHorizontalXS, flexWrap: 'wrap' },
    sectionExtra: { padding: `${tokens.spacingVerticalS} ${tokens.spacingHorizontalL} ${tokens.spacingVerticalM}` },

    row: {
        display: 'flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalL,
        padding: `${tokens.spacingVerticalM} ${tokens.spacingHorizontalL}`,
        ':not(:last-child)': { borderBottom: `1px solid ${tokens.colorNeutralStroke3}` },
    },
    rowStacked: { flexDirection: 'column', alignItems: 'stretch', gap: tokens.spacingVerticalS },
    rowText: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalXXS, flexGrow: 1, minWidth: 0 },
    rowTitle: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalXS },
    rowDescription: { color: tokens.colorNeutralForeground3 },
    rowControl: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flexShrink: 0 },
    // Marks a value that differs from the saved one.
    changedDot: {
        width: '6px',
        height: '6px',
        borderRadius: tokens.borderRadiusCircular,
        backgroundColor: tokens.colorPaletteMarigoldForeground1,
        flexShrink: 0,
    },
    number: { width: '110px' },
    unit: { color: tokens.colorNeutralForeground3, minWidth: '56px' },
    warning: { marginTop: tokens.spacingVerticalS },

    // The Options tab's preview of what a project generates.
    preview: {
        margin: 0,
        padding: tokens.spacingVerticalS,
        borderRadius: tokens.borderRadiusMedium,
        backgroundColor: tokens.colorNeutralBackground3,
        fontFamily: tokens.fontFamilyMonospace,
        fontSize: tokens.fontSizeBase200,
        lineHeight: tokens.lineHeightBase300,
        overflowX: 'auto',
        whiteSpace: 'pre',
    },
    previewNote: { color: tokens.colorNeutralForeground3 },
    previewOff: { color: tokens.colorNeutralForegroundDisabled, textDecoration: 'line-through' },

    footer: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: tokens.spacingHorizontalM },
    footerStatus: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, color: tokens.colorNeutralForeground3 },
    footerStatusDirty: { color: tokens.colorPaletteMarigoldForeground1, fontWeight: tokens.fontWeightSemibold },
    footerActions: { display: 'flex', gap: tokens.spacingHorizontalS },
});
