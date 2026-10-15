# Dataverse Data Modeling Reference

Complete reference for type codes, Web API patterns, and metadata structures.

---

## 1. COLUMN TYPE CODES

### 1.1 MCP Server Column Types

| MCP Type | Description | Example |
|----------|-------------|---------|
| `string` | Single line text (max 4000) | Names, titles |
| `multiline text` | Multi-line text area | Descriptions, notes |
| `text area` | Alias for multiline text | - |
| `rich text` | Rich text with formatting | HTML content |
| `integer` | Whole number (-2B to 2B) | Quantities, counts |
| `decimal` | Decimal number (0-10 precision) | Percentages |
| `double` | Floating point number | Scientific values |
| `money` | Currency with precision | Prices, costs |
| `boolean` | Yes/No field | Flags, toggles |
| `datetime` | Date and time | Timestamps |
| `choice` | Single-select option set | Status, priority |
| `multiselect` | Multi-select option set | Tags, categories |
| `lookup` | Reference to another table | Parent record |
| `customer` | Account or Contact lookup | Customer field |
| `phone` | Phone number format | Phone numbers |
| `email` | Email address format | Email addresses |
| `url` | URL format | Web links |
| `ticker symbol` | Stock ticker format | Stocks |
| `duration` | Time duration | Elapsed time |
| `time zone` | Time zone selection | User timezone |
| `language` | Language code selection | User language |

### 1.2 Web API Attribute Metadata Types

| @odata.type | AttributeType | Use Case |
|-------------|---------------|----------|
| `StringAttributeMetadata` | String | Single line text |
| `MemoAttributeMetadata` | Memo | Multi-line text |
| `IntegerAttributeMetadata` | Integer | Whole numbers |
| `DecimalAttributeMetadata` | Decimal | Decimal numbers |
| `DoubleAttributeMetadata` | Double | Floating point |
| `MoneyAttributeMetadata` | Money | Currency |
| `BooleanAttributeMetadata` | Boolean | Yes/No |
| `DateTimeAttributeMetadata` | DateTime | Dates and times |
| `PicklistAttributeMetadata` | Picklist | Single choice |
| `MultiSelectPicklistAttributeMetadata` | Virtual | Multiple choices |
| `LookupAttributeMetadata` | Lookup | Table reference |
| `ImageAttributeMetadata` | Virtual | Image storage |
| `FileAttributeMetadata` | Virtual | File storage |
| `UniqueIdentifierAttributeMetadata` | Uniqueidentifier | GUID fields |

---

## 2. WEB API JSON STRUCTURES

### 2.1 Label Structure

All display names and descriptions use this structure:

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.Label",
  "LocalizedLabels": [
    {
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "Display Text Here",
      "LanguageCode": 1033
    }
  ]
}
```

**Language Codes (LCID):**

| Language | Code |
|----------|------|
| English (US) | 1033 |
| Spanish | 1034 |
| French | 1036 |
| German | 1031 |
| Italian | 1040 |
| Portuguese (Brazil) | 1046 |
| Dutch | 1043 |
| Japanese | 1041 |
| Chinese (Simplified) | 2052 |

### 2.2 Required Level Structure

```json
{
  "RequiredLevel": {
    "Value": "None"
  }
}
```

| Value | Meaning |
|-------|---------|
| `None` | Optional field |
| `ApplicationRequired` | Required in UI |
| `SystemRequired` | Required by system (cannot change) |
| `Recommended` | Suggested but not required |

---

## 3. TABLE (ENTITY) METADATA

### 3.1 Create Table Request

**Endpoint:** `POST [OrgUrl]/api/data/v9.2/EntityDefinitions`

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.EntityMetadata",
  "SchemaName": "hso_ProjectTask",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "Project Task",
      "LanguageCode": 1033
    }]
  },
  "DisplayCollectionName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "Project Tasks",
      "LanguageCode": 1033
    }]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "Tracks tasks within projects",
      "LanguageCode": 1033
    }]
  },
  "OwnershipType": "UserOwned",
  "IsActivity": false,
  "HasActivities": false,
  "HasNotes": false,
  "Attributes": [
    {
      "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
      "SchemaName": "hso_name",
      "IsPrimaryName": true,
      "MaxLength": 100,
      "FormatName": { "Value": "Text" },
      "DisplayName": {
        "@odata.type": "Microsoft.Dynamics.CRM.Label",
        "LocalizedLabels": [{
          "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
          "Label": "Name",
          "LanguageCode": 1033
        }]
      },
      "RequiredLevel": { "Value": "ApplicationRequired" },
      "AttributeType": "String",
      "AttributeTypeName": { "Value": "StringType" }
    }
  ]
}
```

