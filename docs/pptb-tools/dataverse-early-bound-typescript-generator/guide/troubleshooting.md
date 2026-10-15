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

## Private custom APIs

Private custom APIs, and ones the environment's metadata cache doesn't include yet, are still listed and
selectable. The tool builds them from the custom API record, its request parameters and its response properties.
dataverse-gen can't generate these.

## Known limitations

- **Live testing:** the tool has been tested inside PPTB against a live environment for connecting, listing
  tables, projects, selecting, the Settings panel, previewing, generating, deleting orphaned files (on Windows)
  and the dark theme. Error paths, following a theme switch while the tool is open, and orphan deletion on macOS
  and Linux are still to be tested live; see [Testing](../contributing/testing.md).
- **Custom EJS templates aren't supported.** The dataverse-gen CLI still honors them.
- **Orphaned files are only reported** unless you turn on **Delete orphaned files** and confirm. Deletion is
  permanent (no Recycle Bin or Trash).
- **A few type mappings differ from dataverse-gen** where its output wouldn't compile. See
  [Moving from dataverse-gen](./moving-from-dataverse-gen.md).
