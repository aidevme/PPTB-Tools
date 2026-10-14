# Settings panel: candidate settings

Status: **in progress**: the P1 settings are done (2026-10-14); P2 and P3 are still to do. Tool: [Dataverse Early-Bound TypeScript Generator](../pptb-tools/dataverse-early-bound-typescript-generator/index.md).
Component: `src/components/panels/SettingsPanel.tsx`.

Settings that could be added to the Settings panel, grouped by tab, with where each value is hard-coded today
and a suggested priority. Rows marked **Done** are implemented; the rest are candidates.

## Where each kind of setting belongs

The panel has three tabs. Each new setting goes on the tab that matches what it affects:

| Tab | Purpose | Saved in |
| --- | --- | --- |
| **General** | How the tool itself behaves: notifications, startup, lists, preview | Tool settings (`toolConfig` in PPTB's per-tool settings) |
| **Options** | What every project generates; applied whenever a project is opened, and editable per project on the Options card | Tool settings as defaults, then each project's `.dataverse-gen.json` |
| **Generate & files** | How Generate treats files in the output folders | Tool settings |

## Current settings

| Tab | Setting | Control | Default | Config key |
| --- | --- | --- | --- | --- |
| General | Show "Project loaded" notification | Switch | On | `general.showProjectLoadedNotification` |
| General | Show "Preview ready" notification | Switch | On | `general.showPreviewReadyNotification` |
| General | Show "Generation complete" notification | Switch | On | `general.showGenerationCompleteNotification` |
| General | Recent projects shown | SpinButton, 0–10 | 3 | `general.recentProjectCount` |
| General | Rows shown in the Select tables | SpinButton, 100–2000 | 500 | `general.selectionRowLimit` |
| Options | Output folder | Input | `./src/dataverse-gen` | `projectDefaults.outputRoot` |
| Options | Early-bound entity interfaces (dataverse-ify) | Switch | On | `projectDefaults.generateEntityTypes` |
| Options | Form context helpers (Xrm.FormContext) | Switch | Off | `projectDefaults.generateFormContext` |
| Options | index.ts barrel file | Switch | On | `projectDefaults.generateIndex` |
| Generate & files | Delete Orphaned Files | Switch | Off | `deleteOrphanedFiles` |
| Generate & files | Ask before generating | Switch | Off | `confirmBeforeGenerate` |

Priorities below: **P1** for the first release, **P2** useful next, **P3** advanced or only if users ask.

## General tab

### Notifications

The tool shows a PPTB notification after loading a project, finishing a preview and finishing a generation
(`services/notifications.ts`). Some users will want fewer.

| Setting | Control | Default | Today | Priority |
| --- | --- | --- | --- | --- |
| Show "Project loaded" notification | Switch | On | Always shown (`notifyProjectLoaded`) | P1 · **Done** |
| Show "Preview ready" notification | Switch | On | Always shown (`notifyPreviewReady`) | P1 · **Done** |
| Show "Generation complete" notification | Switch | On | Always shown (`notifyGenerationComplete`) | P1 · **Done** |
| Notification duration (success and info) | Dropdown: 3 s, 5 s, 10 s, until closed | 3 s / 5 s | Fixed in `NOTIFICATION_TYPES` | P2 |

Error notifications stay always on and persistent, as PPTB's error-handling guidance expects.

### Startup and projects

| Setting | Control | Default | Today | Priority |
| --- | --- | --- | --- | --- |
| Recent projects shown on the Project card | Number, 0–10 (0 hides the list) | 3 | `MAX_RECENT` in `ProjectCard.tsx` | P1 · **Done** |
| Remember the project folder per connection | Switch | On | Always (`rememberProjectFolder`) | P2 |
| Load Existing Project: default sort | Dropdown: Name, Modified On, Created On | Name | `DEFAULT_SORT` in `LoadProjectDialog.tsx` | P3 |

"Reopen the last project automatically" can't be offered: PPTB only grants folder access through a folder picker
in the current session.

### Lists (Select step)

| Setting | Control | Default | Today | Priority |
| --- | --- | --- | --- | --- |
| Rows shown in the Select tables | Number, 100–2000 | 500 | `MAX_ROWS` in `SelectionCard.tsx` | P1 · **Done** |
| Start on tab | Dropdown: Tables, Actions, Functions | Tables | Fixed | P3 |
| Hide deprecated tables | Switch | Off | Not available; would hide tables whose display name starts with "(Deprecated)" or "[Deprecated]" | P2 |
| Table types to list | Multi-select: Standard, Activity, Virtual, Elastic | All | Not available; uses the `tableType` already loaded | P3 |

### Preview

| Setting | Control | Default | Today | Priority |
| --- | --- | --- | --- | --- |
| Show unchanged files by default | Switch | Off | Fixed in `PreviewCard.tsx` (`showUnchanged: false`) | P2 |
| Open changed files on | Dropdown: Changes, Content | Changes | Fixed | P2 |
| Remember the file list width | Switch | Off | Resets to 480 px (`DEFAULT_LIST_WIDTH`) | P3 |
| "$metadata too large" banner | Dropdown: 5 s, 10 s, until closed | 5 s | `METADATA_FALLBACK_WARNING_MS` in `App.tsx` | P3 |

### Advanced

These are better left hard-coded unless users report problems. If they're added, put them in a collapsed
**Advanced** section.

| Setting | Control | Default | Today | Priority |
| --- | --- | --- | --- | --- |
| Parallel metadata requests | Number, 1–8 | 4 | `METADATA_CONCURRENCY` in `metadataProvider.ts`. Lower it if the environment throttles (HTTP 429) | P3 |
| Retry attempts for throttling and outages | Number, 1–5 | 3 | `withRetry` in `errors.ts` | P3 |
| Debug logging | Switch | Off | Not available; would log API calls and timings to the console for bug reports | P3 |

## Options tab

Options are written to each project's `.dataverse-gen.json`, which the dataverse-gen CLI also reads. Only add
keys that dataverse-gen understands, so projects stay interchangeable.

| Setting | Control | Default | `.dataverse-gen.json` key | Priority |
| --- | --- | --- | --- | --- |
| Generated file extension | Input | `.ts` | `output.fileSuffix` (already supported by the generator, not exposed) | P2 |
| Referenced types (imports used by generated files) | Editor or JSON field | dataverse-ify defaults (`DEFAULT_REFERENCED_TYPES`) | `referencedTypes`. Lets a project import `dataverse-ify` types from a different module path | P3 |

Not to add: `output.templateRoot` and `output.useCache`. dataverse-gen's CLI uses them, but this tool doesn't (it
has built-in templates and no on-disk cache).

## Generate & files tab

| Setting | Control | Default | Today | Priority |
| --- | --- | --- | --- | --- |
| Ask before generating | Switch | Off | Not available. Shows a confirmation naming the output folder and the files to be created and overwritten; overwrites can't be undone. Also addresses a marketplace intake finding (overwrites aren't confirmed) | P1 · **Done** |
| Show orphan list before deleting | — | — | Already always on when Delete Orphaned Files is on | — |
| Maximum orphans listed in the confirmation | Number | 10 | `ORPHANS_LISTED` in `App.tsx` | P3 |