### 3.2 Ownership Types

Only two values are creatable. `TeamOwned` and `BusinessOwned` exist in the platform enum but the
maker portal and the metadata API do not accept them for new tables — a team owns records **on a
`UserOwned` table**, via the polymorphic `ownerid` column.

| Type | Description | HSO position |
|------|-------------|--------------|
| `UserOwned` | Records owned by a user **or a team** (`ownerid` is polymorphic) | ✅ **Default for every table**, configuration and reference data included |
| `OrganizationOwned` | No `ownerid`; no sharing, owner teams, hierarchy security or BU scoping; Global-or-nothing access | ⚠️ Avoid — only on explicit architect request with recorded rationale ([why](../../../agent/wiki/sop/security/security-best-practices.md#table-ownership-shapes-which-depths-are-valid)) |

### 3.3 Table Feature Flags

| Property | Type | Description |
|----------|------|-------------|
| `HasActivities` | boolean | Enable activity timeline |
| `HasNotes` | boolean | Enable notes/attachments |
| `IsActivity` | boolean | Make table an activity type |
| `IsAuditEnabled` | BooleanManagedProperty | Enable auditing |
| `IsDuplicateDetectionEnabled` | BooleanManagedProperty | Enable duplicate detection |
| `IsValidForQueue` | BooleanManagedProperty | Enable queue support |
| `IsBusinessProcessEnabled` | boolean | Enable business process flows |
| `IsSLAEnabled` | boolean | Enable SLA support |
| `ChangeTrackingEnabled` | boolean | Enable change tracking |
| `SyncToExternalSearchIndex` | boolean | Enable relevance search |
| `IsAvailableOffline` | boolean | Enable mobile offline |

---

## 4. COLUMN (ATTRIBUTE) METADATA

### 4.1 String (Single Line Text)

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
  "AttributeType": "String",
  "AttributeTypeName": { "Value": "StringType" },
  "SchemaName": "hso_projectname_text",
  "MaxLength": 100,
  "FormatName": { "Value": "Text" },
  "DisplayName": { /* Label structure */ },
  "Description": { /* Label structure */ },
  "RequiredLevel": { "Value": "None" }
}
```

**FormatName Values:**

| Value | UI Format |
|-------|-----------|
| `Text` | Plain text input |
| `Email` | Email validation |
| `Url` | URL validation |
| `Phone` | Phone format |
| `TextArea` | Multi-line display (still String type) |
| `TickerSymbol` | Stock ticker format |

### 4.2 Memo (Multi-Line Text)

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.MemoAttributeMetadata",
  "AttributeType": "Memo",
  "AttributeTypeName": { "Value": "MemoType" },
  "SchemaName": "hso_description_memo",
  "MaxLength": 2000,
  "Format": "TextArea",
  "DisplayName": { /* Label structure */ },
  "RequiredLevel": { "Value": "None" }
}
```

**Format Values:**

| Value | Description |
|-------|-------------|
| `TextArea` | Plain text area |
| `RichText` | HTML rich text |
| `Email` | Email body format |

### 4.3 Integer (Whole Number)

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.IntegerAttributeMetadata",
  "AttributeType": "Integer",
  "AttributeTypeName": { "Value": "IntegerType" },
  "SchemaName": "hso_quantity_num",
  "Format": "None",
  "MinValue": 0,
  "MaxValue": 100000,
  "DisplayName": { /* Label structure */ },
  "RequiredLevel": { "Value": "None" }
}
```

**Format Values:**

| Value | Description |
|-------|-------------|
| `None` | Standard integer |
| `Duration` | Duration in minutes |
| `TimeZone` | Time zone offset |
| `Language` | Language code |

### 4.4 Decimal

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.DecimalAttributeMetadata",
  "AttributeType": "Decimal",
  "AttributeTypeName": { "Value": "DecimalType" },
  "SchemaName": "hso_percentage_dec",
  "Precision": 2,
  "MinValue": 0,
  "MaxValue": 100,
  "DisplayName": { /* Label structure */ },
  "RequiredLevel": { "Value": "None" }
}
```

