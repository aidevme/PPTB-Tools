# Changelog

<!-- cspell:ignore hso -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **playwright-cli** skill: driving a browser with `playwright-cli` for testing, form
filling, screenshots and data extraction. Newest first. Each entry says what changed and why it matters to you; the
commit has the detail. The source is `agent-src/skills/core/reference/playwright-cli/`, synced to `.claude/skills/`
and `.github/skills/`.

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

- **Evals in the source.** The skill's `evals/` files were copied into `agent-src/`, so the sync gives Claude Code
  and GitHub Copilot the same test cases. (90a9c34)

## 2026-10-15

### Added

- **In this repository's single source.** The skill lives in `agent-src/skills/core/reference/` and `sync.ps1`
  generates its `.claude/skills/` and `.github/skills/` copies; edit the source only. Ported on 2026-09-11 from
  earlier in-house reference skills and made neutral for the reusable template: no internal license header, no stray
  project tags. (a380df6)

## 2026-10-13

### Added

- **The skill itself**, in the generated skills folder: browser automation with `playwright-cli` (navigate, click,
  fill forms, take screenshots, extract data), limited to the `playwright-cli` command through `allowed-tools`.
  (e8fffb7)
