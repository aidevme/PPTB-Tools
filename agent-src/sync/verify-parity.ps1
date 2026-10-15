<#
.SYNOPSIS
  Drift / orphan backstop for the generated agent outputs. FAIL (exit 1) on any drift.

  Verifies that the generated tool directories exactly reflect the committed source:
    1. Skill-set parity : the set of skills in .claude/skills and .github/skills equals the set of
                          ported skills on disk under agent-src/skills/** (no orphans, none missing).
    2. Content parity   : every file under each generated skill matches its source (MD5).
    3. Cross-tool parity : .claude/skills and .github/skills are identical to each other (MD5).
    3b. Agents parity   : agent-src/agents/*.md fanned out byte-identically to .claude/agents and
                          .github/agents (ADR-0052 harness-mapping); no-op when no agents source.
    4. Instruction parity: CLAUDE.md and copilot-instructions.md each END WITH the AGENTS.md body.
    5. Hygiene          : no stray *.zip in any generated skill; no double-nested <name>/<name>/.

  Run after sync.ps1 (and in CI / pre-commit). Exit 0 = clean, exit 1 = drift found.
#>
[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$syncDir  = $PSScriptRoot
$agentSrc = Split-Path -Parent $syncDir
$repoRoot = Split-Path -Parent $agentSrc
$skillsSrc = Join-Path $agentSrc 'skills'

$issues = New-Object System.Collections.Generic.List[string]
function Fail($m) { $issues.Add($m) }
function Say($m)  { if (-not $Quiet) { Write-Host $m -ForegroundColor Gray } }
function Head($m) { if (-not $Quiet) { Write-Host "`n=== $m ===" -ForegroundColor Cyan } }

# Map of source skills: name -> folder path
$srcSkills = @{}
Get-ChildItem -Path $skillsSrc -Recurse -Filter 'SKILL.md' -File | ForEach-Object {
    $srcSkills[$_.Directory.Name] = $_.Directory.FullName
}
Head ("Source skills: {0}" -f $srcSkills.Count)

function Get-RelHashes([string]$root) {
    # relative-path (lowercased, forward-slash) -> MD5, for every file under $root
    $map = @{}
    if (-not (Test-Path $root)) { return $map }
    Get-ChildItem -Path $root -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($root.Length).TrimStart('\','/').Replace('\','/').ToLowerInvariant()
        $map[$rel] = (Get-FileHash -LiteralPath $_.FullName -Algorithm MD5).Hash
    }
    return $map
}

function Compare-SkillTree([string]$label, [string]$destSkillsDir) {
    Head "Verify $label"
    if (-not (Test-Path $destSkillsDir)) { Fail "$label : directory missing ($destSkillsDir)"; return }

    $destDirs = (Get-ChildItem -Path $destSkillsDir -Directory).Name
    # 1. orphans / missing
    foreach ($d in $destDirs) { if (-not $srcSkills.ContainsKey($d)) { Fail "$label : ORPHAN skill '$d' (not in source)" } }
    foreach ($n in $srcSkills.Keys) { if ($destDirs -notcontains $n) { Fail "$label : MISSING skill '$n' (in source, not generated)" } }

    foreach ($n in $srcSkills.Keys) {
        $destDir = Join-Path $destSkillsDir $n
        if (-not (Test-Path $destDir)) { continue }
        # 5. hygiene: double-nesting + stray zips
        if (Test-Path (Join-Path $destDir $n)) { Fail "$label : DOUBLE-NEST '$n/$n' detected" }
        if (Get-ChildItem -Path $destDir -Recurse -File -Include '*.zip' -ErrorAction SilentlyContinue) { Fail "$label : stray .zip inside '$n'" }
        # 2. content parity vs source (MD5, every file)
        $srcH  = Get-RelHashes $srcSkills[$n]
        $destH = Get-RelHashes $destDir
        foreach ($rel in $srcH.Keys) {
            if (-not $destH.ContainsKey($rel)) { Fail "$label/$n : missing file '$rel'" }
            elseif ($destH[$rel] -ne $srcH[$rel]) { Fail "$label/$n : DRIFT in '$rel'" }
        }
        foreach ($rel in $destH.Keys) { if (-not $srcH.ContainsKey($rel)) { Fail "$label/$n : extra file '$rel'" } }
    }
    Say ("  checked {0} skill(s)" -f $srcSkills.Count)
}

$claudeSkills  = Join-Path $repoRoot '.claude/skills'
$copilotSkills = Join-Path $repoRoot '.github/skills'
Compare-SkillTree '.claude/skills'  $claudeSkills
Compare-SkillTree '.github/skills' $copilotSkills

# 3. cross-tool parity (.claude vs .github must be byte-identical)
Head 'Cross-tool parity (.claude vs .github)'
$ch = Get-RelHashes $claudeSkills
$gh = Get-RelHashes $copilotSkills
foreach ($rel in $ch.Keys) {
    if (-not $gh.ContainsKey($rel)) { Fail "cross-tool : '$rel' only in .claude" }
    elseif ($gh[$rel] -ne $ch[$rel]) { Fail "cross-tool : '$rel' differs between .claude and .github" }
}
foreach ($rel in $gh.Keys) { if (-not $ch.ContainsKey($rel)) { Fail "cross-tool : '$rel' only in .github" } }
Say '  compared both tool trees'

# 3b. Agents parity (ADR-0052 harness-mapping): agent-src/agents/*.md must be fanned out byte-identically
#     to .claude/agents and .github/agents. No-op when the source dir is absent/empty (additive).
Head 'Agents parity (agent-src/agents -> .claude/agents + .github/agents)'
$agentsSrc     = Join-Path $agentSrc 'agents'
$claudeAgents  = Join-Path $repoRoot '.claude/agents'
$copilotAgents = Join-Path $repoRoot '.github/agents'
$srcAgents = @{}
if (Test-Path $agentsSrc) {
    Get-ChildItem -Path $agentsSrc -Filter '*.md' -File | ForEach-Object { $srcAgents[$_.Name] = $_.FullName }
}
if ($srcAgents.Count -eq 0) {
    Say '  no agent-src/agents/*.md — nothing to verify'
} else {
    foreach ($label in @('.claude/agents', '.github/agents')) {
        $destDir = if ($label -eq '.claude/agents') { $claudeAgents } else { $copilotAgents }
        if (-not (Test-Path $destDir)) { Fail "$label : directory missing ($destDir)"; continue }
        $destNames = (Get-ChildItem -Path $destDir -File).Name
        foreach ($n in $destNames) { if (-not $srcAgents.ContainsKey($n)) { Fail "$label : ORPHAN agent '$n' (not in source)" } }
        foreach ($n in $srcAgents.Keys) {
            if ($destNames -notcontains $n) { Fail "$label : MISSING agent '$n' (in source, not generated)"; continue }
            $srcHash  = (Get-FileHash -LiteralPath $srcAgents[$n] -Algorithm MD5).Hash
            $destHash = (Get-FileHash -LiteralPath (Join-Path $destDir $n) -Algorithm MD5).Hash
            if ($srcHash -ne $destHash) { Fail "$label : DRIFT in agent '$n'" }
        }
    }
    Say ("  checked {0} agent(s) across both harnesses" -f $srcAgents.Count)
}

# 4. instruction parity: generated files must end with the AGENTS.md body
Head 'Instruction parity (AGENTS.md -> generated)'
$body = (Get-Content -LiteralPath (Join-Path $repoRoot 'AGENTS.md') -Raw)
function Assert-EndsWithBody([string]$path, [string]$label) {
    if (-not (Test-Path $path)) { Fail "$label : generated file missing"; return }
    $gen = Get-Content -LiteralPath $path -Raw
    $normGen  = ($gen  -replace "`r`n","`n").TrimEnd()
    $normBody = ($body -replace "`r`n","`n").TrimEnd()
    if (-not $normGen.EndsWith($normBody)) { Fail "$label : does not end with the AGENTS.md body (out of sync — re-run sync.ps1)" }
    else { Say "  $label ends with AGENTS.md body (OK)" }
}
Assert-EndsWithBody (Join-Path $repoRoot 'CLAUDE.md') 'CLAUDE.md'
Assert-EndsWithBody (Join-Path $repoRoot '.github/copilot-instructions.md') 'copilot-instructions.md'

# --- Result ---
Head 'Result'
if ($issues.Count -eq 0) {
    Write-Host 'PARITY OK — zero drift.' -ForegroundColor Green
    exit 0
} else {
    Write-Host ("PARITY FAILED — {0} issue(s):" -f $issues.Count) -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
