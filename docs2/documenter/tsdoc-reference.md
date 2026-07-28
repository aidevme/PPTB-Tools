# TSDoc Reference

TSDoc is a standard for doc comments in TypeScript source code. It lets different tools (API Extractor, API Documenter, ESLint plugins, IDEs) parse the same comment without conflicting with each other's markup.

**Sources:** [tsdoc.org](https://tsdoc.org/) · [github.com/microsoft/tsdoc](https://github.com/microsoft/tsdoc)

---

## Comment structure

A TSDoc comment is a `/** … */` block placed immediately before the declaration it describes. The first prose paragraph is the **summary**. Everything else is optional.

```ts
/**
 * Brief one-line summary of the API item.
 *
 * @remarks
 * Extended explanation that appears only on the detail page,
 * not on index/overview pages.
 *
 * @param x - The first input number
 * @param y - The second input number
 * @returns The arithmetic mean of `x` and `y`
 *
 * @beta
 */
function getAverage(x: number, y: number): number {
  return (x + y) / 2.0;
}
```

Rules:
- The summary ends at the first blank line or the first block tag.
- CommonMark Markdown is supported inside comment text.
- Inline tags like `{@link}` can appear anywhere inside prose.

---

## Tag categories

| Category | Description | Example |
|---|---|---|
| **Block tag** | Starts a new section; takes prose after it | `@param`, `@returns`, `@remarks` |
| **Modifier tag** | Appears alone on its own line; no content | `@alpha`, `@public`, `@internal` |
| **Inline tag** | Embedded inside prose with `{@…}` braces | `{@link}`, `{@inheritDoc}` |

---

## Core tags

All conforming tools must recognise and support these tags. The `@microsoft/tsdoc` parser provides dedicated APIs for accessing their content.

---

### `@param`

**Syntax kind:** Block — **Standardization:** Core

Documents a function or method parameter. Use one tag per parameter. Format: `@param <name> - <description>`.

```ts
/**
 * Returns the average of two numbers.
 *
 * @param x - The first input number
 * @param y - The second input number
 * @returns The arithmetic mean of `x` and `y`
 */
function getAverage(x: number, y: number): number {
  return (x + y) / 2.0;
}
```

**Related tags:** `@returns`, `@typeParam`

---

### `@returns`

**Syntax kind:** Block — **Standardization:** Core

Documents the return value of a function. Should describe the semantic meaning and any relevant constraints on the returned value.

```ts
/**
 * @param x - The first input number
 * @param y - The second input number
 * @returns The arithmetic mean of `x` and `y`
 */
function getAverage(x: number, y: number): number { … }
```

**Related tags:** `@param`

---

### `@remarks`

**Syntax kind:** Block — **Standardization:** Core

Separates the brief summary from extended explanation. Documentation index pages display only the summary; detail pages show both summary and remarks.

- The summary ends where `@remarks` begins.
- `@remarks` is optional — omit it if the summary alone is sufficient.

```ts
/**
 * Returns the average of two numbers.
 *
 * @remarks
 * This method is part of the {@link core-library#Statistics | Statistics subsystem}.
 * Prefer this over manual addition to avoid floating-point accumulation.
 */
function getAverage(x: number, y: number): number { … }
```

**Related tags:** `@privateRemarks`

---

### `@privateRemarks`

**Syntax kind:** Block — **Standardization:** Core

Marks documentation content as internal-only. Tools **must** exclude the entire section from public API reference websites, generated `.d.ts` files, and any other public-facing output. Use alongside other public-facing tags in the same comment.

```ts
/**
 * Computes the health score for a solution.
 *
 * @remarks
 * Scores are clamped to [0, 100].
 *
 * @privateRemarks
 * The weighting constants were agreed with the PM in the Q3 review.
 * Do not change without re-running the benchmark suite.
 */
export function computeHealthScore(ctx: SolutionContext): HealthScore { … }
```

**Related tags:** `@remarks`

---

### `@deprecated`

**Syntax kind:** Block — **Standardization:** Core

Marks an API item as no longer supported and subject to removal in a future release. Always follow the tag with a sentence recommending an alternative.

- Applies **recursively** — deprecating a class also marks all its members as deprecated.
- Intended for entire API items, not individual parameters.

```ts
/**
 * The base class for controls that can be rendered.
 *
 * @deprecated Use the new {@link Control} base class instead.
 */
export class VisualControl { … }
```

**Related tags:** `@alpha`, `@beta`, `@experimental`

---

### `@typeParam`

**Syntax kind:** Block — **Standardization:** Core

Documents a generic type parameter. Follows the same `name - description` pattern as `@param`.

```ts
/**
 * @typeParam T - Type of objects the list contains
 */
type List<T> = Array<T>;

/**
 * @typeParam B - Response body shape
 * @typeParam H - Response headers shape
 */
interface HttpResponse<B, H> {
  body: B;
  headers: H;
  statusCode: number;
}
```

**Related tags:** `@param`

---

### `@packageDocumentation`

**Syntax kind:** Modifier — **Standardization:** Core

Identifies a doc comment that describes an entire NPM package rather than a specific API item.

- Must be the **first** `/** … */` comment in the package's entry-point `.d.ts` file.
- A comment containing this tag must not describe any individual API item.

```ts
/**
 * A library for building widgets.
 *
 * @remarks
 * Defines the {@link IWidget} interface and {@link Widget} class.
 *
 * @packageDocumentation
 */

/**
 * Interface implemented by all widgets.
 * @public
 */
export interface IWidget {
  render(): void;
}
```

**Related tags:** `@alpha`, `@beta`, `@public`

---

### `{@link}`

**Syntax kind:** Inline — **Standardization:** Core

Creates a hyperlink to another API item or an external URL. Supply display text after a pipe (`|`). Supports static/instance member selectors, constructor references, label selectors for overloads, and quoted identifiers for names containing special characters.

```ts
// External URL
{@link https://tsdoc.org/}

// Same-package symbol
{@link Button}

// Display text
{@link Button | the Button class}

// Scoped package
{@link @microsoft/my-control-library/lib/Button#Button | text}

// Namespace member
{@link my-control-library#controls.Button | text}

// Class member
{@link controls.Button.render | the render() method}

// Constructor
{@link controls.(Button:constructor) | the class constructor}

// Static vs instance selector
{@link MyClass.(myMethod:static)}

// Special characters in identifier
{@link restProtocol.IServerResponse."first-name"}
```

Full example in a comment:

```ts
/**
 * This method is part of the {@link core-library#Statistics | Statistics subsystem}.
 */
```

**Related tags:** `{@inheritDoc}`, `{@label}`

---

### `{@label}`

**Syntax kind:** Inline — **Standardization:** Core

Assigns a custom identifier to a declaration so it can be referenced in declaration reference notation. Particularly useful for unnamed or complex members such as index signatures, callable signatures, and constructors.

> **Note:** The `{@label}` notation has not been finalized (see GitHub issue #9).

```ts
interface InterfaceL1 {
  /** {@label STRING_INDEXER} */
  [key: string]: number;

  /** {@label NUMBER_INDEXER} */
  [key: number]: number;

  /** {@label FUNCTOR} */
  (source: string, subString: string): boolean;

  /** {@label CONSTRUCTOR} */
  new (s: string): InterfaceL1;
}

// Reference the labeled members with:
// {@link InterfaceL1.(:STRING_INDEXER)}
// {@link InterfaceL1.(:NUMBER_INDEXER)}
```

**Related tags:** `{@link}`

---

## Extended tags

Tools may or may not support extended tags. When a tool does support one, it must follow the standard's defined syntax and semantics.

---

### `@throws`

**Syntax kind:** Block — **Standardization:** Extended

Documents an exception type that a function or property may throw. Informational only — does not restrict what the function may actually throw.

- Use a **separate** `@throws` block for each exception type.
- It is suggested (but not required) to begin each block with a line containing only the exception name via `{@link}`.

```ts
/**
 * Retrieves metadata about a book from the catalogue.
 *
 * @param isbnCode - the ISBN number for the book
 * @returns the retrieved book object
 *
 * @throws {@link IsbnSyntaxError}
 * Thrown if the input is not a valid ISBN number.
 *
 * @throws {@link book-lib#BookNotFoundError}
 * Thrown if the ISBN is valid but no such book exists.
 *
 * @public
 */
function fetchBookByIsbn(isbnCode: string): Book { … }
```

**Related tags:** `@returns`, `@param`

---

### `@example`

**Syntax kind:** Block — **Standardization:** Extended

Marks a documentation section as a usage example. Text on the same line as `@example` becomes the example title; when omitted, tools number examples sequentially ("Example", "Example 2", …). Multiple `@example` blocks are permitted on a single item.

```ts
/**
 * @example Parsing a basic JSON file
 *
 * ```ts
 * const data = parse('{"key": "value"}');
 * console.log(data.key); // "value"
 * ```
 *
 * @example
 * ```ts
 * // Minimal usage — auto-titled "Example 2"
 * parse('{}');
 * ```
 */
function parse(input: string): unknown { … }
```

**Related tags:** `@remarks`, `@returns`, `@param`

---

### `@see`

**Syntax kind:** Block — **Standardization:** Extended

Creates a "See Also" list of references to related APIs or resources. Unlike JSDoc, TSDoc requires explicit `{@link}` tags for hyperlinks — plain text is valid but produces no clickable link.

- Each `@see` block becomes a separate bullet in the "See Also" section.
- Multiple `@see` blocks are permitted on a single item.

```ts
/**
 * Parses a URL string.
 *
 * @see {@link ParsedUrl} for the returned data structure
 * @see {@link https://tools.ietf.org/html/rfc1738 | RFC 1738} for syntax
 * @see your developer SDK for code samples
 * @param url - the string to be parsed
 * @returns the parsed result
 */
function parseURL(url: string): ParsedUrl { … }
```

**Related tags:** `{@link}`

---

### `@defaultValue`

**Syntax kind:** Block — **Standardization:** Extended

Documents the default value for a field or property. Applies only to fields or properties within `class` or `interface` declarations. Supports both single-line and multi-line descriptions.

```ts
/**
 * @defaultValue `WarningStyle.DialogBox`
 */
warningStyle: WarningStyle;

/**
 * @defaultValue
 * The default is `true` unless `WarningStyle.StatusMessage` was requested.
 */
showWarning: boolean;
```

**Related tags:** `@deprecated`, `@eventProperty`

---

### `@eventProperty`

**Syntax kind:** Modifier — **Standardization:** Extended

Marks a class or interface property as an event. Documentation tools may display such properties in a dedicated "Events" section rather than alongside regular properties.

- Applied to properties whose type represents an event object (e.g. `FrameworkEvent<T>`).
- The event-handling API (e.g. `addHandler()`, `removeHandler()`) is not standardised by TSDoc.

```ts
class MyClass {
  /**
   * Fired whenever the application navigates to a new page.
   * @eventProperty
   */
  public readonly navigatedEvent: FrameworkEvent<NavigatedEventArgs>;
}
```

---

### `@decorator`

**Syntax kind:** Block — **Standardization:** Extended

Documents ECMAScript decorators that are part of an API's contract. Because TypeScript's compiler does not include decorators in `.d.ts` output, this tag allows decorator expressions to be preserved in documentation comments. Quote the decorator expression in backticks. Use a separate `@decorator` tag for each decorator.

```ts
class Book {
  /**
   * The title of the book.
   * @decorator `@jsonSerialized`
   * @decorator `@jsonFormat(JsonFormats.Url)`
   */
  @jsonSerialized
  @jsonFormat(JsonFormats.Url)
  public website: string;
}
```

---

### `{@inheritDoc}`

**Syntax kind:** Inline — **Standardization:** Extended

Copies documentation from another API item into the current comment. The referenced item may be an unrelated class or an import from a separate NPM package.

**What is copied:**
- Summary section
- `@remarks` block
- `@param` blocks
- `@typeParam` blocks
- `@returns` block

**What is not copied:** `@defaultValue`, `@example`, and all other tags — add these explicitly after `{@inheritDoc}`.

**Constraint:** When `{@inheritDoc}` is used, the comment must not include its own summary or `@remarks` section.

> **Note:** The declaration reference notation for this tag has not been finalized (see GitHub issue #9).

```ts
export interface IWidget {
  /**
   * Draws the widget on the display surface.
   * @param x - the X position of the widget
   * @param y - the Y position of the widget
   */
  draw(x: number, y: number): void;
}

export class Button implements IWidget {
  /** {@inheritDoc IWidget.draw} */
  draw(x: number, y: number): void { … }

  /**
   * {@inheritDoc example-library#Serializer.writeFile}
   * @deprecated Use {@link example-library#Serializer.writeFile} instead.
   */
  save(): void { … }
}
```

**Related tags:** `{@link}`

---

### `@override`

**Syntax kind:** Modifier — **Standardization:** Extended

Explicitly marks a member function or property as redefining an inherited definition from a base class. Mirrors the `override` keyword in C# and Java.

- Base class definitions intended to be overridden should be marked `@virtual`.
- Prefer TypeScript's built-in `override` keyword when available; use this tag only when generating documentation from declaration files where the keyword is absent.
- Documentation tools may enforce consistency with `@virtual` and `@sealed`, but the TSDoc standard does not require it.

```ts
class Base {
  /** @virtual */
  public render(): void {}
}

class Child extends Base {
  /** @override */
  public render(): void { … }
}
```

**Related tags:** `@virtual`, `@sealed`

---

### `@sealed`

**Syntax kind:** Modifier — **Standardization:** Extended

Prevents inheritance or overriding. When applied to a class, subclasses cannot extend it. When applied to a method or property, subclasses cannot override it. Draws semantic inspiration from the `sealed` keyword in C# and Java.

- Documentation tools may enforce consistency with `@virtual` and `@override`, but the standard does not require it.

```ts
class Base {
  /** @virtual */
  public render(): void {}

  /** @sealed */
  public initialize(): void {}
}

class Child extends Base {
  /** @override */
  public render(): void { … }
  // initialize() cannot be overridden
}
```

**Related tags:** `@virtual`, `@override`

---

### `@virtual`

**Syntax kind:** Modifier — **Standardization:** Extended

Marks a class member (function or property) as overridable by subclasses. Conveys design intent without affecting runtime behaviour. Serves as documentation and linting guidance for maintainers reviewing inheritance hierarchies.

- Documentation tools may enforce consistent pairing with `@override` and `@sealed`, but the standard does not require it.

```ts
class Base {
  /** @virtual */
  public render(): void {}

  /** @sealed */
  public initialize(): void {}
}

class Child extends Base {
  /** @override */
  public render(): void { … }
}
```

**Related tags:** `@override`, `@sealed`

---

### `@readonly`

**Syntax kind:** Modifier — **Standardization:** Extended

Documents an API item as read-only for documentation purposes, even when the TypeScript type signature suggests otherwise. Useful for properties that have a setter which intentionally throws an error, bridging the gap between implementation and the intended API contract.

```ts
class Book {
  /**
   * The title of the book.
   * @readonly
   */
  public get title(): string {
    return this._title;
  }
  public set title(_value: string) {
    throw new Error('title is read-only');
  }
}
```

---

## Discretionary tags — release stage

Semantics are **implementation-specific** — the TSDoc standard standardises the syntax only, so tools that adopt the same tag name at least parse it consistently. Applied per-member; a member with no tag **inherits** the designation of its containing declaration.

| Tag | Meaning |
|---|---|
| `@public` | Stable, officially released API |
| `@beta` | Released experimentally; contract may change without notice |
| `@alpha` | In early development; not yet released to third parties |
| `@experimental` | Same semantics as `@beta`; used by tools without `@alpha` support |
| `@internal` | Not for third-party use; may be stripped from public release artifacts |

---

### `@public`

**Syntax kind:** Modifier — **Standardization:** Discretionary

Designates an API item as stable and officially released. Once marked `@public`, the API's signature carries backward-compatibility guarantees (typically following semantic versioning). Child members inherit `@public` from their containing class unless explicitly marked otherwise.

```ts
/**
 * Represents a book in the catalogue.
 * @public
 */
export class Book {
  /** Inherits @public from the class. */
  public get author(): string { … }

  /**
   * Internal implementation detail — overrides inherited @public.
   * @internal
   */
  public _title: string;
}
```

**Related tags:** `@alpha`, `@beta`, `@experimental`, `@internal`

---

### `@beta`

**Syntax kind:** Modifier — **Standardization:** Discretionary

Marks an API as released experimentally for the purpose of collecting feedback. The contract **may change without notice**, so consumers must not use it in production. Build tools may include `@beta` items in developer-preview releases while excluding them from stable artifacts.

```ts
/**
 * Represents a book in the catalogue.
 * @public
 */
export class Book {
  /**
   * The title of the book.
   * @beta
   */
  public get title(): string { … }

  /** Inherits @public from the class. */
  public get author(): string { … }
}
```

**Related tags:** `@alpha`, `@experimental`, `@internal`, `@public`

---

### `@alpha`

**Syntax kind:** Modifier — **Standardization:** Discretionary

Marks an API item as being in early development. The item is intended for eventual third-party use but has not yet been officially released. Build tools such as [API Extractor](https://api-extractor.com/) may exclude `@alpha`-marked declarations from public release artifacts (`.d.ts` trimming).

- Applied per-member. A class may be `@public` while individual members carry `@alpha`.
- A member with no release tag **inherits** the tag of its containing declaration.
- Semantics are **implementation-specific** — consult your documentation tool for exact trimming behaviour.

```ts
/**
 * Represents a book in the catalogue.
 * @public
 */
export class Book {
  /**
   * The title of the book.
   * @alpha
   */
  public get title(): string { … }

  /** Inherits @public from the class. */
  public get author(): string { … }
}
```

**Related tags:** `@beta` (later pre-release) · `@experimental` · `@internal` · `@public`

---

### `@experimental`

**Syntax kind:** Modifier — **Standardization:** Discretionary

Carries the same semantics as `@beta`. Used by tools that do not support a distinct `@alpha` release stage. Marks API elements as unstable or exploratory, subject to change or removal.

```ts
export class Book {
  /** @experimental */
  public get title(): string { … }

  /** Inherits @public from the class. */
  public get author(): string { … }
}
```

**Related tags:** `@alpha`, `@beta`, `@internal`, `@public`

---

### `@internal`

**Syntax kind:** Modifier — **Standardization:** Discretionary

Marks an API item as not intended for third-party use. Build tools may remove `@internal` declarations from public release artifacts. Certain packages within the same product may still be permitted to access them.

- Can override an inherited `@public` designation from a containing class.

```ts
/**
 * Represents a book in the catalogue.
 * @public
 */
export class Book {
  /** Inherits @public from the class. */
  public get author(): string { … }

  /**
   * Internal backing field — overrides inherited @public.
   * @internal
   */
  public _title: string;
}
```

**Related tags:** `@alpha`, `@beta`, `@experimental`, `@public`

---

## Declaration references

The `{@link}` and `{@inheritDoc}` tags use a **declaration reference** syntax to identify API items across packages.

| Pattern | Example |
|---|---|
| Local symbol | `{@link MyClass}` |
| Package + symbol | `{@link package-name#MyClass}` |
| Scoped package | `{@link @scope/package#MyClass}` |
| Namespace member | `{@link package#ns.MyClass}` |
| Class member | `{@link package#ns.MyClass.method}` |
| Constructor | `{@link package#ns.(MyClass:constructor)}` |
| Static selector | `{@link MyClass.(myMethod:static)}` |
| Special chars | `{@link restProtocol.IServerResponse."first-name"}` |
| Display text | `{@link MyClass \| custom display text}` |

---

## Design principles

TSDoc is designed specifically for TypeScript while staying as close as possible to familiar JSDoc notation. The specification targets seven goals:

1. **TypeScript-focused** — Built for TypeScript's type system; aligns with JSDoc conventions where possible.
2. **CommonMark Markdown** — Doc comment prose supports standard Markdown (bold, code blocks, headings, tables). The spec explicitly resolves Markdown's context-dependent grammar ambiguities.
3. **Standardized core tags** — Tags like `@param` and `@returns` have identical meaning and syntax across all conforming tools.
4. **Extensibility** — Tools define domain-specific custom tags without conflicting with the core standard.
5. **Interoperability** — Unsupported custom tags do not break a parser; Markdown ambiguities are eliminated so tools produce consistent output.
6. **Multi-package compatibility** — Declaration reference syntax (`{@link}`, `{@inheritDoc}`) works portably across packages; `package.json` metadata signals TSDoc usage.
7. **Open standard** — Community-driven specification; contributions are welcome.

### `@microsoft/tsdoc` library goals

The reference parser implementation adds three further objectives:

- **Parsing flexibility** — Supports strict, lax, and transitional parsing modes.
- **Bidirectional processing** — Converts comments to an AST *and* can regenerate modified comments from the AST.
- **Lightweight** — Self-contained, TypeScript-compiler-independent; accepts plain comment text with no additional tooling required.

---

## Standardization groups

Every tag is assigned to one of three standardization groups that describe the level of support tools are expected to provide.

### Core

`Standardization.Core`

Essential to the TSDoc specification. All conforming documentation tools **must** recognize and support core tags. The `@microsoft/tsdoc` parser provides dedicated APIs for accessing core tag content (e.g. `modifierTagSet.isInternal()`).

Core tags: `@param`, `@returns`, `@remarks`, `@privateRemarks`, `@deprecated`, `@typeParam`, `@packageDocumentation`, `{@link}`, `{@label}`

### Extended

`Standardization.Extended`

Optional additions to TSDoc. Tools **may or may not** support extended tags. When a tool does support an extended tag, it **must** follow the standard's defined syntax and semantics.

Extended tags: `@decorator`, `@defaultValue`, `@eventProperty`, `@example`, `{@inheritDoc}`, `@override`, `@readonly`, `@sealed`, `@see`, `@throws`, `@virtual`

### Discretionary

`Standardization.Discretionary`

Optional tags whose **semantics are implementation-specific** — each tool may interpret them differently. The standard defines their syntax only, so that if two tools adopt the same tag name they at least parse it consistently and don't break each other's output.

Discretionary tags: `@alpha`, `@beta`, `@experimental`, `@public`, `@internal`

---

## Tag kinds — parsing rules

### Block tags

- Must appear as the **first element on a line**.
- In normalized form a block tag occupies its own line.
- All text following a block tag — up to the start of the next block tag or modifier tag — is that tag's **tag content**. Content may include Markdown and inline tags.
- Text before the first block tag becomes the **summary** section.
- `@example` and `@throws` assign special meaning to their first line (used as a section title).

```
/**
 * Summary section.
 *
 * @remarks
 * This is the @remarks block content.
 * It continues until the next block tag.
 *
 * @example Title text
 * Code here…
 */
```

### Modifier tags

- Parsed as block tags but **expected to have empty tag content**.
- In normalized form, modifier tags appear together on a single line at the bottom of the comment.
- If content follows a modifier tag, parsers may discard it or associate it with the preceding block tag for backwards compatibility.

```ts
/**
 * Draws the widget.
 * @public @sealed
 */
```

### Inline tags

- Appear **inside** Markdown prose, not on their own line.
- Always surrounded by curly braces: `{@tagName …}`.
- Cannot contain nested `{` or `}` characters.

```ts
/**
 * See {@link https://tsdoc.org/ | TSDoc website} for details.
 * Use {@link Button | the Button class} to render controls.
 */
```

**General rule:** all tag names begin with `@` followed by camelCase ASCII letters only.

---

## Using TSDoc in practice

TSDoc is not a standalone documentation generator — it is a parsing engine used by other tools. Three ways to use it:

### 1. Validate with ESLint

The fastest way to catch malformed comments during development. See the [eslint-plugin-tsdoc](#eslint-plugin-tsdoc) section below.

### 2. Preview with the Playground

Paste any `/** … */` comment into the [TSDoc Playground](https://tsdoc.org/play/) to see how a compatible tool would parse and render it. Useful for verifying complex `{@link}` declaration references or `@example` blocks before committing.

### 3. Parse programmatically

Use `@microsoft/tsdoc` when building a tool that needs to read or transform doc comments — for example a documentation generator, a lint rule, or an API extraction pipeline.

---

## Packages

### `@microsoft/tsdoc`

The reference parser implementation. Accepts raw comment text and produces a structured AST.

**Installation:**
```
npm install @microsoft/tsdoc
```

**Core API classes:**

| Class | Purpose |
|---|---|
| `TSDocParser` | Entry point; parses a comment string into a `ParserContext` |
| `ParserContext` | Holds the parsed AST and any parser messages (errors/warnings) |

**Basic usage:**
```ts
import { TSDocParser, ParserContext } from '@microsoft/tsdoc';

const tsdocParser = new TSDocParser();
const parserContext: ParserContext = tsdocParser.parseString(docComment);
```

**Key features:**

- **Source tracking** — every token retains precise source coordinates, enabling accurate error messages and syntax highlighting in IDEs.
- **AST output** — structured tree supports rendering to HTML or any other format.
- **Custom tag support** — register domain-specific tags via `TSDocParserConfiguration`.
- **Error filtering** — selectively suppress or escalate parser messages.
- **Modifier detection** — helper methods such as `modifierTagSet.isInternal()` check for standardized modifier tags without manual string comparison.

Code examples: [`api-demo/`](https://github.com/microsoft/tsdoc/tree/main/api-demo) folder in the GitHub repository.

---

### `@microsoft/tsdoc-config`

Optional add-on that loads `tsdoc.json` configuration files. Separated from the core package because it depends on Node.js and `ajv`; the core parser remains self-contained.

**Installation:**
```
npm install @microsoft/tsdoc-config
```

**`tsdoc.json` location:** the loader walks up the directory tree looking for a folder that contains `tsconfig.json` or `package.json`, then attempts to load `tsdoc.json` from that location.

**Schema:** `https://developer.microsoft.com/json-schemas/tsdoc/v0/tsdoc.schema.json`

**Defining custom tags:**
```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/tsdoc/v0/tsdoc.schema.json",
  "tagDefinitions": [
    {
      "tagName": "@myTag",
      "syntaxKind": "modifier"
    },
    {
      "tagName": "@myBlockTag",
      "syntaxKind": "block"
    }
  ]
}
```

`syntaxKind` must be one of `"block"`, `"modifier"`, or `"inline"`.

**Sharing config across projects** via `extends`:
```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/tsdoc/v0/tsdoc.schema.json",
  "extends": ["./shared/tsdoc-base.json"]
}
```

Local paths must start with `./` — bare names are resolved as npm package names.

**Programmatic usage:**
```ts
import { TSDocConfigFile } from '@microsoft/tsdoc-config';
import { TSDocParser }     from '@microsoft/tsdoc';

const configFile = TSDocConfigFile.loadForFolder(myFolder);
if (configFile.hasErrors) {
  configFile.logMessages();
}

const tsdocParser = new TSDocParser();
configFile.configureParser(tsdocParser);
```

---

### `eslint-plugin-tsdoc`

Validates that TypeScript doc comments conform to the TSDoc specification as an ESLint rule.

**Installation:**
```
npm install --save-dev eslint-plugin-tsdoc
```

**Configuration (`.eslintrc.js`):**
```js
module.exports = {
  plugins: ['@typescript-eslint/eslint-plugin', 'eslint-plugin-tsdoc'],
  extends: ['plugin:@typescript-eslint/recommended'],
  parser: '@typescript-eslint/parser',
  rules: {
    'tsdoc/syntax': 'warn',   // or 'error' for stricter enforcement
  },
};
```

**Available rule:**

| Rule | Description |
|---|---|
| `tsdoc/syntax` | Validates doc comment syntax against the TSDoc specification |

Prerequisites: ESLint configured for TypeScript (`@typescript-eslint/parser` and `@typescript-eslint/eslint-plugin` installed).
