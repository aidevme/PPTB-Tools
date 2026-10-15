<#
.SYNOPSIS
    Run a Plotly Python diagram script. Outputs SVG + PNG next to the source.

.DESCRIPTION
    Wrapper around `python <input.py>` matching the interface of the sibling
    Render-ExcalidrawDiagram.ps1 / Render-DrawioDiagram.ps1 scripts. Each
    template script is self-contained and writes its own output paths — this
    wrapper just shells out to the configured Python interpreter.

    First-time setup:
        python -m pip install -r .claude/skills/hso-diagram-plotly/scripts/requirements.txt

.PARAMETER InputPath
    Path to the .py source script (typically copied from templates/ into the
    engagement's diagram-source folder).

.PARAMETER PythonPath
    Optional. Path to the Python interpreter. Defaults to 'python' on PATH.

.EXAMPLE
    .\Render-PlotlyDiagram.ps1 -InputPath ..\..\..\..\agent\work\deliverables\diagrams\_generators\example_sankey.py
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$PythonPath = 'python'
)

$ErrorActionPreference = 'Stop'
$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path

Write-Host "Rendering: $resolvedInput" -ForegroundColor Cyan
& $PythonPath $resolvedInput
if ($LASTEXITCODE -ne 0) {
    throw "Python script failed with exit code $LASTEXITCODE"
}
