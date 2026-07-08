/**
 * Barrel export for the XML formatter component and its framework-free helpers.
 *
 * @remarks
 * Re-exports, in dependency order:
 * - `xmlTokenizer` — regex-based tokenizer used for syntax-color spans.
 * - `xmlParser` — structural parser used for folding and pretty-printing.
 * - `xmlDiff` — line-level LCS diff used for before/after highlighting.
 * - `xmlTheme` — color palettes consumed via CSS custom properties.
 * - `XmlFormatter` — the component itself.
 */
export * from "./xmlTokenizer";
export * from "./xmlParser";
export * from "./xmlDiff";
export * from "./xmlTheme";
export * from "./XmlFormatter";
