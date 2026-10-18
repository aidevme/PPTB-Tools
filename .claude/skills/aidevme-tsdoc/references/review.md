# Reviewing and fixing doc comments

<!-- cspell:ignore tsdoc -->

Purpose: audit existing comments (`review`), and fix them after confirmation (`fix`).

## Workflow

1. **Scope:** the files given, `--changed` (`git diff --name-only HEAD`), or a folder. Leave out generated files
   (SKILL.md safety rules).
2. **Run the check:** `node <skill>/scripts/check-tsdoc.mjs <files>`. Its findings are `error`s. Exit 2 means the
   check can't run: say "syntax check unavailable" in the report and offer setup.md.
3. **Read each public symbol** and its comment against the implementation, using the checklist below.
4. **Report** with the table below, most severe first, then a one-line count per severity.
5. **`review` stops here.** In `fix` mode, ask which findings to fix (all, errors and warnings, or listed ones),
   apply them as comment-only edits, re-run the check, and report what changed.

## Checklist

| Severity | Issue |
| --- | --- |
| error | `tsdoc/syntax` finding (malformed tag, missing `@param` hyphen, unknown tag, unclosed `{@link}`) |
| error | The comment contradicts the code: wrong parameter name, wrong return value, an error that's never thrown, outdated behavior |
| error | A `@param` for a parameter that doesn't exist, or a JSDoc `{type}` in a TypeScript file |
| warning | A public symbol (export, public class member, component props, hook) has no comment, or its behavior isn't obvious and the comment doesn't explain it |
| warning | The comment repeats the type or the name instead of describing behavior |
| warning | Wrong tag: `@return`, `@default`, `@exception`, a release tag in application code, a custom tag missing from `tsdoc.json` |
| warning | An async function that doesn't say what it resolves to, or an error the caller must handle without `@throws` |
| warning | `@deprecated` without a replacement |
| info | Style: summary not in the present tense or longer than one sentence, missing period, `@example` without a fenced block |
| info | A default written in prose where new comments would use `@defaultValue` (existing correct prose is fine) |

## Output

| File | Line | Symbol | Severity | Issue | Suggested fix |
| --- | --- | --- | --- | --- | --- |
| `src/services/plan.ts` | 42 | `writeCounts` | error | `@param plan` has no hyphen | `@param plan - The preview plan.` |
| `src/hooks/useProject.ts` | 18 | `useProject` | warning | No comment on an exported hook | Summary, `@param options`, `@returns` shape |
| `src/core/format.ts` | 7 | `shortenPath` | info | Summary starts with "This function" | "Shortens a path in the middle…" |

End with: `N errors, N warnings, N info` and whether the syntax check ran.

## Fix rules

- Comment-only edits; keep correct existing wording and the repo's style.
- Don't invent behavior: when the code doesn't make the intent clear, list the symbol under "needs the author"
  instead of guessing.
- Don't add comments to private or internal symbols unless asked.
- Hand commits to aidevme-github (`docs(<scope>): fix doc comments in <area>`).
