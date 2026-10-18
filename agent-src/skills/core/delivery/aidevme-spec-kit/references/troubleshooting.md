# Troubleshooting

<!-- cspell:ignore speckit taskstoissues -->

Purpose: fixes for common Spec Kit problems in Claude Code, checked against v1.2.1.

## Renamed flags and commands

| Older | v1.2.1 |
| --- | --- |
| `specify init --ai claude` | `specify init --integration claude` |
| `/speckit.<command>` (dot form) | `/speckit-<command>` for Claude Code skills |
| `/speckit-taskstoissues` | Deprecated (warns); replaced by the `github` extension. Here: aidevme-github instead |
| Git branching built into init | Opt-in `git` extension (not installed by default) |

Check the installed names in `.claude/skills/speckit-*` and with `specify version`; when they differ from this
table, follow the installed version and update these references.

## Windows and PowerShell

- On Windows `specify init` defaults to `--script ps`, installing `.specify/scripts/powershell/`. Pass `--script ps`
  explicitly so the choice is recorded.
- Quote the integration options in PowerShell: `--integration-options="--no-model-invocation"`.
- `uv` installs `specify` into a user tools folder; open a new terminal if `specify` isn't found after install.

## Re-running init safely

- A repository with `.specify/` doesn't need `specify init` again. To refresh the Claude files use
  `specify integration upgrade claude`; it stops on locally edited managed files unless `--force` is passed.
- `specify init --here --force` keeps an existing `.specify/memory/constitution.md`, but can overwrite other managed
  files. Use it only on the user's explicit request, after the work is committed.
- `--no-model-invocation` is stored with the integration options and reapplied by `specify integration upgrade
  claude`. Installing, removing or updating a preset (and `specify integration use|switch claude`) reverts the core
  skills that preset overrides; reapply with `specify integration upgrade claude --force` after asking (`--force`
  overwrites local edits to Spec Kit's managed files). Passing `--integration-options` to `upgrade` replaces all
  stored options, so repeat every option you want to keep.

## Upgrading Spec Kit

1. Commit or back up local changes first (through aidevme-github).
2. Reinstall the CLI at the new tag: `uv tool install specify-cli --force --from
   git+https://github.com/github/spec-kit.git@<tag>`.
3. Refresh the project files: `specify integration upgrade claude`.
4. Update the pinned version in [setup.md](setup.md) and re-check the command names here.

Local customizations survive when they live in `.specify/templates/overrides/` or a preset: overrides are resolved
first, then presets by priority, then extensions, then core templates. Edits made directly to core templates or
scripts are preserved only while they match the recorded copy, so don't make them.

## "speckit command not found" after init

- Restart Claude Code or reload skills; new skills in `.claude/skills/` aren't picked up mid-session.
- Check `.claude/skills/speckit-*` exists. In a repository with a skills sync, a sync may have deleted them (see
  [setup.md](setup.md)); restore them with `specify integration upgrade claude`.
- With `--no-model-invocation` the skills don't trigger on their own; type `/speckit-<command>`.

## Review gate

The user approves every fix that reinstalls the CLI, upgrades the integration, uses `--force`, or installs a preset,
before it runs.

## Customizing templates

Never edit `.specify/templates/` or the `speckit-*` skills. One-off change: put the template in
`.specify/templates/overrides/`. Reusable change: a preset (`specify preset add <id>`), installed only after the user
approves it. TODO: verify against Spec Kit v1.2.1 which file names in `overrides/` map to which templates
(`docs/reference/presets.md`, "File resolution").
