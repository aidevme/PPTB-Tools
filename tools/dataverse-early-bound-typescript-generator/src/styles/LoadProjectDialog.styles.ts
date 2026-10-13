import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `LoadProjectDialog`: the wide dialog surface, and the scrolling projects table with its actions column. */
export const useLoadProjectDialogStyles = makeStyles({
    surface: { maxWidth: '1000px', width: '90vw' },
    tableWrapper: {
        maxHeight: '360px',
        overflow: 'auto',
        border: `1px solid ${tokens.colorNeutralStroke2}`,
        borderRadius: tokens.borderRadiusMedium,
    },
    row: { cursor: 'pointer' },
    headerCell: { fontWeight: tokens.fontWeightSemibold },
    actionsCell: { width: '48px' },
    path: { fontFamily: tokens.fontFamilyMonospace, fontSize: tokens.fontSizeBase200, wordBreak: 'break-all' },
    muted: { color: tokens.colorNeutralForeground3 },
    empty: { color: tokens.colorNeutralForeground3 },
});