Not to add: a line-ending (CRLF) or formatting option. The output must match dataverse-gen byte for byte
(`test/generator.test.ts`), and unchanged-file detection already ignores line-ending differences.

## Settings not to add

| Idea | Why not |
| --- | --- |
| Light/dark theme override | The tool must follow PPTB's theme (Verified badge requirement). |
| Reopen the last project on startup | PPTB only grants folder access through a folder picker in the current session. |
| Turn off error notifications | Errors must always be reported to the user. |
| Template folder, metadata cache | dataverse-gen CLI features this tool doesn't have. |
| Output formatting options | Would break byte-for-byte compatibility with dataverse-gen. |

## Implementing a new setting

For each new setting:

1. **Config:** add the field to `ToolConfig` in `src/config/index.ts`, with a default in
   `src/config/dataverse-early-bound-typescript-generator-config.json`, and validate it in `mergeToolConfig` (wrong
   type or missing → default), so settings saved by older versions keep loading.
2. **Schema:** add it to `dataverse-early-bound-typescript-generator-config.schema.json` and the sample config.
3. **UI:** add the control to the right tab in `SettingsPanel.tsx`, with an `infoLabel` explaining it and ending
   in "Saved as `<key>`.", like the existing settings.
4. **Behaviour:** replace the hard-coded constant with the setting, passed from `App.tsx` (`toolSettings`) as a
   prop.
5. **Tests:** cover the default, saving, and loading an old config without the key (`test/settings.test.ts`),
   plus the behaviour it controls.
6. **Docs:** update `src/config/README.md`, `docs/pptb-tools/dataverse-early-bound-typescript-generator/components/settings-panel.md`
   and, for user-visible behaviour, the Getting Started page.

## Suggested first release

The **P1** settings. **Done** on 2026-10-14:

- **General:** the three notification switches, recent projects shown, rows shown in the Select tables.
- **Generate & files:** ask before generating.

Next candidates are the **P2** rows: notification duration, remembering the folder per connection, hiding
deprecated tables, the Preview defaults, and the generated file extension.
