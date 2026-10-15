---
name: hso-salesforce-extractor
layer: atomic
scope: core
description: Extract a Salesforce org's configuration surface — objects, fields, picklists, relationships, record types, validation rules, profiles/permission sets, Apex, Flows — plus a data profile (row counts, fill rates) into a structured inventory for Dataverse replacement projects. Use when replacing or documenting a Salesforce org. Works from a live org (sf CLI) or an offline Metadata API export.
allowed-tools: Bash, Read, Write, Grep, Glob, AskUserQuestion
argument-hint: '[org-alias|package-path] [output-dir]'
---

# Salesforce Org Extractor

Turn a Salesforce org's configuration into a ranked, counted inventory in hours instead of
workshop-weeks. Salesforce exposes its entire configuration surface through APIs — objects,
fields, picklists, relationships, record types, validation rules, page layouts, profiles,
permission sets, Apex, and Flows — so none of it has to be re-discovered by interviewing users.
This skill is **Stage 1 (Extract)** of the SFDC → Dataverse replacement pipeline: it produces the
structured inventory that the semantic gate (`hso-semantic-data-modeling`) consumes before any
target model is designed.

## When to use

- Replacing a Salesforce org with Dynamics 365 CE / Dataverse and needing the source inventory
- Documenting a Salesforce org's schema, automation, or security model
- Sizing a migration: how many objects, fields, profiles, Apex classes, flows are actually in play
- Ranking technical debt: dead objects, zero-fill fields, inactive automation, unused record types

## When NOT to use

- **Executing the data migration** — record-level extract/transform/load belongs to the Stage-5
  migration toolchain (SSIS + KingswaySoft), not this skill. See Downstream below.
- **Designing the Dataverse target model** — that is `hso-semantic-data-modeling` (the research
  gate) followed by `hso-dataverse-architect`. This skill only feeds them.
- **Salesforce Marketing Cloud / B2C Commerce / MuleSoft** — different platforms, different APIs;
  out of scope.

## Input modes

| Mode | Input | Fidelity |
|------|-------|----------|
| **A — Live org** | sf CLI authenticated to the org | Full: schema + automation + security + data profile |
| **B — Offline package** | Metadata API export (mdapi or source format), unzipped | Schema, automation, security from XML; **no row counts or fill rates** |
| **C — Docs only** | ERDs, Schema Builder screenshots, data dictionaries | Degraded: no mechanical extraction — ingest via `hso-wiki-ingest-discovery-artifact` and hand-build the shortlist; state the fidelity cost in the deliverable |

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `org-alias` or `package-path` | Yes | sf CLI org alias (Mode A) or path to the unzipped metadata package (Mode B) |
| `output-dir` | No | Defaults to `agent/work/analysis/Salesforce_Extracted/<org-or-package-name>` |

If the org alias / package path is not given, ask — never assume an org.

## Prerequisites

