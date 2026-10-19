# Branch names (Conventional Branch)

<!-- cspell:ignore oneline -->

Purpose: suggest, check or create branch names that follow [Conventional Branch](https://conventional-branch.github.io).
Local git only. Adapted from the official `conventional-branch` skill (see [official-skills.md](official-skills.md)).

## Format

```text
<type>/<description>
```

| Type | Alias | Use for |
| --- | --- | --- |
| `feature/` | `feat/` | New features or enhancements |
| `bugfix/` | `fix/` | Bug fixes |
| `hotfix/` | — | Urgent production fixes |
| `release/` | — | Release preparation (`release/v1.2.0`; dots allowed only here) |
| `chore/` | — | Non-code tasks: dependencies, docs, config |

`main`, `master` and `develop` are trunk branches: no prefix, and never create a branch with one of those names.

## Naming rules

- Lowercase only; `a-z`, `0-9`, `-`, and `.` only in a `release/` version.
- No underscores, spaces or other characters; no `--`, `..`, `-.` or `.-`; no leading or trailing `-` or `.`.
- Description in kebab-case, 2–5 words, about 50 characters in total: `add-oauth-login`, not `fix-bug`.
- Include an issue number when there is one: `feature/issue-123-add-oauth`.
- Use the alias form (`feat/`, `fix/`) only if the repo's existing branches do.

## Workflow

1. **Work out the type and description** from the request (default `feature` when unclear; ask if it matters).
2. **Validate** against the rules; fix what fails (lowercase, replace `_` and spaces with `-`, collapse `--`,
   strip leading and trailing `-`).
3. **Suggest the name.** Say which commit type and scope go with it (table below). When the branch topic matches a
   scope in the repo's history (`git log --oneline -30`), reuse it as the commit scope in [commit.md](commit.md).
4. **Create it only when asked.** Detect the base branch:

   ```bash
   git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'
   ```

   If that's empty, use the first of `develop`, `main`, `master` that exists locally. Then
   `git switch -c <type>/<description> <base>`. Show the commands first; don't pull or push on your own. With
   uncommitted changes, say they come along to the new branch.
5. **Report** the branch name and that pushing (`git push -u origin <branch>`) waits for the user's confirmation.

## Branch type and commit type

| Branch | Typical commit |
| --- | --- |
| `feature/add-login` | `feat(auth): add login page` |
| `bugfix/header-overflow` | `fix(layout): stop header overflow on mobile` |
| `chore/update-deps` | `chore(deps): bump lodash to 5.0` |
| `release/v1.2.0` | `chore(release): release v1.2.0` |

## Examples

- "Name a branch for this fix" (the change fixes a crash when the folder picker is cancelled) →
  `bugfix/folder-picker-cancel-crash`.
- `Feature/Add_Login` → `feature/add-login`.
