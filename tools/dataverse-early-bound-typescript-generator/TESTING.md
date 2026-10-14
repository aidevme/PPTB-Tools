# Live testing in Power Platform ToolBox

Unit tests (`npm test`) cover the generator, the write plan and the UI components with fixtures and mocked PPTB
APIs. They can't prove the tool works inside PPTB against a real environment, so this file records the manual
checks run in PPTB and the steps for the ones still to do.

Use a **test project** in a throwaway folder (or a git repository with a clean working tree), never a project
whose generated files you can't regenerate.

## Results

| Check | Result | Date | PPTB | Tool | Notes |
| --- | --- | --- | --- | --- | --- |
| Load the built tool (Debug → Load Local Tool) and connect | Pass | 2026-10-13/14 | Desktop 1.2.7 | 1.0.0 | Header shows Connected and the environment name |
| List tables in a large environment | Pass | 2026-10-13/14 | Desktop 1.2.7 | 1.0.0 | About 2,900 tables listed; the Select table shows the first 500 |
| Create and open projects, recent projects | Pass | 2026-10-13/14 | Desktop 1.2.7 | 1.0.0 | New Project, Load Existing Project, recent project tile |
| Select tables, actions and functions | Pass | 2026-10-13/14 | Desktop 1.2.7 | 1.0.0 | Search, solution filter, table types |
| Preview against an existing output folder | Pass | 2026-10-13/14 | Desktop 1.2.7 | 1.0.0 | 1 changed, 279 unchanged, 9 orphaned; diff shown for the changed file |
| Settings panel: change, save, reopen | Pass | 2026-10-13/14 | Desktop 1.2.7 | 1.0.0 | |
| Generate: write new and changed files | **To do** | | | | See [Generate](#generate) |
| Delete orphaned files | **To do** | | | | See [Delete orphaned files](#delete-orphaned-files) |
| Dark theme, and switching theme while open | **To do** | | | | See [Themes](#themes) |
| Error paths: no permission, expired connection | **To do** | | | | See [Error paths](#error-paths) |

The passing rows come from the author's runs during development on 13 and 14 October 2026. When a check passes,
fill in the date, the PPTB Desktop version and the tool version (shown next to the tool name in the header), and
add anything notable.

## Steps for the remaining checks

### Generate

1. Open a test project with an output folder that already has generated files.
2. Change something that alters the output, for example select one more table.
3. Click **Preview**: the new table's files are listed as **new**.
4. Turn on **Settings → Generate & files → Ask before generating**, then click **Generate**.
5. Check the confirmation names the output folder and the number of files to create and overwrite, and click
   **Generate**.
6. **Pass if:** the success message and notification appear, the new files exist on disk, `.dataverse-gen.json`
   lists the new table, and a second **Preview** shows nothing to write.

### Delete orphaned files

1. In the same test project, deselect one table that was generated before.
2. Click **Preview**: its files are listed as **orphaned**.
3. Turn on **Delete orphaned files** (in the Preview card or in Settings → Generate & files).
4. Click **Generate**. Check the "Delete orphaned files?" confirmation lists exactly those files and the output
   folder, then confirm.
5. **Pass if:** those files are gone from disk, every other file is still there, the result line says
   "N deleted", and a second **Preview** shows no orphaned files.
6. Also check a file **outside** the output folder with a similar name (create `notes.ts` in the project folder
   beforehand) is untouched.
7. If you can, repeat on macOS or Linux; deletion runs through a hidden PPTB terminal (PowerShell on Windows,
   `/bin/sh` elsewhere).

### Themes

1. Switch PPTB to the dark theme and open the tool: all cards, tables, dialogs and the Settings panel are legible.
2. With the tool open, switch PPTB between light and dark. **Record** whether the tool follows without being
   reopened. (It currently reads the theme only when it opens; if it doesn't follow, note it as a known
   limitation.)

### Error paths

1. Connect with a user that can't read table metadata: the error bar and an error notification explain the
   problem, and the tool keeps working.
2. Let the connection expire, or disconnect it, then click **Preview**: the error asks you to reconnect.
3. Open a project folder whose `.dataverse-gen.json` lists a table the environment doesn't have: it's listed as
   "Not found in this environment" and skipped.
