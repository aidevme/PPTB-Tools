<#
.SYNOPSIS
  Claude Code PostToolUse hook: keeps the CHANGELOG.md of an aidevme-* skill in step with edits to the skill.

  Runs after Write, Edit and MultiEdit (configured in .claude/settings.json). It reads the hook's JSON from stdin and,
  when the edited file is in a source skill under agent-src/skills/<scope>/<group>/aidevme-*/ (and isn't the
  skill's CHANGELOG.md):
    - The skill has no CHANGELOG.md (a new skill): creates it from docs/templates/CHANGELOG_STYLE.md with
      update-changelog.ps1, and tells Claude to review the first entry.
    - The skill has a CHANGELOG.md that isn't changed in the working tree yet: tells Claude to add an entry for
      this change now, with the exact update-changelog.ps1 command.
    - The CHANGELOG.md already has uncommitted changes: says nothing (the entry is on its way).
  It never blocks a tool call and always exits 0. GitHub Copilot has no such hook; AGENTS.md states the same rule.
#>
$ErrorActionPreference = 'Stop'
try {
    $syncDir  = $PSScriptRoot
    $repoRoot = Split-Path -Parent (Split-Path -Parent $syncDir)

    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }
    $hook = $raw | ConvertFrom-Json
    $file = $hook.tool_input.file_path
    if (-not $file) { exit 0 }

    $full = [System.IO.Path]::GetFullPath($(if ([System.IO.Path]::IsPathRooted($file)) { $file } else { Join-Path $repoRoot $file }))
    $rel = ([System.IO.Path]::GetRelativePath($repoRoot, $full)) -replace '\\', '/'
    $m = [regex]::Match($rel, '^(agent-src/skills/[^/]+/[^/]+/(aidevme-[^/]+))/(.+)$')
    if (-not $m.Success) { exit 0 }
    $skillDir = $m.Groups[1].Value
    $skill = $m.Groups[2].Value
    if ($m.Groups[3].Value -eq 'CHANGELOG.md') { exit 0 }
    if (-not (Test-Path (Join-Path $repoRoot "$skillDir/SKILL.md"))) { exit 0 }   # still being created

    $changelog = "$skillDir/CHANGELOG.md"
    $context = $null
    if (-not (Test-Path (Join-Path $repoRoot $changelog))) {
        & pwsh -NoProfile -File (Join-Path $syncDir 'update-changelog.ps1') -Skill $skill *> $null
        if ($LASTEXITCODE -eq 0) {
            $context = "Created $changelog for the new skill $skill from docs/templates/CHANGELOG_STYLE.md. Review its " +
                "'Added: The skill itself' entry and make it say what the skill does and what it ships with " +
                "(modes, references, scripts, what it was checked against)."
        }
    } else {
        $pending = & git -C $repoRoot status --porcelain -- $changelog 2>$null
        if (-not $pending) {
            $context = "You changed $rel in the skill $skill. Every change to a skill gets a CHANGELOG.md entry in the " +
                "same commit (docs/templates/CHANGELOG_STYLE.md). When this change is done, add the entry with: " +
                "pwsh -File agent-src/sync/update-changelog.ps1 -Skill $skill -Category <Added|Changed|Deprecated|Removed|Fixed|Security> " +
                "-Entry '**<The change, in a short phrase>.** <What it means for the person using the skill, naming the file or option.>' " +
                "Then add a matching row to the SKILL.md Changelog table, and run sync.ps1, verify-parity.ps1 and check-changelogs.ps1."
        }
    }

    if ($context) {
        @{ hookSpecificOutput = @{ hookEventName = 'PostToolUse'; additionalContext = $context } } | ConvertTo-Json -Compress -Depth 4
    }
} catch {
    # Never get in the way of the edit itself.
}
exit 0
