---
name: hso-dataverse-data-modeling
layer: atomic
scope: core
description: |
  Design and create Dataverse schema components — tables, columns, relationships, global choices, alternate keys, solutions, model-driven apps, and publishers — via PowerShell + Web API. Covers create and update for tables and columns (display name, required level, min/max, precision, audit, auto-number conversion), metadata queries, relationship discovery (e.g. for subgrid configuration), and solution component management. Use for "create a table", "add fields", "create a relationship", "build a solution", or any schema-design / metadata-query task.
---

# Dataverse Data Modeling Skill

Create and manage Dataverse schema components: tables, columns, relationships, global choices, and solutions using the Dataverse Web API.

> **Run these scripts with the PowerShell tool — not bash.** They are PowerShell (`pwsh`). Two
> invocation styles appear in the examples below: the `powershell -ExecutionPolicy Bypass -File …`
> form (shell-agnostic, used in most examples) and the `& "….ps1" -Options ($json | ConvertFrom-Json)`
> form (**PowerShell-only** — required for `-Options`/`-Columns` because a converted JSON array can't be
> passed through `-File`). Calling either from bash fails with `=: command not found` or
> `syntax error near unexpected token '&'`.

> **`-SpecJsonPath` is an orchestration convenience** for spec-driven builds; every operation here also works from explicit parameters / inline input — `spec.json` is never required. The orchestrator chooses the step.

## Slice Consumption Contract (executor side of the architect→builder pipeline)

**Authority:** [`slice-consumption-contract-best-practices.md`](../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md) — read before building any slice inside the pipeline. That SOP is the **canonical, executor-side contract** for [ADR 0018](../../../agent/wiki/decisions/0018-agentic-delivery-architect-builder-pipeline.md)'s architect→builder pipeline (the five rules, single-writer, reviewable-unit, anti-mis-attribution). The summary here is a labeled pointer, not a substitute.

When the architect routes a slice to this skill you are handed **the spec (markdown) + its `spec.json` sidecar + a target slice `id`** — not a raw requirement to design end-to-end. Build **exactly that slice's `touches`** (publisher → solution → choices → table → columns → relationship → keys, each still obeying every standard in this skill); trust and verify — don't rebuild — your `blocked_by` slices; honor every recorded design decision (cascade value, global choices, child-owned lookup placement); **read back against the slice's `acceptance`, not against an SOP rule the spec never invoked**; and end at the unmanaged solution named in `spec.json` (never export-as-managed or deploy). **Read-back ops:** `QueryTable`, `QueryColumn`, `QueryRelationships`, `QueryAlternateKeys`, `QueryGlobalChoice`, `QuerySolution`.

**Publisher prefix preflight (mandatory — the spec wins).** Before building any slice, read `spec.json.publisherPrefix` and pass that **exact** value as `-PublisherPrefix` (and prefix every component name with it). When a spec is in play it is the source of truth — it overrides the CLAUDE.md default and overrides whatever publisher the environment already carries. Do **not** infer the prefix from existing tables in the environment: a sandbox often already has a *real* publisher (e.g. `hso`) whose prefix differs from the spec's (`hsot`), and building under the wrong one silently produces a model that is invisible to the spec, the grader, and the scoped reset. The script now **enforces** this — every prefix-bearing create (`CreateTable`, `AddColumn(s)`, `CreateGlobalChoice`, `CreateRelationship`/`CreatePolymorphicLookup`, `CreateAlternateKey`) that targets a `-SolutionName` runs a `[PREFLIGHT]` check and **refuses with `[FATAL]` + a non-zero exit on the first component** if the applied prefix does not match that solution's publisher. A mismatch is a hard stop, not a warning.

**Relationships belong to slices by side-count — this skill owns the rule.** A **lookup** (one many-side) lives on the **entity/extension slice that introduces it**, and the lookup column is created on the **referencing (many-side / child) table** in that slice. An **N:N** belongs to the **capability slice that consumes it**, never a table slice. When your slice is the child entity that introduces a parent lookup, **you create the 1:N + its deliberate cascade as part of *this* slice**, on the child. **Single writer for shared schema** (a global choice, a base relationship, a shared solution): one writer, one operation, never reopen a shipped slice — see the SOP.

| Slice type | What this skill owns in it |
|------------|---------------------------|
| `foundation` | publisher, solution, **global choices**, base/shared relationships |
| `entity` | the table + all its columns + the lookup(s) it introduces (on the child) + alternate keys + cascade (the form/views are the `ui-config` half of the entity slice) |
| `extension` | HSO-owned columns on an **OOB** table (+ keys); never alter OOB metadata destructively |
| `assembly` | a single-writer schema re-touch (e.g. a **rollup count column** added to an already-shipped parent table) |

> Forms, views, sitemap, and the app live in [`hso-dataverse-ui-config`](../hso-dataverse-ui-config/SKILL.md); sample data in [`hso-dataverse-data`](../hso-dataverse-data/SKILL.md). All executor skills share the **same** [Slice Consumption Contract](../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md).

## HSO Standard: Descriptions Are Mandatory

Digest only — §24 of [`data-modeling-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md#24-descriptions-are-mandatory) is the authority for description rules; read it before designing. The rules below are an operational summary.

**Every component this skill creates must have a Description populated** — tables, columns, lookups (1:N / Customer / polymorphic), global choices, alternate keys, model-driven apps, and solutions. The script emits a `[WARN]` line when a description is missing on creation; do not ship a component with that warning unresolved.

Why:

- **Columns** — the description is the **tooltip** rendered when a user hovers the field label in a model-driven app. From the maker portal: *"Enter instructions to the user about what the column is for. These descriptions appear as tooltips for the user in model-driven apps when they hover their mouse over the label of the column."* An empty description means an empty tooltip, which is a missed UX opportunity on every form the column appears on.
- **Tables, choices, lookups, apps, solutions** — the description provides spec traceability (who designed this, why, what does it represent) and surfaces in the maker portal, solution package metadata, and downstream documentation generators.

The description should come from the architect spec — every spec authored by `hso-dataverse-architect` must include a Description column for tables, columns, relationships, choices, forms, and views (see [`shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md` §24](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md#24-descriptions-are-mandatory)).

Operation → parameter mapping:

| Operation | Description parameter |
|-----------|----------------------|
| `CreateTable` / `UpdateTable` | `-Description` |
| `AddColumn` (single) | `-ColumnDescription` |
| `AddColumns` (batch) | `Description` property on each column object in the JSON |
| `UpdateColumn` | `-ColumnDescription` |
| `CreateRelationship` (OneToMany / Customer) | `-LookupDescription` |
| `CreatePolymorphicLookup` | `-LookupDescription` |
| `CreateGlobalChoice` | `-ChoiceDescription` |
| `CreateApp` | `-AppDescription` |
| `CreateSolution` | `-SolutionDescription` |

**Limitation:** N:N relationships (`ManyToMany`) do not have a Description field in `ManyToManyRelationshipMetadata`. Use the per-side `AssociatedMenuConfiguration.Label` (set automatically) for the user-visible label; document the *purpose* of the relationship in the architect spec instead.

## Authoritative Best Practices (READ FIRST)

The **definitive, top-priority source** for schema-design guidance is
**[`data-modeling-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md)** —
read it **before designing or creating any schema**. It outranks this SKILL.md, the operation reference,
and every companion SOP; when a summary rule here and the SOP conflict, **the SOP wins**. The inline
standards in this skill are a quick checklist drawn from it. Key sections: §1 OOB-vs-custom, §3 table
type/ownership, §6 DateTime "set once", §9 global choices, §10 statecode/statuscode (never custom
isactive), §11 relationships, §12 cascade, §15 alternate keys, §18 deprecation, §23 pre-merge checklist.

The task→authority map below routes a standalone task to the right primary doc. The companion families
are **secondary** to data-modeling on any schema-rule question; consult each only when its condition
applies. In brief:

- **Dataverse Solutions family** — which solution/publisher a component lands in and how it layers (locked at creation). Watch the `behavior=0`-on-OOB trap, the Default-Publisher (`cr8a3_*`) trap, and managed-property locking (default `true`).
- **Power Pages family** — when a table is exposed via Power Pages: permission scope drives schema (Contact-scope needs a contact lookup; Account-scope needs `parentcustomerid` indirection), staging-table writes, list indexes.
- **Master Data Management family** — master-data tables (customer/contact/product/location/worker): architectural style + system-of-record matrix decide author-vs-subscribe; alternate-keys-vs-dup-detection; external-hub subscriber columns (`hso_externalsystemid_text` etc.).
- **Customer Management SOP** — when the table is/extends Account/Contact/Lead: `customertypecode` discipline, B2B/B2C shape, polymorphic `customerid`, dual-write impact, `parentcustomerid`/`parentaccountid` rules.

### Task → primary authority map

