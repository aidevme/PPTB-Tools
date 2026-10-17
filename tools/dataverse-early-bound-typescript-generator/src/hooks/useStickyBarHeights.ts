import { useEffect, type RefObject } from 'react';

/**
 * Publishes the heights of the sticky header and footer as the CSS variables `--app-header-height` and
 * `--app-footer-height` on `<html>`, and keeps them current as the bars resize (the header wraps on narrow tool
 * tabs). `index.css` turns them into `scroll-padding`, so scrolling to a step card lands below the header instead
 * of under it.
 */
export function useStickyBarHeights(header: RefObject<HTMLElement | null>, footer: RefObject<HTMLElement | null>): void {
    useEffect(() => {
        const root = document.documentElement;
        const update = () => {
            root.style.setProperty('--app-header-height', `${header.current?.offsetHeight ?? 0}px`);
            root.style.setProperty('--app-footer-height', `${footer.current?.offsetHeight ?? 0}px`);
        };
        update();
        // Not available in every test environment; the initial values still apply there.
        if (typeof ResizeObserver === 'undefined') return;
        const observer = new ResizeObserver(update);
        if (header.current) observer.observe(header.current);
        if (footer.current) observer.observe(footer.current);
        return () => observer.disconnect();
    }, [header, footer]);
}
