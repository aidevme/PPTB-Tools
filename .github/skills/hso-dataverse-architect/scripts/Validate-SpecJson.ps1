<#
.SYNOPSIS
Fail-closed validator for the architect's spec.json against references/spec.schema.json.

.DESCRIPTION
Run before declaring a spec ready. Validates the structured sidecar every grader reads
(Grade-Metadata, Grade-SliceFidelity, Grade-SolutionExport, Assert-SpecFormsBuilt) so a
weak tier cannot emit an incomplete spec the graders silently mis-grade. The JSON Schema
(draft 2020-12) is authoritative; a few load-bearing rules are also reported explicitly for
a clearer message: the sampleData conditional, slices[].acceptance non-empty, forms[].timeline
present, the Main-form-requires-(layoutPattern+non-empty-tabs) rule (the schema if/then for this
may be inert on some pwsh builds, so it is hand-rolled here), the offline referential-integrity
block (every cross-reference resolves), and a Description-on-every-component reminder.

Also enforces the checked spec contracts:
- Declared-column cross-check: every forms[].header/section field and views[].column resolves
  to a declared columns[] entry (or a system column) — no invented or suffixed variants.
- Mandatory-pre-read citations: the markdown spec's "Sources, References, and Research
  Methodology" section must cite each mandatory SOP (with sections) for every area the
  spec.json shows the spec touches.
- Semantic-research gate: net-new custom tables require a dedicated semantic-research.md in
  the spec folder naming each new table.
- HITL <=> design (E2E round-3, HITL/OQ episode): mode HITL is legal only on a `design` slice
  and every design slice is HITL — build slices are AFK by definition.
- App membership (E2E round-3 F-02): every publisher-owned table the spec declares is a
  sitemap subArea entity or is listed in app.unsurfacedTables[] with a reason.
- Portal precondition (E2E round-3 s14): a slice whose touches name a portal / Power Pages
  surface declares a `power-pages-site` precondition the pipeline probes at Stage 0.
- Slice context budget (authoring rule 9, round-3 compaction evidence): estimates each build
  slice's executor weight from touches/acceptance and flags slices likely to blow the executor's
  context window - over-budget weight, code bundled with other artifacts, per-row data
  verification, '-and-' slice ids. Must-disposition: a flagged slice is split or carries
  budgetAccepted:"<reason>". Unsigned runs print flags as warnings; -Signed FAILS a flagged
  slice that has no recorded disposition (silence is not a valid state).

-Signed adds the SIGNED-SPEC gate the delivery pipeline runs at Stage 0: spec approval is
the authorization for every slice, so a signed spec carries zero HITL/design slices and no
Open Question whose status is still open (rows in the markdown "Open Questions" table whose
Status is not Resolved/Closed/Dispositioned).

Exits non-zero with per-violation messages on failure; prints a concise OK summary on success.

.PARAMETER SpecJsonPath
Path to the spec.json to validate.

.PARAMETER SchemaPath
Path to the schema. Defaults to references/spec.schema.json next to this script's skill root.

.PARAMETER SpecMarkdownPath
Path to the markdown spec whose Sources section is checked. Defaults to feature-spec.md or
spec.md in the spec.json folder.

.PARAMETER Signed
Validate as a SIGNED (approved / grilled) spec: additionally fail on any HITL or
design slice and on any open Open-Question row. The delivery pipeline's Stage-0 spec gate passes
this switch; the authoring architect runs without it while design nodes are still legitimately open.
#>
param(
    [Parameter(Mandatory)][string]$SpecJsonPath,
    [string]$SchemaPath = "$PSScriptRoot\..\references\spec.schema.json",
    [string]$SpecMarkdownPath,
    [switch]$Signed
)
$ErrorActionPreference = 'Stop'

function Fail($msg) { Write-Host "FAIL: $msg" -ForegroundColor Red }

if (-not (Test-Path $SpecJsonPath)) { Fail "spec.json not found at $SpecJsonPath"; exit 2 }
if (-not (Test-Path $SchemaPath))   { Fail "schema not found at $SchemaPath"; exit 2 }

$raw = Get-Content -Raw -Path $SpecJsonPath
try { $spec = $raw | ConvertFrom-Json } catch { Fail "spec.json is not valid JSON: $($_.Exception.Message)"; exit 2 }

$violations = New-Object System.Collections.Generic.List[string]
$warnings   = New-Object System.Collections.Generic.List[string]   # advisory only - printed, never fail the run

# Primary engine: JSON Schema (draft 2020-12). Test-Json reports each violation with a JSON pointer.
$schemaErrs = $null
$ok = Test-Json -Json $raw -SchemaFile $SchemaPath -ErrorVariable schemaErrs -ErrorAction SilentlyContinue
if (-not $ok) {
    foreach ($e in $schemaErrs) { $violations.Add(($e.ToString() -split "`n")[0].Trim()) }
}

