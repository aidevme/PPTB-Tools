<#
.SYNOPSIS
    Detects which ADO process a project runs and matches it to a canonical process profile.

.DESCRIPTION
    Implements the detect-or-ask ladder's API rungs (the process-profile abstraction decision):

      1. GET {org}/_apis/work/processes?$expand=projects  -> the process the project uses
         (fallback when unreadable: project properties System.ProcessTemplateType)
      2. Stock system process (Agile / Scrum / CMMI / Basic) -> auto-select canonical profile
      3. Inherited process with the inherited-custom WIT signature
         (End to end / Process area types, Endtoend / Processarea reference names)
         -> custom-inherited (confirmRequired, treated as proposed pending confirmation)
      4. Any other inherited process -> needs-interview (emits base process + WIT vocabulary
         to seed the interview)
      5. API unreachable / auth failed / org+project unresolvable -> no-access
         (the caller falls back to asking the user; detectedVia: user)

    Emits a single JSON document (stdout or -OutputFile):
      { orgUrl, project, processName, typeId, referenceName, customizationType,
        base, matchedProfile, confirmRequired, witVocabulary, detectedVia, apiSource, notes }

    Read-only: uses only process-read and work-item-metadata-read scopes.

.PARAMETER OrgUrl
    Organization URL (e.g. https://dev.azure.com/MyOrg). Auto-detected from
    'git remote get-url origin' when omitted and the working directory is an ADO clone.

.PARAMETER Project
    Project name. Auto-detected from the git remote when omitted.

.PARAMETER Pat
    Personal Access Token override (default: settings-resolved interactive MSAL auth).

.PARAMETER ListProcesses
    Diagnostic mode: list every process in the org (name, typeId, customizationType,
    parent) instead of detecting the project's profile. Used to verify the pinned
    stock-process GUIDs against a live org.

.EXAMPLE
    .\Get-AdoProcessProfile.ps1 -OrgUrl "https://dev.azure.com/MyOrg" -Project "My Project"

.NOTES
    Requires: PowerShell 5.1+, MSAL.PS (auto-installed by the shared auth module)
    Exit codes: 0 = matched profile | 3 = needs-interview | 4 = no-access | 2 = hard error
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OrgUrl,

    [Parameter(Mandatory = $false)]
    [string]$Project,

    [Parameter(Mandatory = $false)]
    [string]$Pat,

    [switch]$ListProcesses,

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

# Universal Azure DevOps system-process GUIDs.
# Verified live against a Dataverse-backed Azure DevOps org on 2026-07-23.
$script:StockProcessIds = @{
    'adcc42ab-9882-485e-a3ed-7678f01f66bc' = 'agile'
    '6b724908-ef14-45cf-84f8-768b5384da45' = 'scrum'
    '27450541-8e31-4150-9947-dc59f998fc01' = 'cmmi'
    'b8a3a935-7e91-48b8-a94c-606d37c3e9f2' = 'basic'
}
$script:StockProcessNames = @{
    'agile' = 'agile'
    'scrum' = 'scrum'
    'cmmi'  = 'cmmi'
    'basic' = 'basic'
}

# Exit codes (documented contract -- the SKILL.md resolution procedure keys off these)
$script:ExitMatched        = 0
$script:ExitHardError      = 2
$script:ExitNeedsInterview = 3
$script:ExitNoAccess       = 4

#endregion

#region Helper Functions

function Get-Prop {
    <#
    .SYNOPSIS
    Reads a property from either a PSCustomObject or the PS 5.1 large-payload
    Dictionary fallback shape returned by Invoke-AdoRestMethod.
    #>
    param([Parameter(Mandatory)][object]$Object, [Parameter(Mandatory)][string]$Name)

    if ($Object -is [System.Collections.IDictionary]) { return $Object[$Name] }
    return $Object.$Name
}

function Resolve-AdoContextFromGit {
    <#
    .SYNOPSIS
    Parses org URL + project from 'git remote get-url origin'. Returns $null when the
    working directory is not an ADO clone. Recognises dev.azure.com, legacy
    *.visualstudio.com, and the v3 SSH shape.
    #>
    $remote = git remote get-url origin 2>$null
    if (-not $remote) { return $null }

    if ($remote -match 'dev\.azure\.com[/:](?<org>[^/]+)/(?<project>[^/]+)/_git/') {
        return @{
            OrgUrl  = "https://dev.azure.com/$($Matches['org'])"
            Project = [System.Uri]::UnescapeDataString($Matches['project'])
        }
    }
    if ($remote -match '(?<org>[^/\.@]+)\.visualstudio\.com/(?:DefaultCollection/)?(?<project>[^/]+)/_git/') {
        return @{
            OrgUrl  = "https://dev.azure.com/$($Matches['org'])"
            Project = [System.Uri]::UnescapeDataString($Matches['project'])
        }
    }
    if ($remote -match 'ssh\.dev\.azure\.com[/:]v3/(?<org>[^/]+)/(?<project>[^/]+)/') {
        return @{
            OrgUrl  = "https://dev.azure.com/$($Matches['org'])"
            Project = [System.Uri]::UnescapeDataString($Matches['project'])
        }
    }
    return $null
}

function Write-ResultAndExit {
    param(
        [Parameter(Mandatory)][hashtable]$Result,
        [Parameter(Mandatory)][int]$ExitCode
    )

    if ($Raw.IsPresent) {
        $json = $Result | ConvertTo-Json -Depth 10 -Compress
    } else {
        $json = $Result | ConvertTo-Json -Depth 10
    }
    if ($OutputFile) {
        [System.IO.File]::WriteAllText($OutputFile, $json, [System.Text.Encoding]::UTF8)
        Write-Host "[OK] Output written to: $OutputFile" -ForegroundColor Green
    } else {
        Write-Output $json
    }
    exit $ExitCode
}

#endregion

#region Main Execution

$notes = New-Object System.Collections.ArrayList

# --- Resolve org + project ------------------------------------------------------------
if (-not $OrgUrl -or -not $Project) {
    $gitContext = Resolve-AdoContextFromGit
    if ($gitContext) {
        if (-not $OrgUrl)  { $OrgUrl  = $gitContext.OrgUrl;  [void]$notes.Add("OrgUrl auto-detected from git remote.") }
        if (-not $Project) { $Project = $gitContext.Project; [void]$notes.Add("Project auto-detected from git remote.") }
    }
}
if (-not $OrgUrl -or -not $Project) {
    Write-Host "[NO-ACCESS] Org URL / project could not be resolved (no parameters, no ADO git remote)." -ForegroundColor Yellow
    Write-ResultAndExit -ExitCode $script:ExitNoAccess -Result @{
        detectedVia = $null
        matchedProfile = $null
        reason = "no-context"
        notes = @("Pass -OrgUrl and -Project explicitly, or run from an ADO repo clone. Fall back to asking the user (detectedVia: user).")
    }
}

$OrgUrl = $OrgUrl.TrimEnd('/')
if (-not $OrgUrl.StartsWith('https://')) { $OrgUrl = "https://$OrgUrl" }
$encodedProject = [System.Uri]::EscapeDataString($Project)

# --- Authenticate (read-only calls only) ----------------------------------------------
$auth = $null
try {
    $auth = Get-AdoToken -OrgUrl $OrgUrl -Pat $Pat
} catch {
    Write-Host "[NO-ACCESS] Authentication threw: $($_.Exception.Message)" -ForegroundColor Yellow
}
if (-not $auth) {
    Write-ResultAndExit -ExitCode $script:ExitNoAccess -Result @{
        orgUrl = $OrgUrl; project = $Project
        detectedVia = $null
        matchedProfile = $null
        reason = "auth-failed"
        notes = @("Could not obtain an ADO token. Fall back to asking the user (detectedVia: user).")
    }
}
if ($auth.AuthType -eq 'Bearer') { $headers = Get-AdoHeaders -Token $auth.Token } else { $headers = Get-AdoHeaders -Pat $auth.Pat }

# --- Diagnostic mode: list org processes ----------------------------------------------
if ($ListProcesses.IsPresent) {
    try {
        $resp = Invoke-AdoRestMethod -Uri "$OrgUrl/_apis/work/processes?api-version=7.1-preview.2" -Headers $headers
        $list = New-Object System.Collections.ArrayList
        foreach ($p in (Get-Prop $resp 'value')) {
            [void]$list.Add(@{
                name                = Get-Prop $p 'name'
                typeId              = Get-Prop $p 'typeId'
                referenceName       = Get-Prop $p 'referenceName'
                customizationType   = Get-Prop $p 'customizationType'
                parentProcessTypeId = Get-Prop $p 'parentProcessTypeId'
                isDefault           = Get-Prop $p 'isDefault'
            })
        }
        Write-Host "[OK] $($list.Count) process(es) in $OrgUrl" -ForegroundColor Green
        Write-ResultAndExit -ExitCode $script:ExitMatched -Result @{ orgUrl = $OrgUrl; processes = $list.ToArray() }
    } catch {
        Write-Host "[NO-ACCESS] Process list failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-ResultAndExit -ExitCode $script:ExitNoAccess -Result @{ orgUrl = $OrgUrl; reason = "process-list-failed"; notes = @("$($_.Exception.Message)") }
    }
}

# --- Rung 1: which process does the project use? --------------------------------------
$process = $null
$apiSource = $null

try {
    $resp = Invoke-AdoRestMethod -Uri "$OrgUrl/_apis/work/processes?`$expand=projects&api-version=7.1-preview.2" -Headers $headers
    foreach ($p in (Get-Prop $resp 'value')) {
        $projList = Get-Prop $p 'projects'
        if ($projList) {
            foreach ($proj in $projList) {
                if ((Get-Prop $proj 'name') -ieq $Project) { $process = $p; break }
            }
        }
        if ($process) { break }
    }
    if ($process) { $apiSource = "work/processes" }
    else { [void]$notes.Add("Project not found in any process's `$expand=projects list (permission trimming?) -- falling back to project properties.") }
} catch {
    [void]$notes.Add("work/processes unreadable ($($_.Exception.Message)) -- falling back to project properties.")
}

$typeId = $null
if ($process) {
    $typeId = Get-Prop $process 'typeId'
} else {
    # Fallback: project properties carry the process type GUID
    try {
        $projResp  = Invoke-AdoRestMethod -Uri "$OrgUrl/_apis/projects/$encodedProject`?api-version=7.1" -Headers $headers
        $projectId = Get-Prop $projResp 'id'
        $propsResp = Invoke-AdoRestMethod -Uri "$OrgUrl/_apis/projects/$projectId/properties?keys=System.ProcessTemplateType&api-version=7.1-preview.1" -Headers $headers
        foreach ($prop in (Get-Prop $propsResp 'value')) {
            if ((Get-Prop $prop 'name') -eq 'System.ProcessTemplateType') { $typeId = Get-Prop $prop 'value' }
        }
        if ($typeId) { $apiSource = "project-properties" }
    } catch {
        Write-Host "[NO-ACCESS] Both process endpoints failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-ResultAndExit -ExitCode $script:ExitNoAccess -Result @{
            orgUrl = $OrgUrl; project = $Project
            detectedVia = $null; matchedProfile = $null
            reason = "api-unreachable"
            notes = @($notes.ToArray() + "Fall back to asking the user (detectedVia: user).")
        }
    }
    if (-not $typeId) {
        Write-ResultAndExit -ExitCode $script:ExitNoAccess -Result @{
            orgUrl = $OrgUrl; project = $Project
            detectedVia = $null; matchedProfile = $null
            reason = "no-process-identity"
            notes = @($notes.ToArray() + "System.ProcessTemplateType property absent. Fall back to asking the user.")
        }
    }
}

