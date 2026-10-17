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
    rowDisabled: { cursor: 'default' },
    stacked: { display: 'flex', flexDirection: 'column', minWidth: 0 },
    mono: { fontFamily: tokens.fontFamilyMonospace, fontSize: tokens.fontSizeBase200 },
    secondary: { color: tokens.colorNeutralForeground3, fontFamily: tokens.fontFamilyMonospace, fontSize: tokens.fontSizeBase200 },
    muted: { color: tokens.colorNeutralForeground3 },
    empty: { padding: tokens.spacingVerticalL, textAlign: 'center', color: tokens.colorNeutralForeground3 },
    summary: { display: 'flex', gap: tokens.spacingHorizontalS, alignItems: 'center', flexWrap: 'wrap' },
});
