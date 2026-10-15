---
name: hso-dataverse-dashboards
layer: atomic
scope: core
description: |
  Configure Dataverse model-driven app dashboards (`SystemForm` Type=0) and the system charts (`SavedQueryVisualization`) they consume. Covers dashboard component cells (chart, list, web-resource, PCF, Power BI tile), in-place cell layout adjustment (colspan / rowspan / records per page), system chart authoring from FetchXML + DataVisualization.Charting presentation, role scoping, per-app default dashboard, and publishing. Trigger phrases: "create/build dashboard", "system dashboard", "add chart to dashboard", "resize dashboard cell/component", "make the list full-width", "change colspan/rowspan", "Power BI tile", "default dashboard", "publish dashboard". Does NOT cover forms/views/sitemap/subgrids (see `hso-dataverse-ui-config`), personal dashboards, custom pages, or Power BI report authoring.
---

# Dataverse Dashboards Skill

Configure and manage Dataverse system dashboards and the system charts they consume, via the Web API.

This skill is the build-time companion to [`hso-dataverse-ui-config`](../hso-dataverse-ui-config/SKILL.md) (forms, views, sitemap). Dashboards are surfaced into a model-driven app's sitemap using the **sitemap operations on the ui-config skill** (`AddSiteMapSubArea` with a URL pointing to the dashboard) — this skill produces the dashboard; the ui-config skill wires it into the navigation.

---

## Slice Consumption Contract (executor side of the architect→builder pipeline)

**Authority:** [`slice-consumption-contract-best-practices.md`](../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md) — read before building any slice inside the pipeline. That SOP is the **canonical, executor-side contract** for [ADR 0018](../../../agent/wiki/decisions/0018-agentic-delivery-architect-builder-pipeline.md)'s architect→builder pipeline (the five rules, single-writer, reviewable-unit, anti-mis-attribution). The summary here is a labeled pointer, not a substitute.

When the architect routes a slice to this skill you are handed **the spec + its `spec.json` sidecar + a target slice `id`**. Build **exactly that slice's `touches`** and nothing more; trust and verify — don't rebuild — your `blocked_by` slices; honor every recorded design decision (which component cells, which charts, role scoping the spec set); **read back against the slice's `acceptance`, not against an SOP rule the spec never invoked**; and end at the **unmanaged solution** named in `spec.json` (never export-as-managed or deploy). A **shared dashboard** more than one slice would touch is a **single-writer** artifact — one writer in one downstream `assembly` slice, never concurrent edits.

| When a slice's `touches` include… | What this skill owns | Read-back against `acceptance` |
|---|---|---|
| a **system dashboard** + its component cells | the dashboard (`SystemForm` Type=0) + each component cell + the system charts (`SavedQueryVisualization`) it consumes; **single-writer** for a shared dashboard | dashboard `formxml` (component cells present, scoped as the spec set) + `savedquery` / `savedqueryvisualization` for each chart |

> All executor skills share the **same** [Slice Consumption Contract](../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md); the sitemap entry that surfaces the dashboard is the [`hso-dataverse-ui-config`](../hso-dataverse-ui-config/SKILL.md) half of the slice.

---

## Authoritative Best Practices

The methodology this skill applies is documented in:

