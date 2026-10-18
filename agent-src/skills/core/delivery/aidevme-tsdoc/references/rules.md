# Writing rules

<!-- cspell:ignore tsdoc -->

Purpose: how to write each TSDoc comment, with before/after examples. Applies to `.ts`, `.tsx`, `.mts` and `.cts`.

## Summary line

One sentence, present tense, third person, ending with a period. Start with what the symbol does or is.

```ts
// Bad: restates the name, imperative, no period
/** get user */
// Good
/** Returns the signed-in user, or `undefined` before sign-in completes. */
```

Add a blank line, then `@remarks` for anything beyond one sentence: rules, edge cases, performance, history.

## When to leave a comment out

No comment beats a comment that only repeats the name and the type. Skip it when the name and signature already
say everything:

```ts
// Adds nothing: remove it rather than "documenting" it
/** The id. */
id: string;
```

Document it once something isn't obvious: units, ranges, who sets it, what `undefined` means.

## Types belong to TypeScript

```ts
// Bad: JSDoc types and a restated type
/**
 * @param {string} userId The user id string
 * @return {Promise<User>} The user
 */
// Good
/**
 * Loads a user from the directory.
 * @param userId - Azure AD object id; case-insensitive.
 * @returns The user, with groups expanded.
 */
```

`@param name - description` always has the hyphen. `@returns` (never `@return`) describes the value, not its type.

## Optional parameters

Say what happens when the argument is left out, not that it's optional (the `?` already says that).

```ts
/**
 * Formats a date for the status bar.
 * @param date - The moment to format.
 * @param locale - BCP 47 tag; the browser's locale when omitted.
 */
```

## Object parameters

Document the properties on the named type, one comment per property, and refer to the type from the function.
Don't repeat each property in `@param`.

```ts
/** Options for {@link exportFiles}. */
export interface ExportOptions {
    /** Folder to write to, relative to the project. */
    outputDir: string;
    /**
     * Overwrite files that already exist.
     * @defaultValue false
     */
    overwrite?: boolean;
}

/**
 * Writes the generated files to disk.
 * @param options - Where and how to write; see {@link ExportOptions}.
 */
export function exportFiles(options: ExportOptions): Promise<void>;
```

## Async functions

Say what the promise resolves to, and when it rejects.

```ts
/**
 * Fetches the table metadata.
 * @returns Resolves to the tables the user can read, sorted by display name.
 * @throws {@link HttpError} When the request fails; `status` holds the HTTP status.
 */
```

## Errors

One `@throws` per error the caller should handle, saying when it happens. Skip programming errors the caller can't
recover from.

## Generics

```ts
/**
 * Returns the first item that matches, or `undefined`.
 * @typeParam T - The item type.
 * @param items - Items to search, in order.
 * @param predicate - Returns `true` for the item to pick.
 */
export function findFirst<T>(items: readonly T[], predicate: (item: T) => boolean): T | undefined;
```

## Overloads

Document each overload signature separately; the implementation signature gets no comment.

## Callbacks and events

For a callback parameter or prop, say when it's called and with what. For an event property, add `@eventProperty`
(see tags.md).

```ts
/** Called after the file list changes, with the new list; not called for the initial load. */
onChange?: (files: readonly string[]) => void;
```

## Enums

A summary on the enum, and a comment on every member whose meaning isn't obvious from its name.

```ts
/** What Generate will do with a file. */
export enum FileStatus {
    /** Not on disk yet; Generate creates it. */
    New = 'new',
    /** On disk with different content; Generate overwrites it. */
    Changed = 'changed',
}
```

## Classes

- The class comment says what an instance represents and how it's meant to be used.
- The constructor comment says what it needs and any side effects; document its parameters with `@param`.
- Public properties, getters and setters get a comment when their meaning isn't obvious. Document a getter/setter
  pair once, on the getter.
- Prefer TypeScript's `override` keyword; the `@override` tag is for docs generated from `.d.ts` files.

## Deprecation

`@deprecated` is a block tag: give the reason and the replacement.

```ts
/** @deprecated Use {@link exportFiles} instead; this ignores `overwrite`. */
```

## Barrel files and re-exports

Don't comment `export { … } from './x'` lines; the comment lives on the original declaration. A barrel `index.ts`
can carry the module comment (below).

## Module documentation

A package's entry point can open with a comment tagged `@packageDocumentation`, describing the package as a whole.
It must be the first doc comment in the file and not attached to a declaration.

```ts
/**
 * Generates early-bound TypeScript types from Dataverse metadata.
 * @packageDocumentation
 */
```

## Cross-references

Use `{@link Symbol}` or `{@link Symbol | label}` for other declarations, and `{@link https://example.com | label}`
for URLs. Use backticks for code that isn't a declaration (`undefined`, `"new"`).

## Defaults

New comments use `@defaultValue` for optional properties and settings. Existing comments that state the default in
prose ("Defaults to `plain`.") are correct; keep them (review reports them as `info` only).
