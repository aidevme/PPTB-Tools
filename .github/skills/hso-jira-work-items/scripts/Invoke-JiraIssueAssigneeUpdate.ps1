<#
.SYNOPSIS
    Assigns Jira issues to a user (and optionally transitions status) with strict user
    resolution, mandatory read-back verification, and isolated per-issue error handling.

.DESCRIPTION
    Updates the assignee of one or more Jira issues using Jira Cloud REST API v3.

    Safety model:
    - Exact user resolution BEFORE any write. The target user must resolve to exactly one
      account. Preferred input is -AssigneeAccountId. When -AssigneeDisplayName or
      -AssigneeEmail is used, exactly one exact match is required, otherwise the script
      stops and lists the candidates for disambiguation.
    - Mandatory post-write verification (default on). After each write the issue is re-read
      and the assignee (and status, when transitioning) is compared to the intended target.
      An HTTP 204 alone is NOT treated as final success.
    - Per-issue isolation. In bulk runs one failing issue never aborts the batch. Each issue
      returns one of: updated | already | failed | error | failed-verify | dryrun.

    Target selection (choose one):
    - -IssueKey           single issue
    - -IssueKeys          explicit list of issue keys (bulk)
    - -ParentIssueKey     a parent; add -IncludeRelatedTasks to also include sub-tasks and
                          child issues (JQL: parent = KEY)

    Assignee intent (choose one):
    - -AssigneeAccountId  Atlassian accountId (best, unambiguous)
    - -AssigneeDisplayName exact display name (requires exactly one match)
    - -AssigneeEmail      exact email address (requires exactly one match; may be hidden by
                          tenant privacy settings)
    - -Unassign           clear the assignee

    Optional status transition:
    - -TargetStatus       validated against JIRA_ALLOWED_STATUSES, applied per issue using
                          strict transition matching (no guessing).

