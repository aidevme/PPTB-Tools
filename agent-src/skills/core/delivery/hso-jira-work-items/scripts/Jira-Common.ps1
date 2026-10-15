<#
.SYNOPSIS
    Shared helpers for the hso-jira-work-items scripts. Dot-sourced, never run directly.

.DESCRIPTION
    One place for the things every script in this skill needs:
      - Invoke-JiraApi               REST call wrapper that turns Jira's error body into a readable message
      - Resolve-JiraField            field NAME or id -> field descriptor (id + schema), cached per run
      - ConvertTo-JiraFieldValue     shapes a plain value the way the field's schema expects
                                     (textarea -> ADF, option -> {value}, components -> [{name}], ...)
      - ConvertTo-JiraFieldsPayload  name/id -> value map into a ready-to-send fields hashtable
      - ConvertTo-JiraAdf            markdown-ish text -> Atlassian Document Format
      - ConvertFrom-JiraAdf / Get-JiraFieldText   ADF or any field value -> plain text
      - Search-JiraIssues            paginated JQL search (nextPageToken) with a hard cap
      - Get-JiraAllowedStatuses / Assert-JiraStatusAllowed   the JIRA_ALLOWED_STATUSES guardrail
      - Find-JiraTransition          matches a target STATUS to a transition (by the status it leads
                                     to first, then by transition name - workflows name them differently)
      - Read-JiraTextInput / Read-JiraJsonFile   inline text or file, UTF-8

    Every script dot-sources this file AFTER hso-atlassian-auth has set $BaseUrl and $headers.
    Keeping these in one file is the same reasoning as ADR 0019: five copies is five places for one
    defect to hide, which is exactly how the 2026-08 adoption shipped five scripts with their input
    validation blocks missing.

.NOTES
    Pure ASCII. PowerShell 5.1 and 7 compatible (no ternary, no null-coalescing).
#>

Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# REST wrapper
# ---------------------------------------------------------------------------
function Invoke-JiraApi {
    [CmdletBinding()]
    param(
        [ValidateSet('Get', 'Post', 'Put', 'Delete')]
        [string]$Method = 'Get',
        [Parameter(Mandatory)][string]$Path,
        [object]$Body,
        [string]$Context = ''
    )

    $uri = $Path
    if ($Path -notmatch '^https?://') { $uri = "$BaseUrl$Path" }
    $params = @{ Uri = $uri; Headers = $headers; Method = $Method }
    if ($null -ne $Body) {
        if ($Body -is [string]) { $params.Body = $Body } else { $params.Body = ($Body | ConvertTo-Json -Depth 30) }
        $params.ContentType = 'application/json'
    }

    try {
        return Invoke-RestMethod @params
    }
    catch {
        $status = $null
        $exception = $_.Exception
        if ($exception.PSObject.Properties['Response'] -and $exception.Response) {
            try { $status = [int]$exception.Response.StatusCode } catch { $status = $null }
        }

        $raw = ''
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $raw = [string]$_.ErrorDetails.Message }
        $detail = ''
        if ($raw) {
            try {
                $err = $raw | ConvertFrom-Json
                $parts = @()
                if ($err.PSObject.Properties['errorMessages'] -and $err.errorMessages) { $parts += @($err.errorMessages) }
                if ($err.PSObject.Properties['errors'] -and $err.errors) {
                    foreach ($p in $err.errors.PSObject.Properties) { $parts += ("{0}: {1}" -f $p.Name, $p.Value) }
                }
                $detail = ($parts -join '; ')
            }
            catch { $detail = $raw }
        }

        $hint = 'Request failed.'
        switch ($status) {
            400 { $hint = 'Jira rejected the request.' }
            401 { $hint = 'Authentication failed. Check the Atlassian email and API token.' }
            403 { $hint = 'Forbidden. The account lacks permission for this operation in the target project.' }
            404 { $hint = 'Not found. Check the issue key or path.' }
        }
        $label = ''
        if ($Context) { $label = "$Context - " }
        $statusText = 'n/a'
        if ($null -ne $status) { $statusText = [string]$status }
        throw ("{0}{1} {2} -> HTTP {3}. {4} {5} {6}" -f $label, $Method.ToUpper(), $Path, $statusText, $hint, $detail, $exception.Message).Trim()
    }
}

