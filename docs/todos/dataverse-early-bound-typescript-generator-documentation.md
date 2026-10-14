# Documentation: screenshots to create

Status: **to do**. Tool: [Dataverse Early-Bound TypeScript Generator](../pptb-tools/dataverse-early-bound-typescript-generator/index.md).

The tool's README and docs have no screenshots of the real tool yet: the only images are the illustrative banners
(`assets/dataverse-early-bound-typescript-generator-preview.png`, `assets/pptb-tools-developer-preview.png`).
Screenshots are needed for:

- **Marketplace intake:** the AI-Assisted Development Policy says "Screenshots and GIFs must show the actual tool,
  not mock-ups", and the README has to describe the tool as it is.
- **Verified badge:** the README-quality criterion asks for "a screenshot or GIF of the tool UI".
- **Docs:** the Getting Started walkthrough and the component pages.

## How to capture

- **Real tool only:** capture the built tool running inside Power Platform ToolBox (Desktop 1.2.7 or later),
  connected to a real environment. No browser dev-server captures, no edited or generated images.
- **Safe data:** use a demo or trial environment. Don't show customer table prefixes, tenant or environment names,
  URLs, email addresses or user names. Blur or crop anything that slips in, such as the connection name in the
  header.
- **Size:** PPTB window about 1600 × 1000, at 100% zoom. Crop to the part of the UI being shown unless the entry
  says "full window".
- **Format:** PNG, compressed (aim for under 500 KB each).
- **Location and names:** `assets/dataverse-early-bound-typescript-generator/`, using the file names below.
- **Themes:** light theme unless the entry says dark. Dark-theme captures also serve as evidence that the tool
  follows the PPTB theme.
- **Alt text:** write it when adding the image to a page: what the screenshot shows, not "screenshot of…".
- **Updating:** retake a screenshot whenever the UI it shows changes.

## Required (marketplace listing and README)

These go in the tool README (`tools/dataverse-early-bound-typescript-generator/README.md`), which the marketplace
shows, and on the docs overview page (`docs/pptb-tools/dataverse-early-bound-typescript-generator/index.md`).

| # | File | What to show | Set-up |
| --- | --- | --- | --- |
| 1 | `overview-light.png` | **Full window**: the whole tool with a project open, tables selected and a preview listed | Open a project, select 3–5 tables and an action, run Preview |
| 2 | `select-tables.png` | The Select card's Tables tab: search, solution filter, table-type badges, selected rows | Filter to a solution, select a few tables, sort by Type |
| 3 | `preview-diff.png` | The Preview card with status tiles, the file list and a changed file's Changes tab | Change an option or selection after a first Generate, run Preview, select a changed file |
| 4 | `overview-dark.png` | Same as #1 in the **dark** theme | Switch PPTB to dark theme with the tool open |

## Getting Started walkthrough

For `docs/pptb-tools/dataverse-early-bound-typescript-generator/getting-started/index.md`, one per section.

| # | File | Section | What to show |
| --- | --- | --- | --- |
| 5 | `gs-load-tool.png` **Done** | 1. Load the tool | The tool in PPTB's tool list or marketplace, and its first screen with no project open (the Project card's empty state) |
| 6 | `gs-new-project.png` | 2. Open a project | The New Project dialog filled in (name, description, location) |
| 7 | `gs-load-project.png` | 2. Open a project | The Load Existing Project dialog with a few saved projects |
| 8 | `gs-project-open.png` | 2. Open a project | The Project card with a project open: name, version, path, ".dataverse-gen.json found" |
| 9 | `gs-select-actions.png` | 3. Choose what to generate | The Actions tab, including a custom API with its badge and "From definition" |
| 10 | `gs-options.png` | 4. Check the options | The Options card: output folder and the three switches |
| 11 | `gs-preview.png` | 5. Preview | The Preview card right after a first Preview: tiles, summary sentence, file list |
| 12 | `gs-generate-confirm.png` | 6. Generate | The "Generate files?" confirmation (turn on **Ask before generating** first) |
| 13 | `gs-generate-done.png` | 6. Generate | The success message and the "Generation complete" notification |
| 14 | `gs-generated-files.png` | 7. Use the types | The generated folder open in VS Code (`entities/`, `enums/`, `metadata.ts`, `index.ts`) |

## Component pages

For `docs/pptb-tools/dataverse-early-bound-typescript-generator/components/`. Crop tightly to the component.

| # | File | Page | What to show |
| --- | --- | --- | --- |
| 15 | `header.png` | `header.md` | The header: tool name, connection badge (environment name blurred), Settings button |
| 16 | `workflow-progress.png` | `workflow-progress.md` | The step bar partway through (project open, selection made, not yet previewed) |
| 17 | `project-card-empty.png` | `project-card.md` | The Project card with no project open, showing recent projects |
| 18 | `selection-card-no-project.png` | `selection-card.md` | The Select card before a project is opened (disabled tabs and search, the "Create a new project…" message) |
| 19 | `selection-card-sort-tooltip.png` | `selection-card.md` | A sorted column with its header tooltip open |
| 20 | `file-viewer-content.png` | `file-viewer.md` | A generated file's content with syntax highlighting |
| 21 | `file-viewer-orphan.png` | `file-viewer.md` | An orphaned file selected, showing the orphan notice |
| 22 | `delete-orphans-confirm.png` | `preview-card.md` | The "Delete orphaned files?" confirmation listing the files (test project only) |
| 23 | `settings-general.png` | `settings-panel.md` | The Settings panel's General tab |
| 24 | `settings-options.png` | `settings-panel.md` | The Options tab with the output preview |
| 25 | `settings-generate-files.png` | `settings-panel.md` | The Generate & files tab with **Delete Orphaned Files** on (warning visible) |
| 26 | `settings-search.png` | `settings-panel.md` | A settings search, e.g. "orphan", showing results from another tab |
| 27 | `footer.png` | `footer.md` | The footer: credits chips and links |

## Problem states (optional)

Useful for the Getting Started "If something goes wrong" section.

| # | File | What to show |
| --- | --- | --- |
| 28 | `error-permission.png` | The error bar and notification when the account lacks read permission (use a restricted test user) |
| 29 | `metadata-fallback.png` | The "$metadata document is too large" message, if an environment that hits the limit is available |
| 30 | `missing-items.png` | The "Not found in this environment" line, after loading a project whose config lists a table the environment lacks |

## Order of work

1. **#1–#4** first: they unblock the marketplace listing and the Verified README check.
2. **#5–#14** next, adding each image to its Getting Started section as it's taken.
3. **#15–#30** as time allows.

## Checklist

- [ ] Demo environment with non-sensitive data ready
- [ ] #1–#4 captured and added to the tool README and the docs overview page
- [ ] #5–#14 captured and added to Getting Started
- [ ] #15–#27 captured and added to the component pages
- [ ] #28–#30 captured (optional)
- [ ] Every image has alt text and is under 500 KB
- [ ] Docs site builds (`npm run docs:build`) with no broken image links
