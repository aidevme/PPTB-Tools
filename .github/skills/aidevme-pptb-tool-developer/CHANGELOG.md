# Changelog

<!-- cspell:ignore hso ForgeUSA tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-pptb-tool-developer** skill: moving inline `makeStyles` hooks out of a PPTB tool's components into `src/styles/`. Newest first. Each entry says what changed and why
it matters to you; the commit has the detail. The source is `agent-src/skills/project/pptb/aidevme-pptb-tool-developer/`, synced to
`.claude/skills/` and `.github/skills/`.

## 2026-10-21

### Added

- **This changelog.** The skill's history in one file, from its commits, following
  `docs/templates/CHANGELOG_STYLE.md`. `SKILL.md` keeps its short Changelog table.

## 2026-10-18

### Changed

- **TSDoc after extraction.** New style files and changed components go to `aidevme-tsdoc` ("After a code
  change"), and `npm run lint:tsdoc` runs where the tool has it. (95212a6)
- **Frontmatter valid under the Agent Skills specification.** `layer` and `scope` moved under `metadata`, so the
  skill passes `agent-src/sync/validate-skills.ps1` (skills-ref). The description was cut to under 1024 characters. (b8fcdcf)

## 2026-10-17

### Added

- **The skill itself.** Tool selection, a read-only analysis of inline `makeStyles` hooks with edge cases flagged,
  an approval gate, extraction to `src/styles/<ComponentName>.styles.ts` with the barrel, build, test and lint
  checks, and a report. Styling questions are answered from Microsoft Learn through the Microsoft Learn MCP Server
  and cited; improvements found there are reported as follow-ups, never applied. (55df029)
