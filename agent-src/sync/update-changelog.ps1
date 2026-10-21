<#
.SYNOPSIS
  Creates a skill's CHANGELOG.md from the template in docs/templates/CHANGELOG_STYLE.md, or adds an entry to it.

  - No CHANGELOG.md yet: creates it from the style guide's template, filled in from the skill's SKILL.md (name,
    what it does, source folder), with a release for -Date and an Added entry: -Entry when given, otherwise
    "The skill itself" and the first sentence of the description.
  - CHANGELOG.md exists and -Entry is given: adds the entry under "## <-Date>" (created at the top when missing) in
    the -Category section (created in the style guide's order when missing). An identical entry isn't added twice.
  - CHANGELOG.md exists and no -Entry: does nothing.

  Runs on the source skill under agent-src/skills/ (never on the generated .claude/ or .github/ copies); run sync.ps1
  afterwards. sync.ps1 calls it for every aidevme-* skill that has no CHANGELOG.md.

.PARAMETER Skill
  The skill's folder name (for example aidevme-github) or its folder path.

.PARAMETER Entry
  The entry text without the leading "- ", following the style guide: the change in bold, then what it means for
  the reader, for example '**Links to tsdoc.org for every tag.** Each tag in references/tags.md links to its page.'

.PARAMETER Category
  Added, Changed, Deprecated, Removed, Fixed or Security. Default: Changed (Added when the file is created).

.PARAMETER Date
  The release heading, YYYY-MM-DD. Default: today.

.EXAMPLE
  pwsh -File agent-src/sync/update-changelog.ps1 -Skill aidevme-vitepress
  pwsh -File agent-src/sync/update-changelog.ps1 -Skill aidevme-vitepress -Category Fixed -Entry '**Dead links in tables are reported.** ...'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Skill,
    [string]$Entry,
    [ValidateSet('Added', 'Changed', 'Deprecated', 'Removed', 'Fixed', 'Security')][string]$Category,
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')][string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'
$syncDir   = $PSScriptRoot
$agentSrc  = Split-Path -Parent $syncDir
$repoRoot  = Split-Path -Parent $agentSrc
$skillsSrc = Join-Path $agentSrc 'skills'
$styleGuide = Join-Path $repoRoot 'docs/templates/CHANGELOG_STYLE.md'
$Order = @('Added', 'Changed', 'Deprecated', 'Removed', 'Fixed', 'Security')

# --- Find the source skill ---
if (Test-Path (Join-Path $Skill 'SKILL.md')) {
    $dir = (Resolve-Path $Skill).Path
} else {
    $match = @(Get-ChildItem -Path $skillsSrc -Recurse -Filter 'SKILL.md' -File | Where-Object { $_.Directory.Name -eq $Skill })
    if ($match.Count -ne 1) { throw "Skill '$Skill' not found (or found more than once) under agent-src/skills." }
    $dir = $match[0].Directory.FullName
}
$name = Split-Path -Leaf $dir
$relDir = ([System.IO.Path]::GetRelativePath($repoRoot, $dir)) -replace '\\', '/'
if ($relDir -notlike 'agent-src/skills/*') { throw "Edit the source skill under agent-src/skills/, not $relDir." }
$changelogPath = Join-Path $dir 'CHANGELOG.md'

function Read-Text([string]$path) { return ([System.IO.File]::ReadAllText($path)) -replace "`r`n", "`n" }
function Write-Text([string]$path, [string]$text) {
    [System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))
}
function Format-Entry([string]$text) {
    # One bullet; continuation lines indented by two spaces.
    $lines = ($text.Trim() -replace "`r`n", "`n") -split "`n"
    return '- ' + (($lines | ForEach-Object { $_.Trim() }) -join "`n  ")
}