# Hand-rolled load-bearing checks (clearer messages than the schema pointer for these specifics).
if ($spec.sampleData -and [bool]$spec.sampleData.inScope) {
    if (-not ($spec.sampleData.minRecords -ge 1)) { $violations.Add("sampleData.inScope is true but minRecords is not >= 1") }
    if ([string]::IsNullOrWhiteSpace("$($spec.sampleData.writerSlice)")) { $violations.Add("sampleData.inScope is true but writerSlice is empty") }
}

$si = 0
foreach ($s in @($spec.slices | Where-Object { $_ })) {
    $label = if ($s.id) { "slice '$($s.id)'" } else { "slice[$si]" }
    if ([string]::IsNullOrWhiteSpace("$($s.acceptance)")) { $violations.Add("$label has no acceptance text") }

    # --- HITL <=> design (E2E round-3 HITL/OQ episode): a build slice tagged HITL parks an unattended
    # run WaitingForClarification on a question the approved spec should have carried resolved.
    $sMode = "$($s.mode)"; $sType = "$($s.type)"
    if ($sMode -eq 'HITL' -and $sType -ne 'design') {
        $violations.Add("$label is mode HITL but type '$sType' - HITL is legal only on a design slice (an architect decision node settled at spec approval); a build slice is AFK, and its open decision belongs in Open Questions with disposition 'at spec approval'")
    }
    if ($sType -eq 'design' -and $sMode -ne 'HITL') {
        $violations.Add("$label is type design but mode '$sMode' - a design slice is a HITL decision node by definition")
    }
    if ($Signed -and ($sMode -eq 'HITL' -or $sType -eq 'design')) {
        $violations.Add("[SIGNED] $label is still $sType/$sMode - a signed spec carries zero HITL/design slices: spec approval IS the authorization for every slice, so settle the decision (record it, convert or drop the slice) before dispatch")
    }

    # --- Portal precondition (E2E round-3 s14): a slice whose touches name a portal surface must declare the
    # environment precondition the pipeline probes at Stage 0, so the run halts with a clear ask up front.
    if ("$($s.touches)" -match '(?i)power\s*pages|portal|adx_|powerpage|web\s*template|site\s*setting') {
        $hasPortalPre = @($s.preconditions | Where-Object { "$($_.kind)" -eq 'power-pages-site' }).Count -gt 0
        if (-not $hasPortalPre) { $violations.Add("$label touches a portal / Power Pages surface but declares no preconditions[] entry of kind 'power-pages-site' - name the site the target env must carry so Stage-0 preflight can probe it (round-3 s14 blocked mid-Stage-1 on a missing site)") }
    }
    foreach ($pc in @($s.preconditions | Where-Object { $_ })) {
        if ("$($pc.kind)" -eq 'other' -and [string]::IsNullOrWhiteSpace("$($pc.probe)")) { $violations.Add("$label precondition of kind 'other' has no probe - say how Stage 0 checks it") }
    }

    # --- Slice context budget (authoring rule 9; round-3 compaction evidence 2026-08-15): an executor pays
    # ~20 calls boarding + ~6 per create-and-verify artifact + ~15 per behavioral gate (three-path walk) +
    # a retry premium on code slices, and compacts (loses mid-slice detail) at ~100 calls. Every round-3
    # dispatch over ~105 calls compacted; every single-concern entity slice stayed intact.
    # The estimate is a TRIPWIRE, not truth: a flagged slice is either split or carries
    # budgetAccepted:"<reason>" (must-disposition, like an OQ row). Unsigned: flags print as warnings.
    # -Signed: a flagged slice with no budgetAccepted is a violation - silence is not a valid state.
    if ($sType -ne 'design') {
        $budgetFlags = New-Object System.Collections.Generic.List[string]
        $sText = "$($s.touches) $($s.acceptance)"
        $sPrefix = "$($spec.publisherPrefix)"
        $artifacts = 0
        if ($sPrefix -ne '') {
            $artifacts = @([regex]::Matches($sText, "\b${sPrefix}_\w+") | ForEach-Object { $_.Value.ToLowerInvariant() } | Sort-Object -Unique).Count
        }
        $isCode  = $sText -match '(?i)plugin|assembly|web\s*resource|form\s*script|\.js\b|\.cs\b'
        $gates   = @([regex]::Matches("$($s.acceptance)", '(?i)refus|reject|blocked|prevent|gate|transition\s+without|re-?fire')).Count -gt 0
        $perRow  = $sText -match '(?i)each\s+(row|record)|every\s+(row|record)|per-?(row|record)\s+verif|row\s*by\s*row'
        # Data-load premium: round-3 measured both load slices heavy regardless of table-token count
        # (s04 config load 126 calls with reconcile acceptance, s15 sample data 79) - CSV grooming,
        # batch scripting, phased passes and snapshots ride on every load. Rule 9 says loads split
        # per dataset/table, so a load slice tripping the wire and getting dispositioned is intended.
        $isLoad  = $sText -match '(?i)(config(uration)?|reference|sample|seed)[\s-]*(data|rows)|data[\s-]*load|load(ed|ing)?\b.{0,30}(csv|dataset|rows)|dataset'
        $est = 20 + (6 * $artifacts)
        if ($isCode) { $est += 30 }
        if ($gates)  { $est += 15 }
        if ($perRow) { $est += 20 }
        if ($isLoad) { $est += 50 }
        if ($sType -eq 'extension') { $est += 20 }   # OOB-surface probing overhead (round-3 s06: est 71 vs 125 actual without it)
        if ("$($s.id)" -match '(?i)-and-') {
            $budgetFlags.Add("id contains '-and-' - two concerns hiding in one slice? (round-3 s08 'contract-lifecycle-and-gate' bundled a lifecycle model with a behavioral gate and hit 183 executor calls, the run's worst compaction)")
        }
        if ($isCode -and $artifacts -gt 2) {
            $budgetFlags.Add("code-bearing but also touches $artifacts publisher artifacts - a plugin/script assembly's compile-test retry loops own the whole executor budget; make the code a slice by itself (rule 9)")
        }
        if ($perRow) {
            $budgetFlags.Add("acceptance reads as per-row verification - verify a data load by row-count + alternate-key reconcile against the curated source, never row by row (rule 9, round-3 s04 compacted at 126 calls)")
        }
        if ($est -ge 100) {
            $budgetFlags.Add("estimated executor weight ~$est calls (>=100, the round-3 compaction line) - split it: move the load, the walk, or the gate out (artifacts=$artifacts code=$isCode gate=$gates perRow=$perRow load=$isLoad; rule 9)")
        } elseif ($est -gt 70) {
            $budgetFlags.Add("estimated executor weight ~$est calls (budget ~70) - consider splitting (artifacts=$artifacts code=$isCode gate=$gates perRow=$perRow load=$isLoad; rule 9)")
        }
        if ($isLoad -and $artifacts -gt 2) {
            $budgetFlags.Add("data-load slice covering $artifacts publisher tables - rule 9 splits loads per dataset/table (round-3 s04 loaded eleven tables and compacted at 126 calls)")
        }
        $accepted = "$($s.budgetAccepted)"
        if ($budgetFlags.Count -gt 0) {
            if (-not [string]::IsNullOrWhiteSpace($accepted)) {
                $warnings.Add("$label over rule-9 budget, disposition RECORDED: '$accepted' (flags: $($budgetFlags.Count))")
            } else {
                foreach ($bf in $budgetFlags) { $warnings.Add("$label $bf") }
                if ($Signed) {
                    $violations.Add("[SIGNED] $label is flagged over the rule-9 context budget with no disposition - split the slice or record budgetAccepted:""<reason>"" on it; silence is not a valid state ($($budgetFlags.Count) flag(s), first: $($budgetFlags[0]))")
                }
            }
        } elseif (-not [string]::IsNullOrWhiteSpace($accepted)) {
            $warnings.Add("$label carries budgetAccepted but trips no rule-9 flag - stale disposition, drop it")
        }
    }
    $si++
}

