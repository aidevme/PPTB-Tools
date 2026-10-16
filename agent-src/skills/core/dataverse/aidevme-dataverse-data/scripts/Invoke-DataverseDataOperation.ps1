# lint:allow-raw-invoke-file ADR 0014 documented exemption - "Left as-is". This script already
# consumes the shared Get-DataverseHeaders builder on every call, so it carries no header drift.
# Its remaining raw calls exist only for the @odata.nextLink paging loop, $batch, and binary /
# UTF-8 bodies - cases the endpoint-relative shared invoker does not cleanly cover. Revisit only
# alongside ADR 0014 itself, not as a drive-by lint fix.
<#
.SYNOPSIS
    Performs Dataverse data operations (CRUD) using the Web API.

.DESCRIPTION
    This script queries and manipulates Dataverse record data:
    - Query: Retrieve records with OData filters, expands, ordering, and paging
    - Get: Retrieve a single record by ID
    - Count: Count records matching a filter
    - Create: Create new records
    - Update: Update existing records
    - Delete: Delete a record by ID
    - BatchCreate: Create multiple records in a single request
    - Associate/Disassociate: Manage record relationships
    - FetchXml: Execute FetchXML queries

.PARAMETER Operation
    The operation to perform.

.PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com)

.EXAMPLE
    # Query active solution areas
    .\Invoke-DataverseDataOperation.ps1 -Operation Query `
        -EnvironmentUrl "https://myorg.crm.dynamics.com" `
        -EntitySetName "hso_solutionareas" `
        -Select "hso_solutionareaid,hso_name" `
        -Filter "statecode eq 0" `
        -OrderBy "hso_name"

.EXAMPLE
    # Create a record
    .\Invoke-DataverseDataOperation.ps1 -Operation Create `
        -EnvironmentUrl "https://myorg.crm.dynamics.com" `
        -EntitySetName "hso_estimatelinetemplates" `
        -JsonBody '{"hso_name":"My Template","hso_hoursestimate_dec":40}'

.NOTES
    Requires: PowerShell 5.1+, MSAL.PS module (installed automatically if missing)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Query", "Get", "Count", "Create", "Update", "Delete", "BatchCreate", "BatchUpsert", "BatchPatch", "Associate", "Disassociate", "FetchXml", "Action")]
    [string]$Operation,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentUrl,


    # Entity target
    [string]$EntitySetName,          # OData entity set name (e.g., "hso_estimatelinetemplates")

    # Query parameters
    [string]$Select,                 # $select columns (comma-separated)
    [string]$Filter,                 # $filter OData expression
    [string]$OrderBy,                # $orderby columns
    [string]$Expand,                 # $expand navigation properties
    [int]$Top = 0,                   # $top N records (0 = no limit)
    [int]$Skip = 0,                  # $skip N records
    [switch]$IncludeCount,           # Include @odata.count in response
    [switch]$IncludeAnnotations,     # Include OData annotations (formatted values, lookup names)
    [int]$MaxPageSize = 5000,        # Prefer: odata.maxpagesize (default 5000)
    [switch]$AllPages,               # Follow @odata.nextLink to retrieve all pages

    # Get/Update/Delete parameters
    [string]$RecordId,               # GUID of the record

    # Create/Update parameters
    [string]$JsonBody,               # JSON string for create/update payload
    [string]$JsonFilePath,           # Path to a JSON file for create/update payload

    # BatchCreate / BatchUpsert / BatchPatch parameters
    [string]$JsonArrayBody,          # JSON array string for batch create/upsert
    [string]$JsonArrayFilePath,      # Path to a JSON file containing an array for batch create/upsert
    [string]$PrimaryKey,             # PK field logical name for BatchUpsert (e.g. hsosol_requirementsetid)
    [int]$BatchSize = 200,           # Records per $batch changeset (default 200)
    [string]$FieldUpdatesJson,       # JSON object of field->value pairs for BatchPatch (e.g. {"field":"value"})

    # FetchXml parameter
    [string]$FetchXml,               # FetchXML query string
    [string]$FetchXmlFilePath,       # Path to a file containing FetchXML

    # Associate/Disassociate parameters
    [string]$NavigationProperty,     # Navigation property name for association
    [string]$TargetEntitySetName,    # Target entity set for association
    [string]$TargetRecordId,         # Target record GUID for association

    # Output parameters
    [string]$OutputFile,             # Write JSON output to file instead of stdout
    [switch]$Raw,                    # Output raw JSON without formatting
    [switch]$Pretty,                 # Read ops: pretty-print JSON (default is compact, to save caller context)
    [int]$MaxInlineRows = 200,       # Query/FetchXml: above this row count (and no -Top/-OutputFile) spill to a temp file instead of stdout
    [switch]$ShowBody,               # Create: also print the full created record body (default prints only [OK] + [ID] to save context)
    [switch]$ReturnId,               # Create: emit ONLY the new record's GUID on stdout (for capture: $id = ... -ReturnId)

    # Solution association (Create/Update/Batch* only)
    [string]$SolutionUniqueName,     # If set, sends MSCRM.SolutionUniqueName header so new/updated records join this solution

    # Duplicate detection (Create / Update / BatchCreate / BatchUpsert / BatchPatch)
    # Writes to duplicate-detection-enabled master tables (accounts / contacts / leads) send
    # MSCRM.SuppressDuplicateDetection:false by DEFAULT -- the duplicate-detection SOP 4.2 HSO Override,
    # because the platform silently suppresses dedupe on PATCH. Pass this switch to send :true instead
    # (skip detection) -- the deliberate bulk-migration escape hatch.
    [switch]$SuppressDuplicateDetection,

    # Action operation
    [string]$ActionName              # Unbound Dataverse action name (e.g., "AddAppComponents", "PublishXml"). Used with -Operation Action; pass body via -JsonBody or -JsonFilePath.
)

#region Shared Module Imports
$sharedDir = Join-Path $PSScriptRoot "..\..\aidevme-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"
. "$sharedDir\Dataverse-WebApi.ps1"
#endregion

#region Validation


#endregion

#region Main Execution

