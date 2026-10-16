# Tool settings

Open the Settings panel with the gear button in the header. It has three tabs, and a **Search settings** box that
finds a setting in any tab by its name or description.

## General

Where the values apply: this Power Platform ToolBox (PPTB) installation.

| Setting | Default | What it does |
| --- | --- | --- |
| Project loaded, Preview ready, Generation complete | On | Show a notification when a project loads, a preview finishes and a generation completes. Error notifications are always shown. |
| Recent projects | 3 (0 to 10) | How many recent projects appear as tiles on the Project card. 0 hides the list. |
| Rows in the Select tables | 500 (100 to 2000, step 100) | The most rows each table on the Select card lists at once. |

## Options

Where the values apply: the default for every project, saved to its `.dataverse-gen.json`.

| Setting | Default | What it does |
| --- | --- | --- |
| Output folder | `./src/dataverse-gen` | Where generated files go, relative to the project folder. A blank value saves as the default. |
| Early-bound entity interfaces | On | An interface per table for dataverse-ify |
| Form context helpers | Off | Typed `Xrm.FormContext` interfaces for form scripts |
| index.ts barrel file | On | One file that re-exports everything |

These start every project you open, also over the values in its `.dataverse-gen.json`. You can still change them
for one project on the Options card, and Generate saves them to that project's file. A preview under the
Generated files card shows the folder tree these options produce.

## Generate & files

Where the values apply: all projects.

| Setting | Default | What it does |
| --- | --- | --- |
| Ask before generating | Off | Asks for confirmation before Generate writes, naming the output folder and how many files will be created and overwritten. Overwrites can't be undone. |
| Rename duplicated identifier(s) | Off | Renames later duplicate enum members to `<Name>_<Value>` (for example `InProgress_700970000`), so files with duplicate identifiers compile. Code using a renamed member must use the new name. Changing it needs a new preview. Same switch as **Rename duplicated identifier(s)** next to the Generate button. |
| Skip duplicated identifier(s) | Off | Generate doesn't write files that declare the same name twice (two choice labels that become the same enum member, so the file won't compile). An existing copy on disk stays as it is. When off, these files are written and only reported. This is the same switch as **Skip duplicated identifier(s)** next to the Generate button. See [Troubleshooting](./troubleshooting.md#duplicate-identifiers). |
| Delete orphaned files | Off | Generate also deletes generated files the current selection no longer produces, after you confirm the list. Deletion is permanent. This is the same switch as **Delete orphaned files** next to the Generate button, so the two stay in sync. |

When both are on, the orphan confirmation covers the writes too. See [Safety](./safety.md).

## Templates

Nothing to set: this tab shows the seven EJS templates behind the generated files, read-only, one tab per file, with the
tool's version. Generate writes them to your project's `templateRoot` folder (`_templates` by default). The tool
generates with built-in copies, so editing the written files doesn't change its output, and the next Generate
overwrites them. See [What gets generated](./what-gets-generated.md).

## Saving

- Changes are a draft until you click **Save**, which is enabled only when something differs from the saved values.
  **Cancel**, or closing the panel, discards them.
- **Reset to defaults** sets every setting back to its default and keeps your saved projects. You still have to
  click **Save**.
- Numbers outside the allowed range are rounded and clamped to it when saved.

## Where settings are saved

Settings are saved in PPTB's per-tool settings for this tool, so they apply to every connection and
project on this installation. Your saved projects and the last project folder used with each connection are kept
there too. The defaults are built into the tool.