$fi = 0
foreach ($f in @($spec.forms | Where-Object { $_ })) {
    $label = if ($f.table) { "form on '$($f.table)'" } else { "form[$fi]" }
    if ($null -eq $f.timeline) { $violations.Add("$label has no timeline verdict (true/false required)") }

    if ("$($f.type)" -eq 'Main') {
        if ([string]::IsNullOrWhiteSpace("$($f.layoutPattern)")) { $violations.Add("$label is Main but has no layoutPattern") }
        if (@($f.tabs | Where-Object { $_ }).Count -lt 1) { $violations.Add("$label is Main but has no non-empty tabs LayoutSpec") }
        if ($f.header -and @($f.header.fields).Count -gt 4) {
            $violations.Add("$label header declares $(@($f.header.fields).Count) fields (max 4)")
        }
        foreach ($t in @($f.tabs | Where-Object { $_ })) {
            $tl = if ($t.name) { "tab '$($t.name)'" } else { "a tab" }
            $sum = 0
            foreach ($lane in @($t.lanes | Where-Object { $_ })) {
                $sum += [int]("$($lane.width)" -replace '%','')
            }
            if ($sum -ne 100) { $violations.Add("$label $tl lane widths sum to $sum (must be 100)") }
        }
        $sectionTimeline = $false
        foreach ($t in @($f.tabs | Where-Object { $_ })) {
            foreach ($lane in @($t.lanes | Where-Object { $_ })) {
                foreach ($sec in @($lane.sections | Where-Object { $_ })) {
                    if ([bool]$sec.timeline) { $sectionTimeline = $true }
                }
            }
        }
        if ($sectionTimeline -and -not [bool]$f.timeline) {
            $violations.Add("$label has a section with timeline:true but the form's timeline verdict is false")
        }
    }
    $fi++
}

# Referential integrity (fully offline, fail-closed): every internal cross-reference must resolve.
$sliceIds = New-Object System.Collections.Generic.HashSet[string]
foreach ($s in @($spec.slices | Where-Object { $_ })) { if ($s.id) { [void]$sliceIds.Add("$($s.id)") } }

