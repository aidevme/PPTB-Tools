# Safety: what the tool changes

## In Dataverse: nothing

The tool only reads table, choice, relationship and message metadata, solution membership and custom API
definitions. It never creates, updates or deletes Dataverse data, metadata or customizations.

## On your computer

The tool writes only when you click **Generate**, and only inside the project folder you opened.

- **Generated files:** Generate creates new files and overwrites changed ones in the output folder (default
  `./src/dataverse-gen`), creating the folder and the folders inside it if they don't exist. Unchanged files aren't
  rewritten. **Preview** lists every file and its status first.
- **No backups:** the tool can't undo an overwrite. Keep your project in source control, and commit the generated
  files so you can get old versions back.
- **Ask before generating:** turn on **Settings → Generate & files → Ask before generating** to confirm each run,
  with the output folder and the number of files to create and overwrite.
- **`.dataverse-gen.json`:** saved in the project folder on every Generate, with the selection and options.
- **dataverse-gen templates:** Generate also writes dataverse-gen's seven EJS templates to the project's
  `templateRoot` folder (`_templates` by default), overwriting changed copies. Edits you made to those templates
  are lost unless they're in source control. Preview lists them, with their changes. Turn off **Settings →
  Generate & files → Generate templates** to stop writing them. With **Custom enum template** on, `enum.ejs` is
  replaced by the custom version (also over an edited copy); turning the setting on or off writes nothing by
  itself, and Preview lists the change before Generate writes it. When the last preview found your `enum.ejs`
  edited, turning the setting on asks first, naming the file (**Replace your edited enum.ejs?**).

## Orphaned files

Orphaned files are in your output folder but no longer generated, for example after you deselect a table.

- By default they're only reported.
- With **Delete orphaned files** on (off by default), Generate also deletes them after you confirm the list, which
  names the output folder. Deletion is permanent: the files don't go to the Recycle Bin or Trash.
- Only files the preview lists as orphaned can be deleted: generated files in the output folder's `entities`,
  `enums`, `actions`, `functions` and `complextypes` folders, plus `metadata.ts` and `index.ts`. Anything else in
  your project folder, including other files in the output folder, is left alone.
- PPTB's file API has no delete, so the tool deletes through a hidden PPTB terminal (PowerShell on Windows,
  `/bin/sh` elsewhere), which is closed afterwards. If any file remains afterwards, the tool reports an error; the
  written files still count as done.

## In Power Platform ToolBox

The tool's settings, your saved projects and the last project folder used with each connection are stored in
PPTB's per-tool settings for this tool. See [Tool settings](./tool-settings.md).