# ---------------------------------------------------------------------------
# Field catalog and resolution
# ---------------------------------------------------------------------------
$script:JiraFieldCatalog = $null

function Get-JiraFieldCatalog {
    if ($null -eq $script:JiraFieldCatalog) {
        # Unroll explicitly: a JSON array can come back as ONE nested Object[] in PowerShell 7.
        $script:JiraFieldCatalog = @((Invoke-JiraApi -Path '/rest/api/3/field' -Context 'Field catalog') | ForEach-Object { $_ })
    }
    return $script:JiraFieldCatalog
}

function Resolve-JiraField {
    <#
    .SYNOPSIS
        Returns the field descriptor (id, name, schema) for a field NAME (case-insensitive) or id.
        Throws when the name is unknown or ambiguous - a client Jira can carry two fields with the
        same display name, and writing to the wrong one silently is worse than stopping.
    #>
    param([Parameter(Mandatory)][string]$NameOrId)

    $catalog = Get-JiraFieldCatalog
    $byId = @($catalog | Where-Object { $_.id -eq $NameOrId })
    if ($byId.Count -eq 1) { return $byId[0] }

    $byName = @($catalog | Where-Object { $_.name -ieq $NameOrId })
    if ($byName.Count -eq 1) { return $byName[0] }
    if ($byName.Count -gt 1) {
        $list = ($byName | ForEach-Object { "$($_.id) [$(Get-JiraSchemaPart -Field $_ -Part 'type')]" }) -join ', '
        throw "Field name '$NameOrId' is ambiguous in this Jira: $list. Pass the field id instead."
    }
    throw "Field '$NameOrId' was not found in this Jira. Check the display name (case-insensitive) or pass the id (customfield_NNNNN)."
}

function Get-JiraSchemaPart {
    param([object]$Field, [string]$Part)
    if ($Field.PSObject.Properties['schema'] -and $Field.schema -and $Field.schema.PSObject.Properties[$Part]) {
        return [string]$Field.schema.$Part
    }
    return ''
}

function Test-JiraAdfDocument {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [System.Collections.IDictionary]) { return ($Value.Contains('type') -and $Value['type'] -eq 'doc') }
    if ($Value.PSObject.Properties['type']) { return ($Value.type -eq 'doc') }
    return $false
}

function ConvertTo-JiraFieldValue {
    <#
    .SYNOPSIS
        Shapes a plain value into what the field's schema expects. Already-shaped values (hashtables,
        ADF documents) pass through untouched so a caller with full knowledge is never second-guessed.
    #>
    param(
        [Parameter(Mandatory)][object]$Field,
        [AllowNull()][object]$Value
    )
    if ($null -eq $Value) { return $null }

    $type   = Get-JiraSchemaPart -Field $Field -Part 'type'
    $items  = Get-JiraSchemaPart -Field $Field -Part 'items'
    $custom = Get-JiraSchemaPart -Field $Field -Part 'custom'
    $isDoc  = Test-JiraAdfDocument -Value $Value

    if ($type -eq 'string') {
        if ($isDoc) { return $Value }
        if ($custom -match 'textarea' -or $Field.id -eq 'description' -or $Field.id -eq 'environment') {
            return (ConvertTo-JiraAdf -Text ([string]$Value))
        }
        return [string]$Value
    }
    if ($type -eq 'number')    { return [double]$Value }
    if ($type -eq 'option')    { if ($Value -is [string]) { return @{ value = $Value } }     ; return $Value }
    if ($type -eq 'priority')  { if ($Value -is [string]) { return @{ name = $Value } }      ; return $Value }
    if ($type -eq 'user')      { if ($Value -is [string]) { return @{ accountId = $Value } } ; return $Value }
    if ($type -eq 'issuetype') { if ($Value -is [string]) { return @{ name = $Value } }      ; return $Value }
    if ($type -eq 'project')   { if ($Value -is [string]) { return @{ key = $Value } }       ; return $Value }
    if ($type -eq 'issuelink') { if ($Value -is [string]) { return @{ key = $Value } }       ; return $Value }
    if ($type -eq 'array') {
        $list = @($Value)
        if ($items -eq 'option')    { return @($list | ForEach-Object { if ($_ -is [string]) { @{ value = $_ } } else { $_ } }) }
        if ($items -eq 'component') { return @($list | ForEach-Object { if ($_ -is [string]) { @{ name = $_ } } else { $_ } }) }
        if ($items -eq 'version')   { return @($list | ForEach-Object { if ($_ -is [string]) { @{ name = $_ } } else { $_ } }) }
        if ($items -eq 'user')      { return @($list | ForEach-Object { if ($_ -is [string]) { @{ accountId = $_ } } else { $_ } }) }
        if ($items -eq 'string')    { return @($list | ForEach-Object { [string]$_ }) }
        return $list
    }
    if ($Field.id -eq 'parent' -and $Value -is [string]) { return @{ key = $Value } }
    return $Value
}

