[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$resolvedInput = (Resolve-Path -LiteralPath $Path).Path
if ([System.IO.Path]::GetExtension($resolvedInput).ToLowerInvariant() -ne '.pdf') {
    throw "Only .pdf files are supported: $resolvedInput"
}

$pythonCommand = Get-Command py, python -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $pythonCommand) {
    throw 'Python is required for PDF text extraction but was not found on PATH.'
}

$pythonExe = $pythonCommand.Source
$pythonPrefixArgs = @()
if ($pythonCommand.Name -eq 'py') {
    $pythonPrefixArgs = @('-3')
}

$tempScript = Join-Path ([System.IO.Path]::GetTempPath()) ("extract-pdf-text-" + [System.Guid]::NewGuid().ToString('N') + '.py')

$pythonSource = @'
from pathlib import Path
import sys

try:
    from pypdf import PdfReader
except ModuleNotFoundError:
    raise SystemExit(7)

pdf_path = Path(sys.argv[1])
output_path = Path(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else None
reader = PdfReader(str(pdf_path))
text = "\n\n".join((page.extract_text() or "") for page in reader.pages)

if output_path:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(text, encoding="utf-8")
else:
    sys.stdout.write(text)
'@

Set-Content -LiteralPath $tempScript -Value $pythonSource -Encoding UTF8

try {
    & $pythonExe @pythonPrefixArgs $tempScript $resolvedInput $OutputPath 2>$null
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 7) {
        & $pythonExe @pythonPrefixArgs -m pip install pypdf | Out-Null
        & $pythonExe @pythonPrefixArgs $tempScript $resolvedInput $OutputPath
        $exitCode = $LASTEXITCODE
    }

    if ($exitCode -ne 0) {
        throw "PDF text extraction failed with exit code $exitCode."
    }

    if ($OutputPath) {
        Write-Output (Resolve-Path -LiteralPath $OutputPath).Path
    }
}
finally {
    if (Test-Path -LiteralPath $tempScript) {
        Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
    }
}