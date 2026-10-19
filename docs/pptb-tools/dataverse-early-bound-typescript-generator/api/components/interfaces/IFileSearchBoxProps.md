# Interface: IFileSearchBoxProps

Defined in: [components/shared/FileSearchBox.tsx:5](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/FileSearchBox.tsx#L5)

Props for [FileSearchBox](../functions/FileSearchBox.md).

## Properties

### className?

> `optional` **className?**: `string`

Defined in: [components/shared/FileSearchBox.tsx:11](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/FileSearchBox.tsx#L11)

Extra class merged after the box's own root style, for layout set by the parent.

***

### onChange

> **onChange**: (`value`) => `void`

Defined in: [components/shared/FileSearchBox.tsx:9](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/FileSearchBox.tsx#L9)

Called with the new text on every keystroke, and with `''` when the clear button is clicked.

#### Parameters

##### value

`string`

#### Returns

`void`

***

### value

> **value**: `string`

Defined in: [components/shared/FileSearchBox.tsx:7](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/FileSearchBox.tsx#L7)

The search text.
