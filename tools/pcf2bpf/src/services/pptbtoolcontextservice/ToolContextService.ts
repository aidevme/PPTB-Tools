export type ToolboxConnection = Awaited<ReturnType<typeof window.toolboxAPI.connections.getActiveConnection>>;
export type ToolboxTheme = Awaited<ReturnType<typeof window.toolboxAPI.utils.getCurrentTheme>>;

/**
 * Centralizes the `window.toolboxAPI` calls used across the app (connection, theme, notifications)
 * behind one object, instead of components/hooks touching the global directly.
 */
export class ToolContextService {
    getActiveConnection(): Promise<ToolboxConnection> {
        return window.toolboxAPI.connections.getActiveConnection();
    }

    getCurrentTheme(): Promise<ToolboxTheme> {
        return window.toolboxAPI.utils.getCurrentTheme();
    }

    async notify(title: string, body: string, type: "success" | "error" | "info" | "warning"): Promise<void> {
        try {
            await window.toolboxAPI.utils.showNotification({ title, body, type });
        } catch {
            // Notifications are best-effort.
        }
    }
}