### 4.5 Money (Currency)

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.MoneyAttributeMetadata",
  "AttributeType": "Money",
  "AttributeTypeName": { "Value": "MoneyType" },
  "SchemaName": "hso_totalcost_amt",
  "PrecisionSource": 2,
  "DisplayName": { /* Label structure */ },
  "RequiredLevel": { "Value": "None" }
}
```

**PrecisionSource Values:**

| Value | Description |
|-------|-------------|
| 0 | Pricing decimal precision |
| 1 | Currency precision |
| 2 | Fixed 2 decimals |

### 4.6 Boolean (Yes/No)

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.BooleanAttributeMetadata",
  "AttributeType": "Boolean",
  "AttributeTypeName": { "Value": "BooleanType" },
  "SchemaName": "hso_isactive_yn",
  "DefaultValue": false,
  "OptionSet": {
    "@odata.type": "Microsoft.Dynamics.CRM.BooleanOptionSetMetadata",
    "TrueOption": {
      "Value": 1,
      "Label": {
        "@odata.type": "Microsoft.Dynamics.CRM.Label",
        "LocalizedLabels": [{
          "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
          "Label": "Yes",
          "LanguageCode": 1033
        }]
      }
    },
    "FalseOption": {
      "Value": 0,
      "Label": {
        "@odata.type": "Microsoft.Dynamics.CRM.Label",
        "LocalizedLabels": [{
          "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
          "Label": "No",
          "LanguageCode": 1033
        }]
      }
    }
  },
  "DisplayName": { /* Label structure */ },
  "RequiredLevel": { "Value": "None" }
}
```

### 4.7 DateTime

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata",
  "AttributeType": "DateTime",
  "AttributeTypeName": { "Value": "DateTimeType" },
  "SchemaName": "hso_duedate_date",
  "Format": "DateOnly",
  "DateTimeBehavior": { "Value": "UserLocal" },
  "DisplayName": { /* Label structure */ },
  "RequiredLevel": { "Value": "None" }
}
```

**Format Values:**

| Value | Description |
|-------|-------------|
| `DateOnly` | Date without time |
| `DateAndTime` | Full date and time |

**DateTimeBehavior Values:**

| Value | Description |
|-------|-------------|
| `UserLocal` | Converted to user's time zone |
| `DateOnly` | No time zone conversion |
| `TimeZoneIndependent` | Stored as-is |

### 4.8 Choice (Picklist) - ALWAYS Use Global Choice

**CRITICAL:** Choice fields should ALWAYS reference a Global Choice. Do NOT use local option sets.

**Workflow:**
1. First create the Global Choice (see Section 6)
2. Then create the Choice field referencing the Global Choice

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.PicklistAttributeMetadata",
  "AttributeType": "Picklist",
  "AttributeTypeName": { "Value": "PicklistType" },
  "SchemaName": "hso_status_code",
  "GlobalOptionSet@odata.bind": "/GlobalOptionSetDefinitions(Name='hso_projectstatus')",
  "DisplayName": { /* Label structure */ },
  "RequiredLevel": { "Value": "None" }
}
```

**Why Global Choices?**
- Reusability across multiple tables
- Single source of truth
- Easier maintenance
- Consistent values

### 4.9 Choice (Picklist) - Local Option Set (AVOID)

**WARNING:** Local option sets should be avoided. Use Global Choices instead.

Only use local option sets when:
- The values are truly unique to one table and will NEVER be reused
- Creating a quick prototype (refactor to global before production)

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.PicklistAttributeMetadata",
  "AttributeType": "Picklist",
  "AttributeTypeName": { "Value": "PicklistType" },
  "SchemaName": "hso_localchoice_code",
  "OptionSet": {
    "@odata.type": "Microsoft.Dynamics.CRM.OptionSetMetadata",
    "IsGlobal": false,
    "OptionSetType": "Picklist",
    "Options": [
      {
        "Value": 100000000,
        "Label": {
          "@odata.type": "Microsoft.Dynamics.CRM.Label",
          "LocalizedLabels": [{
            "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
            "Label": "Option 1",
            "LanguageCode": 1033
          }]
        }
      }
    ]
  },
  "DisplayName": { /* Label structure */ },
  "RequiredLevel": { "Value": "None" }
}
```

### 4.10 Multi-Select Choice

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.MultiSelectPicklistAttributeMetadata",
  "AttributeType": "Virtual",
  "AttributeTypeName": { "Value": "MultiSelectPicklistType" },
  "SchemaName": "hso_tags_codes",
  "OptionSet": {
    "@odata.type": "Microsoft.Dynamics.CRM.OptionSetMetadata",
    "IsGlobal": false,
    "OptionSetType": "Picklist",
    "Options": [ /* Same as Picklist */ ]
  },
  "DisplayName": { /* Label structure */ },
  "RequiredLevel": { "Value": "None" }
}
```

---

## 5. RELATIONSHIP METADATA

### 5.1 One-to-Many (1:N)

