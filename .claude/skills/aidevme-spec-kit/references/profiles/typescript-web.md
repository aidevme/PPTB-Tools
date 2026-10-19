# Profile: TypeScript web

<!-- cspell:ignore speckit -->

Purpose: principles to offer as input to `/speckit-constitution` for TypeScript web projects.

## Principles

1. **Strict TypeScript.** `strict` is on; no `any` and no unchecked casts in new code without a comment saying why.
2. **Tests for new logic.** Every new function or behavior with logic has a test; the tasks name it.
3. **No secrets in code.** Keys, tokens and connection strings come from configuration, never from source or
   committed files.
4. **The repository's lint and format rules apply.** New code passes the existing lint, format and build scripts;
   no new rule exceptions without a reason in the plan.
5. **Accessible UI.** Interactive elements have accessible names, work with the keyboard, have a visible focus
   state, and meet contrast requirements in every supported theme.

## How the plan uses it

`/speckit-plan` checks the plan against these principles ([plan.md](../plan.md)): the plan names the test approach
and the scripts that verify the change (for example `npm run build` and `npm test`).
