# Interface: UseToolSettingsOptions

Defined in: [hooks/useToolSettings.ts:10](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useToolSettings.ts#L10)

## Properties

### onError

> **onError**: (`message`) => `void`

Defined in: [hooks/useToolSettings.ts:12](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useToolSettings.ts#L12)

Shows an error in the page (the error bar).

#### Parameters

##### message

`string`

#### Returns

`void`

***

### onPlanStale

> **onPlanStale**: () => `void`

Defined in: [hooks/useToolSettings.ts:14](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useToolSettings.ts#L14)

Called when a saved setting makes the current preview out of date.

#### Returns

`void`
