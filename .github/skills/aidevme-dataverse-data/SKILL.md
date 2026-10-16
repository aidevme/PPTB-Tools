---
name: aidevme-dataverse-data
layer: atomic
scope: core
description: |
  Query and manipulate Dataverse record data using the Web API. Use when:
  - Querying records with OData filters (e.g., "get all active solution areas", "find templates for F&O")
  - Getting a single record by ID
  - Counting records matching criteria
  - Creating records via the Web API
  - Updating existing records
  - Deleting records
  - Batch-creating multiple records in a single request
  - Running FetchXML queries against Dataverse
  - Associating/disassociating records via navigation properties
  Uses the same settings-resolved authentication with token caching as hso-dataverse-data-modeling.
---

# Dataverse Query Data Skill

Query and manipulate Dataverse record data (CRUD operations) using the Web API with settings-resolved authentication.

> ⚠️ **Authoring sample / demo / seed / test data? Use [`hso-dataverse-sample-data`](../hso-dataverse-sample-data/SKILL.md) — not this skill's `Create` / `BatchCreate`.** This skill is for **ad-hoc, one-off CRUD**: a single query, a manual patch, one or a few records. The moment you are authoring **more than a handful of records**, or the data must be **repeatable / version-controlled / re-seedable** (demos, presales, integration-test fixtures, training seeds), **stop and switch** — `hso-dataverse-sample-data` scaffolds the CSV + `manifest.psd1` + Import/Export/Remove trio and seeds idempotently by preserved GUID. Record-by-record `Create` from here is slow, non-repeatable, and not reviewable.

> **Companion reference — Power Pages**: making a record visible to a portal contact (entity-permission scope + the relationship field to set) and provisioning a local-auth portal login (copy `adx_identity_passwordhash`) → [references/power-pages-record-visibility-and-portal-login.md](references/power-pages-record-visibility-and-portal-login.md). Page/form/nav config lives in `hso-power-pages-config`.

## Task -> primary authority

This skill defers to several authoritative docs depending on the task. Land your task on the right authority before designing the operation:

| Task type | Primary authority (read first) |
|-----------|-------------------------------|
| Bulk transactional load | [Data Migration SOP family](../../../shared/dv/agent/wiki/sop/data-migration/) (defaults to SSIS + KingswaySoft) |
| Post-import patch / status transition / verification suite | [`powershell-script-based-migration-best-practices.md`](../../../shared/dv/agent/wiki/sop/data-migration/powershell-script-based-migration-best-practices.md) |
| CRUD on customer / contact / lead / product / location / worker master data | [Master Data Management SOP family](../../../shared/dv/agent/wiki/sop/master-data-management/) |
| Configuration reference-data upsert (`ConfigurationData/Datasets/`) | [`configuration-data-strategy.md`](../../../shared/dv/agent/wiki/sop/configuration-data/configuration-data-strategy.md) |
| Sample / seed data (`SampleData/Datasets/`) — **author via [`hso-dataverse-sample-data`](../hso-dataverse-sample-data/SKILL.md)**, not record-by-record here | [`sample-data-validation-workflow.md`](../../../shared/dv/agent/wiki/sop/sample-data/sample-data-validation-workflow.md) |
| FetchXML query authoring | `aidevme-fetchxml-queries` |

## Governed-data context (pipeline slice, bulk/migration, master data, configuration/sample)

When an operation is part of an **architect→builder pipeline slice**, a **migration workstream** (bulk write, status transition, post-cutover verification), targets **master data** (customer / contact / lead / product / location / worker), or upserts **configuration/sample data** (`ConfigurationData/Datasets/`, `SampleData/Datasets/`), read **[references/data-governance-context.md](references/data-governance-context.md)** before designing the operation. It carries the Slice Consumption Contract ([ADR 0018](../../../agent/wiki/decisions/0018-agentic-delivery-architect-builder-pipeline.md)), the authority pointers (Data Migration / MDM / Configuration-data / Sample-data SOP families), and the load-bearing digests — service-protection envelope, `CreateMultiple`/`$batch` contracts, `MSCRM.SuppressDuplicateDetection` on PATCH, the `0x80040333`-is-terminal rule, alternate-key idempotency, and the 3-phase config/sample upsert architecture. **Ad-hoc, one-off CRUD (a single query, a manual patch) does not need it** — it's governed by this skill's own standards below.

