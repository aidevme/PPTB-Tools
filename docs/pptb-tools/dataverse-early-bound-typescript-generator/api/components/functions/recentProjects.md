# Function: recentProjects()

> **recentProjects**(`projects`, `projectRoot`, `rememberedFolder`, `now`, `max?`): [`RecentProject`](../interfaces/RecentProject.md)[]

Defined in: [components/cards/recentProjects.ts:38](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/recentProjects.ts#L38)

Up to `max` projects to offer for reopening, excluding the open one: the folder last used with this
connection first, then saved projects by most recently modified. The last-used folder is shown under its
saved name when it's a saved project, and under its folder name otherwise.

## Parameters

### projects

[`ProjectEntry`](../../config/interfaces/ProjectEntry.md)[]

The saved projects; sorted by `modifiedOn` (newest first) in a copy.

### projectRoot

`string` \| `null`

The open project's folder, left out of the list; `null` when none is open.

### rememberedFolder

`string` \| `null`

The folder last used with this connection, offered first; `null` when there's none.

### now

`number`

Current time in milliseconds, for the "Modified … ago" lines.

### max?

`number` = `MAX_RECENT`

The most entries to return; MAX\_RECENT when omitted.

## Returns

[`RecentProject`](../interfaces/RecentProject.md)[]

The entries in display order, without duplicate folders (paths compared with `isSamePath`).
