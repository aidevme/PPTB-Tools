import { useCallback, useEffect, useState } from 'react';

/**
 * Tracks the active PPTB Dataverse connection. Reads it once on mount and again whenever PPTB raises a
 * `connection:*` event; in standalone dev mode (no `window.toolboxAPI`) it resolves to `null`.
 */
export function useConnection() {
    const [connection, setConnection] = useState<ToolBoxAPI.Connection | null>(null);
    const [isLoading, setIsLoading] = useState(true);

    const refreshConnection = useCallback(async () => {
        if (!window.toolboxAPI) {
            setIsLoading(false);
            return;
        }
        try {
            setConnection(await window.toolboxAPI.connections.getActiveConnection());
        } catch (error) {
            console.error('Error reading the active connection:', error);
        } finally {
            setIsLoading(false);
        }
    }, []);

    useEffect(() => {
        void refreshConnection();
        if (!window.toolboxAPI?.events) return;
        const handler = (_event: unknown, payload: ToolBoxAPI.ToolBoxEventPayload) => {
            if (payload.event === 'connection:updated' || payload.event === 'connection:created' || payload.event === 'connection:deleted') {
                void refreshConnection();
            }
        };
        window.toolboxAPI.events.on(handler);
        return () => window.toolboxAPI.events.off?.(handler);
    }, [refreshConnection]);

    return { connection, isLoading, refreshConnection };
}
