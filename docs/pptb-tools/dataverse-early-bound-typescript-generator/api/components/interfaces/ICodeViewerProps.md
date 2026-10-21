# Interface: ICodeViewerProps

Defined in: [components/viewers/CodeViewer.tsx:9](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/viewers/CodeViewer.tsx#L9)

Props for [CodeViewer](../functions/CodeViewer.md).

## Properties

### code

> **code**: `string`

Defined in: [components/viewers/CodeViewer.tsx:11](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/viewers/CodeViewer.tsx#L11)

The file's text; CRLF and CR line endings are shown as plain line breaks, and a final newline is dropped.

***

### lineNotes?

> `optional` **lineNotes?**: `ReadonlyMap`\<`number`, `string`\>

Defined in: [components/viewers/CodeViewer.tsx:15](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/viewers/CodeViewer.tsx#L15)

Lines to highlight (1-based), each with the note shown when hovering over it.

***

### path

> **path**: `string`

Defined in: [components/viewers/CodeViewer.tsx:13](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/viewers/CodeViewer.tsx#L13)

File path; its extension picks the highlighting language.
