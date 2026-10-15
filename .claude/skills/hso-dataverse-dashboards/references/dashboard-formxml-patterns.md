# Dashboard FormXml Patterns Reference

Concrete cell / control XML patterns the `hso-dataverse-dashboards` skill emits. Authoritative source: Microsoft's [Understand dashboards: Dashboard components, FormXml](https://learn.microsoft.com/en-us/power-apps/developer/model-driven-apps/understand-dashboards-dashboard-components-formxml). Methodology: [`shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md`](../../../../shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md).

---

## Top-level dashboard structure

Dashboards live in `SystemForm` with `Type=0`. The FormXml mirrors form FormXml — `<form>` → `<tabs>` → `<tab>` → `<columns>` → `<sections>` → `<rows>` → `<cell>` → `<control>`. Tab and section names are organisational only (not displayed).

```xml
<form>
  <tabs>
    <tab name="tab_dashboard" id="{guid}" IsUserDefined="0" expanded="true" showlabel="false">
      <labels>
        <label description="Dashboard" languagecode="1033" />
      </labels>
      <columns>
        <column width="100%">
          <sections>
            <section name="section_dashboard_3ColumnUniform" id="{guid}"
                     columns="3" showlabel="false" showbar="false"
                     IsUserDefined="0" layout="varwidth">
              <labels>
                <label description="Dashboard" languagecode="1033" />
              </labels>
              <rows>
                <!-- Component cells go here, grouped into <row> elements -->
              </rows>
            </section>
          </sections>
        </column>
      </sections>
    </tab>
  </tabs>
</form>
```

The skill's `CreateDashboard` operation emits this skeleton with `section.columns` set per layout preset:

| LayoutPreset      | section.columns | Use for |
|-------------------|----------------:|---------|
| `2Column`         | 2               | Side-by-side comparison; left list + right chart pattern |
| `3ColumnUniform`  | 3               | Three peer KPIs / streams |
| `3ColumnVaried`   | 3               | Hero + two supporting components (vary cell colspans) |
| `4Column`         | 4               | Dense KPI dashboards |
| `PowerBIEmbedded` | 1               | Single PBI tile fills the dashboard |
| `Interactive`     | 2               | Customer Service Hub interactive scaffolding *(deferred — full authoring is Pass 2)* |

---

## Cell wrapper

Every component is wrapped in a `<cell>` element with explicit `colspan` / `rowspan` for grid sizing.

```xml
<cell id="{guid}" colspan="1" rowspan="4" showlabel="false" locklevel="0">
  <labels>
    <label description="Cell label (optional)" languagecode="1033" />
  </labels>
  <control id="control-id" classid="{class-guid}">
    <parameters>
      <!-- Component-specific parameters -->
    </parameters>
  </control>
</cell>
```

---

## Component types

### Chart and list cells (unified subgrid pattern)

**Critical:** dashboard chart, list, and chart+grid hybrid cells **all share the same `<control>` shape** — same `classid`, same `<parameters>` block. The only thing distinguishing them is the `<ChartGridMode>` value and whether `<VisualizationId>` is populated. This is verified against OOB Sales Activity, Customer Service Manager, and Customer Service Representative dashboards, and matches the FormXml.xsd "subgrid" parameter group (which includes both chart-related and grid-related parameters together).

The form-embedded chart classid `{587CDF98-C1D5-4BDE-8473-14A0BC7644A7}` is **NOT valid for dashboard cells** — dashboards built with that classid render cells as empty placeholders. Use `{E7A81278-8635-4d9e-8D4D-59480B391C5B}` (the subgrid classid) for chart cells too.

#### Required `<control>` attributes

```xml
<control id="ControlId"
         uniqueid="{guid}"                 <!-- separate GUID, not the same as id -->
         classid="{E7A81278-8635-4d9e-8D4D-59480B391C5B}"
         indicationOfSubgrid="true">       <!-- tells the renderer this is a subgrid host -->
```

The `uniqueid` and `indicationOfSubgrid` attributes are both required for the cell to bind data — verified against the FormXml.xsd `FormXmlControlType` (`indicationOfSubgrid` is line 647 of the schema).

#### Chart cell (ChartGridMode=Chart)

