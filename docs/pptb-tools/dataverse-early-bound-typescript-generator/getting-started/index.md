# Getting started

This walks you through generating early-bound TypeScript types for your first Dataverse project, from loading
the tool in Power Platform ToolBox (PPTB) to using the types in your code. It takes about ten minutes.

## Before you start

You need:

- **Power Platform ToolBox**, with a connection to the Dataverse environment you want types for.
- **A TypeScript project** for your web resources, form scripts or PCF control, usually the folder with your
  `package.json`. The tool writes the generated files into it.
- **[dataverse-ify](https://github.com/scottdurow/dataverse-ify)** in that project, which the generated code
  uses at runtime:

  ```bash
  npm install dataverse-ify
  ```

Already using Scott Durow's [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI? The tool reads
and writes the same `.dataverse-gen.json`, and its output matches the CLI's, so you can open your existing
project and switch between the two.

## 1. Load the tool

The tool isn't in the PPTB tool gallery yet, so you load it from a local build:

1. Build it: in `tools/dataverse-early-bound-typescript-generator/`, run `npm install`, then `npm run build`.
2. In PPTB, open **Settings** and turn on the **Debug Menu**.
3. Choose **Debug → Browse** and select the tool's folder.
4. Connect to your Dataverse environment.

The header shows **Connected** with your environment's name; hover over it to see the URL. A progress bar
across the top shows the four steps you're about to go through. Click a step to jump to it.

## 2. Open a project (step 1)

The first time, create a project:

1. Click **New Project**.
2. Enter a **Project Name** and an optional **Description**.
3. For **Location**, click **Browse…** and pick your TypeScript project's folder: the one that has, or will
   have, `.dataverse-gen.json`.
4. Click **Save**. The new project opens straight away.

To open a saved project later, click **Load Existing Project**, select your project in the table, and click **Load**. (Clicking
the project's name opens it straight away.) PPTB may ask you to confirm the folder first; that's how it grants
the tool access to it.

A notification confirms the project loaded. The Project card then shows its name, version, path and whether a
`.dataverse-gen.json` was found. Next time, the projects you used most recently appear as tiles on the Project
card; click one to reopen it.

Under **Settings** → **General** you can turn the "project loaded", "preview ready" and "generation complete"
notifications on or off (errors are always shown), choose how many recent projects are shown (0 to 10), and
how many rows the Select card lists at once (100 to 2000).

## 3. Choose what to generate (step 2)

The **Select** card lists tables, actions and functions once a project is open; until then it asks you to
create or open one. Tick what you want types for:

- **Tables:** search by display, logical or schema name. Use the solution dropdown to show only one solution's
  tables, and **Selected only** to review your choices.
- **Actions** and **Functions:** custom APIs are listed first. **Custom only** hides the built-in messages.

Tables that a selected action or function uses are included automatically. Your selection is saved to
`.dataverse-gen.json` when you generate.

## 4. Check the options (step 3)

The **Options** card controls what's written, and is saved to `.dataverse-gen.json` too:

- **Output folder:** where the files go, relative to the project folder. The default is `./src/dataverse-gen`.
- **Early-bound entity interfaces:** an interface per table for dataverse-ify. On by default.
- **Form context helpers:** typed `Xrm.FormContext` interfaces for form scripts. Off by default.
- **index.ts barrel file:** one file that re-exports everything. On by default.

Each option's info button explains it. The options start from **Settings** (the gear in the header) →
**Options** every time you open a project. Change them there for all projects, or here for this project only.

## 5. Preview (step 4)

Click **Preview**. The tool loads the environment's metadata, generates the files in memory and compares them
with your output folder. Nothing is written yet.

- A sentence sums up what Generate would do, and the **New**, **Changed**, **Unchanged** and **Orphaned**
  tiles show the counts. Click a tile to list only those files.
- The table shows what needs attention: new, changed and orphaned files. Turn on **Show unchanged** to see
  every file, or search by name.
- Select a file to see it on the right. For a **changed** file, the **Changes** tab shows exactly which lines
  would change. Use **↑**/**↓** to move between files.

**Orphaned** files are in your output folder but no longer generated, for example after you deselect a table.
By default they're only reported. Turn on **Delete orphaned files** next to the Generate button (or in
Settings) and Generate removes them after you confirm the list. The switch becomes available once you've run
Preview. Deleted files don't go to the Recycle Bin or
Trash.

## 6. Generate (step 5)

Click **Generate *n* files**. The tool writes only the new and changed files, then saves `.dataverse-gen.json`
with your selection and options. A notification and a message on the card confirm what was written.

To be asked first, turn on **Ask before generating** in **Settings** → **Generate & files**. The confirmation
names the output folder and how many files will be created and overwritten. Overwrites can't be undone, so use
source control to get old versions back.

Commit the generated files, and `.dataverse-gen.json`, with the rest of your project.

## 7. Use the types

Register the metadata once, then use the generated interfaces with dataverse-ify:

```ts
import { setMetadataCache, XrmContextDataverseClient } from "dataverse-ify";
import { metadataCache, Account, accountMetadata } from "./dataverse-gen";

setMetadataCache(metadataCache);
const client = new XrmContextDataverseClient(Xrm.WebApi);
const account = await client.retrieve<Account>(accountMetadata.logicalName, id, ["name"]);
```

With **Form context helpers** on, form scripts get typed controls and attributes:

```ts
import { AccountFormContext } from "./dataverse-gen";

export function onLoad(context: Xrm.Events.EventContext) {
    const form = context.getFormContext() as AccountFormContext;
    form.getAttribute("name"); // typed as Xrm.Attributes.StringAttribute
}
```

## Keeping types up to date

When tables change in Dataverse, open the project, click **Preview** to see what changed, then **Generate**.
If a run adds files or stops producing some, the project's version and **Modified On** are updated
automatically.

## If something goes wrong

Errors appear as a notification and in a red bar at the top of the tool, with a short explanation:

| Message | What to do |
| --- | --- |
| You don't have permission to perform this action. | Your Dataverse security role can't read the metadata. Ask an administrator for read access to the tables. |
| Authentication failed. Please reconnect… | Reconnect to the environment in PPTB. |
| Too many requests. Please wait a moment… | Dataverse is throttling. The tool already retries a few times; wait and try again. |
| Power Platform ToolBox hasn't granted access to that folder. | Open the project again with **Load Existing Project** and confirm the folder. |
| .dataverse-gen.json isn't valid JSON. | Fix the file's syntax, or remove it to start from defaults. |

In very large environments, a short warning may say the `$metadata` document is too large for PPTB. The tool
then builds types from table metadata instead: tables and custom APIs still work, but built-in actions and
functions aren't available.

## Next steps

- [Components](../components/) and [Architecture](../architecture/) explain how the tool is built.
- The [overview](../index.md) lists what's generated and the known limitations.
