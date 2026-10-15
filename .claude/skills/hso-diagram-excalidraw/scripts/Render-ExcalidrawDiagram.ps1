<#
.SYNOPSIS
    Render an Excalidraw JSON file to SVG using the bundled Node renderer.

.DESCRIPTION
    Wraps render-excalidraw.mjs which uses the official @excalidraw/utils
    package with a jsdom DOM polyfill to produce faithful excalidraw SVGs
    without any browser or Electron dependency.

    Requires Node.js 18+ and a one-time `npm install` in this scripts folder
    (the script errors with a helpful message if node_modules is missing).

.PARAMETER InputPath
    Path to a .excalidraw file.

.PARAMETER OutputPath
    Optional. Defaults to the input path with .svg extension.

.EXAMPLE
    .\Render-ExcalidrawDiagram.ps1 -InputPath ..\templates\sketch-architecture.excalidraw
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot

$nodeModules = Join-Path $scriptDir 'node_modules'
if (-not (Test-Path $nodeModules)) {
    throw "Missing dependencies. Run: cd `"$scriptDir`"; npm install"
}

$renderer = Join-Path $scriptDir 'render-excalidraw.mjs'
$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path

$nodeArgs = @($renderer, $resolvedInput)
if ($OutputPath) {
    $nodeArgs += $OutputPath
}

Write-Host "Rendering: $resolvedInput" -ForegroundColor Cyan
& node @nodeArgs
if ($LASTEXITCODE -ne 0) {
    throw "node renderer failed with exit code $LASTEXITCODE"
}
