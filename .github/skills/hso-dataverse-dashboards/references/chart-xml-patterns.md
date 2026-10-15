# Chart XML Patterns Reference

Templates for the FetchXML data description and DataVisualization.Charting presentation description that the `CreateSystemChart` operation emits. Authoritative source: Microsoft's [Visualization (charts) overview](https://learn.microsoft.com/en-us/power-apps/developer/model-driven-apps/customize-dev-visualizations-dashboards) and [Specify chart data](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/customize-dev-visualizations-dashboards#specify-the-chart-data). Methodology: [SOP §5](../../../../shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md#5-charts-on-dashboards).

For chart authoring beyond the templates here — YoY comparisons, multi-entity series, N:N relationship charts, stacked totals, percentage labels, scale breaks, annotations — the canonical tooling is [Chart Manager](https://www.xrmtoolbox.com/plugins/MsCrmTools.ChartManager/) (Tanguy Touzard) for raw XML edits and [Advanced Chart Editor](https://www.xrmtoolbox.com/plugins/ITLec.CRMChartGuy.XRMToolBox.AdvancedChartEditor/) (Ulrik Carlsson + Mohamed Rasheed) for the visual layer on top. SOP §5 cites the canonical CRM Chart Guy patterns for each non-template scenario.

---

## Chart object — the two XML strings

A `savedqueryvisualization` record has two key columns:

1. **`datadescription`** — XML wrapping a FetchXML aggregate query that defines the data shape.
2. **`presentationdescription`** — DataVisualization.Charting markup that controls the visual.

Both are required. The skill emits both from a small set of inputs (`ChartType`, `GroupByColumn`, `AggregateColumn`, `AggregateFunction`, optional `ChartFilter` and `GroupByDateInterval`).

---

## Data description templates

### Bar / column / pie / funnel — count by category

```xml
<datadefinition>
  <fetchcollection>
    <fetch mapping='logical' aggregate='true'>
      <entity name='hso_examplecase'>
        <attribute groupby='true' alias='groupby_hso_status_code' name='hso_status_code' />
        <attribute aggregate='count' alias='agg_hso_examplecaseid' name='hso_examplecaseid' />
        <order alias='groupby_hso_status_code' descending='false' />
      </entity>
    </fetch>
  </fetchcollection>
  <categorycollection>
    <category alias='groupby_hso_status_code'>
      <measurecollection>
        <measure alias='agg_hso_examplecaseid' />
      </measurecollection>
    </category>
  </categorycollection>
</datadefinition>
```

### Line — count over a date dimension

```xml
<datadefinition>
  <fetchcollection>
    <fetch mapping='logical' aggregate='true'>
      <entity name='hso_examplecase'>
        <attribute groupby='true' alias='groupby_createdon' name='createdon' dategrouping='week' />
        <attribute aggregate='count' alias='agg_hso_examplecaseid' name='hso_examplecaseid' />
        <order alias='groupby_createdon' descending='false' />
        <filter>
          <condition attribute='createdon' operator='last-x-months' value='3' />
        </filter>
      </entity>
    </fetch>
  </fetchcollection>
  <categorycollection>
    <category alias='groupby_createdon'>
      <measurecollection>
        <measure alias='agg_hso_examplecaseid' />
      </measurecollection>
    </category>
  </categorycollection>
</datadefinition>
```

`dategrouping` values: `day`, `week`, `month`, `quarter`, `year`.

### Sum / avg / min / max — on a numeric column

```xml
<attribute aggregate='sum' alias='agg_hso_amount_amt' name='hso_amount_amt' />
```

`AggregateFunction` values supported: `count`, `countcolumn`, `sum`, `avg`, `min`, `max`. For `count`, use the table's primary key as `AggregateColumn` (e.g. `hso_examplecaseid`). For `countcolumn` (count of non-null values in a specific column), pass that column.

---

## The 50K pre-aggregation cap

Microsoft enforces `AggregateQueryRecordLimit = 50,000`. *"For an aggregate query, the maximum number of records that can be processed in any environment is 50000. This limit is fixed and can't be changed."*

**Every chart's FetchXML must constrain its scan to under 50K rows before aggregation.** Standard knobs:

| Knob | Example FetchXML filter |
|------|--------------------------|
| Date range | `<condition attribute='createdon' operator='last-x-months' value='3' />` |
| Active state | `<condition attribute='statecode' operator='eq' value='0' />` |
| Owning user | `<condition attribute='ownerid' operator='eq-userid' />` |
| Owning team | `<condition attribute='ownerid' operator='eq-userteams' />` |

Pass via `-ChartFilter` to `CreateSystemChart`. If the source set is genuinely > 50K and unfilterable, the chart belongs in **Power BI** — embed it via `AddDashboardPowerBITile` instead.

---

## Presentation description — the HSO palette

The skill emits a presentation description with the HSO palette baked in (`Get-ChartPresentationXml` in the script is the single source of truth; `CreateSystemChart` and `UpdateSystemChart -ChartType` both call it):

```
PaletteCustomColors='31,78,121; 79,179,220; 46,125,50; 242,160,7; 140,83,152; 200,16,46; …'
```

| RGB | Hex | Role |
|-----|-----|------|
| `31,78,121`  | `#1F4E79` | Primary (HSO deep blue) — also the single-series `Color` |
| `79,179,220` | `#4FB3DC` | Accent (sky) |
| `46,125,50`  | `#2E7D32` | Process / status (clinical green) |
| `242,160,7`  | `#F2A007` | Warning |
| `140,83,152` | `#8C5398` | Series 5 |
| `200,16,46`  | `#C8102E` | Series 6 / outliers |

(Followed by the OOB blues/oranges so 7+ categories still get distinct colours.) For projects with their own palette, override via `UpdateSystemChart -PresentationDescription <file>` or [Chart Manager](https://www.xrmtoolbox.com/plugins/MsCrmTools.ChartManager/).

### What every template does — and why (UCI rendering facts, verified 2026-08-19)

UCI renders charts with Highcharts behind a **modern chart header**: the chart *name* becomes an HTML title row above the canvas, and the Highcharts **legend is pulled up (−27 px) into that header row**; UCI **ignores `Legend Docking` / `Alignment`** (tested `Right`, `Bottom`, `Center`, `IsDockedInsideChartArea`). A left-aligned one-entry legend therefore overprints the title — which is exactly what the pre-2026-08-19 skeleton (`Palette='BrightPastel'`, `<Legend Name='Default' />`, `<Titles />`) produced. Hence the template rules, all mirrored from OOB charts (`Accounts by Owner`, `New Accounts By Month`, `Articles By Status`):

| Element | Rule |
|---|---|
| `<Titles>` | One `<Title Alignment='TopLeft' DockingOffset='-3' Font='{0}, 13px' ForeColor='59, 59, 59' />` with empty text — UCI fills in the chart name. |
| `<Legends>` | **Omitted** for single-series Bar / Column / Line (OOB does the same; a "Count:All (Table)" legend is noise). Right-docked for Pie / Funnel, bottom-docked for Stacked* — honoured by the classic renderer and harmless in UCI. |
| `<Series>` | `IsValueShownAsLabel='True'` + `<SmartLabelStyle Enabled='True' />`; single-series `Color='31, 78, 121'`; bars/columns `CustomProperties='PointWidth=0.75, MaxPixelPointWidth=40'`; pies `PieLabelStyle=Inside`. |
| Axes | OOB greys: `LineColor='165, 172, 181'`, Y `MajorGrid LineColor='239, 242, 246'`, X gridlines off, labels `{0}, 10.5px` / `59, 59, 59`. |

### Bar / column chart presentation (what the script emits)

```xml
<Chart Palette='None' PaletteCustomColors='31,78,121; 79,179,220; 46,125,50; 242,160,7; 140,83,152; 200,16,46; 91,151,213; 237,125,49; 160,116,166; 255,192,0; 68,114,196; 112,173,71'>
  <Series>
    <Series ChartType='Column' IsValueShownAsLabel='True' Color='31, 78, 121' BackSecondaryColor='41, 88, 145' Font='{0}, 9.5px' LabelForeColor='59, 59, 59' CustomProperties='PointWidth=0.75, MaxPixelPointWidth=40'>
      <SmartLabelStyle Enabled='True' />
    </Series>
  </Series>
  <ChartAreas>
    <ChartArea BorderColor='White' BorderDashStyle='Solid'>
      <AxisY LabelAutoFitMinFontSize='8' TitleForeColor='59, 59, 59' TitleFont='{0}, 10.5px' LineColor='165, 172, 181' IntervalAutoMode='VariableCount'>
        <MajorGrid LineColor='239, 242, 246' /><MajorTickMark LineColor='165, 172, 181' /><LabelStyle Font='{0}, 10.5px' ForeColor='59, 59, 59' />
      </AxisY>
      <AxisX LabelAutoFitMinFontSize='8' TitleForeColor='59, 59, 59' TitleFont='{0}, 10.5px' LineColor='165, 172, 181' IntervalAutoMode='VariableCount'>
        <MajorGrid Enabled='False' /><MajorTickMark Enabled='False' /><LabelStyle Font='{0}, 10.5px' ForeColor='59, 59, 59' />
      </AxisX>
    </ChartArea>
  </ChartAreas>
  <Titles><Title Alignment='TopLeft' DockingOffset='-3' Font='{0}, 13px' ForeColor='59, 59, 59' /></Titles>
</Chart>
```

### Pie chart presentation (what the script emits)

```xml
<Chart Palette='None' PaletteCustomColors='…same palette…'>
  <Series>
    <Series ChartType='Pie' IsValueShownAsLabel='True' ShadowOffset='0' Font='{0}, 9.5px' LabelForeColor='59, 59, 59' CustomProperties='PieLabelStyle=Inside, PieDrawingStyle=Default'>
      <SmartLabelStyle Enabled='True' />
    </Series>
  </Series>
  <ChartAreas><ChartArea><Area3DStyle Enable3D='false' /></ChartArea></ChartAreas>
  <Legends><Legend Alignment='Center' LegendStyle='Table' Docking='Right' IsEquallySpacedItems='True' Font='{0}, 11px' ShadowColor='0, 0, 0, 0' ForeColor='59, 59, 59' /></Legends>
  <Titles><Title Alignment='TopLeft' DockingOffset='-3' Font='{0}, 13px' ForeColor='59, 59, 59' /></Titles>
</Chart>
```

Funnel = the Pie shape with `ChartType='Funnel'` and `CustomProperties='FunnelStyle=YIsHeight, FunnelNeckHeight=0, FunnelPointGap=1'`; Line = the bar shape with `ChartType='Line' BorderWidth='3' MarkerStyle='Circle' MarkerSize='8'`; Stacked* = the bar shape plus a bottom-docked legend.

### Chart type keyword mapping

The `ChartType` parameter maps directly to the `<Series ChartType='...'>` attribute:

| Skill parameter | DataVisualization.Charting type |
|-----------------|---------------------------------|
| `Bar`           | `Bar` |
| `Column`        | `Column` |
| `Line`          | `Line` |
| `Pie`           | `Pie` |
| `Funnel`        | `Funnel` |
| `StackedBar`    | `StackedBar` |
| `StackedColumn` | `StackedColumn` |

---

## Accessibility — hatch + colour, never colour alone

Per SOP §5 / [crmtipoftheday #1102](https://crmtipoftheday.com/1102/use-hatch-style-in-your-charts-and-dashboards-if-you-have-color-blind-employees/), colour-blind users can't distinguish red-vs-green series. For multi-series charts, set per-series `BackHatchStyle`:

```xml
<Series Name='Series1' ChartType='StackedBar' Color='31, 78, 121' BackHatchStyle='LightHorizontal' />
<Series Name='Series2' ChartType='StackedBar' Color='79, 179, 220' BackHatchStyle='WideUpwardDiagonal' />
<Series Name='Series3' ChartType='StackedBar' Color='46, 125, 50' BackHatchStyle='DiagonalCross' />
```

**Hatch styles** that work well at dashboard density: `LightHorizontal`, `LightVertical`, `LightDownwardDiagonal`, `LightUpwardDiagonal`, `WideDownwardDiagonal`, `WideUpwardDiagonal`, `DiagonalCross`, `Percent20`, `Percent30`, `Percent40`. Avoid the heavy `Solid` patterns — they read as solid blocks at dashboard scale and defeat the point.

---

## Patterns beyond these templates (cite the source)

The community canon for chart XML, per SOP §5:

| Pattern | Source |
|---------|--------|
| **Year-over-year comparison** | Ulrik Carlsson — [Compare This Year to Last Year with a Dynamics CRM Chart](https://crmchartguy.wordpress.com/2015/06/21/compare-this-year-to-last-year-with-a-dynamics-crm-chart/) |
| **Multi-entity series** in one chart | Ulrik Carlsson — [Multiple Entities in One MS CRM Chart](https://crmchartguy.wordpress.com/2014/02/24/multiple-entities-in-one-ms-crm-chart/) |
| **N:N relationship** chart | Ulrik Carlsson — [N:N Relationship Charts](https://crmchartguy.wordpress.com/2014/11/05/nn-relationship-charts-in-ms-dynamics-crm/) |
| **Stacked totals on top** | Ulrik Carlsson — [Aggregate Total on Top of Stacked Column/Bar Charts](https://crmchartguy.wordpress.com/2013/03/10/aggregate-total-on-top-of-stacked-column-charts-or-bar-charts-in-ms-crm-2011/) |
| **Percentage labels** on 100% stacked / pie | Ulrik Carlsson + crmtipoftheday [#1095](https://crmtipoftheday.com/1095/add-percentage-labels-to-pie-charts/) |
| **Currency in millions / thousands** | crmtipoftheday [#1097](https://crmtipoftheday.com/1097/change-chart-labels-on-currency-values-to-show-in-millions-or-thousands/) |
| **Scale break** for wide-range numeric series | crmtipoftheday [#1101](https://crmtipoftheday.com/1101/add-a-scale-break-to-charts/) |
| **Annotations** on charts | crmtipoftheday [#1099](https://crmtipoftheday.com/1099/add-annotations-to-charts/) |
| **Power BI palette** applied to in-app charts | crmtipoftheday [#1096](https://crmtipoftheday.com/1096/apply-power-bi-theme-to-regular-charts/) |

For any of these, author once via Chart Manager / Advanced Chart Editor in DEV, then export the solution to ship — `CreateSystemChart` is for the common 80%, not for replacing chart-XML mastery.

---

## Chart limitations to design around

Per SOP §5 / Microsoft docs:

- *"Color coding isn't available for tag charts and doughnut charts"* on interactive dashboards (white / grey / black only). Don't promise the user a coloured doughnut.
- *"Chart drill-down functionality isn't available on charts in a subgrid or an associated grid."* Drill-down works on dashboard chart components but not subgrid charts.
- *"The chart drill-down feature is only available on the browser. It isn't available on the mobile app."*
- **Chart + grid dual-display** on a dashboard is not supported on UCI ([crmtipoftheday #1316](https://crmtipoftheday.com/1316/do-form-embedded-charts-work-in-unified-interface/)) — `ChartGridMode='ChartOnly'` is the safe default and matches the skill's HSO default.

---

## Promoting personal charts to system

If a chart was prototyped as a `userqueryvisualization` (personal chart), it must be promoted to system before referencing it from a system dashboard. Microsoft enforces system-only charts on system dashboards.

The community workflow: copy the data + presentation XML out via Chart Manager, then create as a `savedqueryvisualization` (this skill's `CreateSystemChart`) — see Carl de Souza's pattern: [Convert Personal Chart to System Chart](https://carldesouza.com/convert-personal-chart-system-chart-dynamics-365/).

---

## Reusing chart FetchXML in Power BI

If a chart graduates to Power BI (the source set is genuinely > 50K rows or the requirement is analytical), the FetchXML in `datadescription` is reusable as-is via Mark Carrington's [Use FetchXML in Power BI with Dynamics 365](https://crmchartguy.wordpress.com/2017/09/30/use-fetchxml-in-power-bi-with-dynamics-365-customer-engagement/). Don't rewrite the query — copy it across.

---

## References

- Microsoft Learn — [Visualization (charts) overview](https://learn.microsoft.com/en-us/power-apps/developer/model-driven-apps/customize-dev-visualizations-dashboards)
- Microsoft Learn — [SavedQueryVisualization entity reference](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/entities/savedqueryvisualization)
- Microsoft Learn — [Aggregate data using FetchXML — 50,000-record limit](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/fetchxml/aggregate-data)
- HSO SOP — [`shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md` §5](../../../../shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md#5-charts-on-dashboards)
- [CRM Chart Guy (Ulrik Carlsson)](https://crmchartguy.wordpress.com/) — chart XML authority
- [Chart Manager XrmToolBox plugin](https://www.xrmtoolbox.com/plugins/MsCrmTools.ChartManager/) — Tanguy Touzard
- [Advanced Chart Editor XrmToolBox plugin](https://www.xrmtoolbox.com/plugins/ITLec.CRMChartGuy.XRMToolBox.AdvancedChartEditor/) — Ulrik Carlsson + Mohamed Rasheed
