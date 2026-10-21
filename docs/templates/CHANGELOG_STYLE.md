# Changelog Style Guide

**Version:** 1.1.0 · **Last updated:** 2026-10-21

<!-- cspell:ignore tsdoc -->

This guide sets the structure and writing rules for `CHANGELOG.md` files in this repository: the history of an agent
skill, a tool or another unit that people use and need to know has changed. It's modelled on the
[aidevme-tsdoc changelog](https://github.com/aidevme/PPTB-Tools/blob/main/agent-src/skills/core/delivery/aidevme-tsdoc/CHANGELOG.md)
and follows the categories of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). For general writing rules,
see [WRITING_STYLE.md](WRITING_STYLE.md).

**A changelog tells a user what changed and why it matters to them, newest first, grouped by date (or version) and
then by kind of change. Each entry is one short paragraph that leads with the change in bold and ends with the
commit; the reasoning and evidence stay in the commit, the spec or the pull request.**

## Scope

| Belongs in `CHANGELOG.md` | Belongs elsewhere |
| --- | --- |
| Changes a user of the skill or tool notices: new behavior, changed rules or defaults, fixes, removals | How the change was made, alternatives, test evidence: the commit message, spec or pull request |
| A one-line pointer to where the detail is (the commit, a reference file) | Step-by-step instructions: the skill's `SKILL.md` or references, the tool's docs |
| Breaking changes, with what to do instead | Internal refactors no user can see (leave them out) |

Where a changelog lives:

- **Agent skills:** `agent-src/skills/<scope>/<group>/<name>/CHANGELOG.md`, next to `SKILL.md`. Edit the source only;
  `sync.ps1` copies it to `.claude/skills/` and `.github/skills/`. The skill's `SKILL.md` keeps its short
  **Changelog** table (date, author, one-line description), which the skill rules require; the table can point to
  `CHANGELOG.md` for the full history.
- **Tools:** `tools/<tool-name>/CHANGELOG.md`, when the tool is released with versions.

## Document structure

A changelog is, in order:

