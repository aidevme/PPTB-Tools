# App state and hooks

`src/components/apps/App.tsx` owns all of the tool's state and orchestration; there's no state management library. The
[components](../components/) are presentational and receive everything as props.

## State in `App.tsx`

| State | Purpose |
| --- | --- |
| `projectRoot`, `rememberedFolder` | The open project folder, and the one last used with this connection. |
| `configState` | The `.dataverse-gen.json` contents, its path, and whether it exists yet. The selection lives here too. |
| `entities`, `operations`, `solutions` | Lists loaded from the environment. `operations` stays `null` until the `$metadata` document is loaded. |
| `selectedSolutionId`, `solutionEntityIds`, `solutionComponentIds` | The solution filter and the ids in that solution. Results are cached per solution in refs. |
| `plan`, `planStale` | The last preview, and whether the selection or options changed since. |
| `previewedAt`, `lastResult` | When the plan was computed, and the summary of the last Generate run, for the Preview card. Set by `runPreview` and `runGenerate`. |
| `progress`, `error`, `notice` | The progress bar and the error and success message bars. |
| `steps` (derived, not state) | `computeWorkflowSteps` from the open project, the selection count and the plan; passed to `WorkflowProgress` and each card. |
| `settingsOpen` | Whether the [SettingsPanel](../components/settings-panel.md) drawer is open. |
| `toolSettings` | Tool config: Settings-panel values and saved `projects`. Starts as the bundled defaults, replaced by the saved values once `loadToolConfig` resolves on load. `saveToolSettings` and `addProject` save and update it. |
| `newProjectOpen` | Whether the [NewProjectDialog](../components/new-project-dialog.md) is open. |
| `loadProjectOpen` | Whether the [LoadProjectDialog](../components/load-project-dialog.md) is open. |
| `metadataFallback`, `showMetadataFallbackWarning` | The provider is using the metadata fallback because `$metadata` is too large. When it starts, a warning shows for 5 seconds (`METADATA_FALLBACK_WARNING_MS`) and then hides itself. |

Two service objects are held with `useMemo`: a `PptbMetadataProvider`, recreated with an empty cache whenever
the connection changes, and a single `PptbFileSink`.

## Key callbacks

| Callback | What it does |
| --- | --- |
| `loadProject`, `openProjectFolder` | Load a folder's `.dataverse-gen.json` (or defaults for a new project), then apply the Settings panel's Options (`applyProjectDefaults`). `loadProject` shows errors in the page and backs **Reload config**; `openProjectFolder` does the loading and throws instead. |
| `openSavedProject` | Opens a project (`{ name, location }`) directly with `openProjectFolder`. Only if PPTB refuses access does the folder picker open there for the user to confirm. Once loaded, `notifyProjectLoaded` shows an info notification. |
| `openRecent` | Opens a project from the Project card's recent list with `openSavedProject`, showing errors in the page. |
| `updateConfig` | Merges a change into the config and marks the plan stale. `toggle`, `clear` and `clearAll` build on it. |
| `ensureOperations` | Loads actions and functions the first time the Actions or Functions tab opens. |
| `changeSolution` | Loads the chosen solution's components for the filter. |
| `runPreview` | Builds the write plan. See the data flow on the [Architecture](./index.md#data-flow) page. |
| `runGenerate` | Writes new and changed files, saves the config, marks written files unchanged, then calls `recordProjectGeneration`. |
| `recordProjectGeneration` | Updates the saved project for the open folder with `recordGeneration`: a patch version bump and new Modified On when the run added or dropped files. |

## Hooks

`src/hooks/` has one hook:

- **`useConnection`** reads the active PPTB connection on mount and again whenever PPTB raises
  `connection:created`, `connection:updated` or `connection:deleted`. Outside PPTB (for example under
  `npm run dev`) it resolves to `null`. It returns `{ connection, isLoading, refreshConnection }`.

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
