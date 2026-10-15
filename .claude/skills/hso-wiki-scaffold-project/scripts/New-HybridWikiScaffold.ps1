<#
.SYNOPSIS
    Scaffold the hybrid agent/ wiki layout (raw/, _inbox/, wiki/, work/) in a repo.

.DESCRIPTION
    Implements the contract documented in
    agent-src/skills/core/delivery/hso-wiki-scaffold-project/SKILL.md:

      agent/
        README.md   index.md   log.md   schema.md     (seed files with valid frontmatter)
        raw/        transcripts/ discovery/ screenshots/ exports/
        _inbox/
        wiki/       system/ digests/ topics/ sop/ reference/ people/ decisions/
        work/       analysis/ specs/ design/
                    build/implementation-notes/ build/changelog/
                    testing/ deliverables/

    Idempotent: creates only what's missing; never overwrites existing .md seed
    files at agent/ root unless -Force is passed.

    This template keeps log.md and index.md as HAND-APPENDED / linter-audited files
    (see agent/schema.md) - there is no agent/log/ fragment folder and no generator.
    log.md is seeded with the single scaffolding entry at the top.

    Detects the legacy numbered layout (00_system, 02_analysis, ...) and refuses to
    auto-migrate. Points the caller at references/legacy-migration.md for the phased
    migration playbook. Phase 1 (scaffold the hybrid folders alongside the legacy ones)
    is non-destructive and handled by this script.

.PARAMETER RepoPath
    Target repository root. The agent/ folder will be created at $RepoPath/agent/.

.PARAMETER Tier
    Wiki tier: 'product', 'project', 'personal', or 'auto' (default). When 'auto', the
    script detects the tier from repo signals per SKILL.md section 1.

.PARAMETER AuthorName
    Name used in the seed log.md entry. Defaults to the current Windows display name.

.PARAMETER BestPracticesPath
    Path to a clone of the shared product-tier repo. Used to source the canonical
    schema.md when the consuming repo has no shared/dv junction yet. If omitted, the
    script looks for $RepoPath/shared/dv/ first and falls back to walking up from its
    own location.

.PARAMETER Force
    Overwrite existing agent/README.md, agent/index.md, agent/log.md, agent/schema.md.
    Folder/.gitkeep creation is always idempotent.

.EXAMPLE
    .\New-HybridWikiScaffold.ps1 -RepoPath C:\repos\MyClientProject

.EXAMPLE
    .\New-HybridWikiScaffold.ps1 -RepoPath C:\repos\Wiki-Personal -Tier personal
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoPath,

    [ValidateSet('auto', 'product', 'project', 'personal')]
    [string]$Tier = 'auto',

    [string]$AuthorName,

    [string]$BestPracticesPath,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

function Get-ScopeLabel {
    param([string]$Tier)
    switch ($Tier) {
        'product'  { return 'Product' }
        'project'  { return 'Project' }
        'personal' { return 'Personal' }
    }
    return 'Project'
}

function Resolve-Tier {
    param([string]$Path)

    $repoName = Split-Path $Path -Leaf

    # The template/product repo itself carries the committed skill source.
    if (Test-Path (Join-Path $Path 'agent-src\skills')) { return 'product' }
    # A consuming delivery repo mounts the product tier through a shared/<slug>/ junction.
    if (Test-Path (Join-Path $Path 'shared\dv\agent\wiki')) { return 'project' }
    if (Test-Path (Join-Path $Path 'shared')) {
        foreach ($cand in @(Get-ChildItem -LiteralPath (Join-Path $Path 'shared') -Directory -Force -ErrorAction SilentlyContinue)) {
            if (Test-Path (Join-Path $cand.FullName 'agent\wiki')) { return 'project' }
        }
    }
    if ($repoName -match '-wiki$' -or $Path -match '[\\/](personal|wiki-personal)[\\/]?$') { return 'personal' }

    return $null  # caller must ASK
}

function Test-LegacyLayout {
    param([string]$AgentPath)
    $legacy = @('00_system', '02_analysis', '03_digests', '04_specs', '05_design', '06_build', '07_testing', '09_deliverables')
    foreach ($name in $legacy) { if (Test-Path (Join-Path $AgentPath $name)) { return $true } }
    return $false
}

function Resolve-BestPracticesPath {
    param([string]$RepoPath, [string]$Explicit)

    if ($Explicit -and (Test-Path (Join-Path $Explicit 'agent\schema.md'))) { return $Explicit }

    # shared/dv junction - live view of the product-tier clone
    $junction = Join-Path $RepoPath 'shared\dv'
    if (Test-Path (Join-Path $junction 'agent\schema.md')) { return $junction }

    # If this script itself lives inside a product-tier clone, walk up to find agent/schema.md
    $candidate = $PSScriptRoot
    for ($i = 0; $i -lt 8; $i++) {
        if ($candidate -and (Test-Path (Join-Path $candidate 'agent\schema.md'))) { return $candidate }
        $candidate = Split-Path $candidate -Parent
        if (-not $candidate) { break }
    }

    return $null
}