$result = @{
    orgUrl            = $OrgUrl
    project           = $Project
    processName       = if ($process) { Get-Prop $process 'name' } else { $null }
    typeId            = $typeId
    referenceName     = if ($process) { Get-Prop $process 'referenceName' } else { $null }
    customizationType = if ($process) { Get-Prop $process 'customizationType' } else { $null }
    base              = $null
    matchedProfile    = $null
    confirmRequired   = $false
    witVocabulary     = @()
    detectedVia       = "api"
    apiSource         = $apiSource
    notes             = @()
}

# --- Rung 2: stock system process -----------------------------------------------------
$stockByGuid = $null
if ($typeId -and $script:StockProcessIds.ContainsKey("$typeId".ToLower())) {
    $stockByGuid = $script:StockProcessIds["$typeId".ToLower()]
}
$stockByName = $null
if ($result.processName -and $script:StockProcessNames.ContainsKey($result.processName.ToLower()) -and $result.customizationType -eq 'system') {
    $stockByName = $script:StockProcessNames[$result.processName.ToLower()]
}

if ($stockByName -or ($stockByGuid -and -not $process)) {
    # Name is primary when we saw the process row; GUID is primary on the properties fallback
    $matched = if ($stockByName) { $stockByName } else { $stockByGuid }
    if ($stockByName -and $stockByGuid -and ($stockByName -ne $stockByGuid)) {
        [void]$notes.Add("Stock name/GUID mismatch (name->$stockByName, guid->$stockByGuid) -- trusting the name; update the pinned GUID constants.")
    } elseif ($stockByName -and -not $stockByGuid) {
        [void]$notes.Add("System process matched by name but its GUID is not in the pinned constants -- update them.")
    }
    if (-not $result.processName) { $result.processName = $matched.Substring(0,1).ToUpper() + $matched.Substring(1) }
    $result.matchedProfile = $matched
    $result.notes = $notes.ToArray()
    Write-Host "[OK] Matched stock profile: $matched ($($result.processName))" -ForegroundColor Green
    Write-ResultAndExit -ExitCode $script:ExitMatched -Result $result
}

