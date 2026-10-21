# Changelog

<!-- cspell:ignore hso ForgeUSA tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-shared-scripts** skill: the shared PowerShell library other skills load (sign-in, Web API calls, project config). Newest first. Each entry says what changed and why
it matters to you; the commit has the detail. The source is `agent-src/skills/core/foundation/aidevme-shared-scripts/`, synced to
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

- **Renamed from `hso-shared-scripts`.** The skill, its `name:` field, the manifest entry and every cross-reference use the
  `aidevme-` name; ask for it by the new name. (90a9c34)

## 2026-10-15

### Added

- **In this repository's single source.** The skill lives in `agent-src/` and `sync.ps1` generates its
  `.claude/skills/` and `.github/skills/` copies; edit the source only. Ported from ForgeUSA on 2026-09-11 as a foundation library skill, made neutral, with its governance modules
  left out. (a380df6)
