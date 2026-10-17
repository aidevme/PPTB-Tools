import { makeStyles, shorthands, tokens } from '@fluentui/react-components';

/** Styles for `RecentProjectsList`: the heading and the row of project buttons. */
export const useRecentProjectsListStyles = makeStyles({
    root: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalM },
    heading: { color: tokens.colorNeutralForeground3, fontWeight: tokens.fontWeightSemibold },
    list: { display: 'flex', gap: tokens.spacingHorizontalS, flexWrap: 'wrap', margin: 0, padding: 0, listStyle: 'none' },
    item: {
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
    icon: { fontSize: '20px', color: tokens.colorBrandForeground1, flexShrink: 0 },
    text: { display: 'flex', flexDirection: 'column', minWidth: 0 },
    name: { fontWeight: tokens.fontWeightSemibold, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' },
    meta: { color: tokens.colorNeutralForeground3, fontSize: tokens.fontSizeBase200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' },
});