# --- Rung 3/4: inherited process -- WIT signature or interview -------------------------
$parentId = if ($process) { Get-Prop $process 'parentProcessTypeId' } else { $null }
if ($parentId -and $script:StockProcessIds.ContainsKey("$parentId".ToLower())) {
    $result.base = $script:StockProcessIds["$parentId".ToLower()]
}

$witNames = New-Object System.Collections.ArrayList
$newFormatSignature = $false
try {
    $witResp = Invoke-AdoRestMethod -Uri "$OrgUrl/$encodedProject/_apis/wit/workitemtypes?api-version=7.1" -Headers $headers
    foreach ($wit in (Get-Prop $witResp 'value')) {
        $wName = Get-Prop $wit 'name'
        $wRef  = Get-Prop $wit 'referenceName'
        [void]$witNames.Add($wName)
        if ($wName -in @('End to end', 'Process area') -or $wRef -match '(^|\.)(Endtoend|Processarea)$') {
            $newFormatSignature = $true
        }
    }
} catch {
    [void]$notes.Add("WIT vocabulary unreadable ($($_.Exception.Message)) -- signature check skipped.")
}
$result.witVocabulary = $witNames.ToArray()

if ($newFormatSignature) {
    $result.matchedProfile  = 'custom-inherited'
    $result.confirmRequired = $true   # treated as proposed -- confirm with the user before recording
    [void]$notes.Add("Inherited-custom WIT signature found (End to end / Process area). Confirm with the user before recording.")
    $result.notes = $notes.ToArray()
    Write-Host "[OK] Matched custom-canonical profile: custom-inherited (confirm required)" -ForegroundColor Green
    Write-ResultAndExit -ExitCode $script:ExitMatched -Result $result
}

[void]$notes.Add("Inherited process with no known signature -- run the seeded interview (base profile: $(if ($result.base) { $result.base } else { 'unknown' })).")
$result.notes = $notes.ToArray()
Write-Host "[NEEDS-INTERVIEW] $($result.processName): unknown custom process (base: $($result.base))" -ForegroundColor Yellow
Write-ResultAndExit -ExitCode $script:ExitNeedsInterview -Result $result

#endregion