function ConvertTo-JiraFieldsPayload {
    <#
    .SYNOPSIS
        Turns a name-or-id -> value map (hashtable, or PSCustomObject from JSON) into a fields hashtable
        keyed by field id with every value shaped for its schema.
    #>
    param([Parameter(Mandatory)][object]$Map)

    $out = @{}
    $pairs = @()
    if ($Map -is [System.Collections.IDictionary]) {
        foreach ($k in $Map.Keys) { $pairs += [pscustomobject]@{ Key = [string]$k; Value = $Map[$k] } }
    }
    else {
        foreach ($p in $Map.PSObject.Properties) { $pairs += [pscustomobject]@{ Key = $p.Name; Value = $p.Value } }
    }
    foreach ($pair in $pairs) {
        $field = Resolve-JiraField -NameOrId $pair.Key
        $out[$field.id] = ConvertTo-JiraFieldValue -Field $field -Value $pair.Value
    }
    return $out
}

# ---------------------------------------------------------------------------
# Markdown-ish text -> ADF
# ---------------------------------------------------------------------------
function New-JiraMarkedTextNode {
    <#
    .SYNOPSIS
        ADF text nodes for one run of text, optionally carrying inline marks (strong / em / code /
        strike / link). A newline inside the run becomes a hardBreak node, so a mark that opens on
        one line and closes on the next keeps its emphasis across the break instead of being lost.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value, [object[]]$Marks = @())

    $nodes = @()
    $pieces = $Value -split "`n"
    for ($p = 0; $p -lt $pieces.Count; $p++) {
        if ($p -gt 0) { $nodes += @{ type = "hardBreak" } }
        if ([string]::IsNullOrEmpty($pieces[$p])) { continue }
        $node = @{ type = "text"; text = $pieces[$p] }
        if ($Marks -and @($Marks).Count -gt 0) { $node["marks"] = @($Marks) }
        $nodes += $node
    }
    return $nodes
}

