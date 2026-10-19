import { makeStyles } from '@fluentui/react-components';

/** Styles for `SelectionTable`: rows that can't be toggled show the default cursor. */
export const useSelectionTableStyles = makeStyles({
    rowDisabled: { cursor: 'default' },
});