$tableNames = New-Object System.Collections.Generic.HashSet[string]   # a "real table" = appears in forms / views / relationships
foreach ($f in @($spec.forms | Where-Object { $_ })) { if ($f.table) { [void]$tableNames.Add("$($f.table)") } }
foreach ($v in @($spec.views | Where-Object { $_ })) { if ($v.table) { [void]$tableNames.Add("$($v.table)") } }
foreach ($r in @($spec.relationships | Where-Object { $_ })) {
    if ($r.parent) { [void]$tableNames.Add("$($r.parent)") }
    if ($r.child)  { [void]$tableNames.Add("$($r.child)") }
}

$relSchemaNames = New-Object System.Collections.Generic.HashSet[string]   # relationships carry no schema-name field today; gather any if present (forward-compatible)
foreach ($r in @($spec.relationships | Where-Object { $_ })) {
    foreach ($n in @($r.schemaName, $r.name) | Where-Object { "$_" -ne "" }) { [void]$relSchemaNames.Add("$n") }
}
$relNamesDeclared = $relSchemaNames.Count -gt 0   # only diff subgrid.relationship when a declared name set exists (else lenient)

foreach ($s in @($spec.slices | Where-Object { $_ })) {
    $label = if ($s.id) { "slice '$($s.id)'" } else { "a slice" }
    foreach ($b in @($s.blocked_by | Where-Object { "$_" -ne "" })) {
        if (-not $sliceIds.Contains("$b")) { $violations.Add("$label blocked_by references unknown slice '$b'") }
    }
}
foreach ($a in @($spec.assemblies | Where-Object { $_ })) {
    $label = if ($a.artifact) { "assembly '$($a.artifact)'" } else { "an assembly" }
    if ($a.writerSlice -and -not $sliceIds.Contains("$($a.writerSlice)")) { $violations.Add("$label writerSlice references unknown slice '$($a.writerSlice)'") }
    if ($a.subgridTarget -and -not $tableNames.Contains("$($a.subgridTarget)")) { $violations.Add("$label subgridTarget references unknown table '$($a.subgridTarget)'") }
}
foreach ($r in @($spec.relationships | Where-Object { $_ })) {
    if ($r.ownedBySlice -and -not $sliceIds.Contains("$($r.ownedBySlice)")) { $violations.Add("relationship '$($r.parent)'->'$($r.child)' ownedBySlice references unknown slice '$($r.ownedBySlice)'") }
}
if ($spec.sampleData -and $spec.sampleData.writerSlice -and -not [string]::IsNullOrWhiteSpace("$($spec.sampleData.writerSlice)")) {
    if (-not $sliceIds.Contains("$($spec.sampleData.writerSlice)")) { $violations.Add("sampleData.writerSlice references unknown slice '$($spec.sampleData.writerSlice)'") }
}
foreach ($sr in @($spec.statusReasons | Where-Object { $_ })) {
    if ($sr.table -and -not $tableNames.Contains("$($sr.table)")) { $violations.Add("statusReasons table '$($sr.table)' is not a real table (absent from forms/views/relationships)") }
    $defaults = @($sr.options | Where-Object { [bool]$_.default }).Count
    if ($defaults -gt 1) { $violations.Add("statusReasons for '$($sr.table)' has $defaults options with default:true (at most one allowed)") }
}
foreach ($f in @($spec.forms | Where-Object { $_ })) {
    $flabel = if ($f.table) { "form on '$($f.table)'" } else { "a form" }
    foreach ($t in @($f.tabs | Where-Object { $_ })) {
        foreach ($lane in @($t.lanes | Where-Object { $_ })) {
            foreach ($sec in @($lane.sections | Where-Object { $_ })) {
                if ($sec.subgrid) {
                    if ($sec.subgrid.target -and -not $tableNames.Contains("$($sec.subgrid.target)")) { $violations.Add("$flabel section '$($sec.name)' subgrid.target references unknown table '$($sec.subgrid.target)'") }
                    if ($relNamesDeclared -and $sec.subgrid.relationship -and -not $relSchemaNames.Contains("$($sec.subgrid.relationship)")) { $violations.Add("$flabel section '$($sec.name)' subgrid.relationship '$($sec.subgrid.relationship)' matches no declared relationships[] schema name") }
                }
            }
        }
    }
}
# Gather sitemap subArea ids + dashboard-bound subareas (for surfaced-via resolution).
$subAreaIds = New-Object System.Collections.Generic.HashSet[string]
$dashboardSubAreaIds = New-Object System.Collections.Generic.HashSet[string]
foreach ($area in @($spec.app.areas | Where-Object { $_ })) {
    foreach ($grp in @($area.groups | Where-Object { $_ })) {
        foreach ($sa in @($grp.subAreas | Where-Object { $_ })) {
            if ($sa.entity -and -not $tableNames.Contains("$($sa.entity)")) { $violations.Add("app subArea '$($sa.title)' entity references unknown table '$($sa.entity)'") }
            if ($sa.id) { [void]$subAreaIds.Add("$($sa.id)"); if ($sa.dashboard) { [void]$dashboardSubAreaIds.Add("$($sa.id)") } }
        }
    }
}

