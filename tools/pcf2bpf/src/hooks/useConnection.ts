import { useCallback, useEffect, useState } from "react";

type Connection = Awaited<ReturnType<typeof window.toolboxAPI.connections.getActiveConnection>>;

/**
 * Tracks PPTB's active Dataverse connection, fetching it once on mount.
 *
 * @remarks
 * Errors are logged and swallowed rather than thrown, since there's no connected environment
 * to report them against; `connection` simply stays `null` on failure.
 *
 * @returns `connection` — the active connection, or `null` before the first fetch resolves or
 * if it failed; `isLoading` — `true` until the first fetch settles; `refresh` — call to
 * re-check (e.g. after the user switches connections).
 */
export function useConnection() {
    const [connection, setConnection] = useState<Connection>(null);
    const [isLoading, setIsLoading] = useState(true);

    const refresh = useCallback(async () => {
        try {
            const conn = await window.toolboxAPI.connections.getActiveConnection();
            setConnection(conn);
        } catch (error) {
            console.error("Error refreshing connection:", error);
        } finally {
            setIsLoading(false);
        }
    }, []);

    useEffect(() => {
        void refresh();
    }, [refresh]);

    return { connection, isLoading, refresh };
}
