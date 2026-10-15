---
name: hso-analyze-system-review
layer: orchestration
scope: core
description: 'Live, read-only as-is review of an existing Dynamics 365 / Dataverse (CE) system. Harvests metadata (tables, fields, forms+JS libraries/events, views, workflows/flows, web resources, apps, dashboards, security) into JSON, then produces two tiers — a technical Excel inventory + Risk Register (HSO internal) and a comprehensive client-facing Client System Review Word document. Findings: unused searchable fields, classic-workflow→Power-Automate, duplicate active main forms (app inclusion), form field population %, custom JS/plugin/workflow risks, security/ISV snapshot. Use for "review this system", as-is assessment, inherited-client onboarding, ground-to-cloud, or a health check. Not a solution diff (hso-analyze-dataverse-solution-changes) and not F&O/ERP-internal.'
---

# HSO System Review (As-Is / Health Assessment)

Produce a current-state baseline + actionable hygiene/enhancement findings for an **existing** Dataverse (CE)
system. Read-only. Built on **live metadata** (managed ISV/Microsoft solutions can't be exported).

Methodology + finding definitions + caveats live in the SOP:
[Dataverse System Review Methodology](../../../agent/wiki/sop/system-review/dataverse-system-review-methodology.md).
Read it first — this skill executes it.

## Two-tier output
- **Tier 1 — Technical pack (HSO internal):** a multi-sheet **Excel** inventory (Tables, Fields, Forms +JS
  libraries/events, Views, Web Resources/JS, Workflows, Flows, Business Rules, Actions, Plugins, Apps,
  Dashboards, Charts, Solutions, Security-Org) **+ a Risk Register** sheet. Built by `Build-TechnicalPack.py`.
- **Tier 2 — Client System Review (present):** one **comprehensive** client-facing **Word** document via
  `hso-engagement-deliverables`, PLUS any client-safe supporting artifacts bundled alongside it (redacted risk
  summary, form-simplification field list, flow inventory) when they exist. Exec/IT level, no raw internal counts.

### Client System Review — standard section set (fixed template)
The client doc is a **fixed comprehensive template**, not a hand-picked subset — this prevents silent omission
(and over-statement, e.g. reporting dormant ISV scaffolding as a live integration). **Trim by marking a
section "Not assessed (out of scope this phase)", never by deleting it** — a marked section makes the coverage
gap visible to the client. Standard sections, in order:
1. Purpose · 2. What the system looks like today (footprint) · 3. Architecture at a glance (diagram) ·
4. Data model at a glance (diagram) · 5. Business capabilities · 6. Reporting & dashboards ·
7. **Integrations** (validated — POTENTIAL-flag the unconfirmed; see Critical rules) · 8. Environments & release ·
9. Licensing & users · 10. Data volumes · 11. Findings (the requested hygiene checks) ·
12. Field usage & form population · 13. Key risks · 14. Security model (summary) ·
15. Other opportunities / quick wins · 16. Known issues & open items ·
17. **Scope of this review — what was and wasn't assessed** (a client-facing coverage ledger; derive from the
    net-new-client checklist / SOP Appendix — mark each area Assessed / Summary-only / Not-assessed) ·
18. Recommended next steps · 19. Glossary · 20. Document Control / Change Record.

**Default run:** scope to the **primary app** (`-AppName`) and include the **risk** passes. Override per
engagement: scope (app / all custom+ISV / everything) and depth (inventory-only / +risk / full incl. % populated
+ security matrix). One harvest → JSON cache → both tiers derive offline (cost-effective).

## When to use this skill
- Onboarding onto an inherited client; pre-project or phase-gate health check.
- "Review the full system", "what does this system look like now", "as-is assessment", "find unused
  fields / forms / workflows", "which classic workflows should be flows", "how populated are the forms".

