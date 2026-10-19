# Issues

Purpose: check, find or create the GitHub issues that commits and pull requests link to.

Load [mcp-setup.md](mcp-setup.md) first.

## Before writing a `Refs #n` or `Closes #n` footer

1. Read the issue with `issue_read` (method `get`, `owner`, `repo`, `issue_number`).
2. **It exists and is open:** keep the footer. Use `Closes #n` only when the change fully resolves the issue;
   otherwise `Refs #n`.
3. **It doesn't exist, is closed, or is in another repository:** don't write the footer as asked. Drop it, or ask
   whether to use another issue (or `owner/repo#n` for another repository).
4. **The MCP server isn't connected:** say the issue couldn't be checked, and ask whether to keep the footer
   unchecked or drop it.

## Suggesting a link (optional)

When the user asks, or a commit or pull request clearly answers an existing issue, search with `search_issues`
(`owner` and `repo` set to the current repository, `query` in natural language, for example
`folder picker cancel crash`) and suggest at most three open matches with title and number. Don't add a link the
user hasn't agreed to.

## Creating an issue

Only when the user asks. Draft the title and body, show them, and create with `issue_write` (method `create`) only
after explicit confirmation. Report the new issue number and link.

## Never

Close, reopen, relabel, reassign or edit an issue unless the user asks for that change.
