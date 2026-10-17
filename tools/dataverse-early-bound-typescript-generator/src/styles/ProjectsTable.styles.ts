import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `ProjectsTable`: the actions column, the location path, empty values and the description tooltip. */
export const useProjectsTableStyles = makeStyles({
    actionsCell: { width: '88px' },
    path: { fontFamily: tokens.fontFamilyMonospace, fontSize: tokens.fontSizeBase200, wordBreak: 'break-all' },
    muted: { color: tokens.colorNeutralForeground3 },
    /** Full description in the tooltip, keeping the line breaks typed in the project form. */
    descriptionTooltip: { whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' },
});