## Authentication

Authentication mode is resolved automatically from settings, using the same approach as `hso-dataverse-data-modeling`.

When browser sign-in is used:
1. First call opens a browser for Office 365 login
2. Token is cached at `%TEMP%\DataverseAuthCache_<hash>.json` (~1 hour validity)
3. Subsequent calls reuse the cached token automatically

The token cache is shared with `hso-dataverse-data-modeling` -- if you already authenticated there, no new login is needed.

## Script Path

```
.claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1
```

All examples below assume the working directory is the repository root.

## Configuration

Use values from `CLAUDE.md`:
- **EnvironmentUrl**: from CLAUDE.md (e.g., `https://yourorg.crm.dynamics.com`)
- Authentication mode is resolved automatically from settings

---

## 1. QUERY RECORDS

Retrieve records with OData query options.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation Query `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "accounts" `
    -Select "accountid,name" `
    -Filter "statecode eq 0" `
    -OrderBy "name"
```

### Query Parameters

| Parameter | Description |
|-----------|-------------|
| `-EntitySetName` | OData entity set name (e.g., `accounts`, `contacts`) |
| `-Select` | Comma-separated column list |
| `-Filter` | OData filter expression |
| `-OrderBy` | Sort columns (e.g., `name asc`) |
| `-Expand` | Navigation property expansion |
| `-Top N` | Limit to N records |
| `-Skip N` | Skip first N records |
| `-IncludeCount` | Include `@odata.count` in response |
| `-IncludeAnnotations` | Include formatted values and lookup display names |
| `-MaxPageSize N` | Max records per page (default 5000) |
| `-AllPages` | Follow `@odata.nextLink` to get all pages |
| `-OutputFile "path"` | Write JSON to file instead of stdout |
| `-Pretty` | Pretty-print (indent) the JSON. **Default is compact** (single-line) to save context |
| `-Raw` | Force compact JSON. Now the default for reads, so this is a no-op unless `-Pretty` is also in play |
| `-MaxInlineRows N` | Inline-print cap (default **200**). Above it, an **unbounded** query (no `-Top`/`-OutputFile`) spills to a temp file instead of stdout — see below |

> **Output is compact by default, and large unbounded results spill to a file.** `Query`/`Get`/`FetchXml`
> print **single-line** JSON now (add `-Pretty` if you want it indented). And when a `Query`/`FetchXml`
> returns **more than `-MaxInlineRows` (200) rows** and you gave neither `-Top` nor `-OutputFile`, the rows
> are written to `%TEMP%\dataverse-query-<set>-<n>rows.json` and the call prints a `[WARN]` + the column list
> + the file path **instead of dumping every row into context**. To get rows inline, pass `-Top N` (a sample),
> tighten `-Filter`, raise `-MaxInlineRows`, or read the spilled file. `-OutputFile` always writes exactly there.

### Common Filter Patterns

```
statecode eq 0                                        # Active records
_parentaccountid_value eq <guid>                      # By lookup GUID
contains(name,'keyword')                              # Name contains
statuscode eq 1                                       # By option set value
startswith(name,'Contoso')                            # Name starts with
```

### Referencing lookup columns (the `_value` rule)

How you name a lookup column depends on the operation — the single most common trip-up:

| Where | Form to use | Example |
|-------|-------------|---------|
| `$select` / `-Select` | `_<logicalname>_value` | `-Select "name,_primarycontactid_value"` |
| `$filter` / `-Filter` (Query/Get) | `_<logicalname>_value` | `-Filter "_parentaccountid_value eq <guid>"` |
| `$orderby` / `-OrderBy` | `_<logicalname>_value` | `-OrderBy "_parentaccountid_value"` |
| `$expand` / `-Expand` | the **navigation property** (bare logical name) | `-Expand "parentaccountid(\`$select=name)"` |
| **`Count` `-Filter`** (FetchXML) | the **bare logical name** | `-Filter "parentcustomerid eq <guid>"` |

The value reads back as `_<logicalname>_value`; with `-IncludeAnnotations` you also get the display name
and target table in the `@OData.Community.Display.V1.FormattedValue` / `...lookuplogicalname` annotations
(how you confirm a polymorphic customer resolved to an account vs a contact). **`Count` is the exception**
— it builds a FetchXML aggregate, which wants the bare logical name (`parentcustomerid`), the *opposite* of
`$filter`. The skill auto-rewrites a `_x_value` token in a Count filter to the logical name (with a
`[WARN]`), so a filter copied from a Query call still works — but prefer the logical name there directly.

### Expand (Related Records)

```powershell
-Expand "primarycontactid(`$select=fullname),parentaccountid(`$select=name)"
```

### Output to File

```powershell
-OutputFile "agent/work/build/query_results.json"
```

---

## 2. GET SINGLE RECORD

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation Get `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "accounts" `
    -RecordId "a1b2c3d4-5678-90ab-cdef-1234567890ab" `
    -Select "name,accountid"
