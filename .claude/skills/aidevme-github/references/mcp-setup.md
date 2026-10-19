# GitHub MCP server setup

<!-- cspell:ignore githubcopilot toolsets readonly ghcr -->

Purpose: connect the official [GitHub MCP server](https://github.com/github/github-mcp-server) so the GitHub-side
references (issues, pull requests, reviews, CI, security) can work. Local git work never needs it.

Checked against `github/github-mcp-server` at commit `e3809fe` (README, `docs/remote-server.md`,
`docs/installation-guides/install-claude.md`). Tool names change between releases; re-check them when updating.

## Is it connected?

- Run `claude mcp list`, or check whether `mcp__<server>__get_me` is available in the session. These references
  assume the server name `github`, so tools are `mcp__github__<tool>`; with another name, use that prefix.
- If it isn't connected, say so, show the setup below, do the local-git part of the request only, and never fall
  back to raw API calls with a token.
- Don't run `claude mcp add` or edit MCP configuration yourself; the user does it.

## Option 1 (default): local Docker server with OAuth

The official image signs in through the browser on first use and keeps the token in memory only. Run in a terminal:

```bash
claude mcp add github -e GITHUB_OAUTH_CALLBACK_PORT=8085 -e GITHUB_TOOLSETS=context,repos,pull_requests,issues,actions -- docker run -i --rm -p 127.0.0.1:8085:8085 -e GITHUB_OAUTH_CALLBACK_PORT -e GITHUB_TOOLSETS ghcr.io/github/github-mcp-server
```

- Add `secret_protection,code_security` to `GITHUB_TOOLSETS` only if [security.md](security.md) is used.
- **Read-only:** add `-e GITHUB_READ_ONLY=1` (and pass it into the container with `-e GITHUB_READ_ONLY`), or run the
  binary with `--read-only`. Write tools are then skipped, even when listed.
- Requires Docker. See the server's `docs/oauth-login.md` for the native binary and device-code login.

## Option 2: hosted server

Endpoint `https://api.githubcopilot.com/mcp/`. The Claude Code guide (at `e3809fe`) authenticates it with a
personal access token in an `Authorization` header:

```bash
claude mcp add --transport http github https://api.githubcopilot.com/mcp -H "Authorization: Bearer $GITHUB_PAT" -H "X-MCP-Toolsets: context,repos,pull_requests,issues,actions"
```

- **The token ends up in a file:** Claude Code saves the header in your user config (`~/.claude.json`). Prefer
  Option 1. Never put a token in a repository file (`.mcp.json`, `.vscode/mcp.json`, `.env` committed to git).
- **Toolsets:** the `X-MCP-Toolsets` header (comma-separated), or one toolset per URL: `.../mcp/x/<toolset>`.
- **Read-only:** add `/readonly` to the URL (`https://api.githubcopilot.com/mcp/readonly`) or send
  `X-MCP-Readonly: true`.

## Tools each reference uses

All names confirmed in the server README at `e3809fe`. Prefix: `mcp__github__`.

| Reference | Toolset | Tools (method) |
| --- | --- | --- |
| all | `context` | `get_me` |
| [issues.md](issues.md) | `issues` | `issue_read` (`get`), `search_issues`, `issue_write` (`create`) |
| [pull-request.md](pull-request.md) | `pull_requests` | `list_pull_requests`, `pull_request_read` (`get`, `get_commits`), `create_pull_request`, `update_pull_request` |
| [review.md](review.md) | `pull_requests` | `pull_request_read` (`get_review_comments`, `get_reviews`), `add_reply_to_pull_request_comment`, `pull_request_review_write` (`resolve_thread`, only when the user asks) |
| [ci.md](ci.md) | `actions`, `pull_requests` | `actions_list` (`list_workflow_runs`), `actions_get` (`get_workflow_run`), `get_job_logs`, `pull_request_read` (`get_check_runs`, `get_status`) |
| [security.md](security.md) | `secret_protection`, `code_security` | `list_secret_scanning_alerts`, `list_code_scanning_alerts` |

`actions_run_trigger` (re-run or trigger a workflow) exists in the `actions` toolset but isn't in `allowed-tools`;
use it only after the user explicitly asks, so the client also prompts.
