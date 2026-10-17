#Requires -Version 5.1
<#
.SYNOPSIS
Lints skill scripts for re-implemented Dataverse Web API invokers.

.DESCRIPTION
Enforces the "one shared Dataverse invoker; no per-skill copies" standard. A skill script
that dot-sources the shared module (aidevme-shared-scripts/scripts/Dataverse-WebApi.ps1) must NOT
carry its own copy of the HTTP invoker, and a script that talks to Dataverse must not sidestep
the module altogether. Three failure classes are flagged:

  1. SHADOW  - a function named exactly 'Invoke-DataverseApi' (the same name as the
               shared function). Dot-sourcing then re-defining it silently overrides
               the shared one, so fixes to the shared invoker never reach the skill.
  2. REIMPL  - a function named Invoke-Dv* / Invoke-Dataverse* whose body calls
               Invoke-RestMethod or Invoke-WebRequest directly, i.e. a parallel
               invoker that will drift from the shared one.
  3. BYPASS  - a Dataverse call made with Invoke-RestMethod / Invoke-WebRequest at the call
               site instead of through Invoke-DataverseApi. Applies whether or not the script
               dot-sources the module: adopting it and ignoring it lands in the same place as
               never adopting it. Suppress a justified call site with a
               `# lint:allow-raw-invoke <reason>` comment on it or the line above.

Three outcomes, not two. A BYPASS in a file marked `# lint:raw-invoke-backlog <reason>` is
reported as WARN and does NOT fail the run. Those are pre-existing drift tracked in an
open-backlog list, not exemptions: failing on them would leave the lint red on a clean
checkout (so it could never be wired into CI, and a NEW sixth finding would be invisible among
five permanent ones), while exempting them would make the debt unfindable. The marker is
deliberately a different string from `lint:allow-raw-invoke-file`, which marks a real ADR
exemption. Find the backlog with:  grep -r 'lint:raw-invoke-backlog'

Thin adapters that keep a local name but DELEGATE to the shared Invoke-DataverseApi
(no direct Invoke-RestMethod / Invoke-WebRequest in their body) are allowed and pass.

WHY BYPASS EXISTS (added 2026-08-05). SHADOW and REIMPL were both scoped to scripts that
dot-source the shared module and to functions whose NAME looks invoker-shaped. A script
that simply never adopted the module, and calls Invoke-RestMethod inline at the call site
rather than from a wrapper function, satisfied neither condition and was invisible - the
lint could report a repo clean while a skill did exactly that. It therefore
missed both hardenings the shared invoker already carries: -UseBasicParsing (without which
Windows PowerShell 5.1 tries to use the IE parser and dies under -NonInteractive on a build
agent) and the shared error handling. The rule the enforcement was meant to express is
"one invoker", not "one invoker among scripts that already agreed to use it".

Scoped to Dataverse callers by requiring an 'api/data/v9' endpoint in the file, so ADO REST
calls, package downloads and other unrelated HTTP stay out of scope.

