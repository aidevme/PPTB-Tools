---
name: hso-dataverse-ui-config
layer: atomic
scope: core
description: |
  Configure Dataverse UI components: forms and views. Use when updating form layouts (adding/removing/moving tabs, sections, fields), building or restructuring a whole form from a declarative layout spec in one atomic write (BuildForm), managing headers/footers, embedding web resources/quick view controls, configuring lookups, managing subgrids, adding timeline/form components, managing form events and libraries (onload, onsave, onchange, tab/cell-level events), setting form/tab/section/field properties, managing hidden controls, navigation items, display conditions, managing views (create, update, delete), curating the default Active/Inactive views to the column floor from table metadata (CurateDefaultViews), or analyzing form structure. Also use for UI/UX design reviews: Fluent UI compliance, accessibility (WCAG 2.1 AA), PCF control styling, web resource visual standards, and Dynamics 365 look and feel consistency.
---

# Dataverse UI Configuration Skill

Configure and manage Dataverse forms and views using the Web API.

---

## Slice Consumption Contract (executor side of the architect→builder pipeline)

**Authority:** [`slice-consumption-contract-best-practices.md`](../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md) — read before building any slice inside the pipeline. That SOP is the **canonical, executor-side contract** for [ADR 0018](../../../agent/wiki/decisions/0018-agentic-delivery-architect-builder-pipeline.md)'s architect→builder pipeline (the five rules, single-writer, reviewable-unit, anti-mis-attribution). The summary here is a labeled pointer, not a substitute.

When the architect routes a slice to this skill you are handed **the spec + its `spec.json` sidecar + a target slice `id`** — not a raw "make a good form" requirement to design from scratch. The layout pattern, the per-form timeline verdict, which views exist and their column floors are **already decided in the spec**; you build them and verify fidelity, you do not re-decide them. **This skill is invoked whenever a slice's `touches` include forms, views, sitemap, or app placement — a slice with form/view touches is NOT done until those are built and read back.** A slice that completed only its schema half (`hso-dataverse-data-modeling`) is incomplete: an entity slice listing a Pattern-D/B/etc. form still owes that full form here; if a minimal basic form exists from an upstream `capability` slice, **restructure it to the spec's pattern with `BuildForm`** — do not leave the stub.