## When NOT to use
- Diffing solutions/branches or running Solution Checker alone → `hso-analyze-dataverse-solution-changes`.
- Designing a new feature → `hso-dataverse-architect`. Documenting one solution → `hso-solution-documentation`.
- F&O / other-ERP **internal** review → out of scope (see SOP §8 placeholders / a future sibling skill).

## Configuration
Read from `CLAUDE.md`: **Environment URL** · **Publisher Prefix** (client prefix) · primary **app name**.
Read from `CLAUDE.local.md`: **Author Name** · (ADO **Org/Project** + code repo, for the code-health pass).
**Ask** (never assume): prefix ownership (client vs ISV vs Microsoft); key tables + key forms for the
population pass; environment to target.

## Prerequisites
- Auth to the target org via `hso-dataverse-auth-azcli` (cross-tenant client orgs: use a **client-tenant**
  account with a security role; the HSO guest often has none — verify the token `unique_name`).
- For the code-health pass: a clone of the client's source repo (plugins / web resources / PCF).

## Workflow

1. **Frame & scope** (SOP §1–2). Confirm environments, access, prefix ownership, and the primary app.
2. **Harvest metadata** — `scripts/Harvest-DataverseMetadata.ps1`. Resolves in-scope tables (app component
   set if `-AppName`, else in-scope solutions), then: attributes (searchable flags), forms (+field refs,
   type/activation/app-inclusion, **JS libraries/handler functions/event triggers**), views (+field refs),
   **workflows/flows by solution membership** (classic/BR/action/BPF/flow + definition refs), **web resources
   by prefix** (the custom layer is often *managed* — filter by `contoso_/<isv>_/…` prefix, NOT `ismanaged`),
   **apps**, **dashboards/charts**, security/org snapshot, ISV/solution catalog → JSON under `<out>/metadata/`.
3. **Code tokens** (optional) — grep the client repo for prefixed field tokens; feed to step 4.
4. **Derive findings** — `scripts/Analyze-SystemFindings.ps1` → registers (CSV+JSON) for findings 1–3.
5. **Form field population** — `scripts/Analyze-FormFieldPopulation.ps1 -Map @{table='Form Name';...}` →
   % populated per field on each key form (3-year window auto-applied on tables with >3y history).
6. **Risk Register** — `scripts/Analyze-SystemRisks.py <meta> risks.json --code <repo> --client-prefix <p>`
   → consolidates JS (`Xrm.Page`/sync-XHR/`alert`/DOM/hardcoded-URL), plugin (`ColumnSet(true)`, framework
   drift, `Console.Write`), workflow→flow + deprecated dialogs, oversized/duplicate forms, unused searchable
   fields, and security (flat BU, no client field-security) into one severity-rated register.
7. **Technical pack (Tier 1)** — `scripts/Build-TechnicalPack.py <meta> out.xlsx [risks.json]` → the Excel
   inventory + Risks sheet (HSO-branded).
8. **Client doc (Tier 2)** — compose the current-state Word + risk/security summary via
   `hso-engagement-deliverables`. Orchestrate for depth: `hso-dataverse-securityrole` (full role matrix),
   `hso-dataverse-flow-docs`, `hso-analyze-dataverse-solution-changes` (Solution Checker), `hso-plugin-code-review`.

## Operations Reference

```powershell
# 0. ONE COMMAND — full technical tier (harvest -> findings -> [population] -> risks -> Excel pack)
pwsh -File scripts/Invoke-SystemReview.ps1 -EnvironmentUrl <url> -AppName "<App>" -ClientPrefix contoso `
    -IsvPrefixes isv1,isv2 -OutDir <out> -CodeRepo <client-repo> -Interactive
#   (auth must be cached first via hso-dataverse-auth-azcli; add -PopulationMap @{opportunity='Main'} to include % populated)

