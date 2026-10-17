<#
.SYNOPSIS
Shared Dataverse Web API helper functions for all skills and scripts.

.DESCRIPTION
Centralized module providing:
- Standard OData header construction with Prefer options
- Generic Invoke-DataverseApi wrapper with error handling
- Structured error extraction from Web API responses
- JSON output formatting

Dot-source this file after Dataverse-Auth.ps1:
    $sharedDir = Join-Path $PSScriptRoot "..\..\aidevme-shared-scripts\scripts"
    . "$sharedDir\Dataverse-Auth.ps1"
    . "$sharedDir\Dataverse-WebApi.ps1"
#>

# ============================================================================
# Header Construction
# ============================================================================

function Get-DataverseHeaders {
    <#
    .SYNOPSIS
    Builds standard OData headers for Dataverse Web API calls.

    .PARAMETER Token
    Bearer access token.

    .PARAMETER IncludeAnnotations
    Include OData annotations (formatted values, lookup names, etc.).

    .PARAMETER MaxPageSize
    Prefer: odata.maxpagesize value (default 5000, max 5000).

    .PARAMETER ReturnRepresentation
    Include Prefer: return=representation (returns created/updated record).

    .PARAMETER SolutionName
    If set, adds MSCRM.SolutionUniqueName header for solution-aware operations.

    .PARAMETER MergeLabels
    If set, adds MSCRM.MergeLabels header (for metadata updates).

    .OUTPUTS
    Hashtable of HTTP headers.
    #>
    param(
        [Parameter(Mandatory)][string]$Token,
        [bool]$IncludeAnnotations = $false,
        [int]$MaxPageSize = 5000,
        [bool]$ReturnRepresentation = $false,
        [string]$SolutionName,
        [bool]$MergeLabels = $false
    )

    $headers = @{
        'Authorization'    = "Bearer $Token"
        'OData-MaxVersion' = '4.0'
        'OData-Version'    = '4.0'
        'Accept'           = 'application/json'
        'Content-Type'     = 'application/json; charset=utf-8'
    }

    $preferParts = @()
    if ($IncludeAnnotations) {
        $preferParts += 'odata.include-annotations="*"'
    }
    if ($MaxPageSize -gt 0) {
        $preferParts += "odata.maxpagesize=$MaxPageSize"
    }
    if ($ReturnRepresentation) {
        $preferParts += 'return=representation'
    }
    if ($preferParts.Count -gt 0) {
        $headers['Prefer'] = ($preferParts -join ',')
    }

    if ($SolutionName) {
        $headers['MSCRM.SolutionUniqueName'] = $SolutionName
    }
    if ($MergeLabels) {
        $headers['MSCRM.MergeLabels'] = 'true'
    }

    return $headers
}

# ============================================================================
# Error Extraction
# ============================================================================

function Get-DataverseErrorDetail {
    <#
    .SYNOPSIS
    Extracts a structured error message from a Dataverse Web API error response.

    .DESCRIPTION
    Attempts to parse the error from (in order):
    1. ErrorDetails.Message (JSON with error.message)
    2. Exception.Response stream (older PowerShell / WebRequest)
    3. Exception.Message (fallback)

    .PARAMETER ErrorRecord
    The $_ error record from a catch block.

    .OUTPUTS
    String with the most descriptive error message available.
    #>
    param([Parameter(Mandatory)]$ErrorRecord)

    # Method 1: ErrorDetails.Message (PowerShell 5.1+ with Invoke-RestMethod)
    if ($ErrorRecord.ErrorDetails.Message) {
        try {
            $errorDetails = $ErrorRecord.ErrorDetails.Message | ConvertFrom-Json
            if ($errorDetails.error.message) {
                return $errorDetails.error.message
            }
        }
        catch {
            # JSON parse failed — return raw ErrorDetails
            return $ErrorRecord.ErrorDetails.Message
        }
    }

    # Method 2: Response stream (older PowerShell / WebRequest)
    if ($ErrorRecord.Exception.Response) {
        try {
            $responseStream = $ErrorRecord.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($responseStream)
            $responseBody = $reader.ReadToEnd()

            if ($responseBody) {
                $errorDetails = $responseBody | ConvertFrom-Json
                if ($errorDetails.error.message) {
                    return $errorDetails.error.message
                }
            }
        }
        catch {
            # Stream read failed — fall through
        }
    }

    # Method 3: Fallback
    return $ErrorRecord.Exception.Message
}

# ============================================================================
# Generic API Wrapper
# ============================================================================

