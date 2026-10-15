<#
.SYNOPSIS
    Creates and updates many Jira Cloud issues from one JSON manifest - epics, stories, sub-tasks -
    with parent references between items, per-item isolation, and a crash-safe result file.

.DESCRIPTION
    The manifest is a JSON object:

      {
        "projectKey": "PROJ",
        "defaults": { "labels": ["team-x"], "components": ["My Component"], "fields": { } },
        "items": [
          { "ref": "epic-a", "op": "create", "issueType": "Epic", "parent": "PROJ-1",
            "summary": "Contract creation", "descriptionFile": "epics/epic-a.md" },
          { "ref": "s1", "op": "create", "issueType": "Story", "parent": "@epic-a",
            "summary": "Generate the contract number", "descriptionFile": "stories/s1.md",
            "fields": { "Acceptance Criteria": { "file": "stories/s1.ac.md" }, "MoSCoW Priority": "Must" },
            "subtasks": [ { "issueType": "Sub-task", "summary": "PMO Checklist review" } ] },
          { "ref": "s2", "op": "update", "key": "PROJ-123", "parent": "@epic-a",
            "summary": "Rewritten summary", "fields": { "Acceptance Criteria": "..." }, "addLabels": ["team-x"] }
        ]
      }

    Item keys: ref (unique, required), op (create | update), key (update only), issueType, parent
    (an issue key, or "@ref" of an EARLIER item in the same manifest or of a prior run), summary,
    description | descriptionFile, labels | addLabels | removeLabels, components, fields
    (display name or id -> value; a value may be { "file": "path" } to load text from a file),
    subtasks (created under the item after it exists). File paths are relative to the manifest.
    defaults.labels / components / fields are merged into every CREATE item (item values win).

    Safety model:
      - -DryRun resolves every field name and parent reference, prints the plan, writes nothing.
      - -ConfirmWrite is required for any write.
      - Per-item isolation: one failing item never aborts the batch (unless -StopOnError).
      - Duplicate guard on create: an issue with the same summary under the same parent is ADOPTED
        (its key recorded, nothing created) rather than duplicated. -AllowDuplicate creates anyway.
      - Result file (default: <manifest>.result.json) is rewritten after every item, so a re-run
        skips items already created and resolves "@ref" parents from the previous run.
      - Item statuses: created | adopted | updated | skipped | dryrun | error.

.PARAMETER ManifestPath
    Path to the manifest JSON.
.PARAMETER ResultFilePath
    Where to write the ref -> key results. Default: the manifest path with ".result.json".
.PARAMETER DryRun
    Validate and print the plan without writing.
.PARAMETER ConfirmWrite
    Required to perform writes.
.PARAMETER StopOnError
    Abort the batch at the first failing item (default: continue and report).
.PARAMETER AllowDuplicate
    Create even when an issue with the same summary exists under the same parent.

.EXAMPLE
    .\Invoke-JiraIssueBulk.ps1 -ManifestPath .\backlog\contracts-core.json -DryRun
    .\Invoke-JiraIssueBulk.ps1 -ManifestPath .\backlog\contracts-core.json -ConfirmWrite
#>

[CmdletBinding()]
param(
    [string]$BaseUrl,
    [string]$Email,
    [string]$ApiToken,

    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [string]$ResultFilePath,

    [switch]$DryRun,
    [switch]$ConfirmWrite,
    [switch]$StopOnError,
    [switch]$AllowDuplicate
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
# Load manifest and prior results
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $ManifestPath)) { throw "Manifest not found: $ManifestPath" }
$ManifestPath = (Resolve-Path -LiteralPath $ManifestPath).Path
$manifestDir  = Split-Path -Parent $ManifestPath
$manifest     = Read-JiraJsonFile -FilePath $ManifestPath

if ([string]::IsNullOrWhiteSpace($ResultFilePath)) {
    $ResultFilePath = [System.IO.Path]::ChangeExtension($ManifestPath, ".result.json")
}

if (-not $DryRun -and -not $ConfirmWrite) {
    throw "Bulk create/update is a write to the client's backlog. Re-run with -ConfirmWrite (or -DryRun to preview)."
}

function Get-Prop {
    param([object]$Obj, [string]$Name, [object]$Default = $null)
    if ($null -eq $Obj) { return $Default }
    if ($Obj -is [System.Collections.IDictionary]) { if ($Obj.Contains($Name)) { return $Obj[$Name] } ; return $Default }
    if ($Obj.PSObject.Properties[$Name]) { return $Obj.$Name }
    return $Default
}

