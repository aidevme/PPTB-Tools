# Changelog

<!-- cspell:ignore hso ForgeUSA tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-wiki-scaffold-project** skill: creating or completing the `agent/` wiki layout in a repository. Newest first. Each entry says what changed and why
it matters to you; the commit has the detail. The source is `agent-src/skills/core/delivery/aidevme-wiki-scaffold-project/`, synced to
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

- **Renamed from `hso-wiki-scaffold-project`.** The skill, its `name:` field, the manifest entry and every cross-reference use the
  `aidevme-` name; ask for it by the new name. (90a9c34)

## 2026-10-15

### Added

- **The skill itself**, ported from ForgeUSA and fitted to this template: no `license:` header, the hand-appended
  `log.md` instead of the fragment-log folder and its generators, no governance or program-tier files, and this
  template's `agent-src` and `shared/dv` paths instead of ForgeUSA's. (2724ab7)
- **In this repository's single source.** The skill lives in `agent-src/` and `sync.ps1` generates its
  `.claude/skills/` and `.github/skills/` copies; edit the source only. (a380df6)
