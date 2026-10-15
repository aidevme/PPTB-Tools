<#
.SYNOPSIS
    Regression tests for Get-ChoiceContractBreach -- the global-choice read-back predicate.

.DESCRIPTION
    Pure-logic tests. No Dataverse environment, no auth, no network: the helper is lifted out of
    Invoke-DataverseMetadataOperation.ps1 via the AST, because dot-sourcing that script would run
    its dispatch block and try to authenticate.

    These guard two defects that shipped before:

      1. The retry predicate tested PRESENCE only while the FATAL block tested presence AND label.
         A label rename (UpdateOptionValue) whose read came back stale returned the value present
         carrying its OLD label, so the loop broke on attempt 1 without spending any retry budget
         and the script exited 1 on a rename that had actually succeeded. Case 2 is that scenario.

      2. `return ,$breaches` nested the result, so the caller's @(...) saw ONE element regardless
         of the real count -- collapsing 2 breaches to 1 and turning 0 breaches into 1. Case 5
         pins the call-site contract.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Test-GlobalChoiceContract.ps1

.NOTES
    Run under BOTH Windows PowerShell 5.1 and PowerShell 7 (ADR 0058). Exits 1 on any failure.
#>

$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'Invoke-DataverseMetadataOperation.ps1'
if (-not (Test-Path $src)) { throw "Cannot find $src" }

$ast = [System.Management.Automation.Language.Parser]::ParseFile($src, [ref]$null, [ref]$null)
$fn  = $ast.Find({
    param($n)
    $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-ChoiceContractBreach'
}, $true)
if (-not $fn) { throw 'Get-ChoiceContractBreach not found in the script -- was it renamed?' }
Invoke-Expression $fn.Extent.Text

$script:pass = 0
$script:fail = 0
function Check {
    param([string]$Name, [bool]$Condition, [string]$Detail)
    if ($Condition) { $script:pass++; Write-Host "  PASS  $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  FAIL  $Name -- $Detail" -ForegroundColor Red }
}

# The declared contract used by every case below.
$declared = @(
    [pscustomobject]@{ Label = 'Fixed';   Value = 1; Color = '#ff0000' }
    [pscustomobject]@{ Label = 'Percent'; Value = 2; Color = $null }
)

Write-Host "Case 1 - fully settled read (happy path)"
$actual = @{ 1 = [pscustomobject]@{ Label = 'Fixed'; Color = '#ff0000' }
             2 = [pscustomobject]@{ Label = 'Percent'; Color = $null } }
$b = @(Get-ChoiceContractBreach -Declared $declared -Actual $actual)
Check 'no breaches' ($b.Count -eq 0) "got $($b.Count): $($b -join '; ')"

Write-Host "`nCase 2 - REGRESSION: value present, label still stale (UpdateOptionValue rename)"
$actual = @{ 1 = [pscustomobject]@{ Label = 'Fixed'; Color = '#ff0000' }
             2 = [pscustomobject]@{ Label = 'Percent Of Cost'; Color = $null } }   # OLD label
$b = @(Get-ChoiceContractBreach -Declared $declared -Actual $actual)
Check 'stale label IS a breach, so the retry fires' ($b.Count -eq 1) "got $($b.Count)"
Check 'breach names the label mismatch' ($b[0] -like "*label 'Percent Of Cost' != declared 'Percent'*") "got: $($b[0])"

Write-Host "`nCase 3 - value genuinely absent (the original symptom)"
$actual = @{ 1 = [pscustomobject]@{ Label = 'Fixed'; Color = '#ff0000' } }
$b = @(Get-ChoiceContractBreach -Declared $declared -Actual $actual)
Check 'missing value IS a breach' ($b.Count -eq 1) "got $($b.Count)"
Check 'breach names the missing value' ($b[0] -like "*value 2 ('Percent') not present*") "got: $($b[0])"

Write-Host "`nCase 4 - colour drift ONLY must not gate the retry"
$actual = @{ 1 = [pscustomobject]@{ Label = 'Fixed'; Color = '#00ff00' }           # wrong colour
             2 = [pscustomobject]@{ Label = 'Percent'; Color = $null } }
$b = @(Get-ChoiceContractBreach -Declared $declared -Actual $actual)
Check 'colour drift is not a breach' ($b.Count -eq 0) "got $($b.Count): $($b -join '; ')"

Write-Host "`nCase 5 - call-site contract: @(...) makes an empty result addressable"
$actual = @{ 1 = [pscustomobject]@{ Label = 'Fixed'; Color = '#ff0000' }
             2 = [pscustomobject]@{ Label = 'Percent'; Color = $null } }
$wrapped = @(Get-ChoiceContractBreach -Declared $declared -Actual $actual)
Check 'wrapped result is an array' ($wrapped -is [array]) "type: $($wrapped.GetType().Name)"
Check 'Count is 0, not 1 (no nesting from a stray unary comma)' ($wrapped.Count -eq 0) "got $($wrapped.Count)"
Check 'no element is itself an array' (-not ($wrapped | Where-Object { $_ -is [array] })) 'result is nested'

Write-Host "`nCase 6 - both breach kinds at once"
$actual = @{ 1 = [pscustomobject]@{ Label = 'WRONG'; Color = '#ff0000' } }
$b = @(Get-ChoiceContractBreach -Declared $declared -Actual $actual)
Check 'reports both' ($b.Count -eq 2) "got $($b.Count): $($b -join '; ')"

Write-Host "`n--- $script:pass passed, $script:fail failed (host $($PSVersionTable.PSVersion)) ---"
if ($script:fail -gt 0) { exit 1 }
exit 0
