<#
.SYNOPSIS  One-command HSO system-review pipeline (technical tier): harvest -> findings -> [population] -> risks -> Excel pack.
.DESCRIPTION
  Chains the system-review scripts so a review runs end-to-end from one call. Default scope = the primary app
  (-AppName) with the risk passes. Auth must already be cached (run hso-dataverse-auth-azcli first). Reads the
  harvest JSON once; every downstream step derives offline (cost-effective). The client Word doc (Tier 2) is a
  separate, content-authored step via hso-engagement-deliverables.
.EXAMPLE
  pwsh -File Invoke-SystemReview.ps1 -EnvironmentUrl https://org.crm.dynamics.com -AppName "MyApp" `
       -ClientPrefix contoso -IsvPrefixes isv1,isv2 -OutDir C:\review -CodeRepo C:\src\ClientRepo -Interactive
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EnvironmentUrl,
    [string]$AppName,                                   # omit to scope by in-scope solutions instead of an app
    [string[]]$InScopeSolutions,
    [Parameter(Mandatory)][string]$ClientPrefix,
    [string[]]$IsvPrefixes = @(),
    [Parameter(Mandatory)][string]$OutDir,
    [string]$CodeRepo,                                  # optional: client source repo for JS/plugin risk scan
    [hashtable]$PopulationMap,                          # optional: @{ table='Form Name'; ... } for % populated
    [switch]$Interactive
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$meta = Join-Path $OutDir 'metadata'
$find = Join-Path $OutDir 'findings'
$risks = Join-Path $OutDir 'risks.json'
$xlsx = Join-Path $OutDir 'Technical_Pack.xlsx'
function Step($n,$msg){ Write-Host "`n===== [$n] $msg =====" -ForegroundColor Cyan }

# 1. Harvest ------------------------------------------------------------------
Step 1 "Harvest metadata"
$ha = @('-NoProfile','-File',(Join-Path $here 'Harvest-DataverseMetadata.ps1'),
        '-EnvironmentUrl',$EnvironmentUrl,'-ClientPrefix',$ClientPrefix,
        '-IsvPrefixes',($IsvPrefixes -join ','),'-OutDir',$meta)
if($AppName){ $ha += @('-AppName',$AppName) }
if($InScopeSolutions){ $ha += @('-InScopeSolutions',($InScopeSolutions -join ',')) }
if($Interactive){ $ha += '-Interactive' }
& pwsh @ha
if($LASTEXITCODE -ne 0){ throw "Harvest failed ($LASTEXITCODE)" }

# 2. Findings -----------------------------------------------------------------
Step 2 "Derive findings"
$codeTokens = Join-Path $meta 'code_tokens.txt'
$fa = @('-NoProfile','-File',(Join-Path $here 'Analyze-SystemFindings.ps1'),
        '-MetaDir',$meta,'-OutDir',$find,'-ClientPrefix',$ClientPrefix,'-IsvPrefixes',($IsvPrefixes -join ','))
if(Test-Path $codeTokens){ $fa += @('-CodeTokensPath',$codeTokens) }
& pwsh @fa
if($LASTEXITCODE -ne 0){ Write-Warning "Findings step returned $LASTEXITCODE" }

# 3. Form field population (optional) -----------------------------------------
if($PopulationMap){
    Step 3 "Form field population"
    $mapLit = '@{ ' + (($PopulationMap.GetEnumerator() | ForEach-Object { "'$($_.Key)'='$($_.Value)'" }) -join '; ') + ' }'
    $cmd = "& '$(Join-Path $here 'Analyze-FormFieldPopulation.ps1')' -EnvironmentUrl '$EnvironmentUrl' -OutDir '$find' -Map $mapLit" + $(if($Interactive){' -Interactive'}else{''})
    & pwsh -NoProfile -Command $cmd
}

# 4. Risk register ------------------------------------------------------------
Step 4 "Risk register"
$ra = @((Join-Path $here 'Analyze-SystemRisks.py'),$meta,$risks,'--client-prefix',$ClientPrefix)
if($CodeRepo){ $ra += @('--code',$CodeRepo) }
& python @ra
if($LASTEXITCODE -ne 0){ Write-Warning "Risk step returned $LASTEXITCODE" }

# 5. Technical pack (Excel) ---------------------------------------------------
Step 5 "Technical pack (Excel)"
& python (Join-Path $here 'Build-TechnicalPack.py') $meta $xlsx $risks
if($LASTEXITCODE -ne 0){ throw "Technical pack failed ($LASTEXITCODE)" }

Write-Host "`nSYSTEM_REVIEW_DONE" -ForegroundColor Green
Write-Host "  metadata : $meta"
Write-Host "  findings : $find"
Write-Host "  risks    : $risks"
Write-Host "  pack     : $xlsx"
Write-Host "  Next (Tier 2): author the client Word doc via hso-engagement-deliverables (Build-WordDeliverable.py)."
