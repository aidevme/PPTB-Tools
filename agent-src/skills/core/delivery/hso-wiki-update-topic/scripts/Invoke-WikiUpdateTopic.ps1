# Invoke-WikiUpdateTopic.ps1
#
# Executes hso-wiki-update-topic synthesis mode for one anchor slug. Runs
# Pass 1 (frontmatter match) + Pass 2 (keyword fallback from anchor-keywords.md),
# prints a proposal, and on -Apply writes the accepted edits.
#
# Multi-tree (ADR 0006 D1/D2, ADR 0032 D3, implemented under ADR 0061 D7): walks the local
# <AgentPath>/wiki/ AND every inherited tier's wiki/ returned by Resolve-WikiTiers, in rank order.
#
# Inherited hits are proposed LINK-ONLY and labelled with their tier. Pass 2's frontmatter half is
# skipped for them, because every shared/<slug>/agent/ tree is read-only from a consuming repo
# (schema invariant #15): the link-addition half is the useful part, and Pass 2's self-healing
# property is the price of the invariant. That is the ADR 0006 D2 trade, made explicit.
#
# See SKILL.md for the full behaviour spec; this script implements it.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TopicSlug,

    [Parameter(Mandatory = $false)]
    [string]$AgentPath = "agent",

    [Parameter(Mandatory = $false)]
    [switch]$Apply,

    [Parameter(Mandatory = $false)]
    [string[]]$Reject = @()
)

$ErrorActionPreference = "Stop"

