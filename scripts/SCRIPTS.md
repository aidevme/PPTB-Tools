# Repository scripts

PowerShell maintenance scripts for the PPTB-Tools repository. They keep the documentation tooling in order:
Markdown linting, spell-check vocabulary, and code ownership of the `docs/` folder. None of them builds, tests or
publishes a tool; each tool under `tools/` has its own npm scripts for that.

| Script | What it does | Changes files? |
| --- | --- | --- |
| [`Validate-Markdown.ps1`](#validate-markdownps1) | Runs markdownlint and cspell on every Markdown file | No |
| [`Sync-Cspell.ps1`](#sync-cspellps1) | Adds words cspell doesn't know to `cspell.json`, asking first | `cspell.json` |
| [`Sync-Code-Owners.ps1`](#sync-code-ownersps1) | Regenerates the `docs/` entries in `.github/CODEOWNERS` | `.github/CODEOWNERS` |

All three resolve paths from the repository root (the folder above `scripts/`), so they can be run from any
working directory. None of them is called by CI or by an npm script today; run them by hand.

## Prerequisites

| Requirement | Needed by | Notes |
| --- | --- | --- |
| PowerShell 7+ (`pwsh`) | All | Each script starts with `#!/usr/bin/env pwsh`. Windows PowerShell 5.1 may work but isn't the target. |
| Node.js and npm | `Sync-Cspell.ps1` | Runs cspell through `npx` and formats `cspell.json` with `node`. |
| `markdownlint-cli2` on `PATH` | `Validate-Markdown.ps1` | A root devDependency (`npm install` at the root), but the script calls it directly, so it must be on `PATH`: install it globally (`npm install -g markdownlint-cli2`) or run the script from a shell where `node_modules/.bin` is on `PATH`. |
| `cspell` | `Validate-Markdown.ps1`, `Sync-Cspell.ps1` | Not a repository dependency. `Validate-Markdown.ps1` calls it directly, so install it globally (`npm install -g cspell`); `Sync-Cspell.ps1` uses `npx cspell`, which downloads it if needed. |
| Git | `Sync-Code-Owners.ps1` | Lists the tracked files under `docs/` with `git ls-files`. |

If PowerShell blocks the scripts on Windows, run them with
`pwsh -ExecutionPolicy Bypass -File scripts\<Script>.ps1`, or allow local scripts once with
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

## Configuration files

The scripts read the repository's shared lint configuration, which the VS Code extensions also use:

| File | Used by | Contents |
| --- | --- | --- |
| `cspell.json` | cspell | Project word list (`words`, sorted case-insensitively) and `ignorePaths` (`node_modules/**`, `.git/**`, `.github/**`, `.claude/**`). |
| `.markdownlint.jsonc` | markdownlint-cli2 | The default rule set, with MD013 (line length) and MD033 (inline HTML) off, and MD025 set to ignore the front-matter `title`. |
| `.github/CODEOWNERS` | `Sync-Code-Owners.ps1` | Code owners; the script only edits the block between its markers. |

---

## Validate-Markdown.ps1

Runs the two Markdown checks over the whole repository: **markdownlint** for formatting and structure, then
**cspell** for spelling. It only reports; it never changes a file.

### Validate-Markdown: usage

```powershell
./scripts/Validate-Markdown.ps1
```

It takes no parameters.

### Validate-Markdown: what it runs

```powershell
markdownlint-cli2 "**/*.md" "!.venv" "!.github" "!node_modules"
cspell --no-progress --no-summary "**/*.md"
```

- **markdownlint-cli2** checks every `*.md` file except those under `.venv`, `.github` and `node_modules`, using
  `.markdownlint.jsonc`.
- **cspell** checks every `*.md` file, skipping the `ignorePaths` in `cspell.json`, and prints one line per
  unknown word, in the form `file.md:12:5 - Unknown word (someWord)`.

### Validate-Markdown: results

- Problems are printed to the console; fix them in the files, or add genuine words with
  [`Sync-Cspell.ps1`](#sync-cspellps1).
- **Exit code:** the script reports cspell's exit code only, because it doesn't stop or combine results when
  markdownlint fails. Read the markdownlint output rather than relying on the exit code, and don't use the script
  as a CI gate as it stands.

### Validate-Markdown: related

- `npm run lint:md` at the root runs markdownlint alone, through the root `node_modules`, so it doesn't need a
  global install.

---

## Sync-Cspell.ps1

Finds the words cspell doesn't know in the Markdown files and adds the ones you approve to the `words` list in
`cspell.json`, keeping the list sorted.

### Sync-Cspell: usage

```powershell
./scripts/Sync-Cspell.ps1 [-AutoAdd] [-MarkdownPath <string[]>]
```

### Sync-Cspell: parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `-AutoAdd` | switch | off | Adds every unknown word without asking. |
| `-MarkdownPath` | string[] | `**/*.md` | Markdown files or glob patterns to check, relative to the repository root. |

### Sync-Cspell: what it does

1. **Runs cspell** with `npx cspell <paths> --no-progress --no-summary` from the repository root.
2. **Collects unknown words** from lines like `file.md:12:5 - Unknown word (someWord)`, removing duplicates
   (case-insensitive).
3. **Asks about each new word**: `Add 'someWord' to cspell.json? [y/N]`. Only `y` adds it; Enter or anything
   else skips it. Words already in `cspell.json` (case-insensitive) are skipped without asking. With
   `-AutoAdd`, every new word is added.
4. **Saves `cspell.json`** if anything was added: the `words` list is sorted case-insensitively, written as UTF-8
   without a BOM, then reformatted by Node with two-space indentation and a trailing newline.

### Sync-Cspell: results

| Outcome | Message | Exit code |
| --- | --- | --- |
| No unknown words | `No unknown words found. cspell.json is up to date.` | 0 |
| Nothing approved | `No words were added.` | 0 |
| Words added | `Added N word(s) to cspell.json: …` | 0 |
| `cspell.json` couldn't be formatted | `Failed to format cspell.json.` (error) | non-zero |

### Sync-Cspell: examples

```powershell
# Review each unknown word in the whole repository
./scripts/Sync-Cspell.ps1

# Accept every unknown word without prompting
./scripts/Sync-Cspell.ps1 -AutoAdd

# Only check one document
./scripts/Sync-Cspell.ps1 -MarkdownPath docs/index.md

# Several files or patterns
./scripts/Sync-Cspell.ps1 -MarkdownPath 'docs/**/*.md', README.md -AutoAdd
```

### Sync-Cspell: notes

- **Review before `-AutoAdd`.** It accepts genuine typos as well as genuine words; prefer the interactive mode, or
  check the `cspell.json` diff before committing.
- **Interactive by default.** Without `-AutoAdd` it waits for input, so it can't run unattended.
- **Only "Unknown word" lines count.** If cspell fails for another reason (a bad glob, a broken config), the
  script reports no unknown words instead of the failure. If that looks wrong, run `npx cspell <paths>` directly.
- **Whole-file rewrite.** `cspell.json` is read and rewritten in full, so manual formatting in it isn't kept
  (the file has no comments to lose).

---

## Sync-Code-Owners.ps1

Keeps the `docs/` part of `.github/CODEOWNERS` in step with the `docs/` folder: it generates one ownership entry
per documentation file or folder and replaces a marked block in CODEOWNERS with them. The rest of the file is left
alone.

> **Current status: not usable yet.** `.github/CODEOWNERS` contains only `* @aidevme` and none of the markers the
> script needs, so every run stops with "Could not find '# BEGIN AUTO-GENERATED: docs' / '# END AUTO-GENERATED: docs'
> markers". See [Sync-Code-Owners: setting it up](#sync-code-owners-setting-it-up). Until then, the `*` rule already makes `@aidevme` the owner of
> everything, including `docs/`.

### Sync-Code-Owners: usage

```powershell
./scripts/Sync-Code-Owners.ps1 [-Owner <string>] [-Check] [-WhatIf]
```

### Sync-Code-Owners: parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `-Owner` | string | `@aidevme` | GitHub user or team (`@user` or `@org/team`) set as owner of every generated entry. |
| `-Check` | switch | off | Doesn't write anything; exits with code 1 if the block is out of date and prints what it should be. For CI. |
| `-WhatIf` | switch | off | Doesn't write anything; prints the lines that would be added (`+`, green) and removed (`-`, red). |

`-WhatIf` here is the script's own switch, not PowerShell's common `-WhatIf` parameter.

### Sync-Code-Owners: what it generates

The script lists the **git-tracked** files under `docs/` (`git ls-files -- docs`), so gitignored build output such
as `docs/.vitepress/dist` and `docs/.vitepress/cache` never appears. From them it builds:

- one entry for each file **directly** in `docs/`, e.g. `docs/index.md`;
- one `<folder>/**` entry for each folder, at any depth, that **directly** contains at least one tracked file,
  e.g. `docs/pptb-tools/dataverse-early-bound-typescript-generator/components/**`.

Entries are sorted case-insensitively, and each owner is aligned at column 65 (patterns are padded to 64
characters). The block replaces everything between, and including, these marker lines:

```text
# BEGIN AUTO-GENERATED: docs
docs/index.md                                                   @aidevme
docs/pptb-tools/dataverse-early-bound-typescript-generator/**   @aidevme
…
# END AUTO-GENERATED: docs
```

Because a folder gets its own entry whenever it holds files directly, a parent and its subfolder can both be
listed (for example `docs/a/**` and `docs/a/b/**`). That's harmless: both name the same owner.

### Sync-Code-Owners: results

| Outcome | Message | Exit code | File changed? |
| --- | --- | --- | --- |
| Block already matches | `CODEOWNERS docs/ section is already up to date.` | 0 | No |
| `-Check`, block differs | `CODEOWNERS docs/ section is out of date…` plus the expected block | 1 | No |
| `-WhatIf`, block differs | `CODEOWNERS docs/ section would change:` plus a `+`/`-` diff | 0 | No |
| Block differs | `Updated CODEOWNERS with N docs/ entries owned by <owner>.` | 0 | Yes |
| CODEOWNERS missing | `CODEOWNERS file not found at …` (error) | non-zero | No |
| No tracked files under `docs/` | `No git-tracked files found under docs/…` (error) | non-zero | No |
| Markers missing or in the wrong order | `Could not find '# BEGIN AUTO-GENERATED: docs' / …` (error) | non-zero | No |
| `git ls-files` fails | `git ls-files failed.` (error) | non-zero | No |

When it writes, the whole file is saved as UTF-8 without a BOM, with LF line endings and a trailing newline.

### Sync-Code-Owners: examples

```powershell
# Update the block
./scripts/Sync-Code-Owners.ps1

# Preview the change
./scripts/Sync-Code-Owners.ps1 -WhatIf

# Fail if out of date (CI)
./scripts/Sync-Code-Owners.ps1 -Check

# Assign the docs to a team
./scripts/Sync-Code-Owners.ps1 -Owner '@aidevme/docs-team'
```

### Sync-Code-Owners: setting it up

1. **Add the markers** to `.github/CODEOWNERS`, after the global rule. CODEOWNERS uses the **last** matching
   pattern, so entries below `*` take precedence for `docs/`:

   ```text
   # Global Owner

   * @aidevme

   # BEGIN AUTO-GENERATED: docs
   # END AUTO-GENERATED: docs
   ```

2. Run `./scripts/Sync-Code-Owners.ps1 -WhatIf` to preview, then without `-WhatIf` to fill the block.
3. **Re-run it whenever docs are added, moved or deleted.** New files must be committed (tracked) first, because
   untracked files are ignored.
4. Optionally run it with `-Check` in a workflow that triggers on changes under `docs/`, so CI catches drift.

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `markdownlint-cli2` or `cspell` "is not recognized" | The tool isn't on `PATH` | Install it globally (`npm install -g markdownlint-cli2 cspell`), or use `npm run lint:md` for markdownlint |
| "…cannot be loaded because running scripts is disabled" | Windows execution policy | `pwsh -ExecutionPolicy Bypass -File scripts\<Script>.ps1` |
| `Sync-Code-Owners.ps1`: "Could not find … markers" | No marker block in CODEOWNERS | See [Sync-Code-Owners: setting it up](#sync-code-owners-setting-it-up) |
| `Sync-Code-Owners.ps1` ignores a new doc | The file isn't tracked by git yet | `git add` it, then run the script again |
| `Sync-Cspell.ps1` finds nothing, but cspell reports errors | cspell failed for a reason other than unknown words | Run `npx cspell <paths>` to see the real error |
| Validation passes in the script but markdownlint printed problems | The script's exit code only reflects cspell | Read the markdownlint output; see [Validate-Markdown: results](#validate-markdown-results) |

## Known limitations

- **Exit code of `Validate-Markdown.ps1`.** It doesn't fail when markdownlint finds problems.
- **Ignore file name.** The root has a file named `markdownlintignore` (no leading dot) containing `.github/`.
  markdownlint-cli2 looks for `.markdownlintignore`, so this file probably has no effect; the script excludes
  `.github` through its own glob instead.
- **`.claude/` folder.** markdownlint checks Markdown under `.claude/` (agents and skills, including skills copied
  from other repositories), while cspell skips it.
- **`cspell` not in the repository.** It has to be installed globally, or fetched by `npx`.
- **`Sync-Code-Owners.ps1`.** It can't run until CODEOWNERS has the markers.