[`shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md)

**Authority for the XML structure of a chart or dashboard — read before hand-editing one:**
[`customizations-xml-schema.md`](../../../agent/wiki/reference/customizations-xml-schema.md). The SOP above governs *what* a good
dashboard looks like; `VisualizationDataDescription.xsd` governs what the chart XML may legally
contain, and `Fetch.xsd` the query that feeds it. Validate against them when authoring by hand or
when an import rejects a visualization without naming a cause.

Authority for dashboard design and configuration — read it before designing or modifying a dashboard. The bullets below are a digest only (not a substitute); the SOP is authoritative — read it before designing:

- **Dashboard kinds** — System Standard / System Interactive / System Power BI Embedded / Personal Standard / Personal Power BI; `SystemForm` (Type=0) vs `UserForm` storage split. Production deliverables are always system.
- **6-component cap** (configurable to 20 via `MaximumControlsLimit`); HSO target **4–6** components for a portable executive / role overview, **≤ 6** generally for portability across all environments (SOP §3) — design to the 6-component baseline rather than relying on a raised cap. Four legitimate ways past it: second dashboard, interactive, custom page, Power BI.
- **Dashboard FormXml structure** — `<form type="dashboard">` → `<tabs>` → `<tab>` → `<columns>` → `<sections>` → `<rows>` → `<cell>` → `<control>` with supported parameters: `ViewIds`, `ViewId`, `IsUserView`, `IsUserChart`, `TargetEntityType`, `AutoExpand`, `RecordsPerPage`, `EnableQuickFind`, `EnableViewPicker`, `EnableJumpBar`, `EnableChartPicker`, `ChartGridMode`, `VisualizationId`, `Url`, `PassParameters`, `Security`, `Scrolling`, `Border`.
- **Charts on dashboards** — system charts only on system dashboards (Microsoft rule); chart FetchXML must constrain scan to < 50K rows pre-aggregation (`AggregateQueryRecordLimit`); accessibility = hatch + colour, never colour alone.
- **Lists on dashboards** — Default View set explicitly, View Selector off, search box off, Display Index off; Power Apps grid control mandatory (Power Apps Read-Only grid renders blank); inner-join views only (outer joins silently fail); design-time blindness — always test in role context.
- **Web resources** — form-enabled WRs only (HTML / JS / image); cross-frame scripting locked-down on personal dashboards (`UnrestrictedIFrameInUserDashboard` error code). HSO project rule (this engagement): no custom pages — HTML web resources are the chosen interactivity surface.
- **Power BI embedded** — Environment Variables for workspace + report IDs; dynamic RLS via `userprincipalname()`; service principals cannot be added to RLS roles.
- **Default dashboard** — per-app via `IsDefault=1` on one system dashboard; per-user override via "Set as default" command. Set the per-app default thoughtfully — design system dashboards good enough that users don't override.
- **Role scoping** — via `Enable Security Roles` action; one dashboard per role beats per-user personal copies.
- **Performance targets** — ≤ 6 components, ≤ 10K rows pre-aggregation, ≤ 3s P95 cold load.

For the chart accessibility, performance, and FormXml details that drive specific operations, see the SOP sections cross-referenced in each operation's docs below.

### Mobile and offline caveats

**Dashboards are NOT available offline** on the Power Apps mobile client. When a dashboard is surfaced in a sitemap whose app is used on mobile (including Field Service Mobile), the navigation entry must be hidden on mobile (set the sub-area's "Hide on mobile" / `ClientType=Web` filter) or users will see a blank tile when offline. See [`shared/dv/agent/wiki/sop/mobile-and-offline/mobile-and-offline-best-practices.md`](../../../shared/dv/agent/wiki/sop/mobile-and-offline/mobile-and-offline-best-practices.md) for the offline-survival matrix per UI element and the sitemap hide-on-mobile pattern. Additional per-component mobile caveats (already enforced by this skill):

- Chart drill-down is disabled on Power Apps mobile (only labels and totals render)
- Web-browser-on-phone is unsupported (HTML web resources on a dashboard do not render on the phone form factor)
- The dashboard-level "Available on Mobile" flag from legacy mobile is no longer honoured; use per-component flags + the sitemap hide-on-mobile pattern

For Field Service Mobile specifically, the technician home is the FS-defined work-order list — not a dashboard. Building a system dashboard expecting it to be the FS Mobile home is a recurring engagement anti-pattern. See [`shared/dv/agent/wiki/sop/field-service/field-service-mobile-best-practices.md`](../../../shared/dv/agent/wiki/sop/field-service/field-service-mobile-best-practices.md).

---

## Configuration

Read from [`CLAUDE.md`](../../../CLAUDE.md): **Environment URL** · **Default Solution** · **Publisher Prefix** · **Language Code**

Read from [`CLAUDE.local.md`](../../../CLAUDE.local.md): **Author Name** (for changelog entries on documentation)

---

## Standards (MANDATORY)

### Dashboard Naming Convention

`<App / Persona> | Dashboard | <Purpose>`

| Example | When |
|---------|------|
| `HSO \| Dashboard \| Care Coordinator` | Persona-scoped operational dashboard |
| `HSO \| Dashboard \| Franchise Operations` | Functional / area dashboard |
| `HSO \| Dashboard \| Default` | Generic landing dashboard |

The display name lives on the `systemform.name` column — same as forms.

### Before Creating a Dashboard

1. **State the persona's primary question** in one sentence — "what does this user open the dashboard to see?" (e.g. *"Care Coordinator: what needs my attention today across my caseload?"* / *"Biller: which auths and denials are at risk this week?"*). The answer drives which component is the **hero** and what the other 5 cells exist to support — not the section grid.
2. Run `QueryDashboards` and confirm a similar dashboard doesn't already exist
3. Run `QueryViews` (in `hso-dataverse-ui-config`) on each table that will host a list cell — confirm the views exist; if not, create them first. **Also count each view's visible columns** — `>3` means the list cell must be full-width (see "Component fit to cell" below).
4. Run `QuerySystemCharts` per table that will host a chart cell — if the chart doesn't exist, author it first via `CreateSystemChart`. **Note the chart shape** — funnels, line-over-time, and stacked-bar charts have minimum-height needs.
5. Pick a **layout pattern** (visual outcome, not section grid) — see "Layout Patterns" below — then choose the `LayoutPreset` (section grid) that supports it.

### Component Cell Defaults

Per SOP §6, every list cell ships with:

| Parameter | HSO default |
|-----------|-------------|
| `EnableViewPicker` | `false` (deterministic dashboard layout) |
| `EnableQuickFind` | `false` (curated list, not searchable) |
| `EnableJumpBar` | `false` |
| `RecordsPerPage` | `5` (dashboard density) |
| `AutoExpand` | `Fixed` |

Per SOP §5, every chart cell ships with:

| Parameter | HSO default |
|-----------|-------------|
| `EnableChartPicker` | `false` (deterministic; no user pivoting) |
| `ChartGridMode` | `Chart` (chart-only — charts and grids together aren't supported on UCI per crmtipoftheday #1316; use `All` for chart+grid switcher, `Grid` for list-only) |
| `IsUserChart` | `false` (system chart only on system dashboard — Microsoft rule) |

### The section is a real grid — rowspan costs rows, and the XML must show them

A dashboard section is a grid. **Every `<row>` element is one grid row**; a cell with `rowspan="N"` occupies N of them. The designers (classic and modern) therefore write, after each row that holds cells, **`max(rowspan) − 1` empty `<row />` filler elements** — and OOB dashboards carry the same shape (a `rowspan="12"` row followed by 11+ `<row />`). UCI positions each band by cumulative rowspan (its cell ids are literally `<section>_<gridRow>_<col>_<n>` — charts at grid row 0, the next band at 8, the next at 16).

This skill emits and maintains those fillers automatically (`Sync-DashboardFillerRows` runs inside every `Add*`, `RemoveDashboardComponent`, `UpdateDashboardCellLayout`). Dashboards built by this skill **before 2026-08-19** have no fillers — in the classic designer their lists render shifted/overlapping diagonally, and UCI stretches a lone cell across the row. Repair them with **`NormalizeDashboardLayout`** (structure-only; cells, bindings and sizes untouched); `ListDashboardStructure` flags the defect per row (`fillers=0 EXPECTED 5 -- run NormalizeDashboardLayout`).

`RowIndex` on the `Add*` ops addresses **component rows** (rows that hold a cell); fillers are a derived artifact and never addressable. The band model assumes the cells of one component row start on the same grid row — true for every pattern below.

### Component fit to cell

The single most important first-try rule: **picking colspan/rowspan is a function of the component, not just the grid.** Two ways a first build goes wrong: a list too *narrow* truncates its columns to ellipses (`Authorization N…`), and a list too *short* shows **one record and a scrollbar** — a very wide, very low grid is unusable. Prefer **two lists side by side with generous height** over one full-width list with a low rowspan.

**UCI sizing model (measured on a 1920-px viewport, Power Apps grid):**

- **Cell height = 49 px × rowspan.**
- **List anatomy:** command bar 42 + column header 42 + **42 per record** + pager 45 + ~16 padding → **`rowspan ≥ ceil((145 + 42 × RecordsPerPage) / 49)`**; add 1 if `EnableJumpBar`. So 5 records → **8**, 8 records → **10**, 10 records → **12**; `rowspan=4` = 196 px = exactly one record. The modern designer's own default (rowspan 12, 8 records) satisfies this.
- **Chart anatomy:** 104 px of header (title row + legend/second-header row) inside the cell → rowspan 8 leaves a 270-px plot, rowspan 6 only 172 px.
- **Width:** a 3-column section gives ~550 px per column at 1920 px; allow **≥ 160 px per visible view column** → ≤ 3 columns at 1/3 width, ≤ 5 at half width (`2Column` / `4Column` + colspan 2), up to ~10 full-width.

| Component | Width | Height | Default ColSpan / RowSpan |
|---|---|---|---|
| **List with > 5 visible view columns** | full-width only | `rowspan` from the formula (5 records → 8) | `ColSpan = section.columns`, `RowSpan = 8` |
| **List with 4–5 visible view columns** | half-width OK — pair two side by side | formula; give the pair the same rowspan | `ColSpan = section.columns / 2` (use `2Column` or `4Column`), `RowSpan = 8–12` |
| **List with ≤ 3 visible view columns** | 1/3 width OK | formula | `ColSpan = 1`, `RowSpan = 8` |
| **Bar / Column chart** | OK — auto-scales; a lone chart in a row should be full-width (`colspan = section.columns`), not 1/3 + blank | rowspan 8 minimum (270-px plot) | `ColSpan = 1`, `RowSpan = 8` |
| **Funnel chart** | OK width | NEEDS VERTICAL HEIGHT — bottom segments unreadable below rowspan=10 | `ColSpan = 1`, `RowSpan = 10` (pair other charts in the row at the same rowspan so the band aligns) |
| **Line chart over time (>14 ticks)** | OK width but x-axis labels crowd | rowspan 8 minimum | `ColSpan = 1`, `RowSpan = 8` |
| **Pie / Doughnut** | OK any | rowspan 8; the legend row eats header height | `ColSpan = 1`, `RowSpan = 8` |
| **Stacked bar / column** | OK width | NEEDS HEIGHT for legend + segments | `ColSpan = 1`, `RowSpan = 10` |
| **Web resource (KPI tile)** | Compact OK | Compact OK | `ColSpan = 1`, `RowSpan = 2` |
| **Web resource (filter strip)** | Full-width | One row | `ColSpan = section.columns`, `RowSpan = 1` |
| **PCF control (dataset)** | Varies | Generous height usually wins | `ColSpan ≥ 2`, `RowSpan ≥ 8` |

The script default is now `RowSpan = 8` for every `Add*` (was 4 — the one-record grid). Pass `-RowSpan` explicitly for anything taller.

**Anti-patterns that produce unreadable dashboards on first build:**

- ❌ A list at `rowspan=4` (or anything below the formula) — shows one record and a scrollbar; the dashboard looks like a row of headers
- ❌ One very wide, very low grid where two side-by-side lists with more rows would each be usable
- ❌ `3ColumnUniform` × six list cells at `colspan=1` — every list with ≥4 view columns truncates
- ❌ A lone chart at `colspan=1` in its own row — 2/3 of the band is blank; make it full-width or add neighbours
- ❌ Funnel chart at `rowspan=6` — bottom funnel segments unreadable
- ❌ Line chart with `last-x-days 30` (~30 ticks) at `colspan=1` — x-axis labels overlap into a smear
- ❌ Stacked-column with >5 segments at `rowspan=6` — legend clips
- ❌ Mixing `RowSpan=8` charts and `RowSpan=12` charts in the same row — visual misalignment (the band takes the max)

### Layout Patterns (visual outcome, not section grid)

The `LayoutPreset` you pass to `CreateDashboard` (`2Column` / `3ColumnUniform` / `3ColumnVaried` / `4Column`) defines the **section's column count** — not the visual outcome. The same `3ColumnUniform` section can host very different dashboards depending on per-cell `colspan` / `rowspan`. Pick a **named pattern** first (driven by the persona's primary question), then the section preset that supports it.

#### `ChartsOverDetailLists` — "context first, then drill"
**Persona ask:** "show me the trend / mix / distribution, then let me work the urgent rows below."
**Pattern:** Row 0 = 3 charts (`colspan=1, rowspan=8`). Rows 1+ = full-width lists (`colspan=3, rowspan=8` for 5 records; 10 for 8).
**Section:** `3ColumnUniform`. **Components:** 3 charts + 1–3 lists (4–6 components total).

```
+------+------+------+
| chrt | chrt | chrt |   row 0 (rowspan=8)  + 7 filler <row />
+------+------+------+
| LIST full-width    |   row 1 (rowspan=8)  + 7 filler <row />
+--------------------+
| LIST full-width    |   row 2 (rowspan=8)  + 7 filler <row />
+--------------------+
```

#### `SideBySideWorklists` — "two queues I work in parallel"
**Persona ask:** "show me my two worklists at once, each deep enough to actually work from."
**Pattern:** Row 0 = 2 lists side by side (`colspan=1, rowspan=10–12`, 8 records each) — each bound view ≤ 5 visible columns. Optional row 1 = 2 charts (`colspan=1, rowspan=8`) or one full-width list.
**Section:** `2Column` (or `4Column` with `colspan=2` cells when a third, narrower component must share a row). **Components:** 2 lists + 0–2 others.
**Why:** two half-width lists with 8 visible records each beat one full-width list with 1–2 visible records every time — width you don't need, height you do.

```
+---------+---------+
| LIST    | LIST    |   row 0 (rowspan=12) + 11 filler <row />
+---------+---------+
| chrt    | chrt    |   row 1 (rowspan=8)  + 7 filler <row />
+---------+---------+
```

#### `HeroListThenChartsThenDetail` — "what needs my attention today, then context, then secondary worklists"
**Persona ask:** "the urgent worklist is the dashboard. Charts and secondary lists are supporting."
**Pattern:** Row 0 = 1 hero list full-width (`colspan=3, rowspan=10`, 8 records). Row 1 = 3 charts (`colspan=1, rowspan=8`). Rows 2+ = 1–2 secondary full-width lists (`rowspan=8`).
**Section:** `3ColumnUniform`. **Components:** 1 hero + 3 charts + 2 detail = 6 components.

#### `FunnelTriadThenWorklists` — "process health and revenue defense"
**Persona ask:** "is the funnel healthy? then let me work the at-risk rows."
**Pattern:** Row 0 = 3 charts at `rowspan=10` (one of which is the funnel — others sized to match). Rows 1+ = full-width lists (`rowspan=8`).
**Section:** `3ColumnUniform`. **Components:** 3 charts + 3 lists = 6 components.

#### `KPIRowOverFullWidthGrid` — "scoreboard at top, single deep worklist"
**Persona ask:** "give me 4 numbers and the queue I'm working."
**Pattern:** Row 0 = 4 small KPI web-resource cells (`colspan=1, rowspan=2`). Row 1 = 1 full-width list (`colspan=4, rowspan=12`, 10 records).
**Section:** `4Column`. **Components:** 4 WRs + 1 list = 5 components.

#### `SinglePowerBI`
**Persona ask:** "show me the executive view in one canvas."
**Pattern:** 1 PBI tile fills the dashboard (`colspan=1, rowspan=12`).
**Section:** `PowerBIEmbedded`.

> **First-try guidance for an LLM building from a spec:** before calling `Add*`, query the bound view's `layoutxml` and count `<cell>` elements. `> 5` → the list MUST be full-width (`-ColSpan` = section `columns`); `4–5` → half-width is fine, so pair it with another list (`SideBySideWorklists`); `≤ 3` → 1/3 width works. Size every list from the formula — **`rowspan ≥ ceil((145 + 42 × RecordsPerPage) / 49)`** (5 → 8, 8 → 10, 10 → 12) — never below 8. For chart cells, look at the chart type — funnel/stacked → `-RowSpan = 10`; bar/column/line/pie → `-RowSpan = 8`. A lone chart in its own row gets `colspan = section.columns`. If a cell still lands at the wrong size, fix it in place with `UpdateDashboardCellLayout` (it takes a comma-separated list of cells, or `*`) — never Remove + re-Add for a resize.

### System Charts Only on System Dashboards

Microsoft's rule: *"An organization-owned dashboard can contain only organization-owned charts."* If `CreateSystemChart` was prototyped as a personal chart, promote it to system before referencing it from a dashboard cell. This skill only authors system charts.

### Web Resource Cells — Form-Enabled Only

Only HTML / JS / image web resources marked **form-displayable** can be added to a dashboard. CSS / library web resources will fail. The `AddDashboardWebResource` operation does NOT verify the web-resource type — the caller is responsible for picking a form-enabled WR.

### Solutions are READ-ONLY (project rule)

Per the project [CLAUDE.md](../../../CLAUDE.md): the `Solutions/` folder is the output of `pac solution export`, not editable source. **All dashboard mutations go through this skill against Dataverse directly.** Refresh the local solution folder via the Solution Export pipeline after dashboards are built.

---

## Operations Summary

| Category | Operation | Description |
|----------|-----------|-------------|
| **Dashboards** | `QueryDashboards` | List system dashboards (filter by table, app, name pattern) |
| | `GetDashboard` | Get raw FormXml for a dashboard |
| | `ListDashboardStructure` | Human-readable: tabs/sections/cells with each component type |
| | `CreateDashboard` | Create a system dashboard from a layout preset |
| | `AddDashboardChart` | Add a chart cell (system chart, view-bound) |
| | `AddDashboardList` | Add a list cell (view, target table) |
| | `AddDashboardWebResource` | Add a form-enabled HTML web-resource cell |
| | `AddDashboardPCFControl` | Add a PCF as a standalone dashboard cell |
| | `AddDashboardPowerBITile` | Add a Power BI report/tile cell (env-var bound) |
| | `RemoveDashboardComponent` | Remove a cell by control name |
| | `UpdateDashboardCellLayout` | Resize existing cells in place by control id — `-CellName` takes one id, a comma-separated list, or `*` (all cells); any combination of `-ColSpan` / `-RowSpan` / `-RecordsPerPage`; one PATCH + one publish + per-cell read-back; filler rows re-derived |
| | `NormalizeDashboardLayout` | Re-derive the grid filler `<row />` elements of an existing dashboard (structure-only repair for dashboards built before 2026-08-19, or any whose `<rows>` drifted from its rowspans); publish + read-back |
| | `SetDashboardDefault` | Set `IsDefault=1` for the per-app default; unset others |
| | `SetDashboardSecurityRoles` | Scope dashboard to one or more security roles |
| | `AddDashboardToApp` | Add the dashboard to an app module's component list **and publish the app** (so UCI sees the new component). Use `-SkipPublish` for batched adds, then call `PublishApp` once. **Warns when the app has no explicit dashboards yet** — see "App dashboard visibility" below. |
| | `PublishApp` | Publish an app module by unique name (retries on 429 throttling). Use after batched `AddDashboardToApp -SkipPublish` calls or to force a publish after sitemap edits. |
| | `PublishDashboard` | Publish dashboard customizations |
| **System Charts** | `QuerySystemCharts` | List system charts (`savedqueryvisualization`) for a table |
| | `GetSystemChart` | Get a chart's data + presentation XML |
| | `CreateSystemChart` | Create a system chart (templates: bar / column / line / pie / funnel / stacked-bar / stacked-column) |
| | `UpdateSystemChart` | PATCH a chart's presentation and/or data XML — `-ChartType` regenerates the presentation from this skill's template (the repair path for skeleton charts), `-PresentationDescription` / `-DataDescription` take raw XML (inline or file path); publishes the table + read-back |
| | `DeleteSystemChart` | Delete a system chart *(stub — Pass 2)* |

Deferred operations (registered in dispatcher; throw "not yet implemented"):

| Operation | Why deferred |
|-----------|--------------|
| Interactive Experience dashboard authoring | The queue / stream / tile / global-filter / timeframe-filter model is involved; deserves its own pass with the per-table `IsEnabledForInteractiveExperience` and per-column "Appears in global filter" prerequisites enforced |
| `DeleteSystemChart` | Charts are typically created once and replaced via solution import; see [`references/delete-system-chart-web-api.md`](references/delete-system-chart-web-api.md) for the validated raw call |
| Personal dashboards (`UserForm`) | Production deliverables are always system per SOP §10 |

### App dashboard visibility — the implicit → explicit flip

A model-driven app with **no** dashboard components (`appmodulecomponents` with `componenttype=60`) shows **every** system dashboard implicitly. The **first explicit add** — `AddDashboardToApp`, or saving the app from the modern designer after adding a dashboard page — flips the app to "only the listed dashboards", and every other dashboard silently disappears from the picker (observed 2026-08-19: adding one dashboard hid eight others; the sitemap's dashboard sub-areas then all fell back to the one registered dashboard). `AddDashboardToApp` detects the zero-explicit state and prints the non-OOB dashboards that are about to vanish; register each of them in the same pass (`-SkipPublish` + one `PublishApp`). `QueryDashboards -AppModuleUniqueName <app>` lists what the app currently exposes.

### Chart title / legend overlap in UCI (platform behavior, design around it)

UCI's modern chart control renders the chart **name as an HTML header** above a Highcharts canvas and then pulls the **legend up (−27 px) into that header row**; it ignores `Legend Docking` / `Alignment` entirely, so a left-aligned legend overprints the title. Nothing in the chart XML moves the legend. Design around it: **omit `<Legends>` on single-series charts** (a one-entry "Count:All (Table)" legend is noise — the skill's Bar / Column / Line templates now do this), keep pie / funnel / stacked legends short, and put the category on the slice label where you can. OOB charts behave the same way.

### PATCH visibility — a GET after a PATCH shows the PRE-write state until publish (expected)

`systemforms.formxml` is layered: a PATCH lands in the **unpublished** layer, while a plain GET — and therefore `GetDashboard` / `ListDashboardStructure` — keeps returning the **published** (pre-write) layer until `PublishXml` runs. This is expected Dataverse behavior, not a failed write (same behavior as views/forms in [`hso-dataverse-ui-config`](../hso-dataverse-ui-config/SKILL.md), which publishes first and then verifies by read-back):

- **Do not** re-issue the PATCH, and **do not** diagnose "my change didn't take" from a pre-publish GET.
- Every cell mutation in this skill (`Add*`, `RemoveDashboardComponent`, `UpdateDashboardCellLayout`) therefore **publishes immediately and then verifies by a published-layer read-back** — the `[OK] Read-back confirms cell '<name>' …` line is the authoritative verdict; the earlier `[OK] … added` line only means the PATCH was accepted.
- Corollary of the layering: an unpublished edit is invisible to the next GET→modify→PATCH cycle, so a second mutation composed from a pre-publish GET **silently clobbers the first**. This is why `-SkipPublish` is ignored on cell mutations.
- **Never hand-compose GET → regex-edit → PATCH → publish** for a cell change — that round-trip is exactly what `UpdateDashboardCellLayout` wraps, and free-handed inline `pwsh -Command` edits have injected literal backticks into FormXml (a renderer-breaking diagnostic red herring). If an operation is missing for the mutation you need, extend the script instead.

Authority for the FormXml cell structures emitted by every `Add*` operation — read before adding or hand-editing a cell: [`references/dashboard-formxml-patterns.md`](references/dashboard-formxml-patterns.md).

Authority for the chart data + presentation XML emitted by `CreateSystemChart` — read before authoring a chart: [`references/chart-xml-patterns.md`](references/chart-xml-patterns.md).

Authority for deleting a system chart (not wrapped in this skill; composed per [ADR 0013](../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md)) — read before deleting: [`references/delete-system-chart-web-api.md`](references/delete-system-chart-web-api.md); adapt the validated call there.

### Task → primary authority

| Task | Primary authoritative doc |
|------|---------------------------|
| Design / lay out a dashboard; component count; role scoping; performance | [`shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md) |
| Author or hand-edit a dashboard cell's FormXml (any `Add*` op) | [`references/dashboard-formxml-patterns.md`](references/dashboard-formxml-patterns.md) |
| Author a system chart's data + presentation XML (`CreateSystemChart`) | [`references/chart-xml-patterns.md`](references/chart-xml-patterns.md) |
| Delete a system chart (not wrapped in this skill) | [`references/delete-system-chart-web-api.md`](references/delete-system-chart-web-api.md) |
| Mobile / offline surfacing of a dashboard | [`shared/dv/agent/wiki/sop/mobile-and-offline/mobile-and-offline-best-practices.md`](../../../shared/dv/agent/wiki/sop/mobile-and-offline/mobile-and-offline-best-practices.md) |

