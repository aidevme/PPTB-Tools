import type { KeyboardEvent } from 'react';

/**
 * Enter and Space on a focused table row act like a click on it (select or toggle the row). Returns whether the key
 * was one of them, so a handler can go on to other keys.
 *
 * @remarks
 * For Enter and Space, prevents the default action (so Space doesn't scroll) before calling `activate`.
 *
 * @param e - The row's key-down event.
 * @param activate - Called when the key is Enter or Space.
 * @returns `true` when the key was Enter or Space and `activate` ran; otherwise `false`.
 */
export function activateRowOnKey(e: KeyboardEvent, activate: () => void): boolean {
    if (e.key !== ' ' && e.key !== 'Enter') return false;
    e.preventDefault();
    activate();
    return true;
}
