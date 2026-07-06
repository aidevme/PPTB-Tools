/** A full color palette for {@link XmlFormatter}, independent of the app's own Fluent theme. */
export interface XmlTheme {
    background: string;
    text: string;
    tag: string;
    attrName: string;
    attrValue: string;
    comment: string;
    punctuation: string;
    placeholder: string;
    lineNumber: string;
    border: string;
}

export type XmlThemeName = "light" | "dark";

/** Built-in light palette, loosely modeled on common editor "light" XML/HTML color conventions. */
export const LIGHT_XML_THEME: XmlTheme = {
    background: "#ffffff",
    text: "#000000",
    tag: "#800000",
    attrName: "#ff0000",
    attrValue: "#0451a5",
    comment: "#008000",
    punctuation: "#000000",
    placeholder: "#6e6e6e",
    lineNumber: "#237893",
    border: "#d4d4d4",
};

/** Built-in dark palette, loosely modeled on common editor "dark" XML/HTML color conventions. */
export const DARK_XML_THEME: XmlTheme = {
    background: "#1e1e1e",
    text: "#d4d4d4",
    tag: "#569cd6",
    attrName: "#9cdcfe",
    attrValue: "#ce9178",
    comment: "#6a9955",
    punctuation: "#d4d4d4",
    placeholder: "#808080",
    lineNumber: "#858585",
    border: "#3c3c3c",
};

export function resolveXmlTheme(theme: XmlThemeName | XmlTheme | undefined): XmlTheme {
    if (theme === "light") return LIGHT_XML_THEME;
    if (theme === undefined || theme === "dark") return DARK_XML_THEME;
    return theme;
}
