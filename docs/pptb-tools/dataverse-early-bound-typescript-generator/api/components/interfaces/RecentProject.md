# Interface: RecentProject

Defined in: [components/cards/subcomponents/recentProjects.ts:17](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/subcomponents/recentProjects.ts#L17)

One entry in the card's recent-projects list.

## Extends

- [`ProjectOpenTarget`](ProjectOpenTarget.md)

## Properties

### isLastUsed

> **isLastUsed**: `boolean`

Defined in: [components/cards/subcomponents/recentProjects.ts:23](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/subcomponents/recentProjects.ts#L23)

The folder last used with this connection; shown first, with a history icon.

***

### key

> **key**: `string`

Defined in: [components/cards/subcomponents/recentProjects.ts:19](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/subcomponents/recentProjects.ts#L19)

React key: the saved project's id, or `last:<folder>` for a last-used folder that isn't saved.

***

### location

> **location**: `string`

Defined in: [components/cards/subcomponents/recentProjects.ts:13](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/subcomponents/recentProjects.ts#L13)

The project folder's full path.

#### Inherited from

[`ProjectOpenTarget`](ProjectOpenTarget.md).[`location`](ProjectOpenTarget.md#location)

***

### meta

> **meta**: `string`

Defined in: [components/cards/subcomponents/recentProjects.ts:21](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/subcomponents/recentProjects.ts#L21)

Secondary line: "Last used" or "Modified 2 days ago".

***

### name

> **name**: `string`

Defined in: [components/cards/subcomponents/recentProjects.ts:11](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/subcomponents/recentProjects.ts#L11)

The saved project's name, or the folder name for a folder that isn't a saved project.

#### Inherited from

[`ProjectOpenTarget`](ProjectOpenTarget.md).[`name`](ProjectOpenTarget.md#name)
