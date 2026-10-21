<#
.SYNOPSIS
  Changelog backstop for the source skills. FAIL (exit 1) when a skill's CHANGELOG.md is missing or behind.

  For every source skill under agent-src/skills/** whose name matches -Pattern (default: aidevme-*):
    1. Present : the skill folder has a CHANGELOG.md.
    2. Current : the skill wasn't changed without its changelog, checked two ways:
       - Working tree: files in the skill folder are changed (staged or not, or new) but CHANGELOG.md isn't.
       - History: the last commit that touched the skill folder is newer than the last commit that touched its
         CHANGELOG.md. A change and its entry in the same commit pass.

  The rule (docs/templates/CHANGELOG_STYLE.md, aidevme-skill-creator): every change to a skill adds an entry to its
  CHANGELOG.md in the same commit. Run it before committing, after sync.ps1 and verify-parity.ps1.
  Exit 0 = every changelog present and current, exit 1 = problems found (each listed).

.PARAMETER Pattern
  Skill folder names to check, as a wildcard. Default 'aidevme-*'. Use '*' to check every source skill.

.PARAMETER Quiet
  Print only the problems and the result.

.EXAMPLE
  pwsh -File agent-src/sync/check-changelogs.ps1
  pwsh -File agent-src/sync/check-changelogs.ps1 -Pattern '*'
#>
[CmdletBinding()]
param(
    [string]$Pattern = 'aidevme-*',
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$syncDir   = $PSScriptRoot
$agentSrc  = Split-Path -Parent $syncDir
$repoRoot  = Split-Path -Parent $agentSrc
$skillsSrc = Join-Path $agentSrc 'skills'

$issues = New-Object System.Collections.Generic.List[string]
function Say($m) { if (-not $Quiet) { Write-Host $m -ForegroundColor Gray } }

# Repository-relative path with forward slashes, as git prints it.
function Get-RepoPath([string]$full) {
    return ([System.IO.Path]::GetRelativePath($repoRoot, $full)) -replace '\\', '/'
}

# Unix time of the last commit touching $paths (git pathspecs), or 0 when there is none.
function Get-LastCommitTime([string[]]$paths) {
    $out = & git -C $repoRoot log -1 --format=%ct -- @paths 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $out) { return 0 }
    return [long]$out
}

$skills = Get-ChildItem -Path $skillsSrc -Recurse -Filter 'SKILL.md' -File |
    Where-Object { $_.Directory.Name -like $Pattern } |
    ForEach-Object { $_.Directory } |
    Sort-Object Name

Say ("Checking {0} skill(s) matching '{1}'" -f $skills.Count, $Pattern)

foreach ($dir in $skills) {
    $name = $dir.Name
    $rel = Get-RepoPath $dir.FullName
    $changelog = "$rel/CHANGELOG.md"

    # 1. Present
    if (-not (Test-Path (Join-Path $dir.FullName 'CHANGELOG.md'))) {
        $issues.Add("$name : no CHANGELOG.md (create it from docs/templates/CHANGELOG_STYLE.md)")
        continue
    }

    # 2a. Working tree: changed files in the skill, but not its changelog.
    $changed = @(& git -C $repoRoot status --porcelain --untracked-files=all -- $rel 2>$null |
        ForEach-Object { ($_.Substring(3) -replace '^.* -> ', '').Trim('"') })
    if ($changed.Count -gt 0) {
        $changelogChanged = $changed -contains $changelog
        $others = @($changed | Where-Object { $_ -ne $changelog })
        if ($others.Count -gt 0 -and -not $changelogChanged) {
            $issues.Add("$name : changed without a CHANGELOG.md entry ({0})" -f (($others | ForEach-Object { $_.Substring($rel.Length + 1) }) -join ', '))
            continue
        }
        if ($changelogChanged) { Say "  ok   $name (changelog updated in the working tree)"; continue }
    }

    # 2b. History: the skill's last commit (CHANGELOG.md excluded) vs the changelog's last commit.
    $skillTime = Get-LastCommitTime @($rel, ":(exclude)$changelog")
    $changelogTime = Get-LastCommitTime @($changelog)
    if ($skillTime -gt $changelogTime) {
        $sha = & git -C $repoRoot log -1 --format=%h -- $rel ":(exclude)$changelog"
        $issues.Add("$name : commit $sha changed the skill after its last CHANGELOG.md entry")
        continue
    }
    Say "  ok   $name"
}

if ($issues.Count -gt 0) {
    Write-Host ''
    $issues | ForEach-Object { Write-Host "  FAIL $_" -ForegroundColor Red }
    Write-Host ("`nCHANGELOGS: {0} problem(s)." -f $issues.Count) -ForegroundColor Red
    exit 1
}
Write-Host ("`nCHANGELOGS OK - {0} skill(s) checked." -f $skills.Count) -ForegroundColor Green
exit 0
