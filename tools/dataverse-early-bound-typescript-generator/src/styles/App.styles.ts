import { makeStyles, tokens } from '@fluentui/react-components';

/**
 * Styles for `App`: the full-height page, the header and footer that stay visible while the page scrolls, the
 * centred main column of step cards, and the progress area.
 */
export const useAppStyles = makeStyles({
    page: { display: 'flex', flexDirection: 'column', minHeight: '100vh' },
    // The bars' own backgrounds are opaque, so the cards scroll out of sight underneath them. The z-index keeps
    // them above the cards' shadows; Fluent's dialogs, popovers and tooltips render in portals above both.
    stickyHeader: { position: 'sticky', top: 0, zIndex: 2 },
    // The gap above the footer is a margin on the sticky wrapper, outside it, so no see-through strip scrolls with it.
    stickyFooter: { position: 'sticky', bottom: 0, zIndex: 2, marginTop: tokens.spacingVerticalL },
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
