import { makeStyles, shorthands, tokens } from '@fluentui/react-components';

const fadeIn = {
    animationName: { from: { opacity: 0, transform: 'translateY(4px)' }, to: { opacity: 1, transform: 'translateY(0)' } },
    animationDuration: tokens.durationNormal,
    animationTimingFunction: tokens.curveDecelerateMid,
    '@media (prefers-reduced-motion: reduce)': { animationName: 'none' },
};

/** Styles for `ProjectCard`: the empty state, the recent-projects list, and the open-project summary. */
export const useProjectCardStyles = makeStyles({
    body: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalM },
    row: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flexWrap: 'wrap' },

    // Empty state
    empty: {
        display: 'flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalXL,
        padding: tokens.spacingHorizontalXL,
        borderRadius: tokens.borderRadiusLarge,
        backgroundColor: tokens.colorNeutralBackground2,
        border: `1px dashed ${tokens.colorNeutralStroke1}`,
        flexWrap: 'wrap',
        ...fadeIn,
    },
    emptyIcon: { fontSize: '48px', color: tokens.colorBrandForeground1, flexShrink: 0 },
    emptyText: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalXS, flex: '1 1 260px', minWidth: 0 },
    emptyActions: { display: 'flex', gap: tokens.spacingHorizontalS, flexWrap: 'wrap' },

    // Recent projects
    recentHeading: { color: tokens.colorNeutralForeground3, fontWeight: tokens.fontWeightSemibold },
    recentList: { display: 'flex', gap: tokens.spacingHorizontalS, flexWrap: 'wrap', margin: 0, padding: 0, listStyle: 'none' },
    recentItem: {
        display: 'flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalS,
        padding: `${tokens.spacingVerticalS} ${tokens.spacingHorizontalM}`,
        minWidth: '220px',
        maxWidth: '340px',
        borderRadius: tokens.borderRadiusMedium,
        border: `1px solid ${tokens.colorNeutralStroke2}`,
        backgroundColor: tokens.colorNeutralBackground1,
        cursor: 'pointer',
        textAlign: 'left',
        fontFamily: 'inherit',
        color: tokens.colorNeutralForeground1,
        ':hover': { backgroundColor: tokens.colorNeutralBackground1Hover, ...shorthands.borderColor(tokens.colorBrandStroke2) },
        ':focus-visible': { outline: `${tokens.strokeWidthThick} solid ${tokens.colorStrokeFocus2}` },
        ':disabled': { cursor: 'default', opacity: 0.6 },
    },
    recentIcon: { fontSize: '20px', color: tokens.colorBrandForeground1, flexShrink: 0 },
    recentText: { display: 'flex', flexDirection: 'column', minWidth: 0 },
    recentName: { fontWeight: tokens.fontWeightSemibold, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' },
    recentMeta: { color: tokens.colorNeutralForeground3, fontSize: tokens.fontSizeBase200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' },

    // Open-project summary
    summary: {
        display: 'flex',
        alignItems: 'flex-start',
        gap: tokens.spacingHorizontalL,
        flexWrap: 'wrap',
        ...fadeIn,
    },
    summaryIcon: { fontSize: '40px', color: tokens.colorBrandForeground1, flexShrink: 0 },
    summaryText: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalXS, flex: '1 1 320px', minWidth: 0 },
    nameRow: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flexWrap: 'wrap' },
    name: { margin: 0, fontSize: tokens.fontSizeBase500, fontWeight: tokens.fontWeightSemibold, lineHeight: tokens.lineHeightBase500 },
    pathRow: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalXS, minWidth: 0 },
    path: {
        fontFamily: tokens.fontFamilyMonospace,
        fontSize: tokens.fontSizeBase200,
        color: tokens.colorNeutralForeground2,
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        whiteSpace: 'nowrap',
    },
    muted: { color: tokens.colorNeutralForeground3 },
    summaryActions: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flexWrap: 'wrap' },
});