function Invoke-DataverseApi {
    <#
    .SYNOPSIS
    Generic Dataverse Web API call with built-in error handling.

    .DESCRIPTION
    Wraps Invoke-RestMethod (or Invoke-WebRequest when ReturnHeaders is set)
    with consistent error extraction and JSON encoding.

    .PARAMETER EnvironmentUrl
    The Dataverse environment base URL. If omitted, uses the URL from the
    last Get-DataverseToken call.

    .PARAMETER Token
    Bearer access token.

    .PARAMETER Method
    HTTP method (Get, Post, Patch, Delete).

    .PARAMETER Endpoint
    Relative API endpoint (e.g., "accounts", "customapis(guid)").
    Appended to: {EnvironmentUrl}/api/data/v9.2/{Endpoint}

    .PARAMETER Body
    Object or hashtable to serialize as JSON body.

    .PARAMETER RawBody
    Pre-serialized string body (used for batch operations).

    .PARAMETER Headers
    Custom headers hashtable. If omitted, builds default headers from Token.

    .PARAMETER SolutionName
    Adds MSCRM.SolutionUniqueName header.

    .PARAMETER ReturnRepresentation
    Adds Prefer: return=representation.

    .PARAMETER IncludeAnnotations
    Adds Prefer: odata.include-annotations="*".

    .PARAMETER ReturnHeaders
    Uses Invoke-WebRequest instead of Invoke-RestMethod and returns response headers.

    .PARAMETER MergeLabels
    Adds the MSCRM.MergeLabels header (required by metadata update operations).

    .PARAMETER ExtractEntityId
    Uses Invoke-WebRequest and injects an '_entityId' property (parsed from the
    OData-EntityId response header) onto the returned object. Use after a create
    (POST) when the caller needs the new record's GUID without return=representation.
    Mutually exclusive with ReturnHeaders; ReturnHeaders takes precedence if both set.

    .PARAMETER RethrowRaw
    On failure, re-throw the original error record (preserving Exception/ErrorDetails)
    instead of the wrapped "Dataverse API Error (...)" string. Use when callers branch
    on the raw $_.Exception.Message / $_.ErrorDetails.Message of the underlying request.

    .PARAMETER RawContent
    Return the response body untouched (no ConvertFrom-Json). Required for endpoints whose
    payload is not JSON - notably a File/Image column's /$value, which returns
    application/octet-stream and arrives as a byte[]. ReturnHeaders cannot serve this case:
    it always parses Content as JSON and would throw on binary. Purely additive - no existing
    caller passes it, and the default path is unchanged.

    .OUTPUTS
    Deserialized response object (or hashtable with StatusCode/Headers/Content if ReturnHeaders).
    With ExtractEntityId, the deserialized object carries an added '_entityId' note property.
    Throws on failure with a descriptive error message.
    #>
    param(
        [string]$EnvironmentUrl,
        [string]$Token,
        [Parameter(Mandatory)][string]$Method,
        [Alias('Url','Uri','Path')]   # ADR 0025: accept the commonly-guessed names for the relative endpoint
        [Parameter(Mandatory)][string]$Endpoint,
        [object]$Body = $null,
        [string]$RawBody = $null,
        [hashtable]$Headers = $null,
        [string]$SolutionName,
        [bool]$ReturnRepresentation = $false,
        [bool]$IncludeAnnotations = $false,
        [bool]$ReturnHeaders = $false,
        [bool]$MergeLabels = $false,
        [bool]$ExtractEntityId = $false,
        [bool]$RethrowRaw = $false,
        [bool]$RawContent = $false,
        # Prefer: odata.maxpagesize. Default 5000 keeps every existing caller's behaviour byte for
        # byte. Pass 0 to omit the header entirely -- required by the bound functions that reject
        # paging preferences outright, e.g. RetrieveUnpublished answers a request carrying it with
        # "top/paging expression is not supported for this function".
        [int]$MaxPageSize = 5000
    )

    # Resolve environment URL
    if (-not $EnvironmentUrl) {
        $EnvironmentUrl = Get-DataverseEnvironmentUrl
    }
    if (-not $EnvironmentUrl) {
        throw "EnvironmentUrl is required. Authenticate first or pass -EnvironmentUrl."
    }
    $baseUrl = $EnvironmentUrl.TrimEnd('/')

    # Resolve token
    if (-not $Token) {
        $Token = $script:DvAuth_Token
    }
    if (-not $Token) {
        throw "Token is required. Authenticate first or pass -Token."
    }

    # Build URL
    $url = "$baseUrl/api/data/v9.2/$Endpoint"

    # Build headers if not provided
    if (-not $Headers) {
        $Headers = Get-DataverseHeaders -Token $Token `
            -ReturnRepresentation $ReturnRepresentation `
            -IncludeAnnotations $IncludeAnnotations `
            -SolutionName $SolutionName `
            -MergeLabels $MergeLabels `
            -MaxPageSize $MaxPageSize
    }

    try {
        $params = @{
            Uri     = $url
            Method  = $Method
            Headers = $Headers
        }

        # Serialize body
        if ($RawBody) {
            $params["Body"] = [System.Text.Encoding]::UTF8.GetBytes($RawBody)
        }
        elseif ($Body) {
            $jsonBody = $Body | ConvertTo-Json -Depth 20 -Compress
            $params["Body"] = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
        }

        if ($RawContent) {
            $response = Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop
            return $response.Content
        }
        elseif ($ReturnHeaders) {
            $response = Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop
            return @{
                StatusCode = $response.StatusCode
                Headers    = $response.Headers
                Content    = if ($response.Content) { $response.Content | ConvertFrom-Json } else { $null }
            }
        }
        elseif ($ExtractEntityId) {
            $response = Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop

            # Parse response body (204 No Content / empty -> empty object, matching the
            # data-modeling wrapper this consolidates)
            $parsedBody = if ($response.Content -and $response.Content.Trim().Length -gt 0) {
                $response.Content | ConvertFrom-Json
            } else {
                [PSCustomObject]@{}
            }

            # Inject _entityId parsed from the OData-EntityId header (returned on POST/create).
            # Header format: {baseUrl}/api/data/v9.2/entityset(GUID)
            $odataEntityId = $response.Headers["OData-EntityId"]
            if ($odataEntityId) {
                # Header value may be a string or single-element array depending on PS version
                $headerValue = if ($odataEntityId -is [array]) { $odataEntityId[0] } else { $odataEntityId }
                if ($headerValue -match '\(([0-9a-fA-F\-]{36})\)') {
                    $parsedBody | Add-Member -NotePropertyName '_entityId' -NotePropertyValue $Matches[1] -Force
                }
            }

            return $parsedBody
        }
        else {
            return Invoke-RestMethod @params -ErrorAction Stop
        }
    }
    catch {
        if ($RethrowRaw) { throw }
        $errorMessage = Get-DataverseErrorDetail -ErrorRecord $_
        throw "Dataverse API Error ($Method $Endpoint): $errorMessage"
    }
}

# ============================================================================
# OData Query URL Builder
# ============================================================================

function Build-DataverseQueryUrl {
    <#
    .SYNOPSIS
    Builds a Dataverse Web API query URL with OData parameters.

    .PARAMETER BaseUrl
    The Dataverse environment base URL.

    .PARAMETER EntitySetName
    The OData entity set name (pluralized table name).

    .PARAMETER Select
    $select columns (comma-separated).

    .PARAMETER Filter
    $filter OData expression.

    .PARAMETER OrderBy
    $orderby columns.

    .PARAMETER Expand
    $expand navigation properties.

    .PARAMETER Top
    $top N records (0 = no limit).

    .PARAMETER Skip
    $skip N records.

    .PARAMETER IncludeCount
    Include $count=true.

    .OUTPUTS
    Full URL string.
    #>
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][string]$EntitySetName,
        [string]$Select,
        [string]$Filter,
        [string]$OrderBy,
        [string]$Expand,
        [int]$Top = 0,
        [int]$Skip = 0,
        [bool]$IncludeCount = $false
    )

    $queryParts = @()
    if ($Select)       { $queryParts += "`$select=$Select" }
    if ($Filter)       { $queryParts += "`$filter=$Filter" }
    if ($OrderBy)      { $queryParts += "`$orderby=$OrderBy" }
    if ($Expand)       { $queryParts += "`$expand=$Expand" }
    if ($Top -gt 0)    { $queryParts += "`$top=$Top" }
    if ($Skip -gt 0)   { $queryParts += "`$skip=$Skip" }
    if ($IncludeCount) { $queryParts += "`$count=true" }

    $url = "$($BaseUrl.TrimEnd('/'))/api/data/v9.2/$EntitySetName"
    if ($queryParts.Count -gt 0) {
        $url += "?" + ($queryParts -join "&")
    }
    return $url
}

# ============================================================================
# JSON Output Helper
# ============================================================================

function Write-DataverseJsonOutput {
    <#
    .SYNOPSIS
    Writes data as JSON to a file or stdout.

    .PARAMETER Data
    Object to serialize.

    .PARAMETER OutputFile
    Optional file path. If omitted, writes to stdout.

    .PARAMETER Raw
    Use compressed (single-line) JSON.
    #>
    param(
        [Parameter(Mandatory)][object]$Data,
        [string]$OutputFile,
        [bool]$Raw = $false
    )

    if ($Raw) {
        $json = $Data | ConvertTo-Json -Depth 20 -Compress
    } else {
        $json = $Data | ConvertTo-Json -Depth 20
    }

    if ($OutputFile) {
        [System.IO.File]::WriteAllText($OutputFile, $json, [System.Text.Encoding]::UTF8)
        Write-Host "[OK] Output written to: $OutputFile" -ForegroundColor Green
    } else {
        Write-Output $json
    }
}

# ============================================================================
# Unpublished (draft) reads -- verify a write without publishing first
# ============================================================================

# Entity sets that RetrieveUnpublished / RetrieveUnpublishedMultiple bind to. Kept as an explicit
# allow-list so a caller reaching for an UNBOUND set gets a message naming the boundary instead of
# the platform's opaque `0x80060888 Bad Request - Error in query syntax`.
$script:DvUnpublishedEntitySets = @(
    'systemforms', 'savedqueries', 'savedqueryvisualizations', 'sitemaps', 'appmodules',
    'webresourceset', 'workflows', 'customcontroldefaultconfigs', 'appconfigs',
    'appconfiginstances', 'navigationsettings', 'desktopflowbinaries',
    'mobileofflineprofiles', 'mobileofflineprofileitems'
)

function Get-DataverseUnpublished {
    <#
    .SYNOPSIS
    Read a component's UNPUBLISHED (draft) state, so a write can be verified without publishing.

    .DESCRIPTION
    A write to a publishable component (form, view, chart, sitemap, app module, web resource,
    workflow) lands in the UNPUBLISHED layer. A plain GET keeps returning the PUBLISHED
    (pre-write) copy until PublishXml runs -- which is why callers historically published once per
    operation just so their own verification read could see the change. That per-operation publish
    is what makes a batch of edits lose races against itself server-side.

    This reads the draft directly, so the pattern becomes: verify unpublished per operation,
    publish ONCE at the end of the batch, and keep a single published read-back as the final gate.
    Do not use this AS the final gate -- an unpublished read proves the draft persisted, not that
    users can see it.

    Two forms, matching the platform:
      -Id given     -> RetrieveUnpublished        (entity-bound; composes $select ONLY)
      -Id omitted   -> RetrieveUnpublishedMultiple (collection-bound; composes full OData)

    NOT available for table/column metadata -- EntityDefinitions, GlobalOptionSetDefinitions,
    Attributes and RelationshipDefinitions are not tables and have no binding. Metadata reads are
    served published-by-default from an in-memory cache; retry there instead.

    Syntax confirmed live 2026-08-24 (see agent/work/specs/retrieve-unpublished-validation).

    .EXAMPLE
    Get-DataverseUnpublished -EntitySet 'systemforms' -Id $formId -Select formxml,name

    .EXAMPLE
    Get-DataverseUnpublished -EntitySet 'savedqueries' -Select name,fetchxml -Filter "returnedtypecode eq 'account'"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EntitySet,
        [string]$Id,
        [string[]]$Select,
        [string]$Filter,
        [int]$Top,
        [string]$EnvironmentUrl,
        [string]$Token
    )

    if ($script:DvUnpublishedEntitySets -notcontains $EntitySet.ToLower()) {
        throw ("'$EntitySet' has no RetrieveUnpublished binding. Only publishable, table-backed " +
               "components are supported: $($script:DvUnpublishedEntitySets -join ', '). " +
               "Table/column metadata (EntityDefinitions, GlobalOptionSetDefinitions, Attributes) " +
               "is NOT a table and cannot be read unpublished -- it is served published-by-default " +
               "from an in-memory cache, so retry the read instead.")
    }

    $qs = @()
    if ($Select) { $qs += '$select=' + ($Select -join ',') }

    if ($Id) {
        # The singular form is compositionType=select. Passing $filter returns
        # `0x80060888 filter expression is not supported for this function`, so say so here
        # rather than letting the platform phrase it as a syntax error.
        if ($Filter) { throw "-Filter is not supported with -Id: RetrieveUnpublished composes `$select only. Omit -Id and filter on the collection form instead." }
        if ($Top)    { throw "-Top is meaningless with -Id (a single record). Omit -Id to page a collection." }
        $clean    = $Id -replace '[{}]', ''
        $endpoint = "$EntitySet($clean)/Microsoft.Dynamics.CRM.RetrieveUnpublished()"
    }
    else {
        if ($Filter) { $qs += '$filter=' + $Filter }
        if ($Top)    { $qs += '$top=' + $Top }
        $endpoint = "$EntitySet/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()"
    }

    if ($qs.Count -gt 0) { $endpoint += '?' + ($qs -join '&') }

    $splat = @{ Method = 'GET'; Endpoint = $endpoint }
    if ($EnvironmentUrl) { $splat.EnvironmentUrl = $EnvironmentUrl }
    if ($Token)          { $splat.Token          = $Token }
    # The entity-bound form rejects a paging preference outright: the shared invoker's default
    # `Prefer: odata.maxpagesize=5000` comes back as "top/paging expression is not supported for
    # this function", which reads like a bad URL rather than a stray header. Suppress it.
    if ($Id) { $splat.MaxPageSize = 0 }
    Invoke-DataverseApi @splat
}
