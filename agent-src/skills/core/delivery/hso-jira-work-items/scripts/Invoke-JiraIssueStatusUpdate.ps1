<#
.SYNOPSIS
    Transitions a Jira issue to a target status using Jira REST API v3 transitions.

.DESCRIPTION
    Finds the transition that lands the issue in -TargetStatus. Matching is on the transition's
    DESTINATION status first, then on the transition name - workflows routinely name the two
    differently (transition "Start Review" -> status "In Review"). Optionally applies the
    same transition to every sub-task.

    The target status is validated against JIRA_ALLOWED_STATUSES (environment) or
    JiraAllowedStatuses (auth-settings.json), resolved via hso-atlassian-auth. Example:
        JIRA_ALLOWED_STATUSES=To Do,In Review,Ready,Done
    A status outside that list is refused. Configure it per engagement.

    Every transition is verified by reading the issue back; an HTTP 204 alone is not success.

.PARAMETER BaseUrl
    Jira Cloud base URL. Resolved via hso-atlassian-auth when omitted.
.PARAMETER Email
    Jira account email for Basic auth. Resolved via hso-atlassian-auth when omitted.
.PARAMETER ApiToken
    Jira API token. Resolved via hso-atlassian-auth when omitted.
.PARAMETER IssueKey
    Issue key (e.g. PROJ-211).
.PARAMETER TargetStatus
    Target STATUS name (must be in the allowed list).
.PARAMETER IncludeSubtasks
    Also transition all sub-tasks of the issue.
.PARAMETER DryRun
    Show which transition would be applied to each issue, write nothing.
.PARAMETER ConfirmUpdate
    Required to perform the write.

.EXAMPLE
    .\Invoke-JiraIssueStatusUpdate.ps1 -IssueKey PROJ-211 -TargetStatus "In Review" -ConfirmUpdate
#>

[CmdletBinding()]
param(
    [string]$BaseUrl,
    [string]$Email,
    [string]$ApiToken,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Z][A-Z0-9]+-[0-9]+$')]
    [string]$IssueKey,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetStatus,

    [switch]$IncludeSubtasks,
    [switch]$DryRun,
    [switch]$ConfirmUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Atlassian settings + auth header (hso-atlassian-auth, ADR 0060), then the shared helpers
# ---------------------------------------------------------------------------
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
# Guardrail: the target status must be on the allowed list
# ---------------------------------------------------------------------------
$TargetStatus = Assert-JiraStatusAllowed -TargetStatus $TargetStatus

if (-not $DryRun -and -not $ConfirmUpdate) {
    throw "Transitioning a Jira issue is a write to the client's backlog. Re-run with -ConfirmUpdate (or -DryRun to preview)."
}

$issue = Invoke-JiraApi -Path "/rest/api/3/issue/${IssueKey}?fields=subtasks,status" -Context "Read $IssueKey"
$issueKeys = @($IssueKey)
if ($IncludeSubtasks -and $issue.fields.PSObject.Properties['subtasks'] -and $issue.fields.subtasks) {
    $issueKeys += @($issue.fields.subtasks | ForEach-Object { $_.key })
}

$results = @()
foreach ($currentIssueKey in $issueKeys) {
    try {
        $issueBefore = Invoke-JiraApi -Path "/rest/api/3/issue/${currentIssueKey}?fields=status" -Context "Read $currentIssueKey"
        $beforeStatus = $issueBefore.fields.status.name

        if ($beforeStatus -ieq $TargetStatus) {
            $results += [pscustomobject]@{ Issue = $currentIssueKey; Result = "already"; Before = $beforeStatus; After = $beforeStatus; Message = "Already in target status" }
            continue
        }

        $found = Find-JiraTransition -IssueKey $currentIssueKey -TargetStatus $TargetStatus
        if (-not $found.Transition) {
            $results += [pscustomobject]@{ Issue = $currentIssueKey; Result = "failed"; Before = $beforeStatus; After = $beforeStatus; Message = "No transition leads to '$TargetStatus' from '$beforeStatus'. Available: $($found.Available -join '; ')" }
            continue
        }

        if ($DryRun) {
            $results += [pscustomobject]@{ Issue = $currentIssueKey; Result = "dryrun"; Before = $beforeStatus; After = $TargetStatus; Message = "Would apply transition '$($found.Transition.name)'" }
            continue
        }

        $payload = @{ transition = @{ id = $found.Transition.id } }
        Invoke-JiraApi -Method Post -Path "/rest/api/3/issue/${currentIssueKey}/transitions" -Body $payload -Context "Transition $currentIssueKey" | Out-Null

        $issueAfter = Invoke-JiraApi -Path "/rest/api/3/issue/${currentIssueKey}?fields=status" -Context "Read-back $currentIssueKey"
        $afterStatus = $issueAfter.fields.status.name

        if ($afterStatus -ine $TargetStatus) {
            $results += [pscustomobject]@{ Issue = $currentIssueKey; Result = "failed-verify"; Before = $beforeStatus; After = $afterStatus; Message = "Transition POST succeeded but read-back status does not match target '$TargetStatus'" }
            continue
        }

        $results += [pscustomobject]@{ Issue = $currentIssueKey; Result = "updated"; Before = $beforeStatus; After = $afterStatus; Message = "Transition '$($found.Transition.name)' applied" }
    }
    catch {
        $results += [pscustomobject]@{ Issue = $currentIssueKey; Result = "error"; Before = "?"; After = "?"; Message = $_.Exception.Message }
    }
}

$results | ForEach-Object { Write-Output ("$($_.Issue): $($_.Result) | $($_.Before) -> $($_.After) | $($_.Message)") }

$failedCount = ($results | Where-Object { $_.Result -in @("failed", "error") } | Measure-Object).Count
if ($failedCount -gt 0) { throw "$failedCount issue(s) were not transitioned successfully." }

$verifyFailedCount = ($results | Where-Object { $_.Result -eq "failed-verify" } | Measure-Object).Count
if ($verifyFailedCount -gt 0) { throw "$verifyFailedCount issue(s) reported success but failed read-back verification." }
