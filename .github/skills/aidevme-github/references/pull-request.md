# Pull requests

<!-- cspell:ignore oneline -->

Purpose: open or update the pull request for the current branch, with a title and body built from its commits.
Doesn't commit; uncommitted changes go through [commit.md](commit.md) first, and only if the user asks.

Load [mcp-setup.md](mcp-setup.md) first.

## Workflow

1. **Collect the facts (local git):** current branch (`git branch --show-current`), base branch (the repo default,
   see [branch.md](branch.md)), commits on the branch (`git log --oneline <base>..HEAD`), and whether the branch is
   pushed and up to date (`git status -sb`). Never open a pull request from a trunk branch.
2. **Uncommitted changes:** say so. Commit them only if the user asks (through [commit.md](commit.md)).
3. **Not pushed, or behind:** pushing needs explicit confirmation. Show `git push -u origin <branch>`, wait, then
   push. Never force-push.
4. **Look for an existing pull request** with `list_pull_requests` (`head: <owner>:<branch>`, `state: open`).
   - **One exists:** update it instead of creating a duplicate. Read it with `pull_request_read` (method `get`),
     draft the new title and body, show the change, and apply it with `update_pull_request` after confirmation.
   - **None:** create a new one (next steps).
5. **Build the title and body** from the branch's Conventional Commits:
   - **Title:** a Conventional Commits line for the whole change, for example `feat(auth): add oauth login`.
   - **Body:** a one-paragraph summary, then sections that have entries: **Features** (`feat`), **Fixes** (`fix`),
     **Breaking changes** (`!` or `BREAKING CHANGE:` footers, with the migration), **Other** (all other types).
     Each entry is the commit description, without the hash.
   - **Linked issues:** from the commits' `Refs`/`Closes` footers and the branch name (`issue-123`), each checked
     through [issues.md](issues.md); `Closes #n` only for issues the change resolves.
   - Follow the repository's PR template or rules if it has them (`.github/pull_request_template.md`,
     `CONTRIBUTING.md`).
6. **Show the draft** (base, head, title, body, draft yes/no) and create it with `create_pull_request` only after
   confirmation. **Draft by default** (`draft: true`) unless the user says otherwise.
7. **Report** the number and link, and offer to check CI ([ci.md](ci.md)).

## Never

Merge, close, reopen, change reviewers or labels, or mark ready for review without being asked.

## Example body

```markdown
Adds OAuth login to the settings page and fixes the header overflow on small screens.

### Features
- add oauth login (auth)

### Fixes
- stop header overflow on mobile (layout)

Closes #42
```
