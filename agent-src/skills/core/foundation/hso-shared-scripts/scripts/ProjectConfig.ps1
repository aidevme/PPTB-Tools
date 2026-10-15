<#
.SYNOPSIS
Resolve project-specific configuration from the internal repo's CLAUDE.md / CLAUDE.local.md.

.DESCRIPTION
Implements the project-configuration pattern (hso-skill-creator Step 4): a skill MUST NOT
hardcode project-specific values. Project-tier facts (client identifier, publisher prefix,
environment URLs, solution names) are read from CLAUDE.md; per-developer facts (local paths) are
read from CLAUDE.local.md. Anything missing is reported to the caller, which asks rather than guesses.

This keeps the skills themselves client-agnostic — the precondition for a core skill that round-trips
to the shared product tier: a client value baked into a skill folder would be shared across every
repo that inherits it, so project facts must stay in each repo's own config, never in the skill.

Dot-source it from a sibling skill's script:
    $sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
    . "$sharedDir\ProjectConfig.ps1"
#>

# NOTE: deliberately does NOT call Set-StrictMode. This file is dot-sourced, so any mode it sets
# leaks into the CALLER's scope and changes behaviour of code it knows nothing about.

function Find-RepoRoot {
    <#
    .SYNOPSIS
    Walk upward from a starting directory to the repo root (the directory holding CLAUDE.md).
    #>
    param([string]$StartPath = $PWD.Path)

    $dir = Resolve-Path -LiteralPath $StartPath -ErrorAction SilentlyContinue
    if (-not $dir) { return $null }
    $current = [System.IO.DirectoryInfo]::new($dir.Path)
    while ($current) {
        if (Test-Path -LiteralPath (Join-Path $current.FullName 'CLAUDE.md')) { return $current.FullName }
        $current = $current.Parent
    }
    return $null
}

function Get-MarkdownConfigValue {
    <#
    .SYNOPSIS
    Read one value from a two-column markdown config table: | <Key> | <Value> |

    .DESCRIPTION
    Matches the leading cell case-insensitively against -Key, then returns the second cell with
    surrounding backticks, bold markers, and whitespace stripped. Returns $null when absent.

    Values still carrying an "(UPDATE THIS PATH)" style placeholder are treated as NOT set, so an
    unconfigured developer gets the same clear failure as one who deleted the row.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Key
    )

    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    # -Raw + split keeps this fast on a large CLAUDE.md and avoids PS 5.1's single-line unrolling.
    $lines = @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)
    foreach ($line in $lines) {
        if ($line -notmatch '^\s*\|') { continue }
        $cells = $line.Trim().Trim('|').Split('|')
        if ($cells.Count -lt 2) { continue }

        $cellKey = $cells[0].Trim().Trim('*').Trim('`').Trim()
        if ($cellKey -ne $Key) { continue }

        $value = $cells[1].Trim().Trim('`').Trim('*').Trim('`').Trim()
        if ([string]::IsNullOrWhiteSpace($value)) { return $null }
        # Placeholder conventions used across the HSO templates.
        if ($value -match '(?i)UPDATE THIS|^<.*>$|^PLACEHOLDER|^set:') { return $null }
        # Strip a markdown link wrapper: [text](url) -> url
        if ($value -match '^\[[^\]]*\]\(([^)]+)\)$') { $value = $Matches[1] }
        return $value
    }
    return $null
}

