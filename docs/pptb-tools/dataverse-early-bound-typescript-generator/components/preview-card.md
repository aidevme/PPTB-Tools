# PreviewCard

Steps 4 and 5 of the workflow: compare the generated files with the output folder, then write them.

Source: [`src/components/cards/PreviewCard.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx)

## Props (`PreviewCardProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `plan` | `WritePlan \| null` | The last preview: every file with its status and content. `null` before the first preview. |
| `stale` | `boolean` | The selection or options changed since the plan was computed. |
| `canPreview` | `boolean` | Enables the Preview button. |
| `needsProject` | `boolean` | Everything is ready except the project folder; shows a hint. |
| `busy` | `boolean` | Disables both buttons while another operation runs. |
| `onPreview` | `() => void` | Loads metadata, generates the files and compares them with disk. |
| `onGenerate` | `() => void` | Writes new and changed files and saves `.dataverse-gen.json`. |

## Behavior

- **Generate** is disabled until there's an up-to-date preview with at least one new or changed file.
- **File statuses:** each file is `new`, `changed`, `unchanged` or `orphaned`. The status badges in the
  toolbar show counts and filter the list.
- **Unchanged files** aren't rewritten. **Orphaned files** (in the output folder but no longer generated)
  are reported, never deleted.
- **File list and viewer:** the list is on the left; selecting a file shows its generated content on the
  right in a [CodeViewer](./code-viewer.md). An orphaned file has no generated content, so the viewer
  explains that it can be deleted manually.
