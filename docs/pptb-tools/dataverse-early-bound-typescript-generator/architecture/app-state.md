# App state and hooks

`src/App.tsx` owns all of the tool's state and orchestration; there's no state management library. The
[components](../components/) are presentational and receive everything as props.

## State in `App.tsx`

| State | Purpose |
| --- | --- |
| `projectRoot`, `rememberedFolder` | The open project folder, and the one last used with this connection. |
| `configState` | The `.dataverse-gen.json` contents, its path, and whether it exists yet. The selection lives here too. |
| `entities`, `operations`, `solutions` | Lists loaded from the environment. `operations` stays `null` until the `$metadata` document is loaded. |
| `selectedSolutionId`, `solutionEntityIds`, `solutionComponentIds` | The solution filter and the ids in that solution. Results are cached per solution in refs. |
| `plan`, `planStale` | The last preview, and whether the selection or options changed since. |
| `progress`, `error`, `notice` | The progress bar and the error and success message bars. |
| `settingsOpen` | Whether the [SettingsPanel](../components/settings-panel.md) drawer is open. |

Two service objects are held with `useMemo`: a `PptbMetadataProvider`, recreated with an empty cache whenever
the connection changes, and a single `PptbFileSink`.

## Key callbacks

| Callback | What it does |
| --- | --- |
| `browse`, `loadProject` | Pick a folder, then load its `.dataverse-gen.json` (or defaults for a new project). |
| `updateConfig` | Merges a change into the config and marks the plan stale. `toggle`, `clear` and `clearAll` build on it. |
| `ensureOperations` | Loads actions and functions the first time the Actions or Functions tab opens. |
| `changeSolution` | Loads the chosen solution's components for the filter. |
| `runPreview` | Builds the write plan. See the data flow on the [Architecture](./index.md#data-flow) page. |
| `runGenerate` | Writes new and changed files, saves the config, and marks written files unchanged. |
| `regenerate` | `runPreview`, then `runGenerate`. |

## Hooks

`src/hooks/` has one hook:

- **`useConnection`** reads the active PPTB connection on mount and again whenever PPTB raises
  `connection:created`, `connection:updated` or `connection:deleted`. Outside PPTB (for example under
  `npm run dev`) it resolves to `null`. It returns `{ connection, isLoading, refreshConnection }`.

## Errors and notifications

- Failures are shown in an error message bar at the top of the page (`error` state).
- When files are written, the summary appears in a success message bar and as a PPTB notification.
- Copying a path shows a short "Copied" notification.