function New-FolderIfMissing {
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null; return $true }
    return $false
}

function New-GitKeepIfMissing {
    param([string]$FolderPath)
    $gitkeep = Join-Path $FolderPath '.gitkeep'
    if (-not (Test-Path $gitkeep)) { Set-Content -Path $gitkeep -Value '' -NoNewline; return $true }
    return $false
}

function Write-SeedFile {
    param([string]$Path, [string]$Content, [switch]$Overwrite)
    if ((Test-Path $Path) -and -not $Overwrite) {
        Write-Host "  [SKIP] $([IO.Path]::GetFileName($Path)) already exists (pass -Force to overwrite)" -ForegroundColor DarkGray
        return $false
    }
    Set-Content -Path $Path -Value $Content -Encoding UTF8
    return $true
}

function Get-DisplayName {
    try {
        $fullName = (Get-CimInstance -ClassName Win32_UserAccount -Filter "Name='$env:USERNAME' AND LocalAccount='True'" -ErrorAction SilentlyContinue).FullName
        if ($fullName) { return $fullName }
    } catch {}
    return $env:USERNAME
}

# ----------------------------------------------------------------------------
# Seed file content
# ----------------------------------------------------------------------------

function New-ReadmeContent {
    param([string]$Tier, [string]$Today)

    $scopeLabel = Get-ScopeLabel -Tier $Tier
    $tierNote = switch ($Tier) {
        'product'  { 'This is the **product tier** - reusable methodology + platform knowledge, distributed to consuming repos via the `shared/dv/` junction.' }
        'project'  { 'This is the **project tier** - one client, one engagement. Inherits the product-tier wiki live via `shared/dv/agent/wiki/`.' }
        'personal' { 'This is the **personal tier** - one person''s private working memory. Not inherited by any other repo; promotion to project/product is deliberate.' }
    }

@"
---
title: agent - $scopeLabel Wiki
type: system-state
status: active
scope: $Tier
created: $Today
updated: $Today
---

# ``agent/`` - $scopeLabel Wiki (hybrid)

AI-augmented project knowledge for this repo. Hybrid four-layer design.

$tierNote

See [schema.md](schema.md) for conventions and the linter-enforced invariants.

## Four layers

| Layer | Purpose | Mutability |
|---|---|---|
| ``raw/`` | What we were given (sources of truth) | **Immutable** - LLM reads, never writes |
| ``_inbox/`` | Not yet triaged | Transient - emptied by ``hso-wiki-process-inbox`` |
| ``wiki/`` | What we *know* - compiled, cross-cutting, durable knowledge | LLM-maintained |
| ``work/`` | What we *produce* - phase-oriented project deliverables | LLM + human co-authored |

The test for *wiki vs work*: is this knowledge that outlives the project, or an artifact we're delivering? Topics, ADRs, digests -> wiki. Specs, TDDs, test plans, deliverables -> work.

## Core rules

1. **``raw/`` is read-only.** Never edit files here. Ingest skills write once.
2. **``_inbox/`` is transient.** Drop anything here; ``hso-wiki-process-inbox`` routes it.
3. **Every ``wiki/`` and ``work/`` page needs frontmatter.** See [schema.md](schema.md).
4. **Links are markdown only** - ``[text](relative/path.md)``.
5. **Append a ``log.md`` entry on every significant write** (newest at top; see [schema.md](schema.md) ``log.md`` format).
6. **Durable knowledge extracted from work products belongs in ``wiki/``.**
"@
}

function New-IndexContent {
    param([string]$Tier, [string]$Today, [string]$RepoName)

    $scopeLabel = Get-ScopeLabel -Tier $Tier

@"
---
title: Wiki Index
type: system-state
status: active
scope: $Tier
created: $Today
updated: $Today
---

# Index - $RepoName ($scopeLabel Wiki)

Entry point for humans and agents. Categorised catalog of the ``agent/`` contents at the **$Tier tier**. Regenerated (or audited) after every significant addition to the wiki by ``hso-wiki-lint``.

## Knowledge - ``wiki/``

### Topics - anchor pages (curated entry points per subject)
_No pages yet._

### SOPs - authored methodology
_No pages yet._

### Reference - external authoritative material
_No pages yet._

### Decisions (ADRs)
_No pages yet._

### People
_No pages yet._

### Digests
_No pages yet._

### System state
_No pages yet._

## Work products - ``work/``

### Analysis
_No pages yet._

### Specs
_No pages yet._

### Design
_No pages yet._

### Build
_No pages yet._ (see ``work/build/implementation-notes/`` and ``work/build/changelog/``)

### Testing
_No pages yet._

### Deliverables
_No pages yet._

---

*This index is regenerated (or audited) after every significant addition to the wiki. See [schema.md](schema.md) for the invariants the linter enforces.*
"@
}

