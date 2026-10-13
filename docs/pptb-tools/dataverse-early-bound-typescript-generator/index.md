# Dataverse Early-Bound TypeScript Generator

![Dataverse Early-Bound TypeScript Generator banner—a green database with table cards streams data through a crystal prism, which turns it into floating TypeScript interface and enum panels, on a dark blue background](../../../assets/dataverse-early-bound-typescript-generator-preview.png)

A Power Platform ToolBox (PPTB) tool that generates early-bound TypeScript types and metadata for Dataverse
tables, actions and functions. The generated code works with Scott Durow's
[dataverse-ify](https://github.com/scottdurow/dataverse-ify) library. The tool uses the same
`.dataverse-gen.json` project file as the [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI, so
you can switch between the two.

Source: [tools/dataverse-early-bound-typescript-generator](https://github.com/aidevme/PPTB-Tools/tree/main/tools/dataverse-early-bound-typescript-generator) ·
[Implementation guide](./dataverse-early-bound-typescript-generator.md)

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

- Not yet tested against a live environment inside PPTB.
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

Ported from `dataverse-gen` by Scott Durow (MIT). The generated code depends on `dataverse-ify`, also by Scott
Durow (MIT).
