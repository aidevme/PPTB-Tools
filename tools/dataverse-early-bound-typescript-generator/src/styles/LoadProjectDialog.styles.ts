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
    actionsCell: { width: '88px' },
    path: { fontFamily: tokens.fontFamilyMonospace, fontSize: tokens.fontSizeBase200, wordBreak: 'break-all' },
    muted: { color: tokens.colorNeutralForeground3 },
    /** Full description in the tooltip, keeping the line breaks typed in the project form. */
    descriptionTooltip: { whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' },
    empty: { color: tokens.colorNeutralForeground3 },
});
