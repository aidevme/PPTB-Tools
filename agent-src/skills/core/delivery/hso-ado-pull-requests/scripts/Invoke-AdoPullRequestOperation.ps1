<#
.SYNOPSIS
    Performs Azure DevOps pull request operations via the REST API.

.DESCRIPTION
    This script manages ADO pull requests:
    - Create: Create a new PR (UTF-8-safe description handling via file)
    - Update: Update title/description on an existing PR
    - Get: Retrieve a single PR by ID
    - List: List PRs filtered by branch / status
    - AddComment: Post a comment thread to a PR
    - LinkWorkItems: Attach work items to an existing PR

    UTF-8 safety: description and comment bodies are read directly from
    UTF-8 files via Get-Content -Encoding UTF8 and posted with explicit
    `application/json; charset=utf-8` headers. This avoids the Windows
    ANSI-codepage mangling that affects `az repos pr create --description "..."`
    when bodies contain em-dashes, section symbols, smart quotes, etc.

.PARAMETER Operation
    The operation to perform.

.PARAMETER OrgUrl
    Azure DevOps organization URL (e.g., https://dev.azure.com/MyOrg).
    If omitted, the script attempts to parse it from `git remote get-url origin`.

.PARAMETER Project
    Azure DevOps project name. If omitted, parsed from `git remote get-url origin`.

.PARAMETER Repository
    Repository name. If omitted, parsed from `git remote get-url origin`.

.PARAMETER SourceBranch
    Source branch (Create only). Defaults to the current branch via
    `git rev-parse --abbrev-ref HEAD`. Accepts short name ("feat/x") or
    full ref ("refs/heads/feat/x").

.PARAMETER TargetBranch
    Target branch (Create only). Defaults to the upstream default branch
    via `git symbolic-ref refs/remotes/origin/HEAD`.

.PARAMETER Title
    PR title (Create / Update).

.PARAMETER DescriptionFilePath
    Path to a UTF-8 file containing the PR description (Create / Update).
    **Preferred for any body with non-ASCII characters.** The script reads with
    -Encoding UTF8 and the API call posts charset=utf-8 explicitly.

.PARAMETER Description
    Inline description (Create / Update). **Use only for ASCII-only bodies.**
    For em-dashes, section symbols, smart quotes, etc., use -DescriptionFilePath.

.PARAMETER PullRequestId
    PR id (Update / Get / AddComment / LinkWorkItems).

.PARAMETER CommentFilePath
    Path to a UTF-8 file containing the comment text (AddComment).

.PARAMETER Comment
    Inline comment text (AddComment). Same ASCII-only caveat as -Description.

.PARAMETER WorkItemIds
    Comma-separated list of ADO work item IDs to attach (Create / LinkWorkItems).

.PARAMETER Status
    Filter status (List). One of: active, completed, abandoned, all. Default: active.

.PARAMETER Top
    Page size cap (List). Default: 50.

.PARAMETER IsDraft
    Create the PR in draft state (Create).

.PARAMETER AutoComplete
    Set the PR to auto-complete on policy satisfaction (Create / Update).
    Caller must be the PR creator or have appropriate permissions.

.PARAMETER Pat
    Personal Access Token override for PAT-based authentication.

.EXAMPLE
    # Create a PR with a UTF-8 description file
    .\Invoke-AdoPullRequestOperation.ps1 -Operation Create `
        -OrgUrl "https://dev.azure.com/MyOrg" -Project "My Project" -Repository "My Repo" `
        -SourceBranch "feat/example" -TargetBranch "main" `
        -Title "Example PR" `
        -DescriptionFilePath "C:\temp\pr-body.md" `
        -WorkItemIds "12345,12346"

.EXAMPLE
    # Auto-detect org / project / repo / source / target from git
    .\Invoke-AdoPullRequestOperation.ps1 -Operation Create `
        -Title "Example PR" -DescriptionFilePath "C:\temp\pr-body.md"

.EXAMPLE
    # Update an existing PR's description
    .\Invoke-AdoPullRequestOperation.ps1 -Operation Update `
        -PullRequestId 735 -DescriptionFilePath "C:\temp\fixed-body.md"

.EXAMPLE
    # List active PRs targeting main
    .\Invoke-AdoPullRequestOperation.ps1 -Operation List -Status active

.NOTES
    Requires: PowerShell 5.1+, MSAL.PS module (auto-installed by ADO-Auth.ps1 if missing).
    API Version: 7.1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Create", "Update", "Get", "List", "AddComment", "LinkWorkItems")]
    [string]$Operation,

    [string]$OrgUrl,
    [string]$Project,
    [string]$Repository,
    [string]$SourceBranch,
    [string]$TargetBranch,
    [string]$Title,
    [string]$DescriptionFilePath,
    [string]$Description,
    [int]$PullRequestId,
    [string]$CommentFilePath,
    [string]$Comment,
    [string]$WorkItemIds,
    [ValidateSet("active", "completed", "abandoned", "all")]
    [string]$Status = "active",
    [int]$Top = 50,
    [switch]$IsDraft,
    [switch]$AutoComplete,
    [string]$Pat
)

$ErrorActionPreference = 'Stop'
$ApiVersion = '7.1'

$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"   # provides Install-MsalModuleIfMissing
. "$sharedDir\ADO-Auth.ps1"
. "$sharedDir\ADO-WebApi.ps1"   # Invoke-AdoRestMethod - refuses the 302-to-sign-in that reads as an empty result

# region helpers -------------------------------------------------------------

function Resolve-GitRemoteContext {
    # Parses `git remote get-url origin` to recover OrgUrl / Project / Repository.
    # Supported URL shapes:
    #   https://dev.azure.com/<Org>/<Project>/_git/<Repo>
    #   https://<Org>@dev.azure.com/<Org>/<Project>/_git/<Repo>
    #   https://<Org>.visualstudio.com/<Project>/_git/<Repo>
    try {
        $url = (git remote get-url origin 2>$null).Trim()
    } catch {
        return $null
    }
    if (-not $url) { return $null }

    $url = [System.Web.HttpUtility]::UrlDecode($url) -replace '\.git$', ''

    if ($url -match '^https?://(?:[^@]+@)?dev\.azure\.com/([^/]+)/([^/]+)/_git/(.+)$') {
        return @{
            OrgUrl     = "https://dev.azure.com/$($Matches[1])"
            Project    = $Matches[2]
            Repository = $Matches[3]
        }
    }
    if ($url -match '^https?://([^.]+)\.visualstudio\.com/([^/]+)/_git/(.+)$') {
        return @{
            OrgUrl     = "https://dev.azure.com/$($Matches[1])"
            Project    = $Matches[2]
            Repository = $Matches[3]
        }
    }
    return $null
}

function Resolve-DefaultBranch {
    try {
        $ref = (git symbolic-ref refs/remotes/origin/HEAD 2>$null).Trim()
        if ($ref -match 'refs/remotes/origin/(.+)$') {
            return $Matches[1]
        }
    } catch {}
    # Fallback: assume 'main'
    return 'main'
}

function Resolve-CurrentBranch {
    try {
        return (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
    } catch {
        return $null
    }
}

function Test-OriginIsAdo {
    # Returns $true only when origin parses cleanly as an Azure DevOps URL.
    try {
        $url = (git remote get-url origin 2>$null).Trim()
    } catch {
        return $false
    }
    if (-not $url) { return $false }
    return ($url -match 'dev\.azure\.com/' -or $url -match '\.visualstudio\.com/')
}

function Confirm-Context {
    # Fills in OrgUrl / Project / Repository from git remote when missing.
    if (-not $OrgUrl -or -not $Project -or -not $Repository) {
        $ctx = Resolve-GitRemoteContext
        if ($null -ne $ctx) {
            if (-not $OrgUrl)     { $script:OrgUrl     = $ctx.OrgUrl }
            if (-not $Project)    { $script:Project    = $ctx.Project }
            if (-not $Repository) { $script:Repository = $ctx.Repository }
        }
    }
    if (-not $OrgUrl -or -not $Project -or -not $Repository) {
        # Friendly skip when we're not in an ADO repo and no explicit context was passed.
        # Exit 0 — this is "not applicable", not an error. The caller (often an agent
        # invoking the skill speculatively) should treat this as "no PR workflow here".
        if (-not (Test-OriginIsAdo)) {
            Write-Host "hso-ado-pull-requests: this working directory does not have an Azure DevOps origin remote, and no -OrgUrl / -Project / -Repository were supplied."
            Write-Host "Skipping PR operation. If this repo intentionally has no PR workflow, the skill is not applicable here."
            Write-Host "If it should be ADO-connected, configure the remote (e.g. `git remote add origin https://dev.azure.com/<Org>/<Project>/_git/<Repo>`) or pass the three context parameters explicitly."
            exit 0
        }
        throw "OrgUrl, Project, and Repository must be provided (or runnable from a git checkout with an Azure DevOps origin)."
    }

    # ADO project / repo names can contain spaces and other URL-reserved characters
    # (e.g. a project + repo whose name contains a space). The names are kept decoded for display, but
    # every REST path segment MUST be URL-encoded — otherwise the request hits a URL with a
    # raw space and fails (malformed URI / 404). Encode once here for reuse in all URL builders.
    $script:ProjectEnc    = [Uri]::EscapeDataString($Project)
    $script:RepositoryEnc = [Uri]::EscapeDataString($Repository)
}

