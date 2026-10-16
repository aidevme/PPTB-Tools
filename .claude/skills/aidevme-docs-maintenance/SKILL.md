---
name: aidevme-docs-maintenance
layer: atomic
scope: project
description: |
  Keep this repository's documentation tooling in order with three PowerShell scripts: validate Markdown
  (markdownlint + cspell), sync the cspell word list (cspell.json), and sync the docs/ entries in
  .github/CODEOWNERS. Use when:
  (1) User says "validate markdown", "lint the docs", "spell check the docs", "run markdownlint/cspell"
  (2) cspell reports unknown words, or user says "add words to cspell", "sync cspell"
  (3) User says "update CODEOWNERS", "sync code owners", or docs/ folders were added, moved or removed
  (4) Before committing documentation changes
  Does NOT build or test the tools (each tool has its own npm scripts), does NOT build the VitePress site
  (`npm run docs:build`), and never adds spelling words without the user's approval.
allowed-tools: Bash, PowerShell, Read, Grep, Glob, Edit
argument-hint: "[validate | cspell | codeowners] [paths]"
---

# aidevme-docs-maintenance

Three maintenance scripts for the repository's documentation, in `scripts/` next to this file. Full reference
(parameters, outputs, exit codes, prerequisites): [`references/scripts.md`](references/scripts.md).

| Script | What it does | Changes files? |
| --- | --- | --- |
| `Validate-Markdown.ps1` | markdownlint, then cspell, on Markdown files | No |
| `Sync-Cspell.ps1` | Lists unknown words, or adds approved ones to `cspell.json` | `cspell.json` |
| `Sync-Code-Owners.ps1` | Regenerates the `docs/` block in `.github/CODEOWNERS` | `.github/CODEOWNERS` |

Run the copy for your assistant from the repository root; each script finds the root itself:

```powershell
$scripts = '.claude/skills/aidevme-docs-maintenance/scripts'   # GitHub Copilot: .github/skills/...
pwsh -NoProfile -File "$scripts/Validate-Markdown.ps1"
```

The scripts' source is `agent-src/skills/project/repo/aidevme-docs-maintenance/scripts/`. To change a script, edit
the source, then run `pwsh -File agent-src/sync/sync.ps1` and `agent-src/sync/verify-parity.ps1`; never edit the
generated copies.

## Workflow 1: Validate Markdown

1. **Pick the files.** For a change, check only the Markdown files it touches (`git diff --name-only -- '*.md'`
   plus new files); for a full check, use the default (`**/*.md`).
2. **Run** `Validate-Markdown.ps1 -Path <file1>,<file2>` (comma-separated: `pwsh -File` can't pass a list otherwise). It always runs both checks and exits 1 if either fails, naming
   which (`Markdown validation failed: markdownlint, cspell`).
3. **markdownlint findings:** fix them in the files (rules in `.markdownlint.jsonc`). Don't disable a rule to make
   a finding go away without asking.
4. **cspell findings** (`file.md:12:5 - Unknown word (someWord)`): go to Workflow 2.
5. **Re-run** until it passes, and report the result honestly, including findings in files you didn't touch.

## Workflow 2: Sync the cspell word list

Never use `-AutoAdd`: it adds typos too. Instead:

1. **List** the unknown words: `Sync-Cspell.ps1 -ListOnly [-MarkdownPath <files>]`. It changes nothing.
2. **Classify each word** and show the user the result:
   - **Typo:** fix it in the document.
   - **One-off identifier** (a column, file or code name used on one page): add it to that page's
     `<!-- cspell:ignore word1 word2 -->` comment after the H1, as the repository's docs already do.
   - **Genuine term used across the docs** (a product, library or domain word): propose it for `cspell.json`.
3. **Add only the approved words:** `Sync-Cspell.ps1 -Word word1,word2`. It keeps the list sorted and skips words
   that are already there.
4. **Re-run** Workflow 1 to confirm the spelling check passes.

## Workflow 3: Sync code owners

1. **Preview:** `Sync-Code-Owners.ps1 -WhatIf` prints the `+`/`-` lines without writing.
2. **If it stops with "Could not find '# BEGIN AUTO-GENERATED: docs' …"**, `.github/CODEOWNERS` doesn't have the
   markers yet. Tell the user and propose adding them after the `* @aidevme` rule (see "Sync-Code-Owners: setting it
   up" in the reference); don't add them without approval.
3. **Write** with `Sync-Code-Owners.ps1` (owner `@aidevme` by default, `-Owner` to change it) once the user agrees
   with the preview. Only the marked block changes.
4. **Check only** (for example before a commit, or in CI): `Sync-Code-Owners.ps1 -Check` exits 1 when the block is
   out of date.

## Rules

- **Approval before changing shared files.** Show the word list before `-Word`, and the `-WhatIf` diff before
  writing CODEOWNERS.
- **Report what actually ran.** Quote exit codes and remaining findings; don't call a check passed that wasn't run.
- **The scripts need** PowerShell 7, Node.js (`npm install` at the root, for markdownlint-cli2) and Git; cspell runs
  through `npx`.

## Changelog

| Date | Author | Description |
| --- | --- | --- |
| 2026-10-16 | aidevme | Created from the repository's `scripts/` folder. The scripts find the root with git; `Validate-Markdown.ps1` gained `-Path`, runs through npx and fails when either check fails; `Sync-Cspell.ps1` gained `-ListOnly` and `-Word`. |