.PARAMETER BaseUrl
    Jira Cloud base URL (e.g., https://your-domain.atlassian.net). Resolved via hso-atlassian-auth when omitted (env vars, then gitignored auth-settings.json).

.PARAMETER Email
    Jira account email used for Basic auth. Resolved via hso-atlassian-auth when omitted (env vars, then gitignored auth-settings.json).

.PARAMETER ApiToken
    Jira API token. Resolved via hso-atlassian-auth when omitted (env vars, then gitignored auth-settings.json).

.PARAMETER IssueKey
    Single Jira issue key (e.g., PROJ-123).

.PARAMETER IssueKeys
    One or more Jira issue keys for bulk assignment.

.PARAMETER ParentIssueKey
    Parent issue key. Combine with -IncludeRelatedTasks to assign the parent plus related tasks.

.PARAMETER IncludeRelatedTasks
    Discover and include sub-tasks and child issues (parent = KEY) of -ParentIssueKey.

.PARAMETER AssigneeAccountId
    Atlassian accountId of the target assignee (preferred, unambiguous input).

.PARAMETER AssigneeDisplayName
    Exact display name of the target assignee. Must resolve to exactly one user.

.PARAMETER AssigneeEmail
    Exact email of the target assignee. Must resolve to exactly one user.

.PARAMETER Unassign
    Clear the assignee instead of setting a user.

.PARAMETER TargetStatus
    Optional status to transition each issue to. Validated against JIRA_ALLOWED_STATUSES.

.PARAMETER DryRun
    Plan only. Resolves the user and candidate issues and reports intended actions without writing.

.PARAMETER VerifyAfterWrite
    Re-read each issue after writing and verify the change. Default: $true. Pass -VerifyAfterWrite:$false to skip.

.PARAMETER FailOnVerifyMismatch
    When verification detects a mismatch, mark the issue failed-verify (and exit non-zero). Default: $true.

.PARAMETER ConfirmUpdate
    Required switch to perform writes. Not required for -DryRun.

.EXAMPLE
    # Single issue, by accountId
    .\Invoke-JiraIssueAssigneeUpdate.ps1 -IssueKey "PROJ-123" -AssigneeAccountId "5b10ac8d82e05b22cc7d4ef5" -ConfirmUpdate

.EXAMPLE
    # Parent plus related tasks, assign by exact display name and move to a status
    .\Invoke-JiraIssueAssigneeUpdate.ps1 -ParentIssueKey "PROJ-100" -IncludeRelatedTasks `
        -AssigneeDisplayName "Jane Doe" -TargetStatus "In Progress" -ConfirmUpdate

.EXAMPLE
    # Bulk list, dry run first
    .\Invoke-JiraIssueAssigneeUpdate.ps1 -IssueKeys "PROJ-1","PROJ-2","PROJ-3" -AssigneeEmail "jane@example.com" -DryRun

.NOTES
    Requires: PowerShell 5.1+
    API: Jira Cloud REST API v3
    Auth: HTTP Basic (email:api_token, Base64-encoded)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$Email,

    [Parameter(Mandatory = $false)]
    [string]$ApiToken,

    [ValidatePattern('^[A-Z][A-Z0-9]+-[0-9]+$')]
    [string]$IssueKey,

    [string[]]$IssueKeys,

    [ValidatePattern('^[A-Z][A-Z0-9]+-[0-9]+$')]
    [string]$ParentIssueKey,

    [switch]$IncludeRelatedTasks,

    [string]$AssigneeAccountId,

    [string]$AssigneeDisplayName,

    [string]$AssigneeEmail,

    [switch]$Unassign,

    [string]$TargetStatus,

    [switch]$DryRun,

    [bool]$VerifyAfterWrite = $true,

    [bool]$FailOnVerifyMismatch = $true,

    [switch]$ConfirmUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"


# ---------------------------------------------------------------------------
# Atlassian settings + auth header
# ---------------------------------------------------------------------------
# Auth lives in the hso-atlassian-auth foundation library, not here and not in hso-shared-scripts:
# Atlassian Cloud is HTTP Basic, not Entra, so per ADR 0060 it stays outside the Entra provider
# family. The upstream version resolved ATLASSIAN_* from .env / .env.local and rebuilt the Basic
# header in every script; this template does not use .env, and duplicating
# auth five times is exactly what ADR 0019 exists to prevent.
$authDir = Join-Path $PSScriptRoot "..\..\hso-atlassian-auth\scripts"
. (Join-Path $authDir "Atlassian-Auth.ps1")

$atlassian = Get-AtlassianSettings -BaseUrl $BaseUrl -Email $Email -ApiToken $ApiToken
$BaseUrl   = $atlassian.BaseUrl
$Email     = $atlassian.Email
$ApiToken  = $atlassian.ApiToken

$headers = Get-AtlassianHeaders -Email $Email -ApiToken $ApiToken
$headers["Content-Type"] = "application/json"


. (Join-Path $PSScriptRoot "Jira-Common.ps1")

# ---------------------------------------------------------------------------
# Input validation: exactly one target selector, exactly one assignee intent
# ---------------------------------------------------------------------------
$selectorCount = 0
if (-not [string]::IsNullOrWhiteSpace($IssueKey)) { $selectorCount++ }
if ($IssueKeys -and $IssueKeys.Count -gt 0) { $selectorCount++ }
if (-not [string]::IsNullOrWhiteSpace($ParentIssueKey)) { $selectorCount++ }
if ($selectorCount -eq 0) { throw "Provide a target: -IssueKey, -IssueKeys, or -ParentIssueKey." }
if ($IncludeRelatedTasks -and [string]::IsNullOrWhiteSpace($ParentIssueKey)) { throw "-IncludeRelatedTasks requires -ParentIssueKey." }

$intentCount = 0
if (-not [string]::IsNullOrWhiteSpace($AssigneeAccountId)) { $intentCount++ }
if (-not [string]::IsNullOrWhiteSpace($AssigneeDisplayName)) { $intentCount++ }
if (-not [string]::IsNullOrWhiteSpace($AssigneeEmail)) { $intentCount++ }
if ($Unassign) { $intentCount++ }
if ($intentCount -gt 1) { throw "Choose exactly one assignee intent: -AssigneeAccountId, -AssigneeDisplayName, -AssigneeEmail, or -Unassign." }

$hasAssigneeAction = ($intentCount -eq 1)
$hasStatusAction   = -not [string]::IsNullOrWhiteSpace($TargetStatus)
if (-not $hasAssigneeAction -and -not $hasStatusAction) { throw "Nothing to do: provide an assignee intent and/or -TargetStatus." }
if (-not $DryRun -and -not $ConfirmUpdate) { throw "Assignee/status changes are writes to the client's backlog. Re-run with -ConfirmUpdate (or -DryRun to plan)." }

# ---------------------------------------------------------------------------
# Guardrail: the target status (if any) must be on the JIRA_ALLOWED_STATUSES list
# ---------------------------------------------------------------------------
if ($hasStatusAction) { $TargetStatus = Assert-JiraStatusAllowed -TargetStatus $TargetStatus }

# ---------------------------------------------------------------------------
# Helper: Strict user resolution -> exactly one account or fail
# ---------------------------------------------------------------------------
function Resolve-JiraUser {
    param(
        [string]$AccountId,
        [string]$DisplayName,
        [string]$EmailQuery
    )

    if (-not [string]::IsNullOrWhiteSpace($AccountId)) {
        try {
            $u = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/user?accountId=$([Uri]::EscapeDataString($AccountId))" -Headers $headers -Method Get
        }
        catch {
            throw "Could not resolve accountId '$AccountId'. Verify the value. ($($_.Exception.Message))"
        }
        return [pscustomobject]@{ AccountId = $u.accountId; DisplayName = $u.displayName }
    }

    $query = if (-not [string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName } else { $EmailQuery }
    $byEmail = -not [string]::IsNullOrWhiteSpace($EmailQuery)

    $candidates = @()
    try {
        # Unroll explicitly: a JSON array can come back as ONE nested Object[] in PowerShell 7, which made every exact-match test fail.
        $candidates = @((Invoke-JiraApi -Path "/rest/api/3/user/search?query=$([Uri]::EscapeDataString($query))&maxResults=50" -Context 'User search') | ForEach-Object { $_ })
    }
    catch {
        throw "User search failed for '$query': $($_.Exception.Message)"
    }

    if ($byEmail) {
        $exact = @($candidates | Where-Object {
            $_.PSObject.Properties['emailAddress'] -and $_.emailAddress -and ($_.emailAddress -ieq $EmailQuery)
        })
    }
    else {
        $exact = @($candidates | Where-Object {
            $_.PSObject.Properties['displayName'] -and $_.displayName -and ($_.displayName -ieq $DisplayName)
        })
    }

    if ($exact.Count -eq 1) {
        return [pscustomobject]@{ AccountId = $exact[0].accountId; DisplayName = $exact[0].displayName }
    }

    # Build a disambiguation list (never includes secrets; emailAddress may be hidden by Jira).
    $list = if ($candidates.Count -gt 0) {
        ($candidates | ForEach-Object {
            $em = if ($_.PSObject.Properties['emailAddress'] -and $_.emailAddress) { $_.emailAddress } else { "(email hidden)" }
            "  - $($_.displayName) | $em | accountId=$($_.accountId)"
        }) -join "`n"
    } else {
        "  (no users matched the query)"
    }

    if ($exact.Count -gt 1) {
        throw "Ambiguous user '$query': $($exact.Count) exact matches. Re-run with -AssigneeAccountId.`nCandidates:`n$list"
    }
    throw "No exact user match for '$query'. Re-run with an exact value or -AssigneeAccountId.`nCandidates:`n$list"
}

