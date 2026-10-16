#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Syncs cspell.json words list based on unknown words found in Markdown files.

.DESCRIPTION
    Runs cspell against the selected Markdown paths, extracts unknown words, and
    interactively prompts you to add each one to cspell.json. Words already
    present in cspell.json are skipped. The words list is kept sorted
    alphabetically (case-insensitive) after each update.

.PARAMETER AutoAdd
    Add all unknown words without prompting.

.PARAMETER MarkdownPath
    One or more Markdown files or glob patterns to scan. Defaults to all
    Markdown files in the repository.

.PARAMETER ListOnly
    Print the unknown words that aren't in cspell.json yet, one per line, and
    change nothing. For reviewing the list (for example with an AI assistant,
    which can't answer the prompts) before adding words with -Word.

.PARAMETER Word
    Add exactly these words to cspell.json, without prompting and without
    running cspell. Words already in the list are skipped.

.EXAMPLE
    .\Sync-Cspell.ps1
    .\Sync-Cspell.ps1 -AutoAdd
    .\Sync-Cspell.ps1 -MarkdownPath templates/workflows/codeql/README.md -AutoAdd
    .\Sync-Cspell.ps1 -ListOnly
    .\Sync-Cspell.ps1 -Word dataverse-ify, Durow
#>
param(
    [switch]$AutoAdd,
    [string[]]$MarkdownPath = @('**/*.md'),
    [switch]$ListOnly,
    [string[]]$Word
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The repository root, wherever this copy of the script lives (the skill source or a generated skill folder).
$repoRoot = & git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
    throw 'Run this script from inside the PPTB-Tools git repository.'
}
$cspellPath = Join-Path $repoRoot 'cspell.json'

# Split comma-separated values: `pwsh -File` can't pass an array, so '-Word a,b' arrives as one string.
$MarkdownPath = @($MarkdownPath | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($Word) { $Word = @($Word | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

if ($ListOnly -and $Word) {
    throw 'Use either -ListOnly or -Word, not both.'
}

# ---------------------------------------------------------------------------
# 1. Run cspell and capture output (or take the words given with -Word)
# ---------------------------------------------------------------------------
if ($Word) {
    $unknownWords = @($Word | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique -CaseSensitive:$false)
} else {
    $displayPaths = $MarkdownPath -join ', '
    Write-Host "`nRunning cspell against $displayPaths ..." -ForegroundColor Cyan

    Push-Location $repoRoot
    try {
        $cspellOutput = & npx cspell $MarkdownPath --no-progress --no-summary 2>&1
    } finally {
        Pop-Location
    }

    # ---------------------------------------------------------------------------
    # 2. Parse unknown words from output lines like:
    #    file.md:12:5 - Unknown word (someWord)
    # ---------------------------------------------------------------------------
    $unknownWords = @($cspellOutput |
        Where-Object { $_ -match 'Unknown word \((.+?)\)' } |
        ForEach-Object { $Matches[1] } |
        Sort-Object -Unique -CaseSensitive:$false)

    if ($unknownWords.Count -eq 0) {
        Write-Host "No unknown words found. cspell.json is up to date." -ForegroundColor Green
        exit 0
    }

    if (-not $ListOnly) {
        Write-Host "`nFound $($unknownWords.Count) unknown word(s):" -ForegroundColor Yellow
        $unknownWords | ForEach-Object { Write-Host "  - $_" }
    }
}

# ---------------------------------------------------------------------------
# 3. Load cspell.json
# ---------------------------------------------------------------------------
$cspell = Get-Content $cspellPath -Raw | ConvertFrom-Json

# Ensure words is a mutable list
$wordsSource = if ($cspell.words) { $cspell.words } else { @() }
$existingWords = [System.Collections.Generic.List[string]]$wordsSource

# -ListOnly: print the words that aren't in cspell.json yet, and stop.
if ($ListOnly) {
    $newWords = @($unknownWords | Where-Object { -not ($existingWords -icontains $_) })
    if ($newWords.Count -eq 0) {
        Write-Host 'Every unknown word is already in cspell.json.' -ForegroundColor Green
    } else {
        $newWords | ForEach-Object { Write-Output $_ }
    }
    exit 0
}

# ---------------------------------------------------------------------------
# 4. Prompt and add new words (-Word and -AutoAdd add without prompting)
# ---------------------------------------------------------------------------
$added = [System.Collections.Generic.List[string]]::new()

foreach ($word in $unknownWords) {
    # Skip if already in the list (case-insensitive)
    if ($existingWords -icontains $word) {
        Write-Host "  SKIP  '$word' (already in cspell.json)" -ForegroundColor DarkGray
        continue
    }

    if ($AutoAdd -or $Word) {
        $decision = 'y'
    } else {
        $decision = (Read-Host "`nAdd '$word' to cspell.json? [y/N]").Trim().ToLower()
    }

    if ($decision -eq 'y') {
        $existingWords.Add($word)
        $added.Add($word)
        Write-Host "  ADDED '$word'" -ForegroundColor Green
    } else {
        Write-Host "  SKIP  '$word'" -ForegroundColor DarkGray
    }
}

if ($added.Count -eq 0) {
    Write-Host "`nNo words were added." -ForegroundColor Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# 5. Sort and write back
# ---------------------------------------------------------------------------
$cspell.words = ($existingWords | Sort-Object -CaseSensitive:$false)

$json = $cspell | ConvertTo-Json -Depth 10 -Compress
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($cspellPath, $json, $utf8WithoutBom)

& node -e "const fs=require('fs');const p=process.argv[1];const data=JSON.parse(fs.readFileSync(p,'utf8'));fs.writeFileSync(p,JSON.stringify(data,null,2)+'\n');" $cspellPath
if ($LASTEXITCODE -ne 0) {
    throw "Failed to format cspell.json."
}

Write-Host "`nAdded $($added.Count) word(s) to cspell.json: $($added -join ', ')" -ForegroundColor Green
Write-Host "Words list is sorted alphabetically." -ForegroundColor Cyan
