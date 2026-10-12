import { makeStyles, tokens } from '@fluentui/react-components';

/** Layout for `Header`. */
export const useHeaderStyles = makeStyles({
    header: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: tokens.spacingVerticalXS,
        textAlign: 'center',
    },
});
