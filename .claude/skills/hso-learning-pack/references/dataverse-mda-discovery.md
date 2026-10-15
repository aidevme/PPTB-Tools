# Discovering a model-driven Dataverse app — the how-to

Read this before **Phase 1 Step 2**. It maps every part of a model-driven app to where it lives in the solution export and which `hso-dataverse-*` skill fills a gap when the export isn't enough. The goal is a **solution-anchored feature inventory**: every claim in the pack traces to a real component here.

The pack's accuracy lives or dies on this phase. A model-driven app is *generated from metadata*, so its truth is in the metadata — not in a spec, and not in your memory of how Dataverse usually works.

## The shape of a model-driven app

```
Solution (HSOBillingPlatform)
├── App module(s)          ← the thing users open ("HSO Field Service")
│   └── Sitemap            ← Areas → Groups → SubAreas (the navigation = pillar candidates)
├── Tables (entities)      ← the nouns: hso_customersubscription, hso_billingevent, …
│   ├── Columns/attributes ← fields, incl. choice columns whose option-set values are the app's vocabulary
│   ├── Relationships      ← lookups + 1:N/N:N (the graph the subgrids and forms navigate)
│   ├── Forms              ← what a user sees/edits per record (tabs, sections, subgrids, BPF)
│   └── Views (SavedQueries)← the grids/lists surfaced in the sitemap
├── Dashboards + charts    ← roll-up surfaces
├── Business process flows ← guided stage-by-stage workflows across one or more tables
├── Custom pages           ← Power-Fx/canvas pages embedded in the app
├── Security roles         ← who can see/do what (and which roles the app is shared with)
├── Plugins + SDK steps    ← server-side business logic (the verbs)
├── Power Automate flows   ← no-code automation + integration
└── Web resources / PCF    ← client-side scripts and custom controls
```

A model-driven app is **declarative UI over a data model, extended by code**. Your job is to narrate that for five different audiences without inventing a single field.

## Where each component lives in the export

Paths are relative to `Solutions/<SolutionName>/`.

| Component | Path in export | What to read it for |
|---|---|---|
| App module | `AppModules/<app_uniquename>/AppModule.xml` | App unique name, display name, description, **AppModuleId** (for deep-link URLs), client type |
| Sitemap | `AppModuleSiteMaps/<app>/AppModuleSiteMap.xml` | Areas → Groups → SubAreas — your **pillar candidates** and which tables/dashboards are surfaced |
| Table | `Entities/<Entity>/Entity.xml` | Logical + display name, ownership, description, primary column |
| Columns | `Entities/<Entity>/Entity.xml` (attributes) | Field list, types, required level; **choice columns + their option-set values** = the domain vocabulary |
| Forms | `Entities/<Entity>/FormXml/` (or `Forms/`) | Tabs, sections, columns, **subgrids**, quick-view controls, BPF placement, form scripts. This is your screen-walkthrough source even without a screenshot |
| Views | `Entities/<Entity>/SavedQueries/` | Columns shown, sort, filter (FetchXML) — what each grid lists |
| Dashboards | `Dashboards/` or `Entities/.../` (SystemForm Type=0) | Cells: charts, lists, web resources, Power BI tiles |
| Charts | `Entities/<Entity>/SavedQueryVisualizations/` | FetchXML + presentation of each system chart |
| BPF | a hidden table + `Workflows/` (category 4) | Stages, steps, and which tables the flow spans |
| Custom pages | `CanvasApps/` (referenced by sitemap) | Embedded Power-Fx pages |
| Security roles | `Roles/<role>.xml` | Table privileges per role (Create/Read/Write/Delete + access level) |
| Plugin steps | `SdkMessageProcessingSteps/` | Message + table + stage + filtering attributes — *when* a plugin fires |
| Plugin assemblies | `PluginAssemblies/` + `SourceCode/.../BusinessLogic/Services/` | *What* the plugin does — read the service classes |
| Flows | `Workflows/*.json` | Triggers, actions, connectors (integration edges) |
| Web resources | `WebResources/` | Form scripts, HTML/PCF resources |