function ConvertTo-BranchRef([string]$Branch) {
    if (-not $Branch) { return $null }
    if ($Branch -like 'refs/heads/*') { return $Branch }
    return "refs/heads/$Branch"
}

function Read-BodyFromFileOrInline([string]$FilePath, [string]$Inline, [string]$FieldName) {
    if ($FilePath) {
        if (-not (Test-Path -LiteralPath $FilePath)) {
            throw "$FieldName file not found: $FilePath"
        }
        $content = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
    } elseif ($Inline) {
        if ($Inline -cmatch '[^\x00-\x7F]') {
            Write-Warning "$FieldName contains non-ASCII characters; prefer the -*FilePath parameter for guaranteed UTF-8 fidelity."
        }
        $content = $Inline
    } else {
        return $null
    }

    # Pre-flight length check against ADO PR field limits — catches the 4000-char
    # description ceiling and the 400-char title ceiling before the REST call.
    if ($FieldName -eq 'Description' -and $content.Length -gt 4000) {
        throw ("$FieldName is $($content.Length) characters; ADO rejects PR descriptions over 4000 at create/update time. " +
               "Trim the body (aim for under ~3500 to leave headroom) or split detail into a linked design doc / ADR.")
    }
    if ($FieldName -eq 'Title' -and $content.Length -gt 400) {
        throw "$FieldName is $($content.Length) characters; ADO PR titles must be 400 or fewer. HSO style guidance is 70."
    }

    return $content
}

