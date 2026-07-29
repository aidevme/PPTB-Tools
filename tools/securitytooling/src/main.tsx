import { StrictMode, useCallback, useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { FluentProvider, webDarkTheme, webLightTheme } from '@fluentui/react-components';
import App from './App';
import { AppContext, type Connection, type ThemeMode } from './hooks';
import './index.css';

/** Wraps `<App>` in a `FluentProvider`, picking the theme once PPTB reports it (light by default),
 * and exposes the resolved mode plus the active Dataverse connection via `AppContext` for
 * components that need to branch on either. */
function Root() {
    const [mode, setMode] = useState<ThemeMode>('light');
    const [connection, setConnection] = useState<Connection>(null);
    const [isConnectionLoading, setIsConnectionLoading] = useState(true);

    useEffect(() => {
        // window.toolboxAPI is only injected when running inside PPTB; accessing it directly in
        // standalone dev mode would throw synchronously (before any .catch can run), so guard it.
        if (!window.toolboxAPI) return;

        window.toolboxAPI.utils
            .getCurrentTheme()
            .then((current) => setMode(current === 'dark' ? 'dark' : 'light'))
            // Fall back to light rather than leaving the app unrendered on a theme-detection failure.
            .catch(() => setMode('light'));
    }, []);

    const refreshConnection = useCallback(async () => {
        if (!window.toolboxAPI) {
            setIsConnectionLoading(false);
            return;
        }

        try {
            const conn = await window.toolboxAPI.connections.getActiveConnection();
            setConnection(conn);
        } catch (error) {
            console.error('Error refreshing connection:', error);
        } finally {
            setIsConnectionLoading(false);
        }
    }, []);

    useEffect(() => {
        void refreshConnection();
    }, [refreshConnection]);

    // FluentProvider only paints its own element's background, not the page behind/around it
    // (e.g. the margin outside #root's max-width, or any area before the app has mounted). Mirror
    // the active theme's background onto <html>/<body> too so the whole page matches, not just the
    // app's own box.
    useEffect(() => {
        const background = (mode === 'dark' ? webDarkTheme : webLightTheme).colorNeutralBackground1;
        document.documentElement.style.backgroundColor = background;
        document.body.style.backgroundColor = background;
    }, [mode]);

    const appContextValue = useMemo(
        () => ({ themeMode: mode, setThemeMode: setMode, connection, isConnectionLoading, refreshConnection }),
        [mode, connection, isConnectionLoading, refreshConnection],
    );

    return (
        <AppContext.Provider value={appContextValue}>
            <FluentProvider theme={mode === 'dark' ? webDarkTheme : webLightTheme} style={{ minHeight: '100vh' }}>
                <App />
            </FluentProvider>
        </AppContext.Provider>
    );
}

// Ensure DOM is ready and root element exists
const rootElement = document.getElementById('root');
if (rootElement && !rootElement.hasAttribute('data-reactroot-initialized')) {
    // Mark as initialized to prevent double rendering
    rootElement.setAttribute('data-reactroot-initialized', 'true');

    createRoot(rootElement).render(
        <StrictMode>
            <Root />
        </StrictMode>,
    );
} else if (!rootElement) {
    console.error('Root element not found. Make sure the HTML contains <div id="root"></div>');
}
