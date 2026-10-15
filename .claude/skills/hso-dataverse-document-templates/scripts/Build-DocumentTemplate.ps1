<#
.SYNOPSIS
    Build a Dataverse document template (.docx/.xlsx) by overlaying a new body
    onto a known-good base template, preserving the base's customXml plumbing.

.DESCRIPTION
    The robust way to build a native D365 document template is to start from a
    template D365 itself produced and can already generate (e.g. an OOB
    "Case Summary" template pulled via the Web API), and replace ONLY the body
    part — inheriting the base's correct datastore itemProps (dual schemaRefs),
    customXml schema, styles, and relationships.

    This script extracts the base, overlays one or more part files, validates
    XML well-formedness, and repackages a valid OOXML zip (entries in order,
    forward-slash names, [Content_Types].xml first).

.PARAMETER BaseTemplate
    Path to the known-good base .docx/.xlsx (its customXml plumbing is preserved).

.PARAMETER BodyXml
    Path to the replacement body part (for Word: your new word/document.xml).

.PARAMETER PartName
    Package-relative path of the part BodyXml replaces. Default: word/document.xml.

.PARAMETER OutFile
    Path to write the resulting template file.

.PARAMETER ExtraOverlays
    Optional hashtable of additional overlays: @{ 'package/relative/part.xml' = 'C:\local\file.xml' }.

.EXAMPLE
    .\Build-DocumentTemplate.ps1 -BaseTemplate .\oob_case_summary.docx -BodyXml .\my_document.xml -OutFile .\MyTemplate.docx
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaseTemplate,
    [Parameter(Mandatory)][string]$BodyXml,
    [string]$PartName = "word/document.xml",
    [Parameter(Mandatory)][string]$OutFile,
    [hashtable]$ExtraOverlays
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Test-Wellformed([string]$path) {
    try { [xml]$null = Get-Content -LiteralPath $path -Raw -ErrorAction Stop; return $true }
    catch { Write-Error ("Not well-formed XML: {0} -> {1}" -f $path, $_.Exception.Message); return $false }
}

if (-not (Test-Path -LiteralPath $BaseTemplate)) { throw "BaseTemplate not found: $BaseTemplate" }
if (-not (Test-Path -LiteralPath $BodyXml))      { throw "BodyXml not found: $BodyXml" }
if (-not (Test-Wellformed $BodyXml)) { throw "Aborting: $BodyXml is not well-formed." }

# Extract base to a temp working dir
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("doctpl_" + [System.IO.Path]::GetRandomFileName())
[System.IO.Compression.ZipFile]::ExtractToDirectory($BaseTemplate, $work)

try {
    $bs = [char]92; $fwd = [char]47

    # Build the overlay map (package-relative part name -> source file)
    $overlays = @{}
    $overlays[$PartName] = (Resolve-Path -LiteralPath $BodyXml).Path
    if ($ExtraOverlays) { foreach ($k in $ExtraOverlays.Keys) { $overlays[$k] = (Resolve-Path -LiteralPath $ExtraOverlays[$k]).Path } }

    foreach ($part in $overlays.Keys) {
        $dest = Join-Path $work ($part.Replace($fwd, $bs))
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
        Copy-Item -LiteralPath $overlays[$part] -Destination $dest -Force
        if (-not (Test-Wellformed $dest)) { throw "Overlay produced non-well-formed part: $part" }
        Write-Output "overlaid: $part"
    }

    # Enumerate all parts, content-types first
    $all = Get-ChildItem -Recurse -File -LiteralPath $work | ForEach-Object {
        $_.FullName.Substring($work.Length + 1).Replace($bs, $fwd)
    }
    $ordered = @($all | Where-Object { $_ -eq '[Content_Types].xml' }) +
               @($all | Where-Object { $_ -ne '[Content_Types].xml' })

    if (Test-Path -LiteralPath $OutFile) { [System.IO.File]::Delete((Resolve-Path -LiteralPath $OutFile).Path) }
    $fs  = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::CreateNew)
    $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
    foreach ($e in $ordered) {
        $full  = Join-Path $work ($e.Replace($fwd, $bs))
        $entry = $zip.CreateEntry($e, [System.IO.Compression.CompressionLevel]::Optimal)
        $st = $entry.Open()
        $bytes = [System.IO.File]::ReadAllBytes($full)
        $st.Write($bytes, 0, $bytes.Length); $st.Close()
    }
    $zip.Dispose(); $fs.Close()

    Write-Output ("OK: {0} ({1} parts, {2} bytes)" -f $OutFile, $ordered.Count, (Get-Item -LiteralPath $OutFile).Length)
}
finally {
    Remove-Item -Recurse -Force -LiteralPath $work -ErrorAction SilentlyContinue
}
