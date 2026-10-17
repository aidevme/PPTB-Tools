---
name: aidevme-github
layer: atomic
scope: core
description: |
  Commit changes in a git repository one file at a time, each with its own Conventional Commits 1.0.0 message
  written for that file's diff. Use when:
  (1) User says "commit this", "commit my changes", "commit each file", "stage and commit"
  (2) User asks for commit messages, or to split changes into separate commits
  (3) A task ends with changes the user asked to have committed
  Does NOT commit without being asked, push, force-push, amend pushed commits, bypass hooks (--no-verify), rebase
  shared branches, change git config, or commit secrets, build output or dependencies.
allowed-tools: Bash, PowerShell, Read, Grep, Glob, AskUserQuestion
argument-hint: "[file ... | --staged]"
---

# aidevme-github: one commit per file, Conventional Commits

<!-- cspell:ignore oneline -->

Reference: [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)

Use this skill whenever the user asks to commit, stage or write commit messages ("commit this", "commit my
changes"). Committing is something the user asks for; never commit on your own initiative.

**Default mode: one commit per file.** Every changed file gets its own commit, with a message written for that
file's diff. The user can override this (for example "one commit for all of it"), and coupled files can be grouped
with the user's agreement (step 5).

## Workflow

1. **Inspect the repo state**
   - `git status --porcelain` lists every change: modified, added, deleted, renamed, untracked.
   - `git log --oneline -15` shows the repo's types, scopes, casing and style. Match them.
   - Read the repo's own commit rules if it has them (`CONTRIBUTING.md`, `AGENTS.md`, `CLAUDE.md`, a
     `commitlint` config); they take precedence over the house style below.
   - If nothing changed, say so and stop.

2. **Respect what's already staged.** If the user staged files deliberately, process only those (or the files and
   paths passed as arguments) unless they ask otherwise. Otherwise process every changed file, untracked files
   included, after the safety check.

3. **Safety check before anything is staged**
   - Never commit secrets: `.env*`, keys and certificates (`*.pem`, `*.pfx`, `*.key`), tokens, connection strings,
     `local.settings.json`, publish profiles, `CLAUDE.local.md` and other per-developer files. Skip them and warn
     the user.
   - Skip build output and dependencies (`bin/`, `obj/`, `dist/`, `node_modules/`, `out/`, coverage) and large
     binaries; suggest `.gitignore` entries.
   - If a file's diff contains what looks like a credential, skip it and say why.

4. **Read each file's diff on its own**
   - Modified: `git diff -- <file>`; staged: `git diff --cached -- <file>`.
   - Untracked (new): read the file.
   - Deleted: note what the file was for (`git show HEAD:<file>` if needed).
   - Renamed or moved: one change (old path → new path), one commit; stage both sides (`git add -A -- <old> <new>`).

5. **Check for coupled files.** Some files only make sense together, and committing them apart leaves commits that
   don't build or test. Typical groups:
   - a source file and the test that depends on its new code;
   - `package.json` and `package-lock.json` (or a project file and its lock file);
   - a component and its manifest when a new property is added (for example a PCF `index.ts` and
     `ControlManifest.Input.xml`);
   - a renamed or moved file and the files that update their imports to it;
   - a generated file and its source (regenerate it; don't hand-edit it).

   List the coupled groups and ask once whether to keep each group in one commit or still split per file. If the
   user already said "strictly per file", don't ask.

6. **Write one message per file (or agreed group)** using the rules below. Each message describes that file's
   change specifically; never reuse a description across files. Show the plan as a table:

   | # | File | Message |
   | --- | --- | --- |
   | 1 | `src/TagPicker.tsx` | `feat(pcf): add multi-select support to tag picker` |
   | 2 | `README.md` | `docs(readme): document allowMultiple property` |

   Add a body for any change that needs explaining (why, not how).

7. **Commit file by file** after the user confirms the plan (skip the confirmation only if they said "just commit").
   Order the commits so each builds on the previous: dependencies and config first, then source, then tests, then
   docs. For each file:

   ```bash
   git add -- <file>          # git rm -- <file> for a deletion
   git diff --cached --name-only   # must list exactly this file, or the agreed group
   git commit -F - <<'EOF'
   feat(pcf): add multi-select support to tag picker

   Optional body for this file.
   EOF
   ```

   If something else is already staged, unstage it first (`git restore --staged -- <other>`), so each commit holds
   only its own file. In PowerShell, pass the message with a single-quoted here-string instead of `<<'EOF'`.

8. **Confirm** with `git log --oneline -n <count>` and a short summary: commits created, files skipped and why.

9. **Never, unless explicitly asked:** `git push`, `--force`, `--amend` on commits already pushed, `--no-verify`,
   rebasing shared branches, or changing git config. If a pre-commit hook fails on a file, stop, report the error
   and fix the cause; don't bypass the hook or continue with the remaining files until it's resolved.

## Message format (Conventional Commits 1.0.0)

```text
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

### Rules from the spec

- The prefix is required: a type, an optional `(scope)`, an optional `!`, then a colon and a space (`:` followed by a space).
- `feat` must be used for a new feature; `fix` must be used for a bug fix.
- A scope is a noun for a section of the codebase, in parentheses: `fix(parser):`.
- The description follows the colon and space directly.
- The body starts one blank line after the description; free-form, any number of paragraphs.
- Footers start one blank line after the body. Each is `Token: value` or `Token #value`. Tokens use `-` instead of
  spaces (`Reviewed-by`, `Refs`), except `BREAKING CHANGE`.
- Breaking changes: `!` just before the colon, and/or a footer `BREAKING CHANGE: <description>` (uppercase;
  `BREAKING-CHANGE` is equivalent). Any type can be breaking.

### House style (on top of the spec)

- Lowercase type and scope. Description in the imperative mood ("add", not "added" or "adds"), lowercase start, no
  trailing period, and the whole first line within about 72 characters.
- **Types:** `feat`, `fix`, `docs`, `style` (formatting only), `refactor` (no behavior change), `perf`, `test`,
  `build`, `ci`, `chore`, `revert`. Use only the types the repo uses when it lists them.
- **Scope:** the area the file belongs to, taken from the repo's history first (a package, tool, folder or
  feature name, for example `tools`, `docs`, `pcf`, `auth`). Omit the scope when no area fits rather than inventing
  one.
- **Body:** wrap at about 72 characters; say why the change was made and anything a reviewer must know (behavior
  change, migration, follow-up). Don't restate the diff.
- **Footers:** `Refs #123` or `Closes #123` for issues; `BREAKING CHANGE:` for breaking changes. Add an attribution
  trailer (for example `Co-Authored-By:`) only when the repository or your environment's instructions ask for it,
  with exactly the text given there.
- **Examples:**
  - `fix(connections): handle invalid connection urls`
  - `docs(api): add missing type definitions`
  - `chore(deps): update typescript to 5.9`
  - `feat(settings)!: store settings per connection` with a `BREAKING CHANGE:` footer explaining the migration

## Changelog

| Date | Author | Description |
| --- | --- | --- |
| 2026-10-17 | aidevme | Created: one commit per file with Conventional Commits 1.0.0 messages; repo-state inspection, safety check, per-file diffs, coupled-file grouping, plan table and confirmation, ordered commits, and the never-push/never-bypass rules. |
