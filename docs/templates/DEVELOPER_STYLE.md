# Developer Guide Style Guide

**Version:** 1.0.0 · **Last updated:** 2026-10-19

<!-- cspell:ignore pasteable repositorys -->

This guide sets the structure and writing rules for the repository's developer guide, `DEVELOPER.md` at the
repository root: the document that explains how to use a development tool or workflow (a CLI, a VS Code extension, a
set of agent skills) **in this repository**. It applies to every new `##` section in that file, whether a person
writes it or an AI assistant does. For general writing rules, see [WRITING_STYLE.md](WRITING_STYLE.md); for
refactoring documents, [REFACTORING_STYLE.md](REFACTORING_STYLE.md).

**A developer guide section answers four questions in order: what the tool is and whether it's current, when to use
it here and when not, how to set it up and use it in this repository, and what to do when it goes wrong. Every
command is copy-pasteable, every external claim has a source and a "checked on" date, and the section points to the
repository's skills instead of repeating them.**

## Scope

| Belongs in `DEVELOPER.md` | Belongs elsewhere |
| --- | --- |
| An external tool or workflow contributors use to build the tools here (Spec Kit, agent skills, the PPTB VS Code extension) | A tool's own behavior and code: the tool's README and `docs/pptb-tools/<tool-name>/` |
| How that tool fits this repository's layout, skills and rules | The repository's rules themselves: `AGENTS.md` |
| Setup, daily use, upgrade and troubleshooting for contributors | End-user help: the tool's user guide (`getting-started/`, `guide/`) |

One `##` section per tool or workflow. If a section grows past about 300 lines, move the detail to
`docs/repository/<topic>.md` and keep a short section with the link.

## Document structure

`DEVELOPER.md` is, in order:

