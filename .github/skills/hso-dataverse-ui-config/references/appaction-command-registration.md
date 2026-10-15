# Modern Command-Bar Buttons via Web API (`appaction`) — Registration Reference

Modern commands (command-bar buttons) are stored as `appaction` rows and are **fully creatable
over the Web API** — no RibbonDiffXml, no command-bar designer session, no `pac` CLI. One
`POST /api/data/v9.2/appactions` per button, then publish. Proven shapes: **Form (location=0)**
and **Main Grid (location=1)**, including JavaScript handlers, icons, and selection-gated
Power Fx visibility. Sub Grid (location=2) is NOT yet proven — see [Open items](#open-items).

Established empirically (live-environment spike, 2026-06; 13 buttons across form and main-grid
surfaces). Evidence sources: live system `appaction` rows (`msdyn_Mscrm.*`), designer
round-trips (the [designer-oracle method](#onclick-javascript-parameters)), the
[appaction table reference (Microsoft Learn)](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/entities/appaction)
(columns + option sets; the parameters JSON format is NOT documented there), and the
[CoE Starter Kit](https://github.com/microsoft/coe-starter-kit) packaged appaction XML.

---

## The recipe

1. Resolve the binding targets (all read-only lookups):
   - the **`entities` metadata-catalog row** for the target table — `GET entities?$filter=logicalname eq '<entity>'` (NOT `EntityDefinitions`)
   - the **web resource** carrying the handler — `GET webresourceset?$filter=name eq '<path>.js'`
   - the **app module** — `GET appmodules?$filter=uniquename eq '<app>'`
2. `POST appactions` with the column set below. **Always pass the solution** so the row travels
   with it (`MSCRM.SolutionUniqueName` — with the shared invoker use `-SolutionName`, never a
   custom `-Headers` hashtable: `-Headers` REPLACES the default auth headers → instant 401).
3. Publish **both** targets (commands do not surface until published):

```text
POST PublishXml  { ParameterXml = "<importexportxml><entities><entity>ENTITY_LOGICAL_NAME</entity></entities></importexportxml>" }
POST PublishXml  { ParameterXml = "<importexportxml><appmodules><appmodule>APPMODULE_GUID</appmodule></appmodules></importexportxml>" }
```

The entity node takes the **logical name**; the appmodule node needs the **GUID** (uniquename
fails with "An unexpected error occurred").

4. **Eyeball the app** (hard refresh, Ctrl+F5; command caching is aggressive and can lag
   minutes). The Maker Portal showing the row proves nothing about the app.

## Column set

| Column | Value | Notes |
|---|---|---|
| `name` | NO pipes, NO spaces. Dotted (`HSO.Command.CommitThing`) and bang-guid (`Approve!<guid32>`) both render | **THE render-blocker** — see [Pitfalls](#pitfalls) |
| `uniquename` | Form buttons: `hso_<entity>_<verb>`. Designer pattern (grid): `hso__<Slug>!<guid32>!<app>!<entity>!<location>` | SystemRequired; both forms proven |
| `buttonlabeltext` | User-visible label | Plus `buttontooltiptitle`, `buttontooltipdescription`, `buttonaccessibilitytext` |
| `context` | `1` (Entity); `0` = All | |
| `contextvalue` | Entity **logical name** string | **Required in practice** — without it the create dies with `Value cannot be null. Parameter name: entityName`, even with the lookup bound |
| `ContextEntity@odata.bind` | `/entities(<entityid>)` | The metadata-catalog row, NOT EntityDefinitions |
| `location` | `0`=Form, `1`=Main Grid, `2`=Sub Grid (UNPROVEN), `3`=Associated Grid, `4`=Quick Form, `5`=Global Header, `6`=Dashboard | ApplicationRequired |
| `origin` | `0` (Default) | ApplicationRequired |
| `type` | `0` Standard Button; `1` Dropdown, `2` Split, `3` Group | ApplicationRequired |
| `sequence` | Ordering (float). Designer default region ~`1000100050`; space siblings by 10 | `buttonsequencepriority` is deprecated — ignore it |
| `onclickeventtype` | `2` = JavaScript; `1` = Power Fx formula | |
| `OnClickEventJavaScriptWebResourceId@odata.bind` | `/webresourceset(<webresourceid>)` | |
| `onclickeventjavascriptfunctionname` | Fully qualified, e.g. `HSO.Entity.Ribbon.commitThing` | |
| `onclickeventjavascriptparameters` | Enum-int JSON — see [Parameters](#onclick-javascript-parameters) | Server-validated; wrong shape fails the create |
| `fonticon` | `$clientsvg:<Name>` or a bare system icon name — see [Icons](#icons) | Unknown names are accepted by the create but suspect render-killers — only ship enumerated tokens, or omit |
| `visibilitytype` | `0` always, `1` Power Fx formula, `2` Classic Rules (unexplored) | See [Visibility](#selection-gated-visibility-power-fx) |
| `AppModuleId@odata.bind` | `/appmodules(<appmoduleid>)` | Scopes to one app; omit for all apps (untested) |

## OnClick JavaScript parameters

`onclickeventjavascriptparameters` is a JSON array deserialized server-side into
`FunctionParameter[]`: `[{"type":<int>,"value":<literal-or-null>}]`. The enum is undocumented;
established values:

| Int | Parameter | Evidence |
|---|---|---|
| 4 | FirstPrimaryItemId | Designer round-trip (community claims 4 = PrimaryControl are WRONG) |
| **5** | **PrimaryControl** (formContext) — the form-button parameter | Designer-written read-back |
| **12** | **SelectedControl** (grid control) — the grid-button parameter | System rows + designer-built main-grid button |
| 24 | SelectedControlSelectedItemReferences | System grid commands; CoE starter kit |
| 21 | String literal (`value` carries the string) | CoE starter kit + system rows |
| 19 | Integer literal | CoE starter kit |

- Form button → `[{"type":5}]`, handler signature `function (primaryControl)`.
- Main-grid button → `[{"type":12}]`, handler signature `function (selectedControl, firstSelectedItemId)`.
  Modern commanding may pass the second argument as `undefined` — the handler must fall back to
  `selectedControl.getGrid().getSelectedRows().get(0).getData().getEntity().getId()`.
- To identify further enum values: set the parameter in the command-bar designer once,
  Save & Publish, and `GET` the row's `onclickeventjavascriptparameters` back — **the designer
  is the oracle** for every undocumented encoding on this table.

## Icons

`fonticon` accepts **two namespaces**, both observed on rendering system and custom rows:

- `$clientsvg:` tokens: Accept, Add, Archive, Blocked, Calendar, CreateMajor, CreateMinor,
  Delete, Edit, EditMail, FollowUser, ImportToExcel, MailLink, MergeCase, OpenEnrollment, Org,
  PageBlock, PageCompleted, Phone, Pin, Refresh, RelatedKnowledgeArticle, RevertToDraft,
  RoutingRule, Save, SaveAndClose, Share, TranslationNew, UpdateRestore
- Bare system names: AddTerritoryMember, BackButton, Cancel, Close, Connection, DeleteBulk,
  EditDefaultFilter, FormDesign, NewMeeting, No, OpenDelve, OpenEmail, OpenRecord,
  PublishKnowledgeArticle, QueueItemRelease, QueueItemRemove, Report, Resolve, RestoreArticle,
  SendAndClose, SendSelected, SetRegarding, SharePoint* (document commands), TableGroup,
  ViewHierarchy, Yes

Unknown names (e.g. `CheckmarkCircle`) pass the create but never render an icon and are suspect
in render failures. Omitting `fonticon` entirely is always safe (label-only button). To grow the
list: enumerate live rows — `GET appactions?$filter=fonticon ne null&$select=fonticon`.

## Selection-gated visibility (Power Fx)

`visibilitytype=1` binds the button to a Power Fx formula compiled into a per-app **component
library** (`canvasapp`). The library itself can only be compiled by the command-bar designer,
but once it exists the binding is four plain Web-API columns — so the manual cost is **one
designer pass per entity-grid surface, not per button**:

1. **Bootstrap (designer, once per app + entity + location):** build ONE button in the designer
   with the visibility formula — e.g. `!IsEmpty(Self.Selected.AllItems)` (show when ≥1 row
   selected; use `CountRows(Self.Selected.AllItems) = 1` for exactly-one). Save & Publish until
   it behaves in the app.
2. **Read the oracle row back** and capture: `_visibilityformulacomponentlibraryid_value`,
   `visibilityformulacomponentname` (a guid32 string), `visibilityformulafunctionname`
   (typically `Visible`).
3. **Bind siblings over the Web API:**

```json
{
  "visibilitytype": 1,
  "VisibilityFormulaComponentLibraryId@odata.bind": "/canvasapps(<library-guid>)",
  "visibilityformulacomponentname": "<component-guid32>",
  "visibilityformulafunctionname": "Visible"
}
```

Sibling buttons on the same surface can share the designer's component when they want the SAME
formula (`Self` resolves per host command at runtime). Sharing across DIFFERENT formulas needs a
separate designer-compiled component per formula. Classic Rules (`visibilitytype=2`,
`appactionrule` rows) remain unexplored.

Note the classic-model contrast: classic RibbonDiffXml can only *disable* on selection
(`SelectionCountRule` is an EnableRule; there is no selection-based DisplayRule), so
"hide until selected" requires the modern Power Fx visibility even when the action handler
stays JavaScript.

## Pitfalls

1. **A bad row poisons its entity's whole custom command set.** One invalid appaction (pipes in
   `name`, or a malformed location-2 row) suppresses ALL custom commands on that entity — with
   no error anywhere, and even designer-built rows stop rendering. **Deactivating does NOT
   clear it; only DELETE + publish does.** When buttons mysteriously don't render: delete every
   suspect appaction on the entity, publish, retest.
2. `name` with pipes or spaces = silent render failure (the poisoning case above).
3. `-Headers` on the shared `Invoke-DataverseApi` replaces the auth headers (401) — use
   `-SolutionName` for the solution header.
4. Command caching is aggressive: Publish → wait ~1 min → Ctrl+F5 before concluding anything.
5. The render check is a HUMAN step: Maker Portal visibility proves nothing about the app.
6. Grid handlers must tolerate `FirstSelectedItemId === undefined` (fallback to the grid
   selection API) — see [Parameters](#onclick-javascript-parameters).

## Registration checklist

- [ ] Handler function exists in the DEPLOYED web resource (deploy + publish the JS first)
- [ ] `name` has no pipes/spaces; `uniquename` unique
- [ ] `contextvalue` set AND `ContextEntity@odata.bind` bound
- [ ] Parameters JSON matches the location (5 = form, 12 = grid)
- [ ] `fonticon` from the enumerated lists, or omitted
- [ ] Visibility columns bound (or `visibilitytype=0` with a server-side guard on the action)
- [ ] Created with the solution header (`-SolutionName`)
- [ ] Published: entity (logical name) + app module (GUID)
- [ ] Idempotency: check-before-create on `uniquename`/slug
- [ ] Human render + behavior check in the app after cache settles

## Open items

- **Sub Grid (`location=2`)**: the form recipe did not transfer; bad rows poisoned their entity
  (pitfall 1). Resolve via the designer-oracle method before shipping subgrid buttons.
- `AppModuleId` omitted (= all apps): untested.
- `visibilitytype=2` Classic Rules (`appactionrule` + `appaction_appactionrule_classicrules`): untested.
- Programmatic compilation of the visibility component library: no Web-API path found.
