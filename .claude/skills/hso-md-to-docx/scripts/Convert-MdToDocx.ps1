<#
.SYNOPSIS
    Convert a Markdown file to a Word .docx, rendering Mermaid diagrams to PNG along the way.

.DESCRIPTION
    Extracts every Mermaid block (both ```mermaid and ::: mermaid fence styles), renders each to
    PNG via mermaid-cli (mmdc), rewrites the block as an image reference, then converts the result
    to .docx with Pandoc.

    Runs under Windows PowerShell 5.1 and PowerShell 7. Requires Node.js + @mermaid-js/mermaid-cli
    and Pandoc on PATH. No authentication and no network calls beyond what mmdc does locally.

.PARAMETER SourceFile
    Path to the source .md file.

.PARAMETER OutputDocx
    Path to write the .docx to. Its folder must exist.

.PARAMETER KeepBuildDir
    Keep the temporary _docx_build folder instead of removing it. Useful when a diagram fails to
    render and you want the .mmd input that produced it.

.EXAMPLE
    .\Convert-MdToDocx.ps1 -SourceFile .\design.md -OutputDocx .\design.docx
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceFile,
    [Parameter(Mandatory)][string]$OutputDocx,
    [switch]$KeepBuildDir
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceFile)) { throw "Source file not found: $SourceFile" }
$SourceFile = (Resolve-Path -LiteralPath $SourceFile).Path
$sourceDir  = Split-Path $SourceFile -Parent

$outDir = Split-Path $OutputDocx -Parent
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { throw "Output folder does not exist: $outDir" }

# Fail early on a locked destination rather than after minutes of diagram rendering.
if (Test-Path -LiteralPath $OutputDocx) {
    try {
        $fs = [System.IO.File]::Open($OutputDocx, 'Open', 'ReadWrite', 'None')
        $fs.Dispose()
    } catch {
        throw "Output file is locked (open in Word?): $OutputDocx"
    }
}

# Refresh PATH so tools installed moments ago in another shell are visible.
$machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path    = "$machinePath;$userPath"

# pandoc is always required. mmdc is only required if the document actually contains a diagram,
# so a plain-markdown conversion does not force a Node toolchain onto the machine.
if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
    throw "pandoc not found on PATH. Install: winget install --id JohnMacFarlane.Pandoc --accept-source-agreements --accept-package-agreements"
}
$script:MmdcChecked = $false
function Assert-Mmdc {
    if ($script:MmdcChecked) { return }
    if (-not (Get-Command mmdc -ErrorAction SilentlyContinue)) {
        throw "This document contains Mermaid diagrams but mmdc (mermaid-cli) is not on PATH. Install: npm install -g @mermaid-js/mermaid-cli"
    }
    $script:MmdcChecked = $true
}

$buildDir   = Join-Path $sourceDir '_docx_build'
$diagramDir = Join-Path $buildDir 'diagrams'
$tempMd     = Join-Path $buildDir 'temp.md'

if (Test-Path -LiteralPath $buildDir) { Remove-Item -LiteralPath $buildDir -Recurse -Force }
New-Item -ItemType Directory -Path $diagramDir -Force | Out-Null

# UTF-8 without BOM on both hosts. Set-Content -Encoding UTF8 writes a BOM under Windows
# PowerShell 5.1 but not under 7 (ADR 0058 - syntax parity is not behavioral parity); a BOM on a
# .mmd file makes mmdc fail to parse the first directive, so pin the encoding explicitly.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$lines        = Get-Content -LiteralPath $SourceFile -Encoding UTF8
$outputLines  = New-Object System.Collections.Generic.List[string]
$failed       = New-Object System.Collections.Generic.List[string]
$inMermaid    = $false
$mermaidBlock = New-Object System.Collections.Generic.List[string]
$diagramIndex = 0

foreach ($line in $lines) {
    if (-not $inMermaid -and ($line -match '^\s*:::\s*mermaid\s*$' -or $line -match '^\s*```+\s*mermaid\s*$')) {
        Assert-Mmdc
        $inMermaid = $true
        $mermaidBlock.Clear()
        continue
    }

    if ($inMermaid -and ($line -match '^\s*:::\s*$' -or $line -match '^\s*```+\s*$')) {
        $inMermaid = $false
        $diagramIndex++

        $mmdFile = Join-Path $diagramDir "diagram-$diagramIndex.mmd"
        $pngFile = Join-Path $diagramDir "diagram-$diagramIndex.png"
        [System.IO.File]::WriteAllLines($mmdFile, $mermaidBlock, $utf8NoBom)

        Write-Host "Rendering diagram $diagramIndex..."
        $mmdcOutput = & mmdc -i $mmdFile -o $pngFile -b white -w 1600 -s 2 2>&1
        $mmdcExit   = $LASTEXITCODE

        if ((Test-Path -LiteralPath $pngFile) -and $mmdcExit -eq 0) {
            Write-Host "  -> diagram-$diagramIndex.png"
            $outputLines.Add("![Diagram $diagramIndex](_docx_build/diagrams/diagram-$diagramIndex.png)")
        } else {
            # Keep the source block in the document rather than silently dropping content.
            Write-Warning "  -> diagram $diagramIndex failed to render (mmdc exit $mmdcExit)"
            if ($mmdcOutput) { Write-Verbose ($mmdcOutput | Out-String) }
            $failed.Add("diagram-$diagramIndex")
            $outputLines.Add('```')
            foreach ($m in $mermaidBlock) { $outputLines.Add($m) }
            $outputLines.Add('```')
        }
        continue
    }

    if ($inMermaid) { $mermaidBlock.Add($line) } else { $outputLines.Add($line) }
}

if ($inMermaid) {
    throw "Unterminated mermaid block starting at diagram $($diagramIndex + 1) - the fence was never closed."
}

[System.IO.File]::WriteAllLines($tempMd, $outputLines, $utf8NoBom)
Write-Host "$diagramIndex diagram(s) processed."

Write-Host 'Generating Word document...'
& pandoc $tempMd -o $OutputDocx --resource-path=$sourceDir
$pandocExit = $LASTEXITCODE

# The original swallowed this: a native exe returning non-zero does not trip
# $ErrorActionPreference, so a failed pandoc still printed "Created:" and cleaned up the evidence.
if ($pandocExit -ne 0 -or -not (Test-Path -LiteralPath $OutputDocx)) {
    Write-Host "Build folder kept for diagnosis: $buildDir"
    throw "pandoc failed (exit $pandocExit). No document was produced."
}

Write-Host "Created: $OutputDocx"

if ($failed.Count) {
    Write-Warning "$($failed.Count) diagram(s) failed and were left as code blocks: $($failed -join ', ')"
    Write-Host "Build folder kept so the failing .mmd input can be inspected: $buildDir"
} elseif (-not $KeepBuildDir) {
    Remove-Item -LiteralPath $buildDir -Recurse -Force
}
