# Creating a custom activity table via the Web API

Per [ADR 0013](../../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md), this is the
copy-pasteable example library for the **custom activity** shape — both the raw `CreateEntity` payload
and the skill shortcut that composes it.

> **Validation status:** the skill shortcut and payload below encode the platform rules for activity
> tables, but this capability was added under the docs-only constraint and has **not yet been smoke-run
> against a live org**. Treat it as the ADR 0013 "run it live before you rely on it" gate: the first real
> use is the validation. Once it has created an activity successfully in a real environment, drop this note.

## What a custom activity is (and when to reach for one)

An **activity** is a table that participates in the activity framework: its records show up on the
timeline of related records, roll up under "Activities" / "Open Activities" views, can be assigned,
appear in the calendar/Outlook surfaces, and share the `ActivityPointer` base (so `subject`,
`activityid`, regarding, etc. are part of the shape). Custom activities are common in delivery — any
"thing a user logs against a record over time" (a site visit, a coaching note, an inspection, a contact
touch) is naturally an activity rather than a plain custom table.

Reach for a custom activity when **all** of these hold:

- The record is an *event/interaction logged over time* against another record, not master/reference data.
- You want it on the **timeline** and in the rolled-up activity views automatically.
- You're comfortable with the activity base shape (user-owned, `subject` primary, regarding/party model).

If you only need "a child table with a lookup back to the parent," a **plain custom table** is simpler and
cheaper — don't make it an activity just to get a relationship. See the
[data-modeling best practices SOP](../../../../shared/dv/agent/wiki/sop/model-driven-apps/data-modeling-best-practices.md)
§ Custom activities for the decision rule.

## The platform rules (these are what break CreateEntity if violated)

| Rule | Value | Enforced by | The skill shortcut does this for you |
|------|-------|-------------|--------------------------------------|
| Mark it an activity | `IsActivity = true` | platform | set by `-IsActivity` |
| An activity can't host activities | `HasActivities = false` | platform (rejects `true`) | coerced to `false` + `[WARN]` if you passed `true` |
| Ownership | `OwnershipType = UserOwned` | platform (rejects `OrganizationOwned`) | coerced to `UserOwned` + `[WARN]` |
| Primary name attribute present | a `StringAttributeMetadata` with `IsPrimaryName = true` | platform ("PrimaryAttribute missing") | always emitted |
| Primary is the subject | display **Subject**, schema `<prefix>_subject_text` | convention (UX + every OOB activity) | defaulted unless you override `-PrimaryColumnName` |
| Notes | `HasNotes = true` | recommended (timeline attachments) | defaulted to `true` for activities (override with `-HasNotes $false`) |
| Mobile/Outlook sync | `IsAvailableOffline = true` | recommended | set by `-IsAvailableOffline` |

`IsActivity`, `HasActivities`, and `OwnershipType` are **immutable after create** — get them right the
first time or you delete and recreate the table.

## Skill shortcut (preferred)

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateTable -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "sitevisit" -DisplayName "Site Visit" -DisplayNamePlural "Site Visits" `
    -Description "A logged visit to a customer site, tracked on the regarding record's timeline." `
    -IsActivity -IsAvailableOffline `
    -PrimaryColumnDescription "Short summary of the visit, shown on the timeline." `
    -SolutionName "yourcustomsolution"
```

This expands to: `IsActivity=true`, `HasActivities=false`, `HasNotes=true`, `IsAvailableOffline=true`,
`OwnershipType=UserOwned`, and a primary `hso_subject_text` (display "Subject"). Add columns afterward
with `AddColumns` exactly as for any table. Verify with `QueryTable` — it now reports `IsActivity`.

To override the subject default (rarely needed), pass `-PrimaryColumnName`/`-PrimaryColumnDisplayName`.

## Raw `CreateEntity` payload (compose-against-the-library form)

`POST {env}/api/data/v9.2/EntityDefinitions` (add `MSCRM.SolutionUniqueName` header to land it in your
solution). The activity-specific parts are flagged inline.

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.EntityMetadata",
  "SchemaName": "hso_SiteVisit",
  "DisplayName":          { "@odata.type": "Microsoft.Dynamics.CRM.Label", "LocalizedLabels": [ { "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel", "Label": "Site Visit",  "LanguageCode": 1033 } ] },
  "DisplayCollectionName":{ "@odata.type": "Microsoft.Dynamics.CRM.Label", "LocalizedLabels": [ { "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel", "Label": "Site Visits", "LanguageCode": 1033 } ] },
  "Description":          { "@odata.type": "Microsoft.Dynamics.CRM.Label", "LocalizedLabels": [ { "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel", "Label": "A logged visit to a customer site.", "LanguageCode": 1033 } ] },
  "OwnershipType": "UserOwned",          // activities must be UserOwned
  "IsActivity": true,                    // <-- the flag that makes this an activity
  "HasActivities": false,                // an activity cannot host activities
  "HasNotes": true,                      // timeline notes/attachments
  "IsAvailableOffline": true,            // mobile / Outlook sync (recommended)
  "Attributes": [
    {
      "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
      "SchemaName": "hso_subject_text",  // primary name = the subject, by convention
      "IsPrimaryName": true,
      "MaxLength": 200,
      "FormatName": { "Value": "Text" },
      "RequiredLevel": { "Value": "ApplicationRequired" },
      "DisplayName": { "@odata.type": "Microsoft.Dynamics.CRM.Label", "LocalizedLabels": [ { "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel", "Label": "Subject", "LanguageCode": 1033 } ] },
      "Description": { "@odata.type": "Microsoft.Dynamics.CRM.Label", "LocalizedLabels": [ { "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel", "Label": "Short summary shown on the timeline.", "LanguageCode": 1033 } ] },
      "AttributeType": "String",
      "AttributeTypeName": { "Value": "StringType" }
    }
  ]
}
```

