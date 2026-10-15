<#
.SYNOPSIS
    Updates the content of an existing Jira Cloud issue using REST API v3.

.DESCRIPTION
    Updates any combination of: summary, description, parent, labels (replace / add / remove),
    components (replace), and custom fields addressed by display NAME or id. Values are shaped for
    each field's schema (textarea -> ADF, select -> option, ...). At least one change is required.

    Assignee and status have their own scripts (Invoke-JiraIssueAssigneeUpdate.ps1,
    Invoke-JiraIssueStatusUpdate.ps1). Priority is deliberately not written by this skill.

    -DryRun prints the exact payload and writes nothing. Every real write requires -ConfirmUpdate.
    After a write the issue is re-read and the stored summary / parent / labels are reported.

.PARAMETER BaseUrl
    Jira Cloud base URL. Resolved via hso-atlassian-auth when omitted.
.PARAMETER Email
    Jira account email for Basic auth. Resolved via hso-atlassian-auth when omitted.
.PARAMETER ApiToken
    Jira API token. Resolved via hso-atlassian-auth when omitted.
.PARAMETER IssueKey
    Issue key to update (e.g. PROJ-211).
.PARAMETER SummaryText
    New summary.
.PARAMETER DescriptionText
    New description, inline. Markdown-ish text is converted to ADF.
.PARAMETER DescriptionFilePath
    Path to a UTF-8 text/markdown file whose content becomes the new description.
.PARAMETER ParentIssueKey
    New parent (re-parent a Story under a different Epic, for example).
.PARAMETER Labels
    Replace the label set with exactly these labels.
.PARAMETER AddLabels
    Add these labels, keeping existing ones.
.PARAMETER RemoveLabels
    Remove these labels.
.PARAMETER Components
    Replace the component set with exactly these component NAMES.
.PARAMETER Fields
    Hashtable of additional fields: field display name or id -> value.
.PARAMETER FieldsJsonFilePath
    Path to a JSON object with the same shape as -Fields.
.PARAMETER DryRun
    Print the payload and stop.
.PARAMETER ConfirmUpdate
    Required to perform the write.

.EXAMPLE
    .\Invoke-JiraIssueContentUpdate.ps1 -IssueKey PROJ-211 -DescriptionFilePath .\story.md `
        -Fields @{ 'Acceptance Criteria' = (Get-Content .\ac.md -Raw); 'Business Rules' = (Get-Content .\rules.md -Raw) } `
        -AddLabels team-x -ConfirmUpdate

.EXAMPLE
    .\Invoke-JiraIssueContentUpdate.ps1 -IssueKey PROJ-211 -ParentIssueKey PROJ-10 -Components "My Component" -ConfirmUpdate
#>

[CmdletBinding()]
param(
    [string]$BaseUrl,
    [string]$Email,
    [string]$ApiToken,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Z][A-Z0-9]+-[0-9]+$')]
    [string]$IssueKey,

    [string]$SummaryText,
    [string]$DescriptionText,
    [string]$DescriptionFilePath,

    [ValidatePattern('^[A-Z][A-Z0-9]+-[0-9]+$')]
    [string]$ParentIssueKey,

    [string[]]$Labels,
    [string[]]$AddLabels,
    [string[]]$RemoveLabels,
    [string[]]$Components,

    [hashtable]$Fields,
    [string]$FieldsJsonFilePath,

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
# Input validation
# ---------------------------------------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($DescriptionText) -and -not [string]::IsNullOrWhiteSpace($DescriptionFilePath)) {
    throw "Provide either -DescriptionText or -DescriptionFilePath, not both."
}
if ($Labels -and ($AddLabels -or $RemoveLabels)) {
    throw "-Labels replaces the whole set; do not combine it with -AddLabels / -RemoveLabels."
}

$descriptionRaw = Read-JiraTextInput -Text $DescriptionText -FilePath $DescriptionFilePath
$hasDescriptionUpdate = -not [string]::IsNullOrWhiteSpace($descriptionRaw)
$hasSummaryUpdate     = -not [string]::IsNullOrWhiteSpace($SummaryText)
$hasParentUpdate      = -not [string]::IsNullOrWhiteSpace($ParentIssueKey)
$hasLabelReplace      = ($null -ne $Labels)
$hasLabelEdit         = (($AddLabels -and $AddLabels.Count -gt 0) -or ($RemoveLabels -and $RemoveLabels.Count -gt 0))
$hasComponentReplace  = ($null -ne $Components)

