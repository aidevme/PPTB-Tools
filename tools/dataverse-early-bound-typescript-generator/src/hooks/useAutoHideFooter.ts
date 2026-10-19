import { useEffect, useState } from 'react';

/**
 * Where the footer is: `pinned` to the bottom of the window, `sliding` out of it, or `docked` at the end of the page
 * (in the normal flow, so it shows when the page is scrolled to the bottom).
 */
export type FooterPhase = 'pinned' | 'sliding' | 'docked';

/** Whether the window is scrolled to the end of the page, or the page doesn't scroll at all. */
function atPageEnd(): boolean {
    return window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 1;
}

/**
 * Pins the footer for `pinnedMs` after mount, then slides it out over `slideOutMs` and docks it at the end of the
 * page.
 *
 * @remarks If the page is already scrolled to the end (or doesn't scroll), the docked footer would sit exactly where
 * the pinned one is, so it docks straight away instead of sliding out and back in. The timers are cleared on
 * unmount.
 *
 * @param pinnedMs - How long the footer stays pinned, in milliseconds.
 * @param slideOutMs - How long the slide-out takes, in milliseconds; matches the footer's CSS transition.
 * @returns The footer's current phase.
 */
export function useAutoHideFooter(pinnedMs: number, slideOutMs: number): FooterPhase {
    const [phase, setPhase] = useState<FooterPhase>('pinned');
    useEffect(() => {
        let slideTimer: ReturnType<typeof setTimeout> | undefined;
        const pinTimer = setTimeout(() => {
            if (atPageEnd()) {
                setPhase('docked');
                return;
            }
            setPhase('sliding');
            slideTimer = setTimeout(() => setPhase('docked'), slideOutMs);
        }, pinnedMs);
        return () => {
            clearTimeout(pinTimer);
            if (slideTimer) clearTimeout(slideTimer);
        };
    }, [pinnedMs, slideOutMs]);
    return phase;
}