# Normalize environment URL
$envUrl = $EnvironmentUrl.TrimEnd('/')
if (-not $envUrl.StartsWith('https://')) { $envUrl = "https://$envUrl" }

# Authenticate using shared module
$token = Get-DataverseToken -EnvironmentUrl $envUrl
if (-not $token) {
    Write-Host "[ERROR] Failed to obtain authentication token." -ForegroundColor Red
    exit 1
}

# Helper: send one $batch changeset and report results
# Returns @{ Success = int; Failed = int }
function Send-DataverseBatch {
    param(
        [string]$EnvUrl,
        [string]$Token,
        [string]$BatchBody,
        [string]$BatchBoundary,
        [int]$RecordCount,
        [string]$Label = "BATCH",
        [string]$SolutionUniqueName
    )
    $batchUrl = "$EnvUrl/api/data/v9.2/`$batch"
    $batchHeaders = @{
        'Authorization'    = "Bearer $Token"
        'OData-MaxVersion' = '4.0'
        'OData-Version'    = '4.0'
        'Accept'           = 'application/json'
        'Content-Type'     = "multipart/mixed; boundary=$BatchBoundary"
        'Prefer'           = 'odata.continue-on-error'   # allow partial success
    }
    if ($SolutionUniqueName) { $batchHeaders['MSCRM.SolutionUniqueName'] = $SolutionUniqueName }
    $response = Invoke-WebRequest -Uri $batchUrl -Headers $batchHeaders -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($BatchBody))

    # CRITICAL: for a multipart/mixed response PowerShell 7 returns Content as a BYTE ARRAY, not a
    # string. Regex-matching it directly coerces to "System.Byte[]", so NO failure pattern ever
    # matches -- $failureCount stays 0 and every batch reports full success regardless of what
    # actually happened. Observed 2026-08-14: a 7-record changeset that failed atomically on a
    # 500-char field-length violation reported "7/7 OK" and created nothing. Decode explicitly.
    $responseBody = if ($response.Content -is [byte[]]) {
        [System.Text.Encoding]::UTF8.GetString($response.Content)
    } else { [string]$response.Content }

    $failureCount = ([regex]::Matches($responseBody, 'HTTP/1\.1 [45]\d\d')).Count

    # A changeset is ATOMIC: one rejected operation rolls the whole set back. So a single 4xx line
    # means the entire slice failed, not just one record -- counting successes as
    # (RecordCount - failureCount) silently over-reports. Treat any failure in a changeset as a
    # total failure for that slice unless the response proves otherwise.
    if ($failureCount -gt 0) {
        $successCount = 0
        $failureCount = $RecordCount
    } else {
        $successCount = $RecordCount
    }

    if ($failureCount -gt 0) {
        Write-Host "  [$Label] $successCount/$RecordCount OK, $failureCount failed" -ForegroundColor Yellow
        # Parse and deduplicate error messages from the multipart response
        $errMatches = [regex]::Matches($responseBody, '"message"\s*:\s*"([^"]{1,300})"')
        $uniqueErrors = $errMatches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
        foreach ($e in $uniqueErrors) { Write-Output "    ERROR: $e" }
        $dupHint = Get-DuplicateDetectionHint (($uniqueErrors) -join ' ')
        if ($dupHint) { Write-Host "  $dupHint" -ForegroundColor Yellow }
    } else {
        # Check for "error" keys in the response body even when no HTTP 4xx lines were matched --
        # some Dataverse rejection patterns (e.g. If-Match guard failures) don't emit a status line
        # in the format the regex expects, producing a silent false positive.
        if ($responseBody -match '"error"\s*:\s*\{') {
            Write-Host "  [$Label] WARNING: response reports OK but contains error key(s) -- possible silent failures" -ForegroundColor Yellow
            Write-Output "    DIAGNOSTIC: $($responseBody.Substring(0, [Math]::Min(500, $responseBody.Length)))"
        } else {
            Write-Host "  [$Label] $successCount/$RecordCount OK" -ForegroundColor Green
        }
    }
    return @{ Success = $successCount; Failed = $failureCount }
}

# Helper: get JSON array from file path or body string; returns an array via @()
function Get-JsonRecordArray {
    param([string]$JsonArrayFilePath, [string]$JsonArrayBody)
    $arrayJson = $null
    if ($JsonArrayFilePath -and (Test-Path $JsonArrayFilePath)) {
        $arrayJson = Get-Content -Path $JsonArrayFilePath -Raw -Encoding UTF8
    } elseif ($JsonArrayBody) {
        $arrayJson = $JsonArrayBody
    } else {
        Write-Host "[ERROR] -JsonArrayBody or -JsonArrayFilePath is required." -ForegroundColor Red; exit 1
    }
    # @() handles ConvertFrom-Json returning a PSCustomObject for a 1-element array -- but @() alone
    # is NOT enough: PowerShell UNROLLS a single-element array on `return`, so the caller received a
    # scalar, range-indexing it yielded $null, and the batch was built with 0 operations while still
    # reporting success. The leading comma returns the array itself. Observed 2026-08-14.
    return ,@($arrayJson | ConvertFrom-Json)
}

# Master-data tables that carry OOB duplicate-detection rules. Per the duplicate-detection SOP (4.2, HSO
# Override), every PATCH/POST to one of these must explicitly send MSCRM.SuppressDuplicateDetection:false --
# the platform silently suppresses dedupe on PATCH by default, which shipped duplicate-contact bugs on three
# engagements. This skill sends the header by default for these sets; -SuppressDuplicateDetection is the
# escape hatch (sends :true) for the deliberate bulk-migration case where detection must be skipped.
$script:DedupeEnabledEntitySets = @('accounts', 'contacts', 'leads')