**Endpoint:** `POST [OrgUrl]/api/data/v9.2/RelationshipDefinitions`

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata",
  "SchemaName": "hso_project_task",
  "ReferencedEntity": "hso_project",
  "ReferencedAttribute": "hso_projectid",
  "ReferencingEntity": "hso_task",
  "ReferencedEntityNavigationPropertyName": "hso_project_tasks",
  "ReferencingEntityNavigationPropertyName": "hso_projectid",
  "Lookup": {
    "@odata.type": "Microsoft.Dynamics.CRM.LookupAttributeMetadata",
    "AttributeType": "Lookup",
    "AttributeTypeName": { "Value": "LookupType" },
    "SchemaName": "hso_projectid",
    "DisplayName": {
      "@odata.type": "Microsoft.Dynamics.CRM.Label",
      "LocalizedLabels": [{
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Project",
        "LanguageCode": 1033
      }]
    },
    "RequiredLevel": { "Value": "None" }
  },
  "CascadeConfiguration": {
    "Assign": "NoCascade",
    "Delete": "RemoveLink",
    "Merge": "NoCascade",
    "Reparent": "NoCascade",
    "Share": "NoCascade",
    "Unshare": "NoCascade"
  }
}
```

### 5.2 Cascade Configuration Values

| Value | Assign | Delete | Share | Reparent |
|-------|--------|--------|-------|----------|
| `Cascade` | Children assigned to new owner | Children deleted | Children shared | Children reparented |
| `Active` | Only active children | Only active children | Only active children | Only active children |
| `UserOwned` | User-owned children only | User-owned children only | User-owned children only | User-owned children only |
| `NoCascade` | No effect on children | No effect | No effect | No effect |
| `RemoveLink` | N/A | Lookup set to null | N/A | N/A |
| `Restrict` | N/A | Prevent if children exist | N/A | N/A |

### 5.3 Many-to-Many (N:N)

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.ManyToManyRelationshipMetadata",
  "SchemaName": "hso_project_resource",
  "IntersectEntityName": "hso_project_resource",
  "Entity1LogicalName": "hso_project",
  "Entity2LogicalName": "hso_resource",
  "Entity1NavigationPropertyName": "hso_project_resources",
  "Entity2NavigationPropertyName": "hso_resource_projects",
  "Entity1AssociatedMenuConfiguration": {
    "Behavior": "UseCollectionName",
    "Group": "Details",
    "Label": {
      "@odata.type": "Microsoft.Dynamics.CRM.Label",
      "LocalizedLabels": [{
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Resources",
        "LanguageCode": 1033
      }]
    },
    "Order": 10000
  },
  "Entity2AssociatedMenuConfiguration": {
    "Behavior": "UseCollectionName",
    "Group": "Details",
    "Label": {
      "@odata.type": "Microsoft.Dynamics.CRM.Label",
      "LocalizedLabels": [{
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Projects",
        "LanguageCode": 1033
      }]
    },
    "Order": 10000
  }
}
```

### 5.4 Customer Lookup

**Endpoint:** `POST [OrgUrl]/api/data/v9.2/CreateCustomerRelationships`

```json
{
  "Lookup": {
    "@odata.type": "Microsoft.Dynamics.CRM.ComplexLookupAttributeMetadata",
    "AttributeType": "Lookup",
    "AttributeTypeName": { "Value": "LookupType" },
    "SchemaName": "hso_customerid",
    "DisplayName": {
      "@odata.type": "Microsoft.Dynamics.CRM.Label",
      "LocalizedLabels": [{
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Customer",
        "LanguageCode": 1033
      }]
    },
    "RequiredLevel": { "Value": "None" }
  },
  "OneToManyRelationships": [
    {
      "@odata.type": "Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata",
      "ReferencedEntity": "account",
      "ReferencingEntity": "hso_task",
      "SchemaName": "hso_task_customer_account"
    },
    {
      "@odata.type": "Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata",
      "ReferencedEntity": "contact",
      "ReferencingEntity": "hso_task",
      "SchemaName": "hso_task_customer_contact"
    }
  ]
}
```

---

## 6. GLOBAL OPTION SET METADATA

### 6.1 Create Global Option Set

