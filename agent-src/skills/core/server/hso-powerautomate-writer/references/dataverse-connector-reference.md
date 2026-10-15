# Dataverse Connector Reference for Power Automate Flows

Complete JSON patterns for all Microsoft Dataverse connector (`shared_commondataserviceforapps`) triggers and actions.

**Official docs**: https://learn.microsoft.com/en-us/connectors/commondataserviceforapps/

---

## Connection References

Every flow that uses the Dataverse connector needs a connection reference in the top-level `connectionReferences`:

```json
"connectionReferences": {
  "shared_commondataserviceforapps": {
    "runtimeSource": "embedded",
    "connection": {
      "connectionReferenceLogicalName": "<prefix>_sharedcommondataserviceforapps_<suffix>"
    },
    "api": {
      "name": "shared_commondataserviceforapps"
    }
  }
}
```

- The `connectionReferenceLogicalName` must match an existing connection reference in the target Dataverse solution.
- Query existing connection references using `hso-dataverse-data-modeling` or `hso-dataverse-data` skills.
- Multiple connectors can be referenced (e.g., if the flow also uses Approvals or Office 365).

---

## Triggers

### When a row is added, modified or deleted (SubscribeWebhookTrigger)

The most common Dataverse trigger. Fires when a record changes in a specified table.

