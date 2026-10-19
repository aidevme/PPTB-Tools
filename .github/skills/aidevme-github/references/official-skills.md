# Official skills this skill borrows from

Purpose: record which ideas came from GitHub's official skills, from which version, and what was changed. They were
read, not installed or copied in whole.

| Skill | Source | Read at |
| --- | --- | --- |
| `conventional-branch` | [github/awesome-copilot](https://github.com/github/awesome-copilot), `skills/conventional-branch/SKILL.md` | commit `cb64ad12e32737ae764becd6885462e9b4c7cb00` (2026-10-16) |
| `copilot-pr-autopilot` | [github/awesome-copilot](https://github.com/github/awesome-copilot), `skills/copilot-pr-autopilot/SKILL.md` (its `references/`, `scripts/` and `templates/` were not read) | commit `cb64ad12e32737ae764becd6885462e9b4c7cb00` (2026-10-16) |

## conventional-branch → [branch.md](branch.md)

- **Adopted:** the `<type>/<description>` format and the five types with their aliases; trunk branches; the naming
  rules; the description guidelines; validation and fixing steps; base-branch detection; the branch-to-commit-type
  table.
- **Changed:** suggests a name and creates the branch only when asked; uses `git switch -c <branch> <base>` instead of
  checking out, pulling and branching; never pushes (shows the command, waits for confirmation); reuses the branch
  topic as the commit scope when the repo's history has it. Why: this skill acts only when asked and never changes
  the remote without confirmation.

## copilot-pr-autopilot → [review.md](review.md)

- **Adopted:** the fix / decline / escalate triage; human and security-bot threads defaulting to escalate; replying to
  every addressed thread with the commit SHA or reason; escalated threads left open; one focused commit per round;
  building and testing with the repository's own commands before pushing.
- **Not adopted:** triggering Copilot reviews through GraphQL, waiting for reviews, the repeated loop and its
  convergence check, parallel sub-agents, the PowerShell scripts and the `gh` CLI dependency, and resolving threads
  automatically. Why: this skill uses the GitHub MCP server, shows a plan before every write, and never resolves or
  dismisses a review without asking.

## When updating

Re-read both skills at the current `awesome-copilot` commit, compare them with the adopted parts above, and update
the commit SHAs in this file. Re-check the GitHub MCP tool names in [mcp-setup.md](mcp-setup.md) at the same time.