```

---

## 3. COUNT RECORDS

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation Count `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "contacts" `
    -Filter "statecode eq 0 and parentcustomerid eq a1b2c3d4-5678-90ab-cdef-1234567890ab"
```

> **Count uses FetchXML**, so a lookup is referenced by its **bare logical name** (`parentcustomerid`),
> not the `_<x>_value` form that Query/`$filter` wants — the opposite convention. Passing a `_x_value`
> token here still works (the skill auto-rewrites it and emits a `[WARN]`), but use the logical name
> directly. See "Referencing lookup columns" under §1.

---

## 4. CREATE RECORD

> **`Create` is terse by default.** A successful create prints only `[OK] Record created` and `[ID] <guid>` —
> the full record body is **not** echoed back (it floods context, and a create rarely needs the row read
> back). To get the full created record, pass **`-ShowBody`** (or `-OutputFile "path"` to write it to a file).
> To capture *just* the new GUID into a variable, use `-ReturnId` (see the parent→child pattern below).

### Inline JSON

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation Create `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "accounts" `
    -JsonBody '{"name":"Contoso Ltd","revenue":50000.0,"industrycode":7}'
```

### From File

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation Create `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "accounts" `
    -JsonFilePath "agent/work/build/record.json"
```

### Setting Lookup Values in JSON

Use the `@odata.bind` syntax for lookups:

```json
{
    "name": "Contoso Ltd",
    "revenue": 50000.0,
    "industrycode": 7,
    "primarycontactid@odata.bind": "/contacts(a1b2c3d4-5678-90ab-cdef-1234567890ab)",
    "parentaccountid@odata.bind": "/accounts(b2c3d4e5-6789-01bc-def0-234567890abc)"
}
```

**Customer / polymorphic lookups bind a target-specific navigation property**, not the bare field. For a
Customer lookup `hsot_customer_id` you bind `hsot_customer_id_account` *or* `hsot_customer_id_contact`
depending on the target — never `hsot_customer_id@odata.bind`. A custom polymorphic lookup follows the same
`<field>_<target>` shape per target (e.g. `hsot_partyid_contact`). If unsure of the exact nav-property
names, run `QueryRelationships` (data-modeling skill) on the table that has the lookup — its **N:1**
section prints the **Bind Nav-Prop** (`ReferencingEntityNavigationPropertyName`) for each relationship,
and a polymorphic/Customer lookup lists one N:1 leg per target, so both `..._account` and `..._contact`
appear with their exact bind names — no raw `EntityDefinitions/ManyToOneRelationships` GET needed.

