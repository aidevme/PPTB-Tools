# Troubleshooting & limitations

<!-- cspell:ignore customapi WinOpportunity -->

## If something goes wrong

Errors appear as a notification and in a red bar at the top of the tool, with a short explanation:

| Message | What to do |
| --- | --- |
| You don't have permission to perform this action. | Your Dataverse security role can't read the metadata. Ask an administrator for read access to the tables. |
| Authentication failed. Please reconnect… | Reconnect to the environment in PPTB. |
| Too many requests. Please wait a moment… | Dataverse is throttling. The tool already retries a few times; wait and try again. |
| Power Platform ToolBox hasn't granted access to that folder. | Open the project again with **Load Existing Project** and confirm the folder. |
| .dataverse-gen.json isn't valid JSON. | Fix the file's syntax, or remove it to start from defaults. |

## Large metadata documents

The tool reads actions and functions from the environment's `$metadata` document, usually 1 to 5 MB. PPTB rejects
documents over 16 MiB, so in very large environments the tool shows a short warning and builds types from table
and relationship metadata instead.

- **Still works:** tables and custom APIs. Output for tables matches the normal path in the tool's tests, though it
  can differ slightly from dataverse-gen's.
- **Not available:** built-in actions and functions (such as `WinOpportunity`) and custom process actions, because
  there is no other source for them.

This fallback hasn't been checked against a live environment that hits the limit.

## Duplicate identifiers

A file with the **Duplicate identifiers** status declares the same name twice, so TypeScript won't compile it.
It happens when two choice (option set) labels become the same enum member name after the tool removes spaces
and symbols, for example "Open" and "Open!", or the same label used twice in one choice.

Select the file in the Preview card to see which names collide and their values. The lasting fix is to rename one of
the labels in Dataverse, then click **Preview** again.

If you can't change the labels, turn on **Rename duplicated identifier(s)** next to the Generate button (or **Rename
Duplicated Identifier(s)** in **Settings** → **Generate & files**) and preview again. The first member keeps its name
and each later one gets its value appended, so

```ts
  InProgress = 3,
  // ...
  InProgress = 700970000,
```

becomes `InProgress = 3` and `InProgress_700970000 = 700970000`, and the file compiles. Code that used the second
value must use the new name. This differs from dataverse-gen's output, which is why it's off by default; when it's
off, the output stays the same as dataverse-gen's. Generate still writes the file, unless you turn on **Skip duplicated identifier(s)** next to the
Generate button (or **Skip duplicated identifier(s)** in **Settings** → **Generate & files**); then it leaves the file unwritten and any existing copy stays as it is.

### The custom enum template

When a preview finds duplicate identifiers, the Preview card proposes the **Custom enum template**. Click **Use
custom enum template** to turn it on for this project, or **Not now** to keep the default output (the proposal comes
back on the next preview with duplicates). Nothing changes until you preview again and generate. The setting belongs
to the project: Generate saves it in the project's `.dataverse-gen.json`
(`pptbEarlyBoundGenerator.customEnumTemplate`), so other projects keep their own. With it on:

- the generated files rename later duplicates exactly as **Rename duplicated identifier(s)** does (which then shows
  as on);
- Generate writes a custom `enum.ejs` to your project's `templateRoot` (`_templates` by default) in place of
  dataverse-gen's, replacing any copy there, including one you edited. If the last preview found your `enum.ejs`
  edited, turning the setting on first asks **Replace your edited enum.ejs?** with the file's path; **Cancel** leaves
  it off. The [dataverse-gen CLI](./moving-from-dataverse-gen.md) uses the custom template, so it writes the same
  names as this tool;
- the CLI only gets the fix while **Generate templates** is on.

Turn it off again on the Options card or next to the Generate button; the next Generate writes
dataverse-gen's `enum.ejs` and names again. **Settings** → **Options** → **Custom enum template** only sets the
default for projects whose file has no value yet. Which member keeps the plain name follows the option order in Dataverse,
so reordering the options can move the suffix to another member; renaming the labels is still the lasting fix.

## Private custom APIs

Private custom APIs, and ones the environment's metadata cache doesn't include yet, are still listed and
selectable. The tool builds them from the custom API record, its request parameters and its response properties.
dataverse-gen can't generate these.

If the custom API records can't be read (for example, without read access to the `customapi` table), Preview stops
with an error that names the selected custom APIs, rather than generating without them. Preview tries again the next
time you run it. The table list still loads; custom APIs just aren't flagged in it.

## Known limitations

- **Live testing:** the tool has been tested inside PPTB against a live environment for connecting, listing
  tables, projects, selecting, the Settings panel, previewing, generating, deleting orphaned files (on Windows)
  and the dark theme. Error paths, following a theme switch while the tool is open, and orphan deletion on macOS
  and Linux are still to be tested live; see [Testing](../contributing/testing.md).
- **Custom EJS templates aren't used by this tool.** Generate writes dataverse-gen's templates to `_templates` for
  the CLI and overwrites any edits there on every run, so commit customized templates to source control to be able
  to restore them.
- **Orphaned files are only reported** unless you turn on **Delete orphaned files** and confirm. Deletion is
  permanent (no Recycle Bin or Trash).
- **A few type mappings differ from dataverse-gen** where its output wouldn't compile. See
  [Moving from dataverse-gen](./moving-from-dataverse-gen.md).
