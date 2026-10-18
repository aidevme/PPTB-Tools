# Setup

<!-- cspell:ignore speckit -->

Purpose: install the pinned Spec Kit CLI and initialize a Spec Kit project for Claude Code in the right folder,
without the git or agent-context extensions.

**Pinned version: `v1.2.1`** (checked 2026-10-17). This is the one place the version is recorded; change it here
when upgrading ([troubleshooting.md](troubleshooting.md#upgrading-spec-kit)).

## Choose the project folder

Spec Kit's project is the folder that contains `.specify/`, with its own constitution, `specs/` and feature
numbering, and `specify init` installs the `speckit-*` skills in that folder's `.claude/skills/`.

| Repository | Initialize in |
| --- | --- |
| Several independently built packages (for example `tools/<tool-name>/`, `apps/<app>/`) | Each package folder, when it starts using Spec Kit |
| Generates its root `.claude/skills/` with a sync script that deletes folders it doesn't own (for example `agent-src/sync/sync.ps1`) | A package folder, never the root: the sync would delete the `speckit-*` skills |
| A single package with no such sync | The repository root |

Read `AGENTS.md` / `CLAUDE.md` and the folder layout to decide, say which folder you propose and why, and let the
user confirm it. Claude Code started in a package folder loads that folder's skills and every parent's up to the
repository root, so the repository's own skills stay available.

## Workflow

1. **Check what's there** in the chosen folder: `.specify/`, `.claude/skills/speckit-*`, `specs/`. If `.specify/`
   exists, don't initialize again: go back to phase detection in SKILL.md.
2. **Check the tools:** `uv --version` and `specify version`. Python 3.11+ is required.
   - `uv` missing: show the install command and ask before running it.
     - Windows: `winget install --id=astral-sh.uv -e`
     - macOS/Linux: `curl -LsSf https://astral.sh/uv/install.sh | sh`
   - `specify` missing, or not the pinned version: show this and ask before running it:

     ```bash
     uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@v1.2.1
     ```

     A different version is already installed: add `--force` to that command (it reinstalls the CLI only; it
     doesn't touch the repository). Afterwards `specify version` must report 1.2.1.
3. **Ask before initializing.** Show the command and what it creates, then run it from the chosen project folder:

   ```bash
   # Bash
   specify init --here --integration claude --integration-options="--no-model-invocation" --script sh
   ```

   ```powershell
   # PowerShell (Windows default script type is ps)
   specify init --here --integration claude --integration-options="--no-model-invocation" --script ps
   ```

   - `--no-model-invocation` makes the `speckit-*` skills run only when typed as `/speckit-<command>`, so they don't
     trigger on their own and skip this skill's review gates.
   - In a non-empty folder init asks before merging; confirm only on a clean, committed baseline. **Never pass
     `--force`** to `specify init` in a folder that has `.specify/` unless the user says so.
   - Don't add `--preset` here; presets are a separate decision (troubleshooting.md).
4. **Don't install the git or agent-context extensions.** In v1.2.1 neither is installed by `specify init`.
   - **git:** never run `specify extension add git`; aidevme-github owns commits and branches. If
     `specify extension list` shows it, run `specify extension disable git` after asking.
   - **agent-context:** never run `specify extension add agent-context`; it writes a managed block into
     `CLAUDE.md`/`AGENTS.md`. If it's installed, `specify extension disable agent-context` after asking.
5. **Check the result:**
   - `.specify/` exists with `memory/constitution.md`, `templates/`, `scripts/<sh|powershell>/` and
     `init-options.json`;
   - `.claude/skills/speckit-*` exist (at least `speckit-constitution`, `-specify`, `-plan`, `-tasks`,
     `-implement`, `-converge`);
   - `git status` and `git diff` show no change to `AGENTS.md`, `CLAUDE.md` or anything outside the project folder
     (v1.2.1 doesn't touch them); if they changed, stop and show the diff;
   - `specify extension list` doesn't list `git` or `agent-context` as enabled.
6. **Report** what was created, and that Claude Code should be restarted in the project folder so it loads the new
   skills. The next
   phase is the constitution ([constitution.md](constitution.md)). Committing the new files goes through
   aidevme-github ([github-handoff.md](github-handoff.md)).

## Review gate

The user approves (a) installing `uv` or `specify-cli`, (b) running `specify init`, and (c) the list of created
files before the constitution phase starts.

## Safety

- Ask before every install and before `specify init`; never use `--force` on init without an explicit request.
- Never change git config, MCP config or Spec Kit's generated files.

## Example

"Set up spec kit for tools/zip-exporter" in a repository whose root `.claude/skills/` is generated by a sync: propose
`tools/zip-exporter/` as the project folder and say why, report that `specify` isn't installed, show the pinned
`uv tool install` command and the `specify init … --script ps` command to run there, wait for approval, run them,
then list `tools/zip-exporter/.specify/` and its `speckit-*` skills and confirm nothing outside it changed.