> Solution folder layouts vary slightly by how the solution was unpacked (`pac solution unpack` vs. SolutionPackager) and by managed/unmanaged. If a path above is absent, `Grep`/`Glob` for the logical name — the component is there under a sibling folder.

## Which skill to use for a live-metadata gap

The export is a point-in-time snapshot and can omit derived detail (full option-set value lists, relationship schema names, which form is the *active* default, a view's resolved FetchXML). When you need ground truth, **use the skill, never a Dataverse MCP tool** (project rule), and route through `powershell.exe`:

| Gap | Skill | Operation |
|---|---|---|
| Table/column metadata, option-set values, relationships | `hso-dataverse-data-modeling` | metadata query / relationship discovery |
| Form structure (tabs/sections/fields/subgrids), view definitions | `hso-dataverse-ui-config` | `AnalyzeForm`, `GetSiteMap`, view queries |
| Dashboards + the charts they host | `hso-dataverse-dashboards` | dashboard/chart inspection |
| Security roles + privileges (and a role matrix doc) | `hso-dataverse-securityrole` | query roles, generate matrix |
| Actual record data to point screenshots at | `hso-dataverse-data` / `hso-fetchxml-queries` | OData / FetchXML queries |
| Custom API surface | `hso-dataverse-customapi` | list/inspect custom APIs |
| Flow documentation | `hso-dataverse-flow-docs` | generate flow docs (consume into feature guides) |
| Existing generated solution docs | `hso-solution-documentation` | the `Solutions/.docs/...` narrative, if present |

A higher-level solution-change view is available from `hso-analyze-dataverse-solution-changes` when you're documenting *what a PR added* rather than the whole app.

## Reading the wiki for the "why" (not the "what")

The solution tells you *what this app is*. The **shared/dv wiki** tells you what model-driven apps are *for* and how HSO builds them well — the language a first-time reader needs:

- `shared/dv/agent/wiki/topics/model-driven-apps.md` — the anchor (app strategy, sitemap, custom pages, command bar, theming, mobile/offline, ALM) + Microsoft Learn links.
- `shared/dv/agent/wiki/sop/model-driven-apps/` — app-module / form / view / dashboard configuration best practices. Cite these when the pack explains *why* a surface is built the way it is.
- Peer topics: `form-and-view-configuration.md`, `dashboards.md`, `security.md`, `dataverse-solutions.md`, `power-automate.md`, `plugin-development.md`.

Rule of thumb: an **app claim** ("the Billing Event form has a Collections tab") is sourced from the solution XML; a **methodology claim** ("keep the first form tab light so the form loads fast") is sourced from a wiki SOP — link it.

## Turning the inventory into pillars and features

- **Pillars** come first from the **sitemap Areas/Groups** (the makers' own grouping). Adjust only if an Area is too thin/broad — then fall back to a business-lifecycle or capability grouping (see SKILL.md "Picking pillars").
- **Features** are business capabilities, each backed by a *set* of components: a table or two, their forms, the plugins/flows that automate them, and the integration they touch. Example: a "Subscription Lifecycle" feature = `hso_subscriptionplan` + `hso_customersubscription` tables + their forms + the `SubscriptionLifecycleService` plugin + the renewal flow. One feature card, several components.
- **Surfaces** (screen library) are the individual forms/views/dashboards/BPF-stages — the *visible* leaves of the tree, one walkthrough page each.

## Common discovery mistakes (don't make these)

- ❌ Calling one **option-set value** a "feature." `CollectionStatus = Written Off` is a *state*, not a capability — the write-off *workflow* (its plugin + form + status reason) is the feature.
- ❌ Documenting a **standard Field Service / CE table** as if the custom solution built it. Name it, but foreground what *this* solution adds on top.
- ❌ Assuming a schema is narrow without reading it. Read the `Entity.xml` and the option sets before declaring anything "not supported" — a single flexible column often covers a case you'd have flagged as a gap.
- ❌ Describing a form tab that the **active** form doesn't have (an inactive/legacy form may differ). Confirm the active form via `hso-dataverse-ui-config` if unsure.
- ❌ Treating the spec/FDD as ground truth. When the spec and the solution disagree, the **solution wins** — and surface the disagreement to the user.