---

## Quick Reference

All operations use the same base command:

```powershell
powershell -ExecutionPolicy Bypass -File "claude-code/skills/hso-dataverse-dashboards/scripts/Invoke-DataverseDashboardOperation.ps1" `
    -Operation <OperationName> `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    <additional parameters>
```

### QueryDashboards

```powershell
# All system dashboards
-Operation QueryDashboards

# Filter by name pattern
-Operation QueryDashboards -DashboardNameFilter "Care"

# Filter by table (table-specific dashboards have objecttypecode set)
-Operation QueryDashboards -TableName "incident"

# Filter by app module
-Operation QueryDashboards -AppModuleUniqueName "hso_HSOHomeHealthcare"
```

### GetDashboard / ListDashboardStructure

```powershell
-Operation GetDashboard -DashboardId "603991a3-..."

-Operation ListDashboardStructure -DashboardId "603991a3-..."
```

`ListDashboardStructure` is the analogue of `ListFormStructure` — start here when modifying an existing dashboard.

### CreateDashboard

Create a system dashboard with a layout preset. Component cells are added via `AddDashboardChart`, `AddDashboardList`, etc. afterward.

```powershell
# Default 3-column varied (hero + two supporting components on the right)
-Operation CreateDashboard `
    -DashboardName "HSO | Dashboard | Care Coordinator" `
    -LayoutPreset "3ColumnVaried" `
    -SolutionName "HSOHomeHealthcare"

