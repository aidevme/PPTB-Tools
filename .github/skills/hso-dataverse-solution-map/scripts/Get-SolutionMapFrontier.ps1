<#
.SYNOPSIS
    Reports the state of a Solution Map: the frontier, the blocked, the closed, and every
    integrity problem a hand-read of the folder would miss.

.DESCRIPTION
    There is no ticketing system behind a Solution Map -- the board is a folder of markdown
    tickets. This script is the authority on ticket state, so that "what is takeable right now"
    is a deterministic query rather than a model judgment (P19).

    It reports:
      * FRONTIER   -- open, unblocked, unclaimed tickets, in id order. What is takeable now.
      * CLAIMED    -- in flight, by whom.
      * BLOCKED    -- open tickets waiting on tickets that are not yet closed.
      * CLOSED     -- resolved, with the spine areas each disposed of.
      * OUT OF SCOPE
      * SPINE      -- the map's fifteen-area disposition table, and what is missing.

    And fails (exit 1) on:
      * a blocked_by pointing at a ticket id that does not exist
      * a dependency cycle
      * a duplicate ticket_id
      * a closed ticket carrying spine areas but no "Standards grounding" citation
      * a closed ticket with no "## Resolution" section
      * a ticket claimed but not in ticket_state: claimed (or the reverse)

.PARAMETER MapPath
    Path to the effort folder -- the directory containing map.md and tickets/.
    e.g. agent/work/design/solution-map/EFFORT-SLUG

.PARAMETER ReadyToClose
    Also assert the Close-mode preconditions: zero open/claimed tickets and zero spine areas
    still dispositioned 'fog'. Exit 1 if the map is not ready to close.

.PARAMETER Json
    Emit the full state as JSON instead of the human-readable report.

.EXAMPLE
    .\Get-SolutionMapFrontier.ps1 -MapPath agent/work/design/solution-map/EFFORT-SLUG

.EXAMPLE
    .\Get-SolutionMapFrontier.ps1 -MapPath agent/work/design/solution-map/EFFORT-SLUG -ReadyToClose
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MapPath,

    [switch]$ReadyToClose,

    [switch]$Json
)

$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

function Get-Frontmatter {
    <#  Minimal YAML frontmatter reader: scalars and inline [a, b] lists only,
        which is all the ticket contract uses. #>
    param([string[]]$Lines)

    $fm = @{}
    if ($Lines.Count -eq 0 -or $Lines[0].Trim() -ne '---') { return $fm }

    for ($i = 1; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ($line.Trim() -eq '---') { break }
        if ($line -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$') { continue }

        $key = $Matches[1]
        $val = $Matches[2].Trim()

        if ($val -match '^\[(.*)\]$') {
            $inner = $Matches[1].Trim()
            if ([string]::IsNullOrWhiteSpace($inner)) {
                $fm[$key] = @()
            }
            else {
                $fm[$key] = @($inner -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ })
            }
        }
        else {
            $fm[$key] = $val.Trim('"', "'")
        }
    }
    return $fm
}

function Get-ListValue {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [array]) { return @($Value) }
    if ([string]::IsNullOrWhiteSpace([string]$Value)) { return @() }
    return @([string]$Value)
}

# -----------------------------------------------------------------------------
# Load
# -----------------------------------------------------------------------------

$mapRoot = (Resolve-Path -LiteralPath $MapPath).Path
$mapFile = Join-Path $mapRoot 'map.md'
$ticketDir = Join-Path $mapRoot 'tickets'

if (-not (Test-Path -LiteralPath $mapFile)) {
    throw "No map.md found at '$mapFile'. -MapPath must point at the effort folder (the one containing map.md and tickets/)."
}

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

