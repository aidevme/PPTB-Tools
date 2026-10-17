# Components

Part of the [Contributor guide](../contributing/).

The tool's UI is built from presentational React components in
[`src/components/`](https://github.com/aidevme/PPTB-Tools/tree/main/tools/dataverse-early-bound-typescript-generator/src/components),
using Fluent UI v9. They hold no app state: the hooks in `src/hooks/` own the state, and `App.tsx` wires them together and
passes data and callbacks down as props. Everything is exported from the folder's `index.ts` barrel.

## Page layout

`App.tsx` renders the components top to bottom in workflow order:

| Order | Component | Role |
| --- | --- | --- |
| — | [Header](./header.md) | App icon, title and version, connection status, and the Settings button |
| — | [WorkflowProgress](./workflow-progress.md) | The four steps across the top of the page; click one to scroll to its card |
| — | [SettingsPanel](./settings-panel.md) | Drawer opened from the header's Settings button |
| 1 | [ProjectCard](./project-card.md) | Pick the project folder and load `.dataverse-gen.json` |
| — | [ProjectFormDialog](./new-project-dialog.md) | Dialog opened from ProjectCard's New Project button |
| — | [LoadProjectDialog](./load-project-dialog.md) | Dialog opened from ProjectCard's Load Existing Project button |
| — | [ConfirmationDialog](./confirmation-dialog.md) | Reusable confirm/cancel dialog, used before deleting a saved project |
| 2 | [SelectionCard](./selection-card.md) | Choose tables, actions and functions |
| 3 | [OptionsCard](./options-card.md) | Output folder and which files to generate |
| 4 | [PreviewCard](./preview-card.md) | Compare generated files with disk, then write them |
| — | [FileSearchBox](./file-search-box.md) | The search box above PreviewCard's file table |
| — | [FileViewer](./file-viewer.md) | The selected file's header, changes and content, inside PreviewCard |
| — | [CodeViewer](./code-viewer.md) | Syntax-highlighted file view inside PreviewCard |
| — | [StepCard](./step-card.md) | Shared frame for the four step cards: step header, status badge, active-step accent |
| — | [Footer](./footer.md) | Tool name and version, credits to dataverse-ify and dataverse-gen, and Documentation and GitHub links |

## Conventions

- **Fluent UI v9 only.** Build UI from `@fluentui/react-components` and `@fluentui/react-icons`, and take
  colors from `tokens` so components follow PPTB's light/dark theme.
- **No state of their own beyond view state.** Things like the active tab, a search term or a list filter can
  live in the component; anything saved to `.dataverse-gen.json` or shared between cards belongs in `App.tsx`.
- **Props interfaces.** New components name theirs `I<ComponentName>Props` (for example `ICodeViewerProps`).
  Older components use `<ComponentName>Props`.
- **Export from the barrel.** Add each new component and its props type to `src/components/index.ts`.
