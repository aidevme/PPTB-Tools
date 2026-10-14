# Dataverse Early-Bound TypeScript Generator

![Dataverse Early-Bound TypeScript Generator banner—a green database with table cards streams data through a crystal prism, which turns it into floating TypeScript interface and enum panels, on a dark blue background](../../../assets/dataverse-early-bound-typescript-generator-preview.png)

A Power Platform ToolBox (PPTB) tool that generates early-bound TypeScript types and metadata for Dataverse
tables, actions and functions. The generated code works with Scott Durow's
[dataverse-ify](https://github.com/scottdurow/dataverse-ify) library. The tool uses the same
`.dataverse-gen.json` project file as the [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI, so
you can switch between the two.

Source: [tools/dataverse-early-bound-typescript-generator](https://github.com/aidevme/PPTB-Tools/tree/main/tools/dataverse-early-bound-typescript-generator) ·
[Implementation guide](./dataverse-early-bound-typescript-generator.md)

## Why this tool exists

The dataverse-gen CLI signs in to Dataverse with its companion
[dataverse-auth](https://github.com/scottdurow/dataverse-auth) package. In some tenants that sign-in fails:
[dataverse-auth issue #48](https://github.com/scottdurow/dataverse-auth/issues/48) reports
`Authentication failed: InteractionRequiredAuthError: invalid_grant: AADSTS50076` ("you must use multi-factor
authentication"), without an MFA prompt ever appearing. The same account signs in with MFA everywhere else, other
tenants work with dataverse-auth, and device-code sign-in is blocked in those tenants too. The issue is still
open.

This tool generates the same output without signing in by itself: it uses the Dataverse connection you've
already opened in Power Platform ToolBox, so dataverse-auth isn't involved. If you can connect to an environment
in PPTB, with MFA or any other sign-in method PPTB supports, you can generate types for it. Because the tool
reads and writes the same `.dataverse-gen.json`, a project can keep using the dataverse-gen CLI where its sign-in
works.

## How it differs from the Early Bound Generator

The PPTB marketplace also has the
[Early Bound Generator](https://github.com/mbwilding/PPTB-Tools/tree/main/tools/early-bound-generator)
(`@mbwilding/tool-early-bound-generator`), which generates **C#** early-bound classes for .NET code such as
plug-ins and console apps. This tool generates **TypeScript** instead, for code that runs in the browser or in
Node:

| | This tool | Early Bound Generator |
| --- | --- | --- |
| Language | TypeScript | C# |
| Typical use | Form scripts and web resources, PCF controls, React and code apps, Node scripts | Plug-ins, custom workflow activities, .NET apps |
| Runtime the code is for | [dataverse-ify](https://github.com/scottdurow/dataverse-ify) over the Dataverse Web API | The Dataverse SDK for .NET |
| Output | Table interfaces and attribute constants, `const enum`s for choices, a metadata cache for dataverse-ify, optional typed `Xrm.FormContext` helpers, request types for actions and functions (including private custom APIs) | C# classes for tables, option sets and messages |
| Project file | `.dataverse-gen.json`, shared with the [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI | — |

Use this tool for client-side TypeScript, and the Early Bound Generator for server-side .NET code; a solution
with both can use both.

## What this tool changes

**In Dataverse: nothing.** The tool only reads table, choice, relationship and message metadata, solution
membership and custom API definitions. It never creates, updates or deletes Dataverse data, metadata or
customizations.

**On your computer**, only when you click **Generate**, and only inside the project folder you opened:

- **Generated files:** Generate creates new files and overwrites changed ones in the output folder (default
  `./src/dataverse-gen`), creating the folder and the folders inside it if they don't exist. Unchanged files aren't
  rewritten. **Preview** lists every file and its status first. There's no backup, so overwrites can't be undone
  by the tool; use source control. Turn on **Settings → Generate & files → Ask before generating** to confirm
  each run, with the output folder and the number of files to create and overwrite.
- **`.dataverse-gen.json`:** saved in the project folder on every Generate, with the selection and options.
- **Orphaned files (off by default):** with **Delete orphaned files** on, Generate also deletes generated files
  the current selection no longer produces, after you confirm the list, which names the output folder. Deletion is
  permanent (not the Recycle Bin or Trash). Only files the preview lists as orphaned can be deleted: generated
  files in the output folder's `entities`, `enums`, `actions`, `functions` and `complextypes` folders, plus
  `metadata.ts` and `index.ts`. Because PPTB's file API has no delete, deletion runs in a hidden PPTB terminal
  (PowerShell on Windows, `/bin/sh` elsewhere), which is closed afterwards.

**In Power Platform ToolBox:** the tool's settings, your saved projects and the last project folder used with
each connection are stored in PPTB's per-tool settings for this tool.

## What gets generated

For each selected table, under the output folder (default `./src/dataverse-gen`):

| Folder / file | Contents |
| --- | --- |
| `entities/<SchemaName>.ts` | Metadata object for dataverse-ify, attribute-name constants, early-bound interface, and optionally a typed `FormContext` |
| `enums/` | One `const enum` per choice column, plus CSDL enums used by selected actions and functions |
| `actions/`, `functions/` | Request interface and metadata for each selected operation |
| `complextypes/` | Interfaces for complex types used by selected operations |
| `metadata.ts` | `metadataCache` to pass to `setMetadataCache(...)` |
| `index.ts` | Barrel file re-exporting everything (optional) |

Tables used by a selected action or function are included automatically.

## How to use it

New to the tool? [Getting started](./getting-started/) walks through every step in detail.

1. **Project.** Click **New Project**, give the project a name and pick its location: the folder that holds,
   or should hold, `.dataverse-gen.json`. Then click **Load Existing Project**, choose the project and click
   **Load**. The tool remembers the folder for the current connection.
2. **Select.** Tick tables, actions and functions. Use the search box, the solution filter and the
   **Selected only** switch to narrow the list. Names in the config that this environment lacks are listed and
   skipped.
3. **Options.** Set the output folder and choose whether to emit entity interfaces, form-context helpers and the
   `index.ts` barrel.
4. **Preview.** Loads metadata and compares the result with the output folder. Each file is marked new, changed,
   unchanged or orphaned. Click a file to view its content.
5. **Generate.** Writes the new and changed files and saves `.dataverse-gen.json`.

## Using the output

```ts
import { setMetadataCache, XrmContextDataverseClient } from "dataverse-ify";
import { metadataCache, Account, accountMetadata } from "./dataverse-gen";

setMetadataCache(metadataCache);
const client = new XrmContextDataverseClient(Xrm.WebApi);
const account = await client.retrieve<Account>(accountMetadata.logicalName, id, ["name"]);
```

## Known limitations

- Tested inside Power Platform ToolBox against a live environment (connecting, listing tables, projects,
  selecting and previewing). Writing files with Generate, deleting orphaned files and the dark theme are still to
  be tested live; see
  [TESTING.md](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/TESTING.md).
- In very large environments, the `$metadata` document can be over the 16 MB Power Platform ToolBox allows. The
  tool then builds types from table and relationship metadata instead and shows a warning for a few seconds. Tables and custom
  APIs still work, but built-in actions and functions (such as `WinOpportunity`) and custom process actions
  aren't available, and output can differ slightly from `dataverse-gen`'s.
- Custom ejected EJS templates are not supported. The `dataverse-gen` CLI still honours them.
- Orphaned files are only reported unless you turn on **Delete orphaned files** and confirm. Deletion is
  permanent (no Recycle Bin or Trash).
- A few type mappings differ from `dataverse-gen` where its output would not compile. See the tool's
  [README](https://github.com/aidevme/PPTB-Tools/tree/main/tools/dataverse-type-gen#deliberate-deviations-from-dataverse-gen-output).

## Credits

Ported from [dataverse-gen](https://github.com/scottdurow/dataverse-gen) 2.0.17 by Scott Durow (MIT): the
generator logic and output templates are a TypeScript port of it. Its licence and copyright notice are in
[THIRD_PARTY_NOTICES.md](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/THIRD_PARTY_NOTICES.md).
The generated code depends on [dataverse-ify](https://github.com/scottdurow/dataverse-ify), also by Scott Durow
(MIT), which projects install themselves.
