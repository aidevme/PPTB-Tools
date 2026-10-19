# SettingsPanel

<!-- cspell:ignore complextype -->

Tool settings, shown in a Fluent UI `OverlayDrawer` that slides in from the right edge. It opens from the
Settings button in the [Header](../layout/header.md).

Sources: [`SettingsPanel.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx)
(the panel and the list of settings),
[`SettingsPanel.const.ts`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.const.ts)
(the tabs, their intros and the scope badges) and
[`SettingsParts.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsParts.tsx)
(`SettingsSection`, `SettingRow`, `OutputPreview`); styles in `src/styles/SettingsPanel.styles.ts`. The draft, Save and
Reset to defaults are in `src/hooks/useSettingsDraft.ts`, and the titles and info text the panel shares with the
Preview card are in `src/components/shared/settingsInfo.tsx`.

## Props (`SettingsPanelProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `open` | `boolean` | Whether the drawer is shown. |
| `onOpenChange` | `(open: boolean) => void` | Called when the drawer opens or closes. |
| `settings` | `ToolConfig` | The saved settings. Edits are made on a draft copy until Save. |
| `onSave` | `(settings: ToolConfig) => Promise<void>` | Persists the settings. The panel closes when it resolves and shows the error when it rejects. |

## Layout

- **Drawer:** about 780 px wide (`min(780px, 100vw)`), between Fluent's medium and large sizes, so the
  navigation and right-aligned controls fit without stretching rows across the screen.
- **Header:** a settings icon in a brand-coloured tile, the title **Settings**, and the tool's name as a subtitle.
  The close (X) button, the Escape key, or a click outside the drawer closes it. `App.tsx` holds the open state
  (`settingsOpen`).
- **Navigation column** (left, sticky):
  - a **Search settings** box;
  - five vertical tabs, each with an icon and a one-line subtitle: **General** (notifications and lists), **Options**
    (what every project generates), **Generate & files** (confirmations and orphans), **Templates** (EJS templates)
    and **Advanced** (for power users). The selected tab is view state
    inside the component and starts on General.
- **Content** (right, at most 560 px wide): a one-line intro for the tab, then **section cards**. Each card has an
  icon, a title and **scope badges** saying where its values apply, then one **row** per setting:
  - the setting's title (with an info button for the longer explanation, ending "Saved as `<key>`") and a short
    grey description on the left;
  - its control on the right (or below, for the output folder's text box);
  - a small marigold **dot** after the title while the value differs from the saved one.
  The controls are labelled by the row's title and described by its description (`aria-labelledby`,
  `aria-describedby`).
- **Tab changes** fade the content in briefly; the animation is off when the system asks for reduced motion.
- **Footer:** on the left, **● Unsaved changes** (highlighted) or **No unsaved changes**; on the right, **Save** and
  a **Cancel** split button (Fluent UI `SplitButton` with a `Menu`). Clicking Cancel closes the panel; the chevron
  (**More actions**) opens a menu with **Cancel** (the default) and **Reset to defaults**.

## Settings

| Tab | Section (scope badges) | Setting | Control | Key |
| --- | --- | --- | --- | --- |
| General | Notifications (This PPTB installation) | Project loaded, Preview ready, Generation complete | Switch each, on by default | `general.showProjectLoadedNotification`, `general.showPreviewReadyNotification`, `general.showGenerationCompleteNotification` |
| General | Lists & startup (This PPTB installation) | Recent projects | `SpinButton` 0–10 with a "projects" unit; 0 hides the list on the [ProjectCard](../cards/project-card.md) | `general.recentProjectCount` |
| General | Lists & startup | Rows in the Select tables | `SpinButton` 100–2000, step 100, with a "rows" unit; the row limit of the [SelectionCard](../cards/selection-card.md) | `general.selectionRowLimit` |
| Options | Output (Default for every project, .dataverse-gen.json) | Output folder | Text box | `projectDefaults.outputRoot` |
| Options | Generated files (same badges) | Early-bound entity interfaces, Form context helpers, index.ts barrel file | Switch each | `projectDefaults.generateEntityTypes`, `generateFormContext`, `generateIndex` |
| Generate & files | Before generating (All projects) | Ask before generating | Switch, off by default | `confirmBeforeGenerate` |
| Generate & files | Templates (All projects) | Generate templates | Switch, on by default | `generateTemplates` |
| Generate & files | Duplicate identifiers (All projects) | Rename duplicated identifier(s) | Switch, off by default | `renameDuplicateIdentifiers` |
| Generate & files | Duplicate identifiers (All projects) | Custom enum template | Switch, off by default; the global default for projects without their own value, never replacing one, so Save doesn't ask | `projectDefaults.customEnumTemplate` |
| Generate & files | Duplicate identifiers (All projects) | Skip duplicated identifier(s) | Switch, off by default | `skipDuplicateIdentifiers` |
| Generate & files | Orphaned files (All projects, **Permanent**) | Delete orphaned files | Switch, off by default | `deleteOrphanedFiles` |

- **Notifications:** error notifications are always shown; only the three success notifications can be turned off.
- **Numbers:** out-of-range or fractional values are rounded and clamped to the range when saved
  (`mergeToolConfig`).
- **Options:** applied whenever a project is opened, also over the values in its `.dataverse-gen.json`, and to the
  open project when different ones are saved. The [OptionsCard](../cards/options-card.md) can still change them for a
  project; Generate saves them to its `.dataverse-gen.json`. A blank output folder saves as the default
  (`./src/dataverse-gen`).
