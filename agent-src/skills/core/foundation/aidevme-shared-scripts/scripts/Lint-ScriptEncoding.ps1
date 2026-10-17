#Requires -Version 5.1
<#
.SYNOPSIS
Lints skill scripts for the two ways a .ps1 can be unrunnable on Windows PowerShell 5.1 while
looking perfectly fine in an editor and under pwsh 7.

.DESCRIPTION
Shipped skill scripts target Windows PowerShell 5.1 — the edition `powershell.exe` launches, and the
one an Azure DevOps `PowerShell@2` task runs by default (scripts that genuinely need PS7 declare it
with `#Requires -Version 7.0`). Two failure classes are flagged:

  1. ENCODING - the file contains non-ASCII bytes but carries no UTF-8 BOM.

     Windows PowerShell 5.1 decodes a BOM-less file as the ANSI codepage (Windows-1252 on a
     US/EU machine), NOT as UTF-8. An em-dash (U+2014, bytes E2 80 94) therefore decodes to
     'â€"' — and that final character is U+201D, a smart quote that PowerShell honours as a
     string delimiter. Inside a comment it is harmless mojibake; inside a string literal it
     TERMINATES the string early and the rest of the file fails to parse.

     That is not hypothetical: it is why Import-TemplateProject.ps1 could never run under 5.1,
     and nine other shipped scripts with it (2026-08-05). pwsh 7 defaults to UTF-8 and parses
     all of them happily, which is exactly why it went unnoticed for so long.

     Fix by adding a UTF-8 BOM, not by stripping the prose. Ten scripts in this repo already
     carried one for precisely this reason before the sweep.

  2. PS51-PARSE - the file does not parse under Windows PowerShell 5.1 for any other reason,
     typically PS7-only syntax (`??`, `?.`, ternary). Only checked on Windows, and only when
     powershell.exe is present.

     A script that genuinely needs PS7 is fine — declare it with `#Requires -Version 7.0` and
     this rule skips it. The declaration is the point: without it the script dies on
     "Unexpected token '??'" with no hint that the host is the problem.

.PARAMETER SkillsPath
Root folder to scan. Defaults to the skills directory this module lives in (e.g. the generated
.claude/skills), resolved relative to this script.

.PARAMETER SkipParseCheck
Run the ENCODING rule only. Use on non-Windows, or when powershell.exe is unavailable.

.OUTPUTS
Writes findings to the host. Exit code 0 = clean, 1 = one or more findings, 2 = bad path.

.EXAMPLE
pwsh agent-src/skills/core/foundation/aidevme-shared-scripts/scripts/Lint-ScriptEncoding.ps1 -SkillsPath agent-src/skills
#>
param(
    [string]$SkillsPath,
    [switch]$SkipParseCheck
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

$findings = New-Object System.Collections.Generic.List[object]
$scripts = Get-ChildItem -Path $SkillsPath -Recurse -Filter '*.ps1' -File

# Resolve the 5.1 host once. Absent on Linux/macOS and in pwsh-only containers - the ENCODING
# rule still runs there, which is the rule that actually prevents the defect.
$ps51 = $null
if (-not $SkipParseCheck -and $IsWindows -ne $false) {
    $candidate = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path $candidate) { $ps51 = $candidate }
}

foreach ($file in $scripts) {
    $bytes = [IO.File]::ReadAllBytes($file.FullName)

    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $hasNonAscii = $false
    foreach ($b in $bytes) { if ($b -gt 127) { $hasNonAscii = $true; break } }

    if ($hasNonAscii -and -not $hasBom) {
        $findings.Add([pscustomobject]@{
            File = $file.FullName; Class = 'ENCODING'
            Message = 'Contains non-ASCII but has no UTF-8 BOM; Windows PowerShell 5.1 will decode it as ANSI. Add a UTF-8 BOM.'
        })
    }

    if (-not $ps51) { continue }

    # A script that declares PS7 is allowed not to parse under 5.1 - that is the declaration's job.
    $head = [Text.Encoding]::UTF8.GetString($bytes)
    if ($head -match '(?im)^\s*#Requires\s+-Version\s+[7-9]') { continue }

    $out = & $ps51 -NoProfile -NonInteractive -Command @"
`$e = `$null; `$t = `$null
[System.Management.Automation.Language.Parser]::ParseFile('$($file.FullName)', [ref]`$t, [ref]`$e) | Out-Null
if (`$e) { `$e[0].Message }
"@ 2>&1

    $msg = ($out | Out-String).Trim()
    if ($msg) {
        $findings.Add([pscustomobject]@{
            File = $file.FullName; Class = 'PS51-PARSE'
            Message = "Does not parse under Windows PowerShell 5.1: $msg  (if PS7 is intended, declare '#Requires -Version 7.0')"
        })
    }
}

if ($findings.Count -eq 0) {
    Write-Host "[OK] All .ps1 under $SkillsPath are 5.1-safe" -ForegroundColor Green
    exit 0
}

Write-Host "[FAIL] Found $($findings.Count) script encoding/parse problem(s):" -ForegroundColor Red
foreach ($f in $findings) {
    Write-Host ("  [{0}] {1}`n           {2}" -f $f.Class, $f.File, $f.Message) -ForegroundColor Yellow
}
exit 1