```xml
<cell id="{cell-guid}" colspan="1" rowspan="4" showlabel="false" auto="false">
  <labels><label description="Cell" languagecode="1033" /></labels>
  <control id="chart_authsExpiring"
           uniqueid="{abc-guid}"
           classid="{E7A81278-8635-4d9e-8D4D-59480B391C5B}"
           indicationOfSubgrid="true">
    <parameters>
      <TargetEntityType>hso_examplecase</TargetEntityType>
      <ChartGridMode>Chart</ChartGridMode>
      <EnableQuickFind>false</EnableQuickFind>
      <EnableViewPicker>false</EnableViewPicker>
      <EnableJumpBar>false</EnableJumpBar>
      <RecordsPerPage>5</RecordsPerPage>
      <ViewId>{def67890-...}</ViewId>
      <IsUserView>false</IsUserView>
      <ViewIds />                               <!-- empty self-closing element required -->
      <AutoExpand>Fixed</AutoExpand>
      <VisualizationId>{abc12345-...}</VisualizationId>
      <IsUserChart>false</IsUserChart>
      <EnableChartPicker>false</EnableChartPicker>
      <RelationshipName />                      <!-- empty self-closing element required -->
    </parameters>
  </control>
</cell>
```

#### List cell (ChartGridMode=Grid)

Identical structure, but `ChartGridMode=Grid` and `<VisualizationId>` is omitted (or empty if you want a chart switcher available):

```xml
<control id="list_myOpenItems"
         uniqueid="{abc-guid}"
         classid="{E7A81278-8635-4d9e-8D4D-59480B391C5B}"
         indicationOfSubgrid="true">
  <parameters>
    <TargetEntityType>hso_examplecase</TargetEntityType>
    <ChartGridMode>Grid</ChartGridMode>
    <EnableQuickFind>false</EnableQuickFind>
    <EnableViewPicker>false</EnableViewPicker>
    <EnableJumpBar>false</EnableJumpBar>
    <RecordsPerPage>5</RecordsPerPage>
    <ViewId>{def67890-...}</ViewId>
    <IsUserView>false</IsUserView>
    <ViewIds />
    <AutoExpand>Fixed</AutoExpand>
    <IsUserChart>false</IsUserChart>
    <EnableChartPicker>false</EnableChartPicker>
    <RelationshipName />
  </parameters>
</control>
```

#### `ChartGridMode` values

