# Interface: IRecentProjectsListProps

Defined in: [components/cards/RecentProjectsList.tsx:7](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/RecentProjectsList.tsx#L7)

Props for [RecentProjectsList](../functions/RecentProjectsList.md).

## Properties

### busy

> **busy**: `boolean`

Defined in: [components/cards/RecentProjectsList.tsx:13](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/RecentProjectsList.tsx#L13)

Disables every project button.

***

### heading

> **heading**: `string`

Defined in: [components/cards/RecentProjectsList.tsx:9](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/RecentProjectsList.tsx#L9)

"Recent projects", or "Switch to a recent project" while one is open.

***

### items

> **items**: [`RecentProject`](RecentProject.md)[]

Defined in: [components/cards/RecentProjectsList.tsx:11](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/RecentProjectsList.tsx#L11)

The projects to offer, in order (see `recentProjects`); the list renders nothing when it's empty.

***

### onOpen

> **onOpen**: (`target`) => `void`

Defined in: [components/cards/RecentProjectsList.tsx:15](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/RecentProjectsList.tsx#L15)

Called with the project's name and location when its button is clicked.

#### Parameters

##### target

[`ProjectOpenTarget`](ProjectOpenTarget.md)

#### Returns

`void`
