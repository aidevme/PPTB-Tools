# App

The root component. It calls the state hooks, wires them together, and renders the page: the
[Header](../layout/header.md), the [SettingsPanel](../panels/settings-panel.md), the project dialogs, the status
banners and progress bar, [WorkflowProgress](../shared/workflow-progress.md), the four step cards, the Generate
confirmations, and the [Footer](../layout/footer.md). It holds no state of its own beyond the error message and
which dialog or panel is open.

Source: [`src/components/apps/App.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/apps/App.tsx);
styles in `src/styles/App.styles.ts`. `main.tsx` imports it directly; it isn't exported from the components barrel.

The hooks it calls, the state each one owns, and the key callbacks are described in
[App state and hooks](../../architecture/app-state.md). The order the cards appear in is on the
[Components](../index.md#page-layout) page.
