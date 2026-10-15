<#
.SYNOPSIS
    Render a reference architecture SVG to PNG (2400 px wide) via the bundled Node renderer.

.DESCRIPTION
    Wraps render-svg.mjs which uses sharp to rasterize SVG -> PNG at 2400 px
    width and density 200. Mirrors the interface of Render-ExcalidrawDiagram.ps1
    in the hso-diagram-excalidraw skill.

    Requires Node.js 18+ and a one-time `npm install` in this scripts folder
    (the script errors with a helpful message if node_modules is missing).

.PARAMETER InputPath
    Path to a .svg file.

.PARAMETER OutputPath
    Optional. Defaults to the input path with .png extension.

.EXAMPLE
    .\Render-ReferenceArchitecture.ps1 -InputPath ..\..\..\..\..\agent\work\deliverables\diagrams\reference_architecture.svg
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

$renderer = Join-Path $scriptDir 'render-svg.mjs'
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
