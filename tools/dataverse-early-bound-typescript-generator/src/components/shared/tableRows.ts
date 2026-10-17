import type { KeyboardEvent } from 'react';

/**
 * Enter and Space on a focused table row act like a click on it (select or toggle the row). Returns whether the key
 * was one of them, so a handler can go on to other keys.
 */
export function activateRowOnKey(e: KeyboardEvent, activate: () => void): boolean {
    if (e.key !== ' ' && e.key !== 'Enter') return false;
    e.preventDefault();
    activate();
    return true;
}
