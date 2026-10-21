# Changelog

<!-- cspell:ignore hso ForgeUSA tsdoc -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **aidevme-github** skill: git and GitHub work: commits, branches, issues, pull requests, reviews and CI. Newest first. Each entry says what changed and why
it matters to you; the commit has the detail. The source is `agent-src/skills/core/delivery/aidevme-github/`, synced to
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

- **Evals for the whole router.** Six new test cases cover pull requests, missing issues, CI, "ship it", a
  session without the GitHub MCP server, and branch names; the five commit cases are unchanged. (34b5a82)
- **References for every capability**, each loaded only when a request needs it: branch names, issue footers, pull
  requests, review comments, CI status and security alerts through the GitHub MCP server, plus MCP setup (tool names
  checked at `github-mcp-server@e3809fe`) and notes on the `awesome-copilot` skills adapted at `cb64ad1`. The commit
  workflow moved unchanged to [references/commit.md](references/commit.md). (a630de2)
- **The skill itself.** One commit per changed file with a Conventional Commits 1.0.0 message written for its
  diff: a safety check for secrets and build output, coupled-file grouping on request, a plan to confirm, and no
  push, force-push or hook bypass unless asked. (3bbd948)

### Changed

- **One entry point that routes to references.** `SKILL.md` keeps the shared rules (act only when asked, plan
  before every write, push only after confirmation, no hook bypass, stop on failure, no raw API fallback), the routing
  table, the "ship it" chain and a short commit summary. (d332051)