# --- or run the steps individually ---
# 2. Harvest (app-scoped)
powershell -File scripts/Harvest-DataverseMetadata.ps1 -EnvironmentUrl <url> -AppName "<App>" `
    -ClientPrefix contoso -IsvPrefixes isv1,isv2 -OutDir <out>\metadata -Interactive

# 4. Findings (forms+views+code+workflow as the "referenced" set; pass -ReferencedSources to narrow)
powershell -File scripts/Analyze-SystemFindings.ps1 -MetaDir <out>\metadata -CodeTokensPath <out>\code_tokens.txt -OutDir <out>\findings

# 5. % populated for key forms
powershell -File scripts/Analyze-FormFieldPopulation.ps1 -EnvironmentUrl <url> `
    -Map @{ opportunity='Main'; account='Main' } -OutDir <out>\findings -Interactive

# 6. Risk Register (JSON) — code scan optional but recommended
python scripts/Analyze-SystemRisks.py <out>\metadata <out>\risks.json --code <repo> --client-prefix contoso

# 7. Technical pack (Excel) — pass risks.json to populate the Risks sheet
python scripts/Build-TechnicalPack.py <out>\metadata <out>\Contoso_Technical_Pack.xlsx <out>\risks.json
```

### Optional deep-dives (add depth; all feed the pack/risks)
```powershell
# Security role matrix — client/custom roles -> Security Roles sheet + org-level write/delete risk
powershell -File scripts/Harvest-SecurityRoleMatrix.ps1 -EnvironmentUrl <url> -RoleNameContains Contoso -OutDir <out>\metadata -Interactive
# Relationships -> Relationships sheet + feeds the conceptual ERD (hso-engagement-deliverables/Build-ERDDiagram.py)
powershell -File scripts/Harvest-Relationships.ps1 -EnvironmentUrl <url> -MetaDir <out>\metadata -ClientPrefix contoso -IsvPrefixes isv1,isv2 -Interactive
# Environment drift — diff two SAME-SCOPE harvests (Dev/QA/Prod) -> drift_* CSVs + report
python scripts/Compare-Environments.py <devMeta> <qaMeta> <out>\drift\dev-vs-qa Dev QA
# Offline best-practice scan of exported solution .zips (auth-free; complements live `pac solution check`)
python scripts/Analyze-SolutionArtifacts.py <zipsDir> <out>\metadata   # writes checker_summary.json -> Solution Checker risks
```
> Live Microsoft Solution Checker (`pac solution check --path <zip> --geo UnitedStates -o <dir>`) needs a **fresh interactive `pac auth create`**; the offline scan above is the fallback when CA blocks non-interactive pac sign-in.

PowerShell scripts: `-Interactive` for MSAL auth via `hso-shared-scripts`. Python scripts (`Build-TechnicalPack`,
`Analyze-SystemRisks`): need `openpyxl` + `python-docx`; read the harvest JSON offline (no re-query, no creds).

## Critical rules
- **DO** state the "referenced" source set, the counting method, and the population window in the report.
- **DO** segment every finding by layer (client / ISV / Microsoft) — only client-owned items are deletable.
- **DO** resolve form app-inclusion via `RetrieveAppComponents` before calling a form a user-facing duplicate.
- **DO NOT** auto-delete from finding 1 — validate against rollup/calc formulas, charts, Power BI first.
- **DO NOT** use `/$count` (caps at 5000); use FetchXML `countcolumn` aggregates (SOP §5).
- **DO NOT** claim "accessible to everyone" from the API — form role-scoping isn't API-readable; confirm in maker.
- **DO NOT** list an integration as live from mere presence of its fields/entities/named workflow — ISV
  products ship dormant scaffolding (e.g. an ISV's F&O Id / Create in F&O columns) for systems the client
  doesn't run. **Validate** each candidate: flow/workflow active? connection reference configured? mapped
  fields actually populated (population pass)? endpoint/credential present? If unconfirmed from metadata,
  mark it **POTENTIAL (unconfirmed — verify with client)** and add to the client-confirmation list — never
  assert it as current (SOP §8a).

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
