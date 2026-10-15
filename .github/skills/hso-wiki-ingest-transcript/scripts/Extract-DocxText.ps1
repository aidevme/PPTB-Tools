<#
.SYNOPSIS
    Extracts transcript text from a .docx file exported from Microsoft Teams.

.DESCRIPTION
    Parses Teams meeting transcript .docx files by reading the Word XML structure.
    Detects speaker names (bold runs), timestamps (gray runs), and spoken text,
    producing structured output: "SpeakerName   timestamp   text"

    Teams transcript .docx files have a consistent structure:
    - Bold runs = speaker names
    - Gray/muted colored runs = timestamps
    - Dark colored runs = spoken text

    When speaker names are not present in the .docx (some export formats omit them),
    the output will be: "timestamp   text" and a warning is emitted.

    When -MeetingDate and -MeetingTitle are provided, saves directly to
    agent/raw/transcripts/ with standardized naming. Captures for external
    sources (Teams meetings without local recordings) are written separately
    via hso-wiki-capture and are NOT produced by this script.

.PARAMETER Path
    Path to the .docx file to extract text from.

.PARAMETER OutputPath
    Optional output file path. If not specified, writes to the same directory
    as the input file with a .txt extension. Ignored when -MeetingDate is used.

.PARAMETER MeetingDate
    Meeting date in YYYY-MM-DD format. When provided with -MeetingTitle,
    saves to agent/raw/transcripts/{date}_{slug}.txt

.PARAMETER MeetingTitle
    Meeting title (e.g. "D365 CRM Kickoff"). Used with -MeetingDate to
    generate the output filename slug.

.EXAMPLE
    .\Extract-DocxText.ps1 -Path "Transcripts\12.2_D365 CRM Kickoff-en-US.docx"
    # Outputs to same folder as .txt

.EXAMPLE
    .\Extract-DocxText.ps1 -Path "Transcripts\12.2_Account and Contact Management.docx" -MeetingDate "2026-04-10" -MeetingTitle "Account and Contact Management"
    # Outputs to agent/raw/transcripts/2026-04-10_account_and_contact_management.txt
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$MeetingDate,

    [Parameter(Mandatory = $false)]
    [string]$MeetingTitle
)

# Resolve full path
$Path = Resolve-Path $Path -ErrorAction Stop

if (-not (Test-Path $Path)) {
    Write-Error "File not found: $Path"
    exit 1
}

if ([System.IO.Path]::GetExtension($Path) -ne '.docx') {
    Write-Error "File must be a .docx file: $Path"
    exit 1
}

# Determine output path
if ($MeetingDate -and $MeetingTitle) {
    # Slug: lowercase, spaces -> hyphens, strip special chars, match the wiki
    # filename convention used by hso-wiki-capture and hso-wiki-ingest-transcript.
    $slug = $MeetingTitle.ToLower() -replace '[^a-z0-9\s-]', '' -replace '\s+', '-'
    $fileName = "${MeetingDate}_${slug}.txt"

    # Walk up from the source file to find the nearest agent/ folder.
    $repoRoot = $Path
    while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot '.agent'))) {
        $repoRoot = Split-Path $repoRoot -Parent
    }
    if (-not $repoRoot) {
        $repoRoot = Get-Location
    }

    $transcriptsDir = Join-Path $repoRoot 'agent\raw\transcripts'
    if (-not (Test-Path $transcriptsDir)) {
        New-Item -ItemType Directory -Path $transcriptsDir -Force | Out-Null
    }
    $OutputPath = Join-Path $transcriptsDir $fileName
}
elseif (-not $OutputPath) {
    $OutputPath = [System.IO.Path]::ChangeExtension($Path, '.txt')
}

# Create a temp directory for extraction
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("docx_extract_" + [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # Extract document.xml from the .docx (ZIP) archive
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    $entry = $zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' }

    if (-not $entry) {
        Write-Error "No word/document.xml found in the .docx file."
        exit 1
    }

    $xmlPath = Join-Path $tempDir 'document.xml'
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $xmlPath)
    $zip.Dispose()

    # Parse the XML and extract structured transcript text
    [xml]$doc = Get-Content $xmlPath -Encoding UTF8
    $ns = New-Object Xml.XmlNamespaceManager($doc.NameTable)
    $ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')

    $paragraphs = $doc.SelectNodes('//w:p', $ns)
    $lines = [System.Collections.Generic.List[string]]::new()
    $hasSpeakers = $false
    $speakerCount = 0

    foreach ($p in $paragraphs) {
        $runs = $p.SelectNodes('.//w:r', $ns)
        if ($runs.Count -eq 0) { continue }

        $speaker = ''
        $timestamp = ''
        $textParts = [System.Collections.Generic.List[string]]::new()

        foreach ($r in $runs) {
            # Get run text
            $runText = ''
            foreach ($t in $r.SelectNodes('.//w:t', $ns)) {
                $runText += $t.InnerText
            }
            if (-not $runText) { continue }

            # Check if bold (speaker name indicator in Teams transcripts)
            $boldNode = $r.SelectSingleNode('.//w:rPr/w:b', $ns)
            $isBold = $null -ne $boldNode

            # Check color to distinguish timestamps from content
            $colorNode = $r.SelectSingleNode('.//w:rPr/w:color/@w:val', $ns)
            $color = if ($colorNode) { $colorNode.Value } else { '' }

            if ($isBold) {
                # Bold run = speaker name (trim trailing spaces)
                $trimmed = $runText.Trim()
                if ($trimmed -and $trimmed -ne '') {
                    $speaker = $trimmed
                }
            }
            elseif ($color -match '^(5A5A71|a19f9d|605e5c|A19F9D|5a5a71)$') {
                # Gray/muted color = timestamp or metadata text
                $trimmed = $runText.Trim()
                if ($trimmed -match '^\d+:\d+') {
                    $timestamp = $trimmed
                }
                elseif ($trimmed) {
                    # Other metadata (e.g., "started transcription")
                    $textParts.Add($trimmed)
                }
            }
            else {
                # Regular text = spoken content
                $textParts.Add($runText)
            }
        }

        # Build the output line
        $spokenText = ($textParts -join '').Trim()
        if (-not $timestamp -and -not $spokenText -and -not $speaker) { continue }

        # Track if this document has speaker info
        if ($speaker) {
            $hasSpeakers = $true
            $speakerCount++
        }

        $lineParts = @()
        if ($speaker) { $lineParts += $speaker }
        if ($timestamp) { $lineParts += $timestamp }
        if ($spokenText) { $lineParts += $spokenText }

        $line = $lineParts -join "`t"
        if ($line.Trim()) {
            $lines.Add($line)
        }
    }

    # Write output
    $lines | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "Extracted $($lines.Count) paragraphs to: $OutputPath"
    if ($hasSpeakers) {
        Write-Host "Speaker names detected: YES ($speakerCount paragraphs with speaker attribution)"
    } else {
        Write-Host "WARNING: No speaker names found in this transcript. The .docx export may not include speaker labels."
        Write-Host "Consider re-downloading the transcript from Teams with speaker identification enabled."
    }
}
finally {
    # Clean up temp directory
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
}
