# Changelog

<!-- cspell:ignore hso ForgeUSA tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-skill-creator** skill: creating or updating a skill in the single-source layout. Newest first. Each entry says what changed and why
it matters to you; the commit has the detail. The source is `agent-src/skills/core/meta/aidevme-skill-creator/`, synced to
`.claude/skills/` and `.github/skills/`.

## 2026-10-21

### Added

- **This changelog.** The skill's history in one file, from its commits, following
  `docs/templates/CHANGELOG_STYLE.md`. `SKILL.md` keeps its short Changelog table.
- **Changelogs are created and placed automatically.** `agent-src/sync/update-changelog.ps1` creates a skill's `CHANGELOG.md` from the template in `docs/templates/CHANGELOG_STYLE.md` and adds entries under today's date in the right category; `sync.ps1` creates missing ones, and a Claude Code `PostToolUse` hook creates one for a new skill and asks for the entry after the first edit to an existing skill. Step 8 shows both commands.

### Changed

- **Every skill has a CHANGELOG.md, and every change adds an entry.** New Step 8 says how: a new skill starts its
  `CHANGELOG.md` from `docs/templates/CHANGELOG_STYLE.md`, and every update (to `SKILL.md`, references, scripts,
  assets or evals) adds an entry under today's date in the same commit, plus a row in the `SKILL.md` Changelog
  table. The sync step, now Step 9, also runs `agent-src/sync/check-changelogs.ps1`. A new critical rule, a fifth
  trigger (any change to an existing skill) and eval 10 cover it.
- **Breaking:** the rule against `CHANGELOG.md` files in skills is gone; skills created from now on must have one.

## 2026-10-19

### Changed

- **The naming example uses an existing skill**, after the Dataverse data, FetchXML, SDK reference and Custom
  API skills were removed. (c9d6cb5)

## 2026-10-18

### Added

- **Validation against the Agent Skills specification** (new Step 7): new and updated skills run
  `agent-src/sync/validate-skills.ps1` (skills-ref) and fix what it reports before the sync, which is now Step 8.
  (b8fcdcf)

### Changed

- **Frontmatter valid under the Agent Skills specification.** `layer` and `scope` moved under `metadata`, so the
  skill passes `agent-src/sync/validate-skills.ps1` (skills-ref). New skills put `layer` and `scope` under `metadata` too. (b8fcdcf)

## 2026-10-16

### Added

- **Every new skill gets `evals/evals.json`** (new Step 4), with the shared format, at least three cases and one
  edge or boundary case; it became a critical rule. (f96de43)

### Changed

- **Renamed from `hso-skill-creator`.** The skill, its `name:` field, the manifest entry and every cross-reference use the
  `aidevme-` name; ask for it by the new name. New core skills must use the `aidevme-<domain>-<purpose>`
  prefix. (90a9c34)

### Fixed

- **Project skills get their group folder.** The text said project skills go in `agent-src/skills/project/<name>/`,
  but the sync reads the group from the path; it now says `agent-src/skills/project/<group>/<name>/`, so a new
  project skill isn't created without a group. (841f80f)

## 2026-10-15

### Added

- **In this repository's single source.** The skill lives in `agent-src/` and `sync.ps1` generates its
  `.claude/skills/` and `.github/skills/` copies; edit the source only. Ported from HINT on 2026-09-10, with the required `core | project` scope choice, the manifest
  registration and the sync and verify step. (a380df6)
