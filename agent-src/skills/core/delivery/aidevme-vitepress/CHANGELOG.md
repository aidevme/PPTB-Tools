# Changelog

<!-- cspell:ignore hso ForgeUSA tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-vitepress** skill: changes to the VitePress docs site, checked against the official VitePress docs. Newest first. Each entry says what changed and why
it matters to you; the commit has the detail. The source is `agent-src/skills/core/delivery/aidevme-vitepress/`, synced to
`.claude/skills/` and `.github/skills/`.

## 2026-10-21

### Added

- **This changelog.** The skill's history in one file, from its commits, following
  `docs/templates/CHANGELOG_STYLE.md`. `SKILL.md` keeps its short Changelog table.

## 2026-10-18

### Changed

- **Frontmatter valid under the Agent Skills specification.** `layer` and `scope` moved under `metadata`, so the
  skill passes `agent-src/sync/validate-skills.ps1` (skills-ref). (b8fcdcf)

## 2026-10-17

### Added

- **The skill itself.** Pages, sidebar, nav and config changes, Vue template errors in Markdown and dead links,
  verified with `docs:build`. VitePress questions are answered from the official docs through the Vue Docs MCP
  server (vue-mcp.org), with setup for Claude Code and VS Code Copilot; without the server, answers are marked
  "VitePress docs not checked". (b22228a)
