# narrate-pptx.ps1
# Build a narrated MP4 from an existing .pptx + cached per-slide WAVs.
# Uses PowerPoint COM automation to export each slide as a pixel-perfect PNG
# (identical to what PowerPoint shows when you open the file). Then FFmpeg-
# stitches PNG + audio per slide and concatenates into one MP4.
#
# Why this instead of re-rendering through Marp:
#   - The .pptx is the canonical visual artifact (already correctly themed)
#   - Avoids any Marp theme-resolution risk
#   - No re-running of TTS -- WAVs from a prior narrate-deck.py run are reused
#
# Usage:
#   .\narrate-pptx.ps1 -DeckBase 08-industry-primer
#   .\narrate-pptx.ps1 -DeckBase 08-industry-primer -OutMp4 D:\out.mp4
#
# Prereqs:
#   - PowerPoint (Microsoft 365 / Office) installed
#   - FFmpeg on PATH
#   - Per-slide WAVs already generated at _narrate-stage\<base>\wav\slide-NNN.wav
#requires -Version 5.1

param(
    [Parameter(Mandatory=$true)]
    [string]$DeckBase,
    [Parameter(Mandatory=$true)]
    [string]$RepoRoot,
    [string]$OutMp4
)

$ErrorActionPreference = 'Stop'

$pptx     = Join-Path $RepoRoot "$DeckBase.pptx"
$wavDir   = Join-Path $RepoRoot "_narrate-stage\$DeckBase\wav"
$stageDir = Join-Path $RepoRoot "_narrate-stage\$DeckBase"
$pngDir   = Join-Path $stageDir 'png-from-pptx'
$segDir   = Join-Path $stageDir 'segments-from-pptx'

if (-not (Test-Path $pptx))   { throw "PPTX not found: $pptx" }
if (-not (Test-Path $wavDir)) { throw "WAVs not found: $wavDir -- run narrate-deck.py first to generate audio" }

New-Item -ItemType Directory -Path $pngDir -Force | Out-Null
New-Item -ItemType Directory -Path $segDir -Force | Out-Null

if (-not $OutMp4) {
    $OutMp4 = Join-Path $RepoRoot "$DeckBase.mp4"
}

# --- PNG export via PowerPoint COM -----------------------------------------
Write-Host "==> Exporting slides from $pptx via PowerPoint COM..." -ForegroundColor Cyan

$ppt = $null
$pres = $null
try {
    $ppt = New-Object -ComObject PowerPoint.Application
    # Don't make the window visible; some Office versions require msoCTrue (-1) here
    $pres = $ppt.Presentations.Open($pptx, $true, $false, $false)  # ReadOnly, Untitled, WithWindow=false

    $slideCount = $pres.Slides.Count
    Write-Host "  $slideCount slides found in pptx"

    foreach ($slide in $pres.Slides) {
        $idx = $slide.SlideIndex
        $out = Join-Path $pngDir ("slide.{0:D3}.png" -f $idx)
        # 1920x1080 for 16:9 decks
        $slide.Export($out, "PNG", 1920, 1080) | Out-Null
        Write-Host ("  exported slide {0,3} -> {1}" -f $idx, (Split-Path $out -Leaf))
    }
}
finally {
    if ($pres) { $pres.Close() | Out-Null; [System.Runtime.InteropServices.Marshal]::ReleaseComObject($pres) | Out-Null }
    if ($ppt)  { $ppt.Quit()    | Out-Null; [System.Runtime.InteropServices.Marshal]::ReleaseComObject($ppt)  | Out-Null }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
}

# --- FFmpeg: PNG + WAV -> MP4 per slide -------------------------------------
Write-Host ""
Write-Host "==> Building per-slide MP4 segments..." -ForegroundColor Cyan

$pngs = Get-ChildItem $pngDir -Filter 'slide.*.png' | Sort-Object Name
$concatLines = @()
foreach ($png in $pngs) {
    $num = ($png.BaseName -replace 'slide\.', '')   # "001"
    $wav = Join-Path $wavDir ("slide-$num.wav")
    $seg = Join-Path $segDir ("seg-$num.mp4")

    if (-not (Test-Path $wav)) {
        Write-Host "  !  no WAV for slide $num -- using 2s of silence" -ForegroundColor Yellow
        $wavSilent = Join-Path $segDir ("silent-$num.wav")
        ffmpeg -y -loglevel error -f lavfi -i "anullsrc=channel_layout=mono:sample_rate=24000" -t 2 $wavSilent | Out-Null
        $wav = $wavSilent
    }

    if (-not (Test-Path $seg)) {
        & ffmpeg -y -loglevel error `
            -loop 1 -i $png.FullName `
            -i $wav `
            -c:v libx264 -tune stillimage -pix_fmt yuv420p `
            -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" `
            -c:a aac -b:a 192k `
            -shortest `
            $seg
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg segment build failed for slide $num" }
    }
    $concatLines += ("file '{0}'" -f $seg.Replace('\','/'))
    Write-Host ("  seg-{0}.mp4" -f $num)
}

# --- Concat ----------------------------------------------------------------
Write-Host ""
Write-Host "==> Concatenating $($concatLines.Count) segments..." -ForegroundColor Cyan

$concatList = Join-Path $env:TEMP ("narrate-$DeckBase-concat.txt")
$concatLines | Set-Content $concatList -Encoding ASCII

# Re-encode during concat instead of -c copy. Each per-slide segment has
# AAC priming samples (~21ms of encoder delay); with copy they accumulate
# across boundaries and audio drifts ahead of video. Re-encoding rebuilds
# one continuous audio + video timeline so AV stays in sync at every slide.
& ffmpeg -y -loglevel error -f concat -safe 0 -i $concatList `
    -c:v libx264 -tune stillimage -pix_fmt yuv420p -preset veryfast -crf 22 `
    -c:a aac -b:a 192k `
    -movflags +faststart `
    $OutMp4
if ($LASTEXITCODE -ne 0) { throw "ffmpeg concat failed" }

$size = [math]::Round((Get-Item $OutMp4).Length / 1MB, 1)
$dur = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $OutMp4
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "ok $OutMp4" -ForegroundColor Green
Write-Host "  size      : $size MB" -ForegroundColor Green
Write-Host "  duration  : $([int]$dur)s ($([math]::Round($dur/60,1)) min)" -ForegroundColor Green
Write-Host "  slides    : $($concatLines.Count)" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
