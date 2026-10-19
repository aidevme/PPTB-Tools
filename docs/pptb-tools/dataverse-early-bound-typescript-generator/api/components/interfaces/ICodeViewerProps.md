# Interface: ICodeViewerProps

Defined in: [components/viewers/CodeViewer.tsx:38](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/viewers/CodeViewer.tsx#L38)

Props for [CodeViewer](../functions/CodeViewer.md).

## Properties

### code

> **code**: `string`

Defined in: [components/viewers/CodeViewer.tsx:40](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/viewers/CodeViewer.tsx#L40)

The file's text; CRLF and CR line endings are shown as plain line breaks, and a final newline is dropped.

***

### lineNotes?

> `optional` **lineNotes?**: `ReadonlyMap`\<`number`, `string`\>

Defined in: [components/viewers/CodeViewer.tsx:44](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/viewers/CodeViewer.tsx#L44)

Lines to highlight (1-based), each with the note shown when hovering over it.

***

### path

> **path**: `string`

Defined in: [components/viewers/CodeViewer.tsx:42](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/viewers/CodeViewer.tsx#L42)

File path; its extension picks the highlighting language.
