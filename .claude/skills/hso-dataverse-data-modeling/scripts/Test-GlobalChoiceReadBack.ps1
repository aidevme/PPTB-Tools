<#
.SYNOPSIS
    Retry-loop tests for Assert-GlobalChoiceContract -- budget, backoff, exit codes, WARN path.

.DESCRIPTION
    Complements Test-GlobalChoiceContract.ps1, which covers the breach PREDICATE. This one covers
    the LOOP around it: how many attempts it spends, what it sleeps between them, and -- the part
    that actually matters -- what exit code it leaves behind.

    The whole defect class here is "correct work, wrong exit code", so every scenario asserts the
    exit code, not just the output. That means each scenario runs in a CHILD process (the function
    calls `exit 1` on a contract breach, which would take the runner down with it).

    Both Assert-GlobalChoiceContract and Get-ChoiceContractBreach are lifted out of the shipping
    script via the AST, and Invoke-DataverseWebApi is replaced with a scripted stub -- so this
    needs no environment, no auth and no network, and cannot drift from what ships.

.PARAMETER Scenario
    Internal. Runs one scenario in-process and exits with its code; the parent invokes this.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Test-GlobalChoiceReadBack.ps1

.NOTES
    Run under BOTH Windows PowerShell 5.1 and PowerShell 7 (ADR 0058). Exits 1 on any failure.
#>
[CmdletBinding()]
param([string]$Scenario)

$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'Invoke-DataverseMetadataOperation.ps1'

