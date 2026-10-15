---
name: hso-dataverse-naming-conventions
layer: foundation
scope: core
description: |
  Authoritative reference for HSO Dataverse naming conventions. Use when designing or reviewing:
  (1) Table names — verify prefix and lowercase format
  (2) Column names — verify correct type suffix (_text, _num, _amt, _yn, _date, _code, _codes, _id, _memo, _dec)
  (3) Global choices — verify prefix and lowercase format; confirm Global vs local option set choice
  (4) Custom API unique names — verify PascalCase action naming
  (5) Web resource file paths — verify folder structure and _form.js pattern
  (6) Plugin assembly and namespace naming — verify prefix and PascalCase conventions
  Referenced by: hso-dataverse-data-modeling, hso-dataverse-architect, hso-dataverse-customapi, hso-formscript-development, hso-plugin-development, hso-analyze-dataverse-solution-changes.
  Human-readable SOP: shared/dv/agent/wiki/sop/dataverse-naming-conventions.md
---

# Dataverse Naming Conventions

Quick-lookup digest of HSO naming standards for design and review. This is a digest only — [`shared/dv/agent/wiki/sop/dataverse-naming-conventions.md`](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) is authoritative; read it before designing, since it carries rules not reproduced here (PROHIBITED patterns, Customer/Owner lookups, relationship naming, Power Automate flow naming, ribbon scripts, mandatory Descriptions). All schema components and code artifacts must follow these conventions.

Read from `CLAUDE.md`: **Publisher Prefix** (e.g., `hso`)

> **Authority for HSO naming conventions — read before naming any schema component or code artifact:** [`shared/dv/agent/wiki/sop/dataverse-naming-conventions.md`](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) is the authoritative reference. The rules below are a Claude-optimized digest of that SOP for fast lookup during design and review; when the digest and the SOP disagree, the SOP wins, and any rule not reproduced here (e.g. PROHIBITED patterns, relationship and Power Automate flow naming, mandatory descriptions) still applies — read the SOP before designing.

> **Task → primary authority:** when a standalone task spans more than this digest, land on the right doc:
>
> | Task | Primary authority |
> |------|-------------------|
> | Choosing / fixing the publisher prefix; one-publisher-per-project; Default Publisher trap; cross-publisher conflicts | publishers SOP §1–§4 (read before any schema authoring) |
> | Naming tables, columns, choices, Custom APIs, web resources, plugins, relationships, flows | `dataverse-naming-conventions.md` (this skill is its digest) |

> **Where the prefix comes from:** the publisher prefix is the **publisher object's `CustomizationPrefix`** — a tenant-wide unique 4–6-character lowercase string set when the project's custom publisher is created. Decisions about *which* prefix to use, the **one-publisher-per-project** rule, the **Default Publisher trap** (and the Preferred Solutions fix), and the cross-publisher-conflict scenario that requires holding-solution surgery all live in [`shared/dv/agent/wiki/sop/dataverse-solutions/solution-publishers-and-versioning-best-practices.md`](../../../shared/dv/agent/wiki/sop/dataverse-solutions/solution-publishers-and-versioning-best-practices.md) §1–§4. Mandatory pre-read at project inception, before any schema authoring, to ensure the prefix this skill validates against is set correctly in the first place.

---

## Table Names

- Format: `{prefix}_{tablename}` (all lowercase)
- Example: `hso_projecttask`, `hso_workorderitem`
- **Never** use uppercase characters or spaces in the logical name