The actual stored values are `Chart` / `Grid` / `All` — **not** `ChartOnly` / `GridOnly` / `ChartAndGrid` (those Microsoft-docs strings don't appear in any OOB dashboard XML).

| Value | Behaviour |
|-------|-----------|
| `Chart` | Show the chart only (HSO default for `AddDashboardChart`) |
| `Grid` | Show the list only (HSO default for `AddDashboardList`) |
| `All` | Show both — user can toggle. Rare on UCI per [crmtipoftheday #1316](https://crmtipoftheday.com/1316/do-form-embedded-charts-work-in-unified-interface/) — chart+grid together has rendering issues. |

#### Empty self-closing parameter elements

`<ViewIds />` and `<RelationshipName />` must be emitted as **empty self-closing elements**, not omitted entirely and not populated with the same GUID as `<ViewId>`. OOB dashboards always emit them empty. This is the single most subtle difference between OOB and naive hand-written dashboard XML.

**HSO defaults applied by `AddDashboardChart` / `AddDashboardList`:** all picker/jump-bar params default to `false`, `RecordsPerPage=5`, `AutoExpand=Fixed`, `IsUserChart=false`, `IsUserView=false`. Microsoft rule: system dashboards may only host system charts, so `IsUserChart` is always `false` here.

**Outer-join trap (lists):** lists silently can't render outer-joined views. Pick views built with `<link-entity link-type='inner'>` or replace the list with a chart. (SOP §6, [crmtipoftheday #499](https://crmtipoftheday.com/499/outer-joins-and-dashboards/).)

**Power Apps grid control mandatory:** the modern Power Apps grid renders correctly; the deprecated Power Apps Read-Only grid renders blank on dashboards. The default subgrid classid above renders via the modern grid.

### Web resource cell

`classid="{9FDF5F91-88B1-47F4-AD53-C11EFC01A01D}"` (HTML web resource host).

```xml
<cell id="{cell-guid}" colspan="3" rowspan="1" showlabel="false" locklevel="0">
  <control id="wr_filterStrip" classid="{9FDF5F91-88B1-47F4-AD53-C11EFC01A01D}">
    <parameters>
      <Url>$webresource:hso_/html/dashboards/filter-strip.html</Url>
      <PassParameters>true</PassParameters>
      <Security>false</Security>
      <Scrolling>auto</Scrolling>
      <Border>true</Border>
    </parameters>
  </control>
</cell>
```

**Form-enabled WRs only.** HTML / JS / image / XML web resources marked form-displayable. CSS / library WRs are not addable to a dashboard.

**`Security` parameter** controls iframe cross-frame scripting:
- `false` → no cross-frame scripting (default; safe for static HTML widgets, filter strips, KPI cards).
- `true` → cross-frame scripting enabled (system dashboards only; **forbidden** on personal `UserForm` dashboards — returns `UnrestrictedIFrameInUserDashboard` error code).

`PassParameters=true` passes record context (none for system dashboards) plus query-string parameters. Useful for HTML web resources that need to know the current user / org / app context.

### PCF cell (standalone, not field-bound)

The outer cell host uses the web-resource classid; the PCF binding is declared via a `<customControl>` child element.

```xml
<cell id="{cell-guid}" colspan="3" rowspan="6" showlabel="false" locklevel="0">
  <control id="pcf_progressOfCare" classid="{9FDF5F91-88B1-47F4-AD53-C11EFC01A01D}">
    <customControl name="hso_HSO.Dynamics.PCF.ProgressOfCareChart"
                   formFactor="0" version="1.0.0" />
    <parameters>
      <clientId type="SingleLine.Text">00000000-0000-0000-0000-000000000000</clientId>
      <dateFrom type="SingleLine.Text">2025-01-01</dateFrom>
    </parameters>
  </control>
</cell>
```

**Different from form-bound PCFs.** On a form, a PCF is bound to a field via `<controlDescriptions>` / `<controlDescription forControl="...">`. On a dashboard there is no field binding — the PCF is a free-standing cell, and parameters must be **static** values or read by the PCF itself from the URL query string (`?data=...`).

**Per SOP §13** (Diana Birkelbach's caveat): dataset PCFs designed for subgrids may behave differently in dashboard context. Always test in dashboard context specifically — don't assume "works on a subgrid" means "works on a dashboard."

### Power BI tile cell

`classid="{F297668D-71BE-4C8C-960F-30CCD09CDE19}"` (Power BI report tile).

```xml
<cell id="{cell-guid}" colspan="2" rowspan="4" showlabel="false" locklevel="0">
  <control id="pbi_networkPerformance" classid="{F297668D-71BE-4C8C-960F-30CCD09CDE19}">
    <parameters>
      <PowerBIGroupId>@hso_pbi_workspace_id</PowerBIGroupId>
      <PowerBIReportId>@hso_pbi_networkperf_report_id</PowerBIReportId>
      <PowerBITileId>@hso_pbi_networkperf_tile_id</PowerBITileId>
    </parameters>
  </control>
</cell>
```

**Environment Variable references** (`@variable_name`) are strongly preferred over hard-coded GUIDs — DEV / TEST / UAT / PROD each bind to their own workspace per SOP §8. Manage the env vars themselves via [`hso-dataverse-deployment-settings`](../../hso-dataverse-deployment-settings/SKILL.md).

`PowerBITileId` is optional (only when embedding a single tile from a Power BI dashboard — for full reports, omit).

**RLS:** dynamic Row-Level Security via `userprincipalname()` flows through automatically. **Service principals cannot be added to RLS roles** — this is a Microsoft platform constraint, not a workaround away.

---

## Supported control parameters (all components)

Per Microsoft's reference. Every parameter listed here can appear inside a cell's `<control><parameters>` block; specific subsets apply per component type.

| Parameter | Applies to | Purpose |
|-----------|------------|---------|
| `ViewIds` | List, Chart | Comma-separated list of view GUIDs the picker can switch between (used when `EnableViewPicker=true`) |
| `ViewId` | List, Chart | The default view to render |
| `IsUserView` | List, Chart | Whether `ViewId` refers to a `userquery` (true) or `savedquery` (false). HSO production = false. |
| `IsUserChart` | Chart | Whether `VisualizationId` refers to a `userqueryvisualization` (true) or `savedqueryvisualization` (false). HSO production = false. |
| `TargetEntityType` | List, Chart | Logical name of the table the view / chart targets |
| `AutoExpand` | List | `Auto` / `Fixed` / `AutoWithFixedMax` |
| `RecordsPerPage` | List | Default page size (HSO default: 5) |
| `EnableQuickFind` | List | Search box visibility (HSO default: false) |
| `EnableViewPicker` | List, Chart | View dropdown visibility (HSO default: false) |
| `EnableJumpBar` | List | A-Z jump bar visibility (HSO default: false) |
| `EnableChartPicker` | Chart | Chart dropdown visibility (HSO default: false) |
| `ChartGridMode` | Chart | `ChartOnly` / `GridOnly` / `ChartAndGrid` (HSO default: ChartOnly — chart+grid together is unsupported on UCI per crmtipoftheday #1316) |
| `VisualizationId` | Chart | The system chart GUID |
| `Url` | WebResource | `$webresource:` prefixed name |
| `PassParameters` | WebResource | Pass record context as query string |
| `Security` | WebResource | Enable cross-frame scripting (system dashboards only) |
| `Scrolling` | WebResource | `auto` / `yes` / `no` |
| `Border` | WebResource | Show iframe border |
| `PowerBIGroupId` | PBI tile | Workspace ID (env-var preferred) |
| `PowerBIReportId` | PBI tile | Report ID (env-var preferred) |
| `PowerBITileId` | PBI tile | Tile ID (optional, for single-tile embeds) |

---

## Component limits (recap from SOP §3)

- **6 components per dashboard** (Microsoft default cap, configurable to 20 via `MaximumControlsLimit` PowerShell setting).
- **HSO target: ≤ 6** for portability across environments — don't rely on the cap being raised.
- Four legitimate ways past the cap: second dashboard, interactive dashboard, custom page, Power BI. **HSO project rule for this engagement: no custom pages — use HTML web resources or split into multiple dashboards.**
- 50K row pre-aggregation cap (`AggregateQueryRecordLimit`) — every chart's FetchXML must constrain its scan to under 50K rows before aggregation. Date range filters, `statecode = active`, ownership filters are the standard knobs.

---

## Cell positioning

The skill's Add* operations use `-RowIndex` and `-ColumnIndex` to position cells:

- `RowIndex = -1` → append a new component `<row>` at the end of the section.
- `RowIndex >= 0` → place the cell into the **component row** at that 0-based index (rows that hold at least one `<cell>`; filler rows are skipped) — creates the row if it doesn't exist.
- `ColumnIndex = -1` → append the cell at the end of the row.
- `ColumnIndex >= 0` → insert the cell at that 0-based position within the row's existing cells.

`ColSpan` and `RowSpan` control the cell's grid footprint; the section's `columns` attribute (set by `LayoutPreset` at `CreateDashboard` time) is the maximum colspan that fits horizontally without wrapping.

## Grid rows and filler `<row />` elements (the part hand-written FormXml always gets wrong)

The section is a **real grid**: every `<row>` element is one grid row and a cell with `rowspan="N"` occupies N of them. Both designers therefore emit, after each row that holds cells, `max(rowspan) − 1` **empty** `<row />` elements; OOB dashboards carry the same shape. This is what a designer-built 3-charts-over-2-lists dashboard actually stores (rowspan 12 everywhere, 11 fillers per band):

```xml
<rows>
  <row>
    <cell colspan="1" rowspan="12" …>…chart…</cell>
    <cell colspan="1" rowspan="12" …>…chart…</cell>
    <cell colspan="1" rowspan="12" …>…chart…</cell>
  </row>
  <row /><row /><row /><row /><row /><row /><row /><row /><row /><row /><row />
  <row>
    <cell colspan="3" rowspan="12" …>…list…</cell>
  </row>
  <row /><row /><row /><row /><row /><row /><row /><row /><row /><row /><row />
  <row>
    <cell colspan="3" rowspan="12" …>…list…</cell>
  </row>
  <row /><row /><row /><row /><row /><row /><row /><row /><row /><row /><row />
</rows>
```

**Without the fillers** the next `<row>` starts on grid row +1 while the previous cells still span their rows. The classic designer renders the later bands shifted right / overlapping diagonally; UCI, which positions each band by cumulative rowspan (its cell ids are `<sectionId>_<gridRow>_<col>_<n>` — 0, 8, 16 for three rowspan-8 bands), stretches a lone cell across the whole band and mis-sizes the rest. The skill's `Sync-DashboardFillerRows` re-derives the fillers on every write (band model: cells of one component row start on the same grid row); `NormalizeDashboardLayout` repairs dashboards written before 2026-08-19.

**UCI sizing (measured, 1920-px viewport):** cell height = **49 px × rowspan**. A Power Apps grid list needs `145 + 42 × RecordsPerPage` px (command bar, column header, pager, padding + 42 px per record) → `rowspan ≥ ceil((145 + 42 × records) / 49)`: 5 → 8, 8 → 10, 10 → 12. `rowspan=4` is exactly one visible record. A chart keeps 104 px of header (title + legend row) inside its cell.

---

## References

- Microsoft Learn — [Understand dashboards: Dashboard components, FormXml](https://learn.microsoft.com/en-us/power-apps/developer/model-driven-apps/understand-dashboards-dashboard-components-formxml)
- Microsoft Learn — [SystemForm entity reference](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/entities/systemform)
- HSO SOP — [`shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md`](../../../../shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md)
- crmtipoftheday — [#594 Handcrafting your dashboards](https://crmtipoftheday.com/594/tip-594-handcrafting-your-dashboards/) (regenerate cell IDs after copy/paste — silent breakage if you don't)
- crmtipoftheday — [#499 Outer joins and dashboards](https://crmtipoftheday.com/499/outer-joins-and-dashboards/)
- crmtipoftheday — [#1316 Form-embedded charts on Unified Interface](https://crmtipoftheday.com/1316/do-form-embedded-charts-work-in-unified-interface/) (chart + subgrid dual-display unsupported)
