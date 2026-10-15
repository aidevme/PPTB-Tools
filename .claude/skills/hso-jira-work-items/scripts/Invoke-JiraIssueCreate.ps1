<#
.SYNOPSIS
    Creates a Jira Cloud issue (any type, any hierarchy level) using REST API v3.

.DESCRIPTION
    Creates an Epic, Story, Task, Bug, Sub-task, or any project-specific type, optionally parented
    (Story under Epic, Epic under a higher-level type, Sub-task under Story), with labels,
    components, and any custom field addressed by display NAME or id. Field values are shaped for
    the field's schema automatically (textarea -> ADF, select -> option, components -> names).

    Duplicate guard: before creating, the script searches the project for an issue with the same
    summary (and the same parent when one is given). A match aborts the run and reports the key.
    Use -AllowDuplicate to bypass deliberately.

    -DryRun prints the exact payload Jira would receive and creates nothing. Every real write
    requires -ConfirmCreate. After a write the issue is re-read and the stored values reported.

.PARAMETER BaseUrl
    Jira Cloud base URL. Resolved via hso-atlassian-auth when omitted.
.PARAMETER Email
    Jira account email for Basic auth. Resolved via hso-atlassian-auth when omitted.
.PARAMETER ApiToken
    Jira API token. Resolved via hso-atlassian-auth when omitted.
.PARAMETER ProjectKey
    Project key (e.g. PROJ). Derived from -ParentIssueKey when omitted.
.PARAMETER IssueType
    Issue type NAME as the project defines it (Story, Epic, Sub-task, ...).
.PARAMETER SummaryText
    Issue summary / title.
.PARAMETER DescriptionText
    Description, inline. Markdown-ish text is converted to ADF.
.PARAMETER DescriptionFilePath
    Path to a UTF-8 text/markdown file whose content becomes the description.
.PARAMETER ParentIssueKey
    Parent issue key. Required for Sub-task; optional for any other type (Story -> Epic, Epic -> Theme).
.PARAMETER Labels
    Labels to set.
.PARAMETER Components
    Component NAMES to set (must exist in the project).
.PARAMETER Fields
    Hashtable of additional fields: field display name or id -> value. Example:
    @{ 'Acceptance Criteria' = "Scenario 1 ..."; 'MoSCoW Priority' = 'Must' }
.PARAMETER FieldsJsonFilePath
    Path to a JSON object with the same shape as -Fields. Use for anything with special characters.
.PARAMETER AllowDuplicate
    Skip the duplicate-summary guard.
.PARAMETER DryRun
    Print the payload and stop. No write, no -ConfirmCreate needed.
.PARAMETER ConfirmCreate
    Required to perform the write.

.EXAMPLE
    .\Invoke-JiraIssueCreate.ps1 -IssueType Story -ParentIssueKey PROJ-10 `
        -SummaryText "Validate voucher number format" -DescriptionFilePath .\story.md `
        -Labels team-x -Components "My Component" `
        -Fields @{ 'Acceptance Criteria' = (Get-Content .\ac.md -Raw); 'MoSCoW Priority' = 'Must' } `
        -ConfirmCreate

.EXAMPLE
    .\Invoke-JiraIssueCreate.ps1 -IssueType Sub-task -ParentIssueKey PROJ-123 -SummaryText "PMO Checklist review" -ConfirmCreate
#>