$projectKey = [string](Get-Prop $manifest 'projectKey' '')
$defaults   = Get-Prop $manifest 'defaults' $null
$items      = @(Get-Prop $manifest 'items' @())
if ($items.Count -eq 0) { throw "Manifest has no items." }

$defaultLabels     = @(Get-Prop $defaults 'labels' @())
$defaultComponents = @(Get-Prop $defaults 'components' @())
$defaultFields     = Get-Prop $defaults 'fields' $null

# ref -> key map: from a previous run first, then filled as this run progresses
$refToKey = @{}
$priorResults = @()
if (Test-Path -LiteralPath $ResultFilePath) {
    try {
        $priorResults = @(Read-JiraJsonFile -FilePath $ResultFilePath)
        foreach ($r in $priorResults) {
            $rk = [string](Get-Prop $r 'key' '')
            $rr = [string](Get-Prop $r 'ref' '')
            $rs = [string](Get-Prop $r 'status' '')
            if ($rr -and $rk -and ($rs -in @('created', 'adopted', 'updated'))) { $refToKey[$rr] = $rk }
        }
        if ($refToKey.Count -gt 0) { Write-Host "Loaded $($refToKey.Count) ref -> key mapping(s) from $ResultFilePath" -ForegroundColor Cyan }
    }
    catch { Write-Warning "Could not read prior results ($ResultFilePath): $($_.Exception.Message)" }
}

# ---------------------------------------------------------------------------
# Validation pass (runs for DryRun and for real): refs, ops, parents, field names
# ---------------------------------------------------------------------------
$seenRefs = @{}
$plan = @()
foreach ($item in $items) {
    $ref = [string](Get-Prop $item 'ref' '')
    $op  = ([string](Get-Prop $item 'op' 'create')).ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($ref)) { throw "Every item needs a unique 'ref'. Offending item: $($item | ConvertTo-Json -Compress -Depth 3)" }
    if ($seenRefs.ContainsKey($ref)) { throw "Duplicate ref '$ref' in manifest." }
    $seenRefs[$ref] = $true
    if ($op -notin @('create', 'update')) { throw "Item '$ref': op must be 'create' or 'update' (got '$op')." }

    $key = [string](Get-Prop $item 'key' '')
    if ($op -eq 'update' -and [string]::IsNullOrWhiteSpace($key)) { throw "Item '$ref': op 'update' needs 'key'." }
    if ($op -eq 'create' -and [string]::IsNullOrWhiteSpace([string](Get-Prop $item 'issueType' ''))) { throw "Item '$ref': op 'create' needs 'issueType'." }
    if ($op -eq 'create' -and [string]::IsNullOrWhiteSpace([string](Get-Prop $item 'summary' ''))) { throw "Item '$ref': op 'create' needs 'summary'." }

    $parentRaw = [string](Get-Prop $item 'parent' '')
    if ($parentRaw.StartsWith('@')) {
        $pref = $parentRaw.Substring(1)
        if (-not $seenRefs.ContainsKey($pref) -and -not $refToKey.ContainsKey($pref)) {
            throw "Item '$ref': parent '$parentRaw' refers to a ref that is neither earlier in this manifest nor in the prior result file."
        }
    }

    # Resolve field names now so a typo fails before any write.
    $fieldMap = Get-Prop $item 'fields' $null
    if ($fieldMap) {
        $pairs = @()
        if ($fieldMap -is [System.Collections.IDictionary]) { $pairs = @($fieldMap.Keys) } else { $pairs = @($fieldMap.PSObject.Properties | ForEach-Object { $_.Name }) }
        foreach ($name in $pairs) { [void](Resolve-JiraField -NameOrId ([string]$name)) }
    }
    if ($defaultFields) {
        $dpairs = @()
        if ($defaultFields -is [System.Collections.IDictionary]) { $dpairs = @($defaultFields.Keys) } else { $dpairs = @($defaultFields.PSObject.Properties | ForEach-Object { $_.Name }) }
        foreach ($name in $dpairs) { [void](Resolve-JiraField -NameOrId ([string]$name)) }
    }
    $plan += [pscustomobject]@{ Ref = $ref; Op = $op; Key = $key; Parent = $parentRaw; Summary = [string](Get-Prop $item 'summary' '') }
}

Write-Host ("Manifest OK: {0} item(s), project {1}" -f $items.Count, $projectKey) -ForegroundColor Green

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Resolve-ManifestText {
    # A value may be a string, or { "file": "relative/path" }.
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [string]) { return $Value }
    $file = [string](Get-Prop $Value 'file' '')
    if ($file) {
        $full = $file
        if (-not [System.IO.Path]::IsPathRooted($full)) { $full = Join-Path $manifestDir $file }
        return (Read-JiraTextInput -FilePath $full)
    }
    return $Value
}