function Get-PrBaseUrl {
    return "$OrgUrl/$ProjectEnc/_apis/git/repositories/$RepositoryEnc/pullrequests"
}

function Invoke-AdoPrRest {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Url,
        [object]$Body
    )
    $headers = @{} + $script:baseHeaders   # shallow clone so we can override Content-Type per-call
    $headers['Content-Type'] = 'application/json; charset=utf-8'

    $bytes = $null
    if ($Body) {
        $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 10 -Compress:$false }
        # Force UTF-8 byte encoding on the request body — sidesteps PS5's default Latin1 conversion.
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    }
    # Shared invoker rather than Invoke-RestMethod: an unauthenticated ADO request answers 302
    # to a sign-in page, and Invoke-RestMethod follows it and returns an empty object.
    return Invoke-AdoRestMethod -Uri $Url -Headers $headers -Method $Method -Body $bytes
}

function Format-PrUrl([int]$PrId) {
    return "$OrgUrl/$ProjectEnc/_git/$RepositoryEnc/pullrequest/$PrId"
}

# endregion ------------------------------------------------------------------

# region operations ----------------------------------------------------------

function Invoke-CreatePr {
    if (-not $Title)        { throw "-Title is required for Create." }
    if (-not $SourceBranch) { $script:SourceBranch = Resolve-CurrentBranch }
    if (-not $SourceBranch) { throw "-SourceBranch is required (could not auto-detect current branch)." }
    if (-not $TargetBranch) { $script:TargetBranch = Resolve-DefaultBranch }

    $body = @{
        sourceRefName = ConvertTo-BranchRef $SourceBranch
        targetRefName = ConvertTo-BranchRef $TargetBranch
        title         = $Title
        isDraft       = [bool]$IsDraft
    }
    $description = Read-BodyFromFileOrInline -FilePath $DescriptionFilePath -Inline $Description -FieldName 'Description'
    if ($description) { $body.description = $description }

    if ($WorkItemIds) {
        $body.workItemRefs = @(
            ($WorkItemIds -split '\s*,\s*' | Where-Object { $_ }) | ForEach-Object { @{ id = "$_" } }
        )
    }

    $url = "$(Get-PrBaseUrl)?api-version=$ApiVersion"
    $pr  = Invoke-AdoPrRest -Method POST -Url $url -Body $body

    if ($AutoComplete) {
        Set-PrAutoComplete -PrId $pr.pullRequestId
        # Re-fetch to surface the updated autoComplete setter.
        $pr = Invoke-AdoPrRest -Method GET -Url "$(Get-PrBaseUrl)/$($pr.pullRequestId)?api-version=$ApiVersion"
    }

    [pscustomobject]@{
        pullRequestId = $pr.pullRequestId
        status        = $pr.status
        title         = $pr.title
        sourceRefName = $pr.sourceRefName
        targetRefName = $pr.targetRefName
        isDraft       = $pr.isDraft
        autoComplete  = $null -ne $pr.autoCompleteSetBy
        url           = Format-PrUrl -PrId $pr.pullRequestId
    } | Format-List
}