[CmdletBinding()]
param(
    [string]$BaseUrl,
    [string]$Email,
    [string]$ApiToken,

    [ValidatePattern('^[A-Z][A-Z0-9]+$')]
    [string]$ProjectKey,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$IssueType,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SummaryText,

    [string]$DescriptionText,
    [string]$DescriptionFilePath,

    [ValidatePattern('^[A-Z][A-Z0-9]+-[0-9]+$')]
    [string]$ParentIssueKey,

    [string[]]$Labels,
    [string[]]$Components,

    [hashtable]$Fields,
    [string]$FieldsJsonFilePath,

    [switch]$AllowDuplicate,
    [switch]$DryRun,
    [switch]$ConfirmCreate
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
$isSubTask = ($IssueType -match '^sub-?task$')
if ($isSubTask -and [string]::IsNullOrWhiteSpace($ParentIssueKey)) {
    throw "IssueType '$IssueType' requires -ParentIssueKey."
}
if ([string]::IsNullOrWhiteSpace($ProjectKey)) {
    if ([string]::IsNullOrWhiteSpace($ParentIssueKey)) { throw "Provide -ProjectKey, or -ParentIssueKey so the project can be derived from it." }
    $ProjectKey = ($ParentIssueKey -split '-')[0]
}
if (-not [string]::IsNullOrWhiteSpace($DescriptionText) -and -not [string]::IsNullOrWhiteSpace($DescriptionFilePath)) {
    throw "Provide either -DescriptionText or -DescriptionFilePath, not both."
}
$descriptionRaw = Read-JiraTextInput -Text $DescriptionText -FilePath $DescriptionFilePath

# ---------------------------------------------------------------------------
# Build the fields payload
# ---------------------------------------------------------------------------
$issueFields = @{
    project   = @{ key = $ProjectKey }
    issuetype = @{ name = $IssueType }
    summary   = $SummaryText
}
if (-not [string]::IsNullOrWhiteSpace($descriptionRaw)) { $issueFields["description"] = ConvertTo-JiraAdf -Text $descriptionRaw }
if (-not [string]::IsNullOrWhiteSpace($ParentIssueKey)) { $issueFields["parent"] = @{ key = $ParentIssueKey } }
if ($Labels -and $Labels.Count -gt 0) { $issueFields["labels"] = @($Labels | ForEach-Object { [string]$_ }) }
if ($Components -and $Components.Count -gt 0) { $issueFields["components"] = @($Components | ForEach-Object { @{ name = [string]$_ } }) }

$extraMap = @{}
if (-not [string]::IsNullOrWhiteSpace($FieldsJsonFilePath)) {
    $json = Read-JiraJsonFile -FilePath $FieldsJsonFilePath
    foreach ($p in $json.PSObject.Properties) { $extraMap[$p.Name] = $p.Value }
}
if ($Fields) { foreach ($k in $Fields.Keys) { $extraMap[[string]$k] = $Fields[$k] } }
if ($extraMap.Count -gt 0) {
    $shaped = ConvertTo-JiraFieldsPayload -Map $extraMap
    foreach ($k in $shaped.Keys) { $issueFields[$k] = $shaped[$k] }
}

$payload = @{ fields = $issueFields } | ConvertTo-Json -Depth 30

if ($DryRun) {
    Write-Output "DRY RUN - nothing created. Payload for POST /rest/api/3/issue:"
    Write-Output $payload
    return
}

if (-not $ConfirmCreate) {
    throw "Creating a Jira issue is a write to the client's backlog. Re-run with -ConfirmCreate (or -DryRun to preview)."
}

# ---------------------------------------------------------------------------
# Duplicate guard
# ---------------------------------------------------------------------------
if (-not $AllowDuplicate) {
    $escapedSummary = $SummaryText -replace '"', '\"'
    $jql = 'project = "{0}" AND summary ~ "\"{1}\""' -f $ProjectKey, $escapedSummary
    if (-not [string]::IsNullOrWhiteSpace($ParentIssueKey)) { $jql += (' AND parent = {0}' -f $ParentIssueKey) }
    try {
        $search = Search-JiraIssues -Jql $jql -Fields @('summary', 'issuetype', 'parent') -MaxResults 20
        $exactMatch = $search.Issues | Where-Object { $_.fields.summary -ieq $SummaryText } | Select-Object -First 1
        if ($exactMatch) {
            throw ("Duplicate detected: an issue with this exact summary already exists.`n" +
                   "  Existing issue : $($exactMatch.key) - $($exactMatch.fields.summary)`n" +
                   "  URL            : $BaseUrl/browse/$($exactMatch.key)`n" +
                   "Re-run with -AllowDuplicate to create anyway.")
        }
    }
    catch {
        if ($_.Exception.Message -like 'Duplicate detected*') { throw }
        Write-Warning "Duplicate check failed (proceeding with creation): $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# Create + read-back verification
# ---------------------------------------------------------------------------
$response = Invoke-JiraApi -Method Post -Path '/rest/api/3/issue' -Body $payload -Context 'Create issue'
$newIssueKey = $response.key

$verifyFields = 'summary,issuetype,parent,labels,components'
$verified = Invoke-JiraApi -Path "/rest/api/3/issue/${newIssueKey}?fields=$verifyFields" -Context 'Read-back'
$vf = $verified.fields
$parentText = "(none)"
if ($vf.PSObject.Properties['parent'] -and $vf.parent) { $parentText = "$($vf.parent.key) - $($vf.parent.fields.summary)" }
$labelText = "(none)"
if ($vf.labels -and $vf.labels.Count -gt 0) { $labelText = ($vf.labels -join ', ') }
$componentText = "(none)"
if ($vf.components -and $vf.components.Count -gt 0) { $componentText = (($vf.components | ForEach-Object { $_.name }) -join ', ') }

if ($vf.summary -ne $SummaryText) { Write-Warning "Read-back summary differs from the requested value: '$($vf.summary)'" }
if (-not [string]::IsNullOrWhiteSpace($ParentIssueKey) -and ($parentText -notlike "$ParentIssueKey *")) {
    Write-Warning "Read-back parent is '$parentText', expected '$ParentIssueKey'."
}

Write-Output "Jira issue created successfully."
Write-Output "Issue     : $newIssueKey - $($vf.summary)"
Write-Output "Type      : $($vf.issuetype.name)"
Write-Output "Parent    : $parentText"
Write-Output "Labels    : $labelText"
Write-Output "Components: $componentText"
Write-Output "URL       : $BaseUrl/browse/$newIssueKey"
