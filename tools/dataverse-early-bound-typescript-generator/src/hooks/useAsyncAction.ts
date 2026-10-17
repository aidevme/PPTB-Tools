import { useState } from 'react';
import { reportError } from '../services';

/**
 * An async action a dialog or panel runs from a button (save, open, delete): `busy` while it runs, the error
 * cleared when it starts and set when it fails. The caller owns the error state, so several actions can share one
 * error message. Errors are logged and made friendly by `reportError` without a notification, since the caller
 * shows them in place.
 */
export function useAsyncAction(setError: (message: string | null) => void) {
    const [busy, setBusy] = useState(false);

    /** Runs `action`; resolves to its result, or `undefined` when it failed (the error is then shown). */
    const run = async <T>(operation: string, action: () => Promise<T>): Promise<T | undefined> => {
        setBusy(true);
        setError(null);
        try {
            return await action();
        } catch (error) {
            setError(reportError(operation, error, undefined, { notify: false }));
            return undefined;
        } finally {
            setBusy(false);
        }
    };

    return { busy, run };
}