> **GOTCHA — never hand-guess the `EntitySetName` (or option-set values, or privilege casing) — resolve from metadata (skill-gap #17, lessons §3).** The Web API plural **EntitySetName** is **not** "logical name + s": Dataverse pluralizes irregularly, so `hso_roleassignmentbatch` → `hso_roleassignmentbatchs` (no `-es`), and a guessed `hso_notificationdispatches` 404s where the real set is `hso_notificationdispatchs`. Read it from `EntityDefinitions(LogicalName='…')?$select=EntitySetName` (or the shared `Get-EntitySetName` resolver) rather than constructing it. Same discipline for two other "looks obvious, bites you" values: **option-set/statuscode integer values** (read them back — they are often in the publisher range like `540310000`, never assume `1`) and **privilege-name casing** (`prvWriteHso_<table>` uses the table's **schema** casing, not lowercase). Guessing any of the three is a recurring source of silent 404s and no-ops.

## Column Names

All custom columns use a type suffix: `{prefix}_{fieldname}_{suffix}`

| Data Type | Suffix | Example |
|-----------|--------|---------|
| Single Line Text | `_text` | `hso_projectname_text` |
| Multi-Line Text | `_memo` | `hso_description_memo` |
| Whole Number | `_num` | `hso_quantity_num` |
| Decimal | `_dec` | `hso_percentage_dec` |
| Currency | `_amt` | `hso_totalcost_amt` |
| Yes/No | `_yn` | `hso_isverified_yn` |
| Date/DateTime | `_date` | `hso_duedate_date` |
| Choice (single) | `_code` | `hso_status_code` |
| Choice (multi-select) | `_codes` | `hso_tags_codes` |
| Lookup | `_id` | `hso_account_id` |

**Field name segment:** use lowercase with no underscores within the name segment itself (e.g., `projectname` not `project_name`).

**PROHIBITED — never create a custom `{prefix}_isactive_yn` field** to track active/inactive status; use the built-in `statecode`/`statuscode` instead (and custom `statuscode` values for sub-states). This is one of several PROHIBITED patterns; see the SOP's PROHIBITED Patterns section before adding status/boolean fields.

**Mandatory Descriptions (not optional):** every named component also requires a populated `Description` per the HSO standard — see [`data-modeling-best-practices.md` §24](../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md). Naming is only half the contract; an unnamed-description component is non-compliant even if the name is correct.

## Global Choices

- Format: `{prefix}_{choicename}` (all lowercase)
- Example: `hso_projectstatus`, `hso_workordertype`
- **Always prefer Global choices** over local option sets. Local option sets require documented justification.

## Custom APIs

- Format: `{prefix}_ActionName` (PascalCase action name after prefix)
- Example: `hso_SubmitForApproval`, `hso_CalculatePrice`, `hso_ValidateAddress`
- Request parameters: descriptive names without prefix (e.g., `RecordId`, `StatusCode`)
- Response properties: descriptive names without prefix (e.g., `IsValid`, `ResultMessage`)

## Web Resources (Form Scripts)

| Asset Type | Path Pattern | Example |
|------------|-------------|---------|
| Form script | `{prefix}_/scripts/{entity}/{entity}_form.js` | `hso_/scripts/account/account_form.js` |
| Shared utility | `{prefix}_/scripts/shared/{name}.js` | `hso_/scripts/shared/validation.js` |
| CSS | `{prefix}_/css/{entity}/{name}.css` | `hso_/css/account/account_form.css` |

- JavaScript namespace: `HSO.EntityName` (e.g., `HSO.Account`, `HSO.WorkOrder`)

## Plugin Assembly and Namespace

| Component | Pattern | Example |
|-----------|---------|---------|
| Assembly name | `{Publisher}.D365.{Solution}` | `HSO.D365.EmailTemplateConfiguration` |
| Root namespace | `{Publisher}.D365.{Solution}` | `HSO.D365.EmailTemplateConfiguration` |
| Plugin class | `{EntityName}{Message}Plugin` | `AccountUpdatePlugin` |
| Business logic service | `{EntityName}Service` | `AccountService` |
| Repository | `{EntityName}Repository` | `AccountRepository` |

## Quick Validation Checklist

Before creating any schema component, verify:
- [ ] Prefix matches `CLAUDE.md` publisher prefix
- [ ] Table name: all lowercase, no uppercase
- [ ] Column name: correct suffix for data type
- [ ] Choice: Global choice preferred; local requires justification
- [ ] Custom API: PascalCase action name after prefix
- [ ] Web resource: correct folder structure and `_form.js` suffix for form scripts

---

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
