#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs markdownlint and cspell on the repository's Markdown files.

.DESCRIPTION
    Runs both checks: markdownlint-cli2 for formatting and structure (a root devDependency, run from the
    repository's node_modules), then cspell for spelling (not a dependency: npx uses an installed copy, or
    downloads it). It only reports; it never changes a file. The exit code is non-zero when either check fails.

.PARAMETER Path
    Markdown files or glob patterns to check, relative to the repository root. Defaults to every Markdown file.
    Separate several with commas (-Path a.md,b.md), which also works with `pwsh -File`, or list them after the
    script name.

.EXAMPLE
    ./Validate-Markdown.ps1
    ./Validate-Markdown.ps1 -Path docs/repository/agentic-workflows.md
    ./Validate-Markdown.ps1 -Path 'docs/pptb-tools/**/*.md'
    pwsh -File ./Validate-Markdown.ps1 -Path AGENTS.md,PLAN.md
#>
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Path = @('**/*.md')
)

Set-StrictMode -Version Latest

# Split comma-separated values: `pwsh -File` can't pass an array, so '-Path a,b' arrives as one string.
$Path = @($Path | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# The repository root, wherever this copy of the script lives (the skill source or a generated skill folder).
$repoRoot = & git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
    throw 'Run this script from inside the PPTB-Tools git repository.'
}

Push-Location $repoRoot
try {
    Write-Host 'Running markdownlint validation...' -ForegroundColor Cyan
    & npx --no-install markdownlint-cli2 @Path '!.venv' '!.github' '!node_modules'
    $markdownlintExit = $LASTEXITCODE

    Write-Host ''
    Write-Host 'Running spell check...' -ForegroundColor Cyan
    & npx --yes cspell --no-progress --no-summary @Path
    $cspellExit = $LASTEXITCODE
} finally {
    Pop-Location
}

Write-Host ''
$failed = @()
if ($markdownlintExit -ne 0) { $failed += 'markdownlint' }
if ($cspellExit -ne 0) { $failed += 'cspell' }
if ($failed.Count -eq 0) {
    Write-Host 'Markdown validation passed.' -ForegroundColor Green
    exit 0
}
Write-Host "Markdown validation failed: $($failed -join ', ')." -ForegroundColor Red
exit 1
