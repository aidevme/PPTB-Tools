# CodeViewer

A read-only, syntax-highlighted view of a generated file, with line numbers. Used by the
[FileViewer](./file-viewer.md) in the [PreviewCard](./preview-card.md) for a file's generated content.

Source: [`src/components/viewers/CodeViewer.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/viewers/CodeViewer.tsx)

## Props (`ICodeViewerProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `code` | `string` | The file content. |
| `path` | `string` | The file path; its extension picks the highlighting language. |

## Behavior

- **Shown as written.** The code isn't reformatted, so the view matches the file that gets written to disk.
- **Languages:** `.ts`/`.tsx` files are highlighted as TypeScript and `.json` files as JSON. Anything else
  is shown as plain text.
- **Theme colors:** highlighting uses [prism-react-renderer](https://github.com/FormidableLabs/prism-react-renderer)
  for tokenizing, with colors taken from Fluent palette tokens instead of a Prism theme, so they follow
  PPTB's light/dark theme.
- **Copying:** line numbers aren't selectable, and blank lines aren't doubled when you copy.
- **Large files:** content over about 300 KB is shown as plain text, since tokenizing runs synchronously
  while rendering.