$extraMap = @{}
if (-not [string]::IsNullOrWhiteSpace($FieldsJsonFilePath)) {
    $json = Read-JiraJsonFile -FilePath $FieldsJsonFilePath
    foreach ($p in $json.PSObject.Properties) { $extraMap[$p.Name] = $p.Value }
}
if ($Fields) { foreach ($k in $Fields.Keys) { $extraMap[[string]$k] = $Fields[$k] } }
$hasFieldUpdate = ($extraMap.Count -gt 0)

if (-not ($hasDescriptionUpdate -or $hasSummaryUpdate -or $hasParentUpdate -or $hasLabelReplace -or $hasLabelEdit -or $hasComponentReplace -or $hasFieldUpdate)) {
    throw "Nothing to update. Provide at least one of: -SummaryText, -DescriptionText/-DescriptionFilePath, -ParentIssueKey, -Labels/-AddLabels/-RemoveLabels, -Components, -Fields/-FieldsJsonFilePath."
}

# ---------------------------------------------------------------------------
# Build payload
# ---------------------------------------------------------------------------
$fieldsToUpdate = @{}
$updateOps = @{}

if ($hasSummaryUpdate)     { $fieldsToUpdate["summary"] = $SummaryText }
if ($hasDescriptionUpdate) { $fieldsToUpdate["description"] = ConvertTo-JiraAdf -Text $descriptionRaw }
if ($hasParentUpdate)      { $fieldsToUpdate["parent"] = @{ key = $ParentIssueKey } }
if ($hasLabelReplace)      { $fieldsToUpdate["labels"] = @($Labels | ForEach-Object { [string]$_ }) }
if ($hasComponentReplace)  { $fieldsToUpdate["components"] = @($Components | ForEach-Object { @{ name = [string]$_ } }) }
if ($hasLabelEdit) {
    $ops = @()
    if ($AddLabels)    { foreach ($l in $AddLabels)    { $ops += @{ add = [string]$l } } }
    if ($RemoveLabels) { foreach ($l in $RemoveLabels) { $ops += @{ remove = [string]$l } } }
    $updateOps["labels"] = $ops
}
if ($hasFieldUpdate) {
    $shaped = ConvertTo-JiraFieldsPayload -Map $extraMap
    foreach ($k in $shaped.Keys) { $fieldsToUpdate[$k] = $shaped[$k] }
}

$body = @{}
if ($fieldsToUpdate.Count -gt 0) { $body["fields"] = $fieldsToUpdate }
if ($updateOps.Count -gt 0)      { $body["update"] = $updateOps }
$payload = $body | ConvertTo-Json -Depth 30

if ($DryRun) {
    Write-Output "DRY RUN - nothing written. Payload for PUT /rest/api/3/issue/${IssueKey}:"
    Write-Output $payload
    return
}
if (-not $ConfirmUpdate) {
    throw "Updating a Jira issue is a write to the client's backlog. Re-run with -ConfirmUpdate (or -DryRun to preview)."
}

# ---------------------------------------------------------------------------
# Confirm the issue exists, write, read back
# ---------------------------------------------------------------------------
$before = Invoke-JiraApi -Path "/rest/api/3/issue/${IssueKey}?fields=summary,parent,labels" -Context "Read $IssueKey"
Invoke-JiraApi -Method Put -Path "/rest/api/3/issue/$IssueKey" -Body $payload -Context "Update $IssueKey" | Out-Null

$after = Invoke-JiraApi -Path "/rest/api/3/issue/${IssueKey}?fields=summary,parent,labels,components" -Context 'Read-back'
$af = $after.fields
$parentText = "(none)"
if ($af.PSObject.Properties['parent'] -and $af.parent) { $parentText = "$($af.parent.key) - $($af.parent.fields.summary)" }
$labelText = "(none)"
if ($af.labels -and $af.labels.Count -gt 0) { $labelText = ($af.labels -join ', ') }
$componentText = "(none)"
if ($af.components -and $af.components.Count -gt 0) { $componentText = (($af.components | ForEach-Object { $_.name }) -join ', ') }

if ($hasSummaryUpdate -and $af.summary -ne $SummaryText) { Write-Warning "Read-back summary differs from the requested value: '$($af.summary)'" }
if ($hasParentUpdate -and ($parentText -notlike "$ParentIssueKey *")) { Write-Warning "Read-back parent is '$parentText', expected '$ParentIssueKey'." }

Write-Output "Updated Jira issue successfully."
Write-Output "Issue     : $IssueKey"
Write-Output "Summary   : $($before.fields.summary) -> $($af.summary)"
Write-Output "Parent    : $parentText"
Write-Output "Labels    : $labelText"
Write-Output "Components: $componentText"
Write-Output "Fields set: $(($fieldsToUpdate.Keys | Sort-Object) -join ', ')"
Write-Output "URL       : $BaseUrl/browse/$IssueKey"