# --- App membership (E2E round-3 F-02, recurrence of round-2 F-03): 13 reference tables were built and never
# registered in the app. "Built" is not "in the app". Every publisher-owned table the spec declares (newTables[],
# forms[].table, views[].table) must be a sitemap subArea entity OR be recorded in app.unsurfacedTables[] with a
# reason (no nav node — still registered as a component by BuildSiteMap). Publisher prefix required to scope
# the check to owned tables (OOB extension tables are the OOB app's business).
$appPrefix = "$($spec.publisherPrefix)"
if ($appPrefix -ne '') {
    $subAreaEntities = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($area in @($spec.app.areas | Where-Object { $_ })) {
        foreach ($grp in @($area.groups | Where-Object { $_ })) {
            foreach ($sa in @($grp.subAreas | Where-Object { $_ })) { if ($sa.entity) { [void]$subAreaEntities.Add("$($sa.entity)") } }
        }
    }
    $unsurfaced = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($u in @($spec.app.unsurfacedTables | Where-Object { $_ })) {
        if ($u.table) { [void]$unsurfaced.Add("$($u.table)") }
        if ($u.table -and [string]::IsNullOrWhiteSpace("$($u.reason)")) { $violations.Add("app.unsurfacedTables entry '$($u.table)' has no reason - say how a persona reaches it") }
    }
    $specTables = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($nt in @($spec.newTables | Where-Object { "$_" -ne '' })) { [void]$specTables.Add("$nt") }
    foreach ($t in @($tableNames)) { [void]$specTables.Add("$t") }
    $ownedSpecTables = @(@($specTables) | Where-Object { $_ -like "${appPrefix}_*" })
    if ($ownedSpecTables.Count -gt 0) {
        if (-not $spec.app) {
            $violations.Add("spec declares publisher-owned tables ($($ownedSpecTables -join ', ')) but no app node - declare the app (mode create/extend) with a subArea per table, or app.unsurfacedTables[] with reasons; a table no app contains is built-but-unreachable (round-3 F-02)")
        } else {
            foreach ($t in $ownedSpecTables) {
                if (-not $subAreaEntities.Contains($t) -and -not $unsurfaced.Contains($t)) {
                    $violations.Add("table '$t' is declared by the spec but is neither a sitemap subArea entity nor listed in app.unsurfacedTables[] with a reason - every spec table is registered in the app and reachable, or its non-navigability is a recorded decision (round-3 F-02: 13 reference tables absent from the app)")
                }
            }
        }
    }
    foreach ($u in @($unsurfaced)) {
        if ($subAreaEntities.Contains($u)) { $violations.Add("app.unsurfacedTables lists '$u' but it also has a sitemap subArea - it is surfaced; drop the unsurfaced entry") }
    }
}

# Surfaced-via reachability (§1): every declared dashboard names how it is reached.
$dashboardNames = New-Object System.Collections.Generic.HashSet[string]
foreach ($d in @($spec.dashboards | Where-Object { $_ })) { if ($d.name) { [void]$dashboardNames.Add("$($d.name)") } }
foreach ($d in @($spec.dashboards | Where-Object { $_ })) {
    $dl = if ($d.name) { "dashboard '$($d.name)'" } else { "a dashboard" }
    $sv = "$($d.surfacedVia)"
    if ([string]::IsNullOrWhiteSpace($sv)) {
        $violations.Add("$dl has no surfacedVia (a dashboard subArea id, or 'unsurfaced: <reason>')")
    } elseif ($sv -notmatch '^unsurfaced:\s*\S') {
        if (-not $subAreaIds.Contains($sv)) { $violations.Add("$dl surfacedVia '$sv' is not a sitemap subArea id (nor 'unsurfaced: <reason>')") }
        elseif (-not $dashboardSubAreaIds.Contains($sv)) { $violations.Add("$dl surfacedVia '$sv' is a subArea that does not open a dashboard (set its `dashboard` to this dashboard)") }
    }
    if ($d.ownedBySlice -and -not $sliceIds.Contains("$($d.ownedBySlice)")) { $violations.Add("$dl ownedBySlice references unknown slice '$($d.ownedBySlice)'") }
}
# A dashboard subArea must point at a declared dashboard.
foreach ($area in @($spec.app.areas | Where-Object { $_ })) {
    foreach ($grp in @($area.groups | Where-Object { $_ })) {
        foreach ($sa in @($grp.subAreas | Where-Object { $_ })) {
            if ($sa.dashboard -and $dashboardNames.Count -gt 0 -and -not $dashboardNames.Contains("$($sa.dashboard)")) {
                $violations.Add("app subArea '$($sa.title)' dashboard '$($sa.dashboard)' is not a declared dashboards[] name")
            }
        }
    }
}

