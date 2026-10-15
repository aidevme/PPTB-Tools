<#
.SYNOPSIS
    Lists all supported discovery artifact files in a folder, recursively.

.DESCRIPTION
    Enumerates files in the given directory that Claude can ingest as discovery artifacts.
    Skips temp files (~$*), the Digests subfolder, and unsupported extensions.
    Outputs a table of file name, type, relative path, and size.

.PARAMETER Path
    The folder to list. Can be a local path or an OneDrive-synced SharePoint path.

.PARAMETER Recurse
    If set, searches subfolders recursively. Default is the top-level folder only.

.EXAMPLE
    .\List-ArtifactFiles.ps1 -Path "C:\Users\JohnDoe\OneDrive - HSO\<ClientProject> - Shared Documents\Phase 2 - CRM\6.Hypercare\<UseCaseFolder>"
    .\List-ArtifactFiles.ps1 -Path "agent/DiscoveryArtifacts" -Recurse
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [switch]$Recurse
)

$SupportedExtensions = @(
    '.pdf', '.xlsx', '.xlsm', '.xls',
    '.docx', '.doc',
    '.csv', '.tsv', '.txt',
    '.png', '.jpg', '.jpeg', '.gif', '.webp',
    '.svg', '.pptx', '.ppt',
    '.mp4', '.mov', '.vtt'
)

$TypeMap = @{
    '.pdf'  = 'PDF'
    '.xlsx' = 'Excel'; '.xlsm' = 'Excel'; '.xls' = 'Excel'
    '.docx' = 'Word'; '.doc' = 'Word'
    '.csv'  = 'CSV'; '.tsv' = 'TSV'
    '.txt'  = 'Plain Text'
    '.png'  = 'Image'; '.jpg' = 'Image'; '.jpeg' = 'Image'
    '.gif'  = 'Image'; '.webp' = 'Image'
    '.svg'  = 'SVG'
    '.pptx' = 'PowerPoint (export to PDF)'; '.ppt' = 'PowerPoint (export to PDF)'
    '.mp4'  = 'Video (provide transcript)'; '.mov' = 'Video (provide transcript)'
    '.vtt'  = 'Subtitle/Transcript'
}

$resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
if (-not $resolvedPath) {
    Write-Error "Path not found: $Path"
    exit 1
}

$getChildParams = @{
    LiteralPath = $resolvedPath.Path
    File        = $true
    Recurse     = $Recurse.IsPresent
}

$files = Get-ChildItem @getChildParams |
    Where-Object {
        # Skip temp files
        $_.Name -notlike '~$*' -and
        # Skip Digests subfolder
        $_.DirectoryName -notlike '*\Digests*' -and
        $_.DirectoryName -notlike '*/Digests*' -and
        # Only supported extensions
        $SupportedExtensions -contains $_.Extension.ToLower()
    } |
    Sort-Object DirectoryName, Name

if ($files.Count -eq 0) {
    Write-Host "No supported artifact files found in: $($resolvedPath.Path)"
    exit 0
}

Write-Host ""
Write-Host "Artifact files found in: $($resolvedPath.Path)"
Write-Host ("=" * 80)

$files | ForEach-Object {
    $ext      = $_.Extension.ToLower()
    $type     = if ($TypeMap.ContainsKey($ext)) { $TypeMap[$ext] } else { $ext.TrimStart('.').ToUpper() }
    $relPath  = $_.FullName.Replace($resolvedPath.Path, '').TrimStart('\').TrimStart('/')
    $sizeKB   = [math]::Round($_.Length / 1KB, 1)

    [PSCustomObject]@{
        Name     = $_.Name
        Type     = $type
        Path     = $relPath
        'Size (KB)' = $sizeKB
    }
} | Format-Table -AutoSize

Write-Host "Total: $($files.Count) file(s)"
Write-Host ""
