import { StrictMode, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { FluentProvider, webDarkTheme, webLightTheme, type Theme } from "@fluentui/react-components";
import App from "./App";
import { ToolContextProvider, ToolContextService } from "./services/pptbtoolcontextservice";
import "./index.css";

// Created once at module scope so it's a stable singleton reference across re-renders (and
// StrictMode's double-invoke) rather than being rebuilt on every render of `Root`.
const toolContextService = new ToolContextService();

/** Wraps `<App>` in a `FluentProvider`, picking the theme once PPTB reports it (light by default). */
function Root() {
    const [theme, setTheme] = useState<Theme>(webLightTheme);

    useEffect(() => {
        toolContextService
            .getCurrentTheme()
            .then((current) => setTheme(current === "dark" ? webDarkTheme : webLightTheme))
            // Fall back to light rather than leaving the app unrendered on a theme-detection failure.
            .catch(() => setTheme(webLightTheme));
    }, []);

    return (
        <ToolContextProvider toolcontext={toolContextService}>
            {/* FluentProvider renders its own wrapping element; without an explicit height here the
            height: 100% chain from #root down to App's root div breaks at this link, since a
            percentage height needs every ancestor to itself resolve to a definite height. */}
            <FluentProvider theme={theme} style={{ height: "100%" }}>
                <App />
            </FluentProvider>
        </ToolContextProvider>
    );
}

// The attribute guard prevents calling createRoot() twice on the same node if this bundle gets
// re-evaluated without a full page reload (e.g. PPTB reloading the tool in place).
const rootElement = document.getElementById("root");
if (rootElement && !rootElement.hasAttribute("data-reactroot-initialized")) {
    rootElement.setAttribute("data-reactroot-initialized", "true");

    createRoot(rootElement).render(
        <StrictMode>
            <Root />
        </StrictMode>,
    );
} else if (!rootElement) {
    console.error('Root element not found. Make sure the HTML contains <div id="root"></div>');
}
