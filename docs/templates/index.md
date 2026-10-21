# Document templates

The style guides and templates for documents in this repository. Each one sets a document's structure and writing
rules and, where it applies, ends with a template to copy and a review checklist. Start from the one that matches
the document you're writing; [WRITING_STYLE.md](./WRITING_STYLE.md) applies to all of them.

| Template Name | Purpose | Version | Created On | Modified On |
| --- | --- | --- | --- | --- |
| [Changelog Style Guide](./CHANGELOG_STYLE.md) | Structure and writing rules for `CHANGELOG.md` files (agent skills and versioned tools): releases newest first, Keep a Changelog categories, one bold-led entry per change ending with its commit, with a template and review checklist. Modelled on the `aidevme-tsdoc` changelog. | 1.1.0 | 2026-10-21 | 2026-10-21 |
| [Developer Guide Style Guide](./DEVELOPER_STYLE.md) | Structure and writing rules for the sections of `DEVELOPER.md` that explain a development tool or workflow (CLI, VS Code extension, agent skills), with a section template and review checklist. | 1.0.0 | 2026-10-19 | 2026-10-19 |
| [Refactoring Style Guide](./REFACTORING_STYLE.md) | Structure and writing rules for refactoring documents (`docs/todos/<tool-name>/refactoring-<tool-name>-<YYYY-MM-DD>.md`): analysis, plan, decision and execution record. The `aidevme-pptb-tool-refactoring` skill follows it. | 1.0.0 | 2026-10-18 | 2026-10-18 |
| [Writing Style Guide](./WRITING_STYLE.md) | General writing rules for documentation pages: page structure, YAML frontmatter, intro and key takeaway, tone and terminology. | 1.0.0 | 2026-10-12 | 2026-10-12 |

## Keeping this index current

- **Created On** is the date the template was added to the repository; **Modified On** and **Version** match the
  `Version` and `Last updated` line under the template's title.
- When you change a template's rules or structure, bump its version (patch for wording and fixes, minor for new or
  changed rules, major when existing documents no longer comply), update its `Last updated` date, and update its row
  here in the same commit.
- When you add a template, add a row, keeping the table sorted by name, and give the template a `Version: 1.0.0`
  line.
