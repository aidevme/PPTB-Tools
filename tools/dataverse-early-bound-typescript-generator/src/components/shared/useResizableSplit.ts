import { useRef, useState, type KeyboardEvent, type PointerEvent as ReactPointerEvent } from 'react';
import { DEFAULT_LIST_WIDTH, clampListWidth } from './previewFiles';

/**
 * The Preview card's resizable divider between the file list and the viewer: dragging it, or ←/→ while it has
 * focus, changes the list's width, kept within `clampListWidth` of the split container (`splitRef`).
 */
export function useResizableSplit() {
    const [listWidth, setListWidth] = useState(DEFAULT_LIST_WIDTH);
    const splitRef = useRef<HTMLDivElement>(null);

    const clampWidth = (width: number) => clampListWidth(width, splitRef.current?.clientWidth ?? 0);
    const startResize = (e: ReactPointerEvent<HTMLDivElement>) => {
        const startX = e.clientX;
        const startWidth = listWidth;
        const move = (ev: PointerEvent) => setListWidth(clampWidth(startWidth + ev.clientX - startX));
        const stop = () => {
            window.removeEventListener('pointermove', move);
            window.removeEventListener('pointerup', stop);
        };
        window.addEventListener('pointermove', move);
        window.addEventListener('pointerup', stop);
    };
    const onSplitterKeyDown = (e: KeyboardEvent) => {
        const delta = e.key === 'ArrowLeft' ? -32 : e.key === 'ArrowRight' ? 32 : 0;
        if (delta) {
            e.preventDefault();
            setListWidth((w) => clampWidth(w + delta));
        }
    };

    return { listWidth, splitRef, startResize, onSplitterKeyDown };
}