function Invoke-UpdatePr {
    if (-not $PullRequestId) { throw "-PullRequestId is required for Update." }
    $body = @{}
    if ($Title) { $body.title = $Title }
    $description = Read-BodyFromFileOrInline -FilePath $DescriptionFilePath -Inline $Description -FieldName 'Description'
    if ($description) { $body.description = $description }

    if ($body.Keys.Count -gt 0) {
        $url = "$(Get-PrBaseUrl)/${PullRequestId}?api-version=$ApiVersion"
        Invoke-AdoPrRest -Method PATCH -Url $url -Body $body | Out-Null
        Write-Host "Updated PR $PullRequestId."
    } else {
        Write-Host "No -Title or -Description provided; nothing to update on the PR record itself."
    }

    if ($AutoComplete) {
        Set-PrAutoComplete -PrId $PullRequestId
        Write-Host "Auto-complete set on PR $PullRequestId."
    }

    Write-Host "URL: $(Format-PrUrl -PrId $PullRequestId)"
}

function Set-PrAutoComplete {
    param([Parameter(Mandatory)][int]$PrId)
    # We need the PR's creator id to set autoCompleteSetBy.
    $pr = Invoke-AdoPrRest -Method GET -Url "$(Get-PrBaseUrl)/${PrId}?api-version=$ApiVersion"
    $body = @{
        autoCompleteSetBy = @{ id = $pr.createdBy.id }
        completionOptions = @{
            deleteSourceBranch = $false
            mergeStrategy      = 'noFastForward'
        }
    }
    $url = "$(Get-PrBaseUrl)/${PrId}?api-version=$ApiVersion"
    Invoke-AdoPrRest -Method PATCH -Url $url -Body $body | Out-Null
}

function Invoke-GetPr {
    if (-not $PullRequestId) { throw "-PullRequestId is required for Get." }
    $url = "$(Get-PrBaseUrl)/$PullRequestId" + "?includeWorkItemRefs=true&api-version=$ApiVersion"
    $pr  = Invoke-AdoPrRest -Method GET -Url $url
    [pscustomobject]@{
        pullRequestId   = $pr.pullRequestId
        status          = $pr.status
        title           = $pr.title
        sourceRefName   = $pr.sourceRefName
        targetRefName   = $pr.targetRefName
        createdBy       = $pr.createdBy.displayName
        creationDate    = $pr.creationDate
        isDraft         = $pr.isDraft
        mergeStatus     = $pr.mergeStatus
        workItemRefCount= ($pr.workItemRefs | Measure-Object).Count
        url             = Format-PrUrl -PrId $pr.pullRequestId
    } | Format-List
}

function Invoke-ListPrs {
    $params = @("api-version=$ApiVersion", "`$top=$Top")
    if ($Status -ne 'all') { $params += "searchCriteria.status=$Status" }
    if ($TargetBranch)     { $params += "searchCriteria.targetRefName=$(ConvertTo-BranchRef $TargetBranch)" }
    if ($SourceBranch)     { $params += "searchCriteria.sourceRefName=$(ConvertTo-BranchRef $SourceBranch)" }
    $url = "$(Get-PrBaseUrl)?$($params -join '&')"

    $resp = Invoke-AdoPrRest -Method GET -Url $url
    $resp.value | ForEach-Object {
        [pscustomobject]@{
            id      = $_.pullRequestId
            status  = $_.status
            title   = $_.title
            source  = $_.sourceRefName
            target  = $_.targetRefName
            author  = $_.createdBy.displayName
            url     = Format-PrUrl -PrId $_.pullRequestId
        }
    } | Format-Table -AutoSize
}

