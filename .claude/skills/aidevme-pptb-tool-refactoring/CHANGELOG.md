# Changelog

<!-- cspell:ignore hso ForgeUSA tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-pptb-tool-refactoring** skill: analyzing PPTB tools and carrying out approved refactoring steps. Newest first. Each entry says what changed and why
it matters to you; the commit has the detail. The source is `agent-src/skills/project/pptb/aidevme-pptb-tool-refactoring/`, synced to
`.claude/skills/` and `.github/skills/`.

## 2026-10-21

### Added

- **This changelog.** The skill's history in one file, from its commits, following
  `docs/templates/CHANGELOG_STYLE.md`. `SKILL.md` keeps its short Changelog table.

## 2026-10-18

### Changed

- **TODO files per tool.** Proposals and reports are saved in `docs/todos/<tool-name>/` (created if missing)
  instead of directly in `docs/todos/`. (b8b128c)
- **TSDoc moves with the code.** Each step's changed symbols go through `aidevme-tsdoc` ("After a code
  change") and `npm run lint:tsdoc`. (95212a6)
- **Frontmatter valid under the Agent Skills specification.** `layer` and `scope` moved under `metadata`, so the
  skill passes `agent-src/sync/validate-skills.ps1` (skills-ref). The description was cut to under 1024 characters. (b8fcdcf)

## 2026-10-17

### Added

- **A Microsoft Learn references section** in the proposal, listing the pages its findings rely on, or why
  Microsoft Learn wasn't checked. (003b9ae)
- **The Microsoft Learn pages used** are listed in the execution report. (8b82f6f)
- **Evals for Microsoft Learn grounding**, including a session without the Microsoft Learn MCP server. (7fb4f34)

### Changed

- **Microsoft platform findings are checked, not remembered.** Findings, failures and fixes that depend on
  Dataverse, Power Platform, Fluent UI or other Microsoft APIs are looked up through the Microsoft Learn MCP Server
  and cited; without the server they're marked "Microsoft Learn not checked". (71caed5)

## 2026-10-16

### Added

- **"Save as TODO only".** A proposal can be saved as a TODO file without changing any code. (de1178d)
- **Report and saved-file templates** for the execution and reporting phases. (eb10d54)
- **The skill itself.** Tool selection, a read-only analysis, an approval gate, verified step-by-step execution, a
  report, and a record in `docs/todos/`. (b43a7a6)

### Changed

- **The TODO file comes first.** It is written before any change, and the execution report updates the same
  file. (de1178d)
