import { makeStyles, tokens } from '@fluentui/react-components';

const fadeIn = {
    animationName: { from: { opacity: 0, transform: 'translateY(4px)' }, to: { opacity: 1, transform: 'translateY(0)' } },
    animationDuration: tokens.durationNormal,
    animationTimingFunction: tokens.curveDecelerateMid,
    '@media (prefers-reduced-motion: reduce)': { animationName: 'none' },
};

/** Styles for `ProjectCard`: the empty state and the open-project summary (the recent projects are `RecentProjectsList`). */
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