- **Mode A:** Salesforce CLI v2 (`sf --version` to verify; install from
  <https://developer.salesforce.com/tools/salesforcecli>). Authenticate once with
  `sf org login web --alias <alias>` as a user with **API Enabled** and
  **View Setup and Configuration** (a read-only integration user is ideal — this skill never writes).
- **Mode B:** the unzipped export package. To request one from a client admin, send them the
  manifest instructions in [references/salesforce-extraction-reference.md](references/salesforce-extraction-reference.md) §6.

No values are read from `CLAUDE.md` / `CLAUDE.local.md` — the org alias is engagement-specific
and always supplied per run.

## Workflow

Each step notes who does the work: **[script]** = deterministic PowerShell, **[agent]** = Claude
runs commands / consolidates, **[human]** = a consultant decision the skill must not make.

1. **Resolve mode and scope** [agent]. Confirm org alias or package path and output directory.
   For very large orgs, agree the object scope up front (`all` vs `custom`).

2. **Schema sweep** [script]. Mode A:

   ```powershell
   powershell -File scripts/Export-SfSchema.ps1 -OrgAlias <alias> -OutputDir <output-dir>
   ```

   Produces `schema.json` (objects, fields with types and picklists, relationships, record
   types), `RawDescribes/*.json`, and `_extract_summary.json`. System-noise objects
   (`__Share`, `__History`, `__Feed`, `__Tag`, `__ChangeEvent`) are skipped by default;
   managed-package objects are skipped but their namespaces are recorded — see Critical Rules.
   Mode B: parse the package XML into the same `schema.json` shape — the element-to-property
   mapping is in the reference doc §5.

3. **Automation and code inventory** [agent]. Run the Tooling API / SOQL catalog from the
   reference doc §2 — Apex classes and triggers, Flows, validation rules, workflow rules —
   and consolidate counts plus listings into `automation.json`. Retrieve full source only for
   items shortlisted later; do not bulk-download an entire large org's Apex unprompted.

4. **Security model inventory** [agent]. Run the reference doc §3 queries — profiles,
   permission sets, assignment counts, active users per profile, object-permission summary —
   into `security.json`. Profile/permission-set conversion is one of the largest mechanical
   wins of a Salesforce replacement; this inventory is what the conversion estimate stands on.

5. **Data profile** [script, Mode A only]:

   ```powershell
   powershell -File scripts/Export-SfDataProfile.ps1 -OrgAlias <alias> `
       -SchemaJsonPath <output-dir>/schema.json -OutputDir <output-dir>
   ```

   Produces `data_profile.json`: org-wide row counts plus sampled fill rates and cardinality
   (≤200 rows per object, held in memory — aggregates only are written; see Critical Rules).
   Duplicate-density and orphan-reference checks are targeted per-object queries (reference
   doc §4) — run them for shortlisted objects, not the whole org.

6. **Ranked findings report** [agent → human]. Write `inventory.md` ranking, with counts:
   empty / near-empty objects, zero-fill fields, inactive validation rules and flows, unused
   record types, profiles with no active users, managed vs. local split, Apex staleness
   (old `ApiVersion`, size). Every item is a **candidate** — the human decides what is in
   scope, what is dead configuration, and what is technical debt not worth carrying.

7. **Handoff to the semantic gate** [agent]. For the human-approved shortlist, write
   `semantic_handoff.md` (shape below) and invoke `hso-semantic-data-modeling` per concept.

## Output structure

```
<output-dir>/
├── schema.json              # Objects, fields, types, picklists, relationships, record types
├── _extract_summary.json    # Counts, skips, managed namespaces, errors
├── RawDescribes/            # One raw describe JSON per object (Mode A)
├── automation.json          # Apex, Flows, validation rules, workflow rules
├── security.json            # Profiles, permission sets, assignments, object permissions
├── data_profile.json        # Row counts, fill rates, cardinality (Mode A only)
├── inventory.md             # Ranked findings for the human scope pass
└── semantic_handoff.md      # Shortlisted objects in the semantic-gate input shape
```

## schema.json format (condensed)

```json
{
  "org": "<alias>",
  "extracted_at": "2026-01-01T00:00:00Z",
  "source": "live-org | offline-package",
  "objects": [{
    "name": "Invoice__c",
    "label": "Invoice",
    "custom": true,
    "record_count": 120000,
    "fields": [{
      "name": "Status__c", "label": "Status", "type": "picklist",
      "nillable": false, "custom": true,
      "picklistValues": ["Draft", "Posted", "Paid"]
    }],
    "record_types": [{"developerName": "Standard", "available": true}]
  }],
  "relationships": [{
    "from_object": "Invoice__c", "field": "Account__c", "to_object": "Account",
    "relationship_name": "Invoices__r", "type": "lookup | master-detail"
  }],
  "skipped": {"system_noise": [], "managed_package": []},
  "errors": []
}
```

## Handoff contract → the semantic gate

**Authority for target-model research — `hso-semantic-data-modeling`; invoke it per shortlisted
concept before any Dataverse table is proposed from this inventory.** The gate's Step 2 expects,
per concept, exactly what this extract provides: the Salesforce object API name, its standard
fields, and its relationships. `semantic_handoff.md` lists one section per shortlisted object:

```markdown
## <Label> (`Api_Name__c`)
- Type: standard | custom · managed namespace if any
- Rows: <count> · top populated fields: <name:type, …> · dead fields: <n>
- Record types: <list or none>
- Relationships: <field → object (lookup|master-detail)>
- Automation attached: <n> validation rules, <n> triggers, <n> flows
- Disposition candidate: map-to-OOB / custom table / retire — proposed only; gate + human decide
```

The gate then answers the question this skill must never answer mechanically: *is there an OOB
Dataverse entity for this?* A naive migration maps `X__c` → custom table and reproduces the mess;
the gate is what makes the replacement better than a clone.

## Task → primary authority

| Task | Primary authority |
|------|-------------------|
| Command syntax for describe / Tooling / SOQL / Metadata retrieve, package-XML parsing, profiling query patterns | [references/salesforce-extraction-reference.md](references/salesforce-extraction-reference.md) — read before running Step 3–5 commands or parsing a Mode-B package |
| Deciding the Dataverse target model for any extracted object | `hso-semantic-data-modeling` (then `hso-dataverse-architect` for the spec) |
| Planning the record-data load (tooling, sequencing, throttling, rehearsals, PII scrubbing) | [Migration Strategy and Tooling SOP](../../../agent/wiki/sop/data-migration/migration-strategy-and-tooling-best-practices.md) — read when Stage 5 planning starts; **not needed for extraction itself** |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `sf: command not found` | Install Salesforce CLI v2; restart the shell |
| `NamedOrgNotFoundError` / expired token | `sf org login web --alias <alias>` again |
| `FIELDS(ALL)` query rejected | Requires `LIMIT ≤ 200` — the profile script caps `-SampleSize` at 200 |
| `INVALID_TYPE` on ApexClass / ValidationRule query | Those are Tooling API objects — add `--use-tooling-api` (`-t`) to `sf data query` |
| Describe sweep slow (1000+ objects) | Use `-ObjectScope custom`, `-SkipObjects`, or re-run with `-Resume` (skips objects already in `RawDescribes/`) |
| `recordCount` endpoint omits an object | Count is `null` — re-run with `-CountFallback` for per-object `SELECT COUNT()` (slow; only for objects that matter) |
| `REQUEST_LIMIT_EXCEEDED` | Daily API budget exhausted — check `sf limits api display -o <alias>`, resume the sweep later with `-Resume` |
| Client will not grant org access | Fall back to Mode B (metadata export) or Mode C (docs only); state the fidelity cost in the deliverable |

## Critical Rules

- **NEVER write to the org.** Extraction is strictly read-only: no DML, no `sf project deploy`,
  no metadata changes. If a script or command would modify the org, it does not belong here.
- **NEVER persist record-level data.** Profiling samples are held in memory and only aggregates
  (counts, fill rates, distinct counts) are written. Raw record extracts, if ever needed, belong
  to the Stage-5 migration toolchain with PII scrubbing under the migration SOP — not to this
  skill, and never to a git repo.
- **NEVER map extracted objects to Dataverse tables mechanically.** Every shortlisted object
  goes through `hso-semantic-data-modeling` first.
- **ALWAYS record managed-package namespaces** and keep managed internals out of the target-model
  shortlist by default — replacing an AppExchange product is a licensing/buy-vs-build decision
  for the human, not a schema-mapping task.
- **ALWAYS present dead-config findings as candidates** with counts, never as decisions — scope
  is the consultant's call.
- **ALWAYS ask before long or expensive runs** (full describe sweep on a 1000+ object org,
  `-CountFallback`, bulk Apex retrieval).

## References

- [references/salesforce-extraction-reference.md](references/salesforce-extraction-reference.md) —
  the command and mapping catalog: which API yields which artifact (§1), Tooling/SOQL query
  catalog for automation (§2) and security (§3), profiling query patterns (§4), Mode-B package
  XML parsing map (§5), and how to request a metadata export from a client admin (§6). Read the
  relevant section before running that workflow step; do not improvise API calls from memory.

## Related skills

- [hso-msaccess-extractor](../hso-msaccess-extractor/SKILL.md) — the same extraction shape for
  MS Access sources
- [hso-semantic-data-modeling](../hso-semantic-data-modeling/SKILL.md) — the mandatory downstream
  gate (see Handoff contract)
- [hso-dataverse-data-modeling](../hso-dataverse-data-modeling/SKILL.md) — builds the approved
  target schema in Dataverse

---

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-11 | maciejnowicki | Ported from prior in-house reference skills and neutralised for the reusable template (dropped internal license header, stripped stray project tags). |