function Invoke-AddComment {
    if (-not $PullRequestId) { throw "-PullRequestId is required for AddComment." }
    $text = Read-BodyFromFileOrInline -FilePath $CommentFilePath -Inline $Comment -FieldName 'Comment'
    if (-not $text) { throw "-CommentFilePath or -Comment is required for AddComment." }

    $body = @{
        comments = @(
            @{ parentCommentId = 0; content = $text; commentType = 1 }
        )
        status = 1   # active
    }
    $url = "$(Get-PrBaseUrl)/$PullRequestId/threads?api-version=$ApiVersion"
    $thread = Invoke-AdoPrRest -Method POST -Url $url -Body $body
    Write-Host "Added comment thread $($thread.id) to PR $PullRequestId."
    Write-Host "URL: $(Format-PrUrl -PrId $PullRequestId)"
}

function Invoke-LinkWorkItems {
    if (-not $PullRequestId) { throw "-PullRequestId is required for LinkWorkItems." }
    if (-not $WorkItemIds)   { throw "-WorkItemIds is required for LinkWorkItems." }
    # ADO has no direct PR↔workitem REST endpoint; the supported path is to add
    # an ArtifactLink on each work item pointing back at the PR.
    $ids = $WorkItemIds -split '\s*,\s*' | Where-Object { $_ }
    # The artifact id format is: vstfs:///Git/PullRequestId/<projectId>%2F<repoId>%2F<prId>
    # Discover projectId + repoId via a repo-info request.
    $repoInfo = Invoke-AdoPrRest -Method GET -Url "$OrgUrl/$ProjectEnc/_apis/git/repositories/${RepositoryEnc}?api-version=$ApiVersion"
    $artifactUri = "vstfs:///Git/PullRequestId/$($repoInfo.project.id)%2F$($repoInfo.id)%2F$PullRequestId"

    foreach ($id in $ids) {
        $patch = @(
            @{
                op    = 'add'
                path  = '/relations/-'
                value = @{
                    rel        = 'ArtifactLink'
                    url        = $artifactUri
                    attributes = @{ name = 'Pull Request' }
                }
            }
        )
        $headers = @{} + $script:baseHeaders
        $headers['Content-Type'] = 'application/json-patch+json; charset=utf-8'
        $url  = "$OrgUrl/$ProjectEnc/_apis/wit/workitems/$id" + "?api-version=$ApiVersion"
        # -InputObject keeps the one-element patch an ARRAY; piping unwraps it to a
        # bare object and the API rejects it ("must pass a valid patch document").
        $json = ConvertTo-Json -InputObject @($patch) -Depth 10 -Compress:$false
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        Invoke-AdoRestMethod -Uri $url -Headers $headers -Method PATCH -Body $bytes | Out-Null
        Write-Host "Linked work item $id to PR $PullRequestId."
    }
    Write-Host "URL: $(Format-PrUrl -PrId $PullRequestId)"
}

# endregion ------------------------------------------------------------------

Install-MsalModuleIfMissing
Confirm-Context

# Authenticate once and build base headers for reuse across all REST calls.
$auth = if ($Pat) {
    Get-AdoToken -OrgUrl $OrgUrl -Pat $Pat
} else {
    Get-AdoToken -OrgUrl $OrgUrl
}
if (-not $auth) { throw "Failed to obtain ADO authentication." }
if ($auth.AuthType -eq 'Bearer') {
    $script:baseHeaders = Get-AdoHeaders -Token $auth.Token
} else {
    $script:baseHeaders = Get-AdoHeaders -Pat $auth.Pat
}

switch ($Operation) {
    'Create'         { Invoke-CreatePr }
    'Update'         { Invoke-UpdatePr }
    'Get'            { Invoke-GetPr }
    'List'           { Invoke-ListPrs }
    'AddComment'     { Invoke-AddComment }
    'LinkWorkItems'  { Invoke-LinkWorkItems }
}
