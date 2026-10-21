# Changelog

<!-- cspell:ignore hso ForgeUSA tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-skills-sync** skill: checking that the generated skill folders match the source. Newest first. Each entry says what changed and why
it matters to you; the commit has the detail. The source is `agent-src/skills/core/meta/aidevme-skills-sync/`, synced to
`.claude/skills/` and `.github/skills/`.

## 2026-10-21

### Added

- **A changelog check** (new Step 3). `agent-src/sync/check-changelogs.ps1` fails when an `aidevme-*` skill has no
  `CHANGELOG.md`, or was changed in the working tree or a commit without its `CHANGELOG.md`; the report now ends
  with "CHANGELOGS OK" when all three checks are clean. `-Pattern '*'` checks every source skill.
- **This changelog.** The skill's history in one file, from its commits, following
  `docs/templates/CHANGELOG_STYLE.md`. `SKILL.md` keeps its short Changelog table.

## 2026-10-18

### Added

- **Specification check first.** The skill now starts by validating every source skill against the Agent Skills
  specification with `agent-src/sync/validate-skills.ps1`, then checks parity. (b8fcdcf)

### Changed

- **Frontmatter valid under the Agent Skills specification.** `layer` and `scope` moved under `metadata`, so the
  skill passes `agent-src/sync/validate-skills.ps1` (skills-ref). (b8fcdcf)

## 2026-10-16

### Changed

- **Renamed from `hso-skills-sync`.** The skill, its `name:` field, the manifest entry and every cross-reference use the
  `aidevme-` name; ask for it by the new name. (90a9c34)

## 2026-10-15

### Added

- **In this repository's single source.** The skill lives in `agent-src/` and `sync.ps1` generates its
  `.claude/skills/` and `.github/skills/` copies; edit the source only. Rewritten on 2026-09-10 from HINT's twin-mirror reconciler into a check for the source-committed model, with
  the double-nesting bug designed out. (a380df6)
