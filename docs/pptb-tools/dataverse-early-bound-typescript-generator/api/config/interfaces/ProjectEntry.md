# Interface: ProjectEntry

Defined in: [config/index.ts:5](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L5)

A project created with the New Project dialog.

## Properties

### createdOn

> **createdOn**: `string`

Defined in: [config/index.ts:14](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L14)

ISO timestamp.

***

### description

> **description**: `string`

Defined in: [config/index.ts:8](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L8)

***

### id

> **id**: `string`

Defined in: [config/index.ts:6](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L6)

***

### lastGeneratedFiles?

> `optional` **lastGeneratedFiles?**: `string`[]

Defined in: [config/index.ts:21](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L21)

Output files (relative paths) the last Generate produced for this project, used to tell whether the next
one adds or drops files. `undefined` until the project is first generated.

***

### location

> **location**: `string`

Defined in: [config/index.ts:10](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L10)

Absolute folder path, picked through PPTB's folder picker.

***

### modifiedOn

> **modifiedOn**: `string`

Defined in: [config/index.ts:16](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L16)

ISO timestamp of the last change; equals `createdOn` until the project is changed.

***

### name

> **name**: `string`

Defined in: [config/index.ts:7](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L7)

***

### version

> **version**: `string`

Defined in: [config/index.ts:12](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L12)

Project version; new projects start at [DEFAULT\_PROJECT\_VERSION](../variables/DEFAULT_PROJECT_VERSION.md).
