<#
.SYNOPSIS
    Performs Azure DevOps work item operations using the REST API.

.DESCRIPTION
    This script manages ADO work items:
    - Create: Create a new work item (any type)
    - Update: Update fields on an existing work item
    - Get: Retrieve a single work item by ID
    - Query: Run a WIQL query and return full work item details
    - Link: Add a link between two work items
    - AddTestSteps: Set test steps XML on a Test Case
    - Comment: Post a comment to a work item's Discussion (optionally @mentioning someone)
    - GetComments: Read a work item's Discussion thread
    - ListTypes: List available work item types for the project

.PARAMETER Operation
    The operation to perform.

.PARAMETER OrgUrl
    The Azure DevOps organization URL (e.g., https://dev.azure.com/MyOrg)

.PARAMETER Project
    The Azure DevOps project name.

.PARAMETER Pat
    Personal Access Token for PAT-based authentication.

.EXAMPLE
    # List available work item types
    .\Invoke-AdoWorkItemOperation.ps1 -Operation ListTypes `
        -OrgUrl "https://dev.azure.com/MyOrg" -Project "My Project"

.EXAMPLE
    # Create a Requirement
    .\Invoke-AdoWorkItemOperation.ps1 -Operation Create `
        -OrgUrl "https://dev.azure.com/MyOrg" -Project "My Project" `
        -WorkItemType "Requirement" `
        -JsonPatchFilePath "C:\temp\requirement.json"

.EXAMPLE
    # Post a comment
    .\Invoke-AdoWorkItemOperation.ps1 -Operation Comment `
        -OrgUrl "https://dev.azure.com/MyOrg" -Project "My Project" `
        -WorkItemId 12345 -CommentFilePath "C:\temp\comment.html"

.EXAMPLE
    # Post a comment that @mentions the work item's current assignee
    .\Invoke-AdoWorkItemOperation.ps1 -Operation Comment `
        -OrgUrl "https://dev.azure.com/MyOrg" -Project "My Project" `
        -WorkItemId 12345 -CommentFilePath "C:\temp\comment.html" `
        -MentionFromField "System.AssignedTo"

.EXAMPLE
    # Read the Discussion thread (use to check whether a comment was already posted)
    .\Invoke-AdoWorkItemOperation.ps1 -Operation GetComments `
        -OrgUrl "https://dev.azure.com/MyOrg" -Project "My Project" `
        -WorkItemId 12345

.NOTES
    Requires: PowerShell 5.1+, MSAL.PS module (installed automatically if missing)
    API Version: 7.1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Create", "Update", "Get", "Query", "Link", "AddTestSteps", "Comment", "GetComments", "ListTypes")]
    [string]$Operation,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OrgUrl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Project,

    [Parameter(Mandatory = $false)]
    [string]$Pat,

    # Work item type (for Create)
    [string]$WorkItemType,

    # Work item ID (for Get, Update, Link, AddTestSteps)
    [int]$WorkItemId = 0,

    # JSON patch body (for Create, Update)
    [string]$JsonPatchBody,
    [string]$JsonPatchFilePath,

    # WIQL query string (for Query)
    [string]$Wiql,

    # Link parameters
    [int]$LinkTargetId = 0,
    [string]$LinkType,

    # Test steps (for AddTestSteps)
    [string]$TestStepsXml,
    [string]$TestStepsFilePath,

    # Comment body (for Comment). Prefer the file form for anything with HTML.
    [string]$CommentText,
    [string]$CommentFilePath,

    # @mention (for Comment) — resolve the identity from a work item field, e.g. System.AssignedTo
    # or System.CreatedBy. Reads from -MentionFromWorkItemId, defaulting to -WorkItemId.
    [string]$MentionFromField,
    [int]$MentionFromWorkItemId = 0,
    # ...or supply the identity directly (both required together)
    [string]$MentionIdentityId,
    [string]$MentionDisplayName,

    # Query options
    [switch]$ExpandRelations,

    # Output
    [string]$OutputFile,
    [switch]$Raw
)

#region Shared Module Imports
$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"   # provides Install-MsalModuleIfMissing
. "$sharedDir\ADO-Auth.ps1"
. "$sharedDir\ADO-WebApi.ps1"   # Invoke-AdoRestMethod - promoted from this skill; see its header
#endregion

#region Constants
$script:ApiVersion = "7.1"
# The Comments REST API is preview-only — the plain "7.1" version string is rejected on these routes.
$script:CommentsApiVersion = "7.1-preview.4"
#endregion


#region Helper Functions

function Get-EncodedProject {
    <#
    .SYNOPSIS
    URL-encodes the project name (spaces -> %20).
    #>
    return [System.Uri]::EscapeDataString($Project)
}

function Get-ApiUrl {
    <#
    .SYNOPSIS
    Builds a full ADO REST API URL.
    #>
    param([Parameter(Mandatory)][string]$Endpoint)

    $base = $OrgUrl.TrimEnd('/')
    $proj = Get-EncodedProject
    return "$base/$proj/_apis/$Endpoint"
}

function Write-JsonOutput {
    <#
    .SYNOPSIS
    Writes data as JSON to a file or stdout.
    #>
    param(
        [Parameter(Mandatory)][object]$Data,
        [string]$File,
        [bool]$Compress = $false
    )

    if ($Compress) {
        $json = $Data | ConvertTo-Json -Depth 20 -Compress
    } else {
        $json = $Data | ConvertTo-Json -Depth 20
    }

    if ($File) {
        [System.IO.File]::WriteAllText($File, $json, [System.Text.Encoding]::UTF8)
        Write-Host "[OK] Output written to: $File" -ForegroundColor Green
    } else {
        Write-Output $json
    }
}

function Get-FieldValue {
    <#
    .SYNOPSIS
    Reads a property from a response object, tolerating both shapes Invoke-AdoRestMethod can return.

    .DESCRIPTION
    Small payloads parse to PSCustomObject; large ones fall back to JavaScriptSerializer and come
    back as Dictionary[string,object]. Property access differs between the two.
    #>
    param([Parameter(Mandatory)][AllowNull()]$Object, [Parameter(Mandatory)][string]$Key)

    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.Generic.Dictionary[string, object]]) {
        if ($Object.ContainsKey($Key)) { return $Object[$Key] }
        return $null
    }
    return $Object.$Key
}

function Resolve-MentionAnchor {
    <#
    .SYNOPSIS
    Builds the ADO @mention anchor HTML for an identity, or returns $null when no mention was requested.

    .DESCRIPTION
    ADO only raises a notification when the comment contains this exact markup:
        <a href="#" data-vss-mention="version:2.0,{identityGuid}">@Display Name</a>
    A plain "@Name" string posts successfully but notifies nobody — a silent failure — so the
    identity GUID is mandatory.

    Identities are resolved from a work item field (System.AssignedTo, System.CreatedBy, ...) because
    those payloads already carry {id, displayName}. That avoids an identity-search call and therefore
    needs no PAT scope beyond Work Items (Read & Write).
    #>
    param(
        [hashtable]$Headers,
        [string]$FromField,
        [int]$FromWorkItemId,
        [string]$IdentityId,
        [string]$DisplayName
    )

    if ($IdentityId -and $DisplayName) {
        return '<a href="#" data-vss-mention="version:2.0,' + $IdentityId + '">@' + $DisplayName + '</a>'
    }
    if ($IdentityId -or $DisplayName) {
        throw "-MentionIdentityId and -MentionDisplayName must be supplied together."
    }
    if (-not $FromField) { return $null }

    $sourceId = if ($FromWorkItemId -gt 0) { $FromWorkItemId } else { $WorkItemId }
    if ($sourceId -le 0) {
        throw "-MentionFromField needs a work item to read from (-WorkItemId or -MentionFromWorkItemId)."
    }

    $url = Get-ApiUrl -Endpoint "wit/workitems/$($sourceId)?api-version=$($script:ApiVersion)"
    Write-Host "  [MENTION] Resolving '$FromField' from work item #$sourceId" -ForegroundColor Gray
    $wi = Invoke-AdoRestMethod -Uri $url -Headers $Headers -Method Get

    $fields   = Get-FieldValue -Object $wi -Key 'fields'
    $identity = Get-FieldValue -Object $fields -Key $FromField
    if (-not $identity) {
        throw "Field '$FromField' is empty or absent on work item #$sourceId — nobody to mention."
    }

    # api-version 7.1 returns an identity object; legacy payloads can return a bare display string.
    if ($identity -is [string]) {
        throw "Field '$FromField' on #$sourceId returned a plain string ('$identity') with no identity GUID. Supply -MentionIdentityId and -MentionDisplayName explicitly."
    }

    $id   = Get-FieldValue -Object $identity -Key 'id'
    $name = Get-FieldValue -Object $identity -Key 'displayName'
    if (-not $id) { throw "Could not read an identity GUID from '$FromField' on work item #$sourceId." }

    Write-Host "  [MENTION] -> $name ($id)" -ForegroundColor Gray
    return '<a href="#" data-vss-mention="version:2.0,' + $id + '">@' + $name + '</a>'
}

#endregion

#region Main Execution

# Normalize org URL
$OrgUrl = $OrgUrl.TrimEnd('/')
if (-not $OrgUrl.StartsWith('https://')) { $OrgUrl = "https://$OrgUrl" }

# Authenticate
$auth = Get-AdoToken -OrgUrl $OrgUrl -Pat $Pat
if (-not $auth) {
    Write-Host "[ERROR] Failed to obtain authentication." -ForegroundColor Red
    exit 1
}

# Build base headers
$baseHeaders = @{}
if ($auth.AuthType -eq 'Bearer') {
    $baseHeaders = Get-AdoHeaders -Token $auth.Token
} else {
    $baseHeaders = Get-AdoHeaders -Pat $auth.Pat
}

switch ($Operation) {

    "ListTypes" {
        $url = Get-ApiUrl -Endpoint "wit/workitemtypes?api-version=$($script:ApiVersion)"

        Write-Host "[LIST TYPES] $Project" -ForegroundColor Cyan
        try {
            $response = Invoke-AdoRestMethod -Uri $url -Headers $baseHeaders -Method Get
            # Response may be PSCustomObject (small) or Dictionary (large, PS 5.1 fallback)
            $isDictionary = $response -is [System.Collections.Generic.Dictionary[string,object]]
            $typeCount = if ($isDictionary) { $response["count"] } else { $response.count }
            $valueArray = if ($isDictionary) { $response["value"] } else { $response.value }

            # Build clean output with just name + description
            $typesList = New-Object System.Collections.ArrayList
            foreach ($t in $valueArray) {
                $tName = if ($t -is [System.Collections.Generic.Dictionary[string,object]]) { $t["name"] } else { $t.name }
                $tDesc = if ($t -is [System.Collections.Generic.Dictionary[string,object]]) { $t["description"] } else { $t.description }
                [void]$typesList.Add(@{ name = $tName; description = $tDesc })
            }
            Write-Host "[OK] Found $typeCount work item type(s)" -ForegroundColor Green
            # Output as formatted text for readability
            $output = @{ count = $typeCount; value = $typesList.ToArray() }
            Write-JsonOutput -Data $output -File $OutputFile -Compress $Raw.IsPresent
        }
        catch {
            Write-Host "[ERROR] ListTypes failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.ErrorDetails.Message) { Write-Host "  Detail: $($_.ErrorDetails.Message)" -ForegroundColor Gray }
            exit 1
        }
    }

    "Get" {
        if ($WorkItemId -le 0) { Write-Host "[ERROR] -WorkItemId is required." -ForegroundColor Red; exit 1 }

        $expandPart = ""
        if ($ExpandRelations.IsPresent) { $expandPart = "&`$expand=relations" }
        $url = Get-ApiUrl -Endpoint "wit/workitems/$($WorkItemId)?api-version=$($script:ApiVersion)$expandPart"

        Write-Host "[GET] Work item #$WorkItemId" -ForegroundColor Cyan
        try {
            $response = Invoke-AdoRestMethod -Uri $url -Headers $baseHeaders -Method Get
            Write-Host "[OK] Retrieved: $($response.fields.'System.Title')" -ForegroundColor Green
            Write-JsonOutput -Data $response -File $OutputFile -Compress $Raw.IsPresent
        }
        catch {
            Write-Host "[ERROR] Get failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.ErrorDetails.Message) { Write-Host "  Detail: $($_.ErrorDetails.Message)" -ForegroundColor Gray }
            exit 1
        }
    }

    "Create" {
        if (-not $WorkItemType) { Write-Host "[ERROR] -WorkItemType is required." -ForegroundColor Red; exit 1 }

        # Get payload
        $payload = $null
        if ($JsonPatchFilePath -and (Test-Path $JsonPatchFilePath)) {
            $payload = Get-Content -Path $JsonPatchFilePath -Raw -Encoding UTF8
        } elseif ($JsonPatchBody) {
            $payload = $JsonPatchBody
        } else {
            Write-Host "[ERROR] -JsonPatchBody or -JsonPatchFilePath is required." -ForegroundColor Red; exit 1
        }

        # URL-encode the work item type (e.g., "Test Case" -> "Test%20Case")
        $encodedType = [System.Uri]::EscapeDataString($WorkItemType)
        $url = Get-ApiUrl -Endpoint "wit/workitems/`$$($encodedType)?api-version=$($script:ApiVersion)"

        # Use json-patch+json content type
        $createHeaders = $baseHeaders.Clone()
        $createHeaders["Content-Type"] = "application/json-patch+json"

        Write-Host "[CREATE] $WorkItemType" -ForegroundColor Cyan
        try {
            $response = Invoke-AdoRestMethod -Uri $url -Headers $createHeaders -Method Post `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($payload))
            Write-Host "[OK] Created work item #$($response.id): $($response.fields.'System.Title')" -ForegroundColor Green
            Write-JsonOutput -Data $response -File $OutputFile -Compress $Raw.IsPresent
        }
        catch {
            Write-Host "[ERROR] Create failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.ErrorDetails.Message) { Write-Host "  Detail: $($_.ErrorDetails.Message)" -ForegroundColor Gray }
            exit 1
        }
    }

    "Update" {
        if ($WorkItemId -le 0) { Write-Host "[ERROR] -WorkItemId is required." -ForegroundColor Red; exit 1 }

        # Get payload
        $payload = $null
        if ($JsonPatchFilePath -and (Test-Path $JsonPatchFilePath)) {
            $payload = Get-Content -Path $JsonPatchFilePath -Raw -Encoding UTF8
        } elseif ($JsonPatchBody) {
            $payload = $JsonPatchBody
        } else {
            Write-Host "[ERROR] -JsonPatchBody or -JsonPatchFilePath is required." -ForegroundColor Red; exit 1
        }

        $url = Get-ApiUrl -Endpoint "wit/workitems/$($WorkItemId)?api-version=$($script:ApiVersion)"

        $updateHeaders = $baseHeaders.Clone()
        $updateHeaders["Content-Type"] = "application/json-patch+json"

        Write-Host "[UPDATE] Work item #$WorkItemId" -ForegroundColor Cyan
        try {
            $response = Invoke-AdoRestMethod -Uri $url -Headers $updateHeaders -Method Patch `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($payload))
            Write-Host "[OK] Updated work item #$($response.id)" -ForegroundColor Green
            Write-JsonOutput -Data $response -File $OutputFile -Compress $Raw.IsPresent
        }
        catch {
            Write-Host "[ERROR] Update failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.ErrorDetails.Message) { Write-Host "  Detail: $($_.ErrorDetails.Message)" -ForegroundColor Gray }
            exit 1
        }
    }

    "Query" {
        if (-not $Wiql) { Write-Host "[ERROR] -Wiql is required." -ForegroundColor Red; exit 1 }

        $url = Get-ApiUrl -Endpoint "wit/wiql?api-version=$($script:ApiVersion)"

        $wiqlBody = @{ query = $Wiql } | ConvertTo-Json
        $queryHeaders = $baseHeaders.Clone()
        $queryHeaders["Content-Type"] = "application/json"

        Write-Host "[QUERY] Running WIQL query..." -ForegroundColor Cyan
        try {
            $wiqlResult = Invoke-AdoRestMethod -Uri $url -Headers $queryHeaders -Method Post `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($wiqlBody))

            $wiqlItems = if ($wiqlResult -is [System.Collections.Generic.Dictionary[string,object]]) {
                $wiqlResult["workItems"]
            } else {
                $wiqlResult.workItems
            }
            $workItemIds = @($wiqlItems | ForEach-Object {
                if ($_ -is [System.Collections.Generic.Dictionary[string,object]]) { $_["id"] } else { $_.id }
            })

            if (-not $workItemIds -or $workItemIds.Count -eq 0) {
                Write-Host "[OK] Query returned 0 work items" -ForegroundColor Green
                Write-JsonOutput -Data @{ value = @() } -File $OutputFile -Compress $Raw.IsPresent
                return
            }

            Write-Host "  Found $($workItemIds.Count) work item(s), fetching details..." -ForegroundColor Gray

            # Batch-fetch work items (ADO supports up to 200 IDs per request)
            $allItems = @()
            for ($i = 0; $i -lt $workItemIds.Count; $i += 200) {
                $batch = $workItemIds[$i..([Math]::Min($i + 199, $workItemIds.Count - 1))]
                $idsCsv = ($batch -join ",")
                $expandPart = ""
                if ($ExpandRelations.IsPresent) { $expandPart = "&`$expand=relations" }
                $detailUrl = Get-ApiUrl -Endpoint "wit/workitems?ids=$idsCsv$expandPart&api-version=$($script:ApiVersion)"

                $detailHeaders = $baseHeaders.Clone()
                $detailHeaders["Content-Type"] = "application/json"

                $detailResult = Invoke-AdoRestMethod -Uri $detailUrl -Headers $detailHeaders -Method Get
                $allItems += $detailResult.value
            }

            Write-Host "[OK] Retrieved $($allItems.Count) work item(s)" -ForegroundColor Green
            Write-JsonOutput -Data @{ value = $allItems } -File $OutputFile -Compress $Raw.IsPresent
        }
        catch {
            Write-Host "[ERROR] Query failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.ErrorDetails.Message) { Write-Host "  Detail: $($_.ErrorDetails.Message)" -ForegroundColor Gray }
            exit 1
        }
    }

    "Link" {
        if ($WorkItemId -le 0) { Write-Host "[ERROR] -WorkItemId is required." -ForegroundColor Red; exit 1 }
        if ($LinkTargetId -le 0) { Write-Host "[ERROR] -LinkTargetId is required." -ForegroundColor Red; exit 1 }
        if (-not $LinkType) { Write-Host "[ERROR] -LinkType is required." -ForegroundColor Red; exit 1 }

        $base = $OrgUrl.TrimEnd('/')
        $linkBody = ConvertTo-Json -InputObject @(
            @{
                op    = "add"
                path  = "/relations/-"
                value = @{
                    rel = $LinkType
                    url = "$base/_apis/wit/workItems/$LinkTargetId"
                }
            }
        ) -Depth 5

        $url = Get-ApiUrl -Endpoint "wit/workitems/$($WorkItemId)?api-version=$($script:ApiVersion)"

        $linkHeaders = $baseHeaders.Clone()
        $linkHeaders["Content-Type"] = "application/json-patch+json"

        Write-Host "[LINK] #$WorkItemId -> #$LinkTargetId ($LinkType)" -ForegroundColor Cyan
        try {
            $response = Invoke-AdoRestMethod -Uri $url -Headers $linkHeaders -Method Patch `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($linkBody))
            Write-Host "[OK] Link created" -ForegroundColor Green
            Write-JsonOutput -Data $response -File $OutputFile -Compress $Raw.IsPresent
        }
        catch {
            Write-Host "[ERROR] Link failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.ErrorDetails.Message) { Write-Host "  Detail: $($_.ErrorDetails.Message)" -ForegroundColor Gray }
            exit 1
        }
    }

    "AddTestSteps" {
        if ($WorkItemId -le 0) { Write-Host "[ERROR] -WorkItemId is required." -ForegroundColor Red; exit 1 }

        # Get test steps XML
        $stepsXml = $null
        if ($TestStepsFilePath -and (Test-Path $TestStepsFilePath)) {
            $stepsXml = Get-Content -Path $TestStepsFilePath -Raw -Encoding UTF8
        } elseif ($TestStepsXml) {
            $stepsXml = $TestStepsXml
        } else {
            Write-Host "[ERROR] -TestStepsXml or -TestStepsFilePath is required." -ForegroundColor Red; exit 1
        }

        # CRITICAL: Manually construct JSON to avoid ConvertTo-Json double-escaping XML entities
        # ConvertTo-Json turns &lt; into &amp;lt; which causes 400 Bad Request
        $escapedXml = $stepsXml.Replace('\', '\\').Replace('"', '\"').Replace("`r`n", '\n').Replace("`n", '\n')
        $jsonBody = '[{"op":"add","path":"/fields/Microsoft.VSTS.TCM.Steps","value":"' + $escapedXml + '"}]'

        $url = Get-ApiUrl -Endpoint "wit/workitems/$($WorkItemId)?api-version=$($script:ApiVersion)"

        $stepHeaders = $baseHeaders.Clone()
        $stepHeaders["Content-Type"] = "application/json-patch+json"

        Write-Host "[ADD TEST STEPS] Work item #$WorkItemId" -ForegroundColor Cyan
        try {
            $response = Invoke-AdoRestMethod -Uri $url -Headers $stepHeaders -Method Patch `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonBody))
            Write-Host "[OK] Test steps added to #$($response.id)" -ForegroundColor Green
            Write-JsonOutput -Data $response -File $OutputFile -Compress $Raw.IsPresent
        }
        catch {
            Write-Host "[ERROR] AddTestSteps failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.ErrorDetails.Message) { Write-Host "  Detail: $($_.ErrorDetails.Message)" -ForegroundColor Gray }
            exit 1
        }
    }

    "Comment" {
        if ($WorkItemId -le 0) { Write-Host "[ERROR] -WorkItemId is required." -ForegroundColor Red; exit 1 }

        # Get comment body
        $commentHtml = $null
        if ($CommentFilePath -and (Test-Path $CommentFilePath)) {
            # Read as a plain .NET string — NOT Get-Content -Raw. Under Windows PowerShell 5.1
            # (how this script is normally launched: powershell -File ...) Get-Content returns an
            # ETS-decorated string carrying PSPath / PSDrive / PSProvider note properties. The
            # ConvertTo-Json below then serializes it as an OBJECT — {"text":{"value":"...",
            # "PSPath":...}} — and ADO rejects the payload with HTTP 400 "You must provide a value
            # for the text parameter." Under PowerShell 7 the same code works, which is why this
            # went unnoticed. The other Get-Content -Raw reads in this script are safe: their
            # strings go straight to bytes or through .Replace(), never through ConvertTo-Json.
            $resolvedCommentPath = (Resolve-Path -LiteralPath $CommentFilePath).ProviderPath
            $commentHtml = [System.IO.File]::ReadAllText($resolvedCommentPath, [System.Text.Encoding]::UTF8)
        } elseif ($CommentText) {
            $commentHtml = $CommentText
        } else {
            Write-Host "[ERROR] -CommentText or -CommentFilePath is required." -ForegroundColor Red; exit 1
        }

        # Prepend the @mention anchor when one was requested
        try {
            $anchor = Resolve-MentionAnchor -Headers $baseHeaders -FromField $MentionFromField `
                -FromWorkItemId $MentionFromWorkItemId `
                -IdentityId $MentionIdentityId -DisplayName $MentionDisplayName
            if ($anchor) { $commentHtml = "<div>$anchor</div>" + $commentHtml }
        }
        catch {
            Write-Host "[ERROR] Mention resolution failed: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }

        $url = Get-ApiUrl -Endpoint "wit/workItems/$($WorkItemId)/comments?api-version=$($script:CommentsApiVersion)"

        $commentHeaders = $baseHeaders.Clone()
        $commentHeaders["Content-Type"] = "application/json"

        # Plain JSON body (not json-patch) — ConvertTo-Json escapes < > & as \uXXXX, which the
        # service decodes back to literal HTML, so no manual escaping is needed here.
        $commentBody = @{ text = $commentHtml } | ConvertTo-Json -Depth 5

        Write-Host "[COMMENT] Work item #$WorkItemId" -ForegroundColor Cyan
        try {
            $response = Invoke-AdoRestMethod -Uri $url -Headers $commentHeaders -Method Post `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($commentBody))
            Write-Host "[OK] Comment $($response.id) posted to #$WorkItemId" -ForegroundColor Green
            Write-JsonOutput -Data $response -File $OutputFile -Compress $Raw.IsPresent
        }
        catch {
            Write-Host "[ERROR] Comment failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.ErrorDetails.Message) { Write-Host "  Detail: $($_.ErrorDetails.Message)" -ForegroundColor Gray }
            exit 1
        }
    }

    "GetComments" {
        if ($WorkItemId -le 0) { Write-Host "[ERROR] -WorkItemId is required." -ForegroundColor Red; exit 1 }

        $url = Get-ApiUrl -Endpoint "wit/workItems/$($WorkItemId)/comments?api-version=$($script:CommentsApiVersion)"

        Write-Host "[GET COMMENTS] Work item #$WorkItemId" -ForegroundColor Cyan
        try {
            $response = Invoke-AdoRestMethod -Uri $url -Headers $baseHeaders -Method Get

            $total    = Get-FieldValue -Object $response -Key 'totalCount'
            $comments = Get-FieldValue -Object $response -Key 'comments'

            $list = New-Object System.Collections.ArrayList
            foreach ($c in $comments) {
                $createdBy = Get-FieldValue -Object $c -Key 'createdBy'
                [void]$list.Add(@{
                    id           = Get-FieldValue -Object $c -Key 'id'
                    createdBy    = Get-FieldValue -Object $createdBy -Key 'displayName'
                    createdDate  = Get-FieldValue -Object $c -Key 'createdDate'
                    modifiedDate = Get-FieldValue -Object $c -Key 'modifiedDate'
                    text         = Get-FieldValue -Object $c -Key 'text'
                })
            }

            Write-Host "[OK] Retrieved $($list.Count) comment(s) of $total total" -ForegroundColor Green
            Write-JsonOutput -Data @{ totalCount = $total; comments = $list.ToArray() } `
                -File $OutputFile -Compress $Raw.IsPresent
        }
        catch {
            Write-Host "[ERROR] GetComments failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.ErrorDetails.Message) { Write-Host "  Detail: $($_.ErrorDetails.Message)" -ForegroundColor Gray }
            exit 1
        }
    }

    default {
        Write-Host "[ERROR] Unknown operation: $Operation" -ForegroundColor Red
        exit 1
    }
}

#endregion
