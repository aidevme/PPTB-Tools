# TSDoc tags

<!-- cspell:ignore tsdoc jsxfrag jsxruntime jsximportsource -->

Purpose: every standard TSDoc tag, when to use it, and one minimal example. The list and each tag's kind and
standardization group come from `tsdoc/src/details/StandardTags.ts` (microsoft/tsdoc `76dcd8e`, 2026-10-18).

- **Kinds:** a **block** tag starts a section and must be first on its line; a **modifier** tag is a flag with no
  content; an **inline** tag is written `{@tag …}` inside text.
- **Groups:** **Core** tags are supported by every TSDoc tool; **Extended** tags are optional for tools;
  **Discretionary** tags have a standard syntax but tool-specific meaning.
- **★** marks the tags this skill normally writes. Any other tag needs a reason, and a tag that isn't in this list
  needs a `tsdoc.json` definition (see setup.md).

## Block tags

| Tag | Group | Use for | Example |
| --- | --- | --- | --- |
| ★ `@param` | Core | A function or method parameter (repeat per parameter) | `@param path - Relative to the project.` |
| ★ `@returns` | Core | What a function returns | `@returns The written file count.` |
| ★ `@remarks` | Core | Detail beyond the summary | `@remarks Runs in a hidden terminal.` |
| ★ `@typeParam` | Core | A generic type parameter (repeat per parameter) | `@typeParam T - The item type.` |
| ★ `@deprecated` | Core | Marks the API deprecated; say what to use instead | `@deprecated Use {@link save} instead.` |
| `@privateRemarks` | Core | Notes for maintainers that published docs leave out | `@privateRemarks Keep in sync with the CLI.` |
| ★ `@throws` | Extended | An error the caller should handle (repeat per error) | `@throws {@link HttpError} When offline.` |
| ★ `@example` | Extended | A usage example; the rest of its first line is the title, then a fenced block | `@example Basic use` + a ` ```ts ` block |
| ★ `@defaultValue` | Extended | The default of an optional property or setting | `@defaultValue 500` |
| `@see` | Extended | A related item to read | `@see {@link exportFiles}` |
| `@decorator` | Extended | Records a decorator in docs generated from `.d.ts`, which drop decorators (repeat per decorator) | `@decorator @sealed` |
| `@jsx` | Extended | A JSX pragma for the compiler, recognized so TSDoc doesn't report it | `@jsx h` |
| `@jsxRuntime` | Extended | The JSX runtime pragma | `@jsxRuntime automatic` |
| `@jsxFrag` | Extended | The JSX fragment pragma | `@jsxFrag Fragment` |
| `@jsxImportSource` | Extended | The JSX import source pragma | `@jsxImportSource preact` |

## Modifier tags

| Tag | Group | Use for |
| --- | --- | --- |
| `@packageDocumentation` | Core | The comment documents the whole package (first doc comment of the entry point) |
| `@eventProperty` | Extended | A property that returns an event object to subscribe to |
| `@override` | Extended | Overrides a base member; prefer TypeScript's `override` keyword in source |
| `@readonly` | Extended | Treat as read-only in docs even though the type allows writes |
| `@sealed` | Extended | Don't extend this class, or don't override this member |
| `@virtual` | Extended | Subclasses may override this member |
| `@public` | Discretionary | Release tag: stable public API |
| `@beta` | Discretionary | Release tag: preview API that may change |
| `@alpha` | Discretionary | Release tag: early preview, not for production |
| `@experimental` | Discretionary | Same meaning as `@beta` |
| `@internal` | Discretionary | Release tag: not part of the public API, even if exported |

**Release tags** (`@public`, `@beta`, `@alpha`, `@experimental`, `@internal`) only make sense in packages that publish
an API (npm libraries, shared packages), usually with API Extractor. Don't add them to application code unless the
repository already uses them.

## Inline tags

| Tag | Group | Use for | Example |
| --- | --- | --- | --- |
| ★ `{@link}` | Core | A link to a declaration or URL, optionally with a label | `{@link FileStatus \| the statuses}` |
| `{@label}` | Core | Names an overload or member so a `{@link}` declaration reference can target it | `{@label WITH_OPTIONS}` |
| `{@inheritDoc}` | Extended | Copies the documentation of another declaration | `{@inheritDoc Base.save}` |

A comment that uses `{@inheritDoc}` has no summary or `@remarks` of its own; those are inherited.

## Not TSDoc

These JSDoc tags aren't in the TSDoc standard; `tsdoc/syntax` reports them in TypeScript files:

| JSDoc | TSDoc instead |
| --- | --- |
| `@return` | `@returns` |
| `@param {Type} name` | `@param name - …` (the type comes from TypeScript) |
| `@default` | `@defaultValue` |
| `@exception` | `@throws` |
| `@type`, `@typedef`, `@property` | TypeScript types and interfaces, with a comment per property |
