# Changelog

<!-- cspell:ignore tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-tsdoc** skill: writing, reviewing and fixing TSDoc comments in TypeScript. Newest
first. Each entry says what changed and why it matters to you; the commit has the detail. The source is
`agent-src/skills/core/delivery/aidevme-tsdoc/`, synced to `.claude/skills/` and `.github/skills/`.

## 2026-10-21

### Added

- **This changelog.** The skill's history in one file, from its commits. `SKILL.md` keeps its short Changelog table.

## 2026-10-19

### Added

- **Links to tsdoc.org for every tag** ([references/tags.md](references/tags.md)). The 25 tags tsdoc.org documents link
  to their reference page; the four `@jsx…` pragmas have no page there, which the file says.
- **Release-tag inheritance.** The release tags section explains, with tsdoc.org's `@alpha` example, that a member
  without a release tag inherits its container's, and that tooling may trim `@alpha` and `@beta` items from a public
  release. (d425cf1)

## 2026-10-18

### Added

- **"After a code change".** A new section and trigger: when TypeScript is created or changed, by the user or another
  skill (spec-driven implementation, refactoring, style extraction), the skill documents only the public symbols
  that were touched, keeps comments that still match, updates the ones that don't, checks the touched files, and puts
  the comments in the same commit as the code. (95212a6)
- **Every function documents its inputs and output.** Exported functions, public methods and hooks get
  `@param name - description` for every parameter and `@returns` for every result (not for `void`), in a fixed layout:
  summary, `@remarks`, the parameter and result block, then modifiers. Components keep their props on the props
  interface instead. (35342a5)
- **The skill itself.** Write, review, fix and setup modes; references for the writing rules, the tag list, React
  components and hooks, the review checklist, ESLint setup, plain JavaScript and the sources; `scripts/check-tsdoc.mjs`
  to check touched files; a starter `tsdoc.json` and an ESLint flat-config snippet. Checked against TSDoc `76dcd8e`
  and eslint-plugin-tsdoc 0.5.4. (0b7e88f)

### Fixed

- **The check reports only TSDoc findings.** `check-tsdoc.mjs` runs only `tsdoc/syntax`, so `eslint-disable` comments
  for other rules used to show up as unknown rules. It now ignores inline config and keeps only `tsdoc/syntax`
  findings and parse errors. [references/setup.md](references/setup.md) records the versions tested (eslint 10.13.0
  and 9.39.5, @typescript-eslint/parser 8.71.2) and both ways to handle such comments in a TSDoc-only config.
  (55e909f)
