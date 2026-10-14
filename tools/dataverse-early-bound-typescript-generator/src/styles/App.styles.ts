import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `App`: the full-height page, the centred main column of step cards, and the progress area. */
export const useAppStyles = makeStyles({
    page: { display: 'flex', flexDirection: 'column', minHeight: '100vh' },
    main: {
        display: 'flex',
        flexDirection: 'column',
        gap: tokens.spacingVerticalM,
        padding: tokens.spacingHorizontalL,
        flexGrow: 1,
        maxWidth: '1400px',
        width: '100%',
        boxSizing: 'border-box',
        alignSelf: 'center',
    },
    progress: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalXS },
});
