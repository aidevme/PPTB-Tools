<#
.SYNOPSIS
  Single-source -> dual-tool sync for the agent layer.

  Fans the committed SOURCE (agent-src/skills/{core,project} + agent-src/agents + AGENTS.md) out to
  the GENERATED tool directories:
    - Skills  : agent-src/skills/**/<name>/  ->  .claude/skills/<name>/  and  .github/skills/<name>/
    - Agents  : agent-src/agents/<name>.md   ->  .claude/agents/<name>.md and .github/agents/<name>.md
                (ADR-0052 harness-mapping: one subagent source -> both harnesses, byte-identical)
    - Preamble: AGENTS.md body               ->  CLAUDE.md  and  .github/copilot-instructions.md
                (a tool-specific preamble from agent-src/sync/preambles/ is injected at the top)

  This INVERTS the older twin-mirror model: the source is committed; .claude/ and .github/ are build
  outputs and are marked "do not hand-edit". Verify with verify-parity.ps1 (drift = fail).

.PARAMETER Target
  Which tool(s) to generate for: Claude | Copilot | Both (default Both).

.PARAMETER DryRun
  Show what would be written/copied without changing anything.

.PARAMETER Force
  Reserved for future selective-overwrite behaviour; the sync already fully regenerates outputs.

.EXAMPLE
  pwsh -File agent-src/sync/sync.ps1
.EXAMPLE
  pwsh -File agent-src/sync/sync.ps1 -Target Claude -DryRun