# `pwsh -File script.ps1 -Reject "a.md","b.md"` - the form SKILL.md documents - cannot pass an
# array: -File hands every argument to the script as a literal string, so the reject list arrives
# as the single element 'a.md,b.md' and matches no path. Splitting on commas here makes the
# documented command mean what it reads like, and leaves a genuine array (from `pwsh -Command` or
# a dot-source) working unchanged.
$Reject = @($Reject | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# --- Paths -----------------------------------------------------------------

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillDir  = Split-Path -Parent $scriptDir
$sharedSidecar  = Join-Path $skillDir "references\anchor-keywords.md"
$projectSidecar = Join-Path $AgentPath "wiki\topics\anchor-keywords.md"

$wikiRoot    = Join-Path $AgentPath "wiki"
$topicsDir   = Join-Path $wikiRoot "topics"

$anchorPath = Join-Path $topicsDir "$TopicSlug.md"

if (-not (Test-Path $wikiRoot)) {
    Write-Host "ERROR: wiki root not found at $wikiRoot" -ForegroundColor Red
    Write-Host "       Pass -AgentPath <path> if the wiki isn't at ./agent/" -ForegroundColor Gray
    exit 2
}

# --- Tier enumeration (ADR 0061 D7) ----------------------------------------
#
# One enumerator for every wiki read path. Probed across the sibling-skill path, the repo's own
# claude-code/skills, and each shared/<slug>/ - the same probe hso-wiki-lint uses. When the module
# cannot be found the script degrades to the local tier alone and SAYS SO, rather than quietly
# proposing a subset of what it should have found.
$repoRoot = Split-Path -Parent ((Resolve-Path -LiteralPath $AgentPath).ProviderPath.TrimEnd('\', '/'))

$tiersModule = $null
$moduleCandidates = @(
    (Join-Path $skillDir "..\hso-shared-scripts\scripts\Wiki-Tiers.ps1"),
    (Join-Path $repoRoot "claude-code\skills\hso-shared-scripts\scripts\Wiki-Tiers.ps1"),
    (Join-Path $repoRoot ".claude\skills\hso-shared-scripts\scripts\Wiki-Tiers.ps1")
)
$sharedDirProbe = Join-Path $repoRoot "shared"
if (Test-Path -LiteralPath $sharedDirProbe) {
    foreach ($child in @(Get-ChildItem -LiteralPath $sharedDirProbe -Directory -Force -ErrorAction SilentlyContinue)) {
        $moduleCandidates += (Join-Path $child.FullName "claude-code\skills\hso-shared-scripts\scripts\Wiki-Tiers.ps1")
    }
}
foreach ($c in $moduleCandidates) { if (Test-Path -LiteralPath $c) { $tiersModule = $c; break } }

$tiers = @()
if ($tiersModule) {
    . $tiersModule
    $tiers = @(Resolve-WikiTiers -RepoRoot $repoRoot -IncludeLocal)
}
if ($tiers.Count -eq 0) {
    if (-not $tiersModule) {
        Write-Host "WARN: Wiki-Tiers.ps1 not found - walking the LOCAL tree only." -ForegroundColor Yellow
        Write-Host "      Inherited tiers under shared/ will NOT be searched for this anchor." -ForegroundColor Gray
    }
    $tiers = @([pscustomobject]@{
        slug     = 'local'
        class    = 'project'
        rank     = 0
        path     = (Resolve-Path -LiteralPath $AgentPath).ProviderPath
        wikiPath = (Resolve-Path -LiteralPath $wikiRoot).ProviderPath
        isLocal  = $true
    })
}

$tierSummary = ($tiers | ForEach-Object { "$($_.class):$($_.slug)" }) -join ' < '

# --- Sidecar loader --------------------------------------------------------

function Read-AnchorKeywords {
    param([string]$Path)

    $map = @{}
    if (-not (Test-Path $Path)) { return $map }

    $currentSlug = $null
    foreach ($line in Get-Content -Path $Path) {
        if ($line -match '^##\s+(\S+)\s*$') {
            $currentSlug = $Matches[1].Trim()
            if (-not $map.ContainsKey($currentSlug)) {
                $map[$currentSlug] = @()
            }
        } elseif ($currentSlug -and $line -match '^\s*-\s+(.+?)\s*$') {
            $phrase = $Matches[1].Trim()
            if ($phrase) {
                $map[$currentSlug] += $phrase
            }
        }
    }
    return $map
}

# Sidecars merge LEAST-SPECIFIC FIRST so the most specific tier wins a slug collision - the
# generalisation of the old two-file shared-then-project merge to N tiers. The skill's own
# references/anchor-keywords.md is the baseline beneath all of them.
$keywordMap = @{}
$sharedMap = Read-AnchorKeywords -Path $sharedSidecar
foreach ($slug in $sharedMap.Keys) { $keywordMap[$slug] = $sharedMap[$slug] }

foreach ($tier in ($tiers | Sort-Object -Property rank -Descending)) {
    $tierSidecar = Join-Path $tier.wikiPath "topics\anchor-keywords.md"
    $map = Read-AnchorKeywords -Path $tierSidecar
    foreach ($slug in $map.Keys) { $keywordMap[$slug] = $map[$slug] }
}

if (-not $keywordMap.ContainsKey($TopicSlug)) {
    Write-Host "WARN: no keyword set defined for slug '$TopicSlug' in either sidecar." -ForegroundColor Yellow
    Write-Host "      Pass 2 will return zero hits. Add a '## $TopicSlug' section to" -ForegroundColor Gray
    Write-Host "      $sharedSidecar  (for product-tier)" -ForegroundColor Gray
    Write-Host "   or $projectSidecar  (for project-tier, wins on collision)" -ForegroundColor Gray
    $keywords = @()
} else {
    $keywords = $keywordMap[$TopicSlug]
}

# --- Frontmatter parser ----------------------------------------------------

function Read-Frontmatter {
    param([string]$Path)

    $result = @{
        HasFrontmatter = $false
        HasTopicsField = $false
        Topics         = @()
        RawLines       = @()
        EndLineIndex   = -1
    }

    if (-not (Test-Path $Path)) { return $result }
    $lines = Get-Content -Path $Path
    if ($lines.Count -lt 1 -or $lines[0] -notmatch '^---\s*$') { return $result }

    $result.HasFrontmatter = $true
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^---\s*$') {
            $result.EndLineIndex = $i
            break
        }
        $result.RawLines += $lines[$i]
    }
    if ($result.EndLineIndex -lt 0) {
        $result.HasFrontmatter = $false
        return $result
    }

    foreach ($fmLine in $result.RawLines) {
        if ($fmLine -match '^topics\s*:\s*(.*)$') {
            $result.HasTopicsField = $true
            $topicsValue = $Matches[1].Trim()
            if ($topicsValue -match '^\[(.*)\]$') {
                $inner = $Matches[1]
                if ($inner.Trim().Length -gt 0) {
                    $result.Topics = $inner -split ',' | ForEach-Object {
                        $_.Trim().Trim('"').Trim("'")
                    } | Where-Object { $_ }
                }
            }
        }
    }
    return $result
}

# --- Anchor stub creation --------------------------------------------------

function New-AnchorStub {
    param(
        [string]$Path,
        [string]$Slug
    )

    $today = (Get-Date).ToString('yyyy-MM-dd')
    $title = ($Slug -split '-' | ForEach-Object {
        if ($_.Length -gt 0) { $_.Substring(0,1).ToUpper() + $_.Substring(1) } else { $_ }
    }) -join ' '

    $content = @"
---
title: "$title"
type: topic
status: draft
scope: product
client: internal
project: hso-dataverse-best-practices
topics: [$Slug]
people: []
sources: []
created: $today
updated: $today
---

# $title

_TODO: one short paragraph orienting the reader to this subject. Keep it to 2-4 sentences. This is the only prose on this page._

## SOPs

## Reference

## Decisions

## Digests

<!-- This section is auto-managed by hso-wiki-update-topic. Do not edit manually. -->

## Skills

## External

## Related topics

"@

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -Path $Path -Value $content -Encoding UTF8
}

$anchorCreated = $false
if (-not (Test-Path $anchorPath)) {
    Write-Host "Anchor not found: $anchorPath" -ForegroundColor Yellow
    if ($Apply) {
        Write-Host "Creating stub anchor before applying proposals..." -ForegroundColor Yellow
        New-AnchorStub -Path $anchorPath -Slug $TopicSlug
        $anchorCreated = $true
    } else {
        Write-Host "Dry-run: would create stub anchor on -Apply." -ForegroundColor Gray
    }
}

# --- Pass 1: frontmatter match ---------------------------------------------

$pass1Hits = [System.Collections.ArrayList]@()

function Test-FrontmatterMatch {
    param(
        [string]$Folder,
        [string]$Section,
        [string]$Slug,
        $Tier
    )
    if (-not (Test-Path $Folder)) { return }
    Get-ChildItem -Path $Folder -Filter *.md -File -Recurse | ForEach-Object {
        $fm = Read-Frontmatter -Path $_.FullName
        if ($fm.HasTopicsField -and ($fm.Topics -contains $Slug)) {
            [void]$pass1Hits.Add([PSCustomObject]@{
                Section     = $Section
                Path        = $_.FullName
                TierSlug    = $Tier.slug
                TierClass   = $Tier.class
                IsInherited = (-not $Tier.isLocal)
            })
        }
    }
}

# The four searched folders, per tier. Scoped to wiki/ only: an inherited tier's work/, raw/ and
# _inbox/ never cross the tier boundary (schema invariant #18 / ADR 0038).
function Get-TierSearchFolder {
    param($Tier)
    return @(
        @{ Section = 'SOPs';      Folder = (Join-Path $Tier.wikiPath 'sop') },
        @{ Section = 'Reference'; Folder = (Join-Path $Tier.wikiPath 'reference') },
        @{ Section = 'Decisions'; Folder = (Join-Path $Tier.wikiPath 'decisions') },
        @{ Section = 'Digests';   Folder = (Join-Path $Tier.wikiPath 'digests') }
    )
}

foreach ($tier in $tiers) {
    foreach ($f in (Get-TierSearchFolder -Tier $tier)) {
        Test-FrontmatterMatch -Folder $f.Folder -Section $f.Section -Slug $TopicSlug -Tier $tier
    }
}

# --- Pass 2: keyword fallback on untagged files ----------------------------

$pass2Hits = [System.Collections.ArrayList]@()

function Test-KeywordMatch {
    param(
        [string]$Folder,
        [string]$Section,
        [string[]]$Phrases,
        $Tier
    )
    if (-not (Test-Path $Folder)) { return }
    if ($Phrases.Count -eq 0) { return }

    Get-ChildItem -Path $Folder -Filter *.md -File -Recurse | ForEach-Object {
        $fm = Read-Frontmatter -Path $_.FullName
        # Pass 2 only runs on files with missing or empty topics.
        if ($fm.HasTopicsField -and $fm.Topics.Count -gt 0) { return }

        $body = Get-Content -Path $_.FullName -Raw
        foreach ($phrase in $Phrases) {
            if ($body -and ($body.IndexOf($phrase, [StringComparison]::OrdinalIgnoreCase) -ge 0)) {
                [void]$pass2Hits.Add([PSCustomObject]@{
                    Section     = $Section
                    Path        = $_.FullName
                    Keyword     = $phrase
                    TierSlug    = $Tier.slug
                    TierClass   = $Tier.class
                    IsInherited = (-not $Tier.isLocal)
                })
                return  # one hit per file is enough
            }
        }
    }
}

foreach ($tier in $tiers) {
    foreach ($f in (Get-TierSearchFolder -Tier $tier)) {
        Test-KeywordMatch -Folder $f.Folder -Section $f.Section -Phrases $keywords -Tier $tier
    }
}

# --- Proposal output -------------------------------------------------------

Write-Host ""
Write-Host "=== hso-wiki-update-topic proposal for '$TopicSlug' ===" -ForegroundColor Cyan
Write-Host "Anchor: $anchorPath" -ForegroundColor Gray
Write-Host "AgentPath: $AgentPath" -ForegroundColor Gray
Write-Host "Tiers walked: $tierSummary" -ForegroundColor Gray
if ($anchorCreated) {
    Write-Host "(stub anchor just created from template)" -ForegroundColor Yellow
}
Write-Host ""

function Write-HitGroup {
    param(
        [string]$Header,
        [object[]]$Hits,
        [bool]$IsPass2
    )
    if ($Hits.Count -eq 0) { return }
    Write-Host $Header -ForegroundColor Cyan
    $bySection = $Hits | Group-Object Section
    foreach ($group in $bySection) {
        Write-Host "  [$($group.Name)] (+$($group.Count))" -ForegroundColor White
        foreach ($hit in $group.Group) {
            $line = "    + $($hit.Path)"
            if ($hit.IsInherited) {
                # Label the tier so a reviewer can see at a glance that accepting this adds a
                # THROUGH-THE-JUNCTION link to someone else's tier, not a local file.
                $line += "   [$($hit.TierClass): $($hit.TierSlug)]"
            }
            if ($IsPass2) {
                $line += "   [keyword: $($hit.Keyword)]"
                if ($hit.IsInherited) { $line += "  (link-only: inherited file, frontmatter edit skipped)" }
            }
            Write-Host $line
        }
    }
    Write-Host ""
}

Write-HitGroup -Header "Pass 1 (frontmatter match):" -Hits $pass1Hits.ToArray() -IsPass2 $false
Write-HitGroup -Header "Pass 2 (keyword fallback, untagged files, two-edit pairs):" -Hits $pass2Hits.ToArray() -IsPass2 $true

$totalProposed = $pass1Hits.Count + $pass2Hits.Count
if ($totalProposed -eq 0) {
    Write-Host "No proposals. Anchor is up to date (or nothing matches this slug)." -ForegroundColor Green
    exit 0
}

Write-Host "Total proposals: $totalProposed (Pass 1: $($pass1Hits.Count), Pass 2: $($pass2Hits.Count))" -ForegroundColor Gray
if ($Reject.Count -gt 0) {
    Write-Host "Rejections: $($Reject -join ', ')" -ForegroundColor Yellow
}

if (-not $Apply) {
    Write-Host ""
    Write-Host "Dry-run. Re-run with -Apply to write the proposals." -ForegroundColor Gray
    Write-Host "Use -Reject <path1>,<path2> to exclude specific proposals." -ForegroundColor Gray
    exit 0
}

# --- Apply -----------------------------------------------------------------

function Test-RejectMatch {
    param([string]$Path, [string[]]$RejectList)
    foreach ($r in $RejectList) {
        if ([string]::IsNullOrWhiteSpace($r)) { continue }
        if ($Path -like "*$r*") { return $true }
    }
    return $false
}

# Read anchor body once; append links per section; write back once.
$anchorLines = Get-Content -Path $anchorPath
$anchorText  = Get-Content -Path $anchorPath -Raw

function Get-SectionBounds {
    param([string[]]$Lines, [string]$Section)
    $start = -1
    $end   = $Lines.Count
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match ('^##\s+' + [regex]::Escape($Section) + '\s*$')) {
            $start = $i
        } elseif ($start -ge 0 -and $Lines[$i] -match '^##\s+') {
            $end = $i
            break
        }
    }
    return @($start, $end)
}

