<#
.SYNOPSIS
    Reads Jira issue details using the Jira REST API v3.

.DESCRIPTION
    - GetIssue : one issue by key, rendered as markdown, with any extra fields you name
    - SearchJql: a JQL query, paginated (nextPageToken) up to -MaxResults, rendered as a summary
                 table followed by the full detail of each issue (or table only with -SummaryOnly)

.PARAMETER Operation
    GetIssue | SearchJql
.PARAMETER BaseUrl
    Jira Cloud base URL. Resolved via hso-atlassian-auth when omitted.
.PARAMETER Email
    Jira account email for Basic auth. Resolved via hso-atlassian-auth when omitted.
.PARAMETER ApiToken
    Jira API token. Resolved via hso-atlassian-auth when omitted.
.PARAMETER IssueKey
    Issue key for GetIssue (e.g. PROJ-123).
.PARAMETER Jql
    JQL query for SearchJql.
.PARAMETER MaxResults
    Maximum issues to return for SearchJql. Default 20, hard cap 1000 (paginated in pages of 100).
.PARAMETER IncludeFields
    Extra fields to fetch and render, by display NAME or id - e.g. "Story","Business Rules",
    "Validations/Edits","MoSCoW Priority". Names are resolved against the tenant's field catalog.
.PARAMETER SummaryOnly
    SearchJql: print only the summary table, not the per-issue detail.

.EXAMPLE
    .\Invoke-JiraIssueRead.ps1 -Operation GetIssue -IssueKey PROJ-123 -IncludeFields "Story","Business Rules"

.EXAMPLE
    .\Invoke-JiraIssueRead.ps1 -Operation SearchJql -Jql "parent = PROJ-10 ORDER BY created" -MaxResults 300 -SummaryOnly
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("GetIssue", "SearchJql")]
    [string]$Operation,

    [string]$BaseUrl,
    [string]$Email,
    [string]$ApiToken,

    [string]$IssueKey,
    [string]$Jql,
    [int]$MaxResults = 20,
    [string[]]$IncludeFields,
    [switch]$SummaryOnly
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
# Field discovery: story points / acceptance criteria / sprint by convention, plus -IncludeFields
# ---------------------------------------------------------------------------
function Get-CustomFieldMap {
    $map = @{}
    foreach ($f in (Get-JiraFieldCatalog)) {
        $nameLower = $f.name.ToLower()
        if (-not $map.ContainsKey("storyPoints") -and ($nameLower -match "story point")) { $map["storyPoints"] = $f.id }
        elseif (-not $map.ContainsKey("acceptanceCriteria") -and ($nameLower -match "acceptance criteria")) { $map["acceptanceCriteria"] = $f.id }
        elseif (-not $map.ContainsKey("sprint") -and ($nameLower -eq "sprint")) { $map["sprint"] = $f.id }
    }
    return $map
}

Write-Host "Discovering custom fields..." -ForegroundColor Cyan
$fieldMap = Get-CustomFieldMap

$extraFields = @()
if ($IncludeFields) {
    foreach ($name in $IncludeFields) { $extraFields += (Resolve-JiraField -NameOrId $name) }
}

$fieldsList = @("summary", "description", "issuetype", "status", "priority", "assignee", "reporter", "labels", "components", "fixVersions", "created", "updated", "subtasks", "issuelinks", "parent", "customfield_10014")
foreach ($key in $fieldMap.Keys) { if ($fieldsList -notcontains $fieldMap[$key]) { $fieldsList += $fieldMap[$key] } }
foreach ($ef in $extraFields) { if ($fieldsList -notcontains $ef.id) { $fieldsList += $ef.id } }
$fieldsParam = $fieldsList -join ","

