<#
.SYNOPSIS
    Performs Dataverse dashboard and system-chart operations using the Web API.

.DESCRIPTION
    This script manages Dataverse system dashboards (SystemForm Type=0) and the
    system charts (SavedQueryVisualization) they consume.

    Operation categories:
      - Dashboards: Query, Get, ListStructure, Create, AddChart, AddList,
        AddWebResource, AddPCFControl, AddPowerBITile, RemoveComponent,
        UpdateCellLayout, SetDefault, SetSecurityRoles, AddToApp, Publish
      - System Charts: Query, Get, Create (templates), Update (stub), Delete (stub)
      - Deferred: Interactive Experience dashboard authoring; personal dashboards

    IMPORTANT: This script modifies your Dataverse environment. It requires
    interactive authentication.

.PARAMETER Operation
    The operation to perform (see ValidateSet).

.PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com).

.NOTES
    Requires: PowerShell 5.1+, MSAL.PS module (auto-installed if missing)
    Companion SOP: shared/dv/agent/wiki/sop/model-driven-apps/dashboard-configuration-best-practices.md
    Companion skill: hso-dataverse-ui-config (forms, views, sitemap)
    Author: HSO Dataverse Dashboards Skill
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        # Dashboard Operations
        "QueryDashboards", "GetDashboard", "ListDashboardStructure", "CreateDashboard",
        "AddDashboardChart", "AddDashboardList", "AddDashboardWebResource",
        "AddDashboardPCFControl", "AddDashboardPowerBITile",
        "RemoveDashboardComponent", "UpdateDashboardCellLayout", "NormalizeDashboardLayout",
        "SetDashboardDefault", "SetDashboardSecurityRoles",
        "AddDashboardToApp", "PublishDashboard", "PublishApp",
        # System Chart Operations
        "QuerySystemCharts", "GetSystemChart", "CreateSystemChart",
        "UpdateSystemChart", "DeleteSystemChart"
    )]
    [string]$Operation,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentUrl,


    [Parameter(Mandatory = $false)]
    [switch]$SkipPublish,

    # Common
    [string]$SolutionName,
    [string]$TableName,
    [string]$AppModuleUniqueName,

    # Dashboard identity
    [string]$DashboardId,
    [string]$DashboardName,
    [string]$DashboardNameFilter,
    [string]$DashboardDescription,

    # Dashboard layout
    [ValidateSet("2Column", "3ColumnUniform", "3ColumnVaried", "4Column", "PowerBIEmbedded", "Interactive")]
    [string]$LayoutPreset = "3ColumnUniform",

    # Cell positioning
    [string]$CellName,
    [int]$ColumnIndex = -1,
    [int]$RowIndex = -1,
    [int]$ColSpan = 1,
    # RowSpan unit ~= one grid row (~40px in UCI). 8 is the empirically-safe default for a
    # chart or a 5-record list; a list at rowspan=4 shows ONE record and a scrollbar.
    # See SKILL.md "Component fit to cell" for the per-component table.
    [int]$RowSpan = 8,

    # Cell label / showlabel
    # If $CellLabel is empty, list/chart Add ops auto-fetch the view/chart name as the label.
    # $CellShowLabel defaults differ by op:
    #   - Add-ListComponent     defaults to $true  (lists need a visible label so users know
    #                                                which view they're seeing — see SOP §4)
    #   - Add-ChartComponent    defaults to $false (chart visualisation has its own embedded title)
    [string]$CellLabel,
    [Nullable[bool]]$CellShowLabel = $null,

    # Chart cell parameters
    [string]$VisualizationId,
    [string]$ViewId,
    [string]$TargetEntityType,
    [bool]$EnableChartPicker = $false,
    # ChartGridMode values match the FormXml.xsd subgrid-parameter group used by Dataverse dashboards:
    # "Chart" = chart-only, "Grid" = list-only, "All" = chart + grid switcher.
    [ValidateSet("Chart", "Grid", "All")]
    [string]$ChartGridMode = "Chart",
    [bool]$IsUserChart = $false,
    [bool]$IsUserView = $false,

    # List cell parameters
    [bool]$EnableViewPicker = $false,
    [bool]$EnableQuickFind = $false,
    [bool]$EnableJumpBar = $false,
    [int]$RecordsPerPage = 5,
    [ValidateSet("Auto", "Fixed", "AutoWithFixedMax")]
    [string]$AutoExpand = "Fixed",

    # Web Resource cell parameters
    [string]$WebResourceUrl,
    [bool]$WebResourcePassParameters = $false,
    [bool]$WebResourceBorder = $true,
    [ValidateSet("auto", "yes", "no")]
    [string]$WebResourceScrolling = "auto",

    # PCF cell parameters
    [string]$PCFControlName,
    [string]$PCFParametersJson,
    [string]$PCFVersion = "1.0.0",

    # Power BI cell parameters
    [string]$PowerBIWorkspaceId,
    [string]$PowerBIReportId,
    [string]$PowerBITileId,

    # Default / Security
    [string[]]$RoleIds,

    # Chart authoring
    [string]$ChartId,
    [string]$ChartName,
    [string]$ChartDescription,
    [ValidateSet("Bar", "Column", "Line", "Pie", "Funnel", "StackedBar", "StackedColumn")]
    [string]$ChartType = "Column",
    [string]$GroupByColumn,
    [ValidateSet("day", "week", "month", "quarter", "year", "")]
    [string]$GroupByDateInterval = "",
    [string]$AggregateColumn,
    [ValidateSet("count", "countcolumn", "sum", "avg", "min", "max")]
    [string]$AggregateFunction = "count",
    [string]$ChartFilter,
    # UpdateSystemChart: raw XML (inline string or a file path) to replace the stored definition
    [string]$PresentationDescription,
    [string]$DataDescription
)

#region Validation
#endregion

#region Shared Module Imports
$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"
. "$sharedDir\Dataverse-WebApi.ps1"
#endregion

#region Constants
# Promote -SkipPublish to the centralized gate read by Publish-DashboardCustomizations, mirroring
# hso-dataverse-ui-config. Before this, several ops documented the flag as "retained for backwards
# compatibility but ignored" and published unconditionally -- because their verification read
# needed a publish to have happened. Confirm-DashboardCellPersisted now reads the draft layer, so
# the flag can be honoured everywhere and a batch can publish once at the end.
$script:SkipPublishGlobal = [bool]$SkipPublish

$script:LanguageCode = 1033
# PCF placeholder classid for non-bound dashboard PCF cells (shared GUID for HTML host control)
$script:WebResourceClassId = "{9FDF5F91-88B1-47f4-AD53-C11EFC01A01D}"
# Dashboard cells (chart, list, and chart+grid hybrid) ALL use the subgrid classid.
# The form-embedded chart classid {587CDF98-...} is NOT valid for dashboard cells —
# the renderer leaves cells empty if it sees that classid here. Verified by diffing
# OOB dashboards (Sales Activity, Customer Service Manager, Customer Service Rep)
# against the FormXml.xsd subgrid-parameter group.
$script:SubgridClassId     = "{E7A81278-8635-4d9e-8D4D-59480B391C5B}"
$script:PowerBIClassId     = "{F297668D-71BE-4C8C-960F-30CCD09CDE19}"  # PowerBI report tile
#endregion

#region Helper Functions
function New-CellGuid { return "{$([guid]::NewGuid().ToString())}" }

function Invoke-DvApi {
    <#
    .SYNOPSIS
    Thin adapter over the shared Invoke-DataverseApi (hso-shared-scripts/scripts/Dataverse-WebApi.ps1,
    dot-sourced above). Kept as a local name + signature so the call sites below are
    unchanged; all HTTP/header/error logic now lives in the single shared implementation.
    The shared invoker throws the same "Dataverse API Error (Method Endpoint): ..." format
    this wrapper used, so the publish retry loop's message matching is preserved.
    #>
    param(
        [string]$Method,
        [string]$Endpoint,
        [object]$Body = $null,
        [string]$SolutionNameHeader = $null,
        [bool]$ReturnRepresentation = $true
    )
    return Invoke-DataverseApi -Method $Method -Endpoint $Endpoint -Body $Body `
        -SolutionName $SolutionNameHeader -ReturnRepresentation $ReturnRepresentation
}

function Get-DashboardFormXml {
    # -Unpublished reads the DRAFT layer, which is where a formxml PATCH lands. Use it to verify a
    # write without publishing first; use the default (published) read as the final gate that the
    # change actually reached users.
    param([string]$DashboardId, [switch]$Unpublished)
    $cleanId = $DashboardId -replace '[{}]', ''
    if ($Unpublished) {
        return Get-DataverseUnpublished -EntitySet 'systemforms' -Id $cleanId `
            -Select formid,name,type,objecttypecode,formxml,description,isdefault
    }
    $endpoint = "systemforms($cleanId)?`$select=formid,name,type,objecttypecode,formxml,description,isdefault"
    return Invoke-DvApi -Method "GET" -Endpoint $endpoint -ReturnRepresentation $false
}

function Set-DashboardFormXml {
    param([string]$DashboardId, [string]$FormXml)
    $cleanId = $DashboardId -replace '[{}]', ''
    # Compact whitespace for compact JSON serialization
    $compact = $FormXml -replace '\r?\n\s*', '' -replace '>\s+<', '><'
    $body = [ordered]@{ formxml = $compact }
    Invoke-DvApi -Method "PATCH" -Endpoint "systemforms($cleanId)" -Body $body -ReturnRepresentation $false | Out-Null
}

function Publish-DashboardCustomizations {
    <#
    .SYNOPSIS
    Publishes dashboard customizations with retry-on-conflict.

    .DESCRIPTION
    Back-to-back Add/Remove ops each call PublishXml; if a prior publish is still
    running server-side, the subsequent call fails with "The solution installation
    or removal failed due to the installation or removal of another solution at the
    same time. Please try again later." This wraps the call in a retry loop with
    short backoff so batch operations succeed without the caller having to space them.
    #>
    param(
        [string]$DashboardId,
        [int]$MaxAttempts = 5,
        [int]$InitialDelaySeconds = 3
    )
    # Centralized skip gate, mirroring hso-dataverse-ui-config's Publish-FormCustomizations. Set
    # $script:SkipPublishGlobal = $true at dispatch to defer publishing across a batch and publish
    # once at the end. Safe to defer now that Confirm-DashboardCellPersisted verifies against the
    # draft layer rather than needing a publish to have run first -- which is the whole point of
    # the change: the per-op publish existed for the verification read, and that is what made
    # back-to-back ops collide server-side.
    if ($script:SkipPublishGlobal) {
        Write-Host "  [skip-publish] deferring PublishXml for dashboard $DashboardId -- caller will batch-publish" -ForegroundColor DarkGray
        return
    }
    $cleanId = $DashboardId -replace '[{}]', ''
    $publishXml = "<importexportxml><dashboards><dashboard>{$cleanId}</dashboard></dashboards></importexportxml>"
    $delay = $InitialDelaySeconds
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Invoke-DvApi -Method "POST" -Endpoint "PublishXml" -Body @{ ParameterXml = $publishXml } -ReturnRepresentation $false | Out-Null
            Write-Host "  [OK] Dashboard customizations published" -ForegroundColor Green
            return
        }
        catch {
            $msg = $_.Exception.Message
            $isRetryable = $msg -match 'previous \[Publish\] running' -or `
                           $msg -match 'installation or removal of another solution' -or `
                           $msg -match 'Please try again later'
            if ($isRetryable -and $attempt -lt $MaxAttempts) {
                Write-Host "  [WARN] Publish in progress server-side; retrying in ${delay}s (attempt $attempt/$MaxAttempts)" -ForegroundColor Yellow
                Start-Sleep -Seconds $delay
                $delay = [Math]::Min($delay * 2, 30)  # exponential backoff up to 30s
                continue
            }
            throw
        }
    }
}

