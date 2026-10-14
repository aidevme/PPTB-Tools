# PreviewCard

Steps 4 and 5 of the workflow: preview what Generate would do, then write the files. Status tiles summarize
and filter the files, and the table lists them beside a [FileViewer](./file-viewer.md) that shows each
file's content or changes.

Source: [`src/components/cards/PreviewCard.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx)

## Props (`PreviewCardProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `step` | `StepState` | This step's state for the [StepCard](./step-card.md) header. |
| `plan` | `WritePlan \| null` | The last preview: every file with its status and content. `null` before the first preview. |
| `stale` | `boolean` | The selection or options changed since the plan was computed. |
| `canPreview` | `boolean` | Enables the Preview buttons. |
| `needsProject` | `boolean` | Everything is ready except the project folder; shows a hint. |
| `busy` | `boolean` | Disables the buttons while another operation runs, and shows a loading placeholder before the first preview. |
| `previewedAt` | `string \| null` | When the plan was computed (ISO), shown as "Previewed *2 minutes ago*". |
| `lastResult` | `string \| null` | Summary of the last Generate run, shown as a success message until the next preview. |
| `deleteOrphans` | `boolean` | Whether the **Delete orphaned files** switch is on (the tool setting `deleteOrphanedFiles`). |
| `onDeleteOrphansChange` | `(checked: boolean) => void` | Called when the switch is toggled; the app saves the setting. |
| `onPreview` | `() => void` | Loads metadata, generates the files and compares them with disk. |
| `onGenerate` | `() => void` | Writes new and changed files and saves `.dataverse-gen.json`; with `deleteOrphans` on and orphans present, the app asks for confirmation first, then also deletes them. |
| `onCopyText` | `(text: string, label: string) => void` | Copies a file's content or the output folder path. |
| `now` | `number` (optional) | Current time for "Previewed … ago". Defaults to `Date.now()`; tests pass a fixed value. |

## Messages

- **Out of date:** when the selection or options changed since the preview, a warning bar says so and has a
  **Preview again** button.
- **After Generate:** a success bar shows the result, for example "1 file written · 279 unchanged · 9
  orphaned · .dataverse-gen.json saved" (with "· 2 deleted" when orphans were deleted). It stays until the next preview. PPTB also shows the same line in a
  "Generation complete" success notification for 3 seconds (`summarizeGeneration` builds both).

## Action bar

- **Preview** (secondary) and **Generate** (primary). The Generate button names the count: **Generate 2
  files**, or **Nothing to write** when every file is up to date. It's disabled without an up-to-date
  preview or with nothing to write, and its tooltip says why.
- **Delete orphaned files** (`Switch`), right after Generate, with a tooltip explaining it. It reads and saves
  the same `deleteOrphanedFiles` tool setting as the [SettingsPanel](./settings-panel.md) switch, so they stay
  in sync. It's disabled until a preview exists, since only a preview tells which files are orphaned; its
  tooltip then adds "Available after Preview". When on:
  - The summary says "…and N orphaned files will be deleted." instead of "left untouched", and the card
    description changes.
  - Generate is enabled even when only deletions are pending, and reads **Delete N orphaned files** in that
    case. The workflow step counts orphans as pending.
  - Clicking Generate with orphans present opens a [ConfirmationDialog](./confirmation-dialog.md), "Delete
    orphaned files?". It lists up to 10 orphan paths (then "…and N more") and the output folder, and warns
    that deletion is permanent, not to the Recycle Bin or Trash. Its confirm button reads **Generate and
    delete N** or **Delete N files**.
  - On confirm, Generate writes new and changed files, saves `.dataverse-gen.json`, records the project
    generation, then deletes the orphans. If some remain, an error "Some orphaned files were not deleted"
    lists them (notification and page error bar); if the terminal fails entirely, "Could not delete the
    orphaned files". The writes still count as done, and the Orphaned tile shows what's left.
- "Previewed *2 minutes ago*" after a preview.
- Without a project folder, a hint says to open a project first.

## Summary and status tiles

- **Summary:** one sentence saying what Generate would do, for example "1 new file will be created and 1 file
  will be updated, and 9 orphaned files will be left untouched." (`summarizePlan(counts, deleteOrphans)` in `services/plan.ts`; with the switch on, "will be deleted"). The same
  sentence appears in a PPTB info notification, "Preview ready", for 5 seconds after each successful preview.
- **Tiles:** **New**, **Changed**, **Unchanged** and **Orphaned**, each with an icon, a large count and a
  colored left edge. A tooltip explains what Generate does with that status.
- **Tiles as filters:** clicking a tile shows only that status, and the tile is highlighted (`aria-pressed`).
  Clicking it again goes back to the default view.
- **Output folder:** shown as a chip, shortened in the middle, with the full path in a tooltip and a copy
  button.

## File table

- **Default view: changes only.** New, changed and orphaned files are listed; unchanged files appear when
  **Show unchanged** is on, or when the Unchanged tile is selected (`visibleFiles`). With nothing to show, the
  table suggests turning on **Show unchanged**.
- **Search:** filters by path, ignoring case. "Showing *n* of *total* files" updates as you filter, and is
  announced to screen readers.
- **Columns:**
  - **Name:** a type icon (table, list, lightning bolt, ƒx, database or document), the file name without its
    folder, and "(generated as …)" when an existing file's casing was reused. The full path is in a tooltip.
  - **Type:** `entities`, `enums`, `actions`, `functions`, `metadata`, or `other` for `complextypes/` and
    `index.ts` (`fileType`).
  - **Status:** a colored dot and the status.
- **Sorting:** clicking a header sorts by that column, ascending; clicking it again flips to descending. Until
  then the table keeps the plan's order, grouped by folder. Names sort naturally ignoring case, types
  alphabetically, and statuses as new, changed, unchanged, orphaned. Ties fall back to name order
  (`sortFiles`).
- **Header tooltips** explain each column, every type and every status. They open on hover and on keyboard
  focus.
- **Selecting:** click a row, or press Space or Enter, to show it in the viewer. **↑** and **↓** move to the
  previous or next file and focus it.
- **Before the first preview:** a hint to click Preview. While a first preview runs, a skeleton placeholder.

## Layout

The table and the [FileViewer](./file-viewer.md) sit side by side in matching rounded panels. The divider
between them can be dragged to resize the table, or focused and moved with **←** and **→** (32 px a step).
The table is at least 280 px wide and the viewer at least 320 px. It's a `separator` with its current width
in `aria-valuenow`.

Collapsible grouping by type isn't implemented, since it conflicts with sorting by column.