| Task type | Primary doc | Composes with |
|-----------|-------------|---------------|
| Any new schema (tables / columns / choices / relationships / alternate keys) | [`data-modeling-best-practices.md`](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md) | (always) |
| A fiscal year / fiscal period / budget cycle / plan year / any calendar dimension | [`data-modeling-best-practices.md` §9 → calendar dimensions](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md#fiscal-year-periods-and-other-calendar-dimensions--a-table-not-a-scalar) — `<prefix>_fiscalyear` (OrgOwned, alt key on the year) + lookup; period child if the domain closes periods; a denormalised year number only beside the lookup for a stated key reason | configuration-data SOP (load slice) |
| Which solution / publisher a component lands in; managed-property locking | Dataverse Solutions family ([segmentation](../../../shared/dv/agent/wiki/sop/dataverse-solutions/solution-segmentation-best-practices.md), [publishers & versioning](../../../shared/dv/agent/wiki/sop/dataverse-solutions/solution-publishers-and-versioning-best-practices.md), [layering & managed properties](../../../shared/dv/agent/wiki/sop/dataverse-solutions/solution-layering-and-managed-properties-best-practices.md)) | data-modeling |
| Table exposed via Power Pages | [power-pages-security](../../../shared/dv/agent/wiki/sop/power-pages/power-pages-security-best-practices.md) + [power-pages-design-studio](../../../shared/dv/agent/wiki/sop/power-pages/power-pages-design-studio-best-practices.md) | data-modeling |
| Master-data table (customer / contact / product / location / worker) | [Master Data Management family](../../../shared/dv/agent/wiki/sop/master-data-management/master-data-management-best-practices.md) | data-modeling |
| Table is, or extends, Account / Contact / Lead | [`customer-management-best-practices.md`](../../../shared/dv/agent/wiki/sop/crm-processes/customer-management-best-practices.md) | data-modeling + MDM |

The SOP is the methodology. This skill is the operations.

## Authentication

**Schema changes are critical operations.** Authentication mode is resolved automatically from settings when this skill modifies your Dataverse environment.

When browser sign-in is used:
1. **First call**: A browser window opens for Office 365 login
2. You authenticate with your credentials
3. **Token is cached** for subsequent operations (~1 hour validity)
4. **Subsequent calls**: Use cached token automatically - no browser popup

This enables **batch operations** where Claude can create a complete data model (table + multiple fields + relationships) with a single authentication prompt.

**Token caching details:**
- Cache location: `%TEMP%\DataverseAuthCache_<environment-hash>.json`
- Token validity: ~1 hour (checked with 5-minute buffer)
- Cache is per-environment (different environments have separate caches)

## Publisher prefix resolution

Every component this skill creates is named `<prefix>_…`. **There is no default prefix** — a baked-in
one silently stamped one client's prefix onto another client's schema, and entity `SchemaName` is
immutable, so the only correction is to drop and recreate the table.

The prefix is resolved per run, highest precedence first:

| # | Source | Notes |
|---|---|---|
| 1 | `-PublisherPrefix` | Explicit override |
| 2 | **`CLAUDE.md` → `\| Publisher prefix \| … \|`** | **Canonical.** Written by `hso-new-workspace` at scaffold time |
| 3 | `README.md` → same row | For repos that record it there |
| 4 | **Prompt** | Only when 1–3 find nothing; the run then tells you to record it in CLAUDE.md |

Reaching step 4 means the repo was never scaffolded with a prefix (or the row was deleted). It is a
one-time cost — record the answer and it never asks again. Placeholder values (`<UPDATE THIS>`, etc.)
count as *not set*, so a half-filled template prompts rather than creating `<UPDATE THIS>_project`.

Pass **`-NoPrompt`** for CI and unattended agents: it turns step 4 into a hard failure instead of
blocking on a prompt nobody can answer. Every run prints the prefix and where it came from:

```
Publisher prefix: abc  (source: CLAUDE.md (C:\repos\client-x))
```

**The prefix is validated against the target solution's publisher** before the first component is
created (`-SolutionName`), and the run aborts on a mismatch. Without `-SolutionName` that check
cannot run, and the script says so rather than implying it passed.

## Prerequisites

1. **MSAL.PS PowerShell module** (installed automatically on first use)
2. **Configuration** in CLAUDE.md — **publisher prefix** (see above), solution name, environment URL
3. **Internet connectivity** for OAuth authentication
4. **Naming conventions**: Use the `hso-dataverse-naming-conventions` skill for table, column, choice, and relationship naming standards before designing any schema

## Capabilities

| Operation | Supported | Description |
|-----------|-----------|-------------|
| Create table | Yes | Create new custom tables |
| **Create custom activity** | **Yes** | `CreateTable -IsActivity` — create an activity table (timeline-enabled, subject primary, user-owned). See §2.1.1 |
| **Update table** | **Yes** | Update table properties (DisplayName, HasActivities, HasNotes) |
| **Set table icon** | **Yes** | `SetTableIcon` — set a custom table's `IconVectorName` to an SVG web resource (custom tables only). Also settable inline on `CreateTable`. See §2.4 |
| **Create web resource** | **Yes** | `CreateWebResource` — upload an SVG (type 11) as a web resource, validated against MSFT's icon rules, added to the solution + published. See §2.4 |
| Add columns | Yes | Add columns to tables (with optional min/max, defaults) |
| **Update columns** | **Yes** | Modify column settings (audit, min/max, required level, defaults, auto-number) |
| **Query column** | **Yes** | Inspect column metadata (type, constraints, defaults, audit status) |
| **Delete column** | **Yes** | `DeleteColumn` — guarded delete: dependency preflight (lists blocking forms/views and refuses unless `-Force`) + primary-name-column guard. See §3.6 |
| **Query column dependencies** | **Yes** | `QueryColumnDependencies` — **read-only**: lists what would block a column's deletion (forms/views/charts/alternate keys, resolved to names) without deleting. The non-destructive entry point to DeleteColumn's preflight. |
| Create lookup (1:N) | Yes | Create one-to-many relationships |
| Create N:N relationship | Yes | Create many-to-many relationships |
| **Query relationships** | **Yes** | Discover all relationships for a table (for subgrid config) |
| Create global choice | Yes | Create global option sets |
| Update global choice | Yes | Add options to existing choices |
| **Create solution** | **Yes** | Create new unmanaged solutions (idempotent — reuses an existing solution of the same name instead of throwing a 400) |
| **Query solution** | **Yes** | `QuerySolution` — read a solution's existence/version/managed-state + component count (makes verify-then-create expressible) |
| **Add table to solution** | **Yes** | Add existing tables (metadata only option) |
| **Add component to solution** | **Yes** | Add specific components selectively |
| Cascade configuration | Yes | Configure relationship cascading |
| Publish customizations | Yes | Publish specific tables or all |
| **Create model-driven app** | **Yes** | Create new Unified Interface apps |
| **Add table to app** | **Yes** | Add tables to model-driven apps |
| **Query/Publish app** | **Yes** | Query app details and publish |
| **Create alternate key** | **Yes** | Define unique keys for data integration |
| **Query alternate keys** | **Yes** | `QueryAlternateKeys` — list a table's keys with `EntityKeyIndexStatus` (Pending/In Progress/Active/Failed) for async-index verification |
| **Set auto-number seed** | **Yes** | `SetAutoNumberSeed` — set the runtime seed for an auto-number column (`-TableName` + `-ColumnName` + `-AutoNumberSeedValue`); e.g. seed `1` so the first record is `AGR-00001` instead of the platform default `AGR-01000` |
| **Add status value** | **Yes** | Add custom statuscode values linked to states |
| **Update status label** | **Yes** | Rename existing statuscode values |
| **Query publishers** | **Yes** | List all publishers with read-only status |
| **Create publisher** | **Yes** | Create a new publisher for solution creation |

---

## 0. PUBLISHER OPERATIONS

Run these **before CreateSolution** when setting up a new environment or if CreateSolution fails with a publisher error.

> **Publisher vs. Prefix:** The publisher *prefix* (e.g., `hso`) is used for naming custom components (tables, columns). The publisher *unique name* (e.g., `HSOUSSolutionsTeam`) is what you pass to `-PublisherName` in CreateSolution. They are often different. Always pass `-PublisherPrefix` matching your project's CLAUDE.md value — or, when building from an architect spec, the exact `spec.json.publisherPrefix` (the spec overrides CLAUDE.md). The prefix-bearing create operations **enforce** this: if the applied prefix does not match the target `-SolutionName`'s publisher, the script refuses with `[FATAL]` and a non-zero exit before creating anything (see the **Publisher prefix preflight** note under the Slice Consumption Contract).

### 0.1 Query Publishers

List all publishers in the environment to find a writable one for solution creation:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation QueryPublishers `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com"
```

Output shows each publisher's unique name, prefix, and whether it is read-only (green = usable, yellow = cannot be used for solutions).

### 0.2 Create Publisher

Create a new publisher when no suitable writable publisher exists:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreatePublisher `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -PublisherDisplayName "HSO US Solutions Team" `
    -PublisherUniqueName "HSOUSSolutionsTeam" `
    -PublisherPrefix "hsous" `
    -OptionValuePrefix 54031
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| PublisherDisplayName | Yes | Friendly name shown in UI |
| PublisherUniqueName | Yes | Unique name for the publisher record |
| PublisherPrefix | Yes | Short naming prefix, 2-8 lowercase letters (e.g., "hsous") |
| OptionValuePrefix | Yes | Integer used to seed global choice option values (e.g., 54031 → values start at 540310000) |

> **Note:** `PublisherPrefix` here is the prefix for the *new publisher*. It can differ from the project naming prefix in CLAUDE.md if you are creating a publisher in a shared environment.

---

## 1. SOLUTION OPERATIONS

### 1.1 Create Solution

Create a new unmanaged solution. **Always run `QueryPublishers` first** to confirm the publisher exists and is writable.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateSolution `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -SolutionUniqueName "MyNewSolution" `
    -SolutionDisplayName "My New Solution" `
    -SolutionDescription "Description of the solution" `
    -PublisherName "hso" `
    -PublisherPrefix "hso"
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| SolutionUniqueName | Yes | Unique name (no spaces, use PascalCase) |
| SolutionDisplayName | Yes | Display name shown in UI |
| SolutionDescription | No | Description of the solution |
| PublisherName | Yes | Publisher unique name or prefix to use for this solution (e.g., "hso" or "HSOUSSolutionsTeam") |
| PublisherPrefix | No | Naming prefix for tables/columns. **No default** — resolved from CLAUDE.md, then README, then by prompting |

> **Read-only publisher error:** If the publisher is read-only (imported via a managed solution), CreateSolution will display all writable publishers and exit cleanly. Use one of the listed names for `-PublisherName`.

### 1.2 Add Existing Table to Solution

Add an existing table to a solution **without including all assets**:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddTableToSolution `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "account" `
    -SolutionName "MyNewSolution"
```

> **Do NOT pass a PowerShell boolean (`$true`/`$false`) through the `powershell -File` form.** `-File` passes every argument as a string, so a bareword `$true` fails `[bool]` transformation with *"Cannot process argument transformation"* (exit 1). The default (`$true`) already does the right thing, so the happy path above needs no boolean at all. If you must override to `$false`, use the call-operator form (`& "….ps1" … -DoNotIncludeSubcomponents:$false`, shown in §3.2) instead of `-File`.

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| TableName | Yes | - | Logical name of the table (e.g., "account", "contact") |
| SolutionName | Yes | - | Solution unique name to add the table to |
| DoNotIncludeSubcomponents | No | $true | **IMPORTANT**: Defaults to $true (metadata only — recommended for OOB tables). Leave it unset on the happy path; only override to `$false`, via the call-operator form (see the boolean caveat above). |

**CRITICAL**: When adding OOB tables like Account or Contact, add **metadata only** (the default) to avoid solution bloat and deployment conflicts.

### 1.3 Add Specific Component to Solution

Add individual components (columns, forms, views) selectively:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddComponentToSolution `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -ComponentId "a1b2c3d4-5678-90ab-cdef-1234567890ab" `
    -ComponentType "Column" `
    -SolutionName "MyNewSolution"
```

> **Boolean caveat (§1.2) also applies to `-IncludeMetadata` / `-DoNotIncludeSubcomponents`.** Both default to `$true`, so the happy path passes neither; override to `$false` only via the call-operator form.

**Supported Component Types:**

| Type | Code | Description |
|------|------|-------------|
| Table | 1 | Entity |
| Column | 2 | Attribute/Field |
| Relationship | 10 | Entity Relationship |
| GlobalChoice | 9 | Option Set |
| Form | 24 | System Form (Main, Quick Create, etc.) |
| View | 26 | Saved Query (System View) |
| Chart | 59 | Saved Query Visualization |
| Dashboard | 60 | System Form (Dashboard) |
| WebResource | 61 | Web Resource |
| PluginAssembly | 91 | Plugin Assembly |
| Workflow | 29 | Cloud Flow / Workflow |

**Getting Component IDs:**
- Use Web API queries to find the MetadataId/GUID of the component you want to add
- For columns: Query `EntityDefinitions(LogicalName='tablename')/Attributes`
- For forms: Query `systemforms?$filter=objecttypecode eq 'tablename'`

---

## 2. TABLE OPERATIONS

### 2.1 Create Table

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateTable `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -PublisherPrefix "hso" `
    -TableName "projecttask" `
    -DisplayName "Project Task" `
    -DisplayNamePlural "Project Tasks" `
    -Description "Tracks tasks within projects" `
    -OwnershipType "UserOwned" `
    -PrimaryColumnName "hso_name_text" `
    -PrimaryColumnDisplayName "Name" `
    -PrimaryColumnDescription "The task name shown in lists and as the record's primary identifier." `
    -SolutionName "<YourSolutionUniqueName>"
```

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| EnvironmentUrl | Yes | - | Dataverse environment URL |
| Authentication | Automatic | - | Resolved automatically from settings; no caller flag required |
| **PublisherPrefix** | No | *(resolved)* | Controls all naming prefixes. **No default** — resolved from CLAUDE.md, then README, then by prompting. Pass it only to override that |
| TableName | Yes | - | Logical name (without prefix - script adds it) |
| **SchemaName** | **Yes for multi-word tables** | derived | Explicit entity SchemaName, e.g. `hso_FixedPriceGroup`. **Immutable after creation** and it names the generated early-bound class. See the callout below. |
| DisplayName | Yes | - | Singular display name |
| DisplayNamePlural | Yes | - | Plural display name |
| Description | No | - | Table description |
| OwnershipType | No | UserOwned | `UserOwned` (HSO default — **every** table, config included) or `OrganizationOwned` (**only** on recorded architect request; emits a `[WARN]`) |
| HasActivities | No | $false | Enable activity timeline (so this table can be the *regarding* parent of activities) |
| HasNotes | No | $false | Enable notes/attachments |
| **IsActivity** | No | $false (switch) | Make the table a **custom activity**. Forces `HasActivities=false` + `UserOwned`, defaults `HasNotes` and the subject primary on. See [§2.1.1](#211-create-a-custom-activity) and [references/custom-activity-web-api.md](references/custom-activity-web-api.md). |
| **IsAvailableOffline** | No | $false (switch) | Set `IsAvailableOffline=true` (mobile/Outlook sync). Recommended for activities; usable on any table. |
| **PrimaryColumnName** | No | hso_name_text | Schema name for primary column |
| **PrimaryColumnDisplayName** | No | Name | Display name for primary column |
| **PrimaryColumnMaxLength** | No | 100 | Max length for primary column |
| **PrimaryColumnDescription** | No (HSO standard) | - | Description (tooltip) for the primary column. Required by the descriptions-mandatory standard — the primary column is a real column created here; a `[WARN]` is emitted if omitted. |
| **PrimaryColumnRequiredLevel** | No | ApplicationRequired | None / ApplicationRequired / Recommended for the primary column — set **inline** so a non-default requirement no longer needs a follow-up `UpdateColumn`. |
| **PrimaryColumnAutoNumberFormat** | No | - | Make the primary an auto-number at create time (e.g. `AGR-{SEQNUM:5}`) — saves a `CreateTable`→`UpdateColumn` round-trip. The **seed** still defaults to 1000 unless you also pass `PrimaryColumnAutoNumberSeed` (format vs. seed: see the §3 seed note). |
| **PrimaryColumnAutoNumberSeed** | No | - (1000 default) | Set the runtime seed **inline** at table creation (e.g. `1` so the first record is `AGR-00001`). Only meaningful with `PrimaryColumnAutoNumberFormat`. Eliminates the most frequent manual detour after assigning an auto-number format. |

> ### ⚠️ Pass `-SchemaName` for any multi-word table — you only get one chance
>
> **Entity `SchemaName` is locked at creation.** A `PUT` that changes it returns **HTTP 200 and silently
> ignores the change** — no error tells you it failed. The only way to correct it is to **drop and recreate
> the table**, which is impossible once it holds data or anything references it.
>
> It matters because **`SchemaName` is what every early-bound generator uses to name the generated class**
> (vanilla `pac modelbuilder` reads it verbatim; it is not a generator setting you can override later).
>
> Without `-SchemaName`, the script capitalises the first character only. That is correct for single-word
> tables and wrong for everything else:
>
> | TableName | Derived (no `-SchemaName`) | Generated class | Wanted |
> |---|---|---|---|
> | `project` | `Hso_project` | `Hso_project` | ~ acceptable |
> | `fixedpricegroup` | `Hso_fixedpricegroup` ❌ | `Hso_fixedpricegroup` ❌ | `hso_FixedPriceGroup` |
>
> The correct casing **cannot be inferred** — `fixedpricegroup` carries no word boundaries, so no string
> manipulation recovers `FixedPriceGroup`. The caller has to say it:
>
> ```powershell
> -TableName "fixedpricegroup" -SchemaName "hso_FixedPriceGroup"
> ```
>
> The script emits a `[WARN]` when it derives a SchemaName for a name that looks multi-word. Treat that
> warning as blocking — fixing it afterwards means recreating the table.
>
> **Column** SchemaNames do not have this problem in HSO projects: the convention is all-lowercase
> (`hso_roleprice_curr`), which the derived value already produces. Only the **entity** SchemaName and the
> primary column (conventionally `hso_Name`) need care.

**Primary Column Naming:**
- By default, the primary column is created as `{prefix}_name_text` using the `-PublisherPrefix` value
- Always specify `PrimaryColumnName` to follow your naming standards (e.g., `hso_name_text`)
- The script automatically adds the publisher prefix if not included
- **Check the project's existing convention first.** Some projects use `{prefix}_name` rather than
  `{prefix}_name_text` for the primary column. Query an existing table's `PrimaryNameAttribute` before
  creating a new one — a mismatched primary column is a permanent inconsistency.

**Best Practice - Table Ownership (HSO default):**
- **Create every table `UserOwned` — configuration and reference tables included.** Do not treat "it's config data" as a reason for `OrganizationOwned`.
- `OrganizationOwned` is **not banned**, but it is never your call: use it only when the **solution architect explicitly asked for it** and a rationale is recorded in the data-modeling spec. If nobody asked, create `UserOwned` and say that you did.
- **Why:** a `UserOwned` table with **Global** depth on every role reads identically to an org-owned table today, but a depth can be narrowed per role later. An `OrganizationOwned` table has no depth to narrow — securing it later means deleting and recreating the table, which is not possible in production. Teams then hide data in plugin/form code instead, permanently.
- `UserOwned` supports security roles, sharing, owner teams, hierarchy security and BU scoping. `OrganizationOwned` has no `ownerid` and supports none of them.
- Platform-forced exceptions (not decisions): virtual tables and BPF runtime entities are always `OrganizationOwned`; activity tables are always `UserOwned`.
- Full rationale: [`security-best-practices.md` § Table ownership](../../../agent/wiki/sop/security/security-best-practices.md#table-ownership-shapes-which-depths-are-valid).

### 2.1.1 Create a Custom Activity

Use `-IsActivity` when the table is an **activity** — a record logged over time against another record
that should appear on its timeline and in rolled-up activity views (a site visit, coaching note,
inspection, contact touch). Some architects and implementations lean on custom activities heavily; this
is a first-class path, not an edge case.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateTable `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -PublisherPrefix "hso" `
    -TableName "sitevisit" `
    -DisplayName "Site Visit" `
    -DisplayNamePlural "Site Visits" `
    -Description "A logged visit to a customer site, tracked on the regarding record's timeline." `
    -IsActivity -IsAvailableOffline `
    -PrimaryColumnDescription "Short summary of the visit, shown on the timeline." `
    -SolutionName "<YourSolutionUniqueName>"
```

What `-IsActivity` does for you (each is a platform rule whose violation is an opaque `CreateEntity`
error — the script normalises so you get a working activity, not a 400):

- `IsActivity=true`.
- **Forces `HasActivities=false`** (an activity can't host activities) — `[WARN]` if you passed `$true`.
- **Forces `OwnershipType=UserOwned`** (activities can't be org-owned) — `[WARN]` if you passed `OrganizationOwned`.
- **Defaults `HasNotes=true`** (override with `-HasNotes $false`).
- **Defaults the primary to `<prefix>_subject_text` / display "Subject"** (an activity's primary name is
  the subject; override with `-PrimaryColumnName` if you must).
- Add `-IsAvailableOffline` for mobile/Outlook sync (recommended).

`IsActivity`, `HasActivities`, and `OwnershipType` are **immutable after create** — wrong values mean
delete + recreate. `QueryTable` reports `IsActivity` so you can verify.

> **Authority:** [references/custom-activity-web-api.md](references/custom-activity-web-api.md) — read
> before creating a custom activity. It carries the full `CreateEntity` payload, the regarding-vs-explicit-lookup
> relationship guidance (OOB activities use `-ParentPrimaryKey activityid`), and an **error → fix** table.
> The OOB-vs-custom and "activity vs plain table" decision rule is in the
> [data-modeling best practices SOP](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md).

### 2.2 Update Table

Update properties on an existing table. Fetches the current state first and applies only changed properties.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation UpdateTable `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_projecttask" `
    -HasActivities $true `
    -HasNotes $true `
    -DisplayName "Project Task" `
    -DisplayNamePlural "Project Tasks" `
    -Description "Updated description" `
    -SolutionName "<YourSolutionUniqueName>"
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| TableName | Yes | Logical name of the table (e.g., "hso_projecttask") |
| HasActivities | No | Enable activity timeline ($true/$false) |
| HasNotes | No | Enable notes/attachments ($true/$false) |
| DisplayName | No | Update singular display name |
| DisplayNamePlural | No | Update plural display name |
| Description | No | Update table description |
| SolutionName | No | Solution to associate the change with |
| **IsQuickCreateEnabled** | **No** | Surface the Quick Create form (`$true`/`$false`). When `$true`, Dataverse shows the table's active Quick Create form in the global New button and subgrid add buttons. Omit entirely to leave the current value unchanged. Use the call-operator form to avoid the `-File` boolean-string trap (see example below). |

**Important Notes:**
- **HasActivities and HasNotes cannot be disabled once enabled.** The script warns and skips if you attempt to set them to `$false` when they are already `$true`.
- **IsQuickCreateEnabled is bidirectional** — it can be toggled on or off at any time. A Quick Create form must exist and be active on the table for the toggle to have visible effect.
- Only changed properties are included in the update request.
- The table is automatically published after the update.

**Example — enable Quick Create (call-operator form required for boolean):**

```powershell
& ".claude\skills\hso-dataverse-data-modeling\scripts\Invoke-DataverseMetadataOperation.ps1" `
    -Operation UpdateTable `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_financingtransaction" `
    -IsQuickCreateEnabled:$true `
    -SolutionName "HSOBillingPlatform"
```

### 2.3 Check If Table Exists

Before creating a table, query to verify it doesn't already exist:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation QueryTable `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_projecttask"
```

### 2.4 Table Icons (SVG `IconVectorName`)

Give a custom table a distinct icon so it is recognizable in the sitemap, lookups, and subgrids instead of
the generic default cube. The icon is an **SVG web resource** referenced by `EntityMetadata.IconVectorName`
(the modern vector property; supersedes the legacy `IconSmallName`/`IconMediumName` PNGs).

> **Authority:** [references/table-icons-web-api.md](references/table-icons-web-api.md) for the payloads, and
> [`data-modeling-best-practices.md` → Table icons](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md)
> for the methodology + MSFT SVG rules. Read before authoring or accepting a custom icon SVG.

**HSO standard (optional — warn if missing).** `CreateTable` emits a `[WARN]` (counted in the run-level WARN
tally) when a new custom table gets no icon. It does not block — but a custom table with the default cube
icon is a missed-recognizability opportunity. Set one with `-IconSvgPath` / `-IconSvgContent` (your own SVG
art), or `-IconVectorName` (an existing SVG web resource).

> **Custom tables only.** Microsoft does not allow changing the icon of system/OOB tables. `SetTableIcon`
> reads `IsCustomEntity` and refuses on a system table. An `extension` slice (HSO columns on an OOB table)
> can never carry a custom icon.

**MSFT SVG rules** (enforced by the script — hard refusal unless noted):

- ≤ **10 KB**, valid `<svg>`, has a **`viewBox`** (renders at 16×16) — hard.
- **No `<script>`**, no `on*=` handlers, no external/`data:` `href` — hard. *Dataverse does not sanitize SVG —
  it carries the same script risk as a JS web resource — so this is a security control, not cosmetics.*
- Prefer `fill="currentColor"`; avoid embedded `<style>`/classes — **warn** only (theming/contrast).

#### Set an icon inline at table creation (recommended)

Pass your own SVG with `-IconSvgPath` (or inline `-IconSvgContent`). The web resource is created, validated,
added to the solution, published, and the table is pointed at it — all in one call.

> **Need artwork?** The skill does not bundle icons. Pull a 16px glyph from Microsoft **Fluent UI System
> Icons** ([microsoft/fluentui-system-icons](https://github.com/microsoft/fluentui-system-icons) — prefer the
> `*_16_regular` variants, MIT-licensed), replace the hard-coded `fill="#212121"` with `fill="currentColor"`
> (Microsoft's own guidance for table icons, so it themes and keeps contrast), then pass the file. Makers can
> also use the [Iconator](https://www.xrmtoolbox.com/plugins/MscrmTools.Iconator/) XrmToolBox plugin.
> Whatever you supply, `Test-DataverseSvgIcon` enforces the MSFT rules below before upload.

```powershell
& ".claude\skills\hso-dataverse-data-modeling\scripts\Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateTable `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" -PublisherPrefix "hso" `
    -TableName "contract" -DisplayName "Contract" -DisplayNamePlural "Contracts" `
    -Description "A signed customer agreement." `
    -PrimaryColumnName "hso_name_text" -PrimaryColumnDescription "The contract title." `
    -IconSvgPath ".\contract.svg" -WebResourceName "hso_contract_icon.svg" `
    -SolutionName "<YourSolutionUniqueName>"
```

#### Set an icon on an existing table

```powershell
# From your own SVG file (creates + publishes the web resource, then sets IconVectorName)
& "...\Invoke-DataverseMetadataOperation.ps1" -Operation SetTableIcon `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_contract" -IconSvgPath ".\contract.svg" -WebResourceName "hso_contract_icon.svg" `
    -SolutionName "<YourSolutionUniqueName>"

# From an already-existing SVG web resource (no upload)
& "...\Invoke-DataverseMetadataOperation.ps1" -Operation SetTableIcon `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_contract" -IconVectorName "hso_contract_icon.svg" `
    -SolutionName "<YourSolutionUniqueName>"
```

#### Create just the web resource (without setting it on a table)

```powershell
& "...\Invoke-DataverseMetadataOperation.ps1" -Operation CreateWebResource `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -WebResourceName "hso_shared_icon.svg" -IconSvgPath ".\engagement.svg" `
    -WebResourceDescription "Shared engagement icon." `
    -SolutionName "<YourSolutionUniqueName>"
```

**Icon parameters:**

| Parameter | Used by | Description |
|-----------|---------|-------------|
| `-IconVectorName` | CreateTable, SetTableIcon | Name of an **existing** SVG web resource to set as the icon |
| `-IconSvgPath` | "" | Path to a local `.svg` file to upload (mutually exclusive with `-IconSvgContent`). BYO art — pull a glyph from [Fluent UI System Icons](https://github.com/microsoft/fluentui-system-icons) and set `fill="currentColor"` |
| `-IconSvgContent` | "" | Inline SVG markup (mutually exclusive) |
| `-WebResourceName` | CreateWebResource (req.), SetTableIcon/CreateTable when uploading | Unique name for the SVG web resource (prefix added if missing; `CreateTable` default `<table>_icon.svg`) |
| `-WebResourceDisplayName` / `-WebResourceDescription` | CreateWebResource | Display name / description (description is an HSO standard — `[WARN]` if omitted) |

> **Solution portability.** Pass `-SolutionName` so the web resource lands in the **same** solution as the
> table — `IconVectorName` references it by name and the dependency breaks on export otherwise (same trap as
> relationship parent tables). The op is idempotent (re-uploads update the existing web resource) and
> read-back-verifies the applied `IconVectorName` rather than trusting the publish banner.

---

## 3. COLUMN OPERATIONS

### 3.1 Add Columns to Table

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_projecttask" `
    -ColumnName "hso_estimatedhours_dec" `
    -ColumnDisplayName "Estimated Hours" `
    -ColumnDescription "The hours initially estimated to complete this task. Compared with actual hours to compute variance." `
    -ColumnType "Decimal" `
    -Precision 2 `
    -SolutionName "<YourSolutionUniqueName>"
```

> **`-ColumnDescription` is required by HSO standard** (see "Descriptions Are Mandatory" at the top of this file). It populates the column tooltip in model-driven apps. The script emits a `[WARN]` if it is omitted.

### 3.2 Batch Create Multiple Columns (AddColumns)

Create multiple columns in a single operation. Authentication is cached after the first column, so all subsequent columns are created without re-prompting.

> **HSO standard:** every column object MUST include a `Description` field. It renders as the tooltip in model-driven apps and provides spec traceability. The script emits a `[WARN]` per column when missing.
>
> **Transient-failure handling:** Dataverse occasionally returns a transient `400 "An unexpected error occurred"` (or `429`/`5xx`) on a column in a batch where an identically-configured sibling succeeds. The batch loop **retries each such transient failure once** (2s backoff) before giving up; deterministic config errors are not retried. If any column is still failed after the retry, the run prints a loud `BATCH INCOMPLETE — TABLE IS HALF-BUILT` banner listing the failed columns and **exits non-zero**, so an orchestrator cannot silently proceed past a half-built table. Re-running `AddColumns` with just the failed columns usually clears it.
>
> **GOTCHA — publish-collision retries must match BOTH error shapes (skill-gap #14).** On concurrent lanes (or back-to-back metadata writes), Dataverse routinely returns a `429`/`400` publish collision. There are **two distinct messages** and a retry wrapper that matches only one will fail the other through: *"...cannot start [Publish] because there is a previous [Publish] running"* **AND** *"...another [EntityCustomization] publish..."*. Retry-wrap every metadata/publish call and match **both** patterns (plus `CustomizationLock`). This was routine across FUND S0–S4.
>
> **GOTCHA — never regex-match a wrapper's success text; verify by metadata read-back (skill-gap #11/#12).** Two ways success strings lie: (1) `UpdateColumn`'s *"updated successfully"* can carry **ANSI escape codes mid-phrase**, so a `-match 'updated successfully'` check misses a genuine success (and vice-versa); (2) under a publish collision a wrapper can report *"0/1 built."* as success while the artifact reads back as a **1-field stub**. The bar is the env, not the wrapper's stdout — confirm every write with a `Query*` read-back (the read-back ops above) and quote the metadata, not the success banner.

```powershell
# Define columns as JSON array — every column carries a Description (tooltip + spec traceability).
$columnsJson = '[
    {"Name":"hso_subject_text","DisplayName":"Subject","Description":"Subject line shown to the recipient.","Type":"String","MaxLength":200},
    {"Name":"hso_body_memo","DisplayName":"Body","Description":"HTML body of the email.","Type":"Memo","MaxLength":100000},
    {"Name":"hso_isactive_bool","DisplayName":"Is Active","Description":"Whether this template is published for use. (NOTE: prefer statecode for record lifecycle — see SOP.)","Type":"Boolean","DefaultValue":true},
    {"Name":"hso_priority_code","DisplayName":"Priority","Description":"Priority code chosen by the sender. Drives queue routing.","Type":"Picklist","GlobalChoiceName":"hso_priority"},
    {"Name":"hso_sendon_dt","DisplayName":"Send On","Description":"Scheduled send time (UTC).","Type":"DateTime","DateTimeFormat":"DateAndTime"},
    {"Name":"hso_estimatedhours_dec","DisplayName":"Estimated Hours","Description":"Hours initially estimated. Compared with actual hours to compute variance.","Type":"Decimal","Precision":2,"MinValue":0,"MaxValue":1000}
]'

& ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumns `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_emailtemplate" `
    -Columns ($columnsJson | ConvertFrom-Json) `
    -SolutionName "<YourSolutionUniqueName>"
```

> **PREFERRED: pass `-ColumnsFile <path>` instead of `-Columns`.** Write the JSON array (the same shape shown above) to a file with the Write tool, then pass its path — no inline quoting, so you avoid the `$null`/nested-quote shell-escaping failures that make inline `-Columns` cascade into a half-built table. `-ColumnsFile` wins if both are supplied.
> ```powershell
> & "...\Invoke-DataverseMetadataOperation.ps1" -Operation AddColumns -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
>     -TableName "hso_emailtemplate" -ColumnsFile ".\columns.json" -SolutionName "<YourSolutionUniqueName>"
> ```

**Column Definition Properties:**

| Property | Required | Description |
|----------|----------|-------------|
| Name | Yes | Schema name (e.g., `hso_subject_text`) |
| DisplayName | Yes | Display name shown in UI |
| **Description** | **Yes (HSO standard)** | Tooltip text shown when users hover the field label in model-driven apps. Required by HSO standard; warning emitted if missing. |
| Type | Yes | String, Memo, Integer, Decimal, Money, Boolean, DateTime, Picklist, MultiSelectPicklist |
| MaxLength | No | For String/Memo (default: 100) |
| Precision | No | For Decimal (default: 2) |
| Required | No | Boolean (default: false) |
| GlobalChoiceName | No | For Picklist/MultiSelectPicklist |
| DateTimeFormat | No | DateOnly or DateAndTime |
| DateTimeBehavior | No | UserLocal, DateOnly, or TimeZoneIndependent |
| StringFormat | No | Text, Email, Url, Phone, TextArea |
| DefaultValue | No | Default value (type-appropriate) |
| MinValue | No | Min value for Integer/Decimal/Money (pass `0` for non-negative currency) |
| MaxValue | No | Max value for Integer/Decimal/Money |

**Output shows progress and summary:**
```
=== Batch Creating 6 Columns on hso_emailtemplate ===

--- Column 1 of 6: hso_subject_text ---
  Column created successfully!

--- Column 2 of 6: hso_body_memo ---
  Column created successfully!
...

=== Batch Column Creation Complete ===
  Successful: 6
```

### 3.3 Supported Column Types

`-ColumnType` accepts: String, Memo, Integer, Decimal, Money, Boolean, DateTime, Picklist,
MultiSelectPicklist. For the per-type additional parameters, @odata.type codes, and validated JSON
payloads, see [references/reference.md](references/reference.md) §1 and §4 (the authority — don't
duplicate it here). Money: pass `-ColumnMaxValue 0` to forbid negative amounts; Picklist: `-GlobalChoiceName` + `-DefaultValue` (option value int).

> **GOTCHA — Money columns silently floor at `MinValue = 0` (skill-gap #4).** A new Money column
> does **not** inherit the Edm currency minimum; the platform default `MinValue` is **0**, so any column
> that must hold a **negative** value — a deficit, a remaining-balance reduction, a downward rate
> adjustment, a credit — will **silently clamp/reject negatives** unless you set a negative floor
> explicitly. A build wave shipped **multiple broken Money columns** this way (a remaining-balance/deficit
> column was the worst), caught only on read-back. **Rule:** for any semantically-signed Money column, pass an explicit
> `-ColumnMinValue <negative floor>` (the platform money floor is `-922337203685477`) and **verify the
> applied `MinValue` by metadata read-back** — the create wrapper reports success even when the floor
> defaulted to 0. The default-0 also means `-ColumnMaxValue 0` already forbids negatives without a min,
> but that is the *opposite* intent; don't confuse the two.

> **Rollup & formula columns are created HEADLESSLY ([ADR 0057](../../../agent/wiki/decisions/0057-specialized-columns-via-formuladefinition-write.md)).**
> If a spec asks for a "covered asset count" or a "total value", do **not** model it as a plain
> Integer/Money and update it by hand — that silently drifts out of sync. Declare the real thing:
>
> - **`-ColumnType Rollup`** + the declarative shape `-RollupRelatedTable <child> -RollupRelationship
>   <1:N schema name> -RollupLookupColumn <child lookup>` with optional `-RollupAggregate
>   Count|Sum|Min|Max|Avg` (default Count; non-Count needs `-RollupAggregateColumn <child column>` and
>   the rollup's result type **mirrors that column's type**) and optional `-RollupFilterAttribute
>   <statecode|statuscode|choice> -RollupFilterValue <option value>` (single Equal condition). The op
>   compiles the Workflow XAML from a designer-verified template, POSTs it with `SourceType=2`, and
>   **gates on read-back** (SourceType, Invalid bit, definition round-trip, `_date`/`_state`
>   companions). Initial mass-calc runs ~12 h out — for immediate values call the **unbound**
>   `CalculateRollupField` function per record. Limits: ≤ 10 rollups/table, 1:N only, no
>   rollup-over-rollup. See [references/rollup-formula-columns-web-api.md](references/rollup-formula-columns-web-api.md).
> - **`-ColumnType Formula`** + `-FormulaExpression '<Power Fx>'` + `-FormulaResultType
>   String|Decimal|Boolean|DateTime` — the expression ships verbatim as the `FormulaDefinition`
>   (`SourceType=3`); values compute at read time, nothing to recalc. DateTime formulas land DateOnly.
> - In the `AddColumns` batch JSON these are nested objects: `"Rollup": { RelatedTable, Relationship,
>   LookupColumn, Aggregate?, AggregateColumn?, FilterAttribute?, FilterValue? }` and
>   `"Formula": { Expression, ResultType }`.
> - **Fallbacks:** a `Rollup` declared *without* its definition shape, a server-rejected definition, or
>   a failed read-back gate degrades to the legacy `[MAKER-PORTAL-TODO]` record-and-skip (a failed gate
>   also deletes the unverified column — no half-builds, #405). **`Calculated` is not built** — classic
>   calculated columns are deprecated; author the same logic as `Formula`.

> **Capability gap + composed workaround — table-level `IsAuditEnabled` (skill-gap #5).** This skill
> has no wrapper to toggle a table's audit flag. When a spec requires auditing on a table, set it with a
> composed Web API call rather than re-deriving it: `PUT EntityDefinitions(<MetadataId>)` with a body
> carrying `"@odata.type":"Microsoft.Dynamics.CRM.EntityMetadata"`, the table's **`MetadataId`**, and
> `"IsAuditEnabled":{"Value":true}` (the property is a `BooleanManagedProperty` — `{"Value":true}`, not a
> bare boolean), then publish and **read back** `EntityDefinitions(<id>)?$select=IsAuditEnabled`. Note the
> org-level **Auditing** setting must also be on, or the table flag does nothing. (Reused enough on the
> wave to warrant a wrapper later; until then this is the recipe.)

**AddColumn with Min/Max and Defaults:**

```powershell
# Decimal column with min=0, max=100, default=10.00
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_estimate" `
    -ColumnName "hso_contingency_dec" `
    -ColumnDisplayName "Contingency %" `
    -ColumnType "Decimal" `
    -Precision 2 `
    -ColumnMinValue 0 `
    -ColumnMaxValue 100 `
    -DefaultValue 10.0 `
    -SolutionName "<YourSolutionUniqueName>" `

# Picklist column with default value
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_estimate" `
    -ColumnName "hso_risklevel_code" `
    -ColumnDisplayName "Risk Level" `
    -ColumnType "Picklist" `
    -GlobalChoiceName "hso_clientrisklevel" `
    -DefaultValue 540310001 `
    -SolutionName "<YourSolutionUniqueName>"
```

**DefaultValue support by type:**

| Column Type | DefaultValue Behavior |
|-------------|----------------------|
| Integer | Sets `DefaultValue` (int) |
| Decimal | Sets `DefaultValue` (double) |
| Boolean | Sets `DefaultValue` (bool) |
| Picklist | Sets `DefaultFormValue` (option value int, e.g., 540310001) |
| Others | Not supported via Web API |

**Note:** For Integer/Decimal, the OData schema does not expose `DefaultValue` in GET responses, but it is set correctly and works at runtime. Use QueryColumn to verify min/max; verify numeric defaults via the Maker Portal.

### 3.4 Update Column Properties

Update existing column properties using the GET-modify-PUT pattern. Supports multiple property changes in a single call.

```powershell
# Enable auditing and set min/max on a decimal column
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation UpdateColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_estimate" `
    -ColumnName "hso_contingency_dec" `
    -IsAuditEnabled $true `
    -ColumnMinValue 0 `
    -ColumnMaxValue 100 `
    -SolutionName "<YourSolutionUniqueName>" `

# Set default value on a picklist column
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation UpdateColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_estimate" `
    -ColumnName "hso_risklevel_code" `
    -DefaultValue 540310001 `
    -IsAuditEnabled $true `
    -SolutionName "<YourSolutionUniqueName>" `

# Convert text field to auto-number
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation UpdateColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "account" `
    -ColumnName "accountnumber" `
    -AutoNumberFormat "{SEQNUM:6}" `
    -SolutionName "<YourSolutionUniqueName>"
# NOTE: only the auto-number FORMAT is set here; the SEED is set separately (see the seed note in §3.4 below).
```

**Supported UpdateColumn Parameters:**

| Parameter | Applies To | Description |
|-----------|-----------|-------------|
| ColumnDisplayName | All types | Update display name |
| ColumnDescription | All types | Update description |
| RequiredLevel | All types | None, ApplicationRequired, Recommended |
| IsAuditEnabled | All types | Enable/disable auditing ($true/$false) |
| IsValidForAdvancedFind | All types | Show/hide in Advanced Find ($true/$false) |
| ColumnMinValue | Integer, Decimal, Double | Minimum allowed value |
| ColumnMaxValue | Integer, Decimal, Double | Maximum allowed value |
| MaxLength | String, Memo | Maximum character length |
| Precision | Decimal, Double, Money | Decimal precision (0-10) |
| DefaultValue | Boolean, Picklist | Default value (bool for Boolean, option value int for Picklist) |
| AutoNumberFormat | String | Convert to auto-number (e.g., "{SEQNUM:6}") |

**DefaultValue limitations:**
- **Boolean**: Sets `DefaultValue` (true/false)
- **Picklist**: Sets `DefaultFormValue` (option value integer, e.g., 540310001)
- **Integer/Decimal/Double**: NOT in OData schema. Set via Maker Portal instead.

**Auto-Number Format Patterns:**

| Format | Example Output | Description |
|--------|----------------|-------------|
| `{SEQNUM:6}` | 100000 | 6-digit padded number |
| `ACC-{SEQNUM:6}` | ACC-100000 | Prefix with number |
| `{SEQNUM:6}-{RANDSTRING:4}` | 100000-AB12 | Number with random suffix |
| `{DATETIMEUTC:yyyyMMdd}-{SEQNUM:4}` | 20250107-0001 | Date prefix with sequence |

**Note — setting the seed (next number):** The *format* (above) is design-time metadata and travels in the solution; `UpdateColumn` sets it via a PUT on `StringAttributeMetadata`. The **seed** (the next sequence value) is a different thing — per-environment *runtime counter state*, deliberately **not** in metadata or the solution (so importing to QA/Prod doesn't reset a live counter to 1). It therefore can't be set by the metadata PUT, but it **is** settable via the **`SetAutoNumberSeed` unbound Web API action** — no SDK/plugin required. On a table that already has rows, **first query the current max sequence number with `hso-dataverse-data` and seed to `max + 1`** so you don't collide on the auto-number key. Compose the action via the generic invoker (no wrapper, per [ADR 0013](../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md)) — see [references/autonumber-seed-web-api.md](references/autonumber-seed-web-api.md) for the validated example.

### 3.5 Query Column Metadata

Inspect detailed metadata for a specific column, including type-specific properties:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation QueryColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_estimate" `
    -ColumnName "hso_contingencypercentage_dec"
```

**Output includes (varies by type):**

| Property | Shown For | Description |
|----------|-----------|-------------|
| LogicalName, SchemaName | All | Column identifiers |
| DisplayName, Description | All | Labels |
| AttributeType | All | String, Integer, Decimal, Picklist, etc. |
| RequiredLevel | All | None, ApplicationRequired, Recommended |
| IsAuditEnabled | All | Whether auditing is enabled |
| IsValidForAdvancedFind | All | Whether shown in Advanced Find |
| MinValue, MaxValue | Integer, Decimal, Double, Money | Value constraints |
| Precision | Decimal, Double, Money | Decimal precision |
| DefaultValue | Integer, Decimal, Boolean | Default value |
| DefaultFormValue | Picklist | Default option value |
| MaxLength | String, Memo | Character limit |
| FormatName | String | Text, Email, Url, Phone |
| AutoNumberFormat | String | Auto-number format pattern |
| GlobalOptionSet | Picklist | Referenced global choice name |
| Format, DateTimeBehavior | DateTime | Date format and timezone behavior |

See [references/reference.md](references/reference.md) for complete type specifications and Web API JSON structures.

### 3.6 Delete Column (guarded)

Deletes a custom column. **Guarded**: before deleting, it runs the `RetrieveDependenciesForDelete`
preflight and **refuses** — listing the blocking forms/views by friendly name — if the column is still
referenced, instead of firing a `DELETE` that fails opaquely. It also refuses outright on the table's
**primary name column** (the platform never allows deleting it, dependencies or not).

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation DeleteColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_estimate" `
    -ColumnName "hso_obsolete_field_text"
    # add -Force to bypass the dependency refusal (use only after you've confirmed the dependents are acceptable)
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| TableName | Yes | Logical name of the table |
| ColumnName | Yes | Logical name of the column to delete |
| Force | No | Bypass the dependency-preflight refusal. The primary-column guard is **absolute** and cannot be bypassed. |

To **inspect** dependencies first (read-only) without attempting a delete — and to understand the
component-type codes the refusal prints — see
[references/column-dependencies-web-api.md](references/column-dependencies-web-api.md).

---

## 4. RELATIONSHIP OPERATIONS

> ⚠️ **Solution portability — parent tables are now auto-included.** Every parent/referenced table must be
> in the target solution before the relationship create, or the relationship **silently drops on export**.
> The relationship ops now do this automatically (metadata-only, idempotent — Customer adds `account` +
> `contact`, polymorphic adds every target), emitting a `[SOLUTION]` line per auto-include. Background +
> remediation: [references/relationship-solution-portability.md](references/relationship-solution-portability.md).

### 4.1 One-to-Many (1:N) Relationship

Creates a lookup column on the child table pointing to the parent.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateRelationship `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -RelationshipType OneToMany `
    -ParentTable "hso_project" `
    -ChildTable "hso_task" `
    -LookupName "hso_project_id" `
    -LookupDisplayName "Project" `
    -LookupDescription "The project this task belongs to. Drives roll-up of hours and status to the project record." `
    -CascadeDelete "RemoveLink" `
    -CascadeAssign "NoCascade" `
    -SolutionName "<YourSolutionUniqueName>"
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| RelationshipType | Yes | `OneToMany`, `ManyToMany`, or `Customer` |
| ParentTable | Yes (1:N) | Logical name of the parent (referenced) table |
| ChildTable | Yes (1:N) | Logical name of the child (referencing) table |
| LookupName | Yes (1:N) | Schema name of the lookup column on the child table |
| LookupDisplayName | Yes (1:N) | Display name of the lookup column |
| **LookupDescription** | **Yes (HSO standard, 1:N + Customer + Polymorphic)** | Description on the generated lookup column. Renders as the tooltip in model-driven apps. Warning emitted if missing. |
| CascadeDelete | No | `RemoveLink` (default), `Cascade`, `Restrict`, `NoCascade` |
| CascadeAssign | No | `NoCascade` (default), `Cascade`, `Active` |
| RequiredLevel | No | Requirement level for the generated lookup: `None` (default), `ApplicationRequired`, `Recommended`. Set this inline to make the lookup mandatory at creation — no follow-up `UpdateColumn` needed. Also supported on `Customer`. |
| **RelationshipSchemaName** | No | **Override the auto-generated relationship schema name.** Required when creating a second relationship between the same two tables — the auto-derived name would collide. Example: `hso_paymentmethod_customersubscription_backup` |

After a 1:N create the script reads the relationship back and reports the actual cascade-delete on a `[CASCADE]` line; if it differs from the requested `-CascadeDelete` (e.g. a `Cascade` that silently landed as the default `RemoveLink`) a `[WARN]` names requested vs actual.

**Duplicate relationships between the same tables:**

When you need two lookups from the same child table to the same parent table (e.g., primary payment method and backup payment method both pointing from `hso_customersubscription` to `hso_paymentmethod`), the auto-generated schema name would be identical for both. Use `-RelationshipSchemaName` to specify a unique name for the second relationship:

```powershell
# First relationship (auto-named hso_paymentmethod_customersubscription)
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateRelationship `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -RelationshipType OneToMany `
    -ParentTable "hso_paymentmethod" `
    -ChildTable "hso_customersubscription" `
    -LookupName "hso_paymentmethodid_id" `
    -LookupDisplayName "Payment Method" `
    -SolutionName "<YourSolutionUniqueName>" `

# Second relationship — must override schema name to avoid collision
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateRelationship `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -RelationshipType OneToMany `
    -ParentTable "hso_paymentmethod" `
    -ChildTable "hso_customersubscription" `
    -LookupName "hso_backuppaymentmethod_id" `
    -LookupDisplayName "Backup Payment Method" `
    -RelationshipSchemaName "hso_paymentmethod_customersubscription_backup" `
    -SolutionName "<YourSolutionUniqueName>"
```

**Cascade Options:**

| Value | Delete Behavior | Use Case |
|-------|-----------------|----------|
| `Cascade` | Delete children | Tightly coupled records |
| `RemoveLink` | Clear lookup | **Recommended default** |
| `Restrict` | Block if children exist | Protect child records |
| `NoCascade` | No effect | Independent records |

### 4.2 Many-to-Many (N:N) Relationship

Creates an intersection table automatically.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateRelationship `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -RelationshipType ManyToMany `
    -Entity1 "hso_project" `
    -Entity2 "hso_resource" `
    -IntersectEntityName "hso_project_resource" `
    -SolutionName "<YourSolutionUniqueName>"
```

### 4.3 Customer Lookup

Allows referencing either Account OR Contact (fixed pair — use `CreatePolymorphicLookup` for other entity combinations):

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateRelationship `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -RelationshipType Customer `
    -ChildTable "hso_task" `
    -LookupName "hso_customer_id" `
    -LookupDisplayName "Customer" `
    -LookupDescription "Account or contact this task is for. Renders as the field tooltip." `
    -RequiredLevel "ApplicationRequired" `
    -SolutionName "<YourSolutionUniqueName>"
```

`-LookupDescription` is required (HSO descriptions-mandatory standard). `-RequiredLevel` is optional
(`None` default; pass `ApplicationRequired`/`Recommended` to make the lookup mandatory at creation
instead of a follow-up `UpdateColumn`). The op auto-includes `account` **and** `contact` in the solution
(see the portability note at the top of §4).

### 4.4 Polymorphic Lookup (Arbitrary Entity Pairs)

Use when the lookup needs to target any combination of entities other than the fixed Account + Contact pair. Uses the `CreatePolymorphicLookupAttribute` Web API action.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreatePolymorphicLookup `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -ChildTable "contoso_eventattendee" `
    -LookupName "contoso_attendeeid" `
    -LookupDisplayName "Attendee" `
    -TableNames @("contact", "hso_customer_employee") `
    -SolutionName "<YourSolutionUniqueName>"
```

**Notes:**
- `-TableNames` accepts 2 or more entity logical names
- Relationship schema names are auto-generated as `{prefix}_{referencedentity}_{childtable}_{lookupfield}`
- All relationships are created with `CascadeDelete = RemoveLink` (safe default for polymorphic lookups)

### 4.6 Query Relationships

Discover all relationships for a table. Useful for finding relationship schema names when configuring subgrids.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation QueryRelationships `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_contract"
```

**Output includes:**

| Section | Description | Use Case |
|---------|-------------|----------|
| 1:N Relationships | Table is parent, shows child tables and lookup fields | **Subgrid configuration** - use SchemaName as RelationshipName |
| N:1 Relationships | Table has lookups to other tables | Understanding parent references |
| N:N Relationships | Many-to-many relationships | Associated grids |

**Example Output:**
```
[1:N Relationships] (Table is PARENT - use for subgrids showing child records)
    Relationship: hso_contract_amendment
    Child Table:  hso_amendment
    Lookup Field: hso_contract_id
    -> For subgrid: RelationshipName = 'hso_contract_amendment'
```

---

### 4.7 Relationship Field Mappings (AddRelationshipMapping)

**Opt-in, no defaults.** For a custom 1:N, Dataverse auto-fills only the parent lookup on a child created from the parent's subgrid (**+New**). Field mappings copy ADDITIONAL parent columns onto that new child. They fire **only** on create-from-parent-subgrid — never on import, direct create, or quick-create elsewhere. They are not auto-created and carry no defaults, so they must always be stated explicitly. Do **not** map the parent lookup itself — the platform already sets it.

Each mapping is a `{Source, Target}` pair (`Source` = parent column, `Target` = child column). Pairs must be **type-compatible** (same `AttributeType`; for Lookup/Customer the target sets must overlap) — an incompatible or non-existent pair emits a counted `[WARN]` and is skipped (the rest still apply). The op is idempotent: an existing `entitymap`/`attributemap` is reused, and it reads back `[READBACK] mappings: N/M present [...]`.

**Dual-use.** Either declare mappings inline / in a file, or read them from a spec.

Explicit (inline or `-MappingsFile`, which wins if both are given):
```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddRelationshipMapping `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -ParentTable "hso_serviceagreement" -ChildTable "hso_coveredasset" `
    -MappingsFile ".\mappings.json" `
    -SolutionName "HSOServiceAgreements"
```
`mappings.json` (same inline-array shape as `-Columns`):
```json
[ { "Source": "hso_region_choice", "Target": "hso_region_choice" } ]
```
(`-ParentTable`/`-ChildTable` may be omitted if you pass `-RelationshipSchemaName` — parent/child resolve from the relationship metadata.)

Spec-driven — applies every `relationships[]` entry that declares `mappings` (each with `source`/`target`), resolving parent/child from the entry's `parent`/`child`:
```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddRelationshipMapping `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -SpecJsonPath ".\spec.json" `
    -SolutionName "HSOServiceAgreements"
```

---

## 5. GLOBAL CHOICE OPERATIONS

**CRITICAL:** Choice fields should ALWAYS use Global Choices, not local option sets.

### 5.1 Create Global Choice

A global choice is a **declared contract**: each option may carry an explicit `Value` and a `Color` (`#RRGGBB`). After create the script **reads the set back and asserts label/value/color** — a missing/mismatched value `[FATAL]`s (exit 1); color drift `[WARN]`s.

A choice gets a **default Description** when none is supplied (`<DisplayName> — global choice (<N> options): label1, label2, …`) — never blank, satisfying the mandatory-description standard.

`CreateGlobalChoice -Options …` builds a choice directly from explicit options (label/value/color) — first-class, the normal way when working conversationally (`-Options ($json | ConvertFrom-Json)` via the call-operator form; values auto-generate from the publisher prefix when omitted, any positive `Value` honored verbatim). Example: `-ChoiceName "hso_projectstatus" -ChoiceDisplayName "Project Status" -ChoiceDescription "…" -Options ($optionsJson | ConvertFrom-Json)` where `$optionsJson = '[{"Label":"Low","Value":540310000,"Color":"#00B050"},{"Label":"High","Value":540310001,"Color":"#C00000"}]'`. Labels must be exact (the read-back asserts them).

`CreateGlobalChoice -SpecJsonPath <spec.json>` with NO `-ChoiceName` renders **EVERY** declared `choices[]` entry in one invocation, each with its exact declared label/value/color, read-back-asserting the declared labels per choice — the convenience when you HAVE an architect spec.

```powershell
& ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateGlobalChoice `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -SpecJsonPath "agent/work/specs/<Feature>/spec.json" `
    -SolutionName "<YourSolutionUniqueName>"
```

(Pass `-ChoiceName` alongside `-SpecJsonPath` to render just the one matching `choices[]` entry.)

> Neither path is preferred at the skill level — pick whichever matches how you're working. When transcribing options by hand, get each `Label` exactly right (the read-back asserts label/value/color); when you have a spec, `-SpecJsonPath` saves you from re-keying them.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| ChoiceName | Yes | Schema name (e.g., `hso_projectstatus`) |
| ChoiceDisplayName | Yes | Display name shown in UI |
| ChoiceDescription | No | Description of the global choice |
| Options | Yes* | Array of `{Label, Value?, Color?}` (`Value` explicit/auto; `Color` = `#RRGGBB`). *Or supply `-SpecJsonPath` to read `choices[]`. |

When a value is omitted the script queries the publisher's `customizationoptionvalueprefix` (e.g. 54031) and generates 540310000, 540310001, …

### 5.2 Add Choice Column to Table

After creating the global choice, add a column that references it:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddColumn `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_project" `
    -ColumnName "hso_status_code" `
    -ColumnDisplayName "Status" `
    -ColumnType "Picklist" `
    -GlobalChoiceName "hso_projectstatus" `
    -SolutionName "<YourSolutionUniqueName>"
```

### 5.3 Update Global Choice Options

Update existing option labels or add new options to a global choice:

```powershell
# Add a new option (JSON approach)
$optionsJson = '[{"Label":"Archived"}]'

& ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation UpdateGlobalChoice `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -ChoiceName "hso_projectstatus" `
    -Options ($optionsJson | ConvertFrom-Json) `
    -SolutionName "<YourSolutionUniqueName>"
```

**Behavior:**
- If an option's `Value` already exists in the choice: **Updates the label** using `UpdateOptionValue`
- If the `Value` doesn't exist: **Adds a new option** using `InsertOptionValue`
- If no `Value` is provided: **Auto-generates** a value and adds the option

**Example - Update existing option labels:**

```powershell
# Update labels on existing values (e.g., fixing legacy migration)
$optionsJson = '[{"Value":818440000,"Label":"Non-Substitute Care"},{"Value":818440001,"Label":"Substitute Care"},{"Value":818440002,"Label":"None"},{"Value":818440003,"Label":"Grant"},{"Value":818440004,"Label":"Standard"}]'

& ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation UpdateGlobalChoice `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -ChoiceName "hso_contracttype" `
    -Options ($optionsJson | ConvertFrom-Json) `
    -SolutionName "ContosoContracts"
```

The operation will show:
- `[UPDATE]` for existing values where the label is being changed
- `[ADD]` for new values being inserted
- `[SKIP]` for existing values where the label already matches

### 5.4 Query Global Choice

Inspect an existing global choice's options before deciding to extend, rename, or create a sibling. Especially important for generic names (e.g. `hso_accounttype`) that another solution may already own with different semantics.

```powershell
powershell -ExecutionPolicy Bypass -Command "& '.claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1' `
    -Operation QueryGlobalChoice `
    -EnvironmentUrl 'https://yourorg.crm.dynamics.com' `
    -ChoiceName 'hso_accounttype'"
```

**Returns** a structured object with `Name`, `DisplayName`, `Description`, `IsCustom`, `IsManaged`, `MetadataId`, and an `Options` array (each entry with `Value` and `Label`). Returns `$null` if the choice does not exist (404).

**When to use:** Before `CreateGlobalChoice` with a generic name, or before `UpdateGlobalChoice` when you need to know which option values already exist (to add vs. rename vs. skip).

### 5.5 Status Value Operations (statuscode)

The built-in `statuscode` field uses **local option sets** (not global choices) and each value must be linked to a `statecode` (Active=0 or Inactive=1).

**IMPORTANT:** Use statuscode for record lifecycle tracking instead of custom status fields. See `agent/work/analysis/IsActive_AntiPattern_Analysis.md` for rationale.

> **Model the FULL lifecycle, not just the shipped defaults.** A typical custom lifecycle needs a four-value, default-active pattern (e.g. Draft / Active / Suspended / Expired) with the `statecode` default = Active — but the shipped `statuscode` has only Active(1) / Inactive(2) and the shipped `statecode` default is *Inactive*. Model the full lifecycle with `AddStatusValue` **and** set the default-active value before considering the table done. Use [`references/statuscode-lifecycle-web-api.md`](references/statuscode-lifecycle-web-api.md) (set-default / hide / delete via Web API actions) and SOP §10 ([Lifecycle — statecode and statuscode](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md#10-lifecycle--statecode-and-statuscode-never-custom-isactive)) as the lifecycle recipe — do not stop at the shipped two-value default.

#### Add Status Value

Add a new status reason value to an entity:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddStatusValue `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_contract" `
    -StatusLabel "Planning" `
    -StateCode 0 `
    -SolutionName "<YourSolutionUniqueName>"
```

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| TableName | Yes | - | Logical name of the table |
| StatusLabel | Yes | - | Label for the status value |
| StatusValue | No | Auto | Value for the status (auto-generated if not provided) |
| StateCode | Yes | 0 | State to link to: 0 = Active, 1 = Inactive |

**Example - Adding Contract Lifecycle Statuses:**

```powershell
# Active states (StateCode = 0)
-Operation AddStatusValue -TableName "hso_contract" -StatusLabel "Draft" -StateCode 0 ...
-Operation AddStatusValue -TableName "hso_contract" -StatusLabel "Planning" -StateCode 0 ...
-Operation AddStatusValue -TableName "hso_contract" -StatusLabel "Pending Execution" -StateCode 0 ...
-Operation AddStatusValue -TableName "hso_contract" -StatusLabel "Executed" -StateCode 0 ...

# Inactive states (StateCode = 1)
-Operation AddStatusValue -TableName "hso_contract" -StatusLabel "Expired" -StateCode 1 ...
-Operation AddStatusValue -TableName "hso_contract" -StatusLabel "Terminated" -StateCode 1 ...
```

> **⚠️ Issue these calls SERIALLY — never in parallel.** Each `AddStatusValue` maps to one Dataverse `InsertStatusValue` request, and when `-StatusValue` is omitted the platform auto-assigns *the next available option value* at execution time. Two calls fired concurrently both read the same "next value" and collide (observed: `Draft` and `Suspended` were both assigned `541000000`, forcing a retry). The platform has **no batch/insert-many message for status values** (unlike a global choice, where `CreateOptionSet` builds all options in one call), so adding the full lifecycle is inherently N calls — run them **one after another**, waiting for each to return before issuing the next. If you must avoid the round-trips, pass an explicit, non-colliding `-StatusValue` on every call instead of relying on auto-assignment. **Prefer `SetLifecycle` (below) — it does exactly this, with explicit values, and read-back-asserts the result.**

#### Set Default Status (`SetStatusDefault`)

Repoint a state's default-active statuscode (the `UpdateStateValue` action — a `statecode` metadata PATCH silently no-ops). See [references/statuscode-lifecycle-web-api.md](references/statuscode-lifecycle-web-api.md) §2.

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation SetStatusDefault `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_contract" -StateCode 0 -DefaultStatusValue 975310001 `
    -SolutionName "<YourSolutionUniqueName>"
```

#### Set Lifecycle (`SetLifecycle`) — full statuscode contract

Renders a table's **entire** statuscode lifecycle as a read-back contract: inserts every declared reason **serially with explicit values** (no auto-gen collision); a declared value that collides with a shipped reason carrying a different label (e.g. `1`=Active/`2`=Inactive vs. declared Draft/Expired) is **relabeled, not skipped**. It then sets the default via `SetStatusDefault`, reads the full set back and **asserts declared-vs-actual** (label + value + default). On mismatch it prints a `LIFECYCLE INCOMPLETE` banner and exits non-zero — so a half-built lifecycle can't be mistaken for done. This closes the weak-tier "stops at the shipped 2-value default" gap.

Pass the lifecycle directly via `-StatusReasons` (first-class) — `[{Label, State(0|1), Value?, Default?}]`, JSON-converted; mark exactly one option per state `"default": true`, omit `Value` to let the op assign an explicit non-colliding value. Or, when you have an architect spec, read it from the `statusReasons[]` entry whose `table` matches `-TableName` with `-SpecJsonPath`:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation SetLifecycle `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_contract" `
    -SpecJsonPath "agent/work/specs/<Feature>/spec.json" `
    -SolutionName "<YourSolutionUniqueName>"
```

#### Update Status Label

Rename an existing status value:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation UpdateStatusLabel `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_contract" `
    -StatusValue 2 `
    -StatusLabel "Terminated" `
    -SolutionName "<YourSolutionUniqueName>"
```

This is useful for renaming the default "Inactive" status (value=2) to something more meaningful like "Terminated".

---

## 6. ALTERNATE KEY OPERATIONS

Alternate keys enable unique identification of records beyond the primary key, essential for data integration scenarios.

### 6.1 Create Alternate Key

Create an alternate key on a table:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateAlternateKey `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_awardcode" `
    -KeySchemaName "hso_code_key" `
    -KeyDisplayName "Code Key" `
    -KeyColumns @("hso_code_text") `
    -SolutionName "<YourSolutionUniqueName>"
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| TableName | Yes | Logical name of the table |
| KeySchemaName | Yes | Schema name for the key (e.g., "hso_code_key") |
| KeyDisplayName | Yes | Display name for the key |
| KeyColumns | Yes | Array of column logical names that make up the key |

**Constraints:**
- Maximum 16 columns per key
- Maximum 10 alternate keys per table
- Total key size must not exceed 900 bytes (SQL index limit)
- Only these column types are supported: Text, Whole Number, Decimal, DateTime, Lookup, Choice

**Index Creation:**
Alternate key index creation is **asynchronous**. The key status will progress through:
- **Pending**: Index creation not started
- **In Progress**: Index being created
- **Active**: Ready to use
- **Failed**: Index creation failed (check async job for details)

**Verify status with `QueryAlternateKeys`** (don't drop to raw Web API just to read `EntityKeyIndexStatus`):

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation QueryAlternateKeys `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_awardcode"
# Lists each key: SchemaName, [KeyAttributes], and Status (Pending / In Progress / Active / Failed).
# Poll this until the key reports Active before relying on it for upserts/integration.
```

### 6.2 Composite Key Example

Create a key with multiple columns:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateAlternateKey `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hso_contractrate" `
    -KeySchemaName "hso_contract_service_key" `
    -KeyDisplayName "Contract-Service Key" `
    -KeyColumns @("hso_contract_id", "hso_servicecode_id") `
    -SolutionName "<YourSolutionUniqueName>"
```

### 6.3 Common Use Cases

| Use Case | Example Key Columns |
|----------|-------------------|
| External system ID | `hso_externalid_text` |
| Natural key lookup | `hso_code_text` |
| Composite business key | `hso_contract_id`, `hso_servicecode_id` |
| Integration mapping | `hso_sourcerecordid_text` |

---

## 7. PUBLISHING CUSTOMIZATIONS

After creating components, publish to make them available:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation Publish `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TablesToPublish @("hso_project", "hso_task", "hso_resource") `
    -SolutionName "<YourSolutionUniqueName>"
```

To publish all customizations:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation PublishAll `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -SolutionName "<YourSolutionUniqueName>"
```

---

## 8. NAMING CONVENTIONS

All custom fields carry **the project's publisher prefix** and a suffix indicating data type.

**Field Naming Pattern:** `<prefix>_<fieldname>_<suffix>`

> **`<prefix>` is the project's, not a constant.** It is resolved per run from the project's
> `CLAUDE.md` (`| Publisher prefix | … |`), then README, then by prompting — there is no default.
> The examples below use `hso` because these docs live in an HSO repo; on a project whose prefix is
> `abc`, every example below reads `abc_…`. See [§ Publisher prefix resolution](#publisher-prefix-resolution).

| Data Type | Suffix | Example |
|-----------|--------|---------|
| Single Line Text | `_text` | `hso_projectname_text` |
| Multi-Line Text | `_memo` | `hso_description_memo` |
| Whole Number | `_num` | `hso_quantity_num` |
| Decimal | `_dec` | `hso_percentage_dec` |
| Currency | `_amt` | `hso_totalcost_amt` |
| Yes/No | `_yn` | `hso_isverified_yn` |
| Date/DateTime | `_date` | `hso_duedate_date` |
| Choice | `_code` | `hso_status_code` |
| Multi-Select | `_codes` | `hso_tags_codes` |
| Lookup | `_id` | `hso_account_id` |
| File| `_file` | `hso_application_file` |
| Image | `_image` | `hso_profilephoto_image` |

**IMPORTANT:**
- Choice fields MUST use Global Choices (not local option sets)
- Lookup fields follow the same pattern: `<prefix>_<referencedtable>_id`

**PROHIBITED - Custom "Is Active" Fields:**
- **NEVER** create `hso_isactive_yn` fields to track active/inactive status
- Use the built-in `statecode` field instead (every table has this automatically)
- `statecode = 0` (Active), `statecode = 1` (Inactive)
- Platform features like view filtering, lookup filtering, Deactivate/Activate buttons, and Recycle Bin all use statecode
- See [`shared/dv/agent/wiki/sop/dataverse-naming-conventions.md`](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) for details

---

## 9. WORKFLOW: COMPLETE DATA MODEL

For a step-by-step example creating a complete data model with tables, relationships, and global choices, see [references/workflow-example.md](references/workflow-example.md).

**Quick Summary:**
1. Create solution (if needed)
2. Plan the data model (tables, relationships, choices)
3. Create global choices FIRST
4. Create tables OR add existing tables to solution
5. Add columns (including choice columns referencing global choices)
6. Create relationships (1:N, N:N)
7. Publish customizations
8. Verify with QueryTable operation

---

## 10. TROUBLESHOOTING

| Issue | Solution |
|-------|----------|
| Authentication not resolved | Verify the environment settings and rerun; auth is resolved automatically |
| "Table already exists" | Use QueryTable first to check |
| "Invalid column type" | Check types in [references/reference.md](references/reference.md) |
| "Relationship creation failed" | Verify both tables exist and are published |
| "Global choice not found" | Create and publish choice before referencing |
| "Authentication failed" | Check your Office 365 credentials |
| "MSAL.PS module not found" | Module is auto-installed on first use |
| "Publisher not found" | Use valid publisher unique name or prefix |
| "Table not found for AddTableToSolution" | Verify table exists with QueryTable first |

---

## 11. MODEL-DRIVEN APP OPERATIONS

### 11.1 Create App

> **Pick one — don't double-create.** `CreateApp` + `AddTablesToApp` build a model-driven app directly from explicit parameters (first-class for manual / non-spec work). For a SPEC-driven build, ui-config `BuildSiteMap -SpecJsonPath` can **self-create** the app from `spec.app` (exact `uniqueName`/prefix) and render the sitemap in one write — so let it own the app rather than pre-creating one here, or the two collide into a duplicate / wrong-prefix app that breaks the sitemap build.

Create a new model-driven app (Unified Interface):

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateApp `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -AppUniqueName "ContosoContracts" `
    -AppDisplayName "Contoso Contracts" `
    -AppDescription "Contract management application" `
    -SolutionName "<YourSolutionUniqueName>"
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| AppUniqueName | Yes | Unique name (script adds publisher prefix if not present) |
| AppDisplayName | Yes | Display name shown in app launcher |
| AppDescription | No | Description of the app |

**Notes:**
- The script automatically prefixes with the project's publisher prefix if not already prefixed
- Client type is set to 4 (Unified Interface / Web)

> **Idempotent — no manual App Designer step needed.** A fresh app is *unpublished*, not invisible:
> a plain `GET /appmodules` returns published rows only (so it appears to 404), but the script's
> lookups use `RetrieveUnpublishedMultiple`, so `CreateApp`'s existence check sees it (no duplicate on
> re-run) and `QueryApp`/`AddTablesToApp`/`PublishApp` all work right after `CreateApp`. You still run a
> real `PublishApp` before end users can use it. `AddTablesToApp` auto-provisions a sitemap (a bare app
> is invalid — won't publish, can't delete), so `CreateApp → AddTablesToApp → PublishApp` needs no manual step.

> **In a slice-DAG build, app membership is the app/sitemap assembly slice's write, not the entity slice's.** An
> executor building an `entity` slice does **not** `AddTableToApp` its own table — the app is a shared artifact
> with one writer (`BuildSiteMap`, which registers every declared table + `app.unsurfacedTables[]` as components and
> reads `appmodulecomponents` back). The operations below are for standalone / manual work and one-off retrofits.
> **`AddTablesToApp` now carries every existing entity component forward** (SaveAppModule REPLACES the app's element
> set — the round-3 remediation call that listed only the 16 new tables silently dropped `hso_contract`), **publishes
> the app + sitemap** (scoped `PublishXml`) after the save, and reads the **published** generation back — a saved
> draft that is never published looks correct to unpublished-aware queries and wrong to every user (E2E round-3 F-02).

### 11.2 Add Table to App

> **⚠️ UNDOCUMENTED API.** This uses **SaveAppModule** (internal to the Maker Portal, unsupported, may
> change). **Inform the user and get explicit confirmation before running.** Use it **only for initial
> app setup** (adding multiple tables at once); make subsequent changes in the Maker Portal UI.

Add a table to an existing model-driven app:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation AddTableToApp `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -AppUniqueName "hso_ContosoContracts" `
    -TableName "hso_contract" `
    -SolutionName "<YourSolutionUniqueName>"
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| AppUniqueName | Yes | Unique name of the app (with or without prefix) |
| TableName | Yes | Logical name of the table to add |

**How it works:**
1. Retrieves all existing app elements (tables, sitemap, etc.)
2. Adds the new table to the elements list
3. Calls SaveAppModule with the complete payload (all elements must be included or they will be removed)

> **⚠️ WARNING:** Sequential `AddTableToApp` calls overwrite each other (`appmodulecomponents` only reflects *published* changes). Use **AddTablesToApp** (§11.2.1) to add multiple tables in one call.

### 11.2.1 Add Multiple Tables to App (Recommended)

Add multiple tables to an existing model-driven app in a **single call**:

```powershell
powershell -ExecutionPolicy Bypass -Command "& '.claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1' `
    -Operation AddTablesToApp `
    -EnvironmentUrl 'https://yourorg.crm.dynamics.com' `
    -AppUniqueName 'hso_ContosoContracts' `
    -TableNames @('hso_contract','hso_amendment','hso_contractrate','account','contact') `
    -SolutionName '<YourSolutionUniqueName>'"
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| AppUniqueName | One of | Unique name of the app (with or without prefix). |
| AppModuleId | One of | Direct GUID of the app module — bypasses the uniquename lookup. Provide either `AppUniqueName` or `AppModuleId`. (With the unpublished-aware lookups, `AppUniqueName` now resolves unpublished apps too; `AppModuleId` remains a precise escape hatch when you already hold the GUID.) |
| TableNames | Yes | Array of table logical names to add |

**How it works:**
1. Retrieves all existing app elements (tables, sitemap, etc.)
2. **If the app has no sitemap, provisions a default `isappaware` sitemap** seeded with one SubArea per table being added (what App Designer does on first open+save). This is required: an app with no sitemap is invalid — it won't publish and can't be deleted.
3. Gets entity IDs for ALL specified tables
4. Builds a single payload with all tables + sitemap
5. Calls SaveAppModule ONCE with the complete payload

Guarantees the resulting app is valid (publishable + cleanly deletable). Works on freshly-created (unpublished) apps — the lookups use `RetrieveUnpublishedMultiple`, so neither `-AppUniqueName` nor `-AppModuleId` needs a prior App Designer save+publish (see §11.1).

### 11.3 Query App

Query details of a model-driven app:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation QueryApp `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -AppUniqueName "ContosoContracts"
```

Returns app details including name, description, version, and list of components.

### 11.4 Publish App

Publish a model-driven app to make changes visible to users:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation PublishApp `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -AppUniqueName "hso_ContosoContracts"
```

---

## Related Documentation

- [references/reference.md](references/reference.md) - Complete type codes and Web API patterns
- [references/workflow-example.md](references/workflow-example.md) - Step-by-step data model creation
- [references/statuscode-lifecycle-web-api.md](references/statuscode-lifecycle-web-api.md) - Custom statuscode/statecode lifecycle (hide / delete / set-default) via Web API actions — composed, not wrapped ([ADR 0013](../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md))
- [references/column-dependencies-web-api.md](references/column-dependencies-web-api.md) - Read-only: which components block a column's deletion ([ADR 0013](../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md))
- [references/autonumber-seed-web-api.md](references/autonumber-seed-web-api.md) - Setting an auto-number **seed** via the `SetAutoNumberSeed` action (query max with `hso-dataverse-data` first) — composed, not wrapped ([ADR 0013](../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md))
- [references/relationship-solution-portability.md](references/relationship-solution-portability.md) - **Add every parent (referenced) table to the solution *before* creating a relationship** — OOB parents added metadata-only (`AddTableToSolution -DoNotIncludeSubcomponents $true`). Skipping this auto-adds the parent with ALL assets (dev) and silently drops the relationship on export (deploy). Orchestration of existing operations, not a wrapper ([ADR 0013](../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md))
- [references/remove-solution-component-web-api.md](references/remove-solution-component-web-api.md) - **Take an over-included component back OUT of a solution** (e.g. an OOB `account`/`contact` pulled in as a relationship dependency) via `RemoveSolutionComponent` — note the signature is NOT symmetric with the add side and varies between environments (inspect `$metadata` first). Removing ≠ deleting. Composed, not wrapped ([ADR 0013](../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md))
- [`shared/dv/agent/wiki/sop/dataverse-metadata-and-web-api-queries.md`](../../../shared/dv/agent/wiki/sop/dataverse-metadata-and-web-api-queries.md) - Web API query patterns
- [`shared/dv/agent/wiki/sop/dataverse-naming-conventions.md`](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) - Complete naming conventions reference