# Returns the MSCRM.SuppressDuplicateDetection header value to send for a write, or $null to omit it.
# Also emits a one-line note so the applied behavior is observable in the run log.
function Resolve-SuppressDuplicateDetection {
    param(
        [string]$EntitySetName,
        [bool]$SuppressDuplicateDetection
    )
    if ($SuppressDuplicateDetection) {
        Write-Host "[DEDUPE] -SuppressDuplicateDetection set -- sending MSCRM.SuppressDuplicateDetection:true (duplicate detection skipped for this write)." -ForegroundColor Yellow
        return 'true'   # explicit escape hatch: skip detection (bulk migration)
    }
    $set = if ($EntitySetName) { $EntitySetName.ToLowerInvariant() } else { '' }
    if ($script:DedupeEnabledEntitySets -contains $set) {
        Write-Host "[DEDUPE] '$EntitySetName' is a duplicate-detection-enabled master table -- sending MSCRM.SuppressDuplicateDetection:false (duplicate-detection SOP 4.2 HSO Override)." -ForegroundColor Cyan
        return 'false'  # SOP default: force detection on master-data writes
    }
    return $null        # not a dedupe-enabled table -> omit the header (unchanged behavior)
}

# If an error string looks like a duplicate-detection rejection (0x80040333), returns an actionable hint
# pointing at the -SuppressDuplicateDetection escape hatch; otherwise $null. Kept narrow so an alternate-key
# violation (hard-enforced, NOT bypassable) does not falsely suggest the flag.
function Get-DuplicateDetectionHint {
    param([string]$ErrorText)
    if ($ErrorText -and ($ErrorText -match '0x80040333' -or $ErrorText -match '(?i)duplicate of the current record' -or $ErrorText -match '(?i)a duplicate record')) {
        return "[HINT] Duplicate detection blocked this write (0x80040333) -- a matching record already exists. This is a TERMINAL error: do NOT retry (route to a steward / dead-letter queue). To deliberately write anyway (this WILL create a duplicate), re-run with -SuppressDuplicateDetection. See duplicate-detection SOP 4.2 / 4.3."
    }
    return $null
}