$tickets = @()
if (Test-Path -LiteralPath $ticketDir) {
    foreach ($file in Get-ChildItem -LiteralPath $ticketDir -Filter '*.md' -File | Sort-Object Name) {
        $lines = Get-Content -LiteralPath $file.FullName -Encoding UTF8
        $fm = Get-Frontmatter -Lines $lines
        $body = ($lines -join "`n")

        $id = [string]$fm['ticket_id']
        if ([string]::IsNullOrWhiteSpace($id)) {
            $errors.Add("$($file.Name): no ticket_id in frontmatter.")
            continue
        }

        $tickets += [pscustomobject]@{
            Id          = $id
            Title       = [string]$fm['title']
            File        = $file.Name
            Path        = $file.FullName
            Type        = [string]$fm['ticket_type']
            Mode        = [string]$fm['mode']
            State       = ([string]$fm['ticket_state']).ToLowerInvariant()
            ClaimedBy   = [string]$fm['claimed_by']
            BlockedBy   = Get-ListValue $fm['blocked_by']
            Spine       = Get-ListValue $fm['spine']
            WikiStatus  = [string]$fm['status']
            HasResolution = $body -match '(?m)^##\s+Resolution\s*$'
            HasCitation = $body -match '(?m)^\*\*Standards grounding\.\*\*'
        }
    }
}

# -----------------------------------------------------------------------------
# Integrity checks
# -----------------------------------------------------------------------------

$byId = @{}
foreach ($t in $tickets) {
    if ($byId.ContainsKey($t.Id)) {
        $errors.Add("Duplicate ticket_id '$($t.Id)': $($byId[$t.Id].File) and $($t.File).")
    }
    else {
        $byId[$t.Id] = $t
    }
}

$validStates = @('open', 'claimed', 'closed', 'out-of-scope')
foreach ($t in $tickets) {
    if ($t.State -notin $validStates) {
        $errors.Add("$($t.Id): ticket_state '$($t.State)' is not one of $($validStates -join ', ').")
    }

    foreach ($dep in $t.BlockedBy) {
        if (-not $byId.ContainsKey($dep)) {
            $errors.Add("$($t.Id): blocked_by references '$dep', which does not exist.")
        }
    }

    if ($t.State -eq 'claimed' -and [string]::IsNullOrWhiteSpace($t.ClaimedBy)) {
        $errors.Add("$($t.Id): ticket_state is 'claimed' but claimed_by is empty. The claim IS claimed_by.")
    }
    if ($t.State -eq 'open' -and -not [string]::IsNullOrWhiteSpace($t.ClaimedBy)) {
        $errors.Add("$($t.Id): claimed_by is set but ticket_state is still 'open'. Set ticket_state: claimed.")
    }

    if ($t.State -eq 'closed') {
        if (-not $t.HasResolution) {
            $errors.Add("$($t.Id): closed with no '## Resolution' section.")
        }
        if ($t.Spine.Count -gt 0 -and -not $t.HasCitation) {
            $errors.Add("$($t.Id): closed carrying spine area(s) [$($t.Spine -join ', ')] but no '**Standards grounding.**' citation. A citation you cannot honestly write means the pre-read did not happen.")
        }
        if ($t.WikiStatus -ne 'active') {
            $warnings.Add("$($t.Id): closed but wiki status is '$($t.WikiStatus)' -- a closed ticket's decision is live, so status should be 'active'.")
        }
    }

    if ($t.State -eq 'out-of-scope' -and $t.WikiStatus -ne 'archived') {
        $warnings.Add("$($t.Id): out-of-scope but wiki status is '$($t.WikiStatus)' -- should be 'archived'.")
    }
}

# Cycle detection (DFS over blocked_by)
$colour = @{}   # 0 = unvisited, 1 = in stack, 2 = done
foreach ($t in $tickets) { $colour[$t.Id] = 0 }

function Test-Cycle {
    param([string]$Id, [System.Collections.Generic.List[string]]$Stack)

    if ($colour[$Id] -eq 1) {
        $cycleStart = $Stack.IndexOf($Id)
        $cycle = $Stack.GetRange($cycleStart, $Stack.Count - $cycleStart) + $Id
        $script:errors.Add("Dependency cycle: $($cycle -join ' -> ').")
        return
    }
    if ($colour[$Id] -eq 2) { return }

    $colour[$Id] = 1
    $Stack.Add($Id)
    foreach ($dep in $byId[$Id].BlockedBy) {
        if ($byId.ContainsKey($dep)) { Test-Cycle -Id $dep -Stack $Stack }
    }
    $Stack.RemoveAt($Stack.Count - 1)
    $colour[$Id] = 2
}

