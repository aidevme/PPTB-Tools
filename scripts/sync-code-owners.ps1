#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Syncs the auto-generated docs/ section of .github/CODEOWNERS with the current
    contents of the docs/ folder.

.DESCRIPTION
    Scans git-tracked files under docs/ and generates:
      - one entry per Markdown file directly in docs/            (docs/index.md)
      - one `**` entry per docs/ subdirectory (any depth) that
        directly contains at least one tracked file              (docs/github/**)

    The generated block replaces the content between the
        # BEGIN AUTO-GENERATED: docs
        # END AUTO-GENERATED: docs
    markers in .github/CODEOWNERS, leaving the rest of the file untouched. Using
    git-tracked files (rather than walking the filesystem) automatically skips
    gitignored build output such as docs/.vitepress/dist and docs/.vitepress/cache.

.PARAMETER Owner
    GitHub owner (user or team, e.g. @aidevme or @org/team) assigned to every
    generated docs/ entry. Defaults to @aidevme.

.PARAMETER Check
    Do not modify CODEOWNERS. Exit with code 1 if the generated block would
    differ from what is currently in the file. Useful in CI to catch a docs/
    folder that has drifted out of sync with CODEOWNERS.

.PARAMETER WhatIf
    Show the lines that would be added/removed without writing to disk.

.EXAMPLE
    .\sync-code-owners.ps1
    .\sync-code-owners.ps1 -Check
    .\sync-code-owners.ps1 -WhatIf
    .\sync-code-owners.ps1 -Owner '@aidevme/docs-team'
#>
param(
    [string]$Owner = '@aidevme',
    [switch]$Check,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot       = Resolve-Path (Join-Path $PSScriptRoot '..')
$codeownersPath = Join-Path $repoRoot '.github/CODEOWNERS'
$beginMarker    = '# BEGIN AUTO-GENERATED: docs'
$endMarker      = '# END AUTO-GENERATED: docs'
$padWidth       = 64

if (-not (Test-Path $codeownersPath)) {
    throw "CODEOWNERS file not found at $codeownersPath"
}

# ---------------------------------------------------------------------------
# 1. Discover git-tracked files under docs/
# ---------------------------------------------------------------------------
Push-Location $repoRoot
try {
    $trackedFiles = @(& git ls-files -- docs)
    if ($LASTEXITCODE -ne 0) {
        throw "git ls-files failed."
    }
} finally {
    Pop-Location
}

$trackedFiles = @($trackedFiles | Where-Object { $_ })

if ($trackedFiles.Count -eq 0) {
    throw "No git-tracked files found under docs/. Refusing to generate an empty CODEOWNERS section."
}

# ---------------------------------------------------------------------------
# 2. Build CODEOWNERS patterns:
#      - files directly in docs/          -> docs/<file>
#      - directories with >=1 direct file -> docs/<dir>/**  (any depth)
# ---------------------------------------------------------------------------
$patterns = [System.Collections.Generic.HashSet[string]]::new()

foreach ($file in $trackedFiles) {
    $normalized = $file -replace '\\', '/'
    $dir = [System.IO.Path]::GetDirectoryName($normalized) -replace '\\', '/'

    if ([string]::IsNullOrEmpty($dir) -or $dir -eq 'docs') {
        [void]$patterns.Add($normalized)
    } else {
        [void]$patterns.Add("$dir/**")
    }
}

$sortedPatterns = @($patterns | Sort-Object -CaseSensitive:$false)

# ---------------------------------------------------------------------------
# 3. Format the generated block
# ---------------------------------------------------------------------------
$generatedLines = [System.Collections.Generic.List[string]]::new()
$generatedLines.Add($beginMarker)
foreach ($pattern in $sortedPatterns) {
    $paddedPattern = if ($pattern.Length -lt $padWidth) { $pattern.PadRight($padWidth) } else { "$pattern " }
    $generatedLines.Add("$paddedPattern$Owner")
}
$generatedLines.Add($endMarker)

# ---------------------------------------------------------------------------
# 4. Splice the generated block into CODEOWNERS between the markers
# ---------------------------------------------------------------------------
$originalLines = @([System.IO.File]::ReadAllLines($codeownersPath, [System.Text.Encoding]::UTF8))

$beginIndex = [array]::IndexOf($originalLines, $beginMarker)
$endIndex   = [array]::IndexOf($originalLines, $endMarker)

if ($beginIndex -lt 0 -or $endIndex -lt 0 -or $endIndex -lt $beginIndex) {
    throw "Could not find '$beginMarker' / '$endMarker' markers in $codeownersPath. Add them around the docs/ section before running this script."
}

$existingBlock = @($originalLines[$beginIndex..$endIndex])

if (-not (Compare-Object $existingBlock $generatedLines -SyncWindow 0)) {
    Write-Host "CODEOWNERS docs/ section is already up to date." -ForegroundColor Green
    exit 0
}

if ($Check) {
    Write-Host "CODEOWNERS docs/ section is out of date. Run scripts/sync-code-owners.ps1 to fix." -ForegroundColor Red
    Write-Host "`nExpected:" -ForegroundColor Yellow
    $generatedLines | ForEach-Object { Write-Host "  $_" }
    exit 1
}

if ($WhatIf) {
    Write-Host "CODEOWNERS docs/ section would change:" -ForegroundColor Yellow
    Compare-Object $existingBlock $generatedLines -SyncWindow 0 |
        ForEach-Object {
            $prefix = if ($_.SideIndicator -eq '=>') { '+' } else { '-' }
            $color  = if ($_.SideIndicator -eq '=>') { 'Green' } else { 'Red' }
            Write-Host "  $prefix $($_.InputObject)" -ForegroundColor $color
        }
    exit 0
}

$newLines = @()
if ($beginIndex -gt 0) { $newLines += $originalLines[0..($beginIndex - 1)] }
$newLines += $generatedLines
if ($endIndex -lt $originalLines.Count - 1) { $newLines += $originalLines[($endIndex + 1)..($originalLines.Count - 1)] }

$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($codeownersPath, ($newLines -join "`n") + "`n", $utf8WithoutBom)

Write-Host "Updated CODEOWNERS with $($sortedPatterns.Count) docs/ entries owned by $Owner." -ForegroundColor Green
