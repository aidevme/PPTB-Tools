<#
.SYNOPSIS
    Manages Confluence Cloud wiki pages via the Atlassian REST API.

.DESCRIPTION
    Supports the following operations:
    - ListSpaces:    List spaces in the Confluence site (key, name, id)
    - ListPages:     List pages in a Confluence space (follows pagination)
    - SearchPages:   Search for pages by title within a space
    - SearchContent: Full-text search via CQL (text ~ "...") across the site or a space
    - GetPage:       Retrieve a single page by ID (with body content)
    - CreatePage:    Create a new page in a space
    - UpdatePage:    Update an existing page's title and/or body

.PARAMETER Operation
    The operation to perform:
    ListSpaces | ListPages | SearchPages | SearchContent | GetPage | CreatePage | UpdatePage

.PARAMETER BaseUrl
    Atlassian Cloud base URL (e.g., https://yourorg.atlassian.net)

.PARAMETER Email
    Atlassian account email address used for Basic auth.

.PARAMETER ApiToken
    Atlassian API token (generated at https://id.atlassian.com/manage-profile/security/api-tokens).

.PARAMETER SpaceKey
    Confluence space key (e.g., PROJ). Required for ListPages, SearchPages, CreatePage.

.PARAMETER PageId
    Page ID. Required for GetPage. For UpdatePage, optional when BodyFilePath contains
    metadata marker like <!-- confluence-page-id: 123456 --> or confluence-page-id: 123456.

.PARAMETER Title
    Page title. Required for CreatePage, optional for UpdatePage and SearchPages.

.PARAMETER BodyText
    Page body content in Confluence storage format (XHTML). Mutually exclusive with BodyFilePath.

.PARAMETER BodyFilePath
    Path to a local markdown/text file. Content is converted to Confluence storage format.
    Mutually exclusive with BodyText.

.PARAMETER ParentPageId
    Parent page ID for CreatePage. If omitted, the page is created at the space root.

.PARAMETER Query
    Full-text search terms for SearchContent. Matched against page content via CQL text ~ "...".

.PARAMETER SpaceType
    For ListSpaces: global (default) | personal | all. Real team spaces are "global";
    every user's personal space is "personal" and typically noise for discovery.

.PARAMETER MaxResults
    Maximum number of results for ListSpaces/ListPages/SearchPages/SearchContent.
    Default: 25. Pass 0 to fetch ALL results (pagination is followed until exhausted).
    When a cap cuts off results, the output says so explicitly.

.PARAMETER AsText
    For GetPage: convert the storage-format body (XHTML + Confluence macros) to readable
    markdown-style text. Storage format remains the default because UpdatePage round-trips it.

.PARAMETER OutFile
    For GetPage: also write the body (storage format, or text when -AsText) to this file path.

.PARAMETER ConfirmWrite
    Required switch for CreatePage and UpdatePage operations.

.EXAMPLE
    .\Invoke-ConfluencePageOperation.ps1 -Operation ListPages `
        -SpaceKey "PROJ"

.EXAMPLE
    .\Invoke-ConfluencePageOperation.ps1 -Operation GetPage `
        -PageId "123456"

.EXAMPLE
    .\Invoke-ConfluencePageOperation.ps1 -Operation CreatePage `
        -SpaceKey "PROJ" -Title "New Page" `
        -BodyFilePath "./docs/content.md" -ConfirmWrite

.NOTES
    Requires: PowerShell 5.1+
    API: Confluence Cloud REST API v2 (/wiki/api/v2/)
    Auth: HTTP Basic (email:api_token, Base64-encoded)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("ListSpaces", "ListPages", "SearchPages", "SearchContent", "GetPage", "CreatePage", "UpdatePage")]
    [string]$Operation,

    [string]$BaseUrl,

    [string]$Email,

    [string]$ApiToken,

    [string]$SpaceKey,

    [string]$PageId,

    [string]$Title,

    [string]$BodyText,

    [string]$BodyFilePath,

    [string]$ParentPageId,

    [string]$Query,

    [ValidateSet("global", "personal", "all")]
    [string]$SpaceType = "global",

    [int]$MaxResults = 25,

    [switch]$AsText,

    [string]$OutFile,

    [switch]$ConfirmWrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Atlassian settings + auth header
# ---------------------------------------------------------------------------
# Auth lives in the hso-atlassian-auth foundation library, not here and not in hso-shared-scripts:
# Atlassian Cloud is HTTP Basic, not Entra, so it stays outside the Entra provider
# family. The upstream version resolved ATLASSIAN_* from .env / .env.local and built the Basic
# header inline; this template does not use .env, and duplicating auth
# per script is exactly what this shared library exists to prevent.
$authDir = Join-Path $PSScriptRoot "..\..\hso-atlassian-auth\scripts"
. (Join-Path $authDir "Atlassian-Auth.ps1")

$atlassian = Get-AtlassianSettings -BaseUrl $BaseUrl -Email $Email -ApiToken $ApiToken
$BaseUrl   = $atlassian.BaseUrl
$Email     = $atlassian.Email
$ApiToken  = $atlassian.ApiToken

$headers = Get-AtlassianHeaders -Email $Email -ApiToken $ApiToken
$headers["Content-Type"] = "application/json"

$script:ConfluencePageIdMaps = @{}

# ---------------------------------------------------------------------------
# Helper: Format source file path for page banners
# ---------------------------------------------------------------------------
function Get-SourceBannerPath {
    param([string]$FilePath)

    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        return $FilePath
    }

    $fullPath = $FilePath
    try {
        $fullPath = [System.IO.Path]::GetFullPath($FilePath)
    }
    catch {
        return $FilePath
    }

    try {
        $relativeToRepo = [System.IO.Path]::GetRelativePath($repoRoot, $fullPath)
        if ($relativeToRepo -and -not $relativeToRepo.Equals("..") -and -not $relativeToRepo.StartsWith("..\") -and -not $relativeToRepo.StartsWith("../")) {
            return ($relativeToRepo -replace '/', '\')
        }
    }
    catch {
        # Fall back to temp sync normalization below.
    }

    $tempSyncMatch = [regex]::Match($fullPath, '(?i)[\\/](?:docs-confluence-sync-[^\\/]+)[\\/](.+)$')
    if ($tempSyncMatch.Success) {
        return ($tempSyncMatch.Groups[1].Value -replace '/', '\')
    }

    return $FilePath
}

# ---------------------------------------------------------------------------
# Helper: Resolve markdown-link lookup root for publish-time link rewriting
# ---------------------------------------------------------------------------
function Get-MarkdownLinkLookupRoot {
    param([string]$FilePath)

    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        return $null
    }

    $fullPath = $FilePath
    try {
        $fullPath = [System.IO.Path]::GetFullPath($FilePath)
    }
    catch {
        return $null
    }

    try {
        $relativeToRepo = [System.IO.Path]::GetRelativePath($repoRoot, $fullPath)
        if ($relativeToRepo -and -not $relativeToRepo.Equals("..") -and -not $relativeToRepo.StartsWith("..\") -and -not $relativeToRepo.StartsWith("../")) {
            return $repoRoot
        }
    }
    catch {
        # Fall back to temp sync or local folder detection below.
    }

    $tempSyncMatch = [regex]::Match($fullPath, '^(?<root>.*?[\\/](?:docs-confluence-sync-[^\\/]+))(?:[\\/].*)?$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($tempSyncMatch.Success) {
        return $tempSyncMatch.Groups['root'].Value
    }

    return Split-Path -Path $fullPath -Parent
}

# ---------------------------------------------------------------------------
# Helper: Build a file-path to Confluence page ID map for markdown docs
# ---------------------------------------------------------------------------
function Get-ConfluencePageIdMap {
    param([string]$RootPath)

    if ([string]::IsNullOrWhiteSpace($RootPath) -or -not (Test-Path -LiteralPath $RootPath)) {
        return @{}
    }

    $resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path
    if ($script:ConfluencePageIdMaps.ContainsKey($resolvedRoot)) {
        return $script:ConfluencePageIdMaps[$resolvedRoot]
    }

    $pageIdByFile = @{}
    $files = Get-ChildItem -Path $resolvedRoot -Recurse -Filter "*.md" -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $resolvedFilePath = [System.IO.Path]::GetFullPath($file.FullName)
        $pageId = Get-ConfluencePageIdFromFile -FilePath $resolvedFilePath
        if (-not [string]::IsNullOrWhiteSpace($pageId)) {
            $pageIdByFile[$resolvedFilePath] = $pageId
        }
    }

    $script:ConfluencePageIdMaps[$resolvedRoot] = $pageIdByFile
    return $pageIdByFile
}

# ---------------------------------------------------------------------------
# Helper: Rewrite relative markdown links to Confluence page URLs when possible
# ---------------------------------------------------------------------------
function Resolve-MarkdownLinksForConfluence {
    param(
        [string]$Markdown,
        [string]$SourceFilePath
    )

    if ([string]::IsNullOrWhiteSpace($Markdown) -or [string]::IsNullOrWhiteSpace($SourceFilePath) -or [string]::IsNullOrWhiteSpace($SpaceKey)) {
        return $Markdown
    }

    $lookupRoot = Get-MarkdownLinkLookupRoot -FilePath $SourceFilePath
    if ([string]::IsNullOrWhiteSpace($lookupRoot)) {
        return $Markdown
    }

    $pageIdByFile = Get-ConfluencePageIdMap -RootPath $lookupRoot
    if ($pageIdByFile.Count -eq 0) {
        return $Markdown
    }

    $sourceDirectory = Split-Path -Path ([System.IO.Path]::GetFullPath($SourceFilePath)) -Parent

    return [regex]::Replace(
        $Markdown,
        '\[(?<text>[^\]]+)\]\((?<link>[^\)\r\n]+)\)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($match)

            $text = $match.Groups['text'].Value
            $link = $match.Groups['link'].Value.Trim()

            if ($link -match '^(?i)(https?:|mailto:|#)') {
                return $match.Value
            }

            $pathPart = $link
            $suffix = ""
            if ($link -match '^(?<path>[^#\?]+)(?<suffix>[#\?].*)?$') {
                $pathPart = $Matches['path']
                if ($Matches.ContainsKey('suffix') -and $Matches['suffix']) {
                    $suffix = $Matches['suffix']
                }
            }

            if (-not $pathPart.EndsWith('.md', [System.StringComparison]::OrdinalIgnoreCase)) {
                return $match.Value
            }

            try {
                $candidatePath = Join-Path $sourceDirectory $pathPart
                $resolvedTarget = [System.IO.Path]::GetFullPath($candidatePath)
            }
            catch {
                return $match.Value
            }

            if (-not (Test-Path -LiteralPath $resolvedTarget) -or -not $pageIdByFile.ContainsKey($resolvedTarget)) {
                return $match.Value
            }

            $pageId = $pageIdByFile[$resolvedTarget]
            $targetUrl = "{0}/wiki/spaces/{1}/pages/{2}{3}" -f $BaseUrl, $SpaceKey, $pageId, $suffix
            return "[$text]($targetUrl)"
        }
    )
}

# ---------------------------------------------------------------------------
# Helper: Convert Markdown to Confluence Storage Format
# ---------------------------------------------------------------------------
function ConvertFrom-MarkdownToConfluence {
    param(
        [string]$Markdown,
        [string]$SourceFilePath
    )

    $Markdown = Resolve-MarkdownLinksForConfluence -Markdown $Markdown -SourceFilePath $SourceFilePath

    # Initialize the inline-link resolution context consumed by Convert-InlineMarkdown.
    # These must be set before any Convert-InlineMarkdown call so StrictMode does not
    # fault on unset variables. Values mirror the already-applied
    # Resolve-MarkdownLinksForConfluence flow, so inline resolution is a safe no-op
    # for links it has already rewritten.
    $SourceDir = ''
    if (-not [string]::IsNullOrWhiteSpace($SourceFilePath)) {
        try {
            $SourceDir = Split-Path -Path ([System.IO.Path]::GetFullPath($SourceFilePath)) -Parent
        }
        catch {
            $SourceDir = ''
        }
    }
    $SiteBaseUrl  = $BaseUrl
    $SiteSpaceKey = $SpaceKey

    $lines = $Markdown -split "`n"
    $html = [System.Text.StringBuilder]::new()
    $inCodeBlock = $false
    $codeBlockLang = ""
    $codeBlockContent = [System.Text.StringBuilder]::new()
    $listStack = [System.Collections.Generic.List[object]]::new()
    $inTable = $false
    $firstH1Skipped = $false

    # Closes every currently-open list (and its still-open <li>), deepest first.
    # Called whenever non-list content interrupts or ends a list.
    function Close-AllOpenLists {
        while ($listStack.Count -gt 0) {
            $lvl = $listStack[$listStack.Count - 1]
            [void]$html.AppendLine("</li></$($lvl.Type)>")
            $listStack.RemoveAt($listStack.Count - 1)
        }
    }

    foreach ($rawLine in $lines) {
        $line = $rawLine.TrimEnd("`r")

        # --- Skip HTML comments (e.g. <!-- confluence-page-id: 123 -->) ---
        if ($line -match '^\s*<!--.*-->\s*$') { continue }

        # --- Code block toggle ---
        if ($line -match '^```(.*)$') {
            if ($inCodeBlock) {
                # Close code block
                $escapedCode = [System.Security.SecurityElement]::Escape($codeBlockContent.ToString().TrimEnd())
                if ($codeBlockLang) {
                    [void]$html.AppendLine("<ac:structured-macro ac:name=`"code`"><ac:parameter ac:name=`"language`">$codeBlockLang</ac:parameter><ac:plain-text-body><![CDATA[$escapedCode]]></ac:plain-text-body></ac:structured-macro>")
                } else {
                    [void]$html.AppendLine("<ac:structured-macro ac:name=`"code`"><ac:plain-text-body><![CDATA[$escapedCode]]></ac:plain-text-body></ac:structured-macro>")
                }
                $inCodeBlock = $false
                $codeBlockLang = ""
                [void]$codeBlockContent.Clear()
            } else {
                # Close any open list
                Close-AllOpenLists
                # Close any open table
                if ($inTable) {
                    [void]$html.AppendLine("</tbody></table>")
                    $inTable = $false
                }
                $inCodeBlock = $true
                $codeBlockLang = $Matches[1].Trim()
            }
            continue
        }

        if ($inCodeBlock) {
            [void]$codeBlockContent.AppendLine($line)
            continue
        }

        # --- Table row ---
        if ($line -match '^\|(.+)\|$') {
            $cells = @(($line.Trim('|') -split '\|') | ForEach-Object { $_.Trim() })

            # Skip separator rows (e.g., |---|---|). Every cell must be a separator
            # cell; using -match on the array would drop real rows where a single
            # cell happens to contain only dashes/colons.
            $isSeparatorRow = $cells.Count -gt 0 -and -not ($cells | Where-Object { $_ -notmatch '^[-:]+$' })
            if ($isSeparatorRow) {
                continue
            }

            if (-not $inTable) {
                # Close any open list
                Close-AllOpenLists
                [void]$html.Append("<table><thead><tr>")
                foreach ($cell in $cells) {
                    $cellHtml = Convert-InlineMarkdown -Text $cell -SourceDir $SourceDir -SiteBaseUrl $SiteBaseUrl -SiteSpaceKey $SiteSpaceKey
                    [void]$html.Append("<th>$cellHtml</th>")
                }
                [void]$html.AppendLine("</tr></thead><tbody>")
                $inTable = $true
                continue
            }

            [void]$html.Append("<tr>")
            foreach ($cell in $cells) {
                $cellHtml = Convert-InlineMarkdown -Text $cell -SourceDir $SourceDir -SiteBaseUrl $SiteBaseUrl -SiteSpaceKey $SiteSpaceKey
                [void]$html.Append("<td>$cellHtml</td>")
            }
            [void]$html.AppendLine("</tr>")
            continue
        } else {
            # Non-table line: close table if open
            if ($inTable) {
                [void]$html.AppendLine("</tbody></table>")
                $inTable = $false
            }
        }

        # --- Empty line ---
        if ([string]::IsNullOrWhiteSpace($line)) {
            Close-AllOpenLists
            continue
        }

        # --- Headings ---
        if ($line -match '^(#{1,6})\s+(.+)$') {
            Close-AllOpenLists
            $level = $Matches[1].Length
            # Skip the first H1 - Confluence uses the page title as the H1
            if ($level -eq 1 -and -not $firstH1Skipped) {
                $firstH1Skipped = $true
                continue
            }
            $headingText = Convert-InlineMarkdown -Text $Matches[2] -SourceDir $SourceDir -SiteBaseUrl $SiteBaseUrl -SiteSpaceKey $SiteSpaceKey
            [void]$html.AppendLine("<h$level>$headingText</h$level>")
            continue
        }

        # --- List item (ordered or unordered), nested by leading indentation ---
        if ($line -match '^(\s*)([-*+]|\d+\.)\s+(.+)$') {
            $indent = $Matches[1].Length
            $marker = $Matches[2]
            $itemContent = $Matches[3]
            if ($marker -match '^\d+\.$') {
                $type = "ol"
                $itemNumber = [int]($marker.TrimEnd('.'))
            } else {
                $type = "ul"
                $itemNumber = 1
            }

            # Dedent: close any lists nested deeper than the current indentation.
            while ($listStack.Count -gt 0 -and $listStack[$listStack.Count - 1].Indent -gt $indent) {
                $lvl = $listStack[$listStack.Count - 1]
                [void]$html.AppendLine("</li></$($lvl.Type)>")
                $listStack.RemoveAt($listStack.Count - 1)
            }

            if ($listStack.Count -gt 0 -and $listStack[$listStack.Count - 1].Indent -eq $indent) {
                if ($listStack[$listStack.Count - 1].Type -ne $type) {
                    # Same indent but different list style: close and reopen below.
                    [void]$html.AppendLine("</li></$($listStack[$listStack.Count - 1].Type)>")
                    $listStack.RemoveAt($listStack.Count - 1)
                } else {
                    # Same indent and style: close the previous sibling <li>.
                    [void]$html.AppendLine("</li>")
                }
            }

            if ($listStack.Count -eq 0 -or $listStack[$listStack.Count - 1].Indent -lt $indent) {
                # Open a new (possibly nested) list inside the current open <li>.
                # Preserve the source number when an ordered list resumes (e.g. after
                # a table) so numbering stays continuous instead of restarting at 1.
                if ($type -eq "ol" -and $itemNumber -gt 1) {
                    [void]$html.AppendLine("<ol start=`"$itemNumber`">")
                } else {
                    [void]$html.AppendLine("<$type>")
                }
                $listStack.Add([PSCustomObject]@{ Indent = $indent; Type = $type })
            }

            $itemText = Convert-InlineMarkdown -Text $itemContent -SourceDir $SourceDir -SiteBaseUrl $SiteBaseUrl -SiteSpaceKey $SiteSpaceKey
            [void]$html.Append("<li>$itemText")
            continue
        }

        # --- Horizontal rule ---
        if ($line -match '^[-*_]{3,}\s*$') {
            Close-AllOpenLists
            [void]$html.AppendLine("<hr />")
            continue
        }

        # --- Regular paragraph ---
        Close-AllOpenLists
        $paragraphText = Convert-InlineMarkdown -Text $line -SourceDir $SourceDir -SiteBaseUrl $SiteBaseUrl -SiteSpaceKey $SiteSpaceKey
        [void]$html.AppendLine("<p>$paragraphText</p>")
    }

    # Close any remaining open elements
    if ($inCodeBlock) {
        $escapedCode = [System.Security.SecurityElement]::Escape($codeBlockContent.ToString().TrimEnd())
        [void]$html.AppendLine("<ac:structured-macro ac:name=`"code`"><ac:plain-text-body><![CDATA[$escapedCode]]></ac:plain-text-body></ac:structured-macro>")
    }
    Close-AllOpenLists
    if ($inTable) {
        [void]$html.AppendLine("</tbody></table>")
    }

    return $html.ToString().Trim()
}

# Helper: Extract the first H1 title from markdown content.
# Skips YAML/TOML frontmatter (--- or +++ fences) and HTML comments before scanning.
# ---------------------------------------------------------------------------
function Get-MarkdownTitle {
    param([string]$Markdown)

    $lines = $Markdown -split "`n"
    $i = 0
    $total = $lines.Count

    # Skip leading frontmatter block (--- ... --- or +++ ... +++)
    if ($total -gt 0) {
        $firstLine = $lines[0].TrimEnd("`r").Trim()
        if ($firstLine -eq '---' -or $firstLine -eq '+++') {
            $fence = $firstLine
            $i = 1
            while ($i -lt $total) {
                $l = $lines[$i].TrimEnd("`r").Trim()
                $i++
                if ($l -eq $fence) { break }
            }
        }
    }

    # Scan remaining lines for first H1
    for (; $i -lt $total; $i++) {
        $line = $lines[$i].TrimEnd("`r").Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -match '^\s*<!--') { continue }
        if ($line -match '^#\s+(.+)$') {
            return $Matches[1].Trim()
        }
    }
    return $null
}

# ---------------------------------------------------------------------------
# Helper: Convert inline markdown (bold, italic, code, links)
# ---------------------------------------------------------------------------
function Convert-InlineMarkdown {
    param(
        [string]$Text,
        [string]$SourceDir   = '',
        [string]$SiteBaseUrl = '',
        [string]$SiteSpaceKey = ''
    )

    # Inline code (must be before bold/italic to avoid conflicts)
    $Text = [regex]::Replace($Text, '`([^`]+)`', '<code>$1</code>')
    # Bold + italic
    $Text = [regex]::Replace($Text, '\*\*\*(.+?)\*\*\*', '<strong><em>$1</em></strong>')
    # Bold
    $Text = [regex]::Replace($Text, '\*\*(.+?)\*\*', '<strong>$1</strong>')
    # Italic
    $Text = [regex]::Replace($Text, '\*(.+?)\*', '<em>$1</em>')
    # Markdown links [text](url) - resolve .md links to Confluence URLs when possible
    $Text = [regex]::Replace($Text, '\[([^\]]+)\]\(([^)]+)\)', {
        param($m)
        $label = $m.Groups[1].Value
        $href  = $m.Groups[2].Value
        if ($SourceDir -and ($href -match '\.md')) {
            $href = Resolve-MdLinkToConfluence -Href $href -SourceDir $SourceDir `
                        -SiteBaseUrl $SiteBaseUrl -SiteSpaceKey $SiteSpaceKey
        }
        return "<a href=`"$href`">$label</a>"
    })
    # Auto-link bare URLs not already inside an href or <a> tag
    $Text = [regex]::Replace($Text, '(?<!href=")(?<!">)(https?://[^\s<>\)]+)', '<a href="$1">$1</a>')

    return $Text
}

# ---------------------------------------------------------------------------
# Helper: Resolve Confluence page ID from markdown metadata markers
# ---------------------------------------------------------------------------
function Get-ConfluencePageIdFromFile {
    param([string]$FilePath)

    if ([string]::IsNullOrWhiteSpace($FilePath) -or -not (Test-Path -Path $FilePath)) {
        return $null
    }

    $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
    $patterns = @(
        '<!--\s*confluence-page-id\s*:\s*(\d+)\s*-->',
        '(?m)^\s*confluence-page-id\s*:\s*(\d+)\s*$',
        '(?m)^\s*confluence_id\s*:\s*(\d+)\s*$'
    )

    foreach ($pattern in $patterns) {
        $match = [regex]::Match($content, $pattern)
        if ($match.Success) {
            return $match.Groups[1].Value
        }
    }

    return $null
}

# ---------------------------------------------------------------------------
# Helper: Resolve a markdown link href to a Confluence page URL.
# - External URLs and anchor-only links are returned unchanged.
# - Relative .md paths are resolved to /wiki/spaces/KEY/pages/ID if the
#   target file contains a confluence-page-id marker; otherwise a warning
#   is emitted and the original href is kept.
# ---------------------------------------------------------------------------
function Resolve-MdLinkToConfluence {
    param(
        [string]$Href,
        [string]$SourceDir,
        [string]$SiteBaseUrl,
        [string]$SiteSpaceKey
    )

    # External URL or anchor-only: leave as-is
    if ($Href -match '^https?://' -or $Href -match '^#' -or $Href -match '^mailto:') {
        return $Href
    }

    # Only attempt resolution for .md links
    if ($Href -notmatch '\.md') { return $Href }

    # Split off any anchor fragment
    $filePart = $Href
    $anchor   = ''
    if ($Href -match '^(.+\.md)(#.+)$') {
        $filePart = $Matches[1]
        $anchor   = $Matches[2]
    }

    # Resolve the target file path
    $absPath = [System.IO.Path]::GetFullPath((Join-Path $SourceDir $filePart))

    $pageId = Get-ConfluencePageIdFromFile -FilePath $absPath
    if (-not $pageId) {
        Write-Warning "Link resolution: no confluence-page-id found in '$absPath' - keeping original href."
        return $Href
    }

    if ([string]::IsNullOrWhiteSpace($SiteSpaceKey)) {
        Write-Warning "Link resolution: SpaceKey is empty - cannot build Confluence URL for '$filePart'."
        return $Href
    }

    return "$SiteBaseUrl/wiki/spaces/$SiteSpaceKey/pages/$pageId$anchor"
}

# ---------------------------------------------------------------------------
# Helper: Get space ID from space key (needed for v2 API)
# ---------------------------------------------------------------------------
function Get-SpaceId {
    param([string]$Key)

    $url = "$BaseUrl/wiki/api/v2/spaces?keys=$Key"
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        if ($response.results -and $response.results.Count -gt 0) {
            return $response.results[0].id
        }
        throw "Space '$Key' not found."
    }
    catch {
        $resp = $_.Exception | Select-Object -ExpandProperty Response -ErrorAction SilentlyContinue
        if ($resp) {
            $statusCode = [int]$resp.StatusCode
            if ($statusCode -eq 401) { throw "Authentication failed. Check your email and API token." }
            if ($statusCode -eq 403) { throw "Access denied to space '$Key'. Check your permissions." }
        }
        throw $_
    }
}

# ---------------------------------------------------------------------------
# Helper: Format page summary for output
# ---------------------------------------------------------------------------
function Format-PageSummary {
    param([object]$Page)

    $id = $Page.id
    $title = $Page.title
    $status = if ($Page.PSObject.Properties["status"]) { $Page.status } else { "current" }
    $version = ""
    if ($Page.PSObject.Properties["version"]) {
        $version = $Page.version.number
    }
    $url = "$BaseUrl/wiki/spaces/$SpaceKey/pages/$id"

    return [PSCustomObject]@{
        Id      = $id
        Title   = $title
        Status  = $status
        Version = $version
        Url     = $url
    }
}

# ---------------------------------------------------------------------------
# Helper: Build a working Confluence web URL for a page.
# Prefers the API-provided _links.webui (always correct), then falls back to
# the /wiki/spaces/{key}/pages/{id} form, then the legacy viewpage form.
# Note: a bare /wiki/pages/{id} URL does NOT resolve in Confluence Cloud.
# ---------------------------------------------------------------------------
function Get-PageWebUrl {
    param(
        [object]$Page,
        [string]$FallbackSpaceKey
    )

    if ($Page -and $Page.PSObject.Properties["_links"] -and $Page._links -and
        $Page._links.PSObject.Properties["webui"] -and -not [string]::IsNullOrWhiteSpace($Page._links.webui)) {
        $webui = $Page._links.webui
        if ($webui.StartsWith("/wiki")) { return "$BaseUrl$webui" }
        return "$BaseUrl/wiki$webui"
    }

    $id = $Page.id
    if (-not [string]::IsNullOrWhiteSpace($FallbackSpaceKey)) {
        return "$BaseUrl/wiki/spaces/$FallbackSpaceKey/pages/$id"
    }
    return "$BaseUrl/wiki/pages/viewpage.action?pageId=$id"
}

# ---------------------------------------------------------------------------
# Helper: Resolve a Confluence _links.next relative URL to an absolute one.
# v2 endpoints return paths starting with /wiki; v1 search returns paths
# relative to /wiki (e.g. /rest/api/search?...).
# ---------------------------------------------------------------------------
function Resolve-ConfluenceNextUrl {
    param([string]$Relative)

    if ([string]::IsNullOrWhiteSpace($Relative)) { return $null }
    if ($Relative -match '^https?://') { return $Relative }
    if ($Relative.StartsWith("/wiki")) { return "$BaseUrl$Relative" }
    return "$BaseUrl/wiki$Relative"
}

# ---------------------------------------------------------------------------
# Helper: Follow a paginated Confluence collection endpoint until the
# _links.next cursor is exhausted or -MaxResults is reached.
# Max 0 means unlimited. Returns Results plus a Truncated flag so callers
# can SAY when a cap cut the list off - a truncated list presented as
# complete is the failure mode this exists to prevent.
# ---------------------------------------------------------------------------
function Invoke-PagedConfluenceRequest {
    param(
        [string]$FirstUrl,
        [int]$Max = 0
    )

    $collected = [System.Collections.Generic.List[object]]::new()
    $next = $FirstUrl
    $truncated = $false

    while ($next) {
        $response = Invoke-RestMethod -Uri $next -Headers $headers -Method Get
        foreach ($item in @($response.results)) {
            [void]$collected.Add($item)
        }

        $next = $null
        if ($response.PSObject.Properties["_links"] -and $response._links -and
            $response._links.PSObject.Properties["next"] -and
            -not [string]::IsNullOrWhiteSpace($response._links.next)) {
            $next = Resolve-ConfluenceNextUrl -Relative $response._links.next
        }

        if ($Max -gt 0 -and $collected.Count -ge $Max) {
            if ($next -or $collected.Count -gt $Max) { $truncated = $true }
            $next = $null
        }
    }

    $results = $collected.ToArray()
    if ($Max -gt 0 -and $results.Count -gt $Max) {
        $results = $results[0..($Max - 1)]
    }

    [pscustomobject]@{
        Results   = $results
        Truncated = $truncated
    }
}

# ---------------------------------------------------------------------------
# Helper: Emit the standard "showing N of more" warning for a capped list.
# ---------------------------------------------------------------------------
function Write-TruncationNotice {
    param([int]$Shown, [string]$What)

    $message = "Showing the first {0} {1} - MORE EXIST beyond the -MaxResults cap. Re-run with -MaxResults 0 to fetch all of them." -f $Shown, $What
    Write-Warning $message
}

# ---------------------------------------------------------------------------
# Helper: Convert Confluence storage format (XHTML + ac: macros) to readable
# markdown-style text. Lossy by design - for reading, not for round-tripping.
# UpdatePage still needs storage format; this exists so a human (or a capture)
# does not have to read raw <ac:structured-macro> soup.
# ---------------------------------------------------------------------------
function ConvertFrom-ConfluenceStorageToText {
    param([string]$Storage)

    if ([string]::IsNullOrWhiteSpace($Storage)) { return "" }

    $text = $Storage -replace "`r`n", "`n"

    # -- 1. Code macros -> fenced blocks. Protect their content with
    #       placeholders so later tag-stripping cannot eat < > characters.
    #       The counter and map are script-scoped because the MatchEvaluator
    #       scriptblock runs in a child scope where a plain assignment would
    #       not persist between matches.
    $script:StorageCodeBlocks = @{}
    $script:StorageCodeIndex = 0
    $text = [regex]::Replace(
        $text,
        '(?s)<ac:structured-macro[^>]*ac:name="code"[^>]*>(?<inner>.*?)</ac:structured-macro>',
        {
            param($m)
            $inner = $m.Groups['inner'].Value
            $lang = ""
            $langMatch = [regex]::Match($inner, '(?s)<ac:parameter[^>]*ac:name="language"[^>]*>(.*?)</ac:parameter>')
            if ($langMatch.Success) { $lang = $langMatch.Groups[1].Value.Trim() }
            $code = ""
            $cdataMatch = [regex]::Match($inner, '(?s)<ac:plain-text-body><!\[CDATA\[(.*?)\]\]></ac:plain-text-body>')
            if ($cdataMatch.Success) { $code = $cdataMatch.Groups[1].Value }
            $key = "@@CONFLUENCE-CODE-BLOCK-$($script:StorageCodeIndex)@@"
            $script:StorageCodeBlocks[$key] = "``````$lang`n$($code.TrimEnd())`n``````"
            $script:StorageCodeIndex++
            return "`n$key`n"
        })
    $codeBlocks = $script:StorageCodeBlocks

    # -- 2. Panel-style macros (info/note/warning/tip/panel/expand): keep the
    #       body, mark the panel type. Nested rich-text bodies just unwrap.
    $text = [regex]::Replace($text, '<ac:structured-macro[^>]*ac:name="(?<n>info|note|warning|tip|panel|expand)"[^>]*>', "`n> [`${n}]`n")
    $text = $text -replace '<ac:rich-text-body>', "`n"
    $text = $text -replace '</ac:rich-text-body>', "`n"
    # Any other macro: keep a stub naming it, drop its parameters.
    $text = [regex]::Replace($text, '<ac:structured-macro[^>]*ac:name="(?<n>[^"]+)"[^>]*/>', '[macro: ${n}]')
    $text = [regex]::Replace($text, '<ac:structured-macro[^>]*ac:name="(?<n>[^"]+)"[^>]*>', '[macro: ${n}] ')
    $text = $text -replace '</ac:structured-macro>', ''
    $text = [regex]::Replace($text, '(?s)<ac:parameter[^>]*>.*?</ac:parameter>', '')
    $text = [regex]::Replace($text, '(?s)<ac:plain-text-body><!\[CDATA\[(.*?)\]\]></ac:plain-text-body>', '$1')

    # -- 3. Links: internal page links, then plain anchors.
    $text = [regex]::Replace($text, '(?s)<ac:link[^>]*>.*?<ri:page[^>]*ri:content-title="(?<t>[^"]*)"[^>]*/?>.*?</ac:link>', '[${t}]')
    $text = [regex]::Replace($text, '(?s)<ac:link[^>]*>(.*?)</ac:link>', '$1')
    $text = $text -replace '<ac:link-body>', ''
    $text = $text -replace '</ac:link-body>', ''
    $text = [regex]::Replace($text, '(?s)<a[^>]*href="(?<h>[^"]*)"[^>]*>(?<t>.*?)</a>', '[${t}](${h})')

    # -- 4. Images, emoji, attachments.
    $text = [regex]::Replace($text, '(?s)<ac:image[^>]*>.*?ri:filename="(?<f>[^"]*)".*?</ac:image>', '[image: ${f}]')
    $text = [regex]::Replace($text, '(?s)<ac:image[^>]*>.*?</ac:image>', '[image]')
    $text = [regex]::Replace($text, '<ac:emoticon[^>]*ac:emoji-fallback="(?<e>[^"]*)"[^>]*/?>', '${e}')
    $text = [regex]::Replace($text, '<ac:emoticon[^>]*/?>', '')
    $text = [regex]::Replace($text, '<ri:[^>]*/?>', '')

    # -- 5. Tables -> markdown rows. Header separator after a <th> row.
    $text = [regex]::Replace($text, '(?s)<tr[^>]*>(?<row>.*?)</tr>', {
        param($m)
        $row = $m.Groups['row'].Value
        $isHeader = $row -match '<th[\s>]'
        $cells = [regex]::Matches($row, '(?s)<t[hd][^>]*>(.*?)</t[hd]>')
        $rendered = foreach ($c in $cells) {
            ($c.Groups[1].Value -replace '(?s)<[^>]+>', ' ' -replace '\s+', ' ').Trim()
        }
        $line = "| " + ($rendered -join " | ") + " |"
        if ($isHeader) {
            $sep = "|" + (" --- |" * $cells.Count)
            return "`n$line`n$sep`n"
        }
        return "`n$line`n"
    })
    $text = [regex]::Replace($text, '</?(table|thead|tbody|colgroup)[^>]*>', "`n")
    $text = [regex]::Replace($text, '<col[^>]*/?>', '')

    # -- 6. Headings, lists, structure.
    for ($h = 6; $h -ge 1; $h--) {
        $prefix = "#" * $h
        $text = [regex]::Replace($text, "(?s)<h$h[^>]*>(.*?)</h$h>", "`n$prefix `$1`n")
    }
    $text = [regex]::Replace($text, '<li[^>]*>', "`n- ")
    $text = $text -replace '</li>', ''
    $text = [regex]::Replace($text, '</?(ul|ol)[^>]*>', "`n")
    $text = [regex]::Replace($text, '<p[^>]*>', "`n")
    $text = $text -replace '</p>', "`n"
    $text = [regex]::Replace($text, '<br\s*/?>', "`n")
    $text = [regex]::Replace($text, '<hr\s*/?>', "`n---`n")
    $text = [regex]::Replace($text, '(?s)<blockquote[^>]*>(.*?)</blockquote>', "`n> `$1`n")

    # -- 7. Inline emphasis.
    $text = [regex]::Replace($text, '(?s)<(strong|b)[^>]*>(.*?)</\1>', '**$2**')
    $text = [regex]::Replace($text, '(?s)<(em|i)[^>]*>(.*?)</\1>', '*$2*')
    $text = [regex]::Replace($text, '(?s)<code[^>]*>(.*?)</code>', '`$1`')

    # -- 8. Strip whatever tags remain, then decode entities.
    $text = [regex]::Replace($text, '(?s)<[^>]+>', '')
    $text = [System.Net.WebUtility]::HtmlDecode($text)

    # -- 9. Reinsert protected code blocks, tidy blank lines.
    foreach ($key in $codeBlocks.Keys) {
        $text = $text.Replace($key, $codeBlocks[$key])
    }
    # A <li><p>...</p></li> nesting leaves the dash on its own line - rejoin it.
    $text = [regex]::Replace($text, "(?m)^- *`n+", "- ")
    $text = [regex]::Replace($text, "[ `t]+`n", "`n")
    $text = [regex]::Replace($text, "`n{3,}", "`n`n")
    # Consecutive table rows must be adjacent or markdown will not render the table.
    $text = [regex]::Replace($text, "(\|[^`n]*\|)`n+(?=\|)", "`$1`n")
    # A table whose source had no <th> row has no separator - markdown requires
    # one after the first row, so synthesize it with the right column count.
    $text = [regex]::Replace($text, "(?m)(?<!\|[^`n]*`n)^(?<first>\|[^`n]*\|)`n(?!\|[ :\-|]*---)(?=\|)", {
        param($m)
        $first = $m.Groups['first'].Value
        $cols = ([regex]::Matches($first, '\|')).Count - 1
        $sep = "|" + (" --- |" * $cols)
        return "$first`n$sep`n"
    })

    return $text.Trim()
}

# ---------------------------------------------------------------------------
# Helper: Clean a v1 search excerpt (highlight markers, entities, tags).
# ---------------------------------------------------------------------------
function Get-CleanExcerpt {
    param([string]$Excerpt)

    if ([string]::IsNullOrWhiteSpace($Excerpt)) { return "" }
    $e = $Excerpt -replace '@@@hl@@@', '**' -replace '@@@endhl@@@', '**'
    $e = [regex]::Replace($e, '(?s)<[^>]+>', ' ')
    $e = [System.Net.WebUtility]::HtmlDecode($e)
    $e = ($e -replace '\s+', ' ').Trim()
    if ($e.Length -gt 220) { $e = $e.Substring(0, 220) + "..." }
    # Pipes would break the markdown output table.
    return ($e -replace '\|', '\|')
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

switch ($Operation) {

    "ListSpaces" {
        # Per-request page size: the API caps at 250; pagination does the rest.
        $pageSize = if ($MaxResults -gt 0 -and $MaxResults -lt 250) { $MaxResults } else { 250 }
        $url = "$BaseUrl/wiki/api/v2/spaces?limit=$pageSize&sort=name"
        if ($SpaceType -ne "all") { $url += "&type=$SpaceType" }
        Write-Host "Listing $SpaceType spaces (use -SpaceType all to include every type)..." -ForegroundColor Cyan

        try {
            $paged = Invoke-PagedConfluenceRequest -FirstUrl $url -Max $MaxResults
        }
        catch {
            $resp = $_.Exception | Select-Object -ExpandProperty Response -ErrorAction SilentlyContinue
            $statusCode = if ($resp) { [int]$resp.StatusCode } else { 0 }
            if ($statusCode -eq 401) { Write-Error "Authentication failed."; return }
            Write-Error "Failed to list spaces: $_"; return
        }

        $spaces = $paged.Results
        if (-not $spaces -or $spaces.Count -eq 0) {
            Write-Output "No spaces found (or none visible to this account)."
            return
        }

        if ($paged.Truncated) {
            Write-TruncationNotice -Shown $spaces.Count -What "space(s)"
        } else {
            Write-Host "Found $($spaces.Count) space(s) - complete list." -ForegroundColor Green
        }

        $table = @("| Key | Id | Name | Type | Status |", "|-----|----|------|------|--------|")
        foreach ($space in $spaces) {
            $type = if ($space.PSObject.Properties["type"]) { $space.type } else { "" }
            $status = if ($space.PSObject.Properties["status"]) { $space.status } else { "" }
            $table += "| $($space.key) | $($space.id) | $($space.name) | $type | $status |"
        }
        Write-Output ($table -join "`n")
    }

    "ListPages" {
        if (-not $SpaceKey) { throw "SpaceKey is required for ListPages." }

        Write-Host "Resolving space '$SpaceKey'..." -ForegroundColor Cyan
        $spaceId = Get-SpaceId -Key $SpaceKey

        $pageSize = if ($MaxResults -gt 0 -and $MaxResults -lt 250) { $MaxResults } else { 250 }
        $url = "$BaseUrl/wiki/api/v2/spaces/$spaceId/pages?limit=$pageSize&sort=title&status=current"
        Write-Host "Listing pages in space '$SpaceKey'..." -ForegroundColor Cyan

        try {
            $paged = Invoke-PagedConfluenceRequest -FirstUrl $url -Max $MaxResults
        }
        catch {
            $resp = $_.Exception | Select-Object -ExpandProperty Response -ErrorAction SilentlyContinue
            $statusCode = if ($resp) { [int]$resp.StatusCode } else { 0 }
            if ($statusCode -eq 401) { Write-Error "Authentication failed."; return }
            Write-Error "Failed to list pages: $_"; return
        }

        $pages = $paged.Results
        if (-not $pages -or $pages.Count -eq 0) {
            Write-Output "No pages found in space '$SpaceKey'."
            return
        }

        if ($paged.Truncated) {
            Write-TruncationNotice -Shown $pages.Count -What "page(s) in space '$SpaceKey'"
        } else {
            Write-Host "Found $($pages.Count) page(s) - complete list." -ForegroundColor Green
        }

        $table = @("| ID | Title |", "|-----|-------|")
        foreach ($page in $pages) {
            $table += "| $($page.id) | $($page.title) |"
        }
        Write-Output ($table -join "`n")
        if ($paged.Truncated) {
            Write-Output ""
            Write-Output "_Showing the first $($pages.Count) pages - more exist. Re-run with -MaxResults 0 for the full list._"
        }
    }

    "SearchPages" {
        if (-not $SpaceKey) { throw "SpaceKey is required for SearchPages." }
        if (-not $Title) { throw "Title is required for SearchPages." }

        Write-Host "Resolving space '$SpaceKey'..." -ForegroundColor Cyan
        $spaceId = Get-SpaceId -Key $SpaceKey

        # The Confluence REST API v2 has no CQL endpoint. Use the v2 pages list with
        # the exact-match `title` filter first; if nothing matches, page through the
        # ENTIRE space and do a client-side case-insensitive "contains" match so
        # partial titles still resolve. Title matching only - for content search
        # use -Operation SearchContent.
        $encodedTitle = [System.Uri]::EscapeDataString($Title)
        $url = "$BaseUrl/wiki/api/v2/spaces/$spaceId/pages?title=$encodedTitle&status=current&limit=250"

        Write-Host "Searching for pages matching '$Title' in space '$SpaceKey'..." -ForegroundColor Cyan

        $truncated = $false
        try {
            $paged = Invoke-PagedConfluenceRequest -FirstUrl $url -Max $MaxResults
            $pages = @($paged.Results)
            $truncated = $paged.Truncated
        }
        catch {
            $resp = $_.Exception | Select-Object -ExpandProperty Response -ErrorAction SilentlyContinue
            $statusCode = if ($resp) { [int]$resp.StatusCode } else { 0 }
            if ($statusCode -eq 401) { Write-Error "Authentication failed."; return }
            if ($statusCode -eq 400) { Write-Error "Invalid search query."; return }
            Write-Error "Search failed: $_"; return
        }

        if ($pages.Count -eq 0) {
            # Fallback: no exact match -> page through the whole space (uncapped,
            # so a partial match beyond the first API page is not silently missed)
            # and filter client-side.
            Write-Host "No exact title match; scanning space for partial matches..." -ForegroundColor Cyan
            $needle = $Title.ToLowerInvariant()
            $scanUrl = "$BaseUrl/wiki/api/v2/spaces/$spaceId/pages?status=current&limit=250"
            try {
                $scan = Invoke-PagedConfluenceRequest -FirstUrl $scanUrl -Max 0
            }
            catch {
                $scan = [pscustomobject]@{ Results = @(); Truncated = $false }
            }
            $matches_ = @($scan.Results |
                Where-Object { $_.title -and $_.title.ToLowerInvariant().Contains($needle) })
            if ($MaxResults -gt 0 -and $matches_.Count -gt $MaxResults) {
                $truncated = $true
                $matches_ = @($matches_ | Select-Object -First $MaxResults)
            }
            $pages = $matches_
        }

        if ($pages.Count -eq 0) {
            Write-Output "No pages found matching '$Title' in space '$SpaceKey'."
            return
        }

        if ($truncated) {
            Write-TruncationNotice -Shown $pages.Count -What "matching page(s)"
        } else {
            Write-Host "Found $($pages.Count) page(s)." -ForegroundColor Green
        }

        $table = @("| ID | Title | Status |", "|-----|-------|--------|")
        foreach ($page in $pages) {
            $table += "| $($page.id) | $($page.title) | $($page.status) |"
        }
        Write-Output ($table -join "`n")
    }

    "SearchContent" {
        if (-not $Query) { throw "Query is required for SearchContent." }

        # Full-text search needs CQL, which only exists on the v1 REST API
        # (/wiki/rest/api/search). v2 has no CQL endpoint. The v1 response also
        # carries totalSize, so a capped result can say what it is a cap OF.
        $escapedQuery = $Query -replace '"', '\"'
        $cql = "type=page AND text ~ `"$escapedQuery`""
        if ($SpaceKey) { $cql = "space=`"$SpaceKey`" AND $cql" }
        $encodedCql = [System.Uri]::EscapeDataString($cql)

        $pageSize = if ($MaxResults -gt 0 -and $MaxResults -lt 100) { $MaxResults } else { 100 }
        $url = "$BaseUrl/wiki/rest/api/search?cql=$encodedCql&limit=$pageSize"

        $where = if ($SpaceKey) { "space '$SpaceKey'" } else { "all spaces" }
        Write-Host "Full-text search for '$Query' in $where..." -ForegroundColor Cyan

        $totalSize = $null
        $collected = [System.Collections.Generic.List[object]]::new()
        $next = $url
        try {
            while ($next) {
                # The v1 search response carries case-insensitive duplicate keys
                # ("subType" and "subtype") that PowerShell's JSON parser cannot
                # represent - Invoke-RestMethod silently returns the raw string.
                # Fetch raw, drop the camelCase duplicate, then parse.
                $rawResponse = Invoke-WebRequest -Uri $next -Headers $headers -Method Get -UseBasicParsing
                $jsonText = $rawResponse.Content `
                    -replace '"subType"\s*:\s*("[^"]*"|null)\s*,', '' `
                    -replace ',\s*"subType"\s*:\s*("[^"]*"|null)', ''
                $response = $jsonText | ConvertFrom-Json
                if ($null -eq $totalSize -and $response.PSObject.Properties["totalSize"]) {
                    $totalSize = $response.totalSize
                }
                foreach ($item in @($response.results)) { [void]$collected.Add($item) }

                $next = $null
                if ($response.PSObject.Properties["_links"] -and $response._links -and
                    $response._links.PSObject.Properties["next"] -and
                    -not [string]::IsNullOrWhiteSpace($response._links.next)) {
                    $next = Resolve-ConfluenceNextUrl -Relative $response._links.next
                }
                if ($MaxResults -gt 0 -and $collected.Count -ge $MaxResults) { $next = $null }
            }
        }
        catch {
            $resp = $_.Exception | Select-Object -ExpandProperty Response -ErrorAction SilentlyContinue
            $statusCode = if ($resp) { [int]$resp.StatusCode } else { 0 }
            if ($statusCode -eq 401) { Write-Error "Authentication failed."; return }
            if ($statusCode -eq 400) { Write-Error "Invalid CQL query: $cql"; return }
            Write-Error "Search failed: $_"; return
        }

        $hits = $collected.ToArray()
        if ($MaxResults -gt 0 -and $hits.Count -gt $MaxResults) {
            $hits = $hits[0..($MaxResults - 1)]
        }

        if ($hits.Count -eq 0) {
            Write-Output "No pages found containing '$Query' in $where."
            return
        }

        $totalLabel = if ($null -ne $totalSize) { $totalSize } else { "unknown" }
        if ($null -ne $totalSize -and $hits.Count -lt $totalSize) {
            Write-Warning "Showing $($hits.Count) of $totalLabel matching page(s). Re-run with -MaxResults 0 to fetch all."
        } else {
            Write-Host "Found $($hits.Count) matching page(s) - complete list." -ForegroundColor Green
        }

        $table = @("| ID | Title | Space | Excerpt |", "|-----|-------|-------|---------|")
        foreach ($hit in $hits) {
            $content = if ($hit.PSObject.Properties["content"]) { $hit.content } else { $null }
            $id = if ($content -and $content.PSObject.Properties["id"]) { $content.id } else { "" }
            $hitTitle = if ($hit.PSObject.Properties["title"]) { $hit.title } else { if ($content) { $content.title } else { "" } }
            $hitTitle = [System.Net.WebUtility]::HtmlDecode(($hitTitle -replace '@@@hl@@@', '' -replace '@@@endhl@@@', ''))
            $spaceName = ""
            if ($hit.PSObject.Properties["resultGlobalContainer"] -and $hit.resultGlobalContainer -and
                $hit.resultGlobalContainer.PSObject.Properties["title"]) {
                $spaceName = $hit.resultGlobalContainer.title
            }
            $excerpt = if ($hit.PSObject.Properties["excerpt"]) { Get-CleanExcerpt -Excerpt $hit.excerpt } else { "" }
            $table += "| $id | $hitTitle | $spaceName | $excerpt |"
        }
        Write-Output ($table -join "`n")
        if ($null -ne $totalSize -and $hits.Count -lt $totalSize) {
            Write-Output ""
            Write-Output "_Showing $($hits.Count) of $totalSize matches - re-run with -MaxResults 0 for all._"
        }
    }

    "GetPage" {
        if (-not $PageId) { throw "PageId is required for GetPage." }

        $url = "$BaseUrl/wiki/api/v2/pages/$PageId`?body-format=storage"
        Write-Host "Fetching page $PageId..." -ForegroundColor Cyan

        try {
            $page = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        }
        catch {
            $resp = $_.Exception | Select-Object -ExpandProperty Response -ErrorAction SilentlyContinue
            $statusCode = if ($resp) { [int]$resp.StatusCode } else { 0 }
            if ($statusCode -eq 404) { Write-Error "Page '$PageId' not found."; return }
            if ($statusCode -eq 401) { Write-Error "Authentication failed."; return }
            Write-Error "Failed to retrieve page: $_"; return
        }

        $versionNum = if ($page.PSObject.Properties["version"]) { $page.version.number } else { "?" }
        $spaceId = if ($page.PSObject.Properties["spaceId"]) { $page.spaceId } else { "" }
        $pageWebUrl = Get-PageWebUrl -Page $page -FallbackSpaceKey $SpaceKey

        $storageBody = $page.body.storage.value
        if ($AsText) {
            $bodyLabel = "Body (Readable Text - lossy; storage format is the write source of truth)"
            $bodyOut = ConvertFrom-ConfluenceStorageToText -Storage $storageBody
        } else {
            $bodyLabel = "Body (Storage Format)"
            $bodyOut = $storageBody
        }

        if (-not [string]::IsNullOrWhiteSpace($OutFile)) {
            $outDir = Split-Path -Path $OutFile -Parent
            if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
                New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            }
            [System.IO.File]::WriteAllText(
                [System.IO.Path]::GetFullPath($OutFile),
                $bodyOut,
                [System.Text.UTF8Encoding]::new($false))
            Write-Host "Body written to $OutFile" -ForegroundColor Green
        }

        $output = @"
## $($page.title)

**Page ID:** $($page.id)  |  **Version:** $versionNum  |  **Status:** $($page.status)
**Space ID:** $spaceId
**URL:** $pageWebUrl

### $bodyLabel
$bodyOut
"@
        Write-Output $output
    }

    "CreatePage" {
        if (-not $SpaceKey) { throw "SpaceKey is required for CreatePage." }
        if (-not $ConfirmWrite) { throw "Write blocked. Re-run with -ConfirmWrite to create the page." }

        # Resolve content
        if (-not [string]::IsNullOrWhiteSpace($BodyText) -and -not [string]::IsNullOrWhiteSpace($BodyFilePath)) {
            throw "Provide only one source: -BodyText or -BodyFilePath."
        }

        $bodyContent = ""
        if (-not [string]::IsNullOrWhiteSpace($BodyFilePath)) {
            if (-not (Test-Path -Path $BodyFilePath)) { throw "BodyFilePath not found: $BodyFilePath" }
            $markdown = Get-Content -Path $BodyFilePath -Raw -Encoding UTF8
            $bodyContent = ConvertFrom-MarkdownToConfluence -Markdown $markdown -SourceFilePath $BodyFilePath
            # Prepend source file banner
            $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")
            $sourcePath = Get-SourceBannerPath -FilePath $BodyFilePath
            $sourceBanner = "<ac:structured-macro ac:name=`"info`"><ac:rich-text-body><p>This page is generated from <strong>$sourcePath</strong> &#8212; last published: $timestamp</p></ac:rich-text-body></ac:structured-macro>"
            $bodyContent = $sourceBanner + $bodyContent
            # Auto-extract title from H1 if not explicitly provided
            if ([string]::IsNullOrWhiteSpace($Title)) {
                $extractedTitle = Get-MarkdownTitle -Markdown $markdown
                if ($extractedTitle) {
                    $Title = $extractedTitle
                }
            }
        }
        elseif (-not [string]::IsNullOrWhiteSpace($BodyText)) {
            $bodyContent = $BodyText
        }
        else {
            throw "Provide page content via -BodyText or -BodyFilePath."
        }

        if ([string]::IsNullOrWhiteSpace($Title)) {
            throw "Title is required for CreatePage. Provide -Title or include an H1 heading in the markdown file."
        }

        Write-Host "Resolving space '$SpaceKey'..." -ForegroundColor Cyan
        $spaceId = Get-SpaceId -Key $SpaceKey

        $payload = @{
            spaceId = $spaceId
            status  = "current"
            title   = $Title
            body    = @{
                representation = "storage"
                value          = $bodyContent
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($ParentPageId)) {
            $payload["parentId"] = $ParentPageId
        }

        $jsonBody = $payload | ConvertTo-Json -Depth 10
        $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
        $url = "$BaseUrl/wiki/api/v2/pages"

        Write-Host "Creating page '$Title' in space '$SpaceKey'..." -ForegroundColor Cyan

        try {
            $result = Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $jsonBytes
        }
        catch {
            $resp = $_.Exception | Select-Object -ExpandProperty Response -ErrorAction SilentlyContinue
            $statusCode = if ($resp) { [int]$resp.StatusCode } else { 0 }
            if ($statusCode -eq 401) { Write-Error "Authentication failed."; return }
            if ($statusCode -eq 400) {
                $errorBody = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { $_.Exception.Message }
                Write-Error "Bad request: $errorBody"; return
            }
            Write-Error "Failed to create page: $_"; return
        }

        $pageUrl = Get-PageWebUrl -Page $result -FallbackSpaceKey $SpaceKey
        Write-Host "Page created successfully." -ForegroundColor Green
        Write-Output @"
**Created:** $($result.title)
**Page ID:** $($result.id)
**Version:** $($result.version.number)
**URL:** $pageUrl
"@
    }

    "UpdatePage" {
        if (-not $ConfirmWrite) { throw "Write blocked. Re-run with -ConfirmWrite to update the page." }

        # Resolve content
        $hasBody = $false
        $bodyContent = ""
        $hasTitle = -not [string]::IsNullOrWhiteSpace($Title)

        if (-not [string]::IsNullOrWhiteSpace($BodyText) -and -not [string]::IsNullOrWhiteSpace($BodyFilePath)) {
            throw "Provide only one source: -BodyText or -BodyFilePath."
        }

        if (-not [string]::IsNullOrWhiteSpace($BodyFilePath)) {
            if (-not (Test-Path -Path $BodyFilePath)) { throw "BodyFilePath not found: $BodyFilePath" }

            if ([string]::IsNullOrWhiteSpace($PageId)) {
                $resolvedPageId = Get-ConfluencePageIdFromFile -FilePath $BodyFilePath
                if (-not [string]::IsNullOrWhiteSpace($resolvedPageId)) {
                    $PageId = $resolvedPageId
                    Write-Host "Resolved PageId '$PageId' from $BodyFilePath metadata." -ForegroundColor Cyan
                }
            }

            $markdown = Get-Content -Path $BodyFilePath -Raw -Encoding UTF8
            $bodyContent = ConvertFrom-MarkdownToConfluence -Markdown $markdown -SourceFilePath $BodyFilePath
            # Prepend source file banner
            $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")
            $sourcePath = Get-SourceBannerPath -FilePath $BodyFilePath
            $sourceBanner = "<ac:structured-macro ac:name=`"info`"><ac:rich-text-body><p>This page is generated from <strong>$sourcePath</strong> &#8212; last published: $timestamp</p></ac:rich-text-body></ac:structured-macro>"
            $bodyContent = $sourceBanner + $bodyContent
            $hasBody = $true
            # Auto-extract title from H1 if not explicitly provided
            if (-not $hasTitle) {
                $extractedTitle = Get-MarkdownTitle -Markdown $markdown
                if ($extractedTitle) {
                    $Title = $extractedTitle
                    $hasTitle = $true
                }
            }
        }
        elseif (-not [string]::IsNullOrWhiteSpace($BodyText)) {
            $bodyContent = $BodyText
            $hasBody = $true
        }

        if ([string]::IsNullOrWhiteSpace($PageId)) {
            throw "PageId is required for UpdatePage unless BodyFilePath includes a confluence page ID marker."
        }

        if (-not $hasBody -and -not $hasTitle) {
            throw "Provide at least one update: -Title and/or body via -BodyText or -BodyFilePath."
        }

        # Fetch current page to get version number and current title
        Write-Host "Fetching current page $PageId..." -ForegroundColor Cyan
        $getUrl = "$BaseUrl/wiki/api/v2/pages/$PageId`?body-format=storage"

        try {
            $currentPage = Invoke-RestMethod -Uri $getUrl -Headers $headers -Method Get
        }
        catch {
            $resp = $_.Exception | Select-Object -ExpandProperty Response -ErrorAction SilentlyContinue
            $statusCode = if ($resp) { [int]$resp.StatusCode } else { 0 }
            if ($statusCode -eq 404) { Write-Error "Page '$PageId' not found."; return }
            if ($statusCode -eq 401) { Write-Error "Authentication failed."; return }
            Write-Error "Failed to retrieve current page: $_"; return
        }

        $currentVersion = $currentPage.version.number
        $newVersion = $currentVersion + 1
        $pageTitle = if ($hasTitle) { $Title } else { $currentPage.title }

        $payload = @{
            id      = $PageId
            status  = "current"
            title   = $pageTitle
            version = @{
                number  = $newVersion
                message = "Updated via automation"
            }
        }

        if ($hasBody) {
            $payload["body"] = @{
                representation = "storage"
                value          = $bodyContent
            }
        } else {
            # Keep existing body
            $payload["body"] = @{
                representation = "storage"
                value          = $currentPage.body.storage.value
            }
        }

        $jsonBody = $payload | ConvertTo-Json -Depth 10
        $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
        $url = "$BaseUrl/wiki/api/v2/pages/$PageId"

        Write-Host "Updating page '$pageTitle' (v$currentVersion -> v$newVersion)..." -ForegroundColor Cyan

        try {
            $result = Invoke-RestMethod -Uri $url -Headers $headers -Method Put -Body $jsonBytes
        }
        catch {
            $resp = $_.Exception | Select-Object -ExpandProperty Response -ErrorAction SilentlyContinue
            $statusCode = if ($resp) { [int]$resp.StatusCode } else { 0 }
            if ($statusCode -eq 401) { Write-Error "Authentication failed."; return }
            if ($statusCode -eq 409) { Write-Error "Version conflict. The page was modified by someone else. Retry the operation."; return }
            if ($statusCode -eq 400) {
                $errorBody = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { $_.Exception.Message }
                Write-Error "Bad request: $errorBody"; return
            }
            Write-Error "Failed to update page: $_"; return
        }

        Write-Host "Page updated successfully." -ForegroundColor Green
        $pageUrl = Get-PageWebUrl -Page $result -FallbackSpaceKey $SpaceKey
        Write-Output @"
**Updated:** $($result.title)
**Page ID:** $($result.id)
**Version:** $($result.version.number)
**URL:** $pageUrl
"@
    }
}
