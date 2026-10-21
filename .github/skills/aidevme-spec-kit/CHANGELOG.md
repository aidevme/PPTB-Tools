# Changelog

<!-- cspell:ignore hso ForgeUSA tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-spec-kit** skill: spec-driven development with GitHub Spec Kit, one phase and review gate at a time. Newest first. Each entry says what changed and why
it matters to you; the commit has the detail. The source is `agent-src/skills/core/delivery/aidevme-spec-kit/`, synced to
`.claude/skills/` and `.github/skills/`.

## 2026-10-21

### Added

- **This changelog.** The skill's history in one file, from its commits, following
  `docs/templates/CHANGELOG_STYLE.md`. `SKILL.md` keeps its short Changelog table.

## 2026-10-18

### Added

- **The skill itself.** Wraps GitHub Spec Kit (checked against v1.2.1 on 2026-10-17): detects the phase, runs
  the matching `/speckit-*` command and stops at a review gate after each phase. Includes `power-platform` and
  `typescript-web` constitution profiles and nine evals; git and GitHub work goes to `aidevme-github`. (279d113)

### Changed

- **One Spec Kit project per package.** The skill works in the nearest `.specify/` and, when setting up, proposes
  a package folder (for example `tools/<tool-name>/`) in repositories with several packages or a sync that
  regenerates `.claude/skills/`, instead of always using the root. Branch names carry the package; troubleshooting
  covers deleted `speckit-*` skills and features in the wrong project. (f0acecf)
- **The implement step updates TSDoc.** Each task's changed symbols get their doc comments through
  `aidevme-tsdoc` ("After a code change"), in the same commit as the code. (95212a6)
- **Frontmatter valid under the Agent Skills specification.** `layer` and `scope` moved under `metadata`, so the
  skill passes `agent-src/sync/validate-skills.ps1` (skills-ref). (b8fcdcf)
