<#
.SYNOPSIS
    Lists new screenshots in a folder within a date range, with best-guess
    capture time and a cheap dedupe key, for the hso-wiki-ingest-screenshots skill.

.DESCRIPTION
    Enumerates image files in the given folder, determines each file's capture
    time (filename-encoded datetime first, then EXIF DateTimeOriginal for JPEGs,
    then file LastWriteTime), filters to those at or after the range start, and
    emits a JSON array. Each item carries a dedupe key (name|size|captureTime)
    computed from metadata only -- no file bytes are read, so cloud-only OneDrive
    files are NOT hydrated/downloaded. When -ManifestPath points at a processed-
    manifest JSON, files whose key already appears there are skipped (idempotent
    re-runs). Pass -ContentHash to also compute a SHA-256 (reads bytes; only do
    that on local, non-OneDrive folders).

    Output is metadata only. The vision read, Krisp correlation, and customer
    classification are done by Claude, not this script.

.PARAMETER Path
    The screenshots source folder (read from CLAUDE.local.md).

.PARAMETER Since
    Range start as YYYY-MM-DD. Capture times at or after this are included.

.PARAMETER Days
    Alternative to -Since: include the last N days.

.PARAMETER All
    Include every image regardless of date.

.PARAMETER Recurse
    Search subfolders. Default is the top-level folder only.

.PARAMETER ManifestPath
    Optional path to the processed-manifest JSON. Keys listed there are skipped.

.PARAMETER ContentHash
    Also compute a SHA-256 content hash per file. Reads file bytes, so avoid it on
    cloud-backed (OneDrive) folders where it forces downloads. Off by default.

.EXAMPLE
    .\List-Screenshots.ps1 -Path "C:\Users\Me\OneDrive - HSO\Pictures\Screenshots" -Since "2026-06-01"

.EXAMPLE
    .\List-Screenshots.ps1 -Path "<folder>" -Days 7 -ManifestPath "agent/raw/screenshots/.processed-manifest.json"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$Since,

    [int]$Days = 0,

    [switch]$All,

    [switch]$Recurse,

    [string]$ManifestPath,

    [switch]$ContentHash
)

$ErrorActionPreference = 'Stop'

function New-DateOrNull {
    param($y, $mo, $d, $h, $mi, $s)
    try {
        return [datetime]::new([int]$y, [int]$mo, [int]$d, [int]$h, [int]$mi, [int]$s)
    } catch {
        return $null
    }
}

function Get-ExifDateTaken {
    param([string]$FullPath)
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $img = [System.Drawing.Image]::FromFile($FullPath)
        try {
            $prop = $img.GetPropertyItem(36867)  # 0x9003 DateTimeOriginal
            $raw = [System.Text.Encoding]::ASCII.GetString($prop.Value)
            $raw = $raw.Trim([char]0).Trim()
            return [datetime]::ParseExact($raw, 'yyyy:MM:dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
        } finally {
            $img.Dispose()
        }
    } catch {
        return $null
    }
}