function Get-ProjectConfig {
    <#
    .SYNOPSIS
    Resolve the client-publish configuration for the repo at -RepoPath.

    .DESCRIPTION
    Project tier  (CLAUDE.md, committed)       -> ClientName, ClientRepoUrl, ClientTenantId
                                                  plus PublisherPrefix / LanguageCode for scaffolding
    Developer tier(CLAUDE.local.md, gitignored)-> ClientLocalPath, AuthorName

    Returns a hashtable with a .Missing list naming any unresolved key, so callers can fail with a
    specific instruction instead of silently substituting a default.
    #>
    param([Parameter(Mandatory)][string]$RepoPath)

    $claude      = Join-Path $RepoPath 'CLAUDE.md'
    $claudeLocal = Join-Path $RepoPath 'CLAUDE.local.md'

    $cfg = [ordered]@{
        RepoPath         = $RepoPath
        ClientName       = Get-MarkdownConfigValue -Path $claude      -Key 'Client name'
        ClientRepoUrl    = Get-MarkdownConfigValue -Path $claude      -Key 'Client repo URL'
        ClientTenantId   = Get-MarkdownConfigValue -Path $claude      -Key 'Client tenant ID'
        PublisherPrefix  = Get-MarkdownConfigValue -Path $claude      -Key 'Publisher prefix'
        LanguageCode     = Get-MarkdownConfigValue -Path $claude      -Key 'Language code'
        ClientLocalPath  = Get-MarkdownConfigValue -Path $claudeLocal -Key 'Client repo local clone'
        AuthorName       = Get-MarkdownConfigValue -Path $claudeLocal -Key 'Author name'
        Missing          = @()
    }

    foreach ($k in @('ClientName','ClientRepoUrl')) {
        if (-not $cfg[$k]) { $cfg.Missing += "$k (CLAUDE.md -> 'Client publish target' table)" }
    }
    if (-not $cfg.ClientLocalPath) {
        $cfg.Missing += "ClientLocalPath (CLAUDE.local.md -> 'Client repo local clone' table)"
    }

    return $cfg
}

function Get-EnvironmentTable {
    <#
    .SYNOPSIS
    Read the internal repo's "## Environments" table as ordered Role -> URL pairs.

    .DESCRIPTION
    Used by the client-repo scaffolder so the client-facing instructions file describes the ACTUAL
    environments of the engagement it is being run for, rather than a set hardcoded at authoring time.
    Header and separator rows are skipped; the Production row is preserved in place.
    #>
    param([Parameter(Mandatory)][string]$RepoPath)

    $claude = Join-Path $RepoPath 'CLAUDE.md'
    if (-not (Test-Path -LiteralPath $claude)) { return @() }

    $lines  = @(Get-Content -LiteralPath $claude -ErrorAction SilentlyContinue)
    $inEnv  = $false
    $result = @()
    foreach ($line in $lines) {
        if ($line -match '^\s*##\s+Environments\s*$') { $inEnv = $true; continue }
        if ($inEnv -and $line -match '^\s*#{2,}\s') { break }          # next section ends the table
        if (-not $inEnv) { continue }
        if ($line -notmatch '^\s*\|') { continue }
        if ($line -match '^\s*\|\s*-{2,}') { continue }                # separator row

        $cells = $line.Trim().Trim('|').Split('|')
        if ($cells.Count -lt 2) { continue }
        $role = $cells[0].Trim().Trim('*').Trim('`').Trim('*').Trim()
        $url  = $cells[1].Trim().Trim('`').Trim()
        if ($role -match '^(Role|Setting)$') { continue }              # header row
        if ([string]::IsNullOrWhiteSpace($role) -or [string]::IsNullOrWhiteSpace($url)) { continue }
        $result += [pscustomobject]@{ Role = $role; Url = $url }
    }
    return $result
}

function Get-SolutionTable {
    <#
    .SYNOPSIS
    Read the internal repo's "## Solution architecture" table as ordered Solution -> Holds pairs.

    .DESCRIPTION
    Same rationale as Get-EnvironmentTable: the scaffolder must describe the engagement's real
    solution segmentation. Bold markers around the solution name (and a trailing "(default)") are
    stripped so the emitted client doc reads cleanly.
    #>
    param([Parameter(Mandatory)][string]$RepoPath)

    $claude = Join-Path $RepoPath 'CLAUDE.md'
    if (-not (Test-Path -LiteralPath $claude)) { return @() }

    $lines  = @(Get-Content -LiteralPath $claude -ErrorAction SilentlyContinue)
    $inSol  = $false
    $result = @()
    foreach ($line in $lines) {
        if ($line -match '^\s*##\s+Solution architecture\s*$') { $inSol = $true; continue }
        if ($inSol -and $line -match '^\s*#{2,}\s') { break }
        if (-not $inSol) { continue }
        if ($line -notmatch '^\s*\|') { continue }
        if ($line -match '^\s*\|\s*-{2,}') { continue }

        $cells = $line.Trim().Trim('|').Split('|')
        if ($cells.Count -lt 2) { continue }
        $name  = $cells[0].Trim() -replace '\*\*','' -replace '\(default\)','' -replace '`',''
        $name  = $name.Trim()
        $holds = $cells[1].Trim()
        if ($name -match '^Solution$') { continue }                    # header row
        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($holds)) { continue }
        $result += [pscustomobject]@{ Name = $name; Holds = $holds }
    }
    return $result
}