# Command surface (§10/§11): a user-invocable Custom API MUST declare its commandSurface (hand-rolled; the schema if/then can be inert on some pwsh builds).
foreach ($capi in @($spec.customApis | Where-Object { $_ })) {
    $cl = if ($capi.name) { "customApi '$($capi.name)'" } else { "a customApi" }
    if ([bool]$capi.userInvocable) {
        $cs = $capi.commandSurface
        if (-not $cs) {
            $violations.Add("$cl is userInvocable:true but declares no commandSurface (location + callingScript + ownedBySlice)")
        } else {
            if ([string]::IsNullOrWhiteSpace("$($cs.location)"))      { $violations.Add("$cl commandSurface has no location (FormCommandBar/MainGrid/SubGrid)") }
            if ([string]::IsNullOrWhiteSpace("$($cs.callingScript)")) { $violations.Add("$cl commandSurface has no callingScript (the web resource/JS that invokes the API)") }
            if ([string]::IsNullOrWhiteSpace("$($cs.ownedBySlice)"))  { $violations.Add("$cl commandSurface has no ownedBySlice (the ui-invocation slice that registers the command)") }
            elseif (-not $sliceIds.Contains("$($cs.ownedBySlice)"))   { $violations.Add("$cl commandSurface ownedBySlice references unknown slice '$($cs.ownedBySlice)'") }
        }
    }
}

$seenChoice = New-Object System.Collections.Generic.HashSet[string]
foreach ($c in @($spec.choices | Where-Object { $_ })) {
    if ($c.name) { if (-not $seenChoice.Add("$($c.name)")) { $violations.Add("choices has a duplicate name '$($c.name)'") } }
    $seenVal = New-Object System.Collections.Generic.HashSet[int]
    foreach ($o in @($c.options | Where-Object { $_ })) {
        if ($null -ne $o.value) { if (-not $seenVal.Add([int]$o.value)) { $violations.Add("choice '$($c.name)' has a duplicate option value '$($o.value)'") } }
    }
}

# === Checked spec contracts (E2E round-2 RCA) ===
$specDir = Split-Path -Parent (Resolve-Path $SpecJsonPath)

# --- Declared-column cross-check (findings run: the round-2 architect did this by hand; now mechanical).
# Every forms[].header/section field and views[].column must resolve to a declared columns[] entry,
# a system column, or the table's primary name column. Fail-closed: forms/views without a columns[]
# declaration are unverifiable and refused.
$columnsDeclared = $null -ne $spec.PSObject.Properties['columns']
$colsByTable = @{}
if ($columnsDeclared) {
    foreach ($c in @($spec.columns | Where-Object { $_ })) {
        if ($c.table -and $c.name) {
            $ct = "$($c.table)"
            if (-not $colsByTable.ContainsKey($ct)) { $colsByTable[$ct] = New-Object System.Collections.Generic.HashSet[string] }
            [void]$colsByTable[$ct].Add("$($c.name)")
        }
    }
}
$systemColumns = @('statecode','statuscode','createdon','modifiedon','createdby','modifiedby','ownerid','owningbusinessunit','owninguser','owningteam')
$primaryName = if ("$($spec.publisherPrefix)" -ne '') { "$($spec.publisherPrefix)_name" } else { $null }

if ((@($spec.forms | Where-Object { $_ }).Count -gt 0 -or @($spec.views | Where-Object { $_ }).Count -gt 0) -and -not $columnsDeclared) {
    $violations.Add("spec declares forms/views but no columns[] data-model declaration - declare every column ({table, name}) so form/view field references are mechanically checkable")
}

function Test-FieldRef([string]$table, [string]$field) {
    if ($script:systemColumns -contains $field) { return $true }
    if ($script:primaryName -and $field -eq $script:primaryName) { return $true }
    if ($script:colsByTable.ContainsKey($table) -and $script:colsByTable[$table].Contains($field)) { return $true }
    return $false
}

foreach ($f in @($spec.forms | Where-Object { $_ })) {
    $flabel = if ($f.table) { "form on '$($f.table)'" } else { "a form" }
    $ft = "$($f.table)"
    $fields = @()
    if ($f.header) { $fields += @($f.header.fields | Where-Object { "$_" -ne '' }) }
    foreach ($t in @($f.tabs | Where-Object { $_ })) {
        foreach ($lane in @($t.lanes | Where-Object { $_ })) {
            foreach ($sec in @($lane.sections | Where-Object { $_ })) { $fields += @($sec.fields | Where-Object { "$_" -ne '' }) }
        }
    }
    foreach ($fd in $fields) {
        if ("$fd" -like '*_name_auto') { $violations.Add("$flabel references '$fd' - the auto-number primary is the standard primary name column (never a '_name_auto' variant)") }
        elseif ($columnsDeclared -and -not (Test-FieldRef $ft "$fd")) { $violations.Add("$flabel field '$fd' does not resolve to a declared columns[] entry for table '$ft' (nor a system/primary column)") }
    }
}
foreach ($v in @($spec.views | Where-Object { $_ })) {
    $vlabel = if ($v.name) { "view '$($v.name)'" } else { "a view" }
    $vt = "$($v.table)"
    foreach ($vc in @($v.columns | Where-Object { "$_" -ne '' })) {
        if ("$vc" -like '*_name_auto') { $violations.Add("$vlabel references '$vc' - the auto-number primary is the standard primary name column (never a '_name_auto' variant)") }
        elseif ($columnsDeclared -and -not (Test-FieldRef $vt "$vc")) { $violations.Add("$vlabel column '$vc' does not resolve to a declared columns[] entry for table '$vt' (nor a system/primary column)") }
    }
}