function Confirm-DashboardCellPersisted {
    <#
    .SYNOPSIS
    Verify-then-report by published-layer read-back (pattern ported from
    hso-dataverse-ui-config's Write-ViewConfirmation).

    .DESCRIPTION
    A PATCH to systemforms.formxml lands in the UNPUBLISHED layer; a plain GET keeps
    returning the PUBLISHED (pre-write) formxml until PublishXml runs. Echoing the PATCH
    response -- or re-reading before publish -- can therefore show the PRE-write layout
    next to an [OK], which reads as a failed write.

    Callers used to publish FIRST purely so this read could see the change. That is what made a
    batch of dashboard edits lose races against itself server-side (see Publish-DashboardCustomizations'
    retry loop). This now reads the DRAFT layer directly, so verification no longer depends on a
    publish having run, and the publish can move to once per batch.

    This proves the draft persisted -- NOT that users can see it. The batch's final published
    read-back remains the gate for that. The published read stays as a fallback so an org where the
    unpublished read is unavailable is no worse off than before.

    The verdict is always printed from a read-back -- never from the in-memory XML that was sent.

    Optional Expect* values (used by Update-CellLayout) turn the verdict into a
    requested-vs-persisted comparison.
    #>
    param(
        [string]$DashboardId,
        [string]$CellName,
        [ValidateSet('present', 'absent')]
        [string]$Expect = 'present',
        [Nullable[int]]$ExpectColSpan,
        [Nullable[int]]$ExpectRowSpan,
        [Nullable[int]]$ExpectRecordsPerPage
    )
    try {
        # Draft layer first -- that is where the PATCH landed. Published read is the fallback.
        $resp = $null
        try { $resp = Get-DashboardFormXml -DashboardId $DashboardId -Unpublished } catch { }
        if (-not $resp -or -not $resp.formxml) { $resp = Get-DashboardFormXml -DashboardId $DashboardId }
        [xml]$xml = $resp.formxml
        $control = $xml.SelectSingleNode("//cell/control[@id='$CellName']")
        if ($Expect -eq 'absent') {
            if ($control) {
                Write-Host "  [WARN] Published read-back still shows cell '$CellName' -- the remove may not have persisted. Re-run ListDashboardStructure before relying on it." -ForegroundColor Yellow
            } else {
                Write-Host "  [OK] Read-back confirms cell '$CellName' is gone" -ForegroundColor Green
            }
            return
        }
        if (-not $control) {
            Write-Host "  [WARN] PATCH + publish succeeded but the published read-back does not show cell '$CellName'. Re-run ListDashboardStructure before relying on it." -ForegroundColor Yellow
            return
        }
        $cell = $control.ParentNode
        $rpp = $control.SelectSingleNode("parameters/RecordsPerPage")
        $rppText = if ($rpp -and $rpp.InnerText) { " recordsPerPage=$($rpp.InnerText)" } else { "" }
        $mismatches = @()
        if ($null -ne $ExpectColSpan -and [string]$cell.colspan -ne $ExpectColSpan.ToString()) { $mismatches += "colspan=$($cell.colspan) (expected $ExpectColSpan)" }
        if ($null -ne $ExpectRowSpan -and [string]$cell.rowspan -ne $ExpectRowSpan.ToString()) { $mismatches += "rowspan=$($cell.rowspan) (expected $ExpectRowSpan)" }
        if ($null -ne $ExpectRecordsPerPage) {
            $actualRpp = if ($rpp) { $rpp.InnerText } else { '(none)' }
            if ($actualRpp -ne $ExpectRecordsPerPage.ToString()) { $mismatches += "RecordsPerPage=$actualRpp (expected $ExpectRecordsPerPage)" }
        }
        if ($mismatches.Count -gt 0) {
            Write-Host "  [WARN] Read-back mismatch for cell '$CellName': $($mismatches -join ', ') -- publish-layer lag or a concurrent write. Re-run ListDashboardStructure before relying on it." -ForegroundColor Yellow
        } else {
            Write-Host "  [OK] Read-back confirms cell '$CellName': colspan=$($cell.colspan) rowspan=$($cell.rowspan)$rppText" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  [WARN] Write accepted but read-back failed ($($_.Exception.Message)) -- verify with ListDashboardStructure." -ForegroundColor Yellow
    }
}

function ConvertTo-CompactXml {
    param([xml]$Xml)
    $sw = New-Object System.IO.StringWriter
    $Xml.Save($sw)
    return ($sw.ToString() -replace '<\?xml[^?]*\?>\s*', '')
}

function Get-DashboardSection {
    <#
    .SYNOPSIS
    Returns the (single) <section> element of a dashboard's formxml. Dashboards
    have a single tab with a single column with a single section that holds all cells.
    #>
    param([xml]$FormXml)
    $section = $FormXml.SelectSingleNode("//tabs/tab/columns/column/sections/section")
    if (-not $section) { throw "Dashboard FormXml has no section element. Was this dashboard created via CreateDashboard?" }
    return $section
}

function Sync-DashboardFillerRows {
    <#
    .SYNOPSIS
    Re-derives the empty filler <row /> elements a dashboard section needs so that each
    cell's rowspan is honoured by the grid -- the "band" model the dashboard designers emit.

    .DESCRIPTION
    A dashboard section is a real grid: every <row> element is ONE grid row, and a cell
    with rowspan="N" occupies N grid rows. The designers (classic and modern) therefore
    emit, after every row that holds cells, (max rowspan in that row - 1) EMPTY <row />
    elements. OOB dashboards carry the same shape (e.g. a rowspan="12" row followed by
    11+ <row /> fillers). Without the fillers the next component row starts on grid row
    +1 while the previous cells still occupy their span: the classic designer renders
    the lists shifted/overlapping diagonally, and the grid footprint no longer matches
    what UCI paints. (Observed on a skill-built dashboard vs. the same dashboard rebuilt
    by hand in the designer -- the only structural difference was the fillers.)

    Band model: component rows (rows that contain at least one <cell>) are kept in
    document order; every empty <row> is discarded and regenerated as
    (max(rowspan) - 1) fillers after its component row. Cells in the same component row
    are assumed to start on the same grid row -- the layout every pattern in SKILL.md uses.
    Idempotent; safe to run on every write and on legacy dashboards (NormalizeDashboardLayout).

    Returns a summary object { ComponentRows; FillerRows } for logging.
    #>
    param(
        [xml]$FormXml,
        [System.Xml.XmlElement]$Section
    )
    $rowsNode = $Section.SelectSingleNode("rows")
    if (-not $rowsNode) {
        $rowsNode = $FormXml.CreateElement("rows")
        $Section.AppendChild($rowsNode) | Out-Null
    }
    $componentRows = @($rowsNode.SelectNodes("row[cell]"))
    # Detach everything (component rows + stale fillers), then re-append in band order.
    foreach ($r in @($rowsNode.SelectNodes("row"))) { $rowsNode.RemoveChild($r) | Out-Null }
    $fillerTotal = 0
    foreach ($row in $componentRows) {
        $rowsNode.AppendChild($row) | Out-Null
        $maxSpan = 1
        foreach ($cell in @($row.SelectNodes("cell"))) {
            $span = 0
            if ([int]::TryParse([string]$cell.GetAttribute("rowspan"), [ref]$span) -and $span -gt $maxSpan) { $maxSpan = $span }
        }
        for ($i = 1; $i -lt $maxSpan; $i++) {
            $rowsNode.AppendChild($FormXml.CreateElement("row")) | Out-Null
            $fillerTotal++
        }
    }
    return [pscustomobject]@{ ComponentRows = $componentRows.Count; FillerRows = $fillerTotal }
}

function Add-CellToSection {
    <#
    .SYNOPSIS
    Appends a <cell> element (containing a fully-formed <control>) to the section.
    Creates a new component <row> when RowIndex == -1 or no row exists, then re-derives
    the filler rows (Sync-DashboardFillerRows) so the grid footprint matches the rowspans.

    RowIndex addresses COMPONENT rows only (rows that hold at least one <cell>) -- the
    empty filler <row /> elements are a derived artifact and are never addressable.
    #>
    param(
        [xml]$FormXml,
        [System.Xml.XmlElement]$Section,
        [System.Xml.XmlElement]$CellElement,
        [int]$RowIndex,
        [int]$ColumnIndex
    )
    $rowsNode = $Section.SelectSingleNode("rows")
    if (-not $rowsNode) {
        $rowsNode = $FormXml.CreateElement("rows")
        $Section.AppendChild($rowsNode) | Out-Null
    }
    $rows = @($rowsNode.SelectNodes("row[cell]"))

    $targetRow = $null
    if ($RowIndex -ge 0 -and $RowIndex -lt $rows.Count) {
        $targetRow = $rows[$RowIndex]
    }
    elseif ($RowIndex -eq -1 -and $rows.Count -gt 0) {
        $targetRow = $rows[$rows.Count - 1]
    }
    if (-not $targetRow) {
        $targetRow = $FormXml.CreateElement("row")
        $rowsNode.AppendChild($targetRow) | Out-Null
    }

    $existingCells = @($targetRow.SelectNodes("cell"))
    if ($ColumnIndex -ge 0 -and $ColumnIndex -lt $existingCells.Count) {
        $targetRow.InsertBefore($CellElement, $existingCells[$ColumnIndex]) | Out-Null
    }
    else {
        $targetRow.AppendChild($CellElement) | Out-Null
    }
    Sync-DashboardFillerRows -FormXml $FormXml -Section $Section | Out-Null
}

function New-CellElement {
    <#
    .SYNOPSIS
    Builds a <cell> wrapper around a <control> element with the standard dashboard
    cell attributes (id, colspan, rowspan, showlabel, auto, labels).
    #>
    param(
        [xml]$FormXml,
        [System.Xml.XmlElement]$ControlElement,
        [int]$ColSpan,
        [int]$RowSpan,
        [string]$CellLabel = "",
        [bool]$ShowLabel = $false
    )
    # Dashboard cell schema differs from form cells: uses `auto="false"` instead of `locklevel`.
    # `<labels>` is always required (Dataverse validator rejects cells without one).
    $cell = $FormXml.CreateElement("cell")
    $cell.SetAttribute("colspan", $ColSpan.ToString())
    $cell.SetAttribute("rowspan", $RowSpan.ToString())
    $cell.SetAttribute("showlabel", $ShowLabel.ToString().ToLower())
    $cell.SetAttribute("id", (New-CellGuid))
    $cell.SetAttribute("auto", "false")

    $labels = $FormXml.CreateElement("labels")
    $label = $FormXml.CreateElement("label")
    $effectiveLabel = if ($CellLabel) { $CellLabel } else { "Cell" }
    $label.SetAttribute("description", $effectiveLabel)
    $label.SetAttribute("languagecode", $script:LanguageCode.ToString())
    $labels.AppendChild($label) | Out-Null
    $cell.AppendChild($labels) | Out-Null

    $cell.AppendChild($ControlElement) | Out-Null
    return $cell
}

function Get-ViewName {
    <#
    .SYNOPSIS
    Looks up a saved query (view) name by ID. Used to auto-derive the cell label
    for list cells when the caller doesn't provide one explicitly.
    Returns $null if the view isn't found (caller should fall back to the cell name).
    #>
    param([string]$ViewId)
    if (-not $ViewId) { return $null }
    $clean = $ViewId -replace '[{}]', ''
    try {
        $resp = Invoke-DvApi -Method "GET" -Endpoint "savedqueries($clean)?`$select=name" -ReturnRepresentation $false
        return $resp.name
    } catch {
        Write-Host "  [WARN] Could not resolve view name for $ViewId : $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

function Get-ChartName {
    <#
    .SYNOPSIS
    Looks up a system chart (savedqueryvisualization) name by ID. Used to auto-derive
    the cell label for chart cells when the caller doesn't provide one explicitly.
    Returns $null if the chart isn't found.
    #>
    param([string]$ChartId)
    if (-not $ChartId) { return $null }
    $clean = $ChartId -replace '[{}]', ''
    try {
        $resp = Invoke-DvApi -Method "GET" -Endpoint "savedqueryvisualizations($clean)?`$select=name" -ReturnRepresentation $false
        return $resp.name
    } catch {
        Write-Host "  [WARN] Could not resolve chart name for $ChartId : $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

function Add-ParameterElement {
    param(
        [xml]$FormXml,
        [System.Xml.XmlElement]$ParametersElement,
        [string]$Name,
        [string]$Value
    )
    $elem = $FormXml.CreateElement($Name)
    $elem.InnerText = $Value
    $ParametersElement.AppendChild($elem) | Out-Null
}

function Add-EmptyParameterElement {
    <#
    .SYNOPSIS
    Appends a self-closing parameter element (e.g. <ViewIds /> or <RelationshipName />).
    Required by the Dataverse renderer for the subgrid parameter group on dashboard cells —
    OOB dashboards always emit these even when not used.
    #>
    param(
        [xml]$FormXml,
        [System.Xml.XmlElement]$ParametersElement,
        [string]$Name
    )
    $elem = $FormXml.CreateElement($Name)
    $ParametersElement.AppendChild($elem) | Out-Null
}

function New-SubgridControlElement {
    <#
    .SYNOPSIS
    Builds a unified subgrid <control> element with the parameter set the dashboard
    renderer expects. Used for both chart cells (ChartGridMode=Chart) and list cells
    (ChartGridMode=Grid). Critical attributes: classid=SubgridClassId,
    indicationOfSubgrid=true, plus a separate uniqueid GUID.

    Parameter order matches the OOB pattern observed in Customer Service Manager
    Dashboard and Sales Activity Dashboard.
    #>
    param(
        [xml]$FormXml,
        [string]$ControlId,
        [string]$TargetEntityType,
        [string]$ChartGridMode,         # "Chart" | "Grid" | "All"
        [string]$ViewId,                # "{guid}"
        [string]$VisualizationId = "",  # "{guid}" or empty for list-only with no associated chart
        [bool]$IsUserView = $false,
        [bool]$IsUserChart = $false,
        [bool]$EnableQuickFind = $false,
        [bool]$EnableViewPicker = $false,
        [bool]$EnableJumpBar = $false,
        [bool]$EnableChartPicker = $false,
        [int]$RecordsPerPage = 5,
        [string]$AutoExpand = "Fixed"
    )
    $control = $FormXml.CreateElement("control")
    $control.SetAttribute("id", $ControlId)
    $control.SetAttribute("uniqueid", (New-CellGuid))
    $control.SetAttribute("classid", $script:SubgridClassId)
    $control.SetAttribute("indicationOfSubgrid", "true")

    $params = $FormXml.CreateElement("parameters")
    Add-ParameterElement       -FormXml $FormXml -ParametersElement $params -Name "TargetEntityType"  -Value $TargetEntityType
    Add-ParameterElement       -FormXml $FormXml -ParametersElement $params -Name "ChartGridMode"     -Value $ChartGridMode
    Add-ParameterElement       -FormXml $FormXml -ParametersElement $params -Name "EnableQuickFind"   -Value $EnableQuickFind.ToString().ToLower()
    Add-ParameterElement       -FormXml $FormXml -ParametersElement $params -Name "EnableViewPicker"  -Value $EnableViewPicker.ToString().ToLower()
    Add-ParameterElement       -FormXml $FormXml -ParametersElement $params -Name "EnableJumpBar"     -Value $EnableJumpBar.ToString().ToLower()
    Add-ParameterElement       -FormXml $FormXml -ParametersElement $params -Name "RecordsPerPage"    -Value $RecordsPerPage.ToString()
    Add-ParameterElement       -FormXml $FormXml -ParametersElement $params -Name "ViewId"            -Value $ViewId
    Add-ParameterElement       -FormXml $FormXml -ParametersElement $params -Name "IsUserView"        -Value $IsUserView.ToString().ToLower()
    # ViewIds is emitted as an empty self-closing element to match OOB behaviour.
    # OOB dashboards never populate this with the same GUID as ViewId; they leave it empty.
    Add-EmptyParameterElement  -FormXml $FormXml -ParametersElement $params -Name "ViewIds"
    Add-ParameterElement       -FormXml $FormXml -ParametersElement $params -Name "AutoExpand"        -Value $AutoExpand
    if ($VisualizationId) {
        Add-ParameterElement   -FormXml $FormXml -ParametersElement $params -Name "VisualizationId"   -Value $VisualizationId
    }
    Add-ParameterElement       -FormXml $FormXml -ParametersElement $params -Name "IsUserChart"       -Value $IsUserChart.ToString().ToLower()
    Add-ParameterElement       -FormXml $FormXml -ParametersElement $params -Name "EnableChartPicker" -Value $EnableChartPicker.ToString().ToLower()
    Add-EmptyParameterElement  -FormXml $FormXml -ParametersElement $params -Name "RelationshipName"

    $control.AppendChild($params) | Out-Null
    return $control
}
#endregion

#region Dashboard Query / Inspect Operations
function Get-Dashboards {
    param([string]$NameFilter, [string]$TableName, [string]$AppModuleUniqueName)
    Write-Host "`nQuerying system dashboards..." -ForegroundColor Cyan
    # Type 0 = Dashboard
    $filterParts = @("type eq 0")
    if ($TableName) { $filterParts += "objecttypecode eq '$($TableName.ToLower())'" }
    if ($NameFilter) { $filterParts += "contains(name, '$NameFilter')" }
    $filter = $filterParts -join " and "
    $endpoint = "systemforms?`$filter=$filter&`$select=formid,name,objecttypecode,isdefault,description&`$orderby=name"
    $response = Invoke-DvApi -Method "GET" -Endpoint $endpoint

    $dashboards = $response.value
    if ($AppModuleUniqueName) {
        # Filter to dashboards in app module's component list
        $appResponse = Invoke-DvApi -Method "GET" -Endpoint "appmodules?`$filter=uniquename eq '$AppModuleUniqueName'&`$select=appmoduleid&`$top=1"
        if ($appResponse.value -and $appResponse.value.Count -gt 0) {
            $appId = $appResponse.value[0].appmoduleid
            $componentResponse = Invoke-DvApi -Method "GET" -Endpoint "appmodulecomponents?`$filter=_appmoduleidunique_value eq $appId and componenttype eq 60&`$select=objectid"
            $appDashboardIds = @($componentResponse.value | ForEach-Object { $_.objectid })
            $dashboards = $dashboards | Where-Object { $appDashboardIds -contains $_.formid }
        }
    }

    if ($dashboards.Count -eq 0) {
        Write-Host "  No dashboards found." -ForegroundColor Yellow
        return @()
    }
    Write-Host "  Found $($dashboards.Count) dashboard(s):" -ForegroundColor Green
    foreach ($d in $dashboards) {
        $defaultMarker = if ($d.isdefault) { " [DEFAULT]" } else { "" }
        $tableMarker = if ($d.objecttypecode) { " (table: $($d.objecttypecode))" } else { "" }
        Write-Host "  - $($d.name)$defaultMarker$tableMarker" -ForegroundColor White
        Write-Host "    Id: $($d.formid)" -ForegroundColor Gray
    }
    return $dashboards
}

function Get-DashboardRaw {
    param([string]$DashboardId)
    Write-Host "`nGetting dashboard FormXml..." -ForegroundColor Cyan
    $resp = Get-DashboardFormXml -DashboardId $DashboardId
    Write-Host "  Name: $($resp.name)" -ForegroundColor Gray
    Write-Host "  Type: $($resp.type)" -ForegroundColor Gray
    Write-Host "  Table: $(if ($resp.objecttypecode) { $resp.objecttypecode } else { '(global)' })" -ForegroundColor Gray
    Write-Host "  IsDefault: $($resp.isdefault)" -ForegroundColor Gray
    Write-Host "  FormXml length: $($resp.formxml.Length) characters" -ForegroundColor Gray
    Write-Host ""
    Write-Host $resp.formxml
    return $resp
}

function Get-DashboardStructure {
    param([string]$DashboardId)
    Write-Host "`nDashboard structure..." -ForegroundColor Cyan
    $resp = Get-DashboardFormXml -DashboardId $DashboardId
    Write-Host "  Name: $($resp.name)" -ForegroundColor White
    Write-Host "  Id: $($resp.formid)" -ForegroundColor Gray
    Write-Host "  Default: $($resp.isdefault)" -ForegroundColor Gray
    Write-Host ""

    [xml]$xml = $resp.formxml
    $tabIdx = 0
    foreach ($tab in $xml.SelectNodes("//tabs/tab")) {
        $tabIdx++
        $tabName = if ($tab.name) { $tab.name } else { "(unnamed)" }
        Write-Host "Tab $tabIdx -- $tabName" -ForegroundColor Cyan
        $colIdx = 0
        foreach ($col in $tab.SelectNodes("columns/column")) {
            $colIdx++
            Write-Host "  Column $colIdx (width: $($col.width))" -ForegroundColor Gray
            foreach ($section in $col.SelectNodes("sections/section")) {
                $allRows = @($section.SelectNodes("rows/row"))
                $bandRows = @($section.SelectNodes("rows/row[cell]"))
                Write-Host "    Section: $($section.name) (columns: $($section.columns); <row> elements: $($allRows.Count) = $($bandRows.Count) component row(s) + $($allRows.Count - $bandRows.Count) filler(s))" -ForegroundColor Gray
                $cellIdx = 0
                $bandIdx = -1
                foreach ($row in $bandRows) {
                    $bandIdx++
                    # Fillers that follow this band = empty <row /> siblings up to the next band row.
                    $fillers = 0; $sib = $row.NextSibling
                    while ($sib -and $sib.LocalName -eq 'row' -and -not $sib.SelectSingleNode('cell')) { $fillers++; $sib = $sib.NextSibling }
                    $maxSpan = 1
                    foreach ($c in @($row.SelectNodes("cell"))) { $s = 0; if ([int]::TryParse([string]$c.rowspan, [ref]$s) -and $s -gt $maxSpan) { $maxSpan = $s } }
                    $fillerNote = if ($fillers -eq ($maxSpan - 1)) { "fillers=$fillers OK" } else { "fillers=$fillers EXPECTED $($maxSpan - 1) -- run NormalizeDashboardLayout" }
                    Write-Host "      Row $bandIdx (max rowspan=$maxSpan, $fillerNote)" -ForegroundColor Gray
                    foreach ($cell in $row.SelectNodes("cell")) {
                        $cellIdx++
                        $control = $cell.SelectSingleNode("control")
                        $type = "(empty)"; $detail = ""
                        if ($control) {
                            $classid = $control.classid
                            # Dashboard chart, list, and chart+grid cells all use the SubgridClassId
                            # (case-insensitive match to handle OOB's mixed-case lowercase '4d9e' segment).
                            $type = if ($classid -ieq $script:SubgridClassId) {
                                $cgm = $control.SelectSingleNode("parameters/ChartGridMode")
                                switch ($cgm.InnerText) {
                                    "Chart" { "Chart" }
                                    "Grid"  { "List" }
                                    "All"   { "Chart+List" }
                                    default { "List" }
                                }
                            }
                            elseif ($classid -ieq $script:WebResourceClassId) { "WebResource" }
                            elseif ($classid -ieq $script:PowerBIClassId)     { "PowerBI" }
                            else { "Custom (classid=$classid)" }

                            $params = $control.SelectSingleNode("parameters")
                            if ($params) {
                                $vid = $params.SelectSingleNode("VisualizationId"); if ($vid -and $vid.InnerText) { $detail += " visualizationId=$($vid.InnerText)" }
                                $vw  = $params.SelectSingleNode("ViewId");          if ($vw  -and $vw.InnerText)  { $detail += " viewId=$($vw.InnerText)" }
                                $tet = $params.SelectSingleNode("TargetEntityType");if ($tet -and $tet.InnerText) { $detail += " entity=$($tet.InnerText)" }
                                $url = $params.SelectSingleNode("Url");             if ($url -and $url.InnerText) { $detail += " url=$($url.InnerText)" }
                                $pcf = $control.SelectSingleNode("customControl"); if ($pcf) { $detail += " pcf=$($pcf.name)" }
                            }
                        }
                        $cellName = if ($control) { $control.id } else { "(none)" }
                        Write-Host "      Cell $cellIdx [$type] name=$cellName colspan=$($cell.colspan) rowspan=$($cell.rowspan)$detail" -ForegroundColor White
                    }
                }
            }
        }
    }
    return $resp
}
#endregion

#region CreateDashboard
function New-Dashboard {
    param(
        [string]$DashboardName,
        [string]$LayoutPreset,
        [string]$TableName,
        [string]$Description,
        [string]$SolutionName
    )
    Write-Host "`nCreating dashboard: $DashboardName ($LayoutPreset)" -ForegroundColor Cyan

    $tabId = (New-CellGuid)
    $sectionId = (New-CellGuid)
    # Dashboard section.columns is a digit string (one '1' per column), not a number.
    # OOB pattern: "1111" for 4-col, "111" for 3-col, "11" for 2-col, "1" for single-col.
    $colCount = switch ($LayoutPreset) {
        "2Column"          { 2 }
        "3ColumnUniform"   { 3 }
        "3ColumnVaried"    { 3 }
        "4Column"          { 4 }
        "PowerBIEmbedded"  { 1 }
        "Interactive"      { 2 }
        default            { 3 }
    }
    $sectionColumns = "1" * $colCount

    # Empty section with no rows; cells are added via Add* operations.
    # Mirrors the OOB dashboard FormXml structure: tab uses verticallayout=true with no name/expanded;
    # section has no name attr; cells have auto="false" (added via New-CellElement).
    $formXml = @"
<form><tabs><tab showlabel="false" verticallayout="true" id="$tabId"><labels><label description="Tab" languagecode="$($script:LanguageCode)" /></labels><columns><column width="100%"><sections><section showlabel="false" showbar="false" columns="$sectionColumns" id="$sectionId"><labels><label description="Section" languagecode="$($script:LanguageCode)" /></labels><rows /></section></sections></column></columns></tab></tabs></form>
"@.Trim()

    $payload = [ordered]@{
        name           = $DashboardName
        type           = 0    # Dashboard
        formxml        = $formXml
        formactivationstate = 1
    }
    if ($Description) { $payload.description = $Description }
    if ($TableName) { $payload.objecttypecode = $TableName.ToLower() }
    # Else: omit objecttypecode for a global (cross-table) dashboard

    $resp = Invoke-DvApi -Method "POST" -Endpoint "systemforms" -Body $payload -SolutionNameHeader $SolutionName

    Write-Host "  [OK] Dashboard created. FormId: $($resp.formid)" -ForegroundColor Green
    Write-Host "  Layout: $LayoutPreset (section columns: $sectionColumns)" -ForegroundColor Gray
    Write-Host "  Add components via AddDashboardChart / AddDashboardList / AddDashboardWebResource / AddDashboardPCFControl / AddDashboardPowerBITile" -ForegroundColor Gray

    if (-not $SkipPublish) { Publish-DashboardCustomizations -DashboardId $resp.formid }
    return $resp
}
#endregion

#region Component Add Operations
function Add-ChartComponent {
    param(
        [string]$DashboardId, [string]$CellName,
        [string]$VisualizationId, [string]$ViewId, [string]$TargetEntityType,
        [int]$ColumnIndex, [int]$RowIndex, [int]$ColSpan, [int]$RowSpan,
        [bool]$EnableChartPicker, [string]$ChartGridMode, [bool]$IsUserChart, [bool]$IsUserView,
        [string]$CellLabel,
        [Nullable[bool]]$CellShowLabel
    )
    Write-Host "`nAdding chart cell '$CellName'..." -ForegroundColor Cyan
    $resp = Get-DashboardFormXml -DashboardId $DashboardId
    [xml]$xml = $resp.formxml
    $section = Get-DashboardSection -FormXml $xml

    $cleanVid = $VisualizationId -replace '[{}]', ''
    $cleanView = $ViewId -replace '[{}]', ''

    # Chart cells use the unified subgrid <control> shape — same classid + parameter set
    # as list cells, distinguished only by ChartGridMode="Chart".
    $control = New-SubgridControlElement -FormXml $xml `
        -ControlId $CellName `
        -TargetEntityType $TargetEntityType `
        -ChartGridMode $ChartGridMode `
        -ViewId "{$cleanView}" `
        -VisualizationId "{$cleanVid}" `
        -IsUserView $IsUserView `
        -IsUserChart $IsUserChart `
        -EnableChartPicker $EnableChartPicker

    # Auto-derive cell label from chart name if not provided.
    # Chart cells default showlabel=false (chart visualisation has its own embedded title);
    # set $CellShowLabel=$true to surface the cell label as a header bar.
    if (-not $CellLabel) {
        $derived = Get-ChartName -ChartId $VisualizationId
        if ($derived) { $CellLabel = $derived }
    }
    $effectiveShowLabel = if ($null -ne $CellShowLabel) { [bool]$CellShowLabel } else { $false }

    $cell = New-CellElement -FormXml $xml -ControlElement $control -ColSpan $ColSpan -RowSpan $RowSpan -CellLabel $CellLabel -ShowLabel $effectiveShowLabel
    Add-CellToSection -FormXml $xml -Section $section -CellElement $cell -RowIndex $RowIndex -ColumnIndex $ColumnIndex

    Set-DashboardFormXml -DashboardId $DashboardId -FormXml (ConvertTo-CompactXml -Xml $xml)
    Write-Host "  [OK] Chart cell '$CellName' added (entity: $TargetEntityType)" -ForegroundColor Green
    # Always publish after Add: PATCHes go into an "unpublished" layer; subsequent GETs read
    # the "published" layer. Without publish, the next Add overwrites the unpublished cell.
    # (-SkipPublish flag retained for backwards compatibility but ignored on Add ops.)
    Publish-DashboardCustomizations -DashboardId $DashboardId
    Confirm-DashboardCellPersisted -DashboardId $DashboardId -CellName $CellName
}

function Add-ListComponent {
    param(
        [string]$DashboardId, [string]$CellName,
        [string]$ViewId, [string]$TargetEntityType,
        [int]$ColumnIndex, [int]$RowIndex, [int]$ColSpan, [int]$RowSpan,
        [bool]$EnableViewPicker, [bool]$EnableQuickFind, [bool]$EnableJumpBar,
        [int]$RecordsPerPage, [string]$AutoExpand, [bool]$IsUserView,
        [string]$CellLabel,
        [Nullable[bool]]$CellShowLabel
    )
    Write-Host "`nAdding list cell '$CellName'..." -ForegroundColor Cyan
    $resp = Get-DashboardFormXml -DashboardId $DashboardId
    [xml]$xml = $resp.formxml
    $section = Get-DashboardSection -FormXml $xml

    $cleanView = $ViewId -replace '[{}]', ''

    # List cells use the same unified subgrid <control> shape as charts —
    # ChartGridMode="Grid" tells the renderer to show the grid only.
    # VisualizationId is intentionally omitted (no associated chart).
    $control = New-SubgridControlElement -FormXml $xml `
        -ControlId $CellName `
        -TargetEntityType $TargetEntityType `
        -ChartGridMode "Grid" `
        -ViewId "{$cleanView}" `
        -IsUserView $IsUserView `
        -EnableQuickFind $EnableQuickFind `
        -EnableViewPicker $EnableViewPicker `
        -EnableJumpBar $EnableJumpBar `
        -RecordsPerPage $RecordsPerPage `
        -AutoExpand $AutoExpand

    # Auto-derive cell label from view name if not provided.
    # List cells default showlabel=true so users can tell which view they're seeing
    # (the renderer doesn't display the view name automatically for lists). See SOP §4.
    if (-not $CellLabel) {
        $derived = Get-ViewName -ViewId $ViewId
        if ($derived) { $CellLabel = $derived }
    }
    $effectiveShowLabel = if ($null -ne $CellShowLabel) { [bool]$CellShowLabel } else { $true }

    $cell = New-CellElement -FormXml $xml -ControlElement $control -ColSpan $ColSpan -RowSpan $RowSpan -CellLabel $CellLabel -ShowLabel $effectiveShowLabel
    Add-CellToSection -FormXml $xml -Section $section -CellElement $cell -RowIndex $RowIndex -ColumnIndex $ColumnIndex

    Set-DashboardFormXml -DashboardId $DashboardId -FormXml (ConvertTo-CompactXml -Xml $xml)
    Write-Host "  [OK] List cell '$CellName' added (entity: $TargetEntityType)" -ForegroundColor Green
    # Always publish after Add: PATCHes go into an "unpublished" layer; subsequent GETs read
    # the "published" layer. Without publish, the next Add overwrites the unpublished cell.
    # (-SkipPublish flag retained for backwards compatibility but ignored on Add ops.)
    Publish-DashboardCustomizations -DashboardId $DashboardId
    Confirm-DashboardCellPersisted -DashboardId $DashboardId -CellName $CellName
}

function Add-WebResourceComponent {
    param(
        [string]$DashboardId, [string]$CellName,
        [string]$WebResourceUrl, [bool]$WebResourcePassParameters,
        [bool]$WebResourceBorder, [string]$WebResourceScrolling,
        [int]$ColumnIndex, [int]$RowIndex, [int]$ColSpan, [int]$RowSpan
    )
    Write-Host "`nAdding web resource cell '$CellName'..." -ForegroundColor Cyan
    $resp = Get-DashboardFormXml -DashboardId $DashboardId
    [xml]$xml = $resp.formxml
    $section = Get-DashboardSection -FormXml $xml

    # Normalise URL: accept "$webresource:hso_/path.html" or "hso_/path.html"
    $normalizedUrl = $WebResourceUrl
    if (-not $normalizedUrl.StartsWith('$webresource:')) {
        $normalizedUrl = '$webresource:' + $normalizedUrl
    }

    $control = $xml.CreateElement("control")
    $control.SetAttribute("id", $CellName)
    $control.SetAttribute("classid", $script:WebResourceClassId)
    $params = $xml.CreateElement("parameters")
    Add-ParameterElement -FormXml $xml -ParametersElement $params -Name "Url" -Value $normalizedUrl
    Add-ParameterElement -FormXml $xml -ParametersElement $params -Name "PassParameters" -Value $($WebResourcePassParameters.ToString().ToLower())
    Add-ParameterElement -FormXml $xml -ParametersElement $params -Name "Security" -Value "false"   # System dashboard default; iframe security off (no cross-frame scripting needed for HTML WR)
    Add-ParameterElement -FormXml $xml -ParametersElement $params -Name "Scrolling" -Value $WebResourceScrolling
    Add-ParameterElement -FormXml $xml -ParametersElement $params -Name "Border" -Value $($WebResourceBorder.ToString().ToLower())
    $control.AppendChild($params) | Out-Null

    $cell = New-CellElement -FormXml $xml -ControlElement $control -ColSpan $ColSpan -RowSpan $RowSpan
    Add-CellToSection -FormXml $xml -Section $section -CellElement $cell -RowIndex $RowIndex -ColumnIndex $ColumnIndex

    Set-DashboardFormXml -DashboardId $DashboardId -FormXml (ConvertTo-CompactXml -Xml $xml)
    Write-Host "  [OK] Web resource cell '$CellName' added (url: $normalizedUrl)" -ForegroundColor Green
    # Always publish after Add: PATCHes go into an "unpublished" layer; subsequent GETs read
    # the "published" layer. Without publish, the next Add overwrites the unpublished cell.
    # (-SkipPublish flag retained for backwards compatibility but ignored on Add ops.)
    Publish-DashboardCustomizations -DashboardId $DashboardId
    Confirm-DashboardCellPersisted -DashboardId $DashboardId -CellName $CellName
}

function Add-PCFComponent {
    param(
        [string]$DashboardId, [string]$CellName,
        [string]$PCFControlName, [string]$PCFParametersJson, [string]$PCFVersion,
        [int]$ColumnIndex, [int]$RowIndex, [int]$ColSpan, [int]$RowSpan
    )
    Write-Host "`nAdding PCF cell '$CellName'..." -ForegroundColor Cyan
    $resp = Get-DashboardFormXml -DashboardId $DashboardId
    [xml]$xml = $resp.formxml
    $section = Get-DashboardSection -FormXml $xml

    # Outer <control> hosts the PCF via <customControl>
    $control = $xml.CreateElement("control")
    $control.SetAttribute("id", $CellName)
    # Use web resource classid as the cell host; PCF binding lives in customControl child
    $control.SetAttribute("classid", $script:WebResourceClassId)

    $customControl = $xml.CreateElement("customControl")
    $customControl.SetAttribute("name", $PCFControlName)
    $customControl.SetAttribute("formFactor", "0")  # 0 = web/desktop primary
    $customControl.SetAttribute("version", $PCFVersion)
    $control.AppendChild($customControl) | Out-Null

    if ($PCFParametersJson) {
        try {
            $paramsObj = $PCFParametersJson | ConvertFrom-Json
            $pcfParams = $xml.CreateElement("parameters")
            foreach ($prop in $paramsObj.PSObject.Properties) {
                $name = $prop.Name
                $rawValue = $prop.Value.ToString()
                # Convention: "static:value" => static binding; otherwise treat as field name (for form-bound PCFs).
                # Dashboard PCFs are NOT form-bound, so static is the supported mode.
                if ($rawValue -like 'static:*') {
                    $value = $rawValue.Substring(7)
                    $paramElem = $xml.CreateElement($name)
                    $paramElem.SetAttribute("type", "SingleLine.Text")
                    $paramElem.InnerText = $value
                    $pcfParams.AppendChild($paramElem) | Out-Null
                }
                else {
                    Write-Host "  [WARN] PCF parameter '$name': non-static values are not supported on dashboard PCFs (no field binding context). Use 'static:<value>' or read from URL params inside the PCF. Skipping." -ForegroundColor Yellow
                }
            }
            $control.AppendChild($pcfParams) | Out-Null
        }
        catch {
            Write-Host "  [WARN] PCFParametersJson could not be parsed as JSON: $($_.Exception.Message). Skipping parameter binding." -ForegroundColor Yellow
        }
    }

    $cell = New-CellElement -FormXml $xml -ControlElement $control -ColSpan $ColSpan -RowSpan $RowSpan
    Add-CellToSection -FormXml $xml -Section $section -CellElement $cell -RowIndex $RowIndex -ColumnIndex $ColumnIndex

    Set-DashboardFormXml -DashboardId $DashboardId -FormXml (ConvertTo-CompactXml -Xml $xml)
    Write-Host "  [OK] PCF cell '$CellName' added (control: $PCFControlName)" -ForegroundColor Green
    Write-Host "  NOTE: per SOP §13 (Diana Birkelbach's caveat), test the PCF in dashboard context specifically." -ForegroundColor Yellow
    # Always publish after Add: PATCHes go into an "unpublished" layer; subsequent GETs read
    # the "published" layer. Without publish, the next Add overwrites the unpublished cell.
    # (-SkipPublish flag retained for backwards compatibility but ignored on Add ops.)
    Publish-DashboardCustomizations -DashboardId $DashboardId
    Confirm-DashboardCellPersisted -DashboardId $DashboardId -CellName $CellName
}

function Add-PowerBITileComponent {
    param(
        [string]$DashboardId, [string]$CellName,
        [string]$PowerBIWorkspaceId, [string]$PowerBIReportId, [string]$PowerBITileId,
        [int]$ColumnIndex, [int]$RowIndex, [int]$ColSpan, [int]$RowSpan
    )
    Write-Host "`nAdding Power BI tile cell '$CellName'..." -ForegroundColor Cyan
    $resp = Get-DashboardFormXml -DashboardId $DashboardId
    [xml]$xml = $resp.formxml
    $section = Get-DashboardSection -FormXml $xml

    $control = $xml.CreateElement("control")
    $control.SetAttribute("id", $CellName)
    $control.SetAttribute("classid", $script:PowerBIClassId)
    $params = $xml.CreateElement("parameters")
    Add-ParameterElement -FormXml $xml -ParametersElement $params -Name "PowerBIGroupId"  -Value $PowerBIWorkspaceId
    Add-ParameterElement -FormXml $xml -ParametersElement $params -Name "PowerBIReportId" -Value $PowerBIReportId
    if ($PowerBITileId) {
        Add-ParameterElement -FormXml $xml -ParametersElement $params -Name "PowerBITileId" -Value $PowerBITileId
    }
    $control.AppendChild($params) | Out-Null

    $cell = New-CellElement -FormXml $xml -ControlElement $control -ColSpan $ColSpan -RowSpan $RowSpan
    Add-CellToSection -FormXml $xml -Section $section -CellElement $cell -RowIndex $RowIndex -ColumnIndex $ColumnIndex

    Set-DashboardFormXml -DashboardId $DashboardId -FormXml (ConvertTo-CompactXml -Xml $xml)
    Write-Host "  [OK] Power BI tile cell '$CellName' added" -ForegroundColor Green
    Write-Host "  NOTE: ensure PowerBIWorkspaceId / PowerBIReportId are bound via Environment Variables (per SOP §8) for ALM portability." -ForegroundColor Yellow
    # Always publish after Add: PATCHes go into an "unpublished" layer; subsequent GETs read
    # the "published" layer. Without publish, the next Add overwrites the unpublished cell.
    # (-SkipPublish flag retained for backwards compatibility but ignored on Add ops.)
    Publish-DashboardCustomizations -DashboardId $DashboardId
    Confirm-DashboardCellPersisted -DashboardId $DashboardId -CellName $CellName
}

function Remove-Component {
    param([string]$DashboardId, [string]$CellName)
    Write-Host "`nRemoving component '$CellName'..." -ForegroundColor Cyan
    $resp = Get-DashboardFormXml -DashboardId $DashboardId
    [xml]$xml = $resp.formxml

    $controls = @($xml.SelectNodes("//cell/control[@id='$CellName']"))
    if ($controls.Count -eq 0) {
        throw "No component with control id '$CellName' found on dashboard. Run ListDashboardStructure to inspect."
    }
    $cell = $controls[0].ParentNode
    $row = $cell.ParentNode
    $row.RemoveChild($cell) | Out-Null
    # A row left with no cells is dropped (and its fillers re-derived) so the bands below
    # move up -- the same thing the designer does when you delete the last component in a row.
    if (-not $row.SelectSingleNode("cell")) { $row.ParentNode.RemoveChild($row) | Out-Null }
    Sync-DashboardFillerRows -FormXml $xml -Section (Get-DashboardSection -FormXml $xml) | Out-Null

    Set-DashboardFormXml -DashboardId $DashboardId -FormXml (ConvertTo-CompactXml -Xml $xml)
    Write-Host "  [OK] Component '$CellName' removed" -ForegroundColor Green
    # Always publish after a mutation: PATCHes go into an "unpublished" layer; subsequent GETs
    # read the "published" layer. Without publish, the next mutation's GET misses this edit.
    # (-SkipPublish flag retained for backwards compatibility but ignored on cell mutations.)
    Publish-DashboardCustomizations -DashboardId $DashboardId
    Confirm-DashboardCellPersisted -DashboardId $DashboardId -CellName $CellName -Expect absent
}

function Update-CellLayout {
    <#
    .SYNOPSIS
    Resizes an existing dashboard cell in place -- colspan / rowspan / RecordsPerPage --
    targeted by control id. Read-modify-write on the formxml with publish + read-back
    built in, so callers never hand-compose GET -> regex-edit -> PATCH -> publish for a
    resize (that free-handed path has injected literal backticks into FormXml before).
    #>
    param(
        [string]$DashboardId,
        [string]$CellName,            # one control id, a comma-separated list, or '*' for every cell
        [Nullable[int]]$NewColSpan,
        [Nullable[int]]$NewRowSpan,
        [Nullable[int]]$NewRecordsPerPage
    )
    Write-Host "`nUpdating layout for cell(s) '$CellName'..." -ForegroundColor Cyan
    $resp = Get-DashboardFormXml -DashboardId $DashboardId
    [xml]$xml = $resp.formxml

    # Resolve the target set: '*' = all cells; otherwise each comma-separated id must exist.
    # Many cells -> ONE PATCH + ONE publish (a per-cell round-trip is ~10 s each and the
    # intermediate publishes are pure overhead -- see the 2026-08-19 bulk reflow).
    $targets = @()
    if ($CellName.Trim() -eq '*') {
        $targets = @($xml.SelectNodes("//cell/control[@id]"))
        if ($targets.Count -eq 0) { throw "Dashboard has no cells to update." }
    } else {
        foreach ($name in ($CellName -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
            $c = $xml.SelectSingleNode("//cell/control[@id='$name']")
            if (-not $c) { throw "No component with control id '$name' found on dashboard. Run ListDashboardStructure to inspect." }
            $targets += $c
        }
    }

    $rppApplied = @{}
    foreach ($control in $targets) {
        $id = $control.id
        $cell = $control.ParentNode
        if ($null -ne $NewColSpan) {
            $cell.SetAttribute("colspan", $NewColSpan.ToString())
            Write-Host "  [$id] colspan -> $NewColSpan" -ForegroundColor Gray
        }
        if ($null -ne $NewRowSpan) {
            $cell.SetAttribute("rowspan", $NewRowSpan.ToString())
            Write-Host "  [$id] rowspan -> $NewRowSpan" -ForegroundColor Gray
        }
        if ($null -ne $NewRecordsPerPage) {
            $rpp = $control.SelectSingleNode("parameters/RecordsPerPage")
            if ($rpp) {
                $rpp.InnerText = $NewRecordsPerPage.ToString()
                $rppApplied[$id] = $NewRecordsPerPage
                Write-Host "  [$id] RecordsPerPage -> $NewRecordsPerPage" -ForegroundColor Gray
            }
            elseif ($control.classid -ieq $script:SubgridClassId) {
                # Subgrid cell whose parameter block predates the RecordsPerPage default -- add it.
                $params = $control.SelectSingleNode("parameters")
                if (-not $params) { $params = $xml.CreateElement("parameters"); $control.AppendChild($params) | Out-Null }
                Add-ParameterElement -FormXml $xml -ParametersElement $params -Name "RecordsPerPage" -Value $NewRecordsPerPage.ToString()
                $rppApplied[$id] = $NewRecordsPerPage
                Write-Host "  [$id] RecordsPerPage -> $NewRecordsPerPage (parameter added)" -ForegroundColor Gray
            }
            else {
                Write-Host "  [WARN] Cell '$id' is not a list/chart (subgrid) cell -- RecordsPerPage does not apply; skipped." -ForegroundColor Yellow
            }
        }
    }
    if ($null -ne $NewRowSpan) {
        # A rowspan change moves every band below it -- re-derive the filler rows once.
        Sync-DashboardFillerRows -FormXml $xml -Section (Get-DashboardSection -FormXml $xml) | Out-Null
    }

    Set-DashboardFormXml -DashboardId $DashboardId -FormXml (ConvertTo-CompactXml -Xml $xml)
    Write-Host "  [OK] Layout PATCH accepted for $($targets.Count) cell(s)" -ForegroundColor Green
    # Same unpublished-layer rule as the Add* ops: publish immediately so the read-back below
    # (and any subsequent GET) reflects this write instead of the pre-write published layer.
    Publish-DashboardCustomizations -DashboardId $DashboardId
    foreach ($control in $targets) {
        $id = $control.id
        $rppExpect = if ($rppApplied.ContainsKey($id)) { [Nullable[int]]$rppApplied[$id] } else { $null }
        Confirm-DashboardCellPersisted -DashboardId $DashboardId -CellName $id `
            -ExpectColSpan $NewColSpan -ExpectRowSpan $NewRowSpan -ExpectRecordsPerPage $rppExpect
    }
}

function Repair-DashboardLayout {
    <#
    .SYNOPSIS
    NormalizeDashboardLayout -- re-derive the grid filler rows of an existing dashboard
    (see Sync-DashboardFillerRows) and publish. Use on dashboards built by this skill
    before 2026-08-19 (no fillers -> overlapping cells in the classic designer) or on
    any dashboard whose <rows> drifted out of step with its rowspans. Cells, bindings
    and sizes are left exactly as-is; only the empty <row /> elements change.
    #>
    param([string]$DashboardId)
    Write-Host "`nNormalizing dashboard grid rows..." -ForegroundColor Cyan
    $resp = Get-DashboardFormXml -DashboardId $DashboardId
    [xml]$xml = $resp.formxml
    $section = Get-DashboardSection -FormXml $xml
    $before = @($section.SelectNodes("rows/row")).Count
    $summary = Sync-DashboardFillerRows -FormXml $xml -Section $section
    $after = @($section.SelectNodes("rows/row")).Count
    Write-Host "  Name: $($resp.name)" -ForegroundColor White
    Write-Host "  <row> elements: $before -> $after ($($summary.ComponentRows) component row(s) + $($summary.FillerRows) filler(s))" -ForegroundColor Gray
    if ($before -eq $after) {
        Write-Host "  [OK] Grid rows already normalized -- nothing to write." -ForegroundColor Green
        return
    }
    Set-DashboardFormXml -DashboardId $DashboardId -FormXml (ConvertTo-CompactXml -Xml $xml)
    Publish-DashboardCustomizations -DashboardId $DashboardId
    # Read-back from the published layer (same rule as every other cell mutation).
    $check = Get-DashboardFormXml -DashboardId $DashboardId
    [xml]$cx = $check.formxml
    $persisted = @((Get-DashboardSection -FormXml $cx).SelectNodes("rows/row")).Count
    if ($persisted -eq $after) {
        Write-Host "  [OK] Read-back confirms $persisted <row> elements on the published layer" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Read-back shows $persisted <row> elements (expected $after) -- publish-layer lag or a concurrent write. Re-run ListDashboardStructure." -ForegroundColor Yellow
    }
}
#endregion

#region Default / Roles / App Module
function Set-DashboardAsDefault {
    param([string]$DashboardId, [string]$AppModuleUniqueName)
    Write-Host "`nSetting dashboard as default..." -ForegroundColor Cyan
    $cleanId = $DashboardId -replace '[{}]', ''

    if ($AppModuleUniqueName) {
        # Resolve app and find all dashboards in its component list
        $appResp = Invoke-DvApi -Method "GET" -Endpoint "appmodules?`$filter=uniquename eq '$AppModuleUniqueName'&`$select=appmoduleid&`$top=1"
        if (-not $appResp.value -or $appResp.value.Count -eq 0) {
            throw "App module '$AppModuleUniqueName' not found"
        }
        $appId = $appResp.value[0].appmoduleid
        $componentResp = Invoke-DvApi -Method "GET" -Endpoint "appmodulecomponents?`$filter=_appmoduleidunique_value eq $appId and componenttype eq 60&`$select=objectid"
        $appDashboardIds = @($componentResp.value | ForEach-Object { $_.objectid })
        Write-Host "  Found $($appDashboardIds.Count) dashboard(s) in app '$AppModuleUniqueName'" -ForegroundColor Gray

        # Unset IsDefault on others
        foreach ($otherId in ($appDashboardIds | Where-Object { $_ -ne $cleanId })) {
            try {
                Invoke-DvApi -Method "PATCH" -Endpoint "systemforms($otherId)" -Body @{ isdefault = $false } -ReturnRepresentation $false | Out-Null
                Write-Host "  [-] Unset default on $otherId" -ForegroundColor Gray
            } catch {
                Write-Host "  [WARN] Could not unset default on $otherId : $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "  No AppModuleUniqueName provided -- only setting IsDefault on this dashboard, not unsetting others." -ForegroundColor Yellow
    }

    Invoke-DvApi -Method "PATCH" -Endpoint "systemforms($cleanId)" -Body @{ isdefault = $true } -ReturnRepresentation $false | Out-Null
    Write-Host "  [OK] Dashboard $cleanId set as default" -ForegroundColor Green
    if (-not $SkipPublish) { Publish-DashboardCustomizations -DashboardId $cleanId }
}

function Set-DashboardRoles {
    param([string]$DashboardId, [string[]]$RoleIds)
    Write-Host "`nSetting dashboard security roles..." -ForegroundColor Cyan
    $cleanId = $DashboardId -replace '[{}]', ''

    # Get current role associations
    $existingResp = Invoke-DvApi -Method "GET" -Endpoint "systemforms($cleanId)/systemformid_role/`$ref"
    $existing = @($existingResp.value | ForEach-Object {
        if ($_.'@odata.id' -match 'roles\(([^\)]+)\)') { $matches[1] } else { $null }
    } | Where-Object { $_ })

    if (-not $RoleIds -or $RoleIds.Count -eq 0) {
        # Reset: remove all existing
        foreach ($rid in $existing) {
            try {
                Invoke-DvApi -Method "DELETE" -Endpoint "systemforms($cleanId)/systemformid_role(`$id=$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/roles($rid))" -ReturnRepresentation $false | Out-Null
                Write-Host "  [-] Removed role $rid" -ForegroundColor Gray
            } catch {
                Write-Host "  [WARN] Could not remove role $rid : $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        Write-Host "  [OK] Reset to all roles (no role-scoping)" -ForegroundColor Green
    }
    else {
        # Add new ones not already present
        foreach ($rid in $RoleIds) {
            $cleanRid = $rid -replace '[{}]', ''
            if ($existing -contains $cleanRid) {
                Write-Host "  [=] Role $cleanRid already associated, skipping" -ForegroundColor Gray
                continue
            }
            $body = @{ "@odata.id" = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/roles($cleanRid)" }
            try {
                Invoke-DvApi -Method "POST" -Endpoint "systemforms($cleanId)/systemformid_role/`$ref" -Body $body -ReturnRepresentation $false | Out-Null
                Write-Host "  [+] Added role $cleanRid" -ForegroundColor Green
            } catch {
                Write-Host "  [WARN] Could not add role $cleanRid : $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        Write-Host "  [OK] Dashboard scoped to $($RoleIds.Count) role(s)" -ForegroundColor Green
    }
    if (-not $SkipPublish) { Publish-DashboardCustomizations -DashboardId $cleanId }
}

function Publish-AppModule {
    <#
    .SYNOPSIS
        Publishes an app module so staged customizations (dashboard component adds, sitemap edits)
        become visible to UCI. Retries on 429 throttling with exponential backoff.
    #>
    param(
        [Parameter(Mandatory)][string]$AppModuleId,
        [string]$AppName = '',
        [int]$MaxAttempts = 5
    )
    $publishXml = "<importexportxml><appmodules><appmodule>$AppModuleId</appmodule></appmodules></importexportxml>"
    $attempt = 0
    while ($attempt -lt $MaxAttempts) {
        $attempt++
        try {
            Invoke-DvApi -Method "POST" -Endpoint "PublishXml" -Body @{ ParameterXml = $publishXml } | Out-Null
            $label = if ($AppName) { "'$AppName'" } else { $AppModuleId }
            Write-Host "  [OK] App module $label published (attempt $attempt)" -ForegroundColor Green
            return
        } catch {
            $msg = $_.Exception.Message
            if ($msg -match '429' -and $attempt -lt $MaxAttempts) {
                $waitSeconds = [Math]::Pow(2, $attempt) * 5
                Write-Host "  [429] backoff $waitSeconds s (attempt $attempt of $MaxAttempts)" -ForegroundColor Yellow
                Start-Sleep -Seconds $waitSeconds
            } else {
                throw "App module publish failed: $msg"
            }
        }
    }
}

function Add-DashboardToAppModule {
    param(
        [string]$DashboardId,
        [string]$AppModuleUniqueName,
        [switch]$SkipPublish
    )
    Write-Host "`nAdding dashboard to app module..." -ForegroundColor Cyan
    $cleanId = $DashboardId -replace '[{}]', ''

    $appResp = Invoke-DvApi -Method "GET" -Endpoint "appmodules?`$filter=uniquename eq '$AppModuleUniqueName'&`$select=appmoduleid,appmoduleidunique,name"
    if (-not $appResp.value -or $appResp.value.Count -eq 0) {
        throw "App module '$AppModuleUniqueName' not found"
    }
    $appId = $appResp.value[0].appmoduleid
    $appName = $appResp.value[0].name
    $appUnique = $appResp.value[0].appmoduleidunique

    # IMPLICIT -> EXPLICIT visibility flip. A model-driven app with NO dashboard components
    # (componenttype 60 = systemform) shows EVERY system dashboard implicitly. The first
    # explicit add flips it to "only the listed dashboards" -- every other dashboard
    # silently disappears from the app's dashboard picker (observed 2026-08-19: adding one
    # dashboard hid eight others). Warn loudly and name what is about to vanish so the
    # caller registers the rest in the same pass.
    try {
        $existing = Invoke-DvApi -Method "GET" -Endpoint "appmodulecomponents?`$filter=_appmoduleidunique_value eq $appUnique and componenttype eq 60&`$select=objectid" -ReturnRepresentation $false
        $explicitCount = @($existing.value).Count
    } catch { $explicitCount = -1 }
    if ($explicitCount -eq 0) {
        $allDash = Invoke-DvApi -Method "GET" -Endpoint "systemforms?`$filter=type eq 0 and formid ne $cleanId&`$select=formid,name&`$orderby=name" -ReturnRepresentation $false
        $others = @($allDash.value | Where-Object { $_.name -notmatch '^(Microsoft Dynamics 365|\[Deprecated|Server-Side Synchronization)' })
        Write-Host "  [WARN] App '$appName' has NO explicit dashboard components yet -- it currently shows ALL system dashboards implicitly." -ForegroundColor Yellow
        Write-Host "         This add flips it to 'only listed dashboards'. $($others.Count) other non-OOB dashboard(s) will DISAPPEAR from the app unless you also AddDashboardToApp each one:" -ForegroundColor Yellow
        foreach ($o in $others) { Write-Host "           - $($o.formid)  $($o.name)" -ForegroundColor Yellow }
    } elseif ($explicitCount -gt 0) {
        Write-Host "  App '$appName' already lists $explicitCount explicit dashboard(s); adding one more." -ForegroundColor Gray
    }

    $body = @{
        AppId = $appId
        Components = @(
            @{
                "@odata.type" = "Microsoft.Dynamics.CRM.systemform"
                formid = $cleanId
            }
        )
    }
    Invoke-DvApi -Method "POST" -Endpoint "AddAppComponents" -Body $body -ReturnRepresentation $false | Out-Null
    Write-Host "  [OK] Dashboard $cleanId staged on app '$appName'" -ForegroundColor Green

    # Publish so the new component is visible to UCI. AddAppComponents alone leaves UCI
    # serving the previously published customizations; clicking the dashboard sitemap URL
    # hits the un-registered ID and UCI falls back to whichever dashboard IS in the
    # published component list. Always publish unless the caller is batching adds and
    # will publish at the end via PublishApp.
    if (-not $SkipPublish) {
        Publish-AppModule -AppModuleId $appId -AppName $appName
    } else {
        Write-Host "  [SkipPublish] App module not published. Call PublishApp after batched Adds." -ForegroundColor Gray
    }
}

function Publish-AppModuleByUniqueName {
    param([string]$AppModuleUniqueName)
    Write-Host "`nPublishing app module..." -ForegroundColor Cyan
    $appResp = Invoke-DvApi -Method "GET" -Endpoint "appmodules?`$filter=uniquename eq '$AppModuleUniqueName'&`$select=appmoduleid,name"
    if (-not $appResp.value -or $appResp.value.Count -eq 0) {
        throw "App module '$AppModuleUniqueName' not found"
    }
    Publish-AppModule -AppModuleId $appResp.value[0].appmoduleid -AppName $appResp.value[0].name
}
#endregion

#region System Chart Operations
function Get-SystemCharts {
    param([string]$TableName)
    Write-Host "`nQuerying system charts for table: $TableName" -ForegroundColor Cyan
    $endpoint = "savedqueryvisualizations?`$filter=primaryentitytypecode eq '$($TableName.ToLower())'&`$select=savedqueryvisualizationid,name,description,charttype,primaryentitytypecode&`$orderby=name"
    $resp = Invoke-DvApi -Method "GET" -Endpoint $endpoint
    if ($resp.value.Count -eq 0) {
        Write-Host "  No charts found for $TableName" -ForegroundColor Yellow
        return @()
    }
    foreach ($c in $resp.value) {
        Write-Host "  - $($c.name) ($($c.charttype))" -ForegroundColor White
        Write-Host "    Id: $($c.savedqueryvisualizationid)" -ForegroundColor Gray
    }
    return $resp.value
}

function Get-SystemChartDetails {
    param([string]$ChartId)
    Write-Host "`nGetting system chart details..." -ForegroundColor Cyan
    $cleanId = $ChartId -replace '[{}]', ''
    $endpoint = "savedqueryvisualizations($cleanId)?`$select=savedqueryvisualizationid,name,description,charttype,primaryentitytypecode,datadescription,presentationdescription"
    $resp = Invoke-DvApi -Method "GET" -Endpoint $endpoint -ReturnRepresentation $false
    Write-Host "  Name: $($resp.name)" -ForegroundColor White
    Write-Host "  Table: $($resp.primaryentitytypecode)" -ForegroundColor Gray
    Write-Host "  Type: $($resp.charttype)" -ForegroundColor Gray
    Write-Host "" ; Write-Host "Data description:" -ForegroundColor Cyan
    Write-Host $resp.datadescription
    Write-Host "" ; Write-Host "Presentation description:" -ForegroundColor Cyan
    Write-Host $resp.presentationdescription
    return $resp
}

function Get-ChartPresentationXml {
    <#
    .SYNOPSIS
    Per-chart-type presentation XML (DataVisualization.Charting) that renders cleanly in
    UCI dashboard cells. Mirrors the OOB chart conventions (diffed against the OOB
    'Accounts by Owner' bar, 'New Accounts By Month' column and 'Articles By Status' pie):

      * Title  -- <Title Alignment='TopLeft' DockingOffset='-3'> with empty text; UCI fills
                  in the chart name. Never leave <Titles /> empty AND emit an undocked
                  legend: UCI paints both at the top-left and they overlap.
      * Legend -- OMITTED for single-series Bar / Column / Line (a one-entry legend reading
                  'Count:All (Table)' is noise and is what overlapped the title). Docked
                  Right for Pie / Funnel (categories ARE the legend), Bottom for stacked
                  charts so a narrow 1/3-width cell keeps its plot width.
      * Labels -- IsValueShownAsLabel + SmartLabelStyle so labels don't collide.
      * Axes   -- OOB greys; X gridlines off; Y gridlines light.
      * Colour -- HSO palette from references/chart-xml-patterns.md (override per project
                  by PATCHing presentationdescription or UpdateSystemChart -PresentationDescription).
    #>
    param([Parameter(Mandatory)][string]$ChartType)

    $palette = "PaletteCustomColors='31,78,121; 79,179,220; 46,125,50; 242,160,7; 140,83,152; 200,16,46; 91,151,213; 237,125,49; 160,116,166; 255,192,0; 68,114,196; 112,173,71'"
    $title   = "<Titles><Title Alignment='TopLeft' DockingOffset='-3' Font='{0}, 13px' ForeColor='59, 59, 59' /></Titles>"
    $legendRight  = "<Legends><Legend Alignment='Center' LegendStyle='Table' Docking='Right' IsEquallySpacedItems='True' Font='{0}, 11px' ShadowColor='0, 0, 0, 0' ForeColor='59, 59, 59' /></Legends>"
    $legendBottom = "<Legends><Legend Alignment='Center' LegendStyle='Table' Docking='Bottom' IsEquallySpacedItems='True' Font='{0}, 11px' ShadowColor='0, 0, 0, 0' ForeColor='59, 59, 59' /></Legends>"
    $axisArea = @"
<ChartAreas><ChartArea BorderColor='White' BorderDashStyle='Solid'>
  <AxisY LabelAutoFitMinFontSize='8' TitleForeColor='59, 59, 59' TitleFont='{0}, 10.5px' LineColor='165, 172, 181' IntervalAutoMode='VariableCount'><MajorGrid LineColor='239, 242, 246' /><MajorTickMark LineColor='165, 172, 181' /><LabelStyle Font='{0}, 10.5px' ForeColor='59, 59, 59' /></AxisY>
  <AxisX LabelAutoFitMinFontSize='8' TitleForeColor='59, 59, 59' TitleFont='{0}, 10.5px' LineColor='165, 172, 181' IntervalAutoMode='VariableCount'><MajorGrid Enabled='False' /><MajorTickMark Enabled='False' /><LabelStyle Font='{0}, 10.5px' ForeColor='59, 59, 59' /></AxisX>
</ChartArea></ChartAreas>
"@
    $barSeries = "<Series ChartType='{TYPE}' IsValueShownAsLabel='True' Color='31, 78, 121' BackSecondaryColor='41, 88, 145' Font='{0}, 9.5px' LabelForeColor='59, 59, 59' CustomProperties='PointWidth=0.75, MaxPixelPointWidth=40'><SmartLabelStyle Enabled='True' /></Series>"

    switch ($ChartType) {
        { $_ -in 'Bar', 'Column' } {
            return "<Chart Palette='None' $palette><Series>$($barSeries -replace '\{TYPE\}', $_)</Series>$axisArea$title</Chart>"
        }
        'Line' {
            $s = "<Series ChartType='Line' IsValueShownAsLabel='True' Color='31, 78, 121' BorderWidth='3' MarkerStyle='Circle' MarkerSize='8' MarkerColor='31, 78, 121' Font='{0}, 9.5px' LabelForeColor='59, 59, 59'><SmartLabelStyle Enabled='True' /></Series>"
            return "<Chart Palette='None' $palette><Series>$s</Series>$axisArea$title</Chart>"
        }
        'Pie' {
            $s = "<Series ChartType='Pie' IsValueShownAsLabel='True' ShadowOffset='0' Font='{0}, 9.5px' LabelForeColor='59, 59, 59' CustomProperties='PieLabelStyle=Inside, PieDrawingStyle=Default'><SmartLabelStyle Enabled='True' /></Series>"
            return "<Chart Palette='None' $palette><Series>$s</Series><ChartAreas><ChartArea><Area3DStyle Enable3D='false' /></ChartArea></ChartAreas>$legendRight$title</Chart>"
        }
        'Funnel' {
            $s = "<Series ChartType='Funnel' IsValueShownAsLabel='True' ShadowOffset='0' Font='{0}, 9.5px' LabelForeColor='59, 59, 59' CustomProperties='FunnelStyle=YIsHeight, FunnelNeckHeight=0, FunnelPointGap=1'><SmartLabelStyle Enabled='True' /></Series>"
            return "<Chart Palette='None' $palette><Series>$s</Series><ChartAreas><ChartArea><Area3DStyle Enable3D='false' /></ChartArea></ChartAreas>$legendRight$title</Chart>"
        }
        { $_ -in 'StackedBar', 'StackedColumn' } {
            return "<Chart Palette='None' $palette><Series>$($barSeries -replace '\{TYPE\}', $_)</Series>$axisArea$legendBottom$title</Chart>"
        }
        default { throw "Unsupported ChartType '$ChartType'" }
    }
}

function Update-SystemChart {
    <#
    .SYNOPSIS
    UpdateSystemChart -- PATCH an existing savedqueryvisualization's presentation and/or
    data description, then publish its table. Three inputs, any combination:
      -ChartType               regenerate presentationdescription from this skill's template
                               (the repair path for charts whose title and legend overlap)
      -PresentationDescription raw <Chart> XML (inline or a path to a file containing it)
      -DataDescription         raw <datadefinition> XML (inline or a file path)
    #>
    param(
        [string]$ChartId, [string]$ChartType,
        [string]$PresentationDescription, [string]$DataDescription,
        [string]$SolutionName
    )
    $cleanId = $ChartId -replace '[{}]', ''
    Write-Host "`nUpdating system chart $cleanId..." -ForegroundColor Cyan
    $existing = Invoke-DvApi -Method "GET" -Endpoint "savedqueryvisualizations($cleanId)?`$select=name,primaryentitytypecode,presentationdescription" -ReturnRepresentation $false
    Write-Host "  Name: $($existing.name)  Table: $($existing.primaryentitytypecode)" -ForegroundColor White

    $payload = [ordered]@{}
    if ($ChartType) {
        $payload.presentationdescription = Get-ChartPresentationXml -ChartType $ChartType
        Write-Host "  presentationdescription <- $ChartType template" -ForegroundColor Gray
    }
    if ($PresentationDescription) {
        $payload.presentationdescription = if (Test-Path -LiteralPath $PresentationDescription) { Get-Content -LiteralPath $PresentationDescription -Raw } else { $PresentationDescription }
        Write-Host "  presentationdescription <- caller-supplied XML" -ForegroundColor Gray
    }
    if ($DataDescription) {
        $payload.datadescription = if (Test-Path -LiteralPath $DataDescription) { Get-Content -LiteralPath $DataDescription -Raw } else { $DataDescription }
        Write-Host "  datadescription <- caller-supplied XML" -ForegroundColor Gray
    }
    if ($payload.Count -eq 0) { throw "UpdateSystemChart requires at least one of -ChartType, -PresentationDescription, -DataDescription" }
    foreach ($k in @($payload.Keys)) { [xml]$null = $payload[$k] }   # fail fast on malformed XML

    Invoke-DvApi -Method "PATCH" -Endpoint "savedqueryvisualizations($cleanId)" -Body $payload -SolutionNameHeader $SolutionName -ReturnRepresentation $false | Out-Null
    Write-Host "  [OK] Chart PATCH accepted" -ForegroundColor Green
    if (-not $SkipPublish) {
        $publishXml = "<importexportxml><entities><entity>$($existing.primaryentitytypecode)</entity></entities></importexportxml>"
        Invoke-DvApi -Method "POST" -Endpoint "PublishXml" -Body @{ ParameterXml = $publishXml } -ReturnRepresentation $false | Out-Null
        Write-Host "  [OK] Customizations published for $($existing.primaryentitytypecode)" -ForegroundColor Green
    }
    # Read-back: confirm the presentation actually changed (charts are not layered like formxml,
    # but the verdict still comes from the server, never from the payload we sent).
    $after = Invoke-DvApi -Method "GET" -Endpoint "savedqueryvisualizations($cleanId)?`$select=presentationdescription" -ReturnRepresentation $false
    if ($payload.Contains('presentationdescription') -and ($after.presentationdescription -replace '\s', '') -ne ($payload.presentationdescription -replace '\s', '')) {
        Write-Host "  [WARN] Read-back presentationdescription differs from what was sent -- verify with GetSystemChart." -ForegroundColor Yellow
    } else {
        Write-Host "  [OK] Read-back confirms the chart definition" -ForegroundColor Green
    }
}

function New-SystemChart {
    param(
        [string]$ChartName, [string]$ChartDescription, [string]$TableName,
        [string]$ChartType, [string]$GroupByColumn, [string]$GroupByDateInterval,
        [string]$AggregateColumn, [string]$AggregateFunction,
        [string]$ChartFilter, [string]$SolutionName
    )
    Write-Host "`nCreating system chart: $ChartName ($ChartType)" -ForegroundColor Cyan

    $tableLower = $TableName.ToLower()
    $groupByLower = $GroupByColumn.ToLower()
    $aggLower = $AggregateColumn.ToLower()

    # Build FetchXML data description
    $groupByAttr = if ($GroupByDateInterval) {
        "<attribute groupby='true' alias='groupby_$groupByLower' name='$groupByLower' dategrouping='$GroupByDateInterval' />"
    } else {
        "<attribute groupby='true' alias='groupby_$groupByLower' name='$groupByLower' />"
    }
    $aggAttr = "<attribute aggregate='$AggregateFunction' alias='agg_$aggLower' name='$aggLower' />"
    $orderElem = "<order alias='groupby_$groupByLower' descending='false' />"
    $filterElem = if ($ChartFilter) { $ChartFilter } else { "" }

    $dataDescription = @"
<datadefinition>
  <fetchcollection>
    <fetch mapping='logical' aggregate='true'>
      <entity name='$tableLower'>
        $groupByAttr
        $aggAttr
        $orderElem
        $filterElem
      </entity>
    </fetch>
  </fetchcollection>
  <categorycollection>
    <category alias='groupby_$groupByLower'>
      <measurecollection>
        <measure alias='agg_$aggLower' />
      </measurecollection>
    </category>
  </categorycollection>
</datadefinition>
"@.Trim()

    # Build presentation description (DataVisualization.Charting) from the per-type template.
    $presentationDescription = Get-ChartPresentationXml -ChartType $ChartType

    $payload = [ordered]@{
        name                    = $ChartName
        primaryentitytypecode   = $tableLower
        datadescription         = $dataDescription
        presentationdescription = $presentationDescription
    }
    if ($ChartDescription) { $payload.description = $ChartDescription }

    $resp = Invoke-DvApi -Method "POST" -Endpoint "savedqueryvisualizations" -Body $payload -SolutionNameHeader $SolutionName

    Write-Host "  [OK] System chart created. Id: $($resp.savedqueryvisualizationid)" -ForegroundColor Green
    Write-Host "  Reference this VisualizationId from AddDashboardChart." -ForegroundColor Gray
    if (-not $SkipPublish) {
        # Publishing a chart requires entity-level publish
        $publishXml = "<importexportxml><entities><entity>$tableLower</entity></entities></importexportxml>"
        Invoke-DvApi -Method "POST" -Endpoint "PublishXml" -Body @{ ParameterXml = $publishXml } -ReturnRepresentation $false | Out-Null
        Write-Host "  [OK] Customizations published for $tableLower" -ForegroundColor Green
    }
    return $resp
}
#endregion

#region Main Execution -- Auth Bootstrap
$envUrl = $EnvironmentUrl.TrimEnd('/')
$token = Get-DataverseToken -EnvironmentUrl $envUrl
if (-not $token) {
    Write-Host "[ERROR] Failed to obtain authentication token." -ForegroundColor Red
    exit 1
}
$script:AuthToken = $token
$script:EnvironmentUrl = $envUrl
#endregion

#region Dispatcher
switch ($Operation) {
    "QueryDashboards" {
        Get-Dashboards -NameFilter $DashboardNameFilter -TableName $TableName -AppModuleUniqueName $AppModuleUniqueName
    }
    "GetDashboard" {
        if (-not $DashboardId) { throw "DashboardId required" }
        Get-DashboardRaw -DashboardId $DashboardId
    }
    "ListDashboardStructure" {
        if (-not $DashboardId) { throw "DashboardId required" }
        Get-DashboardStructure -DashboardId $DashboardId
    }
    "CreateDashboard" {
        if (-not $DashboardName) { throw "DashboardName required" }
        New-Dashboard -DashboardName $DashboardName -LayoutPreset $LayoutPreset -TableName $TableName -Description $DashboardDescription -SolutionName $SolutionName
    }
    "AddDashboardChart" {
        if (-not $DashboardId) { throw "DashboardId required" }
        if (-not $CellName) { throw "CellName required" }
        if (-not $VisualizationId) { throw "VisualizationId required (run QuerySystemCharts to find one, or CreateSystemChart first)" }
        if (-not $ViewId) { throw "ViewId required (chart's underlying view from QueryViews on the table)" }
        if (-not $TargetEntityType) { throw "TargetEntityType required (e.g. 'hso_authorization')" }
        Add-ChartComponent -DashboardId $DashboardId -CellName $CellName `
            -VisualizationId $VisualizationId -ViewId $ViewId -TargetEntityType $TargetEntityType `
            -ColumnIndex $ColumnIndex -RowIndex $RowIndex -ColSpan $ColSpan -RowSpan $RowSpan `
            -EnableChartPicker $EnableChartPicker -ChartGridMode $ChartGridMode `
            -IsUserChart $IsUserChart -IsUserView $IsUserView `
            -CellLabel $CellLabel -CellShowLabel $CellShowLabel
    }
    "AddDashboardList" {
        if (-not $DashboardId) { throw "DashboardId required" }
        if (-not $CellName) { throw "CellName required" }
        if (-not $ViewId) { throw "ViewId required (find via QueryViews in hso-dataverse-ui-config)" }
        if (-not $TargetEntityType) { throw "TargetEntityType required" }
        Add-ListComponent -DashboardId $DashboardId -CellName $CellName `
            -ViewId $ViewId -TargetEntityType $TargetEntityType `
            -ColumnIndex $ColumnIndex -RowIndex $RowIndex -ColSpan $ColSpan -RowSpan $RowSpan `
            -EnableViewPicker $EnableViewPicker -EnableQuickFind $EnableQuickFind -EnableJumpBar $EnableJumpBar `
            -RecordsPerPage $RecordsPerPage -AutoExpand $AutoExpand -IsUserView $IsUserView `
            -CellLabel $CellLabel -CellShowLabel $CellShowLabel
    }
    "AddDashboardWebResource" {
        if (-not $DashboardId) { throw "DashboardId required" }
        if (-not $CellName) { throw "CellName required" }
        if (-not $WebResourceUrl) { throw "WebResourceUrl required (e.g. 'hso_/html/dashboards/filter-strip.html' or '`$webresource:hso_/html/...')" }
        Add-WebResourceComponent -DashboardId $DashboardId -CellName $CellName `
            -WebResourceUrl $WebResourceUrl -WebResourcePassParameters $WebResourcePassParameters `
            -WebResourceBorder $WebResourceBorder -WebResourceScrolling $WebResourceScrolling `
            -ColumnIndex $ColumnIndex -RowIndex $RowIndex -ColSpan $ColSpan -RowSpan $RowSpan
    }
    "AddDashboardPCFControl" {
        if (-not $DashboardId) { throw "DashboardId required" }
        if (-not $CellName) { throw "CellName required" }
        if (-not $PCFControlName) { throw "PCFControlName required (fully qualified, e.g. 'hso_HSO.Dynamics.PCF.ProgressOfCareChart')" }
        Add-PCFComponent -DashboardId $DashboardId -CellName $CellName `
            -PCFControlName $PCFControlName -PCFParametersJson $PCFParametersJson -PCFVersion $PCFVersion `
            -ColumnIndex $ColumnIndex -RowIndex $RowIndex -ColSpan $ColSpan -RowSpan $RowSpan
    }
    "AddDashboardPowerBITile" {
        if (-not $DashboardId) { throw "DashboardId required" }
        if (-not $CellName) { throw "CellName required" }
        if (-not $PowerBIWorkspaceId) { throw "PowerBIWorkspaceId required (env-var ref like '@hso_pbi_workspace_id' preferred)" }
        if (-not $PowerBIReportId) { throw "PowerBIReportId required" }
        Add-PowerBITileComponent -DashboardId $DashboardId -CellName $CellName `
            -PowerBIWorkspaceId $PowerBIWorkspaceId -PowerBIReportId $PowerBIReportId -PowerBITileId $PowerBITileId `
            -ColumnIndex $ColumnIndex -RowIndex $RowIndex -ColSpan $ColSpan -RowSpan $RowSpan
    }
    "RemoveDashboardComponent" {
        if (-not $DashboardId) { throw "DashboardId required" }
        if (-not $CellName) { throw "CellName required (the control id of the component to remove; see ListDashboardStructure)" }
        Remove-Component -DashboardId $DashboardId -CellName $CellName
    }
    "UpdateDashboardCellLayout" {
        if (-not $DashboardId) { throw "DashboardId required" }
        if (-not $CellName) { throw "CellName required (the control id of the cell to resize; see ListDashboardStructure)" }
        # ColSpan/RowSpan/RecordsPerPage have script-level defaults (1/4/5) meant for the Add* ops.
        # For an in-place update, only touch what the caller explicitly passed.
        $newColSpan = if ($PSBoundParameters.ContainsKey('ColSpan'))        { $ColSpan }        else { $null }
        $newRowSpan = if ($PSBoundParameters.ContainsKey('RowSpan'))        { $RowSpan }        else { $null }
        $newRpp     = if ($PSBoundParameters.ContainsKey('RecordsPerPage')) { $RecordsPerPage } else { $null }
        if ($null -eq $newColSpan -and $null -eq $newRowSpan -and $null -eq $newRpp) {
            throw "UpdateDashboardCellLayout requires at least one of -ColSpan, -RowSpan, -RecordsPerPage"
        }
        Update-CellLayout -DashboardId $DashboardId -CellName $CellName `
            -NewColSpan $newColSpan -NewRowSpan $newRowSpan -NewRecordsPerPage $newRpp
    }
    "NormalizeDashboardLayout" {
        if (-not $DashboardId) { throw "DashboardId required" }
        Repair-DashboardLayout -DashboardId $DashboardId
    }
    "SetDashboardDefault" {
        if (-not $DashboardId) { throw "DashboardId required" }
        Set-DashboardAsDefault -DashboardId $DashboardId -AppModuleUniqueName $AppModuleUniqueName
    }
    "SetDashboardSecurityRoles" {
        if (-not $DashboardId) { throw "DashboardId required" }
        Set-DashboardRoles -DashboardId $DashboardId -RoleIds $RoleIds
    }
    "AddDashboardToApp" {
        if (-not $DashboardId) { throw "DashboardId required" }
        if (-not $AppModuleUniqueName) { throw "AppModuleUniqueName required" }
        Add-DashboardToAppModule -DashboardId $DashboardId -AppModuleUniqueName $AppModuleUniqueName -SkipPublish:$SkipPublish
    }
    "PublishApp" {
        if (-not $AppModuleUniqueName) { throw "AppModuleUniqueName required" }
        Publish-AppModuleByUniqueName -AppModuleUniqueName $AppModuleUniqueName
    }
    "PublishDashboard" {
        if (-not $DashboardId) { throw "DashboardId required" }
        Publish-DashboardCustomizations -DashboardId $DashboardId
    }

    # System Chart Operations
    "QuerySystemCharts" {
        if (-not $TableName) { throw "TableName required" }
        Get-SystemCharts -TableName $TableName
    }
    "GetSystemChart" {
        if (-not $ChartId) { throw "ChartId required" }
        Get-SystemChartDetails -ChartId $ChartId
    }
    "CreateSystemChart" {
        if (-not $ChartName) { throw "ChartName required" }
        if (-not $TableName) { throw "TableName required" }
        if (-not $GroupByColumn) { throw "GroupByColumn required (the dimension to group by, e.g. 'hso_status_code' or 'createdon')" }
        if (-not $AggregateColumn) { throw "AggregateColumn required (the column to aggregate; for count, use the table's primary key)" }
        New-SystemChart -ChartName $ChartName -ChartDescription $ChartDescription -TableName $TableName `
            -ChartType $ChartType -GroupByColumn $GroupByColumn -GroupByDateInterval $GroupByDateInterval `
            -AggregateColumn $AggregateColumn -AggregateFunction $AggregateFunction `
            -ChartFilter $ChartFilter -SolutionName $SolutionName
    }

    "UpdateSystemChart" {
        if (-not $ChartId) { throw "ChartId required" }
        # $ChartType has a script default ("Column") meant for CreateSystemChart -- only regenerate
        # the presentation from the template when the caller explicitly passed -ChartType.
        $typeForTemplate = if ($PSBoundParameters.ContainsKey('ChartType')) { $ChartType } else { '' }
        Update-SystemChart -ChartId $ChartId -ChartType $typeForTemplate `
            -PresentationDescription $PresentationDescription -DataDescription $DataDescription `
            -SolutionName $SolutionName
    }

    # Deferred Operations
    "DeleteSystemChart" {
        throw "DeleteSystemChart is not yet implemented. Use the maker portal or XrmToolBox Chart Manager. File a skill enhancement if you need this in-script."
    }

    default { throw "Unknown operation: $Operation" }
}

Write-Host "`nOperation completed." -ForegroundColor Cyan
#endregion
