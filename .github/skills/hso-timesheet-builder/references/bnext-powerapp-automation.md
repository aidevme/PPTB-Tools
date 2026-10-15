# BNext Power App - automation surface

Reconnaissance of the **BNext Power App** as an alternative to driving the F&O timesheet grid
(see [fno-bnext-entry-mechanics.md](fno-bnext-entry-mechanics.md), which remains the fallback).

Investigated 2026-08-11. **Read this before attempting any new automation route** - it records three
routes that are already proven blocked, so they are not re-litigated.

## The app

| | |
|---|---|
| Name | BNext Power App (canvas, phone form factor) |
| Environment | `3b1bd7c7-1eaf-45f1-88e6-54e6eb2b7133` ("HSO GR Bnext PRD") |
| App id | `e874330e-9931-4f30-979f-78efcc0d3924` |
| Play URL | `https://apps.powerapps.com/play/e/<env>/a/<appid>?tenantId=9bc096ab-f225-476e-8e92-260401469868` |
| Tabs | **Planning** / **Timesheet** / **Expenses** (bottom nav) |
| Auth | Silent SSO in the HSO Chrome profile - no sign-in prompt |

Planning shows a week picker (`Week NN`, date range) with entries grouped per weekday, each row
showing project, activity, hours and a location value (e.g. `OffSite`).

## Architecture: the app does NOT call F&O directly

On load the app fires **nine Power Automate flows**, not F&O connector calls:

```
POST https://<env>.environment.api.powerplatform.com/connectors/runtime/invoke
     /scalegroups/europe002/shards/17/apis/logicflows/connections/<connectionId>
     /triggers/manual/run?api-version=2015-02-01-preview
```

Nine distinct `<connectionId>` values, all returning 200. The flows hold the F&O connections and
run with rights the signed-in user does not have - which is why the app works where direct OData
does not.

## Blocked routes (do not retry without new access)

| Route | Blocker |
|---|---|
| **Read the flow request bodies** | The app runs in a **cross-origin iframe** (`runtime-app.powerplatform.com`). A `fetch`/`XHR` interceptor injected in the host document never sees the app's traffic; the extension's network log exposes URL/method/status but **no bodies**; the iframe `src` carries session data and is withheld. |
| **Call the flows directly** | The flows are not shared with the user - Power Automate *Shared with me* reports "You don't have any flows" for this environment. No trigger schema, no run rights. |
| **F&O OData direct** | Authentication succeeds, **authorization fails**. Every timesheet/project/employee entity returns 403. |

### F&O OData 403 detail

Against `https://bnext-prd.operations.dynamics.com/data/`, signed in as the normal user:

| Entity set | Result |
|---|---|
| `Companies` | **200** (proves auth + the technique work) |
| `PSOTimesheets` | 403 - `PSOTSTimesheetEntity` |
| `PSOImportTimesheets` | 403 - `PSOImportTimesheetEntity` |
| `PSOTimesheetPeriods` | 403 - `PSOTSTimesheetPeriodEntity` |
| `TimesheetTables` | 403 - `TSTimesheetTableEntity` |
| `PeriodTimesheetWeeks` | 403 - `ProjPeriodTimesheetWeekEntity` |
| `PSOTimesheetICComments` | 403 - `PSOTSTimesheetICCommentEntity` |
| `TimesheetLineTransTaxInformations` | 403 - `TaxTimesheetLineTransTaxInformationEntity` |
| `Sync360TSTimesheetStagingTable` | 403 - `PSOGVSync360TSTimesheetStagingTableEntity` |
| `ProjectsV2` | 403 - `ProjProjectV2Entity` |
| `EmployeesV2` | 403 |

Error shape: `User is not authorized to read view <Entity>.  Request denied.`

The view names above are exactly what an access request to HSO IT would have to name. Granting
read/write on `PSOTSTimesheetEntity` (plus project/worker lookups) would let this skill go fully
headless - a PowerShell POST per line, no browser at all. That is the real fix; until then the
skill drives a UI.

## Reusable technique: OData through the browser session

No token minting required. From a tab already on the F&O origin, same-origin `fetch` carries the
session cookies:

```js
// Entity list (4740 sets on this env) - navigate to /data/ and parse the XML service document
// Single entity probe:
const r = await fetch('/data/Companies?$top=1&cross-company=false',
                      { credentials: 'include', headers: { Accept: 'application/json' } });
```

Notes:
- `/data/` returns an **XML** `ODataServiceDocument` (not JSON) - parse `<Name>` elements.
- Do **not** load the F&O SPA root first; it wedges the renderer and script injection times out.
  Navigate straight to a `/data/...` URL, which renders as a lightweight document.
- `$metadata` is far too large to fetch whole - probe one entity with `$top=1` and read the keys.

## Browser-automation gotchas (this app)

- **Cross-origin iframe** - `read_page` / `find` return nothing for the app (the accessibility tree
  does not cross the frame), and JavaScript cannot be injected into it. **Screenshots plus
  coordinate clicks are the only handles.**
- **Page zoom silently breaks coordinates.** On a 2560x1392 window with Windows scaling 1.5 and
  Chrome page zoom ~170%, the CSS viewport collapses to **1008x525** - the app's bottom nav is
  clipped and clicks land in the wrong place with no error. Check first:

  ```js
  JSON.stringify({ innerW: innerWidth, innerH: innerHeight, dpr: devicePixelRatio })
  ```

  Expect roughly 1700x900 at 100% zoom. **The agent cannot fix this**: `ctrl+0` is refused ("page
  zoom keyboard shortcuts are not supported"), and setting CSS `zoom` on the host document makes it
  worse - the iframe keeps a fixed pixel height, so the app shrinks to a strip instead of gaining
  space. **Ask the human to set the window to 100% zoom.**
- **Silent failure mode**: a click that misses simply does nothing - no error, no visual change.
  Probe with a harmless control (the next-week `>` arrow) and confirm the week number changes
  before trusting any coordinate.
- **`Page.captureScreenshot` times out often** on this app (30s CDP timeout). Retry the screenshot
  standalone rather than inside a batch, so the batch does not abort.
- **The extension drops its browser selection mid-session.** Re-select "Hso Work"; note this
  **recreates the tab group and invalidates every tabId** - call `tabs_context_mcp` again.

## Status

Entry mechanics for the Timesheet tab are **not yet mapped** - blocked on the page-zoom issue
above. Until they are, entry follows [fno-bnext-entry-mechanics.md](fno-bnext-entry-mechanics.md).