# --- Create from the style guide's template ---
if (-not (Test-Path $changelogPath)) {
    if (-not (Test-Path $styleGuide)) { throw "Style guide not found: docs/templates/CHANGELOG_STYLE.md" }
    $guide = Read-Text $styleGuide
    $m = [regex]::Match($guide, '(?s)## Template.*?```markdown\n(.*?)\n```')
    if (-not $m.Success) { throw "No ```markdown template block under '## Template' in CHANGELOG_STYLE.md." }
    $template = $m.Groups[1].Value
    # The header: everything before the first release heading.
    $header = ($template -split "`n## <", 2)[0].TrimEnd()

    # What the skill does: the first sentence of its description.
    $skillMd = Read-Text (Join-Path $dir 'SKILL.md')
    $fm = [regex]::Match($skillMd, '(?s)^---\n(.*?)\n---')
    $desc = ''
    if ($fm.Success) {
        $d = [regex]::Match($fm.Groups[1].Value, '(?ms)^description:\s*(?:[|>][-+]?\s*\n)?(.*?)(?=^\S|\z)')
        if ($d.Success) { $desc = (($d.Groups[1].Value -split "`n" | ForEach-Object { $_.Trim() }) -join ' ').Trim().Trim('"', "'") }
    }
    $first = ([regex]::Match($desc, '^(.*?[.!?])(\s|$)')).Groups[1].Value
    if (-not $first) { $first = $desc }
    $first = ($first -replace '\s*Use when:?.*$', '').TrimEnd('.', ' ')
    $what = if ($first) { $first.Substring(0, 1).ToLower() + $first.Substring(1) } else { 'see SKILL.md' }

    $header = $header -replace '(?m)^<!-- cspell:ignore <[^>]*> -->\n', ''
    $header = $header.Replace('**<skill or tool name>** <skill | tool>: <what it does, in a few words>.', "**$name** skill: $what.")
    $header = [regex]::Replace($header, '<For a skill: The source is\s+`agent-src/skills/<scope>/<group>/<name>/`, synced to\s+`\.claude/skills/` and `\.github/skills/`\.>',
        "The source is ``$relDir/``, synced to ``.claude/skills/`` and ``.github/skills/``.")
    if (($header -replace '(?s)<!--.*?-->', '') -match '<[^>\n]+>') { throw "The template in CHANGELOG_STYLE.md has a placeholder this script doesn't fill: $($Matches[0])" }

    $first = if ($Entry) { Format-Entry $Entry } else { Format-Entry "**The skill itself.** $($first.TrimEnd('.'))." }
    $cat = if ($Category) { $Category } else { 'Added' }
    $text = "$header`n`n## $Date`n`n### $cat`n`n$first`n"
    Write-Text $changelogPath $text
    Write-Host "Created $relDir/CHANGELOG.md from docs/templates/CHANGELOG_STYLE.md." -ForegroundColor Green
    exit 0
}

if (-not $Entry) {
    Write-Host "$relDir/CHANGELOG.md exists; nothing to add without -Entry." -ForegroundColor Gray
    exit 0
}

# --- Add an entry ---
if (-not $Category) { $Category = 'Changed' }
$bullet = Format-Entry $Entry
$text = Read-Text $changelogPath

$releaseHead = "## $Date"
$relMatch = [regex]::Match($text, "(?m)^## $([regex]::Escape($Date))\s*$")
if (-not $relMatch.Success) {
    # New release at the top, before the first "## " heading (after the intro).
    $firstRel = [regex]::Match($text, '(?m)^## ')
    $block = "$releaseHead`n`n### $Category`n`n$bullet`n`n"
    $text = if ($firstRel.Success) { $text.Insert($firstRel.Index, $block) } else { $text.TrimEnd() + "`n`n" + $block.TrimEnd() + "`n" }
} else {
    $start = $relMatch.Index
    $next = [regex]::Match($text.Substring($start + $relMatch.Length), '(?m)^## ')
    $end = if ($next.Success) { $start + $relMatch.Length + $next.Index } else { $text.Length }
    $release = $text.Substring($start, $end - $start)
    if ($release.Contains($bullet)) {
        Write-Host "The entry is already in $relDir/CHANGELOG.md." -ForegroundColor Gray
        exit 0
    }
    $catMatch = [regex]::Match($release, "(?m)^### $Category\s*\n\n")
    if ($catMatch.Success) {
        # Add after the category's existing entries (before the next ### or the end of the release).
        $after = $release.Substring($catMatch.Index + $catMatch.Length)
        $nextCat = [regex]::Match($after, '(?m)^### ')
        $cut = if ($nextCat.Success) { $catMatch.Index + $catMatch.Length + $nextCat.Index } else { $release.Length }
        $before = $release.Substring(0, $cut).TrimEnd()
        $release = "$before`n$bullet`n`n" + $release.Substring($cut).TrimStart("`n")
    } else {
        # New category, in the style guide's order.
        $idx = [array]::IndexOf($Order, $Category)
        $insertAt = $release.Length
        foreach ($later in $Order[($idx + 1)..($Order.Count - 1)]) {
            $lm = [regex]::Match($release, "(?m)^### $later\s*$")
            if ($lm.Success) { $insertAt = $lm.Index; break }
        }
        $piece = "### $Category`n`n$bullet`n`n"
        $release = $release.Substring(0, $insertAt).TrimEnd() + "`n`n" + $piece + $release.Substring($insertAt).TrimStart("`n")
    }
    if ($next.Success) { $release = $release.TrimEnd() + "`n`n" }
    $text = $text.Substring(0, $start) + $release + $text.Substring($end)
}
Write-Text $changelogPath ($text.TrimEnd() + "`n")
Write-Host "Added an entry ($Category) under $releaseHead in $relDir/CHANGELOG.md." -ForegroundColor Green
exit 0
