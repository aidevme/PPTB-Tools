import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `ProjectsTable`: the folder icon, the one-line location, muted dates and values, and the tooltips. */
export const useProjectsTableStyles = makeStyles({
    folderIcon: { color: tokens.colorBrandForeground1, fontSize: '18px' },
    path: {
        display: 'block',
        fontFamily: tokens.fontFamilyMonospace,
        fontSize: tokens.fontSizeBase200,
        color: tokens.colorNeutralForeground2,
        whiteSpace: 'nowrap',
        overflow: 'hidden',
        textOverflow: 'ellipsis',
    },
    /** The full location in the tooltip, broken anywhere so a long path fits. */
    pathTooltip: { fontFamily: tokens.fontFamilyMonospace, overflowWrap: 'anywhere', maxWidth: '420px' },
    date: { color: tokens.colorNeutralForeground2, whiteSpace: 'nowrap' },
    muted: { color: tokens.colorNeutralForeground3 },
    /** Full description in the tooltip, keeping the line breaks typed in the project form. */
    descriptionTooltip: { whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' },
});
