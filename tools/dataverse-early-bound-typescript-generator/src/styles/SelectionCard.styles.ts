import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `SelectionCard`: the toolbar, and the scrolling selection table with a sticky header. */
export const useSelectionCardStyles = makeStyles({
    body: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalS },
    toolbar: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flexWrap: 'wrap' },
    search: { minWidth: '260px' },
    list: {
        maxHeight: '360px',
        overflowY: 'auto',
        border: `1px solid ${tokens.colorNeutralStroke2}`,
        borderRadius: tokens.borderRadiusMedium,
    },
    row: { cursor: 'pointer' },
    rowDisabled: { cursor: 'default' },
    // Keeps the column headers visible while the list scrolls.
    headerRow: { position: 'sticky', top: 0, zIndex: 1, backgroundColor: tokens.colorNeutralBackground1 },
    headerCell: { fontWeight: tokens.fontWeightSemibold },
    // Wider than Fluent's default tooltip, for the per-value explanations.
    headerTooltip: { maxWidth: '360px', '& ul': { margin: `${tokens.spacingVerticalXS} 0`, paddingLeft: tokens.spacingHorizontalL } },
    stacked: { display: 'flex', flexDirection: 'column', minWidth: 0 },
    mono: { fontFamily: tokens.fontFamilyMonospace, fontSize: tokens.fontSizeBase200 },
    secondary: { color: tokens.colorNeutralForeground3, fontFamily: tokens.fontFamilyMonospace, fontSize: tokens.fontSizeBase200 },
    muted: { color: tokens.colorNeutralForeground3 },
    empty: { padding: tokens.spacingVerticalL, textAlign: 'center', color: tokens.colorNeutralForeground3 },
    summary: { display: 'flex', gap: tokens.spacingHorizontalS, alignItems: 'center', flexWrap: 'wrap' },
});