#>
[CmdletBinding()]
param(
    [ValidateSet('Claude', 'Copilot', 'Both')]
    [string]$Target = 'Both',
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# --- Paths (resolve repo root from this script's location) ---
$syncDir   = $PSScriptRoot
$agentSrc  = Split-Path -Parent $syncDir
$repoRoot  = Split-Path -Parent $agentSrc
$skillsSrc = Join-Path $agentSrc 'skills'
$agentsSrc = Join-Path $agentSrc 'agents'
$manifestPath  = Join-Path $syncDir 'skills-manifest.json'
$agentsMdPath  = Join-Path $repoRoot 'AGENTS.md'
$preambleDir   = Join-Path $syncDir 'preambles'

function Write-Info($m)  { Write-Host $m -ForegroundColor Gray }
function Write-Good($m)  { Write-Host $m -ForegroundColor Green }
function Write-Warn2($m) { Write-Host $m -ForegroundColor Yellow }
function Write-Head($m)  { Write-Host "`n=== $m ===" -ForegroundColor Cyan }

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-TextFile([string]$Path, [string]$Content) {
    if ($DryRun) { Write-Info "  [DRY RUN] would write $Path"; return }
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

Write-Head 'Agent sync'
Write-Info "Repo root : $repoRoot"
Write-Info "Source    : $skillsSrc"
Write-Info "Target    : $Target"
if ($DryRun) { Write-Warn2 '(DRY RUN — no files will change)' }

# --- 0. Guard: warn (non-fatal) if the inherited shared/ product tier is absent ---
$guard = Join-Path $syncDir 'check-shared.ps1'
if (Test-Path $guard) { & $guard -RepoRoot $repoRoot }   # warn mode; -Strict is used by first-run/CI

# --- 1. Load manifest ---
if (-not (Test-Path $manifestPath)) { throw "Manifest not found: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$ported = @{}                     # name -> manifest entry, for ported=true
foreach ($s in $manifest.skills) { if ($s.ported) { $ported[$s.name] = $s } }

# --- 2. Discover physical skills (any folder under skills/{core,project} containing SKILL.md) ---
$physical = @()
if (Test-Path $skillsSrc) {
    Get-ChildItem -Path $skillsSrc -Recurse -Filter 'SKILL.md' -File | ForEach-Object {
        $folder = $_.Directory
        $rel = $folder.FullName.Substring($skillsSrc.Length).TrimStart('\','/') -replace '\\','/'
        $parts = $rel -split '/'
        $physical += [pscustomobject]@{
            Name   = $folder.Name
            Scope  = $parts[0]           # core | project
            Group  = if ($parts.Count -ge 3) { $parts[1] } else { $null }
            Path   = $folder.FullName
        }
    }
}
Write-Info ("Discovered {0} physical skill folder(s)." -f $physical.Count)

# --- 3. Contract checks (manifest <-> filesystem) ---
$problems = 0
foreach ($p in $physical) {
    if (-not $ported.ContainsKey($p.Name)) {
        Write-Warn2 "  MANIFEST MISS: skill '$($p.Name)' exists on disk but has no ported=true manifest entry."
        $problems++
    } elseif ($ported[$p.Name].scope -ne $p.Scope) {
        Write-Warn2 "  SCOPE MISMATCH: '$($p.Name)' is under '$($p.Scope)/' but manifest says scope='$($ported[$p.Name].scope)'."
        $problems++
    }
}
$physNames = $physical | ForEach-Object { $_.Name }
foreach ($name in $ported.Keys) {
    if ($physNames -notcontains $name) {
        Write-Warn2 "  MISSING SOURCE: manifest marks '$name' ported=true but no folder was found on disk."
        $problems++
    }
}
if ($problems -gt 0) { Write-Warn2 "  ($problems manifest/filesystem discrepancy(ies) — sync continues with what exists on disk.)" }
else { Write-Good '  Manifest and filesystem agree.' }

# --- 4. Fan skills out to the selected tool targets ---
$doClaude  = $Target -in @('Claude','Both')
$doCopilot = $Target -in @('Copilot','Both')

function Sync-SkillsTo([string]$destSkillsDir, [string]$label) {
    Write-Head "Skills -> $label"
    if ($DryRun) {
        Write-Info "  [DRY RUN] would clean $destSkillsDir then copy $($physical.Count) skill(s)"
    } else {
        if (Test-Path $destSkillsDir) { Get-ChildItem -Path $destSkillsDir -Directory | Remove-Item -Recurse -Force }
        else { New-Item -ItemType Directory -Force -Path $destSkillsDir | Out-Null }
    }
    foreach ($p in ($physical | Sort-Object Name)) {
        $dest = Join-Path $destSkillsDir $p.Name
        if ($DryRun) { Write-Info "  [DRY RUN] $($p.Scope)/$($p.Name) -> $dest"; continue }
        # Copy into a freshly-created dest dir (no pre-existing same-name child) => NO double-nesting.
        Copy-Item -Path $p.Path -Destination $dest -Recurse -Force
        # Prune stray build artifacts that must never ship in a skill folder.
        Get-ChildItem -Path $dest -Recurse -File -Include '*.zip' -ErrorAction SilentlyContinue | Remove-Item -Force
        Write-Good "  + $($p.Name)"
    }
}

if ($doClaude)  { Sync-SkillsTo (Join-Path $repoRoot '.claude/skills')  '.claude/skills' }
if ($doCopilot) { Sync-SkillsTo (Join-Path $repoRoot '.github/skills') '.github/skills' }

# --- 4b. Fan single-source agent definitions out to both harnesses (ADR-0052 harness-mapping) ---
# One committed source per subagent under agent-src/agents/*.md -> .claude/agents/ (Claude Agent-tool
# subagents) AND .github/agents/ (Copilot custom agents), byte-identical. No-op when the source dir
# is absent/empty, so this is additive and never destabilises a repo that ships no agents.
$agentFiles = @()
if (Test-Path $agentsSrc) {
    $agentFiles = @(Get-ChildItem -Path $agentsSrc -Filter '*.md' -File)
}
function Sync-AgentsTo([string]$destAgentsDir, [string]$label) {
    Write-Head "Agents -> $label"
    if ($agentFiles.Count -eq 0) { Write-Info "  (no agent-src/agents/*.md — nothing to fan out)"; return }
    if ($DryRun) { Write-Info "  [DRY RUN] would clean $destAgentsDir then copy $($agentFiles.Count) agent(s)"; return }
    if (Test-Path $destAgentsDir) { Get-ChildItem -Path $destAgentsDir -File | Remove-Item -Force }
    else { New-Item -ItemType Directory -Force -Path $destAgentsDir | Out-Null }
    foreach ($a in ($agentFiles | Sort-Object Name)) {
        Copy-Item -Path $a.FullName -Destination (Join-Path $destAgentsDir $a.Name) -Force
        Write-Good "  + $($a.Name)"
    }
}
if ($doClaude)  { Sync-AgentsTo (Join-Path $repoRoot '.claude/agents')  '.claude/agents' }
if ($doCopilot) { Sync-AgentsTo (Join-Path $repoRoot '.github/agents') '.github/agents' }

# --- 5. Generate the instruction files from AGENTS.md + tool preamble ---
Write-Head 'Instructions (AGENTS.md -> generated)'
if (-not (Test-Path $agentsMdPath)) { throw "Source AGENTS.md not found: $agentsMdPath" }
$body = Get-Content -LiteralPath $agentsMdPath -Raw

function New-InstructionFile([string]$preambleFile, [string]$destPath, [string]$label) {
    $preamble = ''
    $pf = Join-Path $preambleDir $preambleFile
    if (Test-Path $pf) { $preamble = (Get-Content -LiteralPath $pf -Raw).TrimEnd() + "`r`n`r`n" }
    else { Write-Warn2 "  preamble missing: $pf (generating body only)" }
    Write-TextFile $destPath ($preamble + $body)
    if (-not $DryRun) { Write-Good "  wrote $label" }
}

if ($doClaude)  { New-InstructionFile 'claude.md'  (Join-Path $repoRoot 'CLAUDE.md') 'CLAUDE.md' }
if ($doCopilot) { New-InstructionFile 'copilot.md' (Join-Path $repoRoot '.github/copilot-instructions.md') '.github/copilot-instructions.md' }

# --- 6. Summary ---
Write-Head 'Summary'
Write-Info ("  Skills synced   : {0}" -f $physical.Count)
Write-Info ("  Agents synced   : {0}" -f $agentFiles.Count)
Write-Info ("  Targets         : {0}" -f $Target)
$catalogued = ($manifest.skills | Where-Object { $_.scope -in @('core','project') -and -not $_.ported }).Count
$dropped    = ($manifest.skills | Where-Object { $_.scope -eq 'drop' }).Count
Write-Info ("  Catalogued (not yet ported): {0}" -f $catalogued)
Write-Info ("  Dropped (recorded)         : {0}" -f $dropped)
if ($DryRun) { Write-Warn2 '  DRY RUN — nothing was written.' }
else { Write-Good '  Sync complete. Run verify-parity.ps1 to confirm zero drift.' }