function Get-CaptureInfo {
    param([System.IO.FileInfo]$File)

    $name = $File.Name

    # Pattern 1: yyyy-MM-dd <sep> HH mm ss  (e.g. "Screenshot 2026-06-18 145955")
    $m = [regex]::Match($name, '(\d{4})-(\d{2})-(\d{2})[ _T\-]+(\d{2})[.:_\-]?(\d{2})[.:_\-]?(\d{2})?')
    if ($m.Success) {
        $sec = if ($m.Groups[6].Value) { $m.Groups[6].Value } else { 0 }
        $dt = New-DateOrNull $m.Groups[1].Value $m.Groups[2].Value $m.Groups[3].Value $m.Groups[4].Value $m.Groups[5].Value $sec
        if ($dt) { return @{ Time = $dt; Source = 'filename' } }
    }

    # Pattern 2: yyyyMMdd <sep> HHmmss  (e.g. "20260618_145955")
    $m = [regex]::Match($name, '(\d{4})(\d{2})(\d{2})[ _T\-]+(\d{2})(\d{2})(\d{2})')
    if ($m.Success) {
        $dt = New-DateOrNull $m.Groups[1].Value $m.Groups[2].Value $m.Groups[3].Value $m.Groups[4].Value $m.Groups[5].Value $m.Groups[6].Value
        if ($dt) { return @{ Time = $dt; Source = 'filename' } }
    }

    # Pattern 3: date only yyyy-MM-dd -> midnight
    $m = [regex]::Match($name, '(\d{4})-(\d{2})-(\d{2})')
    if ($m.Success) {
        $dt = New-DateOrNull $m.Groups[1].Value $m.Groups[2].Value $m.Groups[3].Value 0 0 0
        if ($dt) { return @{ Time = $dt; Source = 'filename' } }
    }

    # EXIF best-effort, JPEG only (screenshots rarely carry EXIF)
    $ext = $File.Extension.ToLower()
    if ($ext -eq '.jpg' -or $ext -eq '.jpeg') {
        $exif = Get-ExifDateTaken $File.FullName
        if ($exif) { return @{ Time = $exif; Source = 'exif' } }
    }

    return @{ Time = $File.LastWriteTime; Source = 'mtime' }
}

# --- Resolve range start ---------------------------------------------------
if ($All) {
    $start = [datetime]::MinValue
} elseif ($Since) {
    try {
        $start = [datetime]::Parse($Since, [System.Globalization.CultureInfo]::InvariantCulture)
    } catch {
        Write-Error "Could not parse -Since '$Since'. Use YYYY-MM-DD."
        exit 1
    }
} elseif ($Days -gt 0) {
    $start = (Get-Date).Date.AddDays(-$Days)
} else {
    $start = (Get-Date).Date.AddDays(-7)  # default window
}

# --- Resolve folder --------------------------------------------------------
$resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $Path"
    exit 1
}

$exts = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp')

$gciParams = @{
    LiteralPath = $resolved.Path
    File        = $true
    Recurse     = $Recurse.IsPresent
}
$files = Get-ChildItem @gciParams -ErrorAction SilentlyContinue |
    Where-Object { ($exts -contains $_.Extension.ToLower()) -and ($_.Name -notlike '~$*') }

# --- Load processed manifest (hashes to skip) ------------------------------
$processed = @{}
if ($ManifestPath -and (Test-Path -LiteralPath $ManifestPath)) {
    try {
        $txt = Get-Content -LiteralPath $ManifestPath -Raw -ErrorAction Stop
        if ($txt -and $txt.Trim()) {
            $m = $txt | ConvertFrom-Json
            foreach ($e in @($m)) {
                if ($e.key) { $processed[[string]$e.key] = $true }
            }
        }
    } catch {
        # Unreadable manifest: treat as empty rather than failing the run.
    }
}

# --- Build results ---------------------------------------------------------
$results = New-Object System.Collections.Generic.List[object]
foreach ($f in $files) {
    $info = Get-CaptureInfo -File $f
    if ($info.Time -lt $start) { continue }

    $captureIso = $info.Time.ToString('yyyy-MM-ddTHH:mm:ss')
    # Dedupe key from metadata only -- no file read, so OneDrive cloud-only files
    # are not hydrated. Content hashing is opt-in via -ContentHash.
    $key = '{0}|{1}|{2}' -f $f.Name, $f.Length, $captureIso
    if ($processed.ContainsKey($key)) { continue }

    $sha = $null
    if ($ContentHash) {
        $sha = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
    }

    $results.Add([pscustomobject]@{
        name          = $f.Name
        path          = $f.FullName
        captureTime   = $captureIso
        captureSource = $info.Source
        sizeKB        = [math]::Round($f.Length / 1KB, 1)
        key           = $key
        sha256        = $sha
    })
}

# --- Emit a JSON array (always, even for 0 or 1 item) ----------------------
$sorted = @($results.ToArray() | Sort-Object captureTime)
$items = $sorted | ForEach-Object { $_ | ConvertTo-Json -Depth 4 -Compress }
Write-Output ('[' + ($items -join ',') + ']')
