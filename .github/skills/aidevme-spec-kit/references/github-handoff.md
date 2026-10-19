# GitHub handoff

<!-- cspell:ignore speckit taskstoissues -->

Purpose: hand every git and GitHub action to aidevme-github, so its confirmation and safety rules apply in one
place.

## Ownership

| Area | Owner |
| --- | --- |
| Constitution, specs, plans, tasks, converge results | aidevme-spec-kit (through Spec Kit) |
| Commits (one per file, Conventional Commits) | aidevme-github `references/commit.md` |
| Branch names and creation | aidevme-github `references/branch.md` |
| Issues and `Refs #n` / `Closes #n` footers | aidevme-github `references/issues.md` |
| Pull requests | aidevme-github `references/pull-request.md` |
| CI status | aidevme-github `references/ci.md` |
| GitHub MCP server checks | aidevme-github `references/mcp-setup.md` |

Spec Kit's git extension and `/speckit-taskstoissues` are not used ([setup.md](setup.md)).

## Handoffs

- **Branch:** suggest `feature/<NNN>-<slug>` from the feature folder (`specs/003-zip-export` →
  `feature/003-zip-export`). With one Spec Kit project per package, feature numbers repeat across packages, so add
  the package: `feature/<package>-<NNN>-<slug>`. aidevme-github validates and creates it only when asked.
- **Commit:** after a task passes its tests ([implement.md](implement.md)), offer the commit; the message names the
  task ID (for example `feat(export): add zip builder (T003)`) and `Refs #n` when the task has an issue.
- **Issues:** created from tasks only on request ([tasks.md](tasks.md)).
- **Pull request:** only after converge reports Converged ([converge.md](converge.md)). Ask aidevme-github to add to
  the body links to `spec.md`, `plan.md` and `tasks.md` and the list of completed task IDs.

## When aidevme-github or the GitHub MCP server isn't available

Say so. Keep the work local: specs, plans, tasks and code still proceed; propose the commit messages, branch name
and pull request body as text for the user. Never run raw GitHub API calls with tokens or commit directly.

## Review gate

Every handoff is a proposal; aidevme-github asks for its own confirmation before any write.

## Example

"Open the PR" after convergence: the request goes to aidevme-github's pull request workflow with a draft body that
links `specs/003-zip-export/spec.md`, `plan.md` and `tasks.md` and lists T001–T009 as completed.
