# Check recipes — env queries per check family

Authority for executing the skill's Phases 1–5 — read before executing checks. Every recipe routes through the sanctioned read paths:

- **Record/metadata-row queries:** `hso-dataverse-data`'s script, invoked **in-process**:
  ```powershell
  $dataOp = ".claude/skills/hso-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1"   # or shared/dv/claude-code/skills/... in repos without a project copy
  & $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "..." -Select "..." -Filter "..." -Raw
  ```
- **EntityDefinitions / $metadata paths** (not entity sets): dot-source the shared modules and call `Invoke-DataverseApi` directly:
  ```powershell
  . ".claude/skills/hso-shared-scripts/scripts/Dataverse-Auth.ps1"
  . ".claude/skills/hso-shared-scripts/scripts/Dataverse-WebApi.ps1"
  ```

Invocation hazards (cost real rework in the field — non-negotiable):

- ALWAYS the `&` call operator, NEVER `powershell -File` (hangs, flattens array params, stringifies booleans).
- Retry transient `429` / `CustomizationLock` / publish-collision errors with backoff; honor `Retry-After`.
- Never regex-match success text (ANSI codes corrupt it) — judge by parsed JSON.
- Never hand-guess option-set values, EntitySetNames, or privilege-name casing — read them from the env. Watch pluralization surprises (`…batchs`, not `…batches`).
- Timestamp every captured response (`[DateTime]::UtcNow.ToString('o')`) — concurrent lanes may be changing the env.

All examples below use `$envUrl` (from CLAUDE.md) and `$app` (the `AppUniqueName` input). `<prefix>` is the publisher prefix from CLAUDE.md.

## Execution pattern — snapshot first, analyze offline (MANDATORY)

Per-query script invocations are slow (each pays module import + auth resolution) and large XML responses (formxml, sitemapxml, fetchxml results) drown your working context. Do NOT run Phase 1 as dozens of single-query calls. Instead:

1. **One batch script for the whole Phase 1 inventory.** Write `OutputDir/evidence/capture-inventory.ps1` that dot-sources the shared modules ONCE, runs every inventory query in-process, and writes each response to `OutputDir/evidence/<name>.json` (use the data script's `-OutputFile`, or pipe to file). Run it once, in the foreground.
2. **Analyze from the snapshot files**, loading only the fragments you need (e.g. pull one dashboard's formxml, not all of them at once).
3. **Targeted live queries only for Phases 4–5 data probes and for re-verification** — findings must be re-verified against the live env, never against a snapshot.
4. **Write working state as you go** — keep a running `OutputDir/evidence/worklog.md` (checks done, results, timestamps) so an interrupted run can resume from evidence instead of restarting. Like every `.md` under a wiki-linted `agent/` tree, the worklog MUST start with the project's standard frontmatter block (title/type/status/scope/created/updated …) or it fails `hso-wiki-lint`.

The snapshot files double as the report's evidence trail; cite them by filename + capture timestamp.

---

## Phase 1 — Env inventory

**App + components:**
```powershell
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "appmodules" `
  -Select "appmoduleid,appmoduleidunique,uniquename,name" -Filter "uniquename eq '$app'" -Raw
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "appmodulecomponents" `
  -Select "objectid,componenttype" -Filter "_appmoduleidunique_value eq $appUniqueId" -AllPages -Raw
```
`componenttype`: 1 = Entity · 26 = View (savedquery) · 29 = Process · 59 = Chart · 60 = Form/Dashboard (systemform) · 62 = Sitemap. Verify labels with `-IncludeAnnotations` rather than trusting this list.

**Sitemap XML:** the component row with `componenttype eq 62` gives `objectid` = `sitemapid`:
```powershell
& $dataOp -Operation Get -EnvironmentUrl $envUrl -EntitySetName "sitemaps" -RecordId $sitemapId `
  -Select "sitemapname,sitemapxml" -Raw
```
Parse `sitemapxml` as XML. Each `<SubArea>` carries `Entity="…"`, `Url="…"`, and/or `DefaultDashboard="…"` (classic-XML vocabulary; the XSD rejects app-designer terms like `Type="Dashboard"`). Collect: all entity subareas, all URL/dashboard-hub subareas.

**Views / charts / dashboards / forms:**
```powershell
# Public views for an entity (querytype 0); statecode 0 = active
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "savedqueries" `
  -Select "savedqueryid,name,fetchxml,layoutxml,querytype,statecode,isdefault" `
  -Filter "returnedtypecode eq '<entity_logical_name>' and querytype eq 0" -Raw
# System charts
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "savedqueryvisualizations" `
  -Select "savedqueryvisualizationid,name,primaryentitytypecode,datadescription,presentationdescription" -AllPages -Raw
# Dashboards (type 0) and main forms (type 2); type: 0 Dashboard · 2 Main · 6 Quick View · 7 Quick Create · 11 Card
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "systemforms" `
  -Select "formid,name,type,objecttypecode,formxml,formactivationstate" -Filter "type eq 0" -AllPages -Raw
```

**Custom APIs, commands, web resources, flows:**
```powershell
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "customapis" `
  -Select "customapiid,uniquename,name,bindingtype,boundentitylogicalname,isfunction" -AllPages -Raw
# Modern commands — column availability varies by platform version: query without $select first, then narrow
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "appactions" -Top 500 -Raw
# Classic ribbon customizations (presence of entity-scoped rows = classic buttons exist for that entity)
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "ribboncustomizations" `
  -Select "ribboncustomizationid,entity" -Filter "entity ne null" -AllPages -Raw
# Deployed JS web resources for the publisher (webresourcetype 3 = JScript)
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "webresourceset" `
  -Select "webresourceid,name,webresourcetype,modifiedon" -Filter "startswith(name,'<prefix>_') and webresourcetype eq 3" -AllPages -Raw
# Flows: category 5 = modern cloud flow (0 classic workflow, 4 BPF); statecode 1 = activated
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "workflows" `
  -Select "workflowid,name,category,statecode,primaryentity" -Filter "category eq 5" -AllPages -Raw
```

**Option-set truth (never hand-guess values):**
```powershell
$resp = Invoke-DataverseApi -EnvironmentUrl $envUrl -Method GET -Path "EntityDefinitions(LogicalName='<entity>')/Attributes(LogicalName='<attr>')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$expand=OptionSet"
```
(Status reasons: same pattern with `StatusAttributeMetadata`.)

**Shared-invoker contract:** `Invoke-DataverseApi` takes `-Endpoint` (not `-Path`) and requires `-Token` — acquire once with `Get-DataverseToken -EnvironmentUrl $envUrl` and reuse.

**EntityDefinitions gotchas:**
- Type-specific properties need the type cast: `$select=MaxLength` 400s on base `AttributeMetadata` — use `…/Attributes/Microsoft.Dynamics.CRM.StringAttributeMetadata?$select=LogicalName,MaxLength` (same idea for Money/Decimal min-max).
- `contains()` is NOT supported in `$filter` on metadata entities — fetch the attribute list and filter client-side.

**Other field-proven gotchas:**
- Role privileges expand: `roles(…)?$expand=roleprivileges_association` — `roleprivileges` is not a valid navigation segment.
- `appaction` column names vary by platform version (`visibilityruleset` vs `visibilitytype`; an `entitylogicalname` $filter may 400) — query without `$select`/`$filter` into the snapshot and filter offline.
- formxml subgrid inspection: parse with string regex on the raw XML, not XPath — `[xml]`-parsed formxml from a JSON response misses `<subgrid>`/classid nodes in practice.

## Phase 2 — Family A: Surfacing

### A-0 — App-membership sweep (table-level, before the claim walks)

The declared table set is `spec.json` `newTables[]` ∪ `app.areas[].groups[].subAreas[].entity` ∪ `app.unsurfacedTables[].table`. Diff it against the app's entity components — **not** against the sitemap (a subarea can point at a table the app does not contain, which is exactly round-3 F-02):

```powershell
$spec = Get-Content -Raw $specJsonPath | ConvertFrom-Json
$declared = @($spec.newTables) + @($spec.app.areas | % { $_.groups } | % { $_.subAreas } | % { $_.entity }) + @($spec.app.unsurfacedTables | % { $_.table }) |
            ? { $_ } | % { "$_".ToLower() } | Select-Object -Unique
# Resolve appmoduleidunique from the PUBLISHED generation (plain appmodules GET). It is PER GENERATION: the
# unpublished draft (RetrieveUnpublishedMultiple) carries a different value and can contain tables the published
# app does not (round-3 remediation: hso_contract restored in the draft, never published). Judge the published app;
# report a diverging draft as "saved, not published" evidence.
$pubApp = & $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "appmodules" -Select "appmoduleid,appmoduleidunique" -Filter "uniquename eq '$app'" -Raw
$appUniqueId = $pubApp.value[0].appmoduleidunique
# app entity components (componenttype 1); objectid = the entity table's entityid, NOT MetadataId
$comps = & $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "appmodulecomponents" `
  -Select "objectid" -Filter "_appmoduleidunique_value eq $appUniqueId and componenttype eq 1" -AllPages -Raw
$compIds = @($comps.value | % { "$($_.objectid)".ToLower() })
$absent = foreach ($t in $declared) {
  $e = & $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "entities" -Select "entityid" -Filter "logicalname eq '$t'" -Raw
  if (-not $e.value -or $compIds -notcontains "$($e.value[0].entityid)".ToLower()) { $t }
}
# ValidateApp (bound function on the app module) — issues are findings too
$va = Invoke-DataverseApi -EnvironmentUrl $envUrl -Method GET -Endpoint "appmodules($appModuleId)/Microsoft.Dynamics.CRM.ValidateApp()" -Token $tok
```

`$absent` non-empty ⇒ one **S1 family-A finding** (owner `build-gap`, routed to the app/sitemap assembly slice) listing every absent table; `ValidationIssueList` non-empty ⇒ append the issues. Pass evidence: "A-0: N declared tables, N in app components, ValidateApp clean" with the timestamp. This sweep runs **whether or not any FR claim names the table**.

For every user-visible artifact in the claim register, assert a reachable path **inside the app**:

| Artifact | Reachable means | Evidence to capture |
|---|---|---|
| Entity + its views | Entity subarea in the app sitemap AND entity in app components AND the view active (`statecode eq 0`) and in app components — OR the app has ZERO view components (type 26) for that entity, which means the view set is unrestricted and every active public view is reachable (an explicit PASS condition, not an ambiguity; same rule for charts/type 59) | sitemap SubArea node + component rows |
| Dashboard | In app components AND reachable via a dashboard-hub subarea (`Url` + `DefaultDashboard`) or the app's Dashboards area | component row + sitemap node + `formactivationstate eq 1` |
| Form / form tab / subgrid | Form active, in app components; tab `visible != false` in `formxml`; subgrid cell present with the right `RelationshipName`/`ViewId` | formxml excerpt |
| Chart | Bound to its entity (`primaryentitytypecode`) and present where the claim says (dashboard cell / entity charts) | chart row + dashboard formxml cell |
| "Deliberately unsurfaced" | The spec records the decision + rationale | spec quote → Accepted boundaries, NOT a finding |

Dashboard composition: parse the dashboard's `formxml` — each `<cell>` declares its control with the chart/view ids. Cross-check every component the spec's dashboard table declares.

**Subgrid relationship checks:** confirm the relationship the subgrid binds actually exists via
`Invoke-DataverseApi … -Path "EntityDefinitions(LogicalName='<entity>')/OneToManyRelationships?`$select=SchemaName,ReferencingEntity"`.

## Phase 3 — Family B: Command surface

For each **user-invocable** operation (Custom API the brief's persona triggers, not flow/admin-only APIs):

1. **Button exists:** an `appaction` row targeting the entity/grid/form location the persona uses, OR a classic ribbon customization for that entity. Capture the row.
2. **Script exists and is deployed:** the command's web resource is in `webresourceset` (not just in source control). Retrieve its `content` (base64) if needed and confirm the named function exists and calls the API (`Xrm.WebApi.online.execute` / fetch of the API unique name).
3. **Wiring:** for form-launched commands, parse `formxml` `<formLibraries><Library name=…>` + `<Handler functionName=…>` and confirm the library/handler pair is on the form the persona opens.
4. **Visibility:** the button's enable/display rules don't hide it from the persona's context (e.g. bound to a state the records never reach).

A server-side runtime invoker (flow, scheduled job, admin script) does **not** satisfy a user-facing operation — that is exactly the gap class this family exists to catch.

## Phase 4 — Family C: Demo/data semantics

For every view: run its own definition, not a re-derivation. Multi-element FetchXML mangles on a command line — execute probes via `Invoke-DataverseApi` with the XML URL-encoded into the query string (the proven path):
```powershell
$enc = [System.Web.HttpUtility]::UrlEncode($savedQueryFetchXml)   # Add-Type -AssemblyName System.Web first
$r = Invoke-DataverseApi -EnvironmentUrl $envUrl -Method GET -Endpoint "<entityset>?fetchXml=$enc" -Token $tok
```
Note `Invoke-DataverseApi`'s parameter is **`-Endpoint`** (not `-Path`), and it needs a token: `$tok = Get-DataverseToken -EnvironmentUrl $envUrl` once, passed to every call.

**Measure audit (MANDATORY, per chart — never skip):** parse each chart's `datadescription` (`<attribute aggregate=…>` = measure; `<attribute groupby=…>` = grouping) and build this table for EVERY chart in the claim register; include it in the report's pass evidence:

| Chart | Groupby field(s) | Measures (field + aggregate) | Quantity the claim promises (verbatim FR/spec quote) | Verdict |
|---|---|---|---|---|

A chart whose claim names a money/amount/dollar/total quantity but whose measures contain **no money-field aggregate** (e.g. only `count` of the id) is a **count-only finding** — even when its group count looks healthy. A count measure passes only where the claim itself promises counts. Group-count degeneracy checks do NOT substitute for this measure-vs-promise diff.

Then run an aggregate FetchXML reproducing each chart's dataset for the degeneracy tests below.

Judge **meaningfulness against the claim**, not well-formedness:

| Degenerate pattern | Test | Verdict |
|---|---|---|
| Empty dataset | row count = 0 | finding (data-gap) — the artifact can't tell its story |
| Flat "distribution" | distinct groupby values = 1 | finding — a chart of one bar demos nothing |
| Count-only measures where the FR promises amounts/dollars | every `<measure>` aggregates `count` while the claim names a money quantity | finding — semantics, not formatting |
| Trend shorter than promised | distinct period (e.g. FY) groups < promised span | finding — "5-year trend" with 2 years is a broken promise even if the chart renders |
| All-identical values | aggregate min = max across groups | finding (suspect seed data) |
| Filter that excludes everything | dataset nonempty unfiltered but empty under the view's own filter | finding — check the filter against real status/option values from the env |

Distinct-count probe pattern:
```xml
<fetch aggregate='true'><entity name='<entity>'>
  <attribute name='<groupattr>' alias='g' groupby='true'/>
  <attribute name='<idattr>' alias='n' aggregate='count'/>
</entity></fetch>
```

## Phase 5 — Family D: Persona scenario walks

For each FR, as its persona, walk and record each step:

1. **Navigate:** which sitemap area/subarea gets me to the starting artifact? (Family A evidence reused.)
2. **See:** does the landing view/form/dashboard show the fields the scenario needs (layoutxml/formxml columns vs the FR's nouns)?
3. **Act:** what does the persona click to perform the FR's verb? (Family B evidence; for record creation/edit: required fields obtainable, lookups resolvable.)
4. **Outcome:** what tells the persona it worked — a state change visible on a view/form column, a row appearing in a named list, a notification record?
5. **Failure path:** when the system refuses (guard plugin, validation), is the refusal **visible to the persona** (synchronous plugin error message, form notification, status column)? An async-rejection with no surfaced message is a finding even when the server behaves correctly.
6. **Scope:** for row-scope claims (regional user sees only their region): in `ReadOnly` mode verify the *mechanism* read-only — role privilege depths (via `hso-dataverse-securityrole` query operations), BU placement, view filters — and check whether a scoped **test user/role assignment exists at all**. If no scoped principal exists to test with, that is itself a finding (the scope claim is unverifiable → manual-followup or build-gap). Never create or modify security config.

`WriteProbes` mode only (explicit opt-in): actually invoke the operation as the scenario demands — then **create → assert → delete → read back the absence** (org audit may be live; leave nothing). Bound APIs: `POST <entityset>(<id>)/Microsoft.Dynamics.CRM.<UniqueName>`; unbound: `-Operation Action -ActionName <UniqueName>` on the data script.

### D-gates — three mutation paths per status / completion gate

For every gate the spec/brief states (a transition that requires prerequisites; columns that lock after a status), enumerate the three paths and record a verdict per path:

| Path | `WriteProbes` probe | `ReadOnly` trace (what must be true for the path to be closed) |
|---|---|---|
| 1 Create with non-default / terminal status | `POST` the record with `statuscode = <terminal>` and the prerequisites absent → expect refusal; delete on success | A plugin step on **`Create`** (`sdkmessageprocessingsteps` where `sdkmessageid/name eq 'Create'`, stage 20 PreOperation or 10 PreValidation, synchronous) for the table, **or** a business rule / Custom API path the form forces — an `Update`-only registration is open on this path |
| 2 Update transition | `PATCH statuscode` from default to terminal with prerequisites absent → expect refusal | A synchronous pre-op step on **`Update`** whose **filtering attributes** (`filteringattributes`) include `statuscode` |
| 3 Post-transition mutation of gated columns | On a record already terminal: `PATCH` a gated column to null / delete a required child → expect refusal | The `Update` step's filtering attributes include **every gated column** (not only `statuscode`), and a `Delete` step (or `Restrict` cascade) guards required children |

```powershell
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "sdkmessageprocessingsteps" `
  -Select "name,stage,mode,filteringattributes,statecode,_sdkmessageid_value,_plugintypeid_value" `
  -Filter "statecode eq 0" -AllPages -Raw    # then filter offline to the table's messages: Create / Update / Delete
```

Any path open ⇒ **S2 family-D finding** (`build-gap` when the spec's acceptance named that path; `spec-gap` when the acceptance omitted it — cite the acceptance verbatim). Pass evidence lists all three paths per gate.

## Phase 6 — Family E: Acceptance-gap analysis

Pure document-vs-evidence work, grounded in the claim register:

1. **Unverified promises:** claim register rows where `acceptance line = NONE`. Quote the FR text.
2. **Unwalkable acceptance:** lines whose execution presupposes artifacts that never existed (a regional test user, a seeded dataset, a second FY of history). Verify the presupposition in the env — if absent NOW, the line was never truly walked. Quote the acceptance line verbatim.
3. **Existence-vs-behavior:** lines that assert "X exists with columns Y" where the FR promises "persona does Z" — the behavior was never the acceptance target.

Each E-finding cites: the promise (verbatim), the nearest acceptance line (verbatim or NONE), and the env evidence of the verification hole.

## Phase 6b — Family F: Standards conformance — security recipes (F-security)

Run whenever the feature adds columns to any table. Authority: security SOP §11 (*Sensitive-identifier columns — the default posture*), §14 (*Auditing*); form SOP §7; data-modeling SOP §5.

**F-sec-1 — sensitive identifier exposed.** Candidate columns = every column the spec adds whose logical name / display name / description matches `ssn|social|nationalid|taxid|fein|ein\b|vat|bank|routing|iban|dob|birth|passport|licen[cs]e|health|medic` (plus the spec's own PII list when it has one). For each:
```powershell
# secured?  (IsSecured on the attribute metadata)
Invoke-DataverseApi -EnvironmentUrl $envUrl -Method GET -Token $tok -Endpoint "EntityDefinitions(LogicalName='<table>')/Attributes(LogicalName='<col>')?`$select=LogicalName,IsSecured,RequiredLevel,IsAuditEnabled"
# any FSP grants it? (a secured column with no profile is unreadable by everyone — also a finding, S2)
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "fieldpermissions" -Select "attributelogicalname,canread,canupdate,_fieldsecurityprofileid_value" -Filter "entityname eq '<table>' and attributelogicalname eq '<col>'" -Raw
# Quick Find exposure: find columns live in the QF view's fetchxml <filter isquickfindfields="1">; display columns in its layoutxml
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "savedqueries" -Select "name,fetchxml,layoutxml" -Filter "returnedtypecode eq '<table>' and querytype eq 4" -Raw
# public views carrying it
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "savedqueries" -Select "name,layoutxml" -Filter "returnedtypecode eq '<table>' and querytype eq 0 and statecode eq 0" -Raw   # grep layoutxml for name="<col>"
```
`IsSecured` false, **or** the column in the QF `isquickfindfields` filter / QF layout / a general public view ⇒ **S1**, owner `spec-gap` (spec silent on securing it) or `build-gap` (spec secured it, env didn't). Quote SOP §11 verbatim.

**F-sec-2 — auditing off on the aggregate root.** Resolve the aggregate root(s) from the spec (the table the approval / financial process transitions on). Then:
```powershell
Invoke-DataverseApi -EnvironmentUrl $envUrl -Method GET -Token $tok -Endpoint "EntityDefinitions(LogicalName='<root>')?`$select=LogicalName,IsAuditEnabled"
Invoke-DataverseApi -EnvironmentUrl $envUrl -Method GET -Token $tok -Endpoint "organizations?`$select=isauditenabled"
```
Root `IsAuditEnabled.Value` false with no spec-recorded exception ⇒ **S2**, `spec-gap`. Org auditing off entirely ⇒ `manual-followup` (admin setting), still reported.

**F-sec-3 — required column added to an OOB table absent from the persona's form.** For every column the spec adds to an OOB table:
```powershell
Invoke-DataverseApi -EnvironmentUrl $envUrl -Method GET -Token $tok -Endpoint "EntityDefinitions(LogicalName='account')/Attributes?`$select=LogicalName,RequiredLevel&`$filter=startswith(LogicalName,'<prefix>_')"
# the form the persona saves from: the app's Main form(s) for the table (systemforms type 2, in app components) — grep formxml for datafieldname="<col>"
& $dataOp -Operation Query -EnvironmentUrl $envUrl -EntitySetName "systemforms" -Select "formid,name,formxml" -Filter "objecttypecode eq 'account' and type eq 2 and formactivationstate eq 1" -AllPages -Raw
```
`RequiredLevel.Value` in `ApplicationRequired` / `SystemRequired` and the column absent from every Main form the app exposes for that table ⇒ **S2**, `build-gap` (or `spec-gap` when the spec never named the form). Quote SOP §11 verbatim ("Required columns added to an OOB table must be on the form the persona actually uses").
