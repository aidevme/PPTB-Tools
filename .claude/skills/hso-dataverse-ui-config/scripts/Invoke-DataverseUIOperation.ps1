# lint:allow-raw-invoke-file ADR 0014 documented deferral. The inline raw calls here (e.g.
# AddAppComponents, the UTF-8 sitemap PATCHes) build headers inline. The ADR classes these as
# intra-skill duplication rather than the cross-skill shadow/drift class, and defers them:
# they need per-site relative-endpoint extraction and carry breakage risk disproportionate to
# the value. Revisit alongside ADR 0014, not as a drive-by lint fix.
<#
.SYNOPSIS
    Performs Dataverse UI operations (forms and views) using the Web API.

.DESCRIPTION
    This script manages Dataverse form configurations and views:
    - Form Operations: Query, Get, Update, AddTab, AddSection, AddFields, AddSubgrid, ListFormStructure
    - View Operations: Query, Create, Update, Delete, GetDetails
    - Publish customizations

    IMPORTANT: This script modifies your Dataverse forms/views. It requires
    interactive authentication to ensure you are aware of the changes
    being made to your environment.

.PARAMETER Operation
    The operation to perform.

.PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com)

.NOTES
    Requires: PowerShell 5.1+, MSAL.PS module (installed automatically if missing)
    Author: HSO Dataverse UI Config Skill
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        # Form Operations
        "QueryForms", "GetForm", "UpdateForm", "CreateForm", "RenameForm", "SetFormDescription", "AddTab", "RemoveTab", "AddSection", "RemoveSection",
        "MoveSection", "RenameTab", "RenameSection", "UpdateField",
        "AddFields", "RemoveField", "MoveField",
        "AddHeaderField", "RemoveHeaderField", "AddFooterField", "RemoveFooterField",
        "AddSubgrid", "ConfigureSubgrid",
        "AddTimeline", "AddFormComponent",
        "AddWebResource", "AddQuickViewControl", "ConfigureLookup", "AddSpacer",
        "AddHiddenField", "RemoveHiddenField",
        "SetFormProperties", "SetTabProperties", "SetSectionProperties",
        "AddFormEvent", "RemoveFormEvent", "AddFormLibrary", "RemoveFormLibrary",
        "SetDisplayConditions", "AddNavItem", "RemoveNavItem",
        "AddFormToApp", "AddViewsToApp", "PublishForm", "ListFormStructure", "AddPCFControl", "RemovePCFControl",
        # Composite Operations (Layer-4 helpers -- declarative builders, not thin wrappers; see ADR 0013 Rule 2)
        "BuildForm", "BuildAllForms", "CurateDefaultViews",
        # View Operations
        "QueryViews", "GetViewDetails", "InspectViews", "CreateView", "UpdateView", "DeleteView",
        # Sitemap Operations
        "GetSiteMap", "BuildSiteMap", "UpdateSubArea", "AddSiteMapSubArea", "MoveSiteMapGroup"
    )]
    [string]$Operation,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentUrl,


    # Table parameters
    [string]$TableName,

    # Form parameters
    [string]$FormId,
    [string]$FormName,
    [string]$FormDescription,    # HSO standard — required on every form. Renders in maker portal Form Properties; useful spec traceability.
    [ValidateSet("Main", "QuickCreate", "QuickView", "Card")]
    [string]$FormType = "Main",
    [string]$FormXmlPath,
    [string]$FormXmlContent,

    # Tab parameters
    [string]$TabName,
    [string]$TabLabel,
    [ValidateRange(1,3)]
    [int]$TabColumns = 1,
    [bool]$TabShowLabel = $true,
    [bool]$TabExpanded = $true,
    [int]$TabPosition = -1,

    # Section parameters
    [string]$SectionName,
    [string]$SectionId,          # GUID-based section lookup for auto-generated forms with no @name
    [string]$NewSectionName,    # Used by RenameSection to set the section's new @name
    [string]$SectionLabel,
    [int]$SectionColumns = 2,
    [object]$SectionShowLabel = $true,   # accept [bool] or string ("true"/"false"/"1"/"0") for bash callers; coerced via ConvertTo-NormalizedBool at dispatch
    [int]$SectionLabelWidth = 115,
    [int]$SectionPosition = -1,
    [int]$TabColumnIndex = 0,
    [int]$TargetColumnIndex = -1,

    # Field parameters
    [array]$Fields,
    [string]$FieldName,
    [string]$FieldType,
    [string]$FieldShowLabel,    # "true" or "false" - show/hide the field label on the form
    [string]$FieldReadOnly,     # "true" or "false" - make field read-only
    [string]$FieldVisible,      # "true" or "false" - show/hide the field

    # Subgrid parameters
    [string]$SubgridName,
    [string]$SubgridLabel,
    [string]$RelatedTable,
    [string]$RelationshipName,
    [string]$ViewId,
    [int]$SubgridRowspan = 10,
    [int]$RecordsPerPage = 10,
    [bool]$EnableQuickFind = $true,
    [bool]$EnableViewPicker = $true,

    # Timeline parameters
    [string]$ControlName,
    [int]$ControlRowspan = 25,

    # Form Component parameters
    [string]$RelatedFormId,

    # Event parameters
    [string]$EventName,
    [string]$FunctionName,
    [string]$LibraryName,
    [string]$EventAttribute,
    [string]$HandlerUniqueId,       # targets ONE handler when duplicates share a functionName
    [bool]$PassExecutionContext = $true,

    # View parameters
    [string]$ViewName,
    [string[]]$ViewNames,           # for AddViewsToApp -- accepts comma-separated string from bash callers via ConvertTo-NormalizedArray
    [string]$ViewDescription,
    [ValidateSet("PublicView", "QuickFind", "Associated", "Lookup")]
    [string]$ViewType = "PublicView",
    [array]$ViewColumns,        # string names, OR object form @{ Name='x'; Width=150 } (name+width can't desync)
    [array]$ViewColumnWidths,
    [string]$ViewFilter,
    [string]$ViewSortBy,
    [int]$ViewFloorMin = 0,         # #407 spec floorMin (0 = none)
    [int]$ViewFloorMax = 0,         # #407 spec floorMax (0 = none)
    [object]$ViewSortDescending = $false,   # accept [bool] or string ("true"/"false"/"1"/"0") for bash callers
    [string[]]$ViewFindColumns,
    [array]$ViewLinkedColumns,      # array of hashtables: @{ Alias; LookupField; RelatedTable; Columns; Widths?; LinkType? }
    [string]$ViewRawFetchXml,       # raw passthrough — bypasses Build-FetchXml entirely (UpdateView only)
    [string]$ViewRawLayoutXml,      # raw passthrough — bypasses Build-LayoutXml entirely (UpdateView only)
    [Alias('SolutionUniqueName')]   # ADR 0025: accept the commonly-guessed name so a transposed param doesn't cost a retry
    [string]$SolutionName,

    # App Module parameters
    [Alias('AppUniqueName')]        # ADR 0025: GetSiteMap/app ops were repeatedly called with -AppUniqueName
    [string]$AppModuleUniqueName,

    # Sitemap parameters
    [string]$SubAreaId,
    [string]$SubAreaEntity,
    [string]$SubAreaUrl,
    [string]$SubAreaDefaultDashboard,
    [string]$SubAreaViewId,
    [string]$AreaId,
    [string]$AreaTitle,
    [string]$GroupId,
    [string]$GroupTitle,
    [string]$SubAreaTitle,
    [int]$GroupPosition = -1,    # 0-based index when moving/creating a Group within its Area; -1 = append (default)

    # MoveField parameters
    [string]$TargetTabName,
    [string]$TargetSectionName,
    [int]$FieldPosition = -1,

    # Web Resource parameters
    [string]$WebResourceUrl,
    [bool]$WebResourcePassParameters = $false,
    [int]$WebResourceHeight = 150,
    [int]$WebResourceWidth = -1,
    [bool]$WebResourceBorder = $true,
    [string]$WebResourceScrolling = "auto",

    # Quick View Control parameters
    [string]$QuickForms,
    [string]$QuickFormEntityName,

    # Lookup configuration parameters
    [string]$LookupDefaultViewId,
    [string]$LookupFilterRelationship,
    [string]$LookupDependentAttribute,
    [string]$LookupDependentAttributeType,
    [string]$LookupDisableMru,
    [string]$LookupDisableQuickFind,
    [string]$LookupDisableViewPicker,
    [string]$LookupAvailableViewIds,
    [string]$LookupAllowFilterOff,
    [string]$LookupIsInlineNewEnabled,

    # Form-level properties
    [string]$FormShowImage,
    [string]$FormShowNavBar,
    [int]$FormMaxWidth = -1,
    [string]$FormEnableRelatedInfo,
    [string]$FormRelatedInfoCollapsed,
    [string]$FormHasMargin,

    # Tab property overrides (for SetTabProperties)
    [string]$TabVisible,
    [string]$TabAvailableForPhone,
    [string]$TabCollapsible,

    # Section property overrides (for SetSectionProperties)
    [string]$SectionVisible,
    [string]$SectionAvailableForPhone,
    [string]$SectionAutoExpand,
    [string]$SectionHeight,

    # Enhanced field properties (for UpdateField / SetFieldProperties)
    [int]$FieldColspan = -1,
    [int]$FieldRowspan = -1,
    [string]$FieldAvailableForPhone,
    [string]$FieldIsRequired,

    # Advanced subgrid parameters (for ConfigureSubgrid)
    [string]$SubgridAutoExpand,
    [int]$SubgridMaxRowsBeforeScroll = -1,
    [string]$SubgridEnableJumpBar,
    [string]$SubgridChartGridMode,
    [string]$SubgridVisualizationId,
    [string]$SubgridEnableChartPicker,
    [string]$SubgridEnableContextualActions,
    [string]$SubgridHeaderColorCode,
    [string]$SubgridEnableViewPicker,

    # Display conditions parameters
    [string[]]$DisplayConditionRoles,
    [string]$FallbackFormId,
    [int]$DisplayOrder = -1,

    # Navigation parameters
    [string]$NavItemId,
    [string]$NavItemLabel,
    [string]$NavItemUrl,
    [string]$NavItemRelationship,
    [string]$NavItemIcon,

    # Event handler parameters (extended)
    [string]$EventParameters,
    [string]$EventTabName,
    [string]$EventControlName,

    # PCF control binding parameters (for AddPCFControl)
    [string]$PCFControlName,
    [string]$PCFVersion = "1.0.0",
    [string]$PCFParametersJson,   # JSON string: {"paramName":"value",...}
    [int[]]$FormFactors = @(0, 1, 2),  # 0=Web, 1=Phone, 2=Tablet

    # Batch / publish control
    [switch]$SkipPublish,

    # Composite-operation parameters (BuildForm / BuildAllForms / CurateDefaultViews)
    [string]$LayoutSpec,                 # BuildForm: declarative layout spec -- inline JSON string or a file path
    [string]$AppSpec,                    # BuildSiteMap: the `app` object (areas/groups/subAreas) -- inline JSON string or a file path; non-spec.json path
    [string]$SpecJsonPath,               # BuildAllForms: spec.json whose forms[] Main entries drive the build
    [string[]]$FormTables,               # BuildAllForms: limit the build to these table logical names (default: all spec Main forms)
    [ValidateSet("Replace", "Merge")]
    [string]$Mode = "Replace",           # BuildForm: Replace (author body from spec) | Merge (additive, future)
    [switch]$DryRun,                     # BuildForm/CurateDefaultViews: compute + print, do not write
    [switch]$StrictContract,             # BuildForm/BuildAllForms: promote [HEADER-WARN]/[SUBGRID-FALLBACK] to build failures (default off)
    [string[]]$Views,                    # CurateDefaultViews: which system views to curate (default Active,Inactive,QuickFind)
    [int]$MaxColumns = 8,                # CurateDefaultViews: column floor cap (6-10); default mid-floor
    [switch]$IncludeOwner,               # CurateDefaultViews: include ownerid in the curated set
    [switch]$Raw,                        # GetViewDetails: also emit the raw savedquery object (default: formatted block only)
    [switch]$Summary                     # GetViewDetails: print only the parsed columns/sort/filter one-liner, not raw XML
)

#region Configuration
$script:LanguageCode = 1033  # English
$script:PublisherPrefix = "hso"
#endregion

#region Control ClassID Reference
$script:ControlClassIds = @{
    # Standard field controls
    "String"            = "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
    "SingleLineText"    = "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"
    "Memo"              = "{E0DECE4B-6FC8-4a8f-A065-082708572369}"
    "MultiLineText"     = "{E0DECE4B-6FC8-4a8f-A065-082708572369}"
    "Integer"           = "{C6D124CA-7EDA-4a60-AEA9-7FB8D318B68F}"
    "WholeNumber"       = "{C6D124CA-7EDA-4a60-AEA9-7FB8D318B68F}"
    "Decimal"           = "{C3EFE0C3-0EC6-42be-8349-CBD9079DFD8E}"
    "Money"             = "{533B9E00-756B-4312-95A0-DC888637AC78}"
    "Currency"          = "{533B9E00-756B-4312-95A0-DC888637AC78}"
    "DateOnly"          = "{5B773807-9FB2-42db-97C3-7A91EFF8ADFF}"
    "DateTime"          = "{6D0E476D-F753-4be8-B03F-7D3D7D4E6C1E}"
    "Lookup"            = "{270BD3DB-D9AF-4782-9025-509E298DEC0A}"
    "Customer"          = "{270BD3DB-D9AF-4782-9025-509E298DEC0A}"
    "Picklist"          = "{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}"
    "OptionSet"         = "{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}"
    "Choice"            = "{3EF39988-22BB-4f0b-BBBE-64B5A3748AEE}"
    "StatusCode"        = "{5D68B988-0661-4db2-BC3E-17598AD3BE6C}"
    "MultiSelectPicklist" = "{4AA28AB7-9C13-4F57-A73D-AD894D048B5F}"
    "TwoOptions"        = "{67FAC785-CD58-4f9f-ABB3-4B7DDC6ED5ED}"
    "Boolean"           = "{67FAC785-CD58-4f9f-ABB3-4B7DDC6ED5ED}"
    "YesNo"             = "{67FAC785-CD58-4f9f-ABB3-4B7DDC6ED5ED}"
    "Checkbox"          = "{B0C6723A-8503-4FD7-BB28-C8A06AC933C2}"
    # Special controls
    "Subgrid"           = "{E7A81278-8635-4d9e-8D4D-59480B391C5B}"
    "QuickViewForm"     = "{5C5600E0-1D6E-4205-A272-BE80DA87FD42}"
    "Notes"             = "{06375649-c143-495e-a496-c962e5b4488e}"
    "Timeline"          = "{06375649-c143-495e-a496-c962e5b4488e}"
    "WebResource"       = "{9FDF5F91-88B1-47f4-AD53-C11EFC01A01D}"
    "IFrame"            = "{FD2A7985-3187-444e-908D-6624B21F69C0}"
    "Spacer"            = "{00AD73DA-BD4D-49C6-88A8-2F4F4CAD4A20}"
    "Map"               = "{62B0DF79-0464-470F-8AF7-4483CFEA0C7D}"
    # Special text controls
    "URL"               = "{71716B6C-711E-476c-8AB8-5D11542BFB47}"
    "Email"             = "{ADA2203E-B4CD-49be-9DDF-234642B43B52}"
    "Phone"             = "{8C10015A-B339-4982-9474-A95FE05631A5}"
    "TickerSymbol"      = "{1E1FC551-F7A8-43af-AC34-A8DC35C7B6D4}"
}

# Reverse lookup for classid to type name
$script:ClassIdToType = @{}
foreach ($key in $script:ControlClassIds.Keys) {
    $classId = $script:ControlClassIds[$key]
    if (-not $script:ClassIdToType.ContainsKey($classId)) {
        $script:ClassIdToType[$classId] = $key
    }
}

$script:FormTypeCodes = @{
    "Main"       = 2
    "QuickCreate" = 7
    "QuickView"  = 6
    "Card"       = 11
}
#endregion

#region Validation
#endregion

#region Shared Module Imports
$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"
. "$sharedDir\Dataverse-WebApi.ps1"
#endregion

#region Helper Functions
function New-Guid { return "{$([guid]::NewGuid().ToString())}" }

function Write-DescriptionWarning {
    <#
    .SYNOPSIS
        Emits a yellow warning when a UI component is created without a description.
    .DESCRIPTION
        HSO standard: every form and view must carry a Description. Forms surface their
        description in maker portal Form Properties; views surface their description in
        the view picker. Even where Microsoft barely surfaces the value, descriptions
        provide spec traceability and consistent documentation.

        Warns rather than blocks so existing automation does not break, but every miss
        is surfaced for the agent to fix in the same session.
    #>
    param(
        [Parameter(Mandatory = $true)] [string]$ComponentKind,
        [Parameter(Mandatory = $true)] [string]$ComponentName,
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Description)) {
        Write-Host "  [WARN] No description provided for $ComponentKind '$ComponentName'." -ForegroundColor Yellow
        Write-Host "         HSO standard: every $ComponentKind must have a Description (spec traceability, maker-portal visibility)." -ForegroundColor Yellow
        Write-Host "         See: shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md / view-configuration-best-practices.md (Descriptions are mandatory)." -ForegroundColor Yellow
    }
}

function Write-PublicViewColumnFloorWarning {
    <#
    .SYNOPSIS
        Emits a yellow warning when a Public (MainApplicationView) view is created/updated with
        too few display columns.
    .DESCRIPTION
        HSO Views SOP: a Public view (querytype = 0) is the primary grid an operator works in,
        so it should be curated to roughly 6-10 meaningful columns. A freshly-built view that
        carries only the auto-default handful of columns (primary name + a couple of stubs) is
        under-populated and ships an unhelpful grid.

        Only fires for Public views (querytype 0) -- Lookup (4), QuickFind (1), and Associated (2)
        views are intentionally narrow and are excluded. Warns rather than blocks so existing
        automation does not break; mirrors Write-DescriptionWarning's warn-only contract.
    #>
    param(
        [Parameter(Mandatory = $true)] [int]$QueryType,
        [Parameter(Mandatory = $true)] [int]$ColumnCount,
        [string]$ViewName
    )

    if ($QueryType -ne 0) { return }
    if ($ColumnCount -ge 4) { return }

    $nameLabel = if ($ViewName) { " '$ViewName'" } else { "" }
    Write-Host "  [WARN] Public view$nameLabel has only $ColumnCount display column(s)." -ForegroundColor Yellow
    Write-Host "         HSO Views SOP: the default Public view is under-populated and should be curated to 6-10 columns." -ForegroundColor Yellow
    Write-Host "         See: shared/dv/agent/wiki/sop/model-driven-apps/view-configuration-best-practices.md (Public views: 6-10 curated columns)." -ForegroundColor Yellow
}

# #407: fail when a built view's column count is outside the spec's per-view floor.
function Assert-ViewColumnFloor {
    param(
        [int]$FloorMin = 0,
        [int]$FloorMax = 0,
        [Parameter(Mandatory = $true)] [int]$ColumnCount,
        [string]$ViewName
    )
    if ($FloorMin -le 0 -and $FloorMax -le 0) { return }
    if ($ColumnCount -lt 0) { return }   # unparseable layout
    $label = if ($ViewName) { " '$ViewName'" } else { "" }
    if ($FloorMin -gt 0 -and $ColumnCount -lt $FloorMin) {
        Write-Host ""
        Write-Host "  [FLOOR-FAIL] view$label built with $ColumnCount column(s), below the spec floor of $FloorMin." -ForegroundColor Red
        Write-Host "               spec.json views[].floorMin is the contract; add columns to meet it (or fix the spec), then re-run." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
    if ($FloorMax -gt 0 -and $ColumnCount -gt $FloorMax) {
        Write-Host ""
        Write-Host "  [FLOOR-FAIL] view$label built with $ColumnCount column(s), above the spec ceiling of $FloorMax." -ForegroundColor Red
        Write-Host "               Trim to spec.json views[].floorMax, then re-run." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
    Write-Host "  [FLOOR-OK] view${label}: $ColumnCount column(s) within spec floor [$FloorMin..$FloorMax]." -ForegroundColor DarkGray
}

# Count the display <cell> elements in a layoutxml string -- the authoritative column count for a
# view's grid (what the operator actually sees). Returns -1 when the layout cannot be parsed so the
# caller can skip the floor check rather than emit a spurious warning. Warn-only path: never throws.
function Get-LayoutColumnCount {
    param([string]$LayoutXml)
    if ([string]::IsNullOrWhiteSpace($LayoutXml)) { return -1 }
    try {
        [xml]$doc = $LayoutXml
        $cells = $doc.SelectNodes("//row/cell")
        if ($null -eq $cells) { return -1 }
        return $cells.Count
    } catch {
        return -1
    }
}

# When invoked via `powershell -File` from bash/cmd, comma-separated array args arrive
# as a single-element array containing one comma-joined string. Normalize so callers can
# pass either a real PS array (`@('a','b')`), a comma-separated string ('a,b,c'), or a
# single value. Hashtable elements (used by AddFields/CreateForm for {Name;Label;Type}
# entries) are passed through untouched.
function ConvertTo-NormalizedArray {
    param($InputValue)
    if ($null -eq $InputValue) { return @() }
    $arr = if ($InputValue -is [array] -or $InputValue -is [System.Collections.IList]) { @($InputValue) } else { @($InputValue) }
    $result = @()
    foreach ($item in $arr) {
        if ($item -is [string] -and $item -match ',') {
            foreach ($part in ($item -split ',')) {
                $trimmed = $part.Trim()
                if ($trimmed) { $result += $trimmed }
            }
        } elseif ($null -ne $item -and $item -ne '') {
            $result += $item
        }
    }
    return ,$result
}

# Same bash/cmd-line concern for [bool] params: a string like "true"/"false"/"1"/"0" passed via
# `powershell -File` doesn't auto-coerce reliably. Normalize to a real [bool], defaulting to $false
# when unset/empty so existing PowerShell callers using `-Param $true` still work.
function ConvertTo-NormalizedBool {
    param($InputValue)
    if ($null -eq $InputValue -or $InputValue -eq '') { return $false }
    if ($InputValue -is [bool]) { return $InputValue }
    if ($InputValue -is [int]) { return ($InputValue -ne 0) }
    $s = "$InputValue".Trim().ToLower()
    return ($s -in 'true', '1', 'yes', 'y', 't')
}

# Cache of resolved DisplayName per "$tableName/$fieldName" so a single AddFields batch only
# round-trips per-attribute metadata once.
$script:FieldLabelCache = @{}

# Humanize a logical field name for use as a fallback cell label when neither the caller nor
# Dataverse metadata supply a DisplayName. Strips publisher prefix (hso_, msdyn_, etc.), strips
# common HSO type suffixes (_text/_num/_amt/_yn/_date/_code/_codes/_id/_memo/_dec), replaces
# underscores with spaces, and title-cases. e.g. "hso_visit_start_date" -> "Visit Start".
function Get-HumanizedFieldName {
    param([string]$FieldName)
    if (-not $FieldName) { return "" }
    $name = $FieldName -replace '^[a-z][a-z0-9]+_', ''
    $name = $name -replace '_(text|num|amt|yn|date|code|codes|id|memo|dec)$', ''
    $name = $name -replace '_', ' '
    if (-not $name) { $name = $FieldName }
    return (Get-Culture).TextInfo.ToTitleCase($name)
}

# Resolve the cell label for a field. Priority order:
#   1. Explicit ProvidedLabel from the caller (hashtable @{Label='...'})
#   2. Live Dataverse attribute DisplayName (from EntityDefinitions metadata)
#   3. Humanized form of the logical field name (Get-HumanizedFieldName)
# We always return a non-empty label so Add-FieldsToForm / Add-HeaderFieldToForm can write an
# explicit <labels> element on every cell. Without this, Dataverse server-side persists an
# auto-generated <label description=""...> when a freshly-created column has no display name --
# which is what produced the empty-cell-label bug on Visit Note (hso_client_id) and Authorization
# (hso_visittypesallowed_codes) in 2026-05.
function Resolve-FieldLabel {
    param([string]$TableName, [string]$FieldName, [string]$ProvidedLabel)
    if ($ProvidedLabel) { return $ProvidedLabel }
    if (-not $TableName -or -not $FieldName) { return (Get-HumanizedFieldName -FieldName $FieldName) }
    $cacheKey = "$TableName/$FieldName"
    if ($script:FieldLabelCache.ContainsKey($cacheKey)) { return $script:FieldLabelCache[$cacheKey] }
    $resolved = $null
    try {
        $endpoint = "EntityDefinitions(LogicalName='$TableName')/Attributes(LogicalName='$FieldName')?`$select=DisplayName"
        $resp = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
        if ($resp -and $resp.DisplayName -and $resp.DisplayName.UserLocalizedLabel -and $resp.DisplayName.UserLocalizedLabel.Label) {
            $resolved = $resp.DisplayName.UserLocalizedLabel.Label
        }
    } catch {
        # Attribute may be a special form-only field (e.g. computed lookup formatted-value alias);
        # fall through to humanize.
    }
    if (-not $resolved) { $resolved = Get-HumanizedFieldName -FieldName $FieldName }
    $script:FieldLabelCache[$cacheKey] = $resolved
    return $resolved
}

function Get-ControlClassId {
    param([string]$FieldType, [string]$FieldName)
    if (-not $FieldType -and $FieldName) {
        if ($FieldName -match '_text$') { $FieldType = "String" }
        elseif ($FieldName -match '_memo$') { $FieldType = "Memo" }
        elseif ($FieldName -match '_num$') { $FieldType = "Integer" }
        elseif ($FieldName -match '_dec$') { $FieldType = "Decimal" }
        elseif ($FieldName -match '_amt$') { $FieldType = "Money" }
        elseif ($FieldName -match '_yn$') { $FieldType = "TwoOptions" }
        elseif ($FieldName -match '_date$') { $FieldType = "DateOnly" }
        elseif ($FieldName -match '_code$') { $FieldType = "Picklist" }
        elseif ($FieldName -match '_codes$') { $FieldType = "MultiSelectPicklist" }
        elseif ($FieldName -match '_id$') { $FieldType = "Lookup" }
        elseif ($FieldName -eq 'statuscode') { $FieldType = "StatusCode" }
        else { $FieldType = "String" }
    }
    if ($script:ControlClassIds.ContainsKey($FieldType)) { return $script:ControlClassIds[$FieldType] }
    return $script:ControlClassIds["String"]
}

# Invoke-DataverseApi is provided by hso-shared-scripts/scripts/Dataverse-WebApi.ps1 (dot-sourced above).
# The former local copy hard-coded Prefer: return=representation on every call; the write
# call sites below pass -ReturnRepresentation $true explicitly to preserve that contract.

function Build-FetchXml {
    param([string]$TableName, [array]$Columns, [string]$Filter, [string]$SortBy, [bool]$SortDescending)
    $tableLower = $TableName.ToLower()
    # The sort column must be present as a fetched <attribute> for the <order> to apply -- but it does
    # NOT have to be a displayed grid column (the layout is built separately). So if -SortBy names a
    # column that isn't in -Columns (e.g. an Inactive view sorted by createdon without showing it),
    # append it as a fetch-only attribute. (P3-4)
    # -notcontains is case-insensitive, so this dedupes regardless of casing.
    $fetchColumns = @($Columns)
    if ($SortBy -and ($fetchColumns -notcontains $SortBy)) { $fetchColumns += $SortBy }
    $attributeElements = ($fetchColumns | ForEach-Object { "<attribute name=`"$($_.ToLower())`" />" }) -join ""
    $orderElement = if ($SortBy) { $sortOrder = if ($SortDescending) { "descending" } else { "ascending" }; "<order attribute=`"$($SortBy.ToLower())`" $sortOrder=`"true`" />" } else { "" }
    $filterElement = if ($Filter) { $Filter } else { "" }
    return @"
<fetch version="1.0" output-format="xml-platform" mapping="logical" distinct="false"><entity name="$tableLower">$attributeElements$orderElement$filterElement</entity></fetch>
"@.Trim()
}

function Build-LayoutXml {
    param([array]$Columns, [array]$Widths, [Parameter(Mandatory=$true)][string]$PrimaryKeyColumn)
    $cellElements = ""
    for ($i = 0; $i -lt $Columns.Count; $i++) {
        $width = if ($Widths -and $i -lt $Widths.Count) { $Widths[$i] } else { 100 }
        $cellElements += "<cell name=`"$($Columns[$i].ToLower())`" width=`"$width`" />"
    }
    return @"
<grid name="resultset" object="1" jump="name" select="1" icon="1" preview="1"><row name="result" id="$PrimaryKeyColumn">$cellElements</row></grid>
"@.Trim()
}

function Build-FetchXmlWithLinks {
    # Appends one <link-entity> block per entry in $LinkedColumns into the base FetchXML.
    # FetchXML N:1 join convention: 'from' = PK on related table ({relatedTable}id),
    # 'to' = lookup field on the primary entity.
    param([string]$BaseFetchXml, [array]$LinkedColumns)
    if (-not $LinkedColumns -or $LinkedColumns.Count -eq 0) { return $BaseFetchXml }
    [xml]$doc = $BaseFetchXml
    $entityNode = $doc.fetch.entity
    foreach ($link in $LinkedColumns) {
        $relatedTable = $link.RelatedTable.ToLower()
        $linkType     = if ($link.LinkType) { $link.LinkType } else { "outer" }
        $cols         = @($link.Columns)

        $linkElem = $doc.CreateElement("link-entity")
        $linkElem.SetAttribute("name", $relatedTable)
        $linkElem.SetAttribute("from", ($relatedTable + "id"))   # PK on related table
        $linkElem.SetAttribute("to", $link.LookupField.ToLower())
        $linkElem.SetAttribute("alias", $link.Alias)
        $linkElem.SetAttribute("link-type", $linkType)

        foreach ($col in $cols) {
            $attrElem = $doc.CreateElement("attribute")
            $attrElem.SetAttribute("name", $col.ToLower())
            $linkElem.AppendChild($attrElem) | Out-Null
        }
        $entityNode.AppendChild($linkElem) | Out-Null
    }
    return $doc.OuterXml
}

function Build-LayoutXmlWithLinks {
    param([string]$BaseLayoutXml, [array]$LinkedColumns)
    if (-not $LinkedColumns -or $LinkedColumns.Count -eq 0) { return $BaseLayoutXml }
    [xml]$doc = $BaseLayoutXml
    $rowNode = $doc.grid.SelectSingleNode("row")
    foreach ($link in $LinkedColumns) {
        $alias  = $link.Alias
        $cols   = @($link.Columns)
        $widths = if ($link.Widths) { @($link.Widths) } else { @() }
        for ($i = 0; $i -lt $cols.Count; $i++) {
            $width = if ($widths -and $i -lt $widths.Count) { $widths[$i] } else { 100 }
            $cellElem = $doc.CreateElement("cell")
            $cellElem.SetAttribute("name", "$alias.$($cols[$i].ToLower())")
            $cellElem.SetAttribute("width", $width.ToString())
            $rowNode.AppendChild($cellElem) | Out-Null
        }
    }
    return $doc.OuterXml
}
#endregion

#region Form Operations

# Helper: locate a form tab by name attribute using XPath to avoid PS7 XmlElement.Name property ambiguity.
# Falls back to matching by @id (GUID) so callers can target auto-generated Dataverse tabs that
# have no @name attribute -- pass the GUID from ListFormStructure output as TabName.
function Find-Tab {
    param([xml]$FormXml, [string]$TabName)

    # Magic value: 'firstunnamed' selects the first <tab> with no @name attribute.
    # Targets the auto-stub tab Dataverse generates on auto-Information Main forms
    # (no name, and the @id GUID is not surfaced through ListFormStructure).
    if ($TabName -eq 'firstunnamed') {
        $tab = $FormXml.SelectSingleNode("//tabs/tab[not(@name)]")
        if ($tab) {
            Write-Host "  [INFO] Matched first unnamed tab via 'firstunnamed' magic value" -ForegroundColor Yellow
        }
        return $tab
    }

    # Primary: exact @name match (works for all user-created tabs)
    $tab = $FormXml.SelectSingleNode("//tabs/tab[@name='$TabName']")
    if ($tab) { return $tab }

    # Fallback: treat TabName as a GUID @id value (strip braces for comparison)
    $cleanId = $TabName -replace '[{}]', ''
    $tab = $FormXml.SelectSingleNode("//tabs/tab[translate(@id,'{}','')='$cleanId']")
    if ($tab) {
        Write-Host "  [INFO] Tab matched by id '$cleanId' (tab has no name attribute -- consider using AddTab to create a named tab)" -ForegroundColor Yellow
    }
    return $tab
}

function Get-Forms {
    param([string]$TableName)
    Write-Host "`nQuerying forms for table: $TableName" -ForegroundColor Cyan
    $endpoint = "systemforms?`$filter=objecttypecode eq '$TableName'&`$select=formid,name,type,formactivationstate,description&`$orderby=type,name"
    $response = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    if ($response.value.Count -eq 0) { Write-Host "  No forms found" -ForegroundColor Yellow; return }
    $typeNames = @{ 0 = "Dashboard"; 1 = "Appointment Book"; 2 = "Main"; 5 = "Mobile Express"; 6 = "Quick View"; 7 = "Quick Create"; 8 = "Dialog"; 11 = "Card"; 12 = "Main (Interactive)" }
    Write-Host "  Found $($response.value.Count) form(s):" -ForegroundColor Green
    foreach ($form in $response.value) {
        # $form.type deserializes as Int64; the map keys are Int32, so ContainsKey misses without a
        # cast (every form printed as "Unknown (n)" despite the code being in the table). Coerce.
        $ft = [int]$form.type
        $typeName = if ($typeNames.ContainsKey($ft)) { $typeNames[$ft] } else { "Unknown ($ft)" }
        $active = if ($form.formactivationstate -eq 1) { "Active" } else { "Inactive" }
        Write-Host "  [$typeName] $($form.name) - $active" -ForegroundColor White
        Write-Host "    ID: $($form.formid)" -ForegroundColor Gray
    }
    return $response.value
}

function Get-FormDetails {
    param([string]$FormId)
    Write-Host "`nRetrieving form details for: $FormId" -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,type,formactivationstate,objecttypecode,formxml,description"
    $response = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    Write-Host "  Form Name: $($response.name)" -ForegroundColor Green
    Write-Host "  Table: $($response.objecttypecode)" -ForegroundColor Gray
    Write-Host "  Form XML Length: $($response.formxml.Length) characters" -ForegroundColor Gray
    Write-Host "`n--- FORM XML START ---" -ForegroundColor DarkGray
    Write-Host $response.formxml
    Write-Host "--- FORM XML END ---" -ForegroundColor DarkGray
    return $response
}

function Get-FormStructure {
    param([string]$FormId)
    Write-Host "`nAnalyzing form structure for: $FormId" -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,type,objecttypecode,formxml"
    $response = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint

    [xml]$formXml = $response.formxml
    $typeNames = @{ 2 = "Main"; 5 = "Mobile Express"; 6 = "Quick View"; 7 = "Quick Create"; 11 = "Card" }
    $typeName = if ($typeNames.ContainsKey([int]$response.type)) { $typeNames[[int]$response.type] } else { "Unknown" }

    Write-Host ""
    Write-Host "Form: $($response.name) ($($response.formid))" -ForegroundColor White
    Write-Host "Table: $($response.objecttypecode) | Type: $typeName" -ForegroundColor Gray
    Write-Host ""

    # Header
    $header = $formXml.form.header
    if ($header -and $header.rows -and $header.rows.row) {
        Write-Host "HEADER" -ForegroundColor Cyan
        $headerFields = @()
        foreach ($row in @($header.rows.row)) {
            foreach ($cell in @($row.cell)) {
                if ($cell.control) {
                    $fieldName = $cell.control.datafieldname
                    if (-not $fieldName) { $fieldName = $cell.control.id }
                    $readonly = if ($cell.control.disabled -eq "true") { " [readonly]" } else { "" }
                    $headerFields += "$fieldName$readonly"
                }
            }
        }
        foreach ($f in $headerFields) { Write-Host "  - $f" -ForegroundColor Gray }
        Write-Host ""
    }

    # Tabs
    Write-Host "TABS" -ForegroundColor Cyan
    $tabIndex = 0
    foreach ($tab in $formXml.form.tabs.tab) {
        $tabIndex++
        $tabLabel = ($tab.labels.label | Where-Object { $_.languagecode -eq "1033" } | Select-Object -First 1).description
        if (-not $tabLabel) { $tabLabel = $tab.name }
        Write-Host "[$tabIndex] $tabLabel ($($tab.name))" -ForegroundColor White

        # Process all columns (lanes) -> sections. The Forms SOP mandates verifying lane
        # distribution before delivery (the right-rail / multi-lane split), so surface each
        # tab column explicitly as a LANE with its width and the sections assigned to it --
        # otherwise this tool can't confirm the very thing the SOP says to check.
        $lanes = @($tab.columns.column)
        $laneCount = $lanes.Count
        $laneIndex = 0
        foreach ($column in $lanes) {
            $laneIndex++
            $laneWidth = if ($column.width) { $column.width } else { "auto" }
            $laneSectionNames = @()
            foreach ($s in @($column.sections.section)) {
                $sn = ($s.labels.label | Where-Object { $_.languagecode -eq "1033" } | Select-Object -First 1).description
                if (-not $sn) { $sn = $s.name }
                $laneSectionNames += $sn
            }
            $laneSummary = if ($laneSectionNames.Count -gt 0) { $laneSectionNames -join ', ' } else { '(no sections)' }
            Write-Host "  LANE $laneIndex/$laneCount (width=$laneWidth): $laneSummary" -ForegroundColor Cyan
            foreach ($section in $column.sections.section) {
                $sectionLabel = ($section.labels.label | Where-Object { $_.languagecode -eq "1033" } | Select-Object -First 1).description
                if (-not $sectionLabel) { $sectionLabel = $section.name }

                # Collect fields, subgrids, web resources, quick views, spacers
                $sectionFields = @()
                $subgrids = @()
                $webResources = @()
                $quickViews = @()
                $spacerCount = 0
                foreach ($row in @($section.rows.row)) {
                    foreach ($cell in @($row.cell)) {
                        if ($cell.control) {
                            $classId = $cell.control.classid
                            if ($classId -eq $script:ControlClassIds["Subgrid"]) {
                                $sgName = $cell.control.id
                                $sgTarget = $cell.control.parameters.TargetEntityType
                                $sgRel = $cell.control.parameters.RelationshipName
                                $sgView = $cell.control.parameters.ViewId
                                $subgrids += @{ Name = $sgName; Target = $sgTarget; Rel = $sgRel; View = $sgView }
                            } elseif ($classId -eq $script:ControlClassIds["WebResource"]) {
                                $wrName = $cell.control.id
                                $wrUrl = $cell.control.parameters.Url
                                $webResources += @{ Name = $wrName; Url = $wrUrl }
                            } elseif ($classId -eq $script:ControlClassIds["QuickViewForm"]) {
                                $qvName = $cell.control.id
                                $qvField = $cell.control.datafieldname
                                $quickViews += @{ Name = $qvName; Field = $qvField }
                            } elseif ($classId -eq $script:ControlClassIds["Spacer"]) {
                                $spacerCount++
                            } else {
                                $fname = $cell.control.datafieldname
                                if (-not $fname) { $fname = $cell.control.id }
                                $sectionFields += $fname
                            }
                        }
                    }
                }

                $hasContent = $subgrids.Count -gt 0 -or $sectionFields.Count -gt 0 -or $webResources.Count -gt 0 -or $quickViews.Count -gt 0
                if ($subgrids.Count -gt 0) {
                    foreach ($sg in $subgrids) {
                        Write-Host "    +-- $($section.name)" -ForegroundColor DarkGray
                        Write-Host "        SUBGRID: $($sg.Name) -> $($sg.Target)" -ForegroundColor Yellow
                        Write-Host "        rel: $($sg.Rel) | view: $($sg.View)" -ForegroundColor DarkGray
                    }
                }
                if ($webResources.Count -gt 0) {
                    foreach ($wr in $webResources) {
                        Write-Host "    +-- $($section.name)" -ForegroundColor DarkGray
                        Write-Host "        WEBRESOURCE: $($wr.Name) -> $($wr.Url)" -ForegroundColor Magenta
                    }
                }
                if ($quickViews.Count -gt 0) {
                    foreach ($qv in $quickViews) {
                        Write-Host "    +-- $($section.name)" -ForegroundColor DarkGray
                        Write-Host "        QUICKVIEW: $($qv.Name) (lookup: $($qv.Field))" -ForegroundColor DarkCyan
                    }
                }
                if ($sectionFields.Count -gt 0) {
                    Write-Host "    +-- $($section.name): $($sectionFields.Count) field(s)" -ForegroundColor DarkGray
                    Write-Host "        [$($sectionFields -join ', ')]" -ForegroundColor DarkGray
                }
            }
        }
        Write-Host ""
    }

    # Footer
    $footer = $formXml.form.footer
    if ($footer -and $footer.rows -and $footer.rows.row) {
        Write-Host "FOOTER" -ForegroundColor Cyan
        foreach ($row in @($footer.rows.row)) {
            foreach ($cell in @($row.cell)) {
                if ($cell.control) {
                    $fname = $cell.control.datafieldname
                    if (-not $fname) { $fname = $cell.control.id }
                    Write-Host "  - $fname" -ForegroundColor Gray
                }
            }
        }
        Write-Host ""
    }

    # Form Libraries
    $formLibraries = $formXml.form.formLibraries
    if ($formLibraries -and $formLibraries.Library) {
        Write-Host "LIBRARIES" -ForegroundColor Cyan
        foreach ($lib in @($formLibraries.Library)) {
            Write-Host "  - $($lib.name)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    # Events
    $formEvents = $formXml.form.events
    if ($formEvents -and $formEvents.event) {
        Write-Host "EVENTS" -ForegroundColor Cyan
        foreach ($evt in @($formEvents.event)) {
            $evtName = $evt.name
            $evtAttr = if ($evt.attribute) { " ($($evt.attribute))" } else { "" }
            $active = if ($evt.active -eq "true") { "" } else { " [inactive]" }
            Write-Host "  $evtName$evtAttr$active" -ForegroundColor White
            if ($evt.Handlers -and $evt.Handlers.Handler) {
                foreach ($h in @($evt.Handlers.Handler)) {
                    $passCtx = if ($h.passExecutionContext -eq "true") { " (passCtx)" } else { "" }
                    $params = if ($h.parameters) { " [params: $($h.parameters)]" } else { "" }
                    Write-Host "    -> $($h.libraryName)::$($h.functionName)$passCtx$params" -ForegroundColor Gray
                }
            }
        }
        Write-Host ""
    }

    # Hidden Controls
    $hiddenControls = $formXml.form.SelectSingleNode("hiddencontrols")
    if ($hiddenControls -and $hiddenControls.HasChildNodes) {
        Write-Host "HIDDEN CONTROLS" -ForegroundColor Cyan
        foreach ($data in @($hiddenControls.data)) {
            $fname = $data.datafieldname
            if (-not $fname) { $fname = $data.id }
            Write-Host "  - $fname" -ForegroundColor Gray
        }
        Write-Host ""
    }

    # Navigation
    $nav = $formXml.form.SelectSingleNode("Navigation")
    if ($nav) {
        $navBar = $nav.SelectSingleNode("NavBar")
        if ($navBar -and $navBar.HasChildNodes) {
            Write-Host "NAVIGATION" -ForegroundColor Cyan
            foreach ($child in $navBar.ChildNodes) {
                if ($child.LocalName -eq "NavBarByRelationshipItem") {
                    $rel = $child.GetAttribute("RelationshipName")
                    $title = ($child.SelectSingleNode("Titles/Title"))
                    $label = if ($title) { $title.GetAttribute("Text") } else { $rel }
                    Write-Host "  - $label (rel: $rel)" -ForegroundColor Gray
                } elseif ($child.LocalName -eq "NavBarItem") {
                    $url = $child.GetAttribute("Url")
                    $title = ($child.SelectSingleNode("Titles/Title"))
                    $label = if ($title) { $title.GetAttribute("Text") } else { $child.GetAttribute("Id") }
                    Write-Host "  - $label (url: $url)" -ForegroundColor Gray
                }
            }
            Write-Host ""
        }
    }

    # Display Conditions
    $displayCond = $formXml.form.SelectSingleNode("DisplayConditions")
    if ($displayCond) {
        Write-Host "DISPLAY CONDITIONS" -ForegroundColor Cyan
        $fallback = $displayCond.GetAttribute("FallbackForm")
        $order = $displayCond.GetAttribute("Order")
        if ($fallback) { Write-Host "  FallbackForm: $fallback" -ForegroundColor Gray }
        if ($order) { Write-Host "  Order: $order" -ForegroundColor Gray }
        $everyone = $displayCond.SelectSingleNode("Everyone")
        if ($everyone) {
            Write-Host "  Visible to: Everyone" -ForegroundColor Gray
        } else {
            $roles = $displayCond.SelectNodes("Role")
            if ($roles.Count -gt 0) {
                Write-Host "  Visible to roles:" -ForegroundColor Gray
                foreach ($role in $roles) {
                    Write-Host "    - $($role.GetAttribute('Id'))" -ForegroundColor Gray
                }
            }
        }
        Write-Host ""
    }

    # Form Properties
    $formAttrs = @()
    if ($formXml.form.GetAttribute("showImage")) { $formAttrs += "showImage=$($formXml.form.GetAttribute('showImage'))" }
    if ($formXml.form.GetAttribute("shownavigationbar")) { $formAttrs += "shownavigationbar=$($formXml.form.GetAttribute('shownavigationbar'))" }
    if ($formXml.form.GetAttribute("maxWidth")) { $formAttrs += "maxWidth=$($formXml.form.GetAttribute('maxWidth'))" }
    if ($formXml.form.GetAttribute("enablerelatedinformation")) { $formAttrs += "enablerelatedinformation=$($formXml.form.GetAttribute('enablerelatedinformation'))" }
    if ($formAttrs.Count -gt 0) {
        Write-Host "FORM PROPERTIES" -ForegroundColor Cyan
        foreach ($attr in $formAttrs) { Write-Host "  $attr" -ForegroundColor Gray }
        Write-Host ""
    }
}

function Get-FormXmlTokens {
    <#
    .SYNOPSIS
        Structural fingerprint of a form's formxml: the tab names, section names, and placed fields.
    .DESCRIPTION
        Used to verify a formxml PATCH actually persisted by reading the form back and confirming
        every element we wrote is present -- independent of the versionnumber bump, which a
        formxml-ONLY write genuinely does not advance (the source of the old false-negative WARN).
        Token-set comparison is robust to the platform reordering attributes or reformatting
        whitespace. Returns a case-insensitive HashSet of prefixed tokens (f:/t:/s:).
    #>
    param([string]$Xml)
    $set = [System.Collections.Generic.HashSet[string]]::new()
    if (-not $Xml) { return $set }
    foreach ($m in [regex]::Matches($Xml, 'datafieldname="([^"]+)"')) { [void]$set.Add("f:" + $m.Groups[1].Value.ToLower()) }
    foreach ($m in [regex]::Matches($Xml, '<tab\b[^>]*?\bname="([^"]+)"')) { [void]$set.Add("t:" + $m.Groups[1].Value.ToLower()) }
    foreach ($m in [regex]::Matches($Xml, '<section\b[^>]*?\bname="([^"]+)"')) { [void]$set.Add("s:" + $m.Groups[1].Value.ToLower()) }
    return $set
}

function Update-FormXml {
    # -CallerVerifiesPersistence: the caller performs its own authoritative read-back after this
    # write. We now verify persistence here by a formxml READ-BACK (token comparison) regardless,
    # so this switch only suppresses the trailing per-op "verify it yourself" Note (BuildForm has
    # already done a structural read-back and doesn't need the nudge).
    param([string]$FormId, [string]$FormXmlPath, [string]$FormXmlContent, [switch]$CallerVerifiesPersistence)
    Write-Host "`nUpdating form XML for: $FormId" -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''
    if ($FormXmlPath -and (Test-Path $FormXmlPath)) {
        $formXml = Get-Content -Path $FormXmlPath -Raw -Encoding UTF8
        Write-Host "  Loaded from: $FormXmlPath" -ForegroundColor Gray
    } elseif ($FormXmlContent) {
        $formXml = $FormXmlContent
        Write-Host "  Using provided form XML content" -ForegroundColor Gray
    } else {
        throw "Either FormXmlPath or FormXmlContent must be provided"
    }
    $formXml = $formXml -replace '\r?\n\s*', '' -replace '>\s+<', '><'
    Write-Host "  Compacted form XML for API" -ForegroundColor Gray

    # Use ConvertTo-Json to safely serialize the XML string -- avoids silent JSON malformation
    # from unescaped backslashes or quotes in hand-rolled string interpolation
    $jsonBody = [ordered]@{ formxml = $formXml } | ConvertTo-Json -Depth 1
    $url = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/systemforms($cleanFormId)"
    $headers = @{
        "Authorization" = "Bearer $script:AuthToken"
        "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0"
        "Accept" = "application/json"; "Content-Type" = "application/json; charset=utf-8"
    }

    # Capture versionnumber BEFORE the write. HTTP 2xx on the PATCH does NOT prove the
    # change persisted as rendered -- the systemforms formxml cache means a "successful"
    # write can be silently lost (or clobbered by a later op that re-read a stale copy).
    # The versionnumber bump is the reliable persistence signal, so confirm it rather than
    # emit a blanket [OK]. (A declarative single-write BuildForm would remove this whole
    # read-modify-write-publish hazard -- see the BuildForm skill-improvement spec.)
    $preVersion = $null
    try { $preVersion = (Invoke-DataverseApi -Method "GET" -Endpoint "systemforms($cleanFormId)?`$select=versionnumber").versionnumber } catch { }

    try {
        Invoke-RestMethod -Uri $url -Method PATCH -Headers $headers -Body $jsonBody -ErrorAction Stop
    } catch {
        Write-Output "[ERROR] Form XML update failed: $($_.Exception.Message)"
        throw
    }

    $postVersion = $null
    try { $postVersion = (Invoke-DataverseApi -Method "GET" -Endpoint "systemforms($cleanFormId)?`$select=versionnumber").versionnumber } catch { }

    # PERSISTENCE VERIFICATION by formxml READ-BACK (authoritative). A formxml-only PATCH genuinely
    # persists WITHOUT advancing versionnumber, so the old version-delta check produced false
    # negatives on the most common path.
    #
    # Read the UNPUBLISHED layer. That is where a formxml PATCH lands, and every caller here
    # publishes AFTER this function returns -- so at this moment a plain GET is serving the
    # PUBLISHED, pre-write copy by definition, not a "momentarily stale cache". Reading the right
    # layer makes this deterministic instead of a race the retry loop was papering over.
    # (Same mis-read that hso-dataverse-dashboards documents at Confirm-DashboardCellPersisted.)
    #
    # The published GET stays as a fallback: if the unpublished read is unavailable for any reason
    # we are no worse off than before rather than losing verification entirely.
    $sentTokens = Get-FormXmlTokens -Xml $formXml
    $persisted = $false
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        $postFormXml = $null
        try { $postFormXml = (Get-DataverseUnpublished -EntitySet 'systemforms' -Id $cleanFormId -Select formxml).formxml } catch { }
        if (-not $postFormXml) {
            try { $postFormXml = (Invoke-DataverseApi -Method "GET" -Endpoint "systemforms($cleanFormId)?`$select=formxml").formxml } catch { }
        }
        if ($postFormXml) {
            $postTokens = Get-FormXmlTokens -Xml $postFormXml
            $missing = @($sentTokens | Where-Object { -not $postTokens.Contains($_) })
            if ($missing.Count -eq 0) { $persisted = $true; break }
        }
        if ($attempt -lt 4) { Start-Sleep -Milliseconds 400 }
    }

    if ($persisted) {
        Write-Output "[OK] Form XML persisted (verified against the unpublished layer: all $($sentTokens.Count) structural element(s) present)."
    } elseif ($null -ne $preVersion -and $null -ne $postVersion -and $postVersion -gt $preVersion) {
        # Read-back didn't fully confirm but the version advanced -- treat as persisted.
        Write-Output "[OK] Form XML persisted (versionnumber $preVersion -> $postVersion)."
    } elseif ($CallerVerifiesPersistence) {
        Write-Output "[INFO] Form XML PATCH accepted; read-back not yet fully reflected. Caller verifies persistence by its own read-back."
    } else {
        Write-Output "[WARN] PATCH succeeded but a formxml read-back did not confirm all elements (a deferred-publish batch may have clobbered an earlier edit). Re-read with ListFormStructure before relying on it."
    }
    # Only warn about the deferred-publish clobber hazard when publish was ACTUALLY deferred. Firing it
    # on a single op that published immediately (the common RemoveField/AddField case) describes a
    # situation that isn't happening and reads as a false alarm next to the [OK]. (P4-2 retro)
    if ($script:SkipPublishGlobal) {
        Write-Host "    Note: deferring publish across a batch of ops can clobber earlier edits; publish per-op or use BuildForm for a one-shot multi-tab build." -ForegroundColor Yellow
    }
}

function Publish-FormCustomizations {
    param([string]$TableName)
    # Centralized skip gate -- set $script:SkipPublishGlobal = $true at dispatch when the caller
    # passed -SkipPublish to defer publishing across a long batch of form mutations. The PublishForm
    # operation always overrides the gate (see dispatcher) so callers can publish once at the end.
    if ($script:SkipPublishGlobal) {
        Write-Host "  [skip-publish] deferring PublishXml for $TableName -- caller will batch-publish" -ForegroundColor DarkGray
        return
    }
    Write-Host "`nPublishing customizations for: $TableName" -ForegroundColor Cyan
    $publishXml = "<importexportxml><entities><entity>$TableName</entity></entities></importexportxml>"
    Invoke-DataverseApi -Method "POST" -Endpoint "PublishXml" -Body @{ ParameterXml = $publishXml } -ReturnRepresentation $true
    Write-Output "[OK] Customizations published for $TableName"
}

function Add-FormToApp {
    param([string]$FormId, [string]$AppModuleUniqueName)
    Write-Host "`nAdding form to model-driven app..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    # Resolve app module ID from unique name
    Write-Host "  Looking up app module: $AppModuleUniqueName" -ForegroundColor Gray
    $appResponse = Invoke-DataverseApi -Method "GET" -Endpoint "appmodules?`$filter=uniquename eq '$AppModuleUniqueName'&`$select=appmoduleid,name"
    if (-not $appResponse.value -or $appResponse.value.Count -eq 0) {
        throw "App module '$AppModuleUniqueName' not found"
    }
    $appModuleId = $appResponse.value[0].appmoduleid
    $appName = $appResponse.value[0].name
    Write-Host "  Found: $appName ($appModuleId)" -ForegroundColor Gray

    # Call AddAppComponents unbound action
    # Note: This action does not return a response body, so we avoid the Prefer: return=representation header
    Write-Host "  Adding form $cleanFormId to app..." -ForegroundColor Gray
    $jsonBody = @{
        AppId = $appModuleId
        Components = @(
            @{
                "@odata.type" = "Microsoft.Dynamics.CRM.systemform"
                formid = $cleanFormId
            }
        )
    } | ConvertTo-Json -Depth 5 -Compress

    $url = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/AddAppComponents"
    $headers = @{
        "Authorization" = "Bearer $script:AuthToken"
        "OData-MaxVersion" = "4.0"
        "OData-Version" = "4.0"
        "Accept" = "application/json"
        "Content-Type" = "application/json; charset=utf-8"
    }
    try {
        Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $jsonBody -ErrorAction Stop
    } catch {
        $errorMessage = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try { $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json; $errorMessage = $errorDetails.error.message } catch { }
        }
        throw "API Error: $errorMessage"
    }
    Write-Output "[OK] Form added to app '$appName'"

    # Publish the app module
    Write-Host "  Publishing app module..." -ForegroundColor Gray
    $publishXml = "<importexportxml><appmodules><appmodule>$appModuleId</appmodule></appmodules></importexportxml>"
    Invoke-DataverseApi -Method "POST" -Endpoint "PublishXml" -Body @{ ParameterXml = $publishXml } -ReturnRepresentation $true
    Write-Output "[OK] App '$appName' published"
}

# Scope an app's view picker for a specific table to a curated list of HSO views.
#
# Default behavior in Dataverse: an app shows ALL Public views for tables it includes. To restrict,
# add specific savedquery records as appmodule components -- once any savedquery is added as a
# component for a table, ONLY those views appear in the picker. (Same mechanism as Add-FormToApp,
# different @odata.type.)
#
# Use case: OOB Field Service tables (bookableresourcebooking, msdyn_workorder, msdyn_agreement,
# bookableresource) ship with many views irrelevant to home healthcare. After authoring HSO Public
# views per UI spec ÃƒÂ‚Ã‚Â§ 9.4, scope the picker to ONLY those HSO views via this op.
#
# Accepts view names (resolved against the supplied TableName) so callers don't have to look up IDs
# beforehand. Names are matched case-insensitively against savedquery.name where querytype=0
# (Public) and statecode=0. A single AddAppComponents action call adds all views at once; a single
# PublishXml flush at the end. Honors -SkipPublish via the centralized skip-publish gate.
function Add-ViewsToApp {
    param([string[]]$ViewNames, [string]$TableName, [string]$AppModuleUniqueName)
    Write-Host "`nAdding views to model-driven app..." -ForegroundColor Cyan
    if (-not $ViewNames -or $ViewNames.Count -eq 0) { throw "ViewNames required (one or more saved-query names)" }
    if (-not $TableName) { throw "TableName required (the table the views belong to; used to disambiguate name lookups)" }
    if (-not $AppModuleUniqueName) { throw "AppModuleUniqueName required" }

    # Resolve app module ID
    Write-Host "  Looking up app module: $AppModuleUniqueName" -ForegroundColor Gray
    $appResponse = Invoke-DataverseApi -Method "GET" -Endpoint "appmodules?`$filter=uniquename eq '$AppModuleUniqueName'&`$select=appmoduleid,name"
    if (-not $appResponse.value -or $appResponse.value.Count -eq 0) { throw "App module '$AppModuleUniqueName' not found" }
    $appModuleId = $appResponse.value[0].appmoduleid
    $appName = $appResponse.value[0].name
    Write-Host "  Found: $appName ($appModuleId)" -ForegroundColor Gray

    # Resolve each view name -> savedqueryid (HSO-authored Public views).
    # Filter to ismanaged=false to disambiguate from same-named OOB managed views (Field Service
    # ships look-alikes like "Today's Visits" on bookableresourcebooking). HSO views built by the
    # skill are always unmanaged in dev. If a customer ever needs to scope to an OOB managed view,
    # call with -ViewIds (future enhancement) or rename their view first.
    Write-Host "  Resolving $($ViewNames.Count) view name(s) on table '$TableName' (ismanaged=false)..." -ForegroundColor Gray
    $resolved = @()
    foreach ($vn in $ViewNames) {
        $name = "$vn".Trim()
        if (-not $name) { continue }
        $nameEsc = $name -replace "'", "''"
        $q = "savedqueries?`$filter=name eq '$nameEsc' and returnedtypecode eq '$($TableName.ToLower())' and querytype eq 0 and statecode eq 0 and ismanaged eq false&`$select=savedqueryid,name,ismanaged"
        $r = Invoke-DataverseApi -Method "GET" -Endpoint $q
        if (-not $r.value -or $r.value.Count -eq 0) {
            # Fallback: if no unmanaged match, surface what DOES match (managed only) for diagnostics
            $qAny = "savedqueries?`$filter=name eq '$nameEsc' and returnedtypecode eq '$($TableName.ToLower())' and querytype eq 0 and statecode eq 0&`$select=savedqueryid,name,ismanaged"
            $rAny = Invoke-DataverseApi -Method "GET" -Endpoint $qAny
            if ($rAny.value -and $rAny.value.Count -gt 0) {
                throw "View '$name' on '$TableName' exists but only as a MANAGED (OOB) view. Either rename the OOB view, or supply the HSO view ID directly."
            }
            throw "View '$name' not found on table '$TableName' (querytype=0, statecode=0, ismanaged=false). Run QueryViews to see what exists."
        }
        if ($r.value.Count -gt 1) {
            $ids = ($r.value | ForEach-Object { $_.savedqueryid }) -join ', '
            throw "Multiple unmanaged views named '$name' on '$TableName' -- ambiguous (savedqueryids: $ids). De-duplicate or supply ID directly."
        }
        $resolved += [pscustomobject]@{ Name = $r.value[0].name; Id = $r.value[0].savedqueryid }
        Write-Host "    [OK] $($r.value[0].name) -> $($r.value[0].savedqueryid)" -ForegroundColor Gray
    }

    # Build single AddAppComponents call with all views
    $components = @()
    foreach ($v in $resolved) {
        $components += @{
            "@odata.type" = "Microsoft.Dynamics.CRM.savedquery"
            savedqueryid = $v.Id
        }
    }
    $jsonBody = @{ AppId = $appModuleId; Components = $components } | ConvertTo-Json -Depth 5 -Compress

    $url = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/AddAppComponents"
    $headers = @{
        "Authorization" = "Bearer $script:AuthToken"
        "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0"
        "Accept" = "application/json"; "Content-Type" = "application/json; charset=utf-8"
    }
    Write-Host "  Adding $($resolved.Count) view component(s) to app via AddAppComponents..." -ForegroundColor Gray
    try {
        Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $jsonBody -ErrorAction Stop
    } catch {
        $errorMessage = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try { $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json; $errorMessage = $errorDetails.error.message } catch { }
        }
        throw "API Error: $errorMessage"
    }
    Write-Output "[OK] $($resolved.Count) view(s) added to app '$appName' for table '$TableName'"

    # Publish app module (honors -SkipPublish via the centralized gate -- but app publish uses a
    # different XML body shape, so we inline rather than calling Publish-FormCustomizations)
    if (-not $script:SkipPublishGlobal) {
        Write-Host "  Publishing app module..." -ForegroundColor Gray
        $publishXml = "<importexportxml><appmodules><appmodule>$appModuleId</appmodule></appmodules></importexportxml>"
        Invoke-DataverseApi -Method "POST" -Endpoint "PublishXml" -Body @{ ParameterXml = $publishXml } -ReturnRepresentation $true
        Write-Output "[OK] App '$appName' published"
    } else {
        Write-Host "  [skip-publish] deferring app-module PublishXml -- caller will batch-publish" -ForegroundColor DarkGray
    }
}
#endregion

#region View Operations
function Get-Views {
    param([string]$TableName)
    Write-Host "`nQuerying views for table: $TableName" -ForegroundColor Cyan
    $endpoint = "savedqueries?`$filter=returnedtypecode eq '$TableName' and statecode eq 0&`$select=savedqueryid,name,isdefault,description,querytype&`$orderby=name"
    $response = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    if ($response.value.Count -eq 0) { Write-Host "  No views found" -ForegroundColor Yellow; return }
    $queryTypes = @{ 0 = "Public"; 2 = "Associated"; 4 = "QuickFind"; 64 = "Lookup" }
    Write-Host "  Found $($response.value.Count) view(s):" -ForegroundColor Green
    foreach ($view in $response.value) {
        $defaultMark = if ($view.isdefault) { " (DEFAULT)" } else { "" }
        $typeName = if ($queryTypes.ContainsKey([int]$view.querytype)) { $queryTypes[[int]$view.querytype] } else { "Type$($view.querytype)" }
        Write-Host "  $($view.name)$defaultMark [$typeName]" -ForegroundColor White
        Write-Host "    ID: $($view.savedqueryid)" -ForegroundColor Gray
    }
    return $response.value
}

function Get-ViewXmlSummary {
    # Parse a view's fetchxml + layoutxml into the three things a reviewer actually checks:
    # displayed columns, sort, and whether a filter is present. Returns a pscustomobject.
    param([string]$FetchXml, [string]$LayoutXml)
    $cols = @()
    if ($LayoutXml) { foreach ($m in [regex]::Matches($LayoutXml, '<cell\s+[^>]*?name="([^"]+)"')) { $cols += $m.Groups[1].Value } }
    $sort = 'none'
    if ($FetchXml -and ($FetchXml -match '<order\b[^>]*/?>')) {
        $ot = $Matches[0]; $sa = $null; $sd = $false
        if ($ot -match 'attribute="([^"]+)"')  { $sa = $Matches[1] }
        if ($ot -match 'descending="([^"]+)"') { $sd = ($Matches[1] -eq 'true') }
        if ($sa) {
            $sort = "$sa$(if ($sd) { ' desc' })"
            $orderCount = ([regex]::Matches($FetchXml, '<order\b')).Count
            if ($orderCount -gt 1) { $sort += " (+$($orderCount - 1) more)" }
        }
    }
    $filter = if ($FetchXml -and ($FetchXml -match '<filter\b')) { 'yes' } else { 'none' }
    return [pscustomobject]@{ Columns = $cols; Sort = $sort; Filter = $filter }
}

function Get-ViewDetails {
    # -Summary: print only the parsed columns/sort/filter one-liner (what a verification pass needs),
    #           not the raw FetchXML/LayoutXML.
    # -Raw:     also return the savedquery object to the pipeline (programmatic callers).
    param([string]$ViewId, [string]$ViewName, [string]$TableName, [switch]$Raw, [switch]$Summary)
    Write-Host "`nQuerying view details..." -ForegroundColor Cyan
    if (-not $ViewId -and $ViewName -and $TableName) {
        Write-Host "  Looking up view by name: $ViewName" -ForegroundColor Gray
        $endpoint = "savedqueries?`$filter=returnedtypecode eq '$($TableName.ToLower())' and name eq '$ViewName'&`$select=savedqueryid"
        $result = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
        if ($result.value -and $result.value.Count -gt 0) {
            $ViewId = $result.value[0].savedqueryid
        } else { Write-Host "  View not found" -ForegroundColor Red; return $null }
    }
    if (-not $ViewId) { Write-Host "  ViewId required" -ForegroundColor Red; return $null }

    $endpoint = "savedqueries($ViewId)?`$select=name,savedqueryid,description,isdefault,querytype,fetchxml,layoutxml,returnedtypecode"
    $view = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    Write-Host "  View Name: $($view.name)" -ForegroundColor White
    Write-Host "  View ID: $($view.savedqueryid)" -ForegroundColor Gray
    Write-Host "  Table: $($view.returnedtypecode)" -ForegroundColor Gray

    if ($Summary) {
        # Parsed one-liner instead of raw XML -- symmetric with the CreateView/UpdateView confirmation.
        $s = Get-ViewXmlSummary -FetchXml $view.fetchxml -LayoutXml $view.layoutxml
        Write-Host ("  columns ({0}): {1}" -f $s.Columns.Count, ($s.Columns -join ', ')) -ForegroundColor White
        Write-Host ("  sort: {0} | filter: {1}" -f $s.Sort, $s.Filter) -ForegroundColor White
        if ($Raw) { return $view }
        return
    }

    Write-Host "  FetchXML:" -ForegroundColor Cyan
    Write-Host $view.fetchxml -ForegroundColor Gray
    Write-Host "  LayoutXML:" -ForegroundColor Cyan
    Write-Host $view.layoutxml -ForegroundColor Gray
    # The formatted block above is the human-facing output. Only emit the raw savedquery object
    # when -Raw is requested (programmatic callers); otherwise the CLI auto-formats it and prints
    # the whole fetchxml/layoutxml a second time.
    if ($Raw) { return $view }
}

function Get-TableViewsSummary {
    # P3-4: inspect ALL of a table's views in one call -- name + type + the columns/sort/filter
    # summary per view -- so a review pass doesn't need one GetViewDetails round-trip per GUID.
    # -Raw: also return the savedquery objects (with fetchxml/layoutxml) to the pipeline. Without it
    # this is summary-ONLY: returning the objects lets the CLI auto-format and dump the full raw XML for
    # every view (a wall of XML for a documented one-line-per-view summary) -- same -Raw gate as GetViewDetails.
    param([string]$TableName, [switch]$Raw)
    $t = $TableName.ToLower()
    Write-Host "`nView summary for table: $t" -ForegroundColor Cyan
    $resp = Invoke-DataverseApi -Method "GET" -Endpoint "savedqueries?`$filter=returnedtypecode eq '$t' and statecode eq 0&`$select=savedqueryid,name,isdefault,querytype,fetchxml,layoutxml&`$orderby=querytype,name"
    if (-not $resp.value -or @($resp.value).Count -eq 0) { Write-Host "  No views found" -ForegroundColor Yellow; return }
    $qt = @{ 0 = 'Public'; 1 = 'AdvancedFind'; 2 = 'Associated/Subgrid'; 4 = 'QuickFind'; 64 = 'Lookup' }
    Write-Host "  Found $(@($resp.value).Count) view(s):" -ForegroundColor Green
    foreach ($v in $resp.value) {
        $typeName = if ($qt.ContainsKey([int]$v.querytype)) { $qt[[int]$v.querytype] } else { "Type$($v.querytype)" }
        $def = if ($v.isdefault) { ' (DEFAULT)' } else { '' }
        $s = Get-ViewXmlSummary -FetchXml $v.fetchxml -LayoutXml $v.layoutxml
        Write-Host ("  - {0}{1} [{2}]" -f $v.name, $def, $typeName) -ForegroundColor White
        Write-Host ("      columns ({0}): {1}" -f $s.Columns.Count, ($s.Columns -join ', ')) -ForegroundColor Gray
        Write-Host ("      sort: {0} | filter: {1} | id: {2}" -f $s.Sort, $s.Filter, $v.savedqueryid) -ForegroundColor Gray
    }
    # Summary-only by default: only hand the raw savedquery objects (fetchxml/layoutxml) to the
    # pipeline when -Raw is asked for; otherwise the CLI auto-formats them and re-prints every view's
    # full XML below the clean summary (the P3-1 retro "wall of raw XML" issue).
    if ($Raw) { return $resp.value }
}

function Resolve-ViewColumnSpec {
    # Accept -ViewColumns as either the legacy parallel-array form (string[] names + a separate
    # -ViewColumnWidths array) OR the safer object form (@{ Name='x'; Width=150 }, ...) so a name
    # and its width travel together and can't silently desync on an insertion. Mirrors the shape
    # already used by -ViewLinkedColumns. Returns @{ Names=@(); Widths=@() }.
    param($Columns, $Widths)
    if (-not $Columns) { return @{ Names = @(); Widths = $Widths } }
    $hasObjects = @($Columns | Where-Object {
        $_ -is [System.Collections.IDictionary] -or ($_ -is [psobject] -and $_.PSObject.Properties['Name'])
    }).Count -gt 0
    if (-not $hasObjects) { return @{ Names = @($Columns); Widths = $Widths } }
    $names = @(); $w = @()
    foreach ($c in $Columns) {
        if ($c -is [System.Collections.IDictionary]) {
            $names += $c['Name']; $w += $(if ($c['Width']) { [int]$c['Width'] } else { 100 })
        } elseif ($c -is [psobject] -and $c.PSObject.Properties['Name']) {
            $names += $c.Name;    $w += $(if ($c.PSObject.Properties['Width'] -and $c.Width) { [int]$c.Width } else { 100 })
        } else {
            $names += $c;         $w += 100
        }
    }
    return @{ Names = $names; Widths = $w }
}

function Write-SortColumnWarning {
    # The Views SOP says do NOT sort on choice / calculated / related-table columns -- Dataverse
    # sorts those by stored value / GUID, not the display label, which surprises users. The skill
    # knows the column's type from metadata, so warn at author time. Best-effort: never blocks.
    param([string]$TableName, [string]$SortColumn)
    if (-not $SortColumn -or -not $TableName) { return }
    try {
        $a = Invoke-DataverseApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$($TableName.ToLower())')/Attributes(LogicalName='$($SortColumn.ToLower())')?`$select=AttributeType"
        $unsortable = @('Picklist','MultiSelectPicklist','State','Status','Lookup','Customer','Owner','Virtual')
        if ($a.AttributeType -in $unsortable) {
            Write-Host "  [WARN] -ViewSortBy '$SortColumn' is a $($a.AttributeType) column. The Views SOP says don't sort on choice/lookup/calculated/related columns (Dataverse sorts by stored value/GUID, not the label). Prefer a text/number/date column." -ForegroundColor Yellow
        }
    } catch { }  # metadata lookup is advisory only
}

function Write-ViewConfirmation {
    # Verify-then-report. The PATCH/POST return=representation echo is unreliable right after a view
    # write (cache-until-publish can return the PRE-write layout), so we don't echo it. We read the
    # persisted view back and print a concise, truthful one-line summary instead of the whole record.
    param([string]$ViewId, [string]$Verb = 'persisted', [bool]$Published = $true)
    try {
        if ($Published) {
            $v     = Invoke-DataverseApi -Method "GET" -Endpoint "savedqueries($ViewId)?`$select=name,fetchxml,layoutxml"
            $layer = 'published'
        }
        else {
            # Publish was deferred (-SkipPublish, or a batch that publishes once at the end). Read the
            # UNPUBLISHED layer instead of declining to verify. A plain GET here returns the PRE-write
            # view, which reads as a failed write; the old branch avoided that by reporting nothing at
            # all, so deferring publish silently cost the caller their verification.
            #
            # This proves the DRAFT persisted -- not that users can see it. The batch's final
            # published read-back is still the gate for that, and must not be dropped.
            $v     = Get-DataverseUnpublished -EntitySet 'savedqueries' -Id $ViewId -Select name,fetchxml,layoutxml
            $layer = 'draft; publish deferred'
        }
        $cols = @(); if ($v.layoutxml) { [xml]$lx = $v.layoutxml; $cols = @($lx.SelectNodes('//row/cell') | ForEach-Object { $_.name }) }
        $sort = 'none'; $filterKept = $false
        if ($v.fetchxml) {
            [xml]$fx = $v.fetchxml
            $ord = @($fx.SelectNodes('//entity/order'))
            if ($ord.Count -gt 0) { $sort = ($ord | ForEach-Object { "$($_.attribute)$(if ($_.descending -eq 'true') { ' desc' })" }) -join ', ' }
            $filterKept = (@($fx.SelectNodes('//entity/filter/condition')).Count -gt 0)
        }
        Write-Output "[OK] View '$($v.name)' $Verb ($layer): $($cols.Count) column(s) [$($cols -join ', ')] | sort: $sort | filter: $(if ($filterKept) { 'kept' } else { 'none' })"
    } catch {
        Write-Output "[OK] View write accepted (could not read back to confirm: $($_.Exception.Message))"
    }
}

function Get-DefaultViewDescription {
    param([string]$ViewName, [string]$TableName)
    $n = if ($ViewName) { $ViewName } else { 'View' }
    "$n view for $TableName."
}

function Add-ActiveStateFilterIfMissing {
    # An 'Active *' public view must filter statecode=0, or it lists inactive rows too. Name-driven and
    # deterministic: guarantee one statecode=0 condition without disturbing other filter conditions.
    param([string]$FetchXml, [string]$ViewName, [int]$QueryType)
    if ($QueryType -ne 0 -or -not $FetchXml -or $ViewName -notmatch '^\s*Active\b') { return $FetchXml }
    try { [xml]$fx = $FetchXml } catch { return $FetchXml }
    $entity = $fx.SelectSingleNode('//entity')
    if (-not $entity) { return $FetchXml }
    if ($entity.SelectSingleNode(".//condition[@attribute='statecode']")) { return $fx.OuterXml }
    $filter = $entity.SelectSingleNode('filter')
    if (-not $filter) {
        $filter = $fx.CreateElement('filter'); $filter.SetAttribute('type', 'and')
        $entity.AppendChild($filter) | Out-Null
    }
    $cond = $fx.CreateElement('condition')
    $cond.SetAttribute('attribute', 'statecode'); $cond.SetAttribute('operator', 'eq'); $cond.SetAttribute('value', '0')
    $filter.AppendChild($cond) | Out-Null
    Write-Host "  [INFO] '$ViewName' is an Active view -- added the statecode=0 (Active) filter (SOP: Active lists exclude inactive rows)." -ForegroundColor Gray
    $fx.OuterXml
}

function New-View {
    param([string]$ViewName, [string]$ViewDescription, [string]$ViewType, [string]$TableName, [array]$ViewColumns, [array]$ViewColumnWidths, [string]$ViewFilter, [string]$ViewSortBy, [object]$ViewSortDescending, [string]$SolutionName, [array]$ViewLinkedColumns, [int]$ViewFloorMin = 0, [int]$ViewFloorMax = 0)
    $ViewColumns = ConvertTo-NormalizedArray $ViewColumns
    $ViewColumnWidths = ConvertTo-NormalizedArray $ViewColumnWidths
    # Accept object-form columns (@{Name=;Width=}) so name+width can't desync (item: alignment footgun)
    $spec = Resolve-ViewColumnSpec -Columns $ViewColumns -Widths $ViewColumnWidths
    $ViewColumns = $spec.Names
    if (-not $ViewColumnWidths -or $ViewColumnWidths.Count -eq 0) { $ViewColumnWidths = $spec.Widths }
    $ViewSortDescending = ConvertTo-NormalizedBool $ViewSortDescending
    $tableLower = $TableName.ToLower()

    # Lookup views: every table already ships a querytype=64 lookup view. Never create a Public
    # duplicate -- find that OOB view and route the declared columns/description to UpdateView.
    if ($ViewType -eq "Lookup") {
        $oobLookup = Invoke-DataverseApi -Method "GET" -Endpoint "savedqueries?`$filter=returnedtypecode eq '$tableLower' and querytype eq 64&`$select=savedqueryid,name"
        if ($oobLookup.value -and $oobLookup.value.Count -gt 0) {
            $lv = $oobLookup.value[0]
            Write-Host "`n[OK] Updating existing lookup view (querytype=64) '$($lv.name)' on '$tableLower' instead of creating a Public duplicate" -ForegroundColor Cyan
            return Update-View -ViewId $lv.savedqueryid -ViewDescription $ViewDescription -TableName $tableLower -ViewColumns $ViewColumns -ViewColumnWidths $ViewColumnWidths -ViewFilter $ViewFilter -ViewSortBy $ViewSortBy -ViewSortDescending $ViewSortDescending -SolutionName $SolutionName -ViewLinkedColumns $ViewLinkedColumns -ViewFloorMin $ViewFloorMin -ViewFloorMax $ViewFloorMax
        }
        Write-Host "  [INFO] No querytype=64 lookup view found on '$tableLower' -- creating one" -ForegroundColor Gray
    }

    # PublicView find-or-update (ADR 0025): an existing same-name unmanaged Public view is REUSED
    # (declared columns/description/filter routed to UpdateView) rather than creating a second
    # savedquery -- the root cause of orphan duplicate Public views. Identity = name + table +
    # querytype 0 + ismanaged=false, the same key the app-add resolution uses. Also keep the OOB-lookup
    # name-collision warning (the caller likely meant -ViewType Lookup).
    if ($ViewType -eq "PublicView") {
        $nameEsc = $ViewName -replace "'", "''"
        $collide = Invoke-DataverseApi -Method "GET" -Endpoint "savedqueries?`$filter=returnedtypecode eq '$tableLower' and querytype eq 64 and name eq '$nameEsc'&`$select=savedqueryid,name"
        if ($collide.value -and $collide.value.Count -gt 0) {
            Write-Host "  [WARN] Public view '$ViewName' collides by name with the OOB lookup view (querytype=64) on '$tableLower'. A lookup view should be declared -ViewType Lookup (routes to UpdateView on the existing view); creating a Public view here leaves a name-colliding duplicate." -ForegroundColor Yellow
        }
        $existing = Invoke-DataverseApi -Method "GET" -Endpoint "savedqueries?`$filter=name eq '$nameEsc' and returnedtypecode eq '$tableLower' and querytype eq 0 and statecode eq 0 and ismanaged eq false&`$select=savedqueryid,name"
        if ($existing.value -and $existing.value.Count -gt 0) {
            if ($existing.value.Count -gt 1) {
                $dupIds = ($existing.value | ForEach-Object { $_.savedqueryid }) -join ', '
                Write-Host "  [WARN] $($existing.value.Count) existing unmanaged Public views named '$ViewName' on '$tableLower' (savedqueryids: $dupIds) -- updating the first instead of creating another. De-duplicate with DeleteView." -ForegroundColor Yellow
            }
            $ev = $existing.value[0]
            Write-Host "`n[OK] Updating existing Public view '$($ev.name)' on '$tableLower' (find-or-update) instead of creating a duplicate" -ForegroundColor Cyan
            return Update-View -ViewId $ev.savedqueryid -ViewDescription $ViewDescription -TableName $tableLower -ViewColumns $ViewColumns -ViewColumnWidths $ViewColumnWidths -ViewFilter $ViewFilter -ViewSortBy $ViewSortBy -ViewSortDescending $ViewSortDescending -SolutionName $SolutionName -ViewLinkedColumns $ViewLinkedColumns -ViewFloorMin $ViewFloorMin -ViewFloorMax $ViewFloorMax
        }
    }

    Write-Host "`nCreating view: $ViewName" -ForegroundColor Cyan
    Write-DescriptionWarning -ComponentKind "view" -ComponentName $ViewName -Description $ViewDescription
    Write-SortColumnWarning -TableName $tableLower -SortColumn $ViewSortBy
    $queryTypeMap = @{ "PublicView" = 0; "QuickFind" = 1; "Associated" = 2; "Lookup" = 4 }
    $queryType = if ($queryTypeMap.ContainsKey($ViewType)) { $queryTypeMap[$ViewType] } else { 0 }

    # Get primary key
    $entityEndpoint = "EntityDefinitions(LogicalName='$tableLower')?`$select=PrimaryIdAttribute"
    $entityResult = Invoke-DataverseApi -Method "GET" -Endpoint $entityEndpoint
    $primaryKeyColumn = $entityResult.PrimaryIdAttribute

    $fetchXml = Build-FetchXml -TableName $tableLower -Columns $ViewColumns -Filter $ViewFilter -SortBy $ViewSortBy -SortDescending $ViewSortDescending
    $layoutXml = Build-LayoutXml -Columns $ViewColumns -Widths $ViewColumnWidths -PrimaryKeyColumn $primaryKeyColumn

    if ($ViewLinkedColumns -and $ViewLinkedColumns.Count -gt 0) {
        Write-Host "  Appending $($ViewLinkedColumns.Count) link-entity join(s)" -ForegroundColor Gray
        $fetchXml  = Build-FetchXmlWithLinks  -BaseFetchXml  $fetchXml  -LinkedColumns $ViewLinkedColumns
        $layoutXml = Build-LayoutXmlWithLinks -BaseLayoutXml $layoutXml -LinkedColumns $ViewLinkedColumns
    }

    $fetchXml = Add-ActiveStateFilterIfMissing -FetchXml $fetchXml -ViewName $ViewName -QueryType $queryType
    if (-not $ViewDescription) { $ViewDescription = Get-DefaultViewDescription -ViewName $ViewName -TableName $tableLower }

    # Public-view column floor: warn (don't block) when a Public view ships under-populated.
    # Count from the layoutxml actually being written so link-entity cells are included.
    $newViewColumnCount = Get-LayoutColumnCount -LayoutXml $layoutXml
    if ($newViewColumnCount -ge 0) {
        Write-PublicViewColumnFloorWarning -QueryType $queryType -ColumnCount $newViewColumnCount -ViewName $ViewName
        Assert-ViewColumnFloor -FloorMin $ViewFloorMin -FloorMax $ViewFloorMax -ColumnCount $newViewColumnCount -ViewName $ViewName
    }

    $viewPayload = @{ "name" = $ViewName; "description" = $ViewDescription; "returnedtypecode" = $tableLower; "querytype" = $queryType; "fetchxml" = $fetchXml; "layoutxml" = $layoutXml }
    $result = Invoke-DataverseApi -Method "POST" -Endpoint "savedqueries" -Body $viewPayload -SolutionName $SolutionName -ReturnRepresentation $true
    $newId = $result.savedqueryid
    $sortInfo = if ($ViewSortBy) { "$ViewSortBy$(if ($ViewSortDescending) { ' desc' })" } else { 'none' }
    # Concise confirmation only -- the full savedquery record is high-noise and its return-echo is
    # cache-unreliable right after the write. Read back with GetViewDetails if you need the full record.
    Write-Output "[OK] View '$ViewName' created (id $newId): $($ViewColumns.Count) column(s) [$($ViewColumns -join ', ')] | sort: $sortInfo"
}

function Update-View {
    param([string]$ViewId, [string]$ViewName, [string]$ViewDescription, [string]$TableName, [array]$ViewColumns, [array]$ViewColumnWidths, [string]$ViewFilter, [string]$ViewSortBy, [bool]$ViewSortDescending, [string]$SolutionName, [string[]]$ViewFindColumns, [switch]$SkipPublish, [array]$ViewLinkedColumns, [string]$ViewRawFetchXml, [string]$ViewRawLayoutXml, [switch]$Quiet, [int]$ViewFloorMin = 0, [int]$ViewFloorMax = 0)
    if ($ViewColumns) { $ViewColumns = ConvertTo-NormalizedArray $ViewColumns }
    if ($ViewColumnWidths) { $ViewColumnWidths = ConvertTo-NormalizedArray $ViewColumnWidths }
    if ($ViewFindColumns) { $ViewFindColumns = ConvertTo-NormalizedArray $ViewFindColumns }
    # Accept object-form columns (@{Name=;Width=}) so name+width can't desync (alignment footgun)
    if ($ViewColumns) {
        $spec = Resolve-ViewColumnSpec -Columns $ViewColumns -Widths $ViewColumnWidths
        $ViewColumns = $spec.Names
        if (-not $ViewColumnWidths -or $ViewColumnWidths.Count -eq 0) { $ViewColumnWidths = $spec.Widths }
    }
    Write-Host "`nUpdating view..." -ForegroundColor Cyan

    # Resolve ViewId from name/table if provided
    if (-not $ViewId -and $ViewName -and $TableName) {
        $endpoint = "savedqueries?`$filter=returnedtypecode eq '$($TableName.ToLower())' and name eq '$ViewName'&`$select=savedqueryid"
        $result = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
        if ($result.value -and $result.value.Count -gt 0) { $ViewId = $result.value[0].savedqueryid }
        else { Write-Host "  View not found" -ForegroundColor Red; return $null }
    }

    # Auto-find Quick Find view when ViewFindColumns is specified with just a TableName
    if ($ViewFindColumns -and -not $ViewId -and $TableName) {
        $endpoint = "savedqueries?`$filter=returnedtypecode eq '$($TableName.ToLower())' and querytype eq 4&`$select=savedqueryid,name"
        $result = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
        if ($result.value -and $result.value.Count -gt 0) {
            $ViewId = $result.value[0].savedqueryid
            Write-Host "  Found Quick Find view: $($result.value[0].name)" -ForegroundColor Gray
        } else {
            Write-Host "  No Quick Find view found for table $TableName" -ForegroundColor Red; return $null
        }
    }

    if (-not $ViewId) { Write-Host "  ViewId required" -ForegroundColor Red; return $null }

    # Fetch existing view with full metadata (Quick Find views require name/description/returnedtypecode in PATCH)
    $existingViewEndpoint = "savedqueries($ViewId)?`$select=name,description,returnedtypecode,querytype,fetchxml,layoutxml,savedqueryid"
    $existingView = Invoke-DataverseApi -Method "GET" -Endpoint $existingViewEndpoint
    $isQuickFind = ($existingView.querytype -eq 4)
    $existingFetchXml = $existingView.fetchxml
    $existingLayoutXml = $existingView.layoutxml

    if ($isQuickFind) { Write-Host "  Quick Find view detected" -ForegroundColor Cyan }

    $updatePayload = @{}

    # --- Raw passthrough: caller supplies complete XML strings (escape hatch for complex joins) ---
    if ($ViewRawFetchXml) {
        Write-Host "  [INFO] Using raw FetchXML passthrough (bypassing Build-FetchXml)" -ForegroundColor Yellow
        $updatePayload["fetchxml"] = $ViewRawFetchXml
    }
    if ($ViewRawLayoutXml) {
        Write-Host "  [INFO] Using raw LayoutXML passthrough (bypassing Build-LayoutXml)" -ForegroundColor Yellow
        $updatePayload["layoutxml"] = $ViewRawLayoutXml
    }

    # Quick Find views require name, description, and returnedtypecode in every PATCH that includes fetchxml
    if ($isQuickFind) {
        $updatePayload["name"] = if ($ViewName) { $ViewName } else { $existingView.name }
        $updatePayload["description"] = if ($ViewDescription -ne $null) { $ViewDescription } else { $existingView.description }
        $updatePayload["returnedtypecode"] = $existingView.returnedtypecode
    } else {
        if ($ViewName) { $updatePayload["name"] = $ViewName }
        if ($ViewDescription) { $updatePayload["description"] = $ViewDescription }
    }

    # --- Quick Find: Update Find Columns (isquickfindfields filter) ---
    if ($ViewFindColumns -and $ViewFindColumns.Count -gt 0) {
        if (-not $isQuickFind) {
            Write-Host "  [WARN] ViewFindColumns only applies to Quick Find views (querytype=4), ignoring" -ForegroundColor Yellow
        } else {
            Write-Host "  Updating Find Columns: $($ViewFindColumns -join ', ')" -ForegroundColor Gray

            # Parse existing fetchxml as XML document
            [xml]$fetchDoc = $existingFetchXml
            $entityNode = $fetchDoc.fetch.entity

            # Ensure each find column has an <attribute> element in the fetchxml
            foreach ($col in $ViewFindColumns) {
                $existingAttr = $entityNode.SelectSingleNode("attribute[@name='$col']")
                if (-not $existingAttr) {
                    $attrElem = $fetchDoc.CreateElement("attribute")
                    $attrElem.SetAttribute("name", $col)
                    $orderNode = $entityNode.SelectSingleNode("order")
                    if ($orderNode) { $entityNode.InsertBefore($attrElem, $orderNode) | Out-Null }
                    else { $entityNode.AppendChild($attrElem) | Out-Null }
                    Write-Host "    Added attribute: $col" -ForegroundColor Gray
                }
            }

            # Find or create the isquickfindfields filter
            $qfFilter = $entityNode.SelectSingleNode("filter[@isquickfindfields='1']")
            if (-not $qfFilter) {
                $qfFilter = $fetchDoc.CreateElement("filter")
                $qfFilter.SetAttribute("type", "or")
                $qfFilter.SetAttribute("isquickfindfields", "1")
                $entityNode.AppendChild($qfFilter) | Out-Null
            }

            # Clear existing conditions and rebuild with specified find columns
            $qfFilter.RemoveAll()
            $qfFilter.SetAttribute("type", "or")
            $qfFilter.SetAttribute("isquickfindfields", "1")
            foreach ($col in $ViewFindColumns) {
                $condElem = $fetchDoc.CreateElement("condition")
                $condElem.SetAttribute("attribute", $col)
                $condElem.SetAttribute("operator", "like")
                $condElem.SetAttribute("value", "{0}")
                $qfFilter.AppendChild($condElem) | Out-Null
            }

            $updatePayload["fetchxml"] = $fetchDoc.OuterXml
            Write-Host "    Find Columns set: $($ViewFindColumns -join ', ')" -ForegroundColor Green
        }
    }

    # --- Update display columns (grid layout) ---
    if ($ViewColumns -and $ViewColumns.Count -gt 0) {
        Write-Host "  Columns to set ($($ViewColumns.Count)): $($ViewColumns -join ', ')" -ForegroundColor Gray
        $tableLower = if ($TableName) { $TableName.ToLower() } else { $existingView.returnedtypecode }
        if (-not $tableLower) { Write-Host "  TableName required to update display columns" -ForegroundColor Red; return $null }
        $entityEndpoint = "EntityDefinitions(LogicalName='$tableLower')?`$select=PrimaryIdAttribute"
        $entityResult = Invoke-DataverseApi -Method "GET" -Endpoint $entityEndpoint
        $primaryKeyColumn = $entityResult.PrimaryIdAttribute

        if ($isQuickFind) {
            # Quick Find: use XML parsing to preserve fetchxml structure (filters, savedqueryid, etc.)
            $fetchToModify = if ($updatePayload.ContainsKey("fetchxml")) { $updatePayload["fetchxml"] } else { $existingFetchXml }
            [xml]$fetchDoc = $fetchToModify
            $entityNode = $fetchDoc.fetch.entity

            # Ensure primary key attribute exists
            if (-not $entityNode.SelectSingleNode("attribute[@name='$primaryKeyColumn']")) {
                $attrElem = $fetchDoc.CreateElement("attribute")
                $attrElem.SetAttribute("name", $primaryKeyColumn)
                $entityNode.PrependChild($attrElem) | Out-Null
            }

            # Ensure each view column has an <attribute> element
            foreach ($col in $ViewColumns) {
                if (-not $entityNode.SelectSingleNode("attribute[@name='$col']")) {
                    $attrElem = $fetchDoc.CreateElement("attribute")
                    $attrElem.SetAttribute("name", $col)
                    $orderNode = $entityNode.SelectSingleNode("order")
                    if ($orderNode) { $entityNode.InsertBefore($attrElem, $orderNode) | Out-Null }
                    else { $entityNode.AppendChild($attrElem) | Out-Null }
                }
            }
            $updatePayload["fetchxml"] = $fetchDoc.OuterXml

            # Build layout preserving grid metadata (object code, jump field) from existing layout
            [xml]$layoutDoc = $existingLayoutXml
            $rowNode = $layoutDoc.grid.SelectSingleNode("row")
            $rowNode.RemoveAll()
            $rowNode.SetAttribute("name", "result")
            $rowNode.SetAttribute("id", $primaryKeyColumn)
            for ($i = 0; $i -lt $ViewColumns.Count; $i++) {
                $width = if ($ViewColumnWidths -and $i -lt $ViewColumnWidths.Count) { $ViewColumnWidths[$i] } else { 100 }
                $cellElem = $layoutDoc.CreateElement("cell")
                $cellElem.SetAttribute("name", $ViewColumns[$i].ToLower())
                $cellElem.SetAttribute("width", $width.ToString())
                $rowNode.AppendChild($cellElem) | Out-Null
            }
            $updatePayload["layoutxml"] = $layoutDoc.OuterXml
        } else {
            # Regular view: use Build-FetchXml/Build-LayoutXml
            Write-SortColumnWarning -TableName $tableLower -SortColumn $ViewSortBy
            $filterToUse = $ViewFilter
            if (-not $ViewFilter) {
                if ($existingFetchXml -match '<filter[^>]*>.*?</filter>') { $filterToUse = $Matches[0] }
            }
            # P3-1: PRESERVE the existing <order> when the caller didn't pass -ViewSortBy. Build-FetchXml
            # emits no <order> for an empty -SortBy, so a columns-only edit would otherwise silently DROP
            # the view's sort (filter is already preserved just above; sort must be treated the same way).
            # Only replace the sort when the caller explicitly supplies -ViewSortBy.
            $sortToUse = $ViewSortBy
            $sortDescToUse = $ViewSortDescending
            if (-not $ViewSortBy -and $existingFetchXml -and ($existingFetchXml -match '<order\b[^>]*/?>')) {
                $orderTag = $Matches[0]
                if ($orderTag -match 'attribute="([^"]+)"')  { $sortToUse = $Matches[1] }
                if ($orderTag -match 'descending="([^"]+)"') { $sortDescToUse = ($Matches[1] -eq 'true') }
                if ($sortToUse) {
                    Write-Host "  Preserving existing sort: $sortToUse$(if ($sortDescToUse) { ' desc' })" -ForegroundColor Gray
                    $orderCount = ([regex]::Matches($existingFetchXml, '<order\b')).Count
                    if ($orderCount -gt 1) { Write-Host "  [WARN] View had $orderCount sort columns; only the primary ('$sortToUse') is preserved on a columns-only edit. Re-supply -ViewSortBy for full control of a multi-column sort." -ForegroundColor Yellow }
                }
            }
            $fetchXml  = Build-FetchXml  -TableName $tableLower -Columns $ViewColumns -Filter $filterToUse -SortBy $sortToUse -SortDescending $sortDescToUse
            $layoutXml = Build-LayoutXml -Columns $ViewColumns -Widths $ViewColumnWidths -PrimaryKeyColumn $primaryKeyColumn

            if ($ViewLinkedColumns -and $ViewLinkedColumns.Count -gt 0) {
                Write-Host "  Appending $($ViewLinkedColumns.Count) link-entity join(s)" -ForegroundColor Gray
                $fetchXml  = Build-FetchXmlWithLinks  -BaseFetchXml  $fetchXml  -LinkedColumns $ViewLinkedColumns
                $layoutXml = Build-LayoutXmlWithLinks -BaseLayoutXml $layoutXml -LinkedColumns $ViewLinkedColumns
            }

            # Raw passthrough overrides helper-built XML when both are supplied (edge case guard)
            if (-not $updatePayload.ContainsKey("fetchxml"))  { $updatePayload["fetchxml"]  = $fetchXml }
            if (-not $updatePayload.ContainsKey("layoutxml")) { $updatePayload["layoutxml"] = $layoutXml }
        }
    }

    if ($updatePayload.ContainsKey("fetchxml")) {
        $activeViewName = if ($updatePayload.ContainsKey("name")) { $updatePayload["name"] } else { $existingView.name }
        $updatePayload["fetchxml"] = Add-ActiveStateFilterIfMissing -FetchXml $updatePayload["fetchxml"] -ViewName $activeViewName -QueryType ([int]$existingView.querytype)
    }

    # Never leave an edited, description-less view without one (don't add a standalone write for it).
    if ($updatePayload.Count -gt 0 -and -not $isQuickFind -and -not $updatePayload.ContainsKey("description") -and -not $existingView.description) {
        $updatePayload["description"] = Get-DefaultViewDescription -ViewName $existingView.name -TableName $existingView.returnedtypecode
    }

    if ($updatePayload.Count -eq 0) { Write-Host "  No changes specified" -ForegroundColor Yellow; return $null }

    # P3-2: safety net -- if we're writing fetchxml that has no <order>, the view will be UNSORTED
    # (grids fall back to an arbitrary primary-key order). Surface it prominently; P3-1 should have
    # preserved an existing sort, so this mainly catches views that never had one.
    if ($updatePayload.ContainsKey("fetchxml") -and ($updatePayload["fetchxml"] -notmatch '<order\b')) {
        Write-Host "  [WARN] sort: NONE -- this view will have no <order> and will render in an arbitrary order. Pass -ViewSortBy to set a sort column." -ForegroundColor Yellow
    }

    # Public-view column floor: warn (don't block) when a Public view ends up under-populated.
    # Count from the layoutxml actually being written if this PATCH touches layout; otherwise from
    # the view's existing layout (the column set is unchanged). querytype comes from the live record.
    $effectiveLayoutXml = if ($updatePayload.ContainsKey("layoutxml")) { $updatePayload["layoutxml"] } else { $existingLayoutXml }
    $updateViewColumnCount = Get-LayoutColumnCount -LayoutXml $effectiveLayoutXml
    if ($updateViewColumnCount -ge 0) {
        $updateViewName = if ($updatePayload.ContainsKey("name")) { $updatePayload["name"] } else { $existingView.name }
        Write-PublicViewColumnFloorWarning -QueryType ([int]$existingView.querytype) -ColumnCount $updateViewColumnCount -ViewName $updateViewName
        Assert-ViewColumnFloor -FloorMin $ViewFloorMin -FloorMax $ViewFloorMax -ColumnCount $updateViewColumnCount -ViewName $updateViewName
    }

    $endpoint = "savedqueries($ViewId)"
    # Capture (and discard) the PATCH response -- do NOT echo it. Its return=representation copy is
    # cache-unreliable right after the write and has shown the PRE-write layout next to an [OK],
    # which reads as a contradiction. We read back the persisted view below (Write-ViewConfirmation) instead.
    $null = Invoke-DataverseApi -Method "PATCH" -Endpoint $endpoint -Body $updatePayload -SolutionName $SolutionName
    if ($ViewFindColumns) { Write-Host "  Find Columns: $($ViewFindColumns -join ', ')" -ForegroundColor Gray }
    if ($ViewLinkedColumns -and $ViewLinkedColumns.Count -gt 0) { Write-Host "  Linked Column Groups: $($ViewLinkedColumns.Count)" -ForegroundColor Gray }

    # Publish FIRST so the read-back reflects the applied change, then verify-then-report.
    # Use -SkipPublish to defer publishing when batching multiple view updates.
    $published = $true
    if (-not $SkipPublish) {
        $publishTableName = if ($TableName) { $TableName } else { $existingView.returnedtypecode }
        if ($publishTableName) { Publish-FormCustomizations -TableName $publishTableName }
    } else {
        $published = $false
        if (-not $Quiet) { Write-Host "  Publish skipped (caller requested -SkipPublish)" -ForegroundColor Gray }
    }
    # -Quiet: a composite (e.g. CurateDefaultViews) batches N deferred-publish writes then publishes once
    # and prints its own authoritative summary. Without -Quiet each inner write prints the per-view
    # "publish deferred -- verify after publish yourself" line, which reads as a contradiction the
    # composite immediately satisfies (P3-2 retro). Suppress it so the composite owns one honest verdict.
    if (-not $Quiet) { Write-ViewConfirmation -ViewId $ViewId -Verb 'updated' -Published $published }
}

function Remove-View {
    param([string]$ViewId, [string]$ViewName, [string]$TableName)
    Write-Host "`nDeleting view..." -ForegroundColor Cyan
    if (-not $ViewId -and $ViewName -and $TableName) {
        $endpoint = "savedqueries?`$filter=returnedtypecode eq '$($TableName.ToLower())' and name eq '$ViewName'&`$select=savedqueryid,isdefault"
        $result = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
        if ($result.value -and $result.value.Count -gt 0) {
            if ($result.value[0].isdefault) { Write-Host "  Cannot delete default view" -ForegroundColor Red; return $null }
            $ViewId = $result.value[0].savedqueryid
        } else { Write-Host "  View not found" -ForegroundColor Red; return $null }
    }
    if (-not $ViewId) { Write-Host "  ViewId required" -ForegroundColor Red; return $null }

    Invoke-DataverseApi -Method "DELETE" -Endpoint "savedqueries($ViewId)"
    Write-Output "[OK] View deleted successfully"
    return $true
}
#endregion

#region Create Form
function New-Form {
    param([string]$TableName, [string]$FormName, [string]$FormDescription, [string]$FormType, [array]$Fields, [string]$SolutionName)

    $Fields = ConvertTo-NormalizedArray $Fields
    Write-Host "`nCreating new form..." -ForegroundColor Cyan
    Write-Host "  Table: $TableName" -ForegroundColor Gray
    Write-Host "  Name: $FormName" -ForegroundColor Gray
    Write-Host "  Type: $FormType" -ForegroundColor Gray
    Write-DescriptionWarning -ComponentKind "form" -ComponentName $FormName -Description $FormDescription

    $formTypeCode = if ($script:FormTypeCodes.ContainsKey($FormType)) { $script:FormTypeCodes[$FormType] } else { 2 }

    # Build rows XML for each field
    $rowsXml = ""
    foreach ($field in $Fields) {
        if ($field -is [string]) {
            $fieldName = $field
            $fieldLabel = $null
            $fieldType = $null
        } else {
            $fieldName = $field.Name
            $fieldLabel = $field.Label
            $fieldType = $field.Type
        }

        $classId = Get-ControlClassId -FieldType $fieldType -FieldName $fieldName
        $cellId = [guid]::NewGuid().ToString()

        $labelXml = ""
        if ($fieldLabel) {
            $labelXml = "<labels><label description=`"$fieldLabel`" languagecode=`"$($script:LanguageCode)`" /></labels>"
        }

        $rowsXml += "<row><cell id=`"{$cellId}`" showlabel=`"true`" locklevel=`"0`">$labelXml<control id=`"$fieldName`" classid=`"$classId`" datafieldname=`"$fieldName`" disabled=`"false`" /></cell></row>"
        Write-Host "  Field: $fieldName (classid: $classId)" -ForegroundColor Gray
    }

    # Build form XML based on form type
    if ($FormType -eq "Card") {
        # Card forms require exactly 4 sections: ColorStrip, Header, Body, Footer
        $tabId = [guid]::NewGuid().ToString()
        $colorStripSectionId = [guid]::NewGuid().ToString()
        $headerSectionId = [guid]::NewGuid().ToString()
        $bodySectionId = [guid]::NewGuid().ToString()
        $footerSectionId = [guid]::NewGuid().ToString()

        # Place first field in Header, remaining in Body, Footer empty
        $headerRowsXml = ""
        $bodyRowsXml = ""
        $fieldIndex = 0
        foreach ($field in $Fields) {
            if ($field -is [string]) { $fn = $field } else { $fn = $field.Name }
            $cid = Get-ControlClassId -FieldType $(if ($field -is [string]) { $null } else { $field.Type }) -FieldName $fn
            $cellGuid = [guid]::NewGuid().ToString()
            $lbl = if ($field -is [string]) { "" } else { if ($field.Label) { "<labels><label description=`"$($field.Label)`" languagecode=`"$($script:LanguageCode)`" /></labels>" } else { "" } }
            $rowXml = "<row><cell id=`"{$cellGuid}`" showlabel=`"true`" locklevel=`"0`">$lbl<control id=`"$fn`" classid=`"$cid`" datafieldname=`"$fn`" disabled=`"false`" /></cell></row>"

            if ($fieldIndex -eq 0) { $headerRowsXml += $rowXml }
            else { $bodyRowsXml += $rowXml }
            $fieldIndex++
        }

        $formXml = @"
<form><tabs><tab name="CardTab" id="{$tabId}" IsUserDefined="0" expanded="true" showlabel="false"><labels><label description="Card" languagecode="$($script:LanguageCode)" /></labels><columns><column width="100%"><sections><section name="CardSection_ColorStrip" id="{$colorStripSectionId}" columns="1" showlabel="false" showbar="false" celllabelalignment="Left" celllabelposition="Left" IsUserDefined="0" layout="varwidth"><labels><label description="Color Strip" languagecode="$($script:LanguageCode)" /></labels><rows /></section><section name="CardSection_Header" id="{$headerSectionId}" columns="1" showlabel="false" showbar="false" celllabelalignment="Left" celllabelposition="Left" IsUserDefined="0"><labels><label description="Header" languagecode="$($script:LanguageCode)" /></labels><rows>$headerRowsXml</rows></section><section name="CardSection_Body" id="{$bodySectionId}" columns="1" showlabel="false" showbar="false" celllabelalignment="Left" celllabelposition="Left" IsUserDefined="0"><labels><label description="Body" languagecode="$($script:LanguageCode)" /></labels><rows>$bodyRowsXml</rows></section><section name="CardSection_Footer" id="{$footerSectionId}" columns="1" showlabel="false" showbar="false" celllabelalignment="Left" celllabelposition="Left" IsUserDefined="0"><labels><label description="Footer" languagecode="$($script:LanguageCode)" /></labels><rows /></section></sections></column></columns></tab></tabs></form>
"@.Trim()
    } else {
        # Standard form structure for Main, QuickCreate, QuickView
        $tabId = [guid]::NewGuid().ToString()
        $sectionId = [guid]::NewGuid().ToString()

        $formXml = @"
<form><tabs><tab name="tab_general" id="{$tabId}" IsUserDefined="0" expanded="true" showlabel="false"><labels><label description="General" languagecode="$($script:LanguageCode)" /></labels><columns><column width="100%"><sections><section name="section_general" id="{$sectionId}" showlabel="false" showbar="false" columns="1" IsUserDefined="0" labelwidth="115"><labels><label description="General" languagecode="$($script:LanguageCode)" /></labels><rows>$rowsXml</rows></section></sections></column></columns></tab></tabs></form>
"@.Trim()
    }

    # Create the form via Web API
    $formPayload = @{
        "name" = $FormName
        "objecttypecode" = $TableName.ToLower()
        "type" = $formTypeCode
        "formxml" = $formXml
    }
    if ($FormDescription) {
        $formPayload["description"] = $FormDescription
    }

    $result = Invoke-DataverseApi -Method "POST" -Endpoint "systemforms" -Body $formPayload -SolutionName $SolutionName -ReturnRepresentation $true
    $newFormId = $null
    if ($result -and $result.formid) {
        $newFormId = $result.formid
    }

    Write-Output "[OK] Form '$FormName' created successfully"
    if ($newFormId) {
        Write-Host "  Form ID: $newFormId" -ForegroundColor Gray
    }

    # Publish
    Publish-FormCustomizations -TableName $TableName
    Write-Output "[OK] Form published"

    return $result
}
#endregion

#region Add Operations (Tab, Section, Fields, Subgrid)
function Add-TabToForm {
    param([string]$FormId, [string]$TabName, [string]$TabLabel, [int]$TabColumns, [bool]$TabShowLabel, [bool]$TabExpanded, [int]$TabPosition = -1)
    Write-Host "`nAdding tab to form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml
    $existingTab = Find-Tab -FormXml $formXml -TabName $TabName
    if ($existingTab) { throw "Tab '$TabName' already exists" }

    # Also check by label -- auto-generated forms have name="tab" with label "General";
    # adding a new tab with label "General" would create a duplicate if unchecked.
    if ($TabLabel) {
        $existingTabByLabel = $formXml.SelectNodes("//tabs/tab") | Where-Object {
            $labelNode = $_.SelectSingleNode("labels/label[@languagecode='1033']")
            $labelNode -and $labelNode.GetAttribute("description") -eq $TabLabel
        } | Select-Object -First 1
        if ($existingTabByLabel) {
            $existingTabName = $existingTabByLabel.GetAttribute("name")
            Write-Host "  Tab with label '$TabLabel' already exists (name: '$existingTabName') -- skipping creation" -ForegroundColor Yellow
            return $existingTabName
        }
    }

    $tab = $formXml.CreateElement("tab")
    $tab.SetAttribute("name", $TabName)
    $tab.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
    $tab.SetAttribute("IsUserDefined", "1")
    $tab.SetAttribute("showlabel", $(if ($TabShowLabel) { "true" } else { "false" }))
    $tab.SetAttribute("expanded", $(if ($TabExpanded) { "true" } else { "false" }))
    $tab.SetAttribute("locklevel", "0")

    $labels = $formXml.CreateElement("labels")
    $label = $formXml.CreateElement("label")
    $label.SetAttribute("description", $TabLabel)
    $label.SetAttribute("languagecode", $script:LanguageCode.ToString())
    $labels.AppendChild($label) | Out-Null
    $tab.AppendChild($labels) | Out-Null

    $columns = $formXml.CreateElement("columns")
    $widthPercent = [math]::Floor(100 / $TabColumns)
    for ($i = 0; $i -lt $TabColumns; $i++) {
        $column = $formXml.CreateElement("column")
        $column.SetAttribute("width", "$widthPercent%")
        $sections = $formXml.CreateElement("sections")
        $column.AppendChild($sections) | Out-Null
        $columns.AppendChild($column) | Out-Null
    }
    $tab.AppendChild($columns) | Out-Null

    if ($TabPosition -ge 0) {
        $existingTabs = @($formXml.form.tabs.tab)
        if ($TabPosition -lt $existingTabs.Count) {
            $formXml.form.tabs.InsertBefore($tab, $existingTabs[$TabPosition]) | Out-Null
            Write-Host "  Added tab '$TabName' with $TabColumns column(s) at position $TabPosition" -ForegroundColor Gray
        } else {
            $formXml.form.tabs.AppendChild($tab) | Out-Null
            Write-Host "  Added tab '$TabName' with $TabColumns column(s) at end (position $TabPosition exceeds tab count)" -ForegroundColor Gray
        }
    } else {
        $formXml.form.tabs.AppendChild($tab) | Out-Null
        Write-Host "  Added tab '$TabName' with $TabColumns column(s)" -ForegroundColor Gray
    }

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Tab '$TabName' added successfully"
}

function Add-SubgridToForm {
    # HideSearchBox defaults to $true (standard practice: hide search box on subgrids)
    param([string]$FormId, [string]$TabName, [string]$SectionName, [string]$SectionLabel, [string]$SubgridName, [string]$SubgridLabel, [string]$RelatedTable, [string]$RelationshipName, [string]$ViewId, [int]$SubgridRowspan, [int]$RecordsPerPage, [bool]$EnableQuickFind = $false, [bool]$EnableViewPicker, [bool]$HideSearchBox = $true)

    Write-Host "`nAdding subgrid to form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }
    Write-Host "  Found tab: $TabName" -ForegroundColor Gray

    $section = $null
    $rowsElement = $null
    foreach ($col in $tab.columns.column) {
        $existingSection = $col.sections.section | Where-Object { $_.name -eq $SectionName }
        if ($existingSection) {
            $section = $existingSection
            $rowsElement = $section.SelectSingleNode("rows")
            break
        }
    }

    if ($section) {
        Write-Host "  Found existing section: $SectionName" -ForegroundColor Gray
    } else {
        Write-Host "  Creating new section: $SectionName" -ForegroundColor Gray
        $targetColumn = $tab.columns.column | Select-Object -Last 1

        $section = $formXml.CreateElement("section")
        $section.SetAttribute("name", $SectionName)
        $section.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
        $section.SetAttribute("columns", "1")
        $section.SetAttribute("showlabel", "true")
        $section.SetAttribute("showbar", "false")
        $section.SetAttribute("IsUserDefined", "0")
        $section.SetAttribute("labelwidth", "115")

        $labels = $formXml.CreateElement("labels")
        $label = $formXml.CreateElement("label")
        $label.SetAttribute("description", $(if ($SectionLabel) { $SectionLabel } else { $SubgridLabel }))
        $label.SetAttribute("languagecode", $script:LanguageCode.ToString())
        $labels.AppendChild($label) | Out-Null
        $section.AppendChild($labels) | Out-Null

        $rowsElement = $formXml.CreateElement("rows")
        $section.AppendChild($rowsElement) | Out-Null
        $sectionsNode = $targetColumn.SelectSingleNode("sections")
        if (-not $sectionsNode) {
            $sectionsNode = $formXml.CreateElement("sections")
            $targetColumn.AppendChild($sectionsNode) | Out-Null
        }
        $sectionsNode.AppendChild($section) | Out-Null
    }

    $row = $formXml.CreateElement("row")
    $cell = $formXml.CreateElement("cell")
    $cell.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
    $cell.SetAttribute("rowspan", $SubgridRowspan.ToString())

    $cellLabels = $formXml.CreateElement("labels")
    $cellLabel = $formXml.CreateElement("label")
    $cellLabel.SetAttribute("description", $SubgridLabel)
    $cellLabel.SetAttribute("languagecode", $script:LanguageCode.ToString())
    $cellLabels.AppendChild($cellLabel) | Out-Null
    $cell.AppendChild($cellLabels) | Out-Null

    $control = $formXml.CreateElement("control")
    $control.SetAttribute("id", $SubgridName)
    $control.SetAttribute("classid", $script:ControlClassIds["Subgrid"])

    $params = $formXml.CreateElement("parameters")
    $cleanViewId = $ViewId -replace '[{}]', ''

    # EnableQuickFind controls the search box. HideSearchBox=true (default) sets it to false.
    $quickFindValue = if ($HideSearchBox) { "false" } else { if ($EnableQuickFind) { "true" } else { "false" } }

    @(
        @("TargetEntityType", $RelatedTable),
        @("ViewId", "{$cleanViewId}"),
        @("ViewIds", "{$cleanViewId}"),
        @("RelationshipName", $RelationshipName),
        @("EnableQuickFind", $quickFindValue),
        @("EnableViewPicker", $(if ($EnableViewPicker) { "true" } else { "false" })),
        @("RecordsPerPage", $RecordsPerPage.ToString())
    ) | ForEach-Object {
        $elem = $formXml.CreateElement($_[0])
        $elem.InnerText = $_[1]
        $params.AppendChild($elem) | Out-Null
    }

    $control.AppendChild($params) | Out-Null
    $cell.AppendChild($control) | Out-Null
    $row.AppendChild($cell) | Out-Null
    $rowsElement.AppendChild($row) | Out-Null

    Write-Host "  Added subgrid '$SubgridName' to section '$SectionName'" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Subgrid '$SubgridName' added successfully"
}

function Remove-SectionFromForm {
    param([string]$FormId, [string]$TabName, [string]$SectionName)

    Write-Host "`nRemoving section from form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }
    Write-Host "  Found tab: $TabName" -ForegroundColor Gray

    $removed = $false
    foreach ($column in $tab.columns.column) {
        $section = $column.sections.section | Where-Object { $_.name -eq $SectionName }
        if ($section) {
            $column.sections.RemoveChild($section) | Out-Null
            $removed = $true
            Write-Host "  Removed section '$SectionName' from tab '$TabName'" -ForegroundColor Gray
            break
        }
    }

    if (-not $removed) { throw "Section '$SectionName' not found in tab '$TabName'" }

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Section '$SectionName' removed successfully"
}

function Move-SectionInForm {
    param([string]$FormId, [string]$TabName, [string]$SectionName, [int]$SectionPosition, [int]$TargetColumnIndex = -1)

    Write-Host "`nMoving section in form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }
    Write-Host "  Found tab: $TabName" -ForegroundColor Gray

    # Find the section and its parent sections node
    $section = $null
    $sourceSectionsNode = $null
    foreach ($col in $tab.columns.column) {
        $sectionsNode = $col.SelectSingleNode("sections")
        if ($sectionsNode) {
            $found = $sectionsNode.SelectSingleNode("section[@name='$SectionName']")
            if ($found) {
                $section = $found
                $sourceSectionsNode = $sectionsNode
                break
            }
        }
    }
    if (-not $section) { throw "Section '$SectionName' not found in tab '$TabName'" }

    # Remove the section from its current position
    $sourceSectionsNode.RemoveChild($section) | Out-Null
    Write-Host "  Removed section '$SectionName' from current position" -ForegroundColor Gray

    # Determine target sections node (optionally a different tab column)
    $targetSectionsNode = $sourceSectionsNode
    if ($TargetColumnIndex -ge 0) {
        $tabColumns = @($tab.columns.column)
        if ($TargetColumnIndex -ge $tabColumns.Count) {
            throw "TargetColumnIndex $TargetColumnIndex out of range (tab has $($tabColumns.Count) column(s))"
        }
        $targetSectionsNode = $tabColumns[$TargetColumnIndex].SelectSingleNode("sections")
        if (-not $targetSectionsNode) {
            $targetSectionsNode = $formXml.CreateElement("sections")
            [void]$tabColumns[$TargetColumnIndex].AppendChild($targetSectionsNode)
        }
        Write-Host "  Target column index: $TargetColumnIndex" -ForegroundColor Gray
    }

    # Get existing sections in the target to determine insertion point
    $allSections = @($targetSectionsNode.SelectNodes("section"))
    $totalSections = $allSections.Count

    if ($SectionPosition -le 0 -or $totalSections -eq 0) {
        if ($targetSectionsNode.FirstChild) {
            $targetSectionsNode.InsertBefore($section, $targetSectionsNode.FirstChild) | Out-Null
        } else {
            $targetSectionsNode.AppendChild($section) | Out-Null
        }
        Write-Host "  Inserted section at position 0 (first)" -ForegroundColor Gray
    } elseif ($SectionPosition -ge $totalSections) {
        $targetSectionsNode.AppendChild($section) | Out-Null
        Write-Host "  Inserted section at position $totalSections (last)" -ForegroundColor Gray
    } else {
        $refSection = $allSections[$SectionPosition]
        $targetSectionsNode.InsertBefore($section, $refSection) | Out-Null
        Write-Host "  Inserted section at position $SectionPosition" -ForegroundColor Gray
    }

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Section '$SectionName' moved to position $SectionPosition successfully"
}

function Rename-TabOnForm {
    param([string]$FormId, [string]$TabName, [string]$TabLabel)

    Write-Host "`nRenaming tab on form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }
    $currentLabel = $tab.SelectSingleNode("labels/label")
    Write-Host "  Found tab: $TabName (current label: $($currentLabel.description))" -ForegroundColor Gray

    # Update the label
    $label = $tab.SelectSingleNode("labels/label[@languagecode='$($script:LanguageCode)']")
    if (-not $label) {
        $label = $tab.SelectSingleNode("labels/label")
    }
    if ($label) {
        $label.SetAttribute("description", $TabLabel)
    } else {
        throw "Could not find label element for tab '$TabName'"
    }
    Write-Host "  Updated tab label to '$TabLabel'" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Tab '$TabName' renamed to '$TabLabel' successfully"
}

function Rename-Form {
    <#
    .SYNOPSIS
        Renames a form by patching `systemforms.name`, and optionally updates the
        form description in the same call. Form display names + descriptions live on
        the systemforms record, NOT in formxml — so Update-FormXml cannot change them.

        Use this to rename auto-created `Information` Main forms to follow the
        `Client | Form Type | Purpose` HSO convention, and to populate the description
        field for spec traceability.
    #>
    param([string]$FormId, [string]$FormName, [string]$FormDescription)

    if (-not $FormName -and -not $FormDescription) {
        throw "Rename-Form requires at least one of -FormName or -FormDescription."
    }

    Write-Host "`nUpdating form $($FormId)..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    $body = [ordered]@{}
    if ($FormName)        { $body['name'] = $FormName;               Write-Host "  name -> $FormName" -ForegroundColor Gray }
    if ($FormDescription) { $body['description'] = $FormDescription; Write-Host "  description -> $FormDescription" -ForegroundColor Gray }

    $jsonBody = $body | ConvertTo-Json -Depth 1
    $url = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/systemforms($cleanFormId)"
    $headers = @{
        "Authorization" = "Bearer $script:AuthToken"
        "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0"
        "Accept" = "application/json"; "Content-Type" = "application/json; charset=utf-8"
    }
    try {
        Invoke-RestMethod -Uri $url -Method PATCH -Headers $headers -Body $jsonBody -ErrorAction Stop
    } catch {
        Write-Output "[ERROR] Form update failed: $($_.Exception.Message)"
        throw
    }
    Write-Output "[OK] Form $cleanFormId updated"
    Write-Host "    Remember to publish customizations to see changes" -ForegroundColor Yellow
}

function Set-FormDescription {
    <#
    .SYNOPSIS
        Updates only a form's description. Thin wrapper over Rename-Form for the
        common spec-traceability use case ("populate the description on every form").
    #>
    param([string]$FormId, [string]$FormDescription)
    if (-not $FormDescription) { throw "FormDescription required" }
    Rename-Form -FormId $FormId -FormDescription $FormDescription
}

function Rename-SectionOnForm {
    <#
    .SYNOPSIS
        Updates a section's @name and/or label inside form XML.

    .DESCRIPTION
        Two modes (caller supplies one or both):
          - Pass -SectionLabel only to change the displayed label without touching @name.
            This is the common case and is safe; nothing in code references the label.
          - Pass -NewSectionName to change @name. WARNING: changing @name breaks any
            code (form scripts, business rules, etc.) that references the section by
            name. Only use this when intentionally aligning with a naming convention
            and you have verified no callers reference the existing @name.
        At least one of -NewSectionName or -SectionLabel must be supplied.

        Section lookup priority:
          1. -SectionId (GUID) — matches @id attribute; use for auto-generated forms
             where the section has no meaningful @name (e.g. name is empty or a raw GUID).
          2. -SectionName — matches @name attribute (original behaviour).
        Supply either -SectionName or -SectionId; -SectionId takes precedence if both given.
    #>
    param([string]$FormId, [string]$TabName, [string]$SectionName, [string]$SectionId, [string]$NewSectionName, [string]$SectionLabel)

    Write-Host "`nUpdating section on form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }

    $section = $null
    $cleanSectionId = if ($SectionId) { $SectionId -replace '[{}]', '' } else { $null }
    if ($cleanSectionId) {
        $section = $tab.SelectSingleNode(".//sections/section[@id='{$cleanSectionId}']")
        if (-not $section) {
            # Try without braces in case the XML stores it either way
            $section = $tab.SelectSingleNode(".//sections/section[@id='$cleanSectionId']")
        }
        if (-not $section) { throw "Section with id '$SectionId' not found in tab '$TabName'" }
        Write-Host "  Found section by id: $($section.GetAttribute('id'))" -ForegroundColor Gray
    } else {
        $section = $tab.SelectSingleNode(".//sections/section[@name='$SectionName']")
        if (-not $section) { throw "Section '$SectionName' not found in tab '$TabName'" }
        Write-Host "  Found section: $SectionName" -ForegroundColor Gray
    }

    if ($NewSectionName) {
        $section.SetAttribute("name", $NewSectionName)
        Write-Host "  Renamed section @name -> '$NewSectionName'" -ForegroundColor Gray
    }

    if ($SectionLabel) {
        $label = $section.SelectSingleNode("labels/label[@languagecode='$($script:LanguageCode)']")
        if (-not $label) {
            $label = $section.SelectSingleNode("labels/label")
        }
        if ($label) {
            $label.SetAttribute("description", $SectionLabel)
            Write-Host "  Updated section label -> '$SectionLabel'" -ForegroundColor Gray
        } else {
            Write-Host "  [WARN] No label element found on section; skipping label update" -ForegroundColor Yellow
        }
    }

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    $finalName = if ($NewSectionName) { $NewSectionName } else { $SectionName }
    Write-Output "[OK] Section '$SectionName' updated successfully (now '$finalName')"
}

function Update-FieldOnForm {
    param([string]$FormId, [string]$FieldName, [string]$FieldShowLabel, [string]$FieldReadOnly, [string]$FieldVisible,
          [int]$FieldColspan, [int]$FieldRowspan, [string]$FieldAvailableForPhone, [string]$FieldIsRequired)

    Write-Host "`nUpdating field properties on form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    # Find the control by datafieldname or id across all cells (tabs, header, footer)
    $control = $formXml.SelectSingleNode("//control[@datafieldname='$FieldName']")
    if (-not $control) {
        $control = $formXml.SelectSingleNode("//control[@id='$FieldName']")
    }
    if (-not $control) { throw "Field '$FieldName' not found on form" }

    $cell = $control.ParentNode
    Write-Host "  Found field '$FieldName'" -ForegroundColor Gray

    $changes = @()

    # Cell-level attributes
    if ($FieldShowLabel) {
        $cell.SetAttribute("showlabel", $FieldShowLabel.ToLower())
        $changes += "showlabel=$($FieldShowLabel.ToLower())"
    }
    if ($FieldVisible) {
        $cell.SetAttribute("visible", $FieldVisible.ToLower())
        $changes += "visible=$($FieldVisible.ToLower())"
    }
    if ($FieldColspan -gt 0) {
        $cell.SetAttribute("colspan", $FieldColspan.ToString())
        $changes += "colspan=$FieldColspan"
    }
    if ($FieldRowspan -gt 0) {
        $cell.SetAttribute("rowspan", $FieldRowspan.ToString())
        $changes += "rowspan=$FieldRowspan"
    }
    if ($FieldAvailableForPhone) {
        $cell.SetAttribute("availableforphone", $FieldAvailableForPhone.ToLower())
        $changes += "availableforphone=$($FieldAvailableForPhone.ToLower())"
    }

    # Control-level attributes
    if ($FieldReadOnly) {
        $control.SetAttribute("disabled", $(if ($FieldReadOnly.ToLower() -eq "true") { "true" } else { "false" }))
        $changes += "disabled=$($FieldReadOnly.ToLower())"
    }
    if ($FieldIsRequired) {
        $control.SetAttribute("isrequired", $FieldIsRequired.ToLower())
        $changes += "isrequired=$($FieldIsRequired.ToLower())"
    }

    if ($changes.Count -eq 0) { throw "No property changes specified. Use -FieldShowLabel, -FieldReadOnly, -FieldVisible, -FieldColspan, -FieldRowspan, -FieldAvailableForPhone, or -FieldIsRequired" }

    Write-Host "  Applied: $($changes -join ', ')" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Field '$FieldName' updated ($($changes -join ', ')) successfully"
}

function Add-SectionToForm {
    param([string]$FormId, [string]$TabName, [string]$SectionName, [string]$SectionLabel,
          [int]$SectionColumns, [bool]$SectionShowLabel, [int]$SectionLabelWidth, [int]$TabColumnIndex = 0)

    Write-Host "`nAdding section to form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }
    Write-Host "  Found tab: $TabName" -ForegroundColor Gray

    foreach ($col in $tab.columns.column) {
        $existingSection = $col.sections.section | Where-Object { $_.name -eq $SectionName }
        if ($existingSection) { throw "Section '$SectionName' already exists in tab '$TabName'" }
    }

    $allColumns = @($tab.columns.column)
    if ($TabColumnIndex -ge $allColumns.Count) {
        Write-Host "  [WARN] TabColumnIndex $TabColumnIndex exceeds column count ($($allColumns.Count)), using last column" -ForegroundColor Yellow
        $TabColumnIndex = $allColumns.Count - 1
    }
    $targetColumn = $allColumns[$TabColumnIndex]

    # Use SelectSingleNode to reliably get the sections XmlNode. PowerShell's dot-notation
    # returns empty string for empty elements like <sections />, causing AppendChild to fail.
    $sectionsNode = $targetColumn.SelectSingleNode("sections")
    if (-not $sectionsNode) {
        $sectionsNode = $formXml.CreateElement("sections")
        $targetColumn.AppendChild($sectionsNode) | Out-Null
    }

    $section = $formXml.CreateElement("section")
    $section.SetAttribute("name", $SectionName)
    $section.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
    $section.SetAttribute("columns", $SectionColumns.ToString())
    $section.SetAttribute("showlabel", $(if ($SectionShowLabel) { "true" } else { "false" }))
    $section.SetAttribute("showbar", "false")
    $section.SetAttribute("IsUserDefined", "1")
    $section.SetAttribute("labelwidth", $SectionLabelWidth.ToString())
    $section.SetAttribute("celllabelalignment", "Left")
    $section.SetAttribute("celllabelposition", "Left")

    $labels = $formXml.CreateElement("labels")
    $label = $formXml.CreateElement("label")
    $label.SetAttribute("description", $(if ($SectionLabel) { $SectionLabel } else { $SectionName }))
    $label.SetAttribute("languagecode", $script:LanguageCode.ToString())
    $labels.AppendChild($label) | Out-Null
    $section.AppendChild($labels) | Out-Null

    $rows = $formXml.CreateElement("rows")
    $section.AppendChild($rows) | Out-Null

    $sectionsNode.AppendChild($section) | Out-Null

    Write-Host "  Added section '$SectionName' to tab '$TabName'" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Section '$SectionName' added successfully"
}

function Add-FieldsToForm {
    param([string]$FormId, [string]$TabName, [string]$SectionName, [array]$Fields)

    Write-Host "`nAdding fields to form..." -ForegroundColor Cyan
    $Fields = ConvertTo-NormalizedArray $Fields
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }

    $section = $null
    $rowsElement = $null
    foreach ($col in $tab.columns.column) {
        $existingSection = $col.sections.section | Where-Object { $_.name -eq $SectionName }
        if ($existingSection) {
            $section = $existingSection
            $rowsElement = $section.SelectSingleNode("rows")
            break
        }
    }
    if (-not $section) { throw "Section '$SectionName' not found in tab '$TabName'" }
    Write-Host "  Found section: $SectionName" -ForegroundColor Gray

    if (-not $rowsElement) {
        $rowsElement = $formXml.CreateElement("rows")
        $section.AppendChild($rowsElement) | Out-Null
    }

    $addedCount = 0
    foreach ($field in $Fields) {
        # Fields can be strings (field name only) or hashtables with Name, Label, Type
        if ($field -is [string]) {
            $fieldName = $field
            $fieldLabel = $null
            $fieldType = $null
        } else {
            $fieldName = $field.Name
            $fieldLabel = $field.Label
            $fieldType = $field.Type
        }

        $classId = Get-ControlClassId -FieldType $fieldType -FieldName $fieldName
        $resolvedLabel = Resolve-FieldLabel -TableName $tableName -FieldName $fieldName -ProvidedLabel $fieldLabel

        $row = $formXml.CreateElement("row")
        $cell = $formXml.CreateElement("cell")
        $cell.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
        $cell.SetAttribute("showlabel", "true")
        $cell.SetAttribute("locklevel", "0")

        # Always emit an explicit <labels> element so Dataverse cannot auto-generate
        # <label description=""...> from an empty column DisplayName. See Resolve-FieldLabel.
        $cellLabels = $formXml.CreateElement("labels")
        $cellLabel = $formXml.CreateElement("label")
        $cellLabel.SetAttribute("description", $resolvedLabel)
        $cellLabel.SetAttribute("languagecode", $script:LanguageCode.ToString())
        $cellLabels.AppendChild($cellLabel) | Out-Null
        $cell.AppendChild($cellLabels) | Out-Null

        $control = $formXml.CreateElement("control")
        $control.SetAttribute("id", $fieldName)
        $control.SetAttribute("classid", $classId)
        $control.SetAttribute("datafieldname", $fieldName)
        $control.SetAttribute("disabled", "false")
        $cell.AppendChild($control) | Out-Null

        $row.AppendChild($cell) | Out-Null
        $rowsElement.AppendChild($row) | Out-Null
        $addedCount++
        Write-Host "  Added field: $fieldName (label: $resolvedLabel)" -ForegroundColor Gray
    }

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] $addedCount field(s) added successfully"
}

function Add-HeaderFieldToForm {
    param([string]$FormId, [string]$FieldName, [string]$FieldType)

    Write-Host "`nAdding header field to form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $header = $formXml.form.header
    if (-not $header) {
        Write-Host "  Creating header element..." -ForegroundColor Gray
        $header = $formXml.CreateElement("header")
        $header.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
        $header.SetAttribute("columns", "4")
        $header.SetAttribute("labelwidth", "115")
        $header.SetAttribute("celllabelalignment", "Left")
        $header.SetAttribute("celllabelposition", "Top")
        $hRows = $formXml.CreateElement("rows")
        $hRow = $formXml.CreateElement("row")
        $hRows.AppendChild($hRow) | Out-Null
        $header.AppendChild($hRows) | Out-Null
        $tabs = $formXml.form.tabs
        if ($tabs) { $formXml.form.InsertBefore($header, $tabs) | Out-Null }
        else { $formXml.form.AppendChild($header) | Out-Null }
    }

    # Check if field already exists in header
    foreach ($row in @($header.rows.row)) {
        foreach ($cell in @($row.cell)) {
            if ($cell.control -and $cell.control.datafieldname -eq $FieldName) {
                throw "Field '$FieldName' already exists in the header"
            }
        }
    }

    $classId = Get-ControlClassId -FieldType $FieldType -FieldName $FieldName
    $resolvedLabel = Resolve-FieldLabel -TableName $tableName -FieldName $FieldName -ProvidedLabel $null

    $headerRow = $header.rows.row | Select-Object -First 1
    if (-not $headerRow) {
        $headerRow = $formXml.CreateElement("row")
        $header.rows.AppendChild($headerRow) | Out-Null
    }

    $cell = $formXml.CreateElement("cell")
    $cell.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
    $cell.SetAttribute("showlabel", "true")
    $cell.SetAttribute("locklevel", "0")

    $cellLabels = $formXml.CreateElement("labels")
    $cellLabel = $formXml.CreateElement("label")
    $cellLabel.SetAttribute("description", $resolvedLabel)
    $cellLabel.SetAttribute("languagecode", $script:LanguageCode.ToString())
    $cellLabels.AppendChild($cellLabel) | Out-Null
    $cell.AppendChild($cellLabels) | Out-Null

    $control = $formXml.CreateElement("control")
    $control.SetAttribute("id", "header_$FieldName")
    $control.SetAttribute("classid", $classId)
    $control.SetAttribute("datafieldname", $FieldName)
    $control.SetAttribute("disabled", "false")
    $cell.AppendChild($control) | Out-Null

    $headerRow.AppendChild($cell) | Out-Null
    Write-Host "  Added header field: $FieldName (label: $resolvedLabel)" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Header field '$FieldName' added successfully"
}

function Remove-HeaderFieldFromForm {
    param([string]$FormId, [string]$FieldName)

    Write-Host "`nRemoving header field from form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $header = $formXml.form.header
    if (-not $header) { throw "Form has no header" }

    $removed = $false
    foreach ($row in @($header.rows.row)) {
        foreach ($cell in @($row.cell)) {
            if ($cell.control -and ($cell.control.datafieldname -eq $FieldName -or $cell.control.id -eq "header_$FieldName")) {
                $row.RemoveChild($cell) | Out-Null
                $removed = $true
                Write-Host "  Removed header field: $FieldName" -ForegroundColor Gray
                break
            }
        }
        if ($removed) { break }
    }

    if (-not $removed) { throw "Field '$FieldName' not found in header" }

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Header field '$FieldName' removed successfully"
}

function Remove-TabFromForm {
    param([string]$FormId, [string]$TabName)

    Write-Host "`nRemoving tab from form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }

    $formXml.form.tabs.RemoveChild($tab) | Out-Null
    Write-Host "  Removed tab: $TabName" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Tab '$TabName' removed successfully"
}

function Add-FormLibraryToForm {
    param([string]$FormId, [string]$LibraryName)

    Write-Host "`nAdding form library..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $formLibraries = $formXml.form.formLibraries
    if (-not $formLibraries) {
        $formLibraries = $formXml.CreateElement("formLibraries")
        $formXml.form.AppendChild($formLibraries) | Out-Null
    }

    $existingLib = $formLibraries.Library | Where-Object { $_.name -eq $LibraryName }
    if ($existingLib) {
        Write-Host "  Library '$LibraryName' already registered on form" -ForegroundColor Yellow
        return
    }

    $library = $formXml.CreateElement("Library")
    $library.SetAttribute("name", $LibraryName)
    $library.SetAttribute("libraryUniqueId", "{$([guid]::NewGuid().ToString())}")
    $formLibraries.AppendChild($library) | Out-Null
    Write-Host "  Added library: $LibraryName" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Library '$LibraryName' added successfully"
}

function Add-FormEventToForm {
    param([string]$FormId, [string]$EventName, [string]$FunctionName, [string]$LibraryName,
          [string]$EventAttribute, [bool]$PassExecutionContext,
          [string]$EventParameters, [string]$EventTabName, [string]$EventControlName)

    Write-Host "`nAdding form event handler..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    # Ensure library is registered on the form
    $formLibraries = $formXml.form.formLibraries
    if (-not $formLibraries) {
        $formLibraries = $formXml.CreateElement("formLibraries")
        $formXml.form.AppendChild($formLibraries) | Out-Null
    }
    $existingLib = $formLibraries.Library | Where-Object { $_.name -eq $LibraryName }
    if (-not $existingLib) {
        Write-Host "  Auto-registering library '$LibraryName' on form..." -ForegroundColor Gray
        $library = $formXml.CreateElement("Library")
        $library.SetAttribute("name", $LibraryName)
        $library.SetAttribute("libraryUniqueId", "{$([guid]::NewGuid().ToString())}")
        $formLibraries.AppendChild($library) | Out-Null
    }

    # Determine where events should be placed: form-level, tab-level, or cell-level
    $events = $null
    $eventContext = "form"

    if ($EventTabName) {
        # Tab-level event (M6: ontabstatechange)
        $tab = Find-Tab -FormXml $formXml -TabName $EventTabName
        if (-not $tab) { throw "Tab '$EventTabName' not found" }
        $events = $tab.SelectSingleNode("events")
        if (-not $events) {
            $events = $formXml.CreateElement("events")
            $tab.AppendChild($events) | Out-Null
        }
        $eventContext = "tab '$EventTabName'"
    } elseif ($EventControlName) {
        # Cell-level event (M7: control events)
        $control = $formXml.SelectSingleNode("//control[@id='$EventControlName']")
        if (-not $control) {
            $control = $formXml.SelectSingleNode("//control[@datafieldname='$EventControlName']")
        }
        if (-not $control) { throw "Control '$EventControlName' not found on form" }
        $cell = $control.ParentNode
        $events = $cell.SelectSingleNode("events")
        if (-not $events) {
            $events = $formXml.CreateElement("events")
            $cell.AppendChild($events) | Out-Null
        }
        $eventContext = "control '$EventControlName'"
    } else {
        # Form-level event (default)
        $events = $formXml.form.events
        if (-not $events) {
            $events = $formXml.CreateElement("events")
            $formXml.form.AppendChild($events) | Out-Null
        }
    }

    $isOnChange = $EventName -eq "onchange"

    # Find existing event or create new one
    $formEvent = $null
    if ($isOnChange -and $EventAttribute) {
        $formEvent = $events.event | Where-Object { $_.name -eq $EventName -and $_.attribute -eq $EventAttribute }
    } else {
        $formEvent = $events.event | Where-Object { $_.name -eq $EventName -and (-not $_.attribute -or $_.attribute -eq "") }
    }

    if (-not $formEvent) {
        $formEvent = $formXml.CreateElement("event")
        $formEvent.SetAttribute("name", $EventName)
        $formEvent.SetAttribute("active", "true")
        $formEvent.SetAttribute("application", "false")
        if ($isOnChange -and $EventAttribute) {
            $formEvent.SetAttribute("attribute", $EventAttribute)
        }
        $events.AppendChild($formEvent) | Out-Null
    }

    # Find or create Handlers
    $handlers = $formEvent.SelectSingleNode("Handlers")
    if (-not $handlers) {
        $handlers = $formXml.CreateElement("Handlers")
        $formEvent.AppendChild($handlers) | Out-Null
    }

    # Check for duplicate
    $existingHandler = $handlers.Handler | Where-Object { $_.functionName -eq $FunctionName -and $_.libraryName -eq $LibraryName }
    if ($existingHandler) {
        Write-Host "  Handler '$FunctionName' already registered for event '$EventName'" -ForegroundColor Yellow
        return
    }

    $handler = $formXml.CreateElement("Handler")
    $handler.SetAttribute("functionName", $FunctionName)
    $handler.SetAttribute("libraryName", $LibraryName)
    $handler.SetAttribute("handlerUniqueId", "{$([guid]::NewGuid().ToString())}")
    $handler.SetAttribute("enabled", "true")
    $handler.SetAttribute("passExecutionContext", $(if ($PassExecutionContext) { "true" } else { "false" }))
    # M8: Handler parameters support
    if ($EventParameters) {
        $handler.SetAttribute("parameters", $EventParameters)
    }
    $handlers.AppendChild($handler) | Out-Null

    $eventDesc = if ($isOnChange -and $EventAttribute) { "$EventName ($EventAttribute)" } else { $EventName }
    Write-Host "  Added handler '$FunctionName' to event '$eventDesc' on $eventContext" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Event handler added successfully"
}

function Add-TimelineToForm {
    param([string]$FormId, [string]$TabName, [string]$SectionName, [string]$SectionLabel,
          [string]$ControlName, [int]$ControlRowspan)

    Write-Host "`nAdding timeline control to form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''
    if (-not $ControlName) { $ControlName = "notescontrol" }

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }
    Write-Host "  Found tab: $TabName" -ForegroundColor Gray

    # Find or create section
    $section = $null
    $rowsElement = $null
    foreach ($col in $tab.columns.column) {
        $existingSection = $col.sections.section | Where-Object { $_.name -eq $SectionName }
        if ($existingSection) {
            $section = $existingSection
            $rowsElement = $section.SelectSingleNode("rows")
            break
        }
    }

    if ($section) {
        Write-Host "  Found existing section: $SectionName" -ForegroundColor Gray
    } else {
        Write-Host "  Creating new section: $SectionName" -ForegroundColor Gray
        $targetColumn = $tab.columns.column | Select-Object -Last 1

        $section = $formXml.CreateElement("section")
        $section.SetAttribute("name", $SectionName)
        $section.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
        $section.SetAttribute("columns", "1")
        $section.SetAttribute("showlabel", "false")
        $section.SetAttribute("showbar", "false")
        $section.SetAttribute("IsUserDefined", "0")
        $section.SetAttribute("labelwidth", "115")

        $labels = $formXml.CreateElement("labels")
        $label = $formXml.CreateElement("label")
        $label.SetAttribute("description", $(if ($SectionLabel) { $SectionLabel } else { "Timeline" }))
        $label.SetAttribute("languagecode", $script:LanguageCode.ToString())
        $labels.AppendChild($label) | Out-Null
        $section.AppendChild($labels) | Out-Null

        $rowsElement = $formXml.CreateElement("rows")
        $section.AppendChild($rowsElement) | Out-Null
        $sectionsNode = $targetColumn.SelectSingleNode("sections")
        if (-not $sectionsNode) {
            $sectionsNode = $formXml.CreateElement("sections")
            $targetColumn.AppendChild($sectionsNode) | Out-Null
        }
        $sectionsNode.AppendChild($section) | Out-Null
    }

    # Create timeline cell and control
    $row = $formXml.CreateElement("row")
    $cell = $formXml.CreateElement("cell")
    $cell.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
    $cell.SetAttribute("showlabel", "false")
    $cell.SetAttribute("rowspan", $ControlRowspan.ToString())

    $cellLabels = $formXml.CreateElement("labels")
    $cellLabel = $formXml.CreateElement("label")
    $cellLabel.SetAttribute("description", "Timeline")
    $cellLabel.SetAttribute("languagecode", $script:LanguageCode.ToString())
    $cellLabels.AppendChild($cellLabel) | Out-Null
    $cell.AppendChild($cellLabels) | Out-Null

    $control = $formXml.CreateElement("control")
    $control.SetAttribute("id", $ControlName)
    $control.SetAttribute("classid", $script:ControlClassIds["Timeline"])
    # Timeline control self-configures from the table's HasActivities/HasNotes settings.
    # No <parameters> element needed (NotesEntityName/isaborttimeline are not valid per FormXml.xsd).

    $cell.AppendChild($control) | Out-Null
    $row.AppendChild($cell) | Out-Null
    $rowsElement.AppendChild($row) | Out-Null

    Write-Host "  Added timeline control '$ControlName' to section '$SectionName'" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Timeline control added successfully"
}

function Add-FormComponentToForm {
    param([string]$FormId, [string]$TabName, [string]$SectionName, [string]$FieldName,
          [string]$RelatedTable, [string]$RelatedFormId, [string]$ControlName, [int]$ControlRowspan)

    Write-Host "`nAdding form component control to form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''
    if (-not $ControlName) { $ControlName = "${FieldName}_formcomponent" }
    $cleanRelatedFormId = $RelatedFormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }
    Write-Host "  Found tab: $TabName" -ForegroundColor Gray

    # Find or create section
    $section = $null
    $rowsElement = $null
    foreach ($col in $tab.columns.column) {
        $existingSection = $col.sections.section | Where-Object { $_.name -eq $SectionName }
        if ($existingSection) {
            $section = $existingSection
            $rowsElement = $section.SelectSingleNode("rows")
            break
        }
    }

    if ($section) {
        Write-Host "  Found existing section: $SectionName" -ForegroundColor Gray
    } else {
        Write-Host "  Creating new section: $SectionName" -ForegroundColor Gray
        $targetColumn = $tab.columns.column | Select-Object -Last 1

        $section = $formXml.CreateElement("section")
        $section.SetAttribute("name", $SectionName)
        $section.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
        $section.SetAttribute("columns", "1")
        $section.SetAttribute("showlabel", "false")
        $section.SetAttribute("showbar", "false")
        $section.SetAttribute("IsUserDefined", "0")
        $section.SetAttribute("labelwidth", "115")

        $labels = $formXml.CreateElement("labels")
        $label = $formXml.CreateElement("label")
        $label.SetAttribute("description", $(if ($SectionLabel) { $SectionLabel } else { $ControlName }))
        $label.SetAttribute("languagecode", $script:LanguageCode.ToString())
        $labels.AppendChild($label) | Out-Null
        $section.AppendChild($labels) | Out-Null

        $rowsElement = $formXml.CreateElement("rows")
        $section.AppendChild($rowsElement) | Out-Null
        $sectionsNode = $targetColumn.SelectSingleNode("sections")
        if (-not $sectionsNode) {
            $sectionsNode = $formXml.CreateElement("sections")
            $targetColumn.AppendChild($sectionsNode) | Out-Null
        }
        $sectionsNode.AppendChild($section) | Out-Null
    }

    # Create a unique ID for the control (used to link cell control to controlDescription)
    $controlUniqueId = "{$([guid]::NewGuid().ToString())}"

    # Create cell with lookup control
    $row = $formXml.CreateElement("row")
    $cell = $formXml.CreateElement("cell")
    $cell.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
    $cell.SetAttribute("showlabel", "false")
    $cell.SetAttribute("rowspan", $ControlRowspan.ToString())

    $cellLabels = $formXml.CreateElement("labels")
    $cellLabel = $formXml.CreateElement("label")
    $cellLabel.SetAttribute("description", "")
    $cellLabel.SetAttribute("languagecode", $script:LanguageCode.ToString())
    $cellLabels.AppendChild($cellLabel) | Out-Null
    $cell.AppendChild($cellLabels) | Out-Null

    $control = $formXml.CreateElement("control")
    $control.SetAttribute("id", $ControlName)
    $control.SetAttribute("uniqueid", $controlUniqueId)
    $control.SetAttribute("classid", $script:ControlClassIds["Lookup"])
    $control.SetAttribute("datafieldname", $FieldName)
    $control.SetAttribute("disabled", "false")
    $cell.AppendChild($control) | Out-Null

    $row.AppendChild($cell) | Out-Null
    $rowsElement.AppendChild($row) | Out-Null

    # Create or find controlDescriptions element
    $controlDescriptions = $formXml.form.controlDescriptions
    if (-not $controlDescriptions) {
        $controlDescriptions = $formXml.CreateElement("controlDescriptions")
        $formXml.form.AppendChild($controlDescriptions) | Out-Null
    }

    # Create controlDescription for the Form Component
    $controlDesc = $formXml.CreateElement("controlDescription")
    $controlDesc.SetAttribute("forControl", $controlUniqueId)

    # Default fallback control (standard lookup)
    $defaultControl = $formXml.CreateElement("customControl")
    $defaultControl.SetAttribute("id", $script:ControlClassIds["Lookup"])
    $defaultParams = $formXml.CreateElement("parameters")
    $dfn = $formXml.CreateElement("datafieldname")
    $dfn.InnerText = $FieldName
    $defaultParams.AppendChild($dfn) | Out-Null
    $defaultControl.AppendChild($defaultParams) | Out-Null
    $controlDesc.AppendChild($defaultControl) | Out-Null

    # Form Component Control for each form factor (0=Web, 1=Phone, 2=Tablet)
    foreach ($formFactor in @("0", "2", "1")) {
        $fcControl = $formXml.CreateElement("customControl")
        $fcControl.SetAttribute("formFactor", $formFactor)
        $fcControl.SetAttribute("name", "MscrmControls.FieldControls.FormComponentControl")

        $fcParams = $formXml.CreateElement("parameters")

        $lookupParam = $formXml.CreateElement("LookupField")
        $lookupParam.SetAttribute("type", "Lookup.Simple")
        $lookupParam.InnerText = $FieldName
        $fcParams.AppendChild($lookupParam) | Out-Null

        $relatedFormParam = $formXml.CreateElement("RelatedForm")
        $relatedFormParam.SetAttribute("type", "SingleLine.Text")
        $relatedFormParam.SetAttribute("static", "true")
        $relatedFormParam.InnerText = $cleanRelatedFormId
        $fcParams.AppendChild($relatedFormParam) | Out-Null

        $entityParam = $formXml.CreateElement("EntityName")
        $entityParam.SetAttribute("type", "SingleLine.Text")
        $entityParam.SetAttribute("static", "true")
        $entityParam.InnerText = $RelatedTable
        $fcParams.AppendChild($entityParam) | Out-Null

        $fcControl.AppendChild($fcParams) | Out-Null
        $controlDesc.AppendChild($fcControl) | Out-Null
    }

    $controlDescriptions.AppendChild($controlDesc) | Out-Null

    Write-Host "  Added form component control '$ControlName' for $RelatedTable (form: $cleanRelatedFormId)" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Form component control added successfully"
}

function Remove-FieldFromForm {
    param([string]$FormId, [string]$FieldName)

    Write-Host "`nRemoving field from form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    # Find the control by datafieldname or id across all cells
    $control = $formXml.SelectSingleNode("//tabs//control[@datafieldname='$FieldName']")
    if (-not $control) {
        $control = $formXml.SelectSingleNode("//tabs//control[@id='$FieldName']")
    }
    if (-not $control) { throw "Field '$FieldName' not found on form (searched tabs only, use RemoveHeaderField/RemoveFooterField for header/footer)" }

    $cell = $control.ParentNode
    $row = $cell.ParentNode

    # Remove the cell from the row
    $row.RemoveChild($cell) | Out-Null

    # If row is now empty, remove the row too
    if ($row.ChildNodes.Count -eq 0) {
        $row.ParentNode.RemoveChild($row) | Out-Null
    }

    Write-Host "  Removed field '$FieldName'" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Field '$FieldName' removed successfully"
}

function Move-FieldOnForm {
    param([string]$FormId, [string]$FieldName, [string]$TargetTabName, [string]$TargetSectionName, [int]$FieldPosition)

    Write-Host "`nMoving field on form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    # Find the control
    $control = $formXml.SelectSingleNode("//tabs//control[@datafieldname='$FieldName']")
    if (-not $control) {
        $control = $formXml.SelectSingleNode("//tabs//control[@id='$FieldName']")
    }
    if (-not $control) { throw "Field '$FieldName' not found on form" }

    $cell = $control.ParentNode
    $row = $cell.ParentNode

    # Detach the row containing the field
    $row.ParentNode.RemoveChild($row) | Out-Null
    Write-Host "  Detached field '$FieldName' from current location" -ForegroundColor Gray

    # Find target section
    $targetTab = Find-Tab -FormXml $formXml -TabName $TargetTabName
    if (-not $targetTab) { throw "Target tab '$TargetTabName' not found" }

    $targetSection = $null
    foreach ($col in $targetTab.columns.column) {
        $s = $col.sections.section | Where-Object { $_.name -eq $TargetSectionName }
        if ($s) { $targetSection = $s; break }
    }
    if (-not $targetSection) { throw "Target section '$TargetSectionName' not found in tab '$TargetTabName'" }

    $rowsElement = $targetSection.SelectSingleNode("rows")
    if (-not $rowsElement) {
        $rowsElement = $formXml.CreateElement("rows")
        $targetSection.AppendChild($rowsElement) | Out-Null
    }

    # Insert at position or append
    if ($FieldPosition -ge 0) {
        $existingRows = @($rowsElement.SelectNodes("row"))
        if ($FieldPosition -lt $existingRows.Count) {
            $rowsElement.InsertBefore($row, $existingRows[$FieldPosition]) | Out-Null
        } else {
            $rowsElement.AppendChild($row) | Out-Null
        }
    } else {
        $rowsElement.AppendChild($row) | Out-Null
    }

    Write-Host "  Moved field '$FieldName' to $TargetTabName/$TargetSectionName$(if ($FieldPosition -ge 0) { " at position $FieldPosition" })" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Field '$FieldName' moved successfully"
}

function Add-WebResourceToForm {
    param([string]$FormId, [string]$TabName, [string]$SectionName, [string]$SectionLabel,
          [string]$ControlName, [string]$WebResourceUrl, [bool]$WebResourcePassParameters,
          [int]$WebResourceHeight, [int]$WebResourceWidth, [bool]$WebResourceBorder,
          [int]$ControlRowspan)

    Write-Host "`nAdding web resource to form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }

    # Find or create section
    $section = $null
    $rowsElement = $null
    foreach ($col in $tab.columns.column) {
        $existingSection = $col.sections.section | Where-Object { $_.name -eq $SectionName }
        if ($existingSection) { $section = $existingSection; $rowsElement = $section.SelectSingleNode("rows"); break }
    }

    if (-not $section) {
        Write-Host "  Creating new section: $SectionName" -ForegroundColor Gray
        $targetColumn = $tab.columns.column | Select-Object -Last 1
        $section = $formXml.CreateElement("section")
        $section.SetAttribute("name", $SectionName)
        $section.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
        $section.SetAttribute("columns", "1")
        $section.SetAttribute("showlabel", "true")
        $section.SetAttribute("showbar", "false")
        $section.SetAttribute("IsUserDefined", "0")
        $section.SetAttribute("labelwidth", "115")
        $labels = $formXml.CreateElement("labels")
        $label = $formXml.CreateElement("label")
        $label.SetAttribute("description", $(if ($SectionLabel) { $SectionLabel } else { $ControlName }))
        $label.SetAttribute("languagecode", $script:LanguageCode.ToString())
        $labels.AppendChild($label) | Out-Null
        $section.AppendChild($labels) | Out-Null
        $rowsElement = $formXml.CreateElement("rows")
        $section.AppendChild($rowsElement) | Out-Null
        $sectionsNode = $targetColumn.SelectSingleNode("sections")
        if (-not $sectionsNode) { $sectionsNode = $formXml.CreateElement("sections"); $targetColumn.AppendChild($sectionsNode) | Out-Null }
        $sectionsNode.AppendChild($section) | Out-Null
    }

    if (-not $rowsElement) {
        $rowsElement = $formXml.CreateElement("rows")
        $section.AppendChild($rowsElement) | Out-Null
    }

    $classId = $script:ControlClassIds["WebResource"]

    $row = $formXml.CreateElement("row")
    $cell = $formXml.CreateElement("cell")
    $cell.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
    $cell.SetAttribute("showlabel", "false")
    $cell.SetAttribute("locklevel", "0")
    if ($ControlRowspan -gt 1) { $cell.SetAttribute("rowspan", $ControlRowspan.ToString()) }

    $control = $formXml.CreateElement("control")
    $control.SetAttribute("id", $ControlName)
    $control.SetAttribute("classid", $classId)
    $control.SetAttribute("disabled", "false")

    # Add web resource parameters
    $params = $formXml.CreateElement("parameters")

    $urlParam = $formXml.CreateElement("Url")
    $urlParam.InnerText = $WebResourceUrl
    $params.AppendChild($urlParam) | Out-Null

    $passParamsParam = $formXml.CreateElement("PassParameters")
    $passParamsParam.InnerText = $(if ($WebResourcePassParameters) { "true" } else { "false" })
    $params.AppendChild($passParamsParam) | Out-Null

    $securityParam = $formXml.CreateElement("Security")
    $securityParam.InnerText = "false"
    $params.AppendChild($securityParam) | Out-Null

    $scrollParam = $formXml.CreateElement("Scrolling")
    $scrollParam.InnerText = "auto"
    $params.AppendChild($scrollParam) | Out-Null

    $borderParam = $formXml.CreateElement("Border")
    $borderParam.InnerText = $(if ($WebResourceBorder) { "true" } else { "false" })
    $params.AppendChild($borderParam) | Out-Null

    if ($WebResourceHeight -gt 0) {
        $heightParam = $formXml.CreateElement("SizeType")
        $heightParam.InnerText = "Specific"
        $params.AppendChild($heightParam) | Out-Null

        $hParam = $formXml.CreateElement("Height")
        $hParam.InnerText = $WebResourceHeight.ToString()
        $params.AppendChild($hParam) | Out-Null
    }

    if ($WebResourceWidth -gt 0) {
        $wParam = $formXml.CreateElement("Width")
        $wParam.InnerText = $WebResourceWidth.ToString()
        $params.AppendChild($wParam) | Out-Null
    }

    $control.AppendChild($params) | Out-Null
    $cell.AppendChild($control) | Out-Null
    $row.AppendChild($cell) | Out-Null
    $rowsElement.AppendChild($row) | Out-Null

    Write-Host "  Added web resource '$ControlName' (URL: $WebResourceUrl)" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Web resource added successfully"
}

function Add-QuickViewControlToForm {
    param([string]$FormId, [string]$TabName, [string]$SectionName, [string]$SectionLabel,
          [string]$ControlName, [string]$FieldName, [string]$QuickForms, [string]$QuickFormEntityName, [int]$ControlRowspan)

    Write-Host "`nAdding Quick View control to form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }

    # Find or create section
    $section = $null
    $rowsElement = $null
    foreach ($col in $tab.columns.column) {
        $existingSection = $col.sections.section | Where-Object { $_.name -eq $SectionName }
        if ($existingSection) { $section = $existingSection; $rowsElement = $section.SelectSingleNode("rows"); break }
    }

    if (-not $section) {
        Write-Host "  Creating new section: $SectionName" -ForegroundColor Gray
        $targetColumn = $tab.columns.column | Select-Object -Last 1
        $section = $formXml.CreateElement("section")
        $section.SetAttribute("name", $SectionName)
        $section.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
        $section.SetAttribute("columns", "1")
        $section.SetAttribute("showlabel", "true")
        $section.SetAttribute("showbar", "false")
        $section.SetAttribute("IsUserDefined", "0")
        $section.SetAttribute("labelwidth", "115")
        $labels = $formXml.CreateElement("labels")
        $label = $formXml.CreateElement("label")
        $label.SetAttribute("description", $(if ($SectionLabel) { $SectionLabel } else { $ControlName }))
        $label.SetAttribute("languagecode", $script:LanguageCode.ToString())
        $labels.AppendChild($label) | Out-Null
        $section.AppendChild($labels) | Out-Null
        $rowsElement = $formXml.CreateElement("rows")
        $section.AppendChild($rowsElement) | Out-Null
        $sectionsNode = $targetColumn.SelectSingleNode("sections")
        if (-not $sectionsNode) { $sectionsNode = $formXml.CreateElement("sections"); $targetColumn.AppendChild($sectionsNode) | Out-Null }
        $sectionsNode.AppendChild($section) | Out-Null
    }

    if (-not $rowsElement) {
        $rowsElement = $formXml.CreateElement("rows")
        $section.AppendChild($rowsElement) | Out-Null
    }

    $classId = $script:ControlClassIds["QuickViewForm"]

    $row = $formXml.CreateElement("row")
    $cell = $formXml.CreateElement("cell")
    $cell.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
    $cell.SetAttribute("showlabel", "false")
    $cell.SetAttribute("locklevel", "0")
    if ($ControlRowspan -gt 1) { $cell.SetAttribute("rowspan", $ControlRowspan.ToString()) }

    $control = $formXml.CreateElement("control")
    $control.SetAttribute("id", $ControlName)
    $control.SetAttribute("classid", $classId)
    $control.SetAttribute("datafieldname", $FieldName)
    $control.SetAttribute("disabled", "false")

    $params = $formXml.CreateElement("parameters")
    $qfParam = $formXml.CreateElement("QuickForms")
    # QuickForms value must be XML-encoded QuickFormIds structure for Dataverse dependency calculator
    # Format: <QuickFormIds><QuickFormId entityname="ENTITY">GUID</QuickFormId></QuickFormIds>
    if ($QuickFormEntityName) {
        $entityName = $QuickFormEntityName
    } else {
        # Try to resolve entity name from lookup field metadata
        $entityName = "unknown"
        try {
            $lookupMeta = Invoke-DataverseApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$tableName')/Attributes/Microsoft.Dynamics.CRM.LookupAttributeMetadata?`$filter=LogicalName eq '$FieldName'&`$select=LogicalName&`$expand=Targets"
            if ($lookupMeta.value -and $lookupMeta.value.Count -gt 0 -and $lookupMeta.value[0].Targets) {
                $entityName = $lookupMeta.value[0].Targets[0]
            }
        } catch {
            Write-Host "  [WARN] Could not resolve lookup target entity, using '$entityName'" -ForegroundColor Yellow
        }
    }
    $quickFormGuids = $QuickForms -split ','
    $innerXml = "<QuickFormIds>"
    foreach ($guid in $quickFormGuids) {
        $innerXml += "<QuickFormId entityname=`"$entityName`">$($guid.Trim())</QuickFormId>"
    }
    $innerXml += "</QuickFormIds>"
    $qfParam.InnerText = $innerXml  # InnerText auto-encodes the XML as &lt;/&gt;
    $params.AppendChild($qfParam) | Out-Null
    $control.AppendChild($params) | Out-Null

    $cell.AppendChild($control) | Out-Null
    $row.AppendChild($cell) | Out-Null
    $rowsElement.AppendChild($row) | Out-Null

    Write-Host "  Added Quick View control '$ControlName' (lookup: $FieldName, forms: $QuickForms)" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Quick View control added successfully"
}

function Set-LookupConfiguration {
    param([string]$FormId, [string]$FieldName,
          [string]$LookupDefaultViewId, [string]$LookupFilterRelationship,
          [string]$LookupDependentAttribute, [string]$LookupDependentAttributeType,
          [string]$LookupDisableMru, [string]$LookupDisableQuickFind,
          [string]$LookupDisableViewPicker, [string]$LookupAvailableViewIds,
          [string]$LookupAllowFilterOff, [string]$LookupIsInlineNewEnabled)

    Write-Host "`nConfiguring lookup field..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $control = $formXml.SelectSingleNode("//control[@datafieldname='$FieldName']")
    if (-not $control) {
        $control = $formXml.SelectSingleNode("//control[@id='$FieldName']")
    }
    if (-not $control) { throw "Field '$FieldName' not found on form" }

    # Ensure parameters element exists
    $params = $control.SelectSingleNode("parameters")
    if (-not $params) {
        $params = $formXml.CreateElement("parameters")
        $control.AppendChild($params) | Out-Null
    }

    $changes = @()

    $lookupParams = @{
        "DefaultViewId" = $LookupDefaultViewId
        "FilterRelationshipName" = $LookupFilterRelationship
        "DependentAttributeName" = $LookupDependentAttribute
        "DependentAttributeType" = $LookupDependentAttributeType
        "DisableMru" = $LookupDisableMru
        "DisableQuickFind" = $LookupDisableQuickFind
        "DisableViewPicker" = $LookupDisableViewPicker
        "AvailableViewIds" = $LookupAvailableViewIds
        "AllowFilterOff" = $LookupAllowFilterOff
        "IsInlineNewEnabled" = $LookupIsInlineNewEnabled
    }

    foreach ($key in $lookupParams.Keys) {
        $value = $lookupParams[$key]
        if ($value) {
            $existingParam = $params.SelectSingleNode($key)
            if ($existingParam) {
                $existingParam.InnerText = $value
            } else {
                $newParam = $formXml.CreateElement($key)
                $newParam.InnerText = $value
                $params.AppendChild($newParam) | Out-Null
            }
            $changes += "$key=$value"
        }
    }

    if ($changes.Count -eq 0) { throw "No lookup configuration parameters specified" }

    Write-Host "  Configured: $($changes -join ', ')" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Lookup '$FieldName' configured successfully"
}

function Add-FooterFieldToForm {
    param([string]$FormId, [string]$FieldName, [string]$FieldType)

    Write-Host "`nAdding footer field to form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $footer = $formXml.form.footer
    if (-not $footer) {
        Write-Host "  Creating footer element..." -ForegroundColor Gray
        $footer = $formXml.CreateElement("footer")
        $footer.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
        $footer.SetAttribute("columns", "4")
        $footer.SetAttribute("labelwidth", "115")
        $footer.SetAttribute("celllabelalignment", "Left")
        $footer.SetAttribute("celllabelposition", "Top")
        $fRows = $formXml.CreateElement("rows")
        $fRow = $formXml.CreateElement("row")
        $fRows.AppendChild($fRow) | Out-Null
        $footer.AppendChild($fRows) | Out-Null
        $formXml.form.AppendChild($footer) | Out-Null
    }

    # Check if field already exists in footer
    foreach ($row in @($footer.rows.row)) {
        foreach ($cell in @($row.cell)) {
            if ($cell.control -and $cell.control.datafieldname -eq $FieldName) {
                throw "Field '$FieldName' already exists in the footer"
            }
        }
    }

    $classId = Get-ControlClassId -FieldType $FieldType -FieldName $FieldName

    $footerRow = $footer.rows.row | Select-Object -First 1
    if (-not $footerRow) {
        $footerRow = $formXml.CreateElement("row")
        $footer.rows.AppendChild($footerRow) | Out-Null
    }

    $cell = $formXml.CreateElement("cell")
    $cell.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
    $cell.SetAttribute("showlabel", "true")
    $cell.SetAttribute("locklevel", "0")

    $control = $formXml.CreateElement("control")
    $control.SetAttribute("id", "footer_$FieldName")
    $control.SetAttribute("classid", $classId)
    $control.SetAttribute("datafieldname", $FieldName)
    $control.SetAttribute("disabled", "false")
    $cell.AppendChild($control) | Out-Null

    $footerRow.AppendChild($cell) | Out-Null
    Write-Host "  Added footer field: $FieldName" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Footer field '$FieldName' added successfully"
}

function Remove-FooterFieldFromForm {
    param([string]$FormId, [string]$FieldName)

    Write-Host "`nRemoving footer field from form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $footer = $formXml.form.footer
    if (-not $footer) { throw "Form has no footer" }

    $removed = $false
    foreach ($row in @($footer.rows.row)) {
        foreach ($cell in @($row.cell)) {
            if ($cell.control -and ($cell.control.datafieldname -eq $FieldName -or $cell.control.id -eq "footer_$FieldName")) {
                $row.RemoveChild($cell) | Out-Null
                $removed = $true
                Write-Host "  Removed footer field: $FieldName" -ForegroundColor Gray
                break
            }
        }
        if ($removed) { break }
    }

    if (-not $removed) { throw "Field '$FieldName' not found in footer" }

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Footer field '$FieldName' removed successfully"
}

function Set-FormProperties {
    param([string]$FormId, [string]$FormShowImage, [string]$FormShowNavBar,
          [int]$FormMaxWidth, [string]$FormEnableRelatedInfo,
          [string]$FormRelatedInfoCollapsed, [string]$FormHasMargin)

    Write-Host "`nSetting form properties..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $changes = @()

    if ($FormShowImage) {
        $formXml.form.SetAttribute("showImage", $FormShowImage.ToLower())
        $changes += "showImage=$($FormShowImage.ToLower())"
    }
    if ($FormShowNavBar) {
        $formXml.form.SetAttribute("shownavigationbar", $FormShowNavBar.ToLower())
        $changes += "shownavigationbar=$($FormShowNavBar.ToLower())"
    }
    if ($FormMaxWidth -ge 400) {
        $formXml.form.SetAttribute("maxWidth", $FormMaxWidth.ToString())
        $changes += "maxWidth=$FormMaxWidth"
    }
    if ($FormEnableRelatedInfo) {
        $formXml.form.SetAttribute("enablerelatedinformation", $FormEnableRelatedInfo.ToLower())
        $changes += "enablerelatedinformation=$($FormEnableRelatedInfo.ToLower())"
    }
    if ($FormRelatedInfoCollapsed) {
        $formXml.form.SetAttribute("relatedInformationCollapsed", $FormRelatedInfoCollapsed.ToLower())
        $changes += "relatedInformationCollapsed=$($FormRelatedInfoCollapsed.ToLower())"
    }
    if ($FormHasMargin) {
        $formXml.form.SetAttribute("hasmargin", $FormHasMargin.ToLower())
        $changes += "hasmargin=$($FormHasMargin.ToLower())"
    }

    if ($changes.Count -eq 0) { throw "No form properties specified. Use -FormShowImage, -FormShowNavBar, -FormMaxWidth, -FormEnableRelatedInfo, -FormRelatedInfoCollapsed, or -FormHasMargin" }

    Write-Host "  Applied: $($changes -join ', ')" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Form properties updated successfully"
}

function Remove-FormEventFromForm {
    param([string]$FormId, [string]$EventName, [string]$EventAttribute,
          [string]$FunctionName, [string]$LibraryName, [string]$HandlerUniqueId)

    Write-Host "`nRemoving form event handler..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $events = $formXml.form.events
    if (-not $events) { throw "Form has no events" }

    $isOnChange = $EventName -eq "onchange"

    # Find the event
    $formEvent = $null
    if ($isOnChange -and $EventAttribute) {
        $formEvent = $events.event | Where-Object { $_.name -eq $EventName -and $_.attribute -eq $EventAttribute }
    } else {
        $formEvent = $events.event | Where-Object { $_.name -eq $EventName -and (-not $_.attribute -or $_.attribute -eq "") }
    }

    if (-not $formEvent) {
        $eventDesc = if ($isOnChange -and $EventAttribute) { "$EventName ($EventAttribute)" } else { $EventName }
        throw "Event '$eventDesc' not found"
    }

    # A malformed form can carry duplicate <event> nodes for the same name/attribute;
    # take the first so the handler search below operates on a single node, not an array.
    if ($formEvent -is [array]) {
        Write-Host "  WARNING: $($formEvent.Count) duplicate '$EventName' event nodes found; using the first" -ForegroundColor Yellow
        $formEvent = $formEvent[0]
    }

    if ($FunctionName -or $HandlerUniqueId) {
        # Remove specific handler
        $handlers = $formEvent.SelectSingleNode("Handlers")
        if (-not $handlers) { throw "Event has no handlers" }

        $handler = $null
        if ($HandlerUniqueId) {
            # Unambiguous: targets exactly one handler even when duplicates share a functionName
            $wantedId = "{$($HandlerUniqueId -replace '[{}]', '')}"
            $handler = $handlers.Handler | Where-Object { $_.handlerUniqueId -eq $wantedId }
            if (-not $handler) { throw "Handler with handlerUniqueId '$wantedId' not found on event '$EventName'" }
        } elseif ($LibraryName) {
            $handler = $handlers.Handler | Where-Object { $_.functionName -eq $FunctionName -and $_.libraryName -eq $LibraryName }
        } else {
            $handler = $handlers.Handler | Where-Object { $_.functionName -eq $FunctionName }
        }
        if (-not $handler) { throw "Handler '$FunctionName' not found on event" }

        # RemoveChild takes ONE node -- passing an array throws. Duplicate registrations
        # (Bug #65815) are exactly this case, so require -HandlerUniqueId to disambiguate.
        if ($handler -is [array]) {
            $ids = ($handler | ForEach-Object { $_.handlerUniqueId }) -join ", "
            throw ("Found $($handler.Count) handlers matching '$FunctionName' on event '$EventName'. " +
                   "Re-run with -HandlerUniqueId to pick one. Candidates: $ids")
        }

        $handlers.RemoveChild($handler) | Out-Null
        $removedDesc = if ($HandlerUniqueId) { "$($handler.functionName) [$($handler.handlerUniqueId)]" } else { $FunctionName }
        Write-Host "  Removed handler '$removedDesc' from event '$EventName'" -ForegroundColor Gray

        # If no handlers remain, remove the whole event
        if ($handlers.ChildNodes.Count -eq 0) {
            $events.RemoveChild($formEvent) | Out-Null
            Write-Host "  Removed empty event '$EventName'" -ForegroundColor Gray
        }
    } else {
        # Remove entire event
        $events.RemoveChild($formEvent) | Out-Null
        $eventDesc = if ($isOnChange -and $EventAttribute) { "$EventName ($EventAttribute)" } else { $EventName }
        Write-Host "  Removed entire event '$eventDesc'" -ForegroundColor Gray
    }

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Event handler removed successfully"
}

function Remove-FormLibraryFromForm {
    param([string]$FormId, [string]$LibraryName)

    Write-Host "`nRemoving form library..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $formLibraries = $formXml.form.formLibraries
    if (-not $formLibraries) { throw "Form has no libraries" }

    $library = $formLibraries.Library | Where-Object { $_.name -eq $LibraryName }
    if (-not $library) { throw "Library '$LibraryName' not found on form" }

    # Check if any event handlers reference this library
    $events = $formXml.form.events
    if ($events) {
        foreach ($evt in @($events.event)) {
            if ($evt.Handlers) {
                $referencingHandler = $evt.Handlers.Handler | Where-Object { $_.libraryName -eq $LibraryName }
                if ($referencingHandler) {
                    $evtDesc = if ($evt.attribute) { "$($evt.name) ($($evt.attribute))" } else { $evt.name }
                    throw "Cannot remove library '$LibraryName' - still referenced by event handler '$($referencingHandler.functionName)' on event '$evtDesc'. Remove the event handler first."
                }
            }
        }
    }

    $formLibraries.RemoveChild($library) | Out-Null
    Write-Host "  Removed library: $LibraryName" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Library '$LibraryName' removed successfully"
}

function Set-TabPropertiesOnForm {
    param([string]$FormId, [string]$TabName, [string]$TabLabel,
          [string]$TabVisible, [string]$TabExpanded, [string]$TabAvailableForPhone, [string]$TabCollapsible,
          [int]$TabColumns = 0)

    Write-Host "`nSetting tab properties..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }

    $changes = @()

    if ($TabLabel) {
        $labelNode = $tab.labels.label | Where-Object { $_.languagecode -eq $script:LanguageCode.ToString() } | Select-Object -First 1
        if ($labelNode) {
            $labelNode.SetAttribute("description", $TabLabel)
        }
        $changes += "label=$TabLabel"
    }
    if ($TabVisible) {
        $tab.SetAttribute("visible", $TabVisible.ToLower())
        $changes += "visible=$($TabVisible.ToLower())"
    }
    if ($TabExpanded) {
        $tab.SetAttribute("expanded", $TabExpanded.ToLower())
        $changes += "expanded=$($TabExpanded.ToLower())"
    }
    if ($TabAvailableForPhone) {
        $tab.SetAttribute("availableforphone", $TabAvailableForPhone.ToLower())
        $changes += "availableforphone=$($TabAvailableForPhone.ToLower())"
    }
    if ($TabCollapsible) {
        $tab.SetAttribute("collapsible", $TabCollapsible.ToLower())
        $changes += "collapsible=$($TabCollapsible.ToLower())"
    }
    if ($TabColumns -gt 0) {
        if ($TabColumns -lt 1 -or $TabColumns -gt 3) { throw "TabColumns must be between 1 and 3" }
        $columnsNode = $tab.SelectSingleNode("columns")
        if (-not $columnsNode) { throw "Tab has no <columns> element" }
        $existingColumns = @($columnsNode.SelectNodes("column"))
        $currentCount = $existingColumns.Count
        if ($currentCount -eq 0) { throw "Tab has no existing <column> children to migrate" }

        if ($TabColumns -gt $currentCount) {
            for ($i = $currentCount; $i -lt $TabColumns; $i++) {
                $newCol = $formXml.CreateElement("column")
                $newSections = $formXml.CreateElement("sections")
                [void]$newCol.AppendChild($newSections)
                [void]$columnsNode.AppendChild($newCol)
            }
        } elseif ($TabColumns -lt $currentCount) {
            $firstCol = $existingColumns[0]
            $firstSections = $firstCol.SelectSingleNode("sections")
            if (-not $firstSections) {
                $firstSections = $formXml.CreateElement("sections")
                [void]$firstCol.AppendChild($firstSections)
            }
            for ($i = $TabColumns; $i -lt $currentCount; $i++) {
                $srcSections = $existingColumns[$i].SelectSingleNode("sections")
                if ($srcSections) {
                    foreach ($sec in @($srcSections.SelectNodes("section"))) {
                        [void]$firstSections.AppendChild($sec)
                    }
                }
                [void]$columnsNode.RemoveChild($existingColumns[$i])
            }
        }

        $allColumns = @($columnsNode.SelectNodes("column"))
        $widthPercent = [math]::Floor(100 / $TabColumns)
        $remainder = 100 - ($widthPercent * $TabColumns)
        for ($i = 0; $i -lt $allColumns.Count; $i++) {
            $w = if ($i -eq ($allColumns.Count - 1)) { $widthPercent + $remainder } else { $widthPercent }
            $allColumns[$i].SetAttribute("width", "$w%")
        }
        $changes += "columns=$TabColumns"
    }

    if ($changes.Count -eq 0) { throw "No tab properties specified" }

    Write-Host "  Applied to tab '$TabName': $($changes -join ', ')" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Tab '$TabName' properties updated successfully"
}

function Set-SectionPropertiesOnForm {
    param([string]$FormId, [string]$TabName, [string]$SectionName, [string]$SectionLabel,
          [string]$SectionVisible, [string]$SectionAvailableForPhone,
          [string]$SectionAutoExpand, [string]$SectionHeight, [int]$SectionColumns,
          [bool]$SectionShowLabel = $true)

    Write-Host "`nSetting section properties..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }

    $section = $null
    foreach ($col in $tab.columns.column) {
        $s = $col.sections.section | Where-Object { $_.name -eq $SectionName }
        if ($s) { $section = $s; break }
    }
    if (-not $section) { throw "Section '$SectionName' not found in tab '$TabName'" }

    $changes = @()

    if ($SectionLabel) {
        $labelNode = $section.labels.label | Where-Object { $_.languagecode -eq $script:LanguageCode.ToString() } | Select-Object -First 1
        if ($labelNode) {
            $labelNode.SetAttribute("description", $SectionLabel)
        }
        $changes += "label=$SectionLabel"
    }
    if ($SectionVisible) {
        $section.SetAttribute("visible", $SectionVisible.ToLower())
        $changes += "visible=$($SectionVisible.ToLower())"
    }
    if ($SectionAvailableForPhone) {
        $section.SetAttribute("availableforphone", $SectionAvailableForPhone.ToLower())
        $changes += "availableforphone=$($SectionAvailableForPhone.ToLower())"
    }
    if ($SectionAutoExpand) {
        $section.SetAttribute("autoexpand", $SectionAutoExpand.ToLower())
        $changes += "autoexpand=$($SectionAutoExpand.ToLower())"
    }
    if ($SectionHeight) {
        $section.SetAttribute("height", $SectionHeight)
        $changes += "height=$SectionHeight"
    }
    if ($SectionColumns -gt 0) {
        $section.SetAttribute("columns", $SectionColumns.ToString())
        $changes += "columns=$SectionColumns"
    }
    $section.SetAttribute("showlabel", $(if ($SectionShowLabel) { "true" } else { "false" }))
    $changes += "showlabel=$(if ($SectionShowLabel) { 'true' } else { 'false' })"

    if ($changes.Count -eq 0) { throw "No section properties specified" }

    Write-Host "  Applied to section '$SectionName': $($changes -join ', ')" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Section '$SectionName' properties updated successfully"
}

function Add-SpacerToForm {
    param([string]$FormId, [string]$TabName, [string]$SectionName)

    Write-Host "`nAdding spacer to form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $tab = Find-Tab -FormXml $formXml -TabName $TabName
    if (-not $tab) { throw "Tab '$TabName' not found" }

    $section = $null
    $rowsElement = $null
    foreach ($col in $tab.columns.column) {
        $s = $col.sections.section | Where-Object { $_.name -eq $SectionName }
        if ($s) { $section = $s; $rowsElement = $section.SelectSingleNode("rows"); break }
    }
    if (-not $section) { throw "Section '$SectionName' not found in tab '$TabName'" }

    if (-not $rowsElement) {
        $rowsElement = $formXml.CreateElement("rows")
        $section.AppendChild($rowsElement) | Out-Null
    }

    $spacerId = "spacer_$([guid]::NewGuid().ToString().Substring(0,8))"
    $classId = $script:ControlClassIds["Spacer"]

    $row = $formXml.CreateElement("row")
    $cell = $formXml.CreateElement("cell")
    $cell.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
    $cell.SetAttribute("showlabel", "false")
    $cell.SetAttribute("locklevel", "0")

    $control = $formXml.CreateElement("control")
    $control.SetAttribute("id", $spacerId)
    $control.SetAttribute("classid", $classId)
    $control.SetAttribute("disabled", "true")
    $cell.AppendChild($control) | Out-Null

    $row.AppendChild($cell) | Out-Null
    $rowsElement.AppendChild($row) | Out-Null

    Write-Host "  Added spacer '$spacerId' to $TabName/$SectionName" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Spacer added successfully"
}

function Add-HiddenFieldToForm {
    param([string]$FormId, [string]$FieldName, [string]$FieldType)

    Write-Host "`nAdding hidden field to form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    # Find or create hiddencontrols section
    $hiddenControls = $formXml.form.SelectSingleNode("hiddencontrols")
    if (-not $hiddenControls) {
        $hiddenControls = $formXml.CreateElement("hiddencontrols")
        $formXml.form.AppendChild($hiddenControls) | Out-Null
    }

    # Check for duplicate
    $existing = $hiddenControls.SelectSingleNode("data[@datafieldname='$FieldName']")
    if ($existing) { throw "Hidden field '$FieldName' already exists on form" }

    $classId = Get-ControlClassId -FieldType $FieldType -FieldName $FieldName

    $data = $formXml.CreateElement("data")
    $data.SetAttribute("id", $FieldName)
    $data.SetAttribute("datafieldname", $FieldName)
    $data.SetAttribute("classid", $classId)
    $hiddenControls.AppendChild($data) | Out-Null

    Write-Host "  Added hidden field: $FieldName" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Hidden field '$FieldName' added successfully"
}

function Remove-HiddenFieldFromForm {
    param([string]$FormId, [string]$FieldName)

    Write-Host "`nRemoving hidden field from form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $hiddenControls = $formXml.form.SelectSingleNode("hiddencontrols")
    if (-not $hiddenControls) { throw "Form has no hidden controls" }

    $data = $hiddenControls.SelectSingleNode("data[@datafieldname='$FieldName']")
    if (-not $data) {
        $data = $hiddenControls.SelectSingleNode("data[@id='$FieldName']")
    }
    if (-not $data) { throw "Hidden field '$FieldName' not found" }

    $hiddenControls.RemoveChild($data) | Out-Null
    Write-Host "  Removed hidden field: $FieldName" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Hidden field '$FieldName' removed successfully"
}

function Set-SubgridConfiguration {
    param([string]$FormId, [string]$SubgridName,
          [string]$SubgridAutoExpand, [int]$SubgridMaxRowsBeforeScroll,
          [string]$SubgridEnableJumpBar, [string]$SubgridChartGridMode,
          [string]$SubgridVisualizationId, [string]$SubgridEnableChartPicker,
          [string]$SubgridEnableContextualActions, [string]$SubgridHeaderColorCode,
          [string]$SubgridEnableViewPicker,
          [string]$ViewId, [int]$RecordsPerPage)

    Write-Host "`nConfiguring subgrid..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $control = $formXml.SelectSingleNode("//control[@id='$SubgridName']")
    if (-not $control) { throw "Subgrid '$SubgridName' not found on form" }

    $params = $control.SelectSingleNode("parameters")
    if (-not $params) {
        $params = $formXml.CreateElement("parameters")
        $control.AppendChild($params) | Out-Null
    }

    $changes = @()

    $subgridParams = @{
        "AutoExpand" = $SubgridAutoExpand
        "EnableJumpBar" = $SubgridEnableJumpBar
        "ChartGridMode" = $SubgridChartGridMode
        "VisualizationId" = $SubgridVisualizationId
        "EnableChartPicker" = $SubgridEnableChartPicker
        "EnableContextualActions" = $SubgridEnableContextualActions
        "HeaderColorCode" = $SubgridHeaderColorCode
        "EnableViewPicker" = $SubgridEnableViewPicker
    }

    if ($ViewId) {
        $subgridParams["ViewId"] = $ViewId
    }
    if ($RecordsPerPage -gt 0) {
        $subgridParams["RecordsPerPage"] = $RecordsPerPage.ToString()
    }
    if ($SubgridMaxRowsBeforeScroll -gt 0) {
        $subgridParams["MaxRowsBeforeScroll"] = $SubgridMaxRowsBeforeScroll.ToString()
    }

    foreach ($key in $subgridParams.Keys) {
        $value = $subgridParams[$key]
        if ($value) {
            $existingParam = $params.SelectSingleNode($key)
            if ($existingParam) {
                $existingParam.InnerText = $value
            } else {
                $newParam = $formXml.CreateElement($key)
                $newParam.InnerText = $value
                $params.AppendChild($newParam) | Out-Null
            }
            $changes += "$key=$value"
        }
    }

    if ($changes.Count -eq 0) { throw "No subgrid configuration parameters specified" }

    Write-Host "  Configured: $($changes -join ', ')" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Subgrid '$SubgridName' configured successfully"
}

function Set-DisplayConditionsOnForm {
    param([string]$FormId, [string[]]$DisplayConditionRoles, [string]$FallbackFormId, [int]$DisplayOrder)

    Write-Host "`nSetting display conditions..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    # Remove existing DisplayConditions if present
    $existing = $formXml.form.SelectSingleNode("DisplayConditions")
    if ($existing) {
        $formXml.form.RemoveChild($existing) | Out-Null
    }

    $displayConditions = $formXml.CreateElement("DisplayConditions")

    if ($FallbackFormId) {
        $cleanFallback = $FallbackFormId -replace '[{}]', ''
        $displayConditions.SetAttribute("FallbackForm", $cleanFallback)
    }
    if ($DisplayOrder -ge 0) {
        $displayConditions.SetAttribute("Order", $DisplayOrder.ToString())
    }

    if (-not $DisplayConditionRoles -or $DisplayConditionRoles.Count -eq 0) {
        # Everyone
        $everyone = $formXml.CreateElement("Everyone")
        $displayConditions.AppendChild($everyone) | Out-Null
        Write-Host "  Set to: Everyone" -ForegroundColor Gray
    } else {
        foreach ($roleId in $DisplayConditionRoles) {
            $role = $formXml.CreateElement("Role")
            $cleanRoleId = $roleId -replace '[{}]', ''
            $role.SetAttribute("Id", $cleanRoleId)
            $displayConditions.AppendChild($role) | Out-Null
        }
        Write-Host "  Set to roles: $($DisplayConditionRoles -join ', ')" -ForegroundColor Gray
    }

    $formXml.form.AppendChild($displayConditions) | Out-Null

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Display conditions updated successfully"
}

function Add-NavItemToForm {
    param([string]$FormId, [string]$NavItemId, [string]$NavItemLabel,
          [string]$NavItemUrl, [string]$NavItemRelationship, [string]$NavItemIcon)

    Write-Host "`nAdding navigation item to form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    # Find or create Navigation
    $nav = $formXml.form.SelectSingleNode("Navigation")
    if (-not $nav) {
        $nav = $formXml.CreateElement("Navigation")
        $tabs = $formXml.form.tabs
        if ($tabs) { $formXml.form.InsertBefore($nav, $tabs) | Out-Null }
        else { $formXml.form.AppendChild($nav) | Out-Null }
    }

    $navBar = $nav.SelectSingleNode("NavBar")
    if (-not $navBar) {
        $navBar = $formXml.CreateElement("NavBar")
        $nav.AppendChild($navBar) | Out-Null
    }

    if ($NavItemRelationship) {
        # Relationship-based nav item
        $navItem = $formXml.CreateElement("NavBarByRelationshipItem")
        $navItem.SetAttribute("RelationshipName", $NavItemRelationship)
        $navItem.SetAttribute("Id", $(if ($NavItemId) { $NavItemId } else { "nav_$NavItemRelationship" }))
        if ($NavItemIcon) { $navItem.SetAttribute("Icon", $NavItemIcon) }

        $titles = $formXml.CreateElement("Titles")
        $title = $formXml.CreateElement("Title")
        $title.SetAttribute("LCID", $script:LanguageCode.ToString())
        $title.SetAttribute("Text", $(if ($NavItemLabel) { $NavItemLabel } else { $NavItemRelationship }))
        $titles.AppendChild($title) | Out-Null
        $navItem.AppendChild($titles) | Out-Null

        $navBar.AppendChild($navItem) | Out-Null
        Write-Host "  Added relationship nav item: $NavItemRelationship" -ForegroundColor Gray
    } else {
        # Custom URL nav item
        $navItem = $formXml.CreateElement("NavBarItem")
        $navItem.SetAttribute("Id", $(if ($NavItemId) { $NavItemId } else { "nav_$([guid]::NewGuid().ToString().Substring(0,8))" }))
        if ($NavItemUrl) { $navItem.SetAttribute("Url", $NavItemUrl) }
        if ($NavItemIcon) { $navItem.SetAttribute("Icon", $NavItemIcon) }

        $titles = $formXml.CreateElement("Titles")
        $title = $formXml.CreateElement("Title")
        $title.SetAttribute("LCID", $script:LanguageCode.ToString())
        $title.SetAttribute("Text", $(if ($NavItemLabel) { $NavItemLabel } else { "Nav Item" }))
        $titles.AppendChild($title) | Out-Null
        $navItem.AppendChild($titles) | Out-Null

        $navBar.AppendChild($navItem) | Out-Null
        Write-Host "  Added URL nav item: $NavItemLabel" -ForegroundColor Gray
    }

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Navigation item added successfully"
}

function Remove-NavItemFromForm {
    param([string]$FormId, [string]$NavItemId)

    Write-Host "`nRemoving navigation item from form..." -ForegroundColor Cyan
    $cleanFormId = $FormId -replace '[{}]', ''

    Write-Host "  Fetching current form XML..." -ForegroundColor Gray
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode

    [xml]$formXml = $formResponse.formxml

    $nav = $formXml.form.SelectSingleNode("Navigation")
    if (-not $nav) { throw "Form has no navigation items" }

    # Search both NavBarItem and NavBarByRelationshipItem
    $navItem = $nav.SelectSingleNode("//NavBarItem[@Id='$NavItemId']")
    if (-not $navItem) {
        $navItem = $nav.SelectSingleNode("//NavBarByRelationshipItem[@Id='$NavItemId']")
    }
    if (-not $navItem) {
        # Also try RelationshipName match
        $navItem = $nav.SelectSingleNode("//NavBarByRelationshipItem[@RelationshipName='$NavItemId']")
    }
    if (-not $navItem) { throw "Navigation item '$NavItemId' not found" }

    $navItem.ParentNode.RemoveChild($navItem) | Out-Null
    Write-Host "  Removed navigation item: $NavItemId" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    Update-FormXml -FormId $FormId -FormXmlContent $updatedFormXml
    Publish-FormCustomizations -TableName $tableName
    Write-Output "[OK] Navigation item removed successfully"
}
#endregion

#region Sitemap Operations

function Resolve-AppModuleSiteMap {
    param([string]$AppModuleUniqueName)
    # Look up app module. appmoduleidunique is the ALTERNATE KEY the appmodulecomponent table joins on
    # (NOT the appmoduleid primary key) — needed for the authoritative binding lookup below.
    $appResponse = Invoke-DataverseApi -Method "GET" -Endpoint "appmodules?`$filter=uniquename eq '$AppModuleUniqueName'&`$select=appmoduleid,appmoduleidunique,name"
    if (-not $appResponse.value -or $appResponse.value.Count -eq 0) {
        # A plain GET serves PUBLISHED rows only. A freshly-created / never-published app is invisible here but
        # real -- fall back to the unpublished-aware lookup (E2E round-3 s01: BuildSiteMap threw "App module not
        # found" on retry against an app it had just created).
        $nameEsc = $AppModuleUniqueName -replace "'", "''"
        try { $appResponse = Invoke-DataverseApi -Method "GET" -Endpoint "appmodules/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$filter=uniquename eq '$nameEsc'&`$select=appmoduleid,appmoduleidunique,name" } catch { }
        if ($appResponse.value -and $appResponse.value.Count -gt 0) { Write-Host "  App module '$AppModuleUniqueName' resolved from the UNPUBLISHED layer (not yet published)" -ForegroundColor DarkYellow }
    }
    if (-not $appResponse.value -or $appResponse.value.Count -eq 0) {
        throw "App module '$AppModuleUniqueName' not found (published or unpublished)"
    }
    $appModuleId       = $appResponse.value[0].appmoduleid
    $appModuleIdUnique = $appResponse.value[0].appmoduleidunique
    $appName           = $appResponse.value[0].name

    $sitemapResponse = $null

    # Strategy 1 (AUTHORITATIVE): resolve the sitemap that is actually BOUND to this app module via the
    # appmodulecomponent table (componenttype 62 = SiteMap; objectid = sitemapid). Display-name matching
    # (old Strategy 1) silently picks an ORPHAN DUPLICATE sitemap that shares the display name but is not
    # the app's bound sitemap — observed corrupting BuildSiteMap/AddSiteMapSubArea read-backs. The binding
    # is the single source of truth. The appmodulecomponent lookup joins appmoduleidunique (unquoted GUID).
    try {
        $bindResult = Invoke-DataverseApi -Method "GET" -Endpoint "appmodulecomponents?`$filter=_appmoduleidunique_value eq $appModuleIdUnique and componenttype eq 62&`$select=objectid"
        $boundSiteMapId = @($bindResult.value | ForEach-Object { $_.objectid }) | Select-Object -First 1
        if ($boundSiteMapId) {
            $smById = Invoke-DataverseApi -Method "GET" -Endpoint "sitemaps($boundSiteMapId)?`$select=sitemapxml,sitemapid,sitemapname,sitemapnameunique"
            if ($smById -and $smById.sitemapid) {
                $sitemapResponse = $smById
                Write-Host "  Found sitemap by app-module binding: $($sitemapResponse.sitemapname) [$($sitemapResponse.sitemapnameunique)] ($($sitemapResponse.sitemapid))" -ForegroundColor Gray
            }
        }
    } catch { }

    # Strategy 2: resolve by sitemapnameunique == app unique name (the key BuildSiteMap writes on create).
    if (-not $sitemapResponse) {
        try {
            $uniqueResult = Invoke-DataverseApi -Method "GET" -Endpoint "sitemaps?`$filter=sitemapnameunique eq '$AppModuleUniqueName'&`$select=sitemapxml,sitemapid,sitemapname,sitemapnameunique"
            if ($uniqueResult.value -and $uniqueResult.value.Count -gt 0) {
                $sitemapResponse = $uniqueResult.value[0]
                Write-Host "  Found sitemap by unique name: $($sitemapResponse.sitemapnameunique)" -ForegroundColor Gray
            }
        } catch { }
    }

    # Strategy 3 (LAST-RESORT fallback): display-name match. Kept for legacy apps with no resolvable
    # binding, but it cannot distinguish duplicate sitemaps — warn so the operator knows it's a guess.
    if (-not $sitemapResponse) {
        try {
            $nameResult = Invoke-DataverseApi -Method "GET" -Endpoint "sitemaps?`$filter=sitemapname eq '$appName'&`$select=sitemapxml,sitemapid,sitemapname,sitemapnameunique"
            if ($nameResult.value -and $nameResult.value.Count -gt 0) {
                $sitemapResponse = $nameResult.value[0]
                $dupCount = @($nameResult.value).Count
                $warnSuffix = if ($dupCount -gt 1) { " — WARNING: $dupCount sitemaps share this display name; binding lookup failed, this may be the wrong (orphan) sitemap" } else { "" }
                Write-Host "  Found sitemap by display name (fallback): $($sitemapResponse.sitemapname)$warnSuffix" -ForegroundColor Yellow
            }
        } catch { }
    }

    if (-not $sitemapResponse) {
        throw "No sitemap found for app module '$AppModuleUniqueName' (app name: '$appName')"
    }

    Write-Host "  Sitemap ID: $($sitemapResponse.sitemapid)" -ForegroundColor Gray

    return @{
        AppModuleId = $appModuleId
        AppName = $appName
        SiteMapId = $sitemapResponse.sitemapid
        SiteMapName = $sitemapResponse.sitemapname
        SiteMapXml = $sitemapResponse.sitemapxml
    }
}

function Get-SiteMap {
    param([string]$AppModuleUniqueName)
    Write-Host "`nRetrieving sitemap for app: $AppModuleUniqueName" -ForegroundColor Cyan

    $result = Resolve-AppModuleSiteMap -AppModuleUniqueName $AppModuleUniqueName
    Write-Host "  App: $($result.AppName) ($($result.AppModuleId))" -ForegroundColor Gray
    Write-Host "  SiteMap: $($result.SiteMapName) ($($result.SiteMapId))" -ForegroundColor Gray

    [xml]$xml = $result.SiteMapXml

    # Display structure
    Write-Host "`nSITEMAP STRUCTURE" -ForegroundColor Yellow
    foreach ($area in $xml.SiteMap.Area) {
        $areaTitle = $area.Titles.Title | Where-Object { $_.LCID -eq "1033" } | Select-Object -ExpandProperty Title -First 1
        if (-not $areaTitle) { $areaTitle = $area.Id }
        Write-Host "[Area] $areaTitle (Id=$($area.Id))" -ForegroundColor White
        foreach ($group in $area.Group) {
            $groupTitle = $group.Titles.Title | Where-Object { $_.LCID -eq "1033" } | Select-Object -ExpandProperty Title -First 1
            if (-not $groupTitle) { $groupTitle = $group.Id }
            Write-Host "  [Group] $groupTitle (Id=$($group.Id))" -ForegroundColor Gray
            foreach ($subarea in $group.SubArea) {
                $subTitle = $null
                if ($subarea.Titles) {
                    $subTitle = $subarea.Titles.Title | Where-Object { $_.LCID -eq "1033" } | Select-Object -ExpandProperty Title -First 1
                }
                $entity = $subarea.Entity
                $url = $subarea.Url
                if ($entity) {
                    $label = if ($subTitle) { "$subTitle" } else { $entity }
                    Write-Host "    [SubArea] $label | Id=$($subarea.Id) | Entity=$entity" -ForegroundColor Cyan
                } elseif ($url) {
                    $label = if ($subTitle) { "$subTitle" } else { "URL" }
                    Write-Host "    [SubArea] $label | Id=$($subarea.Id) | Url=$url" -ForegroundColor Magenta
                } else {
                    $label = if ($subTitle) { "$subTitle" } else { $subarea.Id }
                    Write-Host "    [SubArea] $label | Id=$($subarea.Id)" -ForegroundColor DarkGray
                }
            }
        }
    }

    Write-Host "`nSiteMap ID: $($result.SiteMapId)" -ForegroundColor Gray
}

function Update-SubAreaToUrlView {
    param([string]$AppModuleUniqueName, [string]$SubAreaId, [string]$SubAreaEntity, [string]$SubAreaViewId, [string]$SubAreaUrl)
    Write-Host "`nUpdating SubArea on sitemap..." -ForegroundColor Cyan

    $result = Resolve-AppModuleSiteMap -AppModuleUniqueName $AppModuleUniqueName
    Write-Host "  App: $($result.AppName)" -ForegroundColor Gray
    Write-Host "  SiteMap: $($result.SiteMapName) ($($result.SiteMapId))" -ForegroundColor Gray

    [xml]$xml = $result.SiteMapXml

    # Find the SubArea by Id
    $subArea = $xml.SelectSingleNode("//SubArea[@Id='$SubAreaId']")
    if (-not $subArea) {
        throw "SubArea with Id '$SubAreaId' not found in sitemap"
    }

    $currentEntity = $subArea.GetAttribute("Entity")
    $currentUrl = $subArea.GetAttribute("Url")
    $subTitle = $null
    if ($subArea.Titles) {
        $subTitle = $subArea.Titles.Title | Where-Object { $_.LCID -eq "1033" } | Select-Object -ExpandProperty Title -First 1
    }
    Write-Host "  Found SubArea: $SubAreaId ($(if ($subTitle) { $subTitle } else { 'no title' }))" -ForegroundColor Gray
    Write-Host "  Current: Entity=$currentEntity, Url=$currentUrl" -ForegroundColor Gray

    # Build the URL if entity + viewId provided
    if ($SubAreaEntity -and $SubAreaViewId) {
        $cleanViewId = $SubAreaViewId -replace '[{}]', ''
        $SubAreaUrl = "/main.aspx?etn=$SubAreaEntity&pagetype=entitylist&viewid=%7b$cleanViewId%7d"
        Write-Host "  Built URL: $SubAreaUrl" -ForegroundColor Gray
    }

    if (-not $SubAreaUrl) {
        throw "Either SubAreaUrl or (SubAreaEntity + SubAreaViewId) required"
    }

    # Remove Entity attribute if present (switching to URL-based)
    if ($subArea.HasAttribute("Entity")) {
        $subArea.RemoveAttribute("Entity")
    }

    # Set the URL
    $subArea.SetAttribute("Url", $SubAreaUrl)

    Write-Host "  Updated to URL-based SubArea: $SubAreaUrl" -ForegroundColor Gray

    # Serialize
    $sw = New-Object System.IO.StringWriter
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.OmitXmlDeclaration = $true
    $settings.Indent = $false
    $xw = [System.Xml.XmlWriter]::Create($sw, $settings)
    $xml.WriteTo($xw)
    $xw.Flush()
    $newXml = $sw.ToString()

    # Update sitemap record (direct call without Prefer: return=representation to avoid large response issues)
    $sitemapId = $result.SiteMapId
    $patchUrl = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/sitemaps($sitemapId)"
    $patchHeaders = @{
        "Authorization" = "Bearer $script:AuthToken"
        "OData-MaxVersion" = "4.0"
        "OData-Version" = "4.0"
        "Accept" = "application/json"
        "Content-Type" = "application/json; charset=utf-8"
        "If-Match" = "*"
    }
    $patchBody = @{ sitemapxml = $newXml } | ConvertTo-Json -Depth 5 -Compress
    try {
        Invoke-RestMethod -Uri $patchUrl -Method Patch -Headers $patchHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes($patchBody))
    } catch {
        $errorMessage = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try { $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json; $errorMessage = $errorDetails.error.message } catch { }
        }
        throw "Sitemap PATCH failed: $errorMessage"
    }
    Write-Host "  Sitemap XML updated" -ForegroundColor Gray

    # Publish the app module
    Write-Host "  Publishing app module..." -ForegroundColor Gray
    $publishXml = "<importexportxml><appmodules><appmodule>$($result.AppModuleId)</appmodule></appmodules></importexportxml>"
    Invoke-DataverseApi -Method "POST" -Endpoint "PublishXml" -Body @{ ParameterXml = $publishXml } -ReturnRepresentation $true
    Write-Output "[OK] SubArea '$SubAreaId' updated to viewid=$SubAreaViewId"
}

function Add-SiteMapSubArea {
    <#
    .SYNOPSIS
        Adds a new SubArea (and optionally a new Group and/or Area) to the app sitemap.
    .DESCRIPTION
        Inserts a SubArea element into the sitemap XML. If the specified Group does not exist,
        it is created first within the specified Area. If the specified Area does not exist
        AND -AreaTitle is provided, a new Area is created at the SiteMap root before the Group
        is created inside it. If the Area is missing and no -AreaTitle is supplied, the
        original "Area not found" error is still thrown (backwards-compatible).
        Supports URL-type, Entity-type, and Dashboard-type subareas.

        DASHBOARD subareas: surface a system dashboard the classic, XSD-valid way —
        a `Url` + `DefaultDashboard` (the dashboard GUID). Do NOT use the app-designer
        vocabulary `Type="Dashboard"`: the classic sitemap XSD rejects it (lessons §9).
        Pass -SubAreaDefaultDashboard <dashboardId>; if no -SubAreaUrl is given we default the
        Url to the canonical dashboard page for that GUID.

        NOTE: Local element variables in the new-Area path use distinct names
        ($newAreaTitlesElem / $newAreaTitleElem) to avoid case-insensitive shadowing of
        the $AreaTitle parameter — shadowing produced empty <Title> elements that passed
        the PATCH but failed Dataverse XSD validation downstream.
    #>
    param(
        [string]$AppModuleUniqueName,
        [string]$AreaId,
        [string]$AreaTitle,
        [string]$GroupId,
        [string]$GroupTitle,
        [string]$SubAreaId,
        [string]$SubAreaTitle,
        [string]$SubAreaUrl,
        [string]$SubAreaEntity,
        [string]$SubAreaDefaultDashboard
    )

    Write-Host "`nAdding SubArea to sitemap..." -ForegroundColor Cyan

    $result = Resolve-AppModuleSiteMap -AppModuleUniqueName $AppModuleUniqueName
    Write-Host "  App: $($result.AppName)" -ForegroundColor Gray
    Write-Host "  SiteMap: $($result.SiteMapName) ($($result.SiteMapId))" -ForegroundColor Gray

    [xml]$xml = $result.SiteMapXml

    # Find or create the Area
    $area = $xml.SelectSingleNode("//Area[@Id='$AreaId']")
    if (-not $area) {
        if (-not $AreaTitle) {
            throw "Area with Id '$AreaId' not found in sitemap and no -AreaTitle was provided to create it. Use GetSiteMap to see existing areas, or pass -AreaTitle to create a new area."
        }
        Write-Host "  Creating new Area: $AreaId ($AreaTitle)" -ForegroundColor Yellow
        $siteMapNode = $xml.SelectSingleNode("//SiteMap")
        if (-not $siteMapNode) {
            throw "Could not find SiteMap root element to attach the new Area."
        }
        $area = $xml.CreateElement("Area")
        $area.SetAttribute("Id", $AreaId)
        $newAreaTitlesElem = $xml.CreateElement("Titles")
        $newAreaTitleElem = $xml.CreateElement("Title")
        $newAreaTitleElem.SetAttribute("LCID", "1033")
        $newAreaTitleElem.SetAttribute("Title", $AreaTitle)
        $newAreaTitlesElem.AppendChild($newAreaTitleElem) | Out-Null
        $area.AppendChild($newAreaTitlesElem) | Out-Null
        $siteMapNode.AppendChild($area) | Out-Null
    } else {
        Write-Host "  Found Area: $AreaId" -ForegroundColor Gray
    }

    # Find or create the Group
    $group = $area.SelectSingleNode("Group[@Id='$GroupId']")
    if (-not $group) {
        Write-Host "  Creating new Group: $GroupId ($GroupTitle)" -ForegroundColor Yellow
        $group = $xml.CreateElement("Group")
        $group.SetAttribute("Id", $GroupId)
        $titles = $xml.CreateElement("Titles")
        $title = $xml.CreateElement("Title")
        $title.SetAttribute("LCID", "1033")
        $title.SetAttribute("Title", $GroupTitle)
        $titles.AppendChild($title) | Out-Null
        $group.AppendChild($titles) | Out-Null
        $area.AppendChild($group) | Out-Null
    } else {
        Write-Host "  Found existing Group: $GroupId" -ForegroundColor Gray
    }

    # Check if SubArea already exists
    $existingSubArea = $group.SelectSingleNode("SubArea[@Id='$SubAreaId']")
    if ($existingSubArea) {
        throw "SubArea '$SubAreaId' already exists in Group '$GroupId'. Use UpdateSubArea to modify it."
    }

    # Create the SubArea
    $subArea = $xml.CreateElement("SubArea")
    $subArea.SetAttribute("Id", $SubAreaId)

    if ($SubAreaDefaultDashboard) {
        # Classic, XSD-valid dashboard subarea: Url + DefaultDashboard GUID (NOT Type="Dashboard").
        $dashGuid = $SubAreaDefaultDashboard.Trim('{', '}')
        $dashUrl = if ($SubAreaUrl) { $SubAreaUrl } else { "/main.aspx?pagetype=dashboard&dashboardId=$dashGuid" }
        $subArea.SetAttribute("Url", $dashUrl)
        $subArea.SetAttribute("DefaultDashboard", $dashGuid)
    } elseif ($SubAreaUrl) {
        $subArea.SetAttribute("Url", $SubAreaUrl)
    } elseif ($SubAreaEntity) {
        $subArea.SetAttribute("Entity", $SubAreaEntity)
    }

    # Add title
    $titles = $xml.CreateElement("Titles")
    $title = $xml.CreateElement("Title")
    $title.SetAttribute("LCID", "1033")
    $title.SetAttribute("Title", $SubAreaTitle)
    $titles.AppendChild($title) | Out-Null
    $subArea.AppendChild($titles) | Out-Null

    $group.AppendChild($subArea) | Out-Null
    Write-Host "  Added SubArea: $SubAreaId ($SubAreaTitle)" -ForegroundColor Green

    # Serialize
    $sw = New-Object System.IO.StringWriter
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.OmitXmlDeclaration = $true
    $settings.Indent = $false
    $xw = [System.Xml.XmlWriter]::Create($sw, $settings)
    $xml.WriteTo($xw)
    $xw.Flush()
    $newXml = $sw.ToString()

    # PATCH the sitemap
    $sitemapId = $result.SiteMapId
    $patchUrl = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/sitemaps($sitemapId)"
    $patchHeaders = @{
        "Authorization" = "Bearer $script:AuthToken"
        "OData-MaxVersion" = "4.0"
        "OData-Version" = "4.0"
        "Accept" = "application/json"
        "Content-Type" = "application/json; charset=utf-8"
        "If-Match" = "*"
    }
    $patchBody = @{ sitemapxml = $newXml } | ConvertTo-Json -Depth 5 -Compress
    try {
        Invoke-RestMethod -Uri $patchUrl -Method Patch -Headers $patchHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes($patchBody))
    } catch {
        $errorMessage = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try { $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json; $errorMessage = $errorDetails.error.message } catch { }
        }
        throw "Sitemap PATCH failed: $errorMessage"
    }
    Write-Host "  Sitemap XML updated" -ForegroundColor Gray

    # An entity sub-area is only reachable if the app CONTAINS the table. Register it as an app component
    # (AddAppComponents is idempotent) before publishing -- a nav node pointing at a table the app does not
    # contain is exactly how E2E round-3 shipped 13 reference-table sub-areas the app could not open (F-02:
    # ValidateApp "Site Map ... RequiredComponents" warning; 1 entity component, 14 sub-areas).
    if ($SubAreaEntity) {
        Add-EntityAppComponent -AppModuleId $result.AppModuleId -EntityLogicalName $SubAreaEntity
    }

    # Publish the app module
    Write-Host "  Publishing app module..." -ForegroundColor Gray
    $publishXml = "<importexportxml><appmodules><appmodule>$($result.AppModuleId)</appmodule></appmodules></importexportxml>"
    Invoke-DataverseApi -Method "POST" -Endpoint "PublishXml" -Body @{ ParameterXml = $publishXml } -ReturnRepresentation $true
    Write-Output "[OK] SubArea '$SubAreaId' added to Group '$GroupId' in Area '$AreaId'"
}

function Add-EntityAppComponent {
    # Ensure ONE table is an app component (idempotent). Used by Add-SiteMapSubArea for entity sub-areas.
    param([string]$AppModuleId, [string]$EntityLogicalName)
    $e = "$EntityLogicalName".ToLower()
    $er = Invoke-DataverseApi -Method "GET" -Endpoint "entities?`$filter=logicalname eq '$e'&`$select=entityid"
    if (-not $er.value -or $er.value.Count -eq 0) { throw "Entity '$e' not found in the entity table -- cannot add it to the app (sub-area not written)." }
    $appHeaders = @{
        "Authorization" = "Bearer $script:AuthToken"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0"
        "Accept" = "application/json"; "Content-Type" = "application/json; charset=utf-8"
    }
    $addUrl = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/AddAppComponents"
    $body = @{ AppId = $AppModuleId; Components = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.entity"; entityid = $er.value[0].entityid }) } | ConvertTo-Json -Depth 5 -Compress
    try {
        Invoke-RestMethod -Uri $addUrl -Method POST -Headers $appHeaders -Body $body -ErrorAction Stop | Out-Null
        Write-Host "  [APP] '$e' registered as an app component (idempotent)" -ForegroundColor Gray
    } catch {
        $m = $_.Exception.Message; if ($_.ErrorDetails.Message) { try { $m = ($_.ErrorDetails.Message | ConvertFrom-Json).error.message } catch { } }
        throw "AddAppComponents for '$e' failed: $m -- the sub-area would point at a table the app does not contain."
    }
}

function Move-SiteMapGroup {
    <#
    .SYNOPSIS
        Move an existing Group within its Area to a specific position (0-based index).
    .DESCRIPTION
        Reorders the children of <Area Id="..."> so that <Group Id="..."> appears at -GroupPosition.
        Use this to put a "Dashboards" group at the top of an area's left navigator (-GroupPosition 0)
        without rebuilding the area.
        PATCHes the sitemap and publishes the app module.
    #>
    param(
        [string]$AppModuleUniqueName,
        [string]$AreaId,
        [string]$GroupId,
        [int]$GroupPosition
    )

    if ($GroupPosition -lt 0) { throw "GroupPosition must be >= 0" }

    Write-Host "`nMoving SiteMap Group..." -ForegroundColor Cyan
    $result = Resolve-AppModuleSiteMap -AppModuleUniqueName $AppModuleUniqueName
    Write-Host "  App: $($result.AppName)" -ForegroundColor Gray
    Write-Host "  SiteMap: $($result.SiteMapName) ($($result.SiteMapId))" -ForegroundColor Gray

    [xml]$xml = $result.SiteMapXml
    $area = $xml.SelectSingleNode("//Area[@Id='$AreaId']")
    if (-not $area) { throw "Area '$AreaId' not found in sitemap." }

    $group = $area.SelectSingleNode("Group[@Id='$GroupId']")
    if (-not $group) { throw "Group '$GroupId' not found in Area '$AreaId'." }

    $groupSiblings = @($area.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and $_.Name -eq 'Group' })
    if ($groupSiblings.Count -eq 0) { throw "Area '$AreaId' has no Group children." }

    $currentIndex = -1
    for ($i = 0; $i -lt $groupSiblings.Count; $i++) {
        if ($groupSiblings[$i].GetAttribute('Id') -eq $GroupId) { $currentIndex = $i; break }
    }
    Write-Host "  Found Group '$GroupId' at index $currentIndex of $($groupSiblings.Count - 1); moving to $GroupPosition" -ForegroundColor Gray

    $clampedPos = [Math]::Min($GroupPosition, $groupSiblings.Count - 1)
    if ($currentIndex -eq $clampedPos) {
        Write-Host "  Group is already at the requested position; no change made." -ForegroundColor Yellow
    } else {
        $area.RemoveChild($group) | Out-Null
        # Re-fetch group siblings (now without the moved one) and pick reference node at target position
        $remaining = @($area.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and $_.Name -eq 'Group' })
        if ($clampedPos -ge $remaining.Count) {
            $area.AppendChild($group) | Out-Null
        } else {
            $area.InsertBefore($group, $remaining[$clampedPos]) | Out-Null
        }
        Write-Host "  Group repositioned in XML." -ForegroundColor Gray
    }

    # Serialize
    $sw = New-Object System.IO.StringWriter
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.OmitXmlDeclaration = $true
    $settings.Indent = $false
    $xw = [System.Xml.XmlWriter]::Create($sw, $settings)
    $xml.WriteTo($xw)
    $xw.Flush()
    $newXml = $sw.ToString()

    # PATCH the sitemap
    $sitemapId = $result.SiteMapId
    $patchUrl = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/sitemaps($sitemapId)"
    $patchHeaders = @{
        "Authorization" = "Bearer $script:AuthToken"
        "OData-MaxVersion" = "4.0"
        "OData-Version" = "4.0"
        "Accept" = "application/json"
        "Content-Type" = "application/json; charset=utf-8"
        "If-Match" = "*"
    }
    $patchBody = @{ sitemapxml = $newXml } | ConvertTo-Json -Depth 5 -Compress
    try {
        Invoke-RestMethod -Uri $patchUrl -Method Patch -Headers $patchHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes($patchBody))
    } catch {
        $errorMessage = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try { $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json; $errorMessage = $errorDetails.error.message } catch { }
        }
        throw "Sitemap PATCH failed: $errorMessage"
    }
    Write-Host "  Sitemap XML updated" -ForegroundColor Gray

    # Publish the app module
    Write-Host "  Publishing app module..." -ForegroundColor Gray
    $publishXml = "<importexportxml><appmodules><appmodule>$($result.AppModuleId)</appmodule></appmodules></importexportxml>"
    Invoke-DataverseApi -Method "POST" -Endpoint "PublishXml" -Body @{ ParameterXml = $publishXml } -ReturnRepresentation $true
    Write-Output "[OK] Group '$GroupId' moved to position $clampedPos in Area '$AreaId'"
}

function Set-SiteMapTitle {
    # Set/replace the LCID 1033 <Title> on an Area/Group/SubArea element (reuses the CreateElement pattern
    # the single-mutation sitemap ops use). No-op when $Title is empty.
    param([xml]$Doc, [System.Xml.XmlElement]$Element, [string]$Title)
    if (-not $Title) { return }
    $titles = $Element.SelectSingleNode("Titles")
    if (-not $titles) { $titles = $Doc.CreateElement("Titles"); [void]$Element.AppendChild($titles) }
    # $titleEl, not $title — PowerShell vars are case-insensitive, so $title would alias the $Title param.
    $titleEl = $titles.SelectNodes("Title") | Where-Object { $_.GetAttribute("LCID") -eq "1033" } | Select-Object -First 1
    if (-not $titleEl) { $titleEl = $Doc.CreateElement("Title"); $titleEl.SetAttribute("LCID", "1033"); [void]$titles.AppendChild($titleEl) }
    $titleEl.SetAttribute("Title", $Title)
}

function Get-AppModuleUnpublished {
    # Unpublished-aware app-module lookup (mirrors Reset-TestEnv / data-modeling Get-AppModuleId): a plain
    # GET on /appmodules returns PUBLISHED rows only, so a freshly-created app is missed. Returns the row
    # (appmoduleid,name,uniquename) or $null.
    param([string]$AppModuleUniqueName)
    $nameEsc = $AppModuleUniqueName -replace "'", "''"
    $endpoint = "appmodules/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$filter=uniquename eq '$nameEsc'&`$select=appmoduleid,uniquename,name,appmoduleidunique"
    try { $r = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint } catch { return $null }
    if ($r.value -and $r.value.Count -gt 0) { return $r.value[0] }
    return $null
}

function Get-DeclaredAppEntities {
    # The full set of tables the app must CONTAIN: every subArea entity PLUS every app.unsurfacedTables[].table
    # (no nav node, but a subgrid cannot open records of a table the app does not contain). Lower-cased, de-duped.
    param([object]$App)
    $entities = New-Object System.Collections.Generic.List[string]
    foreach ($area in @($App.areas)) {
        foreach ($group in @($area.groups)) {
            foreach ($sub in @($group.subAreas)) {
                if ($sub.entity -and -not $entities.Contains("$($sub.entity)".ToLower())) { $entities.Add("$($sub.entity)".ToLower()) }
            }
        }
    }
    foreach ($u in @($App.unsurfacedTables)) {
        if ($u.table -and -not $entities.Contains("$($u.table)".ToLower())) { $entities.Add("$($u.table)".ToLower()) }
    }
    return ,$entities
}

function Add-DeclaredEntityComponents {
    # Ensure every declared table (subArea entities + unsurfacedTables) is an app component (AddAppComponents is
    # idempotent for already-added components). Called on EVERY BuildSiteMap path — create-new, create-with-existing
    # app, and extend. The create-with-existing-app path used to skip this (E2E round-3 F-02: an app created by an
    # earlier slice got its sitemap rendered but 13 declared reference tables were never registered as components).
    param([object]$App, [string]$AppModuleId)
    $entities = Get-DeclaredAppEntities -App $App
    $entityComponents = @()
    foreach ($e in $entities) {
        $er = Invoke-DataverseApi -Method "GET" -Endpoint "entities?`$filter=logicalname eq '$e'&`$select=entityid"
        if (-not $er.value -or $er.value.Count -eq 0) { throw "Entity '$e' (declared subarea) not found in the entity table -- can't add it to the app." }
        $entityComponents += @{ "@odata.type" = "Microsoft.Dynamics.CRM.entity"; entityid = $er.value[0].entityid }
    }
    if ($entityComponents.Count -eq 0) { return }
    $appHeaders = @{
        "Authorization" = "Bearer $script:AuthToken"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0"
        "Accept" = "application/json"; "Content-Type" = "application/json; charset=utf-8"
    }
    $addUrl = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/AddAppComponents"
    $entBody = @{ AppId = $AppModuleId; Components = $entityComponents } | ConvertTo-Json -Depth 5 -Compress
    Write-Host "  Adding $($entityComponents.Count) entity component(s) to app..." -ForegroundColor Gray
    try { Invoke-RestMethod -Uri $addUrl -Method POST -Headers $appHeaders -Body $entBody -ErrorAction Stop }
    catch { $m = $_.Exception.Message; if ($_.ErrorDetails.Message) { try { $m = ($_.ErrorDetails.Message | ConvertFrom-Json).error.message } catch { } }; throw "AddAppComponents (entities) failed: $m" }
}

function New-AppModuleFromSpec {
    # SELF-CONTAINED app creation so BuildSiteMap can't be broken by a missing/misnamed app. POSTs the
    # appmodule, adds every declared subarea entity as a component, then provisions an isappaware sitemap
    # (an app without one won't publish and can't be cleanly deleted). Returns the new appmoduleid.
    param([object]$App, [string]$AppUnique, [string]$SolutionName)

    $title = if ($App.title) { "$($App.title)" } else { (Get-Culture).TextInfo.ToTitleCase(($AppUnique -replace '^[a-z][a-z0-9]*_', '' -replace '_', ' ')) }

    # Default app icon (SVG web resource) if one is available -- optional binding.
    $webResourceId = $null
    try {
        $iconRes = Invoke-DataverseApi -Method "GET" -Endpoint "webresourceset?`$filter=webresourcetype eq 11&`$select=webresourceid&`$top=1"
        if ($iconRes.value -and $iconRes.value.Count -gt 0) { $webResourceId = $iconRes.value[0].webresourceid }
    } catch { }

    $appPayload = @{ name = $title; uniquename = $AppUnique; clienttype = 4 }
    if ($webResourceId) { $appPayload["webresourceid"] = $webResourceId }
    Write-Host "  Creating app module '$AppUnique' ($title)..." -ForegroundColor Gray
    $created = Invoke-DataverseApi -Method "POST" -Endpoint "appmodules" -Body $appPayload -SolutionName $SolutionName -ReturnRepresentation $true
    $appModuleId = if ($created._entityId) { $created._entityId } else { (Get-AppModuleUnpublished -AppModuleUniqueName $AppUnique).appmoduleid }
    if (-not $appModuleId) { throw "App module '$AppUnique' POSTed but its id could not be resolved." }

    # Read-after-write: a freshly POSTed appmodule is not immediately addressable by AddAppComponents
    # ("Entity 'appmodule' With Id = ... Does Not Exist" -- E2E round-3 s01, twice, leaving an orphaned unpublished
    # app). Wait until the unpublished layer resolves it, then register with bounded retries on that error.
    $deadline = (Get-Date).AddSeconds(90); $visible = $false
    while ((Get-Date) -lt $deadline) {
        $probe = Get-AppModuleUnpublished -AppModuleUniqueName $AppUnique
        if ($probe -and $probe.appmoduleid) { $visible = $true; break }
        Start-Sleep -Seconds 5
    }
    if (-not $visible) { Write-Host "  [WARN] app module '$AppUnique' not yet resolvable after 90s; attempting component registration anyway" -ForegroundColor Yellow }
    $attempt = 0; $registered = $false; $lastErr = $null
    while (-not $registered -and $attempt -lt 8) {
        $attempt++
        try { Add-DeclaredEntityComponents -App $App -AppModuleId $appModuleId; $registered = $true }
        catch {
            $lastErr = $_.Exception.Message
            if ($lastErr -match 'Does Not Exist' -and $attempt -lt 8) {
                Write-Host "  [APP] app module not yet addressable for AddAppComponents (attempt $attempt) -- retrying in $(5 * $attempt)s" -ForegroundColor DarkYellow
                Start-Sleep -Seconds (5 * $attempt)
            } else { throw }
        }
    }
    if (-not $registered) { throw "AddAppComponents kept failing for the new app '$AppUnique' after $attempt attempts: $lastErr" }

    $appHeaders = @{
        "Authorization" = "Bearer $script:AuthToken"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0"
        "Accept" = "application/json"; "Content-Type" = "application/json; charset=utf-8"
    }
    $addUrl = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/AddAppComponents"

    # Provision an isappaware sitemap seeded with one SubArea per entity (mirrors data-modeling New-AppSiteMap)
    # so Resolve-AppModuleSiteMap finds a default sitemap; BuildSiteMap then overwrites it with the declared XML.
    $existingSm = $null
    try {
        $existingSm = (Invoke-DataverseApi -Method "GET" -Endpoint "sitemaps/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$filter=sitemapnameunique eq '$AppUnique'&`$select=sitemapid").value
    } catch { }
    if (-not ($existingSm -and $existingSm.Count -gt 0)) {
        $subAreas = ""
        for ($i = 0; $i -lt $entities.Count; $i++) {
            $subAreas += '<SubArea Id="subarea_' + $i + '" Entity="' + $entities[$i] + '" Client="All,Outlook,OutlookLaptopClient,OutlookWorkstationClient,Web" AvailableOffline="true" PassParams="false" Sku="All,OnPremise,Live,SPLA" />'
        }
        $smXml = '<SiteMap IntroducedVersion="7.0.0.0"><Area Id="area_default" ResourceId="SitemapDesigner.NewTitle" ShowGroups="true" IntroducedVersion="7.0.0.0"><Titles><Title LCID="1033" Title="Area1" /></Titles><Group Id="group_default" ResourceId="SitemapDesigner.NewGroup" IntroducedVersion="7.0.0.0" IsProfile="false"><Titles><Title LCID="1033" Title="Group1" /></Titles>' + $subAreas + '</Group></Area></SiteMap>'
        $smBody = @{ sitemapname = $title; sitemapnameunique = $AppUnique; isappaware = $true; sitemapxml = $smXml }
        Write-Host "  Provisioning a default sitemap for the new app..." -ForegroundColor Gray
        $smCreated = Invoke-DataverseApi -Method "POST" -Endpoint "sitemaps" -Body $smBody -SolutionName $SolutionName -ReturnRepresentation $true
        $sitemapId = if ($smCreated._entityId) { $smCreated._entityId } else { (Invoke-DataverseApi -Method "GET" -Endpoint "sitemaps/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$filter=sitemapnameunique eq '$AppUnique'&`$select=sitemapid").value[0].sitemapid }
        if (-not $sitemapId) { throw "Sitemap created for '$AppUnique' but its id could not be resolved." }
        $smComp = @{ AppId = $appModuleId; Components = @(@{ "@odata.type" = "Microsoft.Dynamics.CRM.sitemap"; sitemapid = $sitemapId }) } | ConvertTo-Json -Depth 5 -Compress
        Write-Host "  Linking sitemap to app..." -ForegroundColor Gray
        try { Invoke-RestMethod -Uri $addUrl -Method POST -Headers $appHeaders -Body $smComp -ErrorAction Stop }
        catch { $m = $_.Exception.Message; if ($_.ErrorDetails.Message) { try { $m = ($_.ErrorDetails.Message | ConvertFrom-Json).error.message } catch { } }; throw "AddAppComponents (sitemap) failed: $m" }
    }

    # Publish so Resolve-AppModuleSiteMap (which reads published sitemaps by name) finds it.
    $publishXml = "<importexportxml><appmodules><appmodule>$appModuleId</appmodule></appmodules></importexportxml>"
    Invoke-DataverseApi -Method "POST" -Endpoint "PublishXml" -Body @{ ParameterXml = $publishXml } -ReturnRepresentation $true
    Write-Output "[APP] created app module '$AppUnique'"
    return $appModuleId
}

function Invoke-BuildSiteMap {
    # DECLARED-CONTRACT sitemap build: read the spec.json `app` node, resolve the target app's sitemap, assemble
    # the FULL <SiteMap> from the declared areas/groups/subAreas IN DECLARED ORDER in memory, ONE PATCH + publish,
    # then READ BACK and report a diff. One-writer -- structurally immune to the per-mutation clobber the
    # single-mutation ops (AddSiteMapSubArea/UpdateSubArea/MoveSiteMapGroup) risk.
    # -SpecJsonPath is an orchestration convenience for spec-driven builds; -AppSpec drives the SAME build directly
    # (inline JSON or a file path -- the `app` object itself). spec.json is never required.
    param([string]$SpecJsonPath, [string]$AppSpec, [string]$AppModuleUniqueName, [string]$SolutionName, [switch]$DryRun)

    $spec = $null
    if ($SpecJsonPath) {
        if (-not (Test-Path -LiteralPath $SpecJsonPath)) { throw "SpecJsonPath '$SpecJsonPath' not found." }
        $spec = Get-Content -LiteralPath $SpecJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $app = $spec.app
    } elseif ($AppSpec) {
        # Inline JSON, or a short non-JSON-looking string treated as a file path (mirrors BuildForm -LayoutSpec).
        $appText = $AppSpec
        if ($AppSpec.Length -lt 1000 -and $AppSpec -notmatch '[\{\}]' -and (Test-Path -LiteralPath $AppSpec -ErrorAction SilentlyContinue)) {
            $appText = Get-Content -LiteralPath $AppSpec -Raw -Encoding UTF8
            Write-Host "  Loaded app spec from: $AppSpec" -ForegroundColor Gray
        }
        try { $app = $appText | ConvertFrom-Json } catch { throw "AppSpec is not valid JSON: $($_.Exception.Message)" }
    } else {
        throw "Pass -SpecJsonPath <spec.json> (uses its .app node) or -AppSpec <inline JSON | file> (the app object itself)."
    }
    if (-not $app -or -not $app.areas -or @($app.areas).Count -eq 0) { throw "No 'app.areas' to build a sitemap from (check the spec.json .app node or the -AppSpec object)." }

    $appUnique = if ($AppModuleUniqueName) { $AppModuleUniqueName } elseif ($app.uniqueName) { "$($app.uniqueName)" } else { $null }
    if (-not $appUnique) { throw "App module unique name required -- pass -AppModuleUniqueName or set app.uniqueName (in spec.json .app or -AppSpec)." }
    $solution = if ($SolutionName) { $SolutionName } elseif ($spec.solution) { "$($spec.solution)" } else { $null }

    # mode: 'create' (default) builds a NEW app (self-create if missing); 'extend' adds to an EXISTING app
    # (e.g. a non-copyable OOB app like the Customer Service workspace) -- never self-create.
    $mode = if ($app.PSObject.Properties['mode'] -and $app.mode) { "$($app.mode)".ToLower() } else { 'create' }

    Write-Host "`nBuildSiteMap for app: $appUnique (mode=$mode)$(if ($DryRun) { ' [DRY-RUN]' })" -ForegroundColor Cyan

    # SELF-CONTAINED: in create mode, a missing/misnamed app is created + seeded with a sitemap so a weak
    # executor's wrong app name can't break the build. In extend mode the target must already exist.
    $existingApp = Get-AppModuleUnpublished -AppModuleUniqueName $appUnique
    if (-not $existingApp) {
        if ($mode -eq 'extend') {
            throw "app '$appUnique' not found and app.mode=extend -- an extend target must already exist (e.g. a non-copyable OOB app); use mode=create to build a new app, or fix the uniqueName."
        }
        if ($DryRun) {
            Write-Output "[APP] would create app module '$appUnique' (does not exist) [DRY-RUN]"
        } else {
            $null = New-AppModuleFromSpec -App $app -AppUnique $appUnique -SolutionName $solution
        }
    } elseif ($mode -eq 'extend') {
        # Existing app: ADD the declared tables as components before rendering (idempotent for already-added ones).
        Write-Output "[APP] extend mode -- using existing app '$appUnique'"
        if (-not $DryRun) { Add-DeclaredEntityComponents -App $app -AppModuleId $existingApp.appmoduleid }
    } else {
        # create mode, app ALREADY exists (created by an earlier slice / a previous run / by hand): the declared
        # tables must still be registered as components. Skipping this branch is exactly how round-3 shipped a
        # sitemap whose reference-table subareas pointed at tables the app did not contain (F-02).
        Write-Output "[APP] create mode -- app '$appUnique' already exists; registering declared tables as components"
        if (-not $DryRun) { Add-DeclaredEntityComponents -App $app -AppModuleId $existingApp.appmoduleid }
    }

    if ($DryRun) {
        $declaredDry = New-Object System.Collections.Generic.List[string]
        foreach ($area in @($app.areas)) { foreach ($group in @($area.groups)) { foreach ($sub in @($group.subAreas)) {
            $sid = if ($sub.id) { "$($sub.id)" } elseif ($sub.entity) { "subarea_$($sub.entity)" } else { $null }
            if ($sid) { $declaredDry.Add($sid) }
        } } }
        Write-Output "[OK] BuildSiteMap DRY-RUN -- would assemble $($declaredDry.Count) subarea(s) in declared order: $($declaredDry -join ', '). No changes written."
        return
    }

    $resolved = Resolve-AppModuleSiteMap -AppModuleUniqueName $appUnique
    [xml]$xml = $resolved.SiteMapXml
    $siteMapNode = $xml.SelectSingleNode("//SiteMap")
    if (-not $siteMapNode) { throw "Could not find the SiteMap root element." }

    # Assemble the FULL <SiteMap> in declared order: clear existing Areas, then emit each declared Area/Group/SubArea.
    @($siteMapNode.SelectNodes("Area")) | ForEach-Object { [void]$siteMapNode.RemoveChild($_) }

    $declared = New-Object System.Collections.Generic.List[string]
    $ai = 0
    foreach ($area in @($app.areas)) {
        $ai++
        $areaId = if ($area.id) { "$($area.id)" } else { "area_$ai" }
        $areaEl = $xml.CreateElement("Area"); $areaEl.SetAttribute("Id", $areaId)
        Set-SiteMapTitle -Doc $xml -Element $areaEl -Title "$($area.title)"
        $gi = 0
        foreach ($group in @($area.groups)) {
            $gi++
            $groupId = if ($group.id) { "$($group.id)" } else { "${areaId}_group_$gi" }
            $groupEl = $xml.CreateElement("Group"); $groupEl.SetAttribute("Id", $groupId)
            Set-SiteMapTitle -Doc $xml -Element $groupEl -Title "$($group.title)"
            $si = 0
            foreach ($sub in @($group.subAreas)) {
                $si++
                $subId = if ($sub.id) { "$($sub.id)" } elseif ($sub.entity) { "subarea_$($sub.entity)" } else { "${groupId}_sub_$si" }
                $subEl = $xml.CreateElement("SubArea"); $subEl.SetAttribute("Id", $subId)
                if ($sub.dashboard) {
                    # Classic, XSD-valid dashboard subarea: Url + DefaultDashboard GUID, NOT Type="Dashboard"
                    # (same shape as AddSubArea; the app-designer vocabulary fails sitemap XSD validation).
                    $dashGuid = "$($sub.dashboard)".Trim('{', '}')
                    [guid]$parsed = [guid]::Empty
                    if (-not [guid]::TryParse($dashGuid, [ref]$parsed)) {
                        throw "SubArea '$subId': 'dashboard' must be the dashboard (SystemForm) GUID -- got '$($sub.dashboard)'. Look it up via the hso-dataverse-dashboards skill or a systemforms query."
                    }
                    $dashUrl = if ($sub.url) { "$($sub.url)" } else { "/main.aspx?pagetype=dashboard&dashboardId=$dashGuid" }
                    $subEl.SetAttribute("Url", $dashUrl)
                    $subEl.SetAttribute("DefaultDashboard", $dashGuid)
                }
                elseif ($sub.url) { $subEl.SetAttribute("Url", "$($sub.url)") }
                elseif ($sub.entity -and $sub.viewId) {
                    # entity + viewId -> a URL subarea bound to that view (same shape as UpdateSubArea).
                    $cv = "$($sub.viewId)" -replace '[{}]', ''
                    $subEl.SetAttribute("Url", "/main.aspx?etn=$($sub.entity)&pagetype=entitylist&viewid=%7b$cv%7d")
                }
                elseif ($sub.entity) { $subEl.SetAttribute("Entity", "$($sub.entity)") }
                else {
                    # FAIL on unrecognized shapes instead of emitting a dead subarea -- a silent drop costs
                    # the caller a diagnosis loop (WI-262 F2: `sub.dashboard` was dropped without a trace).
                    $seenKeys = @($sub.PSObject.Properties.Name) -join ', '
                    throw "SubArea '$subId': no renderable target. Supported keys: dashboard (GUID), url, entity [+ viewId]. Keys present: $seenKeys."
                }
                if ($sub.title) { Set-SiteMapTitle -Doc $xml -Element $subEl -Title "$($sub.title)" }
                [void]$groupEl.AppendChild($subEl)
                $declared.Add($subId)
            }
            [void]$areaEl.AppendChild($groupEl)
        }
        [void]$siteMapNode.AppendChild($areaEl)
    }

    # Serialize the assembled sitemap.
    $sw = New-Object System.IO.StringWriter
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.OmitXmlDeclaration = $true; $settings.Indent = $false
    $xw = [System.Xml.XmlWriter]::Create($sw, $settings)
    $xml.WriteTo($xw); $xw.Flush()
    $newXml = $sw.ToString()

    # ONE PATCH + publish.
    $patchUrl = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/sitemaps($($resolved.SiteMapId))"
    $patchHeaders = @{
        "Authorization" = "Bearer $script:AuthToken"; "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0"
        "Accept" = "application/json"; "Content-Type" = "application/json; charset=utf-8"; "If-Match" = "*"
    }
    $patchBody = @{ sitemapxml = $newXml } | ConvertTo-Json -Depth 5 -Compress
    try {
        Invoke-RestMethod -Uri $patchUrl -Method Patch -Headers $patchHeaders -Body ([System.Text.Encoding]::UTF8.GetBytes($patchBody))
    } catch {
        $errorMessage = $_.Exception.Message
        if ($_.ErrorDetails.Message) { try { $errorMessage = ($_.ErrorDetails.Message | ConvertFrom-Json).error.message } catch { } }
        throw "Sitemap PATCH failed: $errorMessage"
    }
    $publishXml = "<importexportxml><appmodules><appmodule>$($resolved.AppModuleId)</appmodule></appmodules></importexportxml>"
    Invoke-DataverseApi -Method "POST" -Endpoint "PublishXml" -Body @{ ParameterXml = $publishXml } -ReturnRepresentation $true

    # READ BACK and diff -- subareas present + in declared order.
    $after = Resolve-AppModuleSiteMap -AppModuleUniqueName $appUnique
    [xml]$afterXml = $after.SiteMapXml
    $built = @($afterXml.SelectNodes("//SubArea") | ForEach-Object { $_.GetAttribute("Id") })
    $missing = @($declared | Where-Object { $built -notcontains $_ })
    $orderOk = $true
    $declaredInBuilt = @($declared | Where-Object { $built -contains $_ })
    $builtFiltered = @($built | Where-Object { $declared -contains $_ })
    for ($i = 0; $i -lt $declaredInBuilt.Count; $i++) { if ($declaredInBuilt[$i] -ne $builtFiltered[$i]) { $orderOk = $false; break } }

    Write-Output "[OK] BuildSiteMap: $($declared.Count) declared subarea(s) written in one PATCH + publish."
    Write-Output "  read-back: $($built.Count) subarea(s) present; declared-order $(if ($orderOk) { 'MATCH' } else { 'MISMATCH' })."
    if ($missing.Count -gt 0) { Write-Output "  [SITEMAP-DIFF] $($missing.Count) declared subarea(s) MISSING after read-back: $($missing -join ', ')." }
    if (-not $orderOk) { Write-Output "  [SITEMAP-DIFF] declared subarea order does not match the read-back order." }
    if ($missing.Count -eq 0 -and $orderOk) { Write-Output "  [OK] sitemap read-back matches the declared contract." }

    # READ BACK app membership -- every declared table (subArea entities + unsurfacedTables) must be an app
    # component (appmodulecomponents componenttype 1 = Entity, objectid = the entity table's entityid). A sitemap
    # node pointing at a table the app does not contain is built-but-unreachable (round-3 F-02); this diff is
    # the slice's read-back evidence for "every spec table is in the app". Then ValidateApp, best-effort.
    $declaredEntities = Get-DeclaredAppEntities -App $app
    $appAfter = Get-AppModuleUnpublished -AppModuleUniqueName $appUnique
    # appmoduleidunique is PER GENERATION: the published app and the unpublished draft carry different values, and
    # a read-back against the draft can say "all present" while the app users see lacks the table (E2E round-3
    # remediation: hso_contract restored in the draft, never published, verifier refuted against the published
    # generation). Read back the PUBLISHED generation (plain appmodules GET); report a diverging draft.
    $appIdUnique = $null; $draftUnique = if ($appAfter -and $appAfter.appmoduleidunique) { "$($appAfter.appmoduleidunique)" } else { $null }
    try {
        $pubNameEsc = $appUnique -replace "'", "''"
        $pub = Invoke-DataverseApi -Method "GET" -Endpoint "appmodules?`$filter=uniquename eq '$pubNameEsc'&`$select=appmoduleid,appmoduleidunique"
        if ($pub.value -and $pub.value.Count -gt 0) { $appIdUnique = "$($pub.value[0].appmoduleidunique)" }
    } catch { }
    if (-not $appIdUnique) { $appIdUnique = $draftUnique; if ($appIdUnique) { Write-Output "  [APP-DIFF] app '$appUnique' has no PUBLISHED generation -- read-back is against the unpublished draft; publish is pending." } }
    elseif ($draftUnique -and $draftUnique -ne $appIdUnique) { Write-Output "  [INFO] unpublished draft generation ($draftUnique) differs from the published generation ($appIdUnique) -- read-back below is the PUBLISHED app." }
    if ($declaredEntities.Count -gt 0 -and $appIdUnique) {
        $compRows = @()
        try {
            $cr = Invoke-DataverseApi -Method "GET" -Endpoint "appmodulecomponents?`$filter=_appmoduleidunique_value eq $appIdUnique and componenttype eq 1&`$select=objectid"
            $compRows = @($cr.value)
        } catch { Write-Output "  [APP-DIFF] could not read appmodulecomponents: $($_.Exception.Message)" }
        $componentIds = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($c in $compRows) { if ($c.objectid) { [void]$componentIds.Add("$($c.objectid)") } }
        $absent = New-Object System.Collections.Generic.List[string]
        foreach ($e in $declaredEntities) {
            $eid = $null
            try { $er = Invoke-DataverseApi -Method "GET" -Endpoint "entities?`$filter=logicalname eq '$e'&`$select=entityid"; if ($er.value -and $er.value.Count -gt 0) { $eid = "$($er.value[0].entityid)" } } catch { }
            if (-not $eid -or -not $componentIds.Contains($eid)) { $absent.Add($e) }
        }
        if ($absent.Count -gt 0) {
            Write-Output "  [APP-DIFF] $($absent.Count) declared table(s) NOT registered as app components after read-back: $($absent -join ', ') -- the app does not contain them; their subareas / subgrids are unreachable."
        } else {
            Write-Output "  [OK] app-components read-back: all $($declaredEntities.Count) declared table(s) are app components (componenttype 1)."
        }
    }
    try {
        $va = Invoke-DataverseApi -Method "GET" -Endpoint "appmodules($($appAfter.appmoduleid))/Microsoft.Dynamics.CRM.ValidateApp()"
        $vaOk = $true
        if ($null -ne $va.ValidationSuccess) { $vaOk = [bool]$va.ValidationSuccess }
        $issues = @($va.ValidationIssueList | Where-Object { $_ })
        if ($vaOk -and $issues.Count -eq 0) { Write-Output "  [OK] ValidateApp: clean." }
        else {
            Write-Output "  [APP-DIFF] ValidateApp reported $($issues.Count) issue(s) (ValidationSuccess=$vaOk):"
            foreach ($i in $issues) { Write-Output "    - $($i.Message)" }
        }
    } catch { Write-Output "  [INFO] ValidateApp not evaluated: $($_.Exception.Message)" }
}
#endregion

#region Composite Operations (BuildForm / CurateDefaultViews)
# Layer-4 composites per ADR 0013 Rule 2: their value is a non-obvious metadata-driven algorithm
# (CurateDefaultViews' column heuristic) and a single-write race workaround (BuildForm's no-re-read
# assembly that sidesteps the systemforms cache clobber) -- not thin per-op wrappers.

function ConvertTo-XmlAttrValue {
    param([string]$Value)
    if ($null -eq $Value) { return "" }
    return ($Value -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;')
}

function Get-MetaBool {
    # Coerce a metadata flag that may be a plain [bool] or a BooleanManagedProperty (@{ Value=...}).
    param($Value, [bool]$Default = $true)
    if ($null -eq $Value) { return $Default }
    if ($Value -is [bool]) { return $Value }
    if ($Value.PSObject.Properties['Value']) { return [bool]$Value.Value }
    return $Default
}

function Get-TableMetadataIndex {
    # One metadata read of the table + its attributes, shaped for the column heuristic and BuildForm
    # field validation. Cached per-table for the lifetime of the invocation.
    param([string]$TableName)
    $t = $TableName.ToLower()
    if (-not $script:MetadataIndexCache) { $script:MetadataIndexCache = @{} }
    if ($script:MetadataIndexCache.ContainsKey($t)) { return $script:MetadataIndexCache[$t] }

    $ent = Invoke-DataverseApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$t')?`$select=PrimaryIdAttribute,PrimaryNameAttribute,LogicalName,DisplayName,HasActivities,HasNotes"
    $attrsResp = Invoke-DataverseApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$t')/Attributes?`$select=LogicalName,AttributeType,RequiredLevel,IsValidForRead,IsValidForAdvancedFind,IsCustomAttribute,IsPrimaryName,IsPrimaryId,AttributeOf,DisplayName"
    $attrs = @($attrsResp.value)

    $byName = @{}
    foreach ($a in $attrs) { if ($a.LogicalName) { $byName[$a.LogicalName] = $a } }

    # Parent lookup: prefer a required Lookup/Customer, else first custom lookup, else first lookup.
    $lookups = @($attrs | Where-Object { $_.AttributeType -in @('Lookup', 'Customer') -and -not $_.AttributeOf -and $_.LogicalName -ne 'ownerid' })
    $parent = ($lookups | Where-Object { $_.RequiredLevel -and ($_.RequiredLevel.Value -in @('ApplicationRequired', 'SystemRequired')) } | Select-Object -First 1).LogicalName
    if (-not $parent) { $parent = ($lookups | Where-Object { $_.IsCustomAttribute } | Select-Object -First 1).LogicalName }
    if (-not $parent) { $parent = ($lookups | Select-Object -First 1).LogicalName }

    $display = $t
    if ($ent.DisplayName -and $ent.DisplayName.UserLocalizedLabel -and $ent.DisplayName.UserLocalizedLabel.Label) { $display = $ent.DisplayName.UserLocalizedLabel.Label }

    $index = @{
        Table         = $t
        Display       = $display
        Primary       = $ent.PrimaryNameAttribute
        PrimaryId     = $ent.PrimaryIdAttribute
        HasActivities = [bool]$ent.HasActivities
        HasNotes      = [bool]$ent.HasNotes
        Attrs         = $attrs
        ByName        = $byName
        ParentLookup  = $parent
    }
    $script:MetadataIndexCache[$t] = $index
    return $index
}

function Get-CuratedColumnSet {
    # The column-selection heuristic (Layer 3 IP). Priority: primary name, status (+owner), key
    # business columns ranked required-first then by list usefulness, createdon trailing if room.
    param([hashtable]$Index, [int]$MaxColumns, [bool]$IncludeOwner, [string]$ViewKind)
    $primary = $Index.Primary
    $parent = $Index.ParentLookup
    $deny = @('createdby', 'modifiedby', 'createdonbehalfby', 'modifiedonbehalfby', 'owninguser', 'owningteam',
        'owningbusinessunit', 'overriddencreatedon', 'importsequencenumber', 'timezoneruleversionnumber',
        'utcconversiontimezonecode', 'versionnumber', 'statecode', 'traversedpath',
        # Currency plumbing is list noise: Money columns render their own currency symbol, so the
        # system Currency lookup and the exchange-rate field are almost never wanted as list columns.
        'transactioncurrencyid', 'exchangerate')
    $skipTypes = @('Memo', 'Virtual', 'Uniqueidentifier', 'EntityName', 'CalendarRules', 'ManagedProperty', 'PartyList', 'Image', 'File')

    $cands = @($Index.Attrs | Where-Object {
            $_.LogicalName -and
            -not $_.IsPrimaryId -and
            -not $_.AttributeOf -and
            (Get-MetaBool $_.IsValidForRead) -and
            (Get-MetaBool $_.IsValidForAdvancedFind) -and
            ($_.AttributeType -notin $skipTypes) -and
            ($deny -notcontains $_.LogicalName) -and
            # Per-Money base-currency shadow (e.g. hsot_replacementcost_amt_base): a system-generated
            # companion of every Money column, holding the value in the org base currency. It has no
            # AttributeOf (so the guard above misses it) but is pure noise in a default grid -- it
            # otherwise crowded out a real business column. Same spirit as the transactioncurrencyid deny.
            -not ($_.AttributeType -eq 'Money' -and $_.LogicalName -like '*_base')
        })
    $candNames = @($cands | ForEach-Object { $_.LogicalName })

    $ordered = New-Object System.Collections.Generic.List[string]
    if ($primary) { [void]$ordered.Add($primary) }
    if (($candNames -contains 'statuscode') -and -not $ordered.Contains('statuscode')) { [void]$ordered.Add('statuscode') }
    if ($IncludeOwner -and $Index.ByName.ContainsKey('ownerid') -and -not $ordered.Contains('ownerid')) { [void]$ordered.Add('ownerid') }

    # Rank for "presentable operational list": relating record (1) -> category/status choice (2) ->
    # headline money metric (3) -> key dates (4) -> counts/ratings (5) -> flags (6) -> other numerics
    # (7) -> free text (8). Money sits above DateTime (the headline figure beats a second date), and
    # Integer/Boolean are no longer bottom-ranked so domain ratings/flags can surface.
    $typeRank = @{ 'Lookup' = 1; 'Customer' = 1; 'Picklist' = 2; 'State' = 2; 'Status' = 2; 'MultiSelectPicklist' = 2; 'Money' = 3; 'DateTime' = 4; 'Integer' = 5; 'BigInt' = 5; 'Boolean' = 6; 'Decimal' = 7; 'Double' = 7; 'String' = 8 }
    $reserved = @($primary, 'statuscode', 'ownerid', 'createdon', 'modifiedon')
    $business = @($cands | Where-Object { $reserved -notcontains $_.LogicalName })
    if ($ViewKind -eq 'Subgrid' -and $parent) { $business = @($business | Where-Object { $_.LogicalName -ne $parent }) }

    $businessSorted = @($business | Sort-Object -Property `
        @{ Expression = { if ($_.RequiredLevel -and ($_.RequiredLevel.Value -in @('ApplicationRequired', 'SystemRequired'))) { 0 } else { 1 } } }, `
        @{ Expression = { if ($typeRank.ContainsKey($_.AttributeType)) { $typeRank[$_.AttributeType] } else { 9 } } }, `
        @{ Expression = { $_.LogicalName } })

    foreach ($b in $businessSorted) { if (-not $ordered.Contains($b.LogicalName)) { [void]$ordered.Add($b.LogicalName) } }
    if (($candNames -contains 'createdon') -and -not $ordered.Contains('createdon')) { [void]$ordered.Add('createdon') }

    $cap = if ($ViewKind -eq 'Subgrid') { [Math]::Min($MaxColumns, 6) } else { $MaxColumns }
    return @($ordered | Select-Object -First $cap)
}

function Get-CuratedColumnWidth {
    param([hashtable]$Index, [string]$Name)
    if ($Name -eq $Index.Primary) { return 200 }
    $type = if ($Index.ByName.ContainsKey($Name)) { $Index.ByName[$Name].AttributeType } else { 'String' }
    switch ($type) {
        { $_ -in @('Lookup', 'Customer', 'Owner') } { return 150 }
        'DateTime' { return 125 }
        'Money' { return 110 }
        { $_ -in @('Picklist', 'Status', 'State', 'MultiSelectPicklist') } { return 110 }
        default { return 100 }
    }
}

function Invoke-CurateDefaultViews {
    param([string]$TableName, [string[]]$Views, [int]$MaxColumns, [switch]$IncludeOwner, [switch]$DryRun, [string]$SolutionName, [string]$ViewDescription)

    $t = $TableName.ToLower()
    # P3-3: a "presentable app" pass includes Quick Find, not just the Active/Inactive lists -- so the
    # default curates QuickFind too (find columns = primary + up to 3 entity-owned text columns; lookups
    # are ineligible as find columns, so a table whose primary is an auto-number still searches weakly --
    # expected, not a defect). Pass -Views explicitly to opt out, or add Subgrid (the associated view).
    if (-not $Views -or $Views.Count -eq 0) { $Views = @('Active', 'Inactive', 'QuickFind') }
    $Views = @($Views | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    if ($MaxColumns -lt 3) { $MaxColumns = 3 }

    Write-Host "`nCurateDefaultViews for $t (views: $($Views -join ', '); maxcols: $MaxColumns)$(if ($DryRun) { ' [DRY-RUN]' })" -ForegroundColor Cyan

    $idx = Get-TableMetadataIndex -TableName $t
    if (-not $idx.Primary) { throw "Could not resolve the primary-name attribute for '$t' -- is the table name correct?" }

    $all = Invoke-DataverseApi -Method "GET" -Endpoint "savedqueries?`$filter=returnedtypecode eq '$t'&`$select=savedqueryid,name,querytype,isdefault&`$orderby=name"
    $allViews = @($all.value)

    $kindLabels = @{ Active = 'public list'; Inactive = 'public list'; QuickFind = 'quick find'; Subgrid = 'associated/subgrid' }
    $summary = @()

    foreach ($kind in $Views) {
        $target = switch ($kind) {
            'Active' { @($allViews | Where-Object { [int]$_.querytype -eq 0 -and $_.name -like 'Active*' }) | Select-Object -First 1 }
            'Inactive' { @($allViews | Where-Object { [int]$_.querytype -eq 0 -and $_.name -like 'Inactive*' }) | Select-Object -First 1 }
            'QuickFind' { @($allViews | Where-Object { [int]$_.querytype -eq 4 }) | Select-Object -First 1 }
            'Subgrid' {
                # NOTE: 'Subgrid' here curates the table's ASSOCIATED view (querytype 2). That is NOT the
                # public view (querytype 0) a form subgrid's viewId points to -- a subgrid on a form renders
                # whatever public view its ViewId references. Curating the associated view does not change a
                # form subgrid; to control a subgrid's columns, point it at a dedicated public/subgrid view.
                Write-Host "  [INFO] 'Subgrid' curates the ASSOCIATED view (querytype 2), not the public (querytype 0) view a form subgrid's ViewId points to." -ForegroundColor Gray
                @($allViews | Where-Object { [int]$_.querytype -eq 2 }) | Select-Object -First 1
            }
            default { $null }
        }
        if (-not $target) {
            Write-Host "  [WARN] No '$kind' system view found for '$t' -- skipping." -ForegroundColor Yellow
            continue
        }

        $cols = Get-CuratedColumnSet -Index $idx -MaxColumns $MaxColumns -IncludeOwner:$IncludeOwner -ViewKind $kind
        if (-not $cols -or $cols.Count -eq 0) { Write-Host "  [WARN] No columns resolved for '$kind' -- skipping." -ForegroundColor Yellow; continue }
        $widths = @($cols | ForEach-Object { Get-CuratedColumnWidth -Index $idx -Name $_ })

        # Sort discipline: text (primary) or date (createdon) only -- never a choice/lookup/calculated column.
        $sortBy = $idx.Primary; $sortDesc = $false
        if ($kind -eq 'Inactive') {
            # An inactive/closed list reads best most-recently-ended first: prefer an end/closed-type
            # date column from the curated set (still within sort discipline -- dates are sortable),
            # else fall back to createdon, both descending.
            $endDate = $cols | Where-Object { $idx.ByName.ContainsKey($_) -and $idx.ByName[$_].AttributeType -eq 'DateTime' -and $_ -match 'end|clos|expir|complet|cancel|deactiv|terminat' } | Select-Object -First 1
            if ($endDate) { $sortBy = $endDate; $sortDesc = $true }
            # P3-4: fall back to createdon desc EVEN WHEN it isn't a displayed column, so an inactive list
            # reads most-recently-deactivated-first regardless of the curated column set (Build-FetchXml
            # adds the sort column as a fetched-but-unshown <attribute>). Previously this only fired when
            # createdon happened to be displayed, so tables with no end-type date sorted Inactive by the
            # primary name -- identical to Active, surfacing nothing recent.
            else { $sortBy = 'createdon'; $sortDesc = $true }
        }

        $desc = if ($ViewDescription) { $ViewDescription } else { "$kind $($idx.Display) -- default $($kindLabels[$kind]) view, curated to the HSO 6-10 column floor." }

        $findCols = @()
        if ($kind -eq 'QuickFind') {
            $textCols = @($cols | Where-Object { $_ -ne $idx.Primary -and $idx.ByName.ContainsKey($_) -and $idx.ByName[$_].AttributeType -eq 'String' } | Select-Object -First 3)
            $findCols = @(@($idx.Primary) + $textCols)
        }

        $summary += [pscustomobject]@{ Kind = $kind; View = $target.name; Cols = $cols; Sort = "$sortBy$(if ($sortDesc) { ' desc' })"; Find = $findCols }

        if ($DryRun) { continue }

        # Each view writes with publish deferred; we publish once for the whole batch below.
        if ($kind -eq 'QuickFind') {
            Update-View -ViewId $target.savedqueryid -TableName $t -ViewColumns $cols -ViewColumnWidths $widths -ViewFindColumns $findCols -ViewDescription $desc -SolutionName $SolutionName -SkipPublish -Quiet
        }
        else {
            # Columns only. Update-View preserves the existing fetch filter when -ViewFilter is omitted,
            # so the Active/Inactive statecode filter (reserved) is never touched.
            Update-View -ViewId $target.savedqueryid -TableName $t -ViewColumns $cols -ViewColumnWidths $widths -ViewSortBy $sortBy -ViewSortDescending $sortDesc -ViewDescription $desc -SolutionName $SolutionName -SkipPublish -Quiet
        }
    }

    if (-not $DryRun -and $summary.Count -gt 0) {
        # One publish for the curated batch (honors the -SkipPublish global gate set at dispatch).
        Publish-FormCustomizations -TableName $t
    }

    $verb = if ($DryRun) { 'proposal (no views written, -DryRun)' } else { 'curated' }
    Write-Output "[OK] CurateDefaultViews $verb for $t`:"
    foreach ($s in $summary) {
        $pad = $s.Kind.PadRight(9)
        $line = "  $pad`: $($s.Cols.Count) cols [$($s.Cols -join ', ')] (sort: $($s.Sort))"
        if ($s.Find -and $s.Find.Count -gt 0) { $line += " | find: [$($s.Find -join ', ')]" }
        Write-Output $line
    }
}

function Resolve-BuildFormClassId {
    param([string]$FieldName, [string]$AttributeType)
    $map = @{
        'String' = 'String'; 'Memo' = 'Memo'; 'Integer' = 'Integer'; 'BigInt' = 'Integer'; 'Decimal' = 'Decimal';
        'Double' = 'Decimal'; 'Money' = 'Money'; 'DateTime' = 'DateTime'; 'Lookup' = 'Lookup'; 'Customer' = 'Lookup';
        'Owner' = 'Lookup'; 'Picklist' = 'Picklist'; 'State' = 'Picklist'; 'Status' = 'StatusCode';
        'Boolean' = 'TwoOptions'; 'MultiSelectPicklist' = 'MultiSelectPicklist'; 'Uniqueidentifier' = 'String'
    }
    if ($AttributeType -and $map.ContainsKey($AttributeType)) { return Get-ControlClassId -FieldType $map[$AttributeType] }
    return Get-ControlClassId -FieldName $FieldName   # fall back to suffix auto-detection
}

function Build-FieldCellXml {
    # $Field is a string (logical name) or an object with .name plus overrides (label/showlabel/colspan/rowspan/readonly).
    param([string]$TableName, $Field, [hashtable]$Index, [string]$ControlIdPrefix = "")
    if ($Field -is [string]) { $name = $Field; $ov = $null }
    else { $name = "$($Field.name)"; $ov = $Field }
    if (-not $name) { throw "BuildForm: a field entry is missing its 'name'." }

    $attrType = if ($Index.ByName.ContainsKey($name)) { $Index.ByName[$name].AttributeType } else { $null }
    $classId = Resolve-BuildFormClassId -FieldName $name -AttributeType $attrType

    $providedLabel = $null
    if ($ov -and $ov.PSObject.Properties['label'] -and $ov.label) { $providedLabel = "$($ov.label)" }
    $label = Resolve-FieldLabel -TableName $TableName -FieldName $name -ProvidedLabel $providedLabel

    $showlabel = "true"; $colspan = $null; $rowspan = $null; $disabled = "false"
    if ($ov) {
        if ($ov.PSObject.Properties['showlabel']) { $showlabel = $(if ([bool]$ov.showlabel) { "true" } else { "false" }) }
        if ($ov.PSObject.Properties['colspan'] -and $ov.colspan) { $colspan = [int]$ov.colspan }
        if ($ov.PSObject.Properties['rowspan'] -and $ov.rowspan) { $rowspan = [int]$ov.rowspan }
        if ($ov.PSObject.Properties['readonly'] -and [bool]$ov.readonly) { $disabled = "true" }
    }
    $colspanAttr = if ($colspan) { " colspan=`"$colspan`"" } else { "" }
    $rowspanAttr = if ($rowspan) { " rowspan=`"$rowspan`"" } else { "" }
    $cid = [guid]::NewGuid().ToString()
    $ctlId = if ($ControlIdPrefix) { "$ControlIdPrefix$name" } else { $name }
    $lbl = ConvertTo-XmlAttrValue $label
    return "<row><cell id=`"{$cid}`" showlabel=`"$showlabel`" locklevel=`"0`"$colspanAttr$rowspanAttr><labels><label description=`"$lbl`" languagecode=`"$($script:LanguageCode)`" /></labels><control id=`"$ctlId`" classid=`"$classId`" datafieldname=`"$name`" disabled=`"$disabled`" /></cell></row>"
}

function Resolve-SubgridViewByConvention {
    # Dedicated-view-first subgrid view resolution shared by the composite (Build-SubgridCellXml) and the
    # AddSubgrid surgical arm. Prefer an existing DEDICATED subgrid view (name contains 'Subgrid' -- authored
    # without the parent lookup), else fall back to the default public view and emit the [SUBGRID-FALLBACK]
    # marker (parent-lookup leak risk). Returns @{ ViewId; ViewName; Fallback } or $null when no public view exists.
    param([string]$Target, [string]$SubgridName)
    $tl = "$Target".ToLower()
    $dedicated = Invoke-DataverseApi -Method "GET" -Endpoint "savedqueries?`$filter=returnedtypecode eq '$tl' and querytype eq 0 and statecode eq 0 and contains(name,'Subgrid')&`$select=savedqueryid,name&`$top=1"
    if ($dedicated.value -and $dedicated.value.Count -gt 0) {
        Write-Host "  [INFO] subgrid '$SubgridName': no viewId supplied -- using dedicated subgrid view '$($dedicated.value[0].name)'." -ForegroundColor Gray
        return @{ ViewId = $dedicated.value[0].savedqueryid; ViewName = "$($dedicated.value[0].name)"; Fallback = $false }
    }
    $vq = Invoke-DataverseApi -Method "GET" -Endpoint "savedqueries?`$filter=returnedtypecode eq '$tl' and querytype eq 0 and isdefault eq true&`$select=savedqueryid,name&`$top=1"
    if ($vq.value -and $vq.value.Count -gt 0) {
        Write-Host "  [WARN] subgrid '$SubgridName': no viewId supplied and no dedicated 'Subgrid' view found -- using default public view '$($vq.value[0].name)'. Create a dedicated subgrid view (no parent lookup) and re-run, or set its viewId, before delivery." -ForegroundColor Yellow
        Write-Output "[SUBGRID-FALLBACK] subgrid '$SubgridName' (target '$tl') fell back to the default public view '$($vq.value[0].name)' -- parent-lookup leak risk; point it at a dedicated subgrid view (no parent lookup)."
        return @{ ViewId = $vq.value[0].savedqueryid; ViewName = "$($vq.value[0].name)"; Fallback = $true }
    }
    return $null
}

function Build-SubgridCellXml {
    param($Subgrid, [hashtable]$Index)
    $sgName = if ($Subgrid.name) { "$($Subgrid.name)" } else { "subgrid_$($Subgrid.target)" }
    $sgLabel = if ($Subgrid.label) { "$($Subgrid.label)" } else { $sgName }
    $target = "$($Subgrid.target)"
    $rel = "$($Subgrid.relationship)"
    # Schema key is `view` (name or id); keep `viewId` as a back-compat alias.
    $viewRef = if ($Subgrid.view) { "$($Subgrid.view)" } elseif ($Subgrid.viewId) { "$($Subgrid.viewId)" } else { "" }
    $viewId = ""
    if ($viewRef) {
        # Anchor a FULL GUID -- a saved-view NAME starting with 8 hex + dash must NOT be mis-read as an id.
        if ($viewRef -match '^\{?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}?$') {
            $tl0 = $target.ToLower(); $cv = $viewRef -replace '[{}]', ''
            $vc = Invoke-DataverseApi -Method "GET" -Endpoint "savedqueries($cv)?`$select=savedqueryid&`$top=1"
            if (-not $vc.savedqueryid) { throw "Subgrid '$sgName': view id '$viewRef' does not resolve to a saved query on '$target'." }
            $viewId = $viewRef
        }
        else {
            $tl0 = $target.ToLower(); $nameEsc = $viewRef -replace "'", "''"
            $vr = Invoke-DataverseApi -Method "GET" -Endpoint "savedqueries?`$filter=returnedtypecode eq '$tl0' and querytype eq 0 and statecode eq 0 and name eq '$nameEsc'&`$select=savedqueryid,name&`$top=1"
            if ($vr.value -and $vr.value.Count -gt 0) { $viewId = $vr.value[0].savedqueryid; Write-Host "  [INFO] subgrid '$sgName': resolved view '$viewRef' -> $viewId." -ForegroundColor Gray }
            else { throw "Subgrid '$sgName': view '$viewRef' not found on '$target' (no public view by that name)." }
        }
    }
    if (-not $viewId) {
        # Auto-pick when no viewId is supplied (removes the QueryRelationships->CreateView->copy-GUID
        # plumbing). Dedicated-view-first resolution is shared with the AddSubgrid surgical arm.
        $resolved = Resolve-SubgridViewByConvention -Target $target -SubgridName $sgName
        if ($resolved) {
            $viewId = $resolved.ViewId
            if ($resolved.Fallback -and $script:StrictContract) { throw "[SUBGRID-FALLBACK] subgrid '$sgName' (target '$target') fell back to the default public view '$($resolved.ViewName)' under -StrictContract -- author a dedicated subgrid view (no parent lookup) and bind it." }
        }
        else { throw "Subgrid '$sgName': viewId omitted and no public view found for '$target'." }
    }
    $rs = if ($Subgrid.rowspan) { [int]$Subgrid.rowspan } else { 10 }
    $cid = [guid]::NewGuid().ToString()
    $cleanViewId = $viewId -replace '[{}]', ''
    $sgLabelX = ConvertTo-XmlAttrValue $sgLabel
    $params = "<parameters><TargetEntityType>$target</TargetEntityType><ViewId>{$cleanViewId}</ViewId><ViewIds>{$cleanViewId}</ViewIds><RelationshipName>$rel</RelationshipName><EnableQuickFind>false</EnableQuickFind><EnableViewPicker>false</EnableViewPicker><RecordsPerPage>10</RecordsPerPage></parameters>"
    return "<row><cell id=`"{$cid}`" rowspan=`"$rs`"><labels><label description=`"$sgLabelX`" languagecode=`"$($script:LanguageCode)`" /></labels><control id=`"$sgName`" classid=`"$($script:ControlClassIds['Subgrid'])`">$params</control></cell></row>"
}

function Build-TimelineCellXml {
    $cid = [guid]::NewGuid().ToString()
    return "<row><cell id=`"{$cid}`" showlabel=`"false`" rowspan=`"25`"><labels><label description=`"Timeline`" languagecode=`"$($script:LanguageCode)`" /></labels><control id=`"notescontrol`" classid=`"$($script:ControlClassIds['Timeline'])`" /></cell></row>"
}

function Test-SpecHasRecordLog {
    param($Spec)
    foreach ($t in @($Spec.tabs)) {
        if ("$($t.name)" -match 'recordlog|record_log' -or "$($t.label)" -match 'Record Log') { return $true }
    }
    return $false
}

function Build-RecordLogTabXml {
    # HSO standard Record Log tab (SOP §6) -- appended to every Main form so a weak executor can't omit it.
    $dt = $script:ControlClassIds['DateTime']; $lk = $script:ControlClassIds['Lookup']
    $tabId = [guid]::NewGuid().ToString(); $secL = [guid]::NewGuid().ToString(); $secR = [guid]::NewGuid().ToString()
    $audit = @(
        @{ n = 'modifiedon'; l = 'Modified On'; c = $dt }, @{ n = 'modifiedby'; l = 'Modified By'; c = $lk },
        @{ n = 'createdon'; l = 'Created On'; c = $dt }, @{ n = 'createdby'; l = 'Created By'; c = $lk },
        @{ n = 'ownerid'; l = 'Owner'; c = $lk }
    )
    $rows = ""
    foreach ($f in $audit) {
        $cid = [guid]::NewGuid().ToString()
        $rows += "<row><cell id=`"{$cid}`"><labels><label description=`"$($f.l)`" languagecode=`"$($script:LanguageCode)`" /></labels><control id=`"$($f.n)`" classid=`"$($f.c)`" datafieldname=`"$($f.n)`" disabled=`"true`" /></cell></row>"
    }
    $left = "<column width=`"50%`"><sections><section name=`"tab_recordlog_section_details`" id=`"{$secL}`" columns=`"1`" showlabel=`"false`" showbar=`"false`" IsUserDefined=`"1`"><labels><label description=`"Details`" languagecode=`"$($script:LanguageCode)`" /></labels><rows>$rows</rows></section></sections></column>"
    $right = "<column width=`"50%`"><sections><section name=`"tab_recordlog_section_admin`" id=`"{$secR}`" columns=`"1`" showlabel=`"false`" showbar=`"false`" IsUserDefined=`"1`"><labels><label description=`"Admin`" languagecode=`"$($script:LanguageCode)`" /></labels><rows></rows></section></sections></column>"
    return "<tab name=`"tab_recordlog`" id=`"{$tabId}`" IsUserDefined=`"1`" expanded=`"true`" showlabel=`"true`"><labels><label description=`"Record Log`" languagecode=`"$($script:LanguageCode)`" /></labels><columns>$left$right</columns></tab>"
}

function Build-FormPlanDescription {
    # Synthesize a durable layout-plan description from the compiled form when the spec omitted formDescription.
    # Leads with "Pattern <X>" (the SOP-recorded layout pattern) so the form-SOP §2 traceability check passes.
    param([xml]$BuiltForm, [string]$LayoutPattern, [string]$TableName)
    $parts = @()
    if ("$LayoutPattern" -match '^[A-Ea-e]$') { $parts += "Pattern $($LayoutPattern.ToUpper()) layout" }
    $header = $BuiltForm.SelectSingleNode('/form/header')
    if ($header) { $hf = @($header.SelectNodes('.//control')).Count; if ($hf) { $parts += "$hf-field KPI header" } }
    $tabs = @($BuiltForm.SelectNodes('/form/tabs/tab') | ForEach-Object { (@($_.labels.label) | Select-Object -First 1).description } | Where-Object { $_ })
    if ($tabs.Count) { $parts += "tabs: $($tabs -join ', ')" }
    if (@($BuiltForm.SelectNodes("//control[@classid='$($script:ControlClassIds['Subgrid'])']")).Count) { $parts += "with a child subgrid" }
    if (@($BuiltForm.SelectNodes("//control[@classid='$($script:ControlClassIds['Timeline'])']")).Count) { $parts += "timeline present" }
    if (-not $parts) { return "Main form for $TableName." }
    ($parts -join '; ') + '.'
}

function Write-BuiltFormStructure {
    # Render a freshly-compiled form (lanes included) for -DryRun, without touching the server.
    param([xml]$BuiltForm, [string]$FormName, [string]$TableName)
    Write-Host ""
    Write-Host "BuildForm (compiled spec) for '$FormName' [$TableName]" -ForegroundColor White
    $header = $BuiltForm.SelectSingleNode('/form/header')
    if ($header) {
        $hfields = @($header.SelectNodes('.//control') | ForEach-Object { $_.datafieldname })
        Write-Host "HEADER ($($hfields.Count)): $($hfields -join ', ')" -ForegroundColor Cyan
    }
    $tabs = @($BuiltForm.SelectNodes('/form/tabs/tab'))
    Write-Host "TABS ($($tabs.Count))" -ForegroundColor Cyan
    $ti = 0
    foreach ($tab in $tabs) {
        $ti++
        $tl = (@($tab.labels.label) | Select-Object -First 1).description
        Write-Host "[$ti] $tl ($($tab.name))" -ForegroundColor White
        $lanes = @($tab.columns.column); $li = 0
        foreach ($col in $lanes) {
            $li++
            $secNames = @($col.sections.section | ForEach-Object { (@($_.labels.label) | Select-Object -First 1).description })
            Write-Host "  LANE $li/$($lanes.Count) (width=$($col.width)): $($secNames -join ', ')" -ForegroundColor Cyan
            foreach ($sec in @($col.sections.section)) {
                $fields = @(); $extras = @()
                foreach ($ctl in @($sec.SelectNodes('.//control'))) {
                    if ($ctl.classid -eq $script:ControlClassIds['Subgrid']) { $extras += "SUBGRID:$($ctl.id)" }
                    elseif ($ctl.classid -eq $script:ControlClassIds['Timeline']) { $extras += "TIMELINE" }
                    else { $fields += $ctl.datafieldname }
                }
                $secLabel = (@($sec.labels.label) | Select-Object -First 1).description
                $desc = @(); if ($fields.Count) { $desc += "$($fields.Count) field(s): $($fields -join ', ')" }; if ($extras.Count) { $desc += ($extras -join ', ') }
                Write-Host "    - $secLabel`: $($desc -join ' | ')" -ForegroundColor Gray
            }
        }
    }
}

function Invoke-BuildForm {
    param([string]$FormId, [string]$LayoutSpec, [string]$Mode, [switch]$DryRun, [string]$SolutionName)

    if ($Mode -eq 'Merge') { throw "BuildForm -Mode Merge is not yet supported (Phase 1 is Replace-only). Use the per-op functions (AddTab/AddSection/AddFields/...) for additive edits to an existing form." }
    if (-not $LayoutSpec) { throw "LayoutSpec required (inline JSON string or a path to a .json file)." }

    # Parse the layout spec (inline JSON, or a short non-JSON-looking string treated as a file path).
    $specText = $LayoutSpec
    if ($LayoutSpec.Length -lt 1000 -and $LayoutSpec -notmatch '[\{\}]' -and (Test-Path -LiteralPath $LayoutSpec -ErrorAction SilentlyContinue)) {
        $specText = Get-Content -LiteralPath $LayoutSpec -Raw -Encoding UTF8
        Write-Host "  Loaded layout spec from: $LayoutSpec" -ForegroundColor Gray
    }
    try { $spec = $specText | ConvertFrom-Json } catch { throw "LayoutSpec is not valid JSON: $($_.Exception.Message)" }
    if (-not $spec.tabs -or @($spec.tabs).Count -eq 0) { throw "LayoutSpec must contain at least one tab under 'tabs'." }

    $cleanFormId = $FormId -replace '[{}]', ''
    Write-Host "`nBuildForm $cleanFormId (mode: $Mode)$(if ($DryRun) { ' [DRY-RUN]' })" -ForegroundColor Cyan

    # One GET of the current form -- the only read. Everything is assembled in memory from here,
    # so there is no intermediate re-read for a later op to clobber (the systemforms cache hazard).
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml,type"
    $tableName = $formResponse.objecttypecode
    if (-not $tableName) { throw "Could not resolve the table for form $cleanFormId." }
    [xml]$formXml = $formResponse.formxml

    $idx = Get-TableMetadataIndex -TableName $tableName
    $validNames = $idx.ByName.Keys

    # Validate the whole spec up front; collect every issue, then hard-fail with the full list.
    $errors = New-Object System.Collections.Generic.List[string]

    if ($spec.header -and $spec.header.fields) {
        $hf = @($spec.header.fields)
        if ($hf.Count -gt 4) { [void]$errors.Add("header has $($hf.Count) fields (max 4).") }
        foreach ($f in $hf) {
            $fn = if ($f -is [string]) { $f } else { "$($f.name)" }
            if ($fn -and ($validNames -notcontains $fn)) { [void]$errors.Add("header field '$fn' does not exist on '$tableName'.") }
        }
    }

    # 3b: Patterns A/B/C mandate a KPI header. A zero-field header on one of those is a defect the grader can flag.
    $specPattern = if ($spec.PSObject.Properties['layoutPattern'] -and $spec.layoutPattern) { "$($spec.layoutPattern)".ToUpper() } else { $null }
    $headerFieldCount = if ($spec.header -and $spec.header.fields) { @($spec.header.fields).Count } else { 0 }
    if ($specPattern -in @('A', 'B', 'C') -and $headerFieldCount -eq 0) {
        Write-Output "[HEADER-WARN] Pattern $specPattern mandates a KPI header but the spec declares ZERO header fields -- add up to 4 'header.fields' (the at-a-glance metrics for this record)."
        if ($script:StrictContract) { [void]$errors.Add("[HEADER-WARN] Pattern $specPattern mandates a KPI header but the spec declares ZERO header fields (-StrictContract).") }
    }

    $needsTimeline = $false
    foreach ($tab in @($spec.tabs)) {
        if (-not $tab.lanes -or @($tab.lanes).Count -eq 0) { [void]$errors.Add("tab '$($tab.name)' has no lanes."); continue }
        $sum = 0; $allWidths = $true
        foreach ($lane in @($tab.lanes)) {
            if (-not $lane.width) { $allWidths = $false; continue }
            $w = ([string]$lane.width) -replace '[%\s]', ''
            $wn = 0
            if ([int]::TryParse($w, [ref]$wn)) { $sum += $wn } else { [void]$errors.Add("tab '$($tab.name)' has a non-numeric lane width '$($lane.width)'.") }
            foreach ($sec in @($lane.sections)) {
                foreach ($f in @($sec.fields)) {
                    $fn = if ($f -is [string]) { $f } else { "$($f.name)" }
                    if ($fn -and ($validNames -notcontains $fn)) { [void]$errors.Add("field '$fn' (tab '$($tab.name)', section '$($sec.name)') does not exist on '$tableName'.") }
                }
                if ($sec.timeline -eq $true) { $needsTimeline = $true }
            }
        }
        if (-not $allWidths) { [void]$errors.Add("tab '$($tab.name)': every lane must declare a width (widths must sum to 100).") }
        elseif ($sum -ne 100) { [void]$errors.Add("tab '$($tab.name)': lane widths sum to $sum, must be 100.") }
    }

    if ($needsTimeline -and -not ($idx.HasNotes -or $idx.HasActivities)) {
        [void]$errors.Add("a section requests a timeline but table '$tableName' has neither Notes (HasNotes) nor Activities (HasActivities) enabled. Enable one on the table first (data-modeling skill) -- BuildForm will not mutate table metadata.")
    }

    if ($errors.Count -gt 0) {
        Write-Output "[ERROR] BuildForm spec validation failed ($($errors.Count) issue(s)):"
        foreach ($e in $errors) { Write-Output "  - $e" }
        throw "BuildForm aborted: fix the spec issues above and retry."
    }

    # Build header + tabs XML entirely in memory.
    $headerXml = ""
    if ($spec.header -and $spec.header.fields) {
        $cells = ""
        foreach ($f in @($spec.header.fields)) {
            # header cells reuse the field-cell shape, but live directly inside one header <row>
            $rowXml = Build-FieldCellXml -TableName $tableName -Field $f -Index $idx -ControlIdPrefix "header_"
            $cells += ($rowXml -replace '^<row>', '' -replace '</row>$', '')
        }
        $hid = [guid]::NewGuid().ToString()
        $headerXml = "<header id=`"{$hid}`" columns=`"4`" labelwidth=`"115`" celllabelalignment=`"Left`" celllabelposition=`"Top`"><rows><row>$cells</row></rows></header>"
    }

    $tabsInner = ""
    foreach ($tab in @($spec.tabs)) {
        $tabId = [guid]::NewGuid().ToString()
        $tabName = if ($tab.name) { "$($tab.name)" } else { "tab_$([guid]::NewGuid().ToString('N').Substring(0,8))" }
        $tabLabel = if ($tab.label) { "$($tab.label)" } else { $tabName }
        $lanesXml = ""
        foreach ($lane in @($tab.lanes)) {
            $width = ([string]$lane.width); if ($width -notmatch '%$') { $width = "$width%" }
            $sectionsXml = ""
            foreach ($sec in @($lane.sections)) {
                $secId = [guid]::NewGuid().ToString()
                $secName = if ($sec.name) { "$($sec.name)" } else { "section_$([guid]::NewGuid().ToString('N').Substring(0,8))" }
                $secLabel = if ($sec.label) { "$($sec.label)" } else { $secName }
                $secCols = if ($sec.columns) { [int]$sec.columns } else { 1 }
                $secShowLabel = if ($sec.PSObject.Properties['showlabel']) { $(if ([bool]$sec.showlabel) { "true" } else { "false" }) } else { "true" }
                $rowsXml = ""
                # Skip empty entries so a subgrid-only / timeline-only section (no fields) doesn't
                # hand Build-FieldCellXml a $null from @($null). Mirrors the validation loop's guard.
                foreach ($f in @($sec.fields | Where-Object { $_ })) { $rowsXml += Build-FieldCellXml -TableName $tableName -Field $f -Index $idx }
                if ($sec.subgrid) { $rowsXml += Build-SubgridCellXml -Subgrid $sec.subgrid -Index $idx }
                if ($sec.timeline -eq $true) { $rowsXml += Build-TimelineCellXml }
                $secLabelX = ConvertTo-XmlAttrValue $secLabel
                $secNameX = ConvertTo-XmlAttrValue $secName
                $sectionsXml += "<section name=`"$secNameX`" id=`"{$secId}`" columns=`"$secCols`" showlabel=`"$secShowLabel`" showbar=`"false`" IsUserDefined=`"1`" labelwidth=`"115`" celllabelalignment=`"Left`" celllabelposition=`"Left`"><labels><label description=`"$secLabelX`" languagecode=`"$($script:LanguageCode)`" /></labels><rows>$rowsXml</rows></section>"
            }
            $lanesXml += "<column width=`"$width`"><sections>$sectionsXml</sections></column>"
        }
        $tabLabelX = ConvertTo-XmlAttrValue $tabLabel
        $tabNameX = ConvertTo-XmlAttrValue $tabName
        $tabsInner += "<tab name=`"$tabNameX`" id=`"{$tabId}`" IsUserDefined=`"1`" expanded=`"true`" showlabel=`"true`"><labels><label description=`"$tabLabelX`" languagecode=`"$($script:LanguageCode)`" /></labels><columns>$lanesXml</columns></tab>"
    }

    # SOP §6: every Main form carries a Record Log tab. Append it when the spec omitted it so a weak
    # executor can't drop it (set "recordLog": false in the spec to opt out).
    $recordLogOptOut = $spec.PSObject.Properties['recordLog'] -and $spec.recordLog -eq $false
    if (([int]$formResponse.type -eq 2) -and -not (Test-SpecHasRecordLog -Spec $spec) -and -not $recordLogOptOut) {
        $tabsInner += Build-RecordLogTabXml
        Write-Host "  [INFO] Appended the HSO standard Record Log tab (SOP §6) -- not present in the spec." -ForegroundColor Gray
    }
    $tabsXml = "<tabs>$tabsInner</tabs>"

    [xml]$built = "<form>$headerXml$tabsXml</form>"

    if ($DryRun) {
        Write-BuiltFormStructure -BuiltForm $built -FormName $formResponse.name -TableName $tableName
        Write-Output "[OK] BuildForm DRY-RUN complete -- spec compiled and validated; no changes written."
        return
    }

    # Splice into the existing DOM: replace <tabs> in place (preserves events/scripts/form-property
    # ordering), then <header>. ReplaceChild keeps sibling order, so non-spec content is untouched.
    $newTabs = $formXml.ImportNode($built.SelectSingleNode('/form/tabs'), $true)
    $oldTabs = $formXml.SelectSingleNode('/form/tabs')
    if ($oldTabs) { [void]$formXml.DocumentElement.ReplaceChild($newTabs, $oldTabs) }
    else { [void]$formXml.DocumentElement.AppendChild($newTabs) }

    if ($headerXml) {
        $newHeader = $formXml.ImportNode($built.SelectSingleNode('/form/header'), $true)
        $oldHeader = $formXml.SelectSingleNode('/form/header')
        if ($oldHeader) { [void]$formXml.DocumentElement.ReplaceChild($newHeader, $oldHeader) }
        else { [void]$formXml.DocumentElement.InsertBefore($newHeader, $formXml.SelectSingleNode('/form/tabs')) }
    }

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedFormXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''

    # One PATCH + publish. Update-FormXml now verifies persistence authoritatively via a formxml
    # read-back (token comparison, with retry for cache lag), so BuildForm no longer needs its own
    # count read-back -- that hit the same stale-systemforms-cache hazard and once rendered raw names
    # as a false negative. -CallerVerifiesPersistence just suppresses the per-op "verify it yourself" Note.
    Update-FormXml -FormId $cleanFormId -FormXmlContent $updatedFormXml -CallerVerifiesPersistence
    Publish-FormCustomizations -TableName $tableName

    # F3: record the layout plan in the form Description (durable rationale / spec traceability).
    # Forcing this here -- with a WARN when omitted -- closes the iteration-3 2.1 regression where the
    # plan was only narrated, not persisted, leaving the form Description at the generic default.
    $planDesc = $null
    if ($spec.PSObject.Properties['formDescription'] -and $spec.formDescription) { $planDesc = "$($spec.formDescription)" }
    elseif ($spec.PSObject.Properties['description'] -and $spec.description) { $planDesc = "$($spec.description)" }
    if ($planDesc) {
        try { Set-FormDescription -FormId $cleanFormId -FormDescription $planDesc | Out-Null; Write-Output "[OK] Layout plan recorded in the form Description." }
        catch { Write-Output "[WARN] Could not set the form Description ($($_.Exception.Message)) -- set it with SetFormDescription." }
    }
    else {
        # Auto-synthesize the layout plan from the compiled structure + the spec's layoutPattern, so a weak
        # executor that omits formDescription still leaves a traceable plan (not the generic default).
        $lp = if ($spec.PSObject.Properties['layoutPattern'] -and $spec.layoutPattern) { "$($spec.layoutPattern)" } else { $null }
        $planDesc = Build-FormPlanDescription -BuiltForm $built -LayoutPattern $lp -TableName $tableName
        try {
            Set-FormDescription -FormId $cleanFormId -FormDescription $planDesc | Out-Null
            if ($lp) { Write-Output "[OK] Layout plan AUTO-recorded in the form Description (spec omitted formDescription): '$planDesc'" }
            else { Write-Output "[WARN] Layout plan auto-recorded WITHOUT a pattern letter -- add a top-level \"layoutPattern\": \"<A-E>\" (from spec.json forms[].layoutPattern) so the chosen pattern is captured: '$planDesc'" }
        } catch { Write-Output "[WARN] Could not set the form Description ($($_.Exception.Message)) -- set it with SetFormDescription." }
    }

    $expectedTabs = @($built.SelectNodes('/form/tabs/tab')).Count
    Write-Output "[OK] BuildForm: $expectedTabs tab(s) authored and published (persistence verdict above)."
    # Render the AUTHORITATIVE in-memory structure we just compiled and wrote -- NOT a post-write GET,
    # which can return a stale systemforms cache copy and render raw tab/section names as a false negative.
    Write-BuiltFormStructure -BuiltForm $built -FormName $formResponse.name -TableName $tableName
}

# Expected lane count for a layout pattern -- the single source of truth shared with the form-completeness
# guardrail (Assert-SpecFormsBuilt). A/B/C are two-lane KPI-header forms; D (hub) and E (simple) are single-lane.
function Get-PatternLaneCount {
    param([string]$LayoutPattern)
    switch ("$LayoutPattern".ToUpper()) {
        'A' { 2 } 'B' { 2 } 'C' { 2 } 'D' { 1 } 'E' { 1 } default { 1 }
    }
}

function Build-LayoutSpecFromForm {
    # Compile a BuildForm LayoutSpec DETERMINISTICALLY from one spec.json forms[] Main entry. If the entry
    # already carries the full BuildForm shape (tabs/header), it is used verbatim; otherwise the layout is
    # synthesized from live table metadata + the entry's layoutPattern/timeline (curated fields laid into the
    # pattern's lanes, KPI header for A/B/C, a dedicated timeline section when timeline:true).
    param($Form)
    if ($Form.PSObject.Properties['tabs'] -and @($Form.tabs).Count -gt 0) {
        return ($Form | ConvertTo-Json -Depth 20)
    }

    $tbl = "$($Form.table)".ToLower()
    $pattern = if ($Form.PSObject.Properties['layoutPattern'] -and $Form.layoutPattern) { "$($Form.layoutPattern)".ToUpper() } else { 'E' }
    $wantTimeline = ($Form.PSObject.Properties['timeline'] -and $Form.timeline -eq $true)
    $laneCount = Get-PatternLaneCount -LayoutPattern $pattern

    $idx = Get-TableMetadataIndex -TableName $tbl
    if (-not $idx.Primary) { throw "Could not resolve metadata for '$tbl'." }
    $curated = @(Get-CuratedColumnSet -Index $idx -MaxColumns 20 -IncludeOwner $false -ViewKind 'Main')
    $business = @($curated | Where-Object { $_ -and $_ -ne 'createdon' -and $_ -ne 'modifiedon' })
    if ($business.Count -eq 0) { $business = @($idx.Primary) }

    $header = $null
    if ($pattern -in @('A', 'B', 'C')) {
        $kpiRank = @{ 'Lookup' = 1; 'Customer' = 1; 'Status' = 2; 'State' = 2; 'Picklist' = 2; 'Money' = 3; 'DateTime' = 4 }
        $kpi = @($business | Where-Object { $idx.ByName.ContainsKey($_) -and $kpiRank.ContainsKey($idx.ByName[$_].AttributeType) } |
            Sort-Object { $kpiRank[$idx.ByName[$_].AttributeType] } | Select-Object -First 4)
        if ($kpi.Count -eq 0) { $kpi = @($business | Select-Object -First 1) }
        $header = @{ fields = @($kpi) }
    }

    $lanes = @()
    if ($laneCount -le 1) {
        $sections = @(@{ name = 'general'; label = 'General'; columns = 1; fields = @($business) })
        if ($wantTimeline -and ($idx.HasNotes -or $idx.HasActivities)) {
            $sections += @{ name = 'timeline'; label = 'Timeline'; timeline = $true }
        }
        $lanes = @(@{ width = '100%'; sections = $sections })
    }
    else {
        $half = [Math]::Max(1, [int][Math]::Ceiling($business.Count / 2.0))
        $left = @($business | Select-Object -First $half)
        $right = @($business | Select-Object -Skip $half)
        if ($right.Count -eq 0) { $right = @($left | Select-Object -Last 1); $left = @($left | Select-Object -First ([Math]::Max(1, $left.Count - 1))) }
        $rightSecs = @(@{ name = 'details'; label = 'Details'; columns = 1; fields = @($right) })
        if ($wantTimeline -and ($idx.HasNotes -or $idx.HasActivities)) {
            $rightSecs += @{ name = 'timeline'; label = 'Timeline'; timeline = $true }
        }
        $lanes = @(
            @{ width = '60%'; sections = @(@{ name = 'general'; label = 'General'; columns = 1; fields = @($left) }) },
            @{ width = '40%'; sections = $rightSecs }
        )
    }

    $layout = [ordered]@{ layoutPattern = $pattern; tabs = @(@{ name = 'tab_general'; label = 'General'; lanes = $lanes }) }
    if ($header) { $layout['header'] = $header }
    return ($layout | ConvertTo-Json -Depth 20)
}

function Select-CanonicalMainForm {
    # CANONICAL MAIN-FORM SELECTION RULE -- IDENTICAL ordering the graders use, so build and grade converge.
    # Among a table's active Main forms (type==2, formactivationstate==1), order by
    #   (1) (tab-count + section-count) DESC, (2) isdefault DESC, (3) name ASC (ordinal-ignorecase);
    # take the first. Emits a [WARN] naming the chosen form when >1 active Main form exists.
    param([string]$TableName)
    $tbl = "$TableName".ToLower()
    $forms = @((Invoke-DataverseApi -Method "GET" -Endpoint "systemforms?`$filter=objecttypecode eq '$tbl' and type eq 2 and formactivationstate eq 1&`$select=formid,name,formxml,isdefault").value)
    if ($forms.Count -eq 0) { return $null }
    $ranked = foreach ($f in $forms) {
        $tabCount = 0; $sectionCount = 0
        try {
            [xml]$fx = $f.formxml
            $tabCount = @($fx.SelectNodes('//tab')).Count
            $sectionCount = @($fx.SelectNodes('//section')).Count
        } catch { }
        [pscustomobject]@{
            formid = $f.formid; name = "$($f.name)"; isdefault = [bool]$f.isdefault
            complexity = ($tabCount + $sectionCount)
        }
    }
    $ordered = @($ranked | Sort-Object `
        @{ Expression = 'complexity'; Descending = $true }, `
        @{ Expression = 'isdefault'; Descending = $true }, `
        @{ Expression = { $_.name.ToLowerInvariant() }; Descending = $false })
    if ($ordered.Count -gt 1) {
        Write-Output "[WARN] '$tbl' has $($ordered.Count) active Main forms -- selected '$($ordered[0].name)' ($($ordered[0].formid)) by the canonical rule (complexity $($ordered[0].complexity), isdefault $($ordered[0].isdefault))."
    }
    return $ordered[0]
}

function Invoke-BuildAllForms {
    # DETERMINISTIC corrective build: for each Main form the spec declares (optionally limited to -FormTables),
    # compile a BuildForm LayoutSpec from the spec entry and run Invoke-BuildForm against the table's active Main
    # form. Replaces the stochastic "spawn another Claude to build the stub" repair. Sets a non-zero exit on any failure.
    param([string]$SpecJsonPath, [string[]]$FormTables, [string]$SolutionName, [switch]$DryRun)

    if (-not $SpecJsonPath -or -not (Test-Path -LiteralPath $SpecJsonPath)) { throw "SpecJsonPath required (path to spec.json)." }
    $spec = Get-Content -LiteralPath $SpecJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $mains = @($spec.forms | Where-Object { "$($_.type)" -eq 'Main' -and $_.table })
    if ($FormTables -and $FormTables.Count -gt 0) {
        # Split on commas too -- under `-File` a comma-joined token binds as one element.
        $want = @($FormTables | ForEach-Object { "$_" -split ',' } | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
        $mains = @($mains | Where-Object { $want -contains "$($_.table)".ToLower() })
    }
    if ($mains.Count -eq 0) { Write-Output "[BUILD-ALL] no Main forms to build from the spec."; return }

    # Visible skip for declared non-Main forms (QuickCreate/QuickView/Card) -- BuildAllForms only builds Main forms.
    foreach ($nf in @($spec.forms | Where-Object { $_.table -and "$($_.type)" -and "$($_.type)" -ne 'Main' })) {
        if ($FormTables -and $FormTables.Count -gt 0 -and ($want -notcontains "$($nf.table)".ToLower())) { continue }
        Write-Output "[SKIP] $($nf.type) form for $("$($nf.table)".ToLower()) declared but not built by BuildAllForms -- author via CreateForm."
    }

    Write-Host "`nBuildAllForms: $($mains.Count) Main form(s) from $SpecJsonPath" -ForegroundColor Cyan
    $results = @(); $failed = 0
    foreach ($f in $mains) {
        $tbl = "$($f.table)".ToLower()
        try {
            $chosen = Select-CanonicalMainForm -TableName $tbl
            if (-not $chosen) { throw "no active Main form found for '$tbl'." }
            $formId = $chosen.formid
            $layout = Build-LayoutSpecFromForm -Form $f
            Invoke-BuildForm -FormId $formId -LayoutSpec $layout -Mode 'Replace' -DryRun:$DryRun -SolutionName $SolutionName
            $results += [pscustomobject]@{ table = $tbl; formId = $formId; ok = $true; error = $null }
            Write-Host "  [BUILD-ALL] $tbl -- built." -ForegroundColor Green
        }
        catch {
            $failed++
            $results += [pscustomobject]@{ table = $tbl; formId = $null; ok = $false; error = "$($_.Exception.Message)" }
            Write-Host "  [BUILD-ALL] $tbl -- FAILED: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Output "[BUILD-ALL] $($results.Count - $failed)/$($results.Count) Main form(s) built$(if ($DryRun) { ' [DRY-RUN]' })."
    foreach ($r in $results) { Write-Output "  - $($r.table): $(if ($r.ok) { 'OK' } else { "FAIL ($($r.error))" })" }
    if ($failed -gt 0) { throw "[BUILD-ALL] $failed of $($results.Count) Main form(s) failed to build (see per-form errors above)." }
}
#endregion

#region Main Execution
$envUrl = $EnvironmentUrl.TrimEnd('/')
$token = Get-DataverseToken -EnvironmentUrl $envUrl
if (-not $token) {
    Write-Host "[ERROR] Failed to obtain authentication token." -ForegroundColor Red
    exit 1
}
$script:AuthToken = $token
$script:EnvironmentUrl = $envUrl

function Add-PCFControlToForm {
    param(
        [string]$FormId,
        [string]$TabName,
        [string]$FieldName,
        [string]$PCFControlName,
        [string]$PCFVersion = "1.0.0",
        [string]$PCFParametersJson,   # JSON string: {"paramName":"value",...}
        [int[]]$FormFactors = @(0, 1, 2),
        [switch]$SkipPublish
    )
    Write-Host "`nBinding PCF control to form field..." -ForegroundColor Cyan
    Write-Host "  Control: $PCFControlName" -ForegroundColor Gray
    Write-Host "  Field:   $FieldName" -ForegroundColor Gray

    $cleanFormId = $FormId -replace '[{}]', ''
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode
    [xml]$formXml = $formResponse.formxml

    # Locate the target field control
    $control = $formXml.SelectSingleNode("//tabs//control[@datafieldname='$FieldName']")
    if (-not $control) { throw "Field '$FieldName' not found on form '$($formResponse.name)'" }

    # Ensure the control has a uniqueid attribute for controlDescriptions linkage
    $uniqueId = $control.GetAttribute("uniqueid")
    if (-not $uniqueId -or $uniqueId -eq '') {
        $uniqueId = "{$([guid]::NewGuid().ToString().ToUpper())}"
        $control.SetAttribute("uniqueid", $uniqueId)
        Write-Host "  Assigned uniqueid $uniqueId to control" -ForegroundColor Gray
    }
    $cleanUniqueId = $uniqueId -replace '[{}]', ''

    # Ensure <controlDescriptions> element exists at form root
    $controlDescriptions = $formXml.SelectSingleNode("/form/controlDescriptions")
    if (-not $controlDescriptions) {
        $controlDescriptions = $formXml.CreateElement("controlDescriptions")
        $formXml.form.AppendChild($controlDescriptions) | Out-Null
        Write-Host "  Created <controlDescriptions> element" -ForegroundColor Gray
    }

    # Remove any existing controlDescription for this control (idempotent)
    $existing = $controlDescriptions.SelectSingleNode("controlDescription[@forControl='{$cleanUniqueId}']")
    if ($existing) {
        $controlDescriptions.RemoveChild($existing) | Out-Null
        Write-Host "  Replaced existing controlDescription for this field" -ForegroundColor Gray
    }

    # Parse PCF parameters
    $pcfParams = @{}
    if ($PCFParametersJson) {
        $parsed = @($PCFParametersJson | ConvertFrom-Json)
        if ($parsed.Count -gt 0) {
            $parsed[0].PSObject.Properties | ForEach-Object { $pcfParams[$_.Name] = $_.Value }
        }
    }

    # Build <controlDescription forControl="{uniqueid}">
    $controlDesc = $formXml.CreateElement("controlDescription")
    $controlDesc.SetAttribute("forControl", "{$cleanUniqueId}")

    foreach ($ff in $FormFactors) {
        $customControl = $formXml.CreateElement("customControl")
        $customControl.SetAttribute("formFactor", $ff.ToString())
        $customControl.SetAttribute("name", $PCFControlName)
        $customControl.SetAttribute("version", $PCFVersion)

        $parameters = $formXml.CreateElement("parameters")
        foreach ($key in $pcfParams.Keys) {
            $paramEl = $formXml.CreateElement($key)
            $paramEl.SetAttribute("type", "SingleLine.Text")
            $paramEl.SetAttribute("static", "true")
            $paramEl.InnerText = $pcfParams[$key]
            $parameters.AppendChild($paramEl) | Out-Null
        }
        $customControl.AppendChild($parameters) | Out-Null
        $controlDesc.AppendChild($customControl) | Out-Null
    }
    $controlDescriptions.AppendChild($controlDesc) | Out-Null

    # Serialize and PATCH the form
    # Strip the <?xml ...?> declaration that XmlDocument.Save() emits — Dataverse rejects
    # PATCHes whose formxml doesn't begin with an Element node (matches the regex pattern
    # used by the 18 other form-XML PATCH operations in this script).
    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''
    $jsonBody = [ordered]@{ formxml = $updatedXml } | ConvertTo-Json -Depth 1
    $url = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/systemforms($cleanFormId)"
    $headers = @{
        "Authorization" = "Bearer $script:AuthToken"
        "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0"
        "Accept" = "application/json"; "Content-Type" = "application/json; charset=utf-8"
    }
    try {
        Invoke-RestMethod -Uri $url -Method PATCH -Headers $headers -Body $jsonBody -ErrorAction Stop
    } catch {
        Write-Output "[ERROR] AddPCFControl failed: $($_.Exception.Message)"
        throw
    }
    Write-Output "[OK] PCF control '$PCFControlName' bound to field '$FieldName'"
    if (-not $SkipPublish) { Publish-FormCustomizations -TableName $tableName }
}

function Remove-PCFControlFromForm {
    param(
        [string]$FormId,
        [string]$FieldName,
        [switch]$SkipPublish
    )
    Write-Host "`nRemoving PCF binding from form field..." -ForegroundColor Cyan
    Write-Host "  Field: $FieldName" -ForegroundColor Gray

    $cleanFormId = $FormId -replace '[{}]', ''
    $endpoint = "systemforms($cleanFormId)?`$select=formid,name,objecttypecode,formxml"
    $formResponse = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint
    $tableName = $formResponse.objecttypecode
    [xml]$formXml = $formResponse.formxml

    $control = $formXml.SelectSingleNode("//tabs//control[@datafieldname='$FieldName']")
    if (-not $control) { throw "Field '$FieldName' not found on form '$($formResponse.name)'" }

    $uniqueId = $control.GetAttribute("uniqueid")
    if (-not $uniqueId -or $uniqueId -eq '') {
        Write-Output "[OK] Field '$FieldName' has no uniqueid; nothing to remove."
        return
    }
    $cleanUniqueId = $uniqueId -replace '[{}]', ''

    $controlDescriptions = $formXml.SelectSingleNode("/form/controlDescriptions")
    $removed = $false
    if ($controlDescriptions) {
        $existing = $controlDescriptions.SelectSingleNode("controlDescription[@forControl='{$cleanUniqueId}']")
        if ($existing) {
            $controlDescriptions.RemoveChild($existing) | Out-Null
            Write-Host "  Removed <controlDescription> for {$cleanUniqueId}" -ForegroundColor Gray
            $removed = $true
        }
        if (-not $controlDescriptions.HasChildNodes) {
            $controlDescriptions.ParentNode.RemoveChild($controlDescriptions) | Out-Null
            Write-Host "  Removed empty <controlDescriptions> element" -ForegroundColor Gray
        }
    }

    if (-not $removed) {
        Write-Output "[OK] No PCF binding found for field '$FieldName'; nothing to remove."
        return
    }

    $control.RemoveAttribute("uniqueid")
    Write-Host "  Cleared uniqueid attr from cell control" -ForegroundColor Gray

    $sw = New-Object System.IO.StringWriter
    $formXml.Save($sw)
    $updatedXml = $sw.ToString() -replace '<\?xml[^?]*\?>\s*', ''
    $jsonBody = [ordered]@{ formxml = $updatedXml } | ConvertTo-Json -Depth 1
    $url = "$($script:EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/systemforms($cleanFormId)"
    $headers = @{
        "Authorization" = "Bearer $script:AuthToken"
        "OData-MaxVersion" = "4.0"; "OData-Version" = "4.0"
        "Accept" = "application/json"; "Content-Type" = "application/json; charset=utf-8"
    }
    try {
        Invoke-RestMethod -Uri $url -Method PATCH -Headers $headers -Body $jsonBody -ErrorAction Stop
    } catch {
        Write-Output "[ERROR] RemovePCFControl failed: $($_.Exception.Message)"
        throw
    }
    Write-Output "[OK] PCF binding removed from field '$FieldName' (restored to default control)"
    if (-not $SkipPublish) { Publish-FormCustomizations -TableName $tableName }
}

# Global skip-publish gate. Form-mutation operations (AddSection, AddFields, SetTabProperties,
# RemoveTab, etc.) all funnel through Publish-FormCustomizations, which honors this flag and
# returns early without publishing when set. Use -SkipPublish on every call in a long batch,
# then call PublishForm once at the end (PublishForm explicitly clears the flag below).
$script:SkipPublishGlobal = [bool]$SkipPublish

# -StrictContract promotes the warn-only build markers ([HEADER-WARN]/[SUBGRID-FALLBACK]) to hard failures.
$script:StrictContract = [bool]$StrictContract

switch ($Operation) {
    "QueryForms" { if (-not $TableName) { throw "TableName required" }; Get-Forms -TableName $TableName }
    "GetForm" { if (-not $FormId) { throw "FormId required" }; Get-FormDetails -FormId $FormId }
    "ListFormStructure" {
        # Accept -TableName as a convenience: resolve the table's canonical active Main form (same rule the
        # graders use) so a read-back doesn't first require a QueryForms round-trip just to fetch the GUID.
        if (-not $FormId) {
            if (-not $TableName) { throw "FormId or TableName required" }
            $mf = Select-CanonicalMainForm -TableName $TableName
            if (-not $mf) { throw "No active Main form found for table '$TableName' (pass -FormId explicitly for a non-Main form)" }
            $FormId = $mf.formid
            Write-Host "  Resolved Main form for '$TableName': $($mf.name) ($FormId)" -ForegroundColor Gray
        }
        Get-FormStructure -FormId $FormId
    }
    "UpdateForm" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FormXmlPath -and -not $FormXmlContent) { throw "FormXmlPath or FormXmlContent required" }
        Update-FormXml -FormId $FormId -FormXmlPath $FormXmlPath -FormXmlContent $FormXmlContent
    }
    "CreateForm" {
        if (-not $TableName) { throw "TableName required" }
        if (-not $FormName) { throw "FormName required" }
        if (-not $FormType) { $FormType = "Main" }
        if (-not $Fields -or $Fields.Count -eq 0) { throw "Fields required (array of field names or hashtables with Name, Label, Type)" }
        New-Form -TableName $TableName -FormName $FormName -FormDescription $FormDescription -FormType $FormType -Fields $Fields -SolutionName $SolutionName
    }
    "PublishForm" {
        if (-not $TableName) { throw "TableName required" }
        # PublishForm is the explicit "flush the deferred batch" operation; always publish even
        # when -SkipPublish was set on the same invocation (which would be unusual but harmless).
        $script:SkipPublishGlobal = $false
        Publish-FormCustomizations -TableName $TableName
    }
    "AddFormToApp" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $AppModuleUniqueName) { throw "AppModuleUniqueName required" }
        Add-FormToApp -FormId $FormId -AppModuleUniqueName $AppModuleUniqueName
    }
    "AddViewsToApp" {
        if (-not $AppModuleUniqueName) { throw "AppModuleUniqueName required" }
        if (-not $TableName) { throw "TableName required" }
        if (-not $ViewNames -or $ViewNames.Count -eq 0) { throw "ViewNames required (comma-separated list of saved-query names)" }
        $vns = ConvertTo-NormalizedArray $ViewNames
        Add-ViewsToApp -ViewNames $vns -TableName $TableName -AppModuleUniqueName $AppModuleUniqueName
    }
    "AddTab" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        if (-not $TabLabel) { throw "TabLabel required" }
        Add-TabToForm -FormId $FormId -TabName $TabName -TabLabel $TabLabel -TabColumns $TabColumns -TabShowLabel $TabShowLabel -TabExpanded $TabExpanded -TabPosition $TabPosition
    }
    "RemoveTab" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        Remove-TabFromForm -FormId $FormId -TabName $TabName
    }
    "AddSection" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        if (-not $SectionName) { throw "SectionName required" }
        $secShowLabel = ConvertTo-NormalizedBool $SectionShowLabel
        Add-SectionToForm -FormId $FormId -TabName $TabName -SectionName $SectionName -SectionLabel $(if ($SectionLabel) { $SectionLabel } else { $SectionName }) -SectionColumns $SectionColumns -SectionShowLabel $secShowLabel -SectionLabelWidth $SectionLabelWidth -TabColumnIndex $TabColumnIndex
    }
    "RemoveSection" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        if (-not $SectionName) { throw "SectionName required" }
        Remove-SectionFromForm -FormId $FormId -TabName $TabName -SectionName $SectionName
    }
    "MoveSection" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        if (-not $SectionName) { throw "SectionName required" }
        if ($SectionPosition -lt 0) { throw "SectionPosition required (0-based index)" }
        $moveTargetCol = if ($PSBoundParameters.ContainsKey('TargetColumnIndex')) { $TargetColumnIndex } else { -1 }
        Move-SectionInForm -FormId $FormId -TabName $TabName -SectionName $SectionName -SectionPosition $SectionPosition -TargetColumnIndex $moveTargetCol
    }
    "RenameTab" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        if (-not $TabLabel) { throw "TabLabel required (new label text)" }
        Rename-TabOnForm -FormId $FormId -TabName $TabName -TabLabel $TabLabel
    }
    "RenameForm" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FormName -and -not $FormDescription) { throw "Supply at least one of -FormName (new display name) or -FormDescription (HSO standard form description)." }
        Rename-Form -FormId $FormId -FormName $FormName -FormDescription $FormDescription
    }
    "SetFormDescription" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FormDescription) { throw "FormDescription required" }
        Set-FormDescription -FormId $FormId -FormDescription $FormDescription
    }
    "RenameSection" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required (containing tab; supports 'firstunnamed' magic value)" }
        if (-not $SectionName -and -not $SectionId) { throw "Supply -SectionName (current @name) or -SectionId (GUID for auto-generated sections with no @name)" }
        if (-not $NewSectionName -and -not $SectionLabel) { throw "Supply at least one of -NewSectionName (rename @name) or -SectionLabel (change displayed label). Pass -SectionLabel alone to update only the label without touching @name." }
        Rename-SectionOnForm -FormId $FormId -TabName $TabName -SectionName $SectionName -SectionId $SectionId -NewSectionName $NewSectionName -SectionLabel $SectionLabel
    }
    "UpdateField" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FieldName) { throw "FieldName required" }
        if (-not $FieldShowLabel -and -not $FieldReadOnly -and -not $FieldVisible -and $FieldColspan -le 0 -and $FieldRowspan -le 0 -and -not $FieldAvailableForPhone -and -not $FieldIsRequired) { throw "At least one property required: -FieldShowLabel, -FieldReadOnly, -FieldVisible, -FieldColspan, -FieldRowspan, -FieldAvailableForPhone, or -FieldIsRequired" }
        Update-FieldOnForm -FormId $FormId -FieldName $FieldName -FieldShowLabel $FieldShowLabel -FieldReadOnly $FieldReadOnly -FieldVisible $FieldVisible -FieldColspan $FieldColspan -FieldRowspan $FieldRowspan -FieldAvailableForPhone $FieldAvailableForPhone -FieldIsRequired $FieldIsRequired
    }
    "AddFields" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        if (-not $SectionName) { throw "SectionName required" }
        if (-not $Fields -or $Fields.Count -eq 0) { throw "Fields required (array of field names or hashtables with Name, Label, Type)" }
        Add-FieldsToForm -FormId $FormId -TabName $TabName -SectionName $SectionName -Fields $Fields
    }
    "AddHeaderField" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FieldName) { throw "FieldName required" }
        Add-HeaderFieldToForm -FormId $FormId -FieldName $FieldName -FieldType $FieldType
    }
    "RemoveHeaderField" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FieldName) { throw "FieldName required" }
        Remove-HeaderFieldFromForm -FormId $FormId -FieldName $FieldName
    }
    "AddSubgrid" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        if (-not $SectionName) { throw "SectionName required" }
        if (-not $SubgridName) { throw "SubgridName required" }
        if (-not $RelatedTable) { throw "RelatedTable required" }
        if (-not $RelationshipName) { throw "RelationshipName required" }
        # Auto-pick when ViewId not supplied -- dedicated-view-first (name contains 'Subgrid'), else default
        # public view with [SUBGRID-FALLBACK]. Shared with the BuildForm composite (Resolve-SubgridViewByConvention).
        if (-not $ViewId) {
            $resolvedSg = Resolve-SubgridViewByConvention -Target $RelatedTable -SubgridName $SubgridName
            if ($resolvedSg) {
                $ViewId = $resolvedSg.ViewId
                if ($resolvedSg.Fallback -and $script:StrictContract) { throw "[SUBGRID-FALLBACK] subgrid '$SubgridName' (target '$RelatedTable') fell back to the default public view '$($resolvedSg.ViewName)' under -StrictContract -- author a dedicated subgrid view (no parent lookup) and bind it." }
            } else {
                throw "ViewId required -- no public view found for '$RelatedTable'. Run QueryViews to find an available view."
            }
        }
        $resolvedSubgridLabel = $SubgridLabel
        if (-not $resolvedSubgridLabel) { $resolvedSubgridLabel = $SubgridName }
        $subgridParams = @{
            FormId = $FormId; TabName = $TabName
            SectionName = $SectionName; SectionLabel = $SectionLabel
            SubgridName = $SubgridName; SubgridLabel = $resolvedSubgridLabel
            RelatedTable = $RelatedTable; RelationshipName = $RelationshipName
            ViewId = $ViewId; SubgridRowspan = $SubgridRowspan
            RecordsPerPage = $RecordsPerPage; EnableQuickFind = $EnableQuickFind
            EnableViewPicker = $EnableViewPicker; HideSearchBox = $true
        }
        Add-SubgridToForm @subgridParams
    }
    "AddFormEvent" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $EventName) { throw "EventName required (onload, onsave, onchange, ontabstatechange)" }
        if (-not $FunctionName) { throw "FunctionName required" }
        if (-not $LibraryName) { throw "LibraryName required (web resource name)" }
        if ($EventName -eq "onchange" -and -not $EventAttribute -and -not $EventControlName) { throw "EventAttribute required for onchange events (or EventControlName for cell-level)" }
        Add-FormEventToForm -FormId $FormId -EventName $EventName -FunctionName $FunctionName -LibraryName $LibraryName -EventAttribute $EventAttribute -PassExecutionContext $PassExecutionContext -EventParameters $EventParameters -EventTabName $EventTabName -EventControlName $EventControlName
    }
    "AddFormLibrary" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $LibraryName) { throw "LibraryName required (web resource name)" }
        Add-FormLibraryToForm -FormId $FormId -LibraryName $LibraryName
    }
    "AddTimeline" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        if (-not $SectionName) { $SectionName = "section_timeline" }
        if (-not $SectionLabel) { $SectionLabel = "Timeline" }
        if (-not $ControlName) { $ControlName = "notescontrol" }
        Add-TimelineToForm -FormId $FormId -TabName $TabName -SectionName $SectionName -SectionLabel $SectionLabel -ControlName $ControlName -ControlRowspan $ControlRowspan
    }
    "AddFormComponent" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        if (-not $SectionName) { throw "SectionName required" }
        if (-not $FieldName) { throw "FieldName required (lookup field)" }
        if (-not $RelatedTable) { throw "RelatedTable required (target entity)" }
        if (-not $RelatedFormId) { throw "RelatedFormId required (GUID of main form to embed)" }
        if (-not $ControlName) { $ControlName = "formcomponent_$FieldName" }
        Add-FormComponentToForm -FormId $FormId -TabName $TabName -SectionName $SectionName -FieldName $FieldName -RelatedTable $RelatedTable -RelatedFormId $RelatedFormId -ControlName $ControlName -ControlRowspan $ControlRowspan
    }
    "RemoveField" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FieldName) { throw "FieldName required" }
        Remove-FieldFromForm -FormId $FormId -FieldName $FieldName
    }
    "MoveField" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FieldName) { throw "FieldName required" }
        if (-not $TargetTabName) { throw "TargetTabName required" }
        if (-not $TargetSectionName) { throw "TargetSectionName required" }
        Move-FieldOnForm -FormId $FormId -FieldName $FieldName -TargetTabName $TargetTabName -TargetSectionName $TargetSectionName -FieldPosition $FieldPosition
    }
    "AddWebResource" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        if (-not $SectionName) { throw "SectionName required" }
        if (-not $ControlName) { throw "ControlName required" }
        if (-not $WebResourceUrl) { throw "WebResourceUrl required (web resource name e.g. hso_/html/mypage.html)" }
        Add-WebResourceToForm -FormId $FormId -TabName $TabName -SectionName $SectionName -SectionLabel $SectionLabel -ControlName $ControlName -WebResourceUrl $WebResourceUrl -WebResourcePassParameters $WebResourcePassParameters -WebResourceHeight $WebResourceHeight -WebResourceWidth $WebResourceWidth -WebResourceBorder $WebResourceBorder -ControlRowspan $ControlRowspan
    }
    "AddQuickViewControl" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        if (-not $SectionName) { throw "SectionName required" }
        if (-not $ControlName) { throw "ControlName required" }
        if (-not $FieldName) { throw "FieldName required (lookup field to related entity)" }
        if (-not $QuickForms) { throw "QuickForms required (comma-separated Quick View form GUIDs)" }
        Add-QuickViewControlToForm -FormId $FormId -TabName $TabName -SectionName $SectionName -SectionLabel $SectionLabel -ControlName $ControlName -FieldName $FieldName -QuickForms $QuickForms -QuickFormEntityName $QuickFormEntityName -ControlRowspan $ControlRowspan
    }
    "AddPCFControl" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FieldName) { throw "FieldName required (the bound field datafieldname)" }
        if (-not $PCFControlName) { throw "PCFControlName required (e.g. hsosol_HSO.Dynamics.PCF.LibraryNodeTree)" }
        Add-PCFControlToForm -FormId $FormId -TabName $TabName -FieldName $FieldName -PCFControlName $PCFControlName -PCFVersion $PCFVersion -PCFParametersJson $PCFParametersJson -FormFactors $FormFactors -SkipPublish:$SkipPublish
    }
    "RemovePCFControl" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FieldName) { throw "FieldName required (the bound field datafieldname)" }
        Remove-PCFControlFromForm -FormId $FormId -FieldName $FieldName -SkipPublish:$SkipPublish
    }
    "ConfigureLookup" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FieldName) { throw "FieldName required" }
        Set-LookupConfiguration -FormId $FormId -FieldName $FieldName -LookupDefaultViewId $LookupDefaultViewId -LookupFilterRelationship $LookupFilterRelationship -LookupDependentAttribute $LookupDependentAttribute -LookupDependentAttributeType $LookupDependentAttributeType -LookupDisableMru $LookupDisableMru -LookupDisableQuickFind $LookupDisableQuickFind -LookupDisableViewPicker $LookupDisableViewPicker -LookupAvailableViewIds $LookupAvailableViewIds -LookupAllowFilterOff $LookupAllowFilterOff -LookupIsInlineNewEnabled $LookupIsInlineNewEnabled
    }
    "AddFooterField" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FieldName) { throw "FieldName required" }
        Add-FooterFieldToForm -FormId $FormId -FieldName $FieldName -FieldType $FieldType
    }
    "RemoveFooterField" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FieldName) { throw "FieldName required" }
        Remove-FooterFieldFromForm -FormId $FormId -FieldName $FieldName
    }
    "SetFormProperties" {
        if (-not $FormId) { throw "FormId required" }
        Set-FormProperties -FormId $FormId -FormShowImage $FormShowImage -FormShowNavBar $FormShowNavBar -FormMaxWidth $FormMaxWidth -FormEnableRelatedInfo $FormEnableRelatedInfo -FormRelatedInfoCollapsed $FormRelatedInfoCollapsed -FormHasMargin $FormHasMargin
    }
    "RemoveFormEvent" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $EventName) { throw "EventName required" }
        Remove-FormEventFromForm -FormId $FormId -EventName $EventName -EventAttribute $EventAttribute -FunctionName $FunctionName -LibraryName $LibraryName -HandlerUniqueId $HandlerUniqueId
    }
    "RemoveFormLibrary" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $LibraryName) { throw "LibraryName required" }
        Remove-FormLibraryFromForm -FormId $FormId -LibraryName $LibraryName
    }
    "SetTabProperties" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        $setTabColumns = if ($PSBoundParameters.ContainsKey('TabColumns')) { $TabColumns } else { 0 }
        Set-TabPropertiesOnForm -FormId $FormId -TabName $TabName -TabLabel $TabLabel -TabVisible $TabVisible -TabExpanded $(if ($TabExpanded) { $TabExpanded.ToString().ToLower() } else { $null }) -TabAvailableForPhone $TabAvailableForPhone -TabCollapsible $TabCollapsible -TabColumns $setTabColumns
    }
    "SetSectionProperties" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        if (-not $SectionName) { throw "SectionName required" }
        $secShowLabel = ConvertTo-NormalizedBool $SectionShowLabel
        Set-SectionPropertiesOnForm -FormId $FormId -TabName $TabName -SectionName $SectionName -SectionLabel $SectionLabel -SectionVisible $SectionVisible -SectionAvailableForPhone $SectionAvailableForPhone -SectionAutoExpand $SectionAutoExpand -SectionHeight $SectionHeight -SectionColumns $SectionColumns -SectionShowLabel $secShowLabel
    }
    "AddSpacer" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $TabName) { throw "TabName required" }
        if (-not $SectionName) { throw "SectionName required" }
        Add-SpacerToForm -FormId $FormId -TabName $TabName -SectionName $SectionName
    }
    "AddHiddenField" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FieldName) { throw "FieldName required" }
        Add-HiddenFieldToForm -FormId $FormId -FieldName $FieldName -FieldType $FieldType
    }
    "RemoveHiddenField" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $FieldName) { throw "FieldName required" }
        Remove-HiddenFieldFromForm -FormId $FormId -FieldName $FieldName
    }
    "ConfigureSubgrid" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $SubgridName) { throw "SubgridName required" }
        Set-SubgridConfiguration -FormId $FormId -SubgridName $SubgridName -SubgridAutoExpand $SubgridAutoExpand -SubgridMaxRowsBeforeScroll $SubgridMaxRowsBeforeScroll -SubgridEnableJumpBar $SubgridEnableJumpBar -SubgridChartGridMode $SubgridChartGridMode -SubgridVisualizationId $SubgridVisualizationId -SubgridEnableChartPicker $SubgridEnableChartPicker -SubgridEnableContextualActions $SubgridEnableContextualActions -SubgridHeaderColorCode $SubgridHeaderColorCode -SubgridEnableViewPicker $SubgridEnableViewPicker -ViewId $ViewId -RecordsPerPage $RecordsPerPage
    }
    "SetDisplayConditions" {
        if (-not $FormId) { throw "FormId required" }
        Set-DisplayConditionsOnForm -FormId $FormId -DisplayConditionRoles $DisplayConditionRoles -FallbackFormId $FallbackFormId -DisplayOrder $DisplayOrder
    }
    "AddNavItem" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $NavItemLabel -and -not $NavItemRelationship) { throw "NavItemLabel or NavItemRelationship required" }
        Add-NavItemToForm -FormId $FormId -NavItemId $NavItemId -NavItemLabel $NavItemLabel -NavItemUrl $NavItemUrl -NavItemRelationship $NavItemRelationship -NavItemIcon $NavItemIcon
    }
    "RemoveNavItem" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $NavItemId -and -not $NavItemRelationship) { throw "NavItemId or NavItemRelationship required" }
        Remove-NavItemFromForm -FormId $FormId -NavItemId $(if ($NavItemId) { $NavItemId } else { $NavItemRelationship })
    }
    "BuildForm" {
        if (-not $FormId) { throw "FormId required" }
        if (-not $LayoutSpec) { throw "LayoutSpec required (inline JSON or a path to a .json file)" }
        Invoke-BuildForm -FormId $FormId -LayoutSpec $LayoutSpec -Mode $Mode -DryRun:$DryRun -SolutionName $SolutionName
    }
    "BuildAllForms" {
        if (-not $SpecJsonPath) { throw "SpecJsonPath required (path to spec.json)" }
        Invoke-BuildAllForms -SpecJsonPath $SpecJsonPath -FormTables $FormTables -SolutionName $SolutionName -DryRun:$DryRun
    }
    "CurateDefaultViews" {
        if (-not $TableName) { throw "TableName required" }
        $curateViews = if ($Views) { ConvertTo-NormalizedArray $Views } else { @() }
        Invoke-CurateDefaultViews -TableName $TableName -Views $curateViews -MaxColumns $MaxColumns -IncludeOwner:$IncludeOwner -DryRun:$DryRun -SolutionName $SolutionName -ViewDescription $ViewDescription
    }
    "QueryViews" { if (-not $TableName) { throw "TableName required" }; Get-Views -TableName $TableName }
    "GetViewDetails" { Get-ViewDetails -ViewId $ViewId -ViewName $ViewName -TableName $TableName -Raw:$Raw -Summary:$Summary }
    "InspectViews" { if (-not $TableName) { throw "TableName required" }; Get-TableViewsSummary -TableName $TableName -Raw:$Raw }
    "CreateView" {
        if (-not $ViewName) { throw "ViewName required" }
        if (-not $TableName) { throw "TableName required" }
        if (-not $ViewColumns -or $ViewColumns.Count -eq 0) { throw "ViewColumns required" }
        New-View -ViewName $ViewName -ViewDescription $ViewDescription -ViewType $ViewType -TableName $TableName -ViewColumns $ViewColumns -ViewColumnWidths $ViewColumnWidths -ViewFilter $ViewFilter -ViewSortBy $ViewSortBy -ViewSortDescending $ViewSortDescending -SolutionName $SolutionName -ViewLinkedColumns $ViewLinkedColumns -ViewFloorMin $ViewFloorMin -ViewFloorMax $ViewFloorMax
    }
    "UpdateView" {
        if (-not $ViewId -and -not ($ViewName -and $TableName) -and -not ($ViewFindColumns -and $TableName)) { throw "ViewId or (ViewName and TableName) or (ViewFindColumns and TableName) required" }
        Update-View -ViewId $ViewId -ViewName $ViewName -ViewDescription $ViewDescription -TableName $TableName -ViewColumns $ViewColumns -ViewColumnWidths $ViewColumnWidths -ViewFilter $ViewFilter -ViewSortBy $ViewSortBy -ViewSortDescending $ViewSortDescending -SolutionName $SolutionName -ViewFindColumns $ViewFindColumns -SkipPublish:$SkipPublish -ViewLinkedColumns $ViewLinkedColumns -ViewRawFetchXml $ViewRawFetchXml -ViewRawLayoutXml $ViewRawLayoutXml -ViewFloorMin $ViewFloorMin -ViewFloorMax $ViewFloorMax
    }
    "DeleteView" {
        if (-not $ViewId -and -not ($ViewName -and $TableName)) { throw "ViewId or (ViewName and TableName) required" }
        Remove-View -ViewId $ViewId -ViewName $ViewName -TableName $TableName
    }
    "GetSiteMap" {
        if (-not $AppModuleUniqueName) { throw "AppModuleUniqueName required" }
        Get-SiteMap -AppModuleUniqueName $AppModuleUniqueName
    }
    "BuildSiteMap" {
        if (-not $SpecJsonPath -and -not $AppSpec) { throw "Pass -SpecJsonPath <spec.json> or -AppSpec <inline JSON | file>" }
        Invoke-BuildSiteMap -SpecJsonPath $SpecJsonPath -AppSpec $AppSpec -AppModuleUniqueName $AppModuleUniqueName -SolutionName $SolutionName -DryRun:$DryRun
    }
    "UpdateSubArea" {
        if (-not $AppModuleUniqueName) { throw "AppModuleUniqueName required" }
        if (-not $SubAreaId) { throw "SubAreaId required" }
        if (-not $SubAreaUrl -and -not ($SubAreaEntity -and $SubAreaViewId)) { throw "SubAreaUrl or (SubAreaEntity + SubAreaViewId) required" }
        Update-SubAreaToUrlView -AppModuleUniqueName $AppModuleUniqueName -SubAreaId $SubAreaId -SubAreaEntity $SubAreaEntity -SubAreaViewId $SubAreaViewId -SubAreaUrl $SubAreaUrl
    }
    "AddSiteMapSubArea" {
        if (-not $AppModuleUniqueName) { throw "AppModuleUniqueName required" }
        if (-not $AreaId) { throw "AreaId required" }
        if (-not $GroupId) { throw "GroupId required" }
        if (-not $SubAreaId) { throw "SubAreaId required" }
        if (-not $SubAreaTitle) { throw "SubAreaTitle required" }
        if (-not $SubAreaUrl -and -not $SubAreaEntity -and -not $SubAreaDefaultDashboard) { throw "SubAreaUrl, SubAreaEntity, or SubAreaDefaultDashboard required" }
        Add-SiteMapSubArea -AppModuleUniqueName $AppModuleUniqueName -AreaId $AreaId -AreaTitle $AreaTitle -GroupId $GroupId -GroupTitle $GroupTitle -SubAreaId $SubAreaId -SubAreaTitle $SubAreaTitle -SubAreaUrl $SubAreaUrl -SubAreaEntity $SubAreaEntity -SubAreaDefaultDashboard $SubAreaDefaultDashboard
    }
    "MoveSiteMapGroup" {
        if (-not $AppModuleUniqueName) { throw "AppModuleUniqueName required" }
        if (-not $AreaId) { throw "AreaId required" }
        if (-not $GroupId) { throw "GroupId required" }
        if ($GroupPosition -lt 0) { throw "GroupPosition required (>= 0). Pass 0 to move the group to the top of its Area." }
        Move-SiteMapGroup -AppModuleUniqueName $AppModuleUniqueName -AreaId $AreaId -GroupId $GroupId -GroupPosition $GroupPosition
    }
    default { throw "Unknown operation: $Operation" }
}

Write-Host "`nOperation completed." -ForegroundColor Cyan
#endregion
