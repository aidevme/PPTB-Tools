# narrate-all.ps1
# Render an MP4 narration video for every deck in the pack that has:
#   - <base>.md          (Marp source)
#   - <base>.pptx        (rendered PowerPoint -- slide images)
#   - <base>.narration.json (per-slide spoken narration)
#
# Each deck is processed end-to-end: synth WAVs from JSON -> export PPTX
# slides as PNG via COM -> ffmpeg per-slide segments -> concat to MP4 in
# the repo root.
#
# Idempotent: cached WAVs are skipped on re-run. Use -Force to wipe cache.
#requires -Version 5.1

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoRoot,
    [string]$Voice,                               # if set, every deck uses this voice (overrides randomization)
    [string[]]$Voices = @("af_heart", "am_michael", "bf_emma", "bm_george"),
    [string[]]$Only,                              # restrict to specific deck bases
    [int]$RandomSeed = 0,                         # change to get a different deterministic distribution
    [string]$VoiceMapFile,                        # optional JSON: { "01-executive-overview": "bf_emma", ... }
    [switch]$Force,                               # wipe per-deck cache before render
    [string]$PyExe = "python"
)

# Voice assignment -- the pack should feel like a small team narrated it, not one
# robot. Default behavior: deterministically randomize across $Voices per deck so
# the EA deck in project X and project Y don't always sound identical.
#
# Priority order: -Voice override -> VoiceMapFile JSON -> hash-based pseudo-random.

$VoiceMap = @{}
if ($VoiceMapFile -and (Test-Path $VoiceMapFile)) {
    $loaded = Get-Content $VoiceMapFile -Raw | ConvertFrom-Json
    foreach ($prop in $loaded.PSObject.Properties) { $VoiceMap[$prop.Name] = $prop.Value }
    Write-Host "Loaded explicit voice map from $VoiceMapFile ($($VoiceMap.Count) entries)" -ForegroundColor DarkGray
}

function Get-VoiceForDeck {
    param([string]$DeckBase)
    if ($Voice) { return $Voice }
    if ($VoiceMap.ContainsKey($DeckBase)) { return $VoiceMap[$DeckBase] }
    # Hash-based deterministic random -- stable across runs for the same deck+seed,
    # but distributes evenly across $Voices because we mod the hash by voice count.
    $bytes = [System.Text.Encoding]::UTF8.GetBytes("$DeckBase`:seed:$RandomSeed")
    $hash  = [System.Security.Cryptography.MD5]::Create().ComputeHash($bytes)
    $idx   = ([System.BitConverter]::ToUInt32($hash, 0)) % $Voices.Count
    return $Voices[$idx]
}

$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING  = "utf-8"
Set-Location $RepoRoot

# Discover candidate decks: every .md that has a sibling .narration.json + .pptx
$decks = Get-ChildItem -Path $RepoRoot -Filter "*.md" -File |
    Where-Object {
        $base = $_.BaseName
        (Test-Path (Join-Path $RepoRoot "$base.narration.json")) -and
        (Test-Path (Join-Path $RepoRoot "$base.pptx"))
    } |
    Sort-Object Name

if ($Only) {
    $decks = $decks | Where-Object { $Only -contains $_.BaseName }
}

if (-not $decks) {
    Write-Host "No decks found with both .narration.json and .pptx. Nothing to do." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host " narrate-all -- $($decks.Count) deck(s) to render" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
$decks | ForEach-Object { Write-Host ("  * {0}" -f $_.BaseName) -ForegroundColor Gray }
Write-Host ""


$totalStart = Get-Date
foreach ($deck in $decks) {
    $base = $deck.BaseName
    $deckStart = Get-Date

    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host " $base" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green

    $stage = Join-Path $RepoRoot "_narrate-stage\$base"
    if ($Force -and (Test-Path $stage)) {
        Write-Host "[force] wiping $stage" -ForegroundColor Yellow
        Remove-Item -Recurse -Force $stage
    }

    $repoMp4 = Join-Path $RepoRoot "$base.mp4"
    Remove-Item -Force $repoMp4 -ErrorAction SilentlyContinue

    # Step 1 -- synth audio from .narration.json (idempotent; reuses cached WAVs)
    $deckVoice = Get-VoiceForDeck $base
    Write-Host "==> Synthesizing audio (voice: $deckVoice) ..." -ForegroundColor Cyan
    & $PyExe "$RepoRoot\scripts\narrate-deck.py" "$base.md" $deckVoice $repoMp4 2>&1 |
        ForEach-Object {
            # Pass through but compactly; full log is captured in the task file
            if ($_ -match "(override|theme|\[\d{2}/\d{2}\]|wrote |chunks|ok)") { Write-Host $_ -ForegroundColor DarkGray }
        }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  x narrate-deck.py failed for $base -- skipping" -ForegroundColor Red
        continue
    }

    # Step 2 -- re-build MP4 from .pptx slide images (overrides narrate-deck.py's MP4)
    Write-Host "==> Reassembling MP4 with PPTX slide images ..." -ForegroundColor Cyan
    Remove-Item -Force $repoMp4 -ErrorAction SilentlyContinue
    & "$RepoRoot\scripts\narrate-pptx.ps1" -DeckBase $base -RepoRoot $RepoRoot -OutMp4 $repoMp4 2>&1 |
        ForEach-Object {
            if ($_ -match "(exported|seg-|Concatenating|wrote|duration)") { Write-Host $_ -ForegroundColor DarkGray }
        }
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $repoMp4)) {
        Write-Host "  x narrate-pptx.ps1 failed for $base" -ForegroundColor Red
        continue
    }

    $sz  = [math]::Round((Get-Item $repoMp4).Length / 1MB, 1)
    $dur = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $repoMp4
    $deckMin = [math]::Round(((Get-Date) - $deckStart).TotalMinutes, 1)
    Write-Host ""
    Write-Host ("  ok $base.mp4 (voice: $deckVoice) -- {0} MB, {1}s of audio, took {2} min wall" -f $sz, [math]::Round($dur, 0), $deckMin) -ForegroundColor Green
}

$totalMin = [math]::Round(((Get-Date) - $totalStart).TotalMinutes, 1)
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host " ok Batch complete in $totalMin minutes" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