switch ($Operation) {

    "Query" {
        if (-not $EntitySetName) { Write-Host "[ERROR] -EntitySetName is required." -ForegroundColor Red; exit 1 }

        $url = Build-DataverseQueryUrl -BaseUrl $envUrl -EntitySetName $EntitySetName `
            -Select $Select -Filter $Filter -OrderBy $OrderBy -Expand $Expand `
            -Top $Top -Skip $Skip -IncludeCount $IncludeCount.IsPresent
        $headers = Get-DataverseHeaders -Token $token -IncludeAnnotations $IncludeAnnotations.IsPresent -MaxPageSize $MaxPageSize

        Write-Host "[QUERY] $url" -ForegroundColor Cyan

        try {
            $allResults = @()
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
            $allResults += $response.value
            $totalCount = $response.'@odata.count'

            if ($AllPages.IsPresent) {
                $nextLink = $response.'@odata.nextLink'
                $pageNum = 1
                while ($nextLink) {
                    $pageNum++
                    Write-Host "  Fetching page $pageNum..." -ForegroundColor Gray
                    $response = Invoke-RestMethod -Uri $nextLink -Headers $headers -Method Get
                    $allResults += $response.value
                    $nextLink = $response.'@odata.nextLink'
                }
            }

            $output = @{ value = $allResults }
            if ($null -ne $totalCount) { $output['@odata.count'] = $totalCount }

            Write-Host "[OK] Retrieved $($allResults.Count) record(s)" -ForegroundColor Green

            # Context-token guard: a large, unbounded result set printed to stdout floods the caller's
            # context. When the caller gave neither -Top nor -OutputFile and the set exceeds the inline
            # cap, spill to a temp file and print the path + column summary instead of every row.
            if ((-not $OutputFile) -and ($Top -le 0) -and ($allResults.Count -gt $MaxInlineRows)) {
                $spill = Join-Path ([System.IO.Path]::GetTempPath()) "dataverse-query-$EntitySetName-$($allResults.Count)rows.json"
                Write-DataverseJsonOutput -Data $output -OutputFile $spill -Raw $true
                $cols = if ($allResults.Count -gt 0) { @($allResults[0].PSObject.Properties.Name) -join ', ' } else { '' }
                Write-Host "[WARN] $($allResults.Count) rows exceeds the $MaxInlineRows-row inline cap -- spilled to file to save context (not printed to stdout)." -ForegroundColor Yellow
                Write-Host "       Columns: $cols" -ForegroundColor Gray
                Write-Host "       Narrow with -Top N or a tighter -Filter, or read the file: $spill" -ForegroundColor Gray
            } else {
                Write-DataverseJsonOutput -Data $output -OutputFile $OutputFile -Raw (-not $Pretty.IsPresent)
            }
        }
        catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Query failed: $errDetail" -ForegroundColor Red
            exit 1
        }
    }

    "Get" {
        if (-not $EntitySetName) { Write-Host "[ERROR] -EntitySetName is required." -ForegroundColor Red; exit 1 }
        if (-not $RecordId) { Write-Host "[ERROR] -RecordId is required." -ForegroundColor Red; exit 1 }

        $selectPart = ""
        if ($Select) { $selectPart = "?`$select=$Select" }
        $url = "$envUrl/api/data/v9.2/$EntitySetName($RecordId)$selectPart"
        $headers = Get-DataverseHeaders -Token $token -IncludeAnnotations $IncludeAnnotations.IsPresent

        Write-Host "[GET] $url" -ForegroundColor Cyan
        try {
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
            Write-Host "[OK] Record retrieved" -ForegroundColor Green
            Write-DataverseJsonOutput -Data $response -OutputFile $OutputFile -Raw (-not $Pretty.IsPresent)
        }
        catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Get failed: $errDetail" -ForegroundColor Red
            exit 1
        }
    }

    "Count" {
        if (-not $EntitySetName) { Write-Host "[ERROR] -EntitySetName is required." -ForegroundColor Red; exit 1 }

        $headers = Get-DataverseHeaders -Token $token

        # Resolve the logical entity name from EntityDefinitions
        $edUrl = "$envUrl/api/data/v9.2/EntityDefinitions?`$select=LogicalName&`$filter=EntitySetName eq '$EntitySetName'"
        try {
            $edResponse = Invoke-RestMethod -Uri $edUrl -Headers $headers -Method Get
            $logicalName = $edResponse.value[0].LogicalName
        }
        catch {
            Write-Host "[ERROR] Could not resolve logical name for '$EntitySetName': $(Get-DataverseErrorDetail -ErrorRecord $_)" -ForegroundColor Red
            exit 1
        }

        # Use FetchXML aggregate count to bypass the 5000-row paging limit
        $q = [char]34  # double-quote character for XML attributes
        $fetchXml = "<fetch aggregate=${q}true${q}><entity name=${q}${logicalName}${q}><attribute name=${q}${logicalName}id${q} alias=${q}count${q} aggregate=${q}count${q}/>"
        if ($Filter) {
            # Convert simple OData filter to FetchXML condition (supports basic 'eq' filters)
            # For complex filters, callers should use FetchXml operation directly
            $fetchXml += "<filter>"
            foreach ($part in ($Filter -split ' and ')) {
                $part = $part.Trim()
                if ($part -match '^(\S+)\s+eq\s+(.+)$') {
                    $attr = $Matches[1]; $val = $Matches[2].Trim("'")
                    # Count builds a FetchXML aggregate, which references a lookup by its LOGICAL name
                    # (hsot_x_id) -- the opposite of the OData _<x>_value form that Query/$filter wants.
                    # Auto-rewrite so a filter copied straight from a Query call works here instead of
                    # failing with "Could not find a property named '_x_value'".
                    if ($attr -match '^_(.+)_value$') {
                        $rewritten = $Matches[1]
                        Write-Host "[WARN] Count uses FetchXML: rewrote lookup filter '$attr' -> '$rewritten' (FetchXML wants the logical name, not the OData _x_value form)." -ForegroundColor Yellow
                        $attr = $rewritten
                    }
                    $fetchXml += "<condition attribute=${q}${attr}${q} operator=${q}eq${q} value=${q}${val}${q}/>"
                }
            }
            $fetchXml += "</filter>"
        }
        $fetchXml += "</entity></fetch>"

        $url = "$envUrl/api/data/v9.2/$EntitySetName"

        Write-Host "[COUNT] Using FetchXML aggregate on '$logicalName'" -ForegroundColor Cyan
        try {
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -Body @{ fetchXml = $fetchXml }
            $count = $response.value[0].count
            Write-Host "[OK] Count: $count" -ForegroundColor Green
            Write-Output $count
        }
        catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Count failed: $errDetail" -ForegroundColor Red
            exit 1
        }
    }

    "Create" {
        if (-not $EntitySetName) { Write-Host "[ERROR] -EntitySetName is required." -ForegroundColor Red; exit 1 }

        # Get payload from JsonBody or JsonFilePath
        $payload = $null
        if ($JsonFilePath -and (Test-Path $JsonFilePath)) {
            $payload = Get-Content -Path $JsonFilePath -Raw -Encoding UTF8
        } elseif ($JsonBody) {
            $payload = $JsonBody
        } else {
            Write-Host "[ERROR] -JsonBody or -JsonFilePath is required." -ForegroundColor Red; exit 1
        }

        $url = "$envUrl/api/data/v9.2/$EntitySetName"
        $headers = Get-DataverseHeaders -Token $token -ReturnRepresentation $true -IncludeAnnotations $IncludeAnnotations.IsPresent -SolutionName $SolutionUniqueName
        $sdd = Resolve-SuppressDuplicateDetection -EntitySetName $EntitySetName -SuppressDuplicateDetection $SuppressDuplicateDetection.IsPresent
        if ($sdd) { $headers['MSCRM.SuppressDuplicateDetection'] = $sdd }

        Write-Host "[CREATE] $EntitySetName" -ForegroundColor Cyan
        try {
            # Use Invoke-WebRequest (not Invoke-RestMethod -ResponseHeadersVariable) so this runs on
            # Windows PowerShell 5.1 as well as 7+. -ResponseHeadersVariable is a PowerShell 7-only
            # parameter and throws "A parameter cannot be found that matches parameter name
            # ResponseHeadersVariable" under 5.1 (the edition `powershell.exe` launches). Invoke-WebRequest
            # exposes both the body (.Content) and the response headers (.Headers) on every edition; the
            # header-reading block below already tolerates 5.1's string vs 7's string[] header values.
            $webResponse = Invoke-WebRequest -Uri $url -Headers $headers -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -UseBasicParsing
            $createHeaders = $webResponse.Headers
            $response = if ($webResponse.Content) { $webResponse.Content | ConvertFrom-Json } else { $null }
            Write-Host "[OK] Record created" -ForegroundColor Green

            # Capture the new record's GUID so it can be threaded into child records (parent->child
            # seeding: create the parent, capture its id, then create children bound to it). We request
            # Prefer: return=representation (above), so the full record body comes back -- read the id
            # from MULTIPLE sources in priority order and only fail if ALL are absent. The header-only
            # path used to be the sole source and non-deterministically returned nothing even though the
            # representation body clearly carried the PK (the iteration-3 P5-1 half-applied-state bug).
            $newId = $null
            # 1. Representation body's @odata.id (".../entityset(<guid>)") -- present when return=representation is honored.
            if ($response -and $response.'@odata.id' -and ([string]$response.'@odata.id' -match '\(([0-9a-fA-F-]{36})\)')) { $newId = $Matches[1] }
            # 2. OData-EntityId / Location response header.
            if (-not $newId -and $createHeaders) {
                $loc = $createHeaders['OData-EntityId']; if (-not $loc) { $loc = $createHeaders['Location'] }
                if ($loc) { $locStr = [string]($loc | Select-Object -First 1); if ($locStr -match '\(([0-9a-fA-F-]{36})\)') { $newId = $Matches[1] } }
            }
            # 3. The primary-key field in the representation body. This is the source that was present on
            #    the call where 1 & 2 came up empty. Prefer the exact PK name derived from the entity set
            #    (singular + 'id', e.g. hsot_serviceagreements -> hsot_serviceagreementid); fall back to a
            #    generic scan for a top-level GUID property named '*id' (lookups are '_x_value', excluded
            #    by the no-leading-underscore guard; '@odata.*' excluded).
            if (-not $newId -and $response) {
                $pkGuess = ($EntitySetName -replace 'ies$', 'y' -replace 's$', '') + 'id'
                $pkProp = $response.PSObject.Properties | Where-Object { $_.Name -eq $pkGuess -and ($_.Value -is [string]) -and ($_.Value -match '^[0-9a-fA-F-]{36}$') } | Select-Object -First 1
                if (-not $pkProp) {
                    $pkProp = $response.PSObject.Properties | Where-Object {
                        $_.Name -match '^[a-z][a-z0-9_]*id$' -and $_.Name -notlike '_*' -and $_.Name -notlike '*@*' -and
                        ($_.Value -is [string]) -and ($_.Value -match '^[0-9a-fA-F-]{36}$')
                    } | Select-Object -First 1
                }
                if ($pkProp) { $newId = $pkProp.Value }
            }
            if ($newId) { Write-Host "[ID] $newId" -ForegroundColor Green }

            if ($ReturnId) {
                if ($newId) { Write-Output $newId }
                else {
                    # Loud + actionable: the record almost certainly WAS created (the POST returned 2xx),
                    # so a blind re-run would DUPLICATE it. Tell the caller how to recover the id rather
                    # than leaving them to orphan the parent in a half-applied seed.
                    Write-Host "[ERROR] -ReturnId set but the new record id could not be determined from the create response (header, @odata.id, and PK field all absent)." -ForegroundColor Red
                    Write-Host "        The record was likely created (POST succeeded) -- do NOT blind-retry (no dedupe = duplicate). Recover the id with a Retrieve filtered on a known field, then continue seeding children." -ForegroundColor Yellow
                    exit 1
                }
            }
            elseif ($ShowBody -or $OutputFile) {
                # Full record body only on explicit opt-in (-ShowBody) or when redirected to a file.
                Write-DataverseJsonOutput -Data $response -OutputFile $OutputFile -Raw (-not $Pretty.IsPresent)
            }
            # Default: terse. The [OK] + [ID] lines above are the whole result -- the full record body
            # is suppressed to save the caller's context (a create rarely needs the echoed row back).
        }
        catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Create failed: $errDetail" -ForegroundColor Red
            $dupHint = Get-DuplicateDetectionHint $errDetail
            if ($dupHint) { Write-Host $dupHint -ForegroundColor Yellow }
            exit 1
        }
    }

    "Update" {
        if (-not $EntitySetName) { Write-Host "[ERROR] -EntitySetName is required." -ForegroundColor Red; exit 1 }
        if (-not $RecordId) { Write-Host "[ERROR] -RecordId is required." -ForegroundColor Red; exit 1 }

        $payload = $null
        if ($JsonFilePath -and (Test-Path $JsonFilePath)) {
            $payload = Get-Content -Path $JsonFilePath -Raw -Encoding UTF8
        } elseif ($JsonBody) {
            $payload = $JsonBody
        } else {
            Write-Host "[ERROR] -JsonBody or -JsonFilePath is required." -ForegroundColor Red; exit 1
        }

        $url = "$envUrl/api/data/v9.2/$EntitySetName($RecordId)"
        $headers = Get-DataverseHeaders -Token $token -SolutionName $SolutionUniqueName
        $sdd = Resolve-SuppressDuplicateDetection -EntitySetName $EntitySetName -SuppressDuplicateDetection $SuppressDuplicateDetection.IsPresent
        if ($sdd) { $headers['MSCRM.SuppressDuplicateDetection'] = $sdd }

        Write-Host "[UPDATE] $EntitySetName($RecordId)" -ForegroundColor Cyan
        try {
            Invoke-RestMethod -Uri $url -Headers $headers -Method Patch -Body ([System.Text.Encoding]::UTF8.GetBytes($payload))
            Write-Host "[OK] Record updated" -ForegroundColor Green
        }
        catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Update failed: $errDetail" -ForegroundColor Red
            $dupHint = Get-DuplicateDetectionHint $errDetail
            if ($dupHint) { Write-Host $dupHint -ForegroundColor Yellow }
            exit 1
        }
    }

    "Delete" {
        if (-not $EntitySetName) { Write-Host "[ERROR] -EntitySetName is required." -ForegroundColor Red; exit 1 }
        if (-not $RecordId) { Write-Host "[ERROR] -RecordId is required." -ForegroundColor Red; exit 1 }

        $url = "$envUrl/api/data/v9.2/$EntitySetName($RecordId)"
        $headers = Get-DataverseHeaders -Token $token

        Write-Host "[DELETE] $EntitySetName($RecordId)" -ForegroundColor Cyan
        try {
            Invoke-RestMethod -Uri $url -Headers $headers -Method Delete
            Write-Host "[OK] Record deleted" -ForegroundColor Green
        }
        catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Delete failed: $errDetail" -ForegroundColor Red
            exit 1
        }
    }

    "BatchCreate" {
        if (-not $EntitySetName) { Write-Host "[ERROR] -EntitySetName is required." -ForegroundColor Red; exit 1 }
        $records = Get-JsonRecordArray -JsonArrayFilePath $JsonArrayFilePath -JsonArrayBody $JsonArrayBody
        $totalCount = $records.Count
        $batchCount = [math]::Ceiling($totalCount / $BatchSize)
        Write-Host "[BATCH CREATE] $totalCount records into $EntitySetName ($batchCount batch(es) x $BatchSize)" -ForegroundColor Cyan
        $sdd = Resolve-SuppressDuplicateDetection -EntitySetName $EntitySetName -SuppressDuplicateDetection $SuppressDuplicateDetection.IsPresent
        $sddLine = if ($sdd) { "MSCRM.SuppressDuplicateDetection: $sdd`r`n" } else { '' }

        $totalSuccess = 0; $totalFailed = 0
        for ($b = 0; $b -lt $batchCount; $b++) {
            # @() guards the single-record case: ConvertFrom-Json unrolls a 1-element array to a
            # scalar PSCustomObject, and range-indexing a scalar yields $null -- the batch was then
            # built with 0 operations and still reported "0/0 OK". Observed 2026-08-14.
            $slice = @($records[($b * $BatchSize)..([math]::Min(($b + 1) * $BatchSize - 1, $totalCount - 1))])
            if ($slice.Count -eq 0) {
                Write-Output "[ERROR] Batch $($b+1) resolved to 0 records from $totalCount input record(s) -- aborting rather than reporting a false success."
                exit 1
            }
            $batchBoundary = "batch_$([guid]::NewGuid().ToString())"
            $changesetBoundary = "changeset_$([guid]::NewGuid().ToString())"
            $batchBody = "--$batchBoundary`r`n"
            $batchBody += "Content-Type: multipart/mixed; boundary=$changesetBoundary`r`n`r`n"
            $contentId = 1
            foreach ($record in $slice) {
                $recordJson = $record | ConvertTo-Json -Depth 10 -Compress
                $batchBody += "--$changesetBoundary`r`n"
                $batchBody += "Content-Type: application/http`r`nContent-Transfer-Encoding: binary`r`nContent-ID: $contentId`r`n`r`n"
                $batchBody += "POST $envUrl/api/data/v9.2/$EntitySetName HTTP/1.1`r`n"
                $batchBody += "Content-Type: application/json; charset=utf-8`r`nAccept: application/json`r`n$sddLine`r`n"
                $batchBody += "$recordJson`r`n"
                $contentId++
            }
            $batchBody += "--$changesetBoundary--`r`n--$batchBoundary--`r`n"
            Write-Host "  Batch $($b+1)/$batchCount ($($slice.Count) records)..." -ForegroundColor Gray -NoNewline
            try {
                $result = Send-DataverseBatch -EnvUrl $envUrl -Token $token -BatchBody $batchBody -BatchBoundary $batchBoundary -RecordCount $slice.Count -Label "B$($b+1)" -SolutionUniqueName $SolutionUniqueName
                $totalSuccess += $result.Success; $totalFailed += $result.Failed
            } catch {
                Write-Output "[ERROR] Batch $($b+1) failed: $($_.Exception.Message)"; exit 1
            }
        }
        if ($totalFailed -gt 0) {
            # ADR 0025 — honest reporting: a partial/total failure must NOT pass as success. Exit non-zero
            # so the caller (and the runner/grader) sees the failure instead of a green log line.
            Write-Output "[FAILED] BatchCreate: $totalSuccess loaded, $totalFailed FAILED of $totalCount"
            exit 1
        } else {
            Write-Output "[OK] BatchCreate: $totalSuccess record(s) loaded"
        }
    }

    "BatchUpsert" {
        # Creates or updates records using PATCH with caller-specified GUIDs (Dataverse upsert pattern)
        # Important: PATCH is the correct verb for upsert inside $batch. PUT returns HTTP 405.
        if (-not $EntitySetName) { Write-Host "[ERROR] -EntitySetName is required." -ForegroundColor Red; exit 1 }
        if (-not $PrimaryKey) { Write-Host "[ERROR] -PrimaryKey is required (e.g. hsosol_requirementsetid)." -ForegroundColor Red; exit 1 }
        $records = Get-JsonRecordArray -JsonArrayFilePath $JsonArrayFilePath -JsonArrayBody $JsonArrayBody
        $totalCount = $records.Count
        $batchCount = [math]::Ceiling($totalCount / $BatchSize)
        Write-Host "[BATCH UPSERT] $totalCount records into $EntitySetName ($batchCount batch(es) x $BatchSize)" -ForegroundColor Cyan
        $sdd = Resolve-SuppressDuplicateDetection -EntitySetName $EntitySetName -SuppressDuplicateDetection $SuppressDuplicateDetection.IsPresent
        $sddLine = if ($sdd) { "MSCRM.SuppressDuplicateDetection: $sdd`r`n" } else { '' }

        $totalSuccess = 0; $totalFailed = 0
        for ($b = 0; $b -lt $batchCount; $b++) {
            # @() guards the single-record case: ConvertFrom-Json unrolls a 1-element array to a
            # scalar PSCustomObject, and range-indexing a scalar yields $null -- the batch was then
            # built with 0 operations and still reported "0/0 OK". Observed 2026-08-14.
            $slice = @($records[($b * $BatchSize)..([math]::Min(($b + 1) * $BatchSize - 1, $totalCount - 1))])
            if ($slice.Count -eq 0) {
                Write-Output "[ERROR] Batch $($b+1) resolved to 0 records from $totalCount input record(s) -- aborting rather than reporting a false success."
                exit 1
            }
            $batchBoundary = "batch_$([guid]::NewGuid().ToString())"
            $changesetBoundary = "changeset_$([guid]::NewGuid().ToString())"
            $batchBody = "--$batchBoundary`r`n"
            $batchBody += "Content-Type: multipart/mixed; boundary=$changesetBoundary`r`n`r`n"
            $contentId = 1
            foreach ($record in $slice) {
                # Extract PK GUID using PSObject.Properties to avoid PSCustomObject[$key] returning null
                $pkValue = $record.PSObject.Properties[$PrimaryKey].Value
                if (-not $pkValue) { Write-Host "[ERROR] Record missing PrimaryKey field '$PrimaryKey'" -ForegroundColor Red; exit 1 }
                # Build payload without the PK field (Dataverse upsert: PK goes in URL, not body)
                $payload = [ordered]@{}
                $record.PSObject.Properties | Where-Object { $_.Name -ne $PrimaryKey } | ForEach-Object { $payload[$_.Name] = $_.Value }
                $recordJson = $payload | ConvertTo-Json -Depth 10 -Compress
                $batchBody += "--$changesetBoundary`r`n"
                $batchBody += "Content-Type: application/http`r`nContent-Transfer-Encoding: binary`r`nContent-ID: $contentId`r`n`r`n"
                $batchBody += "PATCH $envUrl/api/data/v9.2/$EntitySetName($pkValue) HTTP/1.1`r`n"
                $batchBody += "Content-Type: application/json; charset=utf-8`r`nAccept: application/json`r`n$sddLine`r`n"
                $batchBody += "$recordJson`r`n"
                $contentId++
            }
            $batchBody += "--$changesetBoundary--`r`n--$batchBoundary--`r`n"
            Write-Host "  Batch $($b+1)/$batchCount ($($slice.Count) records)..." -ForegroundColor Gray -NoNewline
            try {
                $result = Send-DataverseBatch -EnvUrl $envUrl -Token $token -BatchBody $batchBody -BatchBoundary $batchBoundary -RecordCount $slice.Count -Label "B$($b+1)" -SolutionUniqueName $SolutionUniqueName
                $totalSuccess += $result.Success; $totalFailed += $result.Failed
            } catch {
                Write-Output "[ERROR] Batch $($b+1) failed: $($_.Exception.Message)"; exit 1
            }
        }
        if ($totalFailed -gt 0) {
            # ADR 0025 — honest reporting: surface a failed batch as a non-zero exit, not a green log line.
            Write-Output "[FAILED] BatchUpsert: $totalSuccess upserted, $totalFailed FAILED of $totalCount"
            exit 1
        } else {
            Write-Output "[OK] BatchUpsert: $totalSuccess record(s) upserted"
        }
    }

    "BatchPatch" {
        # Bulk-updates a set of fields on existing records matching a filter
        if (-not $EntitySetName) { Write-Host "[ERROR] -EntitySetName is required." -ForegroundColor Red; exit 1 }
        if (-not $PrimaryKey) { Write-Host "[ERROR] -PrimaryKey is required (e.g. hsosol_plannodedefinitionid)." -ForegroundColor Red; exit 1 }
        if (-not $FieldUpdatesJson) { Write-Host "[ERROR] -FieldUpdatesJson is required (e.g. '{`"hsosol_level_num`":1}')." -ForegroundColor Red; exit 1 }
        $fieldUpdates = @($FieldUpdatesJson | ConvertFrom-Json)[0]

        # Query record IDs using the provided filter
        $selectParam = "`$select=$PrimaryKey"
        $queryUrl = "$envUrl/api/data/v9.2/$EntitySetName?$selectParam"
        if ($Filter) { $queryUrl += "&`$filter=$Filter" }
        $queryHeaders = Get-DataverseHeaders -Token $token
        Write-Host "[BATCH PATCH] Querying records from $EntitySetName..." -ForegroundColor Cyan
        $queryResponse = Invoke-RestMethod -Uri $queryUrl -Headers $queryHeaders -Method Get
        $records = @($queryResponse.value)
        $totalCount = $records.Count
        if ($totalCount -eq 0) { Write-Host "  No records found matching filter" -ForegroundColor Yellow; exit 0 }

        $batchCount = [math]::Ceiling($totalCount / $BatchSize)
        Write-Host "[BATCH PATCH] $totalCount records to update ($batchCount batch(es) x $BatchSize)" -ForegroundColor Cyan
        $updateJson = $fieldUpdates | ConvertTo-Json -Depth 5 -Compress
        $sdd = Resolve-SuppressDuplicateDetection -EntitySetName $EntitySetName -SuppressDuplicateDetection $SuppressDuplicateDetection.IsPresent
        $sddLine = if ($sdd) { "MSCRM.SuppressDuplicateDetection: $sdd`r`n" } else { '' }

        $totalSuccess = 0; $totalFailed = 0
        for ($b = 0; $b -lt $batchCount; $b++) {
            # @() guards the single-record case: ConvertFrom-Json unrolls a 1-element array to a
            # scalar PSCustomObject, and range-indexing a scalar yields $null -- the batch was then
            # built with 0 operations and still reported "0/0 OK". Observed 2026-08-14.
            $slice = @($records[($b * $BatchSize)..([math]::Min(($b + 1) * $BatchSize - 1, $totalCount - 1))])
            if ($slice.Count -eq 0) {
                Write-Output "[ERROR] Batch $($b+1) resolved to 0 records from $totalCount input record(s) -- aborting rather than reporting a false success."
                exit 1
            }
            $batchBoundary = "batch_$([guid]::NewGuid().ToString())"
            $changesetBoundary = "changeset_$([guid]::NewGuid().ToString())"
            $batchBody = "--$batchBoundary`r`n"
            $batchBody += "Content-Type: multipart/mixed; boundary=$changesetBoundary`r`n`r`n"
            $contentId = 1
            foreach ($record in $slice) {
                $pkValue = $record.PSObject.Properties[$PrimaryKey].Value
                $batchBody += "--$changesetBoundary`r`n"
                $batchBody += "Content-Type: application/http`r`nContent-Transfer-Encoding: binary`r`nContent-ID: $contentId`r`n`r`n"
                $batchBody += "PATCH $envUrl/api/data/v9.2/$EntitySetName($pkValue) HTTP/1.1`r`n"
                $batchBody += "Content-Type: application/json; charset=utf-8`r`nAccept: application/json`r`n$sddLine`r`n"
                $batchBody += "$updateJson`r`n"
                $contentId++
            }
            $batchBody += "--$changesetBoundary--`r`n--$batchBoundary--`r`n"
            Write-Host "  Batch $($b+1)/$batchCount ($($slice.Count) records)..." -ForegroundColor Gray -NoNewline
            try {
                $result = Send-DataverseBatch -EnvUrl $envUrl -Token $token -BatchBody $batchBody -BatchBoundary $batchBoundary -RecordCount $slice.Count -Label "B$($b+1)" -SolutionUniqueName $SolutionUniqueName
                $totalSuccess += $result.Success; $totalFailed += $result.Failed
            } catch {
                Write-Output "[ERROR] Batch $($b+1) failed: $($_.Exception.Message)"; exit 1
            }
        }
        if ($totalFailed -gt 0) {
            # ADR 0025 -- honest reporting: surface a failed batch as a non-zero exit, not a green/soft line
            # (was a [WARNING] + exit 0). A duplicate-detection rejection (0x80040333) on a master-data PATCH
            # now correctly fails the run instead of passing as success.
            Write-Output "[FAILED] BatchPatch: $totalSuccess updated, $totalFailed FAILED of $totalCount"
            exit 1
        } else {
            Write-Output "[OK] BatchPatch: $totalSuccess record(s) updated"
        }
    }

    "Associate" {
        if (-not $EntitySetName) { Write-Host "[ERROR] -EntitySetName is required." -ForegroundColor Red; exit 1 }
        if (-not $RecordId) { Write-Host "[ERROR] -RecordId is required." -ForegroundColor Red; exit 1 }
        if (-not $NavigationProperty) { Write-Host "[ERROR] -NavigationProperty is required." -ForegroundColor Red; exit 1 }
        if (-not $TargetEntitySetName) { Write-Host "[ERROR] -TargetEntitySetName is required." -ForegroundColor Red; exit 1 }
        if (-not $TargetRecordId) { Write-Host "[ERROR] -TargetRecordId is required." -ForegroundColor Red; exit 1 }

        $url = "$envUrl/api/data/v9.2/$EntitySetName($RecordId)/$NavigationProperty/`$ref"
        $headers = Get-DataverseHeaders -Token $token
        $body = @{ '@odata.id' = "$envUrl/api/data/v9.2/$TargetEntitySetName($TargetRecordId)" } | ConvertTo-Json

        Write-Host "[ASSOCIATE] $EntitySetName($RecordId) -> $TargetEntitySetName($TargetRecordId) via $NavigationProperty" -ForegroundColor Cyan
        try {
            Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
            Write-Host "[OK] Association created" -ForegroundColor Green
        }
        catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Associate failed: $errDetail" -ForegroundColor Red
            exit 1
        }
    }

    "Disassociate" {
        if (-not $EntitySetName) { Write-Host "[ERROR] -EntitySetName is required." -ForegroundColor Red; exit 1 }
        if (-not $RecordId) { Write-Host "[ERROR] -RecordId is required." -ForegroundColor Red; exit 1 }
        if (-not $NavigationProperty) { Write-Host "[ERROR] -NavigationProperty is required." -ForegroundColor Red; exit 1 }
        if (-not $TargetRecordId) { Write-Host "[ERROR] -TargetRecordId is required." -ForegroundColor Red; exit 1 }

        $url = "$envUrl/api/data/v9.2/$EntitySetName($RecordId)/$NavigationProperty($TargetRecordId)/`$ref"
        $headers = Get-DataverseHeaders -Token $token

        Write-Host "[DISASSOCIATE] $EntitySetName($RecordId) -X- $TargetRecordId via $NavigationProperty" -ForegroundColor Cyan
        try {
            Invoke-RestMethod -Uri $url -Headers $headers -Method Delete
            Write-Host "[OK] Association removed" -ForegroundColor Green
        }
        catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Disassociate failed: $errDetail" -ForegroundColor Red
            exit 1
        }
    }

    "FetchXml" {
        if (-not $EntitySetName) { Write-Host "[ERROR] -EntitySetName is required." -ForegroundColor Red; exit 1 }

        $fetchContent = $null
        if ($FetchXmlFilePath -and (Test-Path $FetchXmlFilePath)) {
            $fetchContent = Get-Content -Path $FetchXmlFilePath -Raw -Encoding UTF8
        } elseif ($FetchXml) {
            $fetchContent = $FetchXml
        } else {
            Write-Host "[ERROR] -FetchXml or -FetchXmlFilePath is required." -ForegroundColor Red; exit 1
        }

        $encodedFetch = [System.Uri]::EscapeDataString($fetchContent)
        $url = "$envUrl/api/data/v9.2/$EntitySetName?fetchXml=$encodedFetch"
        $headers = Get-DataverseHeaders -Token $token -IncludeAnnotations $IncludeAnnotations.IsPresent

        Write-Host "[FETCHXML] $EntitySetName" -ForegroundColor Cyan
        try {
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
            Write-Host "[OK] Retrieved $($response.value.Count) record(s)" -ForegroundColor Green
            $output = @{ value = $response.value }
            $rows = @($response.value)
            if ((-not $OutputFile) -and ($rows.Count -gt $MaxInlineRows)) {
                $spill = Join-Path ([System.IO.Path]::GetTempPath()) "dataverse-fetchxml-$EntitySetName-$($rows.Count)rows.json"
                Write-DataverseJsonOutput -Data $output -OutputFile $spill -Raw $true
                Write-Host "[WARN] $($rows.Count) rows exceeds the $MaxInlineRows-row inline cap -- spilled to file to save context (not printed to stdout)." -ForegroundColor Yellow
                Write-Host "       Add a top/limit to the FetchXML or read the file: $spill" -ForegroundColor Gray
            } else {
                Write-DataverseJsonOutput -Data $output -OutputFile $OutputFile -Raw (-not $Pretty.IsPresent)
            }
        }
        catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] FetchXml failed: $errDetail" -ForegroundColor Red
            exit 1
        }
    }

    "Action" {
        # Invoke an unbound Dataverse Web API action (POST /api/data/v9.2/<ActionName>).
        # Examples: AddAppComponents, PublishXml, RetrieveDuplicates, custom hso_* actions.
        if (-not $ActionName) { Write-Host "[ERROR] -ActionName is required for Action operation." -ForegroundColor Red; exit 1 }

        $payload = $null
        if ($JsonFilePath -and (Test-Path $JsonFilePath)) {
            $payload = Get-Content -Path $JsonFilePath -Raw -Encoding UTF8
        } elseif ($JsonBody) {
            $payload = $JsonBody
        }

        $url = "$envUrl/api/data/v9.2/$ActionName"
        $headers = Get-DataverseHeaders -Token $token

        Write-Host "[ACTION] $ActionName" -ForegroundColor Cyan
        try {
            if ($payload) {
                $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($payload))
            } else {
                $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Post
            }
            Write-Host "[OK] Action completed" -ForegroundColor Green
            if ($response) {
                Write-DataverseJsonOutput -Data $response -OutputFile $OutputFile -Raw $Raw.IsPresent
            }
        }
        catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Action failed: $errDetail" -ForegroundColor Red
            exit 1
        }
    }

    default {
        Write-Host "[ERROR] Unknown operation: $Operation" -ForegroundColor Red
        exit 1
    }
}

#endregion