function Get-FunctionText {
    # Returns the source text of the named functions. It deliberately does NOT define them:
    # Invoke-Expression inside a function defines the result in THAT function's scope, so the
    # imports would vanish the moment it returned. The caller evaluates at script scope.
    param([string]$Path, [string[]]$Names)
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    $all = $ast.FindAll({
        param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true)
    $texts = foreach ($n in $Names) {
        $fn = $all | Where-Object { $_.Name -eq $n } | Select-Object -First 1
        if (-not $fn) { throw "Function '$n' not found in $Path -- was it renamed?" }
        $fn.Extent.Text
    }
    return ($texts -join "`n`n")
}

# ---------------------------------------------------------------------------
# Child mode: run one scenario and exit with its code
# ---------------------------------------------------------------------------
if ($Scenario) {
    Invoke-Expression (Get-FunctionText -Path $src -Names @('Get-ChoiceContractBreach', 'Assert-GlobalChoiceContract'))

    $script:WarnCount = 0
    # Keep the suite fast. The real 2/4/8/16 values are asserted separately, by reading them out of
    # the shipping script rather than by sleeping through them.
    $script:ChoiceReadBackAttempts = 5
    $script:ChoiceReadBackBackoff  = @(0, 0, 0, 0)

    $declared = @(
        [pscustomobject]@{ Label = 'Alpha'; Value = 1; Color = $null }
        [pscustomobject]@{ Label = 'Beta';  Value = 2; Color = $null }
    )

    # Scripted responses, one per attempt; the last is reused if the loop runs longer.
    $script:Calls = 0
    $good  = @{ Options = @(
        @{ Value = 1; Label = @{ UserLocalizedLabel = @{ Label = 'Alpha' } }; Color = $null }
        @{ Value = 2; Label = @{ UserLocalizedLabel = @{ Label = 'Beta'  } }; Color = $null }) }
    $stale = @{ Options = @(
        @{ Value = 1; Label = @{ UserLocalizedLabel = @{ Label = 'Alpha' } }; Color = $null }
        @{ Value = 2; Label = @{ UserLocalizedLabel = @{ Label = 'OLD'   } }; Color = $null }) }
    $absent = @{ Options = @(
        @{ Value = 1; Label = @{ UserLocalizedLabel = @{ Label = 'Alpha' } }; Color = $null }) }

    # Hashtable, NOT a switch: PowerShell unrolls a switch branch's pipeline output, so a
    # single-element plan like @($stale) collapsed to the bare $stale hashtable and @('throw')
    # collapsed to the string 'throw' -- after which $Plan[0] indexed a hashtable by key 0 (null)
    # or a string by character ('t'). Every one-step scenario silently read an EMPTY option set
    # and reported "not present" instead of exercising its real path. Hashtable values keep arrays.
    $plans = @{
        'settles-on-3'        = @($stale, $stale, $good)
        'never-settles-label' = @($stale)
        'never-settles-value' = @($absent)
        'always-throws'       = @('throw')
        'throws-then-settles' = @('throw', 'throw', $good)
    }
    if (-not $plans.ContainsKey($Scenario)) { throw "Unknown scenario '$Scenario'" }
    $script:Plan = @($plans[$Scenario])

    function Invoke-DataverseWebApi {
        param($Method, $Endpoint, $Body, $SolutionName, $IsMetadataOperation)
        $i = [Math]::Min($script:Calls, $script:Plan.Count - 1)
        $script:Calls++
        $r = $script:Plan[$i]
        if ($r -eq 'throw') { throw [System.Exception]::new('simulated 429 Too Many Requests') }
        return $r
    }

    Assert-GlobalChoiceContract -ChoiceName 'probe' -Declared $declared
    Write-Host "WARNCOUNT=$($script:WarnCount)"
    Write-Host "APICALLS=$($script:Calls)"
    exit 0
}

# ---------------------------------------------------------------------------
# Parent mode
# ---------------------------------------------------------------------------
$self = $MyInvocation.MyCommand.Path
$exe  = (Get-Process -Id $PID).Path        # re-enter on the SAME host we were started on
$pass = 0; $fail = 0
function Check {
    param([string]$Name, [bool]$Condition, [string]$Detail)
    if ($Condition) { $script:pass++; Write-Host "  PASS  $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  FAIL  $Name -- $Detail" -ForegroundColor Red }
}
function Run-Scenario {
    param([string]$Name)
    $out = & $exe -NoProfile -ExecutionPolicy Bypass -File $self -Scenario $Name 2>&1 | Out-String
    [pscustomobject]@{ Out = $out; Code = $LASTEXITCODE
                       Retries = ([regex]::Matches($out, '\[READBACK\].*retrying in')).Count
                       Warns   = ([regex]::Matches($out, '\[WARN\] Could not read the choice back')).Count }
}

Write-Host "T3/T5 harness - retry loop, budget and exit codes (host $($PSVersionTable.PSVersion))`n"

Write-Host 'Scenario: settles on attempt 3 (transient cache lag, then clean)'
$r = Run-Scenario 'settles-on-3'
Check 'exit 0' ($r.Code -eq 0) "got $($r.Code)"
Check 'reports 3 attempts' ($r.Out -match 'verified \(2 option\(s\)\) after 3 attempt\(s\)') 'attempt count not reported'
Check 'retried exactly twice' ($r.Retries -eq 2) "got $($r.Retries)"
Check 'no FATAL' ($r.Out -notmatch '\[FATAL\]') 'unexpected FATAL'

Write-Host "`nScenario: label never settles (T4 - genuine label breach)"
$r = Run-Scenario 'never-settles-label'
Check 'exit 1' ($r.Code -eq 1) "got $($r.Code)"
Check 'FATAL names the label mismatch' ($r.Out -match "label 'OLD' != declared 'Beta'") 'wrong FATAL text'
Check 'spent the FULL budget before failing (4 retries)' ($r.Retries -eq 4) "got $($r.Retries)"

Write-Host "`nScenario: value never appears (T3 - genuine missing value)"
$r = Run-Scenario 'never-settles-value'
Check 'exit 1' ($r.Code -eq 1) "got $($r.Code)"
Check 'FATAL names the missing value' ($r.Out -match "value 2 \('Beta'\) not present") 'wrong FATAL text'
Check 'spent the FULL budget before failing' ($r.Retries -eq 4) "got $($r.Retries)"

Write-Host "`nScenario: read fails every attempt (T5 - F2 regression)"
$r = Run-Scenario 'always-throws'
Check 'exit 0 - a read failure is NOT fatal' ($r.Code -eq 0) "got $($r.Code)"
Check 'exactly one WARN' ($r.Warns -eq 1) "got $($r.Warns)"
Check 'WarnCount incremented once' ($r.Out -match 'WARNCOUNT=1') 'WarnCount not 1'
Check 'RETRIED before giving up (was: bailed on attempt 1)' ($r.Retries -eq 4) "got $($r.Retries)"
Check 'made all 5 API attempts' ($r.Out -match 'APICALLS=5') 'did not use the full budget'
Check 'no FATAL' ($r.Out -notmatch '\[FATAL\]') 'a read failure must never be fatal'

Write-Host "`nScenario: read throws twice then succeeds (F2 - transient throttle recovers)"
$r = Run-Scenario 'throws-then-settles'
Check 'exit 0' ($r.Code -eq 0) "got $($r.Code)"
Check 'assertion actually ran (not skipped)' ($r.Out -match 'Choice contract verified') 'assertion was skipped'
Check 'no WARN - it recovered' ($r.Warns -eq 0) "got $($r.Warns)"

Write-Host "`nShipping budget constants (asserted from source, not slept through)"
$txt = Get-Content $src -Raw
Check 'attempts = 5' ($txt -match '\$script:ChoiceReadBackAttempts\s*=\s*5') 'attempts not 5'
Check 'backoff = 2,4,8,16 (30s ceiling)' ($txt -match '\$script:ChoiceReadBackBackoff\s*=\s*@\(2,\s*4,\s*8,\s*16\)') 'backoff sequence changed'

Write-Host "`n--- $pass passed, $fail failed (host $($PSVersionTable.PSVersion)) ---"
if ($fail -gt 0) { exit 1 }
exit 0
