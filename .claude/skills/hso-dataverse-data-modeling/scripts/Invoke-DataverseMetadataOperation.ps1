<#
.SYNOPSIS
    Performs Dataverse metadata operations using the Web API.

.DESCRIPTION
    This script creates and manages Dataverse metadata components:
    - Tables (Entities)
    - Columns (Attributes)
    - Relationships (1:N, N:N)
    - Global Choices (Option Sets)

    IMPORTANT: This script modifies your Dataverse schema. It requires
    interactive authentication to ensure you are aware of the changes
    being made to your environment.

.PARAMETER Operation
    The operation to perform: CreateTable, DeleteTable, CreateRelationship, CreateGlobalChoice,
    DeleteGlobalChoice, AddColumn, UpdateGlobalChoice, Publish, PublishAll, QueryTable

.PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com)

.PARAMETER SolutionName
    The solution unique name to associate components with

.EXAMPLE
    # Create a table (requires interactive login)
    .\Invoke-DataverseMetadataOperation.ps1 -Operation CreateTable `
        -EnvironmentUrl "https://myorg.crm.dynamics.com" `
        -TableName "project" -DisplayName "Project" -DisplayNamePlural "Projects"

.EXAMPLE
    # Query a table (requires interactive login)
    .\Invoke-DataverseMetadataOperation.ps1 -Operation QueryTable `
        -EnvironmentUrl "https://myorg.crm.dynamics.com" `
        -TableName "hso_project"

.NOTES
    Requires: PowerShell 5.1+, MSAL.PS module (installed automatically if missing)
    Author: HSO Data Modeling Skill
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("CreateTable", "UpdateTable", "DeleteTable", "CreateRelationship", "CreatePolymorphicLookup", "AddRelationshipMapping", "QueryRelationships", "CreateGlobalChoice", "DeleteGlobalChoice", "QueryGlobalChoice", "AddColumn", "AddColumns", "DeleteColumn", "QueryColumnDependencies", "UpdateColumn", "UpdateGlobalChoice", "DeleteOptionValue", "AddStatusValue", "UpdateStatusLabel", "SetStatusDefault", "SetLifecycle", "Publish", "PublishAll", "QueryTable", "QueryColumn", "CreateSolution", "QuerySolution", "AddTableToSolution", "AddComponentToSolution", "CreateApp", "AddTableToApp", "AddTablesToApp", "QueryApp", "PublishApp", "CreateAlternateKey", "QueryAlternateKeys", "SetAutoNumberSeed", "QueryPublishers", "CreatePublisher", "CreateWebResource", "SetTableIcon")]
    [string]$Operation,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentUrl,


    [Parameter(Mandatory = $false)]
    # NOTE: cannot alias 'SolutionUniqueName' here — a distinct real parameter $SolutionUniqueName
    # (used by CreateSolution) already owns that name, and the collision breaks parameter binding for
    # every operation. (ADR 0025 intent preserved via that explicit param.)
    [string]$SolutionName = "",

    [switch]$Force,                      # DeleteColumn: bypass the dependency-preflight refusal (the primary-column guard is absolute)
    [switch]$StrictDescriptions,         # Make a non-zero end-of-run description/standard WarnCount exit non-zero (default off; opt-in for the test loop)

    # Table parameters
    [string]$TableName,
    # Explicit entity SchemaName, e.g. "hso_FixedPriceGroup". IMMUTABLE after creation (a PUT that
    # changes it returns 200 and is silently ignored) and it is what names the generated early-bound
    # class. Pass this for any multi-word table — the correct casing cannot be inferred from the
    # all-lowercase logical name. Omit for single-word tables to keep the legacy derived behaviour.
    [string]$SchemaName,
    [string]$DisplayName,
    [string]$DisplayNamePlural,
    [string]$Description,
    # HSO default: UserOwned for EVERY table, configuration and reference data included.
    # OrganizationOwned is not blocked, but it is never a routine choice -- a user-owned table with
    # Global depth reads identically today and can still be narrowed per role later, whereas an
    # org-owned table can only be secured by deleting and recreating it. Passing OrganizationOwned
    # emits a [WARN] naming the architect-approval requirement; -OrganizationOwnedApprovedBy
    # records who asked for it and downgrades the warning to an acknowledgement.
    [ValidateSet("UserOwned", "OrganizationOwned")]
    [string]$OwnershipType = "UserOwned",
    # Name of the solution architect who explicitly requested OrganizationOwned for this table.
    [string]$OrganizationOwnedApprovedBy,
    # NOTE: untyped (not [bool]) so the documented `powershell -File` invocation (every arg a STRING)
    # does not hard-fail [bool] argument-transformation before the body runs. Normalized to a real [bool]
    # in the body via ConvertTo-CoercedBool (coerce-and-warn). The `& ...ps1 -HasActivities $true` form is
    # unchanged. ADR 0025 — same treatment as $IsQuickCreateEnabled / $IncludeMetadata below.
    $HasActivities = $false,
    $HasNotes = $false,
    [switch]$IsActivity,                 # CreateTable: make the table a CUSTOM ACTIVITY (IsActivity=true). Forces HasActivities=false + UserOwned, defaults HasNotes/IsAvailableOffline to true, and defaults the primary to "<prefix>_subject_text" (display "Subject"). See references/custom-activity-web-api.md.
    [switch]$IsAvailableOffline,         # CreateTable: enable mobile offline (IsAvailableOffline=true). Recommended for activities so they sync to the mobile/Outlook timeline; usable on any table.
    [string]$PrimaryColumnName,          # Schema name for primary column (e.g., "hso_name_text"). For an activity, leave unset to default to "<prefix>_subject_text".
    [string]$PrimaryColumnDisplayName,   # Display name for primary column (e.g., "Name")
    [int]$PrimaryColumnMaxLength = 100,  # Max length for primary column (default: 100)
    [string]$PrimaryColumnDescription,   # HSO standard: description (tooltip) for the primary column
    [ValidateSet("None", "ApplicationRequired", "Recommended")]
    [string]$PrimaryColumnRequiredLevel,    # CreateTable: requirement level for the primary column (default ApplicationRequired) — set inline, no follow-up UpdateColumn
    [string]$PrimaryColumnAutoNumberFormat, # CreateTable: make the primary an auto-number (e.g. "AGR-{SEQNUM:5}") at create time — saves a CreateTable->UpdateColumn round-trip (seed still defaults to 1000)
    [int]$PrimaryColumnAutoNumberSeed = -1,  # CreateTable: set the runtime seed inline (e.g. 1 for AGR-00001). -1 = leave at the 1000 default. Only with -PrimaryColumnAutoNumberFormat.
    [int]$AutoNumberSeedValue = -1,          # SetAutoNumberSeed op: the seed value to set (uses -TableName + -ColumnName as Entity/Attribute)

    # Table-icon / web-resource parameters (CreateTable, SetTableIcon, CreateWebResource)
    # MSFT: custom-table icons are SVG web resources referenced by EntityMetadata.IconVectorName.
    # See references/table-icons-web-api.md + data-modeling-best-practices.md (Table icons).
    [string]$IconVectorName,             # CreateTable/SetTableIcon: name of an EXISTING SVG web resource to set as the table's IconVectorName (custom tables only).
    [string]$IconSvgPath,                # CreateTable/SetTableIcon/CreateWebResource: path to a local .svg file to upload (one of -IconSvgPath / -IconSvgContent). Bring your own art — see references/table-icons-web-api.md ("Getting an icon") for pulling a Fluent UI System Icon.
    [string]$IconSvgContent,             # ...: inline SVG markup (alternative to -IconSvgPath).
    [string]$WebResourceName,            # CreateWebResource (required) / CreateTable+SetTableIcon-from-source: unique name for the SVG web resource (prefix added if missing; default for CreateTable = "<table>_icon.svg").
    [string]$WebResourceDisplayName,     # CreateWebResource: friendly display name (defaults to the unique name).
    [string]$WebResourceDescription,     # CreateWebResource: description (HSO standard — [WARN] if omitted).

    # Relationship parameters
    [ValidateSet("OneToMany", "ManyToMany", "Customer")]
    [string]$RelationshipType,
    [string]$ParentTable,
    [string]$ChildTable,
    [string]$Entity1,
    [string]$Entity2,
    [string]$IntersectEntityName,
    [string]$LookupName,
    [string]$LookupDisplayName,
    [string]$LookupDescription,  # Description for the lookup column (shows as tooltip in model-driven apps). Required by HSO standard.
    [string]$ParentPrimaryKey,   # Override parent PK attribute (e.g., "activityid" for email entity)
    [ValidateSet("Cascade", "Active", "NoCascade", "RemoveLink", "Restrict")]
    [string]$CascadeDelete = "RemoveLink",
    [ValidateSet("Cascade", "Active", "NoCascade")]
    [string]$CascadeAssign = "NoCascade",
    [string]$RelationshipSchemaName,  # Optional: override auto-generated schema name (needed when creating a second relationship between the same two tables). AddRelationshipMapping: resolve parent/child from this relationship's metadata.

    # Relationship field-mapping parameters (for AddRelationshipMapping)
    [array]$Mappings,    # Array of {Source (parent col), Target (child col)} pairs — same inline-array shape as -Columns
    [string]$MappingsFile,  # PREFERRED: path to a UTF-8 JSON file holding that same array (dodges inline shell-escaping). Wins over -Mappings if both are given.

    # Global Choice parameters
    [string]$ChoiceName,
    [string]$ChoiceDisplayName,
    [string]$ChoiceDescription,
    [array]$Options,
    [int[]]$OptionValues,           # For DeleteOptionValue: list of integer option values to delete from a global choice

    # Column parameters
    [string]$ColumnName,
    [string]$ColumnDisplayName,
    [ValidateSet("String", "Memo", "Integer", "Decimal", "Money", "Boolean", "DateTime", "Picklist", "MultiSelectPicklist", "Rollup", "Calculated", "Formula")]
    [string]$ColumnType,
    # NOTE: $ColumnDescription is declared further down in the UpdateColumn parameter group;
    # it is shared by AddColumn (creation-time description) and UpdateColumn (description edits).
    # Untyped (not [int]/[bool]) for the same `powershell -File` string-passing reason as $HasActivities
    # above — these are the params a column build passes most often, and a fatal [int]/[bool] binding error
    # (e.g. "Cannot convert System.String to System.Int32" on -Precision) before the body was the observed
    # -File failure. Normalized to real [int]/[bool] in the body (ConvertTo-CoercedInt / ConvertTo-CoercedBool).
    $MaxLength = 100,
    $Precision = 2,
    $Required = $false,
    [string]$GlobalChoiceName,
    [ValidateSet("DateOnly", "DateAndTime")]
    [string]$DateTimeFormat = "DateAndTime",
    [ValidateSet("UserLocal", "DateOnly", "TimeZoneIndependent")]
    [string]$DateTimeBehavior,  # If not specified, defaults based on DateTimeFormat
    [ValidateSet("Text", "Email", "Url", "Phone", "TextArea")]
    [string]$StringFormat = "Text",
    $DefaultValue,  # Supports bool, int, or decimal depending on ColumnType
    [double]$ColumnMinValue,  # Min value for Integer/Decimal/Money columns (uses type default if not specified; pass 0 for non-negative currency)
    [double]$ColumnMaxValue,  # Max value for Integer/Decimal/Money columns (uses type default if not specified)

    # Specialized-column parameters (ADR 0057: rollup + Power Fx formula columns created headlessly
    # via a FormulaDefinition write — see references/rollup-formula-columns-web-api.md)
    [string]$FormulaExpression,       # -ColumnType Formula: the Power Fx expression, VERBATIM (e.g. "DateAdd(hso_enddate_date, -hso_leaddays_num, TimeUnit.Days)")
    [ValidateSet("String", "Decimal", "Boolean", "DateTime")]
    [string]$FormulaResultType,       # -ColumnType Formula: result type (maps to the typed attribute metadata class; DateTime defaults to DateOnly)
    [string]$RollupRelatedTable,      # -ColumnType Rollup: CHILD table logical name whose rows are aggregated
    [string]$RollupRelationship,      # -ColumnType Rollup: the 1:N relationship SCHEMA name between this table and the child (e.g. hso_serviceagreement_assetcoverage)
    [string]$RollupLookupColumn,      # -ColumnType Rollup: the child's lookup column (logical name) pointing at this table (e.g. hso_serviceagreement_id)
    [ValidateSet("Count", "Sum", "Min", "Max", "Avg")]
    [string]$RollupAggregate = "Count",
    [string]$RollupAggregateColumn,   # -ColumnType Rollup: child column to aggregate — required for Sum/Min/Max/Avg, ignored for Count (child PK is used)
    [string]$RollupFilterAttribute,   # -ColumnType Rollup: optional child state/status/choice column to filter on (e.g. statuscode)
    [int]$RollupFilterValue,          # -ColumnType Rollup: the option value a child row must Equal to qualify (e.g. 100000001)

    # Batch column parameters (for AddColumns operation)
    [array]$Columns,  # Array of column definitions: [{Name, DisplayName, Type, MaxLength, Precision, Required, GlobalChoiceName, DateTimeFormat, StringFormat, DefaultValue, MinValue, MaxValue}]
    [string]$ColumnsFile,  # PREFERRED: path to a UTF-8 JSON file holding that same array — write it with the Write tool to dodge inline shell-escaping. Wins over -Columns if both are given.

    # Publish parameters
    [array]$TablesToPublish,

    # Solution parameters
    [string]$SolutionUniqueName,
    [string]$SolutionDisplayName,
    [string]$SolutionDescription,
    [string]$PublisherName,
    # Naming prefix for tables/columns/choices. NO DEFAULT BY DESIGN -- it is resolved from the
    # project's CLAUDE.md ("Publisher prefix"), then README, then by prompting. A baked-in default
    # silently stamped one client's prefix onto every other client's schema. See Resolve-PublisherPrefix.
    [string]$PublisherPrefix,
    # Non-interactive callers (CI, unattended agents) that cannot answer a prompt: fail instead of
    # blocking forever when the prefix cannot be resolved from config.
    [switch]$NoPrompt,

    # Publisher management parameters (for CreatePublisher)
    [string]$PublisherDisplayName,     # Friendly name shown in UI
    [string]$PublisherUniqueName,      # Unique name for the publisher record (e.g., "HSOUSSolutionsTeam")
    [int]$OptionValuePrefix,           # Integer prefix for global choice values (e.g., 54031 → values start at 540310000)

    # Add to Solution parameters
    [string]$ComponentId,  # GUID of existing component to add
    [ValidateSet("Table", "Column", "Relationship", "GlobalChoice", "Form", "View", "Chart", "Dashboard", "WebResource", "PluginAssembly", "SDKMessageProcessingStep", "Workflow", "AppModule")]
    [string]$ComponentType,
    # NOTE: these two are deliberately UNTYPED (not [bool]). The documented `powershell -File`
    # invocation passes every arg as a STRING, so a bareword `-DoNotIncludeSubcomponents $true`
    # would fail [bool] argument-transformation ("Cannot process argument transformation", exit 1)
    # before the body ever ran. Leaving them untyped lets the body coerce-and-warn (see
    # ConvertTo-SolutionMembershipBool below) so the -File symptom no longer hard-fails. Existing
    # `& ...ps1 ... $true` (real boolean) callers continue to work unchanged. Default = $true.
    $IncludeMetadata = $true,  # For tables: add metadata only (not all assets)
    $DoNotIncludeSubcomponents = $true,  # For tables: don't include all columns, views, forms

    # UpdateColumn parameters
    [string]$AutoNumberFormat,  # e.g., "{SEQNUM:6}" or "ACC-{SEQNUM:6}" (auto-number conversion). The SEED is NOT set here — it is per-environment runtime counter state; set it via the SetAutoNumberSeed action (see references/autonumber-seed-web-api.md).
    [string]$ColumnDescription,  # Update column description
    [ValidateSet("None", "ApplicationRequired", "Recommended")]
    [string]$RequiredLevel,  # Update requirement level
    $IsAuditEnabled = $null,  # Enable/disable auditing (bool or $null)
    $IsValidForAdvancedFind = $null,  # Show/hide in Advanced Find (bool or $null)

    # App Module parameters
    [string]$AppUniqueName,        # Unique name for the app (e.g., "ContosoContracts")
    [string]$AppModuleId,          # Direct GUID of the app module (bypasses uniquename lookup; precise escape hatch when you already hold the GUID. Lookups are unpublished-aware, so AppUniqueName resolves unpublished apps too.)
    [string]$AppDisplayName,       # Display name shown in UI
    [string]$AppDescription,       # Description of the app
    [array]$TableNames,            # Array of table names for AddTablesToApp (e.g., @("hso_contract", "hso_amendment"))

    # Alternate Key parameters
    [string]$KeySchemaName,        # Schema name for the alternate key (e.g., "hso_code_key")
    [string]$KeyDisplayName,       # Display name for the alternate key
    [array]$KeyColumns,            # Array of column logical names that make up the key

    # Status Value parameters (for AddStatusValue/UpdateStatusLabel/SetStatusDefault/SetLifecycle operations)
    [string]$StatusLabel,          # Label for the status value (e.g., "Planning")
    [int]$StatusValue,             # Value for the status (e.g., 100000000) - auto-generated if not provided
    [ValidateSet(0, 1)]
    [int]$StateCode = 0,           # StateCode to link to: 0 = Active, 1 = Inactive
    [int]$DefaultStatusValue,      # SetStatusDefault: the statuscode value to make the default for -StateCode
    [array]$StatusReasons,         # SetLifecycle: ordered status-reason list [{Label, State(0|1), Value?, Default?}] (alternative to -SpecJsonPath)
    [string]$SpecJsonPath,         # SetLifecycle / declared-contract ops: read statusReasons[]/choices[] for -TableName/-ChoiceName from this spec.json

    # IsQuickCreateEnabled (UpdateTable): enable/disable the Quick Create form surface for this table.
    # When $true the table's Quick Create form (if one exists and is active) appears in the global + subgrid
    # create buttons. Pass $false only to explicitly disable; omit the param to leave the current value unchanged.
    $IsQuickCreateEnabled = $null  # bool or $null (untyped so -File string-passing does not hard-fail [bool] binding)
)


#region Configuration
$script:LanguageCode = 1033  # English
# Capture the caller's -PublisherPrefix BEFORE the line below runs. At SCRIPT scope
# $script:PublisherPrefix and the $PublisherPrefix PARAMETER are the same variable (PowerShell
# variable names are case-insensitive and the param block lives in script scope), so assigning
# $script:PublisherPrefix here silently discards whatever the caller passed. Same trap the
# SchemaName fix documents in New-DataverseTable.
$script:ExplicitPublisherPrefix = $PublisherPrefix

# Populated by Resolve-PublisherPrefix after the shared modules load -- never a literal default.
$script:PublisherPrefix = $null
$script:PublisherPrefixSource = $null
# Run-level tally of description/standard [WARN]s emitted, so the implicit "resolve all WARN before
# done" norm becomes a single observable line at the end of the run (see end-of-run summary).
$script:WarnCount = 0
#endregion

#region Validation


#endregion

#region Shared Module Imports
$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"
. "$sharedDir\Dataverse-WebApi.ps1"
. "$sharedDir\ProjectConfig.ps1"   # Find-RepoRoot / Get-MarkdownConfigValue -- prefix resolution
#endregion

#region Publisher prefix resolution

function Get-PublisherPrefixFromReadme {
    <#
    .SYNOPSIS
        Last documented source before prompting: a "Publisher prefix" row in the repo README.
    .DESCRIPTION
        CLAUDE.md is the canonical home, but some repos record the prefix in README.md instead.
        Reuses the same markdown-table reader so both files honour identical placeholder rules.
    #>
    param([Parameter(Mandatory)][string]$RepoPath)

    foreach ($name in @('README.md', 'Readme.md', 'readme.md')) {
        $path = Join-Path $RepoPath $name
        if (Test-Path -LiteralPath $path) {
            $value = Get-MarkdownConfigValue -Path $path -Key 'Publisher prefix'
            if ($value) { return $value }
        }
    }
    return $null
}

function Test-PublisherPrefixShape {
    <#
    .SYNOPSIS
        Dataverse customization prefixes are alphanumeric, 2-8 chars, starting with a letter.
    .DESCRIPTION
        Deliberately CASE-INSENSITIVE (-match, not -cmatch). Dataverse stores the prefix lowercase,
        and every caller here lowercases before use, so "ABC" in CLAUDE.md is a formatting slip
        rather than a different prefix -- accept and normalise it instead of failing the run.
    #>
    param([string]$Prefix)
    return [bool]($Prefix -and $Prefix -match '^[a-z][a-z0-9]{1,7}$')
}

function Resolve-PublisherPrefix {
    <#
    .SYNOPSIS
        Resolve the naming prefix from the caller, then project config, then the user. Never a default.

    .DESCRIPTION
        Precedence, highest first:
          1. -PublisherPrefix passed explicitly
          2. CLAUDE.md   -> 'Publisher prefix'   (canonical; written by hso-new-workspace)
          3. README.md   -> 'Publisher prefix'
          4. Prompt the user, and tell them to record it so this is a one-time cost

        This replaces a literal "hso" default. That default was invisible on HSO projects and
        actively wrong everywhere else: a caller who omitted the flag on a non-HSO project got
        components named hso_* under a publisher that did not own them -- unrecoverable once the
        table exists, because entity SchemaName is immutable.

        -NoPrompt turns step 4 into a hard failure, for CI and unattended agents that cannot answer.
    #>
    param(
        [string]$Explicit,
        [switch]$NoPrompt
    )

    if ($Explicit) {
        if (-not (Test-PublisherPrefixShape $Explicit)) {
            throw "Invalid -PublisherPrefix '$Explicit'. A Dataverse customization prefix is 2-8 characters, lowercase alphanumeric, starting with a letter."
        }
        return @{ Prefix = $Explicit.ToLower(); Source = '-PublisherPrefix parameter' }
    }

    $repoRoot = Find-RepoRoot -StartPath $PWD.Path
    if ($repoRoot) {
        $fromClaude = Get-MarkdownConfigValue -Path (Join-Path $repoRoot 'CLAUDE.md') -Key 'Publisher prefix'
        if ($fromClaude) {
            if (-not (Test-PublisherPrefixShape $fromClaude)) {
                throw "CLAUDE.md declares Publisher prefix '$fromClaude', which is not a valid Dataverse customization prefix (2-8 chars, lowercase alphanumeric, starts with a letter). Fix the row rather than passing -PublisherPrefix around it."
            }
            return @{ Prefix = $fromClaude.ToLower(); Source = "CLAUDE.md ($repoRoot)" }
        }

        $fromReadme = Get-PublisherPrefixFromReadme -RepoPath $repoRoot
        if ($fromReadme) {
            if (-not (Test-PublisherPrefixShape $fromReadme)) {
                throw "README declares Publisher prefix '$fromReadme', which is not a valid Dataverse customization prefix (2-8 chars, lowercase alphanumeric, starts with a letter)."
            }
            return @{ Prefix = $fromReadme.ToLower(); Source = "README ($repoRoot)" }
        }
    }

    # Nothing recorded. Normally this means the repo was not scaffolded by hso-new-workspace, or the
    # row was deleted -- so say that, rather than guessing a prefix that lands under a foreign publisher.
    $guidance = @(
        "No publisher prefix is configured for this repo.",
        "  It is normally recorded by hso-new-workspace as a 'Publisher prefix' row in CLAUDE.md:",
        "      | Publisher prefix | abc |",
        "  Add that row (or pass -PublisherPrefix) so every run names components consistently."
    ) -join "`n"

    if ($NoPrompt -or [Console]::IsInputRedirected) {
        throw ("$guidance`n  Running non-interactively, so there is nobody to ask. Aborting rather than " +
               "defaulting -- a wrong prefix is unrecoverable once a table is created.")
    }

    Write-Host ""
    Write-Host $guidance -ForegroundColor Yellow
    Write-Host ""
    $answer = Read-Host "Publisher prefix to use for this run (2-8 lowercase alphanumeric, e.g. 'abc')"
    $answer = ($answer | ForEach-Object { $_ }) -as [string]
    if ($answer) { $answer = $answer.Trim().ToLower() }
    if (-not (Test-PublisherPrefixShape $answer)) {
        throw "'$answer' is not a valid Dataverse customization prefix (2-8 characters, lowercase alphanumeric, starting with a letter)."
    }

    Write-Host ""
    Write-Host "  [ACTION] Record this so it is asked once, not every run:" -ForegroundColor Yellow
    Write-Host "           add   | Publisher prefix | $answer |   to CLAUDE.md" -ForegroundColor Yellow
    Write-Host ""
    return @{ Prefix = $answer; Source = 'interactive prompt (NOT persisted -- record it in CLAUDE.md)' }
}

$__prefixResolution = Resolve-PublisherPrefix -Explicit $script:ExplicitPublisherPrefix -NoPrompt:$NoPrompt
$script:PublisherPrefix       = $__prefixResolution.Prefix
$script:PublisherPrefixSource = $__prefixResolution.Source

$script:KnownPublisherPrefixes = $null

function Get-KnownPublisherPrefixes {
    <#
    .SYNOPSIS
        Customization prefixes registered in the target org, lowercased. Cached; [] if unavailable.
    .DESCRIPTION
        Used only to tell "this name already carries SOME publisher's prefix" apart from "the first
        word of this name happens to be followed by an underscore". Degrades to an empty set when
        the org cannot be queried, which makes Test-NameAlreadyPrefixed fall back to comparing
        against the resolved prefix alone.
    #>
    if ($null -ne $script:KnownPublisherPrefixes) { return $script:KnownPublisherPrefixes }
    $script:KnownPublisherPrefixes = @()
    try {
        $resp = Invoke-DataverseWebApi -Method "GET" `
            -Endpoint "publishers?`$select=customizationprefix" -IsMetadataOperation $false
        if ($resp.value) {
            $script:KnownPublisherPrefixes = @(
                $resp.value | ForEach-Object { $_.customizationprefix } |
                    Where-Object { $_ } | ForEach-Object { $_.ToLower() } | Select-Object -Unique
            )
        }
    } catch {
        Write-Host "  [INFO] Could not list publishers to validate name prefixes ($($_.Exception.Message)). " -ForegroundColor DarkGray
    }
    return $script:KnownPublisherPrefixes
}

function Test-NameAlreadyPrefixed {
    <#
    .SYNOPSIS
        Does $Name already carry a publisher prefix?

    .DESCRIPTION
        The old rule was the regex ^[a-z][a-z0-9]*_ -- "anything with a leading token and an
        underscore". That cannot tell a publisher prefix from the first word of a compound name, so
        "service_agreement" was read as already-prefixed and got NO prefix applied at all.

        The rule now is specific: the leading token counts as a prefix only when it IS the resolved
        publisher prefix, or a prefix actually registered in the target org (which preserves the
        original intent of not double-prefixing e.g. "hsosol_project" on an "hso" project).
        Everything else -- including underscored compound names -- is treated as unprefixed.
    #>
    param([Parameter(Mandatory)][string]$Name)

    if ($Name -notmatch '^([a-z][a-z0-9]*)_') { return $false }
    $leading = $Matches[1].ToLower()

    if ($leading -eq $script:PublisherPrefix.ToLower()) { return $true }
    if ((Get-KnownPublisherPrefixes) -contains $leading) { return $true }
    return $false
}

function Get-NamePublisherPrefix {
    <#
    .SYNOPSIS
        The publisher prefix $Name actually carries, or the resolved prefix when it carries none.
    #>
    param([Parameter(Mandatory)][string]$Name)

    if ((Test-NameAlreadyPrefixed -Name $Name) -and $Name -match '^([a-z][a-z0-9]*)_') {
        return $Matches[1].ToLower()
    }
    return $script:PublisherPrefix
}

function Add-PublisherPrefix {
    <#
    .SYNOPSIS
        Return $Name carrying the resolved publisher prefix, adding it only when genuinely absent.
    #>
    param([Parameter(Mandatory)][string]$Name)

    if (Test-NameAlreadyPrefixed -Name $Name) { return $Name }

    # A compound name that LOOKS prefixed but is not gets prefixed, with a note -- silently
    # producing "abc_service_agreement" from "service_agreement" is right, but surprising enough
    # to say out loud in case the caller meant to pass a fully-qualified name.
    if ($Name -match '^([a-z][a-z0-9]*)_') {
        Write-Host "  [INFO] '$Name' has no publisher prefix ('$($Matches[1])' is not one) -- naming it '$($script:PublisherPrefix)_$Name'." -ForegroundColor DarkGray
    }
    return "$($script:PublisherPrefix)_$Name"
}
#endregion

#region Helper Functions

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Recursively converts a PSCustomObject to an ordered hashtable.
        Required for PowerShell 5.1 compatibility (no -AsHashtable on ConvertFrom-Json).
    #>
    param([Parameter(ValueFromPipeline = $true)]$InputObject)

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $collection = @()
        foreach ($item in $InputObject) {
            $collection += ConvertTo-Hashtable $item
        }
        return ,$collection
    }

    if ($InputObject -is [psobject]) {
        $hash = [ordered]@{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $hash[$prop.Name] = ConvertTo-Hashtable $prop.Value
        }
        return $hash
    }

    return $InputObject
}

function New-LabelStructure {
    <#
    .SYNOPSIS
        Creates a localized label structure for Web API.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [int]$LanguageCode = 1033
    )

    return @{
        "@odata.type" = "Microsoft.Dynamics.CRM.Label"
        "LocalizedLabels" = @(
            @{
                "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"
                "Label" = $Label
                "LanguageCode" = $LanguageCode
            }
        )
    }
}

function New-RequiredLevel {
    param([bool]$Required = $false)

    $value = if ($Required) { "ApplicationRequired" } else { "None" }
    return @{ "Value" = $value }
}

function ConvertTo-SolutionMembershipBool {
    <#
    .SYNOPSIS
        Coerce-and-warn for the solution-membership flags (-DoNotIncludeSubcomponents / -IncludeMetadata).
    .DESCRIPTION
        These params are declared UNTYPED so the documented `powershell -File` invocation (which
        passes every arg as a STRING) doesn't hard-fail [bool] argument-transformation. This helper
        does the conservative coercion: a real boolean passes straight through; the -File string
        symptom ('True'/'False'/'$true'/'$false') is coerced with a one-line [WARN] naming the
        call-operator form so the caller learns the correct override syntax. It is deliberately
        NOT a silent acceptance — every string-coerced value prints a warning.
    #>
    param(
        [Parameter(Mandatory = $true)] [AllowNull()] $Value,
        [Parameter(Mandatory = $true)] [string]$ParamName,
        [bool]$Default = $true
    )

    if ($null -eq $Value) { return $Default }
    if ($Value -is [bool]) { return $Value }                 # real boolean (& call-operator form) — pass through
    if ($Value -is [int])  { return ([bool]$Value) }         # 0/1 numeric — pass through

    # Anything else arrived as a string — the `-File` symptom. Coerce + warn.
    $raw = [string]$Value
    $normalized = $raw.Trim().TrimStart('$')                 # accept '$true' / '$false' as well as 'True'/'False'
    try {
        $coerced = [System.Convert]::ToBoolean($normalized)
    }
    catch {
        throw "Cannot interpret -$ParamName value '$raw' as a boolean. Use the call-operator form, e.g. & `"....ps1`" -$ParamName`:`$false"
    }
    Write-Host "  [WARN] -$ParamName arrived as the string '$raw' (the ``powershell -File`` symptom) and was" -ForegroundColor Yellow
    Write-Host "         coerced to [bool]$coerced. The -File form passes every arg as a string, so a bareword" -ForegroundColor Yellow
    Write-Host "         `$true/`$false fails [bool] binding. To override deliberately, use the call-operator form:" -ForegroundColor Yellow
    Write-Host "           & `".../Invoke-DataverseMetadataOperation.ps1`" ... -$ParamName`:`$$($coerced.ToString().ToLower())" -ForegroundColor Cyan
    return $coerced
}

function ConvertTo-CoercedBool {
    <#
    .SYNOPSIS
        Coerce-and-warn for a scalar [bool] param declared UNTYPED for `powershell -File` safety.
    .DESCRIPTION
        Same contract as ConvertTo-SolutionMembershipBool but generic (used for -HasActivities/-HasNotes/
        -Required). A real boolean (& call-operator form) or numeric 0/1 passes straight through; the -File
        string symptom ('True'/'False'/'$true'/'$false') is coerced with a one-line [WARN] pointing at the
        call-operator override. Never a silent acceptance.
    #>
    param(
        [Parameter(Mandatory = $true)] [AllowNull()] $Value,
        [Parameter(Mandatory = $true)] [string]$ParamName,
        [bool]$Default = $false
    )
    if ($null -eq $Value) { return $Default }
    if ($Value -is [bool]) { return $Value }
    if ($Value -is [int])  { return ([bool]$Value) }
    $raw = [string]$Value
    $normalized = $raw.Trim().TrimStart('$')
    try { $coerced = [System.Convert]::ToBoolean($normalized) }
    catch { throw "Cannot interpret -$ParamName value '$raw' as a boolean. Use the call-operator form, e.g. & `"....ps1`" -$ParamName`:`$false" }
    Write-Host "  [WARN] -$ParamName arrived as the string '$raw' (the ``powershell -File`` symptom) and was coerced to [bool]$coerced." -ForegroundColor Yellow
    Write-Host "         To set it deliberately, use the call-operator form: & `"...ps1`" ... -$ParamName`:`$$($coerced.ToString().ToLower())" -ForegroundColor Cyan
    return $coerced
}

function ConvertTo-CoercedInt {
    <#
    .SYNOPSIS
        Coerce-and-warn for a scalar [int] param declared UNTYPED for `powershell -File` safety
        (-MaxLength/-Precision). A real int passes through; a numeric string is parsed with a one-line
        [WARN]; an array (the collapsed/misbound -File symptom) or non-numeric value throws an actionable
        error rather than the cryptic "Cannot convert System.Object[] to System.Int32".
    #>
    param(
        [Parameter(Mandatory = $true)] [AllowNull()] $Value,
        [Parameter(Mandatory = $true)] [string]$ParamName,
        [int]$Default = 0
    )
    if ($null -eq $Value) { return $Default }
    if ($Value -is [int]) { return $Value }
    if ($Value -is [System.Array]) {
        throw "-$ParamName received an array ($(@($Value).Count) values) — likely a misbound ``powershell -File`` argument. Pass a single integer, e.g. & `"...ps1`" ... -$ParamName 5."
    }
    $raw = [string]$Value
    $parsed = 0
    if (-not [int]::TryParse($raw.Trim(), [ref]$parsed)) {
        throw "Cannot interpret -$ParamName value '$raw' as an integer."
    }
    Write-Host "  [WARN] -$ParamName arrived as the string '$raw' (the ``powershell -File`` symptom) and was coerced to [int]$parsed." -ForegroundColor Yellow
    return $parsed
}

function Write-DescriptionWarning {
    <#
    .SYNOPSIS
        Emits a yellow warning when a metadata component is created without a description.
    .DESCRIPTION
        HSO standard: every table, column, lookup, global choice, view, form, model-driven app,
        and solution must carry a Description. For columns specifically, the description renders
        as the tooltip when users hover the field label in model-driven apps — so an empty
        description means an empty tooltip.

        This helper warns rather than blocks so existing automation does not break, but the
        warning surfaces every miss for the agent to fix in the same session.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComponentKind,   # e.g. "table", "column", "lookup", "global choice"
        [Parameter(Mandatory = $true)]
        [string]$ComponentName,
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Description)) {
        $script:WarnCount++
        Write-Host "  [WARN] No description provided for $ComponentKind '$ComponentName'." -ForegroundColor Yellow
        Write-Host "         HSO standard: every $ComponentKind must have a Description (tooltip / spec traceability)." -ForegroundColor Yellow
        Write-Host "         See: shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md (Descriptions are mandatory)." -ForegroundColor Yellow
    }
}

function Write-AutoNumberSeedNote {
    <#
    .SYNOPSIS
        Prints the auto-number seed guidance after a column is given an AutoNumberFormat.
    .DESCRIPTION
        Two distinct traps, both silent in the AutoNumberFormat PUT output:
        (1) NEW/EMPTY table: Dataverse seeds a fresh auto-number counter at 1000, so the FIRST
            record is ...01000, NOT ...00001. Any requirement for a low starting number (e.g.
            AGR-00001) REQUIRES an explicit SetAutoNumberSeed -Value 1 -- the format alone won't
            do it. This is a correctness bug, not just cosmetics.
        (2) POPULATED table: seed to max+1 (query current max via hso-dataverse-data) so you don't
            collide on the alternate key.
        The seed is per-environment runtime counter state, not metadata, so it is never set by the
        format PUT and never travels in the solution.
    #>
    param(
        [string]$AutoNumberFormat,
        [string]$EntityName,     # logical name of the table — used to print a ready-to-run command
        [string]$AttributeName   # logical name of the auto-number column
    )

    Write-Host ""
    Write-Host "  [SEED] The auto-number SEED is runtime counter state (not metadata), so the format" -ForegroundColor Yellow
    Write-Host "         PUT above did NOT set it -- it stays environment-local and out of the solution." -ForegroundColor Yellow
    Write-Host "         * NEW/EMPTY table: the default seed is 1000, so the first record is ...01000," -ForegroundColor Yellow
    Write-Host "           NOT ...00001. If you need a low start (e.g. AGR-00001) you MUST seed explicitly." -ForegroundColor Yellow
    Write-Host "         * POPULATED table: query the current max sequence via hso-dataverse-data and" -ForegroundColor Yellow
    Write-Host "           seed to max+1 so you don't collide on the key." -ForegroundColor Yellow
    if ($EntityName -and $AttributeName) {
        # Ready-to-run, values already substituted for the column just created.
        Write-Host "         Ready-to-run (set first record to ...00001 — change Value as needed):" -ForegroundColor White
        Write-Host "           `$body = @{ EntityName = '$EntityName'; AttributeName = '$AttributeName'; Value = 1 }" -ForegroundColor Cyan
        Write-Host "           Invoke-DataverseWebApi -Method POST -Endpoint 'SetAutoNumberSeed' -Body `$body" -ForegroundColor Cyan
        Write-Host "         Or set it inline at table creation: CreateTable -PrimaryColumnAutoNumberSeed 1" -ForegroundColor White
    } else {
        Write-Host "             POST SetAutoNumberSeed { EntityName, AttributeName, Value: 1 }" -ForegroundColor White
    }
    Write-Host "         See references/autonumber-seed-web-api.md for the validated example." -ForegroundColor White
    Write-Host ""
}

function Write-IconWarning {
    <#
    .SYNOPSIS
        Emits a yellow warning when a new custom table is created without a custom icon.
    .DESCRIPTION
        HSO standard (optional, like descriptions): a custom table without an IconVectorName uses the
        generic default cube icon, which makes it indistinguishable from every other custom table in the
        sitemap and lookups. This warns rather than blocks (the user chose "optional + warn"); it counts
        toward the run-level WARN tally so the miss is observable.
    #>
    param([Parameter(Mandatory = $true)][string]$TableName)

    $script:WarnCount++
    Write-Host "  [WARN] No icon set for table '$TableName' — it will use the default cube icon." -ForegroundColor Yellow
    Write-Host "         HSO standard (optional): set a custom SVG icon so the table is distinguishable in apps/sitemap." -ForegroundColor Yellow
    Write-Host "         Provide -IconVectorName (existing SVG web resource), or your own SVG art" -ForegroundColor Yellow
    Write-Host "         (-IconSvgPath / -IconSvgContent) with -WebResourceName." -ForegroundColor Yellow
    Write-Host "         Need artwork? Pull a 16px glyph from Microsoft Fluent UI System Icons" -ForegroundColor Yellow
    Write-Host "         (https://github.com/microsoft/fluentui-system-icons), set fill=`"currentColor`", then pass it." -ForegroundColor Yellow
    Write-Host "         See: shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md (Table icons)." -ForegroundColor Yellow
}

function Test-DataverseSvgIcon {
    <#
    .SYNOPSIS
        Validates SVG markup against Microsoft's custom-table-icon rules. Returns the content or throws.
    .DESCRIPTION
        Microsoft's rules for SVG used as a table icon (IconVectorName), from MS Learn:
          - All image web resources must be <= 10 KB.
          - The <svg> must declare a default size (width/height/viewBox) so it renders at 16x16.
          - Prefer fill="currentColor" over hard-coded hex so the app themes the icon (contrast). Embedded
            <style>/class blocks leak across SVGs — use a fill/style attribute instead.
        SECURITY (the important one): Dataverse does NOT sanitize SVG web resources — they are treated
        like Script (JScript) web resources and "SVG files allow JScript embedding", so a script-bearing
        icon executes in the user's security context. We therefore HARD-REFUSE <script>, on*= event
        handlers, and external/data href references. The theming issues are WARN-only.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SvgContent,
        [string]$SourceLabel = "SVG"
    )

    if ([string]::IsNullOrWhiteSpace($SvgContent)) {
        throw "Icon source '$SourceLabel' is empty — expected SVG markup."
    }
    if ($SvgContent -notmatch '(?is)<svg[\s>]') {
        throw "Icon '$SourceLabel' has no <svg> root element — it is not an SVG document."
    }
    # 10 KB hard limit. The upload is base64 of the UTF-8 bytes, so measure UTF-8 byte length.
    $byteLen = [System.Text.Encoding]::UTF8.GetByteCount($SvgContent)
    if ($byteLen -gt 10240) {
        throw "Icon '$SourceLabel' is $byteLen bytes; Dataverse image web resources must be <= 10 KB (10240 bytes). Simplify the SVG (fewer/merged paths, no embedded raster)."
    }
    # SECURITY refusals — Dataverse serves SVG as-is (no sanitization).
    if ($SvgContent -match '(?is)<script[\s>]') {
        throw "Icon '$SourceLabel' contains a <script> element. Dataverse does not sanitize SVG (it carries the same risk as a JS web resource); a script-bearing icon runs in the user's security context. Remove it."
    }
    if ($SvgContent -match '(?i)\son[a-z]+\s*=\s*["'']') {
        throw "Icon '$SourceLabel' contains an inline event handler (on*= attribute). SVG icons must be inert — remove it."
    }
    if ($SvgContent -match '(?i)href\s*=\s*["'']?\s*(?:https?:|//|data:)') {
        throw "Icon '$SourceLabel' references an external or data: resource (href). Inline the artwork; external references are unsafe and unsupported for table icons."
    }
    # viewBox is required for a defined default size.
    if ($SvgContent -notmatch '(?i)viewBox\s*=') {
        throw "Icon '$SourceLabel' has no viewBox attribute. Add width/height/viewBox so the icon has a default size (e.g. viewBox=`"0 0 16 16`")."
    }
    # Theming WARN-only checks.
    if ($SvgContent -match '(?i)fill\s*[:=]\s*["'']?\s*#[0-9a-f]') {
        $script:WarnCount++
        Write-Host "  [WARN] Icon '$SourceLabel' uses a hard-coded fill color (#...)." -ForegroundColor Yellow
        Write-Host "         MSFT guidance: use fill=`"currentColor`" so the icon themes correctly and avoids contrast issues." -ForegroundColor Yellow
    }
    if ($SvgContent -match '(?is)<style[\s>]') {
        $script:WarnCount++
        Write-Host "  [WARN] Icon '$SourceLabel' contains an embedded <style> block." -ForegroundColor Yellow
        Write-Host "         MSFT guidance: avoid embedded stylesheets/classes (they leak across SVGs sharing a class); use a fill/style attribute." -ForegroundColor Yellow
    }
    return $SvgContent
}

function Resolve-IconSvgSource {
    <#
    .SYNOPSIS
        Returns SVG markup from exactly one of -IconSvgPath / -IconSvgContent (or $null if none).
    .DESCRIPTION
        Bring-your-own art: a local .svg path or inline markup. Returns a hashtable
        @{ Svg = <markup>; Label = <source label> } or $null. Need a glyph? Pull a 16px icon from Microsoft
        Fluent UI System Icons (https://github.com/microsoft/fluentui-system-icons), set fill="currentColor",
        and pass it via -IconSvgPath. See references/table-icons-web-api.md ("Getting an icon").
    #>
    param(
        [string]$IconSvgPath,
        [string]$IconSvgContent
    )

    $provided = @(
        @($IconSvgPath, $IconSvgContent) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    if ($provided.Count -eq 0) { return $null }
    if ($provided.Count -gt 1) {
        throw "Provide only ONE icon source: -IconSvgPath or -IconSvgContent (got $($provided.Count))."
    }

    if (-not [string]::IsNullOrWhiteSpace($IconSvgContent)) {
        return @{ Svg = $IconSvgContent; Label = "inline SVG" }
    }
    if (-not (Test-Path -LiteralPath $IconSvgPath)) { throw "IconSvgPath not found: $IconSvgPath" }
    return @{ Svg = (Get-Content -Raw -Encoding UTF8 -LiteralPath $IconSvgPath); Label = (Split-Path -Leaf $IconSvgPath) }
}

function New-DataverseWebResource {
    <#
    .SYNOPSIS
        Creates (or updates) an SVG web resource, adds it to the solution, and publishes it.
    .DESCRIPTION
        Validates the SVG (Test-DataverseSvgIcon), prefixes the unique name with the publisher prefix,
        base64-encodes the UTF-8 content, and POSTs to webresourceset (webresourcetype 11 = SVG).
        Idempotent: an existing web resource of the same name is PATCHed in place rather than 400-ing.
        Publishes the web resource so any table that references it via IconVectorName resolves on publish.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$WebResourceName,
        [Parameter(Mandatory = $true)][string]$SvgContent,
        [string]$DisplayName,
        [string]$Description,
        [string]$SolutionName,
        [string]$SourceLabel = "SVG"
    )

    Write-Host "`n=== Creating SVG Web Resource: $WebResourceName ===" -ForegroundColor Cyan

    # Validate against MSFT table-icon rules (size / script / external / viewBox). Throws on hard failures.
    $SvgContent = Test-DataverseSvgIcon -SvgContent $SvgContent -SourceLabel $SourceLabel

    # Prefix the unique name with the publisher prefix if not already prefixed (same rule as tables).
    $name = Add-PublisherPrefix -Name $WebResourceName
    Write-DescriptionWarning -ComponentKind "web resource" -ComponentName $name -Description $Description

    $base64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($SvgContent))
    $escaped = $name.Replace("'", "''")

    # Idempotent: reuse-and-update an existing web resource of the same name.
    $existing = Invoke-DataverseWebApi -Method "GET" `
        -Endpoint "webresourceset?`$filter=name eq '$escaped'&`$select=webresourceid,name,webresourcetype" `
        -IsMetadataOperation $false
    $webResourceId = $null

    if ($existing.value -and $existing.value.Count -gt 0) {
        $webResourceId = $existing.value[0].webresourceid
        if ([int]$existing.value[0].webresourcetype -ne 11) {
            throw "Web resource '$name' already exists but is not an SVG (webresourcetype=$($existing.value[0].webresourcetype)). Refusing to repurpose it; choose a different -WebResourceName."
        }
        Write-Host "  Web resource exists; updating content: $name ($webResourceId)" -ForegroundColor Yellow
        $patch = @{ "content" = $base64 }
        if ($DisplayName) { $patch["displayname"] = $DisplayName }
        if ($Description) { $patch["description"] = $Description }
        # [void]: uncaptured PATCH response would leak into the function return and pollute $wr.Name.
        [void](Invoke-DataverseWebApi -Method "PATCH" -Endpoint "webresourceset($webResourceId)" -Body $patch -SolutionName $SolutionName -IsMetadataOperation $false)
    }
    else {
        $body = @{
            "name"            = $name
            "displayname"     = if ($DisplayName) { $DisplayName } else { $name }
            "webresourcetype" = 11   # 11 = SVG (Vector Format)
            "content"         = $base64
        }
        if ($Description) { $body["description"] = $Description }
        Write-Host "  Unique Name: $name" -ForegroundColor Gray
        Write-Host "  Type: 11 (SVG)" -ForegroundColor Gray
        [void](Invoke-DataverseWebApi -Method "POST" -Endpoint "webresourceset" -Body $body -SolutionName $SolutionName -IsMetadataOperation $false)
        # Re-query for the clean GUID (don't rely on the OData-EntityId URL shape).
        $re = Invoke-DataverseWebApi -Method "GET" -Endpoint "webresourceset?`$filter=name eq '$escaped'&`$select=webresourceid" -IsMetadataOperation $false
        if ($re.value -and $re.value.Count -gt 0) { $webResourceId = $re.value[0].webresourceid }
        Write-Host "  Web resource created: $name ($webResourceId)" -ForegroundColor Green
    }

    # Publish the web resource so it is available before any table references it.
    # NOTE: [void] is REQUIRED — an uncaptured PublishXml response leaks into this function's pipeline
    # output, so callers receive @(publishResponse, pscustomobject) and `$wr.Name` resolves wrong
    # (SetTableIcon then throws "cannot call a method on a null-valued expression").
    if ($webResourceId) {
        $publishBody = @{ ParameterXml = "<importexportxml><webresources><webresource>$webResourceId</webresource></webresources></importexportxml>" }
        [void](Invoke-DataverseWebApi -Method "POST" -Endpoint "PublishXml" -Body $publishBody -IsMetadataOperation $false)
        Write-Host "  Web resource published." -ForegroundColor Green
    }

    return [pscustomobject]@{ Name = $name; WebResourceId = $webResourceId }
}

function Set-DataverseTableIcon {
    <#
    .SYNOPSIS
        Sets EntityMetadata.IconVectorName on a CUSTOM table to an SVG web resource, then publishes.
    .DESCRIPTION
        Refuses on system tables (Microsoft does not allow changing system-table icons). Accepts either an
        existing web resource name (-IconVectorName) or raw SVG (-SvgContent + -WebResourceName), in which
        case it creates/publishes the web resource first via New-DataverseWebResource. Verifies the target
        web resource exists and is an SVG before pointing the table at it (a dangling IconVectorName
        silently no-ops on publish), and read-back-verifies the applied value (don't trust the PUT banner).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$TableName,
        [string]$IconVectorName,
        [string]$SvgContent,
        [string]$WebResourceName,
        [string]$WebResourceDisplayName,
        [string]$WebResourceDescription,
        [string]$SolutionName,
        [string]$SourceLabel = "SVG"
    )

    Write-Host "`n=== Setting Table Icon: $TableName ===" -ForegroundColor Cyan
    $tableLower = $TableName.ToLower()

    # Read the table; refuse on system tables.
    $meta = Invoke-DataverseWebApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$tableLower')?`$select=MetadataId,LogicalName,IsCustomEntity,IconVectorName"
    if (-not $meta.IsCustomEntity) {
        throw "Table '$tableLower' is a system table. Microsoft does not allow changing the icon of system tables (only custom tables). Refusing."
    }

    # If raw SVG was supplied, create/publish the web resource first and use its (prefixed) name.
    $iconName = $IconVectorName
    if ($SvgContent) {
        if (-not $WebResourceName) {
            throw "WebResourceName is required when setting a table icon from raw SVG (-IconSvgPath/-IconSvgContent)."
        }
        $wr = New-DataverseWebResource -WebResourceName $WebResourceName -SvgContent $SvgContent `
            -DisplayName $WebResourceDisplayName -Description $WebResourceDescription `
            -SolutionName $SolutionName -SourceLabel $SourceLabel
        $iconName = $wr.Name
    }
    if (-not $iconName) {
        throw "No icon to set — pass -IconVectorName (an existing SVG web resource) or an icon source (-IconSvgPath/-IconSvgContent) with -WebResourceName."
    }

    # Verify the web resource exists and is an SVG — a dangling/non-SVG IconVectorName silently no-ops.
    $escaped = $iconName.Replace("'", "''")
    $wrCheck = Invoke-DataverseWebApi -Method "GET" -Endpoint "webresourceset?`$filter=name eq '$escaped'&`$select=webresourceid,webresourcetype" -IsMetadataOperation $false
    if (-not $wrCheck.value -or $wrCheck.value.Count -eq 0) {
        throw "Web resource '$iconName' not found. Create it first (CreateWebResource) or pass an icon source so SetTableIcon creates it."
    }
    if ([int]$wrCheck.value[0].webresourcetype -ne 11) {
        throw "Web resource '$iconName' is not an SVG (webresourcetype != 11). IconVectorName requires an SVG web resource."
    }

    # PUT IconVectorName on the entity metadata.
    $updateBody = @{
        "@odata.type"    = "Microsoft.Dynamics.CRM.EntityMetadata"
        "MetadataId"     = $meta.MetadataId
        "IconVectorName" = $iconName
    }
    # [void] on the write calls below: this function returns $verify (read-back), so any uncaptured
    # PUT/PublishXml response would leak into the pipeline and pollute the returned object.
    [void](Invoke-DataverseWebApi -Method "PUT" -Endpoint "EntityDefinitions(LogicalName='$tableLower')" -Body $updateBody -SolutionName $SolutionName)
    Write-Host "  [OK] IconVectorName set to '$iconName'" -ForegroundColor Green

    # Publish the table so the icon takes effect.
    $publishBody = @{ ParameterXml = "<importexportxml><entities><entity>$tableLower</entity></entities></importexportxml>" }
    [void](Invoke-DataverseWebApi -Method "POST" -Endpoint "PublishXml" -Body $publishBody -IsMetadataOperation $false)
    Write-Host "  [OK] Published $tableLower" -ForegroundColor Green

    # Read-back verification — verify by metadata, not the PUT success banner.
    $verify = Invoke-DataverseWebApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$tableLower')?`$select=IconVectorName"
    if ($verify.IconVectorName -eq $iconName) {
        Write-Host "  [VERIFY] IconVectorName = '$($verify.IconVectorName)'" -ForegroundColor Green
    }
    else {
        $script:WarnCount++
        Write-Host "  [WARN] Read-back IconVectorName = '$($verify.IconVectorName)' (expected '$iconName'). Re-check the web resource exists/published." -ForegroundColor Yellow
    }
    return $verify
}

function Set-DataverseAutoNumberSeed {
    <#
    .SYNOPSIS
        Sets the runtime auto-number seed for a column via the SetAutoNumberSeed action.
    .DESCRIPTION
        The seed is per-environment runtime counter state (not metadata, not in the solution).
        This is the single highest-frequency manual step after assigning an AutoNumberFormat —
        offered as a thin, safety-bearing helper so callers don't have to drop out of the skill
        and hand-write the POST. ADR-0013: composing the documented action with the value the
        caller already knows, not a 1:1 wrapper of an arbitrary write endpoint.
    #>
    param(
        [Parameter(Mandatory = $true)] [string]$EntityName,
        [Parameter(Mandatory = $true)] [string]$AttributeName,
        [Parameter(Mandatory = $true)] [int]$Value
    )
    Write-Host "`n  Setting auto-number seed: $EntityName.$AttributeName = $Value" -ForegroundColor Cyan
    $body = @{ EntityName = $EntityName.ToLower(); AttributeName = $AttributeName.ToLower(); Value = $Value }
    $null = Invoke-DataverseWebApi -Method "POST" -Endpoint "SetAutoNumberSeed" -Body $body
    Write-Host "  [OK] Seed set — the next record created will use $Value (then increment)." -ForegroundColor Green
}

function Get-PacCliPath {
    <#
    .SYNOPSIS
        Finds the PAC CLI executable path.
    .DESCRIPTION
        Searches common installation locations for the Power Platform CLI (pac.exe).
        Returns the path if found, otherwise throws an error.
    #>

    # Check for PacPath parameter from script invocation
    if ($script:PacPath -and (Test-Path $script:PacPath)) {
        return $script:PacPath
    }

    # Common PAC CLI locations
    $commonPaths = @(
        # VS Code Extension (most common)
        "$env:APPDATA\Code\User\globalStorage\microsoft-isvexptools.powerplatform-vscode\pac\tools\pac.exe",
        # Standalone installation
        "C:\Program Files\Microsoft Power Platform CLI\pac.exe",
        # dotnet tool
        "$env:USERPROFILE\.dotnet\tools\pac.exe"
    )

    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            Write-Host "  Found PAC CLI at: $path" -ForegroundColor Gray
            return $path
        }
    }

    # Try to find pac in PATH
    try {
        $pacInPath = Get-Command pac -ErrorAction SilentlyContinue
        if ($pacInPath) {
            Write-Host "  Found PAC CLI in PATH: $($pacInPath.Source)" -ForegroundColor Gray
            return $pacInPath.Source
        }
    } catch { }

    throw "PAC CLI (pac.exe) not found. Please install the Power Platform CLI or provide the path via -PacPath parameter."
}

function Get-GlobalOptionSetId {
    <#
    .SYNOPSIS
        Retrieves the MetadataId (GUID) of a global option set by name.
    #>
    param([string]$OptionSetName)

    # Use direct query by name (alternate key)
    $endpoint = "GlobalOptionSetDefinitions(Name='$OptionSetName')?`$select=MetadataId,Name"

    try {
        $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint
        if ($result -and $result.MetadataId) {
            return $result.MetadataId
        }
        Write-Host "  Warning: Global option set '$OptionSetName' not found" -ForegroundColor Yellow
        return $null
    }
    catch {
        Write-Host "  Warning: Failed to lookup global option set '$OptionSetName'" -ForegroundColor Yellow
        return $null
    }
}

function Get-PublisherOptionValuePrefix {
    <#
    .SYNOPSIS
        Retrieves the customizationoptionvalueprefix for a publisher by its schema prefix.
    .DESCRIPTION
        Queries the publisher entity to get the option value prefix used for generating
        global option set values. The prefix is multiplied by 10000 to get the base value.
    .EXAMPLE
        Get-PublisherOptionValuePrefix -PublisherPrefix "hso"
        Returns 54031 (or whatever the publisher's prefix is configured as)
    #>
    param([string]$PublisherPrefix)

    $endpoint = "publishers?`$filter=customizationprefix eq '$PublisherPrefix'&`$select=publisherid,uniquename,customizationprefix,customizationoptionvalueprefix"

    try {
        $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint -IsMetadataOperation $false
        if ($result.value -and $result.value.Count -gt 0) {
            $prefix = $result.value[0].customizationoptionvalueprefix
            Write-Host "  Found publisher '$PublisherPrefix' with option value prefix: $prefix" -ForegroundColor Gray
            return $prefix
        }
        Write-Host "  Warning: Publisher with prefix '$PublisherPrefix' not found" -ForegroundColor Yellow
        return $null
    }
    catch {
        Write-Host "  Warning: Failed to lookup publisher '$PublisherPrefix': $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

function Get-NextOptionValue {
    <#
    .SYNOPSIS
        Generates the next option value based on publisher prefix and sequence number.
    .DESCRIPTION
        Formula: customizationoptionvalueprefix * 10000 + sequence_number
        Example: 54031 * 10000 + 0 = 540310000
    #>
    param(
        [int]$PublisherOptionPrefix,
        [int]$SequenceNumber
    )

    return ($PublisherOptionPrefix * 10000) + $SequenceNumber
}

function Invoke-DataverseWebApi {
    <#
    .SYNOPSIS
        Invokes a Dataverse Web API request.
    .DESCRIPTION
        Thin adapter over the shared Invoke-DataverseApi (hso-shared-scripts/scripts/Dataverse-WebApi.ps1,
        dot-sourced above). Kept as a local name + signature so the ~70 call sites in this
        script are unchanged. The shared invoker now carries every behavior this wrapper
        depended on, requested explicitly here:
          -MergeLabels $IsMetadataOperation : MSCRM.MergeLabels on metadata operations
          -ExtractEntityId $true            : injects _entityId from the OData-EntityId header
          -RethrowRaw $true                 : re-throws the original error record, so the
                                              catch blocks in this script that match on
                                              $_.Exception.Message / $_.ErrorDetails keep working.
        Body is suppressed on GET (matching the original) and the debug/error console
        tracing is preserved.
    #>
    param(
        [string]$Method,
        [Alias('Url','Uri','Path')]   # ADR 0025: accept the commonly-guessed names for the relative endpoint
        [string]$Endpoint,
        [hashtable]$Body,
        [string]$SolutionName,
        [bool]$IsMetadataOperation = $true  # Set to false for non-metadata entity operations
    )

    $effectiveBody = if ($Method -eq "GET") { $null } else { $Body }

    Write-Host "  Calling: $Method $Endpoint" -ForegroundColor Gray
    if ($effectiveBody) {
        # Full request payload is detail-level output — hidden by default so the Success/created
        # lines stay readable (a 10-column batch otherwise buries them under a wall of JSON).
        # Pass -Verbose to the script to surface it when debugging a failed call.
        Write-Verbose "JSON Payload: $($effectiveBody | ConvertTo-Json -Depth 20 -Compress)"
    }

    try {
        return Invoke-DataverseApi -Method $Method -Endpoint $Endpoint -Body $effectiveBody `
            -SolutionName $SolutionName -MergeLabels $IsMetadataOperation `
            -ExtractEntityId $true -RethrowRaw $true
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        $errorMessage = $_.ErrorDetails.Message

        if ($errorMessage) {
            try {
                $errorDetails = $errorMessage | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($errorDetails.error) {
                    Write-Host "  Error ($statusCode): $($errorDetails.error.message)" -ForegroundColor Red
                    if ($errorDetails.error.innererror) {
                        Write-Host "  Details: $($errorDetails.error.innererror.message)" -ForegroundColor Yellow
                    }
                }
            }
            catch {
                Write-Host "  Error ($statusCode): $errorMessage" -ForegroundColor Red
            }
        }
        else {
            Write-Host "  Error ($statusCode): $($_.Exception.Message)" -ForegroundColor Red
        }
        throw $_
    }
}

#endregion

#region Table Operations

function New-DataverseTable {
    param(
        [string]$TableName,
        [string]$DisplayName,
        [string]$DisplayNamePlural,
        [string]$Description,
        [string]$OwnershipType,
        [string]$OrganizationOwnedApprovedBy,
        [bool]$HasActivities,
        [bool]$HasNotes,
        [switch]$IsActivity,            # Make the table a custom activity (IsActivity=true). See the activity-specific handling below.
        [switch]$IsAvailableOffline,    # Set IsAvailableOffline=true (mobile offline). Recommended for activities.
        [string]$SolutionName,
        [string]$PrimaryColumnName,
        [string]$PrimaryColumnDisplayName,
        [int]$PrimaryColumnMaxLength = 100,
        [string]$PrimaryColumnDescription,
        [string]$PrimaryColumnRequiredLevel,    # None|ApplicationRequired|Recommended for the primary column (default ApplicationRequired). Inline so no follow-up UpdateColumn is needed.
        [string]$PrimaryColumnAutoNumberFormat, # e.g. "AGR-{SEQNUM:5}" — make the primary an auto-number at create time (saves a CreateTable->UpdateColumn round-trip). The SEED still defaults to 1000; see references/autonumber-seed-web-api.md.
        [int]$PrimaryColumnAutoNumberSeed = -1  # Optional: set the runtime seed inline (e.g. 1 for AGR-00001). -1 = not specified (leave at the 1000 platform default + print the [SEED] note). Only meaningful with -PrimaryColumnAutoNumberFormat.
    )

    Write-Host "`n=== Creating Table: $TableName ===" -ForegroundColor Cyan

    # --- Custom activity guards -------------------------------------------------------------------
    # An activity table is its own special shape. The platform enforces several rules that, if
    # violated, surface as opaque CreateEntity errors ("Required field HasActivities missing",
    # "PrimaryAttribute missing", ownership errors). We normalise to the supported shape up front so
    # the caller gets a working activity instead of a 400.
    if ($IsActivity) {
        Write-Host "  Custom activity: IsActivity=true" -ForegroundColor Gray
        # An activity cannot itself host activities — HasActivities=true is rejected on an activity.
        if ($HasActivities) {
            Write-Host "  [WARN] HasActivities is invalid on an activity table (an activity cannot host activities). Forcing HasActivities=false." -ForegroundColor Yellow
            $HasActivities = $false
        }
        # Activity tables are user-owned; OrganizationOwned is rejected for activities.
        if ($OwnershipType -eq "OrganizationOwned") {
            Write-Host "  [WARN] Activity tables must be UserOwned; coercing OwnershipType from OrganizationOwned to UserOwned." -ForegroundColor Yellow
            $OwnershipType = "UserOwned"
        }
    }
    # ----------------------------------------------------------------------------------------------

    # --- HSO ownership default guard --------------------------------------------------------------
    # HSO builds EVERY table UserOwned, configuration and reference data included. OrganizationOwned
    # is not blocked -- an architect may ask for it -- but it is never a routine or agent-made choice.
    # A UserOwned table with Global depth reads identically to an org-owned one today, and a depth can
    # still be narrowed per role later. An org-owned table has no depth to narrow, so securing it later
    # means deleting and recreating the table, which is not possible in production. Teams then hide
    # data in plugin/form code instead, permanently.
    if ($OwnershipType -eq "OrganizationOwned") {
        if ($OrganizationOwnedApprovedBy) {
            Write-Host "  [HSO] OrganizationOwned requested by architect: $OrganizationOwnedApprovedBy" -ForegroundColor Cyan
            Write-Host "        Record the rationale in the data-modeling spec (Ownership Type row) before go-live." -ForegroundColor Cyan
        }
        else {
            Write-Host ""
            Write-Host "  [WARN] OrganizationOwned is NOT the HSO default -- and this is a ONE-WAY DOOR." -ForegroundColor Yellow
            Write-Host "         HSO builds every table UserOwned, configuration and reference data included." -ForegroundColor Yellow
            Write-Host "         A UserOwned table with Global depth on every role reads IDENTICALLY to" -ForegroundColor Yellow
            Write-Host "         org-owned today, but a depth can still be narrowed per role later." -ForegroundColor Yellow
            Write-Host "         OrganizationOwned has no depth to narrow: securing it later means DELETING" -ForegroundColor Yellow
            Write-Host "         AND RECREATING the table, which is not possible in production." -ForegroundColor Yellow
            Write-Host "         Proceed only if the solution architect explicitly asked for this table to be" -ForegroundColor Yellow
            Write-Host "         org-owned. Pass -OrganizationOwnedApprovedBy '<architect name>' to record it." -ForegroundColor Yellow
            Write-Host "         Rationale: agent/wiki/sop/security/security-best-practices.md (Table ownership)" -ForegroundColor Yellow
            Write-Host ""
        }
    }
    # ----------------------------------------------------------------------------------------------

    # Capture the caller's explicit -SchemaName BEFORE the local $schemaName is assigned below.
    # PowerShell variable names are CASE-INSENSITIVE, so `$schemaName = $TableName` would otherwise
    # clobber the `$SchemaName` parameter and the explicit value would be silently lost.
    $explicitSchemaName = $SchemaName

    # Build schema name with prefix. Add-PublisherPrefix only treats the leading token as a prefix
    # when it is the resolved prefix or one registered in the org, so "hsosol_project" is still not
    # double-prefixed while "service_agreement" correctly becomes "<prefix>_service_agreement".
    $schemaName = Add-PublisherPrefix -Name $TableName

    # ----------------------------------------------------------------------------------------------
    # SchemaName. This is LOCKED AT CREATION and cannot be changed afterwards — a PUT that alters it
    # returns 200 and silently ignores the change. It is also what every early-bound generator uses to
    # name the generated class, so getting it wrong permanently mis-names the class in every consuming
    # project (e.g. SchemaName "Hso_fixedpricegroup" generates class "Hso_fixedpricegroup", where the
    # convention is "hso_FixedPriceGroup").
    #
    # The intended casing cannot be derived from the logical name — "fixedpricegroup" carries no word
    # boundaries, so no amount of string manipulation yields "FixedPriceGroup". Pass -SchemaName when
    # the table name is multi-word.
    if ($explicitSchemaName) {
        # Caller supplied it explicitly — honour it verbatim, only guarding the publisher prefix.
        $pascalSchemaName = $explicitSchemaName
        if ($pascalSchemaName -notmatch '^[A-Za-z][A-Za-z0-9]*_') {
            $pascalSchemaName = "$($script:PublisherPrefix)_$pascalSchemaName"
        }
        Write-Host "  Schema name (explicit): $pascalSchemaName" -ForegroundColor Gray
    }
    else {
        # Fallback: capitalise the first character. Correct for single-word tables ("hso_Project"),
        # but for multi-word names it produces "Hso_fixedpricegroup" rather than "hso_FixedPriceGroup".
        $pascalSchemaName = $schemaName.Substring(0,1).ToUpper() + $schemaName.Substring(1)
        if ($schemaName -replace '^[a-z][a-z0-9]*_','' -match '^[a-z]{2,}$') {
            Write-Host "  [WARN] SchemaName derived as '$pascalSchemaName'. If '$TableName' is multi-word," -ForegroundColor Yellow
            Write-Host "         pass -SchemaName '$($script:PublisherPrefix)_YourPascalCaseName' instead." -ForegroundColor Yellow
            Write-Host "         SchemaName is immutable after creation and names the early-bound class." -ForegroundColor Yellow
        }
    }
    # ----------------------------------------------------------------------------------------------

    # Determine primary column schema name.
    # Normal tables default to "<prefix>_name_text"; activity tables default to "<prefix>_subject_text"
    # because an activity's primary name is conventionally the Subject (and the platform expects a
    # primary name attribute to be present — its absence is the "PrimaryAttribute missing" error).
    $primaryColSchemaName = $PrimaryColumnName
    if (-not $primaryColSchemaName) {
        $defaultPrimaryStem = if ($IsActivity) { "subject" } else { "name" }
        $primaryColSchemaName = "$($script:PublisherPrefix)_${defaultPrimaryStem}_text"
    }
    # Ensure primary column has a publisher prefix (same rule as the table schema name)
    $primaryColSchemaName = Add-PublisherPrefix -Name $primaryColSchemaName

    # Determine primary column display name (Subject for activities, Name otherwise)
    $primaryColDisplayName = $PrimaryColumnDisplayName
    if (-not $primaryColDisplayName) {
        $primaryColDisplayName = if ($IsActivity) { "Subject" } else { "Name" }
    }

    # Primary column requirement level (default ApplicationRequired, as before). Settable inline so a
    # mandatory/optional primary no longer needs a follow-up UpdateColumn.
    $primaryRequiredLevel = if ($PrimaryColumnRequiredLevel) { $PrimaryColumnRequiredLevel } else { "ApplicationRequired" }

    $primaryAttr = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
        "SchemaName" = $primaryColSchemaName
        "IsPrimaryName" = $true
        "MaxLength" = $PrimaryColumnMaxLength
        "FormatName" = @{ "Value" = "Text" }
        "DisplayName" = (New-LabelStructure -Label $primaryColDisplayName)
        "RequiredLevel" = @{ "Value" = $primaryRequiredLevel }
        "AttributeType" = "String"
        "AttributeTypeName" = @{ "Value" = "StringType" }
    }
    # Make the primary an auto-number at create time (saves the CreateTable->UpdateColumn round-trip).
    if ($PrimaryColumnAutoNumberFormat) {
        $primaryAttr["AutoNumberFormat"] = $PrimaryColumnAutoNumberFormat
    }

    $tableDefinition = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.EntityMetadata"
        "SchemaName" = $pascalSchemaName
        "DisplayName" = (New-LabelStructure -Label $DisplayName)
        "DisplayCollectionName" = (New-LabelStructure -Label $DisplayNamePlural)
        "OwnershipType" = $OwnershipType
        "IsActivity" = [bool]$IsActivity
        "HasActivities" = $HasActivities
        "HasNotes" = $HasNotes
        "Attributes" = @($primaryAttr)
    }

    # IsAvailableOffline is a plain boolean on EntityMetadata; only emit it when requested so existing
    # non-activity creates keep their previous payload byte-for-byte.
    if ($IsAvailableOffline) {
        $tableDefinition["IsAvailableOffline"] = $true
    }

    if ($Description) {
        $tableDefinition["Description"] = (New-LabelStructure -Label $Description)
    }
    Write-DescriptionWarning -ComponentKind "table" -ComponentName $schemaName -Description $Description

    # HSO standard: the PRIMARY column needs a description too (it renders as the field tooltip and
    # is a real column). It is created here at table-create time, so set + warn for it just like any
    # other column -- previously it was silently skipped, shipping a description-less primary column.
    if ($PrimaryColumnDescription) {
        $tableDefinition.Attributes[0]["Description"] = (New-LabelStructure -Label $PrimaryColumnDescription)
    }
    Write-DescriptionWarning -ComponentKind "column" -ComponentName $primaryColSchemaName -Description $PrimaryColumnDescription

    Write-Host "  Schema name: $pascalSchemaName" -ForegroundColor Gray
    Write-Host "  Primary column: $primaryColSchemaName ($primaryColDisplayName)" -ForegroundColor Gray
    Write-Host "  Primary column max length: $PrimaryColumnMaxLength" -ForegroundColor Gray
    Write-Host "  Primary column required level: $primaryRequiredLevel" -ForegroundColor Gray
    if ($PrimaryColumnAutoNumberFormat) {
        Write-Host "  Primary column auto-number: $PrimaryColumnAutoNumberFormat" -ForegroundColor Gray
    }
    Write-Host "  Ownership: $OwnershipType" -ForegroundColor Gray
    Write-Host "  Is Activity: $([bool]$IsActivity)" -ForegroundColor Gray
    Write-Host "  Has Activities: $HasActivities" -ForegroundColor Gray
    Write-Host "  Has Notes: $HasNotes" -ForegroundColor Gray
    if ($IsAvailableOffline) {
        Write-Host "  Is Available Offline: True" -ForegroundColor Gray
    }

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "EntityDefinitions" `
        -Body $tableDefinition -SolutionName $SolutionName

    Write-Host "  Table created successfully!" -ForegroundColor Green

    # If the primary was made an auto-number inline, the seed trap applies just as it does on the
    # UpdateColumn path -- the default seed is 1000, not 1.
    if ($PrimaryColumnAutoNumberFormat) {
        if ($PrimaryColumnAutoNumberSeed -ge 0) {
            # Caller asked for an explicit seed (e.g. 1) — set it now so the FIRST record honours it,
            # closing the highest-frequency manual detour in the auto-number flow.
            Set-DataverseAutoNumberSeed -EntityName $schemaName -AttributeName $primaryColSchemaName -Value $PrimaryColumnAutoNumberSeed
        } else {
            # No seed specified — leave at the 1000 default and print the ready-to-run guidance,
            # with the table/column names already substituted into the command.
            Write-AutoNumberSeedNote -AutoNumberFormat $PrimaryColumnAutoNumberFormat -EntityName $schemaName -AttributeName $primaryColSchemaName
        }
    }

    return $result
}

function Get-DataverseTable {
    param([string]$TableName)

    Write-Host "`n=== Querying Table: $TableName ===" -ForegroundColor Cyan

    $tableLower = $TableName.ToLower()
    $endpoint = "EntityDefinitions(LogicalName='$tableLower')?`$select=LogicalName,SchemaName,EntitySetName,DisplayName,OwnershipType,IsActivity,HasActivities,HasNotes"

    try {
        $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint

        Write-Host "  Table found:" -ForegroundColor Green
        Write-Host "    LogicalName: $($result.LogicalName)" -ForegroundColor White
        Write-Host "    SchemaName: $($result.SchemaName)" -ForegroundColor White
        Write-Host "    EntitySetName: $($result.EntitySetName)" -ForegroundColor White
        Write-Host "    DisplayName: $($result.DisplayName.LocalizedLabels[0].Label)" -ForegroundColor White
        Write-Host "    OwnershipType: $($result.OwnershipType)" -ForegroundColor White
        Write-Host "    IsActivity: $($result.IsActivity)" -ForegroundColor White
        Write-Host "    HasActivities: $($result.HasActivities)" -ForegroundColor White
        Write-Host "    HasNotes: $($result.HasNotes)" -ForegroundColor White

        # Query all columns on the table
        $attrEndpoint = "EntityDefinitions(LogicalName='$tableLower')/Attributes?`$select=LogicalName,SchemaName,DisplayName,AttributeType,AttributeTypeName,RequiredLevel,IsCustomAttribute"

        try {
            $attrResult = Invoke-DataverseWebApi -Method "GET" -Endpoint $attrEndpoint
            $attrs = $attrResult.value | Sort-Object LogicalName

            if ($attrs -and $attrs.Count -gt 0) {
                Write-Host ""
                Write-Host "  Columns ($($attrs.Count)):" -ForegroundColor Cyan
                Write-Host "  $('-' * 110)" -ForegroundColor Gray
                Write-Host ("  {0,-40} {1,-20} {2,-25} {3,-15}" -f "LogicalName", "Type", "DisplayName", "Required") -ForegroundColor White
                Write-Host "  $('-' * 110)" -ForegroundColor Gray

                foreach ($attr in $attrs) {
                    $attrDisplayName = ""
                    if ($attr.DisplayName -and $attr.DisplayName.LocalizedLabels -and $attr.DisplayName.LocalizedLabels.Count -gt 0) {
                        $attrDisplayName = $attr.DisplayName.LocalizedLabels[0].Label
                    }
                    $reqLevel = if ($attr.RequiredLevel -and $attr.RequiredLevel.Value) { $attr.RequiredLevel.Value } else { "None" }
                    $attrTypeName = if ($attr.AttributeTypeName -and $attr.AttributeTypeName.Value) { $attr.AttributeTypeName.Value } else { $attr.AttributeType }

                    Write-Host ("  {0,-40} {1,-20} {2,-25} {3,-15}" -f $attr.LogicalName, $attrTypeName, $attrDisplayName, $reqLevel) -ForegroundColor White
                }

                # Resolve lookup targets
                $lookupAttrs = $attrs | Where-Object { $_.AttributeType -eq "Lookup" }
                if ($lookupAttrs -and $lookupAttrs.Count -gt 0) {
                    Write-Host ""
                    Write-Host "  Lookup Targets:" -ForegroundColor Cyan
                    foreach ($lookupAttr in $lookupAttrs) {
                        $lookupName = $lookupAttr.LogicalName
                        try {
                            $lookupEndpoint = "EntityDefinitions(LogicalName='$tableLower')/Attributes(LogicalName='$lookupName')/Microsoft.Dynamics.CRM.LookupAttributeMetadata?`$select=LogicalName,Targets"
                            $lookupMeta = Invoke-DataverseWebApi -Method "GET" -Endpoint $lookupEndpoint
                            $targets = $lookupMeta.Targets -join ", "
                            Write-Host "    $lookupName -> $targets" -ForegroundColor White
                        }
                        catch {
                            Write-Host "    $lookupName -> (unable to resolve target)" -ForegroundColor Yellow
                        }
                    }
                }
            }
        }
        catch {
            Write-Host "  [WARNING] Could not query columns: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        return $result
    }
    catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            Write-Host "  Table not found: $TableName" -ForegroundColor Yellow
            return $null
        }
        throw $_
    }
}

function Update-DataverseTable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        [Parameter(Mandatory = $false)]
        [bool]$HasActivities,
        [Parameter(Mandatory = $false)]
        [bool]$HasNotes,
        [Parameter(Mandatory = $false)]
        [string]$DisplayName,
        [Parameter(Mandatory = $false)]
        [string]$DisplayNamePlural,
        [Parameter(Mandatory = $false)]
        [string]$Description,
        [Parameter(Mandatory = $false)]
        [string]$SolutionName,
        # IsQuickCreateEnabled: untyped so the -File string-passing path does not hard-fail [bool] binding.
        # Coerced via ConvertTo-SolutionMembershipBool with $null default (= omitted = keep current value).
        $IsQuickCreateEnabled = $null
    )

    Write-Host "`n=== Updating Table: $TableName ===" -ForegroundColor Cyan

    $tableLower = $TableName.ToLower()

    # Fetch current state — include IsQuickCreateEnabled so we can diff it
    $endpoint = "EntityDefinitions(LogicalName='$tableLower')?`$select=MetadataId,LogicalName,SchemaName,DisplayName,DisplayCollectionName,OwnershipType,HasActivities,HasNotes,IsQuickCreateEnabled"
    $current = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint

    Write-Host "  Current state:" -ForegroundColor Gray
    Write-Host "    HasActivities:        $($current.HasActivities)" -ForegroundColor White
    Write-Host "    HasNotes:             $($current.HasNotes)" -ForegroundColor White
    Write-Host "    IsQuickCreateEnabled: $($current.IsQuickCreateEnabled)" -ForegroundColor White

    # Build update body with only changed properties
    $updateBody = @{}
    $changes = @()

    if ($PSBoundParameters.ContainsKey('HasActivities') -and $HasActivities -ne $current.HasActivities) {
        if ($current.HasActivities -eq $true -and $HasActivities -eq $false) {
            Write-Host "  [WARNING] HasActivities cannot be disabled once enabled. Skipping." -ForegroundColor Yellow
        } else {
            $updateBody["HasActivities"] = $HasActivities
            $changes += "HasActivities: $($current.HasActivities) -> $HasActivities"
        }
    }

    if ($PSBoundParameters.ContainsKey('HasNotes') -and $HasNotes -ne $current.HasNotes) {
        if ($current.HasNotes -eq $true -and $HasNotes -eq $false) {
            Write-Host "  [WARNING] HasNotes cannot be disabled once enabled. Skipping." -ForegroundColor Yellow
        } else {
            $updateBody["HasNotes"] = $HasNotes
            $changes += "HasNotes: $($current.HasNotes) -> $HasNotes"
        }
    }

    # IsQuickCreateEnabled — coerce and diff (null = not provided = skip)
    if ($null -ne $IsQuickCreateEnabled) {
        $qcEnabled = ConvertTo-SolutionMembershipBool -Value $IsQuickCreateEnabled -ParamName "IsQuickCreateEnabled" -Default $current.IsQuickCreateEnabled
        if ($qcEnabled -ne $current.IsQuickCreateEnabled) {
            $updateBody["IsQuickCreateEnabled"] = $qcEnabled
            $changes += "IsQuickCreateEnabled: $($current.IsQuickCreateEnabled) -> $qcEnabled"
        } else {
            Write-Host "  IsQuickCreateEnabled already $($current.IsQuickCreateEnabled) - no change needed." -ForegroundColor Gray
        }
    }

    if ($DisplayName) {
        $updateBody["DisplayName"] = (New-LabelStructure -Label $DisplayName)
        $changes += "DisplayName -> $DisplayName"
    }

    if ($DisplayNamePlural) {
        $updateBody["DisplayCollectionName"] = (New-LabelStructure -Label $DisplayNamePlural)
        $changes += "DisplayCollectionName -> $DisplayNamePlural"
    }

    if ($Description) {
        $updateBody["Description"] = (New-LabelStructure -Label $Description)
        $changes += "Description -> $Description"
    }

    if ($updateBody.Count -eq 0) {
        Write-Host "  No changes to apply." -ForegroundColor Yellow
        return
    }

    Write-Host "  Changes to apply:" -ForegroundColor Cyan
    foreach ($change in $changes) {
        Write-Host "    $change" -ForegroundColor White
    }

    # Entity metadata updates require PUT with @odata.type
    $updateBody["@odata.type"] = "Microsoft.Dynamics.CRM.EntityMetadata"
    $updateBody["MetadataId"] = $current.MetadataId
    $putEndpoint = "EntityDefinitions(LogicalName='$tableLower')"
    Invoke-DataverseWebApi -Method "PUT" -Endpoint $putEndpoint -Body $updateBody -SolutionName $SolutionName

    Write-Host "  [OK] Table updated successfully" -ForegroundColor Green

    # Publish
    Write-Host "  Publishing $tableLower..." -ForegroundColor Gray
    $publishBody = @{
        ParameterXml = "<importexportxml><entities><entity>$tableLower</entity></entities></importexportxml>"
    }
    Invoke-DataverseWebApi -Method "POST" -Endpoint "PublishXml" -Body $publishBody -IsMetadataOperation $false
    Write-Host "  [OK] Published successfully" -ForegroundColor Green
}

function Get-DataverseColumn {
    <#
    .SYNOPSIS
        Queries detailed metadata for a specific column on a table.
    .DESCRIPTION
        Returns the full attribute metadata including type-specific properties like
        MinValue, MaxValue, Precision, DefaultValue, DefaultFormValue, MaxLength, etc.
        Uses the type-cast endpoint to get all type-specific properties.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        [Parameter(Mandatory = $true)]
        [string]$ColumnName
    )

    Write-Host "`n=== Querying Column: $ColumnName on $TableName ===" -ForegroundColor Cyan

    $tableLower = $TableName.ToLower()
    $columnLower = $ColumnName.ToLower()

    # First get the base attribute to determine its type
    $baseEndpoint = "EntityDefinitions(LogicalName='$tableLower')/Attributes(LogicalName='$columnLower')?`$select=LogicalName,SchemaName,DisplayName,Description,AttributeType,AttributeTypeName,RequiredLevel,IsAuditEnabled,IsValidForAdvancedFind"

    try {
        $baseResult = Invoke-DataverseWebApi -Method "GET" -Endpoint $baseEndpoint
    }
    catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            Write-Host "  Column not found: $ColumnName on table $TableName" -ForegroundColor Yellow
            return $null
        }
        throw $_
    }

    $attrType = $baseResult.AttributeType
    $displayName = if ($baseResult.DisplayName -and $baseResult.DisplayName.LocalizedLabels -and $baseResult.DisplayName.LocalizedLabels.Count -gt 0) {
        $baseResult.DisplayName.LocalizedLabels[0].Label
    } else { $ColumnName }

    $description = if ($baseResult.Description -and $baseResult.Description.LocalizedLabels -and $baseResult.Description.LocalizedLabels.Count -gt 0) {
        $baseResult.Description.LocalizedLabels[0].Label
    } else { "" }

    Write-Host "  Column found:" -ForegroundColor Green
    Write-Host "    LogicalName:   $($baseResult.LogicalName)" -ForegroundColor White
    Write-Host "    SchemaName:    $($baseResult.SchemaName)" -ForegroundColor White
    Write-Host "    DisplayName:   $displayName" -ForegroundColor White
    Write-Host "    Description:   $description" -ForegroundColor White
    Write-Host "    AttributeType: $attrType" -ForegroundColor White

    # Map to type-cast endpoint for type-specific properties
    $typeCastMap = @{
        "String"    = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
        "Memo"      = "Microsoft.Dynamics.CRM.MemoAttributeMetadata"
        "Integer"   = "Microsoft.Dynamics.CRM.IntegerAttributeMetadata"
        "Decimal"   = "Microsoft.Dynamics.CRM.DecimalAttributeMetadata"
        "Money"     = "Microsoft.Dynamics.CRM.MoneyAttributeMetadata"
        "Double"    = "Microsoft.Dynamics.CRM.DoubleAttributeMetadata"
        "DateTime"  = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"
        "Boolean"   = "Microsoft.Dynamics.CRM.BooleanAttributeMetadata"
        "Picklist"  = "Microsoft.Dynamics.CRM.PicklistAttributeMetadata"
        "State"     = "Microsoft.Dynamics.CRM.StateAttributeMetadata"
        "Status"    = "Microsoft.Dynamics.CRM.StatusAttributeMetadata"
        "Lookup"    = "Microsoft.Dynamics.CRM.LookupAttributeMetadata"
        "BigInt"    = "Microsoft.Dynamics.CRM.BigIntAttributeMetadata"
    }
    # MultiSelectPicklist has AttributeType=Virtual, check AttributeTypeName
    $attrTypeName = $baseResult.AttributeTypeName.Value
    if ($attrTypeName -eq "MultiSelectPicklistType") {
        $typeCastMap["Virtual"] = "Microsoft.Dynamics.CRM.MultiSelectPicklistAttributeMetadata"
    }

    # Picklist/State/Status/MultiSelectPicklist columns own an OptionSet — expand it
    # so callers can see the actual option values + labels (otherwise QueryColumn returns
    # only the column shape, not its choices). Local OptionSets live inline; global
    # choices are exposed via the GlobalOptionSet navigation property (Picklist/MultiSelect).
    $optionSetExpand = ""
    if ($attrType -in @("Picklist", "State", "Status") -or $attrTypeName -eq "MultiSelectPicklistType") {
        $optionSetExpand = "?`$expand=OptionSet(`$select=Options),GlobalOptionSet(`$select=Name,Options)"
    }

    if ($typeCastMap.ContainsKey($attrType)) {
        $typeCast = $typeCastMap[$attrType]
        $typedEndpoint = "EntityDefinitions(LogicalName='$tableLower')/Attributes(LogicalName='$columnLower')/$typeCast$optionSetExpand"

        try {
            $typedResult = Invoke-DataverseWebApi -Method "GET" -Endpoint $typedEndpoint
        }
        catch {
            Write-Host "  WARNING: Could not retrieve typed metadata. Showing base properties only." -ForegroundColor Yellow
            $typedResult = $null
        }

        if ($typedResult) {
            # Display type-specific properties
            $requiredLevel = if ($typedResult.RequiredLevel) { $typedResult.RequiredLevel.Value } else { "Unknown" }
            $isAudit = if ($typedResult.IsAuditEnabled) { $typedResult.IsAuditEnabled.Value } else { "Unknown" }
            $isAdvFind = if ($typedResult.IsValidForAdvancedFind) { $typedResult.IsValidForAdvancedFind.Value } else { "Unknown" }

            Write-Host "    RequiredLevel: $requiredLevel" -ForegroundColor White
            Write-Host "    IsAuditEnabled: $isAudit" -ForegroundColor White
            Write-Host "    IsValidForAdvancedFind: $isAdvFind" -ForegroundColor White

            switch ($attrType) {
                "String" {
                    Write-Host "    MaxLength:     $($typedResult.MaxLength)" -ForegroundColor White
                    Write-Host "    FormatName:    $($typedResult.FormatName.Value)" -ForegroundColor White
                    if ($typedResult.AutoNumberFormat) {
                        Write-Host "    AutoNumberFormat: $($typedResult.AutoNumberFormat)" -ForegroundColor White
                    }
                }
                "Memo" {
                    Write-Host "    MaxLength:     $($typedResult.MaxLength)" -ForegroundColor White
                    Write-Host "    Format:        $($typedResult.Format)" -ForegroundColor White
                }
                "Integer" {
                    Write-Host "    MinValue:      $($typedResult.MinValue)" -ForegroundColor White
                    Write-Host "    MaxValue:      $($typedResult.MaxValue)" -ForegroundColor White
                    Write-Host "    DefaultValue:  $($typedResult.DefaultValue)" -ForegroundColor White
                    Write-Host "    Format:        $($typedResult.Format)" -ForegroundColor White
                }
                { $_ -in @("Decimal", "Double") } {
                    Write-Host "    MinValue:      $($typedResult.MinValue)" -ForegroundColor White
                    Write-Host "    MaxValue:      $($typedResult.MaxValue)" -ForegroundColor White
                    Write-Host "    Precision:     $($typedResult.Precision)" -ForegroundColor White
                    Write-Host "    DefaultValue:  $($typedResult.DefaultValue)" -ForegroundColor White
                }
                "Money" {
                    Write-Host "    Precision:     $($typedResult.Precision)" -ForegroundColor White
                    Write-Host "    PrecisionSource: $($typedResult.PrecisionSource)" -ForegroundColor White
                    Write-Host "    MinValue:      $($typedResult.MinValue)" -ForegroundColor White
                    Write-Host "    MaxValue:      $($typedResult.MaxValue)" -ForegroundColor White
                }
                "DateTime" {
                    Write-Host "    Format:        $($typedResult.Format)" -ForegroundColor White
                    Write-Host "    DateTimeBehavior: $($typedResult.DateTimeBehavior.Value)" -ForegroundColor White
                }
                "Boolean" {
                    Write-Host "    DefaultValue:  $($typedResult.DefaultValue)" -ForegroundColor White
                }
                "Picklist" {
                    Write-Host "    DefaultFormValue: $($typedResult.DefaultFormValue)" -ForegroundColor White
                    if ($typedResult.GlobalOptionSet) {
                        Write-Host "    GlobalOptionSet:  $($typedResult.GlobalOptionSet.Name)" -ForegroundColor White
                    }
                    Write-OptionSetOptions -TypedResult $typedResult
                }
                "State" {
                    Write-Host "    DefaultFormValue: $($typedResult.DefaultFormValue)" -ForegroundColor White
                    Write-OptionSetOptions -TypedResult $typedResult
                }
                "Status" {
                    Write-Host "    DefaultFormValue: $($typedResult.DefaultFormValue)" -ForegroundColor White
                    Write-OptionSetOptions -TypedResult $typedResult
                }
            }

            # MultiSelectPicklist uses AttributeType=Virtual and falls outside the switch above
            if ($attrTypeName -eq "MultiSelectPicklistType") {
                if ($typedResult.GlobalOptionSet) {
                    Write-Host "    GlobalOptionSet:  $($typedResult.GlobalOptionSet.Name)" -ForegroundColor White
                }
                Write-OptionSetOptions -TypedResult $typedResult
            }

            return $typedResult
        }
    }

    return $baseResult
}

function Write-OptionSetOptions {
    <#
    .SYNOPSIS
        Pretty-prints the options on a Picklist / Status / State / MultiSelectPicklist column.
    .DESCRIPTION
        Local option sets live on $TypedResult.OptionSet; global choices live on
        $TypedResult.GlobalOptionSet. For statecode-linked statuses, each option also has
        a State property indicating which statecode value it links to.
    #>
    param([Parameter(Mandatory = $true)]$TypedResult)

    $opts = $null
    $source = ""
    if ($TypedResult.OptionSet -and $TypedResult.OptionSet.Options -and $TypedResult.OptionSet.Options.Count -gt 0) {
        $opts = $TypedResult.OptionSet.Options
        $source = "local"
    }
    elseif ($TypedResult.GlobalOptionSet -and $TypedResult.GlobalOptionSet.Options -and $TypedResult.GlobalOptionSet.Options.Count -gt 0) {
        $opts = $TypedResult.GlobalOptionSet.Options
        $source = "global"
    }

    if (-not $opts) { return }

    Write-Host "    Options ($($opts.Count), $source):" -ForegroundColor White
    foreach ($opt in $opts) {
        $optLabel = if ($opt.Label -and $opt.Label.UserLocalizedLabel) { $opt.Label.UserLocalizedLabel.Label }
                    elseif ($opt.Label -and $opt.Label.LocalizedLabels -and $opt.Label.LocalizedLabels.Count -gt 0) { $opt.Label.LocalizedLabels[0].Label }
                    else { "" }
        # Statuscode options carry State (the linked statecode value); include when present
        if ($null -ne $opt.State) {
            $stateName = if ($opt.State -eq 0) { "Active" } else { "Inactive" }
            Write-Host ("      {0,12}  {1,-30}  -> State {2} ({3})" -f $opt.Value, $optLabel, $opt.State, $stateName) -ForegroundColor Gray
        }
        else {
            Write-Host ("      {0,12}  {1}" -f $opt.Value, $optLabel) -ForegroundColor Gray
        }
    }
}

function Remove-DataverseTable {
    param([string]$TableName)

    Write-Host "`n=== Deleting Table: $TableName ===" -ForegroundColor Cyan
    Write-Host "  WARNING: This will permanently delete the table and all its data!" -ForegroundColor Yellow

    # First verify the table exists
    $endpoint = "EntityDefinitions(LogicalName='$($TableName.ToLower())')?`$select=LogicalName,DisplayName"

    try {
        $table = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint
        Write-Host "  Found table: $($table.DisplayName.LocalizedLabels[0].Label)" -ForegroundColor White
    }
    catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            Write-Host "  Table not found: $TableName - nothing to delete" -ForegroundColor Yellow
            return $true
        }
        throw $_
    }

    # Delete the table
    $deleteEndpoint = "EntityDefinitions(LogicalName='$($TableName.ToLower())')"

    try {
        Invoke-DataverseWebApi -Method "DELETE" -Endpoint $deleteEndpoint | Out-Null
        Write-Host "  Table deleted successfully: $TableName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  Failed to delete table: $($_.Exception.Message)" -ForegroundColor Red
        throw $_
    }
}

function Resolve-DependencyName {
    # Best-effort friendly name for a RetrieveDependenciesForDelete entry (form/view/chart/key) so the
    # output lists what to fix rather than raw GUIDs. Component codes per
    # references/column-dependencies-web-api.md. Falls back to type/id if the lookup fails.
    # -TableName is needed to resolve an EntityKey (type 14), whose name lives under the table's /Keys.
    param([int]$ComponentType, [string]$ObjectId, [string]$TableName)
    try {
        switch ($ComponentType) {
            26 { $r = Invoke-DataverseWebApi -Method "GET" -Endpoint "savedqueries($ObjectId)?`$select=name,returnedtypecode"; return "View '$($r.name)' [$($r.returnedtypecode)] (savedquery $ObjectId)" }
            60 { $r = Invoke-DataverseWebApi -Method "GET" -Endpoint "systemforms($ObjectId)?`$select=name,objecttypecode"; return "Form '$($r.name)' [$($r.objecttypecode)] (systemform $ObjectId)" }
            59 { $r = Invoke-DataverseWebApi -Method "GET" -Endpoint "savedqueryvisualizations($ObjectId)?`$select=name"; return "Chart '$($r.name)' (savedqueryvisualization $ObjectId)" }
            14 {
                # EntityKey (alternate key). No global entityset; resolve via the table's /Keys by MetadataId.
                if ($TableName) {
                    $keys = Invoke-DataverseWebApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$($TableName.ToLower())')/Keys?`$select=SchemaName,MetadataId,EntityKeyIndexStatus,KeyAttributes"
                    $k = @($keys.value | Where-Object { $_.MetadataId -eq $ObjectId }) | Select-Object -First 1
                    if ($k) { return "Alternate Key '$($k.SchemaName)' over [$($k.KeyAttributes -join ', ')] (status $($k.EntityKeyIndexStatus); entitykey $ObjectId)" }
                }
                return "Alternate Key (EntityKey $ObjectId)"
            }
            default { return "componenttype $ComponentType / $ObjectId" }
        }
    }
    catch { return "componenttype $ComponentType / $ObjectId (name lookup failed)" }
}

function Remove-DataverseColumn {
    <#
    .SYNOPSIS
        Deletes a column from a Dataverse table -- guarded.
    .DESCRIPTION
        Before deleting, runs the RetrieveDependenciesForDelete preflight (the check documented in
        references/column-dependencies-web-api.md) and REFUSES -- listing the blocking forms/views by
        friendly name -- rather than firing a DELETE that fails opaquely. Also refuses to delete the
        table's primary name column (the platform never allows it, regardless of dependencies).
        -Force bypasses the dependency refusal; the primary-column guard is absolute.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        [Parameter(Mandatory = $true)]
        [string]$ColumnName,
        [switch]$Force
    )

    $tableLower = $TableName.ToLower()
    $columnLower = $ColumnName.ToLower()
    Write-Host "`n=== Deleting Column: $ColumnName from $TableName ===" -ForegroundColor Cyan

    # Verify the column exists (and capture MetadataId for the dependency preflight)
    $endpoint = "EntityDefinitions(LogicalName='$tableLower')/Attributes(LogicalName='$columnLower')?`$select=LogicalName,DisplayName,AttributeType,MetadataId"
    try {
        $column = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint
        $displayName = if ($column.DisplayName -and $column.DisplayName.LocalizedLabels -and $column.DisplayName.LocalizedLabels.Count -gt 0) {
            $column.DisplayName.LocalizedLabels[0].Label
        } else {
            $ColumnName
        }
        Write-Host "  Found column: $displayName (Type: $($column.AttributeType))" -ForegroundColor White
    }
    catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            Write-Host "  Column not found: $ColumnName on table $TableName - nothing to delete" -ForegroundColor Yellow
            return $true
        }
        throw $_
    }

    # Guard 1 (absolute): the primary name column can never be deleted, dependencies or not.
    $primaryName = $null
    try { $primaryName = (Invoke-DataverseWebApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$tableLower')?`$select=PrimaryNameAttribute").PrimaryNameAttribute } catch { }
    if ($primaryName -and $primaryName.ToLower() -eq $columnLower) {
        Write-Host "  [REFUSED] '$columnLower' is the primary name column of '$tableLower' -- the platform never allows deleting it (the dependency check does not apply to it)." -ForegroundColor Red
        throw "DeleteColumn refused: '$columnLower' is the primary name column and cannot be deleted."
    }

    # Guard 2: dependency preflight (ComponentType 2 = Attribute). List blockers and refuse unless -Force.
    if (-not $Force) {
        $blockers = @(); $depChecked = $true
        try {
            $dep = Invoke-DataverseWebApi -Method "GET" -Endpoint "RetrieveDependenciesForDelete(ObjectId=$($column.MetadataId),ComponentType=2)"
            $blockers = @($dep.value)
        }
        catch {
            $depChecked = $false
            Write-Host "  [WARN] Dependency preflight could not be completed ($($_.Exception.Message)); proceeding -- the platform will still block the DELETE if dependencies exist." -ForegroundColor Yellow
        }
        if ($depChecked -and $blockers.Count -gt 0) {
            Write-Host "  [REFUSED] '$columnLower' has $($blockers.Count) dependency(ies). Remove it from these first (e.g. via hso-dataverse-ui-config form/view edits), or re-run with -Force:" -ForegroundColor Red
            foreach ($b in $blockers) {
                Write-Host "    - $(Resolve-DependencyName -ComponentType ([int]$b.dependentcomponenttype) -ObjectId $b.dependentcomponentobjectid -TableName $tableLower)" -ForegroundColor Yellow
            }
            throw "DeleteColumn refused: '$columnLower' still has $($blockers.Count) dependency(ies). Remove them or re-run with -Force."
        }
    }

    # Delete the column
    $deleteEndpoint = "EntityDefinitions(LogicalName='$tableLower')/Attributes(LogicalName='$columnLower')"
    try {
        Invoke-DataverseWebApi -Method "DELETE" -Endpoint $deleteEndpoint | Out-Null
        Write-Host "  Column deleted successfully: $ColumnName from $TableName" -ForegroundColor Green
        return $true
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "dependency|dependencies") {
            Write-Host "  Failed to delete column: Column has dependencies (views, forms, etc.)" -ForegroundColor Red
            Write-Host "  Remove the column from all views and forms first, then try again." -ForegroundColor Yellow
        }
        else {
            Write-Host "  Failed to delete column: $errorMessage" -ForegroundColor Red
        }
        throw $_
    }
}

function Get-ColumnDependencies {
    <#
    .SYNOPSIS
        READ-ONLY: lists the components that would block deleting a column -- without deleting anything.
    .DESCRIPTION
        The non-destructive entry point to the same RetrieveDependenciesForDelete preflight that guarded
        DeleteColumn runs internally. Answers "what references this column / what would block its delete?"
        for a purely informational question, so the caller doesn't have to hand-roll the Web API call or
        invoke the destructive DeleteColumn just to inspect. Resolves dependents to friendly names
        (forms, views, charts, alternate keys). ComponentType 2 = Attribute.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        [Parameter(Mandatory = $true)]
        [string]$ColumnName
    )

    $tableLower = $TableName.ToLower()
    $columnLower = $ColumnName.ToLower()
    Write-Host "`n=== Column Dependencies (read-only): $ColumnName on $TableName ===" -ForegroundColor Cyan

    # Resolve the column's MetadataId (and flag the primary name column, which can never be deleted).
    $endpoint = "EntityDefinitions(LogicalName='$tableLower')/Attributes(LogicalName='$columnLower')?`$select=LogicalName,AttributeType,MetadataId"
    try {
        $column = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint
    }
    catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            Write-Host "  Column not found: $ColumnName on table $TableName" -ForegroundColor Yellow
            return $null
        }
        throw $_
    }

    $primaryName = $null
    try { $primaryName = (Invoke-DataverseWebApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$tableLower')?`$select=PrimaryNameAttribute").PrimaryNameAttribute } catch { }
    if ($primaryName -and $primaryName.ToLower() -eq $columnLower) {
        Write-Host "  NOTE: '$columnLower' is the PRIMARY NAME column -- the platform never allows deleting it, regardless of dependencies." -ForegroundColor Yellow
    }

    $dep = Invoke-DataverseWebApi -Method "GET" -Endpoint "RetrieveDependenciesForDelete(ObjectId=$($column.MetadataId),ComponentType=2)"
    $blockers = @($dep.value)
    if ($blockers.Count -eq 0) {
        Write-Host "  No dependencies -- this column is safe to delete$(if ($primaryName -and $primaryName.ToLower() -eq $columnLower) { ' EXCEPT it is the primary name column (see note above)' } else { '' })." -ForegroundColor Green
        return @()
    }

    Write-Host "  $($blockers.Count) dependency(ies) would block deletion:" -ForegroundColor Yellow
    $resolved = @()
    foreach ($b in $blockers) {
        $name = Resolve-DependencyName -ComponentType ([int]$b.dependentcomponenttype) -ObjectId $b.dependentcomponentobjectid -TableName $tableLower
        Write-Host "    - $name" -ForegroundColor White
        $resolved += [pscustomobject]@{ ComponentType = [int]$b.dependentcomponenttype; ObjectId = $b.dependentcomponentobjectid; Name = $name }
    }
    Write-Host "  Remove the column from these first (e.g. via hso-dataverse-ui-config form/view edits), then DeleteColumn (or DeleteColumn -Force to bypass the dependency refusal)." -ForegroundColor Gray
    return $resolved
}

#endregion

#region Column Operations

function Get-RollupFormulaXaml {
    <#
    .SYNOPSIS
        Compiles a rollup column's FormulaDefinition (Workflow XAML) from a declarative shape.
    .DESCRIPTION
        ADR 0057: executors never author XAML. This template was captured verbatim from a
        designer-authored rollup read-back (a Dev test org, 2026-08-06) and parameterized on
        exactly the parts that vary: child table, relationship schema name, lookup column,
        optional single Equal filter on a state/status/choice column, and the aggregate step.
        See references/rollup-formula-columns-web-api.md for the capture provenance.
    #>
    param(
        [Parameter(Mandatory)][string]$ChildTable,
        [Parameter(Mandatory)][string]$RelationshipSchemaName,
        [Parameter(Mandatory)][string]$LookupColumn,
        [Parameter(Mandatory)][string]$AggregateOperator,   # EvaluateExpression operator string (Count/Sum/...)
        [Parameter(Mandatory)][string]$AggregateAttribute,  # child PK for Count, the aggregated column otherwise
        [string]$FilterAttribute,
        $FilterValue,
        [string]$FilterCrmTypeName                          # State | Status | Picklist (third CreateCrmType parameter)
    )

    $header = '<?xml version="1.0" encoding="utf-16"?><Activity x:Class="XrmWorkflow00000000000000000000000000000000" xmlns="http://schemas.microsoft.com/netfx/2009/xaml/activities" xmlns:mcwc="clr-namespace:Microsoft.Crm.Workflow.ClientActivities;assembly=Microsoft.Crm.Workflow, Version=9.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" xmlns:mva="clr-namespace:Microsoft.VisualBasic.Activities;assembly=System.Activities, Version=4.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" xmlns:mxs="clr-namespace:Microsoft.Xrm.Sdk;assembly=Microsoft.Xrm.Sdk, Version=9.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" xmlns:mxsq="clr-namespace:Microsoft.Xrm.Sdk.Query;assembly=Microsoft.Xrm.Sdk, Version=9.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" xmlns:mxswa="clr-namespace:Microsoft.Xrm.Sdk.Workflow.Activities;assembly=Microsoft.Xrm.Sdk.Workflow, Version=9.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" xmlns:s="clr-namespace:System;assembly=mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" xmlns:scg="clr-namespace:System.Collections.Generic;assembly=mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" xmlns:srs="clr-namespace:System.Runtime.Serialization;assembly=System.Runtime.Serialization, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" xmlns:this="clr-namespace:" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"><x:Members><x:Property Name="InputEntities" Type="InArgument(scg:IDictionary(x:String, mxs:Entity))" /><x:Property Name="CreatedEntities" Type="InArgument(scg:IDictionary(x:String, mxs:Entity))" /></x:Members><this:XrmWorkflow00000000000000000000000000000000.InputEntities><InArgument x:TypeArguments="scg:IDictionary(x:String, mxs:Entity)" /></this:XrmWorkflow00000000000000000000000000000000.InputEntities><this:XrmWorkflow00000000000000000000000000000000.CreatedEntities><InArgument x:TypeArguments="scg:IDictionary(x:String, mxs:Entity)" /></this:XrmWorkflow00000000000000000000000000000000.CreatedEntities><mva:VisualBasic.Settings>Assembly references and imported namespaces for internal implementation</mva:VisualBasic.Settings><mxswa:Workflow><Sequence DisplayName="RollupRuleStep1">'

    $source = '<Sequence DisplayName="Source"><Sequence.Variables><Variable x:TypeArguments="x:String" Default="[Nothing]" Name="HierarchicalRelationshipName" /></Sequence.Variables></Sequence>'

    $setAttribute = '<mcwc:SetAttributeValue DisplayName="__CHILD__.__LOOKUP__.__REL__" Entity="[CreatedEntities(&quot;relatedlinked___REL__#__LOOKUP__#__CHILD__#Temp&quot;)]" EntityName="__CHILD__" />'

    if ($FilterAttribute) {
        $filterVars = '<Sequence.Variables><Variable x:TypeArguments="x:Boolean" Default="False" Name="RollupRuleStep1_1" /><Variable x:TypeArguments="x:Object" Name="RollupRuleStep1_2" /><Variable x:TypeArguments="x:Object" Name="RollupRuleStep1_3" /></Sequence.Variables>'
        $filterSteps = '<mxswa:GetEntityProperty Attribute="__FILTERATTR__" Entity="[InputEntities(&quot;primaryEntity&quot;)]" EntityName="__CHILD__" Value="[RollupRuleStep1_2]"><mxswa:GetEntityProperty.TargetType><InArgument x:TypeArguments="s:Type"><mxswa:ReferenceLiteral x:TypeArguments="s:Type"><x:Null /></mxswa:ReferenceLiteral></InArgument></mxswa:GetEntityProperty.TargetType></mxswa:GetEntityProperty><mxswa:ActivityReference AssemblyQualifiedName="Microsoft.Crm.Workflow.Activities.EvaluateExpression, Microsoft.Crm.Workflow, Version=9.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" DisplayName="EvaluateExpression"><mxswa:ActivityReference.Arguments><InArgument x:TypeArguments="x:String" x:Key="ExpressionOperator">CreateCrmType</InArgument><InArgument x:TypeArguments="s:Object[]" x:Key="Parameters">[New Object() { Microsoft.Xrm.Sdk.Workflow.WorkflowPropertyType.OptionSetValue, "__FILTERVALUE__", "__FILTERCRMTYPE__" }]</InArgument><InArgument x:TypeArguments="s:Type" x:Key="TargetType"><mxswa:ReferenceLiteral x:TypeArguments="s:Type" Value="mxs:OptionSetValue" /></InArgument><OutArgument x:TypeArguments="x:Object" x:Key="Result">[RollupRuleStep1_3]</OutArgument></mxswa:ActivityReference.Arguments></mxswa:ActivityReference><mxswa:ActivityReference AssemblyQualifiedName="Microsoft.Crm.Workflow.Activities.EvaluateCondition, Microsoft.Crm.Workflow, Version=9.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" DisplayName="EvaluateCondition"><mxswa:ActivityReference.Arguments><InArgument x:TypeArguments="mxsq:ConditionOperator" x:Key="ConditionOperator">Equal</InArgument><InArgument x:TypeArguments="s:Object[]" x:Key="Parameters">[New Object() { RollupRuleStep1_3 }]</InArgument><InArgument x:TypeArguments="x:Object" x:Key="Operand">[RollupRuleStep1_2]</InArgument><OutArgument x:TypeArguments="x:Boolean" x:Key="Result">[RollupRuleStep1_1]</OutArgument></mxswa:ActivityReference.Arguments></mxswa:ActivityReference>'
        $target = '<Sequence DisplayName="Target">' + $filterVars + $setAttribute + $filterSteps + '</Sequence>'
    } else {
        $target = '<Sequence DisplayName="Target">' + $setAttribute + '</Sequence>'
    }

    $aggregate = '<Sequence DisplayName="Aggregate"><Sequence.Variables><Variable x:TypeArguments="x:Object" Name="RollupRuleStep1_4" /><Variable x:TypeArguments="x:Object" Name="RollupRuleStep1_5" /></Sequence.Variables><mxswa:GetEntityProperty Attribute="__AGGATTR__" Entity="[InputEntities(&quot;primaryEntity&quot;)]" EntityName="__CHILD__" Value="[RollupRuleStep1_5]"><mxswa:GetEntityProperty.TargetType><InArgument x:TypeArguments="s:Type"><mxswa:ReferenceLiteral x:TypeArguments="s:Type"><x:Null /></mxswa:ReferenceLiteral></InArgument></mxswa:GetEntityProperty.TargetType></mxswa:GetEntityProperty><mxswa:ActivityReference AssemblyQualifiedName="Microsoft.Crm.Workflow.Activities.EvaluateExpression, Microsoft.Crm.Workflow, Version=9.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" DisplayName="EvaluateExpression"><mxswa:ActivityReference.Arguments><InArgument x:TypeArguments="x:String" x:Key="ExpressionOperator">__AGGOP__</InArgument><InArgument x:TypeArguments="s:Object[]" x:Key="Parameters">[New Object() { RollupRuleStep1_5 }]</InArgument><InArgument x:TypeArguments="s:Type" x:Key="TargetType"><mxswa:ReferenceLiteral x:TypeArguments="s:Type"><x:Null /></mxswa:ReferenceLiteral></InArgument><OutArgument x:TypeArguments="x:Object" x:Key="Result">[RollupRuleStep1_4]</OutArgument></mxswa:ActivityReference.Arguments></mxswa:ActivityReference></Sequence>'

    $xaml = $header + $source + $target + $aggregate + '</Sequence></mxswa:Workflow></Activity>'
    $xaml = $xaml.Replace('__CHILD__', $ChildTable).Replace('__REL__', $RelationshipSchemaName).Replace('__LOOKUP__', $LookupColumn)
    $xaml = $xaml.Replace('__AGGATTR__', $AggregateAttribute).Replace('__AGGOP__', $AggregateOperator)
    if ($FilterAttribute) {
        $xaml = $xaml.Replace('__FILTERATTR__', $FilterAttribute).Replace('__FILTERVALUE__', "$FilterValue").Replace('__FILTERCRMTYPE__', $FilterCrmTypeName)
    }
    return $xaml
}

function Assert-SpecializedColumnReadBack {
    <#
    .SYNOPSIS
        ADR 0057 read-back gate: a specialized column is only "created" when the persisted
        definition proves out. Returns silently on pass; THROWS on any assertion failure.
    .DESCRIPTION
        Asserts: SourceType is the expected value, SourceTypeMask bit 32 (Invalid) is clear,
        FormulaDefinition round-trips exactly, and (rollups) the _date/_state companions exist.
        Bounded retry absorbs metadata-cache lag after the POST.
    #>
    param(
        [Parameter(Mandatory)][string]$TableName,
        [Parameter(Mandatory)][string]$ColumnName,
        [Parameter(Mandatory)][int]$ExpectedSourceType,
        [Parameter(Mandatory)][string]$ExpectedFormulaDefinition,
        [bool]$IsRollup = $false
    )
    $col = $ColumnName.ToLower()
    $rb = $null
    # A successful POST can still 404 on read for 10-20s while metadata propagates — allow ~40s.
    $backoff = @(2, 2, 2, 5, 5, 5, 8, 8)
    foreach ($attempt in 1..8) {
        try {
            $rb = Invoke-DataverseWebApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$($TableName.ToLower())')/Attributes(LogicalName='$col')"
            break
        } catch {
            if ($attempt -eq 8) { throw "[READBACK] Could not read '$col' back after create: $($_.Exception.Message)" }
            Start-Sleep -Seconds $backoff[$attempt - 1]
        }
    }
    if ($rb.SourceType -ne $ExpectedSourceType) {
        throw "[READBACK] '$col' persisted with SourceType=$($rb.SourceType), expected $ExpectedSourceType."
    }
    if ($rb.SourceTypeMask -band 32) {
        throw "[READBACK] '$col' has SourceTypeMask bit 32 (Invalid) set — the definition references something broken."
    }
    if ($rb.FormulaDefinition -cne $ExpectedFormulaDefinition) {
        throw "[READBACK] '$col' FormulaDefinition did not round-trip (persisted $($rb.FormulaDefinition.Length) chars, sent $($ExpectedFormulaDefinition.Length))."
    }
    if ($IsRollup) {
        # Companions materialize with their own (short) propagation delay — retry independently.
        $missing = $null
        foreach ($attempt in 1..5) {
            $attrs = Invoke-DataverseWebApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$($TableName.ToLower())')/Attributes?`$select=LogicalName"
            $names = @($attrs.value.LogicalName)
            $missing = @(@("${col}_date", "${col}_state") | Where-Object { $names -notcontains $_ })
            if ($missing.Count -eq 0) { break }
            if ($attempt -lt 5) { Start-Sleep -Seconds 3 }
        }
        if ($missing.Count -gt 0) {
            throw "[READBACK] rollup companion(s) $($missing -join ', ') were not auto-created."
        }
    }
    Write-Host "  [READBACK] $col verified: SourceType=$ExpectedSourceType, definition round-trip OK$(if ($IsRollup) { ', _date/_state companions present' })" -ForegroundColor Green
}

function New-SpecializedDataverseColumn {
    <#
    .SYNOPSIS
        Creates a rollup or Power Fx formula column headlessly (ADR 0057).
    .DESCRIPTION
        POSTs typed attribute metadata with SourceType + FormulaDefinition — the surface
        Microsoft's docs decline to support, adopted as an HSO Override by ADR 0057 because
        the platform validates the definition server-side and the read-back gate proves the
        result. On a server-side rejection OR a failed read-back gate this degrades to the
        legacy [MAKER-PORTAL-TODO] record-and-skip (a gate failure additionally deletes the
        bad column — no half-builds, #405), so older runs' behavior is the floor, not the loss.
    #>
    param(
        [Parameter(Mandatory)][string]$TableName,
        [Parameter(Mandatory)][string]$ColumnName,
        [Parameter(Mandatory)][ValidateSet('Rollup', 'Formula')][string]$Kind,
        [string]$ColumnDisplayName,
        [string]$ColumnDescription,
        [bool]$Required = $false,
        # Rollup shape
        [string]$RollupRelatedTable,
        [string]$RollupRelationship,
        [string]$RollupLookupColumn,
        [string]$RollupAggregate = 'Count',
        [string]$RollupAggregateColumn,
        [string]$RollupFilterAttribute,
        $RollupFilterValue,
        # Formula shape
        [string]$FormulaExpression,
        [string]$FormulaResultType,
        [string]$SolutionName
    )

    Write-Host "`n=== Adding $Kind Column: $ColumnName to $TableName (ADR 0057) ===" -ForegroundColor Cyan
    Write-DescriptionWarning -ComponentKind "column" -ComponentName $ColumnName -Description $ColumnDescription

    $columnDefinition = @{
        "SchemaName"    = $ColumnName
        "DisplayName"   = (New-LabelStructure -Label $ColumnDisplayName)
        "RequiredLevel" = (New-RequiredLevel -Required $Required)
    }
    if ($ColumnDescription) { $columnDefinition["Description"] = (New-LabelStructure -Label $ColumnDescription) }

    if ($Kind -eq 'Rollup') {
        # --- config validation (deterministic errors fail loudly BEFORE any write) ---
        foreach ($req in @('RollupRelatedTable', 'RollupRelationship', 'RollupLookupColumn')) {
            if (-not (Get-Variable -Name $req -ValueOnly)) { throw "Rollup column '$ColumnName' declares a definition but is missing -$req." }
        }
        if ($RollupAggregate -ne 'Count' -and -not $RollupAggregateColumn) {
            throw "Rollup column '$ColumnName': -RollupAggregate $RollupAggregate requires -RollupAggregateColumn (the child column to aggregate)."
        }
        if ($RollupFilterAttribute -and $null -eq $RollupFilterValue) {
            throw "Rollup column '$ColumnName': -RollupFilterAttribute requires -RollupFilterValue (the qualifying option value)."
        }

        # --- preflight: platform cap of 10 rollup columns per table ---
        $existing = Invoke-DataverseWebApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$($TableName.ToLower())')/Attributes?`$select=LogicalName,SourceType"
        $rollupCount = @($existing.value | Where-Object { $_.SourceType -eq 2 }).Count
        if ($rollupCount -ge 10) {
            throw "Rollup column '$ColumnName': table '$TableName' already has $rollupCount rollup columns (platform cap: 10 per table, 100 per org)."
        }

        $child = $RollupRelatedTable.ToLower()

        # --- aggregate step: Count aggregates the child PK; others aggregate the declared column and
        #     the rollup's own result type MIRRORS that column's type (never a hand-picked stand-in) ---
        # EvaluateExpression operator strings, live-verified on a Dev test org (2026-08-06).
        # NB: NOT the ValidateSet names — the workflow activities are Minimum/Maximum/Average.
        $aggregateOperators = @{ Count = 'Count'; Sum = 'Sum'; Min = 'Minimum'; Max = 'Maximum'; Avg = 'Average' }
        if ($RollupAggregate -eq 'Count') {
            $childMeta = Invoke-DataverseWebApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$child')?`$select=PrimaryIdAttribute"
            $aggAttr = $childMeta.PrimaryIdAttribute
            $resultShape = @{ "@odata.type" = "Microsoft.Dynamics.CRM.IntegerAttributeMetadata"; "Format" = "None"; "MinValue" = -2147483648; "MaxValue" = 2147483647 }
        } else {
            $aggAttr = $RollupAggregateColumn.ToLower()
            $aggMeta = Invoke-DataverseWebApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$child')/Attributes(LogicalName='$aggAttr')"
            switch ($aggMeta.AttributeType) {
                "Integer" { $resultShape = @{ "@odata.type" = "Microsoft.Dynamics.CRM.IntegerAttributeMetadata"; "Format" = "None"; "MinValue" = -2147483648; "MaxValue" = 2147483647 } }
                "Decimal" { $resultShape = @{ "@odata.type" = "Microsoft.Dynamics.CRM.DecimalAttributeMetadata"; "Precision" = $(if ($aggMeta.Precision) { $aggMeta.Precision } else { 2 }); "MinValue" = -100000000000; "MaxValue" = 100000000000 } }
                "Money"   { $resultShape = @{ "@odata.type" = "Microsoft.Dynamics.CRM.MoneyAttributeMetadata"; "PrecisionSource" = 2 } }
                "DateTime" {
                    if ($RollupAggregate -notin @('Min', 'Max')) { throw "Rollup column '$ColumnName': DateTime child column '$aggAttr' only supports Min/Max aggregation." }
                    $resultShape = @{ "@odata.type" = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"; "Format" = "DateAndTime"; "DateTimeBehavior" = @{ "Value" = "UserLocal" } }
                }
                default { throw "Rollup column '$ColumnName': child column '$aggAttr' has AttributeType '$($aggMeta.AttributeType)' — not aggregatable (Integer/Decimal/Money/DateTime only)." }
            }
        }

        # --- optional filter: single Equal condition on a state/status/choice column ---
        $filterCrmType = $null
        if ($RollupFilterAttribute) {
            $filterCrmType = switch ($RollupFilterAttribute.ToLower()) {
                "statecode"  { "State" }
                "statuscode" { "Status" }
                default      { "Picklist" }
            }
        }

        $xaml = Get-RollupFormulaXaml -ChildTable $child -RelationshipSchemaName $RollupRelationship `
            -LookupColumn $RollupLookupColumn.ToLower() -AggregateOperator $aggregateOperators[$RollupAggregate] `
            -AggregateAttribute $aggAttr -FilterAttribute $(if ($RollupFilterAttribute) { $RollupFilterAttribute.ToLower() }) `
            -FilterValue $RollupFilterValue -FilterCrmTypeName $filterCrmType

        foreach ($k in $resultShape.Keys) { $columnDefinition[$k] = $resultShape[$k] }
        $columnDefinition["SourceType"] = 2
        $columnDefinition["FormulaDefinition"] = $xaml
        $expectedSourceType = 2
        $expectedDefinition = $xaml
        Write-Host "  Compiled rollup: $RollupAggregate over $child ($RollupRelationship)$(if ($RollupFilterAttribute) { " where $RollupFilterAttribute = $RollupFilterValue" })" -ForegroundColor Gray
    }
    else {
        # --- Formula (Power Fx). Classic calculated columns are deprecated and out of scope (ADR 0057). ---
        if (-not $FormulaExpression) { throw "Formula column '$ColumnName' requires -FormulaExpression (the Power Fx expression)." }
        if (-not $FormulaResultType) { throw "Formula column '$ColumnName' requires -FormulaResultType (String | Decimal | Boolean | DateTime)." }
        switch ($FormulaResultType) {
            "String"  { $resultShape = @{ "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"; "MaxLength" = 100; "FormatName" = @{ "Value" = "Text" } } }
            "Decimal" { $resultShape = @{ "@odata.type" = "Microsoft.Dynamics.CRM.DecimalAttributeMetadata"; "Precision" = 2 } }
            "Boolean" {
                $resultShape = @{
                    "@odata.type" = "Microsoft.Dynamics.CRM.BooleanAttributeMetadata"
                    "OptionSet"   = @{
                        "@odata.type" = "Microsoft.Dynamics.CRM.BooleanOptionSetMetadata"
                        "TrueOption"  = @{ "Value" = 1; "Label" = (New-LabelStructure -Label "Yes") }
                        "FalseOption" = @{ "Value" = 0; "Label" = (New-LabelStructure -Label "No") }
                    }
                }
            }
            "DateTime" { $resultShape = @{ "@odata.type" = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"; "Format" = "DateOnly"; "DateTimeBehavior" = @{ "Value" = "DateOnly" } } }
        }
        foreach ($k in $resultShape.Keys) { $columnDefinition[$k] = $resultShape[$k] }
        $columnDefinition["SourceType"] = 3
        $columnDefinition["FormulaDefinition"] = $FormulaExpression
        $expectedSourceType = 3
        $expectedDefinition = $FormulaExpression
        Write-Host "  Power Fx ($FormulaResultType): $FormulaExpression" -ForegroundColor Gray
    }

    # --- create + read-back gate; degrade to the legacy record-and-skip on failure (ADR 0057 §4) ---
    $endpoint = "EntityDefinitions(LogicalName='$($TableName.ToLower())')/Attributes"
    try {
        $result = Invoke-DataverseWebApi -Method "POST" -Endpoint $endpoint -Body $columnDefinition -SolutionName $SolutionName
    } catch {
        $script:WarnCount++
        Write-Host "  [WARN] Server rejected the $Kind definition: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  [MAKER-PORTAL-TODO] $ColumnName ($Kind) - create it in the maker portal; the headless definition was rejected (see error above). Skipped, not half-built." -ForegroundColor Magenta
        return
    }
    try {
        Assert-SpecializedColumnReadBack -TableName $TableName -ColumnName $ColumnName `
            -ExpectedSourceType $expectedSourceType -ExpectedFormulaDefinition $expectedDefinition -IsRollup:($Kind -eq 'Rollup')
    } catch {
        # No half-builds (#405): remove the failed column, then record the maker-portal TODO.
        # The delete retries through propagation lag — a just-POSTed attribute can 404 on
        # DELETE for the same reason it 404'd on GET.
        $script:WarnCount++
        Write-Host "  [WARN] Read-back gate failed: $($_.Exception.Message)" -ForegroundColor Yellow
        $deleted = $false
        foreach ($attempt in 1..4) {
            try {
                Invoke-DataverseWebApi -Method "DELETE" -Endpoint "EntityDefinitions(LogicalName='$($TableName.ToLower())')/Attributes(LogicalName='$($ColumnName.ToLower())')"
                $deleted = $true
                Write-Host "  Deleted the unverified column (no half-builds)." -ForegroundColor Gray
                break
            } catch {
                if ($attempt -lt 4) { Start-Sleep -Seconds 5 }
            }
        }
        if (-not $deleted) {
            Write-Host "  [WARN] Could not delete the unverified column — remove '$ColumnName' manually before recreating." -ForegroundColor Yellow
        }
        Write-Host "  [MAKER-PORTAL-TODO] $ColumnName ($Kind) - create it in the maker portal; the headless create did not verify. Skipped." -ForegroundColor Magenta
        return
    }

    if ($Kind -eq 'Rollup') {
        Write-Host "  [ROLLUP] Initial Mass Calculate job runs ~12h from now; for immediate values call the UNBOUND CalculateRollupField function per record (it is not a bound action — see references/rollup-formula-columns-web-api.md)." -ForegroundColor Yellow
    }
    Write-Host "  Column created successfully!" -ForegroundColor Green
    return $result
}

function Add-DataverseColumn {
    param(
        [string]$TableName,
        [string]$ColumnName,
        [string]$ColumnDisplayName,
        [string]$ColumnDescription,    # HSO standard — required. Renders as the tooltip in model-driven apps.
        [string]$ColumnType,
        [int]$MaxLength,
        [int]$Precision,
        [bool]$Required,
        [string]$GlobalChoiceName,
        [string]$DateTimeFormat,
        [string]$DateTimeBehavior,  # UserLocal, DateOnly, or TimeZoneIndependent
        [string]$StringFormat,
        $DefaultValue,
        [double]$ColumnMinValue,
        [double]$ColumnMaxValue,
        [string]$SolutionName,
        # Specialized-column shapes (ADR 0057) — consumed only when ColumnType is Rollup/Formula
        [string]$FormulaExpression,
        [string]$FormulaResultType,
        [string]$RollupRelatedTable,
        [string]$RollupRelationship,
        [string]$RollupLookupColumn,
        [string]$RollupAggregate = 'Count',
        [string]$RollupAggregateColumn,
        [string]$RollupFilterAttribute,
        $RollupFilterValue
    )

    # Auto-prepend publisher prefix if missing. Add-PublisherPrefix distinguishes a real publisher
    # prefix from a compound name, so "hsosol_effort_num" stays put but "unit_cost_num" is prefixed.
    if ($script:PublisherPrefix) {
        $prefixedColumnName = Add-PublisherPrefix -Name $ColumnName
        if ($prefixedColumnName -ne $ColumnName) {
            $ColumnName = $prefixedColumnName
            Write-Host "  Auto-prefixed column name to: $ColumnName" -ForegroundColor Gray
        }
    }

    # ADR 0057: rollup + Power Fx formula columns are created headlessly via a FormulaDefinition
    # write. Classic Calculated stays maker-portal-only (deprecated — author as Formula instead),
    # and a Rollup declared WITHOUT its definition shape keeps the legacy #405 record-and-skip so
    # older specs degrade gracefully instead of half-building or hard-failing.
    if ($ColumnType -eq 'Calculated') {
        $script:WarnCount++
        Write-Host "  [MAKER-PORTAL-TODO] $ColumnName (Calculated) - classic calculated columns are deprecated and not built headlessly (ADR 0057). Author it as -ColumnType Formula (Power Fx), or create it in the maker portal. Skipped." -ForegroundColor Magenta
        return
    }
    if ($ColumnType -eq 'Rollup' -and -not $RollupRelatedTable -and -not $RollupRelationship) {
        $script:WarnCount++
        Write-Host "  [MAKER-PORTAL-TODO] $ColumnName (Rollup) - no rollup definition declared; create it in the maker portal, or declare RollupRelatedTable/RollupRelationship/RollupLookupColumn (+ aggregate/filter) to build it headlessly (ADR 0057). Skipped, not half-built (#405)." -ForegroundColor Magenta
        return
    }
    if ($ColumnType -in @('Rollup', 'Formula')) {
        $specParams = @{
            TableName         = $TableName
            ColumnName        = $ColumnName
            Kind              = $ColumnType
            ColumnDisplayName = $ColumnDisplayName
            ColumnDescription = $ColumnDescription
            Required          = (ConvertTo-CoercedBool -Value $Required -ParamName 'Required')
            SolutionName      = $SolutionName
        }
        foreach ($p in @('FormulaExpression', 'FormulaResultType', 'RollupRelatedTable', 'RollupRelationship', 'RollupLookupColumn', 'RollupAggregate', 'RollupAggregateColumn', 'RollupFilterAttribute', 'RollupFilterValue')) {
            $v = Get-Variable -Name $p -ValueOnly
            if ($null -ne $v -and "$v" -ne '') { $specParams[$p] = $v }
        }
        return New-SpecializedDataverseColumn @specParams
    }

    Write-Host "`n=== Adding Column: $ColumnName to $TableName ===" -ForegroundColor Cyan
    Write-DescriptionWarning -ComponentKind "column" -ComponentName $ColumnName -Description $ColumnDescription

    $columnDefinition = @{
        "SchemaName" = $ColumnName
        "DisplayName" = (New-LabelStructure -Label $ColumnDisplayName)
        "RequiredLevel" = (New-RequiredLevel -Required $Required)
    }
    if ($ColumnDescription) {
        $columnDefinition["Description"] = (New-LabelStructure -Label $ColumnDescription)
    }

    # Default a non-positive MaxLength to a sane platform value (ADR 0025): a Memo/String created with
    # MaxLength 0 (an explicit 0 or an omitted value coerced to [int] 0) is rejected by the API. Floor it
    # rather than failing the build.
    if (($ColumnType -in @("String", "Memo")) -and ($MaxLength -le 0)) {
        $defaultedMax = if ($ColumnType -eq "Memo") { 2000 } else { 100 }
        Write-Host "  [DEFAULT] $ColumnType column '$ColumnName' had MaxLength $MaxLength -> defaulting to $defaultedMax" -ForegroundColor Yellow
        $MaxLength = $defaultedMax
    }

    switch ($ColumnType) {
        "String" {
            $columnDefinition["@odata.type"] = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            $columnDefinition["AttributeType"] = "String"
            $columnDefinition["AttributeTypeName"] = @{ "Value" = "StringType" }
            $columnDefinition["MaxLength"] = $MaxLength
            $columnDefinition["FormatName"] = @{ "Value" = $StringFormat }
        }
        "Memo" {
            $columnDefinition["@odata.type"] = "Microsoft.Dynamics.CRM.MemoAttributeMetadata"
            $columnDefinition["AttributeType"] = "Memo"
            $columnDefinition["AttributeTypeName"] = @{ "Value" = "MemoType" }
            $columnDefinition["MaxLength"] = $MaxLength
            $columnDefinition["Format"] = "TextArea"
        }
        "Integer" {
            $columnDefinition["@odata.type"] = "Microsoft.Dynamics.CRM.IntegerAttributeMetadata"
            $columnDefinition["AttributeType"] = "Integer"
            $columnDefinition["AttributeTypeName"] = @{ "Value" = "IntegerType" }
            $columnDefinition["Format"] = "None"
            $columnDefinition["MinValue"] = if ($PSBoundParameters.ContainsKey('ColumnMinValue')) { [int]$ColumnMinValue } else { -2147483648 }
            $columnDefinition["MaxValue"] = if ($PSBoundParameters.ContainsKey('ColumnMaxValue')) { [int]$ColumnMaxValue } else { 2147483647 }
            if ($PSBoundParameters.ContainsKey('DefaultValue') -and $null -ne $DefaultValue) {
                $columnDefinition["DefaultValue"] = [int]$DefaultValue
            }
        }
        "Decimal" {
            $columnDefinition["@odata.type"] = "Microsoft.Dynamics.CRM.DecimalAttributeMetadata"
            $columnDefinition["AttributeType"] = "Decimal"
            $columnDefinition["AttributeTypeName"] = @{ "Value" = "DecimalType" }
            $columnDefinition["Precision"] = $Precision
            $columnDefinition["MinValue"] = if ($PSBoundParameters.ContainsKey('ColumnMinValue')) { [double]$ColumnMinValue } else { -100000000000 }
            $columnDefinition["MaxValue"] = if ($PSBoundParameters.ContainsKey('ColumnMaxValue')) { [double]$ColumnMaxValue } else { 100000000000 }
            if ($PSBoundParameters.ContainsKey('DefaultValue') -and $null -ne $DefaultValue) {
                $columnDefinition["DefaultValue"] = [double]$DefaultValue
            }
        }
        "Money" {
            $columnDefinition["@odata.type"] = "Microsoft.Dynamics.CRM.MoneyAttributeMetadata"
            $columnDefinition["AttributeType"] = "Money"
            $columnDefinition["AttributeTypeName"] = @{ "Value" = "MoneyType" }
            $columnDefinition["PrecisionSource"] = 2
            # Money MinValue/MaxValue: only set when the caller supplies them, otherwise the platform
            # default range applies (which permits negatives). Pass -ColumnMinValue 0 for amounts that
            # should never go negative (e.g. replacement cost, annual value). Parity with Integer/Decimal.
            if ($PSBoundParameters.ContainsKey('ColumnMinValue')) { $columnDefinition["MinValue"] = [double]$ColumnMinValue }
            if ($PSBoundParameters.ContainsKey('ColumnMaxValue')) { $columnDefinition["MaxValue"] = [double]$ColumnMaxValue }
        }
        "Boolean" {
            $columnDefinition["@odata.type"] = "Microsoft.Dynamics.CRM.BooleanAttributeMetadata"
            $columnDefinition["AttributeType"] = "Boolean"
            $columnDefinition["AttributeTypeName"] = @{ "Value" = "BooleanType" }
            $columnDefinition["DefaultValue"] = if ($PSBoundParameters.ContainsKey('DefaultValue')) { [bool]$DefaultValue } else { $false }
            $columnDefinition["OptionSet"] = @{
                "@odata.type" = "Microsoft.Dynamics.CRM.BooleanOptionSetMetadata"
                "TrueOption" = @{
                    "Value" = 1
                    "Label" = (New-LabelStructure -Label "Yes")
                }
                "FalseOption" = @{
                    "Value" = 0
                    "Label" = (New-LabelStructure -Label "No")
                }
            }
        }
        "DateTime" {
            $columnDefinition["@odata.type"] = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"
            $columnDefinition["AttributeType"] = "DateTime"
            $columnDefinition["AttributeTypeName"] = @{ "Value" = "DateTimeType" }
            $columnDefinition["Format"] = $DateTimeFormat

            # Determine DateTimeBehavior:
            # - If explicitly provided, use it
            # - If DateOnly format with no behavior specified, default to DateOnly (timezone-independent)
            # - Otherwise default to UserLocal (timezone-aware)
            $behavior = $DateTimeBehavior
            if (-not $behavior) {
                if ($DateTimeFormat -eq "DateOnly") {
                    $behavior = "DateOnly"
                    Write-Host "  Using DateOnly behavior (timezone-independent)" -ForegroundColor Gray
                } else {
                    $behavior = "UserLocal"
                }
            }
            $columnDefinition["DateTimeBehavior"] = @{ "Value" = $behavior }
        }
        "Picklist" {
            $columnDefinition["@odata.type"] = "Microsoft.Dynamics.CRM.PicklistAttributeMetadata"
            $columnDefinition["AttributeType"] = "Picklist"
            $columnDefinition["AttributeTypeName"] = @{ "Value" = "PicklistType" }
            if ($GlobalChoiceName) {
                Write-Host "  Looking up global choice: $GlobalChoiceName" -ForegroundColor Gray
                $optionSetId = Get-GlobalOptionSetId -OptionSetName $GlobalChoiceName
                if ($optionSetId) {
                    $columnDefinition["GlobalOptionSet@odata.bind"] = "/GlobalOptionSetDefinitions($optionSetId)"
                    Write-Host "  Found global choice ID: $optionSetId" -ForegroundColor Gray
                }
                else {
                    throw "Global option set '$GlobalChoiceName' not found. Create it first using CreateGlobalChoice operation."
                }
            }
            if ($PSBoundParameters.ContainsKey('DefaultValue') -and $null -ne $DefaultValue) {
                $columnDefinition["DefaultFormValue"] = [int]$DefaultValue
            }
        }
        "MultiSelectPicklist" {
            $columnDefinition["@odata.type"] = "Microsoft.Dynamics.CRM.MultiSelectPicklistAttributeMetadata"
            $columnDefinition["AttributeType"] = "Virtual"
            $columnDefinition["AttributeTypeName"] = @{ "Value" = "MultiSelectPicklistType" }
            if ($GlobalChoiceName) {
                Write-Host "  Looking up global choice: $GlobalChoiceName" -ForegroundColor Gray
                $optionSetId = Get-GlobalOptionSetId -OptionSetName $GlobalChoiceName
                if ($optionSetId) {
                    $columnDefinition["GlobalOptionSet@odata.bind"] = "/GlobalOptionSetDefinitions($optionSetId)"
                    Write-Host "  Found global choice ID: $optionSetId" -ForegroundColor Gray
                }
                else {
                    throw "Global option set '$GlobalChoiceName' not found. Create it first using CreateGlobalChoice operation."
                }
            }
        }
    }

    $endpoint = "EntityDefinitions(LogicalName='$($TableName.ToLower())')/Attributes"

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint $endpoint `
        -Body $columnDefinition -SolutionName $SolutionName

    Write-Host "  Column created successfully!" -ForegroundColor Green
    return $result
}

function Add-DataverseColumns {
    <#
    .SYNOPSIS
        Creates multiple columns on a table in a single batch operation.
    .DESCRIPTION
        Iterates through an array of column definitions and creates each column.
        Authentication token is cached after first call, so subsequent columns
        are created without re-prompting for login.
    .PARAMETER TableName
        The logical name of the table to add columns to.
    .PARAMETER Columns
        Array of column definition objects. Each object should have:
        - Name (required): Schema name for the column (e.g., "hso_subject_text")
        - DisplayName (required): Display name shown in UI
        - Type (required): String, Memo, Integer, Decimal, Money, Boolean, DateTime, Picklist, MultiSelectPicklist, Rollup, Formula
        - Rollup (for Type=Rollup, ADR 0057): { RelatedTable, Relationship, LookupColumn, Aggregate?, AggregateColumn?, FilterAttribute?, FilterValue? }
        - Formula (for Type=Formula, ADR 0057): { Expression (Power Fx), ResultType (String|Decimal|Boolean|DateTime) }
        - MaxLength: For String/Memo types (default: 100)
        - Precision: For Decimal type (default: 2)
        - Required: Boolean (default: false)
        - GlobalChoiceName: For Picklist/MultiSelectPicklist types
        - DateTimeFormat: DateOnly or DateAndTime (default: DateAndTime)
        - StringFormat: Text, Email, Url, Phone, TextArea (default: Text)
        - DefaultValue: Default value for Boolean/Integer/Decimal/Picklist
        - MinValue: Min value for Integer/Decimal/Money (pass 0 for non-negative currency)
        - MaxValue: Max value for Integer/Decimal/Money
    .PARAMETER SolutionName
        The solution to add the columns to.
    .EXAMPLE
        $columnsJson = '[{"Name":"hso_subject_text","DisplayName":"Subject","Type":"String","MaxLength":200}]'
        Add-DataverseColumns -TableName "hso_emailtemplate" -Columns ($columnsJson | ConvertFrom-Json) -SolutionName "MySolution"
    #>
    param(
        [string]$TableName,
        [array]$Columns,
        [string]$SolutionName
    )

    Write-Host "`n=== Batch Creating $($Columns.Count) Columns on $TableName ===" -ForegroundColor Cyan

    $successCount = 0
    $failCount = 0
    $results = @()

    foreach ($col in $Columns) {
        Write-Host "`n--- Column $($successCount + $failCount + 1) of $($Columns.Count): $($col.Name) ---" -ForegroundColor Yellow

        # Map column properties with defaults (built once, reused on retry)
        $colParams = @{
            TableName = $TableName
            ColumnName = $col.Name
            ColumnDisplayName = $col.DisplayName
            ColumnType = $col.Type
            SolutionName = $SolutionName
        }
        if ($col.Description) { $colParams['ColumnDescription'] = $col.Description }
        if ($col.MaxLength) { $colParams['MaxLength'] = $col.MaxLength }
        if ($col.Precision) { $colParams['Precision'] = $col.Precision }
        if ($null -ne $col.Required) { $colParams['Required'] = $col.Required }
        if ($col.GlobalChoiceName) { $colParams['GlobalChoiceName'] = $col.GlobalChoiceName }
        if ($col.DateTimeFormat) { $colParams['DateTimeFormat'] = $col.DateTimeFormat }
        if ($col.DateTimeBehavior) { $colParams['DateTimeBehavior'] = $col.DateTimeBehavior }
        if ($col.StringFormat) { $colParams['StringFormat'] = $col.StringFormat }
        if ($null -ne $col.DefaultValue) { $colParams['DefaultValue'] = $col.DefaultValue }
        # MinValue / MaxValue for Integer/Decimal/Money columns (Money pass 0 for non-negative currency)
        if ($null -ne $col.MinValue -and "$($col.MinValue)" -ne '') { $colParams['ColumnMinValue'] = $col.MinValue }
        if ($null -ne $col.MaxValue -and "$($col.MaxValue)" -ne '') { $colParams['ColumnMaxValue'] = $col.MaxValue }
        # Specialized-column shapes (ADR 0057): nested objects in the column JSON.
        #   "Rollup":  { RelatedTable, Relationship, LookupColumn, Aggregate?, AggregateColumn?, FilterAttribute?, FilterValue? }
        #   "Formula": { Expression, ResultType }
        if ($col.Rollup) {
            if ($col.Rollup.RelatedTable)    { $colParams['RollupRelatedTable']    = $col.Rollup.RelatedTable }
            if ($col.Rollup.Relationship)    { $colParams['RollupRelationship']    = $col.Rollup.Relationship }
            if ($col.Rollup.LookupColumn)    { $colParams['RollupLookupColumn']    = $col.Rollup.LookupColumn }
            if ($col.Rollup.Aggregate)       { $colParams['RollupAggregate']       = $col.Rollup.Aggregate }
            if ($col.Rollup.AggregateColumn) { $colParams['RollupAggregateColumn'] = $col.Rollup.AggregateColumn }
            if ($col.Rollup.FilterAttribute) { $colParams['RollupFilterAttribute'] = $col.Rollup.FilterAttribute }
            if ($null -ne $col.Rollup.FilterValue -and "$($col.Rollup.FilterValue)" -ne '') { $colParams['RollupFilterValue'] = $col.Rollup.FilterValue }
        }
        if ($col.Formula) {
            if ($col.Formula.Expression) { $colParams['FormulaExpression'] = $col.Formula.Expression }
            if ($col.Formula.ResultType) { $colParams['FormulaResultType'] = $col.Formula.ResultType }
        }

        # One bounded retry, scoped to TRANSIENT server-side failures only. Dataverse intermittently
        # returns 400 "An unexpected error occurred" (or 429/5xx) on batch column create where an
        # identically-configured sibling succeeds; a single re-issue clears it. We do NOT retry
        # deterministic config errors (those keep their original message and fail immediately).
        $maxAttempts = 2
        $attempt = 0
        $created = $false
        $lastError = $null
        while ($attempt -lt $maxAttempts -and -not $created) {
            $attempt++
            try {
                $null = Add-DataverseColumn @colParams
                $created = $true
            }
            catch {
                $lastError = $_.Exception.Message
                $isTransient = $lastError -match 'unexpected error|timed out|timeout|throttl|Service Unavailable|\b(429|500|502|503|504)\b'
                if ($isTransient -and $attempt -lt $maxAttempts) {
                    Write-Host "  [RETRY] Transient failure on '$($col.Name)' (attempt $attempt): $lastError" -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                } else {
                    break
                }
            }
        }

        if ($created) {
            $successCount++
            $results += @{ Name = $col.Name; Status = "Success"; Attempts = $attempt }
        } else {
            Write-Host "  [ERROR] Failed to create column '$($col.Name)' after $attempt attempt(s): $lastError" -ForegroundColor Red
            $failCount++
            $results += @{ Name = $col.Name; Status = "Failed"; Error = $lastError; Attempts = $attempt }
        }
    }

    # Summary
    Write-Host "`n=== Batch Column Creation Complete ===" -ForegroundColor Cyan
    Write-Host "  Successful: $successCount / $($Columns.Count)" -ForegroundColor Green
    if ($failCount -gt 0) {
        # Loud, impossible-to-miss banner: a half-built table must not be mistaken for done.
        Write-Host ""
        Write-Host "########################################################################" -ForegroundColor Red
        Write-Host "##  BATCH INCOMPLETE: $failCount of $($Columns.Count) column(s) FAILED — TABLE IS HALF-BUILT  ##" -ForegroundColor Red
        Write-Host "########################################################################" -ForegroundColor Red
        Write-Host "  Failed columns (re-run AddColumns with just these — transient errors usually clear):" -ForegroundColor Yellow
        $results | Where-Object { $_.Status -eq "Failed" } | ForEach-Object {
            Write-Host "    - $($_.Name): $($_.Error)" -ForegroundColor Red
        }
        Write-Host ""
        # Non-zero exit so an orchestrator cannot silently proceed past a half-built table.
        exit 1
    }

    return $results
}

#endregion

#region Relationship Operations

function Add-RelationshipParentsToSolution {
    # Every parent/referenced table must be in the SOLUTION before the relationship POST, or the
    # relationship is SILENTLY DROPPED on export. Auto-include each (metadata-only, idempotent).
    param(
        [string[]]$ParentTables,
        [string]$SolutionName
    )
    if ([string]::IsNullOrWhiteSpace($SolutionName)) { return }
    foreach ($p in ($ParentTables | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        try {
            Add-TableToSolution -TableName $p -SolutionName $SolutionName -DoNotIncludeSubcomponents $true | Out-Null
            Write-Host "  [SOLUTION] Auto-included referenced table '$p' in '$SolutionName' (else the relationship drops on export)." -ForegroundColor Cyan
        }
        catch {
            Write-Host "  [WARN] Could not auto-include referenced table '$p' in '$SolutionName' ($($_.Exception.Message))." -ForegroundColor Yellow
            $script:WarnCount++
        }
    }
}

function New-OneToManyRelationship {
    param(
        [string]$ParentTable,
        [string]$ChildTable,
        [string]$LookupName,
        [string]$LookupDisplayName,
        [string]$LookupDescription,    # HSO standard — required. Description on the generated lookup column.
        [string]$CascadeDelete,
        [string]$CascadeAssign,
        [string]$RequiredLevel,        # Optional requirement level for the generated lookup (None|ApplicationRequired|Recommended). Defaults to None.
        [string]$SolutionName,
        [string]$RelationshipSchemaName  # Optional: override auto-generated schema name
    )

    Write-Host "`n=== Creating 1:N Relationship ===" -ForegroundColor Cyan
    Write-Host "  Parent: $ParentTable -> Child: $ChildTable" -ForegroundColor Gray
    Write-DescriptionWarning -ComponentKind "lookup" -ComponentName $LookupName -Description $LookupDescription

    # Determine primary key attribute
    $parentLogical = $ParentTable.ToLower()
    $parentPrimaryKey = if ($ParentPrimaryKey) { $ParentPrimaryKey } else { "${parentLogical}id" }

    # Build relationship schema name (use explicit override if provided, otherwise auto-derive)
    if ($RelationshipSchemaName) {
        $relationshipSchemaName = $RelationshipSchemaName
        Write-Host "  Schema name (explicit): $relationshipSchemaName" -ForegroundColor Gray
    } else {
        # Derive the relationship-name prefix from the CHILD table's own logical name, which is
        # authoritative: the child already exists in the org, so whatever prefix it carries is the
        # one that actually applies. Test-NameAlreadyPrefixed keeps a compound child name like
        # "service_agreement" from yielding a bogus prefix of "service". Falls back to the resolved
        # prefix when the child carries none.
        $relPrefix = Get-NamePublisherPrefix -Name $ChildTable
        $parentBare = $ParentTable -replace "^${relPrefix}_", ''
        $childBare  = $ChildTable  -replace "^${relPrefix}_", ''
        $relationshipSchemaName = "${relPrefix}_${parentBare}_${childBare}"

        # Duplicate-relationship guard: when the schema name is AUTO-DERIVED, two lookups between the
        # same parent/child pair (e.g. a Customer lookup AND a separate contact lookup, both
        # contact -> agreement) derive the IDENTICAL name and the platform rejects the second with an
        # opaque error. Detect the clash up front and FAIL LOUDLY with a ready-to-use suggested name,
        # rather than silently inventing one (which could mask a genuine modelling mistake).
        try {
            $existing = Invoke-DataverseWebApi -Method "GET" `
                -Endpoint "EntityDefinitions(LogicalName='$parentLogical')/OneToManyRelationships?`$filter=SchemaName eq '$relationshipSchemaName'&`$select=SchemaName"
            if ($existing.value -and $existing.value.Count -gt 0) {
                $lookupBare = $LookupName -replace "^${relPrefix}_", '' -replace '_id$', ''
                $suggested = "${relationshipSchemaName}_${lookupBare}"
                Write-Host ""
                Write-Host "  [ERROR] A relationship named '$relationshipSchemaName' already exists between" -ForegroundColor Red
                Write-Host "          '$parentLogical' and '$($ChildTable.ToLower())' (a prior lookup, e.g. a Customer lookup," -ForegroundColor Red
                Write-Host "          auto-created it). A second auto-derived relationship would collide on this name." -ForegroundColor Red
                Write-Host "          Re-run with an explicit, unique schema name, e.g.:" -ForegroundColor Yellow
                Write-Host "            -RelationshipSchemaName $suggested" -ForegroundColor Cyan
                throw "Duplicate relationship schema name '$relationshipSchemaName' between '$parentLogical' and '$($ChildTable.ToLower())'. Pass -RelationshipSchemaName (suggested: $suggested)."
            }
        }
        catch {
            # Only re-throw our own deliberate clash error; a failure of the PROBE itself (e.g. a
            # metadata-query hiccup) must not block a legitimate relationship create.
            if ($_.Exception.Message -match 'Duplicate relationship schema name') { throw }
            Write-Host "  [INFO] Could not pre-check for a duplicate relationship name (continuing): $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    }

    # NOTE: Do NOT include @odata.type on the Lookup object, or AttributeType/AttributeTypeName,
    # or navigation property names — the Web API rejects these with a 400 type-kind error.
    # Verified working payload pattern: only SchemaName, LogicalName, DisplayName, RequiredLevel on Lookup.
    $lookupRequiredLevel = if ($RequiredLevel) { $RequiredLevel } else { "None" }
    $lookupDef = @{
        "SchemaName" = $LookupName
        "LogicalName" = $LookupName.ToLower()
        "DisplayName" = (New-LabelStructure -Label $LookupDisplayName)
        "RequiredLevel" = @{ "Value" = $lookupRequiredLevel }
    }
    if ($LookupDescription) {
        $lookupDef["Description"] = (New-LabelStructure -Label $LookupDescription)
    }

    $relationshipDefinition = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata"
        "SchemaName" = $relationshipSchemaName
        "ReferencedEntity" = $parentLogical
        "ReferencingEntity" = $ChildTable.ToLower()
        "Lookup" = $lookupDef
        "CascadeConfiguration" = @{
            "Assign" = $CascadeAssign
            "Delete" = $CascadeDelete
            "Merge" = "NoCascade"
            "Reparent" = "NoCascade"
            "Share" = "NoCascade"
            "Unshare" = "NoCascade"
        }
    }

    Add-RelationshipParentsToSolution -ParentTables @($ParentTable) -SolutionName $SolutionName

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "RelationshipDefinitions" `
        -Body $relationshipDefinition -SolutionName $SolutionName

    Write-Host "  Relationship created successfully!" -ForegroundColor Green

    # S4: read CascadeConfiguration.Delete back so a requested Cascade that silently landed as the
    # default RemoveLink is visible. Read-only and lag-tolerant — never fails the build.
    Assert-RelationshipCascadeDelete -RelationshipSchemaName $relationshipSchemaName `
        -ReferencedEntity $parentLogical -RequestedDelete $CascadeDelete

    return $result
}

function Assert-RelationshipCascadeDelete {
    param(
        [string]$RelationshipSchemaName,
        [string]$ReferencedEntity,
        [string]$RequestedDelete
    )
    $actualDelete = $null
    try {
        $rb = (Invoke-DataverseWebApi -Method "GET" `
            -Endpoint "EntityDefinitions(LogicalName='$ReferencedEntity')/OneToManyRelationships?`$filter=SchemaName eq '$RelationshipSchemaName'&`$select=SchemaName,CascadeConfiguration").value |
            Select-Object -First 1
        if ($rb -and $rb.CascadeConfiguration) { $actualDelete = "$($rb.CascadeConfiguration.Delete)" }
    } catch { }

    if (-not $actualDelete) {
        Write-Host "  [READBACK][CASCADE] could not read CascadeConfiguration back for '$RelationshipSchemaName' (metadata-cache lag); verify with RelationshipDefinitions if cascade-delete is contractual." -ForegroundColor DarkGray
        return
    }
    Write-Host "  [CASCADE] '$RelationshipSchemaName' actual cascade-delete = $actualDelete" -ForegroundColor DarkGray
    if ($RequestedDelete -and $actualDelete -ne $RequestedDelete) {
        Write-Host "  [READBACK][WARN] cascade-delete mismatch on '$RelationshipSchemaName': requested '$RequestedDelete' but actual is '$actualDelete'." -ForegroundColor Yellow
        $script:WarnCount++
    }
}

function New-ManyToManyRelationship {
    param(
        [string]$Entity1,
        [string]$Entity2,
        [string]$IntersectEntityName,
        [string]$SolutionName
    )

    Write-Host "`n=== Creating N:N Relationship ===" -ForegroundColor Cyan
    Write-Host "  $Entity1 <-> $Entity2" -ForegroundColor Gray

    if (-not $IntersectEntityName) {
        $e1Clean = $Entity1.Replace($script:PublisherPrefix + "_", "")
        $e2Clean = $Entity2.Replace($script:PublisherPrefix + "_", "")
        $IntersectEntityName = "$($script:PublisherPrefix)_${e1Clean}_${e2Clean}"
    }

    $relationshipDefinition = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.ManyToManyRelationshipMetadata"
        "SchemaName" = $IntersectEntityName
        "IntersectEntityName" = $IntersectEntityName
        "Entity1LogicalName" = $Entity1.ToLower()
        "Entity2LogicalName" = $Entity2.ToLower()
        "Entity1NavigationPropertyName" = "${IntersectEntityName}_$($Entity1.ToLower())"
        "Entity2NavigationPropertyName" = "${IntersectEntityName}_$($Entity2.ToLower())"
        "Entity1AssociatedMenuConfiguration" = @{
            "Behavior" = "UseCollectionName"
            "Group" = "Details"
            "Label" = (New-LabelStructure -Label $Entity2)
            "Order" = 10000
        }
        "Entity2AssociatedMenuConfiguration" = @{
            "Behavior" = "UseCollectionName"
            "Group" = "Details"
            "Label" = (New-LabelStructure -Label $Entity1)
            "Order" = 10000
        }
    }

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "RelationshipDefinitions" `
        -Body $relationshipDefinition -SolutionName $SolutionName

    Write-Host "  Relationship created successfully!" -ForegroundColor Green
    return $result
}

function New-CustomerRelationship {
    param(
        [string]$ChildTable,
        [string]$LookupName,
        [string]$LookupDisplayName,
        [string]$LookupDescription,    # HSO standard — required.
        [string]$RequiredLevel,        # Optional requirement level for the generated lookup (None|ApplicationRequired|Recommended). Defaults to None.
        [string]$SolutionName
    )

    Write-Host "`n=== Creating Customer Lookup ===" -ForegroundColor Cyan
    Write-Host "  Table: $ChildTable" -ForegroundColor Gray
    Write-DescriptionWarning -ComponentKind "lookup" -ComponentName $LookupName -Description $LookupDescription

    # IMPORTANT — do NOT set @odata.type on the Lookup or the relationship objects.
    # The *Metadata classes carry a MetadataId key, so the EDM classifies them as ENTITY
    # types; CreateCustomerRelationships declares its parameters as COMPLEX, and the OData
    # reader validates the declared @odata.type against the expected kind before reading any
    # data — entity != complex throws "Incompatible type kinds ... expected kind 'Complex'".
    # With no annotation the reader infers the type from the parameter and succeeds. This
    # mirrors the verified New-PolymorphicLookup payload below.
    $customerRequiredLevel = if ($RequiredLevel) { $RequiredLevel } else { "None" }
    $customerLookup = @{
        "SchemaName" = $LookupName
        "DisplayName" = (New-LabelStructure -Label $LookupDisplayName)
        "RequiredLevel" = @{ "Value" = $customerRequiredLevel }
    }
    if ($LookupDescription) {
        $customerLookup["Description"] = (New-LabelStructure -Label $LookupDescription)
    }

    $customerCascade = @{
        Delete = "RemoveLink"; Merge = "NoCascade"; Reparent = "NoCascade"
        Share = "NoCascade"; Unshare = "NoCascade"; Assign = "NoCascade"
    }
    $customerRelationship = @{
        "Lookup" = $customerLookup
        "OneToManyRelationships" = @(
            @{
                "ReferencedEntity" = "account"
                "ReferencingEntity" = $ChildTable.ToLower()
                "SchemaName" = "$($ChildTable.ToLower())_customer_account"
                "CascadeConfiguration" = $customerCascade
            },
            @{
                "ReferencedEntity" = "contact"
                "ReferencingEntity" = $ChildTable.ToLower()
                "SchemaName" = "$($ChildTable.ToLower())_customer_contact"
                "CascadeConfiguration" = $customerCascade
            }
        )
    }

    Add-RelationshipParentsToSolution -ParentTables @("account", "contact") -SolutionName $SolutionName

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "CreateCustomerRelationships" `
        -Body $customerRelationship -SolutionName $SolutionName

    Write-Host "  Customer lookup created: $LookupName -> account, contact" -ForegroundColor Green

    # Description reminder (read-back safety net). A pre-call missing-description [WARN] can't confirm
    # the description actually landed on the GENERATED customerid attribute — Customer lookups built
    # via CreateCustomerRelationships have been observed shipping without it applied (iksandbox
    # iteration-4: hsot_customerid read back blank shortly after create). Read the persisted
    # description back and, if it's empty, remind the caller with the exact command to set it
    # (UpdateColumn applies attribute descriptions correctly). Read-only, warn-only — and tolerant of
    # metadata-cache lag (the GET can briefly trail a fresh write, so this is a reminder, not a gate).
    try {
        $lookupLower = $LookupName.ToLower()
        $childLower = $ChildTable.ToLower()
        $persisted = Invoke-DataverseWebApi -Method "GET" `
            -Endpoint "EntityDefinitions(LogicalName='$childLower')/Attributes(LogicalName='$lookupLower')?`$select=Description"
        $persistedDesc = if ($persisted.Description -and $persisted.Description.UserLocalizedLabel) { $persisted.Description.UserLocalizedLabel.Label } else { '' }
        if ([string]::IsNullOrWhiteSpace($persistedDesc)) {
            Write-Host ""
            Write-Host "  [DESC] Could not confirm a description on the Customer lookup '$LookupName' (read back blank)." -ForegroundColor Yellow
            Write-Host "         The descriptions-mandatory standard requires one. If it is genuinely missing" -ForegroundColor Yellow
            Write-Host "         (not just metadata-cache lag), set it explicitly with UpdateColumn:" -ForegroundColor Yellow
            $descToUse = if ($LookupDescription) { $LookupDescription } else { '<describe this lookup>' }
            Write-Host "           -Operation UpdateColumn -TableName $childLower ``" -ForegroundColor Cyan
            Write-Host "             -ColumnName $lookupLower -ColumnDescription '$descToUse'" -ForegroundColor Cyan
            Write-Host ""
        } else {
            Write-Host "  [DESC] Customer lookup description confirmed persisted." -ForegroundColor DarkGray
        }
    }
    catch {
        # A read-back hiccup must not fail the create — just note we couldn't verify the description.
        Write-Host "  [INFO] Could not read back the Customer lookup description to verify it (continuing): $($_.Exception.Message)" -ForegroundColor DarkGray
    }
    # Return a tidy scalar summary. The raw CreateCustomerRelationships OData response renders as a
    # mangled one-character-per-line table (RelationshipIds is a PSObject collection hitting the
    # default formatter). A pscustomobject with scalar fields formats cleanly; the underlying ids
    # are still surfaced as a joined string for anyone who needs them.
    $relIds = if ($result.RelationshipIds) { @($result.RelationshipIds) -join ', ' } else { '' }
    return [pscustomobject]@{
        Lookup          = $LookupName
        Targets         = 'account, contact'
        AttributeId     = $result.AttributeId
        RelationshipIds = $relIds
    }
}

function New-PolymorphicLookup {
    <#
    .SYNOPSIS
        Creates a polymorphic lookup field targeting two or more entity types.
    .DESCRIPTION
        Uses the CreatePolymorphicLookupAttribute Web API action. Unlike the Customer
        relationship type (which is limited to Account + Contact), this supports any
        combination of entity types (e.g. Contact + hso_customer_employee).

        IMPORTANT payload rules (verified by testing):
        - Do NOT include @odata.type on relationship objects or the Lookup object
        - Do NOT include ReferencingAttribute or ReferencedAttribute in relationships
        - SolutionUniqueName goes in the request body, not just the header
    .EXAMPLE
        New-PolymorphicLookup -ChildTable "contoso_eventattendee" -LookupName "contoso_attendeeid" `
            -LookupDisplayName "Attendee" -ReferencedEntities @("contact","hso_customer_employee") `
            -SolutionName "ContosoCustomPh2"
    #>
    param(
        [string]$ChildTable,
        [string]$LookupName,
        [string]$LookupDisplayName,
        [string]$LookupDescription,    # HSO standard — required.
        [string[]]$ReferencedEntities,
        [string]$SolutionName
    )

    Write-Host "`n=== Creating Polymorphic Lookup ===" -ForegroundColor Cyan
    Write-Host "  Table: $ChildTable" -ForegroundColor Gray
    Write-Host "  Lookup: $LookupName -> $($ReferencedEntities -join ' | ')" -ForegroundColor Gray
    Write-DescriptionWarning -ComponentKind "lookup" -ComponentName $LookupName -Description $LookupDescription

    if ($ReferencedEntities.Count -lt 2) {
        throw "ReferencedEntities must contain at least 2 entity logical names"
    }

    # Build relationships — NO @odata.type, NO ReferencingAttribute/ReferencedAttribute
    # Derive the relationship-name prefix from the child table (see New-OneToManyRelationship).
    $relPrefix = Get-NamePublisherPrefix -Name $ChildTable
    $relationships = @()
    foreach ($entity in $ReferencedEntities) {
        $entityLower = $entity.ToLower()
        $lookupSuffix = $LookupName.ToLower() -replace "^${relPrefix}_", '' -replace 'id$', ''
        $relSchema = "${relPrefix}_${entityLower}_$($ChildTable.ToLower())_${lookupSuffix}"
        $relationships += @{
            SchemaName       = $relSchema
            ReferencedEntity = $entityLower
            ReferencingEntity = $ChildTable.ToLower()
            CascadeConfiguration = @{
                Delete   = "RemoveLink"
                Merge    = "NoCascade"
                Reparent = "NoCascade"
                Share    = "NoCascade"
                Unshare  = "NoCascade"
                Assign   = "NoCascade"
            }
        }
        Write-Host "  Relationship: $relSchema" -ForegroundColor Gray
    }

    $polymorphicLookup = @{
        SchemaName   = $LookupName
        LogicalName  = $LookupName.ToLower()
        DisplayName  = (New-LabelStructure -Label $LookupDisplayName)
        RequiredLevel = @{
            Value                        = "None"
            CanBeChanged                 = $true
            ManagedPropertyLogicalName   = "canmodifyrequirementlevelsettings"
        }
    }
    if ($LookupDescription) {
        $polymorphicLookup["Description"] = (New-LabelStructure -Label $LookupDescription)
    }

    $payload = @{
        OneToManyRelationships = $relationships
        Lookup = $polymorphicLookup
        SolutionUniqueName = $SolutionName
    }

    Add-RelationshipParentsToSolution -ParentTables $ReferencedEntities -SolutionName $SolutionName

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "CreatePolymorphicLookupAttribute" `
        -Body $payload -SolutionName $SolutionName

    Write-Host "  Polymorphic lookup created!" -ForegroundColor Green
    if ($result.AttributeId)     { Write-Host "  AttributeId: $($result.AttributeId)" -ForegroundColor Gray }
    if ($result.RelationshipIds) { Write-Host "  RelationshipIds: $($result.RelationshipIds -join ', ')" -ForegroundColor Gray }

    # Description read-back (mirrors New-CustomerRelationship). Polymorphic lookups ship via the same
    # generated-attribute path and can land without a description; confirm it persisted, remind if blank.
    try {
        $lookupLower = $LookupName.ToLower()
        $childLower = $ChildTable.ToLower()
        $persisted = Invoke-DataverseWebApi -Method "GET" `
            -Endpoint "EntityDefinitions(LogicalName='$childLower')/Attributes(LogicalName='$lookupLower')?`$select=Description"
        $persistedDesc = if ($persisted.Description -and $persisted.Description.UserLocalizedLabel) { $persisted.Description.UserLocalizedLabel.Label } else { '' }
        if ([string]::IsNullOrWhiteSpace($persistedDesc)) {
            Write-Host ""
            Write-Host "  [DESC] Could not confirm a description on the polymorphic lookup '$LookupName' (read back blank)." -ForegroundColor Yellow
            Write-Host "         The descriptions-mandatory standard requires one. If it is genuinely missing" -ForegroundColor Yellow
            Write-Host "         (not just metadata-cache lag), set it explicitly with UpdateColumn:" -ForegroundColor Yellow
            $descToUse = if ($LookupDescription) { $LookupDescription } else { '<describe this lookup>' }
            Write-Host "           -Operation UpdateColumn -TableName $childLower ``" -ForegroundColor Cyan
            Write-Host "             -ColumnName $lookupLower -ColumnDescription '$descToUse'" -ForegroundColor Cyan
            Write-Host ""
            $script:WarnCount++
        } else {
            Write-Host "  [DESC] Polymorphic lookup description confirmed persisted." -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "  [INFO] Could not read back the polymorphic lookup description to verify it (continuing): $($_.Exception.Message)" -ForegroundColor DarkGray
    }
    return $result
}

function Get-TableRelationships {
    <#
    .SYNOPSIS
        Queries all relationships for a table.
    .DESCRIPTION
        Returns 1:N relationships (where table is parent), N:1 relationships
        (where table is child/has lookup), and N:N relationships.
        Output is formatted for easy use when configuring subgrids.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TableName
    )

    Write-Host "`n=== Querying Relationships for $TableName ===" -ForegroundColor Cyan

    $tableLower = $TableName.ToLower()

    # Query 1:N relationships (this table is the parent/referenced entity)
    Write-Host "`n[1:N Relationships] (Table is PARENT - use for subgrids showing child records)" -ForegroundColor Yellow
    try {
        $oneToManyResult = Invoke-DataverseWebApi -Method "GET" `
            -Endpoint "EntityDefinitions(LogicalName='$tableLower')/OneToManyRelationships?`$select=SchemaName,ReferencingEntity,ReferencingAttribute,ReferencingEntityNavigationPropertyName"

        if ($oneToManyResult.value -and $oneToManyResult.value.Count -gt 0) {
            Write-Host "  Found $($oneToManyResult.value.Count) relationship(s):" -ForegroundColor Gray
            foreach ($rel in $oneToManyResult.value) {
                Write-Host ""
                Write-Host "    Relationship: $($rel.SchemaName)" -ForegroundColor White
                Write-Host "    Child Table:  $($rel.ReferencingEntity)" -ForegroundColor Gray
                Write-Host "    Lookup Field: $($rel.ReferencingAttribute)" -ForegroundColor Gray
                Write-Host "    Bind Nav-Prop:$($rel.ReferencingEntityNavigationPropertyName)  (set this on the CHILD to bind it to a parent of this table: `"$($rel.ReferencingEntityNavigationPropertyName)@odata.bind`": `"/<this-table-entityset>(<id>)`")" -ForegroundColor Green
                Write-Host "    -> For subgrid: RelationshipName = '$($rel.SchemaName)'" -ForegroundColor Green
            }
        }
        else {
            Write-Host "  No 1:N relationships found" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  Error querying 1:N relationships: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Query N:1 relationships (this table has lookups to other tables)
    Write-Host "`n[N:1 Relationships] (Table has LOOKUP to parent)" -ForegroundColor Yellow
    try {
        $manyToOneResult = Invoke-DataverseWebApi -Method "GET" `
            -Endpoint "EntityDefinitions(LogicalName='$tableLower')/ManyToOneRelationships?`$select=SchemaName,ReferencedEntity,ReferencingAttribute,ReferencingEntityNavigationPropertyName"

        if ($manyToOneResult.value -and $manyToOneResult.value.Count -gt 0) {
            Write-Host "  Found $($manyToOneResult.value.Count) relationship(s):" -ForegroundColor Gray
            # A polymorphic / Customer lookup surfaces here as ONE N:1 relationship PER target (e.g. an
            # account leg and a contact leg), each with its own target-specific bind nav-property
            # (hsot_customerid_account / hsot_customerid_contact). The bind nav-prop -- NOT the lookup
            # field -- is what you set with @odata.bind when creating/updating a record on THIS table.
            foreach ($rel in $manyToOneResult.value) {
                Write-Host ""
                Write-Host "    Relationship:  $($rel.SchemaName)" -ForegroundColor White
                Write-Host "    Parent Table:  $($rel.ReferencedEntity)" -ForegroundColor Gray
                Write-Host "    Lookup Field:  $($rel.ReferencingAttribute)" -ForegroundColor Gray
                Write-Host "    Bind Nav-Prop: $($rel.ReferencingEntityNavigationPropertyName)" -ForegroundColor Green
                Write-Host "       -> bind on create/update:  `"$($rel.ReferencingEntityNavigationPropertyName)@odata.bind`": `"/<$($rel.ReferencedEntity)-entityset>(<id>)`"" -ForegroundColor Green
            }
        }
        else {
            Write-Host "  No N:1 relationships found" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  Error querying N:1 relationships: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Query N:N relationships
    Write-Host "`n[N:N Relationships] (Many-to-Many)" -ForegroundColor Yellow
    try {
        $manyToManyResult = Invoke-DataverseWebApi -Method "GET" `
            -Endpoint "EntityDefinitions(LogicalName='$tableLower')/ManyToManyRelationships?`$select=SchemaName,Entity1LogicalName,Entity2LogicalName,IntersectEntityName"

        if ($manyToManyResult.value -and $manyToManyResult.value.Count -gt 0) {
            Write-Host "  Found $($manyToManyResult.value.Count) relationship(s):" -ForegroundColor Gray
            foreach ($rel in $manyToManyResult.value) {
                $otherEntity = if ($rel.Entity1LogicalName -eq $tableLower) { $rel.Entity2LogicalName } else { $rel.Entity1LogicalName }
                Write-Host ""
                Write-Host "    Relationship:    $($rel.SchemaName)" -ForegroundColor White
                Write-Host "    Related Table:   $otherEntity" -ForegroundColor Gray
                Write-Host "    Intersect Table: $($rel.IntersectEntityName)" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "  No N:N relationships found" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  Error querying N:N relationships: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
}

#endregion

#region Relationship Field-Mapping Operations

function Get-AttributeMappingMeta {
    # AttributeType (+ lookup Targets) for one column, or $null if the column doesn't exist.
    param([string]$TableName, [string]$ColumnName)
    $t = $TableName.ToLower(); $c = $ColumnName.ToLower()
    try {
        $a = Invoke-DataverseWebApi -Method "GET" `
            -Endpoint "EntityDefinitions(LogicalName='$t')/Attributes(LogicalName='$c')?`$select=LogicalName,AttributeType"
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) { return $null }
        throw $_
    }
    if (-not $a -or -not $a.AttributeType) { return $null }
    $targets = @()
    if ($a.AttributeType -in @("Lookup", "Customer", "Owner")) {
        try {
            $lm = Invoke-DataverseWebApi -Method "GET" `
                -Endpoint "EntityDefinitions(LogicalName='$t')/Attributes(LogicalName='$c')/Microsoft.Dynamics.CRM.LookupAttributeMetadata?`$select=Targets"
            if ($lm.Targets) { $targets = @($lm.Targets) }
        } catch { }
    }
    return [pscustomobject]@{ Type = "$($a.AttributeType)"; Targets = $targets }
}

function Test-AttributeMapCompatible {
    # Same AttributeType, with Lookup/Customer/Owner compatible when their target sets overlap.
    param($Source, $Target)
    if ($Source.Type -ne $Target.Type) { return $false }
    if ($Source.Type -in @("Lookup", "Customer", "Owner")) {
        if (-not $Source.Targets -or -not $Target.Targets) { return $true }  # can't compare -> allow
        $common = $Source.Targets | Where-Object { $Target.Targets -contains $_ }
        return @($common).Count -gt 0
    }
    return $true
}

function Get-OrNew-EntityMap {
    # entitymapid for (source=parent, target=child); create the entitymap if absent.
    param([string]$SourceEntity, [string]$TargetEntity, [string]$SolutionName)
    $s = $SourceEntity.ToLower(); $t = $TargetEntity.ToLower()
    $existing = Invoke-DataverseWebApi -Method "GET" `
        -Endpoint "entitymaps?`$filter=sourceentityname eq '$s' and targetentityname eq '$t'&`$select=entitymapid" `
        -IsMetadataOperation $false
    if ($existing.value -and @($existing.value).Count -gt 0) {
        $id = $existing.value[0].entitymapid
        Write-Host "  [READBACK] entitymap exists for $s -> $t ($id)" -ForegroundColor Gray
        return $id
    }
    Write-Host "  Creating entitymap $s -> $t" -ForegroundColor Gray
    $res = Invoke-DataverseWebApi -Method "POST" -Endpoint "entitymaps" `
        -Body @{ sourceentityname = $s; targetentityname = $t } `
        -SolutionName $SolutionName -IsMetadataOperation $false
    $id = $res._entityId
    if (-not $id) {
        $existing = Invoke-DataverseWebApi -Method "GET" `
            -Endpoint "entitymaps?`$filter=sourceentityname eq '$s' and targetentityname eq '$t'&`$select=entitymapid" `
            -IsMetadataOperation $false
        $id = $existing.value[0].entitymapid
    }
    return $id
}

function Get-RelationshipParentChild {
    # Resolve (parent=ReferencedEntity, child=ReferencingEntity) from a 1:N relationship schema name.
    param([string]$RelationshipSchemaName)
    $r = Invoke-DataverseWebApi -Method "GET" `
        -Endpoint "RelationshipDefinitions(SchemaName='$RelationshipSchemaName')/Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata?`$select=ReferencedEntity,ReferencingEntity"
    if (-not $r -or -not $r.ReferencedEntity) {
        throw "Could not resolve a 1:N relationship named '$RelationshipSchemaName'."
    }
    return [pscustomobject]@{ Parent = $r.ReferencedEntity; Child = $r.ReferencingEntity }
}

function Add-RelationshipMapping {
    # Map ADDITIONAL parent fields onto a child created from the parent's subgrid (+New). Idempotent,
    # type-checked, fail-soft per pair. The parent lookup is auto-set by the platform — never mapped.
    param(
        [Parameter(Mandatory = $true)] [string]$ParentTable,
        [Parameter(Mandatory = $true)] [string]$ChildTable,
        [Parameter(Mandatory = $true)] [array]$Mappings,
        [string]$SolutionName
    )
    $parent = $ParentTable.ToLower(); $child = $ChildTable.ToLower()
    Write-Host "`n=== Field mappings: $parent -> $child ($($Mappings.Count) requested) ===" -ForegroundColor Cyan

    $entityMapId = Get-OrNew-EntityMap -SourceEntity $parent -TargetEntity $child -SolutionName $SolutionName

    # Existing attributemaps on this entitymap (for idempotency + read-back).
    $existingPairs = @{}
    try {
        $am = Invoke-DataverseWebApi -Method "GET" `
            -Endpoint "attributemaps?`$filter=_entitymapid_value eq $entityMapId&`$select=sourceattributename,targetattributename" `
            -IsMetadataOperation $false
        foreach ($m in @($am.value)) { $existingPairs["$($m.sourceattributename)->$($m.targetattributename)"] = $true }
    } catch { }

    $requested = @()
    foreach ($pair in $Mappings) {
        $src = "$($pair.Source)".ToLower(); $tgt = "$($pair.Target)".ToLower()
        if (-not $src -or -not $tgt) {
            Write-Host "  [WARN] Skipping malformed mapping (need both Source and Target): $($pair | ConvertTo-Json -Compress)" -ForegroundColor Yellow
            $script:WarnCount++
            continue
        }
        $key = "$src->$tgt"; $requested += $key

        if ($existingPairs.ContainsKey($key)) {
            Write-Host "  [SKIP] mapping already present: $key" -ForegroundColor DarkGray
            continue
        }

        $srcMeta = Get-AttributeMappingMeta -TableName $parent -ColumnName $src
        $tgtMeta = Get-AttributeMappingMeta -TableName $child  -ColumnName $tgt
        if (-not $srcMeta) {
            Write-Host "  [WARN] parent column '$src' does not exist on '$parent' — skipping $key." -ForegroundColor Yellow
            $script:WarnCount++; continue
        }
        if (-not $tgtMeta) {
            Write-Host "  [WARN] child column '$tgt' does not exist on '$child' — skipping $key." -ForegroundColor Yellow
            $script:WarnCount++; continue
        }
        if (-not (Test-AttributeMapCompatible -Source $srcMeta -Target $tgtMeta)) {
            Write-Host "  [WARN] type mismatch for $key (parent $($srcMeta.Type) vs child $($tgtMeta.Type)) — skipping." -ForegroundColor Yellow
            $script:WarnCount++; continue
        }

        Write-Host "  Creating attributemap $key" -ForegroundColor Gray
        $null = Invoke-DataverseWebApi -Method "POST" -Endpoint "attributemaps" `
            -Body @{
                "entitymapid@odata.bind" = "/entitymaps($entityMapId)"
                sourceattributename      = $src
                targetattributename      = $tgt
            } -SolutionName $SolutionName -IsMetadataOperation $false
        $existingPairs[$key] = $true
    }

    # Read back the entitymap's attributemaps and report present-vs-requested.
    $present = @{}
    try {
        $am = Invoke-DataverseWebApi -Method "GET" `
            -Endpoint "attributemaps?`$filter=_entitymapid_value eq $entityMapId&`$select=sourceattributename,targetattributename" `
            -IsMetadataOperation $false
        foreach ($m in @($am.value)) { $present["$($m.sourceattributename)->$($m.targetattributename)"] = $true }
    } catch { }

    $have = @($requested | Where-Object { $present.ContainsKey($_) })
    Write-Host "  [READBACK] mappings: $($have.Count)/$($requested.Count) present [$($have -join ', ')]" -ForegroundColor Green
    $missing = @($requested | Where-Object { -not $present.ContainsKey($_) })
    if ($missing.Count -gt 0) {
        Write-Host "  [WARN] missing mappings: $($missing -join ', ')" -ForegroundColor Yellow
        $script:WarnCount++
    }
}

function Invoke-SpecRelationshipMappings {
    # Apply mappings for every relationships[] entry that declares mappings[] in a spec.json.
    param([string]$SpecJsonPath, [string]$SolutionName)
    if (-not (Test-Path $SpecJsonPath)) { throw "SpecJsonPath not found: $SpecJsonPath" }
    $spec = Get-Content -Raw -Path $SpecJsonPath | ConvertFrom-Json
    $rels = @($spec.relationships | Where-Object { $_.mappings -and @($_.mappings).Count -gt 0 })
    if ($rels.Count -eq 0) {
        Write-Host "  [INFO] -SpecJsonPath '$SpecJsonPath' declares no relationships[].mappings — nothing to do." -ForegroundColor DarkGray
        return
    }
    foreach ($rel in $rels) {
        $pairs = @($rel.mappings | ForEach-Object { [pscustomobject]@{ Source = $_.source; Target = $_.target } })
        Add-RelationshipMapping -ParentTable $rel.parent -ChildTable $rel.child -Mappings $pairs -SolutionName $SolutionName
    }
}

#endregion

#region Global Choice Operations

function Resolve-OptionColor {
    # Normalize an option color to #RRGGBB, or $null when absent/blank. Tolerates a missing '#'.
    param([string]$Color)
    if ([string]::IsNullOrWhiteSpace($Color)) { return $null }
    $c = $Color.Trim()
    if ($c -notmatch '^#') { $c = "#$c" }
    if ($c -notmatch '^#[0-9a-fA-F]{6}$') {
        Write-Host "  [WARN] Ignoring malformed option color '$Color' (expected #RRGGBB)." -ForegroundColor Yellow
        $script:WarnCount++
        return $null
    }
    return $c
}

# Read-back retry budget for the global-choice contract assertion.
#
# WHY A RETRY AT ALL: published is the default layer for ALL metadata reads, and it is served from
# an in-memory metadata cache ("the application's in-memory metadata cache returns published
# metadata by default" — Microsoft, "Retrieve published metadata"). So a read issued immediately
# after InsertOptionValue/UpdateOptionValue can still be serving the pre-write definition. That is
# CACHE INVALIDATION, not publish state — a publish-state problem would never converge on a retry,
# and this one does (observed 2026-08-21 on hso_fixedpricemethod_gc: FATAL reported, option live,
# second read clean).
#
# WHY THIS WIDE: the two failure modes are wildly asymmetric. A false FATAL costs a whole
# orchestrated build plus someone deciding whether the choice was really broken; a genuine FATAL
# costs 30s more before a build that was going to stop anyway stops. So size the budget for the
# worst plausible cache window, not the median. Narrow it later only on evidence from the
# [READBACK] telemetry below.
$script:ChoiceReadBackAttempts = 5
$script:ChoiceReadBackBackoff  = @(2, 4, 8, 16)  # seconds before attempts 2..5; 30s total ceiling

function Get-ChoiceContractBreach {
    # FATAL-grade breaches only: value missing, or label mismatch.
    #
    # SINGLE SOURCE OF TRUTH. The retry predicate and the FATAL block must ask the same question.
    # They did not: the loop tested presence only while the FATAL block tested presence AND label,
    # so a label rename (UpdateOptionValue) whose read came back stale returned the value PRESENT
    # carrying its OLD label — the loop broke on attempt 1 without spending any budget, and the
    # script exited 1 on a rename that had actually succeeded.
    #
    # Colour is deliberately NOT here: it is advisory, warned on separately, and must never gate
    # the retry or a deliberate colour change would burn the whole budget before WARNing.
    param([array]$Declared, [hashtable]$Actual)
    $breaches = @()
    foreach ($d in $Declared) {
        if (-not $Actual.ContainsKey($d.Value)) {
            $breaches += "value $($d.Value) ('$($d.Label)') not present"
            continue
        }
        if ($Actual[$d.Value].Label -ne $d.Label) {
            $breaches += "value $($d.Value) label '$($Actual[$d.Value].Label)' != declared '$($d.Label)'"
        }
    }
    # Plain return, NOT `return ,$breaches`. The unary comma wraps the result in an outer array, so
    # the caller's @(...) then sees ONE element (the inner array) regardless of the real breach
    # count — silently collapsing 2 breaches to 1 and, worse, turning 0 breaches into 1. Callers
    # MUST wrap this in @(...), which is what makes an empty result addressable as .Count -eq 0.
    return $breaches
}

function Assert-GlobalChoiceContract {
    # Read the persisted global choice back and assert declared-vs-actual (label + value + color).
    # [FATAL] (exit 1) on a missing/mismatched value; [WARN] on color drift (color is advisory).
    param([string]$ChoiceName, [array]$Declared)
    if (-not $Declared -or @($Declared).Count -eq 0) { return }
    Write-Host "  Verifying choice contract (label/value/color)..." -ForegroundColor Gray

    $actual   = @{}
    $readOk   = $false
    $readErr  = $null
    $breaches = @()

    for ($attempt = 1; $attempt -le $script:ChoiceReadBackAttempts; $attempt++) {
        $actual = @{}
        $readOk = $false
        try {
            $set = Invoke-DataverseWebApi -Method "GET" -Endpoint "GlobalOptionSetDefinitions(Name='$ChoiceName')"
            foreach ($o in $set.Options) {
                $actual[[int]$o.Value] = [pscustomobject]@{
                    Label = $o.Label.UserLocalizedLabel.Label
                    Color = $o.Color
                }
            }
            $readOk  = $true
            $readErr = $null
        }
        catch {
            # Record and fall through to the backoff — do NOT return. A transient 429/503 is exactly
            # what a retry loop is for, and returning here both skipped the assertion on the first
            # throttle and made the post-loop WARN unreachable.
            $readErr = $_.Exception.Message
        }

        if ($readOk) {
            $breaches = @(Get-ChoiceContractBreach -Declared $Declared -Actual $actual)
            if ($breaches.Count -eq 0) { break }
        }

        if ($attempt -lt $script:ChoiceReadBackAttempts) {
            $wait = $script:ChoiceReadBackBackoff[$attempt - 1]
            $why  = if ($readOk) { "$($breaches.Count) declared value(s)/label(s) not settled yet" } else { "read failed ($readErr)" }
            Write-Host "  [READBACK] $why — metadata cache lag; retrying in ${wait}s (attempt $attempt of $($script:ChoiceReadBackAttempts))." -ForegroundColor DarkGray
            Start-Sleep -Seconds $wait
        }
    }

    if (-not $readOk) {
        Write-Host "  [WARN] Could not read the choice back to verify the contract ($readErr); skipping assertion." -ForegroundColor Yellow
        $script:WarnCount++
        return
    }

    # Colour drift is advisory — evaluated ONCE on the settled read, never inside the retry loop.
    foreach ($d in $Declared) {
        if (-not $actual.ContainsKey($d.Value)) { continue }
        $a = $actual[$d.Value]
        if ($d.Color -and $a.Color -and ($a.Color.ToLower() -ne $d.Color.ToLower())) {
            Write-Host "  [WARN] value $($d.Value) color '$($a.Color)' != declared '$($d.Color)'." -ForegroundColor Yellow
            $script:WarnCount++
        } elseif ($d.Color -and -not $a.Color) {
            Write-Host "  [WARN] value $($d.Value) declared color '$($d.Color)' did not persist." -ForegroundColor Yellow
            $script:WarnCount++
        }
    }

    if ($breaches.Count -gt 0) {
        Write-Host ""
        Write-Host "  [FATAL] Global choice '$ChoiceName' does not match the declared contract — refusing to continue." -ForegroundColor Red
        $breaches | ForEach-Object { Write-Host "          - $_" -ForegroundColor Red }
        Write-Host ""
        exit 1
    }
    Write-Host "  [READBACK] Choice contract verified ($($Declared.Count) option(s)) after $attempt attempt(s)." -ForegroundColor DarkGray
}

function Publish-GlobalChoice {
    # Microsoft's reference sample follows InsertOptionValue / UpdateOptionValue / OrderOption on a
    # GLOBAL choice with a scoped PublishXml. This is NOT the fix for the read-back FATAL — that is
    # the retry in Assert-GlobalChoiceContract, because the lag there is metadata-cache
    # invalidation. This is here because published is the default layer for ALL metadata reads, so
    # skipping it leaves the choice half-landed for the maker portal, for dependent forms and
    # views, and for anything else that reads it. A publish is also itself a cache-invalidation
    # event, so it should shrink the window the retry budget covers — a side effect, not the reason.
    #
    # NOTE: [void] is REQUIRED — an uncaptured PublishXml response leaks into the caller's pipeline
    # and pollutes its return value (the same trap already commented at the other publish sites).
    param([string]$ChoiceName)
    $pubXml = "<importexportxml><optionsets><optionset>$ChoiceName</optionset></optionsets></importexportxml>"
    try {
        [void](Invoke-DataverseWebApi -Method "POST" -Endpoint "PublishXml" `
            -Body @{ ParameterXml = $pubXml } -IsMetadataOperation $false)
        Write-Host "  [OK] Global choice published (scoped PublishXml)" -ForegroundColor Green
    }
    catch {
        # Never fatal: the read-back retry is what governs correctness of the assertion, and it
        # works with or without this call.
        Write-Host "  [WARN] Scoped publish of '$ChoiceName' failed ($($_.Exception.Message)); continuing." -ForegroundColor Yellow
        $script:WarnCount++
    }
}

function Get-DefaultChoiceDescription {
    # Mandatory-description fallback (mirrors ui-config Get-DefaultViewDescription): never leave a
    # global choice blank. Prefer the display name, fall back to the logical name.
    param([string]$DisplayName, [string]$ChoiceName, [array]$Options)
    $n = if ($DisplayName) { $DisplayName } elseif ($ChoiceName) { $ChoiceName } else { 'Choice' }
    $labels = @($Options | ForEach-Object { $_.Label } | Where-Object { $_ })
    if ($labels.Count -gt 0) {
        "$n — global choice ($($labels.Count) options): $($labels -join ', ')."
    } else {
        "$n global choice."
    }
}

function New-GlobalChoice {
    param(
        [string]$ChoiceName,
        [string]$ChoiceDisplayName,
        [string]$ChoiceDescription,
        [array]$Options,
        [string]$SolutionName
    )

    Write-Host "`n=== Creating Global Choice: $ChoiceName ===" -ForegroundColor Cyan

    # Idempotent create (ADR 0025): if the choice already exists, reconcile its options in place rather
    # than POSTing a second definition (which errors) or letting a retry append duplicates. This makes a
    # re-run of CreateGlobalChoice a no-op when the contract is already satisfied.
    if (Get-GlobalOptionSetId -OptionSetName $ChoiceName) {
        Write-Host "  [EXISTS] Global choice '$ChoiceName' already exists -- reconciling options (idempotent create), not creating a duplicate." -ForegroundColor Yellow
        Update-GlobalChoice -ChoiceName $ChoiceName -Options $Options -SolutionName $SolutionName
        return
    }

    if (-not $ChoiceDescription) {
        $ChoiceDescription = Get-DefaultChoiceDescription -DisplayName $ChoiceDisplayName -ChoiceName $ChoiceName -Options $Options
    }
    Write-DescriptionWarning -ComponentKind "global choice" -ComponentName $ChoiceName -Description $ChoiceDescription

    # Extract publisher prefix from choice name (e.g., "hso" from "hso_testskillpriority")
    $publisherPrefix = $script:PublisherPrefix
    if ($ChoiceName -match "^([a-z]+)_") {
        $publisherPrefix = $matches[1]
    }

    # Get the publisher's option value prefix
    Write-Host "  Looking up publisher option value prefix for '$publisherPrefix'..." -ForegroundColor Gray
    $optionValuePrefix = Get-PublisherOptionValuePrefix -PublisherPrefix $publisherPrefix

    if (-not $optionValuePrefix) {
        Write-Host "  Warning: Could not determine publisher option value prefix. Using provided values." -ForegroundColor Yellow
    }

    $optionItems = @()
    $declared = @()
    $sequenceNumber = 0

    foreach ($opt in $Options) {
        # Any positive value is explicit and is honored verbatim (a spec value below the publisher's
        # prefix range is still the declared contract — never overwrite it with an auto-gen value).
        $explicit = ($null -ne $opt.Value) -and ([int]$opt.Value -gt 0)
        $optionValue = $opt.Value

        # Auto-generate only when no explicit value was supplied (back-compat default).
        if ($optionValuePrefix -and -not $explicit) {
            $optionValue = Get-NextOptionValue -PublisherOptionPrefix $optionValuePrefix -SequenceNumber $sequenceNumber
            Write-Host "  Auto-generated value for '$($opt.Label)': $optionValue" -ForegroundColor Gray
        }

        $optionItem = @{
            "Value" = $optionValue
            "Label" = (New-LabelStructure -Label $opt.Label)
        }
        $color = Resolve-OptionColor -Color $opt.Color
        if ($color) { $optionItem["Color"] = $color }   # per-option #RRGGBB (omit = platform default)

        $optionItems += $optionItem
        $declared += [pscustomobject]@{ Label = $opt.Label; Value = [int]$optionValue; Color = $color }
        $sequenceNumber++
    }

    $choiceDefinition = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.OptionSetMetadata"
        "Name" = $ChoiceName
        "OptionSetType" = "Picklist"
        "DisplayName" = (New-LabelStructure -Label $ChoiceDisplayName)
        "Options" = $optionItems
    }

    if ($ChoiceDescription) {
        $choiceDefinition["Description"] = (New-LabelStructure -Label $ChoiceDescription)
    }

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "GlobalOptionSetDefinitions" `
        -Body $choiceDefinition -SolutionName $SolutionName

    Write-Host "  Global choice created successfully!" -ForegroundColor Green
    Publish-GlobalChoice -ChoiceName $ChoiceName
    Assert-GlobalChoiceContract -ChoiceName $ChoiceName -Declared $declared
    return $result
}

function Update-GlobalChoice {
    <#
    .SYNOPSIS
        Updates a global choice by adding new options or updating labels on existing options.
    .DESCRIPTION
        For each option provided:
        - If the value already exists in the choice: Updates the label using UpdateOptionValue
        - If the value doesn't exist: Adds it using InsertOptionValue
        - If no value is provided: Auto-generates a value and adds the option
    #>
    param(
        [string]$ChoiceName,
        [array]$Options,
        [string]$SolutionName
    )

    Write-Host "`n=== Updating Global Choice: $ChoiceName ===" -ForegroundColor Cyan

    # Extract publisher prefix from choice name
    $publisherPrefix = $script:PublisherPrefix
    if ($ChoiceName -match "^([a-z]+)_") {
        $publisherPrefix = $matches[1]
    }

    # Query existing options to build lookups of existing values AND labels. The label lookup is the
    # idempotency key (ADR 0025): a declared option whose LABEL already exists must NOT be re-added,
    # even though a re-run with no explicit value would auto-generate a NEW value that misses the
    # value lookup. Matching only by value was the root cause of duplicate-option corruption.
    $existingValues = @{}
    $existingLabels = @{}   # normalized label -> existing value
    $existingChoice = $null
    try {
        $existingChoice = Invoke-DataverseWebApi -Method "GET" -Endpoint "GlobalOptionSetDefinitions(Name='$ChoiceName')"
        if ($existingChoice.Options) {
            Write-Host "  Current options in $ChoiceName`:" -ForegroundColor Yellow
            foreach ($existingOpt in $existingChoice.Options) {
                $existingLabel = $existingOpt.Label.UserLocalizedLabel.Label
                # [int] CAST IS LOAD-BEARING. ConvertFrom-Json types these as Int64, but the declared
                # value below is [int] (Int32), and a hashtable keyed by Int64 answers ContainsKey
                # ([int]100000000) with FALSE -- .NET equality requires the same type. Without the cast
                # every explicitly-valued option missed the lookup, took the ADD branch, and came back
                # 0x80044310 "another picklist or status option ... already exists with that value".
                # The UpdateOptionValue (label rename) branch was therefore UNREACHABLE, and the
                # failure was masked: the errors printed but the run still exited 0 because the labels
                # already matched. Assert-GlobalChoiceContract already casts for the same reason.
                $existingValues[[int]$existingOpt.Value] = $existingLabel
                if ($existingLabel) { $existingLabels[$existingLabel.Trim().ToLower()] = [int]$existingOpt.Value }
                Write-Host "    $($existingOpt.Value) = $existingLabel" -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-Host "  Warning: Could not query existing options - $_" -ForegroundColor Yellow
    }

    # Backfill a default Description when the existing set has none (mandatory-description standard).
    if ($existingChoice -and -not $existingChoice.Description.UserLocalizedLabel.Label) {
        $displayName = $existingChoice.DisplayName.UserLocalizedLabel.Label
        $defaultDesc = Get-DefaultChoiceDescription -DisplayName $displayName -ChoiceName $ChoiceName -Options $Options
        try {
            Invoke-DataverseWebApi -Method "PUT" -Endpoint "GlobalOptionSetDefinitions(Name='$ChoiceName')" -Body @{
                "@odata.type" = "Microsoft.Dynamics.CRM.OptionSetMetadata"
                "MetadataId"  = $existingChoice.MetadataId
                "Name"        = $ChoiceName
                "Description" = (New-LabelStructure -Label $defaultDesc)
            } -SolutionName $SolutionName
            Write-Host "  [OK] Backfilled default Description (was blank)" -ForegroundColor Green
        }
        catch {
            Write-Host "  Warning: Could not backfill Description - $_" -ForegroundColor Yellow
        }
    }

    # Get publisher's option value prefix for auto-generation (only needed for new options without explicit values)
    $optionValuePrefix = $null
    $needsAutoGenerate = $Options | Where-Object { -not $_.Value }
    if ($needsAutoGenerate) {
        Write-Host "  Looking up publisher option value prefix for '$publisherPrefix'..." -ForegroundColor Gray
        $optionValuePrefix = Get-PublisherOptionValuePrefix -PublisherPrefix $publisherPrefix
    }

    # Find the highest existing value to continue sequence for new options
    $startSequence = 0
    if ($optionValuePrefix -and $existingValues.Count -gt 0) {
        $maxValue = ($existingValues.Keys | Measure-Object -Maximum).Maximum
        if ($maxValue -ge ($optionValuePrefix * 10000)) {
            $startSequence = $maxValue - ($optionValuePrefix * 10000) + 1
        }
    }

    Write-Host ""
    $updatedCount = 0
    $addedCount = 0
    $declared = @()

    $skippedCount = 0
    foreach ($opt in $Options) {
        $optionValue = $opt.Value

        # LABEL-FIRST idempotency (ADR 0025): when the declared option carries no explicit value and a
        # same-label option already exists, the contract is already satisfied -- skip it. Without this,
        # the auto-generate-below assigns a fresh value past the existing max, which then misses the
        # value lookup and gets InsertOptionValue'd as a duplicate (the 8/16-option corruption).
        if (-not $opt.Value) {
            $labelKey = if ($opt.Label) { $opt.Label.Trim().ToLower() } else { $null }
            if ($labelKey -and $existingLabels.ContainsKey($labelKey)) {
                $existingVal = $existingLabels[$labelKey]
                Write-Host "  [SKIP] Label '$($opt.Label)' already present (value $existingVal) -- not re-adding" -ForegroundColor DarkGray
                $declared += [pscustomobject]@{ Label = $opt.Label; Value = [int]$existingVal; Color = (Resolve-OptionColor -Color $opt.Color) }
                $skippedCount++
                continue
            }
        }

        # Auto-generate value if not provided (for new options only)
        if (-not $optionValue -and $optionValuePrefix) {
            $optionValue = Get-NextOptionValue -PublisherOptionPrefix $optionValuePrefix -SequenceNumber $startSequence
            Write-Host "  Auto-generated value for '$($opt.Label)': $optionValue" -ForegroundColor Gray
            $startSequence++
        }

        $color = Resolve-OptionColor -Color $opt.Color
        $declared += [pscustomobject]@{ Label = $opt.Label; Value = [int]$optionValue; Color = $color }

        if ($existingValues.ContainsKey($optionValue)) {
            # Value exists - update the label (and color) using UpdateOptionValue
            $currentLabel = $existingValues[$optionValue]
            if (($currentLabel -eq $opt.Label) -and -not $color) {
                Write-Host "  [SKIP] Value $optionValue already has label '$($opt.Label)'" -ForegroundColor DarkGray
                continue
            }

            Write-Host "  [UPDATE] $optionValue`: '$currentLabel' -> '$($opt.Label)'" -ForegroundColor Cyan

            $updateOption = @{
                "OptionSetName" = $ChoiceName
                "Value" = $optionValue
                "Label" = (New-LabelStructure -Label $opt.Label)
                "MergeLabels" = $true
                "SolutionUniqueName" = $SolutionName
            }
            if ($color) { $updateOption["Color"] = $color }

            try {
                Invoke-DataverseWebApi -Method "POST" -Endpoint "UpdateOptionValue" -Body $updateOption
                Write-Host "    [OK] Label updated" -ForegroundColor Green
                $updatedCount++
            }
            catch {
                Write-Host "    [ERROR] Failed to update: $_" -ForegroundColor Red
            }
        }
        else {
            # Value doesn't exist - add it using InsertOptionValue
            Write-Host "  [ADD] $optionValue = '$($opt.Label)'" -ForegroundColor Yellow

            $insertOption = @{
                "OptionSetName" = $ChoiceName
                "Value" = $optionValue
                "Label" = (New-LabelStructure -Label $opt.Label)
                "SolutionUniqueName" = $SolutionName
            }
            if ($color) { $insertOption["Color"] = $color }

            try {
                Invoke-DataverseWebApi -Method "POST" -Endpoint "InsertOptionValue" -Body $insertOption
                Write-Host "    [OK] Option added" -ForegroundColor Green
                $addedCount++
            }
            catch {
                Write-Host "    [ERROR] Failed to add: $_" -ForegroundColor Red
            }
        }
    }

    Write-Host ""
    Write-Host "  Summary: $updatedCount updated, $addedCount added, $skippedCount already-present (no-op)" -ForegroundColor Green
    # Publish only when something actually changed — a fully idempotent re-run (all [SKIP]) must
    # not issue a publish, or every no-op run adds publish load and contention for nothing.
    if (($updatedCount + $addedCount) -gt 0) { Publish-GlobalChoice -ChoiceName $ChoiceName }
    Assert-GlobalChoiceContract -ChoiceName $ChoiceName -Declared $declared
}

function Invoke-SpecGlobalChoices {
    # Render EVERY declared choices[] entry from the spec in one pass: create if absent, else
    # update-in-place. Each path read-back-asserts the declared labels ([FATAL]/exit 1 on a miss),
    # so the executor never hand-passes option labels inline (the garbled-label failure mode).
    param([string]$SpecJsonPath, [string]$SolutionName)

    $choices = Get-SpecChoices -SpecJsonPath $SpecJsonPath
    if (-not $choices -or @($choices).Count -eq 0) {
        Write-Host "  [FATAL] -SpecJsonPath '$SpecJsonPath' declares no choices[] to render." -ForegroundColor Red
        exit 1
    }

    Write-Host "`n=== Rendering $(@($choices).Count) declared global choice(s) from spec ===" -ForegroundColor Cyan
    foreach ($c in $choices) {
        $labels = ($c.Options | ForEach-Object { $_.Label }) -join ', '
        Write-Host "  - $($c.Name): $(@($c.Options).Count) option(s) [$labels]" -ForegroundColor Gray
        if (Get-GlobalOptionSetId -OptionSetName $c.Name) {
            Update-GlobalChoice -ChoiceName $c.Name -Options $c.Options -SolutionName $SolutionName
        } else {
            New-GlobalChoice -ChoiceName $c.Name -ChoiceDisplayName $c.Name -ChoiceDescription $c.Description -Options $c.Options -SolutionName $SolutionName
        }
    }
}

function Remove-OptionValue {
    <#
    .SYNOPSIS
        Deletes one or more option values from a global choice using DeleteOptionValue.
    .DESCRIPTION
        For each value in OptionValues:
        - If the value exists in the choice: deletes it via DeleteOptionValue.
        - If the value does not exist: skips with a warning.
        Will fail server-side if a value is still in use by a record on a Picklist column;
        such failures are reported per-value and the loop continues with the next value.

        Common cleanup scenario: a build session called CreateGlobalChoice twice and the
        choice ended up with duplicate (label, different value) entries. After verifying
        no records reference the duplicates, use this op to remove them.
    #>
    param(
        [string]$ChoiceName,
        [int[]]$OptionValues,
        [string]$SolutionName
    )

    Write-Host "`n=== Deleting Option Values from Global Choice: $ChoiceName ===" -ForegroundColor Cyan

    if (-not $OptionValues -or $OptionValues.Count -eq 0) {
        Write-Host "  [ERROR] -OptionValues is required (one or more integer option values to delete)." -ForegroundColor Red
        return
    }

    # Query existing options to verify each target value is present before attempting delete.
    $existingValues = @{}
    try {
        $existingChoice = Invoke-DataverseWebApi -Method "GET" -Endpoint "GlobalOptionSetDefinitions(Name='$ChoiceName')"
        if ($existingChoice.Options) {
            foreach ($existingOpt in $existingChoice.Options) {
                $existingLabel = $existingOpt.Label.UserLocalizedLabel.Label
                $existingValues[[int]$existingOpt.Value] = $existingLabel
            }
            Write-Host "  Choice currently has $($existingValues.Count) option(s)." -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  [ERROR] Could not query existing options: $_" -ForegroundColor Red
        return
    }

    Write-Host ""
    $deletedCount = 0
    $skippedCount = 0
    $failedCount = 0

    foreach ($value in $OptionValues) {
        if (-not $existingValues.ContainsKey([int]$value)) {
            Write-Host "  [SKIP] Value $value not present in $ChoiceName" -ForegroundColor DarkGray
            $skippedCount++
            continue
        }

        $label = $existingValues[[int]$value]
        Write-Host "  [DELETE] $value = '$label'" -ForegroundColor Yellow

        $deleteOption = @{
            "OptionSetName" = $ChoiceName
            "Value" = [int]$value
            "SolutionUniqueName" = $SolutionName
        }

        try {
            Invoke-DataverseWebApi -Method "POST" -Endpoint "DeleteOptionValue" -Body $deleteOption
            Write-Host "    [OK] Option deleted" -ForegroundColor Green
            $deletedCount++
        }
        catch {
            Write-Host "    [ERROR] Failed to delete: $_" -ForegroundColor Red
            $failedCount++
        }
    }

    Write-Host ""
    Write-Host "  Summary: $deletedCount deleted, $skippedCount skipped (not present), $failedCount failed" -ForegroundColor Green
}

function Add-StatusValue {
    <#
    .SYNOPSIS
        Adds a new status value to an entity's statuscode field.
    .DESCRIPTION
        Uses InsertStatusValue to add a custom status reason to an entity.
        Each status must be linked to a state (Active=0 or Inactive=1).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        [Parameter(Mandatory = $true)]
        [string]$StatusLabel,
        [Parameter(Mandatory = $false)]
        [int]$StatusValue,
        [Parameter(Mandatory = $true)]
        [ValidateSet(0, 1)]
        [int]$StateCode,
        [Parameter(Mandatory = $true)]
        [string]$SolutionName
    )

    $stateLabel = if ($StateCode -eq 0) { "Active" } else { "Inactive" }
    Write-Host "`n=== Adding Status Value to $TableName ===" -ForegroundColor Cyan
    Write-Host "  Label: $StatusLabel" -ForegroundColor White
    Write-Host "  State: $stateLabel ($StateCode)" -ForegroundColor White

    # Extract publisher prefix from table name (canonical helper — handles digit-bearing prefixes like hso2_)
    $tablePrefix = Get-DataverseSchemaPrefix $TableName
    $publisherPrefix = if ($tablePrefix) { $tablePrefix } else { $script:PublisherPrefix }

    # Auto-generate value if not provided
    if (-not $StatusValue) {
        Write-Host "  Looking up publisher option value prefix for '$publisherPrefix'..." -ForegroundColor Gray
        $optionValuePrefix = Get-PublisherOptionValuePrefix -PublisherPrefix $publisherPrefix

        if ($optionValuePrefix) {
            # Query existing status values to find max
            $startSequence = 0
            try {
                $endpoint = "EntityDefinitions(LogicalName='$TableName')/Attributes(LogicalName='statuscode')/Microsoft.Dynamics.CRM.StatusAttributeMetadata?`$select=LogicalName&`$expand=OptionSet(`$select=Options)"
                $statusAttr = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint
                if ($statusAttr.OptionSet.Options) {
                    $maxValue = ($statusAttr.OptionSet.Options | Measure-Object -Property Value -Maximum).Maximum
                    if ($maxValue -ge ($optionValuePrefix * 10000)) {
                        $startSequence = $maxValue - ($optionValuePrefix * 10000) + 1
                    }
                }
            }
            catch {
                Write-Host "  Warning: Could not query existing status values" -ForegroundColor Yellow
            }

            $StatusValue = Get-NextOptionValue -PublisherOptionPrefix $optionValuePrefix -SequenceNumber $startSequence
            Write-Host "  Auto-generated value: $StatusValue" -ForegroundColor Gray
        }
        else {
            throw "Could not determine publisher option value prefix. Please provide StatusValue explicitly."
        }
    }

    # Build the InsertStatusValue request
    $insertStatus = @{
        "EntityLogicalName" = $TableName
        "AttributeLogicalName" = "statuscode"
        "Value" = $StatusValue
        "Label" = (New-LabelStructure -Label $StatusLabel)
        "StateCode" = $StateCode
        "SolutionUniqueName" = $SolutionName
    }

    Write-Host "  Adding status value: $StatusLabel ($StatusValue) -> State: $stateLabel" -ForegroundColor Gray

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "InsertStatusValue" -Body $insertStatus

    Write-Host "  Status value added successfully!" -ForegroundColor Green
    return $result
}

function Update-StatusLabel {
    <#
    .SYNOPSIS
        Updates the label of an existing status value.
    .DESCRIPTION
        Uses UpdateStateValue/UpdateOptionValue to rename a status reason.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        [Parameter(Mandatory = $true)]
        [int]$StatusValue,
        [Parameter(Mandatory = $true)]
        [string]$NewLabel,
        [Parameter(Mandatory = $true)]
        [string]$SolutionName
    )

    Write-Host "`n=== Updating Status Label on $TableName ===" -ForegroundColor Cyan
    Write-Host "  Value: $StatusValue" -ForegroundColor White
    Write-Host "  New Label: $NewLabel" -ForegroundColor White

    # Build the UpdateOptionValue request
    $updateOption = @{
        "EntityLogicalName" = $TableName
        "AttributeLogicalName" = "statuscode"
        "Value" = $StatusValue
        "Label" = (New-LabelStructure -Label $NewLabel)
        "MergeLabels" = $true
        "SolutionUniqueName" = $SolutionName
    }

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "UpdateOptionValue" -Body $updateOption

    # Same gap as Publish-GlobalChoice, entity-scoped. There is no read-back here, so this produced
    # no false FATAL — it just left the rename half-landed until something else published. [void]
    # for the same pipeline-pollution reason: $result is this function's return value.
    try {
        $pubXml = "<importexportxml><entities><entity>$TableName</entity></entities></importexportxml>"
        [void](Invoke-DataverseWebApi -Method "POST" -Endpoint "PublishXml" `
            -Body @{ ParameterXml = $pubXml } -IsMetadataOperation $false)
    }
    catch {
        Write-Host "  [WARN] Scoped publish of '$TableName' failed ($($_.Exception.Message)); the label change may not be visible until the next publish." -ForegroundColor Yellow
        $script:WarnCount++
    }

    Write-Host "  Status label updated successfully!" -ForegroundColor Green
    return $result
}

function Set-StatusDefault {
    <#
    .SYNOPSIS
        Sets the default-active statuscode for a state via the UpdateStateValue action.
    .DESCRIPTION
        Repoints a state's default status reason (DefaultStatusCode). A PATCH of the statecode
        StateAttributeMetadata is a silent no-op — only this action works. See
        references/statuscode-lifecycle-web-api.md §2.
    #>
    param(
        [Parameter(Mandatory = $true)] [string]$TableName,
        [Parameter(Mandatory = $true)] [ValidateSet(0, 1)] [int]$StateCode,
        [Parameter(Mandatory = $true)] [int]$DefaultStatusValue,
        [Parameter(Mandatory = $true)] [string]$SolutionName
    )

    $stateLabel = if ($StateCode -eq 0) { "Active" } else { "Inactive" }
    Write-Host "`n=== Setting Default Status for $TableName ($stateLabel) ===" -ForegroundColor Cyan
    Write-Host "  State: $stateLabel ($StateCode) -> default statuscode $DefaultStatusValue" -ForegroundColor White

    $body = @{
        EntityLogicalName    = $TableName
        AttributeLogicalName = "statecode"
        Value                = $StateCode
        DefaultStatusCode    = $DefaultStatusValue
        MergeLabels          = $true
    }
    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "UpdateStateValue" -Body $body -SolutionName $SolutionName
    Write-Host "  Default status set." -ForegroundColor Green
    return $result
}

function Set-Lifecycle {
    <#
    .SYNOPSIS
        Renders a table's FULL statuscode lifecycle as a read-back contract.
    .DESCRIPTION
        Inserts every declared status reason SERIALLY with EXPLICIT prefixed values (kills the
        auto-gen read-after-write collision), sets the default-active statuscode, then reads the
        full option set back and asserts declared-vs-actual (count + default). On mismatch:
        a LIFECYCLE INCOMPLETE banner + non-zero exit. Reasons come from -StatusReasons or a
        spec.json statusReasons[] entry for the table.
    #>
    param(
        [Parameter(Mandatory = $true)] [string]$TableName,
        [Parameter(Mandatory = $true)] [array]$StatusReasons,  # [{Label, State(0|1), Value?, Default?}]
        [Parameter(Mandatory = $true)] [string]$SolutionName
    )

    Write-Host "`n=== Setting statuscode Lifecycle on $TableName ===" -ForegroundColor Cyan
    Write-Host "  Declared reasons: $($StatusReasons.Count)" -ForegroundColor White

    # Resolve explicit values for every reason up front so inserts never rely on lagging auto-gen.
    $tablePrefix = Get-DataverseSchemaPrefix $TableName
    $publisherPrefix = if ($tablePrefix) { $tablePrefix } else { $script:PublisherPrefix }
    $optionValuePrefix = Get-PublisherOptionValuePrefix -PublisherPrefix $publisherPrefix
    if (-not $optionValuePrefix) {
        throw "Could not determine the publisher option value prefix for '$publisherPrefix'; pass explicit Value on every status reason."
    }

    # Read the current set so we skip values already present and continue the sequence past them.
    $existingValues = @{}
    $startSequence = 0
    try {
        $endpoint = "EntityDefinitions(LogicalName='$TableName')/Attributes(LogicalName='statuscode')/Microsoft.Dynamics.CRM.StatusAttributeMetadata?`$select=LogicalName&`$expand=OptionSet(`$select=Options)"
        $statusAttr = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint
        if ($statusAttr.OptionSet.Options) {
            foreach ($o in $statusAttr.OptionSet.Options) { $existingValues[[int]$o.Value] = $o.Label.UserLocalizedLabel.Label }
            $maxValue = ($existingValues.Keys | Measure-Object -Maximum).Maximum
            if ($maxValue -ge ($optionValuePrefix * 10000)) { $startSequence = $maxValue - ($optionValuePrefix * 10000) + 1 }
        }
    }
    catch { Write-Host "  Warning: Could not read existing status values: $($_.Exception.Message)" -ForegroundColor Yellow }

    # Resolve a concrete value + default flag for each declared reason.
    $declared = @()
    $defaultByState = @{}
    foreach ($r in $StatusReasons) {
        $state = [int]$r.State
        if (($null -ne $r.Value) -and ([int]$r.Value -gt 0)) {
            $val = [int]$r.Value
        } else {
            $val = Get-NextOptionValue -PublisherOptionPrefix $optionValuePrefix -SequenceNumber $startSequence
            $startSequence++
        }
        $isDefault = [bool]$r.Default
        if ($isDefault) { $defaultByState[$state] = $val }
        $declared += [pscustomobject]@{ Label = $r.Label; State = $state; Value = $val; Default = $isDefault }
    }

    # Insert each declared value SERIALLY with its explicit value. A value already present with the
    # SAME label is skipped; one present with a DIFFERENT label (e.g. shipped 1='Active'/2='Inactive'
    # colliding with declared Draft/Expired) is RELABELED — never left wrong.
    foreach ($d in $declared) {
        if ($existingValues.ContainsKey($d.Value)) {
            if ($existingValues[$d.Value] -eq $d.Label) {
                Write-Host "  [SKIP] $($d.Value) = '$($d.Label)' already present" -ForegroundColor DarkGray
            } else {
                Write-Host "  [RELABEL] $($d.Value) = '$($existingValues[$d.Value])' -> '$($d.Label)'" -ForegroundColor DarkGray
                Update-StatusLabel -TableName $TableName -StatusValue $d.Value -NewLabel $d.Label -SolutionName $SolutionName | Out-Null
            }
            continue
        }
        Add-StatusValue -TableName $TableName -StatusLabel $d.Label -StatusValue $d.Value -StateCode $d.State -SolutionName $SolutionName | Out-Null
    }

    # Set the default-active statuscode per state that declared one.
    foreach ($state in $defaultByState.Keys) {
        Set-StatusDefault -TableName $TableName -StateCode $state -DefaultStatusValue $defaultByState[$state] -SolutionName $SolutionName | Out-Null
    }

    # READ BACK and assert declared-vs-actual (count present + default landed).
    Write-Host "`n  Reading lifecycle back to verify..." -ForegroundColor Gray
    $actualValues = @{}
    $actualDefaultByState = @{}
    try {
        $endpoint = "EntityDefinitions(LogicalName='$TableName')/Attributes(LogicalName='statuscode')/Microsoft.Dynamics.CRM.StatusAttributeMetadata?`$expand=OptionSet"
        $attr = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint
        foreach ($o in $attr.OptionSet.Options) { $actualValues[[int]$o.Value] = $o.Label.UserLocalizedLabel.Label }
        # default-status per state lives on the statecode attribute's DefaultStatus
        $stateEp = "EntityDefinitions(LogicalName='$TableName')/Attributes(LogicalName='statecode')/Microsoft.Dynamics.CRM.StateAttributeMetadata?`$expand=OptionSet"
        $stateAttr = Invoke-DataverseWebApi -Method "GET" -Endpoint $stateEp
        foreach ($o in $stateAttr.OptionSet.Options) {
            if ($null -ne $o.DefaultStatus) { $actualDefaultByState[[int]$o.Value] = [int]$o.DefaultStatus }
        }
    }
    catch { Write-Host "  Warning: Read-back failed: $($_.Exception.Message)" -ForegroundColor Yellow }

    $problems = @()
    foreach ($d in $declared) {
        if (-not $actualValues.ContainsKey($d.Value)) { $problems += "value $($d.Value) ('$($d.Label)') not present after insert" }
        elseif ($actualValues[$d.Value] -ne $d.Label) { $problems += "value $($d.Value) label '$($actualValues[$d.Value])' != declared '$($d.Label)'" }
    }
    foreach ($state in $defaultByState.Keys) {
        $want = $defaultByState[$state]
        $got = if ($actualDefaultByState.ContainsKey($state)) { $actualDefaultByState[$state] } else { $null }
        if ($got -ne $want) { $problems += "state $state default = $(if ($null -ne $got) { $got } else { '<none>' }), expected $want" }
    }

    if ($problems.Count -gt 0) {
        Write-Host ""
        Write-Host "########################################################################" -ForegroundColor Red
        Write-Host "##  LIFECYCLE INCOMPLETE: declared statuscode set does NOT match the env  ##" -ForegroundColor Red
        Write-Host "########################################################################" -ForegroundColor Red
        Write-Host "  Declared $($declared.Count) reason(s); actual set has $($actualValues.Count). Mismatches:" -ForegroundColor Yellow
        $problems | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
        Write-Host ""
        exit 1
    }

    Write-Host "  [READBACK] Lifecycle verified: $($declared.Count) declared reason(s) present, default(s) set." -ForegroundColor Green
    return $declared
}

function Get-GlobalChoice {
    <#
    .SYNOPSIS
    Query an existing Global Choice (Option Set) and list its options.

    .DESCRIPTION
    Returns a structured object with Name, DisplayName, Description, and an Options
    array (each option includes Value and Label). Useful before calling
    UpdateGlobalChoice so you know which option values exist and can decide
    whether to add, rename, or skip.

    Returns $null if the choice does not exist (404 from the API).
    #>
    param([string]$ChoiceName)

    Write-Host "`n=== Querying Global Choice: $ChoiceName ===" -ForegroundColor Cyan

    $endpoint = "GlobalOptionSetDefinitions(Name='$ChoiceName')"

    try {
        $choice = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint
    }
    catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            Write-Host "  Global choice not found: $ChoiceName" -ForegroundColor Yellow
            return $null
        }
        throw $_
    }

    $displayName = if ($choice.DisplayName -and $choice.DisplayName.LocalizedLabels) {
        $choice.DisplayName.LocalizedLabels[0].Label
    } else { '' }

    $description = if ($choice.Description -and $choice.Description.LocalizedLabels -and $choice.Description.LocalizedLabels.Count -gt 0) {
        $choice.Description.LocalizedLabels[0].Label
    } else { '' }

    Write-Host "  Name:        $($choice.Name)" -ForegroundColor White
    Write-Host "  DisplayName: $displayName" -ForegroundColor White
    Write-Host "  Description: $description" -ForegroundColor Gray
    Write-Host "  IsCustom:    $($choice.IsCustomOptionSet)" -ForegroundColor Gray
    Write-Host "  IsManaged:   $($choice.IsManaged)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Options ($($choice.Options.Count)):" -ForegroundColor Yellow

    $optionList = @()
    foreach ($opt in ($choice.Options | Sort-Object Value)) {
        $label = if ($opt.Label -and $opt.Label.LocalizedLabels -and $opt.Label.LocalizedLabels.Count -gt 0) {
            $opt.Label.LocalizedLabels[0].Label
        } else { '' }
        Write-Host ("    {0,12}  {1}" -f $opt.Value, $label) -ForegroundColor Gray
        $optionList += [pscustomobject]@{
            Value = $opt.Value
            Label = $label
        }
    }

    return [pscustomobject]@{
        Name        = $choice.Name
        DisplayName = $displayName
        Description = $description
        IsCustom    = $choice.IsCustomOptionSet
        IsManaged   = $choice.IsManaged
        MetadataId  = $choice.MetadataId
        Options     = $optionList
    }
}

function Remove-GlobalChoice {
    param([string]$ChoiceName)

    Write-Host "`n=== Deleting Global Choice: $ChoiceName ===" -ForegroundColor Cyan

    # First verify the global choice exists
    $endpoint = "GlobalOptionSetDefinitions(Name='$ChoiceName')?`$select=Name,DisplayName"

    try {
        $choice = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint
        Write-Host "  Found global choice: $($choice.DisplayName.LocalizedLabels[0].Label)" -ForegroundColor White
    }
    catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            Write-Host "  Global choice not found: $ChoiceName - nothing to delete" -ForegroundColor Yellow
            return $true
        }
        throw $_
    }

    # Delete the global choice
    $deleteEndpoint = "GlobalOptionSetDefinitions(Name='$ChoiceName')"

    try {
        Invoke-DataverseWebApi -Method "DELETE" -Endpoint $deleteEndpoint | Out-Null
        Write-Host "  Global choice deleted successfully: $ChoiceName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  Failed to delete global choice: $($_.Exception.Message)" -ForegroundColor Red
        throw $_
    }
}

#endregion

#region Alternate Key Operations

function New-AlternateKey {
    <#
    .SYNOPSIS
        Creates an alternate key on a Dataverse table.
    .DESCRIPTION
        Creates an alternate key using the Web API. Alternate keys enable you to define
        columns that uniquely identify records and can be used for data integration.

        IMPORTANT: Index creation is asynchronous. The key may take time to become active.
    .PARAMETER TableName
        The logical name of the table (e.g., "hso_awardcode")
    .PARAMETER KeySchemaName
        The schema name for the key (e.g., "hso_code_key")
    .PARAMETER KeyDisplayName
        The display name for the key
    .PARAMETER KeyColumns
        Array of column logical names that make up the key
    .PARAMETER SolutionName
        The solution to add the key to
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        [Parameter(Mandatory = $true)]
        [string]$KeySchemaName,
        [Parameter(Mandatory = $true)]
        [string]$KeyDisplayName,
        [Parameter(Mandatory = $true)]
        [array]$KeyColumns,
        [string]$SolutionName
    )

    Write-Host "`n=== Creating Alternate Key: $KeySchemaName on $TableName ===" -ForegroundColor Cyan

    # Validate inputs
    if (-not $KeyColumns -or $KeyColumns.Count -eq 0) {
        throw "KeyColumns must contain at least one column name"
    }

    if ($KeyColumns.Count -gt 16) {
        throw "Maximum of 16 columns allowed per alternate key"
    }

    Write-Host "  Table: $TableName" -ForegroundColor Gray
    Write-Host "  Key Schema Name: $KeySchemaName" -ForegroundColor Gray
    Write-Host "  Key Display Name: $KeyDisplayName" -ForegroundColor Gray
    Write-Host "  Key Columns: $($KeyColumns -join ', ')" -ForegroundColor Gray

    # Build the key metadata payload
    $keyMetadata = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.EntityKeyMetadata"
        "SchemaName" = $KeySchemaName
        "DisplayName" = (New-LabelStructure -Label $KeyDisplayName)
        "KeyAttributes" = $KeyColumns
    }

    # Build endpoint - POST to EntityDefinitions(LogicalName='tablename')/Keys
    $endpoint = "EntityDefinitions(LogicalName='$TableName')/Keys"

    Write-Host "  Creating alternate key..." -ForegroundColor Gray

    try {
        $result = Invoke-DataverseWebApi -Method "POST" -Endpoint $endpoint -Body $keyMetadata -SolutionName $SolutionName

        Write-Host "  Alternate key created successfully!" -ForegroundColor Green

        # #404: read the key back and report its ACTUAL async index status, not a static guess.
        $keyStatus = $null
        for ($i = 0; $i -lt 5; $i++) {
            if ($i -gt 0) { Start-Sleep -Seconds 3 }
            try {
                $kb = (Invoke-DataverseWebApi -Method "GET" -Endpoint "EntityDefinitions(LogicalName='$TableName')/Keys?`$select=SchemaName,EntityKeyIndexStatus").value |
                      Where-Object { $_.SchemaName -eq $KeySchemaName } | Select-Object -First 1
                if ($kb) { $keyStatus = "$($kb.EntityKeyIndexStatus)" }
            } catch { }
            if ($keyStatus -eq 'Active') { break }
        }
        if ($keyStatus -eq 'Active') {
            Write-Host "  [READBACK] alternate key '$KeySchemaName' is Active." -ForegroundColor Green
        } elseif ($keyStatus) {
            Write-Host "  [READBACK][WARN] alternate key '$KeySchemaName' status is '$keyStatus' - the index activates ASYNCHRONOUSLY; re-check with QueryAlternateKeys before relying on upsert-by-key." -ForegroundColor Yellow
            $script:WarnCount++
        } else {
            Write-Host "  [READBACK][WARN] could not read '$KeySchemaName' back - verify with QueryAlternateKeys." -ForegroundColor Yellow
            $script:WarnCount++
        }

        return $result
    }
    catch {
        $errorMessage = $_.Exception.Message

        # Check for common errors
        if ($errorMessage -match "already exists") {
            Write-Host "  Alternate key '$KeySchemaName' already exists on table '$TableName'" -ForegroundColor Yellow
            return $null
        }
        elseif ($errorMessage -match "invalid column" -or $errorMessage -match "does not exist") {
            Write-Host "  One or more columns in KeyColumns do not exist on table '$TableName'" -ForegroundColor Red
            throw "Invalid key columns: $($KeyColumns -join ', '). Verify columns exist on the table."
        }
        elseif ($errorMessage -match "key size" -or $errorMessage -match "900 bytes") {
            Write-Host "  Key size exceeds SQL index limit (900 bytes)" -ForegroundColor Red
            throw "Key size exceeds maximum. Reduce the number or size of columns in the key."
        }
        else {
            throw $_
        }
    }
}

function Get-AlternateKeys {
    <#
    .SYNOPSIS
        Gets all alternate keys defined on a table.
    .DESCRIPTION
        Queries the alternate keys for a table including their status.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TableName
    )

    Write-Host "`n=== Querying Alternate Keys for: $TableName ===" -ForegroundColor Cyan

    $endpoint = "EntityDefinitions(LogicalName='$TableName')/Keys?`$select=SchemaName,DisplayName,KeyAttributes,EntityKeyIndexStatus"

    try {
        $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint

        if ($result.value -and $result.value.Count -gt 0) {
            Write-Host "  Found $($result.value.Count) alternate key(s):" -ForegroundColor Green
            foreach ($key in $result.value) {
                $displayName = if ($key.DisplayName.LocalizedLabels) { $key.DisplayName.LocalizedLabels[0].Label } else { "(no display name)" }
                # EntityKeyIndexStatus comes back from the Web API as its STRING enum name
                # (e.g. "Active"), not an integer — match strings first, fall back to the int codes.
                $raw = $key.EntityKeyIndexStatus
                $status = switch -Regex ("$raw") {
                    '^(2|Active)$'                { "Active" ; break }
                    '^(0|Pending)$'               { "Pending" ; break }
                    '^(1|InProgress|In Progress)$' { "In Progress" ; break }
                    '^(3|Failed)$'                { "Failed" ; break }
                    '^$'                          { "Unknown" ; break }
                    default                       { "$raw" }
                }
                Write-Host "    - $($key.SchemaName): [$($key.KeyAttributes -join ', ')] - Status: $status" -ForegroundColor White
            }
        }
        else {
            Write-Host "  No alternate keys found on table '$TableName'" -ForegroundColor Yellow
        }

        return $result.value
    }
    catch {
        if ($_.Exception.Message -match "404" -or $_.Exception.Message -match "not found") {
            Write-Host "  Table '$TableName' not found" -ForegroundColor Red
        }
        throw $_
    }
}

#endregion

#region Solution Operations

function Get-DataverseSolution {
    <#
    .SYNOPSIS
        Reads a solution by unique name (read-only), with its component count.
    .DESCRIPTION
        Makes the verify-then-create flow expressible: query a solution's existence/version/managed
        state and how many components it currently holds, without the fail-and-interpret 400 that
        CreateSolution throws on a name clash. Returns the solution record (or $null if absent).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SolutionUniqueName
    )

    Write-Host "`n=== Querying Solution: $SolutionUniqueName ===" -ForegroundColor Cyan

    $result = Invoke-DataverseWebApi -Method "GET" `
        -Endpoint "solutions?`$filter=uniquename eq '$SolutionUniqueName'&`$select=solutionid,uniquename,friendlyname,version,ismanaged,description" `
        -IsMetadataOperation $false

    if (-not $result.value -or $result.value.Count -eq 0) {
        Write-Host "  Solution '$SolutionUniqueName' not found." -ForegroundColor Yellow
        return $null
    }

    $s = $result.value[0]
    Write-Host "  Found solution:" -ForegroundColor Green
    Write-Host "    UniqueName:   $($s.uniquename)" -ForegroundColor White
    Write-Host "    FriendlyName: $($s.friendlyname)" -ForegroundColor White
    Write-Host "    Version:      $($s.version)" -ForegroundColor White
    Write-Host "    IsManaged:    $($s.ismanaged)" -ForegroundColor White

    # Component count (best-effort; grouped by componenttype)
    try {
        $comp = Invoke-DataverseWebApi -Method "GET" `
            -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $($s.solutionid)&`$select=componenttype" `
            -IsMetadataOperation $false
        $count = @($comp.value).Count
        Write-Host "    Components:   $count" -ForegroundColor White
        if ($count -gt 0) {
            $comp.value | Group-Object componenttype | Sort-Object Name | ForEach-Object {
                Write-Host ("      componenttype {0,-4} x{1}" -f $_.Name, $_.Count) -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "    Components:   (count unavailable: $($_.Exception.Message))" -ForegroundColor Yellow
    }

    return $s
}

function New-DataverseSolution {
    <#
    .SYNOPSIS
        Creates a new Dataverse solution (idempotent — reuses an existing one of the same name).
    .DESCRIPTION
        Creates an unmanaged solution in Dataverse using the Web API. If a solution with the same
        unique name already exists, it is reused (no 400), so a re-run is safe.
    #>
    param(
        [string]$SolutionUniqueName,
        [string]$SolutionDisplayName,
        [string]$SolutionDescription,
        [string]$PublisherName
    )

    Write-Host "`n=== Creating Solution: $SolutionUniqueName ===" -ForegroundColor Cyan

    # IDEMPOTENCY PREFLIGHT: CreateSolution is otherwise non-idempotent -- a re-run on an existing
    # solution throws a 400 ("uniquename already being used"), forcing a fail-and-interpret instead of
    # the natural verify-then-create flow. Check first and reuse if present.
    $existingSol = Invoke-DataverseWebApi -Method "GET" `
        -Endpoint "solutions?`$filter=uniquename eq '$SolutionUniqueName'&`$select=solutionid,uniquename,friendlyname,version,ismanaged" `
        -IsMetadataOperation $false
    if ($existingSol.value -and $existingSol.value.Count -gt 0) {
        $s = $existingSol.value[0]
        Write-Host "  [EXISTS] Solution '$SolutionUniqueName' already exists (v$($s.version), managed=$($s.ismanaged)) -- reusing it." -ForegroundColor Yellow
        Write-Host "           No create needed; new components will land here as long as you pass -SolutionName '$SolutionUniqueName'." -ForegroundColor Gray
        return $s
    }

    Write-DescriptionWarning -ComponentKind "solution" -ComponentName $SolutionUniqueName -Description $SolutionDescription

    # Look up the publisher — exact uniquename match first, then fallback to prefix
    Write-Host "  Looking up publisher: $PublisherName" -ForegroundColor Gray

    # Step 1: Try exact match on uniquename
    $exactEndpoint = "publishers?`$filter=uniquename eq '$PublisherName'&`$select=publisherid,uniquename,friendlyname,customizationprefix"
    $exactResult = Invoke-DataverseWebApi -Method "GET" -Endpoint $exactEndpoint -IsMetadataOperation $false

    $foundPublisher = $null
    if ($exactResult.value -and $exactResult.value.Count -gt 0) {
        $foundPublisher = $exactResult.value[0]
    } else {
        # Step 2: Fallback to customizationprefix match
        Write-Host "  No exact uniquename match, searching by prefix..." -ForegroundColor Gray
        $prefixEndpoint = "publishers?`$filter=customizationprefix eq '$PublisherName'&`$select=publisherid,uniquename,friendlyname,customizationprefix"
        $prefixResult = Invoke-DataverseWebApi -Method "GET" -Endpoint $prefixEndpoint -IsMetadataOperation $false

        if (-not $prefixResult.value -or $prefixResult.value.Count -eq 0) {
            # PREFLIGHT: CLAUDE.md named a publisher that does not exist in this environment
            # (config-vs-environment drift -- the #1 "I burned a call discovering this" trap on a
            # fresh env). Surface it explicitly, list what IS here, and hand over a ready
            # CreatePublisher command rather than failing with a bare "not found".
            Write-Host "`n  [PREFLIGHT] Publisher '$PublisherName' does NOT exist in this environment." -ForegroundColor Red
            Write-Host "  Likely config-vs-environment drift: CLAUDE.md names a publisher/prefix that was never created here." -ForegroundColor Yellow
            try {
                $allPubs = Invoke-DataverseWebApi -Method "GET" -Endpoint "publishers?`$select=uniquename,customizationprefix,friendlyname&`$orderby=uniquename asc" -IsMetadataOperation $false
                Write-Host "`n  Existing publishers you could use instead (pass as -PublisherName <uniquename>):" -ForegroundColor Cyan
                foreach ($pub in $allPubs.value) {
                    Write-Host ("    - {0,-34} prefix={1,-10} {2}" -f $pub.uniquename, $pub.customizationprefix, $pub.friendlyname) -ForegroundColor Gray
                }
            } catch { }
            $suggestedPrefix = if ($PublisherName -match '^[a-z][a-z0-9]{1,7}$') { $PublisherName } else { $script:PublisherPrefix }
            Write-Host "`n  Or create it first (pick any unused OptionValuePrefix in 10000-99999):" -ForegroundColor Cyan
            Write-Host "    -Operation CreatePublisher -PublisherUniqueName '<UniqueName>' -PublisherDisplayName '<Display Name>' -PublisherPrefix '$suggestedPrefix' -OptionValuePrefix <10000-99999>" -ForegroundColor White
            throw "Publisher '$PublisherName' not found (see preflight guidance above). Create it with CreatePublisher, or re-run CreateSolution with an existing -PublisherName."
        }

        if ($prefixResult.value.Count -gt 1) {
            Write-Host "`n  [ERROR] Multiple publishers found with prefix '$PublisherName':" -ForegroundColor Red
            foreach ($pub in $prefixResult.value) {
                Write-Host "    - $($pub.uniquename) (prefix: $($pub.customizationprefix)) — $($pub.friendlyname)" -ForegroundColor Yellow
            }
            throw "Ambiguous publisher prefix '$PublisherName'. Please specify the exact uniquename with -PublisherName (e.g., -PublisherName '$($prefixResult.value[0].uniquename)')."
        }

        $foundPublisher = $prefixResult.value[0]
    }

    $publisherId = $foundPublisher.publisherid
    Write-Host "  Found publisher: $($foundPublisher.uniquename) ($publisherId)" -ForegroundColor Gray

    # Create solution record
    $solutionData = @{
        "uniquename" = $SolutionUniqueName
        "friendlyname" = $SolutionDisplayName
        "version" = "1.0.0.0"
        "publisherid@odata.bind" = "/publishers($publisherId)"
    }

    if ($SolutionDescription) {
        $solutionData["description"] = $SolutionDescription
    }

    Write-Host "  Solution name: $SolutionUniqueName" -ForegroundColor Gray
    Write-Host "  Display name: $SolutionDisplayName" -ForegroundColor Gray
    Write-Host "  Version: 1.0.0.0" -ForegroundColor Gray

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "solutions" -Body $solutionData -IsMetadataOperation $false

    Write-Host "  Solution created successfully!" -ForegroundColor Green
    return $result
}

function Add-TableToSolution {
    <#
    .SYNOPSIS
        Adds an existing table to a solution.
    .DESCRIPTION
        Adds a table (entity) to a solution using the AddSolutionComponent action.
        By default, adds metadata only without including all subcomponents (columns, views, forms).
    #>
    param(
        [string]$TableName,
        [string]$SolutionName,
        [bool]$DoNotIncludeSubcomponents = $true
    )

    Write-Host "`n=== Adding Table to Solution: $TableName ===" -ForegroundColor Cyan

    # First, get the table's MetadataId
    $tableLower = $TableName.ToLower()
    $tableEndpoint = "EntityDefinitions(LogicalName='$tableLower')?`$select=MetadataId,LogicalName,DisplayName"

    try {
        $tableResult = Invoke-DataverseWebApi -Method "GET" -Endpoint $tableEndpoint
        $tableMetadataId = $tableResult.MetadataId
        Write-Host "  Found table: $($tableResult.DisplayName.LocalizedLabels[0].Label) ($tableMetadataId)" -ForegroundColor Gray
    }
    catch {
        throw "Table '$TableName' not found. Verify the table exists."
    }

    # Use AddSolutionComponent action
    # ComponentType 1 = Entity (Table)
    $addComponentRequest = @{
        "ComponentId" = $tableMetadataId
        "ComponentType" = 1  # Entity
        "SolutionUniqueName" = $SolutionName
        "AddRequiredComponents" = $false
        "DoNotIncludeSubcomponents" = $DoNotIncludeSubcomponents
        "IncludedComponentSettingsValues" = $null
    }

    Write-Host "  Adding to solution: $SolutionName" -ForegroundColor Gray
    Write-Host "  Include subcomponents: $(-not $DoNotIncludeSubcomponents)" -ForegroundColor Gray

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "AddSolutionComponent" -Body $addComponentRequest -IsMetadataOperation $false

    Write-Host "  Table added to solution successfully!" -ForegroundColor Green
    if ($DoNotIncludeSubcomponents) {
        Write-Host "  Note: Only table metadata was added. Use AddComponentToSolution to add specific columns, forms, or views." -ForegroundColor Yellow
    }
    return $result
}

function Add-ComponentToSolution {
    <#
    .SYNOPSIS
        Adds a specific component to a solution.
    .DESCRIPTION
        Adds individual components (columns, forms, views, etc.) to a solution.
        Use this for selective inclusion of table components.
    #>
    param(
        [string]$ComponentId,
        [string]$ComponentType,
        [string]$SolutionName
    )

    Write-Host "`n=== Adding Component to Solution ===" -ForegroundColor Cyan

    # Map component type to numeric value
    # Reference: https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/entities/solutioncomponent
    $componentTypeMap = @{
        "Table" = 1           # Entity
        "Column" = 2          # Attribute
        "Relationship" = 10   # Entity Relationship
        "GlobalChoice" = 9    # Option Set
        "Form" = 24           # System Form (including main forms)
        "View" = 26           # Saved Query (System View)
        "Chart" = 59          # Saved Query Visualization
        "Dashboard" = 60      # System Form (Dashboard)
        "WebResource" = 61    # Web Resource
        "AppModule" = 80      # Model-driven App
        "PluginAssembly" = 91 # Plugin Assembly
        "SDKMessageProcessingStep" = 92 # SDK Message Processing Step
        "Workflow" = 29       # Workflow
    }

    $componentTypeValue = $componentTypeMap[$ComponentType]
    if (-not $componentTypeValue) {
        throw "Unknown component type: $ComponentType. Valid types: $($componentTypeMap.Keys -join ', ')"
    }

    Write-Host "  Component Type: $ComponentType (Type Code: $componentTypeValue)" -ForegroundColor Gray
    Write-Host "  Component ID: $ComponentId" -ForegroundColor Gray
    Write-Host "  Solution: $SolutionName" -ForegroundColor Gray

    $addComponentRequest = @{
        "ComponentId" = $ComponentId
        "ComponentType" = $componentTypeValue
        "SolutionUniqueName" = $SolutionName
        "AddRequiredComponents" = $false
    }

    # DoNotIncludeSubcomponents only applies to Entity (Table) components
    if ($componentTypeValue -eq 1) {
        $addComponentRequest["DoNotIncludeSubcomponents"] = $true
    }

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "AddSolutionComponent" -Body $addComponentRequest -IsMetadataOperation $false

    Write-Host "  Component added to solution successfully!" -ForegroundColor Green
    return $result
}

#endregion

#region Column Update Operations

function Update-DataverseColumn {
    <#
    .SYNOPSIS
        Updates an existing column's settings.
    .DESCRIPTION
        Updates column properties using the GET-modify-PUT pattern required by the Dataverse Web API.
        Retrieves the full current metadata, applies requested changes, and PUTs the entire object back.

        Supports updating:
        - DisplayName, Description, RequiredLevel (all types)
        - IsAuditEnabled, IsValidForAdvancedFind (all types)
        - MinValue, MaxValue (Integer, Decimal, Double)
        - MaxLength (String, Memo)
        - Precision (Decimal, Double, Money)
        - DefaultValue (Integer, Decimal, Boolean)
        - AutoNumberFormat (String -> AutoNumber conversion)
    #>
    param(
        [string]$TableName,
        [string]$ColumnName,
        [string]$ColumnDisplayName,
        [string]$ColumnDescription,
        [string]$RequiredLevel,
        $IsAuditEnabled,
        $IsValidForAdvancedFind,
        [double]$ColumnMinValue,
        [double]$ColumnMaxValue,
        [int]$MaxLength,
        [int]$Precision,
        $DefaultValue,
        [string]$AutoNumberFormat,
        [string]$SolutionName,
        [hashtable]$BoundParams
    )

    Write-Host "`n=== Updating Column: $ColumnName on $TableName ===" -ForegroundColor Cyan

    $tableLower = $TableName.ToLower()
    $columnLower = $ColumnName.ToLower()

    # Step 1: GET the full current metadata for the column
    $columnEndpoint = "EntityDefinitions(LogicalName='$tableLower')/Attributes(LogicalName='$columnLower')"

    try {
        $currentMetadata = Invoke-DataverseWebApi -Method "GET" -Endpoint $columnEndpoint
        Write-Host "  Found column: $($currentMetadata.DisplayName.LocalizedLabels[0].Label)" -ForegroundColor Gray
        Write-Host "  Current type: $($currentMetadata.AttributeType)" -ForegroundColor Gray
    }
    catch {
        throw "Column '$ColumnName' not found on table '$TableName'."
    }

    # If this is ONLY an auto-number conversion (legacy path), use the simple PUT
    if ($AutoNumberFormat -and -not $BoundParams.ContainsKey('ColumnDisplayName') -and -not $BoundParams.ContainsKey('ColumnDescription') `
        -and -not $BoundParams.ContainsKey('RequiredLevel') -and -not $BoundParams.ContainsKey('IsAuditEnabled') `
        -and -not $BoundParams.ContainsKey('IsValidForAdvancedFind') -and -not $BoundParams.ContainsKey('ColumnMinValue') `
        -and -not $BoundParams.ContainsKey('ColumnMaxValue') -and -not $BoundParams.ContainsKey('MaxLength') `
        -and -not $BoundParams.ContainsKey('Precision') -and -not $BoundParams.ContainsKey('DefaultValue')) {

        Write-Host "  Converting to Auto-Number format: $AutoNumberFormat" -ForegroundColor Cyan

        $updateBody = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            "AutoNumberFormat" = $AutoNumberFormat
        }

        $result = Invoke-DataverseWebApi -Method "PUT" -Endpoint $columnEndpoint -Body $updateBody -SolutionName $SolutionName

        Write-Host "  Column updated to Auto-Number format!" -ForegroundColor Green
        Write-AutoNumberSeedNote -AutoNumberFormat $AutoNumberFormat -EntityName $TableName -AttributeName $ColumnName

        return $result
    }

    # Step 2: Build a MINIMAL update body with only @odata.type and changed properties
    # The Dataverse Web API PUT for metadata rejects properties not in the OData schema,
    # even though GET returns them. Using a minimal body avoids this issue.

    $typeMap = @{
        "String" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
        "Memo" = "Microsoft.Dynamics.CRM.MemoAttributeMetadata"
        "Integer" = "Microsoft.Dynamics.CRM.IntegerAttributeMetadata"
        "Decimal" = "Microsoft.Dynamics.CRM.DecimalAttributeMetadata"
        "Money" = "Microsoft.Dynamics.CRM.MoneyAttributeMetadata"
        "Double" = "Microsoft.Dynamics.CRM.DoubleAttributeMetadata"
        "DateTime" = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"
        "Boolean" = "Microsoft.Dynamics.CRM.BooleanAttributeMetadata"
        "Picklist" = "Microsoft.Dynamics.CRM.PicklistAttributeMetadata"
        "Virtual" = "Microsoft.Dynamics.CRM.MultiSelectPicklistAttributeMetadata"
        "Lookup" = "Microsoft.Dynamics.CRM.LookupAttributeMetadata"
        "Uniqueidentifier" = "Microsoft.Dynamics.CRM.UniqueIdentifierAttributeMetadata"
        "BigInt" = "Microsoft.Dynamics.CRM.BigIntAttributeMetadata"
        "ManagedProperty" = "Microsoft.Dynamics.CRM.ManagedPropertyAttributeMetadata"
        "EntityName" = "Microsoft.Dynamics.CRM.EntityNameAttributeMetadata"
    }

    $attrType = $currentMetadata.AttributeType
    $odataType = $currentMetadata.'@odata.type'
    if (-not $odataType -and $typeMap.ContainsKey($attrType)) {
        $odataType = $typeMap[$attrType]
    }
    if ($odataType -and $odataType.StartsWith("#")) {
        $odataType = $odataType.Substring(1)
    }

    $updateBody = @{
        "@odata.type" = $odataType
        "LogicalName" = $currentMetadata.LogicalName
        "SchemaName" = $currentMetadata.SchemaName
    }

    $changesApplied = @()

    # Step 3: Apply requested changes

    # DisplayName
    if ($BoundParams.ContainsKey('ColumnDisplayName') -and $ColumnDisplayName) {
        $updateBody["DisplayName"] = New-LabelStructure -Label $ColumnDisplayName
        $changesApplied += "DisplayName -> '$ColumnDisplayName'"
    }

    # Description
    if ($BoundParams.ContainsKey('ColumnDescription') -and $ColumnDescription) {
        $updateBody["Description"] = New-LabelStructure -Label $ColumnDescription
        $changesApplied += "Description -> '$ColumnDescription'"
    }

    # RequiredLevel
    if ($BoundParams.ContainsKey('RequiredLevel') -and $RequiredLevel) {
        $updateBody["RequiredLevel"] = @{ "Value" = $RequiredLevel; "CanBeChanged" = $true; "ManagedPropertyLogicalName" = "canmodifyrequirementlevelsettings" }
        $changesApplied += "RequiredLevel -> '$RequiredLevel'"
    }

    # IsAuditEnabled
    if ($BoundParams.ContainsKey('IsAuditEnabled') -and $null -ne $IsAuditEnabled) {
        $updateBody["IsAuditEnabled"] = @{ "Value" = $IsAuditEnabled; "CanBeChanged" = $true; "ManagedPropertyLogicalName" = "canmodifyauditsettings" }
        $changesApplied += "IsAuditEnabled -> $IsAuditEnabled"
    }

    # IsValidForAdvancedFind
    if ($BoundParams.ContainsKey('IsValidForAdvancedFind') -and $null -ne $IsValidForAdvancedFind) {
        $updateBody["IsValidForAdvancedFind"] = @{ "Value" = $IsValidForAdvancedFind; "CanBeChanged" = $true; "ManagedPropertyLogicalName" = "canmodifysearchsettings" }
        $changesApplied += "IsValidForAdvancedFind -> $IsValidForAdvancedFind"
    }

    # Type-specific properties
    $attrType = $currentMetadata.AttributeType

    # MinValue / MaxValue (Integer, Decimal, Double, Money)
    if ($BoundParams.ContainsKey('ColumnMinValue')) {
        if ($attrType -in @("Integer", "Decimal", "Double", "Money")) {
            $castValue = if ($attrType -eq "Integer") { [int]$ColumnMinValue } else { [double]$ColumnMinValue }
            $updateBody["MinValue"] = $castValue
            $changesApplied += "MinValue -> $castValue"
        } else {
            Write-Host "  WARNING: MinValue is not supported for $attrType columns. Skipping." -ForegroundColor Yellow
        }
    }

    if ($BoundParams.ContainsKey('ColumnMaxValue')) {
        if ($attrType -in @("Integer", "Decimal", "Double", "Money")) {
            $castValue = if ($attrType -eq "Integer") { [int]$ColumnMaxValue } else { [double]$ColumnMaxValue }
            $updateBody["MaxValue"] = $castValue
            $changesApplied += "MaxValue -> $castValue"
        } else {
            Write-Host "  WARNING: MaxValue is not supported for $attrType columns. Skipping." -ForegroundColor Yellow
        }
    }

    # MaxLength (String, Memo)
    if ($BoundParams.ContainsKey('MaxLength')) {
        if ($attrType -in @("String", "Memo")) {
            $updateBody["MaxLength"] = $MaxLength
            $changesApplied += "MaxLength -> $MaxLength"
        } else {
            Write-Host "  WARNING: MaxLength is not supported for $attrType columns. Skipping." -ForegroundColor Yellow
        }
    }

    # Precision (Decimal, Double, Money)
    if ($BoundParams.ContainsKey('Precision')) {
        if ($attrType -in @("Decimal", "Double", "Money")) {
            $updateBody["Precision"] = $Precision
            $changesApplied += "Precision -> $Precision"
        } else {
            Write-Host "  WARNING: Precision is not supported for $attrType columns. Skipping." -ForegroundColor Yellow
        }
    }

    # DefaultValue
    # The OData schema only exposes DefaultValue for Boolean columns.
    # For Picklist, the property is DefaultFormValue (the option value integer).
    # For Integer, Decimal, Double: DefaultValue is NOT in the OData model.
    if ($BoundParams.ContainsKey('DefaultValue') -and $null -ne $DefaultValue) {
        if ($attrType -eq "Boolean") {
            $updateBody["DefaultValue"] = [bool]$DefaultValue
            $changesApplied += "DefaultValue -> $([bool]$DefaultValue)"
        } elseif ($attrType -eq "Picklist") {
            $updateBody["DefaultFormValue"] = [int]$DefaultValue
            $changesApplied += "DefaultFormValue -> $([int]$DefaultValue)"
        } elseif ($attrType -in @("Integer", "Decimal", "Double")) {
            Write-Host "  WARNING: DefaultValue for $attrType columns is not in the OData schema." -ForegroundColor Yellow
            Write-Host "  Set default values for numeric columns via the Maker Portal." -ForegroundColor Yellow
        } else {
            Write-Host "  WARNING: DefaultValue is not supported for $attrType columns. Skipping." -ForegroundColor Yellow
        }
    }

    # AutoNumberFormat (can be combined with other changes)
    if ($AutoNumberFormat) {
        if ($attrType -eq "String") {
            $updateBody["AutoNumberFormat"] = $AutoNumberFormat
            $changesApplied += "AutoNumberFormat -> '$AutoNumberFormat'"
        } else {
            Write-Host "  WARNING: AutoNumberFormat is only supported for String columns. Skipping." -ForegroundColor Yellow
        }
    }

    # Step 4: Validate we have changes to apply
    if ($changesApplied.Count -eq 0) {
        Write-Host "  No update parameters specified." -ForegroundColor Yellow
        Write-Host "  Supported parameters: -ColumnDisplayName, -ColumnDescription, -RequiredLevel," -ForegroundColor Yellow
        Write-Host "    -IsAuditEnabled, -IsValidForAdvancedFind, -ColumnMinValue, -ColumnMaxValue," -ForegroundColor Yellow
        Write-Host "    -MaxLength, -Precision, -DefaultValue, -AutoNumberFormat" -ForegroundColor Yellow
        return $null
    }

    Write-Host "  Applying $($changesApplied.Count) change(s):" -ForegroundColor Cyan
    foreach ($change in $changesApplied) {
        Write-Host "    - $change" -ForegroundColor White
    }

    # Step 5: PUT the updated metadata
    $result = Invoke-DataverseWebApi -Method "PUT" -Endpoint $columnEndpoint -Body $updateBody -SolutionName $SolutionName

    Write-Host "  Column updated successfully!" -ForegroundColor Green

    if ($AutoNumberFormat -and $attrType -eq "String") {
        Write-AutoNumberSeedNote -AutoNumberFormat $AutoNumberFormat -EntityName $TableName -AttributeName $ColumnName
    }

    return $result
}

#endregion

#region Publisher Operations

function Get-AllPublishers {
    <#
    .SYNOPSIS
        Lists all publishers in the environment with read-only status.
    #>

    Write-Host "`n=== Publishers in Environment ===" -ForegroundColor Cyan

    $endpoint = "publishers?`$select=uniquename,friendlyname,customizationprefix,customizationoptionvalueprefix&`$orderby=uniquename asc"
    $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint -IsMetadataOperation $false

    if (-not $result.value -or $result.value.Count -eq 0) {
        Write-Host "  No publishers found." -ForegroundColor Yellow
        return
    }

    Write-Host ("  {0,-35} {1,-12} {2,-8} {3}" -f "Unique Name", "Prefix", "OVP", "Display Name") -ForegroundColor White
    Write-Host ("  {0,-35} {1,-12} {2,-8} {3}" -f ("-" * 34), ("-" * 11), ("-" * 7), ("-" * 20)) -ForegroundColor DarkGray

    foreach ($pub in $result.value) {
        Write-Host ("  {0,-35} {1,-12} {2,-8} {3}" -f $pub.uniquename, $pub.customizationprefix, $pub.customizationoptionvalueprefix, $pub.friendlyname) -ForegroundColor Green
    }

    Write-Host "`n  Total: $($result.value.Count) publishers" -ForegroundColor Cyan

    return $result.value
}

function New-DataversePublisher {
    <#
    .SYNOPSIS
        Creates a new publisher in Dataverse.
    .DESCRIPTION
        Creates a publisher record that can be used when creating solutions.
        The publisher prefix is used for all custom component names (tables, columns, etc.).
    #>
    param(
        [string]$DisplayName,
        [string]$UniqueName,
        [string]$Prefix,
        [int]$OptionValuePrefix
    )

    Write-Host "`n=== Creating Publisher: $DisplayName ===" -ForegroundColor Cyan

    if (-not $DisplayName) { throw "-PublisherDisplayName is required" }
    if (-not $UniqueName)  { throw "-PublisherUniqueName is required" }
    if (-not $Prefix)      { throw "-PublisherPrefix is required for the new publisher" }
    if ($OptionValuePrefix -le 0) { throw "-OptionValuePrefix is required (integer, e.g. 54031)" }

    # Validate prefix format
    if ($Prefix -notmatch '^[a-z]{2,8}$') {
        throw "Publisher prefix '$Prefix' must be 2-8 lowercase letters (a-z only)"
    }

    # Check if already exists
    $checkEndpoint = "publishers?`$filter=uniquename eq '$UniqueName' or customizationprefix eq '$Prefix'&`$select=publisherid,uniquename,customizationprefix"
    $existing = Invoke-DataverseWebApi -Method "GET" -Endpoint $checkEndpoint -IsMetadataOperation $false
    if ($existing.value -and $existing.value.Count -gt 0) {
        $found = $existing.value[0]
        Write-Host "  Publisher already exists: $($found.uniquename) (prefix: $($found.customizationprefix))" -ForegroundColor Yellow
        return $found
    }

    $payload = @{
        "friendlyname"                   = $DisplayName
        "uniquename"                     = $UniqueName
        "customizationprefix"            = $Prefix
        "customizationoptionvalueprefix" = $OptionValuePrefix
    }

    Write-Host "  Unique Name:         $UniqueName" -ForegroundColor Gray
    Write-Host "  Prefix:              $Prefix" -ForegroundColor Gray
    Write-Host "  Option Value Prefix: $OptionValuePrefix" -ForegroundColor Gray

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "publishers" -Body $payload -IsMetadataOperation $false

    Write-Host "  Publisher created successfully!" -ForegroundColor Green
    Write-Host "  Use -PublisherName '$UniqueName' when calling CreateSolution." -ForegroundColor Cyan

    return $result
}

#endregion

#region App Module Operations

function Get-AppModuleId {
    <#
    .SYNOPSIS
        Gets the App Module ID by unique name (case-insensitive).
    .DESCRIPTION
        Queries via the RetrieveUnpublishedMultiple bound function — NOT a plain
        GET on /appmodules. A plain GET returns only PUBLISHED app modules, so a
        freshly-created (unpublished) app is missed, which used to make CreateApp's
        existence check fail and create duplicate apps on every re-run.
        RetrieveUnpublishedMultiple returns the unpublished (latest) version of all
        apps, so it sees both published and just-created apps. (Verified: an
        unpublished app returns count=1 here while a plain GET returns 0 / 404.)
    #>
    param([string]$AppUniqueName)

    # First try direct filter by uniquename (most reliable)
    $endpoint = "appmodules/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$filter=uniquename eq '$AppUniqueName'&`$select=appmoduleid,appmoduleidunique,uniquename,name,statecode,statuscode"
    Write-Host "  Querying: $endpoint" -ForegroundColor Gray
    $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint -IsMetadataOperation $false

    if ($result.value -and $result.value.Count -gt 0) {
        Write-Host "  Found app: $($result.value[0].name) ($($result.value[0].uniquename))" -ForegroundColor Green
        return $result.value[0]
    }

    # If not found, try case-insensitive by getting all and filtering
    Write-Host "  Direct filter returned no results, trying full query..." -ForegroundColor Yellow
    $appNameLower = $AppUniqueName.ToLower()
    $endpoint = "appmodules/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$select=appmoduleid,appmoduleidunique,uniquename,name,statecode,statuscode"
    $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint -IsMetadataOperation $false

    if ($result.value -and $result.value.Count -gt 0) {
        Write-Host "  Found $($result.value.Count) app(s) in environment" -ForegroundColor Gray
        # Find exact match (case-insensitive)
        $match = $result.value | Where-Object { $_.uniquename.ToLower() -eq $appNameLower }
        if ($match) {
            return $match
        }
        # Show available apps for debugging
        Write-Host "  Looking for: $appNameLower" -ForegroundColor Yellow
        Write-Host "  Available:" -ForegroundColor Yellow
        foreach ($app in $result.value) {
            Write-Host "    - $($app.uniquename)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  No apps returned from query" -ForegroundColor Red
    }
    return $null
}

function Get-AppModuleById {
    <#
    .SYNOPSIS
        Gets an App Module record by GUID. Accepts EITHER appmoduleid (PK) OR
        appmoduleidunique — the maker portal sometimes exposes the unique id.
    .DESCRIPTION
        Use this when Get-AppModuleId (which filters by uniquename) cannot find an
        app. Direct GUID lookup is authoritative.

        Tries (both via the RetrieveUnpublishedMultiple bound function):
        1. filter by appmoduleid (PK)
        2. filter by appmoduleidunique

        Uses RetrieveUnpublishedMultiple — NOT a plain GET — because a plain
        appmodules(<id>) PK GET returns "Does Not Exist" for an unpublished app
        (it only serves published rows). The app is NOT actually invisible; it is
        retrievable immediately after create via the unpublished function. No
        manual App Designer save+publish is required.
    #>
    param([string]$AppModuleId)

    $selectCols = "appmoduleid,appmoduleidunique,uniquename,name,statecode,statuscode,webresourceid,welcomepageid,description"

    # Try 1: filter by primary key (appmoduleid) via RetrieveUnpublishedMultiple
    $endpoint = "appmodules/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$filter=appmoduleid eq $AppModuleId&`$select=$selectCols"
    Write-Host "  Trying PK lookup (unpublished): $endpoint" -ForegroundColor Gray
    $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint -IsMetadataOperation $false
    if ($result.value -and $result.value.Count -gt 0) {
        $app = $result.value[0]
        Write-Host "  Found app via PK: $($app.name) ($($app.uniquename))" -ForegroundColor Green
        return $app
    }

    # Try 2: filter by appmoduleidunique (maker portal sometimes exposes this id)
    Write-Host "  PK filter returned nothing; trying appmoduleidunique filter..." -ForegroundColor Yellow
    $endpoint = "appmodules/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$filter=appmoduleidunique eq $AppModuleId&`$select=$selectCols"
    Write-Host "  Trying: GET $endpoint" -ForegroundColor Gray
    $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint -IsMetadataOperation $false
    if ($result.value -and $result.value.Count -gt 0) {
        $app = $result.value[0]
        Write-Host "  Found app via appmoduleidunique: $($app.name) ($($app.uniquename))" -ForegroundColor Green
        Write-Host "  Note: caller passed appmoduleidunique; PK is $($app.appmoduleid)" -ForegroundColor DarkGray
        return $app
    }
    return $null
}

function Get-EntityMetadataId {
    <#
    .SYNOPSIS
        Gets the MetadataId (GUID) for an entity definition.
    #>
    param([string]$TableName)

    $tableLower = $TableName.ToLower()
    $endpoint = "EntityDefinitions(LogicalName='$tableLower')?`$select=MetadataId,LogicalName"
    $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint
    return $result.MetadataId
}

function Get-EntityId {
    <#
    .SYNOPSIS
        Gets the entityid (GUID) from the entity table for AddAppComponents.
    .DESCRIPTION
        The 'entity' table stores entity records with entityid as primary key.
        This is different from MetadataId in EntityDefinitions.
        AddAppComponents requires the entityid, not the MetadataId.
    #>
    param([string]$TableName)

    $tableLower = $TableName.ToLower()
    $endpoint = "entities?`$filter=logicalname eq '$tableLower'&`$select=entityid,logicalname,name"

    Write-Host "  Querying entity table for: $tableLower" -ForegroundColor Gray
    $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint -IsMetadataOperation $false

    if ($result.value -and $result.value.Count -gt 0) {
        $entityId = $result.value[0].entityid
        Write-Host "  Found entityid: $entityId" -ForegroundColor Gray
        return $entityId
    }

    throw "Entity '$TableName' not found in entity table."
}

function Get-DefaultViewForTable {
    <#
    .SYNOPSIS
        Gets the default public view (savedquery) for a table.
    .DESCRIPTION
        Retrieves the default active public view for a table.
        This is needed because AddAppComponents adds tables via their views,
        not directly as entities.
    #>
    param([string]$TableName)

    $tableLower = $TableName.ToLower()
    # querytype 0 = public views, isdefault = true
    $endpoint = "savedqueries?`$filter=returnedtypecode eq '$tableLower' and querytype eq 0 and isdefault eq true&`$select=savedqueryid,name,isdefault&`$top=1"

    Write-Host "  Looking for default view for: $tableLower" -ForegroundColor Gray
    $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint -IsMetadataOperation $false

    if ($result.value -and $result.value.Count -gt 0) {
        $view = $result.value[0]
        Write-Host "  Found default view: $($view.name) ($($view.savedqueryid))" -ForegroundColor Gray
        return $view
    }

    # If no default, get any public view
    Write-Host "  No default view found, looking for any public view..." -ForegroundColor Yellow
    $endpoint = "savedqueries?`$filter=returnedtypecode eq '$tableLower' and querytype eq 0&`$select=savedqueryid,name,isdefault&`$top=1"
    $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint -IsMetadataOperation $false

    if ($result.value -and $result.value.Count -gt 0) {
        $view = $result.value[0]
        Write-Host "  Found view: $($view.name) ($($view.savedqueryid))" -ForegroundColor Gray
        return $view
    }

    throw "No public views found for table '$TableName'."
}

function New-ModelDrivenApp {
    <#
    .SYNOPSIS
        Creates a new model-driven app.
    .DESCRIPTION
        Creates a model-driven app using the appmodules entity.
        After creation, use AddTableToApp to add tables.
    #>
    param(
        [string]$AppUniqueName,
        [string]$AppDisplayName,
        [string]$AppDescription,
        [string]$SolutionName
    )

    Write-Host "`n=== Creating Model-Driven App: $AppDisplayName ===" -ForegroundColor Cyan
    Write-DescriptionWarning -ComponentKind "model-driven app" -ComponentName $AppUniqueName -Description $AppDescription

    # Check if app already exists (with and without publisher prefix, mirroring how
    # Add-TableToModelDrivenApp looks up the app to prevent false "not found" on re-runs)
    $existingApp = Get-AppModuleId -AppUniqueName $AppUniqueName
    if (-not $existingApp -and -not (Test-NameAlreadyPrefixed -Name $AppUniqueName)) {
        $existingApp = Get-AppModuleId -AppUniqueName (Add-PublisherPrefix -Name $AppUniqueName)
    }
    if ($existingApp) {
        Write-Host "  App already exists: $($existingApp.name) ($($existingApp.appmoduleid))" -ForegroundColor Yellow
        return $existingApp
    }

    # Construct the unique name with publisher prefix if not already prefixed
    $uniqueName = Add-PublisherPrefix -Name $AppUniqueName

    # Find a default icon web resource (SVG preferred)
    Write-Host "  Looking for default app icon..." -ForegroundColor Gray
    $iconEndpoint = "webresourceset?`$filter=webresourcetype eq 11 and contains(name,'icon')&`$select=webresourceid,name&`$top=1"
    $iconResult = Invoke-DataverseWebApi -Method "GET" -Endpoint $iconEndpoint -IsMetadataOperation $false

    $webResourceId = $null
    if ($iconResult.value -and $iconResult.value.Count -gt 0) {
        $webResourceId = $iconResult.value[0].webresourceid
        Write-Host "  Using icon: $($iconResult.value[0].name)" -ForegroundColor Gray
    }
    else {
        # Try to find any SVG web resource
        $svgEndpoint = "webresourceset?`$filter=webresourcetype eq 11&`$select=webresourceid,name&`$top=1"
        $svgResult = Invoke-DataverseWebApi -Method "GET" -Endpoint $svgEndpoint -IsMetadataOperation $false
        if ($svgResult.value -and $svgResult.value.Count -gt 0) {
            $webResourceId = $svgResult.value[0].webresourceid
            Write-Host "  Using SVG: $($svgResult.value[0].name)" -ForegroundColor Gray
        }
    }

    $appPayload = @{
        "name" = $AppDisplayName
        "uniquename" = $uniqueName
        "description" = $AppDescription
        "clienttype" = 4  # 4 = Web (Unified Interface)
    }

    # Add web resource reference if found (direct GUID binding for lookup)
    if ($webResourceId) {
        $appPayload["webresourceid"] = $webResourceId
    }

    Write-Host "  Unique Name: $uniqueName" -ForegroundColor Gray
    Write-Host "  Display Name: $AppDisplayName" -ForegroundColor Gray
    Write-Host "  Client Type: 4 (Unified Interface)" -ForegroundColor Gray

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "appmodules" -Body $appPayload -SolutionName $SolutionName -IsMetadataOperation $false

    # Get the created app ID from the response headers (OData-EntityId)
    Write-Host "  Model-driven app created successfully!" -ForegroundColor Green

    # Query to get the actual app module ID
    $createdApp = Get-AppModuleId -AppUniqueName $uniqueName
    if ($createdApp) {
        Write-Host "  App ID: $($createdApp.appmoduleid)" -ForegroundColor Gray
    }

    return $createdApp
}

function Get-AppElements {
    <#
    .SYNOPSIS
        Retrieves existing app elements (components) from an app module.
    .DESCRIPTION
        Queries the appmodulecomponent table to get all existing components
        for the specified app, returning them in the format needed for SaveAppModule.
    #>
    param(
        [string]$AppModuleIdUnique
    )

    Write-Host "  Retrieving existing app elements..." -ForegroundColor Gray

    $endpoint = "appmodulecomponents?`$filter=_appmoduleidunique_value eq '$AppModuleIdUnique'&`$select=componenttype,objectid"
    $result = Invoke-DataverseWebApi -Method "GET" -Endpoint $endpoint -IsMetadataOperation $false

    $appElements = @()
    if ($result.value) {
        foreach ($component in $result.value) {
            # Map componenttype to AppElementType
            $elementType = switch ($component.componenttype) {
                1 { "entity" }
                26 { "view" }
                60 { "form" }
                62 { "sitemap" }
                default { "unknown_$($component.componenttype)" }
            }

            $appElements += @{
                "ObjectId" = $component.objectid
                "AppElementType" = $elementType
            }
        }
        Write-Host "  Found $($appElements.Count) existing element(s)" -ForegroundColor Gray
    }

    return $appElements
}

function Add-TableToModelDrivenApp {
    <#
    .SYNOPSIS
        Adds a table to an existing model-driven app.
    .DESCRIPTION
        Adds a table (entity) to the app using the SaveAppModule action.
        This retrieves all existing app elements, adds the new table, and saves
        the complete app configuration.

        WARNING: This uses an UNDOCUMENTED API (SaveAppModule) that Microsoft uses
        internally in the Maker Portal. It is NOT officially supported and may change
        without notice. Use this ONLY for initial app setup to add multiple tables
        efficiently. For subsequent changes, use the Maker Portal UI directly.

    .NOTES
        The SaveAppModule action requires a complete payload with ALL app elements.
        If elements are missing from the payload, they will be removed from the app.
    #>
    param(
        [string]$AppUniqueName,
        [string]$TableName,
        [string]$SolutionName
    )

    Write-Host "`n=== Adding Table '$TableName' to App '$AppUniqueName' ===" -ForegroundColor Cyan
    Write-Host "  (Using SaveAppModule - undocumented API)" -ForegroundColor DarkYellow

    # Get the app module with full details
    $app = Get-AppModuleId -AppUniqueName $AppUniqueName
    if (-not $app) {
        # Try with publisher prefix
        $app = Get-AppModuleId -AppUniqueName "$($script:PublisherPrefix)_$AppUniqueName"
    }
    if (-not $app) {
        throw "App module '$AppUniqueName' not found. Verify the app's unique name (check App Designer > Properties) and ensure the app has been saved."
    }

    Write-Host "  Found app: $($app.name)" -ForegroundColor Gray
    Write-Host "    appmoduleid: $($app.appmoduleid)" -ForegroundColor DarkGray
    Write-Host "    appmoduleidunique: $($app.appmoduleidunique)" -ForegroundColor DarkGray

    # Get full app details for the payload. Use RetrieveUnpublishedMultiple (filter by PK)
    # rather than a plain appmodules(<id>) GET — the plain GET 404s on an unpublished app
    # (it serves published rows only), which would break this for any not-yet-published app.
    #
    # Same pattern as Get-DataverseUnpublished in hso-shared-scripts, deliberately NOT routed
    # through it: this script's Invoke-DataverseWebApi wrapper adds -RethrowRaw (the catch blocks
    # here match on $_.Exception.Message) plus the "Calling:" trace, and the shared helper goes
    # straight to Invoke-DataverseApi. Keep the URL shape in step with the helper if either changes.
    $appDetailsEndpoint = "appmodules/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$filter=appmoduleid eq $($app.appmoduleid)&`$select=appmoduleid,uniquename,name,webresourceid,welcomepageid,description"
    $appDetailsResult = Invoke-DataverseWebApi -Method "GET" -Endpoint $appDetailsEndpoint -IsMetadataOperation $false
    $appDetails = if ($appDetailsResult.value -and $appDetailsResult.value.Count -gt 0) { $appDetailsResult.value[0] } else { throw "Could not retrieve app details for $($app.appmoduleid)." }

    # Get the entityid from the entity table
    $entityId = Get-EntityId -TableName $TableName

    # Get existing app elements
    $existingElements = Get-AppElements -AppModuleIdUnique $app.appmoduleidunique

    # Check if entity is already in the app
    $alreadyExists = $existingElements | Where-Object { $_.ObjectId -eq $entityId -and $_.AppElementType -eq "entity" }
    if ($alreadyExists) {
        Write-Host "  Table '$TableName' is already in the app." -ForegroundColor Yellow
        return @{ success = $true; tableName = $TableName; appName = $AppUniqueName; entityId = $entityId; alreadyExists = $true }
    }

    # Add the new entity to the elements array
    $allElements = @($existingElements)
    $allElements += @{
        "ObjectId" = $entityId
        "AppElementType" = "entity"
    }

    # Build the SaveAppModule payload
    $savePayload = @{
        "AppModule" = @{
            "@odata.type" = "#Microsoft.Dynamics.CRM.appmodule"
            "appmoduleid" = $appDetails.appmoduleid
            "uniquename" = $appDetails.uniquename
            "name" = $appDetails.name
            "webresourceid" = $appDetails.webresourceid
            "welcomepageid" = if ($appDetails.welcomepageid) { $appDetails.welcomepageid } else { "00000000-0000-0000-0000-000000000000" }
            "description" = $appDetails.description
        }
        "AppElements" = $allElements
        "IsNew" = $false
        "SolutionUniqueName" = $SolutionName
    }

    Write-Host "  Calling SaveAppModule action..." -ForegroundColor Gray
    Write-Host "  Payload contains $($allElements.Count) element(s)" -ForegroundColor DarkGray

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "SaveAppModule" -Body $savePayload -SolutionName $SolutionName -IsMetadataOperation $false

    Write-Host "  Table '$TableName' added to app!" -ForegroundColor Green
    return @{ success = $true; tableName = $TableName; appName = $AppUniqueName; entityId = $entityId; totalElements = $allElements.Count }
}

function Add-TablesToModelDrivenApp {
    <#
    .SYNOPSIS
        Adds multiple tables to an existing model-driven app in a single call.
    .DESCRIPTION
        Adds multiple tables (entities) to the app using the SaveAppModule action.
        This retrieves all existing app elements, adds all the new tables, and saves
        the complete app configuration in ONE call - avoiding the issue where
        sequential calls overwrite each other.

        WARNING: This uses an UNDOCUMENTED API (SaveAppModule) that Microsoft uses
        internally in the Maker Portal. It is NOT officially supported and may change
        without notice. Use this ONLY for initial app setup.

    .NOTES
        The SaveAppModule action requires a complete payload with ALL app elements.
        If elements are missing from the payload, they will be removed from the app.
    #>
    param(
        [string]$AppUniqueName,
        [string]$AppModuleId,
        [array]$TableNames,
        [string]$SolutionName
    )

    $appLabel = if ($AppModuleId) { $AppModuleId } else { $AppUniqueName }
    Write-Host "`n============================================" -ForegroundColor Yellow
    Write-Host "  Adding $($TableNames.Count) Tables to App '$appLabel'" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "  (Using SaveAppModule - undocumented API)" -ForegroundColor DarkYellow
    Write-Host ""

    # Get the app module with full details. Prefer direct GUID lookup when
    # AppModuleId is provided — uniquename filter sometimes misses freshly
    # created apps for several minutes after POST.
    if ($AppModuleId) {
        $app = Get-AppModuleById -AppModuleId $AppModuleId
        if (-not $app) {
            throw "App module with id '$AppModuleId' not found. Verify the GUID (lookups are unpublished-aware, so an unpublished app should still resolve)."
        }
    } else {
        $app = Get-AppModuleId -AppUniqueName $AppUniqueName
        if (-not $app) {
            $app = Get-AppModuleId -AppUniqueName "$($script:PublisherPrefix)_$AppUniqueName"
        }
        if (-not $app) {
            throw "App module '$AppUniqueName' not found. Verify the app's unique name (check App Designer > Properties). If you know the GUID, pass -AppModuleId instead. (Lookups are unpublished-aware, so an unpublished app should still resolve.)"
        }
    }

    Write-Host "  Found app: $($app.name)" -ForegroundColor Gray
    Write-Host "    appmoduleid: $($app.appmoduleid)" -ForegroundColor DarkGray

    # Get full app details for the payload. Use RetrieveUnpublishedMultiple (filter by PK)
    # rather than a plain appmodules(<id>) GET — the plain GET 404s on an unpublished app
    # (it serves published rows only), which would break this for any not-yet-published app.
    #
    # Same pattern as Get-DataverseUnpublished in hso-shared-scripts, deliberately NOT routed
    # through it: this script's Invoke-DataverseWebApi wrapper adds -RethrowRaw (the catch blocks
    # here match on $_.Exception.Message) plus the "Calling:" trace, and the shared helper goes
    # straight to Invoke-DataverseApi. Keep the URL shape in step with the helper if either changes.
    $appDetailsEndpoint = "appmodules/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$filter=appmoduleid eq $($app.appmoduleid)&`$select=appmoduleid,uniquename,name,webresourceid,welcomepageid,description"
    $appDetailsResult = Invoke-DataverseWebApi -Method "GET" -Endpoint $appDetailsEndpoint -IsMetadataOperation $false
    $appDetails = if ($appDetailsResult.value -and $appDetailsResult.value.Count -gt 0) { $appDetailsResult.value[0] } else { throw "Could not retrieve app details for $($app.appmoduleid)." }

    # Get existing app elements (sitemap, etc.)
    $existingElements = Get-AppElements -AppModuleIdUnique $app.appmoduleidunique

    # Separate sitemap from existing entities
    $sitemapElement = $existingElements | Where-Object { $_.AppElementType -eq "sitemap" }
    $existingEntityIds = ($existingElements | Where-Object { $_.AppElementType -eq "entity" }).ObjectId

    Write-Host "`n  Getting entity IDs for all tables..." -ForegroundColor Cyan

    # Build list of all entity elements (existing + new). SaveAppModule REPLACES the app's element set with the
    # payload, so every existing entity component must be carried forward whether or not it is in -TableNames.
    # (E2E round-3 remediation: a call listing only the 16 NEW tables silently dropped hso_contract from the app.)
    $entityElements = @()
    $addedTables = @()
    $skippedTables = @()
    $seenEntityIds = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($eid in @($existingEntityIds | Where-Object { $_ })) {
        if ($seenEntityIds.Add("$eid")) { $entityElements += @{ "ObjectId" = "$eid"; "AppElementType" = "entity" } }
    }
    $preservedCount = $entityElements.Count
    if ($preservedCount -gt 0) { Write-Host "  Preserving $preservedCount existing entity component(s) not necessarily in -TableNames" -ForegroundColor DarkGray }

    foreach ($tableName in $TableNames) {
        try {
            $entityId = Get-EntityId -TableName $tableName

            # Check if already exists
            if ($existingEntityIds -contains $entityId) {
                Write-Host "    [SKIP] $tableName (already in app)" -ForegroundColor DarkGray
                $skippedTables += $tableName
            } else {
                Write-Host "    [ADD]  $tableName = $entityId" -ForegroundColor Green
                $addedTables += $tableName
            }

            # Add to elements array once (existing ones were carried forward above)
            if ($seenEntityIds.Add("$entityId")) {
                $entityElements += @{
                    "ObjectId" = $entityId
                    "AppElementType" = "entity"
                }
            }
        } catch {
            Write-Host "    [ERROR] $tableName - $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Ensure the app has a sitemap. A model-driven app is INVALID until it has an
    # isappaware sitemap with at least one real-entity SubArea — it won't publish, and
    # it can't be cleanly deleted (DELETE appmodules(<id>) is blocked by the
    # appmodule_appsetting_parentappmoduleid FK on the auto-created "App channel" setting).
    # A freshly-created app (from CreateApp) has none, so provision one here, seeded with
    # the tables being added. This is what App Designer does on first open+save — replicating
    # it makes the CreateApp -> AddTablesToApp -> PublishApp flow self-sufficient.
    if (-not $sitemapElement) {
        Write-Host "`n  App has no sitemap — provisioning a default one seeded with the added tables..." -ForegroundColor Yellow
        $newSiteMapId = New-AppSiteMap -AppName $appDetails.name -AppUniqueName $appDetails.uniquename -TableNames $TableNames -SolutionName $SolutionName
        $sitemapElement = @{ "ObjectId" = $newSiteMapId; "AppElementType" = "sitemap" }
    }

    # Build complete elements array (entities + sitemap)
    $allElements = @($entityElements)
    if ($sitemapElement) {
        $allElements += $sitemapElement
    }

    # Build the SaveAppModule payload
    $savePayload = @{
        "AppModule" = @{
            "@odata.type" = "#Microsoft.Dynamics.CRM.appmodule"
            "appmoduleid" = $appDetails.appmoduleid
            "uniquename" = $appDetails.uniquename
            "name" = $appDetails.name
            "webresourceid" = $appDetails.webresourceid
            "welcomepageid" = if ($appDetails.welcomepageid) { $appDetails.welcomepageid } else { "00000000-0000-0000-0000-000000000000" }
            "description" = $appDetails.description
        }
        "AppElements" = $allElements
        "IsNew" = $false
        "SolutionUniqueName" = $SolutionName
    }

    Write-Host "`n  Calling SaveAppModule with $($allElements.Count) element(s)..." -ForegroundColor Cyan
    Write-Host "    Tables: $($entityElements.Count)" -ForegroundColor DarkGray
    Write-Host "    Sitemap: $(if ($sitemapElement) { 'Yes' } else { 'No' })" -ForegroundColor DarkGray

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "SaveAppModule" -Body $savePayload -SolutionName $SolutionName -IsMetadataOperation $false

    Write-Host "`n  [SUCCESS] All tables processed!" -ForegroundColor Green
    Write-Host "    Added: $($addedTables.Count) tables" -ForegroundColor Green
    Write-Host "    Skipped: $($skippedTables.Count) tables (already in app)" -ForegroundColor Yellow
    Write-Host "    Preserved: $preservedCount existing entity component(s)" -ForegroundColor DarkGray

    # SaveAppModule writes the UNPUBLISHED draft only. Publish the app module (+ its sitemap) now, scoped, so
    # the published generation matches what was just saved -- a draft that is never published looks correct
    # to unpublished-aware read-backs and wrong to every user (E2E round-3: the restore of hso_contract was
    # saved at 00:14:38 and never published; the verifier refuted the fix against the published generation).
    try {
        $pubXml = "<importexportxml><appmodules><appmodule>$($appDetails.appmoduleid)</appmodule></appmodules>"
        if ($sitemapElement -and $sitemapElement.ObjectId) { $pubXml += "<sitemaps><sitemap>$($sitemapElement.ObjectId)</sitemap></sitemaps>" }
        $pubXml += "</importexportxml>"
        [void](Invoke-DataverseWebApi -Method "POST" -Endpoint "PublishXml" -Body @{ "ParameterXml" = $pubXml } -IsMetadataOperation $false)
        Write-Host "  [OK] App module published (scoped PublishXml: app + sitemap)" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] SaveAppModule succeeded but the scoped publish failed ($($_.Exception.Message)) -- run PublishApp; until then the published app does not carry these tables." -ForegroundColor Yellow
        $script:WarnCount++
    }

    # Read back against the PUBLISHED generation (plain appmodules GET -- appmoduleidunique differs per generation;
    # RetrieveUnpublishedMultiple can show a draft the published app does not match).
    try {
        $pubApp = Invoke-DataverseWebApi -Method "GET" -Endpoint "appmodules?`$filter=appmoduleid eq $($appDetails.appmoduleid)&`$select=appmoduleidunique" -IsMetadataOperation $false
        if ($pubApp.value -and $pubApp.value.Count -gt 0) {
            $pubUnique = $pubApp.value[0].appmoduleidunique
            $pubComps = Invoke-DataverseWebApi -Method "GET" -Endpoint "appmodulecomponents?`$filter=_appmoduleidunique_value eq $pubUnique and componenttype eq 1&`$select=objectid" -IsMetadataOperation $false
            $pubIds = @($pubComps.value | ForEach-Object { "$($_.objectid)".ToLower() })
            $missing = @($entityElements | Where-Object { $pubIds -notcontains "$($_.ObjectId)".ToLower() })
            if ($missing.Count -eq 0) { Write-Host "  [OK] published app carries all $($entityElements.Count) entity component(s)" -ForegroundColor Green }
            else { Write-Host "  [WARN] published app is missing $($missing.Count) of $($entityElements.Count) saved entity component(s) -- publish may not have completed; re-run PublishApp and re-query" -ForegroundColor Yellow; $script:WarnCount++ }
        }
    } catch { Write-Host "  [WARN] could not read the published app's components back ($($_.Exception.Message))" -ForegroundColor Yellow }

    # #406: warn when an added table is in the app but has no sitemap sub-area (not navigable).
    if ($addedTables.Count -gt 0) {
        try {
            $smRb = (Invoke-DataverseWebApi -Method "GET" -IsMetadataOperation $false `
                -Endpoint "sitemaps/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$filter=sitemapnameunique eq '$($appDetails.uniquename)'&`$select=sitemapxml").value
            $smXml = if ($smRb -and $smRb.Count -gt 0) { "$($smRb[0].sitemapxml)" } else { "" }
            foreach ($t in $addedTables) {
                if ($smXml -notmatch ("Entity\s*=\s*[`"']" + [regex]::Escape($t) + "[`"']")) {
                    Write-Host "  [WARN] '$t' is in the app but has no sitemap sub-area -- not navigable. Add one with hso-dataverse-ui-config AddSiteMapSubArea, then PublishApp." -ForegroundColor Yellow
                    $script:WarnCount++
                }
            }
        } catch {
            Write-Host "  [WARN] could not verify sitemap navigability ($($_.Exception.Message))." -ForegroundColor Yellow
        }
    }

    return @{
        success = $true
        appName = $AppUniqueName
        addedTables = $addedTables
        skippedTables = $skippedTables
        totalElements = $allElements.Count
    }
}

function New-AppSiteMap {
    <#
    .SYNOPSIS
        Find-or-create an isappaware sitemap for an app, seeded with one SubArea per table.
        Returns the sitemapid.
    .DESCRIPTION
        A model-driven app must have an isappaware sitemap with at least one real-entity
        SubArea to be valid: publishable, usable, and cleanly deletable (otherwise
        DELETE appmodules(<id>) is blocked by the appmodule_appsetting_parentappmoduleid FK
        on the auto-created "App channel" appsetting). A freshly-created app has none — this
        provisions one, mirroring what App Designer does on first open+save.

        Reuses an existing (possibly unpublished) sitemap for the app via
        RetrieveUnpublishedMultiple before creating, so re-runs are idempotent.
    #>
    param(
        [string]$AppName,
        [string]$AppUniqueName,
        [string[]]$TableNames,
        [string]$SolutionName
    )

    # Reuse an existing sitemap for this app (unpublished-aware) if present
    $existing = (Invoke-DataverseWebApi -Method "GET" -IsMetadataOperation $false `
        -Endpoint "sitemaps/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$filter=sitemapnameunique eq '$AppUniqueName'&`$select=sitemapid").value
    if ($existing -and $existing.Count -gt 0) {
        Write-Host "    Reusing existing sitemap: $($existing[0].sitemapid)" -ForegroundColor Gray
        return $existing[0].sitemapid
    }

    # Build one SubArea per table under a single Area/Group (mirrors App Designer's XML shape)
    $subAreas = ""
    for ($i = 0; $i -lt $TableNames.Count; $i++) {
        $subAreas += '<SubArea Id="subarea_' + $i + '" Entity="' + $TableNames[$i] + '" Client="All,Outlook,OutlookLaptopClient,OutlookWorkstationClient,Web" AvailableOffline="true" PassParams="false" Sku="All,OnPremise,Live,SPLA" />'
    }
    $xml = '<SiteMap IntroducedVersion="7.0.0.0"><Area Id="area_default" ResourceId="SitemapDesigner.NewTitle" ShowGroups="true" IntroducedVersion="7.0.0.0"><Titles><Title LCID="1033" Title="Area1" /></Titles><Group Id="group_default" ResourceId="SitemapDesigner.NewGroup" IntroducedVersion="7.0.0.0" IsProfile="false"><Titles><Title LCID="1033" Title="Group1" /></Titles>' + $subAreas + '</Group></Area></SiteMap>'

    $smBody = @{
        sitemapname       = $AppName
        sitemapnameunique = $AppUniqueName
        isappaware        = $true
        sitemapxml        = $xml
    }
    $created = Invoke-DataverseWebApi -Method "POST" -Endpoint "sitemaps" -Body $smBody -SolutionName $SolutionName -IsMetadataOperation $false
    $sitemapId = $created._entityId
    if (-not $sitemapId) {
        # Fallback: read it back (unpublished-aware) if the OData-EntityId header wasn't captured
        $rb = (Invoke-DataverseWebApi -Method "GET" -IsMetadataOperation $false `
            -Endpoint "sitemaps/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$filter=sitemapnameunique eq '$AppUniqueName'&`$select=sitemapid").value
        if ($rb -and $rb.Count -gt 0) { $sitemapId = $rb[0].sitemapid }
    }
    if (-not $sitemapId) { throw "Sitemap created for '$AppUniqueName' but its id could not be resolved." }
    Write-Host "    Created sitemap: $sitemapId" -ForegroundColor Green
    return $sitemapId
}

function Get-ModelDrivenApp {
    <#
    .SYNOPSIS
        Queries details of a model-driven app.
    #>
    param([string]$AppUniqueName)

    Write-Host "`n=== Querying App: $AppUniqueName ===" -ForegroundColor Cyan

    $app = Get-AppModuleId -AppUniqueName $AppUniqueName
    if (-not $app) {
        # Try with publisher prefix
        $app = Get-AppModuleId -AppUniqueName "$($script:PublisherPrefix)_$AppUniqueName"
    }

    if ($app) {
        # Get full details. Use RetrieveUnpublishedMultiple (filtered by PK) rather than a
        # plain appmodules(<id>) GET — the plain GET 404s on an unpublished app (it serves
        # published rows only), which would break QueryApp for any not-yet-published app.
        $detailEndpoint = "appmodules/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?`$filter=appmoduleid eq $($app.appmoduleid)&`$select=name,uniquename,description,clienttype,appmoduleversion,isdefault,publishedon"
        $detailResult = Invoke-DataverseWebApi -Method "GET" -Endpoint $detailEndpoint -IsMetadataOperation $false
        $details = if ($detailResult.value -and $detailResult.value.Count -gt 0) { $detailResult.value[0] } else { $app }

        Write-Host "  Name: $($details.name)" -ForegroundColor White
        Write-Host "  Unique Name: $($details.uniquename)" -ForegroundColor Gray
        Write-Host "  Description: $($details.description)" -ForegroundColor Gray
        Write-Host "  Client Type: $($details.clienttype)" -ForegroundColor Gray
        Write-Host "  Version: $($details.appmoduleversion)" -ForegroundColor Gray
        Write-Host "  Is Default: $($details.isdefault)" -ForegroundColor Gray
        Write-Host "  Published On: $($details.publishedon)" -ForegroundColor Gray

        # Get components
        $componentsEndpoint = "appmodulecomponents?`$filter=_appmoduleidunique_value eq '$($app.appmoduleidunique)'&`$select=componenttype,objectid"
        $components = Invoke-DataverseWebApi -Method "GET" -Endpoint $componentsEndpoint -IsMetadataOperation $false

        if ($components.value) {
            Write-Host "`n  Components: $($components.value.Count)" -ForegroundColor Cyan
            foreach ($comp in $components.value) {
                $typeNames = @{1="Entity"; 26="View"; 24="Form"; 60="Dashboard"; 59="Chart"}
                $typeName = $typeNames[$comp.componenttype]
                if (-not $typeName) { $typeName = "Type $($comp.componenttype)" }
                Write-Host "    - $typeName : $($comp.objectid)" -ForegroundColor Gray
            }
        }

        return $details
    }
    else {
        Write-Host "  App not found: $AppUniqueName" -ForegroundColor Yellow
        return $null
    }
}

function Publish-ModelDrivenApp {
    <#
    .SYNOPSIS
        Publishes a model-driven app.
    .DESCRIPTION
        Publishes the app to make changes visible to users.
    #>
    param([string]$AppUniqueName)

    Write-Host "`n=== Publishing App: $AppUniqueName ===" -ForegroundColor Cyan

    $app = Get-AppModuleId -AppUniqueName $AppUniqueName
    if (-not $app) {
        # Try with publisher prefix
        $app = Get-AppModuleId -AppUniqueName "$($script:PublisherPrefix)_$AppUniqueName"
    }

    if (-not $app) {
        throw "App module '$AppUniqueName' not found. Verify the app's unique name (check App Designer > Properties) and ensure the app has been saved."
    }

    Write-Host "  Found app: $($app.name)" -ForegroundColor Gray

    # Use PublishXml action with AppModule
    $publishPayload = @{
        "ParameterXml" = "<importexportxml><appmodules><appmodule>$($app.appmoduleid)</appmodule></appmodules></importexportxml>"
    }

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "PublishXml" -Body $publishPayload -IsMetadataOperation $false

    Write-Host "  App published successfully!" -ForegroundColor Green
    return $result
}

#endregion



#region Publishing

function Publish-DataverseCustomizations {
    param([array]$Tables)

    Write-Host "`n=== Publishing Customizations ===" -ForegroundColor Cyan

    $entityList = ($Tables | ForEach-Object { "<entity>$_</entity>" }) -join ""
    $publishXml = @{
        "ParameterXml" = "<importexportxml><entities>$entityList</entities></importexportxml>"
    }

    Write-Host "  Publishing tables: $($Tables -join ', ')" -ForegroundColor Gray

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "PublishXml" -Body $publishXml -IsMetadataOperation $false

    Write-Host "  Customizations published successfully!" -ForegroundColor Green
    return $result
}

function Publish-AllCustomizations {
    Write-Host "`n=== Publishing All Customizations ===" -ForegroundColor Cyan

    $result = Invoke-DataverseWebApi -Method "POST" -Endpoint "PublishAllXml" -Body @{} -IsMetadataOperation $false

    Write-Host "  All customizations published successfully!" -ForegroundColor Green
    return $result
}

#endregion

#region Spec.json readers (declared contracts)

function Get-SpecStatusReasons {
    # statusReasons[] options for a table from a spec.json -> [{Label, State, Value?, Default?}].
    param([string]$SpecJsonPath, [string]$TableName)
    if (-not (Test-Path $SpecJsonPath)) { throw "SpecJsonPath not found: $SpecJsonPath" }
    $spec = Get-Content -Raw -Path $SpecJsonPath | ConvertFrom-Json
    $entry = $spec.statusReasons | Where-Object { $_.table -eq $TableName } | Select-Object -First 1
    if (-not $entry) { return @() }
    return @($entry.options | ForEach-Object {
        [pscustomobject]@{ Label = $_.label; State = [int]$_.state; Value = $_.value; Default = [bool]$_.default }
    })
}

function Get-SpecChoice {
    # choices[] entry for a name from a spec.json -> { Name, Options:[{Label, Value?, Color?}] }.
    param([string]$SpecJsonPath, [string]$ChoiceName)
    if (-not (Test-Path $SpecJsonPath)) { throw "SpecJsonPath not found: $SpecJsonPath" }
    $spec = Get-Content -Raw -Path $SpecJsonPath | ConvertFrom-Json
    $entry = $spec.choices | Where-Object { $_.name -eq $ChoiceName } | Select-Object -First 1
    if (-not $entry) { return $null }
    return [pscustomobject]@{
        Name        = $entry.name
        Description = $entry.description
        Options     = @($entry.options | ForEach-Object { [pscustomobject]@{ Label = $_.label; Value = $_.value; Color = $_.color } })
    }
}

function Get-SpecChoices {
    # EVERY choices[] entry from a spec.json -> [{ Name, Options:[{Label, Value?, Color?}] }, ...].
    param([string]$SpecJsonPath)
    if (-not (Test-Path $SpecJsonPath)) { throw "SpecJsonPath not found: $SpecJsonPath" }
    $spec = Get-Content -Raw -Path $SpecJsonPath | ConvertFrom-Json
    return @($spec.choices | ForEach-Object {
        [pscustomobject]@{
            Name        = $_.name
            Description = $_.description
            Options     = @($_.options | ForEach-Object { [pscustomobject]@{ Label = $_.label; Value = $_.value; Color = $_.color } })
        }
    })
}

#endregion

# Bug-403 guard: refuse a prefix-bearing create when its prefix doesn't match the target solution's
# publisher (a wrong prefix is otherwise accepted silently and only caught at grading).

function Get-DataverseSchemaPrefix {
    <#
    .SYNOPSIS
        The publisher prefix embedded in a schema name ("hsot" from "hsot_serviceagreement"), or $null.

    .DESCRIPTION
        Must agree with Test-NameAlreadyPrefixed, because the guard's job is to validate the prefix
        the create path will ACTUALLY apply. The old rule here was the bare ^([a-z][a-z0-9]*)_
        regex, which reads the first word of a compound name as a prefix: "probe_service_agreement"
        yielded "probe", matched no publisher, and the guard refused a perfectly valid create --
        reporting a prefix the caller never supplied. That is the same misreading as Bug 763,
        surfacing on the validation side instead of the naming side.

        Returning $null for an unprefixed name is the correct answer: the caller then falls back to
        the resolved publisher prefix, which is exactly what the create path is about to prepend.
    #>
    param([string]$Name)
    if (-not $Name) { return $null }
    if (-not (Test-NameAlreadyPrefixed -Name $Name)) { return $null }
    if ($Name -match '^([a-z][a-z0-9]*)_') { return $Matches[1].ToLower() }
    return $null
}

function Assert-PublisherPrefixMatchesSolution {
    # exit 1 on a confirmed prefix/publisher mismatch. Fails open (warn) if the solution is absent or
    # the lookup errors, so an infra hiccup never blocks a legitimate build.
    param(
        [Parameter(Mandatory = $true)] [string]$SolutionUniqueName,
        [Parameter(Mandatory = $true)] [string]$AppliedPrefix,
        [string]$Source = ""
    )
    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName) -or [string]::IsNullOrWhiteSpace($AppliedPrefix)) { return }

    try {
        $sol = Invoke-DataverseWebApi -Method "GET" `
            -Endpoint "solutions?`$filter=uniquename eq '$SolutionUniqueName'&`$select=solutionid,uniquename&`$expand=publisherid(`$select=customizationprefix,uniquename)" `
            -IsMetadataOperation $false
    } catch {
        Write-Host "  [WARN] Could not verify publisher prefix against solution '$SolutionUniqueName' ($($_.Exception.Message)). Proceeding without the prefix guard." -ForegroundColor Yellow
        $script:WarnCount++
        return
    }

    if (-not $sol.value -or @($sol.value).Count -eq 0) {
        return  # solution not created yet -> nothing to compare
    }

    $solPrefix    = $sol.value[0].publisherid.customizationprefix
    $solPublisher = $sol.value[0].publisherid.uniquename
    if ([string]::IsNullOrWhiteSpace($solPrefix)) { return }

    if ($AppliedPrefix.ToLower() -ne $solPrefix.ToLower()) {
        Write-Host ""
        Write-Host "  [FATAL] Publisher-prefix mismatch - refusing to build (publisher-prefix guard)." -ForegroundColor Red
        Write-Host "          Applied prefix : '$AppliedPrefix'$(if ($Source) { "  (from $Source)" })" -ForegroundColor Red
        Write-Host "          Solution       : '$SolutionUniqueName' -> publisher '$solPublisher' (prefix '$solPrefix')" -ForegroundColor Red
        Write-Host "          A component named '${AppliedPrefix}_*' would NOT belong to this solution's publisher: it would land" -ForegroundColor Yellow
        Write-Host "          under a DIFFERENT publisher (often the environment's real one), invisible to the spec, the grader," -ForegroundColor Yellow
        Write-Host "          and the scoped reset. spec.json 'publisherPrefix' is the source of truth -- pass that exact prefix" -ForegroundColor Yellow
        Write-Host "          (and target its solution), or fix the component name, then re-run." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
    Write-Host "  [PREFLIGHT] prefix '$AppliedPrefix' matches solution '$SolutionUniqueName' (publisher '$solPublisher', prefix '$solPrefix')." -ForegroundColor DarkGray
}

#region Main Execution

# Read-only inspection operations: these only GET metadata and must NOT print a
# schema-modification warning (it misleads the caller into thinking an inspection mutates state).
$readOnlyOperations = @(
    'QueryTable', 'QueryColumn', 'QueryColumnDependencies', 'QueryRelationships',
    'QueryGlobalChoice', 'QuerySolution', 'QueryApp', 'QueryAlternateKeys', 'QueryPublishers'
)
$isReadOnly = $readOnlyOperations -contains $Operation

Write-Host ""
Write-Host "========================================================================" -ForegroundColor Cyan
if ($isReadOnly) {
    Write-Host "  Dataverse Schema Inspection (read-only)" -ForegroundColor Cyan
} else {
    Write-Host "  Dataverse Schema Modification" -ForegroundColor Cyan
}
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Operation: $Operation" -ForegroundColor White
Write-Host "Environment: $EnvironmentUrl" -ForegroundColor White
Write-Host "Solution: $SolutionName" -ForegroundColor White
# Print the prefix AND where it came from. The silent-default bug was invisible precisely because
# the applied prefix was never stated; naming its source makes a wrong one obvious at a glance.
Write-Host "Publisher prefix: $($script:PublisherPrefix)  (source: $($script:PublisherPrefixSource))" -ForegroundColor White
Write-Host ""
if (-not $isReadOnly) {
    Write-Host "WARNING: This script will modify your Dataverse schema." -ForegroundColor Yellow
    Write-Host ""
}

# Authenticate interactively
$token = Get-DataverseToken -EnvironmentUrl $EnvironmentUrl
if (-not $token) {
    Write-Host "[ERROR] Failed to obtain authentication token." -ForegroundColor Red
    exit 1
}
$script:AuthToken = $token
$script:EnvironmentUrl = $EnvironmentUrl

Write-Host ""

# Pre-write environment-confirmation banner (ADR 0013 open-work note / SOP guardrail intent).
# The harness is non-interactive so this cannot PROMPT, but it echoes the WRITE TARGET so a
# misdirected environment is visible in the transcript before any schema-mutating operation.
if (-not $isReadOnly) {
    Write-Host "  [ENV] About to WRITE metadata to $EnvironmentUrl (solution $(if ($SolutionName) { $SolutionName } else { '<none>' }))." -ForegroundColor Yellow
    Write-Host "        This is a schema-mutating operation ($Operation)." -ForegroundColor Yellow
    Write-Host ""
}

# -File hardening (ADR 0025): normalize the scalar params declared untyped above to their real [bool]/[int]
# types BEFORE any function consumes them, so downstream code is unchanged and a `powershell -File` string
# form (-HasActivities $false / -Precision 5) coerces-and-warns instead of hard-failing at binding time.
$HasActivities = ConvertTo-CoercedBool -Value $HasActivities -ParamName 'HasActivities' -Default $false
$HasNotes      = ConvertTo-CoercedBool -Value $HasNotes      -ParamName 'HasNotes'      -Default $false
$Required      = ConvertTo-CoercedBool -Value $Required      -ParamName 'Required'      -Default $false
$MaxLength     = ConvertTo-CoercedInt  -Value $MaxLength     -ParamName 'MaxLength'     -Default 100
$Precision     = ConvertTo-CoercedInt  -Value $Precision     -ParamName 'Precision'     -Default 2

# File-based column batch: read clean JSON from a path instead of constructing -Columns inline (the
# #1 cascade cause in the Haiku run — botched shell/JSON escaping). Resolve here so $Columns feeds
# the prefix guard AND the dispatcher identically. ConvertFrom-Json yields PSCustomObjects, which the
# downstream $col.Name/$col.Type property access handles the same as inline hashtables.
if ($ColumnsFile) {
    if (-not (Test-Path -LiteralPath $ColumnsFile)) { throw "ColumnsFile not found: $ColumnsFile" }
    try {
        $Columns = @(Get-Content -Raw -Encoding UTF8 -LiteralPath $ColumnsFile | ConvertFrom-Json)
    } catch {
        throw "ColumnsFile '$ColumnsFile' is not valid JSON (expected a top-level array of column objects): $($_.Exception.Message)"
    }
}

# Guard a COLLAPSED / column-major columns payload (ADR 0025): a single object whose Name/Type fields
# are themselves arrays -- e.g. {"Name":["a","b"],"Type":["String","Integer"]} -- instead of an array of
# one-object-per-column. This is what produced the cryptic 'Cannot convert System.Object[] to
# System.Int32' on Precision; fail early with an actionable message naming the correct (row-major) shape.
if ($Columns) {
    $collapsed = @($Columns) | Where-Object {
        ($_.PSObject.Properties['Name'] -and $_.Name -is [System.Array]) -or
        ($_.PSObject.Properties['Type'] -and $_.Type -is [System.Array])
    }
    if ($collapsed) {
        throw ("Columns payload is column-major / collapsed: a column object has an array-valued Name or Type. " +
               "Pass an ARRAY with ONE object per column (row-major), e.g. " +
               '[{"Name":"hso_x","Type":"String"},{"Name":"hso_y","Type":"Integer"}]. ' +
               "Prefer -ColumnsFile (a UTF-8 JSON file) to avoid inline shell/JSON escaping.")
    }
}

# File-based mapping batch: same rationale as -ColumnsFile (dodge inline shell/JSON escaping).
if ($MappingsFile) {
    if (-not (Test-Path -LiteralPath $MappingsFile)) { throw "MappingsFile not found: $MappingsFile" }
    try {
        $Mappings = @(Get-Content -Raw -Encoding UTF8 -LiteralPath $MappingsFile | ConvertFrom-Json)
    } catch {
        throw "MappingsFile '$MappingsFile' is not valid JSON (expected a top-level array of {Source,Target}): $($_.Exception.Message)"
    }
}

# Bug-403 prefix guard: confirm the naming prefix matches the target solution's publisher before
# creating the first component (see Assert-PublisherPrefixMatchesSolution).
$prefixGuardOps = @(
    'CreateTable', 'AddColumn', 'AddColumns', 'CreateGlobalChoice', 'UpdateGlobalChoice',
    'CreateRelationship', 'CreatePolymorphicLookup', 'CreateAlternateKey', 'CreateWebResource',
    # Status-reason work also applies the publisher prefix -- it resolves the option-value base from
    # a publisher, so a wrong prefix seeds option values from the wrong publisher. Option values are
    # part of the data contract and expensive to correct once records exist, so guard them too.
    'AddStatusValue', 'SetLifecycle'
)
if (-not $isReadOnly -and $SolutionName -and ($prefixGuardOps -contains $Operation)) {
    $appliedPrefix = $null
    $prefixSource  = ""
    switch ($Operation) {
        'CreateTable'             { $appliedPrefix = Get-DataverseSchemaPrefix $TableName;  $prefixSource = "table name '$TableName'" }
        'AddColumn'               { $appliedPrefix = Get-DataverseSchemaPrefix $ColumnName; $prefixSource = "column '$ColumnName'" }
        'AddColumns'              {
            if ($Columns -and @($Columns).Count -gt 0) {
                $firstName = $Columns[0].Name
                $appliedPrefix = Get-DataverseSchemaPrefix $firstName
                $prefixSource = "column '$firstName'"
                # Validate EVERY column's prefix, not just the first — a mistyped prefix on a later
                # column would otherwise slip past and land under a different publisher.
                $offenders = @()
                foreach ($c in $Columns) {
                    # Null-safe: an unprefixed name yields $null here (and $appliedPrefix may be $null
                    # if column[0] was unprefixed) — a bare .ToLower() would throw BEFORE the try below,
                    # crashing the guard on the exact malformed-prefix case it exists to catch. Treat a
                    # null/empty per-column prefix as an offender; compare case-insensitively without it.
                    $cp = Get-DataverseSchemaPrefix $c.Name
                    if ([string]::IsNullOrEmpty($cp) -or -not [string]::Equals($cp, $appliedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $offenders += "$($c.Name) (prefix '$(if ($cp) { $cp } else { '<none>' })')"
                    }
                }
                if ($offenders.Count -gt 0) {
                    Write-Host ""
                    Write-Host "  [FATAL] Inconsistent column prefixes in this batch - refusing to build (publisher-prefix guard)." -ForegroundColor Red
                    Write-Host "          Batch prefix : '$appliedPrefix' (from $prefixSource)" -ForegroundColor Red
                    Write-Host "          Mismatched   : $($offenders -join '; ')" -ForegroundColor Red
                    Write-Host "          Every column must carry the same publisher prefix; a stray prefix lands under a" -ForegroundColor Yellow
                    Write-Host "          DIFFERENT publisher, invisible to the spec, the grader, and the scoped reset." -ForegroundColor Yellow
                    Write-Host "          Fix the offending column name(s) and re-run." -ForegroundColor Yellow
                    Write-Host ""
                    exit 1
                }
            }
        }
        'CreateGlobalChoice'      { $appliedPrefix = Get-DataverseSchemaPrefix $ChoiceName; $prefixSource = "choice '$ChoiceName'" }
        'UpdateGlobalChoice'      { $appliedPrefix = Get-DataverseSchemaPrefix $ChoiceName; $prefixSource = "choice '$ChoiceName'" }
        'CreateRelationship'      { $relName = if ($LookupName) { $LookupName } elseif ($RelationshipSchemaName) { $RelationshipSchemaName } else { $IntersectEntityName }; $appliedPrefix = Get-DataverseSchemaPrefix $relName; $prefixSource = "relationship/lookup '$relName'" }
        'CreatePolymorphicLookup' { $appliedPrefix = Get-DataverseSchemaPrefix $LookupName; $prefixSource = "lookup '$LookupName'" }
        'CreateAlternateKey'      { $appliedPrefix = Get-DataverseSchemaPrefix $KeySchemaName; $prefixSource = "key '$KeySchemaName'" }
        'CreateWebResource'       { $appliedPrefix = Get-DataverseSchemaPrefix $WebResourceName; $prefixSource = "web resource '$WebResourceName'" }
        'AddStatusValue'          { $appliedPrefix = Get-DataverseSchemaPrefix $TableName; $prefixSource = "table '$TableName'" }
        'SetLifecycle'            { $appliedPrefix = Get-DataverseSchemaPrefix $TableName; $prefixSource = "table '$TableName'" }
    }
    # Fall back to the RESOLVED prefix only for the ops that prepend it to an unprefixed name;
    # otherwise an unprefixed name (e.g. an OOB relationship) means stand down rather than risk a
    # false refusal. The status ops belong here: an unprefixed -TableName means they will apply the
    # resolved prefix when deriving option values, so that is the value to validate.
    $prefixFallbackOps = @('CreateTable', 'AddColumn', 'AddColumns', 'CreateGlobalChoice',
                           'CreateWebResource', 'AddStatusValue', 'SetLifecycle')
    if ([string]::IsNullOrWhiteSpace($appliedPrefix) -and ($prefixFallbackOps -contains $Operation)) {
        $appliedPrefix = $script:PublisherPrefix
        $prefixSource  = "resolved publisher prefix ($script:PublisherPrefixSource)"
    }
    if (-not [string]::IsNullOrWhiteSpace($appliedPrefix)) {
        Assert-PublisherPrefixMatchesSolution -SolutionUniqueName $SolutionName -AppliedPrefix $appliedPrefix -Source $prefixSource
    }
}
elseif (-not $isReadOnly -and -not $SolutionName -and ($prefixGuardOps -contains $Operation)) {
    # The guard needs a solution to compare the prefix against. Without -SolutionName it cannot run,
    # and it used to say nothing -- so a wrong prefix sailed through in silence. The prefix itself is
    # no longer a guessed default, but an explicit -PublisherPrefix can still disagree with the
    # solution this component will end up in, so name the gap rather than imply it was checked.
    Write-Host ""
    Write-Host "  [WARN] Publisher-prefix guard SKIPPED - no -SolutionName supplied, so there is no" -ForegroundColor Yellow
    Write-Host "         publisher to validate '$($script:PublisherPrefix)' against." -ForegroundColor Yellow
    Write-Host "         Prefix source: $($script:PublisherPrefixSource)" -ForegroundColor Yellow
    Write-Host "         Pass -SolutionName to have the prefix checked before anything is created." -ForegroundColor Yellow
    Write-Host ""
    $script:WarnCount++
}

# Execute the requested operation
try {
    switch ($Operation) {
        "CreateTable" {
            # An activity defaults HasNotes to true (activities are almost always note-enabled) unless
            # the caller explicitly passed -HasNotes. Non-activity creates keep the $false default.
            $effectiveHasNotes = $HasNotes
            if ($IsActivity -and -not $PSBoundParameters.ContainsKey('HasNotes')) {
                $effectiveHasNotes = $true
            }
            $createTableParams = @{
                TableName                = $TableName
                DisplayName              = $DisplayName
                DisplayNamePlural        = $DisplayNamePlural
                Description              = $Description
                OwnershipType            = $OwnershipType
                OrganizationOwnedApprovedBy = $OrganizationOwnedApprovedBy
                HasActivities            = $HasActivities
                HasNotes                 = $effectiveHasNotes
                SolutionName             = $SolutionName
                PrimaryColumnName        = $PrimaryColumnName
                PrimaryColumnDisplayName = $PrimaryColumnDisplayName
                PrimaryColumnMaxLength   = $PrimaryColumnMaxLength
                PrimaryColumnDescription = $PrimaryColumnDescription
            }
            if ($IsActivity)          { $createTableParams['IsActivity'] = $true }
            if ($IsAvailableOffline)  { $createTableParams['IsAvailableOffline'] = $true }
            if ($PSBoundParameters.ContainsKey('PrimaryColumnRequiredLevel'))    { $createTableParams['PrimaryColumnRequiredLevel'] = $PrimaryColumnRequiredLevel }
            if ($PSBoundParameters.ContainsKey('PrimaryColumnAutoNumberFormat')) { $createTableParams['PrimaryColumnAutoNumberFormat'] = $PrimaryColumnAutoNumberFormat }
            if ($PSBoundParameters.ContainsKey('PrimaryColumnAutoNumberSeed'))   { $createTableParams['PrimaryColumnAutoNumberSeed'] = $PrimaryColumnAutoNumberSeed }
            New-DataverseTable @createTableParams

            # Optional table icon (HSO standard: warn if missing). Compute the logical name the same way
            # New-DataverseTable does, then either set the icon or emit the optional [WARN].
            # MUST use the same helper New-DataverseTable uses, or the icon targets a name that
            # does not exist (e.g. "service_agreement" vs the created "<prefix>_service_agreement").
            $tableLogical = (Add-PublisherPrefix -Name $TableName.ToLower())
            $iconSrc = Resolve-IconSvgSource -IconSvgPath $IconSvgPath -IconSvgContent $IconSvgContent
            if ($iconSrc -or $IconVectorName) {
                $setIconParams = @{ TableName = $tableLogical; SolutionName = $SolutionName }
                if ($IconVectorName) { $setIconParams['IconVectorName'] = $IconVectorName }
                if ($iconSrc) {
                    $setIconParams['SvgContent']      = $iconSrc.Svg
                    $setIconParams['SourceLabel']     = $iconSrc.Label
                    $setIconParams['WebResourceName'] = if ($WebResourceName) { $WebResourceName } else { "${tableLogical}_icon.svg" }
                    if ($WebResourceDisplayName) { $setIconParams['WebResourceDisplayName'] = $WebResourceDisplayName }
                    if ($WebResourceDescription) { $setIconParams['WebResourceDescription'] = $WebResourceDescription }
                }
                Set-DataverseTableIcon @setIconParams
            }
            else {
                Write-IconWarning -TableName $tableLogical
            }
        }

        "CreateWebResource" {
            if (-not $WebResourceName) { throw "WebResourceName required (unique name for the SVG web resource, e.g. 'hso_contract_icon.svg')" }
            $iconSrc = Resolve-IconSvgSource -IconSvgPath $IconSvgPath -IconSvgContent $IconSvgContent
            if (-not $iconSrc) { throw "An icon source is required: pass -IconSvgPath or -IconSvgContent (your own SVG). Need a glyph? Pull one from Microsoft Fluent UI System Icons (https://github.com/microsoft/fluentui-system-icons), set fill=`"currentColor`" — see references/table-icons-web-api.md." }
            New-DataverseWebResource `
                -WebResourceName $WebResourceName `
                -SvgContent $iconSrc.Svg `
                -DisplayName $WebResourceDisplayName `
                -Description $WebResourceDescription `
                -SolutionName $SolutionName `
                -SourceLabel $iconSrc.Label
        }

        "SetTableIcon" {
            if (-not $TableName) { throw "TableName required (logical name of the custom table to set the icon on)" }
            $iconSrc = Resolve-IconSvgSource -IconSvgPath $IconSvgPath -IconSvgContent $IconSvgContent
            if (-not $iconSrc -and -not $IconVectorName) {
                throw "Pass -IconVectorName (an existing SVG web resource) or an icon source (-IconSvgPath/-IconSvgContent) with -WebResourceName."
            }
            $setIconParams = @{ TableName = $TableName; SolutionName = $SolutionName }
            if ($IconVectorName) { $setIconParams['IconVectorName'] = $IconVectorName }
            if ($iconSrc) {
                if (-not $WebResourceName) { throw "WebResourceName required when setting the icon from raw SVG." }
                $setIconParams['SvgContent']             = $iconSrc.Svg
                $setIconParams['SourceLabel']            = $iconSrc.Label
                $setIconParams['WebResourceName']        = $WebResourceName
                if ($WebResourceDisplayName) { $setIconParams['WebResourceDisplayName'] = $WebResourceDisplayName }
                if ($WebResourceDescription) { $setIconParams['WebResourceDescription'] = $WebResourceDescription }
            }
            Set-DataverseTableIcon @setIconParams
        }

        "SetAutoNumberSeed" {
            if (-not $TableName)  { throw "TableName required (the table's logical name = SetAutoNumberSeed EntityName)" }
            if (-not $ColumnName) { throw "ColumnName required (the auto-number column's logical name = SetAutoNumberSeed AttributeName)" }
            if ($AutoNumberSeedValue -lt 0) { throw "AutoNumberSeedValue required (non-negative integer, e.g. 1 for AGR-00001)" }
            Set-DataverseAutoNumberSeed -EntityName $TableName -AttributeName $ColumnName -Value $AutoNumberSeedValue
        }

        "UpdateTable" {
            $updateParams = @{ TableName = $TableName }
            if ($PSBoundParameters.ContainsKey('HasActivities')) { $updateParams['HasActivities'] = $HasActivities }
            if ($PSBoundParameters.ContainsKey('HasNotes')) { $updateParams['HasNotes'] = $HasNotes }
            if ($DisplayName) { $updateParams['DisplayName'] = $DisplayName }
            if ($DisplayNamePlural) { $updateParams['DisplayNamePlural'] = $DisplayNamePlural }
            if ($Description) { $updateParams['Description'] = $Description }
            if ($SolutionName) { $updateParams['SolutionName'] = $SolutionName }
            # IsQuickCreateEnabled: pass through when explicitly provided (null = omit = keep current).
            # The untyped $null default (script-level param) means PSBoundParameters.ContainsKey fires only
            # when the caller passed it; passing $null explicitly is treated as "omit" by Update-DataverseTable.
            if ($PSBoundParameters.ContainsKey('IsQuickCreateEnabled')) { $updateParams['IsQuickCreateEnabled'] = $IsQuickCreateEnabled }
            Update-DataverseTable @updateParams
        }

        "QueryTable" {
            Get-DataverseTable -TableName $TableName
        }

        "QueryColumn" {
            Get-DataverseColumn -TableName $TableName -ColumnName $ColumnName
        }

        "DeleteTable" {
            Remove-DataverseTable -TableName $TableName
        }

        "AddColumn" {
            $addColParams = @{
                TableName         = $TableName
                ColumnName        = $ColumnName
                ColumnDisplayName = $ColumnDisplayName
                ColumnDescription = $ColumnDescription
                ColumnType        = $ColumnType
                MaxLength         = $MaxLength
                Precision         = $Precision
                Required          = $Required
                GlobalChoiceName  = $GlobalChoiceName
                DateTimeFormat    = $DateTimeFormat
                DateTimeBehavior  = $DateTimeBehavior
                StringFormat      = $StringFormat
                DefaultValue      = $DefaultValue
                SolutionName      = $SolutionName
            }
            if ($PSBoundParameters.ContainsKey('ColumnMinValue')) { $addColParams['ColumnMinValue'] = $ColumnMinValue }
            if ($PSBoundParameters.ContainsKey('ColumnMaxValue')) { $addColParams['ColumnMaxValue'] = $ColumnMaxValue }
            # Specialized-column shapes (ADR 0057) — forwarded only when bound so unbound typed
            # defaults (e.g. [int] 0) never masquerade as declared values.
            foreach ($p in @('FormulaExpression', 'FormulaResultType', 'RollupRelatedTable', 'RollupRelationship', 'RollupLookupColumn', 'RollupAggregate', 'RollupAggregateColumn', 'RollupFilterAttribute', 'RollupFilterValue')) {
                if ($PSBoundParameters.ContainsKey($p)) { $addColParams[$p] = (Get-Variable -Name $p -ValueOnly) }
            }
            Add-DataverseColumn @addColParams
        }

        "AddColumns" {
            Add-DataverseColumns `
                -TableName $TableName `
                -Columns $Columns `
                -SolutionName $SolutionName
        }

        "DeleteColumn" {
            Remove-DataverseColumn `
                -TableName $TableName `
                -ColumnName $ColumnName `
                -Force:$Force
        }

        "QueryColumnDependencies" {
            Get-ColumnDependencies -TableName $TableName -ColumnName $ColumnName
        }

        "CreateRelationship" {
            # SOP §12 (Cascade behavior): the cascade choice must be a STATED, deliberate decision.
            # When -CascadeDelete was not explicitly bound, the RemoveLink default was *assumed*, not
            # chosen — surface that in the transcript (conservative warn-form of a gate; does NOT block).
            if (($RelationshipType -in @("OneToMany", "Customer")) -and (-not $PSBoundParameters.ContainsKey('CascadeDelete'))) {
                $script:WarnCount++
                Write-Host ""
                Write-Host "  [WARN] CascadeDelete was not specified; defaulting to '$CascadeDelete'." -ForegroundColor Yellow
                Write-Host "         Per SOP §12 (Cascade behavior) the cascade choice must be a stated, deliberate" -ForegroundColor Yellow
                Write-Host "         decision — pass -CascadeDelete explicitly (RemoveLink|Restrict|Cascade) and" -ForegroundColor Yellow
                Write-Host "         record the rationale. (Customer lookups apply this cascade to both sides.)" -ForegroundColor Yellow
                Write-Host ""
            }
            switch ($RelationshipType) {
                "OneToMany" {
                    New-OneToManyRelationship `
                        -ParentTable $ParentTable `
                        -ChildTable $ChildTable `
                        -LookupName $LookupName `
                        -LookupDisplayName $LookupDisplayName `
                        -LookupDescription $LookupDescription `
                        -CascadeDelete $CascadeDelete `
                        -CascadeAssign $CascadeAssign `
                        -RequiredLevel $RequiredLevel `
                        -SolutionName $SolutionName `
                        -RelationshipSchemaName $RelationshipSchemaName
                }
                "ManyToMany" {
                    New-ManyToManyRelationship `
                        -Entity1 $Entity1 `
                        -Entity2 $Entity2 `
                        -IntersectEntityName $IntersectEntityName `
                        -SolutionName $SolutionName
                }
                "Customer" {
                    New-CustomerRelationship `
                        -ChildTable $ChildTable `
                        -LookupName $LookupName `
                        -LookupDisplayName $LookupDisplayName `
                        -LookupDescription $LookupDescription `
                        -RequiredLevel $RequiredLevel `
                        -SolutionName $SolutionName
                }
            }
        }

        "CreatePolymorphicLookup" {
            if (-not $ChildTable)        { throw "ChildTable required" }
            if (-not $LookupName)        { throw "LookupName required" }
            if (-not $LookupDisplayName) { throw "LookupDisplayName required" }
            if (-not $TableNames -or $TableNames.Count -lt 2) { throw "TableNames required (array of 2+ entity logical names to target)" }
            New-PolymorphicLookup `
                -ChildTable $ChildTable `
                -LookupName $LookupName `
                -LookupDisplayName $LookupDisplayName `
                -LookupDescription $LookupDescription `
                -ReferencedEntities $TableNames `
                -SolutionName $SolutionName
        }

        "AddRelationshipMapping" {
            # Dual-use: read every relationships[].mappings from a spec.json, OR map an explicit
            # parent/child pair. Mappings fire only on create-from-parent-subgrid (+New).
            if ($SpecJsonPath -and -not ($Mappings -and @($Mappings).Count -gt 0)) {
                Invoke-SpecRelationshipMappings -SpecJsonPath $SpecJsonPath -SolutionName $SolutionName
                break
            }
            $parent = $ParentTable; $child = $ChildTable
            if ((-not $parent -or -not $child) -and $RelationshipSchemaName) {
                $pc = Get-RelationshipParentChild -RelationshipSchemaName $RelationshipSchemaName
                if (-not $parent) { $parent = $pc.Parent }
                if (-not $child)  { $child  = $pc.Child }
            }
            if (-not $parent -or -not $child) { throw "ParentTable and ChildTable required (or -RelationshipSchemaName / -SpecJsonPath to resolve them)." }
            if (-not $Mappings -or @($Mappings).Count -eq 0) { throw "No mappings to apply — pass -Mappings/-MappingsFile or a -SpecJsonPath with relationships[].mappings." }
            Add-RelationshipMapping -ParentTable $parent -ChildTable $child -Mappings @($Mappings) -SolutionName $SolutionName
        }

        "QueryRelationships" {
            Get-TableRelationships -TableName $TableName
        }

        "CreateGlobalChoice" {
            # -SpecJsonPath with NO -ChoiceName -> render EVERY declared choices[] entry in one call
            # (single, can't-be-garbled path; the executor never hand-passes labels inline).
            if ($SpecJsonPath -and (-not $ChoiceName)) {
                Invoke-SpecGlobalChoices -SpecJsonPath $SpecJsonPath -SolutionName $SolutionName
                break
            }
            $choiceOptions = $Options
            if ((-not $choiceOptions) -and $SpecJsonPath) {
                $specChoice = Get-SpecChoice -SpecJsonPath $SpecJsonPath -ChoiceName $ChoiceName
                if ($specChoice) { $choiceOptions = $specChoice.Options }
            }
            New-GlobalChoice `
                -ChoiceName $ChoiceName `
                -ChoiceDisplayName $ChoiceDisplayName `
                -ChoiceDescription $ChoiceDescription `
                -Options $choiceOptions `
                -SolutionName $SolutionName
        }

        "UpdateGlobalChoice" {
            $choiceOptions = $Options
            if ((-not $choiceOptions) -and $SpecJsonPath) {
                $specChoice = Get-SpecChoice -SpecJsonPath $SpecJsonPath -ChoiceName $ChoiceName
                if ($specChoice) { $choiceOptions = $specChoice.Options }
            }
            Update-GlobalChoice `
                -ChoiceName $ChoiceName `
                -Options $choiceOptions `
                -SolutionName $SolutionName
        }

        "DeleteOptionValue" {
            Remove-OptionValue `
                -ChoiceName $ChoiceName `
                -OptionValues $OptionValues `
                -SolutionName $SolutionName
        }

        "DeleteGlobalChoice" {
            Remove-GlobalChoice -ChoiceName $ChoiceName
        }

        "QueryGlobalChoice" {
            Get-GlobalChoice -ChoiceName $ChoiceName
        }

        "Publish" {
            Publish-DataverseCustomizations -Tables $TablesToPublish
        }

        "PublishAll" {
            Publish-AllCustomizations
        }

        "CreateSolution" {
            New-DataverseSolution `
                -SolutionUniqueName $SolutionUniqueName `
                -SolutionDisplayName $SolutionDisplayName `
                -SolutionDescription $SolutionDescription `
                -PublisherName $PublisherName
        }

        "QuerySolution" {
            Get-DataverseSolution -SolutionUniqueName $SolutionUniqueName
        }

        "AddTableToSolution" {
            # Coerce the (untyped) flag so the documented `-File` string symptom is tolerated
            # with a [WARN] rather than a hard [bool] transformation failure (exit 1).
            $doNotIncludeSub = ConvertTo-SolutionMembershipBool -Value $DoNotIncludeSubcomponents -ParamName 'DoNotIncludeSubcomponents' -Default $true
            Add-TableToSolution `
                -TableName $TableName `
                -SolutionName $SolutionName `
                -DoNotIncludeSubcomponents $doNotIncludeSub
        }

        "AddComponentToSolution" {
            Add-ComponentToSolution `
                -ComponentId $ComponentId `
                -ComponentType $ComponentType `
                -SolutionName $SolutionName
        }

        "UpdateColumn" {
            Update-DataverseColumn `
                -TableName $TableName `
                -ColumnName $ColumnName `
                -ColumnDisplayName $ColumnDisplayName `
                -ColumnDescription $ColumnDescription `
                -RequiredLevel $RequiredLevel `
                -IsAuditEnabled $IsAuditEnabled `
                -IsValidForAdvancedFind $IsValidForAdvancedFind `
                -ColumnMinValue $ColumnMinValue `
                -ColumnMaxValue $ColumnMaxValue `
                -MaxLength $MaxLength `
                -Precision $Precision `
                -DefaultValue $DefaultValue `
                -AutoNumberFormat $AutoNumberFormat `
                -SolutionName $SolutionName `
                -BoundParams $PSBoundParameters
        }

        "CreateApp" {
            New-ModelDrivenApp `
                -AppUniqueName $AppUniqueName `
                -AppDisplayName $AppDisplayName `
                -AppDescription $AppDescription `
                -SolutionName $SolutionName
        }

        "AddTableToApp" {
            Add-TableToModelDrivenApp `
                -AppUniqueName $AppUniqueName `
                -TableName $TableName `
                -SolutionName $SolutionName
        }

        "AddTablesToApp" {
            Add-TablesToModelDrivenApp `
                -AppModuleId $AppModuleId `
                -AppUniqueName $AppUniqueName `
                -TableNames $TableNames `
                -SolutionName $SolutionName
        }

        "QueryApp" {
            Get-ModelDrivenApp -AppUniqueName $AppUniqueName
        }

        "PublishApp" {
            Publish-ModelDrivenApp -AppUniqueName $AppUniqueName
        }

        "CreateAlternateKey" {
            New-AlternateKey `
                -TableName $TableName `
                -KeySchemaName $KeySchemaName `
                -KeyDisplayName $KeyDisplayName `
                -KeyColumns $KeyColumns `
                -SolutionName $SolutionName
        }

        "QueryAlternateKeys" {
            Get-AlternateKeys -TableName $TableName
        }

        "AddStatusValue" {
            Add-StatusValue `
                -TableName $TableName `
                -StatusLabel $StatusLabel `
                -StatusValue $StatusValue `
                -StateCode $StateCode `
                -SolutionName $SolutionName
        }

        "UpdateStatusLabel" {
            Update-StatusLabel `
                -TableName $TableName `
                -StatusValue $StatusValue `
                -NewLabel $StatusLabel `
                -SolutionName $SolutionName
        }

        "SetStatusDefault" {
            if (-not $TableName) { throw "TableName required" }
            if (-not $PSBoundParameters.ContainsKey('DefaultStatusValue')) { throw "DefaultStatusValue required (the statuscode value to make the default for -StateCode)" }
            Set-StatusDefault `
                -TableName $TableName `
                -StateCode $StateCode `
                -DefaultStatusValue $DefaultStatusValue `
                -SolutionName $SolutionName
        }

        "SetLifecycle" {
            if (-not $TableName) { throw "TableName required" }
            $reasons = $StatusReasons
            if (-not $reasons -and $SpecJsonPath) {
                $reasons = Get-SpecStatusReasons -SpecJsonPath $SpecJsonPath -TableName $TableName
            }
            if (-not $reasons -or @($reasons).Count -eq 0) {
                throw "No status reasons to set — pass -StatusReasons or a -SpecJsonPath whose statusReasons[] has an entry for table '$TableName'."
            }
            Set-Lifecycle `
                -TableName $TableName `
                -StatusReasons @($reasons) `
                -SolutionName $SolutionName
        }

        "QueryPublishers" {
            Get-AllPublishers
        }

        "CreatePublisher" {
            New-DataversePublisher `
                -DisplayName $PublisherDisplayName `
                -UniqueName $PublisherUniqueName `
                -Prefix $PublisherPrefix `
                -OptionValuePrefix $OptionValuePrefix
        }

        default {
            Write-Host "Operation not implemented: $Operation" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "`nOperation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================================================" -ForegroundColor Green
Write-Host "  Operation Complete" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Green

# Run-level [WARN] tally — turns the implicit "resolve all WARN before done" norm into a single
# observable line. Does not block; makes the count countable instead of scattered across the log.
if ($script:WarnCount -gt 0) {
    Write-Host ""
    Write-Host "  [WARN SUMMARY] $($script:WarnCount) description/standard warning(s) emitted this run — resolve before" -ForegroundColor Yellow
    Write-Host "                 considering the table done (HSO standard)." -ForegroundColor Yellow
    if ($StrictDescriptions) {
        Write-Host ""
        Write-Host "  [FATAL] -StrictDescriptions set and $($script:WarnCount) standard warning(s) remain — exiting non-zero." -ForegroundColor Red
        Write-Host ""
        exit 1
    }
}
Write-Host ""

#endregion