Build **exactly the slice's `touches`** honoring the recorded design — the **timeline verdict** the spec recorded (present **iff** the spec says so; never auto-insert one it excluded, never drop one it required) and the **view floors/columns** the spec lists. Trust and verify — don't rebuild — your `blocked_by` slices (`QueryForms`, `QueryViews`, `QueryRelationships` to confirm prerequisites). **Read back against the slice's `acceptance`, not against an SOP rule the spec never invoked:** this skill already mandates an **independent structural read-back** after any structural form op (see [Verify the rendered structure](#verify-the-rendered-structure--independent-read-back-dont-trust-your-own-write) below) — inside the pipeline its bar is the slice's `acceptance`. **Read-back ops:** `ListFormStructure` (tabs/lanes/timeline match the spec's pattern), `GetViewDetails` (columns match the floors). A Pattern-D master-detail tab is *correctly* one lane; a child form the spec marked timeline=NO is *correctly* timeline-less — the missing-timeline finding belongs to the architect unless the **spec** said timeline=YES. End at the unmanaged solution named in `spec.json` (never export-as-managed or deploy).

**Single writer for shared artifacts — the canonical `assembly` slice is yours.** A parent Main form that needs **every child's subgrid** is **not** edited once per child; the architect places a single `assembly` slice that adds the subgrid(s) in **one `BuildForm` PATCH** (structurally immune to the systemforms cache clobber that concurrent per-child edits cause). When your slice is that assembly, you are the single writer. For an OOB form HSO does not own, do not edit it — the architect models an `extension` slice with a parallel HSO-owned form instead.

| Slice type | What this skill owns in it |
|------------|---------------------------|
| `capability` | the thin UI surface of the tracer-bullet (a basic form + the default view + adding the table to the app) |
| `entity` | the table's **forms** (pattern + timeline verdict) + **views** (floors + columns) + sitemap/app placement (the schema half is `data-modeling`) |
| `extension` | a **new HSO-owned** form + HSO views on an **OOB** table (never edit the OOB form) + app scoping (`ismanaged eq false`) |
| `assembly` | the **single-writer parent-form re-touch** (add child subgrids in one `BuildForm`), sitemap-area assembly |

> Tables, columns, relationships, choices, and alternate keys live in [`hso-dataverse-data-modeling`](../hso-dataverse-data-modeling/SKILL.md); sample data in [`hso-dataverse-data`](../hso-dataverse-data/SKILL.md). All executor skills share the **same** [Slice Consumption Contract](../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md).

---

## HSO Standard: Descriptions Are Mandatory

**Every form and view this skill creates must have a Description populated.** The script emits a `[WARN]` line when a description is missing on creation; do not ship a form or view with that warning unresolved.

| Component | Operation | Parameter |
|-----------|-----------|-----------|
| Form (Main / Quick Create / Quick View / Card) | `CreateForm` | `-FormDescription` |
| Form (existing) | `RenameForm`, `SetFormDescription` | `-FormDescription` |
| View (Public / Quick Find / Associated / Lookup) | `CreateView`, `UpdateView` | `-ViewDescription` |

Why:

- **Forms** — the description surfaces in maker-portal Form Properties and provides spec traceability (which form is this, why does it exist, what's the layout philosophy). Microsoft does not surface it on the runtime form, but downstream tooling (solution package metadata, documentation generators, ALM diff views) all consume it. An empty description is a dead end for anyone trying to reverse-engineer intent later.
- **Views** — the description renders in the view picker tooltip and in Advanced Find. Especially valuable for views with non-obvious filters ("Active Contracts" — what counts as active?).

The description should come from the architect spec — every spec authored by `hso-dataverse-architect` includes a Description column in its forms and views tables.

See [`shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md) and [`shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md) for the rule and rationale.

---

## Authoritative Best Practices

This skill spans several authoritative SOPs. Each governs a distinct set of first-class operations,
and each carries one task-scoped authority line below. Find the task you're doing in this map, then
read that doc *before doing the work* — its guidance takes priority over anything in this SKILL.md
and over the inline standards section further down.

### Task → primary authority

| Task | Primary authority |
|------|-------------------|
| Form layout / tabs / sections / header / footer / subgrids / timeline / FCC / business-rules-vs-JS / PCF placement | [`form-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md) |
| `CreateView` / `UpdateView` / `DeleteView` / `QueryViews` / `GetViewDetails` / subgrid views / Quick Find | [`view-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md) |
| Sitemap (`GetSiteMap` / `AddSiteMapSubArea` / `UpdateSubArea`) + `AddFormToApp` | [`app-module-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/app-module-configuration-best-practices.md) |
| `AddWebResource` / `AddFormEvent` / `RemoveFormEvent` / `AddFormLibrary` / `RemoveFormLibrary` | [`webresource-best-practices.md`](../../../shared/dv/agent/wiki/sop/webresource-development/webresource-best-practices.md) |
| PCF binding (`AddPCFControl`) visual / accessibility standards | [`pcf-theming-and-styling-best-practices.md`](../../../shared/dv/agent/wiki/sop/pcf-controls/pcf-theming-and-styling-best-practices.md) + [`pcf-accessibility-i18n-and-security-best-practices.md`](../../../shared/dv/agent/wiki/sop/pcf-controls/pcf-accessibility-i18n-and-security-best-practices.md) |
| Mobile / offline form, view, app | [`mobile-and-offline-best-practices.md`](../../../shared/dv/agent/wiki/sop/mobile-and-offline/mobile-and-offline-best-practices.md) (+ [`field-service-mobile-best-practices.md`](../../../shared/dv/agent/wiki/sop/field-service/field-service-mobile-best-practices.md) for Field Service) |
| Dashboards placed on app navigation | [`dashboard-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md) (secondary — see below) |
| Multi-language environment: label translation, sitemap More Titles, form-label copies, translation ALM | [`localization-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/localization-best-practices.md) §3 [Label and metadata translation](../../../shared/dv/agent/wiki/sop/model-driven-apps/localization-best-practices.md#3-label-and-metadata-translation--mechanics-and-alm) — sitemap/ribbon are NOT in the translation file; form labels are copies of column labels; 500-char import limit; same-org round trip |

### Forms SOP — primary authority

> **[`shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md)**

**Authority for form configuration** (layout, header/footer, subgrids, timeline, Form Component
Control, business-rules-vs-JavaScript, PCF placement) — **read before designing or modifying any
form.** Its guidance takes priority over anything in this SKILL.md, the inline standards section
below, and any other SOP on a *form-level* question. The standards section further down carries
forward the highest-frequency rules from this SOP so they're always in context — when those summary
rules and the SOP appear to conflict, **the SOP wins**.

What the Forms SOP covers:

- Form types (Main / Quick Create / Quick View / Card / Main Form Dialog) — when to use which
- Information architecture and the default-tab performance rule
- Header constraints (max 4 fields, no PCF/web-resource), footer deprecation
- Tab and section layout (1–3 columns / 1–4 columns, label widths, sidebar patterns)
- Subgrid, timeline, quick-view, Form Component Control, and side-pane patterns
- Business rules vs JavaScript decision rules
- Form-script (Client API) patterns, async OnLoad/OnSave, namespacing, anti-patterns
- PCF integration patterns for status badges, banners, progress donuts, sales-process pill bars, sidebar widgets
- Modern features (modern command bar, Power Apps grid, side panes, copilot)
- Accessibility (WCAG 2.1 AA), mobile/phone considerations, performance rules
- The pre-merge form configuration checklist

### App Module SOP — primary authority for app & sitemap operations

[`shared/dv/agent/wiki/sop/model-driven-apps/app-module-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/app-module-configuration-best-practices.md):

**Authority for app & sitemap configuration** (`GetSiteMap`, `AddSiteMapSubArea`, `UpdateSubArea`,
`AddFormToApp`) — **read before editing the sitemap or adding a form to an app.** Primary for these
first-class operations of this skill; it yields to the Forms SOP only when its guidance overlaps a
*form-level* question.

- Modern app designer + 2026 New Look mandate (classic look toggle removed)
- App strategy decision framework — when to build a new app vs extend an OOB hub; when to split into multiple apps
- App module structure — what tables/forms/views/dashboards/charts/BPFs/custom pages/web resources to add (and not)
- Sitemap design — areas/groups/sub-areas, sub-area types (Entity, Dashboard, Web Resource, URL, Custom Page, PCF Control via `/main.aspx?pagetype=control&controlName=...`), unique-ID rules, collapsible groups, hide-on-mobile
- Custom pages — when to use vs forms vs canvas; the ≤25-per-app cap; modern controls only; 1.33× font upscaling; generic launcher pattern (Sara Lagerquist); page-then-app publish order
- App-level command bar — Power Fx scopes (App / Table / Global), edit-from-inside-the-app rule, Power Fx limitations (no flow trigger, no privilege visibility, no email), bulk-action thresholds
- Modern theme overrides — XML resource (BasePaletteColor, Font, Vibrancy, HueTorsion, AppHeaderColors); classic theme records no longer honored
- Mobile and offline — offline profile limits (< 200K records / 100 tables / 1 GB / 4 GB files); "don't remove default-profile tables" rule; filter-pattern pitfalls
- App-level security and licensing — share with role pattern; per-app license deprecation 2026-01-02; restricted Dynamics 365 tables (read-only for Power Apps users)
- App ALM — solution layering (apps in dedicated layer above schema/plugins/forms/flows), Connection References + Environment Variables, deployment settings JSON, managed-to-prod
- Performance — cold/warm load (~2× difference), HSO targets, FastTrack Form Load + Plugin / Web Requests / Query Throttling dashboards
- Copilot — chat (deprecation deadline Jan 2026 for non-D365 environments), AI form fill (text/numeric/choice/date on Main + Quick Create only), Copilot Studio agents, Visualize with Copilot
- App URLs / deep links — `appname` vs `appid`, environment-variable pattern for stable links, `ms-dynamicsxrm://` mobile deep links
- App naming, anti-patterns, app configuration checklist

**Auditing which forms/views an app actually surfaces** — a form being *active* (`systemform`
`formactivationstate=1`) does **not** mean it appears in a given app. Apps that use explicit component
selection only show the forms in their component set, so a table with several active main forms can still
present just one in the app. To resolve what an app really exposes, call the unbound function
`RetrieveAppComponents(AppModuleId=<guid>)` and read the returned rows' `componenttype` (1=Entity,
26=View, 59=Chart, 60=SystemForm) and `objectid` — match form `objectid` to `systemform.formid`. Use this
before reporting a form as a user-facing duplicate or before deactivating one. (Form **security-role**
scoping is a separate axis and is *not* exposed via the Web API — confirm role targeting in the maker portal.)

### Dashboards SOP — secondary

[`shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md):

**Secondary relative to the Forms and App Module SOPs** — consult only for dashboards placed on app
navigation; this skill exposes no first-class dashboard operation, so this doc never governs a
first-class operation here.

- Dashboard kinds (System Standard / System Interactive / System Power BI Embedded / Personal Standard / Personal Power BI) — when to use which; the `SystemForm` (`Type=0`) vs `UserForm` storage split
- The 6-component cap (configurable up to 20 via `MaximumControlsLimit` PowerShell setting); HSO target ≤ 6 for portability; the four legitimate ways to break out of it (second dashboard, interactive, custom page, Power BI)
- Dashboard FormXml structure and the supported control parameters (`ViewIds`, `EnableChartPicker`, `ChartGridMode`, etc.); maker layout presets (2/3/4-column overview, Power BI embedded)
- Charts on dashboards — system-vs-personal ownership rule; chart authoring with [Advanced Chart Editor](https://www.xrmtoolbox.com/plugins/ITLec.CRMChartGuy.XRMToolBox.AdvancedChartEditor/) and [Chart Manager](https://www.xrmtoolbox.com/plugins/MsCrmTools.ChartManager/); Ulrik Carlsson chart patterns (YoY, multi-entity, N:N, stacked totals, percentage labels); chart accessibility (hatch + colour); 50K `AggregateQueryRecordLimit`
- Lists on dashboards — Default View / View Selector / Display Search Box / Display Index per-component properties; the outer-join trap; Power Apps grid control mandatory (Power Apps Read-Only grid not supported); design-time blindness (no preview)
- Web resources and iframes — form-enabled web resources only; iframe cross-frame scripting restricted on personal dashboards (`UnrestrictedIFrameInUserDashboard` error code); custom-page alternative is preferred for new work
- Power BI embedded as system dashboard — Environment Variables for workspace/report ID; dynamic RLS via `userprincipalname()`; service principals NOT supported in RLS roles; "complementary not competing" with system dashboards
- Interactive Experience dashboards — multi-stream / single-stream / table-specific layouts; three-filter pattern (visual + global + timeframe); per-table `IsEnabledForInteractiveExperience`; per-column "Appears in global filter" + "Sortable in interactive experience"; the queue-not-solution-aware deployment gotcha
- Personal dashboards and the ALM gap — production deliverables are always system; Andrew Butenko's [Personal Views/Charts/Dashboards Transfer Tool](https://www.xrmtoolbox.com/plugins/AB.PersonalViewsChartsDBTransferTool/) for the workaround; recreate-in-DEV vs promote-personal pattern
- Default dashboard (per-app vs per-user override); role scoping via Enable Security Roles; dashboard added to app module component list mandatory
- Custom pages as the modern alternative — when to choose canvas-on-MDA over a system dashboard; the ≤25-per-app cap from the app module SOP
- Dataset PCFs as dashboard components — Microsoft KPI Dashboard Suite; PCF Gallery (Kanban, Calendar, Schedule Board, Hierarchy); Diana Birkelbach's "subgrid context vs dashboard context" caveat — test in dashboard context specifically
- Dashboard command bar — the modern command designer does NOT support dashboard scope as a first-class scope; HSO rule: don't invest in dashboard-chrome commands, move to custom page or interactive dashboard
- Mobile (per-component "Available on Mobile" flag, not dashboard-level legacy flag); chart drill-down disabled on Power Apps Mobile; web browser on phone unsupported; dashboards NOT available offline
- AI / Copilot — Visualize with Copilot is view-scope not dashboard-scope; M365 Copilot in MDA for natural-language Q&A; Power BI Copilot at workspace level
- ALM — dashboards in app layer alongside forms/views/charts (not a separate Dashboards solution); Solution Components Mover for moving between solutions; Env Vars for PBI; queue pre-creation per environment
- Performance — concrete HSO targets (≤ 6 components, ≤ 10K rows pre-aggregation, ≤ 3s P95 cold load); Live Monitor; Performance Insights; FastTrack Web Requests / Form Load / Query Throttling dashboards; SQL 4 CDS for chart/list FetchXML
- Pre-merge dashboard configuration checklist

### Views SOP — primary authority for view operations

[`shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md):

**Authority for view configuration** (`CreateView`, `UpdateView`, `DeleteView`, `QueryViews`,
`GetViewDetails`, column counts, FetchXML, Quick Find, subgrid views) — **read before authoring or
editing any view.** For standalone view-authoring tasks (`CreateView` / `UpdateView` / `DeleteView`
— first-class operations of this skill) the Views SOP is the **primary** authority; it is secondary
only when its guidance overlaps the Forms SOP on a *form-level* question (e.g. which subgrid view a
form should surface).

- View types (Public / Advanced Find / Associated / Quick Find / Lookup / Reporting) keyed by `querytype`
- System views vs personal views; ALM implications
- Column count targets (digest only — the Views SOP is authoritative; read it before authoring a view): Default Public view (e.g. `Active X`) **6–10** columns; workflow Public views (`Open X` / `My X` / `Closed X`) **4–8**; subgrid view **3–6**; lookup view **2–4** (modern lookup shows the first 3); Quick Find result-display **3–5**; Quick Find find columns **≤ 4**. These are floor-and-ceiling ranges, not ceilings: the auto-generated `Active X` / `Inactive X` views ship with only the primary name column and must be **populated to the 6–10 floor** before delivery — do not ship a 1-column public or subgrid view
- Column order and sort discipline (no sort on choice / calculated / related-table columns)
- HSO view-naming patterns (`Active X`, `Open X`, `My X`, `Closed X`)
- FetchXML query performance — operator efficiency, leading-wildcard throttling, computed-column anti-pattern, link-entity limits, distinct, paging, `latematerialize` and `union` hints, deprecated `no-lock`
- Indexing in Dataverse — auto-indexed columns, alternate keys, Dataverse search; why ad-hoc index requests are not the path
- Quick Find: the 10,000-row hard cap evaluated BEFORE security trim, find-column rules, `isquickfindfields` semantics
- Filter and sort anti-patterns with their Microsoft error codes
- Power Apps Grid Control feature configuration (jump bar, infinite scroll, grouping/aggregation, OptionSet colors, customizer)
- Customizers (cell renderers / cell editors) for highlighting fields — color cells, badge pills, avatar lookups, progress bars, conditional formatting
- Dataset PCFs that replace the grid (kanban, calendar, gallery, map) — when to switch layouts
- View command bar — Power Fx commands, custom-page dialogs, bulk-action patterns
- Charts on views vs Power BI handoff
- Hierarchical views, mobile/phone card-list mode, subgrid view rules
- Modern features (Visualize with Copilot, natural-language search, Focused View)
- Performance rules + monitoring (SQL 4 CDS, FetchXML Builder, View Layout Replicator, FastTrack Query Throttling Dashboard, Web Requests Dashboard, Performance Insights, Power Apps Monitor)
- The pre-merge view configuration checklist

Apply the rules from these SOPs whenever this skill emits or modifies form XML / view XML / FetchXML. The standards section below carries forward the highest-frequency rules so they're always in context.

### Web Resource & Form Scripts SOP — primary authority for web resources and form scripts

[`shared/dv/agent/wiki/sop/webresource-development/webresource-best-practices.md`](../../../shared/dv/agent/wiki/sop/webresource-development/webresource-best-practices.md):

**Authority for web resources and form scripts** — **read before `AddWebResource`,
`AddFormEvent` / `RemoveFormEvent`, or `AddFormLibrary` / `RemoveFormLibrary`** (iframe sandbox
model, Client API discipline, async OnLoad/OnSave budget, lookup filtering, ribbon EnableRule
rules). Primary for these first-class operations of this skill.

- Web resource taxonomy (12 types — JS / HTML / CSS / images / SVG / RESX), 5-MB cap, when to use which; Silverlight (Type 8) deprecated
- Web-resource-vs-PCF-vs-business-rule decision matrix — Microsoft's "use PCF for interactive content" position; HSO rule "new interactive UI is PCF"
- Naming and folder layout — `<prefix>_/<category>/<entity>/<descriptor>.<ext>` URL contract; local folder mirroring; `$webresource:` directive auto-creates dependencies
- HTML web resources embedded in forms — iframe sandbox model, query-string parameters (`typename`, `id`, `data`, `formid`, etc.), `parent.Xrm` access pattern (only place `Xrm.Page` is unavoidable), `data` parameter URL-encoding, FluentProvider + IdPrefixProvider wrap requirement, `openWebResource` vs `navigateTo({pageType:webresource})` decision, the "no auth-protected iframes" rule
- Form-script Client API — `executionContext.getFormContext()` over `Xrm.Page`, "Pass execution context as first parameter" tick-box, namespace pattern (`HSO.<EntityName>`), event-handler 50-per-event limit, `addOnPostSave` / save-mode constants
- Async OnLoad / OnSave — 10-second-per-promise budget, `disableAsyncTimeout` for user-dialog scenarios + the AutoSave-fires-every-30s trap, `Promise.all` parallel-fetch pattern, sync-vs-async cancel paths
- Lookup filtering — `addPreSearch` registered once in OnLoad, `addCustomFilter` link-entity gotcha, `addCustomView` for joins
- Subgrid `addOnLoad` recursion-loop guard pattern (Linn Zaw Win / Alex Shlega)
- BPF stage-locking via `addOnPreStageChange` + `preventDefault()`
- Ribbon scripts — Power Fx first; JavaScript for Custom API / external calls; EnableRule perf rules (no Web API without cache, no `refreshRibbon`); Andrew Butenko's cached-async pattern
- Solution Checker — full rule list HSO enforces (Critical / High / Medium / Warning) with remediation
- ESLint plugin (`@microsoft/eslint-plugin-power-apps`) as preferred pre-merge gate
- Security — XSS / CSP / postMessage origin / sourcemap-strip-from-prod / DOMPurify caveats
- Caching and cache-busting — version-token contract, "publish all customizations" non-negotiable, why manual `?v=` is wrong
- Mobile and offline — what fails on UCI mobile (`window.parent` unreliable, auth-iframes don't work); `Xrm.WebApi.offline` branching
- Telemetry — App Insights JS SDK from inside web resources, no `Xrm.Performance` API
- Testing — `xrm-mock` + Jest for handler logic; FastTrack Playwright sample for E2E
- ALM — solution segmentation, `PowerPlatformPublishCustomizations@2` after every import, FastTrack pipeline templates, XrmToolBox WebResources Manager / `spkl` / PACX
- `Xrm.Page` → `formContext` migration via Aric Levin's three-part mapping series
- Anti-patterns and pre-merge checklist

### Mobile & Offline SOP — primary authority for mobile/offline UI

[`shared/dv/agent/wiki/sop/mobile-and-offline/mobile-and-offline-best-practices.md`](../../../shared/dv/agent/wiki/sop/mobile-and-offline/mobile-and-offline-best-practices.md):

**Authority for mobile and offline form/view/app behaviour** — **read before configuring any form,
view, or app that will be used from Power Apps mobile (model-driven mobile or Field Service Mobile)
or needs to survive offline.** Primary whenever the deliverable targets mobile/offline:

- **Mobile-form design** — dedicated mobile forms vs single responsive form; the "two-apps" pattern (separate mobile app module pointing at the mobile form); lightweight form patterns; what tab/section/column structures degrade gracefully on a phone; the "Available on Mobile" / "Available on Phone" flags on tabs/sections/controls
- **Offline-survival matrix per UI element** — form / view / web resource / PCF / business rule / business process flow / plugin: which work offline, which silently degrade, which fail outright
- **Offline profile shape and the four table classes** (Standalone / Related / Resources) — the profile sizing limits (200K records / 100 tables / 1 GB / 4 GB files) and the impact of including a chatty subgrid table on sync time
- **Profile filter design** — AND vs OR composition, the `Contains` / `Begins with` ban (only Equals / In is supported in offline filters)
- **Security in offline** — table-level privileges only; no Field-Level Security in offline; the implications for forms that rely on FLS to hide columns
- **Subgrid / quick-view / form-component-control behaviour on mobile** — what renders, what is skipped, the mobile-rail rules
- **Dashboards are NOT offline** — sitemap items pointing at dashboards must be hidden on mobile (or the sub-area gets the "Hide on mobile" flag) or the user sees a blank tile
- **Pre-go-live mobile readiness checklist** — including the airplane-mode test gate

**Authority for Field Service Mobile-specific form/view patterns** (the technician workspace, booking subgrid, customer-asset hierarchy view, inspection embedding) — read before configuring those, in addition to the Mobile & Offline SOP: [`shared/dv/agent/wiki/sop/field-service/field-service-mobile-best-practices.md`](../../../shared/dv/agent/wiki/sop/field-service/field-service-mobile-best-practices.md).

### Supporting references — secondary (never govern a first-class operation of this skill)

The following docs are secondary **relative to the primary authorities above**: they refine *how*
embedded UI looks and is named, but this skill exposes no first-class operation that they govern on
their own. Consult them as noted per entry.

- [`shared/dv/agent/wiki/sop/pcf-controls/pcf-theming-and-styling-best-practices.md`](../../../shared/dv/agent/wiki/sop/pcf-controls/pcf-theming-and-styling-best-practices.md) — **Authority for the visual standards of custom UI embedded into forms (PCF, web resources)** — read before designing or reviewing the appearance of an `AddPCFControl` binding or embedded web resource: native Dataverse styling values (TESTED Dec 2025), Drawer/Dialog portal fix, full-tab responsive sizing. The standalone UI guidelines monolith was retired 2026-05-05; visual rules now live in the PCF SOP family.
- [`shared/dv/agent/wiki/sop/pcf-controls/pcf-accessibility-i18n-and-security-best-practices.md`](../../../shared/dv/agent/wiki/sop/pcf-controls/pcf-accessibility-i18n-and-security-best-practices.md) — **Authority for accessibility (WCAG 2.1 AA) of anything embedded on a form** — read before reviewing an embedded PCF or web resource for accessibility.
- [`shared/dv/agent/wiki/sop/dataverse-naming-conventions.md`](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) — naming rules for forms, views, columns, subgrid views (consulted alongside the primary authority for whatever component you're naming).
- [`shared/dv/agent/wiki/sop/pcf-controls/pcf-control-development.md`](../../../shared/dv/agent/wiki/sop/pcf-controls/pcf-control-development.md) — PCF umbrella + 6 peer SOPs; consult when binding a PCF to a form.

Apply these whenever this skill emits or modifies form XML / view XML / FetchXML.

**Authority for whether the XML is structurally legal — read before hand-editing form or view XML:**
[`customizations-xml-schema.md`](../../../agent/wiki/reference/customizations-xml-schema.md). The SOPs above govern *what* a good form
or view looks like; `FormXml.xsd` and `Fetch.xsd` govern *what the XML may contain at all*. Two
different questions — when an import rejects a form with a line number rather than a cause, the
schemas are what turn that into an answer. They also record what schema validation will **not**
catch: unresolved references, GUID mismatches, dependency ordering, and control ClassIDs that are
well-formed but wrong for the column type.

---

## Form design comes first

> **A form is a UI to a *user task* and the primary surface a user interacts with for an entity — never a dump of the table's columns.** On a new or substantially-changed form, make the layout decision *first*. The path of least resistance — one tab, every section in lane 0, dump the column list — produces single-lane, patternless forms. Don't take it.

### Required first step — choose a pattern, write a layout plan

Before any form-mutating operation (`AddTab` / `AddSection` / `AddFields` / `AddSubgrid` / `AddQuickViewControl` / …) on a new or substantially-changed form:

1. **Read the Forms SOP** — [§2 information architecture](../../../shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md#2-information-architecture), [§3 header rules](../../../shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md#3-header-rules), [§5 tab & section layout](../../../shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md#5-tab-and-section-layout), [§6 canonical layout patterns](../../../shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md#6-canonical-layout-patterns).
2. **Choose a canonical pattern (A–E)** and **record a short layout plan** (put it in the form's `-FormDescription` / the architect spec). The plan names:
   - **Tabs** + order — the **default tab carries the hot path** (§2), not "General → everything".
   - **Sections**, and **which tab lane (column)** each one occupies.
   - **Header** — ≤ 4 at-a-glance KPI fields; no PCF / web resources (§3).
   - Placement of **subgrids / timeline / quick views / right-rail widgets**.

| Entity archetype | Pattern | Examples |
|---|---|---|
| Relationship record — you track a party / relationship | **A** — three-column, Timeline center | Account, Contact |
| Operational / transactional — you execute work | **B** — two-column, right-rail action cards | Work Order, Booking, Project, Task |
| Staged / process-driven (BPF) | **C** — BPF + three-column, AI summary | Opportunity, Lead, Case |
| Master–detail — header + line items | **D** — centered subgrid | Quote, Order, Invoice |
| Single-control workspace | **E** — full-tab single control | Marketing journey, custom canvas |

Full treatment of each pattern is in [SOP §6](../../../shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md#6-canonical-layout-patterns). If none fits, default to 50/50 two-column **with a documented rationale** (SOP §21 checklist).

### Layout mechanics — why forms render single-lane unless you act

- A **tab has columns (lanes)**; a **section has its own column count** for the fields inside it. Different settings — don't conflate them.
- **`AddSection` puts every section in tab lane 0 by default** (a vertical stack). For a real multi-lane layout you must **distribute sections across lanes** (assign each section's lane / column index), and **reserve the right lane** for at-a-glance widgets — status, KPIs, quick actions, reference panel.
- **`SectionColumns`** lays out fields *within* a section — it does **not** create tab lanes.
- **`TabColumns`** (1–3) sets how many lanes the tab has; sections still have to be assigned to them.

### Every change is a whole-form decision

Even adding one field / section / subgrid is judged against the **whole form**, not just the insertion point:

- [ ] Default-tab **hot path** — does this belong on it, or a later tab? (§2)
- [ ] **Lane balance** — which lane does it go in; or did everything just land in lane 0?
- [ ] **Header budget** — still ≤ 4 KPI fields? (§3)
- [ ] **Pattern fit** — does it hold the chosen pattern, or quietly break it?
- [ ] **Right rail** — should this be an at-a-glance widget rather than an inline field?

### Verify the rendered structure — independent read-back, don't trust your own write

After any **structural** form operation (`BuildForm`, `AddTab` / `AddSection` / `AddFields` / `AddSubgrid` / `MoveSection` / `MoveField` / … — anything that changes tabs, lanes, sections, or controls), an **independent read-back is mandatory before declaring done**:

1. **Read the form back** with `ListFormStructure` (or `QueryForms` returning formxml) against the **just-written form** — a fresh read of the saved record, **not** the operation's own return value. `BuildForm`'s output is its *in-memory compiled spec*; treating that as proof of what landed is the exact gap that let a form ship unverified. The internal persistence read-back `BuildForm` performs confirms the *write landed* — it is not a substitute for *you* reading the structure back and reasoning over it.
2. **Assert the read-back matches the spec / layout plan** — the tabs, **lanes** (with their distribution), and sections the architect spec / `formDescription` called for. Quote the read-back lane structure when reporting done. `TabColumns` / `SectionColumns` being set does **not** prove the intended layout rendered — confirm lane distribution explicitly.
3. **Match the spec, not a fixed shape.** Do not assert an invented floor like "≥ 2 lanes" — a Pattern D master-detail tab or a Pattern E single-control workspace is *correctly* one lane. The bar is fidelity to the plan you were handed, nothing more.

**Forbidden:** declaring "structure verified" / "done" on a build or mutation call's **own output**. The done-criterion is a quoted, independent read-back that matches the spec. (The test harness runs the authoritative completeness read-back via `Assert-SpecFormsBuilt`; this is the per-op discipline.)

> Scope: this applies to **structural** operations. `RenameForm` / `SetFormDescription` patch only the form's name/description (outside formxml) — a full structural read-back after them is unnecessary.

## Form & View Standards (Quick Reference)

> The rules below are a quick checklist drawn from the Forms SOP. The full methodology, with
> rationale, edge cases, and worked examples, lives in
> [`form-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md).
> Defer to the SOP when in doubt — its guidance takes precedence over this section.

### Form Naming Convention

Form names follow the pattern: **`Client Name | Form Type | Purpose (if applicable)`**

| Example | When |
|---------|------|
| `HSO \| Main` | Standard main form |
| `HSO \| Quick Create` | Quick create form |
| `HSO \| Quick View` | Quick view form |
| `HSO \| Quick View \| Account` | Quick view for a specific entity context |

### Before Creating a Form or View

Always check whether one already exists before creating a new one:
- Run `QueryForms` on the table — if a Main form already exists, confirm with the user before creating another
- Run `QueryViews` on the table — if a suitable view exists, use it rather than creating a duplicate

### Subgrid Standards

1. **Hide search box** — Always set `HideSearchBox = $true` (the default). Do not expose the search box on embedded subgrids.
2. **Use a dedicated subgrid view** — The view used in a subgrid should NOT include the parent lookup column (it's redundant and wastes column space). Before adding a subgrid:
   - Run `QueryViews` on the related table
   - Look for a view with "Subgrid" in the name, or create one using `CreateView` that excludes the parent lookup
3. **If ViewId is not provided**, the skill auto-picks a view: first an existing dedicated subgrid view (name contains "Subgrid"), else the default public view with a warning — the latter is acceptable for a first pass but should be replaced with a proper subgrid view before delivery
4. **A form subgrid points at a PUBLIC view (querytype 0).** Note that `CurateDefaultViews -Views Subgrid` curates the table's **associated** view (querytype **2**) — a *different artifact*. Curating the associated view does **not** change a form subgrid; to control a subgrid's columns, point its `ViewId` at a dedicated public/subgrid view (querytype 0).

### View Standards

> Digest only — the [Views SOP](../../../shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md) is authoritative; read it before authoring a view.

- **Default `Active`/`Inactive` views populated to 6–10 columns before delivery.** These auto-generate with only the primary name column; curate them up to the floor via `UpdateView` — never ship a 1-column default Public view.
- Column-count ranges (floor–ceiling, not ceilings): default Public 6–10; workflow Public (`Open`/`My`/`Closed`) 4–8; subgrid 3–6; lookup 2–4; Quick Find result-display 3–5; Quick Find find columns ≤ 4.
- **Enforce the floor at build time (#407):** pass each view's spec.json `floorMin`/`floorMax` as `-ViewFloorMin`/`-ViewFloorMax` on `CreateView`/`UpdateView`. The build emits `[FLOOR-FAIL]` and exits non-zero when the built column count is outside the range — so an under-curated view fails at the build, not later at the grader.
- An `Active X` view's name and filter are reserved (see [View Naming - Reserved Names](#view-naming---reserved-names)); its columns are not.

### Timeline Standards

- The timeline control must always be in its own dedicated section (not shared with other fields)
- Use `SectionName = "section_timeline"`, `SectionLabel = "Timeline"`
- The section should be on its own tab, or as the last section in a tab

---

## Operations Summary

| Category | Operation | Description |
|----------|-----------|-------------|
| **Composite** | `BuildForm` | **Build or restructure a form from a declarative layout spec in one atomic write** (header + tabs + lanes + sections + fields/subgrids/timeline). Single GET → assemble in memory → one PATCH → one publish → read-back verify; immune to the systemforms cache clobber. Prefer over decomposing into 20+ per-op calls for new or substantially-changed forms. `-DryRun` previews the compiled structure. |
| | `BuildAllForms` | **Build every Main form a `spec.json` declares in one call** — compiles each `forms[]` entry into a BuildForm LayoutSpec (verbatim if it carries `tabs`/`header`, else synthesized from table metadata + `layoutPattern`/`timeline`) and runs `BuildForm`. Deterministic; exits non-zero on any failure. `-FormTables` limits to named tables; `-DryRun` previews. |
| | `CurateDefaultViews` | **Curate the auto-generated `Active`/`Inactive`/`QuickFind` (Subgrid optional) views to the 6–10 column floor in one call**, picking columns from a metadata-driven heuristic. Replaces ~4 calls + column research. `-DryRun` previews the proposal. |
| **Forms** | `QueryForms` | List forms for a table |
| | `GetForm` | Get raw form XML |
| | `CreateForm` | Create a new form (Main, QuickCreate, QuickView, Card). Pass `-FormDescription` (HSO standard). |
| | `RenameForm` | Patch `systemforms.name` and/or `systemforms.description` (display name and description both live outside formxml). Pass `-FormName`, `-FormDescription`, or both. |
| | `SetFormDescription` | Update only the form's description on `systemforms.description` (HSO standard). |
| | `ListFormStructure` | Human-readable form structure (tabs, sections, fields, events, libraries, hidden controls, nav, display conditions) |
| | `SetFormProperties` | Set form-level attributes (showImage, shownavigationbar, maxWidth, etc.) |
| | `SetDisplayConditions` | Configure role-based form visibility |
| **Tabs** | `AddTab` | Add tab to form |
| | `RemoveTab` | Remove tab from form (supports `-TabName 'firstunnamed'` to target the auto-stub tab on customized auto-`Information` Main forms) |
| | `RenameTab` | Change a tab's display label |
| | `SetTabProperties` | Set tab visibility, expanded, availableforphone, collapsible |
| **Sections** | `AddSection` | Add section to existing tab |
| | `RemoveSection` | Remove section from tab |
| | `MoveSection` | Reposition section within a tab |
| | `RenameSection` | Change a section's label and/or `@name` (label-only is safe; `@name` change breaks code that references the section by name) |
| | `SetSectionProperties` | Set section visibility, columns, availableforphone, autoexpand, height |
| **Fields** | `AddFields` | Add one or more fields to a section |
| | `RemoveField` | Remove a field from the form body |
| | `MoveField` | Move a field between sections |
| | `UpdateField` | Set field properties (showlabel, readonly, visible, colspan, rowspan, isrequired, availableforphone) |
| | `AddHeaderField` | Add field to form header |
| | `RemoveHeaderField` | Remove field from form header |
| | `AddFooterField` | Add field to form footer |
| | `RemoveFooterField` | Remove field from form footer |
| | `AddHiddenField` | Add field to hidden controls (available to scripts, not UI) |
| | `RemoveHiddenField` | Remove field from hidden controls |
| **Controls** | `AddSubgrid` | Add subgrid control to section |
| | `ConfigureSubgrid` | Set advanced subgrid params (AutoExpand, ChartGridMode, EnableViewPicker, etc.) |
| | `AddTimeline` | Add timeline (notes/activities) control |
| | `AddFormComponent` | Embed related entity form inline via lookup field |
| | `AddWebResource` | Embed web resource (HTML/JS/image) on form |
| | `AddQuickViewControl` | Add Quick View Form control for inline related data |
| | `ConfigureLookup` | Set lookup parameters (filtered views, dependent lookups, etc.) |
| | `AddSpacer` | Add spacer control for layout |
| **PCF Controls** | `AddPCFControl` | Bind a deployed PCF control to a form field via `controlDescriptions` |
| | `RemovePCFControl` | Remove a PCF binding from a form field (restores the field's default control) |
| **Events** | `AddFormEvent` | Add event handler (onload, onsave, onchange, ontabstatechange, cell-level) |
| | `RemoveFormEvent` | Remove event handler or entire event |
| | `AddFormLibrary` | Register JS web resource on form |
| | `RemoveFormLibrary` | Remove JS web resource from form |
| **Navigation** | `AddNavItem` | Add navigation item (relationship or custom URL) |
| | `RemoveNavItem` | Remove navigation item |
| **App Module** | `AddFormToApp` | Add a form to a model-driven app |
| **Publish** | `PublishForm` | Publish form customizations |
| **Sitemap** | `BuildSiteMap` | **Build the whole sitemap from `spec.json`'s `app` node in one write** — assembles every declared area/group/sub-area IN DECLARED ORDER in memory, one PATCH + publish, then reads back and diffs (present + order). Single-writer; immune to the per-mutation clobber the singles risk. Prefer for spec-driven app builds. |
| | `GetSiteMap` | Display full sitemap structure (areas, groups, sub-areas) for an app |
| | `AddSiteMapSubArea` | *Surgical — retrofit one node on a sitemap you are NOT rebuilding; never after `BuildSiteMap`.* Add one sub-area (URL, entity, or **dashboard** via `-SubAreaDefaultDashboard`); creates the group if missing, and the area if `-AreaTitle` is supplied |
| | `UpdateSubArea` | *Surgical — retrofit only; never after `BuildSiteMap`.* Change one existing sub-area to a URL-based view (entity + viewId or explicit URL) |
| | `MoveSiteMapGroup` | *Surgical — retrofit only; never after `BuildSiteMap`.* Reposition one group within its area (`-GroupPosition 0` = top) |
| **Views** | `QueryViews` | List views for a table (name + type + id) |
| | `GetViewDetails` | Get view FetchXML/LayoutXML. `-Summary` prints a parsed `columns / sort / filter` one-liner instead of raw XML; `-Raw` also returns the savedquery object |
| | `InspectViews` | **All of a table's views at once** — name + type + a `columns / sort / filter` summary per view (the review pattern, without one `GetViewDetails` per GUID) |
| | `CreateView` | Create new view |
| | `UpdateView` | Update view columns/sort/find columns. A columns-only edit **preserves the existing sort and filter** (only `-ViewSortBy` replaces the sort); warns if the view ends up with no sort |
| | `DeleteView` | Delete view |

## Composite Operations (preferred for new builds)

Two Layer-4 composites that turn an SOP-scripted chore into a single operation. Per
[ADR 0013](../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md) Rule 2 these are **kept** (not thin
wrappers): their value is a non-obvious algorithm + a race workaround, not a 1:1 alias for one API call. Both
support **`-DryRun`** — compute and print, write nothing — so you can confirm the result before committing.

> **`-SpecJsonPath` is an orchestration convenience for spec-driven builds; every op here also works from explicit
> params / inline input — spec.json is never required.** `BuildForm -LayoutSpec <inline | file>` builds one form with
> NO spec.json; `BuildAllForms -SpecJsonPath` is the spec-batch convenience that renders every declared form via BuildForm.
>
> **The spec IS the form.** The architect emits the **full BuildForm LayoutSpec** in `spec.json` `forms[].tabs`
> (plus `header`, `layoutPattern`, view `columns`) — so the form is fully specified and reviewable before any write.
> The **primary spec-driven form-build path is `BuildAllForms`**: it renders every Main form's declared LayoutSpec
> **verbatim**, and `BuildForm` consumes that same LayoutSpec for one form. Synthesis-from-metadata is a **fallback
> only**, for legacy/lean specs that omit `tabs` — never the chosen path when the spec carries a layout.

### BuildForm

Build (or substantially restructure) a model-driven form from one **declarative layout spec** instead of the
**20–25 sequential `GET → modify → PATCH → PublishXml` round-trips** the per-op functions require. BuildForm does a
**single `GET` → assembles the complete formxml in memory → one `PATCH` → one publish → one read-back verify**.
Because it never re-reads between mutations, it is structurally **immune to the systemforms cache clobber** (the
stale-read race where a deferred-publish batch silently drops an earlier op — this collapsed 5 tabs into 1 in the
sandbox test). It is atomic, faster, and self-verifying.

```powershell
-Operation BuildForm -FormId "<guid>" -LayoutSpec '<json|path>' [-Mode Replace] [-DryRun] [-SolutionName <s>]
```

- **`-FormId`** — target form (e.g. the table's Main form from `CreateForm` or the default Information form).
- **`-LayoutSpec`** — the JSON layout below, **inline** or a **file path** to a `.json`.
- **`-Mode Replace`** (default) — authors the form body (header + tabs) from the spec; **preserves** form-level
  scripts, events, libraries, and properties not described in the spec (they are spliced around, not rewritten).
  `Merge` is reserved (Phase 2) and currently hard-fails with guidance.
- **`-DryRun`** — compile + validate the spec and print the resulting structure (lanes included) **without** writing.

**Layout-spec JSON:**

```jsonc
{
  "formDescription": "Primary working form. Pattern: tabbed hot-path. Tabs: Summary (customer, coverage, financials) | Covered Assets (subgrid) | Timeline. Header surfaces status, coverage tier, end date, annual value.",
                                       // STRONGLY RECOMMENDED — the IA plan + chosen pattern. Persisted to
                                       // the form Description (durable rationale / spec traceability). BuildForm
                                       // emits a [WARN] if omitted (it was the iteration-3 2.1 regression).
  "header": {                          // <= 4 fields, field-only (enforced — hard-fail otherwise)
    "fields": ["statuscode", "hsot_coveragetier_code", "hsot_enddate_date", "hsot_annualvalue_amt"]
  },
  "tabs": [
    {
      "name": "tab_summary", "label": "Summary",
      "lanes": [                        // each lane = one tab <column>; widths MUST sum to 100
        { "width": "50%", "sections": [
            { "name": "sec_customer", "label": "Customer & Contact", "columns": 1,
              "fields": ["hsot_customer_id", "hsot_maincontact_id"] },
            { "name": "sec_coverage", "label": "Coverage & Term",
              "fields": ["hsot_coveragetier_code", "hsot_startdate_date", "hsot_enddate_date"] }
        ]},
        { "width": "50%", "sections": [
            { "name": "sec_financials", "label": "Financials",
              "fields": [
                "hsot_annualvalue_amt",
                { "name": "hsot_description_memo", "colspan": 2, "readonly": true, "showlabel": false }
              ] }
        ]}
      ]
    },
    {
      "name": "tab_assets", "label": "Covered Assets",
      "lanes": [ { "width": "100%", "sections": [
        { "name": "sec_assets", "label": "Covered Assets",
          "subgrid": { "name": "sg_assets", "relationship": "hsot_serviceagreement_coveredasset",
                       "target": "hsot_coveredasset", "view": "Covered Assets Subgrid" } }
      ]}]
    },
    {
      "name": "tab_timeline", "label": "Timeline",
      "lanes": [ { "width": "100%", "sections": [
        { "name": "sec_timeline", "label": "Timeline", "timeline": true }
      ]}]
    }
  ]
}
```

- **`formDescription`** (top-level) — the layout plan + chosen pattern, persisted to the form's Description.
  **Strongly recommended**: capturing the rationale durably (not just in chat) is the HSO standard. `description`
  is accepted as an alias. **If omitted, BuildForm auto-synthesizes** a plan from the compiled structure
  ("Pattern &lt;X&gt; layout; N-field KPI header; tabs: …; with a child subgrid; timeline present") — so the
  layout plan is always recorded (form-SOP §2). For the synthesis to include the **pattern letter** (the grader
  checks for `Pattern A–E`), pass **`layoutPattern`** (top-level, `"A"`–`"E"`, straight from `spec.json`
  `forms[].layoutPattern`); without it the auto-plan is recorded but carries no pattern letter (a `[WARN]`).
- **Fields** are either a logical name string, or an object `{ "name", "label?", "showlabel?", "colspan?",
  "rowspan?", "readonly?" }`. Labels resolve from the live attribute DisplayName when not provided.
- **`subgrid`** — `{ name, target, relationship, view?, label?, rowspan? }`. `view` is the bound saved view by
  **name or id** (`viewId` is accepted as an alias). Omitting `view` triggers the dedicated-view-first auto-pick
  (and `[SUBGRID-FALLBACK]` marker) documented in [Subgrid Standards](#subgrid-standards).
- **`"timeline": true`** on a section emits the timeline control. The table **must** have Notes (`HasNotes`) or
  Activities (`HasActivities`) enabled — BuildForm **hard-fails** if not (it will not mutate table metadata; enable
  it on the table first via the data-modeling skill).
- A section may hold any mix of `fields`, a `subgrid`, and `timeline`. A **subgrid-only or timeline-only section
  simply omits `fields`** (as `sec_assets` and `sec_timeline` do above) — no `"fields": []` placeholder needed.
- **Record Log tab is automatic** on Main forms (SOP §6): if your spec has no `recordlog`/`Record Log` tab,
  BuildForm appends the standard one (Modified On/By, Created On/By, Owner) so it can't be forgotten. Include it
  yourself to control placement/contents, or set top-level `"recordLog": false` to opt out.

**Validation is up-front and strict** — the whole spec is checked and every issue is listed before anything is
written: lane widths must sum to 100, header ≤ 4, every `datafieldname` must exist on the table, timeline
dependency must be satisfied. Element coverage is header fields, tabs, lanes (with widths), sections (with
`columns`), bound fields with per-field overrides, subgrids, and timeline. **Anything not yet expressible
(quick-view, web-resource, spacer, form-component, PCF) falls back to the per-op functions after the build.**

Output on success:

```
[OK] Form XML persisted (verified by formxml read-back: all 27 structural element(s) present).
[OK] Customizations published for hsot_serviceagreement
[OK] Layout plan recorded in the form Description.
[OK] BuildForm: 3 tab(s) authored and published (persistence verdict above).
<render of the compiled spec, with LANES — from the in-memory build, never a stale post-write GET>
```

> Persistence is now verified by a **formxml read-back** (confirming every tab/section/field token we wrote
> is present, with retry for cache lag) — **not** the versionnumber bump, which a formxml-only write genuinely
> does not advance. The final structure render comes from the **in-memory compiled spec**, so it can never show
> a stale `tab_general`/`sec_*` raw-name false negative from the systemforms cache.

### BuildAllForms (the primary spec-driven form build)

Build **every Main form a `spec.json` declares** in one call — no per-form `FormId` plumbing. For each
`forms[]` Main entry it resolves the table's active Main form **by the canonical selection rule** (active Main
forms ordered by `(tab-count + section-count)` desc, then `isdefault` desc, then `name` asc — the identical
ordering the graders use, so build and grade converge; `[WARN]` names the chosen form when a table has >1 active
Main form), **compiles a BuildForm LayoutSpec from the entry**, then runs `BuildForm`. When the entry carries the full `tabs`/`header` LayoutSpec (the architect's
standard output) it is rendered **verbatim** — the spec IS the form. **Fallback only**, for a lean/legacy entry
that omits `tabs`: it synthesizes lanes from live table metadata keyed off `layoutPattern` (A/B/C two-lane + KPI
header, D/E single-lane) and adds a dedicated timeline section when `timeline:true`. Reports per-form and
**exits non-zero if any fails** — also the deterministic repair the test harness fires for any Main form left a
default stub, removing the LLM from the form-repair loop.

```powershell
-Operation BuildAllForms -SpecJsonPath "<path>\spec.json" [-FormTables hsot_a,hsot_b] [-DryRun] [-SolutionName <s>]
```

- **`-SpecJsonPath`** — the `spec.json` whose `forms[]` Main entries drive the build (required).
- **`-FormTables`** — limit to these table logical names (e.g. just the stubbed ones); omit to build all spec Main forms.
- **`-DryRun`** — compile + print each form without writing.
- **`-StrictContract`** — promote the warn-only build markers (`[HEADER-WARN]` Pattern-A/B/C zero-field header,
  `[SUBGRID-FALLBACK]` subgrid fell back to the default public view) to **hard build failures** (default off; legacy
  specs warn). Also honored by `BuildForm`. A declared non-Main form (QuickCreate/QuickView/Card) emits a visible
  `[SKIP]` (BuildAllForms builds Main forms only — author the rest via `CreateForm`).

### CurateDefaultViews

Curate the shipped 1-column `Active X` / `Inactive X` (and `QuickFind`) views up to the **6–10 column floor in one
call**, picking the column set from the table's metadata — replacing ≈4 `UpdateView` calls + column research.

```powershell
-Operation CurateDefaultViews -TableName "<logical>" `
    [-Views Active,Inactive,QuickFind,Subgrid]   # default: Active,Inactive,QuickFind
    [-MaxColumns 8] [-IncludeOwner] [-DryRun] [-ViewDescription "<s>"] [-SolutionName <s>]
```

- **`-Views`** (default `Active,Inactive,QuickFind`) — `QuickFind` also sets find columns (primary + up to 3
  entity-owned **text** columns; a lookup is ineligible, so an auto-number primary still searches weakly). Add
  `Subgrid` for the associated view.
- **`-MaxColumns 8`** — cap within the 6–10 floor (Subgrid additionally capped at 6); **`-IncludeOwner`** adds
  `ownerid`; **`-ViewDescription`** overrides the auto-generated description.

**Column heuristic** (capped at `-MaxColumns`): primary → `statuscode` (+`ownerid` with `-IncludeOwner`) → business
columns ranked required-first then by list usefulness (Lookup → DateTime → Money → Choice → Integer/Decimal →
Boolean) → `createdon` if room. Excludes Memo / virtual / calculated / shadow columns. Parent lookup is on the
Active/Inactive lists but excluded from `Subgrid`. Sort defaults to primary (or `createdon desc` for Inactive),
never a choice/lookup/calculated column; the Active filter is never touched — columns only.

Output:

```
[OK] CurateDefaultViews curated for hsot_serviceagreement:
  Active   : 8 cols [hsot_name, statuscode, hsot_customer_id, hsot_enddate_date, hsot_startdate_date, hsot_annualvalue_amt, hsot_coveragetier_code, hsot_autorenew_yn] (sort: hsot_name)
  Inactive : 8 cols [hsot_name, statuscode, hsot_customer_id, ...] (sort: hsot_name)
```

> **Validation gate (per ADR 0013):** both composites must be **live-validated** against a real environment before
> being relied on — `BuildForm`: rebuild a non-trivial multi-lane form and confirm the read-back matches the spec;
> `CurateDefaultViews`: run on a table with the shipped 1-column defaults and confirm Active + Inactive land in the
> 6–10 floor with the Active filter intact.

## Form XML Schema Reference

For detailed Form XML schema (elements, attributes, control ClassIDs, parameters by type), see [shared/dv/agent/wiki/references/form-xml-schema.md](../../../shared/dv/agent/wiki/references/form-xml-schema.md).

Companion references in this skill:
- **D365 Word Templates** — document generation from a record (content-controls-not-MERGEFIELDs, the `0x80044150` dual-schemaRef root cause, the OOB-base-template + swap-`document.xml` pattern): [references/d365-word-templates.md](references/d365-word-templates.md).
- **SLA KPI timers** — which case forms carry the timer control, how it reads `slakpiinstance`, and the delete-Canceled + re-anchor-`failuretime` technique to set a live countdown for a fixed demo time: [references/sla-kpi-timers.md](references/sla-kpi-timers.md).

For **removing** components — delete a form, remove a form from an app, remove a subgrid, remove/batch-edit sitemap sub-areas — not wrapped as operations here; composed (or kept as a composite helper) per [ADR 0013](../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md) — see [`references/form-and-sitemap-removal-web-api.md`](references/form-and-sitemap-removal-web-api.md).

For **modern command-bar buttons** (`appaction` rows — form and main-grid buttons with JS handlers, icons, and selection-gated Power Fx visibility, created over pure Web API; no RibbonDiffXml, no designer session) — not wrapped as operations here yet (candidate `RegisterCommand` capability); the full recipe, column set, undocumented parameter-enum table, both `fonticon` namespaces, the visibility-binding bootstrap, and the entity-poisoning pitfall live in [`references/appaction-command-registration.md`](references/appaction-command-registration.md).

## Quick Reference

All operations use the same base command:

```powershell
powershell -ExecutionPolicy Bypass -File "claude-code/skills/hso-dataverse-ui-config/scripts/Invoke-DataverseUIOperation.ps1" `
    -Operation <OperationName> `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    <additional parameters>
```

> **Array parameters under `-File`:** pass simple-array params (`-ViewColumns`, `-ViewColumnWidths`,
> `-ViewFindColumns`, a plain `-Fields` name list, `-FormFactors`) as **one comma-separated token**
> (`-ViewColumns "hso_name,statuscode,createdon"`) — a `@(...)` literal overruns the next parameter under
> `-File`. Hashtable-form arrays (`-Fields` with label/type, `-ViewLinkedColumns`) can't cross `-File` at all:
> use a JSON-spec param (`BuildForm -LayoutSpec`, `-PCFParametersJson`) or invoke in-process via `& "<path>…"`.

### Surgical form edits — prefer `BuildForm`

`BuildForm` (and `BuildAllForms`, which calls it per form from the spec) is the **only documented full-form build
path** (header + tabs + lanes + sections + subgrids/timeline in one atomic write — from the architect's declared
LayoutSpec). The per-op surgical functions below are for **additive tweaks to an already-built form**
(retrofit one field, rename a tab, set one property) — **do not** decompose a whole-form build into them
(that is the 20+-round-trip path BuildForm exists to replace, and it re-opens the systemforms cache clobber).

Surgical ops (each a thin wrapper — run `ListFormStructure` first, target by name/GUID): `CreateForm`,
`SetFormDescription`, `AddTab` / `RemoveTab` / `RenameTab` / `SetTabProperties`, `AddSection` / `RemoveSection` /
`MoveSection` / `RenameSection` / `SetSectionProperties`, `AddFields` / `RemoveField` / `MoveField` / `UpdateField`,
`AddHeaderField` / `RemoveHeaderField` / `AddFooterField` / `RemoveFooterField`, `AddHiddenField` /
`RemoveHiddenField`, `AddSubgrid` / `ConfigureSubgrid`, `AddTimeline`, `AddFormComponent`, `AddQuickViewControl`,
`AddWebResource`, `ConfigureLookup`, `AddSpacer`, `AddPCFControl` / `RemovePCFControl`, `SetFormProperties` /
`SetDisplayConditions`, `AddFormEvent` / `RemoveFormEvent`, `AddFormLibrary` / `RemoveFormLibrary`,
`AddNavItem` / `RemoveNavItem`, `AddFormToApp`, `QueryForms` / `QueryViews`, `PublishForm`.

Every op's exact parameters are in the **script header / `param()` block** of
[`scripts/Invoke-DataverseUIOperation.ps1`](scripts/Invoke-DataverseUIOperation.ps1) (the `Operations Summary`
table above maps each op to its purpose). Field type auto-detection by suffix and naming live in
[`dataverse-naming-conventions.md`](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md).

### ListFormStructure (Start Here)

Shows tabs, sections with field names, subgrids, web resources, quick views, header/footer, events, libraries, hidden controls, navigation, display conditions, and form properties.

```powershell
-Operation ListFormStructure -FormId "603991a3-..."
```

> The per-op samples below are **surgical / targeted** edits to an already-built form. For building or
> substantially restructuring a whole form, prefer `BuildForm` / `BuildAllForms` (`-SpecJsonPath`); for a
> whole sitemap, prefer `BuildSiteMap` — see [Composite Operations](#composite-operations-preferred-for-new-builds).

### CreateForm

Create a new form (Main, QuickCreate, QuickView, or Card) for a table with specified fields.

```powershell
# Create a Card form (for Timeline display) — HSO standard requires -FormDescription
-Operation CreateForm -TableName "quoteclose" -FormName "Quote Close Card" `
    -FormDescription "Card layout shown in the Quote Close timeline. Surfaces subject, end date, and description for at-a-glance review." `
    -FormType "Card" -Fields @("subject", "actualend", "description") `
    -SolutionName "MySolution"

# Create a Quick View form
-Operation CreateForm -TableName "hso_contract" -FormName "Contract Quick View" `
    -FormDescription "Inline preview of the linked contract, used on related entity forms (orders, amendments). Read-only." `
    -FormType "QuickView" `
    -Fields @(
        @{Name="hso_contractnumber_text"; Label="Contract Number"; Type="String"},
        @{Name="hso_status_code"; Label="Status"; Type="Picklist"}
    ) -SolutionName "MySolution"
```

**Parameters:**
- `TableName` - Entity logical name (required)
- `FormName` - Display name for the form (required)
- **`FormDescription`** - Description of the form (HSO standard — required; warning emitted if missing)
- `FormType` - `Main`, `QuickCreate`, `QuickView`, or `Card` (default: Main)
- `Fields` - Array of field names or hashtables with Name/Label/Type (required)
- `SolutionName` - Solution to add the form to (optional)

### SetFormDescription

Populate (or update) the description on an existing form — the most common path for retrofitting the HSO description standard onto auto-created forms (e.g., the default `Information` Main form on a custom table).

```powershell
-Operation SetFormDescription -FormId "603991a3-1234-..." `
    -FormDescription "Default Main form for hso_visit. Tab layout: Summary | Schedule | Notes."
```

### AddTab / RemoveTab / RenameTab

> **Auto-generated form tabs have no `name` attribute:** When Dataverse auto-creates a Main form for
> a new custom table, the default "General" tab is created with only an `id` (GUID) attribute and
> **no `name` attribute at all**. Passing any string (including `"tab"`) to tab-targeting operations
> (`AddSection`, `AddFields`, etc.) will fail with "Tab not found" on these forms.
>
> `Find-Tab` now falls back to matching by `@id` (GUID), so you can target a nameless tab by
> passing its GUID from `ListFormStructure` as `-TabName`. However, the recommended approach is to
> run `AddTab` first to create an explicitly-named tab (e.g. `tab_details`), then add all content
> to that tab. Do not modify the auto-generated nameless "General" tab.
>
> Always run `ListFormStructure` before any form modification to discover actual tab names and IDs.
>
> **Duplicate label detection:** `AddTab` checks both the tab `name` attribute and the tab label.
> If a tab with the same label already exists, the operation returns the existing tab's name and
> skips creation rather than creating a duplicate.

```powershell
-Operation AddTab -FormId "..." -TabName "tab_details" -TabLabel "Details" `
    -TabColumns 2

-Operation RemoveTab -FormId "..." -TabName "tab_details"

-Operation RenameTab -FormId "..." -TabName "tab_notes" -TabLabel "Timeline"

# Special: target the auto-stub tab on a customized auto-`Information` Main form
# (no @name attribute, and the GUID isn't surfaced through ListFormStructure)
-Operation RemoveTab -FormId "..." -TabName "firstunnamed"
```

`TabColumns` is validated to range 1-3 per XSD.

The `firstunnamed` magic value passed to `-TabName` selects the first `<tab>` element with no `@name` attribute. Use it to delete the auto-stub tab Dataverse generates when an auto-`Information` Main form is customized — that stub has no name and no usable id.

### RenameForm

Rename a form by patching `systemforms.name`. Form **display names live on the systemforms record**, not in formxml — so `Update-FormXml` cannot rename a form. Use `RenameForm` when an auto-created `Information` Main form needs to follow the `Client | Form Type | Purpose` HSO convention.

```powershell
-Operation RenameForm -FormId "723d5ce1-c315-4c1b-af9a-d0711a60bc6a" `
    -FormName "HSO | Main | Client Intake"
```

**Parameters:**
- `FormId` (required) — GUID of the form to rename
- `FormName` (required) — new display name (follow the `Client | Form Type | Purpose` convention)

### RenameSection

Update a section's displayed label and/or its `@name` attribute inside form XML. Caller must supply at least one of `-SectionLabel` or `-NewSectionName`.

> **⚠️ Prefer `-SectionLabel` alone.** Changing `@name` (via `-NewSectionName`) breaks any code that references the section by name — form scripts, business rules, anything that calls `Xrm.Page.ui.tabs.get(...).sections.get('<oldName>')`. Only change `@name` when intentionally aligning with a naming convention AND you have verified no callers reference the existing name.

```powershell
# Common case — change the displayed label only (safe)
-Operation RenameSection -FormId "..." `
    -TabName "tab_overview" -SectionName "section_overview" `
    -SectionLabel "Overview"

# Change @name only — only when realigning with a naming convention
-Operation RenameSection -FormId "..." `
    -TabName "tab_overview" -SectionName "section_overview" `
    -NewSectionName "tab_overview_section_overview"

# Change both at once
-Operation RenameSection -FormId "..." `
    -TabName "tab_overview" -SectionName "section_overview" `
    -NewSectionName "tab_overview_section_overview" `
    -SectionLabel "Overview"
```

**Parameters:**
- `FormId` (required) — GUID of the form
- `TabName` (required) — containing tab; supports the `firstunnamed` magic value
- `SectionName` (required) — current `@name` of the section
- `NewSectionName` (optional) — new `@name` for the section. Omit when only changing the label.
- `SectionLabel` (optional) — new label `description` attribute. Omit when only changing `@name`.
- At least one of `-NewSectionName` or `-SectionLabel` must be supplied.

### SetTabProperties

Set tab-level properties beyond label.

```powershell
-Operation SetTabProperties -FormId "..." -TabName "tab_details" `
    -TabVisible "false" -TabExpanded $true `
    -TabAvailableForPhone "true" -TabCollapsible "true"
```

**Parameters:** `TabLabel`, `TabVisible`, `TabExpanded`, `TabAvailableForPhone`, `TabCollapsible` (all optional, at least one required)

### AddSection / RemoveSection / MoveSection

```powershell
-Operation AddSection -FormId "..." -TabName "tab_general" `
    -SectionName "section_contacts" -SectionLabel "Contact Information" `
    -SectionColumns 2

-Operation RemoveSection -FormId "..." -TabName "tab_general" `
    -SectionName "section_contacts"

-Operation MoveSection -FormId "..." -TabName "tab_general" `
    -SectionName "section_comments" -SectionPosition 0
```

### SetSectionProperties

```powershell
-Operation SetSectionProperties -FormId "..." -TabName "tab_general" `
    -SectionName "section_details" -SectionVisible "false" `
    -SectionColumns 3 -SectionAutoExpand "true"
```

**Parameters:** `SectionLabel`, `SectionVisible`, `SectionAvailableForPhone`, `SectionAutoExpand`, `SectionHeight`, `SectionColumns`, `SectionShowLabel` (all optional, at least one required)

### AddFields

Add fields to an existing section. Fields can be simple strings (auto-detects type from suffix) or hashtables with explicit type.

```powershell
# Simple - field names only (type auto-detected from suffix)
-Operation AddFields -FormId "..." -TabName "tab_general" `
    -SectionName "section_classification" `
    -Fields @("hso_name", "hso_type_code", "hso_account_id")

# With explicit labels and types
-Operation AddFields -FormId "..." -TabName "tab_general" `
    -SectionName "section_classification" `
    -Fields @(
        @{Name="hso_name"; Label="Contract Name"; Type="String"},
        @{Name="hso_type_code"; Label="Type"; Type="Picklist"},
        @{Name="hso_account_id"; Label="Account"; Type="Lookup"}
    )
```

**Field type auto-detection by suffix:** See [shared/dv/agent/wiki/sop/dataverse-naming-conventions.md](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) for the full suffix-to-type mapping.

### RemoveField

Remove a field from the form body (tabs only; use RemoveHeaderField/RemoveFooterField for header/footer).

```powershell
-Operation RemoveField -FormId "..." -FieldName "hso_obsolete_field_text"
```

### MoveField

Move a field to a different section (optionally at a specific position).

```powershell
-Operation MoveField -FormId "..." -FieldName "hso_account_id" `
    -TargetTabName "tab_details" -TargetSectionName "section_main" `
    -FieldPosition 0
```

**Parameters:**
- `FieldName` - Field to move (required)
- `TargetTabName` - Destination tab (required)
- `TargetSectionName` - Destination section (required)
- `FieldPosition` - 0-based position in target section (optional, appends if omitted)

### UpdateField

Set field display properties on the form.

```powershell
# Basic properties
-Operation UpdateField -FormId "..." -FieldName "hso_name" `
    -FieldReadOnly "true" -FieldShowLabel "false"

# Layout properties
-Operation UpdateField -FormId "..." -FieldName "hso_description_memo" `
    -FieldColspan 2 -FieldRowspan 5

# Form-level requirement override
-Operation UpdateField -FormId "..." -FieldName "hso_account_id" `
    -FieldIsRequired "true"
```

**Parameters:** `FieldShowLabel`, `FieldReadOnly`, `FieldVisible`, `FieldColspan`, `FieldRowspan`, `FieldAvailableForPhone`, `FieldIsRequired` (all optional, at least one required)

### AddHeaderField / RemoveHeaderField

```powershell
-Operation AddHeaderField -FormId "..." -FieldName "hso_status_code" `
    -FieldType "Picklist"

-Operation RemoveHeaderField -FormId "..." -FieldName "hso_status_code"
```

### AddFooterField / RemoveFooterField

```powershell
-Operation AddFooterField -FormId "..." -FieldName "ownerid" `
    -FieldType "Lookup"

-Operation RemoveFooterField -FormId "..." -FieldName "ownerid"
```

### AddHiddenField / RemoveHiddenField

Hidden fields are available to form scripts but not rendered in the UI.

```powershell
-Operation AddHiddenField -FormId "..." -FieldName "hso_internal_flag_yn"

-Operation RemoveHiddenField -FormId "..." -FieldName "hso_internal_flag_yn"
```

### AddSubgrid

```powershell
-Operation AddSubgrid -FormId "..." -TabName "tab_rates" `
    -SectionName "section_rates" -SectionLabel "Rates" `
    -SubgridName "subgrid_rates" -SubgridLabel "Contract Rates" `
    -RelatedTable "hso_contractrate" -RelationshipName "hso_contract_contractrate" `
    -ViewId "6b6a8881-..."
```

**ViewId is optional** — if omitted, the skill auto-selects the default public view for the related table and warns you. You should replace this with a dedicated subgrid view that excludes the parent lookup column.

**Defaults:** `HideSearchBox = $true` (search box hidden), `EnableViewPicker = $false`.

If the section doesn't exist, it is created automatically.

### ConfigureSubgrid

Set advanced parameters on an existing subgrid.

```powershell
-Operation ConfigureSubgrid -FormId "..." -SubgridName "subgrid_rates" `
    -SubgridAutoExpand "Auto" -SubgridEnableChartPicker "true" `
    -SubgridEnableContextualActions "true"

# Disable the view picker (hide the view-selector dropdown from the subgrid toolbar)
-Operation ConfigureSubgrid -FormId "..." -SubgridName "subgrid_rates" `
    -SubgridEnableViewPicker "false"
```

**Parameters:** `SubgridAutoExpand` (Auto/Fixed/AutoWithFixedMax), `SubgridMaxRowsBeforeScroll`, `SubgridEnableJumpBar`, `SubgridChartGridMode`, `SubgridVisualizationId`, `SubgridEnableChartPicker`, `SubgridEnableContextualActions`, `SubgridHeaderColorCode`, `SubgridEnableViewPicker` ("true"/"false" — controls the view-selector dropdown on the subgrid toolbar; default inherited from the existing XML, typically "false" for HSO subgrids), `ViewId`, `RecordsPerPage`

### AddTimeline

The timeline control must be in its own dedicated section. Standard practice is to place it in `section_timeline` on its own tab or as the last section in a tab.

```powershell
-Operation AddTimeline -FormId "..." -TabName "tab_timeline" `
    -SectionName "section_timeline" -SectionLabel "Timeline" `
    -ControlName "notescontrol" -ControlRowspan 25
```

Minimal usage (all defaults):
```powershell
-Operation AddTimeline -FormId "..." -TabName "tab_timeline"
```

### AddFormComponent

Embed a related entity's main form inline using the Form Component Control.

```powershell
-Operation AddFormComponent -FormId "..." -TabName "tab_details" `
    -SectionName "section_provider" -FieldName "hso_account_id" `
    -RelatedTable "account" -RelatedFormId "8448b78f-..." `
    -ControlName "formcomponent_account" -ControlRowspan 20
```

### AddWebResource

Embed a web resource (HTML page, image, JS visualization) on a form.

```powershell
-Operation AddWebResource -FormId "..." -TabName "tab_details" `
    -SectionName "section_custom" -SectionLabel "Custom View" `
    -ControlName "webresource_customview" `
    -WebResourceUrl "hso_/html/CustomView.html" `
    -WebResourcePassParameters $true -WebResourceHeight 300 `
    -ControlRowspan 10
```

**Parameters:**
- `ControlName` - Unique control ID (required)
- `WebResourceUrl` - Web resource name (required, e.g., `hso_/html/page.html`)
- `WebResourcePassParameters` - Pass record context to web resource (default: false)
- `WebResourceHeight` - Height in pixels (default: 150)
- `WebResourceWidth` - Width in pixels (optional)
- `WebResourceBorder` - Show border (default: true)
- `ControlRowspan` - Row span for the control (default: 25)

### AddQuickViewControl

Add a Quick View Form control to display related record data inline.

```powershell
-Operation AddQuickViewControl -FormId "..." -TabName "tab_general" `
    -SectionName "section_parent" -SectionLabel "Parent Details" `
    -ControlName "qv_account" -FieldName "hso_account_id" `
    -QuickForms "a1b2c3d4-..."
```

**Parameters:**
- `ControlName` - Unique control ID (required)
- `FieldName` - Lookup field to the related entity (required)
- `QuickForms` - Comma-separated Quick View form GUIDs (required)

### AddPCFControl

Bind a deployed PCF control to a form field using the `<controlDescriptions>` pattern (the correct
Dataverse form XML approach). The field keeps its original classid; the PCF binding is stored in a
`<controlDescription forControl="{uniqueid}">` block linked to the field by a `uniqueid` GUID.

**Prerequisites:**
1. The PCF control must already be deployed to the environment (`pac pcf push`).
2. The field must already exist on the form body (added via `AddFields`).

```powershell
# Bind HsosolStatusBadge PCF control to hsosol_status_code on a task form
-Operation AddPCFControl `
    -FormId "3df12d23-6c9e-482e-825b-57f0c601333d" `
    -FieldName "hsosol_status_code" `
    -PCFControlName "hsosol_HSOUSSolutionsTeam.Dynamics.PCF.HsosolStatusBadge" `
    -PCFParametersJson '{"statusvalue":"hsosol_status_code"}' `
    -FormFactors @(0,1,2)
```

**Parameters:**
- `-FieldName` — `datafieldname` of the field to bind (required)
- `-PCFControlName` — Fully qualified deployed control name, e.g. `hsosol_HSOUSSolutionsTeam.Dynamics.PCF.HsosolStatusBadge` (required). Query from Dataverse: `customcontrols?$select=name&$filter=contains(name,'ControlName')`
- `-PCFParametersJson` — JSON object mapping PCF property names to bound field names, e.g. `'{"propertyName":"fieldLogicalName"}'`
- `-PCFVersion` — Version string (default: `"1.0.0"`)
- `-FormFactors` — Array of form factors to configure: `0`=Web/Desktop, `1`=Phone, `2`=Tablet (default: `@(0,1,2)`)
- `-SkipPublish` — Switch to skip PublishXml after patching (useful for batching multiple changes)

> ⚠️ **Known limitation:** The `type` attribute on PCF parameter XML elements is hardcoded to
> `"SingleLine.Text"`. For bound properties of other types (Integer, OptionSet, Lookup), the binding
> may not render as expected in all form configurations.

### RemovePCFControl

Remove a PCF binding from a form field. Strips the `<controlDescription forControl="...">` block
matching the field's `uniqueid`, clears the `uniqueid` attribute from the cell control, and
publishes (the cell keeps its original classid, so the field reverts to its default control —
e.g. a string field reverts to a single-line text box).

```powershell
-Operation RemovePCFControl `
    -FormId "738ec649-b6b2-4c2d-b366-a3ce966d319e" `
    -FieldName "hso_name"
```

**Parameters:**
- `-FieldName` — `datafieldname` of the field to unbind (required)
- `-SkipPublish` — Switch to skip PublishXml after patching (useful for batching)

Idempotent: if the field has no `uniqueid` or no matching `<controlDescription>`, the operation
reports nothing-to-remove and exits cleanly.

### ConfigureLookup

Set lookup-specific parameters on an existing lookup field.

```powershell
# Filtered lookup
-Operation ConfigureLookup -FormId "..." -FieldName "hso_contact_id" `
    -LookupFilterRelationship "hso_account_contacts" `
    -LookupDependentAttribute "hso_account_id" `
    -LookupDependentAttributeType "Lookup"

# Restrict views and disable MRU
-Operation ConfigureLookup -FormId "..." -FieldName "hso_product_id" `
    -LookupDefaultViewId "abcd1234-..." `
    -LookupDisableMru "true" -LookupDisableViewPicker "true"
```

**Parameters:** `LookupDefaultViewId`, `LookupFilterRelationship`, `LookupDependentAttribute`, `LookupDependentAttributeType`, `LookupDisableMru`, `LookupDisableQuickFind`, `LookupDisableViewPicker`, `LookupAvailableViewIds`, `LookupAllowFilterOff`, `LookupIsInlineNewEnabled`

### AddSpacer

Add a spacer control for visual spacing in multi-column layouts.

```powershell
-Operation AddSpacer -FormId "..." -TabName "tab_general" `
    -SectionName "section_details"
```

### SetFormProperties

Set form-level attributes.

```powershell
-Operation SetFormProperties -FormId "..." `
    -FormShowImage "false" -FormMaxWidth 1200 `
    -FormEnableRelatedInfo "true" -FormRelatedInfoCollapsed "true"
```

**Parameters:** `FormShowImage`, `FormShowNavBar`, `FormMaxWidth` (min 400), `FormEnableRelatedInfo`, `FormRelatedInfoCollapsed`, `FormHasMargin`

### AddFormEvent

Add an event handler. Auto-registers the library if not already on the form. Supports form-level, tab-level, and cell-level events.

```powershell
# Form-level OnLoad
-Operation AddFormEvent -FormId "..." -EventName "onload" `
    -FunctionName "onFormLoad" -LibraryName "hso_/scripts/ContractForm.js" `
    -PassExecutionContext $true

# OnChange (field-level, requires EventAttribute)
-Operation AddFormEvent -FormId "..." -EventName "onchange" `
    -EventAttribute "hso_type_code" -FunctionName "onTypeChange" `
    -LibraryName "hso_/scripts/ContractForm.js" `
    -PassExecutionContext $true

# Tab-level event (ontabstatechange)
-Operation AddFormEvent -FormId "..." -EventName "ontabstatechange" `
    -EventTabName "tab_details" -FunctionName "onTabStateChange" `
    -LibraryName "hso_/scripts/ContractForm.js"

# Cell-level event
-Operation AddFormEvent -FormId "..." -EventName "onchange" `
    -EventControlName "hso_status_code" -FunctionName "onStatusChange" `
    -LibraryName "hso_/scripts/ContractForm.js"

# With handler parameters
-Operation AddFormEvent -FormId "..." -EventName "onload" `
    -FunctionName "onFormLoad" -LibraryName "hso_/scripts/ContractForm.js" `
    -EventParameters "config=strict;mode=edit"
```

**Parameters:**
- `EventName` - Event type: `onload`, `onsave`, `onchange`, `ontabstatechange` (required)
- `FunctionName` - JavaScript function name (required)
- `LibraryName` - Web resource name (required, auto-registered if missing)
- `EventAttribute` - Field name for onchange events
- `PassExecutionContext` - Pass execution context (default: true)
- `EventParameters` - Static parameter string passed to handler (optional)
- `EventTabName` - Tab name for tab-level events (optional)
- `EventControlName` - Control name for cell-level events (optional)

### RemoveFormEvent

Remove a handler from an event, or remove the entire event.

```powershell
# Remove specific handler
-Operation RemoveFormEvent -FormId "..." -EventName "onload" `
    -FunctionName "onFormLoad" -LibraryName "hso_/scripts/ContractForm.js"

# Remove entire onchange event for a field
-Operation RemoveFormEvent -FormId "..." -EventName "onchange" `
    -EventAttribute "hso_type_code"

# Remove ONE of several duplicate registrations of the same function
-Operation RemoveFormEvent -FormId "..." -EventName "onload" `
    -HandlerUniqueId "{a1b2c3d4-...}"
```

**Duplicate registrations.** When a form has registered the same `FunctionName` more
than once, matching by name is ambiguous — the operation refuses rather than guessing,
and lists the `handlerUniqueId` of each candidate:

```
Found 2 handlers matching 'onFormLoad' on event 'onload'.
Re-run with -HandlerUniqueId to pick one. Candidates: {a1b2...}, {e5f6...}
```

Re-run with `-HandlerUniqueId` (braces optional) to remove exactly one, leaving the
other registration intact. **That refusal message is where the ids come from** — run the
name-based removal first and let it refuse. `AnalyzeForm` does not help here: it lists
handlers as `libraryName::functionName` (plus context and parameters) and never prints
`handlerUniqueId`, which is precisely the attribute duplicates differ by.

### AddFormLibrary / RemoveFormLibrary

```powershell
-Operation AddFormLibrary -FormId "..." `
    -LibraryName "hso_/scripts/ContractForm.js"

-Operation RemoveFormLibrary -FormId "..." `
    -LibraryName "hso_/scripts/OldScript.js"
```

`RemoveFormLibrary` will error if event handlers still reference the library. Remove event handlers first.

### SetDisplayConditions

Configure which security roles can see this form.

```powershell
# Restrict to specific roles
-Operation SetDisplayConditions -FormId "..." `
    -DisplayConditionRoles @("role-guid-1", "role-guid-2") `
    -FallbackFormId "fallback-form-guid" -DisplayOrder 1

# Reset to everyone
-Operation SetDisplayConditions -FormId "..."
```

### AddNavItem / RemoveNavItem

Manage form navigation pane items.

```powershell
# Add relationship-based nav item
-Operation AddNavItem -FormId "..." `
    -NavItemRelationship "hso_contract_contractrate" `
    -NavItemLabel "Contract Rates"

# Add custom URL nav item
-Operation AddNavItem -FormId "..." `
    -NavItemLabel "External Portal" `
    -NavItemUrl "https://portal.example.com"

# Remove nav item
-Operation RemoveNavItem -FormId "..." `
    -NavItemRelationship "hso_contract_contractrate"
```

### AddFormToApp

```powershell
-Operation AddFormToApp -FormId "603991a3-..." `
    -AppModuleUniqueName "hso_myapp"
```

### QueryForms / QueryViews

```powershell
-Operation QueryForms -TableName "hso_contract"
-Operation QueryViews -TableName "hso_contract"
```

### CreateView / UpdateView / DeleteView

```powershell
# Create
# Array params are passed as a single comma-separated string so they bind correctly under `-File`
# on PowerShell 5.1 (see the array-parameter note under Quick Reference above).
-Operation CreateView -ViewName "Open Contracts" -TableName "hso_contract" `
    -ViewColumns "hso_contractnumber_text,hso_name,statuscode" `
    -ViewColumnWidths "150,200,100" -ViewSortBy "hso_contractnumber_text" `
    -SolutionName "EstimationSolution"

# Enforce the spec's per-view column floor at BUILD time (#407). Pass the view's spec.json
# floorMin/floorMax; the build emits [FLOOR-FAIL] and exits non-zero if the built view is outside it —
# catching an under-curated view here instead of waiting for the downstream grader.
-Operation CreateView -ViewName "Active Service Agreements" -TableName "hsot_serviceagreement" `
    -ViewColumns "hsot_name,hsot_customer_id,hsot_coveragetier_code,statuscode,hsot_startdate_date,hsot_enddate_date,hsot_annualvalue_amt,ownerid" `
    -ViewFloorMin 6 -ViewFloorMax 10 `
    -SolutionName "HSOServiceAgreements"

# Update display columns (preserves existing filters)
-Operation UpdateView -ViewName "Open Contracts" -TableName "hso_contract" `
    -ViewColumns "hso_contractnumber_text,hso_name,hso_account_id,statuscode" `
    -SolutionName "EstimationSolution"

# Update Quick Find view - set Find Columns (searchable fields)
# Auto-finds the Quick Find view for the table when only TableName + ViewFindColumns are provided
-Operation UpdateView -TableName "hso_contract" `
    -ViewFindColumns "hso_name,hso_contractnumber_text" `
    -SolutionName "MySolution"

# Update Quick Find view - set both Find Columns and display columns
-Operation UpdateView -TableName "hso_contract" `
    -ViewFindColumns "hso_name,hso_contractnumber_text" `
    -ViewColumns "hso_name,hso_contractnumber_text,createdon" `
    -ViewColumnWidths "200,150,125" `
    -SolutionName "MySolution"

# Delete
-Operation DeleteView -ViewName "Open Contracts" -TableName "hso_contract"

# Create view with linked entity columns (N:1 join — alias.field naming)
-Operation CreateView -ViewName "Narratives – Current & Prior Snapshot" -TableName "hsosol_narrative" `
    -ViewColumns @("hsosol_name_text", "hsosol_comparisondate_date", "hsosol_currentsnapshot_id", "hsosol_priorsnapshot_id", "statuscode") `
    -ViewColumnWidths @(150, 150, 150, 150, 120) `
    -ViewLinkedColumns @(
        @{ Alias="currentsnapshot"; LookupField="hsosol_currentsnapshot_id"; RelatedTable="hsosol_narrativesnapshot"; Columns=@("hsosol_periodtype_code","hsosol_periodstart_date"); Widths=@(150,120) },
        @{ Alias="priorsnapshot";   LookupField="hsosol_priorsnapshot_id";   RelatedTable="hsosol_narrativesnapshot"; Columns=@("hsosol_periodstart_date"); Widths=@(120) }
    ) `
    -SolutionName "HSONarrativeSnapshot"

# Update existing view — add linked columns to an existing view
-Operation UpdateView -ViewId "..." -TableName "hsosol_narrative" `
    -ViewColumns @("hsosol_name_text", "hsosol_comparisondate_date", "hsosol_currentsnapshot_id", "statuscode") `
    -ViewColumnWidths @(150, 150, 150, 120) `
    -ViewLinkedColumns @(
        @{ Alias="currentsnapshot"; LookupField="hsosol_currentsnapshot_id"; RelatedTable="hsosol_narrativesnapshot"; Columns=@("hsosol_periodtype_code","hsosol_periodstart_date"); Widths=@(150,120) }
    ) `
    -SolutionName "HSONarrativeSnapshot"

# Raw XML passthrough — UpdateView only; bypasses all XML generation (multi-level joins, non-standard link types)
-Operation UpdateView -ViewId "..." `
    -ViewRawFetchXml '<fetch version="1.0" ...>...</fetch>' `
    -ViewRawLayoutXml '<grid name="resultset" ...>...</grid>' `
    -SolutionName "HSONarrativeSnapshot"
```

**Quick Find View Notes:**
- `ViewFindColumns` sets which columns are searched via Quick Find (the `isquickfindfields` filter)
- When `ViewFindColumns` is provided with just `-TableName`, the Quick Find view is auto-discovered (querytype=4)
- Quick Find views require `name`, `description`, and `returnedtypecode` in every PATCH — these are automatically included
- The existing fetchxml structure (filters, sort order, `savedqueryid`) is preserved via XML parsing

**Lookup View Notes:**
- `CreateView -ViewType Lookup` routes to `UpdateView` on the table's existing querytype=64 lookup view (every table ships one) — it never creates a Public duplicate. A new lookup view is only created if none exists. A `PublicView` whose name matches that OOB lookup view emits a `[WARN]` (declare it `-ViewType Lookup` instead).

**Linked Column Notes:**
- Each `-ViewLinkedColumns` entry is a hashtable: `Alias`, `LookupField`, `RelatedTable`, `Columns` (required); `Widths` and `LinkType` are optional
- FetchXML join convention: `from` = PK on the related table (`{relatedTable}id`), `to` = lookup field on the primary entity
- Linked cells appear in LayoutXML as `alias.fieldname` (e.g. `currentsnapshot.hsosol_periodtype_code`)
- **Linked-entity columns (`alias.field`) are not sortable.** Dataverse silently disables the sort arrow on these cells — do not set `-ViewSortBy` to a linked column name
- `LinkType` defaults to `"outer"` if omitted; `Widths` defaults each cell to `100` if omitted or short
- Linked columns are supported on regular (Public/Associated/Lookup) views only — not Quick Find views
- `-ViewRawFetchXml` / `-ViewRawLayoutXml` are available on `UpdateView` as a permanent escape hatch for edge cases (multi-level joins, non-standard link types) — they bypass all XML generation for that field and take priority over `-ViewLinkedColumns`

**Batch publishing:** Each `UpdateView` call publishes the table's customizations. When updating many
views across multiple tables, use `-SkipPublish` to defer publishing and call `PublishForm` manually
at the end to reduce redundant `PublishXml` round-trips:
```powershell
-Operation UpdateView -ViewId "..." -ViewColumns @(...) -SkipPublish
# ... repeat for other views ...
-Operation PublishForm -TableName "hsosol_catalogfamily"  # publish once per table
```

**TableName optional when ViewId is known:** If you pass `-ViewId` directly, `-TableName` can be
omitted -- the skill resolves the table name from the existing view's `returnedtypecode`.

---

## Sitemap Operations

> **`-SpecJsonPath` is an orchestration convenience for spec-driven builds; every op here also works from explicit
> params / inline input — spec.json is never required.**
>
> **`BuildSiteMap` builds the whole app+sitemap in one write, via either path:** `BuildSiteMap -SpecJsonPath <spec.json>`
> when you have an architect spec (uses its `.app` node), OR `BuildSiteMap -AppSpec <inline JSON | file>` when you're
> building directly (the `app` object itself). Both **self-create the app** (exact `uniqueName`/prefix) and render the
> whole sitemap from the declared contract in one write. BuildSiteMap self-creates the app from the definition, so you
> don't NEED a separate `CreateApp` first; creating the app directly is fine for non-spec/manual setup. **After
> `BuildSiteMap` reports success, don't re-PATCH the whole sitemap** — over-editing clobbers the just-built sitemap.
> `AddSiteMapSubArea` / `UpdateSubArea` / `MoveSiteMapGroup` are **targeted edits** — the right tool when you're
> adjusting one node and don't want to rebuild the whole sitemap (exactly as the per-op FORM functions relate to `BuildForm`).

### BuildSiteMap

Assemble the **entire `<SiteMap>` from the `app` definition** (from `-SpecJsonPath`'s `.app` node or from `-AppSpec`
directly; areas → groups → sub-areas, **in declared order**) in memory, write it in **one PATCH + publish**, then
**read back and diff** (every declared sub-area is
present, and the order matches). Single-writer, so it is structurally immune to the per-mutation clobber that
concurrent single-sub-area edits risk.

**App membership is part of the contract, on every path.** Before rendering, `BuildSiteMap` registers **every
declared table** — each sub-area `entity` **plus** every `app.unsurfacedTables[].table` (no nav node, but a subgrid
cannot open records of a table the app does not contain) — as an app component via one `AddAppComponents` call,
in **all three** situations: create-new, **create-mode with an app that already exists** (created by an earlier
slice, a previous run, or by hand — this path used to skip registration and shipped a sitemap whose reference-table
sub-areas pointed at tables the app did not contain, E2E round-3 F-02), and extend. The read-back then diffs
`appmodulecomponents` (componenttype 1) against the declared table set — `[OK] app-components read-back: all N
declared table(s) are app components` or `[APP-DIFF] … NOT registered as app components` — and calls
`ValidateApp` best-effort (`[OK] ValidateApp: clean` / `[APP-DIFF] ValidateApp reported N issue(s)`). **A slice
whose acceptance says "every spec table is in the app" quotes these two lines** — that is the read-back evidence;
per-slice `AddTableToApp` calls from entity slices are NOT the pattern (`SaveAppModule` replaces the app's element
set — a call listing only the new tables drops the old ones — and the app is a single-writer artifact; see the
data-modeling skill §11.2). The membership read-back is taken against the **published generation** of the app
(`appmoduleidunique` differs per generation — an unpublished draft can carry tables the published app lacks;
`[INFO] unpublished draft generation … differs` names it, `[APP-DIFF] … no PUBLISHED generation` means publish is
pending). Self-create waits for the freshly-POSTed app module to become addressable and retries `AddAppComponents`
on `Does Not Exist` (a read-after-write race that twice orphaned an unpublished app in round-3 s01).

**`AddSiteMapSubArea -SubAreaEntity` registers the table as an app component too** (idempotent `AddAppComponents`
before the publish) — a nav node pointing at a table the app does not contain is unreachable, and this surgical op
was how round-3's 13 reference-table sub-areas shipped without their tables in the app.

**Self-creates the app if missing:** when no app module matches `app.uniqueName` (unpublished-aware), it CREATES the app (POSTs the appmodule, adds every declared sub-area entity, seeds a sitemap) before building — so a missing/misnamed app can't break the build (emits `[APP] created app module '<uniqueName>'`).

**`app.mode` — `create` (default) vs `extend`:** `create` builds a NEW app (self-create as above). `extend` adds to an **existing** app that you must NOT create — use it for a **non-copyable OOB app** (e.g. the Customer Service workspace); set `app.uniqueName` to that existing app's unique name. In extend mode the target must already exist (else a clear `throw`), and the declared tables are ADDED to it as app components before the sitemap is rendered (emits `[APP] extend mode -- using existing app '<uniqueName>'`).

```powershell
# spec-driven (uses the spec's .app node):
-Operation BuildSiteMap -SpecJsonPath "<path>\spec.json" [-AppModuleUniqueName <name>] [-DryRun]
# direct / non-spec (the app object itself, inline or a file path):
-Operation BuildSiteMap -AppSpec '{ "uniqueName":"...", "title":"...", "areas":[...] }' [-AppModuleUniqueName <name>] [-DryRun]
```

- **`-SpecJsonPath`** — a `spec.json` whose `.app` node drives the build. Schema:
  `app: { uniqueName?, title?, mode?, areas:[{ id?, title, groups:[{ id?, title, subAreas:[{ id?, title, entity?, url?, viewId?, dashboard? }] }] }] }` (`mode`: `create` default | `extend`).
- **`-AppSpec`** — the **same `app` object** as above, passed directly as inline JSON or a file path (no spec.json needed).
  Pass exactly one of `-SpecJsonPath` / `-AppSpec`.
- **`-AppModuleUniqueName`** — target app; omit to use `uniqueName` from the app definition.
- A sub-area with `dashboard` (the dashboard's SystemForm GUID) renders the classic, XSD-valid dashboard shape
  (`Url` + `DefaultDashboard`; `url` optionally overrides the default dashboard page URL); `entity` + `viewId` is
  bound to that view (URL form); `entity` alone is an entity sub-area; `url` is a URL sub-area. IDs auto-generate
  when omitted. A sub-area matching **none** of these shapes fails the build with the keys it saw — nothing is
  silently dropped.
- **`-DryRun`** — assemble + print the declared sub-areas without writing.

Read-back reports `[SITEMAP-DIFF]` if any declared sub-area is missing or the order drifted.

### GetSiteMap

Display the full sitemap structure for an app — all areas, groups, and sub-areas with their IDs and entity/URL targets. **Always run this first** before adding or updating sub-areas so you know the exact `AreaId` and `GroupId` values.

```powershell
-Operation GetSiteMap -AppModuleUniqueName "hso_HSOFieldService"
```

Output shows the tree: `[Area] → [Group] → [SubArea]` with each node's `Id`, entity, and URL.

### AddSiteMapSubArea

Add a new sub-area to an existing area and group. If the group doesn't exist it is created automatically. If the area doesn't exist AND `-AreaTitle` is provided, the area is created at the SiteMap root before the group is created inside it. Auto-publishes the app module after saving.

```powershell
# URL-based sub-area (e.g. a web resource dashboard)
-Operation AddSiteMapSubArea `
    -AppModuleUniqueName "hso_HSOFieldService" `
    -AreaId "hso_Finance" `
    -GroupId "hso_DashboardsGroup" `
    -SubAreaId "hso_BrandPresidentDashboard" `
    -SubAreaTitle "Brand President" `
    -SubAreaUrl "/WebResources/hso_/html/dashboards/brand-president.html" `

# Entity-based sub-area
-Operation AddSiteMapSubArea `
    -AppModuleUniqueName "hso_HSOFieldService" `
    -AreaId "hso_Finance" `
    -GroupId "hso_RoyaltiesGroup" `
    -SubAreaId "hso_RoyaltySchedulesSub" `
    -SubAreaTitle "Royalty Schedules" `
    -SubAreaEntity "hso_royaltyschedule" `

# With a new group that doesn't exist yet (GroupTitle required)
-Operation AddSiteMapSubArea `
    -AppModuleUniqueName "hso_HSOFieldService" `
    -AreaId "hso_Finance" `
    -GroupId "hso_NewGroup" `
    -GroupTitle "New Group Label" `
    -SubAreaId "hso_NewSubArea" `
    -SubAreaTitle "My Sub-Area" `
    -SubAreaEntity "hso_mytable" `

# With a new area that doesn't exist yet (AreaTitle + GroupTitle required)
-Operation AddSiteMapSubArea `
    -AppModuleUniqueName "hso_HSOHomeHealthcare" `
    -AreaId "hso_clinical" -AreaTitle "Clinical" `
    -GroupId "hso_assessmentsgroup" -GroupTitle "Assessments" `
    -SubAreaId "hso_assessmentssub" `
    -SubAreaTitle "Assessments" `
    -SubAreaEntity "hso_assessment"

# Dashboard sub-area — surface a system dashboard (classic, XSD-valid: Url + DefaultDashboard)
-Operation AddSiteMapSubArea `
    -AppModuleUniqueName "hso_HSOHomeHealthcare" `
    -AreaId "hso_clinical" `
    -GroupId "hso_dashboardsgroup" -GroupTitle "Dashboards" `
    -SubAreaId "hso_opsdashsub" `
    -SubAreaTitle "Operations Overview" `
    -SubAreaDefaultDashboard "1a2b3c4d-0000-0000-0000-000000000001"
```

**Parameters:**
- `AppModuleUniqueName` - App module unique name (required)
- `AreaId` - Existing or new area ID (required)
- `AreaTitle` - Display label for the area — only needed when creating a new area; without it, a missing area still throws the original "not found" error (backwards-compatible)
- `GroupId` - Existing or new group ID (required)
- `GroupTitle` - Display label for the group — only needed when creating a new group
- `SubAreaId` - Unique ID for the new sub-area (required, use `hso_` prefix)
- `SubAreaTitle` - Display label shown in the navigation (required)
- `SubAreaUrl` - URL for URL-based sub-areas (required if not using `SubAreaEntity`/`SubAreaDefaultDashboard`)
- `SubAreaEntity` - Entity logical name for entity-based sub-areas
- `SubAreaDefaultDashboard` - **Dashboard GUID** to surface a system dashboard. Renders the classic, XSD-valid shape `Url + DefaultDashboard` — **never** the app-designer `Type="Dashboard"`, which the classic sitemap XSD rejects (lessons §9). If `SubAreaUrl` is omitted, the Url defaults to `/main.aspx?pagetype=dashboard&dashboardId=<guid>`. This is what makes a built dashboard *reachable* — see the architect `dashboards[].surfacedVia` contract.

**Notes:**
- New sub-areas are appended to the end of the group
- Throws if a sub-area with the same `SubAreaId` already exists — use `UpdateSubArea` to modify existing ones
- Web resource sub-areas use the path `/WebResources/hso_/html/...` (with `/WebResources/` prefix, unlike the web resource name used in deployment)
- A sub-area opens exactly one target: pass one of `SubAreaEntity`, `SubAreaUrl`, or `SubAreaDefaultDashboard`

### UpdateSubArea

Change an existing sub-area to point to a specific view URL. Useful for switching an entity sub-area to a filtered view.

```powershell
# Update to a specific view by entity + viewId
-Operation UpdateSubArea `
    -AppModuleUniqueName "hso_HSOFieldService" `
    -SubAreaId "hso_BillingEvents" `
    -SubAreaEntity "hso_billingevent" `
    -SubAreaViewId "3de8cd5e-5c30-f111-88b4-000d3a341b5f" `

# Update to an explicit URL
-Operation UpdateSubArea `
    -AppModuleUniqueName "hso_HSOFieldService" `
    -SubAreaId "hso_BillingEvents" `
    -SubAreaUrl "/main.aspx?etn=hso_billingevent&pagetype=entitylist&viewid=%7b3de8cd5e-5c30-f111-88b4-000d3a341b5f%7d"
```

**Parameters:**
- `AppModuleUniqueName` - App module unique name (required)
- `SubAreaId` - ID of the sub-area to update (required)
- `SubAreaEntity` + `SubAreaViewId` - Builds the URL automatically (recommended form)
- `SubAreaUrl` - Explicit URL override (alternative to entity + viewId)

---

## Important Rules

> Subgrid rules (public view querytype 0, dedicated parent-excluding view, auto-pick fallback) live once
> in [Subgrid Standards](#subgrid-standards) above; the querytype map is in [View Types](#view-types-savedqueryquerytype) below.

### View Naming - Reserved Names

The "Active {TableName}" view's **name and filter** are **reserved** for the system default view —
do not rename it and do not edit its filter (the Views SOP states *"Do not edit this view's filter.
It is reserved."*). **Its columns are NOT reserved.** The auto-generated `Active X` / `Inactive X`
system views ship with **only the primary name column**, and that is not deliverable: curate them to
**6–10 columns** via `UpdateView` (the floor for a default Public view) before delivery.

| View Name | Filter | Correct? |
|-----------|--------|----------|
| Active Contracts | statecode = Active | System default |
| Open Contracts | statecode = Active AND status = Open | Descriptive name |
| Active Contracts | statecode = Active AND status = Open | Don't modify the Active view's filter |

### View Types (SavedQueryQueryType)

| Type | querytype | Use For |
|------|-----------|---------|
| MainApplicationView | 0 | Main grids, subgrids, default entity views |
| AdvancedSearch | 1 | Advanced Find queries |
| SubGrid | 2 | Associated/sub-grid views |
| QuickFindSearch | 4 | Quick Find search columns (Find Columns) |
| LookupView | 64 | Lookup dialogs |

(Full `SavedQueryQueryType` enum — Reporting 8, Offline 16, etc. — in the Views SOP.)

## Authentication

Uses MSAL.PS with token caching (~1 hour validity). First call opens browser for O365 login; subsequent calls use cached token.

---

## UI Design Guidelines

UI/UX design reviews of custom UI embedded into forms (PCF controls, web resources, HTML/JS) — Fluent UI / Dynamics 365 visual language, WCAG 2.1 AA, the review checklist + response structure — live on-demand in [`references/ui-review.md`](references/ui-review.md). Form layout itself goes to the Forms SOP (see [Authoritative Best Practices](#authoritative-best-practices)).