## Relating activities to other tables

Activities link to the record they're *about* through the platform **regarding** (`regardingobjectid`)
relationship — you usually do **not** model your own lookup to the parent for that. A custom activity is
enabled as a regarding target for a table by that table's `HasActivities=true` (the *parent* gets
`HasActivities`, the activity gets `IsActivity`).

When you genuinely need an explicit lookup **between** an OOB activity (task / appointment / email /
phonecall) and another table, that's a normal `CreateRelationship` — but the OOB activity's primary key
is `activityid`, not `<entity>id`, so pass `-ParentPrimaryKey activityid` when the OOB activity is the
**parent** (referenced) side:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation CreateRelationship -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -RelationshipType OneToMany -ParentTable "email" -ParentPrimaryKey "activityid" `
    -ChildTable "hso_sitevisit" -LookupName "hso_sourceemail" -LookupDisplayName "Source Email" `
    -LookupDescription "The email this site visit was logged from." -SolutionName "yourcustomsolution"
```

> **Design note (de-identified):** when several activity types must each reference two other tables
> independently, model each reference as its own lookup on the activity types — do **not** invent a direct
> relationship between the two referenced tables to "join" them. The activities already link both sides;
> a direct relationship duplicates that and over-constrains the model.

## Error → fix table

These are the opaque `CreateEntity` / metadata errors you hit when an activity is malformed, and the exact
remediation:

| Error message (substring) | Cause | Fix |
|---------------------------|-------|-----|
| `Required field HasActivities missing` / activity rejects `HasActivities=true` | Tried to set `HasActivities` on an activity | Set `HasActivities=false` — an activity can't host activities. (`-IsActivity` forces this.) |
| `PrimaryAttribute missing` / no primary name | No `IsPrimaryName=true` string attribute in `Attributes` | Include the subject primary (see payload). The shortcut always emits it. |
| Ownership / `OrganizationOwned` rejected for activity | Activity created as org-owned | Use `OwnershipType=UserOwned`. (`-IsActivity` coerces this.) |
| `Must have Offline Availability` (org/validation policy) | `IsAvailableOffline` not set where the org requires it | Add `-IsAvailableOffline` (`IsAvailableOffline=true`). |
| `Must have relationship to Notes` (org/validation policy) | `HasNotes=false` where notes are required | Leave `HasNotes` at its activity default of `true` (don't pass `-HasNotes $false`). |
| Relationship schema name invalid prefix | Relationship `SchemaName` doesn't start with the publisher prefix | Prefix it (`hso_…`). `CreateRelationship` auto-prefixes generated names; only overrides via `-RelationshipSchemaName` need manual care. |
| OData enum/object shape error on relationship payload | `@odata.type`/`AttributeType` added to the `Lookup` object, or `LookupAttributeMetadata` placed under `EntityDefinitions(...)/Attributes` | Use the `RelationshipDefinitions` collection with a bare `Lookup` object (no `@odata.type`). See [relationship-solution-portability.md](relationship-solution-portability.md) and §5 of [reference.md](reference.md). |

## Gotchas

- `IsActivity`, `HasActivities`, and `OwnershipType` are **set-once** — wrong values mean delete + recreate.
- The activity primary is the **subject**; don't also add a `name` column expecting it to be the primary.
- Adding the parent table's `HasActivities=true` (so the activity can be *regarding* it) is a separate
  `UpdateTable` on the **parent**, not part of creating the activity.
- An activity inherits the base `statecode`/`statuscode` (Open/Completed/Canceled) — design your lifecycle
  around those, don't add a parallel custom status. See the lifecycle SOP.
