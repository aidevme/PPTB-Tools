# App state and hooks

The tool's state lives in custom hooks in `src/hooks/`; there's no state management library.
`src/components/apps/App.tsx` calls the hooks, wires them together and renders the cards. The
[components](../components/) are presentational and receive everything as props.

## Hooks

`App.tsx` calls them in this order, because each one takes values or callbacks from the ones before it:

| Hook | Owns |
| --- | --- |
| `useConnection` | The active PPTB connection. Read on mount and again whenever PPTB raises `connection:created`, `connection:updated` or `connection:deleted`; `null` outside PPTB (for example under `npm run dev`). Returns `{ connection, isLoading, refreshConnection }`. |
| `useStickyBarHeights` | Publishes the sticky header and footer heights as CSS variables, so scrolling to a step card lands below the header. |
| `usePlanState` | `plan`, `planStale`, `previewedAt` and `lastResult`. It comes first so the hooks below can invalidate the plan: `clearPlan` drops it, `resetPlan` also clears the stale flag (another project opened), and `markPlanStale` keeps it but asks for a new preview. |
| `useToolSettings` | `toolSettings`: Settings-panel values and saved `projects`. Starts as the bundled defaults, replaced by the saved values once `loadToolConfig` resolves. `saveToolSettings`, `saveNewProject`, `deleteProject`, `editProject`, `recordProjectGeneration`, and `changeSetting` for the Preview card's switches. |
| `useProject` | `projectRoot`, `rememberedFolder` and `configState` (the `.dataverse-gen.json` contents, its path, and whether it exists yet; the selection lives here too). Opening a folder or a saved project, the folder picker for project locations, config edits, and applying the Settings panel's Options. |
| `useEnvironmentMetadata` | `entities`, `operations` and `solutions`, the solution filter (`selectedSolutionId`, `solutionEntityIds`, `solutionComponentIds`, cached per solution in refs), the selected names the environment lacks (`missing`), and the `$metadata` fallback warning. |
| `usePreviewGenerate` | `progress`, Preview and Generate, and whether the two Generate confirmation dialogs are open. |

Two smaller hooks serve the dialogs and the Settings panel: `useSettingsDraft` (the panel's draft, Save and Reset to
defaults) and `useAsyncAction(setError)`, which runs a button's async action (save, open, delete) with a `busy` flag,
clearing the caller's error when it starts and setting it through `reportError` when it fails.

`App.tsx` itself keeps only `error`, `settingsOpen`, `newProjectOpen` and `loadProjectOpen`, plus `steps`
(derived, not state): `computeWorkflowSteps` from the open project, the selection count and the plan, passed to
`WorkflowProgress` and each card.

Two service objects are held with `useMemo` in `App.tsx` and passed to the hooks: a `PptbMetadataProvider`,
recreated with an empty cache whenever the connection changes, and a single `PptbFileSink`.

## Key callbacks

| Callback | Hook | What it does |
| --- | --- | --- |
| `loadProject`, `openProjectFolder` | `useProject` | Load a folder's `.dataverse-gen.json` (or defaults for a new project), then apply the Settings panel's Options (`applyProjectDefaults`). `loadProject` shows errors in the page and backs **Reload config**; `openProjectFolder` does the loading and throws instead. |
| `openSavedProject` | `useProject` | Opens a project (`{ name, location }`) directly with `openProjectFolder`. Only if PPTB refuses access does the folder picker open there for the user to confirm. Once loaded, `notifyProjectLoaded` shows an info notification. |
| `addProject` | `App.tsx` | Saves a project from the New Project dialog (`saveNewProject`), then opens it with `openSavedProject`. |
| `openRecent` | `App.tsx` | Opens a project from the Project card's recent list with `openSavedProject`, showing errors in the page. |
| `updateConfig` | `useProject` | Merges a change into the config and marks the plan stale. `toggle`, `clear` and `clearAll` build on it. |
| `ensureOperations` | `useEnvironmentMetadata` | Loads actions and functions the first time the Actions or Functions tab opens. |
| `changeSolution` | `useEnvironmentMetadata` | Loads the chosen solution's components for the filter. |
| `runPreview` | `usePreviewGenerate` | Builds the write plan. See the data flow on the [Architecture](./index.md#data-flow) page. |
| `runGenerate` | `usePreviewGenerate` | Writes new and changed files, saves the config, marks written files unchanged, then calls `recordProjectGeneration`. |
| `startGenerate` | `usePreviewGenerate` | Opens the right confirmation (Delete orphaned files, or Ask before generating) or runs Generate straight away. |
| `confirmDelete`, `confirmGenerate`, `cancelDelete`, `cancelGenerate` | `usePreviewGenerate` | Close a confirmation, and on Confirm run Generate (with the deletion for `confirmDelete`). `GenerateConfirmationDialogs` in `components/dialogs/GenerateConfirmations.tsx` renders both dialogs and their labels. |
| `recordProjectGeneration` | `useToolSettings` | Updates the saved project for the open folder with `recordGeneration`: a patch version bump and new Modified on when the run added or dropped files. |

The metadata fallback warning shows for 5 seconds (`METADATA_FALLBACK_WARNING_MS` in `useEnvironmentMetadata`) when
the provider starts using it because `$metadata` is too large, then hides itself.

## Errors and notifications

Error handling follows PPTB's [error-handling guide](https://docs.powerplatformtoolbox.com/tool-development/api-reference/error-handling),
through `src/services/errors.ts`:

- **Every failure goes through `reportError(operation, error, context?)`.** It:
  - logs the full error to the console with the operation, a timestamp, the HTTP status and any context
    (folder, project location);
  - shows a persistent PPTB **error notification** titled with the operation;
  - returns the text for the red error bar at the top of the page. Both stay, so the problem is still
    visible after the notification is dismissed.
- **Friendly messages** (`friendlyError`) replace technical details:
  - HTTP statuses and well-known Dataverse codes use the guide's messages, for example 403 "You don't have
    permission to perform this action." and 429 "Too many requests. Please wait a moment and try again.";
  - invalid `.dataverse-gen.json` JSON, folder access and network failures get their own messages;
  - other errors keep their own message without PPTB's "Error invoking remote method" prefix.
- **Dialogs and the Settings panel** show their errors in place, so they call `reportError` with
  `{ notify: false }`: logged and friendly, without a second notification.
- **Retries:** the metadata provider and the solutions service reach Dataverse through `withRetries`. Each call
  is retried up to 3 times, after 500 ms and then 1 s, but only for throttling and temporary unavailability
  (429, 502, 503, 504).
- **Success and info notifications:** "*Project* loaded" (info) after a saved project opens, "Preview ready"
  (info) after a preview, and "Generation complete" (success) after Generate. The Preview card also shows the
  Generate result as a success message. Copying a path shows a short "Copied" notification.