# --- Mandatory-pre-read citation gate (finding #21): the markdown spec's Sources section must cite
# each mandatory SOP, with sections, for every area the spec.json shows the spec touches. SOPs load
# when a routing table mandates them, not only when a prompt names a technology - and the Sources
# table is the verifiable trace that the pre-read actually happened.
if (-not $SpecMarkdownPath) {
    foreach ($cand in @('feature-spec.md', 'spec.md')) {
        $p = Join-Path $specDir $cand
        if (Test-Path $p) { $SpecMarkdownPath = $p; break }
    }
}
if (-not $SpecMarkdownPath -or -not (Test-Path $SpecMarkdownPath)) {
    $violations.Add("markdown spec not found next to spec.json (looked for feature-spec.md / spec.md) - pass -SpecMarkdownPath; the mandatory-pre-read citation gate cannot run without it")
} else {
    $md = Get-Content -Raw -Path $SpecMarkdownPath

    # --- Open Questions gate (E2E round-3 HITL/OQ episode). Every OQ names its disposition point as "at spec
    # approval" — never "before slice sN is built" — and a SIGNED spec carries no open OQ. Format per
    # document-templates.md: a "## Open Questions" section with a table carrying Status + Disposition point
    # columns. Rows are judged by their Status cell (Open / Resolved / Closed / Dispositioned).
    $oqMatch = [regex]::Match($md, '(?m)^(#{2,4})\s+Open Questions')
    if ($oqMatch.Success) {
        $oqText = $md.Substring($oqMatch.Index)
        $lvl = $oqMatch.Groups[1].Value.Length
        $headingEnd = $oqText.IndexOf("`n"); if ($headingEnd -lt 0) { $headingEnd = $oqText.Length }
        $nextHeading = [regex]::Match($oqText.Substring($headingEnd), "(?m)^#{1,$lvl}\s+")   # section ends at the next heading of the same or a higher level
        if ($nextHeading.Success) { $oqText = $oqText.Substring(0, $headingEnd + $nextHeading.Index) }
        $oqRows = @(($oqText -split "`n") | Where-Object { $_ -match '^\s*\|' -and $_ -notmatch '^\s*\|\s*-{2,}' -and $_ -notmatch '(?i)^\s*\|\s*(id|#|oq|question)\s*\|' })
        foreach ($row in $oqRows) {
            $cells = @(($row.Trim().Trim('|') -split '\|') | ForEach-Object { $_.Trim() })
            $rowText = ($cells -join ' | ')
            if ($rowText -match '(?i)before\s+slice|before\s+s\d+\b|before\s+\S+\s+is\s+built|during\s+(the\s+)?build|at\s+build\s+time') {
                $violations.Add("Open Questions row gates a slice ('$($cells[0])'): '$rowText' - an OQ's disposition point is 'at spec approval', never 'before slice sN is built'; the approved spec carries the answer, the build never waits for it")
            }
            $isOpen = ($cells | Where-Object { $_ -match '(?i)^(open|pending|tbd|unresolved)$' }).Count -gt 0
            $isClosed = ($cells | Where-Object { $_ -match '(?i)^(resolved|closed|dispositioned|answered|decided)\b' }).Count -gt 0
            if ($Signed -and $isOpen -and -not $isClosed) {
                $violations.Add("[SIGNED] Open Questions row '$($cells[0])' is still open - a signed spec carries no open question: approval settles every OQ (record the answer or a dispositioned deferral with an owner) before dispatch")
            }
        }
    }

    $srcMatch = [regex]::Match($md, '(?m)^##\s+Sources')
    if (-not $srcMatch.Success) {
        $violations.Add("markdown spec has no 'Sources, References, and Research Methodology' section - it is the required mandatory-pre-read citation surface")
    } else {
        $sourcesText = $md.Substring($srcMatch.Index)
        $requiredSops = New-Object System.Collections.Generic.List[object]
        if (@($spec.forms).Count -or @($spec.views).Count -or @($spec.relationships).Count -or @($spec.choices).Count -or @($spec.statusReasons).Count -or $columnsDeclared) {
            $requiredSops.Add(@{ area = 'tables/columns/relationships/choices/lifecycle'; sop = 'data-modeling-best-practices.md'; sections = $true })
        }
        if (@($spec.forms | Where-Object { $_ }).Count)      { $requiredSops.Add(@{ area = 'forms';       sop = 'form-configuration-best-practices.md';      sections = $true }) }
        if (@($spec.views | Where-Object { $_ }).Count)      { $requiredSops.Add(@{ area = 'views';       sop = 'view-configuration-best-practices.md';      sections = $true }) }
        if ($spec.app)                                       { $requiredSops.Add(@{ area = 'app/sitemap'; sop = 'app-module-configuration-best-practices.md'; sections = $true }) }
        if (@($spec.dashboards | Where-Object { $_ }).Count) { $requiredSops.Add(@{ area = 'dashboards';  sop = 'dashboard-configuration-best-practices.md'; sections = $true }) }
        if (@($spec.customApis | Where-Object { $_ }).Count) { $requiredSops.Add(@{ area = 'custom APIs'; sop = 'custom-api-best-practices.md';              sections = $true }) }
        $touchText = (@($spec.slices | ForEach-Object { "$($_.touches)" }) -join ' ')
        if ($touchText -match 'plugin')                      { $requiredSops.Add(@{ area = 'plugins';     sop = 'plugin-development.md';                     sections = $true }) }
        if ($touchText -match 'flow')                        { $requiredSops.Add(@{ area = 'cloud flows'; sop = 'power-automate-cloud-flow-best-practices.md'; sections = $true }) }
        if ($touchText -match 'security|role')               { $requiredSops.Add(@{ area = 'security';    sop = 'security-best-practices.md';                sections = $true }) }
        $requiredSops.Add(@{ area = 'schema naming (always)'; sop = 'dataverse-naming-conventions.md'; sections = $false })
        foreach ($r in $requiredSops) {
            $citingLines = @(($sourcesText -split "`n") | Where-Object { $_ -match [regex]::Escape($r.sop) })
            if ($citingLines.Count -eq 0) {
                $violations.Add("Sources section does not cite mandatory pre-read '$($r.sop)' (spec touches $($r.area)) - cite it with the sections used")
            } elseif ($r.sections -and @($citingLines | Where-Object { $_ -match '§|[Ss]ection' }).Count -eq 0) {
                $violations.Add("Sources section cites '$($r.sop)' but names no sections (spec touches $($r.area)) - cite the sections used, e.g. §1, §9")
            }
        }
    }
}