# Power BI embedded variant (single PBI tile fills the dashboard)
-Operation CreateDashboard `
    -DashboardName "HSO | Dashboard | Network Performance" `
    -LayoutPreset "PowerBIEmbedded" `
    -SolutionName "HSOHomeHealthcare"
```

**LayoutPreset values:** `2Column`, `3ColumnUniform`, `3ColumnVaried`, `4Column`, `PowerBIEmbedded`

**Optional:** `-TableName` for table-specific dashboards (sets `objecttypecode`).

### AddDashboardChart

Add a system chart cell bound to a saved query.

```powershell
-Operation AddDashboardChart `
    -DashboardId "..." `
    -CellName "chart_authsExpiring" `
    -TargetEntityType "hso_authorization" `
    -VisualizationId "abc12345-..." `
    -ViewId "def67890-..." `
    -ColumnIndex 0 -RowIndex 0 -ColSpan 1 -RowSpan 8
```

**Defaults applied:** `EnableChartPicker=false`, `ChartGridMode=Chart`, `IsUserChart=false`, `IsUserView=false`. Override via `-EnableChartPicker $true` etc.

**Cell label** — if `-CellLabel` is omitted, the skill auto-fetches the chart's `name` from `savedqueryvisualizations` and uses it as the cell label. Charts default to `showlabel="false"` (the chart embeds its own visual title); pass `-CellShowLabel $true` to surface the cell label as a header bar above the chart.

