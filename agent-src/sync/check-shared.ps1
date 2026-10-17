<#
.SYNOPSIS
  Fail-fast guard for the inherited product-tier junction (shared/).

  The wiki and many core skills point at product-tier knowledge under shared/dv/agent/wiki/...,
  which is a gitignored OS junction each developer/CI provisions once. If it is absent, sessions
  silently read nothing and the pre-implementation checklist is hollow. This guard makes that
  condition LOUD.

  Modes:
    (default) WARN — print a clear, actionable message and exit 0. Used by sync.ps1 so the template
                     itself still builds before a junction exists.
    -Strict         FAIL — exit 3 if the junction is absent. Wire this into first-run/onboarding and CI.

.EXAMPLE
  pwsh -File agent-src/sync/check-shared.ps1            # warn
.EXAMPLE
  pwsh -File agent-src/sync/check-shared.ps1 -Strict    # fail fast (exit 3 if absent)
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }

# The canonical product-tier mount. Child junctions follow the slug registry (dv = Dataverse tier).
$sharedRoot = Join-Path $RepoRoot 'shared'
$dvProbe    = Join-Path $RepoRoot 'shared/dv/agent/wiki'

$present = (Test-Path $dvProbe)

if ($present) {
    Write-Host "[shared-guard] OK — inherited product tier resolves at shared/dv/agent/wiki." -ForegroundColor Green
    exit 0
}

$msg = @"
[shared-guard] MISSING inherited product tier.

  Expected:  $dvProbe
  Found:     $(if (Test-Path $sharedRoot) { 'shared/ exists but shared/dv/agent/wiki does not resolve' } else { 'no shared/ folder at all' })

  The product-tier wiki and core skills are inherited via a gitignored OS junction. Until it is
  provisioned, every 'read shared/dv/agent/wiki/sop/...' step in the pre-implementation checklist
  reads nothing.

  To provision (Windows, from the repo root), point the junction at your local product-tier repo:
      cmd /c mklink /J shared\dv "C:\path\to\your\Dataverse-Best-Practices\repo"
  (or the equivalent for your platform / product slug). See docs/onboarding/agent.md.
"@

if ($Strict) {
    Write-Host $msg -ForegroundColor Red
    exit 3
} else {
    Write-Host $msg -ForegroundColor Yellow
    exit 0
}
