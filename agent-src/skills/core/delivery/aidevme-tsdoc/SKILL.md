---
name: aidevme-tsdoc
description: |
  Write, review and fix TSDoc doc comments in TypeScript code (libraries, Node tools and CLIs, React front ends),
  following the TSDoc standard (tsdoc.org) and checked with ESLint's tsdoc/syntax rule. Documents exported and public
  symbols: functions, classes, methods, interfaces, types, enums, React components with their props, and hooks.
  Use when:
  (1) User says "document this", "add TSDoc", "add doc comments", or "add JSDoc to this TypeScript"
  (2) User says "review the doc comments" or "fix the doc comments"
  (3) User asks to document a component, hook or API
  (4) User asks why tsdoc/syntax is failing, or wants eslint-plugin-tsdoc set up
  (5) A component, hook or service was just created or changed, by the user or another skill
  Does NOT change code behavior, signatures or formatting outside comments; document private symbols unless asked;
  edit generated files; install packages without asking; or commit (hand-off to aidevme-github).
license: MIT
compatibility: Designed for Claude Code. Needs Node.js; validation uses ESLint with eslint-plugin-tsdoc.
metadata:
  author: aidevme
  layer: atomic
  scope: core
  version: "1.0"
allowed-tools: Read Edit Write Grep Glob Bash(npx eslint:*) Bash(node:*) Bash(git diff:*) PowerShell AskUserQuestion
argument-hint: "[file ... | --changed | --review]"
---

# aidevme-tsdoc: TSDoc doc comments for TypeScript

<!-- cspell:ignore tsdoc -->

Writes, reviews and fixes [TSDoc](https://tsdoc.org/) comments: the `/** … */` blocks that TypeDoc, API Extractor,
DocFX, ESLint and VS Code IntelliSense read. Checked against TSDoc's standard tag list (microsoft/tsdoc `76dcd8e`)
and `eslint-plugin-tsdoc` 0.5.4 on 2026-10-18. Load only the reference a request needs.

## Modes

| Mode | Trigger | What happens |
| --- | --- | --- |
| `write` | "document this", files given, or `--changed` | Add comments to the public symbols of the given files, or of the files `git diff --name-only HEAD` lists |
| `review` | "review the doc comments", `--review` | Report problems ([review.md](references/review.md)); edit nothing |
| `fix` | "fix the doc comments" | Review, show the findings, and apply fixes after the user confirms |
| `setup` | "set up eslint-plugin-tsdoc", or the check exits 2 | Load [setup.md](references/setup.md) |

## After a code change

Run this whenever TypeScript code was just created or changed, by the user or by another skill that hands off
(spec-driven implementation, refactoring, style extraction):

- **Scope:** the files the change touched (`--changed`, or the list the calling skill passes). Within them, only the
  public symbols that are new or whose name, parameters, props, return value or behavior changed. Remove tags for
  parameters that no longer exist.
- **Keep** comments that still match the code; update the ones that don't; add the missing ones.
- **No separate plan** for a handful of files: the change that's already approved covers its comments. Edits stay
  comment-only.
- **Check** with `scripts/check-tsdoc.mjs` on the touched files, and report what was added and updated.
- **Same commit:** the comments go into the commit with the code they describe, not a separate docs commit.

## Workflow (write and fix)

1. **Read the repo's conventions:** existing doc comments, `tsdoc.json`, the ESLint config, and whether the package
   publishes an API (release tags, see [tags.md](references/tags.md)).
2. **List the public symbols** in each file: exports, and public members of exported classes. Skip private and
   internal helpers unless asked.
3. **Read each symbol's implementation** so the comment says what the code actually does: inputs, result, errors,
   side effects, async behavior.
4. **Show a short plan per file** (symbol → summary idea → tags) and wait for confirmation in `fix` mode, or when
   more than a few files change.
5. **Edit** the comments only.
6. **Check:** `node <skill>/scripts/check-tsdoc.mjs <touched files>`. Exit 2 means the check can't run (no ESLint,
   parser or plugin): say so, offer [setup.md](references/setup.md), and never install on your own.