# --- Semantic-research gate (finding #22): net-new custom tables require the dedicated skill-run
# artifact semantic-research.md in the spec folder. An inline self-authored summary does not satisfy
# the gate, and a client constraint narrows the decision - it does not waive the research.
$prefix = "$($spec.publisherPrefix)"
$ownedTables = @()
if ($prefix -ne '') { $ownedTables = @(@($tableNames) | Where-Object { $_ -like "${prefix}_*" }) }
$newTablesDeclared = $null -ne $spec.PSObject.Properties['newTables']
if ($ownedTables.Count -gt 0 -and -not $newTablesDeclared) {
    $violations.Add("spec declares publisher-owned tables ($($ownedTables -join ', ')) but no newTables[] declaration - list the net-new custom tables ([] when every owned table already exists); the semantic-research gate keys on it")
}
if ($newTablesDeclared -and @($spec.newTables | Where-Object { "$_" -ne '' }).Count -gt 0) {
    $srPath = Join-Path $specDir 'semantic-research.md'
    if (-not (Test-Path $srPath)) {
        $violations.Add("newTables declares net-new table(s) but the spec folder has no semantic-research.md - the dedicated artifact produced by running hso-semantic-data-modeling is required (an inline 'Semantic Research Summary' in the spec does not satisfy the gate)")
    } else {
        $srText = Get-Content -Raw -Path $srPath
        foreach ($nt in @($spec.newTables | Where-Object { "$_" -ne '' })) {
            if ($srText -notmatch [regex]::Escape("$nt")) { $violations.Add("semantic-research.md never mentions net-new table '$nt' - per-entity research is required for every net-new table") }
        }
    }
}

if ($warnings.Count -gt 0) {
    Write-Host "spec.json advisories ($($warnings.Count) warning(s) - not failures):" -ForegroundColor Yellow
    foreach ($w in $warnings) { Write-Host "  ! $w" -ForegroundColor Yellow }
}

if ($violations.Count -gt 0) {
    Write-Host "spec.json validation FAILED ($($violations.Count) violation(s)): $SpecJsonPath" -ForegroundColor Red
    foreach ($v in $violations) { Write-Host "  - $v" -ForegroundColor Red }
    Write-Host "Authoritative schema: $SchemaPath" -ForegroundColor Yellow
    Write-Host "Reminder: every component the spec proposes must carry a non-empty Description (SKILL.md Quality Standards)." -ForegroundColor Yellow
    exit 1
}

$slc = @($spec.slices).Count
$frm = @($spec.forms).Count
$sd  = if ($spec.sampleData) { "inScope=$([bool]$spec.sampleData.inScope)" } else { "absent" }
$signedNote = if ($Signed) { " [SIGNED gate passed: no HITL/design slices, no open OQ]" } else { "" }
Write-Host "OK: spec.json valid. solution=$($spec.solution) prefix=$($spec.publisherPrefix) slices=$slc forms=$frm sampleData=$sd$signedNote" -ForegroundColor Green
exit 0