# ---------------------------------------------------------------------------
# Render one issue as markdown
# ---------------------------------------------------------------------------
function Format-Issue {
    param([object]$Issue, [hashtable]$FieldMap, [object[]]$ExtraFields)

    $f = $Issue.fields
    $summary   = $f.summary
    $type      = if ($f.issuetype) { $f.issuetype.name } else { "Unknown" }
    $status    = if ($f.status) { $f.status.name } else { "Unknown" }
    $priority  = if ($f.priority) { $f.priority.name } else { "(none)" }
    $assignee  = if ($f.assignee) { $f.assignee.displayName } else { "Unassigned" }
    $reporter  = if ($f.reporter) { $f.reporter.displayName } else { "(none)" }
    $created   = if ($f.created) { ([datetime]$f.created).ToString("yyyy-MM-dd") } else { "" }
    $updated   = if ($f.updated) { ([datetime]$f.updated).ToString("yyyy-MM-dd") } else { "" }
    $description = Get-JiraFieldText -Value $f.description

    $storyPoints = "(none)"
    if ($FieldMap.ContainsKey("storyPoints") -and $f.PSObject.Properties[$FieldMap["storyPoints"]]) {
        $spValue = $f.($FieldMap["storyPoints"])
        if ($null -ne $spValue) { $storyPoints = $spValue.ToString() }
    }

    $acceptanceCriteria = "(none)"
    if ($FieldMap.ContainsKey("acceptanceCriteria") -and $f.PSObject.Properties[$FieldMap["acceptanceCriteria"]]) {
        $acceptanceCriteria = Get-JiraFieldText -Value $f.($FieldMap["acceptanceCriteria"])
    }

    $sprint = "(none)"
    if ($FieldMap.ContainsKey("sprint") -and $f.PSObject.Properties[$FieldMap["sprint"]]) {
        $sprintValue = $f.($FieldMap["sprint"])
        if ($sprintValue -is [System.Array] -and $sprintValue.Count -gt 0) {
            $activeSprint = $sprintValue | Where-Object { $_.state -eq "active" } | Select-Object -First 1
            if ($activeSprint) { $sprint = $activeSprint.name } else { $sprint = $sprintValue[-1].name }
        }
        elseif ($null -ne $sprintValue -and $sprintValue.PSObject.Properties["name"]) { $sprint = $sprintValue.name }
    }

    $labels = if ($f.labels -and $f.labels.Count -gt 0) { $f.labels -join ", " } else { "(none)" }
    $components = if ($f.components -and $f.components.Count -gt 0) { ($f.components | ForEach-Object { $_.name }) -join ", " } else { "(none)" }
    $fixVersions = if ($f.fixVersions -and $f.fixVersions.Count -gt 0) { ($f.fixVersions | ForEach-Object { $_.name }) -join ", " } else { "(none)" }

    $parent = "(none)"
    if ($f.PSObject.Properties["parent"] -and $f.parent) { $parent = "$($f.parent.key) - $($f.parent.fields.summary)" }
    elseif ($f.PSObject.Properties["customfield_10014"] -and $f.customfield_10014) { $parent = $f.customfield_10014 }

    $subtasks = ""
    if ($f.subtasks -and $f.subtasks.Count -gt 0) {
        $subtasks = ($f.subtasks | ForEach-Object { "  - $($_.key) - $($_.fields.summary) ($($_.fields.status.name))" }) -join "`n"
    }

    $linkedIssues = ""
    if ($f.issuelinks -and $f.issuelinks.Count -gt 0) {
        $linkedIssues = ($f.issuelinks | ForEach-Object {
            $link = $_
            if ($link.PSObject.Properties["outwardIssue"] -and $link.outwardIssue) { "  - $($link.type.outward): $($link.outwardIssue.key) - $($link.outwardIssue.fields.summary)" }
            elseif ($link.PSObject.Properties["inwardIssue"] -and $link.inwardIssue) { "  - $($link.type.inward): $($link.inwardIssue.key) - $($link.inwardIssue.fields.summary)" }
        } | Where-Object { $_ }) -join "`n"
    }

    $output = @"
## $($Issue.key) - $summary

**Type:** $type  |  **Status:** $status  |  **Priority:** $priority
**Assignee:** $assignee  |  **Reporter:** $reporter
**Sprint:** $sprint  |  **Story Points:** $storyPoints
**Created:** $created  |  **Updated:** $updated
**Parent:** $parent
**Components:** $components  |  **Fix Versions:** $fixVersions
**Labels:** $labels

### Description
$description
"@

    if ($acceptanceCriteria -ne "(none)") { $output += "`n### Acceptance Criteria`n$acceptanceCriteria`n" }

    foreach ($ef in $ExtraFields) {
        if ($ef.id -eq $FieldMap["acceptanceCriteria"]) { continue }
        $val = "(none)"
        if ($f.PSObject.Properties[$ef.id]) { $val = Get-JiraFieldText -Value $f.($ef.id) }
        $output += "`n### $($ef.name)`n$val`n"
    }

    if ($subtasks) { $output += "`n### Sub-tasks`n$subtasks`n" }
    if ($linkedIssues) { $output += "`n### Linked Issues`n$linkedIssues`n" }
    $output += "`n**URL:** $BaseUrl/browse/$($Issue.key)`n"
    return $output
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
switch ($Operation) {

    "GetIssue" {
        if (-not $IssueKey) { throw "IssueKey is required for GetIssue operation." }
        Write-Host "Fetching $IssueKey..." -ForegroundColor Cyan
        $issue = Invoke-JiraApi -Path "/rest/api/3/issue/${IssueKey}?fields=$fieldsParam" -Context "Get $IssueKey"
        Write-Output (Format-Issue -Issue $issue -FieldMap $fieldMap -ExtraFields $extraFields)
    }

    "SearchJql" {
        if (-not $Jql) { throw "Jql is required for SearchJql operation." }
        if ($MaxResults -gt 1000) { $MaxResults = 1000 }
        if ($MaxResults -lt 1) { $MaxResults = 1 }

        Write-Host "Executing JQL: $Jql" -ForegroundColor Cyan
        $search = Search-JiraIssues -Jql $Jql -Fields $fieldsList -MaxResults $MaxResults
        $issues = $search.Issues
        Write-Host "Showing $($issues.Count) issue(s)." -ForegroundColor Green

        if ($issues.Count -eq 0) { Write-Output "No issues found matching: $Jql"; return }

        $table = @("| Key | Summary | Type | Status | Priority | Assignee |",
                   "|-----|---------|------|--------|----------|----------|")
        foreach ($issue in $issues) {
            $f       = $issue.fields
            $type    = if ($f.issuetype) { $f.issuetype.name } else { "" }
            $status  = if ($f.status) { $f.status.name } else { "" }
            $prio    = if ($f.priority) { $f.priority.name } else { "" }
            $person  = if ($f.assignee) { $f.assignee.displayName } else { "Unassigned" }
            $summ    = [string]$f.summary
            if ($summ.Length -gt 60) { $summ = $summ.Substring(0, 57) + "..." }
            $table += "| $($issue.key) | $($summ -replace '\|', '/') | $type | $status | $prio | $person |"
        }
        Write-Output ($table -join "`n")

        if (-not $SummaryOnly) {
            Write-Output ""; Write-Output "---"; Write-Output ""
            foreach ($issue in $issues) {
                Write-Output (Format-Issue -Issue $issue -FieldMap $fieldMap -ExtraFields $extraFields)
                Write-Output ""; Write-Output "---"; Write-Output ""
            }
        }

        if ($search.HasMore) { Write-Output ""; Write-Output "_More results are available. Refine your JQL or increase -MaxResults (cap 1000)._" }
    }
}