function New-LogContent {
    param([string]$Tier, [string]$Today, [string]$AuthorName)

@"
---
title: Project Log
type: system-state
status: active
scope: $Tier
created: $Today
updated: $Today
---

# Log

Append-only chronological event stream. Newest entries at the top. Each entry follows the ``agent/schema.md`` format: ``## [YYYY-MM-DD] <kind> | <subject> | <title>``.

## [$Today] milestone | wiki | ``agent/`` scaffolded
Created by ``hso-wiki-scaffold-project`` / ``New-HybridWikiScaffold.ps1``. Tier: ``$Tier``. Author: $AuthorName. See ``agent/schema.md`` for conventions.
"@
}

function Copy-CanonicalSchema {
    param([string]$TargetPath, [string]$BestPracticesPath, [string]$Tier, [string]$Today, [switch]$Overwrite)

    $source = if ($BestPracticesPath) { Join-Path $BestPracticesPath 'agent\schema.md' } else { $null }

    if (-not $source -or -not (Test-Path $source)) {
        Write-Host "  [WARN] Canonical schema.md not found; writing minimal stub." -ForegroundColor Yellow
        $stub = @"
---
title: Wiki Schema & Conventions
type: system-state
status: active
scope: $Tier
created: $Today
updated: $Today
---

# Schema & Conventions

This is a stub. The canonical schema lives in the shared product-tier repo at ``agent/schema.md`` and should be copied here once the ``shared/dv/`` junction is in place. Run ``hso-wiki-scaffold-project`` again (or pass ``-BestPracticesPath``) to populate this file.
"@
        return (Write-SeedFile -Path $TargetPath -Content $stub -Overwrite:$Overwrite)
    }

    if ((Test-Path $TargetPath) -and -not $Overwrite) {
        Write-Host "  [SKIP] schema.md already exists (pass -Force to overwrite)" -ForegroundColor DarkGray
        return $false
    }

    $content = Get-Content $source -Raw -Encoding UTF8
    $content = $content -replace '(?m)^scope:\s*\S+\s*$', "scope: $Tier"

    # For non-product tiers, the schema's internal markdown links point at product-only content that
    # does not exist in a fresh consuming repo. Two cases:
    #   1) A junction to the source tier exists -> retarget links to ../shared/<slug>/agent/... .
    #   2) No junction -> strip the ](relative/path.md) portion, leaving link text as plain text so
    #      hso-wiki-lint does not flag broken links.
    if ($Tier -ne 'product') {
        $repoDir = Split-Path $TargetPath -Parent | Split-Path -Parent

        $sourceSlug = $null
        $sharedDir  = Join-Path $repoDir 'shared'
        if (Test-Path $sharedDir) {
            $sourceReal = $null
            try { $sourceReal = (Resolve-Path -LiteralPath $source).Path } catch { }
            foreach ($cand in @(Get-ChildItem -LiteralPath $sharedDir -Directory -Force -ErrorAction SilentlyContinue)) {
                $candSchema = Join-Path $cand.FullName 'agent\schema.md'
                if (-not (Test-Path $candSchema)) { continue }
                $candReal = $null
                try { $candReal = (Resolve-Path -LiteralPath $candSchema).Path } catch { }
                if ($sourceReal -and $candReal -and ($candReal -ieq $sourceReal)) { $sourceSlug = $cand.Name; break }
                if (-not $sourceSlug) { $sourceSlug = $cand.Name }   # fallback: first mounted tier
            }
        }
        $hasJunction = [bool]$sourceSlug

        $prefixable = @(
            'wiki/decisions/', 'wiki/digests/', 'wiki/topics/', 'wiki/sop/', 'wiki/reference/',
            'wiki/people/', 'wiki/system/',
            'work/analysis/', 'work/specs/', 'work/design/', 'work/build/', 'work/testing/', 'work/deliverables/',
            'raw/transcripts/', 'raw/discovery/', 'raw/exports/', 'raw/screenshots/'
        )

        if ($hasJunction) {
            foreach ($p in $prefixable) {
                $escaped = [regex]::Escape($p)
                $content = $content -replace "(\]\()$escaped", "`${1}../shared/$sourceSlug/agent/$p"
            }
        }
        else {
            foreach ($p in $prefixable) {
                $escaped = [regex]::Escape($p)
                $content = $content -replace "\[([^\]]+)\]\($escaped[^)]+\)", '$1'
            }
        }
    }

    Set-Content -Path $TargetPath -Value $content -Encoding UTF8
    return $true
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

if (-not (Test-Path $RepoPath)) { throw "RepoPath does not exist: $RepoPath" }
$RepoPath = (Resolve-Path $RepoPath).Path

$agentPath = Join-Path $RepoPath 'agent'
$today = Get-Date -Format 'yyyy-MM-dd'
if (-not $AuthorName) { $AuthorName = Get-DisplayName }

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " Hybrid Wiki Scaffold" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Repo: $RepoPath" -ForegroundColor Gray

if ($Tier -eq 'auto') {
    $detected = Resolve-Tier -Path $RepoPath
    if (-not $detected) {
        throw "Could not auto-detect wiki tier for $RepoPath. Pass -Tier product|project|personal explicitly."
    }
    $Tier = $detected
    Write-Host "  Tier: $Tier (auto-detected)" -ForegroundColor Gray
}
else {
    Write-Host "  Tier: $Tier" -ForegroundColor Gray
}
Write-Host ""

$bpPath = Resolve-BestPracticesPath -RepoPath $RepoPath -Explicit $BestPracticesPath

if ((Test-Path $agentPath) -and (Test-LegacyLayout -AgentPath $agentPath)) {
    Write-Host "  [NOTICE] Legacy numbered layout detected under agent/." -ForegroundColor Yellow
    Write-Host "  Scaffolding the hybrid folders alongside the legacy ones (Phase 1)." -ForegroundColor Yellow
    Write-Host "  For the full migration playbook, see references/legacy-migration.md" -ForegroundColor DarkGray
    Write-Host ""
}

[void](New-FolderIfMissing -Path $agentPath)

$folders = @(
    'raw/transcripts', 'raw/discovery', 'raw/screenshots', 'raw/exports',
    '_inbox',
    'wiki/system', 'wiki/digests', 'wiki/topics', 'wiki/sop', 'wiki/reference', 'wiki/people', 'wiki/decisions',
    'work/analysis', 'work/specs', 'work/design',
    'work/build/implementation-notes', 'work/build/changelog',
    'work/testing', 'work/deliverables'
)

$foldersCreated = 0
$gitkeepsCreated = 0
foreach ($rel in $folders) {
    $full = Join-Path $agentPath ($rel -replace '/', '\')
    if (New-FolderIfMissing -Path $full) { $foldersCreated++ }
    if (New-GitKeepIfMissing -FolderPath $full) { $gitkeepsCreated++ }
}
Write-Host "  Folders: $foldersCreated created ($($folders.Count - $foldersCreated) already existed)" -ForegroundColor Green
Write-Host "  .gitkeep files: $gitkeepsCreated created" -ForegroundColor Green

$repoName = Split-Path $RepoPath -Leaf

$readmeWritten = Write-SeedFile -Path (Join-Path $agentPath 'README.md') -Content (New-ReadmeContent -Tier $Tier -Today $today) -Overwrite:$Force
$indexWritten  = Write-SeedFile -Path (Join-Path $agentPath 'index.md')  -Content (New-IndexContent  -Tier $Tier -Today $today -RepoName $repoName) -Overwrite:$Force
$logWritten    = Write-SeedFile -Path (Join-Path $agentPath 'log.md')    -Content (New-LogContent    -Tier $Tier -Today $today -AuthorName $AuthorName) -Overwrite:$Force
$schemaWritten = Copy-CanonicalSchema -TargetPath (Join-Path $agentPath 'schema.md') -BestPracticesPath $bpPath -Tier $Tier -Today $today -Overwrite:$Force

$seeded = @($readmeWritten, $indexWritten, $logWritten, $schemaWritten) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
Write-Host "  Seed files: $seeded of 4 written (skipped existing unless -Force)" -ForegroundColor Green
Write-Host ""
Write-Host "  [OK] agent/ scaffolded at: $agentPath" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "    - Drop artifacts into agent/_inbox/ and run /hso-wiki-process-inbox" -ForegroundColor Gray
Write-Host "    - Capture a meeting or doc via /hso-wiki-capture" -ForegroundColor Gray
Write-Host "    - Record a decision via /hso-wiki-write-decision" -ForegroundColor Gray
Write-Host "    - Verify with /hso-wiki-lint (should be clean)" -ForegroundColor Gray
Write-Host ""