Out-of-scope by construction: standalone assets that are COPIED into generated client repos
(e.g. an init-repo's bundled data scripts). They ship outside the skills tree and cannot
dot-source a library that is not there - a real exemption, not an oversight, so it is an
explicit allowlist rather than a side effect of the "must dot-source first" filter.

.PARAMETER SkillsPath
Root folder to scan. Defaults to the skills directory this module lives in (e.g. the generated
.claude/skills), resolved relative to this script.

.OUTPUTS
Writes findings to the host. Exit code 0 = no NEW findings (backlog WARNs do not fail),
1 = one or more new findings.

.EXAMPLE
pwsh agent-src/skills/core/foundation/aidevme-shared-scripts/scripts/Lint-SharedInvokerUsage.ps1 -SkillsPath agent-src/skills
#>
param(
    [string]$SkillsPath
)

$ErrorActionPreference = 'Stop'

if (-not $SkillsPath) {
    # This tool lives at <root>/skills/aidevme-shared-scripts/scripts; climb to <root>/skills.
    $SkillsPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
if (-not (Test-Path $SkillsPath)) {
    Write-Error "Skills path not found: $SkillsPath"
    exit 2
}

# Markers that mean "this script has the shared invoker in scope".
#
# Dataverse-Auth.ps1 counts: it dot-sources Dataverse-WebApi.ps1 at the end (2026-06-16), so a
# script that sources only Auth still gets Invoke-DataverseApi. Matching on the WebApi filename
# alone mis-filed such a script as "not a consumer" - a genuine SHADOW or REIMPL in an
# auth-only consumer would then have been missed entirely.
$sharedMarkers = @('Dataverse-WebApi.ps1', 'Dataverse-Auth.ps1')

# Function names that are invoker-shaped (case-insensitive).
$invokerNameRegex = '^Invoke-(Dv|Dataverse).*'

$findings = New-Object System.Collections.Generic.List[object]
# Known pre-existing drift (ADR 0014 open backlog). Reported on every run, never fails the
# build - see the `lint:raw-invoke-backlog` note below for why this is a separate bucket.
$backlog  = New-Object System.Collections.Generic.List[object]

$scripts = Get-ChildItem -Path $SkillsPath -Recurse -Filter '*.ps1' -File

foreach ($file in $scripts) {
    # Skip the shared library skill itself — it DEFINES the shared invoker and mentions the
    # marker filename, so it would false-positive as a SHADOW now that it lives under skills/.
    if ($file.FullName -match '[\\/]aidevme-shared-scripts[\\/]') { continue }

    # Shipped INTO client repos, outside the junction - the shared module is not on disk there.
    if ($file.FullName -match '[\\/]hso-dataverse-init-repo[\\/]assets[\\/]') { continue }

    $text = Get-Content -LiteralPath $file.FullName -Raw

    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$parseErrors)

    # BYPASS is deliberately NOT conditional on dot-sourcing. Whether a script never adopted the
    # module or adopted it and ignored it, the outcome is the same: a Dataverse call that misses
    # every hardening the shared invoker carries. Scoping this rule to non-consumers was the
    # original blind spot; scoping it to consumers would just move the hole.
    # File-level opt-out. ADR 0014's documented exemptions are whole SCRIPTS, not individual call
    # sites - aidevme-dataverse-data's paging / $batch / binary-body calls, and ui-config's deferred
    # inline calls - so a per-line marker would mean 27 near-identical comments and a reviewer
    # unable to see the exemption without reading every one. Declare it once at the top:
    #   # lint:allow-raw-invoke-file <reason>
    # SHADOW and REIMPL still apply; this suppresses BYPASS only.
    $fileAllowsRaw = $text -match 'lint:allow-raw-invoke-file'

    # KNOWN BACKLOG - a DIFFERENT marker on purpose:
    #   # lint:raw-invoke-backlog <reason>
    # These are not exemptions. They are pre-existing drift, listed in ADR 0014's open-backlog
    # table, that predates the BYPASS rule and is scheduled for conversion.
    #
    # They get their own outcome because the two obvious options are both worse. Failing on them
    # leaves the lint red on a clean checkout, so it cannot be wired into CI - and once five
    # findings are permanent, a SIXTH arriving next month is invisible in the noise, which
    # destroys the only thing this rule is for. Silently exempting them makes the debt
    # unfindable. Reported-but-not-failing keeps the gate usable for NEW drift while printing
    # the backlog on every run.
    #
    # The marker text differs from the exemption marker so the two can never be confused, and so
    # the backlog stays greppable:  grep -r 'lint:raw-invoke-backlog'
    $fileIsBacklog = $text -match 'lint:raw-invoke-backlog'

    if ($text -match 'api/data/v9' -and -not $fileAllowsRaw) {
        $rawTop = $ast.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.CommandAst] -and
                $n.GetCommandName() -in @('Invoke-RestMethod', 'Invoke-WebRequest')
            }, $true)

        # Calls inside an invoker-named function are REIMPL below - a more specific diagnosis of
        # the same problem. Only report the ones sitting loose in the script body here.
        $inNamedInvoker = $ast.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $n.Name -match '^Invoke-(Dv|Dataverse).*'
            }, $true) | ForEach-Object { $_.Extent }

        # Documented exceptions opt out per call site with `# lint:allow-raw-invoke <reason>` on
        # the call's line or the line above. Some raw calls are legitimate - a $batch request, or
        # a response the invoker cannot model - and a lint with no escape hatch is a lint everyone
        # learns to ignore. The marker makes each exception explicit and reviewable instead of
        # indistinguishable from drift.
        $lines = $text -split "`r?`n"
        $loose = @($rawTop | Where-Object {
                $call = $_
                $inInvoker = $inNamedInvoker | Where-Object {
                    $call.Extent.StartOffset -ge $_.StartOffset -and $call.Extent.EndOffset -le $_.EndOffset
                }
                if ($inInvoker) { return $false }

                $n = $call.Extent.StartLineNumber
                $onLine = $lines[$n - 1]
                $above = if ($n -ge 2) { $lines[$n - 2] } else { '' }
                -not (($onLine -match 'lint:allow-raw-invoke') -or ($above -match 'lint:allow-raw-invoke'))
            })

        if ($loose.Count -gt 0) {
            # Assign in statement form, NOT `$target = if (...) { $backlog } else { $findings }`.
            # PowerShell enumerates the output of an if-expression, and both of these are
            # List[object]: an empty list enumerates to nothing, so $target lands as $null and
            # .Add() throws; a populated one would yield its ELEMENTS rather than the list.
            # Same collection-unrolling trap that makes ConvertTo-Json drop empty arrays.
            if ($fileIsBacklog) { $target = $backlog } else { $target = $findings }
            $target.Add([pscustomobject]@{
                File = $file.FullName; Line = $loose[0].Extent.StartLineNumber
                Class = 'BYPASS'; Function = '<script body>'
                Message = "Calls the Dataverse Web API directly ($($loose.Count) call site(s)) instead of Invoke-DataverseApi; invoker hardening never reaches this skill."
            })
        }
    }

    $isSharedConsumer = $false
    foreach ($m in $sharedMarkers) { if ($text -match [regex]::Escape($m)) { $isSharedConsumer = $true; break } }
    if (-not $isSharedConsumer) { continue }

    $functions = $ast.FindAll(
        { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

    foreach ($fn in $functions) {
        if ($fn.Name -notmatch $invokerNameRegex) { continue }

        # Does the function body call Invoke-RestMethod / Invoke-WebRequest directly?
        $rawCalls = $fn.Body.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.CommandAst] -and
                $n.GetCommandName() -in @('Invoke-RestMethod', 'Invoke-WebRequest')
            }, $true)

        if ($fn.Name -ieq 'Invoke-DataverseApi') {
            $findings.Add([pscustomobject]@{
                File = $file.FullName; Line = $fn.Extent.StartLineNumber
                Class = 'SHADOW'; Function = $fn.Name
                Message = "Local function shadows the shared Invoke-DataverseApi; delete it and call the shared one."
            })
        }
        elseif ($rawCalls.Count -gt 0) {
            $findings.Add([pscustomobject]@{
                File = $file.FullName; Line = $fn.Extent.StartLineNumber
                Class = 'REIMPL'; Function = $fn.Name
                Message = "Local invoker calls Invoke-RestMethod/Invoke-WebRequest directly; delegate to the shared Invoke-DataverseApi instead."
            })
        }
    }
}

# Backlog first, so it reads as context for the verdict rather than as part of it.
if ($backlog.Count -gt 0) {
    Write-Host "[WARN] $($backlog.Count) known bypass(es) awaiting conversion - ADR 0014 open backlog:" -ForegroundColor DarkYellow
    foreach ($b in $backlog) {
        Write-Host ("  [{0}] {1}:{2}  {3}() - {4}" -f $b.Class, $b.File, $b.Line, $b.Function, $b.Message) -ForegroundColor DarkYellow
    }
    Write-Host "  These do not fail the build. Convert them and delete the lint:raw-invoke-backlog marker." -ForegroundColor DarkYellow
    Write-Host ""
}

if ($findings.Count -eq 0) {
    Write-Host "[OK] No new shared-invoker violations in $SkillsPath" -ForegroundColor Green
    exit 0
}

Write-Host "[FAIL] Found $($findings.Count) shared-invoker violation(s):" -ForegroundColor Red
foreach ($f in $findings) {
    $rel = $f.File
    Write-Host ("  [{0}] {1}:{2}  {3}() - {4}" -f $f.Class, $rel, $f.Line, $f.Function, $f.Message) -ForegroundColor Yellow
}
exit 1
