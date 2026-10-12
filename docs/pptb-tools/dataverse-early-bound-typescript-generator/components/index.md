# Components

The tool's UI is built from presentational React components in
[`src/components/`](https://github.com/aidevme/PPTB-Tools/tree/main/tools/dataverse-early-bound-typescript-generator/src/components),
using Fluent UI v9. They hold no app state: `App.tsx` owns all state and orchestration and passes data and
callbacks down as props. Everything is exported from the folder's `index.ts` barrel.

## Page layout

`App.tsx` renders the components top to bottom in workflow order:

| Order | Component | Role |
| --- | --- | --- |
| — | [Header](./header.md) | Title, connection badge, Regenerate and Settings buttons |
| — | [SettingsPanel](./settings-panel.md) | Drawer opened from the header's Settings button |
| 1 | [ProjectCard](./project-card.md) | Pick the project folder and load `.dataverse-gen.json` |
| 2 | [SelectionCard](./selection-card.md) | Choose tables, actions and functions |
| 3 | [OptionsCard](./options-card.md) | Output folder and which files to generate |
| 4 | [PreviewCard](./preview-card.md) | Compare generated files with disk, then write them |
| — | [CodeViewer](./code-viewer.md) | Syntax-highlighted file view inside PreviewCard |
| — | [Footer](./footer.md) | Attribution to dataverse-gen and dataverse-ify |

## Conventions

- **Fluent UI v9 only.** Build UI from `@fluentui/react-components` and `@fluentui/react-icons`, and take
  colors from `tokens` so components follow PPTB's light/dark theme.
- **No state of their own beyond view state.** Things like the active tab, a search term or a list filter can
  live in the component; anything saved to `.dataverse-gen.json` or shared between cards belongs in `App.tsx`.
- **Props interfaces.** New components name theirs `I<ComponentName>Props` (for example `ICodeViewerProps`).
  Older components use `<ComponentName>Props`.
- **Export from the barrel.** Add each new component and its props type to `src/components/index.ts`.
