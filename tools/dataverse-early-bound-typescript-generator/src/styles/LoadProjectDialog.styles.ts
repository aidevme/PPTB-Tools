import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `LoadProjectDialog`: the wide dialog surface and the scrolling wrapper around `ProjectsTable`. */
export const useLoadProjectDialogStyles = makeStyles({
    surface: { maxWidth: '1000px', width: '90vw' },
    tableWrapper: {
        maxHeight: '360px',
        overflow: 'auto',
        border: `1px solid ${tokens.colorNeutralStroke2}`,
        borderRadius: tokens.borderRadiusMedium,
    },
    empty: { color: tokens.colorNeutralForeground3 },
});