**Endpoint:** `POST [OrgUrl]/api/data/v9.2/GlobalOptionSetDefinitions`

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.OptionSetMetadata",
  "Name": "hso_projectstatus",
  "OptionSetType": "Picklist",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "Project Status",
      "LanguageCode": 1033
    }]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "Status values for projects",
      "LanguageCode": 1033
    }]
  },
  "Options": [
    {
      "Value": 100000000,
      "Label": {
        "@odata.type": "Microsoft.Dynamics.CRM.Label",
        "LocalizedLabels": [{
          "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
          "Label": "Draft",
          "LanguageCode": 1033
        }]
      }
    },
    {
      "Value": 100000001,
      "Label": {
        "@odata.type": "Microsoft.Dynamics.CRM.Label",
        "LocalizedLabels": [{
          "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
          "Label": "Active",
          "LanguageCode": 1033
        }]
      }
    }
  ]
}
```

### 6.2 Add Option to Global Option Set

**Endpoint:** `POST [OrgUrl]/api/data/v9.2/InsertOptionValue`

```json
{
  "OptionSetName": "hso_projectstatus",
  "Value": 100000002,
  "Label": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "Completed",
      "LanguageCode": 1033
    }]
  },
  "SolutionUniqueName": "YourSolution"
}
```

### 6.3 Update Option Label

**Endpoint:** `POST [OrgUrl]/api/data/v9.2/UpdateOptionValue`

```json
{
  "OptionSetName": "hso_projectstatus",
  "Value": 100000001,
  "Label": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "In Progress",
      "LanguageCode": 1033
    }]
  },
  "MergeLabels": true
}
```

### 6.4 Reorder Options

**Endpoint:** `POST [OrgUrl]/api/data/v9.2/OrderOption`

```json
{
  "OptionSetName": "hso_projectstatus",
  "Values": [100000000, 100000001, 100000002],
  "SolutionUniqueName": "YourSolution"
}
```

### 6.5 Delete Option

**Endpoint:** `POST [OrgUrl]/api/data/v9.2/DeleteOptionValue`

```json
{
  "OptionSetName": "hso_projectstatus",
  "Value": 100000002
}
```

---

## 7. PUBLISHING CUSTOMIZATIONS

### 7.1 Publish Specific Tables

**Endpoint:** `POST [OrgUrl]/api/data/v9.2/PublishXml`

```json
{
  "ParameterXml": "<importexportxml><entities><entity>hso_project</entity><entity>hso_task</entity></entities></importexportxml>"
}
```

### 7.2 Publish All

**Endpoint:** `POST [OrgUrl]/api/data/v9.2/PublishAllXml`

```json
{}
```

---

## 8. REQUIRED HEADERS

All Web API metadata requests should include:

```http
Authorization: Bearer {access_token}
Content-Type: application/json; charset=utf-8
OData-MaxVersion: 4.0
OData-Version: 4.0
MSCRM.SolutionUniqueName: {solution_unique_name}
MSCRM.MergeLabels: true
```

| Header | Purpose |
|--------|---------|
| `Authorization` | OAuth 2.0 bearer token |
| `MSCRM.SolutionUniqueName` | Associates component with solution |
| `MSCRM.MergeLabels` | Preserves existing translations (critical for updates) |

---

## 9. OPTION VALUE RANGES

| Range | Purpose |
|-------|---------|
| 0-999 | System/Microsoft reserved |
| 1000-99999 | Legacy custom options |
| 100000000+ | **Recommended for custom options** |

**Best Practice:** Start custom option values at 100000000 and increment by 1.

---

## 10. ERROR CODES

| Error | Meaning | Solution |
|-------|---------|----------|
| `DuplicateRecord` | Component already exists | Query first, then update |
| `ObjectDoesNotExist` | Referenced component not found | Create dependencies first |
| `InvalidAttribute` | Invalid property in request | Check JSON structure |
| `PrivilegeNotGranted` | Missing permissions | Check user security roles |
| `SolutionNotFound` | Invalid solution name | Verify solution exists |

---

## 11. USEFUL QUERIES

### Query Table Definition

```http
GET [OrgUrl]/api/data/v9.2/EntityDefinitions(LogicalName='hso_project')?$select=LogicalName,DisplayName,SchemaName
```

### Query All Custom Tables

```http
GET [OrgUrl]/api/data/v9.2/EntityDefinitions?$filter=IsCustomEntity eq true&$select=LogicalName,DisplayName
```

### Query Table Attributes

```http
GET [OrgUrl]/api/data/v9.2/EntityDefinitions(LogicalName='hso_project')/Attributes?$select=LogicalName,DisplayName,AttributeType
```

### Query Global Option Sets

```http
GET [OrgUrl]/api/data/v9.2/GlobalOptionSetDefinitions?$filter=IsCustomOptionSet eq true&$select=Name,DisplayName
```

### Query Relationships

```http
GET [OrgUrl]/api/data/v9.2/RelationshipDefinitions?$filter=contains(SchemaName,'hso_')&$select=SchemaName,RelationshipType
```