```json
{ "hsot_customer_id_account@odata.bind": "/accounts(<guid>)" }   // customer = an account
{ "hsot_customer_id_contact@odata.bind": "/contacts(<guid>)" }   // customer = a contact
```

### Parent → child seeding (capture the new id with `-ReturnId`)

> **Seeding a *dataset* (repeatable, many records)? Use [`hso-dataverse-sample-data`](../hso-dataverse-sample-data/SKILL.md)** — its manifest models parent/child dependency order and the trio seeds idempotently by preserved GUID. The pattern below is for **one-off** parent→child writes only.

When children must point back at a just-created parent (e.g. an agreement and its covered assets), capture
the parent's GUID with **`-ReturnId`** — which emits *only* the new GUID on stdout — then bind each child to
it:

```powershell
$skill = ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1"
$parentId = & powershell -ExecutionPolicy Bypass -File $skill `
    -Operation Create -EnvironmentUrl $env -EntitySetName "hsot_serviceagreements" `
    -JsonBody '{"hsot_agreementnumber_text":"AGR-001"}' -ReturnId
& powershell -ExecutionPolicy Bypass -File $skill `
    -Operation Create -EnvironmentUrl $env -EntitySetName "hsot_coveredassets" `
    -JsonBody "{`"hsot_assettag_text`":`"MOB-HVAC-001`",`"hsot_serviceagreement_id@odata.bind`":`"/hsot_serviceagreements($parentId)`"}"
```

Every `Create` also prints an `[ID] <guid>` line to the host for visibility; `-ReturnId` is what makes the
GUID cleanly capturable into a variable. `-ReturnId` reads the new id from the representation body
(`@odata.id`), the `OData-EntityId` header, **and** the primary-key field in the body — in that order — so
it is reliable across response shapes. If it genuinely can't find the id it now **fails loudly (exit 1)**
rather than returning empty, because the record was almost certainly created and a blind re-run would
duplicate it.

> **`BatchCreate` cannot do parent→child in one call** — it's a single transactional changeset, so a child
> can't reference a sibling created in the same batch. Use sequential `Create -ReturnId` for this shape (or
> batch all parents first, then a second batch of children bound to the now-known ids).

> ⚠️ **Report results honestly — never hand-roll an inline create loop that self-prints "all created".**
> Use `BatchCreate`/`BatchUpsert`: they report `N/M OK, K failed` per batch and now **exit non-zero when any
> record fails** (ADR 0025), so a partial/total failure surfaces instead of passing as success. A model-authored
> `foreach` that POSTs each record and prints a hard-coded success banner can mask a *total* failure (every
> Create rejected) — don't write one; call the batch op and trust its exit code.

> ⚠️ **Mid-sequence failure orphans the parent (no clean re-run).** Sequential `Create` is the only
> parent→child path, but plain `Create` has **no dedupe** — if a step *after* the parent fails, the parent
> exists with no children and you **cannot safely re-run the script** (it would create a second parent).
> Recover by querying the orphan's id back (filter on a field you set) and resuming from the children, not
> by re-running from the top.
> **Idempotent alternative — seed by alternate key (re-runnable).** For any table that carries an alternate
> key, upsert against the **alt-key URL** instead of `Create`, so the same seed script converges to the same
> end state on every run (the data-migration idempotency contract — see the Master-data context above). The
> **children** have a natural key (asset tag) and should be upserted; the **parent** (no natural key) needs a
> stable seed key first — give it an `hsot_legacyid` String column + alternate key via the data-modeling skill.
> The runnable recipe is below.
>
> ⚠️ **Which op actually does alt-key upsert:** the single **`Update`** op — it PATCHes `/<set>(<RecordId>)`,
> and a PATCH to an alt-key URL is a Dataverse **upsert** (creates the record when the key doesn't resolve,
> updates it when it does). So pass the key predicate *as* `-RecordId`: `-RecordId "hsot_assettag='TAG-1'"`.
> **`BatchUpsert` is NOT this path** — it upserts by **primary-key GUID** (`/<set>(<guid>)`), so it is
> idempotent only if *you* assign stable GUIDs yourself; it does not target alt-key URLs. (There is no
> separate `Upsert` operation.)

**Idempotent parent→child seed — worked example**

Prerequisite: the parent carries a stable seed key (`hsot_legacyid` + alternate key) and the child carries its
natural key (`hsot_assettag` + alternate key). Put each record's body in a JSON file — this sidesteps the
single-quote trap of an inline `@odata.bind` value like `(hsot_legacyid='SA-001')` inside a `'…'` PowerShell string.

```jsonc
// asset-TAG-1.json — child bound to its parent by the parent's ALT-KEY url (not a GUID)
{ "hsot_name": "Rooftop HVAC Unit 1",
  "hsot_serviceagreement_id@odata.bind": "/hsot_serviceagreements(hsot_legacyid='SA-001')" }
