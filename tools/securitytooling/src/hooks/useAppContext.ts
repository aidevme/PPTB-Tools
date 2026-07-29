import { createContext, useContext, type Dispatch, type SetStateAction } from "react";

export type ThemeMode = "light" | "dark";

export type Connection = Awaited<ReturnType<typeof window.toolboxAPI.connections.getActiveConnection>>;

export interface IAppContextValue {
    /**
     * The PPTB host's current theme ("light" | "dark"), as detected once in `main.tsx`'s `Root` via
     * `window.toolboxAPI.utils.getCurrentTheme()`. Fluent's own `ThemeContext` only exposes the
     * resolved `Theme` token object (and only via an `_unstable` API), not a simple light/dark flag,
     * so components that need to branch on theme mode (e.g. `ModuleCard`'s fixed-palette look) read
     * this instead.
     */
    themeMode: ThemeMode;
    /** Lets a component (e.g. `HeaderToolbar`'s Light/Dark toggle) override the detected theme
     * rather than only reading it. */
    setThemeMode: Dispatch<SetStateAction<ThemeMode>>;
    /** PPTB's active Dataverse connection, fetched once in `main.tsx`'s `Root` via
     * `window.toolboxAPI.connections.getActiveConnection()`. `null` before the first fetch resolves,
     * if it failed, or if there's no active connection. */
    connection: Connection;
    /** `true` until the first connection fetch settles. */
    isConnectionLoading: boolean;
    /** Re-fetches the active connection, e.g. after the user switches connections in PPTB. */
    refreshConnection: () => Promise<void>;
}

/** App-wide state shared via React context. `main.tsx`'s `Root` owns the real values (and provides
 * them via `AppContext.Provider`); this default is only used if a consumer renders outside it. */
export const AppContext = createContext<IAppContextValue>({
    themeMode: "light",
    setThemeMode: () => {},
    connection: null,
    isConnectionLoading: true,
    refreshConnection: async () => {},
});

export function useAppContext(): IAppContextValue {
    return useContext(AppContext);
}