- **Output preview:** under the Generated files card, `OutputPreview` shows the folder tree a project with these
  options produces (for an account table), updating as the switches change: every table gets a file in
  `entities/`, the two interface options add to those files, and `index.ts` is struck through when it's off.
- **Ask before generating:** when on, Generate opens a "Generate files?" confirmation naming the output folder and
  how many files will be created and overwritten, and saying overwrites can't be undone. When orphaned files are
  deleted too, their confirmation covers both.
- **Generate templates:** its own card after Before generating. When on, Generate writes dataverse-gen's EJS
  templates to the project's `templateRoot` (`./_templates` by default), overwriting edited copies. When off,
  Preview leaves them out and Generate doesn't write them; copies already on disk stay as they are, since templates
  are never orphans.
- **Skip duplicated identifier(s):** when on, Generate doesn't write files with the **duplicate identifiers** status
  (two choice labels that become the same enum member name), so an existing copy on disk stays as it is. The
  Generate button, the Preview summary, the confirmation and the result line count only the files that are
  written. When off, those files are written and only reported.
- **Delete orphaned files:** its card has a red accent stripe and a red **Permanent** badge, and while the switch is
  on, a warning says files are deleted permanently, not moved to the Recycle Bin or Trash. When on, Generate
  deletes orphaned files after you confirm the list; when off, they're only reported. It's the same setting as the
  **Delete orphaned files** switch in the [PreviewCard](../cards/preview-card.md), so the two stay in sync. Skip
  Duplicated Identifier(s) is likewise the same setting as the Preview card's **Skip duplicated identifier(s)** switch.

## Templates tab

One card, **dataverse-early-bound-typescript-generator templates** (badges: the tool's version from `package.json`,
as in the header, and **Read-only**), with no settings. `TemplatesViewer` in `SettingsParts.tsx` shows:

- a note that Generate writes these templates to the project's `templateRoot` (`./_templates` by default),
  overwriting edited copies, unless **Generate templates** is off on the Generate & files tab, and that the tool generates with built-in copies, so editing the written files doesn't
  change its output;
- a tab per template (`action.ejs`, `complextype.ejs`, `entity.ejs`, `enum.ejs`, `function.ejs`, `index.ejs`,
  `metadata.ejs`), with the path and line count;
- the selected template, read-only, in a [CodeViewer](../viewers/code-viewer.md) with line numbers and TypeScript highlighting,
  scrolling inside a 420px box.

The content comes from `DATAVERSE_GEN_TEMPLATES` in `services/dataverseGenTemplates.ts`, so it's exactly what
Generate writes. The tab isn't searchable, since it has no settings, and Save and Reset to defaults don't affect it.

## Advanced tab

For details most projects never need (icon `DeveloperBoardRegular`). Settings added here with `tab: 'advanced'`
appear on it and in search like any other; a tab without sections shows "No settings on this tab yet."

One card, **PPTB tool settings** (badges: **This PPTB installation** and **Read-only**), with no settings.
`StoredSettingsViewer` in `SettingsParts.tsx` shows:

- a note on what's included (the saved `toolConfig`, the saved projects and the project folder per connection),
  that unsaved changes in the panel aren't, and that PPTB doesn't expose the file's location;
- the number of keys and a **Refresh** button;
- the stored settings as formatted JSON, read-only, in a [CodeViewer](../viewers/code-viewer.md) with JSON
  highlighting, scrolling inside a 420px box.

The data comes from `loadStoredToolSettings` in `services/settings.ts`, which calls `toolboxAPI.settings.getAll()`.
It loads when the tab is shown (the panel's content is re-created on each tab change) and on **Refresh**. While
loading it shows a spinner; outside PPTB, a warning that the settings can only be read inside Power Platform
ToolBox; if PPTB fails to read them, the error. Like the Templates tab, it isn't searchable, and Save and Reset to
defaults don't affect it.

## Search

Typing in **Search settings** shows the matching settings from every tab at once, grouped in their section cards,
whose titles then also name the tab (for example "Orphaned files · Generate & files"). A setting matches when
every word of the search appears in its title, description, section title or a few extra keywords (for example
"toast" for the notifications). The tab selection is cleared while searching; choosing a tab clears the search.
With no matches it says so.

## Saving

- Each time the panel opens, it starts from the saved values with an empty search.
- **Save** is enabled only when a value differs from the saved one. It saves and closes the panel, or shows the
  error and stays open if saving fails.
- **Cancel** (or closing the panel) discards the changes.
- **Reset to defaults** (in the Cancel button's menu) sets every setting back to the bundled default, keeping saved
  projects. It's disabled when
  everything already has its default value, and it only changes the draft: Save still has to be clicked.
- **Where values come from:** the defaults are in
  `src/config/dataverse-early-bound-typescript-generator-config.json` (`general`, `deleteOrphanedFiles: false`,
  `confirmBeforeGenerate: false`, `skipDuplicateIdentifiers: false`, `projectDefaults`), bundled at build time. Saved values are stored in PPTB's
  per-tool settings (`toolboxAPI.settings`, key `toolConfig`) and applied over the defaults every time the tool
  loads. The tool can't write the JSON file itself: PPTB doesn't tell a tool where it's installed and only lets
  it write to folders the user picked.