```

```powershell
# 1) Upsert each parent by its seed key (PATCH to the alt-key URL = create-if-absent, update-if-present)
... -Operation Update -EntitySetName "hsot_serviceagreements" -RecordId "hsot_legacyid='SA-001'" -JsonFilePath "agent/work/build/agreement-SA-001.json"

# 2) Upsert each child by its asset-tag key, binding to the parent via the parent's alt-key url (step-1 file above)
... -Operation Update -EntitySetName "hsot_coveredassets"   -RecordId "hsot_assettag='TAG-1'"   -JsonFilePath "agent/work/build/asset-TAG-1.json"
```

Re-running these exact commands is safe: no duplicate parents (the seed key resolves the existing one), no
asset-tag key violations (the child key resolves its existing row), and the child stays bound to the same parent.
`Update` prints a generic `[OK] Record updated` on both the create and the update leg of the upsert. Because each
`Update` is one record, loop over your seed set (a few `Update` calls per table); `BatchCreate`/`BatchUpsert`
remain the bulk path **when** you already hold stable ids and don't need alt-key resolution.

---

## 5. UPDATE RECORD

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation Update `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "accounts" `
    -RecordId "a1b2c3d4-5678-90ab-cdef-1234567890ab" `
    -JsonBody '{"revenue":75000.0}'
```

> **Duplicate detection is handled for you on master-data writes.** Writes to Dataverse's
> duplicate-detection-enabled master tables — **`accounts`, `contacts`, `leads`** — automatically send
> `MSCRM.SuppressDuplicateDetection: false` on `Create`, `Update`, `BatchCreate`, `BatchUpsert`, and
> `BatchPatch`, so dedupe rules fire even though the platform default **silently suppresses them on PATCH**
> ([duplicate-detection SOP §4.2 HSO Override](../../../shared/dv/agent/wiki/sop/master-data-management/duplicate-detection-best-practices.md#4-the-web-api-contract--mscrmsuppressduplicatedetection-and-0x80040333)).
> You do **not** need to add the header yourself, and a `[DEDUPE]` log line reports the value sent. For the
> deliberate bulk-migration case where detection must be skipped, pass **`-SuppressDuplicateDetection`**
> (sends `:true`) — it works on any of the five write ops. Writes to other tables are unaffected.
>
> **If a write is blocked as a duplicate** (`0x80040333`), the op **fails** (non-zero exit, including
> `BatchPatch`) and prints a `[HINT]` explaining that this is a **terminal** error — do **not** retry; route
> to a steward/dead-letter queue, or, to deliberately write anyway (which *will* create a duplicate), re-run
> with `-SuppressDuplicateDetection`.

---

## 6. DELETE RECORD

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation Delete `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "accounts" `
    -RecordId "a1b2c3d4-5678-90ab-cdef-1234567890ab"
```

**IMPORTANT:** Always confirm with the user before deleting records.

---

## 7. BATCH CREATE

Create multiple records in a single OData `$batch` request. All records succeed or fail together (transactional changeset).

### Inline JSON Array

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation BatchCreate `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "accounts" `
    -JsonArrayBody '[{"name":"Account 1","revenue":10000},{"name":"Account 2","revenue":20000}]'
