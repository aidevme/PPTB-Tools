# Function: useToolSettings()

> **useToolSettings**(`__namedParameters`): `object`

Defined in: [hooks/useToolSettings.ts:21](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useToolSettings.ts#L21)

The tool config: Settings-panel values and saved projects. Holds the bundled defaults until the saved values
have loaded, and saves every change through PPTB's settings.

## Parameters

### \_\_namedParameters

[`UseToolSettingsOptions`](../interfaces/UseToolSettingsOptions.md)

## Returns

### changeSetting

> **changeSetting**: (`key`, `checked`) => `Promise`\<`void`\>

The Preview card's switches (Delete orphaned files, Skip and Rename duplicated identifier(s)): each saves
its key in the tool config, like the Settings panel.

#### Parameters

##### key

[`PreviewSettingKey`](../type-aliases/PreviewSettingKey.md)

##### checked

`boolean`

#### Returns

`Promise`\<`void`\>

### deleteProject

> **deleteProject**: (`project`) => `Promise`\<`void`\>

Removes a saved project from `projects` and saves the config; files in its folder are left alone.

#### Parameters

##### project

[`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

#### Returns

`Promise`\<`void`\>

### editProject

> **editProject**: (`project`, `changes`) => `Promise`\<`void`\>

Saves the name, description and location edited in the Load Project dialog and saves the config. The version
and dates are left alone; they track generation. A project that's open stays open at its current folder.

#### Parameters

##### project

[`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

##### changes

[`NewProject`](../../components/type-aliases/NewProject.md)

#### Returns

`Promise`\<`void`\>

### recordProjectGeneration

> **recordProjectGeneration**: (`root`, `applied`) => `Promise`\<`void`\>

After a Generate run, updates the saved project whose location is `root`: a patch version bump and a new
Modified on when the run added files or stopped producing ones the previous run did. Folders that
aren't saved projects are left alone; a failure to save is logged, since the files were written.

#### Parameters

##### root

`string`

##### applied

[`WritePlan`](../../types/interfaces/WritePlan.md)

#### Returns

`Promise`\<`void`\>

### saveNewProject

> **saveNewProject**: (`project`) => `Promise`\<`void`\>

Adds a project from the New Project dialog to `projects` and saves the config. Throws if saving fails.

#### Parameters

##### project

[`NewProject`](../../components/type-aliases/NewProject.md)

#### Returns

`Promise`\<`void`\>

### saveToolSettings

> **saveToolSettings**: (`draft`) => `Promise`\<`void`\>

Saves the Settings-panel values; the panel stays open and shows the error if saving fails.

#### Parameters

##### draft

[`ToolConfig`](../../config/interfaces/ToolConfig.md)

#### Returns

`Promise`\<`void`\>

### toolSettings

> **toolSettings**: [`ToolConfig`](../../config/interfaces/ToolConfig.md)
