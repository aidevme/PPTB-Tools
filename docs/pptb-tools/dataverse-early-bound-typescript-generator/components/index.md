# Components

Part of the [Contributor guide](../contributing/).

The tool's UI is built from presentational React components in
[`src/components/`](https://github.com/aidevme/PPTB-Tools/tree/main/tools/dataverse-early-bound-typescript-generator/src/components),
using Fluent UI v9. They hold no app state: the hooks in `src/hooks/` own the state, and `App.tsx` wires them together and
passes data and callbacks down as props. Everything is exported from the folder's `index.ts` barrel.

These pages are grouped in the same folders as the source: `apps/`, `cards/`, `dialogs/`, `layout/`, `panels/`,
`shared/`, `tables/` and `viewers/`.

## Page layout

`App.tsx` renders the components top to bottom in workflow order:

| Order | Component | Role |
| --- | --- | --- |
| — | [App](./apps/app.md) | The root component: calls the state hooks and renders everything below |
| — | [Header](./layout/header.md) | App icon, title and version, connection status, and the Settings button |
| — | [WorkflowProgress](./shared/workflow-progress.md) | The four steps across the top of the page; click one to scroll to its card |
| — | [SettingsPanel](./panels/settings-panel.md) | Drawer opened from the header's Settings button |
| 1 | [ProjectCard](./cards/project-card.md) | Pick the project folder and load `.dataverse-gen.json` |
| — | [ProjectFormDialog](./dialogs/project-form-dialog.md) | Dialog opened from ProjectCard's New Project button |
| — | [LoadProjectDialog](./dialogs/load-project-dialog.md) | Dialog opened from ProjectCard's Load Existing Project button |
| — | [ConfirmationDialog](./dialogs/confirmation-dialog.md) | Reusable confirm/cancel dialog, used before deleting a saved project |
| 2 | [SelectionCard](./cards/selection-card.md) | Choose tables, actions and functions |
| 3 | [OptionsCard](./cards/options-card.md) | Output folder and which files to generate |
| 4 | [PreviewCard](./cards/preview-card.md) | Compare generated files with disk, then write them |
| — | [SelectionTable](./tables/selection-table.md) | The SelectionCard's table: a checkbox per row, sortable columns |
| — | [FileTable](./tables/file-table.md) | PreviewCard's sortable file table |
| — | [ProjectsTable](./tables/projects-table.md) | LoadProjectDialog's table of saved projects |
| — | [SortableHeaderCell](./tables/sortable-header-cell.md) | The sortable header cell the three tables share |
| — | [FileSearchBox](./shared/file-search-box.md) | The search box above PreviewCard's file table |
| — | [PathChip](./shared/path-chip.md) | A shortened path with a tooltip and a copy button, in ProjectCard and PreviewCard |
| — | [FileViewer](./viewers/file-viewer.md) | The selected file's header, changes and content, inside PreviewCard |
| — | [CodeViewer](./viewers/code-viewer.md) | Syntax-highlighted file view inside PreviewCard |
| — | [StepCard](./shared/step-card.md) | Shared frame for the four step cards: step header, status badge, active-step accent |
| — | [Footer](./layout/footer.md) | Tool name and version, credits to dataverse-ify and dataverse-gen, and Documentation and GitHub links |

## Conventions

- **Fluent UI v9 only.** Build UI from `@fluentui/react-components` and `@fluentui/react-icons`, and take
  colors from `tokens` so components follow PPTB's light/dark theme.
- **No state of their own beyond view state.** Things like the active tab, a search term or a list filter can
  live in the component; anything saved to `.dataverse-gen.json` or shared between cards belongs in the hooks (`src/hooks/`).
- **Props interfaces.** New components name theirs `I<ComponentName>Props` (for example `ICodeViewerProps`).
  Older components use `<ComponentName>Props`.
- **Export from the barrel.** Add each new component and its props type to `src/components/index.ts`.