1. `# DEVELOPER`, the only H1.
1. The banner image, with alt text that describes the picture (see [WRITING_STYLE.md](WRITING_STYLE.md)).
1. `## Contents`: every `##` section and its `###` subsections, as nested links (see [Contents](#contents)).
1. The `##` sections, one per tool or workflow. Add a new section at the end unless it belongs next to a related one.

## Contents

- One line per `##` section, one indented line per `###` subsection; `####` headings aren't listed.
- Link text is the heading text exactly; the anchor is GitHub's heading ID: lowercase, punctuation removed, spaces
  become hyphens. An em dash surrounded by spaces becomes a double hyphen (`ToolBox Development — VS Code Extension`
  → `#toolbox-development--vs-code-extension`); an apostrophe disappears (`repository's` → `repositorys`).
- Update it in the same change that adds, renames or removes a heading. markdownlint's MD051 rule reports a link
  whose anchor doesn't exist.

## Section structure

Each section uses these subsections, in this order. Use the heading text shown; a section may leave out an optional
subsection, but not reorder them.

| Subsection | Required | What it contains |
| --- | --- | --- |
| Intro (no heading) | Yes | A cspell comment if needed, one paragraph on what the tool is (linked, with its license when it's open source) and what it gives this repository, then the [verification line](#verification-line) |
| `### When to use it` | Yes | A `Work` / `Use` table that sends each kind of work to this tool, a skill, or something else (see [Decision tables](#decision-tables)) |
| `### How it fits this repository` | When the tool touches the repository's layout or skills | A `Piece` / `Role` table, then one bold rule of thumb |
| `### Prerequisites` | Yes | A bullet list: versions, install commands per OS, how to check (`<tool> --version`) |
| `### Install and set up` | When there's anything to install or configure | Numbered steps, each with its command and what to check afterwards |
| `### Daily use` (or a name for the workflow, such as `### The workflow`) | Yes | The steps or commands a contributor runs, as a table or numbered list |
| `### Example` | Recommended | One end-to-end example on a real tool in this repository |
| `### Using it with the repository's skills` | When a skill wraps or relies on the tool | Which `aidevme-*` or PPTB skill to use, and example prompts |
| `### Upgrading` | When the tool has versions to keep up with | How to upgrade safely and what's kept |
| `### Troubleshooting` | Recommended | A `Problem` / `Fix` table |
| `### Scope and limitations` | Recommended | What the tool doesn't do or doesn't replace (approval, live testing, human review) |
| `### Sources` | Yes | The pages the section is based on, with versions |

Sections written before this guide may use other headings (for example `### What you need`); keep them unless you're
already rewriting the section.

### Verification line

Right after the intro, one sentence says what the section was checked against and when, and which source wins:

```markdown
This guide was checked against <tool> **v<x.y.z>** (released <YYYY-MM-DD>) on <YYYY-MM-DD>. <Tool> changes quickly;
if a command or flag below doesn't match, the [<tool> documentation](<url>) for your version wins.
```

Without a release version, name the pages instead:
`This section was checked against the PPTB documentation on <YYYY-MM-DD>: [<page>](<url>) and [<page>](<url>).`
Update the date whenever you re-check the section, even if nothing else changes.

### Decision tables

The `### When to use it` table is the most useful part of a section: it stops people using the wrong tool.

- Two columns, `Work` and `Use`. Each row is a kind of work a contributor recognizes ("A small, obvious fix (a typo, a
  wrong label)"), not a feature of the tool.
- Include the rows where the answer is **not** this tool: another skill, the Desktop App, or "ask the assistant
  directly".
- After the table, one or two sentences on the trade-off (what the tool costs and when that pays off).

### Commands and steps

- **Copy-pasteable:** a command block runs as written from the folder the text names. Placeholders use
  `<angle-brackets>` and are explained right after the block.
- **Per OS:** give PowerShell and Bash blocks separately when they differ, each starting with a comment
  (`# Windows (PowerShell)`, `# macOS / Linux (Bash)`).
- **Pinned versions:** install a specific release (`@v1.2.1`, `--from …@<tag>`), and say how to move to another one.
- **Check after each step:** a numbered setup step ends with what the reader should see (a folder, a command's
  output, a clean `git status`).
- **Flags explained:** a bullet list under the block says what each non-obvious flag does and why it's used here.
- **Destructive or irreversible commands** (`--force`, publishing, deleting) carry a warning in the same step, saying
  when not to run them.

### Repository fit

A section says how the tool works with this repository's rules, not only how it works in general:

- **Folders:** where the tool puts files here, with a `text` tree when the layout matters, and why (for example, per
  tool under `tools/<tool-name>/` rather than at the root).
- **Generated files:** never tell readers to edit `.claude/skills/`, `.github/skills/`, `CLAUDE.md` or
  `.github/copilot-instructions.md`; those are generated from `agent-src/` and `AGENTS.md`.
- **Skills:** name the skill that owns each job (`aidevme-github` for commits, branches and pull requests,
  `pptb-tool-dev` for PPTB APIs and the manifest, `intake-policy-review` before submitting) and link to its use
  instead of repeating its steps.
- **Checks:** say which of the repository's checks apply (`npm run build`, `npm test`, `npm run validate` in the
  tool's folder; a live test in PPTB in light and dark themes).

### Sources

- A bullet list of the pages the section relies on, each with the version or the date checked.
- Group pages from the same site in one bullet, as `DEVELOPER.md`'s Spec Kit sources do.
- Link the primary source (the tool's own docs or repository) before blog posts or secondary listings.

## Writing rules

- **Second person, present tense, active voice:** "Run `specify version`", "The extension only runs published tools".
  Write for a developer who knows Git, Node.js and TypeScript but not this tool.
- **Facts from sources, not memory.** Commands, flags, versions and limits come from the tool's documentation or a
  command you ran. If you couldn't check something, say so.
- **Repository-specific beats generic.** Every section names at least one real path, tool or skill in this
  repository. Leave generic tutorials to the tool's own docs and link to them.
- **Bold for the rule a reader must not miss,** at most once per subsection; not for emphasis in passing.
- **Code format** for paths, file names, commands, flags, settings keys, package names, extension IDs and skill
  names.
- **Tables** for choices and mappings (Work / Use, Piece / Role, Problem / Fix, Step / Command / Writes / What to
  check); numbered lists for steps that must happen in order; bullets for everything else.
- **Line length:** wrap prose and list items at about 120 characters; never break a table row, a link or a code span.
- **Spelling:** one-off technical words go in the section's `<!-- cspell:ignore … -->` comment, right under its
  heading, not in `cspell.json`, unless the word is used across the repository.
- **Links:** relative links to repository files, anchors for headings in the same file, and full URLs for external
  pages.
- **No angle-bracket placeholders in prose outside code spans:** the docs site is VitePress, which reads `<word>` as
  an HTML tag. Write `` `<tool-name>` ``, not a bare placeholder.

## Template

Copy this into `DEVELOPER.md`, replace every `<placeholder>`, delete the optional subsections you don't need, and add
the section to `## Contents`.

````markdown
## <Tool or workflow name>

<!-- cspell:ignore <one-off words> -->

[<Tool>](<url>) (<license>) <does what, in one clause>. <What it gives this repository, in one sentence.>

This guide was checked against <tool> **v<x.y.z>** (released <YYYY-MM-DD>) on <YYYY-MM-DD>. If a command or flag below
doesn't match, the [<tool> documentation](<url>) for your version wins.

### When to use it

| Work | Use |
| --- | --- |
| <kind of work this tool is for> | <Tool> |
| <kind of work it's not for> | <the skill, app or approach to use instead> |

<One or two sentences on the trade-off: what the tool costs and when it pays off.>

### How it fits this repository

| Piece | Role |
| --- | --- |
| <Tool> | <what it owns> |
| `<aidevme-skill>` skill | <what it owns> |

The rule of thumb: **<one sentence on who owns what>.**

### Prerequisites

- **<Runtime> <version> or later** (`<install command>` on Windows, `<install command>` on macOS and Linux). Check
  with `<command> --version`.
- <Other prerequisite.>
- A clean working tree on a feature branch.

### Install and set up

1. **<Step>** (once per machine):

   ```bash
   <command>
   ```

   <What the flags do; how to move to another version.>

2. **<Step>.** From `tools/<tool-name>/`:

   ```powershell
   # Windows (PowerShell)
   <command>
   ```

   ```bash
   # macOS / Linux (Bash)
   <command>
   ```

3. **Check the result:** <folders that exist, output to expect, `git status` showing no change outside the tool's
   folder>.

### Daily use

| Step | Command | Writes | What to check |
| --- | --- | --- | --- |
| 1. <step> | `<command>` | `<file>` | <check> |

**<Review gates, commits or other rule that applies to every step.>**

### Example

<A real change in this repository, end to end, as numbered steps with the commands or prompts used.>

### Using it with the repository's skills

<Which skill drives or relies on the tool, and what it does and doesn't do.> Example prompts:

- "<prompt>"

### Upgrading

- **Upgrade:** <commit first; the upgrade command; what's kept and what to check>.

### Troubleshooting

| Problem | Fix |
| --- | --- |
| <symptom, quoted as the reader sees it> | <fix> |

### Scope and limitations

- **<Limit>:** <what the tool doesn't do, or doesn't replace>.

### Sources

- [<Primary source>](<url>), at v<x.y.z>: [<page>](<url>) and [<page>](<url>).
- [<Other source>](<url>): <what it was used for>.
````

## Review checklist

- [ ] The section is about a development tool or workflow, not a tool's own behavior (see [Scope](#scope)).
- [ ] `## Contents` lists the new `##` heading and its `###` subsections, and every link works.
- [ ] The intro has the tool's link, license (if open source) and what it gives this repository, followed by a
  verification line with a version or the pages checked, and a date.
- [ ] `### When to use it` includes at least one row where the answer is something other than this tool.
- [ ] Subsections follow the [section order](#section-structure); required ones are present.
- [ ] Every command block runs as written from the folder named, with placeholders explained and flags described.
- [ ] Irreversible commands carry a warning; install commands pin a version.
- [ ] The section names the repository's folders and skills where they apply, and doesn't tell readers to edit
  generated files.
- [ ] `### Sources` lists every page the section relies on, with versions or dates.
- [ ] `Validate-Markdown.ps1` (the `aidevme-docs-maintenance` skill) passes on `DEVELOPER.md`: markdownlint and cspell.
