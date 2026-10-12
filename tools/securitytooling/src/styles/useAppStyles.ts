import { makeStyles, tokens } from '@fluentui/react-components';

/** Layout for `App`'s header and the tool card grid. */
export const useAppStyles = makeStyles({
    root: {
        display: 'flex',
        flexDirection: 'column',
        gap: tokens.spacingVerticalXXL,
    },
    toolbarRow: {
        display: 'flex',
        justifyContent: 'flex-end',
    },
    toolGrid: {
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))',
        gap: tokens.spacingHorizontalM,
    },
});
