# React components, props and hooks

<!-- cspell:ignore tsdoc -->

Purpose: what to document on React components, their props, hooks and context providers. The general rules in
rules.md still apply.

## Components

Say what the component shows and does from the user's point of view, and any side effects (data loading,
subscriptions, writes, focus changes). Don't describe the markup.

```tsx
// Bad: restates the name and the JSX
/** PathChip component that renders a span and a button. */

// Good
/**
 * A path shortened in the middle, with the full path in a tooltip and a copy button. Renders a fragment, so the
 * parent decides the layout.
 */
export function PathChip(props: PathChipProps) { … }
```

## Props

Document the props interface, one comment per prop, and not the destructuring in the function signature.

```tsx
/** Props for {@link PathChip}. */
export interface PathChipProps {
    /** The full path to show and copy. */
    path: string;
    /**
     * Longest text shown before the middle is shortened, in characters.
     * @defaultValue 48
     */
    maxLength?: number;
    /** Called with the full path when the copy button is clicked. */
    onCopy: (path: string) => void;
}
```

- **Callbacks:** when they're called and with what; whether they're called on mount.
- **Controlled and uncontrolled pairs** (`value`/`defaultValue`, `open`/`onOpenChange`): say which prop controls the
  state and what happens when it's left out.
- **`children` and render props:** what's expected and where it's rendered.
- **Defaults:** `@defaultValue` matching the default in the destructuring or `defaultProps`.

## Hooks

Cover the inputs, the return shape, what makes it re-render or re-run, and cleanup.

```ts
/**
 * Loads the tables of the active connection and reloads them when the connection changes.
 * @param connection - The active connection; nothing loads while it's `null`.
 * @returns `tables` (empty until loaded), `loading`, and `error` (a user-facing message, or `null`).
 * @remarks Cancels the pending request when the connection changes or the component unmounts.
 */
export function useTables(connection: Connection | null): UseTablesResult { … }
```

- Document the returned object's properties on its named type when it has more than two or three.
- Say which arguments must be stable (memoized) to avoid repeated effects.

## Context providers

Document the provider (what it supplies and where to place it), the context value type (each property), and the
hook that reads it, including what happens when it's used outside the provider.

## Wrappers around third-party components

Document your wrapper's own props and behavior, not the library's. For props passed straight through, link to the
library's docs once on the props type instead of copying them.

## Skip

- Internal sub-components that aren't exported.
- Styles hooks and class-name constants, unless their use isn't obvious.
- Prop comments that only restate the prop name.