```json
"<Trigger_Name>": {
  "metadata": {
    "operationMetadataId": "<new-guid>"
  },
  "type": "OpenApiConnectionWebhook",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "SubscribeWebhookTrigger",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "subscriptionRequest/message": 1,
      "subscriptionRequest/entityname": "<table-logical-name>",
      "subscriptionRequest/scope": 4,
      "subscriptionRequest/filteringattributes": "<comma-separated-columns>",
      "subscriptionRequest/filterexpression": "<odata-filter>",
      "subscriptionRequest/postponeuntil": "<delay-expression>",
      "subscriptionRequest/runas": 1
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

**Parameter values:**

| Parameter | Values | Description |
|-----------|--------|-------------|
| `message` | `1` = Create, `2` = Delete, `3` = Update, `4` = Create or Update | Change type |
| `entityname` | Table logical name (e.g., `account`, `contact`, `msdyn_workorder`) | Target table |
| `scope` | `1` = User, `2` = Business Unit, `3` = Parent:Child Business Units, `4` = Organization | Trigger scope |
| `filteringattributes` | Comma-separated column logical names | Only trigger on these column changes (Update only) |
| `filterexpression` | OData filter expression | Only trigger for rows matching this filter |
| `postponeuntil` | ISO 8601 datetime or expression | Delay trigger evaluation |
| `runas` | `1` = Flow owner, `2` = Row modifier | Running user for invoker connections |

**Optional parameters**: `filteringattributes`, `filterexpression`, `postponeuntil`, `runas` — omit if not needed.

**Examples:**

```json
// Trigger on account creation (org-wide)
"When_Account_Created": {
  "metadata": { "operationMetadataId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890" },
  "type": "OpenApiConnectionWebhook",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "SubscribeWebhookTrigger",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "subscriptionRequest/message": 1,
      "subscriptionRequest/entityname": "account",
      "subscriptionRequest/scope": 4
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

```json
// Trigger on status change of a custom table with filter
"When_Status_Changes": {
  "metadata": { "operationMetadataId": "b2c3d4e5-f6a7-8901-bcde-f12345678901" },
  "type": "OpenApiConnectionWebhook",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "SubscribeWebhookTrigger",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "subscriptionRequest/message": 3,
      "subscriptionRequest/entityname": "hso_customtable",
      "subscriptionRequest/scope": 4,
      "subscriptionRequest/filteringattributes": "statuscode",
      "subscriptionRequest/filterexpression": "statecode eq 0"
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

### When a row is selected (OnRecordSelected)

Triggered from the command bar "Run Flow" button on a model-driven app form or view.

```json
"When_a_row_is_selected": {
  "metadata": {
    "operationMetadataId": "<new-guid>"
  },
  "type": "OpenApiConnectionWebhook",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "OnRecordSelected",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entity/entityName": "<table-logical-name>",
      "entity/schema": {
        "type": "object",
        "properties": {},
        "required": []
      }
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

### When an action is performed (BusinessEventsTrigger)

Triggers when a Dataverse action (SDK message) completes.

```json
"When_action_performed": {
  "metadata": {
    "operationMetadataId": "<new-guid>"
  },
  "type": "OpenApiConnectionWebhook",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "BusinessEventsTrigger",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "catalog": "allTables",
      "category": "allCategory",
      "subscriptionRequest/entityname": "<table-logical-name>",
      "subscriptionRequest/sdkmessagename": "<action-name>"
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

### Manual / Button Trigger (Request)

For manually-triggered flows (instant flows).

```json
"manual": {
  "metadata": {
    "operationMetadataId": "<new-guid>"
  },
  "type": "Request",
  "kind": "Button",
  "inputs": {
    "schema": {
      "type": "object",
      "properties": {
        "text": {
          "title": "Input Name",
          "type": "string",
          "x-ms-dynamically-added": true,
          "description": "Please enter your input",
          "x-ms-content-hint": "TEXT"
        }
      },
      "required": ["text"]
    }
  }
}
```

**Input types for schema properties:**

| x-ms-content-hint | type | Description |
|-------------------|------|-------------|
| `TEXT` | `string` | Single line text |
| `MULTILINE` | `string` | Multi-line text |
| `NUMBER` | `number` | Decimal number |
| `FILE` | `object` | File attachment |
| `EMAIL` | `string` | Email address |
| `DATE` | `string` (format: `date`) | Date picker |
| `BOOLEAN` | `boolean` | Yes/No toggle |

### Scheduled Trigger (Recurrence)

For flows that run on a schedule.

```json
"Recurrence": {
  "metadata": {
    "operationMetadataId": "<new-guid>"
  },
  "type": "Recurrence",
  "recurrence": {
    "frequency": "Day",
    "interval": 1,
    "startTime": "2026-01-01T08:00:00Z",
    "timeZone": "Eastern Standard Time",
    "schedule": {
      "hours": ["8", "12", "17"],
      "minutes": ["0"],
      "weekDays": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    }
  }
}
```

**Frequency values**: `Second`, `Minute`, `Hour`, `Day`, `Week`, `Month`

---

## Actions

### Common Action Structure

Every Dataverse connector action follows this pattern:

```json
"<Action_Name>": {
  "runAfter": {
    "<Previous_Action>": ["Succeeded"]
  },
  "metadata": {
    "operationMetadataId": "<new-guid>"
  },
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "<operation-id>",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "<parameter-key>": "<parameter-value>"
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

The first action after the trigger uses `"runAfter": {}` (empty object).

### Add a new row (CreateRecord)

```json
"Create_Account": {
  "runAfter": {},
  "metadata": { "operationMetadataId": "<new-guid>" },
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "CreateRecord",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entityName": "accounts",
      "item/name": "Contoso Ltd",
      "item/telephone1": "555-0100",
      "item/primarycontactid@odata.bind": "contacts(@{triggerOutputs()?['body/contactid']})"
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

**Field patterns:**
- Simple fields: `"item/<fieldname>": "<value>"`
- Lookup fields (set): `"item/<lookupfield>@odata.bind": "<entitysetname>(<guid-or-expression>)"`
- Lookup fields (clear): `"item/<lookupfield>@odata.bind": null`
- Choice fields: `"item/<choicefield>": <numeric-value>`
- Date fields: `"item/<datefield>": "@utcNow()"` or ISO 8601 string
- Boolean fields: `"item/<boolfield>": true` or `false`
- Required field left intentionally blank: `"item/<requiredfield>": "@{null}"` (keep the key present rather than omitting it)

**Polymorphic lookup fields (ownerid, regardingobjectid, customerid):**

Polymorphic lookups can point to multiple table types. The Dataverse connector uses a table-specific **parameter name** pattern, but the **value** still follows the standard `@odata.bind` format: `<entitysetname>(<guid>)`. A bare GUID will fail at runtime with `0x80060888 ODataUnrecognizedPathException — Resource not found for the segment '<guid>'`.

**Parameter name pattern:**
- Owner: `"item/ownerid_<sourcetable>@odata.bind"` (e.g., `ownerid_task`, `ownerid_account`)
- Regarding: `"item/regardingobjectid_<targettable>_<sourcetable>@odata.bind"` (e.g., `regardingobjectid_account_task`)
- Customer: `"item/customerid_<targettable>@odata.bind"` (e.g., `customerid_account`, `customerid_contact`)

**Value pattern (all polymorphic lookups):** `"<entitysetname>(<guid>)"` — same as regular `@odata.bind` lookups.

| Field | Parameter Name | Value |
|-------|---------------|-------|
| Owner → user | `"item/ownerid_task@odata.bind"` | `"systemusers(<guid>)"` |
| Owner → team | `"item/ownerid_task@odata.bind"` | `"teams(<guid>)"` |
| Regarding → hso_billingevent | `"item/regardingobjectid_hso_billingevent_task@odata.bind"` | `"hso_billingevents(<guid>)"` |
| Regarding → account | `"item/regardingobjectid_account_task@odata.bind"` | `"accounts(<guid>)"` |
| Customer → account | `"item/customerid_account@odata.bind"` | `"accounts(<guid>)"` |
| Customer → contact | `"item/customerid_contact@odata.bind"` | `"contacts(<guid>)"` |

**Owner: picking the correct entity set for a polymorphic source.** When the value comes from a trigger/list output, the `@Microsoft.Dynamics.CRM.lookuplogicalname` annotation on the raw lookup value tells you whether it is a `systemuser` or a `team`. Use it to build the reference:

```json
"item/ownerid_task@odata.bind": "@concat(if(equals(items('Apply_to_each')?['_ownerid_value@Microsoft.Dynamics.CRM.lookuplogicalname'], 'team'), 'teams(', 'systemusers('), items('Apply_to_each')?['_ownerid_value'], ')')"
```

If the source is guaranteed to be a user (e.g., a user lookup column), hardcode `systemusers(...)`:
```json
"item/ownerid_task@odata.bind": "@concat('systemusers(', items('Apply_to_each')?['_hso_owner_lu_value'], ')')"
```

**Regarding: always wrap in the target entity set.** Never pass `@items('loop_name')` directly — that serializes the whole record, not a URL reference:

```json
"item/regardingobjectid_hso_billingevent_task@odata.bind": "@concat('hso_billingevents(', items('Apply_to_each')?['hso_billingeventid'], ')')"
```

**Common failure modes:**
- `0x80060888 ODataUnrecognizedPathException — Resource not found for the segment '<guid>'` → value is a bare GUID; add `<entitysetname>(...)` wrapper.
- `0x80060888 ... Resource not found for the segment 'body'` → value is a record object (e.g., `@items('Apply_to_each')`) instead of a URL string; wrap with `concat('<entityset>(', item?['<pkfield>'], ')')`.

> **IMPORTANT:** The `regardingobjectid` field requires the target table to have **Activities enabled** (`HasActivities = true`). If the target table does not have Activities enabled, the field will not appear in the connector schema and the flow will fail with `InvalidOpenApiFlow`. Use the `hso-dataverse-data-modeling` skill's `UpdateTable` operation to enable Activities before referencing a table in Regarding.

> **TIP:** If unsure of the exact parameter name, set the field in the Power Automate UI designer, save the flow, then read the `clientdata` from the workflow record to see the exact parameter name the platform generated.

### Update a row (UpdateOnlyRecord)

```json
"Update_Account": {
  "runAfter": { "Get_Account": ["Succeeded"] },
  "metadata": { "operationMetadataId": "<new-guid>" },
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "UpdateOnlyRecord",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entityName": "accounts",
      "recordId": "@outputs('Get_Account')?['body/accountid']",
      "item/telephone1": "555-0200"
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

### Delete a row (DeleteRecord)

```json
"Delete_Record": {
  "runAfter": {},
  "metadata": { "operationMetadataId": "<new-guid>" },
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "DeleteRecord",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entityName": "accounts",
      "recordId": "@triggerOutputs()?['body/accountid']"
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

### Get a row by ID (GetItem)

```json
"Get_Account": {
  "runAfter": {},
  "metadata": { "operationMetadataId": "<new-guid>" },
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "GetItem",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entityName": "accounts",
      "recordId": "@triggerOutputs()?['body/_parentaccountid_value']",
      "$select": "name,telephone1,accountid",
      "$expand": "primarycontactid($select=fullname,emailaddress1)"
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

### List rows (ListRecords)

```json
"List_Active_Contacts": {
  "runAfter": {},
  "metadata": { "operationMetadataId": "<new-guid>" },
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "ListRecords",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entityName": "contacts",
      "$select": "fullname,emailaddress1,contactid",
      "$filter": "statecode eq 0 and _parentcustomerid_value eq '@{triggerOutputs()?['body/accountid']}'",
      "$orderby": "fullname asc",
      "$top": 50
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

**Using FetchXML instead of OData:**

```json
"List_with_FetchXML": {
  "runAfter": {},
  "metadata": { "operationMetadataId": "<new-guid>" },
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "ListRecords",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entityName": "contacts",
      "fetchXml": "<fetch top='50'><entity name='contact'><attribute name='fullname'/><filter><condition attribute='statecode' operator='eq' value='0'/></filter></entity></fetch>"
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

### Upsert a row (UpdateRecord)

```json
"Upsert_Record": {
  "runAfter": {},
  "metadata": { "operationMetadataId": "<new-guid>" },
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "UpdateRecord",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entityName": "accounts",
      "recordId": "@variables('AccountId')",
      "item/name": "@variables('AccountName')"
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

### Relate rows (AssociateEntities)

```json
"Relate_Contact_to_Account": {
  "runAfter": {},
  "metadata": { "operationMetadataId": "<new-guid>" },
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "AssociateEntities",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entityName": "accounts",
      "recordId": "@triggerOutputs()?['body/accountid']",
      "associationEntityRelationship": "contact_customer_accounts",
      "@odata.id": "@{outputs('Get_Contact')?['body/@odata.id']}"
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

### Perform a bound action (PerformBoundAction)

```json
"Perform_Bound_Action": {
  "runAfter": {},
  "metadata": { "operationMetadataId": "<new-guid>" },
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "PerformBoundAction",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entityName": "incidents",
      "actionName": "Microsoft.Dynamics.CRM.ResolveIncident",
      "recordId": "@triggerOutputs()?['body/incidentid']",
      "item/Status": 5,
      "item/IncidentResolution": {
        "subject": "Resolved via automation",
        "incidentid@odata.bind": "incidents(@{triggerOutputs()?['body/incidentid']})"
      }
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

**CRITICAL — Unbound-only messages must NOT be authored as bound-action steps:**

Some Web API messages exist **only as unbound functions/actions** — `CalculateRollupField`
(unbound function; parameters `Target` + `FieldName`) is the proven case. Authored as a
`PerformBoundAction` step the flow **deploys fine but activation deterministically fails** with
`InvalidOpenApiFlow` → `GetMetadataForBoundActionInput` → *"Bound action
'Microsoft.Dynamics.CRM.CalculateRollupField' is not found in the Organization"* — a
`PublishAll` + retry reproduces it verbatim (Bug #298, WI-342 run). `Invoke-FlowDeployment.ps1`
now rejects these at deploy time (`Test-FlowClientData`).

Alternatives, in preference order:

1. **Drop the step** when a server-side rollup-refresh plugin already covers the recalculation
   (e.g. a plugin registered on the write that the flow performs) — the step is redundant.
2. **Rely on the platform's periodic rollup recalculation** (each rollup column recalculates
   hourly by default; the initial mass-calc job runs 12 h after column creation) when freshness
   within the hour is acceptable.
3. **Call the unbound message directly** via the Dataverse connector's HTTP-request pattern
   (`GET [Organization URI]/api/data/v9.2/CalculateRollupField(Target=@tid,FieldName=@fn)?...`)
   or an HTTP-with-Entra-ID action when the connector shape can't express it.

### Perform an unbound action (PerformUnboundAction)

```json
"Perform_Unbound_Action": {
  "runAfter": {},
  "metadata": { "operationMetadataId": "<new-guid>" },
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "PerformUnboundAction",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "actionName": "hso_MyCustomAction",
      "item/InputParam1": "value1",
      "item/InputParam2": 42
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

**CRITICAL — EntityReference parameters in Custom API unbound actions:**

When a Custom API request parameter is of type `EntityReference` (type code 5), the parameter path
must include the referenced entity's primary key field as a nested sub-path. The Dataverse connector's
OpenAPI schema expands EntityReference parameters into the referenced entity's fields.

```
CORRECT:  "item/ParamName/entityprimarykeyfield": "@expression"
WRONG:    "item/ParamName": "@expression"
```

Example — Custom API `hso_GenerateInvoiceForSubscription` with `SubscriptionId` parameter
(EntityReference → `hso_customersubscription`):

```json
"parameters": {
  "actionName": "hso_GenerateInvoiceForSubscription",
  "item/SubscriptionId/hso_customersubscriptionid": "@items('Apply_to_Each')?['hso_customersubscriptionid']",
  "item/BillingDate": "@utcNow()"
}
```

Using the flat `"item/SubscriptionId"` format causes `InvalidOpenApiFlow` on save, which
bricks the workflow record (all subsequent operations including delete will fail with
`DefinitionRequestMissingFields` until the clientdata is patched with valid JSON).

### Perform a changeset request (ExecuteChangeset)

Wraps multiple actions in a single transaction — all succeed or all roll back.

```json
"Changeset": {
  "runAfter": {},
  "metadata": { "operationMetadataId": "<new-guid>" },
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "ExecuteChangeset",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "operations": [
        {
          "operationId": "CreateRecord",
          "parameters": {
            "entityName": "accounts",
            "item/name": "New Account"
          }
        },
        {
          "operationId": "CreateRecord",
          "parameters": {
            "entityName": "contacts",
            "item/lastname": "Smith"
          }
        }
      ]
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

---

## Output Reference Patterns

### Accessing trigger outputs

```
@triggerOutputs()?['body/<fieldname>']              // Simple field
@triggerOutputs()?['body/_<lookupfield>_value']     // Lookup GUID
@triggerOutputs()?['body/<fieldname>@OData.Community.Display.V1.FormattedValue']  // Formatted value
@triggerOutputs()?['body/_<lookupfield>_value@Microsoft.Dynamics.CRM.lookuplogicalname']  // Lookup entity type
@triggerOutputs()?['body/_<lookupfield>_value@OData.Community.Display.V1.FormattedValue'] // Lookup display name
```

### Accessing action outputs

```
@outputs('<ActionName>')?['body/<fieldname>']        // Simple field from Get/Create/Update
@outputs('<ActionName>')?['body/value']              // Array from List rows
@outputs('<ActionName>')?['body/@odata.id']          // OData ID URL for Relate
@outputs('<ActionName>')?['body/<primarykey>']       // Primary key GUID
```

### Accessing list items in loops

```
@items('<ForEachName>')?['<fieldname>']              // Current item field
@items('<ForEachName>')?['_<lookupfield>_value']     // Current item lookup
```

---

## Custom Parameters (Environment Variables)

Flows can use custom parameters that map to Dataverse environment variables for configurable values:

```json
"parameters": {
  "$connections": { "defaultValue": {}, "type": "Object" },
  "$authentication": { "defaultValue": {}, "type": "SecureObject" },
  "My Config Value (prefix_SchemaName)": {
    "defaultValue": "<default-value>",
    "type": "String",
    "metadata": {
      "schemaName": "prefix_SchemaName",
      "description": "Description of this parameter"
    }
  }
}
```

Reference in actions: `@parameters('My Config Value (prefix_SchemaName)')`

Supported types: `String`, `Int`, `Float`, `Bool`, `Array`, `Object`, `SecureString`, `SecureObject`

---

## Retry Policy

Add to any action for automatic retry on transient errors:

```json
"retryPolicy": {
  "type": "fixed",
  "count": 3,
  "interval": "PT30S"
}
```

Or exponential backoff:

```json
"retryPolicy": {
  "type": "exponential",
  "count": 4,
  "interval": "PT10S",
  "minimumInterval": "PT5S",
  "maximumInterval": "PT1H"
}
```

---

## Pagination

For List rows operations that may return more than the default page size:

```json
"runtimeConfiguration": {
  "paginationPolicy": {
    "minimumItemCount": 5000
  }
}
```

Add this as a sibling to `type`, `inputs`, `runAfter` on the action.

## Concurrency Control

For triggers:
```json
"runtimeConfiguration": {
  "concurrency": {
    "runs": 1,
    "maximumWaitingRuns": 100
  }
}
```

For Apply to each:
```json
"runtimeConfiguration": {
  "concurrency": {
    "repetitions": 20
  }
}
```
