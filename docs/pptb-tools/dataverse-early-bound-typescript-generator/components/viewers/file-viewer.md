# FileViewer

The right side of the [PreviewCard](./preview-card.md). It shows the selected file: what Generate would
change for a changed file, or the generated content otherwise.

Sources:
[`src/components/viewers/FileViewer.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/viewers/FileViewer.tsx),
[`src/components/viewers/DiffViewer.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/viewers/DiffViewer.tsx),
[`src/components/shared/lineDiff.ts`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/lineDiff.ts)

## Props (`IFileViewerProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `file` | `PlannedFile \| null` | The selected file, or `null` for the empty state. |
| `onCopyText` | `(text: string, label: string) => void` | Copies the file's generated content. |

## Behavior

- **Empty state:** an icon, "Select a file to preview it", and a hint about the **↑**/**↓** keys.
- **Header bar:** the file name, its type and status as badges (the status badge's tooltip explains it), the
  full path, the line count, and a **Copy** button for the generated content.
- **Files with duplicate identifiers** show a warning above the content, naming each repeated identifier with
  its values (for example `Open` (values 1, 3)) and saying to rename one of the labels in Dataverse. Generate
  still writes the file, unless Skip duplicated identifier(s) is on. The lines that declare a duplicated identifier
  are highlighted in both the Generated content and Changes views (dark orange tint, accent edge on the line
  number), with a tooltip such as "Duplicate identifier Open (values 1, 3)". `duplicateLineNotes` finds them: lines
  of the form `Name = value` whose name is one of the file's `duplicateIdentifiers`.
- **Changed files** (including duplicate-identifier files that would be overwritten) get two tabs, **Changes** (the default) and **Generated content**. Selecting another file
  goes back to Changes.
- **New and unchanged files** show the generated content in a [CodeViewer](./code-viewer.md).
- **Orphaned files** have no generated content. A warning explains that the selection no longer generates
  them and that they're only deleted when **Delete orphaned files** is on and you confirm; otherwise you
  remove them yourself.

## Changes view (`DiffViewer`)

- Compares what's on disk (`existingContent`) with what Generate would write. Removed lines are tinted red
  with a `−`, added lines green with a `+`, and both the old and new line numbers are in the gutter.
- **Context:** three unchanged lines are kept around each change. Longer unchanged stretches collapse into
  "··· *n* unchanged lines" rows that span the full width.
- **Line endings:** the comparison ignores them, along with a trailing newline. If a changed file differs only
  in its final newline, the view says so.
- **Large rewrites:** past about 2000 differing lines the comparison stops, and the view shows the full new
  content with a note.
- **Accessibility:** the diff is a `table` labelled "Changes: *n* added, *n* removed", and each sign has an
  "added", "removed" or "unchanged" label.

## The diff algorithm (`diffLines`)

`diffLines(oldText, newText, context = 3)` returns blocks of lines (each with its kind and old and new line
numbers) and collapsed runs, plus the added and removed counts, or `null` past the size limit. It:

1. strips the common prefix and suffix, which is most of a regenerated file;
2. runs Myers' shortest-edit-script algorithm on the remaining middle lines;
3. groups the result into blocks with `context` lines around each change.

It's dependency-free, so it bundles into the single-script build without adding anything. `test/lineDiff.test.ts`
checks it on 500 random cases by replaying each diff to rebuild both texts.

Styles are in `src/styles/FileViewer.styles.ts`.
