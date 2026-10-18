<#
.SYNOPSIS
  Validate skills against the Agent Skills specification (https://agentskills.io) with the pinned skills-ref
  reference library. FAIL (exit 1) when a skill breaks the specification.

  Checks every SKILL.md under agent-src/skills (or the paths given): only the specification's frontmatter fields
  (name, description, license, allowed-tools, metadata, compatibility), the name format and that it matches the
  folder, and the length limits. Repository conventions (layer, scope) live under `metadata`; client extension keys
  Claude Code reads at the top level (argument-hint) are set aside, see CLIENT_EXTENSION_KEYS in validate_skills.py.

  skills-ref is pinned to $SkillsRefVersion and installed in agent-src/sync/.venv-skills-ref (gitignored). Without
  it the script stops and says how to install; -Install creates the venv and installs the pinned version.

  Run after editing a skill and before sync.ps1. Exit 0 = valid, 1 = invalid skills, 2 = skills-ref missing.

.EXAMPLE
  pwsh -File agent-src/sync/validate-skills.ps1
  pwsh -File agent-src/sync/validate-skills.ps1 agent-src/skills/core/delivery/aidevme-github
  pwsh -File agent-src/sync/validate-skills.ps1 -Install
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments)][string[]]$Path,
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
$SkillsRefVersion = '0.1.1'
$syncDir  = $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $syncDir)
$venv     = Join-Path $syncDir '.venv-skills-ref'
$python   = if ($IsWindows -or $env:OS -eq 'Windows_NT') { Join-Path $venv 'Scripts\python.exe' } else { Join-Path $venv 'bin/python' }

function Test-SkillsRef {
    if (-not (Test-Path $python)) { return $false }
    $installed = & $python -m pip show skills-ref 2>$null | Select-String '^Version:\s*(.+)$' | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }
    return $installed -eq $SkillsRefVersion
}

if (-not (Test-SkillsRef)) {
    if (-not $Install) {
        Write-Host "skills-ref $SkillsRefVersion isn't installed in $venv." -ForegroundColor Yellow
        Write-Host "Install it (Python 3.11+ required) with:  pwsh -File agent-src/sync/validate-skills.ps1 -Install"
        exit 2
    }
    $basePython = (Get-Command python -ErrorAction SilentlyContinue)?.Source ?? (Get-Command python3).Source
    if (-not (Test-Path $python)) { & $basePython -m venv $venv; if ($LASTEXITCODE) { exit $LASTEXITCODE } }
    & $python -m pip install --quiet --disable-pip-version-check "skills-ref==$SkillsRefVersion"
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    Write-Host "Installed skills-ref $SkillsRefVersion in $venv." -ForegroundColor Green
}

# Read SKILL.md files as UTF-8 regardless of the platform encoding.
$env:PYTHONUTF8 = '1'
Push-Location $repoRoot
try {
    & $python (Join-Path $syncDir 'validate_skills.py') @Path
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