function Resolve-ParentKey {
    param([string]$Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { return '' }
    if ($Raw.StartsWith('@')) {
        $pref = $Raw.Substring(1)
        if ($refToKey.ContainsKey($pref)) { return [string]$refToKey[$pref] }
        throw "Parent '$Raw' is not resolved yet (the referenced item did not produce a key)."
    }
    return $Raw
}

function Merge-FieldMaps {
    param([AllowNull()][object]$Base, [AllowNull()][object]$Override)
    $out = [ordered]@{}
    foreach ($src in @($Base, $Override)) {
        if ($null -eq $src) { continue }
        if ($src -is [System.Collections.IDictionary]) { foreach ($k in $src.Keys) { $out[[string]$k] = Resolve-ManifestText -Value $src[$k] } }
        else { foreach ($p in $src.PSObject.Properties) { $out[$p.Name] = Resolve-ManifestText -Value $p.Value } }
    }
    return $out
}

function Find-ExistingIssue {
    param([string]$Project, [string]$Summary, [string]$ParentKey)
    $escaped = $Summary -replace '"', '\"'
    $jql = 'project = "{0}" AND summary ~ "\"{1}\""' -f $Project, $escaped
    if ($ParentKey) { $jql += (' AND parent = {0}' -f $ParentKey) }
    try {
        $search = Search-JiraIssues -Jql $jql -Fields @('summary', 'parent') -MaxResults 20
        return ($search.Issues | Where-Object { $_.fields.summary -ieq $Summary } | Select-Object -First 1)
    }
    catch {
        Write-Warning "Duplicate check failed for '$Summary': $($_.Exception.Message)"
        return $null
    }
}

function New-CreateFields {
    param([object]$Item, [string]$ParentKey, [string]$Project, [switch]$IsSubtask)
    $f = @{
        project   = @{ key = $Project }
        issuetype = @{ name = [string](Get-Prop $Item 'issueType' 'Story') }
        summary   = [string](Get-Prop $Item 'summary' '')
    }
    $desc = Resolve-ManifestText -Value (Get-Prop $Item 'description' $null)
    $descFile = [string](Get-Prop $Item 'descriptionFile' '')
    if ($descFile) { $desc = Resolve-ManifestText -Value @{ file = $descFile } }
    if (-not [string]::IsNullOrWhiteSpace([string]$desc)) { $f['description'] = ConvertTo-JiraAdf -Text ([string]$desc) }
    if ($ParentKey) { $f['parent'] = @{ key = $ParentKey } }

    $labels = @($defaultLabels) + @(Get-Prop $Item 'labels' @())
    $labels = @($labels | ForEach-Object { [string]$_ } | Where-Object { $_ } | Select-Object -Unique)
    if ($labels.Count -gt 0) { $f['labels'] = $labels }

    $comps = @($defaultComponents) + @(Get-Prop $Item 'components' @())
    $comps = @($comps | ForEach-Object { [string]$_ } | Where-Object { $_ } | Select-Object -Unique)
    if ($comps.Count -gt 0) { $f['components'] = @($comps | ForEach-Object { @{ name = $_ } }) }

    $merged = Merge-FieldMaps -Base $defaultFields -Override (Get-Prop $Item 'fields' $null)
    if ($IsSubtask) { $merged = Merge-FieldMaps -Base $null -Override (Get-Prop $Item 'fields' $null) }
    if ($merged.Count -gt 0) {
        $shaped = ConvertTo-JiraFieldsPayload -Map $merged
        foreach ($k in $shaped.Keys) { $f[$k] = $shaped[$k] }
    }
    return $f
}

function New-UpdateBody {
    param([object]$Item, [string]$ParentKey)
    $fields = @{}
    $update = @{}
    $summary = [string](Get-Prop $Item 'summary' '')
    if ($summary) { $fields['summary'] = $summary }
    $desc = Resolve-ManifestText -Value (Get-Prop $Item 'description' $null)
    $descFile = [string](Get-Prop $Item 'descriptionFile' '')
    if ($descFile) { $desc = Resolve-ManifestText -Value @{ file = $descFile } }
    if (-not [string]::IsNullOrWhiteSpace([string]$desc)) { $fields['description'] = ConvertTo-JiraAdf -Text ([string]$desc) }
    if ($ParentKey) { $fields['parent'] = @{ key = $ParentKey } }
    $labels = Get-Prop $Item 'labels' $null
    if ($null -ne $labels) { $fields['labels'] = @($labels | ForEach-Object { [string]$_ }) }
    $comps = Get-Prop $Item 'components' $null
    if ($null -ne $comps) { $fields['components'] = @($comps | ForEach-Object { @{ name = [string]$_ } }) }
    $ops = @()
    foreach ($l in @(Get-Prop $Item 'addLabels' @()))    { $ops += @{ add = [string]$l } }
    foreach ($l in @(Get-Prop $Item 'removeLabels' @())) { $ops += @{ remove = [string]$l } }
    if ($ops.Count -gt 0) { $update['labels'] = $ops }
    $merged = Merge-FieldMaps -Base $null -Override (Get-Prop $Item 'fields' $null)
    if ($merged.Count -gt 0) {
        $shaped = ConvertTo-JiraFieldsPayload -Map $merged
        foreach ($k in $shaped.Keys) { $fields[$k] = $shaped[$k] }
    }
    $body = @{}
    if ($fields.Count -gt 0) { $body['fields'] = $fields }
    if ($update.Count -gt 0) { $body['update'] = $update }
    return $body
}

$results = @()
foreach ($pr in $priorResults) {
    $results += [pscustomobject]@{
        ref = [string](Get-Prop $pr 'ref' ''); op = [string](Get-Prop $pr 'op' ''); key = [string](Get-Prop $pr 'key' '')
        status = [string](Get-Prop $pr 'status' ''); message = [string](Get-Prop $pr 'message' ''); at = [string](Get-Prop $pr 'at' '')
    }
}

function Save-Results {
    if ($DryRun) { return }
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ResultFilePath -Encoding UTF8
}

function Add-Result {
    param([string]$Ref, [string]$Op, [string]$Key, [string]$Status, [string]$Message)
    $script:results = @($script:results | Where-Object { $_.ref -ne $Ref })
    $script:results += [pscustomobject]@{ ref = $Ref; op = $Op; key = $Key; status = $Status; message = $Message; at = (Get-Date).ToString('s') }
    if ($Key -and ($Status -in @('created', 'adopted', 'updated'))) { $refToKey[$Ref] = $Key }
    Save-Results
    $color = 'Green'
    if ($Status -eq 'error') { $color = 'Red' } elseif ($Status -in @('skipped', 'dryrun', 'adopted')) { $color = 'Yellow' }
    Write-Host ("[{0,-8}] {1,-24} {2,-10} {3}" -f $Status, $Ref, $Key, $Message) -ForegroundColor $color
}

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------
$errorCount = 0
foreach ($item in $items) {
    $ref = [string](Get-Prop $item 'ref' '')
    $op  = ([string](Get-Prop $item 'op' 'create')).ToLowerInvariant()
    try {
        $parentKey = Resolve-ParentKey -Raw ([string](Get-Prop $item 'parent' ''))
        $itemProject = $projectKey
        if ([string]::IsNullOrWhiteSpace($itemProject) -and $parentKey) { $itemProject = ($parentKey -split '-')[0] }
        if ([string]::IsNullOrWhiteSpace($itemProject) -and $op -eq 'create') { throw "No projectKey in the manifest and no parent to derive it from." }

        if ($op -eq 'create') {
            if ($refToKey.ContainsKey($ref) -and -not $DryRun) {
                Add-Result -Ref $ref -Op $op -Key $refToKey[$ref] -Status 'skipped' -Message 'Already created in a prior run'
            }
            else {
                $summary = [string](Get-Prop $item 'summary' '')
                $fields = New-CreateFields -Item $item -ParentKey $parentKey -Project $itemProject
                if ($DryRun) {
                    Add-Result -Ref $ref -Op $op -Key '' -Status 'dryrun' -Message ("{0} '{1}' under {2}; fields: {3}" -f $fields.issuetype.name, $summary, $(if ($parentKey) { $parentKey } else { '(none)' }), (($fields.Keys | Sort-Object) -join ','))
                    $refToKey[$ref] = "@$ref"
                }
                else {
                    $existing = $null
                    if (-not $AllowDuplicate) { $existing = Find-ExistingIssue -Project $itemProject -Summary $summary -ParentKey $parentKey }
                    if ($existing) {
                        Add-Result -Ref $ref -Op $op -Key $existing.key -Status 'adopted' -Message "Existing issue with the same summary and parent; not created"
                    }
                    else {
                        $resp = Invoke-JiraApi -Method Post -Path '/rest/api/3/issue' -Body @{ fields = $fields } -Context "Create '$ref'"
                        Add-Result -Ref $ref -Op $op -Key $resp.key -Status 'created' -Message $summary
                    }
                }
            }
        }
        else {
            $key = [string](Get-Prop $item 'key' '')
            $body = New-UpdateBody -Item $item -ParentKey $parentKey
            if ($body.Count -eq 0) {
                Add-Result -Ref $ref -Op $op -Key $key -Status 'skipped' -Message 'Nothing to update'
            }
            elseif ($DryRun) {
                $names = @()
                if ($body.ContainsKey('fields')) { $names += @($body.fields.Keys) }
                if ($body.ContainsKey('update')) { $names += @($body.update.Keys | ForEach-Object { "$_ (add/remove)" }) }
                Add-Result -Ref $ref -Op $op -Key $key -Status 'dryrun' -Message ("fields: {0}" -f (($names | Sort-Object) -join ','))
                $refToKey[$ref] = $key
            }
            else {
                Invoke-JiraApi -Method Put -Path "/rest/api/3/issue/$key" -Body $body -Context "Update $key ('$ref')" | Out-Null
                Add-Result -Ref $ref -Op $op -Key $key -Status 'updated' -Message ((($body.fields.Keys | Sort-Object) -join ','))
            }
        }

        # Sub-tasks under this item
        $subs = @(Get-Prop $item 'subtasks' @())
        if ($subs.Count -gt 0) {
            $parentForSubs = $refToKey[$ref]
            $n = 0
            foreach ($sub in $subs) {
                $n++
                $subRef = [string](Get-Prop $sub 'ref' '')
                if (-not $subRef) { $subRef = "$ref/sub$n" }
                $subSummary = [string](Get-Prop $sub 'summary' '')
                if (-not $subSummary) { throw "Sub-task $n of '$ref' has no summary." }
                if (-not (Get-Prop $sub 'issueType' $null)) { $sub | Add-Member -NotePropertyName issueType -NotePropertyValue 'Sub-task' -Force }
                try {
                    if ($refToKey.ContainsKey($subRef) -and -not $DryRun) {
                        Add-Result -Ref $subRef -Op 'create' -Key $refToKey[$subRef] -Status 'skipped' -Message 'Already created in a prior run'
                        continue
                    }
                    if ($DryRun) {
                        Add-Result -Ref $subRef -Op 'create' -Key '' -Status 'dryrun' -Message ("Sub-task '{0}' under {1}" -f $subSummary, $parentForSubs)
                        continue
                    }
                    $subProject = ($parentForSubs -split '-')[0]
                    $existing = $null
                    if (-not $AllowDuplicate) { $existing = Find-ExistingIssue -Project $subProject -Summary $subSummary -ParentKey $parentForSubs }
                    if ($existing) {
                        Add-Result -Ref $subRef -Op 'create' -Key $existing.key -Status 'adopted' -Message 'Existing sub-task with the same summary; not created'
                        continue
                    }
                    $sf = New-CreateFields -Item $sub -ParentKey $parentForSubs -Project $subProject -IsSubtask
                    $resp = Invoke-JiraApi -Method Post -Path '/rest/api/3/issue' -Body @{ fields = $sf } -Context "Create sub-task '$subRef'"
                    Add-Result -Ref $subRef -Op 'create' -Key $resp.key -Status 'created' -Message $subSummary
                }
                catch {
                    $errorCount++
                    Add-Result -Ref $subRef -Op 'create' -Key '' -Status 'error' -Message $_.Exception.Message
                    if ($StopOnError) { throw }
                }
            }
        }
    }
    catch {
        $errorCount++
        Add-Result -Ref $ref -Op $op -Key '' -Status 'error' -Message $_.Exception.Message
        if ($StopOnError) { break }
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Output ""
Write-Output "| Ref | Op | Key | Status | Message |"
Write-Output "|-----|----|-----|--------|---------|"
foreach ($r in $results) {
    $msg = [string]$r.message
    if ($msg.Length -gt 70) { $msg = $msg.Substring(0, 67) + '...' }
    Write-Output ("| {0} | {1} | {2} | {3} | {4} |" -f $r.ref, $r.op, $r.key, $r.status, ($msg -replace '\|', '/'))
}
if (-not $DryRun) { Write-Output ""; Write-Output "Results written to: $ResultFilePath" }
if ($errorCount -gt 0) { throw "$errorCount item(s) failed. See the table above and the result file." }
