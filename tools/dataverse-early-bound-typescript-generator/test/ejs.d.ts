// Types for the part of `ejs` the tests use. ejs ships without types and is a test-only devDependency (spec 001,
// research R3), so a declaration here avoids another package; src/ never imports ejs.
declare module 'ejs' {
    /** Renders an EJS template with `data` (available as top-level names and as `locals`). */
    export function render(template: string, data?: Record<string, unknown>): string;
}
