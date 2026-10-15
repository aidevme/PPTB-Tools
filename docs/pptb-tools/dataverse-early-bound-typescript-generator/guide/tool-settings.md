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
| Delete Orphaned Files | Off | Generate also deletes generated files the current selection no longer produces, after you confirm the list. Deletion is permanent. This is the same switch as **Delete orphaned files** next to the Generate button, so the two stay in sync. |

When both are on, the orphan confirmation covers the writes too. See [Safety](./safety.md).

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
