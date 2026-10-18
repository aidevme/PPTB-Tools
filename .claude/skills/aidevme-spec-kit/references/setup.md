# Setup

<!-- cspell:ignore speckit -->

Purpose: install the pinned Spec Kit CLI and initialize the repository for Claude Code, without the git or
agent-context extensions.

**Pinned version: `v1.2.1`** (checked 2026-10-17). This is the one place the version is recorded; change it here
when upgrading ([troubleshooting.md](troubleshooting.md#upgrading-spec-kit)).

## Before anything: the skill sync

> **TODO (blocks setup in repositories that generate `.claude/skills/`):** in a repository with a skills sync (for
> example `agent-src/sync/sync.ps1`), the sync deletes every folder in `.claude/skills/` and the parity check fails
> on folders that aren't in the source, so it removes Spec Kit's `speckit-*` skills. Don't initialize until the sync
> and parity check skip `speckit-*` folders. Stop and tell the user if they don't.

## Workflow

1. **Check what's there:** `.specify/`, `.claude/skills/speckit-*`, `specs/`. If `.specify/` exists, don't
   initialize again: go back to phase detection in SKILL.md.
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
3. **Ask before initializing.** Show the command and what it creates, then run it from the repository root:

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
   - In a non-empty repository init warns about merging. **Never pass `--force`** to `specify init` in a repository
     that has `.specify/` unless the user says so.
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
   - `git status` and `git diff` show no change to `AGENTS.md` or `CLAUDE.md` (v1.2.1 doesn't touch them); if they
     changed, stop and show the diff;
   - `specify extension list` doesn't list `git` or `agent-context` as enabled.
6. **Report** what was created and that the new skills may need a Claude Code restart or skills reload. The next
   phase is the constitution ([constitution.md](constitution.md)). Committing the new files goes through
   aidevme-github ([github-handoff.md](github-handoff.md)).

## Review gate

The user approves (a) installing `uv` or `specify-cli`, (b) running `specify init`, and (c) the list of created
files before the constitution phase starts.

## Safety

- Ask before every install and before `specify init`; never use `--force` on init without an explicit request.
- Never change git config, MCP config or Spec Kit's generated files.

## Example

"Set up spec kit" in a repository without `.specify/`: report that `specify` isn't installed, show the pinned
`uv tool install` command and the `specify init … --script ps` command, wait for approval, run them, then list
`.specify/` and the `speckit-*` skills and confirm `CLAUDE.md` is unchanged.
