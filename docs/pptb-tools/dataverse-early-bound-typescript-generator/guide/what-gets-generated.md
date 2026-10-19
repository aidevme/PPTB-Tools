# What gets generated

<!-- cspell:ignore customapi customapirequestparameters customapiresponseproperties complextypes complextype -->

This page is a reference for the files the tool writes and what you can select to generate them. To run a
generation, see [Getting started](../getting-started/).

## Output folder layout

Everything goes under the output folder (default `./src/dataverse-gen`, set on the Options card or in the
[project file](./project-file.md)):

| Folder / file | Contents |
| --- | --- |
| `entities/<SchemaName>.ts` | Metadata object for dataverse-ify, attribute-name constants, early-bound interface, and optionally a typed `FormContext` |
| `enums/` | One `const enum` per choice column, plus CSDL enums used by selected actions and functions |
| `actions/`, `functions/` | Request interface and metadata for each selected operation |
| `complextypes/` | Interfaces for complex types used by selected operations |
| `metadata.ts` | `metadataCache` to pass to `setMetadataCache(...)` |
| `index.ts` | Barrel file re-exporting everything (optional) |

In the **project folder**, not the output folder:

| Folder / file | Contents |
| --- | --- |
| `_templates/*.ejs` | dataverse-gen's seven EJS templates, written to `templateRoot` for the dataverse-gen CLI (see below) |

dataverse-gen's EJS templates (`action.ejs`, `complextype.ejs`, `entity.ejs`, `enum.ejs`, `function.ejs`,
`index.ejs`, `metadata.ejs`, from dataverse-gen 2.0.17) are written to the project folder's `templateRoot`
(`_templates` by default) on every Generate, like `npx dataverse-gen eject`, unless **Settings → Generate & files →
Generate templates** is off. The dataverse-gen CLI then uses them in place of its built-in templates. This tool doesn't read them, since EJS can't run in PPTB.
With **Custom enum template** on, `enum.ejs` is a custom version that renames duplicate enum members, so the CLI
writes the same names as this tool ([Troubleshooting](./troubleshooting.md#the-custom-enum-template)); the other six
are always dataverse-gen's.

Files are written in this order: entities, enums, actions, functions, complex types and `metadata.ts`. `index.ts`
re-exports them in the same order.

## What each file contains

- **Entities:** one file per selected table. It has the metadata object dataverse-ify uses (see
  [Why generate metadata?](./why-generate-metadata.md)), constants for the table's attribute names, and the
  early-bound interface (**Early-bound entity interfaces** option, on by default). With **Form context helpers**
  on, it also has a typed `FormContext` (see [Using the generated code](./using-the-generated-code.md)).
- **Enums:** a `const enum` for each choice column of the selected tables, and the enums that selected actions and
  functions use.
- **Actions and functions:** for each selected operation, a request interface and the metadata dataverse-ify
  needs to call it.
- **Complex types:** interfaces for the complex types that selected operations use. For a custom API with
  response properties, this includes a `<UniqueName>Response` type, the complex type `$metadata` publishes for
  them (or would publish, for a private custom API).
- **`metadata.ts`:** `metadataCache`, which you pass to `setMetadataCache(...)`.
- **`index.ts`:** re-exports every generated file, so you can import from one place. Turn it off with the
  **index.ts barrel file** option.

Tables that a selected action or function uses are included automatically, along with the enums and complex types
it needs.

## What you can select

| Kind | Where it comes from |
| --- | --- |
| Tables | The environment's table metadata. Filter by solution on the Select card. |
| Built-in actions and functions | The environment's `$metadata` document. |
| Custom APIs (action or function type) | `$metadata`. |
| Private custom APIs, and custom APIs missing from `$metadata` | Built from the `customapi` record, its request parameters and its response properties. Only this tool does this; dataverse-gen can't generate them. |
| Classic custom process actions | Listed and generated as actions. |

On the Select card, custom APIs are listed first, and **Custom only** hides the built-in messages. Names saved in
`.dataverse-gen.json` that the environment doesn't have are listed as "Not found in this environment" and skipped.

In very large environments the `$metadata` document may be unavailable. Then only tables and custom APIs can be
selected; see [Troubleshooting & limitations](./troubleshooting.md#large-metadata-documents).
