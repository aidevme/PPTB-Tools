# FileSearchBox

The search box above the [PreviewCard](../cards/preview-card.md)'s file table. It's a Fluent UI `SearchBox` with the
placeholder "Search files", the clear button `SearchBox` brings, and a minimum width that fits a file
name.

Source: [`src/components/shared/FileSearchBox.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/FileSearchBox.tsx)

## Props (`IFileSearchBoxProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `value` | `string` | The search text. |
| `onChange` | `(value: string) => void` | Called with the new text on every keystroke, and with `''` when the clear button is clicked. |
| `className` | `string` (optional) | Extra class for the box. |

## Behavior

The component only edits the text; the PreviewCard keeps it in its file filter and the table filters on it
(`visibleFiles` in `components/shared/previewFiles.tsx`):

- **Fewer than three characters** (`MIN_SEARCH_LENGTH`): no filtering.
- **Three or more** (`isSearchActive`): the table lists the files whose name, or path, starts with the text,
  ignoring case (`matchesSearch`). Unchanged files are included, so a search finds every file; a selected status
  tile still narrows the results, and the PreviewCard disables **Show unchanged**.

Styles: `useFileSearchBoxStyles` in `src/styles/FileSearchBox.styles.ts`.
