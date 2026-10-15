# Salesforce Extraction Reference

Command and mapping catalog for `hso-salesforce-extractor`. Read the section matching the
workflow step before running its commands — do not improvise API calls from memory. All commands
are **read-only**.

## §1 Extraction surface map — which API yields what

| Artifact | API | How this skill gets it |
|----------|-----|------------------------|
| Objects, fields, types, picklists, relationships, record types | sObject `describe` (REST) | `Export-SfSchema.ps1` (sf CLI `sobject describe`) |
| Row counts | REST `limits/recordCount` | `Export-SfDataProfile.ps1` |
| Fill rates, cardinality | SOQL `FIELDS(ALL)` sample | `Export-SfDataProfile.ps1` |
| Apex classes / triggers | Tooling API SOQL | §2 queries |
| Flows / Process Builder | `FlowDefinitionView` (standard SOQL) | §2 queries |
| Validation rules, workflow rules | Tooling API SOQL | §2 queries |
| Profiles, permission sets, assignments | Standard SOQL | §3 queries |
| Object/field permission matrix | `ObjectPermissions` / `FieldPermissions` SOQL | §3 queries |
| Full metadata source (layouts, Apex bodies, flow XML) | Metadata API | §6 retrieve — targeted only |

`sf data query` runs standard SOQL; add `--use-tooling-api` (`-t`) for Tooling API objects.
Add `--json` and parse `result.records` (strip each record's `attributes` property).

## §2 Automation and code inventory queries

Consolidate the results into `automation.json` as `{apex_classes, apex_triggers, flows,
validation_rules, workflow_rules}`, each with a count and a listing.

```bash
# Apex classes — local (non-managed) only; LengthWithoutComments + ApiVersion signal staleness/size
sf data query -t --json -o <alias> -q "SELECT Name, ApiVersion, Status, LengthWithoutComments FROM ApexClass WHERE NamespacePrefix = null ORDER BY Name"

# Apex triggers — TableEnumOrId names the object the trigger fires on
sf data query -t --json -o <alias> -q "SELECT Name, TableEnumOrId, ApiVersion, Status FROM ApexTrigger WHERE NamespacePrefix = null ORDER BY TableEnumOrId"

# Flows and Process Builder — standard SOQL (no -t); ProcessType Workflow = Process Builder
sf data query --json -o <alias> -q "SELECT ApiName, Label, ProcessType, TriggerType, IsActive FROM FlowDefinitionView ORDER BY ProcessType, ApiName"

# Validation rules — Tooling; EntityDefinition gives the object
sf data query -t --json -o <alias> -q "SELECT ValidationName, EntityDefinition.QualifiedApiName, Active, ErrorMessage FROM ValidationRule ORDER BY EntityDefinition.QualifiedApiName"

# Legacy workflow rules — Tooling
sf data query -t --json -o <alias> -q "SELECT Name, TableEnumOrId FROM WorkflowRule ORDER BY TableEnumOrId"
```

Retrieve full source (Apex bodies, flow XML) only for shortlisted items — see §6. Bulk-pulling
an entire org's code is slow and rarely needed for the inventory.

## §3 Security model inventory queries

Consolidate into `security.json` as `{profiles, permission_sets, assignment_counts,
users_per_profile, object_permissions}`.

```bash
# Profiles
sf data query --json -o <alias> -q "SELECT Id, Name, UserType FROM Profile ORDER BY Name"

# Permission sets (IsOwnedByProfile = true rows are profiles' internal twins — keep them separable)
sf data query --json -o <alias> -q "SELECT Id, Name, Label, IsCustom, IsOwnedByProfile FROM PermissionSet ORDER BY IsOwnedByProfile, Name"

# Which permission sets are actually assigned, and how widely
sf data query --json -o <alias> -q "SELECT PermissionSet.Label, COUNT(Id) assignments FROM PermissionSetAssignment GROUP BY PermissionSet.Label ORDER BY COUNT(Id) DESC"

# Active users per profile — profiles with 0 active users are dead-config candidates
sf data query --json -o <alias> -q "SELECT Profile.Name, COUNT(Id) users FROM User WHERE IsActive = true GROUP BY Profile.Name ORDER BY COUNT(Id) DESC"

# Object-permission matrix (large — aggregate per object first, drill into shortlisted objects)
sf data query --json -o <alias> -q "SELECT SobjectType, COUNT(Id) grants FROM ObjectPermissions GROUP BY SobjectType ORDER BY COUNT(Id) DESC"

# Drill-down for one object
sf data query --json -o <alias> -q "SELECT Parent.Label, Parent.IsOwnedByProfile, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords FROM ObjectPermissions WHERE SobjectType = '<Object>'"
```

For the Dataverse security-role conversion estimate, the numbers that matter are: profile count,
custom permission-set count, assignment spread, and per-object grant density on shortlisted
objects.

## §4 Targeted profiling query patterns

Run these per shortlisted object (not org-wide — each is an API call and some are heavy).

```bash
# Duplicate density by a business key (GROUP BY returns max 2000 rows — LIMIT protects)
sf data query --json -o <alias> -q "SELECT Name, COUNT(Id) c FROM Account GROUP BY Name HAVING COUNT(Id) > 1 ORDER BY COUNT(Id) DESC LIMIT 200"

# Parentless density — how many children float without the expected parent
sf data query --json -o <alias> -q "SELECT COUNT() FROM Contact WHERE AccountId = null"

# Staleness — records untouched for a year
sf data query --json -o <alias> -q "SELECT COUNT() FROM <Object> WHERE LastModifiedDate < LAST_N_DAYS:365"

# Record-type usage — record types with 0 rows are retirement candidates
sf data query --json -o <alias> -q "SELECT RecordType.DeveloperName, COUNT(Id) c FROM <Object> GROUP BY RecordType.DeveloperName"

# Picklist value usage — values with 0 rows need no Dataverse choice equivalent
sf data query --json -o <alias> -q "SELECT <PicklistField>, COUNT(Id) c FROM <Object> GROUP BY <PicklistField> ORDER BY COUNT(Id) DESC"
```

PII discipline: keep queries aggregate (`COUNT`, `GROUP BY`). Where a `GROUP BY` key is itself
personal data (e.g. `Name` in the duplicate query), report the *counts distribution*, not the
key values, in any committed deliverable.

## §5 Mode B — offline metadata package parsing

Two package layouts exist; detect by structure:

| Layout | Marker | Object schema location |
|--------|--------|------------------------|
| **mdapi format** | `package.xml` at root, `objects/Account.object` | One XML per object: `<fields>`, `<validationRules>`, `<recordTypes>` inline |
| **source format** | `force-app/main/default/`, `*-meta.xml` suffixes | `objects/Account/fields/*.field-meta.xml`, one XML per field |

Element → `schema.json` property map:

| Package XML | schema.json |
|-------------|-------------|
| `<fullName>` (field) | `fields[].name` |
| `<label>` | `fields[].label` |
| `<type>` (Text, Picklist, Lookup, MasterDetail, …) | `fields[].type` (lowercase; `Lookup`/`MasterDetail` → `reference` + relationship entry) |
| `<length>` / `<precision>` / `<scale>` | same names |
| `<required>` | `nillable` (inverted) |
| `<unique>` / `<externalId>` | same names |
| `<referenceTo>` + `<relationshipName>` | relationship entry; `MasterDetail` type → `master-detail` |
| `<valueSet><valueSetDefinition><value><fullName>` | `fields[].picklistValues` |
| `recordTypes/*.recordType-meta.xml` or `<recordTypes>` | `record_types[]` |
| `<formula>` | `fields[].calculated = true` |

Also present in packages: `profiles/*.profile`, `permissionsets/*.permissionset` (→ `security.json`),
`classes/`, `triggers/`, `flows/` (→ `automation.json` — count files; `<status>` in
`*.flow-meta.xml` gives active/inactive).

Set `"source": "offline-package"` in `schema.json`. **Not available offline:** row counts, fill
rates, assignment counts, active-user counts, `keyPrefix`. Mark `data_profile.json` as not
produced and state the fidelity gap in `inventory.md`.

Standard objects only appear in a package if explicitly retrieved with customizations — an
offline extract may under-represent standard-object usage. Say so in the deliverable.

## §6 Metadata retrieve — targeted pulls and requesting an export

Targeted retrieve from a live org (Mode A, shortlisted items only):

```bash
sf project generate --name sfdc-extract && cd sfdc-extract
sf project retrieve start -o <alias> -m "ApexClass:MyClass" -m "Flow:My_Flow" -m "Layout:Account-Account Layout"
```

Full-org manifest (also what to send a client admin who will produce a Mode-B package):

```bash
# Generate package.xml covering the org
sf project generate manifest --from-org <alias> --output-dir manifest
# Retrieve everything the manifest names (large orgs: minutes, and Metadata API caps at 10,000 files/39 MB per retrieve — split the manifest if exceeded)
sf project retrieve start -o <alias> --manifest manifest/package.xml
```

A client admin without sf CLI can use Setup → *Package Manager* / change-set export or Workbench
(Migration → Retrieve) with the same `package.xml`. Minimum useful types for this skill:
`CustomObject`, `CustomField`, `ValidationRule`, `RecordType`, `Profile`, `PermissionSet`,
`ApexClass`, `ApexTrigger`, `Flow`, `Layout`.

## API limits and cost

- Describe, SOQL, and Tooling calls all count against the org's **daily API request limit**
  (typically 100k+). A full sweep of a 1,000-object org costs ≈ 1,000 describes + ≈ 1,000
  sample queries + ≈ 50 recordCount chunks — negligible for a day, but check remaining budget
  with `sf limits api display -o <alias>` before sweeping a heavily integrated production org.
- `FIELDS(ALL)` requires `LIMIT ≤ 200` — the platform cap that sets the profile sample size.
- `GROUP BY` aggregate queries return at most 2,000 groups; use `LIMIT` and `ORDER BY COUNT(Id) DESC`.
- The `limits/recordCount` endpoint returns **approximate** counts (fast, index-based). Present
  them as approximate; use `SELECT COUNT()` only where exactness matters (reconciliation is a
  Stage-5 concern, not an inventory concern).

## Describe property notes

| Describe property | Meaning for migration |
|-------------------|----------------------|
| `type: reference` + `referenceTo` | Lookup or master-detail (see `cascadeDelete`) → Dataverse lookup / parental relationship |
| `cascadeDelete: true` | Master-detail → candidate parental (cascade) relationship behavior |
| `nillable: false` on a custom field | Required field — carries to Business Required unless re-engineered |
| `calculated: true` | Formula field — Dataverse calculated/rollup column or Power Fx; flag for pass-2 redesign |
| `externalId: true` | Integration key — candidate Dataverse alternate key; preserve for traceability |
| `unique: true` | Candidate alternate key |
| `picklistValues` (active only) | Choice values; inactive values matter only for historical data mapping |
| `recordTypeInfos` with `available: false` | Record type no profile can use — dead-config candidate |
| `queryable: false` | Skip in data profiling |
