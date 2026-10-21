/**
 * The Prism language to highlight a file in, from its extension.
 *
 * @param path - The file's path or name.
 * @returns `typescript` for `.ts`, `.tsx` and `.ejs` files, `json` for `.json` files, or `undefined` to show the file
 * unhighlighted.
 */
export function languageFor(path: string): string | undefined {
    if (/\.tsx?$/i.test(path)) return 'typescript';
    if (/\.json$/i.test(path)) return 'json';
    // dataverse-gen's EJS templates produce TypeScript, so most of their text is TypeScript; the <% %> tags show in the
    // punctuation color.
    if (/\.ejs$/i.test(path)) return 'typescript';
    return undefined;
}