function Add-LinkToSection {
    param(
        [string[]]$Lines,
        [string]$Section,
        [string]$LinkPath,
        [string]$LinkLabel,
        [string]$TargetFullPath,
        [string]$AnchorDirectory,
        [ref]$WasAdded
    )
    if ($WasAdded) { $WasAdded.Value = $false }
    $bounds = Get-SectionBounds -Lines $Lines -Section $Section
    $start = $bounds[0]; $end = $bounds[1]
    if ($start -lt 0) {
        Write-Host "  WARN: section '$Section' not found in anchor; skipping." -ForegroundColor Yellow
        return $Lines
    }
    $linkLine = "- [$LinkLabel]($LinkPath)"
    # Deduplicate on the resolved target, so any existing spelling of the same file counts.
    $existing = Get-SectionLinkTargetSet -Lines $Lines -Start $start -End $end -AnchorDirectory $AnchorDirectory
    if ($existing.Contains($TargetFullPath)) {
        return $Lines  # already linked
    }
    if ($WasAdded) { $WasAdded.Value = $true }
    # Insert at end of section (before next ## or EOF).
    $insertAt = $end
    # Skip trailing blank lines.
    while ($insertAt -gt $start + 1 -and [string]::IsNullOrWhiteSpace($Lines[$insertAt - 1])) {
        $insertAt--
    }
    $before = $Lines[0..($insertAt - 1)]
    if ($insertAt -lt $Lines.Count) {
        $after = $Lines[$insertAt..($Lines.Count - 1)]
    } else {
        $after = @()
    }
    return @($before + $linkLine + $after)
}

