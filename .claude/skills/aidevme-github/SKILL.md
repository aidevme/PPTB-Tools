---
name: aidevme-github
metadata:
  layer: orchestration
  scope: core
description: |
  Git and GitHub workflow, one entry point: commit changes one file at a time with Conventional Commits 1.0.0
  messages, name branches, link or create issues, open or update a pull request and write its description, address
  pull request review comments, read CI/build status, and "ship it" (commit, push after confirmation, pull request,
  CI). Local git through the git CLI; GitHub through the official GitHub MCP server. Use when:
  (1) User says "commit this", "commit my changes", asks for commit messages, or to split changes into commits
  (2) User asks to name a branch, or to link, find or create an issue
  (3) User asks to open a PR, update it, or write its description
  (4) User asks to address or reply to PR review comments, or why CI or the build is failing
  (5) User says "ship it"
  Does NOT act without being asked, push without explicit confirmation, force-push, use --no-verify, rebase shared
  branches, change git config, or commit secrets, build output or dependencies.
allowed-tools: Bash, PowerShell, Read, Grep, Glob, AskUserQuestion, mcp__github__get_me, mcp__github__issue_read, mcp__github__search_issues, mcp__github__issue_write, mcp__github__list_pull_requests, mcp__github__pull_request_read, mcp__github__create_pull_request, mcp__github__update_pull_request, mcp__github__add_reply_to_pull_request_comment, mcp__github__pull_request_review_write, mcp__github__actions_list, mcp__github__actions_get, mcp__github__get_job_logs, mcp__github__list_secret_scanning_alerts, mcp__github__list_code_scanning_alerts
argument-hint: "[file ... | --staged]"
---

# aidevme-github: git and GitHub workflow

<!-- cspell:ignore oneline -->

One entry point for local git and GitHub work. This file holds the shared rules and the routing; each capability
is in a reference file under `references/`. Load only the reference the request needs.

## Shared rules (every reference)

- **Only act when asked.** Never commit, push, open a pull request or write to GitHub on your own initiative.
- **Show a plan before any write** to git or GitHub (commits, branches, pushes, issues, pull requests, replies), and
  wait for confirmation unless the user said "just commit" (commits only).
- **Push only after explicit confirmation**, every time. Never force-push.
- **Never bypass hooks** (`--no-verify`), amend pushed commits, rebase shared branches, or change git config.
- **Stop and report on any failure** (hook, build, test, API error); don't continue with the next step.
- **GitHub MCP server unavailable:** say so and what's missing (see `references/mcp-setup.md`), do the local-git
  part only, and never fall back to raw API calls with tokens.
- Follow the repository's own rules (`CONTRIBUTING.md`, `AGENTS.md`, `CLAUDE.md`) where they're stricter.

## Routing

| Request | Load |
| --- | --- |
| Commit, stage, commit messages, split changes into commits | [references/commit.md](references/commit.md) |
| Name, check or create a branch | [references/branch.md](references/branch.md) |
| `Refs #n` / `Closes #n` footers, find or create an issue | [references/issues.md](references/issues.md) |
| Open or update a pull request, write its title or description | [references/pull-request.md](references/pull-request.md) |
| Address or reply to pull request review comments | [references/review.md](references/review.md) |
| CI, build or workflow status, why a check failed | [references/ci.md](references/ci.md) |
| Security alerts before a push (optional) | [references/security.md](references/security.md) |
| Set up or check the GitHub MCP server | [references/mcp-setup.md](references/mcp-setup.md) |
| Where the branch and review rules came from | [references/official-skills.md](references/official-skills.md) |

GitHub-side references start with "Load `mcp-setup.md` first": check the server is connected before using its tools.

### "Ship it"

Run these in order, each with its own confirmation, and stop at the first failure:

1. **Commit** the changes ([commit.md](references/commit.md)).
2. **Push**: show `git push` (with `-u origin <branch>` for a new branch) and push only after explicit confirmation.
3. **Pull request**: draft one, or update the existing one ([pull-request.md](references/pull-request.md)); create it
   only after confirmation, as a draft by default.
4. **CI**: report the checks for the pull request ([ci.md](references/ci.md)); read-only.

Without the GitHub MCP server, do steps 1–2 (push still needs confirmation) and say that steps 3–4 need it.

## Commit workflow in short

Every changed file gets its own commit with a Conventional Commits message written for its diff: inspect the repo
state and recent log, skip secrets and build output, read each file's diff, offer to group coupled files, show a
plan table, then commit one file at a time after confirmation. The full workflow, message format and house style
are in [references/commit.md](references/commit.md).

## Changelog

| Date | Author | Description |
| --- | --- | --- |
| 2026-10-17 | aidevme | Created: one commit per file with Conventional Commits 1.0.0 messages; repo-state inspection, safety check, per-file diffs, coupled-file grouping, plan table and confirmation, ordered commits, and the never-push/never-bypass rules. |
| 2026-10-17 | aidevme | Restructured into a router with references: the commit workflow moved verbatim to `references/commit.md`; added branch naming, issues, pull requests, review comments, CI and security through the GitHub MCP server (tool names checked at `github-mcp-server@e3809fe`), MCP setup, and notes on the official `awesome-copilot` skills adapted (`@cb64ad1`). |