1. `# Changelog`, the only H1.
1. File-level comments: `cspell:ignore` for the words cspell doesn't know, and the markdownlint setting that lets
   every release repeat the category headings (see [Markdown checks](#markdown-checks)).
1. An intro of two or three sentences: what the file covers (name the skill or tool), the order (newest first), the
   promise ("what changed and why it matters to you; the commit has the detail"), and, for a skill, where its source
   is.
1. One `##` per release, newest first.
1. Under each release, one `###` per category that has entries, in this order: **Added**, **Changed**,
   **Deprecated**, **Removed**, **Fixed**, **Security**. Leave out categories with nothing in them.

## Releases

- **Unversioned units** (most skills): the heading is the date, `## 2026-10-21`. Use the date the change was
  committed, in `YYYY-MM-DD`. Several commits on one day share one heading.
- **Versioned units** (released tools): the heading is the version and the date, `## [1.4.0] - 2026-10-21`.
- **Unreleased changes**, when the unit is versioned: keep an `## Unreleased` section at the top and move its
  entries under the version heading when you release.
- **Never rewrite history.** Correct a wrong entry with a new entry ("Fixed: the 1.3.0 entry said … ; it's …"), not
  by editing the old one, unless the old one has a broken link or a typo.

## Entries

Each entry is one bullet:

```markdown
- **What changed, as a short noun phrase.** What it does now and why that matters to the reader, in one to three
  sentences, naming the file, option or command they'll meet. (abc1234)
```

- **Lead with the change in bold**, as a phrase a reader can scan: "**Links to tsdoc.org for every tag**",
  "**The check reports only TSDoc findings.**" Not "Updated tags.md".
- **Say what it means for the reader**, not how it was implemented. "Every exported function documents each
  parameter" rather than "Added a rule to rules.md".
- **Name what they'll meet**: the file (as a relative link when it's in the same unit, such as
  `[references/tags.md](references/tags.md)`), option, command or setting.
- **End with the commit**, as its short SHA in parentheses, `(55e909f)`. Several commits for one change: list them,
  `(95212a6, 35342a5)`. A plain SHA, not a link: links to commits break when a branch is rebased before merging.
  The SHA doesn't exist until the change is committed, so the entry that ships with a change has none; add it the
  next time the file changes.
- **Breaking changes** start with `**Breaking:**` and say what to do instead.
- **Fixed** entries say what was wrong from the user's side ("eslint-disable comments showed up as unknown rules")
  and what happens now.
- **Versions and sources**: when a change was checked against a specific version of something (a standard, a CLI, a
  plugin), name it, as `TSDoc 76dcd8e` or `eslint-plugin-tsdoc 0.5.4`.
- Keep entries short: if one needs more than three sentences, the rest belongs in the commit or the docs.

## Writing rules

- Follow [WRITING_STYLE.md](WRITING_STYLE.md): plain words, present tense for what the unit does now, no marketing
  language ("powerful", "seamless").
- Write for the person using the skill or tool, not for its maintainers.
- One change per bullet. Don't mix a fix and a new feature in one entry.
- Don't repeat the release date or version inside entries.
- Code, file names, options and commands go in backticks.

## Markdown checks

- Every release repeats headings such as `### Added`, which markdownlint's `MD024` (no duplicate headings) reports.
  Put this comment at the top of the file, so it only reports duplicates under the same release:

  ```markdown
  <!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->
  ```

- Add the words cspell doesn't know to a `<!-- cspell:ignore … -->` comment at the top of the file. Add them to
  `cspell.json` only when they're used across the repository, through the `aidevme-docs-maintenance` skill.
- For a skill, `agent-src/sync/update-changelog.ps1` creates the changelog from the [Template](#template) below (filled
  in from `SKILL.md`) and adds entries in the right release and category; `sync.ps1` and the Claude Code hook call it
  for new skills. Keep this template's placeholders as they are: the script fills them in by name.
- Run `Validate-Markdown.ps1` (the `aidevme-docs-maintenance` skill) on the changelog before committing. For a skill,
  also run `agent-src/sync/sync.ps1`, `agent-src/sync/verify-parity.ps1` and `agent-src/sync/check-changelogs.ps1`,
  which fails when an `aidevme-*` skill has no `CHANGELOG.md` or was changed without it.

## Template

Copy this, replace the angle-bracket placeholders, and delete the categories a release doesn't use.

```markdown
# Changelog

<!-- cspell:ignore <words cspell doesn't know> -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

All notable changes to the **<skill or tool name>** <skill | tool>: <what it does, in a few words>. Newest first. Each
entry says what changed and why it matters to you; the commit has the detail. <For a skill: The source is
`agent-src/skills/<scope>/<group>/<name>/`, synced to `.claude/skills/` and `.github/skills/`.>

## <YYYY-MM-DD, or [x.y.z] - YYYY-MM-DD>

### Added

- **<New capability, as a short phrase>.** <What it does and why it matters, naming the file or option.> (<sha>)

### Changed

- **<What behaves differently>.** <What it does now, and what to do if you relied on the old behavior.> (<sha>)

### Deprecated

- **<What's going away>.** <What to use instead, and when it will be removed.> (<sha>)

### Removed

- **<What's gone>.** <What to use instead.> (<sha>)

### Fixed

- **<What was wrong, from the user's side>.** <What happens now.> (<sha>)

### Security

- **<What was exposed or hardened>.** <What users should do, if anything.> (<sha>)

## <earlier release>

### Added

- **<The unit itself>.** <What it shipped with: modes, references, scripts, and what it was checked against.> (<sha>)
```

## Review checklist

- [ ] The file has one H1, `# Changelog`, the `MD024` comment, and an intro naming the unit and the order.
- [ ] Releases are newest first, with `YYYY-MM-DD` or `[x.y.z] - YYYY-MM-DD` headings, and no empty categories.
- [ ] Categories appear in the order Added, Changed, Deprecated, Removed, Fixed, Security.
- [ ] Every entry leads with the change in bold, says what it means for the reader, and ends with the commit's short
  SHA.
- [ ] Breaking changes start with `**Breaking:**` and say what to do instead.
- [ ] No implementation detail, internal refactor or test evidence that belongs in the commit.
- [ ] For a skill: the entry is in the same commit as the change; the file is in `agent-src/`, not edited in
  `.claude/` or `.github/`; the sync, parity check and `check-changelogs.ps1` pass; `SKILL.md`'s Changelog table
  has a matching row.
- [ ] `Validate-Markdown.ps1` passes: markdownlint and cspell.