# The base is the anchor's DIRECTORY, not the anchor file. Appending a separator to the file path
# made MakeRelativeUri treat 'integration-patterns.md' as a folder, so every generated link
# carried one extra '..' - 'wiki/topics/x.md' linking a decision produced '../../decisions/y.md',
# which resolves to 'agent/decisions/' and does not exist. That also silently defeated the dedup
# below, since the malformed link never matched the correct one already on the page.
function Get-RelativePath {
    param([string]$FromDirectory, [string]$To)
    $fromUri = New-Object System.Uri(((Resolve-Path -LiteralPath $FromDirectory).ProviderPath.TrimEnd('\', '/')) + [IO.Path]::DirectorySeparatorChar)
    $toUri   = New-Object System.Uri((Resolve-Path -LiteralPath $To).ProviderPath)
    $rel = $fromUri.MakeRelativeUri($toUri).ToString()
    return [System.Uri]::UnescapeDataString($rel)
}

<#
.SYNOPSIS
    Every repo-relative link target already present in a section, resolved to a full path.
.DESCRIPTION
    Dedup compares resolved targets rather than link text, so a file already linked by hand - in
    any relative spelling, with any label, with or without an anchor fragment - is recognised as
    linked. Comparing the literal path string only ever worked when the script happened to generate
    byte-identical text to a human, which is why re-runs kept appending duplicates.
#>
function Get-SectionLinkTargetSet {
    param([string[]]$Lines, [int]$Start, [int]$End, [string]$AnchorDirectory)

    $targets = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    for ($i = $Start + 1; $i -lt $End -and $i -lt $Lines.Count; $i++) {
        foreach ($match in [regex]::Matches($Lines[$i], '\[[^\]]*\]\(([^)]+)\)')) {
            $target = $match.Groups[1].Value.Trim()
            if ($target -match '^[A-Za-z][A-Za-z0-9+.\-]*:') { continue }   # external URL, not a file
            $target = ($target -split '#', 2)[0]
            if ([string]::IsNullOrWhiteSpace($target)) { continue }
            try {
                $full = [System.IO.Path]::GetFullPath(
                    [System.IO.Path]::Combine($AnchorDirectory, [System.Uri]::UnescapeDataString($target)))
                [void]$targets.Add($full)
            } catch { continue }
        }
    }
    return $targets
}

<#
.SYNOPSIS
    A human-readable link label: the file's frontmatter `title:`, else its first H1, else the stem.
.DESCRIPTION
    The bare filename stem the script used to emit ('0052-copilot-custom-agents-artifact-class')
    reads nothing like the hand-authored entries beside it. Titles keep generated links
    indistinguishable from curated ones, which is the point of an anchor page.
#>
function Get-LinkLabel {
    param([string]$Path)

    $stem = [IO.Path]::GetFileNameWithoutExtension($Path)
    try { $lines = Get-Content -LiteralPath $Path -ErrorAction Stop } catch { return $stem }
    if ($lines.Count -lt 1) { return $stem }

    if ($lines[0] -match '^---\s*$') {
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^---\s*$') { break }
            if ($lines[$i] -match '^title\s*:\s*(.+)$') {
                $title = $Matches[1].Trim().Trim('"').Trim("'").Trim()
                if ($title) { return $title }
            }
        }
    }
    foreach ($line in $lines) {
        if ($line -match '^#\s+(.+)$') { return $Matches[1].Trim() }
    }
    return $stem
}

function Add-TopicSlugToFrontmatter {
    param([string]$Path, [string]$Slug)
    $lines = Get-Content -Path $Path
    if ($lines.Count -lt 1 -or $lines[0] -notmatch '^---\s*$') {
        # No frontmatter; create minimal block.
        $today = (Get-Date).ToString('yyyy-MM-dd')
        $block = @(
            '---',
            "topics: [$Slug]",
            "updated: $today",
            '---',
            ''
        )
        Set-Content -Path $Path -Value ($block + $lines) -Encoding UTF8
        return
    }
    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^---\s*$') { $end = $i; break }
    }
    if ($end -lt 0) { return }

    $topicsIdx = -1
    for ($i = 1; $i -lt $end; $i++) {
        if ($lines[$i] -match '^topics\s*:') { $topicsIdx = $i; break }
    }

    if ($topicsIdx -lt 0) {
        $newLines = $lines[0..$end]
        $newLines = $newLines[0..($end - 1)] + "topics: [$Slug]" + '---'
        if ($end + 1 -lt $lines.Count) {
            $newLines += $lines[($end + 1)..($lines.Count - 1)]
        }
        Set-Content -Path $Path -Value $newLines -Encoding UTF8
        return
    }

    $topicsLine = $lines[$topicsIdx]
    if ($topicsLine -match '^topics\s*:\s*\[(.*)\]\s*$') {
        $inner = $Matches[1].Trim()
        if ($inner.Length -eq 0) {
            $newInner = $Slug
        } else {
            $existing = $inner -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") }
            if ($existing -contains $Slug) { return }
            $newInner = ($existing + $Slug) -join ', '
        }
        $lines[$topicsIdx] = "topics: [$newInner]"
    } elseif ($topicsLine -match '^topics\s*:\s*$') {
        $lines[$topicsIdx] = "topics: [$Slug]"
    } else {
        return
    }

    Set-Content -Path $Path -Value $lines -Encoding UTF8
}

$appliedPass1 = 0
$appliedPass2 = 0
$skipped = 0
$alreadyLinked = 0
$degradedPass2 = 0

$anchorDir = (Resolve-Path -LiteralPath (Split-Path -Parent $anchorPath)).ProviderPath

foreach ($hit in $pass1Hits) {
    if (Test-RejectMatch -Path $hit.Path -RejectList $Reject) { $skipped++; continue }
    $relLink = Get-RelativePath -FromDirectory $anchorDir -To $hit.Path
    $label = Get-LinkLabel -Path $hit.Path
    $added = $false
    $anchorLines = Add-LinkToSection -Lines $anchorLines -Section $hit.Section -LinkPath $relLink `
        -LinkLabel $label -TargetFullPath (Resolve-Path -LiteralPath $hit.Path).ProviderPath `
        -AnchorDirectory $anchorDir -WasAdded ([ref]$added)
    if ($added) { $appliedPass1++ } else { $alreadyLinked++ }
}

foreach ($hit in $pass2Hits) {
    if (Test-RejectMatch -Path $hit.Path -RejectList $Reject) { $skipped++; continue }
    $relLink = Get-RelativePath -FromDirectory $anchorDir -To $hit.Path
    $label = Get-LinkLabel -Path $hit.Path
    $added = $false
    $anchorLines = Add-LinkToSection -Lines $anchorLines -Section $hit.Section -LinkPath $relLink `
        -LinkLabel $label -TargetFullPath (Resolve-Path -LiteralPath $hit.Path).ProviderPath `
        -AnchorDirectory $anchorDir -WasAdded ([ref]$added)
    # The frontmatter half of a Pass 2 pair runs regardless FOR LOCAL FILES: the slug belongs on
    # the file even when the anchor already links it. For an INHERITED file it is skipped outright
    # - every shared/<slug>/agent/ tree is read-only from a consuming repo (schema invariant #15 /
    # ADR 0006 D2), so Pass 2 degrades to its link half. The self-healing property is lost for
    # inherited files; that is the cost of the invariant and the correct trade. To make Pass 1
    # catch the file next time, tag it in the owning tier's own repo.
    if ($hit.IsInherited) {
        $degradedPass2++
    } else {
        Add-TopicSlugToFrontmatter -Path $hit.Path -Slug $TopicSlug
    }
    if ($added) { $appliedPass2++ } else { $alreadyLinked++ }
}

# Bump the anchor's updated: frontmatter, then write back.
$today = (Get-Date).ToString('yyyy-MM-dd')
for ($i = 0; $i -lt $anchorLines.Count; $i++) {
    if ($anchorLines[$i] -match '^updated\s*:') {
        $anchorLines[$i] = "updated: $today"
        break
    }
}

Set-Content -Path $anchorPath -Value $anchorLines -Encoding UTF8

Write-Host ""
Write-Host "Applied: Pass 1 = $appliedPass1, Pass 2 = $appliedPass2, Skipped (rejected) = $skipped, Already linked = $alreadyLinked" -ForegroundColor Green
if ($degradedPass2 -gt 0) {
    Write-Host "Pass 2 degraded to link-only for $degradedPass2 inherited file(s) - no frontmatter written under shared/ (invariant #15)." -ForegroundColor Yellow
}
Write-Host "Anchor updated: $anchorPath" -ForegroundColor Green
exit 0