### AddDashboardList

Add a list cell bound to a system view.

```powershell
-Operation AddDashboardList `
    -DashboardId "..." `
    -CellName "list_myOpenIntakes" `
    -TargetEntityType "hso_clientintake" `
    -ViewId "def67890-..." `
    -ColumnIndex 0 -RowIndex 0 -ColSpan 1 -RowSpan 8 `

# Custom label override
-Operation AddDashboardList `
    -DashboardId "..." `
    -CellName "list_priorityWork" `
    -TargetEntityType "hso_clientintake" `
    -ViewId "def67890-..." `
    -CellLabel "Priority Work Queue" `
    -ColumnIndex 0 -RowIndex 1 -ColSpan 3 -RowSpan 8
```

**Defaults applied:** `EnableViewPicker=false`, `EnableQuickFind=false`, `EnableJumpBar=false`, `RecordsPerPage=5`, `AutoExpand=Fixed`.

**Cell label** — list cells default to `showlabel="true"` so users can tell which view the cell is bound to (the renderer doesn't display view names automatically for lists). If `-CellLabel` is omitted, the skill auto-fetches the view's `name` from `savedqueries` and uses it as the cell label. Pass `-CellShowLabel $false` to suppress the header.

**Layout note (per [SOP §4](../../../shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md#4-dashboard-layout))** — lists with > 3 visible columns belong on **full-width rows** (`-ColSpan` matching the section column count, e.g. `3` for a 3-column section). At 1/3 width a list cuts off most columns and shows ellipses; charts are width-tolerant but lists are not. Use the **charts-over-detail-lists** pattern: row 0 has 3 charts at colspan=1 each, rows 1+ each have one full-width list at colspan=3.

### AddDashboardWebResource

Add a form-enabled HTML web resource cell.

```powershell
-Operation AddDashboardWebResource `
    -DashboardId "..." `
    -CellName "wr_filterStrip" `
    -WebResourceUrl "$webresource:hso_/html/dashboards/poc-filter-strip.html" `
    -WebResourcePassParameters $true `
    -ColumnIndex 0 -RowIndex 0 -ColSpan 3 -RowSpan 1
```

**Notes:**
- `WebResourceUrl` uses the form-style `$webresource:` prefix — same convention as form web resources.
- `WebResourcePassParameters=$true` passes record context (none for system dashboards) plus query-string parameters.
- The web resource itself must be deployed first (separate operation; not handled here).

### AddDashboardPCFControl

Add a PCF as a standalone dashboard cell. **Different from `AddPCFControl` in `hso-dataverse-ui-config`** — that one binds a PCF to a form field; this one places a PCF as a free-standing dashboard cell with no field binding.

```powershell
-Operation AddDashboardPCFControl `
    -DashboardId "..." `
    -CellName "pcf_progressOfCare" `
    -PCFControlName "hso_HSO.Dynamics.PCF.ProgressOfCareChart" `
    -PCFParametersJson '{"clientId":"static:00000000-0000-0000-0000-000000000000","dateFrom":"static:2025-01-01"}' `
    -ColumnIndex 0 -RowIndex 1 -ColSpan 3 -RowSpan 8
```

**Notes:**
- The PCF must already be deployed (`pac pcf push` or solution import).
- `PCFParametersJson` supports static values (`static:value`) — runtime URL-param binding is the caller's responsibility (the dashboard URL `?data=...` parameter is read inside the PCF).
- Per SOP §13 (Diana Birkelbach's caveat), test in dashboard context specifically — dataset PCFs that work on subgrids may behave differently here.

### AddDashboardPowerBITile

Add a Power BI report tile cell. Per SOP §8, workspace and report IDs should be Environment-Variable-bound for ALM portability.

```powershell
-Operation AddDashboardPowerBITile `
    -DashboardId "..." `
    -CellName "pbi_networkPerformance" `
    -PowerBIWorkspaceId "@hso_pbi_workspace_id" `
    -PowerBIReportId "@hso_pbi_networkperf_report_id" `
    -ColumnIndex 0 -RowIndex 0 -ColSpan 2 -RowSpan 8
```

**Notes:**
- `@variable_name` syntax indicates an Environment Variable reference. Plain GUIDs are also accepted but discouraged for cross-environment portability.
- The Env Vars themselves are managed via [`hso-dataverse-deployment-settings`](../hso-dataverse-deployment-settings/SKILL.md).

### RemoveDashboardComponent

```powershell
-Operation RemoveDashboardComponent -DashboardId "..." -CellName "list_myOpenIntakes"
```

### UpdateDashboardCellLayout

Resize existing cells **in place** — no Remove + re-Add ceremony, no hand-composed formxml round-trip. Targets cells by control id (`-CellName`, as printed by `ListDashboardStructure`): one id, a **comma-separated list**, or **`*`** for every cell. Pass any combination of `-ColSpan`, `-RowSpan`, `-RecordsPerPage` (at least one). One PATCH + one publish for the whole set, filler rows re-derived, then each cell is verified against a published-layer read-back.

```powershell
# Make a truncating list full-width and tall enough for its 5 records (see "Component fit to cell")
-Operation UpdateDashboardCellLayout -DashboardId "..." -CellName "list_myOpenIntakes" -ColSpan 3 -RowSpan 8

# Give a funnel chart the vertical height it needs
-Operation UpdateDashboardCellLayout -DashboardId "..." -CellName "chart_authFunnel" -RowSpan 10

# Denser worklist: 10 records per page -> rowspan 12 by the formula
-Operation UpdateDashboardCellLayout -DashboardId "..." -CellName "list_priorityWork" -RecordsPerPage 10 -RowSpan 12

# Bulk reflow: every cell on the dashboard to rowspan 8 in a single publish
-Operation UpdateDashboardCellLayout -DashboardId "..." -CellName "*" -RowSpan 8

# Two cells at once
-Operation UpdateDashboardCellLayout -DashboardId "..." -CellName "list_a,list_b" -RowSpan 12 -RecordsPerPage 8
```

**Notes:**
- `-RecordsPerPage` applies to list/chart (subgrid) cells only; on web-resource / PCF / Power BI cells it is skipped with a warning (colspan/rowspan still apply).
- Untouched cell properties (label, bound view/chart, picker flags) are left exactly as-is — rebinding a cell to a different view or chart is Remove + re-Add.
- A `-RowSpan` change re-derives the filler `<row />` elements for the whole section (see "The section is a real grid").

### NormalizeDashboardLayout

Structure-only repair: re-derive the grid filler `<row />` elements so each band's rowspan is honoured, publish, read back. Cells, bindings and sizes are untouched. Run it on every dashboard built by this skill before 2026-08-19, or whenever `ListDashboardStructure` prints `fillers=N EXPECTED M`.

```powershell
-Operation NormalizeDashboardLayout -DashboardId "..."
#   <row> elements: 3 -> 14 (3 component row(s) + 11 filler(s))
#   [OK] Read-back confirms 14 <row> elements on the published layer
```

Idempotent — a second run reports "already normalized -- nothing to write".

### SetDashboardDefault

Set this dashboard as the default for an app module — unsets `IsDefault` on all other dashboards in that app's component list first.

```powershell
-Operation SetDashboardDefault `
    -DashboardId "..." `
    -AppModuleUniqueName "hso_HSOHomeHealthcare"
```

### SetDashboardSecurityRoles

Restrict dashboard visibility to one or more security roles.

```powershell
-Operation SetDashboardSecurityRoles `
    -DashboardId "..." `
    -RoleIds @("role-guid-1", "role-guid-2") `

# Reset to all roles
-Operation SetDashboardSecurityRoles -DashboardId "..."
```

### AddDashboardToApp

Add the dashboard to an app module's component list — required for it to appear in the dashboard picker for that app **once the app lists any dashboard explicitly** (see "App dashboard visibility — the implicit → explicit flip"). On an app with zero explicit dashboards the op prints the non-OOB dashboards that will disappear after this add; register them all in the same pass.

```powershell
-Operation AddDashboardToApp `
    -DashboardId "..." `
    -AppModuleUniqueName "hso_HSOHomeHealthcare"

# Registering several at once: stage with -SkipPublish, then publish the app once
-Operation AddDashboardToApp -DashboardId "<id-1>" -AppModuleUniqueName "hso_HSOHomeHealthcare" -SkipPublish
-Operation AddDashboardToApp -DashboardId "<id-2>" -AppModuleUniqueName "hso_HSOHomeHealthcare" -SkipPublish
-Operation PublishApp -AppModuleUniqueName "hso_HSOHomeHealthcare"
```

### PublishDashboard

Publish dashboard customizations. Every cell mutation (`Add*`, `RemoveDashboardComponent`, `UpdateDashboardCellLayout`) publishes implicitly — see "PATCH visibility" above for why deferring is not offered there. Use this standalone to re-publish after out-of-band edits. `-SkipPublish` is honored only by `CreateDashboard`, `SetDashboardDefault`, `SetDashboardSecurityRoles`, `AddDashboardToApp`, `CreateSystemChart`, and `UpdateSystemChart`.

```powershell
-Operation PublishDashboard -DashboardId "..."
```

### CreateSystemChart

Create a `savedqueryvisualization` for a table from a chart-type template + a column / aggregation spec.

```powershell
# Bar chart of count(*) by group
-Operation CreateSystemChart `
    -ChartName "Active Clients by Territory" `
    -TableName "contact" `
    -ChartType "Bar" `
    -GroupByColumn "hso_territory_id" `
    -AggregateColumn "contactid" `
    -AggregateFunction "count" `
    -SolutionName "HSOHomeHealthcare" `

# Line chart over time
-Operation CreateSystemChart `
    -ChartName "New Intakes by Week" `
    -TableName "hso_clientintake" `
    -ChartType "Line" `
    -GroupByColumn "createdon" `
    -GroupByDateInterval "week" `
    -AggregateColumn "hso_clientintakeid" `
    -AggregateFunction "count" `
    -ChartFilter "<filter><condition attribute='createdon' operator='last-x-months' value='3' /></filter>" `
    -SolutionName "HSOHomeHealthcare" `

# Funnel chart
-Operation CreateSystemChart `
    -ChartName "Authorization Funnel" `
    -TableName "hso_authorization" `
    -ChartType "Funnel" `
    -GroupByColumn "hso_status_code" `
    -AggregateColumn "hso_authorizationid" `
    -AggregateFunction "count" `
    -SolutionName "HSOHomeHealthcare"
```

**Parameters:**
- `ChartType` — `Bar`, `Column`, `Line`, `Pie`, `Funnel`, `StackedBar`, `StackedColumn`
- `GroupByDateInterval` — for date columns: `day`, `week`, `month`, `quarter`, `year`
- `ChartFilter` — optional FetchXML `<filter>` element to constrain the dataset (mandatory for charts whose unfiltered dataset > 50K rows per SOP §5 / `AggregateQueryRecordLimit`)

**Presentation the templates emit** (mirrors the OOB chart conventions — see [`references/chart-xml-patterns.md`](references/chart-xml-patterns.md)): a `TopLeft`-docked `<Title>` that UCI fills with the chart name; **no `<Legends>` for single-series Bar / Column / Line** (a one-entry legend only overprints the title in UCI); a right-docked legend for Pie / Funnel and a bottom-docked one for stacked charts; `SmartLabelStyle` value labels; OOB axis greys; the HSO palette. Do not emit the pre-2026-08-19 skeleton (`Palette='BrightPastel'`, undocked `<Legend Name='Default'/>`, empty `<Titles/>`) — it is what produced the overlapping title/legend.

For chart shapes / colour palettes / accessibility (hatch + colour) beyond these templates, see [`references/chart-xml-patterns.md`](references/chart-xml-patterns.md). For chart authoring beyond what this skill covers, use [Chart Manager](https://www.xrmtoolbox.com/plugins/MsCrmTools.ChartManager/) (Tanguy Touzard) or the [Advanced Chart Editor](https://www.xrmtoolbox.com/plugins/ITLec.CRMChartGuy.XRMToolBox.AdvancedChartEditor/) (Ulrik Carlsson) directly.

### UpdateSystemChart

PATCH an existing `savedqueryvisualization` and publish its table. Three inputs, any combination:

```powershell
# Repair a skeleton chart: regenerate its presentation from the skill template for its type
-Operation UpdateSystemChart -ChartId "abc12345-..." -ChartType "Bar"

# Replace the presentation (or data) XML outright -- inline string or a path to a file holding it
-Operation UpdateSystemChart -ChartId "abc12345-..." -PresentationDescription ".\charts\pipeline-presentation.xml"
-Operation UpdateSystemChart -ChartId "abc12345-..." -DataDescription "<datadefinition>...</datadefinition>"
```

Malformed XML fails fast before the PATCH; the `[OK] Read-back confirms the chart definition` line is the verdict. Client-side note: UCI caches chart and dashboard metadata — a plain navigation may still paint the previous definition; hard-reload (Ctrl+Shift+R) to see the change.

### QuerySystemCharts / GetSystemChart

```powershell
-Operation QuerySystemCharts -TableName "hso_authorization"

-Operation GetSystemChart -ChartId "abc12345-..."
```

---

## Workflow

When building a dashboard from a spec:

1. **Read the SOP section** for the dashboard kind you're building (System Standard / Power BI Embedded). Confirm the layout preset is compatible with the requested component count.
2. **Verify dependencies exist**:
   - Tables exist and are populated (or seeded for testing) — query via the data-modeling skill.
   - Views referenced by list cells exist with HSO standards (≤ 6 columns for subgrids per the view SOP, no parent-lookup column for subgrids — but dashboard lists don't have a parent so any active view works). Use `QueryViews` in `hso-dataverse-ui-config` to verify.
   - Charts referenced by chart cells exist as **system charts** (querytype-equivalent on `savedqueryvisualization`). Use `QuerySystemCharts` here. Create them via `CreateSystemChart` if missing.
   - Web resources referenced by web-resource cells are **form-enabled** and deployed.
   - PCF controls referenced by PCF cells are deployed (`pac pcf push` or solution import).
   - Power BI workspace + report Environment Variables exist (use `hso-dataverse-deployment-settings`).
3. **Create the dashboard** with the chosen layout preset (`CreateDashboard`).
4. **Add components** one at a time (`AddDashboardChart`, `AddDashboardList`, `AddDashboardWebResource`, `AddDashboardPCFControl`, `AddDashboardPowerBITile`). Each Add publishes immediately and verifies by read-back (see "PATCH visibility") — `-SkipPublish` is ignored on cell mutations because an unpublished cell would be clobbered by the next Add's GET. Sizing landed wrong on a cell? Fix it in place with `UpdateDashboardCellLayout` — don't Remove + re-Add, and don't hand-edit the formxml.
5. **Wire to the app**:
   - `AddDashboardToApp` — add to the app module's component list.
   - `SetDashboardDefault` (if this is the default landing dashboard for the app).
   - `SetDashboardSecurityRoles` (if role-scoped).
   - `AddSiteMapSubArea` (in `hso-dataverse-ui-config`) — surface the dashboard in the sitemap. Sub-area URL pattern: `/main.aspx?pagetype=dashboard&id=<dashboardId>` or `appid=<appId>&pagetype=dashboard&id=<dashboardId>`.
6. **Verify**:
   - Run `ListDashboardStructure` and confirm components landed where expected.
   - Open the dashboard in the target app module — every chart, list, and PCF must render with non-zero data when seeded.
   - Confirm the per-app default — the dashboard picker should land here on app launch.

---

## Critical Rules

### DO NOT

- **Author personal charts on a system dashboard.** Microsoft enforces system-only charts on system dashboards. Promote personal charts to system before referencing them — see [Carl de Souza's pattern](https://carldesouza.com/convert-personal-chart-system-chart-dynamics-365/).
- **Create dashboards via `pac solution pack` / unpacked XML edits.** Per the project [CLAUDE.md](../../../CLAUDE.md), `Solutions/` is read-only — go through Web API (this skill).
- **Exceed 6 components on a system standard dashboard** unless you've explicitly raised `MaximumControlsLimit` (and even then HSO target is ≤ 6 for portability). Use a second dashboard, an interactive dashboard, or Power BI for richer surfaces.
- **Use the Power Apps Read-Only grid control on a dashboard list.** It renders blank. Use the **Power Apps grid control** (modern grid).
- **Add iframes with cross-frame scripting on personal dashboards.** Returns `UnrestrictedIFrameInUserDashboard` error. (This skill creates system dashboards only, but the rule is worth knowing if a personal dashboard surfaces in maintenance.)
- **Hard-code Power BI workspace / report GUIDs.** Use Environment Variable references (`@variable_name`) so DEV / TEST / UAT / PROD each point at their own workspace.

### DO

- **Set the per-app default dashboard explicitly** via `SetDashboardDefault`. Don't leave it to whatever Microsoft picked by `IsDefault` ordering.
- **Set role scoping** via `SetDashboardSecurityRoles` for persona-specific dashboards. Ship one system dashboard per role; don't proliferate per-user personal copies.
- **Pre-create system charts** for every chart cell before running `AddDashboardChart`. This skill won't auto-create them; it requires a `VisualizationId`.
- **Test in role context.** Lists on dashboards have design-time blindness (no preview); always publish + open in a real role context before declaring done.
- **Run the wiki linter** after committing skill changes — see Step 3 of [`hso-skill-creator`](../hso-skill-creator/SKILL.md).

---

## Authentication

Authentication is resolved automatically from settings via the shared module [`hso-shared-scripts/scripts/Dataverse-Auth.ps1`](../hso-shared-scripts/scripts/Dataverse-Auth.ps1). Token cache: `%TEMP%\DataverseAuthCache_<environment-hash>.json`, ~1 hour validity. When browser sign-in is used, the first call opens the browser for O365 login; subsequent calls reuse the cached token.

---

## Limitations (Pass 1)

- **Interactive Experience dashboards** — only `CreateDashboard -LayoutPreset Interactive` scaffolding is on the roadmap; the full stream / tile / global-filter / timeframe-filter authoring with the per-table `IsEnabledForInteractiveExperience` and per-column "Appears in global filter" prerequisites is deferred. For Pass 1, author interactive dashboards in the Customer Service Hub designer and use `AddDashboardToApp` here only.
- **Personal dashboards (`UserForm`)** — out of scope. Production deliverables are always system per SOP §10. If a personal dashboard needs to be promoted, recreate as a system dashboard in DEV.
- **Power BI report authoring** — out of scope. This skill places the embed tile only; the underlying `.pbix` is authored in Power BI Desktop.
- **`DeleteSystemChart`** — registered in the dispatcher with "not yet implemented"; charts are typically created once and replaced via solution import. `UpdateSystemChart` landed 2026-08-19 (template regeneration + raw XML replace).

---

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