function ConvertTo-JiraInlineNodes {
    <#
    .SYNOPSIS
        Parses inline markdown inside ONE paragraph of text and returns the ADF text nodes for it.

    .DESCRIPTION
        Without this, "**not**" reached Jira as the four literal characters around the word - the
        author's emphasis lost and the asterisks shown to the reader (found on a live client story, 2026-09).
        Handled, earliest match first so the markers nest the way an author expects:
          `code`  **strong**  __strong__  ~~strike~~  *em*  _em_  [text](https://url)
        A code span's content is literal - markers inside it are left alone. An unmatched or lone
        marker is left exactly as typed, so prose like "3 * 4" and snake_case survive untouched.

        Matching is Singleline, so a pair that opens on one line and closes on the next still marks
        the text between them - hand-wrapped prose splits a bold sentence across lines all the time.
        The reach is bounded by the paragraph: the caller only ever passes one paragraph's lines,
        and a blank line has already ended it.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value, [object[]]$Marks = @())

    if ([string]::IsNullOrEmpty($Value)) { return @() }
    $reOptions = [System.Text.RegularExpressions.RegexOptions]::Singleline

    $patterns = @(
        @{ Kind = "code";   Pattern = '`([^`]+)`';                                       Literal = $true },
        @{ Kind = "link";   Pattern = '\[([^\]]+)\]\(([^)\s]+)\)';                       Literal = $false },
        @{ Kind = "strong"; Pattern = '\*\*(?=\S)(.+?)(?<=\S)\*\*';                      Literal = $false },
        @{ Kind = "strong"; Pattern = '(?<!\w)__(?=\S)(.+?)(?<=\S)__(?!\w)';             Literal = $false },
        @{ Kind = "strike"; Pattern = '~~(?=\S)(.+?)(?<=\S)~~';                          Literal = $false },
        @{ Kind = "em";     Pattern = '(?<![\*\w])\*(?=\S)([^\*]+?)(?<=\S)\*(?![\*\w])'; Literal = $false },
        @{ Kind = "em";     Pattern = '(?<![_\w])_(?=\S)([^_]+?)(?<=\S)_(?![_\w])';      Literal = $false }
    )

    $bestMatch = $null
    $bestPattern = $null
    foreach ($p in $patterns) {
        $m = [regex]::Match($Value, $p.Pattern, $reOptions)
        if (-not $m.Success) { continue }
        if ($null -eq $bestMatch -or $m.Index -lt $bestMatch.Index) { $bestMatch = $m; $bestPattern = $p }
    }

    if ($null -eq $bestMatch) { return @(New-JiraMarkedTextNode -Value $Value -Marks $Marks) }

    $newMark = @{ type = $bestPattern.Kind }
    if ($bestPattern.Kind -eq "link") { $newMark = @{ type = "link"; attrs = @{ href = $bestMatch.Groups[2].Value } } }

    $nodes = @()
    if ($bestMatch.Index -gt 0) {
        $nodes += @(ConvertTo-JiraInlineNodes -Value $Value.Substring(0, $bestMatch.Index) -Marks $Marks)
    }
    $inner = $bestMatch.Groups[1].Value
    $innerMarks = @($Marks) + @($newMark)
    if ($bestPattern.Literal) { $nodes += @(New-JiraMarkedTextNode -Value $inner -Marks $innerMarks) }
    else { $nodes += @(ConvertTo-JiraInlineNodes -Value $inner -Marks $innerMarks) }
    $tailStart = $bestMatch.Index + $bestMatch.Length
    if ($tailStart -lt $Value.Length) {
        $nodes += @(ConvertTo-JiraInlineNodes -Value $Value.Substring($tailStart) -Marks $Marks)
    }
    return $nodes
}

