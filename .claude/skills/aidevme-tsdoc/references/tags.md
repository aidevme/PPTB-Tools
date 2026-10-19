# TSDoc tags

<!-- cspell:ignore tsdoc jsxfrag jsxruntime jsximportsource -->

Purpose: every standard TSDoc tag, when to use it, and one minimal example. The list and each tag's kind and
standardization group come from `tsdoc/src/details/StandardTags.ts` (microsoft/tsdoc `76dcd8e`, 2026-10-18).

- **Kinds:** a **block** tag starts a section and must be first on its line; a **modifier** tag is a flag with no
  content; an **inline** tag is written `{@tag …}` inside text.
- **Groups:** **Core** tags are supported by every TSDoc tool; **Extended** tags are optional for tools;
  **Discretionary** tags have a standard syntax but tool-specific meaning.
- **Reference:** each tag links to its page on [tsdoc.org](https://tsdoc.org/) (syntax kind, group, description
  and an example), checked on 2026-10-19. The four `@jsx…` pragmas have no page there.
- **★** marks the tags this skill normally writes. Any other tag needs a reason, and a tag that isn't in this list
  needs a `tsdoc.json` definition (see setup.md).

## Block tags

| Tag | Group | Use for | Example |
| --- | --- | --- | --- |
| ★ [`@param`](https://tsdoc.org/pages/tags/param/) | Core | A function or method parameter (repeat per parameter) | `@param path - Relative to the project.` |
| ★ [`@returns`](https://tsdoc.org/pages/tags/returns/) | Core | What a function returns | `@returns The written file count.` |
| ★ [`@remarks`](https://tsdoc.org/pages/tags/remarks/) | Core | Detail beyond the summary | `@remarks Runs in a hidden terminal.` |
| ★ [`@typeParam`](https://tsdoc.org/pages/tags/typeparam/) | Core | A generic type parameter (repeat per parameter) | `@typeParam T - The item type.` |
| ★ [`@deprecated`](https://tsdoc.org/pages/tags/deprecated/) | Core | Marks the API deprecated; say what to use instead | `@deprecated Use {@link save} instead.` |
| [`@privateRemarks`](https://tsdoc.org/pages/tags/privateremarks/) | Core | Notes for maintainers that published docs leave out | `@privateRemarks Keep in sync with the CLI.` |
| ★ [`@throws`](https://tsdoc.org/pages/tags/throws/) | Extended | An error the caller should handle (repeat per error) | `@throws {@link HttpError} When offline.` |
| ★ [`@example`](https://tsdoc.org/pages/tags/example/) | Extended | A usage example; the rest of its first line is the title, then a fenced block | `@example Basic use` + a ` ```ts ` block |
| ★ [`@defaultValue`](https://tsdoc.org/pages/tags/defaultvalue/) | Extended | The default of an optional property or setting | `@defaultValue 500` |
| [`@see`](https://tsdoc.org/pages/tags/see/) | Extended | A related item to read | `@see {@link exportFiles}` |
| [`@decorator`](https://tsdoc.org/pages/tags/decorator/) | Extended | Records a decorator in docs generated from `.d.ts`, which drop decorators (repeat per decorator) | `@decorator @sealed` |
| `@jsx` | Extended | A JSX pragma for the compiler, recognized so TSDoc doesn't report it | `@jsx h` |
| `@jsxRuntime` | Extended | The JSX runtime pragma | `@jsxRuntime automatic` |
| `@jsxFrag` | Extended | The JSX fragment pragma | `@jsxFrag Fragment` |
| `@jsxImportSource` | Extended | The JSX import source pragma | `@jsxImportSource preact` |

## Modifier tags

| Tag | Group | Use for |
| --- | --- | --- |
| [`@packageDocumentation`](https://tsdoc.org/pages/tags/packagedocumentation/) | Core | The comment documents the whole package (first doc comment of the entry point) |
| [`@eventProperty`](https://tsdoc.org/pages/tags/eventproperty/) | Extended | A property that returns an event object to subscribe to |
| [`@override`](https://tsdoc.org/pages/tags/override/) | Extended | Overrides a base member; prefer TypeScript's `override` keyword in source |
| [`@readonly`](https://tsdoc.org/pages/tags/readonly/) | Extended | Treat as read-only in docs even though the type allows writes |
| [`@sealed`](https://tsdoc.org/pages/tags/sealed/) | Extended | Don't extend this class, or don't override this member |
| [`@virtual`](https://tsdoc.org/pages/tags/virtual/) | Extended | Subclasses may override this member |
| [`@public`](https://tsdoc.org/pages/tags/public/) | Discretionary | Release tag: stable public API |
| [`@beta`](https://tsdoc.org/pages/tags/beta/) | Discretionary | Release tag: preview API that may change |
| [`@alpha`](https://tsdoc.org/pages/tags/alpha/) | Discretionary | Release tag: early preview, not for production |
| [`@experimental`](https://tsdoc.org/pages/tags/experimental/) | Discretionary | Same meaning as `@beta` |
| [`@internal`](https://tsdoc.org/pages/tags/internal/) | Discretionary | Release tag: not part of the public API, even if exported |

**Release tags** (`@public`, `@beta`, `@alpha`, `@experimental`, `@internal`) only make sense in packages that publish
an API (npm libraries, shared packages), usually with API Extractor. Don't add them to application code unless the
repository already uses them. A member without a release tag inherits its container's: in tsdoc.org's
[`@alpha` example](https://tsdoc.org/pages/tags/alpha/), a `@public` class has an `@alpha` getter and an untagged
getter that stays `@public`. Tooling may trim `@alpha` and `@beta` items from a public release.

## Inline tags

| Tag | Group | Use for | Example |
| --- | --- | --- | --- |
| ★ [`{@link}`](https://tsdoc.org/pages/tags/link/) | Core | A link to a declaration or URL, optionally with a label | `{@link FileStatus \| the statuses}` |
| [`{@label}`](https://tsdoc.org/pages/tags/label/) | Core | Names an overload or member so a `{@link}` declaration reference can target it | `{@label WITH_OPTIONS}` |
| [`{@inheritDoc}`](https://tsdoc.org/pages/tags/inheritdoc/) | Extended | Copies the documentation of another declaration | `{@inheritDoc Base.save}` |

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