# ---------------------------------------------------------------------------
# Resolve the target user ONCE, up front, before any write.
# ---------------------------------------------------------------------------
$targetAccountId = $null
$targetUserLabel = "(unassigned)"
if ($hasAssigneeAction -and -not $Unassign) {
    $resolved = Resolve-JiraUser -AccountId $AssigneeAccountId -DisplayName $AssigneeDisplayName -EmailQuery $AssigneeEmail
    $targetAccountId = $resolved.AccountId
    $targetUserLabel = $resolved.DisplayName
    Write-Host "Resolved assignee: $targetUserLabel (accountId=$targetAccountId)" -ForegroundColor Cyan
}
elseif ($Unassign) {
    Write-Host "Assignee target: (unassign)" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Build candidate issue list
# ---------------------------------------------------------------------------
function Get-RelatedIssueKeys {
    param([string]$ParentKey)

    $keys = [System.Collections.Generic.List[string]]::new()

    # Sub-tasks via the parent's fields.
    try {
        $parentIssue = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/issue/${ParentKey}?fields=subtasks" -Headers $headers -Method Get
        if ($parentIssue.fields.PSObject.Properties['subtasks'] -and $parentIssue.fields.subtasks) {
            foreach ($st in $parentIssue.fields.subtasks) { $keys.Add($st.key) }
        }
    }
    catch {
        Write-Warning "Could not read sub-tasks for ${ParentKey}: $($_.Exception.Message)"
    }

    # Child issues via JQL (stories/tasks under an epic, sub-tasks under a story), paginated.
    try {
        $search = Search-JiraIssues -Jql ('parent = "{0}"' -f $ParentKey) -Fields @('summary') -MaxResults 1000
        foreach ($i in $search.Issues) { $keys.Add($i.key) }
    }
    catch {
        Write-Warning "Child-issue lookup for ${ParentKey}: $($_.Exception.Message)"
    }

    return $keys
}

$candidateKeys = [System.Collections.Generic.List[string]]::new()
if (-not [string]::IsNullOrWhiteSpace($IssueKey)) { $candidateKeys.Add($IssueKey) }
if ($IssueKeys) { foreach ($k in $IssueKeys) { if (-not [string]::IsNullOrWhiteSpace($k)) { $candidateKeys.Add($k.Trim()) } } }
if (-not [string]::IsNullOrWhiteSpace($ParentIssueKey)) {
    $candidateKeys.Add($ParentIssueKey)
    if ($IncludeRelatedTasks) {
        foreach ($rk in (Get-RelatedIssueKeys -ParentKey $ParentIssueKey)) { $candidateKeys.Add($rk) }
    }
}

# Dedupe, preserve order.
$seen = @{}
$issueList = @()
foreach ($k in $candidateKeys) {
    $kk = $k.ToUpperInvariant()
    if (-not $seen.ContainsKey($kk)) {
        $seen[$kk] = $true
        $issueList += $k
    }
}

if ($issueList.Count -eq 0) {
    throw "No target issues resolved."
}

Write-Host "Target issues ($($issueList.Count)): $($issueList -join ', ')" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Write guard
# ---------------------------------------------------------------------------
if (-not $DryRun -and -not $ConfirmUpdate) {
    throw "Write blocked. Re-run with -ConfirmUpdate to apply changes (or -DryRun to preview)."
}

# ---------------------------------------------------------------------------
# Per-issue sub-action helpers (each returns a sub-result object).
# ---------------------------------------------------------------------------
function Update-IssueAssignee {
    param([string]$Key)

    $cur = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/issue/${Key}?fields=assignee" -Headers $headers -Method Get
    $beforeId = if ($cur.fields.assignee) { $cur.fields.assignee.accountId } else { $null }
    $beforeName = if ($cur.fields.assignee) { $cur.fields.assignee.displayName } else { "(unassigned)" }
    $targetName = if ($Unassign) { "(unassigned)" } else { $targetUserLabel }

    if ($beforeId -eq $targetAccountId) {
        return [pscustomobject]@{ Action = "assignee"; Result = "already"; Before = $beforeName; After = $beforeName; Message = "Assignee already set" }
    }

    if ($DryRun) {
        return [pscustomobject]@{ Action = "assignee"; Result = "dryrun"; Before = $beforeName; After = $targetName; Message = "Would set assignee to $targetName" }
    }

    $body = @{ accountId = $targetAccountId } | ConvertTo-Json
    Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/issue/${Key}/assignee" -Headers $headers -Method Put -Body $body | Out-Null

    $afterName = $targetName
    if ($VerifyAfterWrite) {
        $verify = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/issue/${Key}?fields=assignee" -Headers $headers -Method Get
        $afterId = if ($verify.fields.assignee) { $verify.fields.assignee.accountId } else { $null }
        $afterName = if ($verify.fields.assignee) { $verify.fields.assignee.displayName } else { "(unassigned)" }
        if ($afterId -ne $targetAccountId) {
            return [pscustomobject]@{ Action = "assignee"; Result = "failed-verify"; Before = $beforeName; After = $afterName; Message = "Write returned success but read-back assignee does not match target" }
        }
    }

    return [pscustomobject]@{ Action = "assignee"; Result = "updated"; Before = $beforeName; After = $afterName; Message = "Assignee updated" }
}

function Update-IssueStatus {
    param([string]$Key)

    $cur = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/issue/${Key}?fields=status" -Headers $headers -Method Get
    $beforeStatus = $cur.fields.status.name

    if ($beforeStatus -ieq $TargetStatus) {
        return [pscustomobject]@{ Action = "status"; Result = "already"; Before = $beforeStatus; After = $beforeStatus; Message = "Already in target status" }
    }

    # Match the DESTINATION status first, then the transition name (Jira-Common Find-JiraTransition).
    $found = Find-JiraTransition -IssueKey $Key -TargetStatus $TargetStatus
    $targetTransition = $found.Transition
    if (-not $targetTransition) {
        return [pscustomobject]@{ Action = "status"; Result = "failed"; Before = $beforeStatus; After = $beforeStatus; Message = "No transition leads to '$TargetStatus' from '$beforeStatus'. Available: $($found.Available -join '; ')" }
    }

    if ($DryRun) {
        return [pscustomobject]@{ Action = "status"; Result = "dryrun"; Before = $beforeStatus; After = $TargetStatus; Message = "Would transition to $TargetStatus" }
    }

    $payload = @{ transition = @{ id = $targetTransition.id } } | ConvertTo-Json -Depth 5
    Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/issue/${Key}/transitions" -Headers $headers -Method Post -Body $payload | Out-Null

    $afterStatus = $TargetStatus
    if ($VerifyAfterWrite) {
        $verify = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/issue/${Key}?fields=status" -Headers $headers -Method Get
        $afterStatus = $verify.fields.status.name
        if ($afterStatus -ine $TargetStatus) {
            return [pscustomobject]@{ Action = "status"; Result = "failed-verify"; Before = $beforeStatus; After = $afterStatus; Message = "Write returned success but read-back status does not match target" }
        }
    }

    return [pscustomobject]@{ Action = "status"; Result = "updated"; Before = $beforeStatus; After = $afterStatus; Message = "Status transitioned" }
}

# ---------------------------------------------------------------------------
# Process each issue with isolated error handling.
# ---------------------------------------------------------------------------
function Resolve-OverallResult {
    param([string[]]$SubResults)

    if ($SubResults -contains "error") { return "error" }
    if ($SubResults -contains "failed") { return "failed" }
    if ($SubResults -contains "failed-verify") { return "failed-verify" }
    if ($SubResults -contains "dryrun") { return "dryrun" }
    if ((@($SubResults | Where-Object { $_ -ne "already" })).Count -eq 0) { return "already" }
    return "updated"
}

$results = @()
foreach ($key in $issueList) {
    $subResults = @()
    $assigneeBefore = ""; $assigneeAfter = ""
    $statusBefore = ""; $statusAfter = ""
    $messages = @()

    try {
        if ($hasAssigneeAction) {
            $a = Update-IssueAssignee -Key $key
            $subResults += $a.Result
            $assigneeBefore = $a.Before
            $assigneeAfter = $a.After
            $messages += "assignee:$($a.Result) ($($a.Message))"
        }
        if ($hasStatusAction) {
            $s = Update-IssueStatus -Key $key
            $subResults += $s.Result
            $statusBefore = $s.Before
            $statusAfter = $s.After
            $messages += "status:$($s.Result) ($($s.Message))"
        }

        $overall = Resolve-OverallResult -SubResults $subResults
        $results += [pscustomobject]@{
            Issue          = $key
            Result         = $overall
            AssigneeBefore = $assigneeBefore
            AssigneeAfter  = $assigneeAfter
            StatusBefore   = $statusBefore
            StatusAfter    = $statusAfter
            Message        = ($messages -join "; ")
        }
    }
    catch {
        $results += [pscustomobject]@{
            Issue          = $key
            Result         = "error"
            AssigneeBefore = $assigneeBefore
            AssigneeAfter  = $assigneeAfter
            StatusBefore   = $statusBefore
            StatusAfter    = $statusAfter
            Message        = $_.Exception.Message
        }
    }
}

# ---------------------------------------------------------------------------
# Human-readable lines + structured JSON summary
# ---------------------------------------------------------------------------
foreach ($r in $results) {
    Write-Host ("{0}: {1} | assignee {2} -> {3} | status {4} -> {5} | {6}" -f `
        $r.Issue, $r.Result, $r.AssigneeBefore, $r.AssigneeAfter, $r.StatusBefore, $r.StatusAfter, $r.Message)
}

$summary = [pscustomobject]@{
    TotalCandidates = $results.Count
    Updated         = (@($results | Where-Object { $_.Result -eq "updated" })).Count
    Already         = (@($results | Where-Object { $_.Result -eq "already" })).Count
    Failed          = (@($results | Where-Object { $_.Result -eq "failed" })).Count
    FailedVerify    = (@($results | Where-Object { $_.Result -eq "failed-verify" })).Count
    Error           = (@($results | Where-Object { $_.Result -eq "error" })).Count
    DryRun          = (@($results | Where-Object { $_.Result -eq "dryrun" })).Count
    TargetAssignee  = [pscustomobject]@{ AccountId = $targetAccountId; DisplayName = $targetUserLabel; Unassign = [bool]$Unassign }
    TargetStatus    = if ($hasStatusAction) { $TargetStatus } else { $null }
    Results         = $results
}

Write-Output ($summary | ConvertTo-Json -Depth 6)

# ---------------------------------------------------------------------------
# Exit code policy
# ---------------------------------------------------------------------------
$hardFailures = $summary.Failed + $summary.Error
$verifyFailures = $summary.FailedVerify
if ($hardFailures -gt 0 -or ($FailOnVerifyMismatch -and $verifyFailures -gt 0)) {
    throw "$($hardFailures) failed/error and $($verifyFailures) failed-verify issue(s). See summary above."
}