function ConvertTo-JiraAdf {
    <#
    .SYNOPSIS
        Converts plain / markdown-ish text to an ADF document: headings (#), bullet and numbered
        lists, fenced code blocks, pipe tables, horizontal rules, and paragraphs. Consecutive
        non-blank lines become ONE paragraph with hard line breaks, so Gherkin steps stay together.
        Inline markers (**strong**, *em*, `code`, ~~strike~~, [text](url)) become real ADF marks
        everywhere except inside a fenced code block - see ConvertTo-JiraInlineNodes.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $normalizedText = $Text -replace "`r`n", "`n" -replace "`r", "`n"
    $lines = $normalizedText -split "`n"

    $content = @()
    $inCodeBlock = $false
    $codeLanguage = ""
    $codeLines = @()
    $listType = $null
    $listItems = @()
    $paraLines = @()

    function New-TextNode { param([AllowEmptyString()][string]$Value) return @{ type = "text"; text = $Value } }

    function New-ParagraphNode {
        param([string[]]$Values)
        # Joined, not parsed line by line: hand-wrapped prose splits a **bold sentence** across two
        # lines, and a per-line parse would never see the closing marker. The newlines come back as
        # hardBreak nodes inside ConvertTo-JiraInlineNodes, so the layout is unchanged either way.
        $nodes = @(ConvertTo-JiraInlineNodes -Value ($Values -join "`n"))
        if ($nodes.Count -eq 0) { $nodes += (New-TextNode -Value " ") }
        return @{ type = "paragraph"; content = $nodes }
    }

    function Split-MarkdownTableCells {
        param([Parameter(Mandatory)][string]$Row)
        $trimmedRow = $Row.Trim()
        if ($trimmedRow.StartsWith("|")) { $trimmedRow = $trimmedRow.Substring(1) }
        if ($trimmedRow.EndsWith("|")) { $trimmedRow = $trimmedRow.Substring(0, $trimmedRow.Length - 1) }
        $cells = @()
        foreach ($cell in ($trimmedRow -split "\|")) { $cells += $cell.Trim() }
        return $cells
    }

    function Test-MarkdownTableRow {
        param([Parameter(Mandatory)][AllowEmptyString()][string]$Row)
        return ($Row.Trim() -like "|*|")
    }

    function Test-MarkdownTableSeparator {
        param([Parameter(Mandatory)][AllowEmptyString()][string]$Row)
        if (-not (Test-MarkdownTableRow -Row $Row)) { return $false }
        $cells = Split-MarkdownTableCells -Row $Row
        if ($cells.Count -eq 0) { return $false }
        $hasSeparator = $false
        foreach ($cell in $cells) {
            if ([string]::IsNullOrWhiteSpace($cell)) { continue }
            if ($cell -notmatch '^:?-{3,}:?$') { return $false }
            $hasSeparator = $true
        }
        return $hasSeparator
    }

    function New-TableCellNode {
        param([Parameter(Mandatory)][AllowEmptyString()][string]$Text, [switch]$Header)
        $cellType = "tableCell"
        if ($Header) { $cellType = "tableHeader" }
        return @{ type = $cellType; content = @( (New-ParagraphNode -Values @($Text)) ) }
    }

    $flushParagraph = {
        if ($paraLines.Count -gt 0) {
            $content += (New-ParagraphNode -Values $paraLines)
            $paraLines = @()
        }
    }

    $flushList = {
        if ($listItems.Count -eq 0 -or [string]::IsNullOrWhiteSpace($listType)) { return }
        $listNodes = @()
        foreach ($item in $listItems) {
            $listNodes += @{ type = "listItem"; content = @( (New-ParagraphNode -Values @($item)) ) }
        }
        $content += @{ type = $listType; content = $listNodes }
        $listType = $null
        $listItems = @()
    }

    $addCodeBlock = {
        param([string]$Language, [string[]]$CodeBlockLines)
        $node = @{ type = "codeBlock"; content = @( (New-TextNode -Value ($CodeBlockLines -join "`n")) ) }
        if (-not [string]::IsNullOrWhiteSpace($Language)) { $node.attrs = @{ language = $Language } }
        $content += $node
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $trimmed = $line.Trim()

        if ($inCodeBlock) {
            if ($trimmed -match '^```') {
                . $addCodeBlock -Language $codeLanguage -CodeBlockLines $codeLines
                $inCodeBlock = $false; $codeLanguage = ""; $codeLines = @()
            }
            else { $codeLines += $line }
            continue
        }

        if ($trimmed -match '^```\s*([A-Za-z0-9_-]+)?\s*$') {
            . $flushParagraph; . $flushList
            $inCodeBlock = $true
            $codeLanguage = ""
            if ($Matches.Count -gt 1) { $codeLanguage = $Matches[1] }
            $codeLines = @()
            continue
        }

        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            . $flushParagraph; . $flushList
            continue
        }

        if ((Test-MarkdownTableRow -Row $trimmed) -and (($i + 1) -lt $lines.Count) -and (Test-MarkdownTableSeparator -Row $lines[$i + 1])) {
            . $flushParagraph; . $flushList
            $headerCells = Split-MarkdownTableCells -Row $trimmed
            $columnCount = $headerCells.Count
            $tableRows = @()
            $headerRowCells = @()
            foreach ($headerCell in $headerCells) { $headerRowCells += (New-TableCellNode -Text $headerCell -Header) }
            $tableRows += @{ type = "tableRow"; content = $headerRowCells }

            $i += 2
            while ($i -lt $lines.Count) {
                $dataLine = $lines[$i]
                if (-not (Test-MarkdownTableRow -Row $dataLine.Trim())) { break }
                $dataCells = @(Split-MarkdownTableCells -Row $dataLine)
                while ($dataCells.Count -lt $columnCount) { $dataCells += "" }
                if ($dataCells.Count -gt $columnCount) { $dataCells = $dataCells[0..($columnCount - 1)] }
                $rowCells = @()
                foreach ($dataCell in $dataCells) { $rowCells += (New-TableCellNode -Text $dataCell) }
                $tableRows += @{ type = "tableRow"; content = $rowCells }
                $i++
            }
            $i--
            $content += @{ type = "table"; attrs = @{ isNumberColumnEnabled = $false; layout = "default" }; content = $tableRows }
            continue
        }

        if ($trimmed -match '^(---|\*\*\*|___)$') {
            . $flushParagraph; . $flushList
            $content += @{ type = "rule" }
            continue
        }

        if ($trimmed -match '^(#{1,6})\s+(.+)$') {
            . $flushParagraph; . $flushList
            $content += @{ type = "heading"; attrs = @{ level = $Matches[1].Length }; content = @(ConvertTo-JiraInlineNodes -Value $Matches[2]) }
            continue
        }

        if ($trimmed -match '^[-*]\s+(.+)$') {
            . $flushParagraph
            if ($listType -and $listType -ne "bulletList") { . $flushList }
            if (-not $listType) { $listType = "bulletList" }
            $listItems += $Matches[1]
            continue
        }

        if ($trimmed -match '^\d+[.)]\s+(.+)$') {
            . $flushParagraph
            if ($listType -and $listType -ne "orderedList") { . $flushList }
            if (-not $listType) { $listType = "orderedList" }
            $listItems += $Matches[1]
            continue
        }

        if ($listType) { . $flushList }
        $paraLines += $trimmed
    }

    if ($inCodeBlock) { . $addCodeBlock -Language $codeLanguage -CodeBlockLines $codeLines }
    . $flushParagraph
    . $flushList

    if ($content.Count -eq 0) { $content = @( (New-ParagraphNode -Values @($Text)) ) }

    return @{ type = "doc"; version = 1; content = $content }
}

