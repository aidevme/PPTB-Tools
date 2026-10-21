import { makeStyles, tokens } from '@fluentui/react-components';
import { FOOTER_SLIDE_OUT_MS } from '../components/layout/Layout.const';

/**
 * Styles for `App`: the full-height page, the header that stays visible while the page scrolls, the footer that is
 * pinned for a few seconds and then slides out to the end of the page, the centred main column of step cards, and
 * the progress area.
 */
export const useAppStyles = makeStyles({
    page: { display: 'flex', flexDirection: 'column', minHeight: '100vh' },
    // The bars' own backgrounds are opaque, so the cards scroll out of sight underneath them. The z-index keeps
    // them above the cards' shadows; Fluent's dialogs, popovers and tooltips render in portals above both.
    stickyHeader: { position: 'sticky', top: 0, zIndex: 2 },
    // The gap above the footer is a margin on the sticky wrapper, outside it, so no see-through strip scrolls with it.
    stickyFooter: { position: 'sticky', bottom: 0, zIndex: 2, marginTop: tokens.spacingVerticalL },
    // After FOOTER_AUTO_HIDE_MS (useAutoHideFooter): the footer slides down out of the window, then docks at the end of
    // the page in the normal flow, where scrolling to the bottom shows it again.
    footerSliding: {
        transform: 'translateY(100%)',
        transitionProperty: 'transform',
        transitionDuration: `${FOOTER_SLIDE_OUT_MS}ms`,
        transitionTimingFunction: tokens.curveAccelerateMid,
        '@media (prefers-reduced-motion: reduce)': { transitionDuration: '0.01ms' },
    },
    footerDocked: { position: 'static' },
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