```

### From JSON Array File

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation BatchCreate `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "accounts" `
    -JsonArrayFilePath "agent/work/build/records_batch.json"
```

**Parameters:**
- `-BatchSize` (default 200): records per changeset. The skill automatically chunks large arrays into sequential batches. Add progress reporting per batch.
- Requests include `Prefer: odata.continue-on-error` so partial failures are reported rather than rolling back the entire batch.

> **Building `-JsonArrayBody` with `ConvertTo-Json`? Use `-AsArray` for the single-record case.** `ConvertTo-Json`
> emits a JSON **object** (`{...}`), not an array (`[...]`), when given a one-element collection — so
> `$records | ConvertTo-Json` silently degrades to a non-array the moment a parent has exactly one child.
> Always write `$records | ConvertTo-Json -AsArray -Depth 10` so the body is `[ {...} ]` even for one record.
> (The skill parses defensively — `@($body | ConvertFrom-Json)` re-wraps a lone object — but emit a real
> array so the payload is correct regardless, and so a downstream consumer that *does* require `[...]` works.)

> **Important:** Dataverse does not support `PUT` inside OData `$batch` requests. Only `POST` (create),
> `PATCH` (upsert/update), and `DELETE` are valid. `PUT` returns HTTP 405.

---

## 7a. BATCH UPSERT

Create or update records with pre-specified GUIDs using PATCH inside `$batch`. Use this when you need to preserve known IDs (migrating from another system, loading reference data that other records link to).

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation BatchUpsert `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "hsosol_requirementsets" `
    -PrimaryKey "hsosol_requirementsetid" `
    -JsonArrayFilePath "agent/work/build/requirementsets.json" `
    -BatchSize 200
```

The JSON array must include the PK field with a GUID value. The skill strips the PK from the body and uses it in the PATCH URL: `PATCH /EntitySet(guid)`.

---

## 7b. BATCH PATCH

Bulk-update one or more fields on existing records matching a filter:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation BatchPatch `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "hsosol_plannodedefinitions" `
    -PrimaryKey "hsosol_plannodedefinitionid" `
    -Filter "hsosol_nodetype_code eq 168920000" `
    -FieldUpdatesJson '{"hsosol_level_num":1}' `
    -BatchSize 200
```

---

## PowerShell Gotchas

When working with data returned by `ConvertFrom-Json` (which returns `PSCustomObject`, not a hashtable):

```powershell
# WRONG -- returns $null, not an error
$value = $rec["fieldname"]

# CORRECT -- access property by dynamic name
$value = $rec.PSObject.Properties["fieldname"].Value

# CORRECT -- enumerate all properties
foreach ($prop in $rec.PSObject.Properties) { Write-Host "$($prop.Name) = $($prop.Value)" }

# CORRECT -- convert to hashtable when needed
$ht = @{}; $rec.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
```

This also applies to reading PK GUIDs in custom batch loops. Using `$rec[$pk]` returns `$null`; use `$rec.PSObject.Properties[$pk].Value`.

---

## 8. FETCHXML

Run a FetchXML query (useful for aggregations, linked entities, and complex queries not easily expressed in OData).

> **Authority for FetchXML syntax** (joins, aggregation, paging cookies, filter conditions, performance) — read before authoring a FetchXML query: `aidevme-fetchxml-queries`.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation FetchXml `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "accounts" `
    -FetchXml '<fetch top="10"><entity name="account"><attribute name="name"/><attribute name="revenue"/><filter><condition attribute="statecode" operator="eq" value="0"/></filter></entity></fetch>'
```

Or from a file:

```powershell
-FetchXmlFilePath "agent/work/build/my_query.xml"
```

---

## 9. ASSOCIATE / DISASSOCIATE

### Associate

Link two records via a navigation property (N:N or collection-valued):

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation Associate `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "accounts" `
    -RecordId "aaaa-..." `
    -NavigationProperty "contact_customer_accounts" `
    -TargetEntitySetName "contacts" `
    -TargetRecordId "bbbb-..."
```