7. **Fix** what the check reports and re-run it until it's clean.
8. **Report:** files and symbols documented, symbols skipped and why, and the check result (or "check unavailable").
9. **Offer the commit** through aidevme-github (one commit per file, Conventional Commits), for example
   `docs(<scope>): document the plan helpers`. Never commit yourself.

## Core rules (detail and examples in rules.md)

- The first line is a one-sentence summary in the present tense ("Returns…", "Creates…").
- Describe intent and behavior; never repeat the type. No JSDoc `{type}` annotations in `.ts` or `.tsx`.
- **Every function documents its inputs and output:** exported functions, public methods and hooks get
  `@param name - description` (with the hyphen) for each parameter and `@returns` for the result, unless it returns
  `void` or `Promise<void>`, even when the summary already mentions them. `@typeParam T - description` for generics.
  Components are the exception: their props are documented on the props interface.
- **Layout:** summary; blank line; `@remarks` (when needed); blank line; the `@param`, `@typeParam`, `@returns` and
  `@throws` block; blank line; modifier tags such as `@deprecated` or release tags.
- `@returns`, never `@return`; `@throws` for every error the caller must handle.
- `@remarks` for detail beyond the summary; `@example` only when usage isn't obvious, as a fenced `ts` block.
- `{@link Symbol}` for cross-references; `@deprecated` names what to use instead.
- `@defaultValue` for optional props and settings in new comments; existing correct prose defaults stay.
- No comment that restates the name ("Gets the name"). Keep existing wording when it's correct.
- TSDoc and JSDoc syntax never mix in one comment; plain `.js` files follow [jsdoc-js.md](references/jsdoc-js.md).

## Safety rules

- **Comment-only edits:** never change code, signatures, imports or formatting outside the comment.
- **Never edit generated files:** anything under `generated/`, `dist/` or `build/`, emitted `*.d.ts`, and files with a
  "generated" or "do not edit" header.
- **No custom tags** unless `tsdoc.json` defines them.
- **Unclear behavior:** stop and ask rather than guess.
- **No installs and no commits:** offer setup and hand commits to aidevme-github.

## Routing

| Request | Load |
| --- | --- |
| Writing rules, before/after examples, overloads, generics, async, enums, classes, barrels | [references/rules.md](references/rules.md) |
| Which tag to use, tag syntax, release tags, each tag's tsdoc.org page | [references/tags.md](references/tags.md) |
| React components, props, hooks, context providers | [references/react.md](references/react.md) |
| Reviewing or fixing existing comments, the findings table | [references/review.md](references/review.md) |
| `eslint-plugin-tsdoc`, `tsdoc.json`, TypeDoc, API Extractor, "why is tsdoc/syntax failing" | [references/setup.md](references/setup.md) |
| Plain JavaScript (`.js`, `.mjs`, `.cjs`) | [references/jsdoc-js.md](references/jsdoc-js.md) |
| Where the rules came from, verified versions | [references/sources.md](references/sources.md) |

## Changelog

| Date | Author | Description |
| --- | --- | --- |
| 2026-10-18 | aidevme | Created: write, review, fix and setup modes; rules, tag reference, React, review checklist, ESLint setup, JavaScript notes and sources; check-tsdoc.mjs; starter tsdoc.json and flat-config snippet. Checked against TSDoc `76dcd8e` and eslint-plugin-tsdoc 0.5.4. |
| 2026-10-18 | aidevme | Every exported function, public method and hook documents each parameter (`@param`) and its result (`@returns`) in a fixed layout (summary, `@remarks`, parameters and result, modifiers); components keep their props on the props interface. |
| 2026-10-18 | aidevme | New "After a code change" section and trigger: other skills and ad-hoc edits hand off here to document only the symbols they touched, in the same commit. |
| 2026-10-19 | aidevme | tags.md links every tag to its tsdoc.org reference page (25 tags; the `@jsx…` pragmas have none) and explains release-tag inheritance from the `@alpha` example. |
| 2026-10-21 | aidevme | New [CHANGELOG.md](CHANGELOG.md): the skill's full history from its commits, including the 2026-10-18 check-script fix. |
