import { StrictMode, useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { FluentProvider, webDarkTheme, webLightTheme } from '@fluentui/react-components';
import App from './App';
import './index.css';

type ThemeMode = 'light' | 'dark';

/** Wraps `<App>` in a `FluentProvider`, picking the theme once PPTB reports it (light by default). */
function Root() {
    const [mode, setMode] = useState<ThemeMode>('light');

    useEffect(() => {
        // window.toolboxAPI is only injected inside PPTB; guard so standalone dev mode does not throw.
        if (!window.toolboxAPI) return;
        window.toolboxAPI.utils
            .getCurrentTheme()
            .then((current) => setMode(current === 'dark' ? 'dark' : 'light'))
            .catch(() => setMode('light'));
    }, []);

    // FluentProvider only paints its own element; mirror the theme background onto <html>/<body>.
    useEffect(() => {
        const background = (mode === 'dark' ? webDarkTheme : webLightTheme).colorNeutralBackground1;
        document.documentElement.style.backgroundColor = background;
        document.body.style.backgroundColor = background;
    }, [mode]);

    return (
        <FluentProvider theme={mode === 'dark' ? webDarkTheme : webLightTheme} style={{ minHeight: '100vh' }}>
            <App />
        </FluentProvider>
    );
}

const rootElement = document.getElementById('root');
if (rootElement && !rootElement.hasAttribute('data-reactroot-initialized')) {
    rootElement.setAttribute('data-reactroot-initialized', 'true');
    createRoot(rootElement).render(
        <StrictMode>
            <Root />
        </StrictMode>,
    );
} else if (!rootElement) {
    console.error('Root element not found. Make sure the HTML contains <div id="root"></div>');
}
