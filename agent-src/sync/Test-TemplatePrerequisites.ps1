#Requires -Version 5.1
<#
.SYNOPSIS
  Lane validator for the tools a generated project needs, grouped by capability lane.

.DESCRIPTION
  Names which skills each missing tool breaks and the exact command that fixes it. Adopted from the
  ForgeUSA "Test-*Prerequisites.ps1" pattern (agent-model improvement C) and kept neutral.

  PRINCIPLE — no fossilised machine state (agent-model improvement B). This script is the source of
  truth for "is the machine ready", and it decides that by PROBING live, every run. It never records
  a result to a config file (no "installed: yes" line): a stale positive is worse than no record,
  because it hides a regression. The same reason the shared/ guard (check-shared.ps1) probes rather
  than trusts a flag. If you are tempted to cache an answer here, don't — re-probe instead.

  Runs under Windows PowerShell 5.1 and PowerShell 7 (deliberately 5.1-clean: it is the first thing
  a fresh machine runs, before pwsh may exist).

.PARAMETER Group
  One or more lanes to check. Default: All. Lanes: Core Dataverse AzureDevOps Node Plugins.

.PARAMETER Json
  Emit a machine-readable result object instead of the human table.

.PARAMETER Install
  Print the fix command for each missing tool. Does NOT run it — installing software is the human's
  call (and often needs elevation); this stays a recommender, never an installer.

.OUTPUTS
  Exit 0 = every checked lane satisfied; 1 = one or more tools missing; 2 = bad -Group.

.EXAMPLE
  pwsh -File agent-src/sync/Test-TemplatePrerequisites.ps1
.EXAMPLE
  pwsh -File agent-src/sync/Test-TemplatePrerequisites.ps1 -Group Dataverse,Plugins -Json
#>
[CmdletBinding()]
param(
    [ValidateSet('All', 'Core', 'Dataverse', 'AzureDevOps', 'Node', 'Plugins')]
    [string[]]$Group = @('All'),
    [switch]$Json,
    [switch]$Install
)

$ErrorActionPreference = 'Stop'

function Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}
function Test-PsModule([string]$Name) {
    return [bool](Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue)
}

# Each check: Lane, Tool, a live Probe, the Fix command, and the skills it unblocks.
$checks = @(
    @{ Lane = 'Core';        Tool = 'PowerShell 7 (pwsh)'; Probe = { Test-Command 'pwsh' };  Fix = 'winget install Microsoft.PowerShell'; Skills = 'all skills that ship pwsh scripts' }
    @{ Lane = 'Core';        Tool = 'git';                 Probe = { Test-Command 'git' };   Fix = 'winget install Git.Git';               Skills = 'worklog, close-ticket, any git-aware skill' }
    @{ Lane = 'Dataverse';   Tool = 'pac CLI';             Probe = { Test-Command 'pac' };   Fix = 'dotnet tool install --global Microsoft.PowerApps.CLI.Tool'; Skills = 'hso-pcf-control-development, hso-dataverse-* (solution export/import)' }
    @{ Lane = 'Dataverse';   Tool = 'MSAL.PS module';      Probe = { Test-PsModule 'MSAL.PS' }; Fix = 'Install-Module MSAL.PS -Scope CurrentUser'; Skills = 'aidevme-shared-scripts (Get-DataverseToken / Get-AdoToken interactive), all Dataverse skills' }
    @{ Lane = 'Dataverse';   Tool = 'Azure CLI (az)';      Probe = { Test-Command 'az' };    Fix = 'winget install Microsoft.AzureCLI'; Skills = 'aidevme-shared-scripts managed-device fallbacks (Connect-*ViaAzCli); optional' }
    @{ Lane = 'AzureDevOps'; Tool = 'Azure CLI (az)';      Probe = { Test-Command 'az' };    Fix = 'winget install Microsoft.AzureCLI'; Skills = 'hso-ado-* (WAM auth); a PAT is the alternative' }
    @{ Lane = 'Node';        Tool = 'Node.js + npm';       Probe = { Test-Command 'npm' };   Fix = 'winget install OpenJS.NodeJS.LTS'; Skills = 'hso-pcf-control-development, hso-formscript-development (TS build)' }
    @{ Lane = 'Plugins';     Tool = '.NET SDK (dotnet)';   Probe = { Test-Command 'dotnet' };Fix = 'winget install Microsoft.DotNet.SDK.8'; Skills = 'hso-plugin-development (build/test/deploy)' }
)

$wantAll = ($Group -contains 'All')
$selected = $checks | Where-Object { $wantAll -or ($Group -contains $_.Lane) }
if (-not $selected) { Write-Error "No checks for group(s): $($Group -join ', ')"; exit 2 }

$results = foreach ($c in $selected) {
    $ok = $false
    try { $ok = [bool](& $c.Probe) } catch { $ok = $false }
    [pscustomobject]@{
        Lane   = $c.Lane
        Tool   = $c.Tool
        Ok     = $ok
        Fix    = $c.Fix
        Skills = $c.Skills
    }
}

$missing = @($results | Where-Object { -not $_.Ok })

if ($Json) {
    [pscustomobject]@{
        checkedGroups = $Group
        allOk         = ($missing.Count -eq 0)
        missingCount  = $missing.Count
        results       = $results
    } | ConvertTo-Json -Depth 5
    if ($missing.Count -gt 0) { exit 1 } else { exit 0 }
}

Write-Host ""
Write-Host "=== Template prerequisites ===" -ForegroundColor Cyan
foreach ($r in $results) {
    if ($r.Ok) {
        Write-Host ("  [OK]      {0,-11} {1}" -f $r.Lane, $r.Tool) -ForegroundColor Green
    } else {
        Write-Host ("  [MISSING] {0,-11} {1}" -f $r.Lane, $r.Tool) -ForegroundColor Red
        Write-Host ("             breaks: {0}" -f $r.Skills) -ForegroundColor Yellow
        if ($Install) { Write-Host ("             fix:    {0}" -f $r.Fix) -ForegroundColor Yellow }
    }
}

Write-Host ""
if ($missing.Count -eq 0) {
    Write-Host "All checked lanes satisfied." -ForegroundColor Green
    exit 0
} else {
    Write-Host ("{0} tool(s) missing. Re-run with -Install to see fix commands." -f $missing.Count) -ForegroundColor Red
    exit 1
}
