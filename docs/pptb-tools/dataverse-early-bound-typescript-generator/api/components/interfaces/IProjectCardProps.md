# Interface: IProjectCardProps

Defined in: [components/cards/ProjectCard.tsx:23](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L23)

Props for [ProjectCard](../functions/ProjectCard.md).

## Properties

### busy

> **busy**: `boolean`

Defined in: [components/cards/ProjectCard.tsx:40](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L40)

Work in progress (or not running in PPTB): disables every button, including the recent projects.

***

### configState

> **configState**: [`ProjectConfigState`](../../services/interfaces/ProjectConfigState.md) \| `null`

Defined in: [components/cards/ProjectCard.tsx:34](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L34)

The open project's `.dataverse-gen.json`: whether it exists (a "found" or "created on generate" badge) and its
selection counts. No badges while `null`.

***

### now?

> `optional` **now?**: `number`

Defined in: [components/cards/ProjectCard.tsx:52](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L52)

Current time for relative dates; a parameter so tests get stable output.

***

### onCopyPath

> **onCopyPath**: (`path`, `label`) => `void`

Defined in: [components/cards/ProjectCard.tsx:50](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L50)

Called with the project folder and `"Project folder path"` when its copy button is clicked.

#### Parameters

##### path

`string`

##### label

`string`

#### Returns

`void`

***

### onLoadExistingProject

> **onLoadExistingProject**: () => `void`

Defined in: [components/cards/ProjectCard.tsx:44](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L44)

Opens the Load Existing Project dialog.

#### Returns

`void`

***

### onNewProject

> **onNewProject**: () => `void`

Defined in: [components/cards/ProjectCard.tsx:42](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L42)

Opens the New Project dialog.

#### Returns

`void`

***

### onOpenRecent

> **onOpenRecent**: (`target`) => `void`

Defined in: [components/cards/ProjectCard.tsx:46](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L46)

Opens a recent project directly.

#### Parameters

##### target

[`ProjectOpenTarget`](ProjectOpenTarget.md)

#### Returns

`void`

***

### onReload

> **onReload**: () => `void`

Defined in: [components/cards/ProjectCard.tsx:48](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L48)

Called when the reload button of an open project is clicked, to read `.dataverse-gen.json` from disk again.

#### Returns

`void`

***

### projectRoot

> **projectRoot**: `string` \| `null`

Defined in: [components/cards/ProjectCard.tsx:27](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L27)

The open project's folder, or `null` for the empty state with Load Existing Project and New Project.

***

### projects

> **projects**: [`ProjectEntry`](../../config/interfaces/ProjectEntry.md)[]

Defined in: [components/cards/ProjectCard.tsx:36](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L36)

Saved projects, for the open project's name and version and for the recent-projects list.

***

### recentProjectCount?

> `optional` **recentProjectCount?**: `number`

Defined in: [components/cards/ProjectCard.tsx:38](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L38)

How many recent projects to offer (the General setting); 0 hides the list. Defaults to 3.

***

### rememberedFolder

> **rememberedFolder**: `string` \| `null`

Defined in: [components/cards/ProjectCard.tsx:29](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L29)

Folder used last time with this connection, offered first for reopening while no project is open.

***

### step

> **step**: [`StepState`](StepState.md)

Defined in: [components/cards/ProjectCard.tsx:25](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx#L25)

The card's step in the workflow: number, title and completion badge.
