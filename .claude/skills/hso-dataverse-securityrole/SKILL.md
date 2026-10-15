---
name: hso-dataverse-securityrole
layer: atomic
scope: core
description: |
  Create, modify, retrieve, and delete Dataverse security roles and their privilege assignments using the Web API. Also generate Security Role Matrix documentation in Excel format. Use when the user asks to:
  - Create a new security role
  - Add, remove, or replace privileges on a security role
  - Query existing security roles and their privileges
  - Look up privilege names/IDs for tables
  - Assign or remove a security role for a user, or list which roles a user holds
  - Delete a security role
  - Generate security role documentation/matrix
  - Document table privileges and role permissions
  - Create role-based access control documentation
  - Understand security role XML structure in unpacked solutions (Roles/*.xml)
  Uses PowerShell scripts with Web API for all operations.
---

# Dataverse Security Role Skill

Create and manage Dataverse security roles and privilege assignments via the Web API.

## Slice Consumption Contract (executor side of the architect→builder pipeline)

**Authority:** [`slice-consumption-contract-best-practices.md`](../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md) — read before building any slice inside the pipeline. That SOP is the **canonical, executor-side contract** for [ADR 0018](../../../agent/wiki/decisions/0018-agentic-delivery-architect-builder-pipeline.md)'s architect→builder pipeline (the five rules, single-writer, reviewable-unit, anti-mis-attribution). The summary here is a labeled pointer, not a substitute.

When the architect routes a slice to this skill you are handed **the spec + its `spec.json` sidecar + a target slice `id`**. Build **exactly that slice's `touches`** and nothing more; trust and verify — don't rebuild — your `blocked_by` slices; honor the **privilege depth the spec set** for each table; **read back against the slice's `acceptance`, not against an SOP rule the spec never invoked**; and end at the **unmanaged solution** named in `spec.json` (never export-as-managed or deploy). **Never over-privilege beyond the slice's `acceptance`** — no `prvDelete` / admin-depth the spec did not grant.

| When a slice's `touches` include… | What this skill owns | Read-back against `acceptance` |
|---|---|---|
| a **security role** + privilege depth | the role + its role privileges at exactly the depth the slice's acceptance specifies (no more) | `RetrieveRolePrivilegesRole(RoleId=…)` — returns `PrivilegeName` + `Depth` (see [Web API Reference](#web-api-reference)); confirm the **presence** of granted privileges at the right **depth**, **and the absence** of any the slice excluded |

> All executor skills share the **same** [Slice Consumption Contract](../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md).

## Authoritative Best Practices

**Mandatory pre-read before any role design or privilege assignment work**: [`shared/dv/agent/wiki/sop/security/security-best-practices.md`](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md). This is the HSO methodology that governs *what* roles, teams, BUs, and sharing should look like — this skill executes the *how*.

| When you are about to | Read this section of the SOP |
|-----------------------|------------------------------|
| Decide whether to recommend matrix-mode or legacy-hierarchy BUs | [§3 Modern Matrix Data Access Structure](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#3-business-units--the-modern-matrix-data-access-structure) and [§4 BU design — flat, hierarchical, or matrix](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#4-business-unit-design--flat-hierarchical-or-matrix) |
| Decide privilege depths for a new role | [§5 Privileges and access depths](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#5-security-roles--privileges-and-access-depths) |
| Decide whether to author one big role or several small ones | [§6 Role design patterns — modular over monolithic](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#6-security-role-design-patterns--modular-over-monolithic) |
| Decide whether copying System Administrator is acceptable (it isn't) | [§7 OOB roles and the System Administrator rule](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#7-out-of-the-box-roles-and-the-system-administrator-rule) |
| Choose Owner / Access / Entra Group team | [§8 Teams](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#8-teams--owner-access-and-microsoft-entra-group) |
| Configure record sharing (or push back on it) | [§9 Sharing and POA](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#9-sharing-and-the-principalobjectaccess-poa-table) |
| Decide whether to enable Hierarchy Security | [§10 Hierarchy security](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#10-hierarchy-security--manager-and-position) |
| Secure a column with a Field Security Profile | [§11 Column-level security](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#11-column-level-security-field-security-profiles) |
| Custom API `ExecutePrivilegeName` — HSO ruling (2026-06-13): leave empty, table privileges govern; not required and not a finding | [§12 Custom API ExecutePrivilegeName](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#12-custom-api-executeprivilegename) |
| Plan ALM — what travels in solutions vs what is environment config | [§15 ALM](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#15-alm--what-travels-in-solutions-and-what-doesnt) |
| Set numeric thresholds for the customer (POA size, hierarchy depth, role count) | [§16 Performance rules](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#16-performance-rules) |
| Recognise an anti-pattern in an existing environment | [§18 Anti-patterns](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#18-anti-patterns) |
| Sign off a security review before merge / deploy | [§19 Pre-merge and pre-deploy checklist](../../../shared/dv/agent/wiki/sop/security/security-best-practices.md#19-pre-merge-and-pre-deploy-checklist) |
| Provision an application user for an integration SPN (Function / Logic App / Power Automate / external system) | [Azure Integration SOP §8 — Authentication and identity](../../../shared/dv/agent/wiki/sop/azure-integration/azure-integration-best-practices.md#8-authentication-and-identity), particularly §8.4 (**HSO Override: never grant System Administrator to an application user**; custom role mandatory) and §8.5 (one application user per integration purpose with `<env>-<purpose>-integration` naming) |

**Rule:** when this skill's quick-reference tables (privilege naming, depth values, XML schema) and the SOP differ, **the SOP wins**. Ping Ivan to update this skill.

**Authority for the role-creation spec format — read and follow before authoring a CreateRole / AddPrivileges spec**: [`shared/dv/agent/wiki/reference/security-role-spec-template.md`](../../../shared/dv/agent/wiki/reference/security-role-spec-template.md).

**Power Pages context** — Dataverse security roles and Power Pages **web roles** are *different* mechanisms that overlap. Power Pages users are `contact` records (not `systemuser`); they bypass Dataverse role privileges and authorise via web roles + table permissions instead. When designing security for any portal-fronted solution, read [`shared/dv/agent/wiki/sop/power-pages/power-pages-security-best-practices.md`](../../../shared/dv/agent/wiki/sop/power-pages/power-pages-security-best-practices.md) — the dedicated Power Pages security peer SOP. Particularly:

- §1 — authentication providers (Entra External ID default; never local username/password)
- §2.1 — web roles (Anonymous Users, Authenticated Users, persona-specific layered roles)
- §2.2 — table permissions with the five scopes (Global / Contact / Account / Parent / Self) and the **AppOmni breach pattern** of Anonymous → Global Read on PII tables
- §2.3 — column permissions for the Web API and the `AttributePermissionIsMissing` lookup-column trap
- §2.5 — the contact-as-portal-user model and why Dataverse roles don't apply

Dataverse-side: the only role concern for Power Pages is the **service principal** (or application user) the portal uses to call Dataverse — grant it System Customizer at minimum, never System Administrator.

---

## Prerequisites

1. **MSAL.PS PowerShell module** (installed automatically on first use)
2. **Configuration** in CLAUDE.md (publisher prefix, solution name, environment URL)
3. **Internet connectivity** for OAuth authentication

## Capabilities

| Operation | Description |
|-----------|-------------|
| CreateRole | Create a new security role in a solution |
| RetrieveRole | Get a role by name with its privileges |
| AddPrivileges | Add privileges to a role (AddPrivilegesRole action) |
| ReplacePrivileges | Replace all privileges on a role (ReplacePrivilegesRole action) |
| RemovePrivilege | Remove a single privilege from a role |
| LookupPrivileges | Query available privileges by table name or privilege name |
| DeleteRole | Delete a security role |

---

## 1. CREATE ROLE

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-securityrole/scripts/Invoke-SecurityRoleOperation.ps1" `
    -Operation CreateRole `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -SolutionName "YourSolution" `
    -RoleName "My Custom Role" `
    -RoleDescription "Description of the role"
```

## 2. RETRIEVE ROLE

Get a role by name, expanding its assigned privileges:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-securityrole/scripts/Invoke-SecurityRoleOperation.ps1" `
    -Operation RetrieveRole `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -RoleName "My Custom Role"
```

## 3. ADD PRIVILEGES

Add privileges to a role. Provide a JSON array of privilege assignments:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-securityrole/scripts/Invoke-SecurityRoleOperation.ps1" `
    -Operation AddPrivileges `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -RoleName "My Custom Role" `
    -PrivilegesJson '[{"name":"prvReadAccount","depth":"Global"},{"name":"prvCreateAccount","depth":"Basic"}]'
```

**Depth values**: `Basic` (user), `Local` (business unit), `Deep` (parent:child BU), `Global` (organization)

## 4. REPLACE PRIVILEGES

Replace ALL privileges on a role (removes existing, sets new):

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-securityrole/scripts/Invoke-SecurityRoleOperation.ps1" `
    -Operation ReplacePrivileges `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -RoleName "My Custom Role" `
    -PrivilegesJson '[{"name":"prvReadAccount","depth":"Global"},{"name":"prvWriteAccount","depth":"Local"}]'
```

## 5. REMOVE PRIVILEGE

Remove a single privilege from a role:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-securityrole/scripts/Invoke-SecurityRoleOperation.ps1" `
    -Operation RemovePrivilege `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -RoleName "My Custom Role" `
    -PrivilegeName "prvReadAccount"
```

## 6. LOOKUP PRIVILEGES

Search for privilege names/IDs by table name or partial name:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-securityrole/scripts/Invoke-SecurityRoleOperation.ps1" `
    -Operation LookupPrivileges `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "account"
```

Or search by privilege name pattern:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-securityrole/scripts/Invoke-SecurityRoleOperation.ps1" `
    -Operation LookupPrivileges `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -PrivilegeName "prvRead"
```

## 7. DELETE ROLE

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-securityrole/scripts/Invoke-SecurityRoleOperation.ps1" `
    -Operation DeleteRole `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -RoleName "My Custom Role"
```

---

## Privilege Naming Convention

Standard table privileges follow: `prv{Action}{EntitySchemaName}`

| Action | Privilege Prefix | Description |
|--------|-----------------|-------------|
| Create | `prvCreate` | Create records |
| Read | `prvRead` | Read records |
| Write | `prvWrite` | Update records |
| Delete | `prvDelete` | Delete records |
| Append | `prvAppend` | Attach to another record |
| AppendTo | `prvAppendTo` | Allow other records to attach |
| Assign | `prvAssign` | Assign record ownership |
| Share | `prvShare` | Share records |

Example: For table `hso_estimate` -> `prvCreatehso_estimate`, `prvReadhso_estimate`, etc.

**Custom privileges** (e.g., for Custom APIs) use names like `prvhso_MyCustomAction`.

## Privilege Depth Levels

| Depth | Scope | Description |
|-------|-------|-------------|
| Basic | User | Own records only |
| Local | Business Unit | All records in user's BU |
| Deep | Parent:Child BU | User's BU and child BUs |
| Global | Organization | All records across all BUs |

**Note**: Organization-owned tables only support `Global` or no access (the privilege is absent from the role).

## Solution XML Structure

When `pac solution unpack` extracts a solution, security roles appear in `Roles/` as XML files:

```xml
<Role name="My Custom Role" id="{guid}">
  <RolePrivileges>
    <RolePrivilege name="prvCreateAccount" level="Basic" />
    <RolePrivilege name="prvReadAccount" level="Global" />
    <RolePrivilege name="prvWriteAccount" level="Local" />
  </RolePrivileges>
</Role>
```

**XSD Reference**: `shared/dv/agent/wiki/reference/customizations-xsd/CustomizationsSolution.xsd` (lines 1213-1245)

The `level` attribute maps directly to the Depth values: `Basic`, `Local`, `Deep`, `Global`.

## Web API Reference

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Create role | POST | `/api/data/v9.2/roles` |
| Retrieve role | GET | `/api/data/v9.2/roles?$filter=name eq '...'&$expand=roleprivileges_association` |
| Read back privileges **with depth** | GET | `/api/data/v9.2/RetrieveRolePrivilegesRole(RoleId=<roleid>)` — returns `PrivilegeName` + `Depth`. The `roleprivileges` intersect is **not** an exposed entity set; `roleprivileges_association` above returns names **without** depth. |
| Add privileges | POST | `/api/data/v9.2/roles({id})/Microsoft.Dynamics.CRM.AddPrivilegesRole` |
| Replace privileges | POST | `/api/data/v9.2/roles({id})/Microsoft.Dynamics.CRM.ReplacePrivilegesRole` |
| Remove privilege | POST | `/api/data/v9.2/roles({id})/Microsoft.Dynamics.CRM.RemovePrivilegeRole` |
| Query privileges | GET | `/api/data/v9.2/privileges?$filter=contains(name,'...')` |
| Delete role | DELETE | `/api/data/v9.2/roles({id})` |
| Assign role to user | POST | `/api/data/v9.2/systemusers({userId})/systemuserroles_association/$ref` |
| List a user's roles | GET | `/api/data/v9.2/systemusers({userId})/systemuserroles_association?$select=name` |
| List a role's users | GET | `/api/data/v9.2/roles({roleId})/systemuserroles_association?$select=fullname` |
| Unassign role from user | DELETE | `/api/data/v9.2/systemusers({userId})/systemuserroles_association({roleId})/$ref` |

### User role assignment (who holds a role)

**Authority — read before composing any user-assignment call**: [`references/user-role-assignment-web-api.md`](references/user-role-assignment-web-api.md). Not wrapped as an operation (ADR 0013 Rule 2 — a thin `$ref` association). The reference carries the BU-aware role resolution, the user-lookup gotcha, cohort-provisioning shape, and a validation-status table marking which claims are environment-proven.

### Field Security Profiles (column-level security)

**Authority for Field Security Profile / column-permission Web API operations — read before composing any FLS call**: [`references/field-security-profiles-web-api.md`](references/field-security-profiles-web-api.md). Column-level security is **not** wrapped as an operation here (per [ADR 0013](../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md) it is delivered as composed Web API calls); for create / grant a column permission / assign-to-team / inspect / delete, use the validated, copy-pasteable calls in that reference rather than composing from scratch. Secure the column first via `hso-dataverse-data-modeling` `UpdateColumn -IsSecured $true`, and assign profiles to **teams, not users**.

---

## Security Role Matrix Documentation

Generate comprehensive security role documentation in Excel format from unpacked solution role XML files.

### Purpose

The **Security Role Matrix** is a deliverable Excel file documenting:
- **Security Roles**: Custom roles with descriptions
- **Table Privileges**: Create, Read, Write, Delete, Append, AppendTo, Assign, Share permissions per role
- **Column Security Profiles**: Field-level security profiles (placeholder)
- **Business Units**: Organizational hierarchy (placeholder)
- **Teams**: Team structure and associated roles (placeholder)

### Generate Security Role Matrix

Create a PowerShell script to parse role XML files and generate the Excel documentation:

```powershell
# Parse roles and create Excel matrix
$solutionPath = "Solutions/EstimationSolution"
$outputPath = "agent/work/deliverables/Security Role Matrix.xlsx"
$publisherPrefix = "hso"

# Script will:
# 1. Read all XML files from $solutionPath/Roles/
# 2. Extract role names, descriptions, and privilege assignments
# 3. Create Excel workbook with 5 worksheets
# 4. Format with headers, borders, and proper column widths
```

### Excel Output Structure

The generated Excel file contains **5 worksheets** in this order:

#### 1. Column Security Profiles
**Headers**: `Column Security Profile Name | Role Type (Base/Custom) | Copy Of (if custom) | Description`

Placeholder tab for field-level security. Populate manually with column security profiles from Settings → Customizations.

#### 2. Business Units
**Headers**: `Business Unit Name | Parent Business Unit | Description`

Placeholder tab for organizational hierarchy. Populate from Settings → Security → Business Units.

#### 3. Teams
**Headers**: `Team Name | Team Type (Owner/Access) | Business Unit | Default Queue | Associated Security Roles | Description | Notes`

Placeholder tab for team structure. Populate from Settings → Security → Teams.

#### 4. Security Roles
**Headers**: `Security Role Name | Role Type (Base/Custom) | Copy Of (if custom) | Description`

**Populated from role XML files** in Solutions folder:
- Role names extracted from `<Role name="...">`
- Descriptions from `<Description>` element
- Type always "Custom" for solution roles

#### 5. Table Privileges
**Headers**: `Role | Name | Table Type | Create | Read | Write | Delete | Append | Append To | Assign | Share`

**Populated from RolePrivileges** in XML files:
- One row per role-table combination
- Privilege levels mapped from XML:
  - `Basic` → `User`
  - `Local` → `Business Unit`
  - `Deep` → `Parent: Child Business Units`
  - `Global` → `Organization`
  - Missing privilege → `None`
- Table Type: `Custom` (matches publisher prefix) or `OOB` (standard D365 tables)

### Parsing Role XML Files

Role XML structure in unpacked solutions:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Role id="{guid}" name="HSO Estimation User">
  <IsCustomizable>1</IsCustomizable>
  <IsAutoAssigned>0</IsAutoAssigned>
  <Description>Create and manage estimates, submit for approval.</Description>
  <RolePrivileges>
    <RolePrivilege name="prvCreatehso_Estimate" level="Local" />
    <RolePrivilege name="prvReadhso_Estimate" level="Global" />
    <RolePrivilege name="prvWritehso_Estimate" level="Local" />
    <RolePrivilege name="prvDeletehso_Estimate" level="Basic" />
    <RolePrivilege name="prvAppendhso_Estimate" level="Local" />
    <RolePrivilege name="prvAppendTohso_Estimate" level="Local" />
    <RolePrivilege name="prvAssignhso_Estimate" level="Local" />
    <RolePrivilege name="prvSharehso_Estimate" level="Local" />
  </RolePrivileges>
</Role>
```

Extract privileges using PowerShell XML parsing:

```powershell
[xml]$roleXml = Get-Content "Solutions/MySolution/Roles/My Role.xml"
$roleName = $roleXml.Role.name
$description = $roleXml.Role.Description
$privileges = $roleXml.Role.RolePrivileges.RolePrivilege

foreach ($priv in $privileges) {
    # Parse privilege name: prvOperationEntity
    if ($priv.name -match '^prv(Create|Read|Write|Delete|Append|AppendTo|Assign|Share)(.+)$') {
        $operation = $Matches[1]
        $entityName = $Matches[2]
        $level = $priv.level  # Basic, Local, Deep, Global
        # Store for Excel generation
    }
}
```

### Excel Formatting

Apply consistent formatting to the generated Excel file:

```powershell
# Headers: Bold, Gray background, Center aligned
$headerRange.Font.Bold = $true
$headerRange.Interior.ColorIndex = 15  # Gray
$headerRange.HorizontalAlignment = -4108  # Center

# Column widths
$worksheet.Columns.Item(1).ColumnWidth = 30  # Role/Name columns
$worksheet.Columns.Item(4).ColumnWidth = 80  # Description (with wrap)

# Borders around data
$dataRange.Borders.LineStyle = 1

# Placeholder rows: Italic, Gray background
$placeholderRange.Font.Italic = $true
$placeholderRange.Interior.ColorIndex = 15
```

### Table Type Classification

Determine if a table is Custom or OOB:

```powershell
function GetTableType {
    param($entityName, $publisherPrefix)
    
    if ($entityName -like "$publisherPrefix`_*") {
        return "Custom"
    } else {
        return "OOB"
    }
}

# Example
GetTableType "hso_estimate" "hso"    # Returns: Custom
GetTableType "Account" "hso"         # Returns: OOB
```

### Privilege Matrix Example

For table `hso_estimate` with 3 roles:

| Role | Name | Table Type | Create | Read | Write | Delete | Append | Append To | Assign | Share |
|------|------|------------|--------|------|-------|--------|--------|-----------|--------|-------|
| HSO Estimation User | Estimate | Custom | Business Unit | Organization | Business Unit | User | Business Unit | Business Unit | Business Unit | Business Unit |
| HSO Estimation Approver | Estimate | Custom | Business Unit | Organization | Business Unit | User | Business Unit | Business Unit | Business Unit | Business Unit |
| HSO Estimation Administrator | Estimate | Custom | Organization | Organization | Organization | Organization | Organization | Organization | Organization | Organization |

### Best Practices

1. **Regenerate After Changes**: Update the matrix whenever security roles are modified in Dataverse and re-exported
2. **Store in Deliverables**: Save to `agent/work/deliverables/` for version control
3. **Populate Placeholders**: Fill in Business Units, Teams, and Column Security Profiles for complete documentation
4. **Include in Handoffs**: Provide to deployment teams, administrators, and auditors

### Related Documentation

- **Solution Documentation**: [hso-update-solution-docs](../hso-update-solution-docs/SKILL.md)
- **Security Concepts**: [Microsoft Learn - Security in Dataverse](https://learn.microsoft.com/en-us/power-platform/admin/security-roles-privileges)

---

## Known capability gaps + composed workarounds (skill-gap #2)

Three operations this skill has no wrapper for yet; use the composed Web API recipe rather than re-deriving:

- **Associate a role with an app module** (no `AssociateAppModule` op): `POST` to the role's
  `appmoduleroles_association` collection-valued navigation via an `@odata.bind` reference, then publish. Needed when a role must be scoped to a specific model-driven app.
- **Read back role-privilege *depth*** (no depth read-back op): call the
  **`RetrieveRolePrivilegesRole`** function — `GET /api/data/v9.2/RetrieveRolePrivilegesRole(RoleId=<roleid>)`.
  It returns a `RolePrivileges` array carrying **`PrivilegeName` and `Depth` directly**
  (`Basic` / `Local` / `Deep` / `Global` as strings), so no join to `privileges` is needed. The assign
  call's success does not prove the depth landed; verify it. Pair with the **root-role** resolution
  above (edit the root, not a BU copy).

  > ⚠️ **Two dead ends, both of which look like the obvious approach.** `roleprivileges` is **not an
  > exposed Web API entity set** — querying it returns
  > `0x80060888 "Resource not found for the segment 'roleprivileges'"`. And this skill's own
  > **`RetrieveRole` operation prints privilege names *without* depth**, so it cannot be used to verify
  > depth landed. Use the function above. *(Corrected 2026-08-20 after the earlier
  > `roleprivileges?$filter=_roleid_value eq …&privilegedepthmask` recipe documented here was found not
  > to work against a live environment.)*
- **Assign a security role to a *user*** (no user-side op at all — the operations above are all
  role-side): `POST` to `systemusers(<userId>)/systemuserroles_association/$ref`. Read
  [`references/user-role-assignment-web-api.md`](references/user-role-assignment-web-api.md) before
  composing — it carries the validated calls plus the traps: resolve the role copy in **the user's
  own BU** (the *inverse* of the root-role rule used for privilege edits), match users on
  `internalemailaddress` **or** `domainname`, and note that assignments are per-environment config
  that does **not** travel in a solution. A role is also not a licence.

---

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
