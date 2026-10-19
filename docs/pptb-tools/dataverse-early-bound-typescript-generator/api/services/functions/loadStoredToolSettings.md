# Function: loadStoredToolSettings()

> **loadStoredToolSettings**(): `Promise`\<`Record`\<`string`, `unknown`\> \| `undefined`\>

Defined in: [services/settings.ts:85](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/settings.ts#L85)

Reads everything PPTB has stored for this tool in this installation (`toolboxAPI.settings.getAll()`): the saved
Settings-panel values (`toolConfig`), the saved projects, and the project folder remembered per connection.

## Returns

`Promise`\<`Record`\<`string`, `unknown`\> \| `undefined`\>

The stored settings by key (`{}` when nothing is stored yet), or `undefined` outside PPTB.

## Remarks

PPTB doesn't expose where it stores the file, only its contents.

## Throws

When PPTB fails to read the settings.
