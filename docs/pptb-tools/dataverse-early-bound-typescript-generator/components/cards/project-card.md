# ProjectCard

Step 1 of the workflow: open a project. With no project open, it shows an empty state with the main actions
and recent projects. With a project open, it shows a summary of that project.

Source: [`src/components/cards/ProjectCard.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx)

## Props (`ProjectCardProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `step` | `StepState` | This step's state for the [StepCard](../shared/step-card.md) header. |
| `projectRoot` | `string \| null` | The open project folder. |
| `rememberedFolder` | `string \| null` | Folder used last time with this connection; offered first among the recent projects. |
| `configState` | `ProjectConfigState \| null` | The loaded `.dataverse-gen.json`, its path, and whether it exists. |
| `projects` | `ProjectEntry[]` | Saved projects: the open project's name and version, and the recent projects. |
| `busy` | `boolean` | Disables every action while another operation runs. |
| `onNewProject` | `() => void` | Opens the [ProjectFormDialog](../dialogs/project-form-dialog.md). |
| `onLoadExistingProject` | `() => void` | Opens the [LoadProjectDialog](../dialogs/load-project-dialog.md). |
| `onOpenRecent` | `(target: ProjectOpenTarget) => void` | Opens a recent project directly. `ProjectOpenTarget` is `{ name, location }`. |
| `onReload` | `() => void` | Re-reads `.dataverse-gen.json` from disk. |
| `onCopyPath` | `(path: string, label: string) => void` | Copies a path to the clipboard; `label` names it in the confirmation toast. |
| `recentProjectCount` | `number` (optional) | How many recent projects to show; 0 hides the list. Defaults to 3. `App.tsx` passes the `general.recentProjectCount` setting. |
| `now` | `number` (optional) | Current time for relative dates. Defaults to `Date.now()`; tests pass a fixed value. |

## No project open

- **Empty state:** a large folder icon, "Open a project to get started", one line of explanation, and two
  actions. **Load Existing Project** is the primary button and **New Project** the secondary one. There's no
  Reload button until a project is open.
- **Recent projects:** up to three by default (`recentProjectCount`), as clickable tiles with an icon, the name and a second line. The full
  path shows in a tooltip, and clicking a tile opens that project directly. Each tile is a button named
  "Open *name* (*second line*)", with Fluent UI's focus ring (`colorStrokeFocus2`) when reached with the keyboard.

## Project open

- **Summary:** a folder icon, then:
  - the project's **name** as the title, with a **version** badge (`v1.0.2`). A folder that isn't a saved
    project shows its folder name and no version.
  - the **path**, shortened in the middle (`C:\…\Client\clientjs`), with the full path in a tooltip and a
    copy button ([PathChip](../shared/path-chip.md)).
  - **chips** for the config status (".dataverse-gen.json found" or "New project: created on generate") and
    the table, action and function counts.
  - "Modified *3 hours ago*" for saved projects.
- **Actions** on the right: Reload as an icon-only button with a tooltip, **Load Existing Project**, and
  **New Project** as a subtle button.
- **Recent projects** below, titled "Switch to a recent project", without the open project.

## Which projects are recent

`recentProjects(projects, projectRoot, rememberedFolder, now, max)` in `src/components/cards/recentProjects.ts` returns up to `max` entries (default 3, the
`recentProjectCount` setting; 0 returns none):

1. The folder last used with this connection, labelled "Last used". It shows under its saved project name
   when it's a saved project, and under its folder name otherwise.
2. Saved projects, most recently modified first, labelled "Modified *time ago*".

The open project and duplicates (the same folder, compared with `isSamePath`) are left out.

## Details

- The empty state and the summary fade in when they appear. The fade is switched off when the user has
  asked their system for reduced motion.
- The recent projects list is `RecentProjectsList` (`src/components/cards/RecentProjectsList.tsx`, styled by
  `src/styles/RecentProjectsList.styles.ts`); the card passes it the heading, the entries and `onOpenRecent`.
- Styles are in `src/styles/ProjectCard.styles.ts`. Relative times and shortened paths come from
  `src/components/shared/format.ts`.