# ---------------------------------------------------------------------------
# ADF -> text
# ---------------------------------------------------------------------------
function ConvertFrom-JiraAdf {
    param([object]$Node)
    if ($null -eq $Node) { return "" }
    $text = [System.Text.StringBuilder]::new()
    if ($Node.PSObject.Properties["text"]) { [void]$text.Append($Node.text) }
    if ($Node.PSObject.Properties["type"] -and $Node.type -eq "hardBreak") { [void]$text.AppendLine() }
    if ($Node.PSObject.Properties["content"] -and $Node.content) {
        foreach ($child in $Node.content) {
            $childText = ConvertFrom-JiraAdf -Node $child
            if ($Node.type -eq "paragraph" -or $Node.type -eq "heading") { [void]$text.Append($childText) }
            elseif ($Node.type -eq "listItem") { [void]$text.AppendLine("  - $($childText.Trim())") }
            elseif ($Node.type -eq "tableRow") { [void]$text.Append("| $($childText.Trim()) ") }
            else { [void]$text.Append($childText) }
        }
        if ($Node.type -eq "paragraph" -or $Node.type -eq "heading") { [void]$text.AppendLine() }
        if ($Node.type -eq "tableRow") { [void]$text.AppendLine("|") }
    }
    return $text.ToString()
}

function Get-JiraFieldText {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return "(none)" }
    if ($Value -is [string]) { return $Value }
    if ($Value -is [System.Array]) {
        $parts = @($Value | ForEach-Object { Get-JiraFieldText -Value $_ })
        return ($parts -join ", ")
    }
    if ($Value.PSObject.Properties["type"] -and $Value.type -eq "doc") { return (ConvertFrom-JiraAdf -Node $Value).Trim() }
    if ($Value.PSObject.Properties["displayName"]) { return $Value.displayName }
    if ($Value.PSObject.Properties["name"]) { return $Value.name }
    if ($Value.PSObject.Properties["value"]) { return $Value.value }
    return $Value.ToString()
}

