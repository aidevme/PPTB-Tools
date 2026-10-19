# Setup: eslint-plugin-tsdoc, tsdoc.json, TypeDoc and API Extractor

<!-- cspell:ignore tsdoc typedoc tsconfig inheritdoc rollups -->

Purpose: set up the `tsdoc/syntax` check (and optionally doc generation) in a project. Always show the changes and
ask before installing a package or editing a config file.

Versions checked on 2026-10-18: `eslint-plugin-tsdoc` 0.5.4 (peer `eslint >=7`; it depends on `@microsoft/tsdoc`
0.17.1 and `@microsoft/tsdoc-config` 0.18.3), `typedoc` 0.28.20, `@microsoft/api-extractor` 7.59.4. The check script
was tested with `eslint` 10.13.0 and 9.39.5 and `@typescript-eslint/parser` 8.71.2 (TypeScript 5.9.3); ESLint 9 is
out of support, so install 10.

## What the check needs

`scripts/check-tsdoc.mjs` runs ESLint with only the `tsdoc/syntax` rule, so it needs three packages resolvable from
the project (the nearest folder with `package.json`):

| Package | Why |
| --- | --- |
| `eslint` | Runs the rule |
| `@typescript-eslint/parser` | Parses TypeScript (no type information is needed) |
| `eslint-plugin-tsdoc` | Provides `tsdoc/syntax` |

The script uses its own inline config, so it works even if the project's ESLint config doesn't enable the rule.

## Workflow

1. **Look first:** `package.json` (dev dependencies, a `lint` script), the ESLint config (`eslint.config.js/mjs/cjs`
   for flat config, `.eslintrc*` for legacy), and `tsdoc.json`.
2. **Propose the smallest change:**
   - **No ESLint:** offer only the check's three packages. Adding a full lint setup is the user's decision.
   - **ESLint present:** add `eslint-plugin-tsdoc` (and `@typescript-eslint/parser` if it's missing) and enable
     `tsdoc/syntax` in the existing config.
3. **Show the diff and the install command, and ask.** Example:

   ```bash
   npm install --save-dev eslint-plugin-tsdoc @typescript-eslint/parser eslint@10
   ```

4. **After approval:** install, edit, run `node <skill>/scripts/check-tsdoc.mjs <a few files>`, and report. Hand the
   commit (`package.json`, the lock file and the config together) to aidevme-github.

## Flat config (ESLint 9: eslint.config.js / .mjs)

Merge `assets/eslint-tsdoc.snippet.mjs` into the existing config; don't replace the config. The essential part:

```js
import tsParser from '@typescript-eslint/parser';
import tsdoc from 'eslint-plugin-tsdoc';

export default [
    // …existing config objects…
    {
        files: ['**/*.{ts,tsx,mts,cts}'],
        languageOptions: { parser: tsParser },
        plugins: { tsdoc },
        rules: { 'tsdoc/syntax': 'warn' },
    },
];
```

The plugin exports a single rule, `syntax`, and no preset configs. Its README only shows the legacy setup, so this
flat form follows ESLint's standard plugin pattern. TODO: verify against a future eslint-plugin-tsdoc README that
documents flat config. With `typescript-eslint`'s `tseslint.config(...)`, add the same object to its list.

In a TSDoc-only config (no other lint rules), `eslint-disable` comments in the code that name other rules
(`react-hooks/exhaustive-deps`, …) are reported as unknown or unused. Either register those rule names as no-op rules
in a placeholder plugin (`{ rules: { 'exhaustive-deps': { create: () => ({}) } } }`) and set
`linterOptions: { reportUnusedDisableDirectives: 'off' }`, or set `linterOptions: { noInlineConfig: true }`. The
check script does the latter and reports only `tsdoc/syntax` findings.

## Legacy config (.eslintrc.*)

From the plugin README:

```js
module.exports = {
    plugins: ['@typescript-eslint/eslint-plugin', 'eslint-plugin-tsdoc'],
    parser: '@typescript-eslint/parser',
    rules: { 'tsdoc/syntax': 'warn' },
};
```

## tsdoc.json

Optional. Needed only for custom tags or to change which standard tags are supported. Put it next to `tsconfig.json`;
the loader walks up from each source file to the first folder with `tsconfig.json` or `package.json` and reads
`tsdoc.json` there. `assets/tsdoc.json` is a starter with no custom tags.

| Key | Use |
| --- | --- |
| `$schema` | `https://developer.microsoft.com/json-schemas/tsdoc/v0/tsdoc.schema.json` |
| `extends` | Other `tsdoc.json` files to mix in; local paths start with `./` (module resolution) |
| `tagDefinitions` | Custom tags: `tagName` (`@myTag`), `syntaxKind` (`block`, `modifier` or `inline`), `allowMultiple` |
| `supportForTags` | Turn individual tags on or off for the project's tools |
| `noStandardTags` | Start from no standard tags, then define each one |
| `supportedHtmlElements`, `reportUnsupportedHtmlElements` | Which HTML elements comments may use, and whether others are reported |

Never define a custom tag the user didn't ask for. TODO: verify the exact value shapes of `supportForTags` and
`supportedHtmlElements` in `tsdoc.schema.json` before writing them.

## Why is tsdoc/syntax failing?

The check prints TSDoc's message id with each finding (ids from `tsdoc/src/parser/TSDocMessageId.ts`):

| Message id | Usually means | Fix |
| --- | --- | --- |
| `tsdoc-param-tag-missing-hyphen` | `@param name description` | `@param name - description` |
| `tsdoc-param-tag-with-invalid-type` | A JSDoc `{type}` after `@param` | Remove the type; TypeScript has it |
| `tsdoc-undefined-tag` | A tag TSDoc doesn't know, such as `@return` or `@default`, or an undefined custom tag | Use the TSDoc tag (tags.md), or define the custom tag in `tsdoc.json` if the user wants it |
| `tsdoc-unsupported-tag` | A known tag the configuration turned off | Use another tag, or change `supportForTags` with the user's agreement |
| `tsdoc-malformed-inline-tag`, `tsdoc-inline-tag-missing-right-brace` | `{@link` without its `}` | Close the tag |
| `tsdoc-escape-right-brace`, `tsdoc-escape-greater-than` | A literal `}` or `>` in text | Escape it (`\}`, `\>`) or put it in backticks |
| `tsdoc-at-sign-in-word`, `tsdoc-malformed-tag-name` | A literal `@` that looks like a tag (an email address, a decorator name) | Escape it (`\@`) or put it in backticks |
| `tsdoc-missing-deprecation-message` | `@deprecated` with no text | Say why and what to use instead |
| `tsdoc-inheritdoc-incompatible-summary` | `{@inheritDoc}` plus a summary of its own | Remove the summary or the `{@inheritDoc}` |
| `error-loading-config-file`, `error-applying-config` (from the plugin, reported on line 1) | `tsdoc.json` can't be loaded or doesn't match the schema | Fix `tsdoc.json`; the message names the file and the problem |

Read the exact message before editing; fix the comment, never the rule configuration.

## Generating docs (optional)

- **TypeDoc** (`typedoc`): an HTML or Markdown API site from the TSDoc comments, for libraries and tools with a
  public API. Setup is a separate request.
- **API Extractor** (`@microsoft/api-extractor`): API reports and `.d.ts` rollups for published packages; it uses the
  release tags (tags.md).

Neither is needed for writing or checking comments.