foreach ($t in $tickets) {
    if ($colour[$t.Id] -eq 0) {
        Test-Cycle -Id $t.Id -Stack ([System.Collections.Generic.List[string]]::new())
    }
}

# -----------------------------------------------------------------------------
# Buckets
# -----------------------------------------------------------------------------

function Test-Unblocked {
    param($Ticket)
    foreach ($dep in $Ticket.BlockedBy) {
        if (-not $byId.ContainsKey($dep)) { return $false }
        if ($byId[$dep].State -ne 'closed') { return $false }
    }
    return $true
}

$frontier   = @($tickets | Where-Object { $_.State -eq 'open' -and (Test-Unblocked $_) } | Sort-Object Id)
$claimed    = @($tickets | Where-Object { $_.State -eq 'claimed' } | Sort-Object Id)
$blocked    = @($tickets | Where-Object { $_.State -eq 'open' -and -not (Test-Unblocked $_) } | Sort-Object Id)
$closed     = @($tickets | Where-Object { $_.State -eq 'closed' } | Sort-Object Id)
$outOfScope = @($tickets | Where-Object { $_.State -eq 'out-of-scope' } | Sort-Object Id)

# -----------------------------------------------------------------------------
# Spine dispositions from map.md
# -----------------------------------------------------------------------------

$spineAreas = @(
    'Business capability & process footprint', 'Product & module footprint',
    'Fit-gap: OOB vs custom', 'Conceptual data model & core entities',
    'Personas, security & access shape', 'Licensing & cost baseline',
    'Integration landscape', 'Data migration, config data & MDM',
    'Reporting & analytics', 'Extensibility posture (technology ladder)',
    'Environment strategy, topology & ALM', 'AI / Copilot leverage',
    'Non-functional: performance, volume, availability',
    'Delivery shape: phasing, testing, go-live', 'HSO IP & accelerator fit'
)
$validDispositions = @('resolved', 'ticketed', 'fog', 'out-of-scope', 'n/a')

$mapLines = Get-Content -LiteralPath $mapFile -Encoding UTF8
$mapFm = Get-Frontmatter -Lines $mapLines
$spine = @()

foreach ($line in $mapLines) {
    if ($line -notmatch '^\s*\|\s*(\d{1,2})\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*$') { continue }
    $n = [int]$Matches[1]
    if ($n -lt 1 -or $n -gt 15) { continue }
    $spine += [pscustomobject]@{
        Number      = $n
        Area        = $Matches[2].Trim()
        Disposition = $Matches[3].Trim().ToLowerInvariant()
        Note        = $Matches[4].Trim()
    }
}

$missingSpine = @()
$fogAreas = @()
for ($n = 1; $n -le 15; $n++) {
    $row = $spine | Where-Object { $_.Number -eq $n } | Select-Object -First 1
    if (-not $row -or [string]::IsNullOrWhiteSpace($row.Disposition)) {
        $missingSpine += "$n. $($spineAreas[$n - 1])"
        continue
    }
    if ($row.Disposition -notin $validDispositions) {
        $errors.Add("Spine area $n ('$($row.Area)'): disposition '$($row.Disposition)' is not one of $($validDispositions -join ', ').")
        continue
    }
    if ($row.Disposition -eq 'fog') { $fogAreas += "$n. $($row.Area)" }
    if ($row.Disposition -in @('out-of-scope', 'n/a') -and [string]::IsNullOrWhiteSpace($row.Note)) {
        $errors.Add("Spine area $n ('$($row.Area)'): '$($row.Disposition)' requires a reason in the last column. Silence is the omission the spine exists to catch.")
    }
}
if ($missingSpine.Count -gt 0) {
    $errors.Add("Spine areas with no disposition: $($missingSpine -join '; '). Every area gets one -- 'n/a' with a reason beats silence.")
}

# -----------------------------------------------------------------------------
# Close-mode preconditions
# -----------------------------------------------------------------------------

