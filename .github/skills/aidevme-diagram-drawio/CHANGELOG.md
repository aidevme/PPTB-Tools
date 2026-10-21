# Changelog

<!-- cspell:ignore hso ForgeUSA tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-diagram-drawio** skill: authoring and rendering draw.io diagrams for Markdown and reveal.js. Newest first. Each entry says what changed and why
it matters to you; the commit has the detail. The source is `agent-src/skills/project/pptb/aidevme-diagram-drawio/`, synced to
`.claude/skills/` and `.github/skills/`.

## 2026-10-21

### Added

- **This changelog.** The skill's history in one file, from its commits, following
  `docs/templates/CHANGELOG_STYLE.md`. `SKILL.md` keeps its short Changelog table.

## 2026-10-18

### Changed

- **Frontmatter valid under the Agent Skills specification.** `layer` and `scope` moved under `metadata`, so the
  skill passes `agent-src/sync/validate-skills.ps1` (skills-ref). (b8fcdcf)

## 2026-10-16

### Changed

- **Part of the single source.** The skill moved into `agent-src/skills/project/pptb/` and was registered in the
  manifest; before, it existed only in the generated folders, which the sync rebuilds. (90a9c34)

## 2026-10-13

### Added

- **The skill itself.** Authors draw.io diagrams and renders them as SVG (or PNG and PDF) for Markdown pages and
  reveal.js slides. (e8fffb7)
