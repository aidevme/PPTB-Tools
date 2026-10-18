# Plain JavaScript files

<!-- cspell:ignore tsdoc typedef -->

Purpose: documenting `.js`, `.mjs` and `.cjs` files, where there's no TypeScript signature to carry the types.

- Use **JSDoc** here, with types in braces, because the comment is the only place the types live. TypeScript's
  `checkJs` and editors read these types.
- **Never mix** JSDoc and TSDoc syntax in one comment: no `@param name - text` hyphen together with `{type}` braces,
  no `@typeParam`.
- `tsdoc/syntax` is for TypeScript files; don't run it on `.js` (the check script skips them).
- The writing rules still apply: a one-sentence summary, behavior over restating names, `@throws` and `@example`
  only when useful.

## Syntax

```js
/**
 * Formats a byte count for display.
 * @param {number} bytes - Size in bytes; negative values are treated as 0.
 * @param {object} [options] - Formatting options.
 * @param {number} [options.digits=1] - Decimal places.
 * @returns {string} For example "1.5 MB".
 */
export function formatBytes(bytes, options) { … }
```

| Need | JSDoc |
| --- | --- |
| Optional parameter | `@param {string} [name]` |
| Default value | `@param {number} [digits=1]` |
| Object properties | `@param {object} options` then `@param {string} options.path` |
| Reusable shape | `@typedef {object} ExportOptions` with one `@property {string} path - …` per property |
| Return value | `@returns {Promise<string[]>} …` |

The dash before a description is optional in JSDoc; keep whichever the file already uses.
