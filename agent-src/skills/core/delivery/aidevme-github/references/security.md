# Security alerts (optional)

Purpose: list open secret-scanning and code-scanning alerts before a push. Read-only. A second check beside the
local secret scan in [commit.md](commit.md) step 3, not a replacement for it.

Load [mcp-setup.md](mcp-setup.md) first. Needs the `secret_protection` and `code_security` toolsets, which the
minimal setup leaves out.

## Workflow

1. Only when the user asks, or as an offered step before a push.
2. `list_secret_scanning_alerts` (`owner`, `repo`, `state: open`) and `list_code_scanning_alerts` (`owner`, `repo`,
   `state: open`, `ref`: the branch, for example `refs/heads/<branch>`).
3. Report the count per kind and, for each alert, the rule or secret type, severity, and file and line. Don't print
   secret values.
4. Point out alerts in files the current changes touch. Fixing them is a separate request.
5. If the toolsets or the repository's security features aren't available, say so and rely on the local check.

## Never

Dismiss, close or change alerts.
