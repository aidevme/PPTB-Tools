/** A full color palette for {@link JsonFormatter}, independent of the app's own Fluent theme. */
export interface JsonTheme {
    background: string;
    text: string;
    key: string;
    string: string;
    number: string;
    boolean: string;
    nullLiteral: string;
    punctuation: string;
    placeholder: string;
    lineNumber: string;
    border: string;
    /** Background for search-match highlighting; highlighted text always uses a dark foreground
     * regardless of theme, since this stays a bright color on both light and dark backgrounds. */
    highlight: string;
}

/** Name of a built-in {@link JsonTheme} palette, as accepted by {@link resolveJsonTheme}. */
export type JsonThemeName = "light" | "dark";

/** Built-in light palette, modeled on common editor "light" JSON color conventions. */
export const LIGHT_JSON_THEME: JsonTheme = {
    background: "#ffffff",
    text: "#000000",
    key: "#001080",
    string: "#a31515",
    number: "#098658",
    boolean: "#0000ff",
    nullLiteral: "#0000ff",
    punctuation: "#000000",
    placeholder: "#6e6e6e",
    lineNumber: "#237893",
    border: "#d4d4d4",
    highlight: "#ffeb3b",
};

/** Built-in dark palette, modeled on common editor "dark" JSON color conventions. */
export const DARK_JSON_THEME: JsonTheme = {
    background: "#1e1e1e",
    text: "#d4d4d4",
    key: "#9cdcfe",
    string: "#ce9178",
    number: "#b5cea8",
    boolean: "#569cd6",
    nullLiteral: "#569cd6",
    punctuation: "#d4d4d4",
    placeholder: "#808080",
    lineNumber: "#858585",
    border: "#3c3c3c",
    highlight: "#ffeb3b",
};

/** Resolves the `theme` prop to a concrete {@link JsonTheme}: a built-in name, a custom palette
 * passed through as-is, or the dark palette when omitted. */
export function resolveJsonTheme(theme: JsonThemeName | JsonTheme | undefined): JsonTheme {
    if (theme === "light") return LIGHT_JSON_THEME;
    if (theme === undefined || theme === "dark") return DARK_JSON_THEME;
    return theme;
}
