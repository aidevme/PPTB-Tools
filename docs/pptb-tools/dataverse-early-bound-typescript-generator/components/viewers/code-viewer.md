# CodeViewer

A read-only, syntax-highlighted view of a generated file, with line numbers. Used by the
[FileViewer](./file-viewer.md) in the [PreviewCard](./preview-card.md) for a file's generated content.

Source: [`src/components/viewers/CodeViewer.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/viewers/CodeViewer.tsx)

## Props (`ICodeViewerProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `code` | `string` | The file content. |
| `path` | `string` | The file path; its extension picks the highlighting language. |
| `lineNotes` | `ReadonlyMap<number, string>` (optional) | Lines to highlight, 1-based, each with the note shown as its tooltip. Highlighted lines get a dark orange tint and a semibold line number with an accent edge. Used for duplicated identifiers. |

## Behavior

- **Shown as written.** The code isn't reformatted, so the view matches the file that gets written to disk. CRLF
  line endings (dataverse-gen's templates use them) are shown as plain line breaks.
- **Languages:** `.ts`/`.tsx` files are highlighted as TypeScript and `.json` files as JSON. dataverse-gen's `.ejs`
  templates are highlighted as TypeScript too, since that's what they produce; their `<% %>` tags show in the
  punctuation color. Anything else is plain text, still with line numbers.
- **Theme colors:** highlighting uses [prism-react-renderer](https://github.com/FormidableLabs/prism-react-renderer)
  for tokenizing, with colors taken from Fluent palette tokens instead of a Prism theme, so they follow
  PPTB's light/dark theme.
- **Copying:** line numbers aren't selectable, and blank lines aren't doubled when you copy.
- **Large files:** content over about 300 KB is shown as plain text with line numbers, since tokenizing runs
  synchronously while rendering.