if ($ReadyToClose) {
    if ($frontier.Count -gt 0 -or $claimed.Count -gt 0 -or $blocked.Count -gt 0) {
        $errors.Add("Not ready to close: $($frontier.Count + $claimed.Count + $blocked.Count) ticket(s) still open or claimed.")
    }
    if ($fogAreas.Count -gt 0) {
        $errors.Add("Not ready to close: spine area(s) still at 'fog' -- $($fogAreas -join '; '). Graduate them to tickets or rule them out of scope with a reason; never synthesize over a gap.")
    }
}

# -----------------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------------

if ($Json) {
    [pscustomobject]@{
        map        = @{ path = $mapFile; status = [string]$mapFm['map_status']; effort = [string]$mapFm['effort_slug'] }
        frontier   = $frontier
        claimed    = $claimed
        blocked    = $blocked
        closed     = $closed
        outOfScope = $outOfScope
        spine      = $spine
        fogAreas   = $fogAreas
        errors     = @($errors)
        warnings   = @($warnings)
        ok         = ($errors.Count -eq 0)
    } | ConvertTo-Json -Depth 6
    exit ($(if ($errors.Count -eq 0) { 0 } else { 1 }))
}

function Write-Bucket {
    param([string]$Heading, $Items, [scriptblock]$Format)
    Write-Host ""
    Write-Host $Heading -ForegroundColor Cyan
    if (-not $Items -or $Items.Count -eq 0) {
        Write-Host "  (none)" -ForegroundColor DarkGray
        return
    }
    foreach ($i in $Items) { Write-Host ("  " + (& $Format $i)) }
}

Write-Host ""
Write-Host "Solution Map: $([string]$mapFm['title'])" -ForegroundColor White
Write-Host "  $mapFile"
Write-Host "  map_status: $([string]$mapFm['map_status'])   tickets: $($tickets.Count)"

Write-Bucket "FRONTIER  (takeable now -- open, unblocked, unclaimed)" $frontier {
    param($t) "$($t.Id)  [$($t.Type)/$($t.Mode)]  $($t.Title)"
}
Write-Bucket "CLAIMED   (in flight)" $claimed {
    param($t) "$($t.Id)  [$($t.Type)/$($t.Mode)]  $($t.Title)   -- claimed by $($t.ClaimedBy)"
}
Write-Bucket "BLOCKED" $blocked {
    param($t)
    $open = @($t.BlockedBy | Where-Object { -not $byId.ContainsKey($_) -or $byId[$_].State -ne 'closed' })
    "$($t.Id)  [$($t.Type)]  $($t.Title)   -- waiting on $($open -join ', ')"
}
Write-Bucket "CLOSED" $closed {
    param($t) "$($t.Id)  $($t.Title)   -- spine: $(if ($t.Spine.Count) { $t.Spine -join ', ' } else { '(none)' })"
}
Write-Bucket "OUT OF SCOPE" $outOfScope {
    param($t) "$($t.Id)  $($t.Title)"
}

Write-Host ""
Write-Host "SPINE" -ForegroundColor Cyan
if ($spine.Count -eq 0) {
    Write-Host "  (no decision-spine table found in map.md)" -ForegroundColor DarkGray
}
else {
    foreach ($row in ($spine | Sort-Object Number)) {
        $d = if ([string]::IsNullOrWhiteSpace($row.Disposition)) { '(none)' } else { $row.Disposition }
        $colour = switch ($d) {
            'resolved'     { 'Green' }
            'ticketed'     { 'White' }
            'fog'          { 'Yellow' }
            'out-of-scope' { 'DarkGray' }
            'n/a'          { 'DarkGray' }
            default        { 'Red' }
        }
        Write-Host ("  {0,2}. {1,-52} {2}" -f $row.Number, $row.Area, $d) -ForegroundColor $colour
    }
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "WARNINGS" -ForegroundColor Yellow
    foreach ($w in $warnings) { Write-Host "  $w" -ForegroundColor Yellow }
}

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "ERRORS" -ForegroundColor Red
    foreach ($e in $errors) { Write-Host "  $e" -ForegroundColor Red }
    Write-Host ""
    exit 1
}

Write-Host ""
if ($ReadyToClose) { Write-Host "Map is ready to close." -ForegroundColor Green }
else { Write-Host "No integrity errors." -ForegroundColor Green }
Write-Host ""
exit 0
