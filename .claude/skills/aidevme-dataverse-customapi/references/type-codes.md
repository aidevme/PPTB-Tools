# Custom API Type Codes Reference

Complete reference for Dataverse Custom API type codes, bindings, and field specifications.

## Parameter Type Codes

| Type | Code | C# Type | Notes |
|------|------|---------|-------|
| Boolean | 0 | `bool` | True/false |
| DateTime | 1 | `DateTime` | UTC format |
| Decimal | 2 | `decimal` | High precision |
| Entity | 3 | `Entity` | Requires `logicalentityname` |
| EntityCollection | 4 | `EntityCollection` | Requires `logicalentityname` |
| EntityReference | 5 | `EntityReference` | Optional `logicalentityname` |
| Float | 6 | `double` | Floating point |
| Integer | 7 | `int` | Whole number |
| Money | 8 | `Money` | Currency |
| Picklist | 9 | `OptionSetValue` | Option set |
| String | 10 | `string` | Text |
| StringArray | 11 | `string[]` | Array of strings |
| Guid | 12 | `Guid` | Unique identifier |

## Binding Types

| Type | Code | Use Case |
|------|------|----------|
| Global | 0 | Not bound to entity (most common) |
| Entity | 1 | Bound to single entity record |
| EntityCollection | 2 | Bound to entity collection |

**Note:** Entity/EntityCollection binding requires `boundentitylogicalname`.

## Processing Step Types

| Type | Code |
|------|------|
| Sync Only | 0 |
| Async Only | 1 |
| Sync and Async | 2 |

## Custom API Fields

| Field | Required | Description |
|-------|----------|-------------|
| `uniquename` | Yes | Unique identifier (prefix_Name) |
| `name` | Yes | Same as uniquename |
| `displayname` | Yes | User-friendly name |
| `description` | No | Description |
| `bindingtype` | Yes | See Binding Types |
| `boundentitylogicalname` | If bound | Entity logical name |
| `isfunction` | No | True = GET, False = POST |
| `isprivate` | No | Hide from documentation |
| `allowedcustomprocessingsteptype` | Yes | See Processing Step Types |
| `plugintypeid` | No | Plugin reference |

## Request Parameter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `uniquename` | Yes | Parameter name |
| `name` | Yes | Same as uniquename |
| `displayname` | Yes | Display name |
| `description` | No | Description |
| `type` | Yes | Type code |
| `isoptional` | Yes | True if optional |
| `logicalentityname` | If Entity type | Entity logical name |
| `CustomAPIId` | Yes | Parent Custom API |

## Response Property Fields

| Field | Required | Description |
|-------|----------|-------------|
| `uniquename` | Yes | Property name |
| `name` | Yes | Same as uniquename |
| `displayname` | Yes | Display name |
| `description` | No | Description |
| `type` | Yes | Type code |
| `logicalentityname` | If Entity type | Entity logical name |
| `CustomAPIId` | Yes | Parent Custom API |

## C# Type Mapping

```csharp
// Input parameters
var target = (EntityReference)context.InputParameters["Target"];  // Type 5
var count = (int)context.InputParameters["Count"];                // Type 7
var name = (string)context.InputParameters["Name"];               // Type 10
var id = (Guid)context.InputParameters["Id"];                     // Type 12

// Output parameters
context.OutputParameters["Success"] = true;                       // Type 0
context.OutputParameters["Message"] = "Done";                     // Type 10
context.OutputParameters["ResultId"] = Guid.NewGuid();            // Type 12
```

## Query Examples

```sql
-- List Custom APIs
SELECT customapiid, uniquename, displayname FROM customapi WHERE uniquename LIKE 'hso_%'

-- Get parameters for Custom API
SELECT p.uniquename, p.type, p.isoptional
FROM customapirequestparameter p
JOIN customapi c ON p.customapiid = c.customapiid
WHERE c.uniquename = 'hso_ActionName'

-- Get response properties
SELECT p.uniquename, p.type
FROM customapiresponseproperty p
JOIN customapi c ON p.customapiid = c.customapiid
WHERE c.uniquename = 'hso_ActionName'
```
