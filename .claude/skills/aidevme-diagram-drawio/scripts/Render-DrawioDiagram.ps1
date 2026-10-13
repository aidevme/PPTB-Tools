<#
.SYNOPSIS
    Render a draw.io XML file to SVG/PNG/PDF using the draw.io desktop CLI.

.DESCRIPTION
    Wraps "draw.io.exe -x" with sensible HSO defaults (SVG, embedded fonts,
    cropped, light theme). Input can be a single .drawio file or a folder.

    Requires draw.io Desktop installed. Default install location:
        C:\Program Files\draw.io\draw.io.exe

.PARAMETER InputPath
    Path to a .drawio file or a folder of .drawio files.

.PARAMETER Format
    Output format: svg (default), png, pdf, jpg.

.PARAMETER OutputPath
    Optional. Defaults to the input path with the new extension.

.PARAMETER Transparent
    PNG only. Produces a transparent background.

.PARAMETER Width
    Fit output to this width in pixels (preserves aspect ratio).

.PARAMETER Height
    Fit output to this height in pixels (preserves aspect ratio).

.PARAMETER Scale
    Scale factor (default 1.0).

.PARAMETER AllPages
    PDF only. Export all pages.

.PARAMETER DrawioExe
    Override path to draw.io.exe.

.EXAMPLE
    .\Render-DrawioDiagram.ps1 -InputPath .\diagrams\erd.drawio
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [ValidateSet('svg', 'png', 'pdf', 'jpg')]
    [string]$Format = 'svg',

    [string]$OutputPath,

    [switch]$Transparent,

    [int]$Width,

    [int]$Height,

    [double]$Scale = 1.0,

    [switch]$AllPages,

    [switch]$EmbedFonts,

    [string]$DrawioExe = 'C:\Program Files\draw.io\draw.io.exe'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $DrawioExe)) {
    throw "draw.io.exe not found at: $DrawioExe. Install draw.io Desktop from https://github.com/jgraph/drawio-desktop/releases or pass -DrawioExe."
}

$resolved = Resolve-Path -LiteralPath $InputPath -ErrorAction Stop
$inputFull = $resolved.Path

if (-not $OutputPath) {
    if (Test-Path $inputFull -PathType Container) {
        $OutputPath = $inputFull
    }
    else {
        $OutputPath = [System.IO.Path]::ChangeExtension($inputFull, ".$Format")
    }
}

$args = @(
    '--export',
    '--format', $Format,
    '--output', $OutputPath,
    '--border', '10',
    '--scale', ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0}', $Scale))
)

if ($Format -eq 'svg') {
    # Fonts are NOT embedded by default — keeps SVG small (~15KB vs ~400KB) and
    # Segoe UI falls back gracefully. Pass -EmbedFonts to embed for offline/print use.
    $embed = if ($EmbedFonts) { 'true' } else { 'false' }
    $args += @('--embed-svg-fonts', $embed)
}

if ($Transparent -and $Format -eq 'png') {
    $args += '--transparent'
}

if ($Width) { $args += @('--width', "$Width") }
if ($Height) { $args += @('--height', "$Height") }
if ($AllPages -and $Format -eq 'pdf') { $args += '--all-pages' }
if ($Format -eq 'pdf') { $args += '--crop' }

$args += $inputFull

Write-Host "Rendering: $inputFull -> $OutputPath ($Format)" -ForegroundColor Cyan
Write-Verbose ("Command: `"$DrawioExe`" " + ($args -join ' '))

# Capture pre-existing mtime (so we can tell whether this run actually wrote the file)
$preMtime = if (Test-Path $OutputPath) { (Get-Item $OutputPath).LastWriteTime } else { [DateTime]::MinValue }

& $DrawioExe @args | Out-Null
# NOTE: draw.io.exe is an Electron GUI app on Windows and frequently detaches from
# the console, leaving $LASTEXITCODE empty even on success. We therefore verify
# success by checking that the output file exists AND was updated by this run.

Start-Sleep -Milliseconds 500  # allow filesystem flush

if (-not (Test-Path $OutputPath)) {
    throw "draw.io export failed: output file not produced at $OutputPath"
}

$item = Get-Item $OutputPath
if ($item.LastWriteTime -le $preMtime) {
    throw "draw.io export failed: output file at $OutputPath was not updated (stale from $($item.LastWriteTime))"
}

Write-Host "OK  $OutputPath  ($($item.Length) bytes)" -ForegroundColor Green