### Disassociate

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/aidevme-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation Disassociate `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -EntitySetName "accounts" `
    -RecordId "aaaa-..." `
    -NavigationProperty "contact_customer_accounts" `
    -TargetRecordId "bbbb-..."
```

---

## Recipe: Sales Insights Assistant cards (`actioncard`)

The Sales Insights **Assistant** (the "Up Next" / insight-card stack on a record) stores its cards in the **`actioncard`** table. Out-of-box cards are generated by the platform on a daily cycle; **custom cards can be seeded directly via the Web API**, which is the most reliable way to put a specific card on a specific record for a demo or guided-action scenario.

**Prerequisites**
- The Sales Insights **Assistant must be enabled** in the environment, or nothing renders.
- A custom **card type** must exist and be enabled — a `cardtype` record with `isenabled = true` and a `cardtype` integer in the custom range (≥ 65536). When its `adaptivecardtemplate` is null, the card renders from the per-instance `title` / `description`.

**Seed one card** (create an `actioncard`):

```json
{
  "title": "Card headline shown in the Assistant",
  "description": "Body text shown under the headline.",
  "priority": 1000,
  "visibility": false,
  "source": 1,
  "cardtype": 65554,
  "startdate": "2026-01-01T08:00:00Z",
  "expirydate": "2026-01-08T23:59:00Z",
  "msdyn_regardingobjectid": "<record-guid>",
  "msdyn_regardingobjectlogicalname": "opportunity",
  "cardtypeid@odata.bind": "/cardtype(<cardtype-guid>)",
  "regardingobjectid_opportunity_actioncard@odata.bind": "/opportunities(<record-guid>)",
  "ownerid@odata.bind": "/systemusers(<user-guid>)"
}
```

**Gotchas (all verified):**
- **Irregular entity-set names:** `actioncard` → `actioncards`, but the card-type entity set is **singular `cardtype`** (not `cardtypes`).
- **Status uses `state`** (0 = Active), **not `statecode`** — selecting/filtering `statecode` errors.
- **Regarding is polymorphic.** Bind via the relationship nav property `regardingobjectid_<target>_actioncard` (e.g. `regardingobjectid_opportunity_actioncard`); confirm the exact name from `EntityDefinitions(LogicalName='actioncard')/ManyToOneRelationships`. Also set the plain string fields `msdyn_regardingobjectid` + `msdyn_regardingobjectlogicalname`. `parentregardingobjectid` auto-mirrors from `regardingobjectid` — don't set it.
- **`ownerid` drives who sees the card** — set it to the target user (the card is owner-scoped even though `createdby` is the connection account).
- **24-hour default expiry.** Cards expire fast; set `expirydate` explicitly for anything that must survive to a demo day.
- **`$batch` creates hang silently** — the rows commit server-side but the request never returns. **Use single `Create` calls**, or seed then verify with a `Query` on `cardtype eq <n>` filtered by `createdon`.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| 401 Unauthorized | Token may be expired; rerun the command and let auth resolve automatically from settings |
| 404 Not Found | Check EntitySetName spelling (plural form) |
| 400 Bad Request | Check filter syntax or JSON payload format |
| Empty results | Verify filter includes `statecode eq 0` for active records |
| Lookup bind error | Use `"field@odata.bind": "/entityset(guid)"` syntax |
| Large result set | An unbounded `Query`/`FetchXml` over 200 rows auto-spills to a temp file (printed path) instead of stdout. Use `-Top N` for a sample, `-OutputFile` to choose the path, `-AllPages` to follow paging, or `-MaxInlineRows N` to change the cap |
| `0x80040333` returned as HTTP 500 | Duplicate detected — terminal error per [duplicate-detection SOP §4.3](../../../shared/dv/agent/wiki/sop/master-data-management/duplicate-detection-best-practices.md#4-the-web-api-contract--mscrmsuppressduplicatedetection-and-0x80040333). Do not retry; route to dead-letter / steward queue. |

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
