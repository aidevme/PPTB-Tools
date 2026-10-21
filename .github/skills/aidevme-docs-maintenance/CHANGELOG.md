# Changelog

<!-- cspell:ignore hso ForgeUSA tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-docs-maintenance** skill: validating Markdown, syncing the cspell word list and the `docs/` entries in CODEOWNERS. Newest first. Each entry says what changed and why
it matters to you; the commit has the detail. The source is `agent-src/skills/project/repo/aidevme-docs-maintenance/`, synced to
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

### Added

- **The skill itself**, made from the repository's maintenance scripts: validate Markdown (markdownlint and
  cspell), sync `cspell.json`, and sync the `docs/` entries in `.github/CODEOWNERS`, with review rules (never
  `-AutoAdd`, show new words before adding them, preview CODEOWNERS with `-WhatIf`). The scripts find the repository
  root with git; `Validate-Markdown.ps1` gained `-Path` and fails when either check fails; `Sync-Cspell.ps1` gained
  `-ListOnly` and `-Word`. (c864810)