# ---------------------------------------------------------------------------
# Search with pagination
# ---------------------------------------------------------------------------
function Search-JiraIssues {
    <#
    .SYNOPSIS
        Runs a JQL query through /rest/api/3/search/jql (the legacy /search endpoint was removed by
        Atlassian on 1 May 2025) and follows nextPageToken until MaxResults or the last page.
    #>
    param(
        [Parameter(Mandatory)][string]$Jql,
        [string[]]$Fields = @('summary', 'issuetype', 'status'),
        [int]$MaxResults = 100
    )

    $issues = @()
    $token = $null
    $pageSize = [Math]::Min(100, [Math]::Max(1, $MaxResults))
    $hasMore = $false
    do {
        $body = @{ jql = $Jql; fields = $Fields; maxResults = $pageSize }
        if ($token) { $body.nextPageToken = $token }
        $r = Invoke-JiraApi -Method Post -Path '/rest/api/3/search/jql' -Body $body -Context 'JQL search'
        if ($r.PSObject.Properties['issues'] -and $r.issues) { $issues += @($r.issues) }
        $token = $null
        if ($r.PSObject.Properties['nextPageToken'] -and -not [string]::IsNullOrWhiteSpace([string]$r.nextPageToken)) { $token = [string]$r.nextPageToken }
        $isLast = ($null -eq $token)
        if ($r.PSObject.Properties['isLast'] -and $r.isLast) { $isLast = $true }
        $hasMore = -not $isLast
    } while ($hasMore -and $issues.Count -lt $MaxResults)

    if ($issues.Count -gt $MaxResults) { $issues = $issues[0..($MaxResults - 1)] }
    return [pscustomobject]@{ Issues = @($issues); HasMore = $hasMore }
}

# ---------------------------------------------------------------------------
# Status guardrail and transitions
# ---------------------------------------------------------------------------
function Get-JiraAllowedStatuses {
    $raw = Get-AtlassianSetting -Key "JIRA_ALLOWED_STATUSES" -Default ""
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    return @($raw -split '[,;|\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}

function Assert-JiraStatusAllowed {
    param([Parameter(Mandatory)][string]$TargetStatus)
    $allowed = Get-JiraAllowedStatuses
    if ($allowed.Count -eq 0) {
        throw "No allowed Jira statuses configured. Set JIRA_ALLOWED_STATUSES (environment) or JiraAllowedStatuses (auth-settings.json) to the comma-separated list of statuses this skill may transition issues into."
    }
    $match = $allowed | Where-Object { $_ -ieq $TargetStatus } | Select-Object -First 1
    if (-not $match) { throw "TargetStatus '$TargetStatus' is not in JIRA_ALLOWED_STATUSES. Allowed: $($allowed -join ', ')" }
    return $match
}

function Find-JiraTransition {
    <#
    .SYNOPSIS
        Finds the transition that lands an issue in TargetStatus. Matches the destination status
        first (transition 'Start Review' -> status 'In Review'), then the transition name.
    #>
    param(
        [Parameter(Mandatory)][string]$IssueKey,
        [Parameter(Mandatory)][string]$TargetStatus
    )
    $t = Invoke-JiraApi -Path "/rest/api/3/issue/$IssueKey/transitions" -Context "Transitions for $IssueKey"
    $all = @()
    if ($t.PSObject.Properties['transitions'] -and $t.transitions) { $all = @($t.transitions) }
    $match = $all | Where-Object { $_.PSObject.Properties['to'] -and $_.to -and ($_.to.name -ieq $TargetStatus) } | Select-Object -First 1
    if (-not $match) { $match = $all | Where-Object { $_.name -ieq $TargetStatus } | Select-Object -First 1 }
    $available = @($all | ForEach-Object {
        $dest = ''
        if ($_.PSObject.Properties['to'] -and $_.to) { $dest = $_.to.name }
        "$($_.name) -> $dest"
    })
    return [pscustomobject]@{ Transition = $match; Available = $available }
}

# ---------------------------------------------------------------------------
# Input helpers
# ---------------------------------------------------------------------------
function Read-JiraTextInput {
    param([string]$Text, [string]$FilePath)
    if (-not [string]::IsNullOrWhiteSpace($FilePath)) {
        if (-not (Test-Path -LiteralPath $FilePath)) { throw "File not found: $FilePath" }
        return (Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8)
    }
    return $Text
}

function Read-JiraJsonFile {
    param([Parameter(Mandatory)][string]$FilePath)
    if (-not (Test-Path -LiteralPath $FilePath)) { throw "JSON file not found: $FilePath" }
    $raw = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
}
