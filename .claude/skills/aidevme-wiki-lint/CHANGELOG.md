# Changelog

<!-- cspell:ignore hso ForgeUSA tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-wiki-lint** skill: checking the `agent/` wiki's invariants and regenerating its index. Newest first. Each entry says what changed and why
it matters to you; the commit has the detail. The source is `agent-src/skills/core/delivery/aidevme-wiki-lint/`, synced to
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

- **Renamed from `hso-wiki-lint`.** The skill, its `name:` field, the manifest entry and every cross-reference use the
  `aidevme-` name; ask for it by the new name. (90a9c34)

## 2026-10-15

### Added

- **In this repository's single source.** The skill lives in `agent-src/` and `sync.ps1` generates its
  `.claude/skills/` and `.github/skills/` copies; edit the source only. Ported from earlier in-house skills on 2026-09-10, with the invariant numbering made unique (14, 15 and 16
  instead of two 14s). (a380df6)
