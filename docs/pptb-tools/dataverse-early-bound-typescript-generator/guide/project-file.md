# Project file (`.dataverse-gen.json`)

<!-- cspell:ignore outputRoot templateRoot fileSuffix useCache referencedTypes complexTypes entityTypes -->

Each project is described by a `.dataverse-gen.json` file in the project folder. The tool shares this file with
the [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI: it reads the file when you open a project
and saves it on every Generate, with your selection and options. Keys the tool doesn't know are kept when the
file is saved again.

A brand new project starts from the same defaults as dataverse-gen's `.dataverse-gen.template.json`:

```json
{
  "entities": [],
  "actions": [],
  "functions": [],
  "generateIndex": true,
  "generateFormContext": false,
  "generateEntityTypes": true,
  "output": {
    "outputRoot": "./src/dataverse-gen"
  }
}
```

The file is written as JSON with two-space indentation and a trailing newline, like dataverse-gen does. The tool
accepts a leading UTF-8 byte order mark when reading.

## Selection

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `entities` | array of strings | `[]` | Logical names of the tables to generate |
| `actions` | array of strings | `[]` | Names of the actions to generate |
| `functions` | array of strings | `[]` | Names of the functions to generate |

Each of these must be an array of names. Tables, actions and functions used by your selection are added at
generation time without being listed (see [What gets generated](./what-gets-generated.md)).

## Generation options

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `generateEntityTypes` | boolean | `true` | Early-bound interface for each table (**Early-bound entity interfaces**) |
| `generateFormContext` | boolean | `false` | Typed `Xrm.FormContext` helpers (**Form context helpers**) |
| `generateIndex` | boolean | `true` | The `index.ts` barrel file (**index.ts barrel file**) |

## Output

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `output.outputRoot` | string | `./src/dataverse-gen` | Folder the files go to, relative to the project folder |
| `output.fileSuffix` | string | `.ts` | File extension of generated files |
| `output.templateRoot` | string | `./_templates` | Folder of ejected EJS templates. **Ignored by this tool** |
| `output.useCache` | boolean | `false` | Caches the metadata document on disk. **CLI only; ignored by this tool** |

## Referenced types

`referencedTypes` maps the type names the generated code refers to onto the names and import paths it uses. Each
entry has an optional `name` and an optional `import`. Your entries are merged key by key over the defaults, so a
partial override keeps the other defaults.

| Key | Default |
| --- | --- |
| `Object` | name `ObjectValue` |
| `Guid`, `Entity` (as `IEntity`), `EntityReference`, `WebApiExecuteRequest`, `StructuralProperty`, `OperationType`, `ActivityParty` | imported from `dataverse-ify` |
| `enums` | import `../enums/` |
| `complexTypes` | import `../complextypes/` |
| `entityTypes` | import `../entities/` |

## Options the tool ignores

- **`output.templateRoot`:** custom (ejected) EJS templates aren't supported. The tool always uses its built-in
  templates; the CLI still honors yours. See [Moving from dataverse-gen](./moving-from-dataverse-gen.md).
- **`output.useCache`:** a CLI-only setting.

## Settings that overwrite project options

The **Options** settings in the [Settings panel](./tool-settings.md) (output folder and the three generation
switches) are applied every time you open a project, also over the values already in its `.dataverse-gen.json`.
The Options card can still change them for the open project, and Generate saves the result to the file. So if
you edit those four options in the file by hand, set them in Settings too, or they'll be replaced when the project
is opened.
