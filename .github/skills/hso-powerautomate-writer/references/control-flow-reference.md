# Control Flow & Variable Reference

JSON patterns for conditions, loops, scopes, variables, and other non-connector actions in Power Automate flows.

**Schema reference**: https://learn.microsoft.com/en-us/azure/logic-apps/workflow-definition-language-schema
**Actions/Triggers**: https://learn.microsoft.com/en-us/azure/logic-apps/logic-apps-workflow-actions-triggers

---

## Condition (If)

```json
"Check_if_Active": {
  "type": "If",
  "expression": {
    "equals": [
      "@triggerOutputs()?['body/statecode']",
      0
    ]
  },
  "actions": {
    "True_Branch_Action": { }
  },
  "else": {
    "actions": {
      "False_Branch_Action": { }
    }
  },
  "runAfter": {},
  "metadata": { "operationMetadataId": "<new-guid>" }
}
```

### Expression Operators

Single comparisons:

| Operator | Syntax | Description |
|----------|--------|-------------|
| `equals` | `{ "equals": [<left>, <right>] }` | Values are equal |
| `greater` | `{ "greater": [<left>, <right>] }` | Left > Right |
| `greaterOrEquals` | `{ "greaterOrEquals": [<left>, <right>] }` | Left >= Right |
| `less` | `{ "less": [<left>, <right>] }` | Left < Right |
| `lessOrEquals` | `{ "lessOrEquals": [<left>, <right>] }` | Left <= Right |
| `contains` | `{ "contains": [<string>, <search>] }` | String contains substring |
| `startsWith` | `{ "startsWith": [<string>, <search>] }` | String starts with |
| `endsWith` | `{ "endsWith": [<string>, <search>] }` | String ends with |

Logical combinations:

```json
// AND - all conditions must be true
{
  "and": [
    { "equals": ["@triggerOutputs()?['body/statecode']", 0] },
    { "greater": ["@triggerOutputs()?['body/revenue']", 1000] }
  ]
}

// OR - any condition must be true
{
  "or": [
    { "equals": ["@triggerOutputs()?['body/statuscode']", 818440001] },
    { "equals": ["@triggerOutputs()?['body/statuscode']", 818440002] }
  ]
}

// NOT - negate a condition
{
  "not": {
    "equals": ["@triggerOutputs()?['body/statecode']", 0]
  }
}

// Nested: AND containing OR
{
  "and": [
    { "equals": ["@triggerOutputs()?['body/statecode']", 0] },
    {
      "or": [
        { "equals": ["@variables('Type')", "A"] },
        { "equals": ["@variables('Type')", "B"] }
      ]
    }
  ]
}
```

### Checking for null/empty

```json
// Check if a field is empty/null
{ "equals": ["@triggerOutputs()?['body/description']", null] }
{ "equals": ["@empty(triggerOutputs()?['body/description'])", true] }

// Check if a lookup is set
{ "not": { "equals": ["@triggerOutputs()?['body/_parentaccountid_value']", null] } }

// Check array length
{ "greater": ["@length(outputs('List_rows')?['body/value'])", 0] }
```

---

## Switch

```json
"Switch_on_Status": {
  "type": "Switch",
  "expression": "@triggerOutputs()?['body/statuscode']",
  "cases": {
    "Case_Active": {
      "case": 1,
      "actions": {
        "Handle_Active": { }
      }
    },
    "Case_Inactive": {
      "case": 2,
      "actions": {
        "Handle_Inactive": { }
      }
    }
  },
  "default": {
    "actions": {
      "Handle_Unknown": { }
    }
  },
  "runAfter": {},
  "metadata": { "operationMetadataId": "<new-guid>" }
}
```

- Case values can be strings or numbers
- Each case name must be unique within the Switch
- The `default` branch is optional but recommended
- Maximum 25 cases per Switch

---

## Apply to each (Foreach)

```json
"Apply_to_each_Contact": {
  "type": "Foreach",
  "foreach": "@outputs('List_Contacts')?['body/value']",
  "actions": {
    "Update_Contact": {
      "runAfter": {},
      "metadata": { "operationMetadataId": "<new-guid>" },
      "type": "OpenApiConnection",
      "inputs": {
        "host": {
          "connectionName": "shared_commondataserviceforapps",
          "operationId": "UpdateOnlyRecord",
          "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
        },
        "parameters": {
          "entityName": "contacts",
          "recordId": "@items('Apply_to_each_Contact')?['contactid']",
          "item/description": "Updated by automation"
        },
        "authentication": "@parameters('$authentication')"
      }
    }
  },
  "runAfter": {
    "List_Contacts": ["Succeeded"]
  },
  "metadata": { "operationMetadataId": "<new-guid>" }
}
```

- `@items('<LoopName>')` references the current item
- By default, iterations run in parallel. Use `"operationOptions": "Sequential"` or `runtimeConfiguration.concurrency.repetitions` to control.
- Nested loops: reference the specific loop name in `items()`, e.g., `@items('Outer_Loop')`

### Sequential execution

```json
"Apply_to_each": {
  "type": "Foreach",
  "foreach": "@outputs('List_rows')?['body/value']",
  "actions": { },
  "runAfter": {},
  "runtimeConfiguration": {
    "concurrency": {
      "repetitions": 1
    }
  }
}
```

---

## Do until

```json
"Retry_Until_Success": {
  "type": "Until",
  "actions": {
    "Check_Status": {
      "runAfter": {},
      "type": "OpenApiConnection",
      "inputs": {
        "host": {
          "connectionName": "shared_commondataserviceforapps",
          "operationId": "GetItem",
          "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
        },
        "parameters": {
          "entityName": "hso_jobs",
          "recordId": "@variables('JobId')",
          "$select": "statuscode"
        },
        "authentication": "@parameters('$authentication')"
      }
    },
    "Wait_30_Seconds": {
      "type": "Wait",
      "inputs": {
        "interval": { "count": 30, "unit": "Second" }
      },
      "runAfter": { "Check_Status": ["Succeeded"] }
    }
  },
  "expression": "@equals(outputs('Check_Status')?['body/statuscode'], 818440002)",
  "limit": {
    "count": 60,
    "timeout": "PT1H"
  },
  "runAfter": {},
  "metadata": { "operationMetadataId": "<new-guid>" }
}
```

- Loop evaluates expression AFTER each iteration
- Exits when expression is `true` OR limit is reached
- `limit.count`: max iterations (required)
- `limit.timeout`: max duration in ISO 8601 format (required)

---

## Scope

Groups actions and provides a collective status. Used for try-catch patterns.

```json
"Try_Scope": {
  "type": "Scope",
  "actions": {
    "Action_That_Might_Fail": { }
  },
  "runAfter": {}
},
"Catch_Scope": {
  "type": "Scope",
  "actions": {
    "Handle_Error": { }
  },
  "runAfter": {
    "Try_Scope": ["Failed", "TimedOut"]
  }
},
"Finally_Scope": {
  "type": "Scope",
  "actions": {
    "Cleanup": { }
  },
  "runAfter": {
    "Try_Scope": ["Succeeded", "Failed", "Skipped", "TimedOut"],
    "Catch_Scope": ["Succeeded", "Failed", "Skipped", "TimedOut"]
  }
}
```

### runAfter Status Values

| Status | Description |
|--------|-------------|
| `Succeeded` | Previous action completed successfully |
| `Failed` | Previous action failed |
| `Skipped` | Previous action was skipped (e.g., condition branch not taken) |
| `TimedOut` | Previous action timed out |

Use multiple statuses to handle error scenarios:

```json
"runAfter": {
  "Previous_Action": ["Succeeded", "Failed"]
}
```

---

## Variables

### Initialize Variable

Must be at the top level of the flow (not inside conditions, loops, or scopes).

```json
"Initialize_Counter": {
  "type": "InitializeVariable",
  "inputs": {
    "variables": [
      {
        "name": "Counter",
        "type": "integer",
        "value": 0
      }
    ]
  },
  "runAfter": {}
}
```

**Variable types**: `string`, `integer`, `float`, `boolean`, `array`, `object`

```json
// String variable
{ "name": "MyString", "type": "string", "value": "hello" }

// Array variable
{ "name": "MyArray", "type": "array", "value": [] }

// Object variable
{ "name": "MyObject", "type": "object", "value": {} }

// Boolean variable
{ "name": "IsActive", "type": "boolean", "value": true }
```

### Set Variable

```json
"Set_Counter": {
  "type": "SetVariable",
  "inputs": {
    "name": "Counter",
    "value": "@add(variables('Counter'), 1)"
  },
  "runAfter": { "Some_Action": ["Succeeded"] }
}
```

### Increment Variable

```json
"Increment_Counter": {
  "type": "IncrementVariable",
  "inputs": {
    "name": "Counter",
    "value": 1
  },
  "runAfter": {}
}
```

### Decrement Variable

```json
"Decrement_Counter": {
  "type": "DecrementVariable",
  "inputs": {
    "name": "Counter",
    "value": 1
  },
  "runAfter": {}
}
```

### Append to string variable

```json
"Append_to_String": {
  "type": "AppendToStringVariable",
  "inputs": {
    "name": "ResultText",
    "value": "@{items('Apply_to_each')?['name']}\n"
  },
  "runAfter": {}
}
```

### Append to array variable

```json
"Append_to_Array": {
  "type": "AppendToArrayVariable",
  "inputs": {
    "name": "ResultArray",
    "value": "@items('Apply_to_each')?['accountid']"
  },
  "runAfter": {}
}
```

---

## Compose

Creates a single output from inputs. Useful for building complex objects or transforming data.

```json
"Compose_Payload": {
  "type": "Compose",
  "inputs": {
    "name": "@triggerOutputs()?['body/name']",
    "email": "@triggerOutputs()?['body/emailaddress1']",
    "createdOn": "@formatDateTime(utcNow(), 'yyyy-MM-dd')"
  },
  "runAfter": {}
}
```

Access output: `@outputs('Compose_Payload')`

---

## Parse JSON

```json
"Parse_Response": {
  "type": "ParseJson",
  "inputs": {
    "content": "@body('HTTP_Request')",
    "schema": {
      "type": "object",
      "properties": {
        "id": { "type": "string" },
        "status": { "type": "string" },
        "items": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "name": { "type": "string" },
              "value": { "type": "number" }
            }
          }
        }
      }
    }
  },
  "runAfter": { "HTTP_Request": ["Succeeded"] }
}
```

Access parsed fields: `@body('Parse_Response')?['status']`

---

## Select

Transform array items into a new shape.

```json
"Select_Names": {
  "type": "Select",
  "inputs": {
    "from": "@outputs('List_Contacts')?['body/value']",
    "select": {
      "FullName": "@item()?['fullname']",
      "Email": "@item()?['emailaddress1']"
    }
  },
  "runAfter": { "List_Contacts": ["Succeeded"] }
}
```

---

## Filter array (Query)

```json
"Filter_Active_Only": {
  "type": "Query",
  "inputs": {
    "from": "@outputs('List_rows')?['body/value']",
    "where": "@equals(item()?['statecode'], 0)"
  },
  "runAfter": { "List_rows": ["Succeeded"] }
}
```

---

## Join

```json
"Join_Names": {
  "type": "Join",
  "inputs": {
    "from": "@body('Select_Names')",
    "joinWith": ", "
  },
  "runAfter": { "Select_Names": ["Succeeded"] }
}
```

---

## Create HTML/CSV Table

```json
"Create_CSV_Table": {
  "type": "Table",
  "inputs": {
    "format": "CSV",
    "from": "@outputs('List_rows')?['body/value']",
    "columns": [
      { "header": "Name", "value": "@item()?['name']" },
      { "header": "Status", "value": "@item()?['statecode']" }
    ]
  },
  "runAfter": { "List_rows": ["Succeeded"] }
}
```

---

## Terminate

```json
"Terminate_Success": {
  "type": "Terminate",
  "inputs": {
    "runStatus": "Succeeded"
  },
  "runAfter": {}
}
```

```json
"Terminate_Failure": {
  "type": "Terminate",
  "inputs": {
    "runStatus": "Failed",
    "runError": {
      "code": "ValidationError",
      "message": "Required field was empty"
    }
  },
  "runAfter": {}
}
```

---

## Delay (Wait)

```json
"Wait_5_Minutes": {
  "type": "Wait",
  "inputs": {
    "interval": {
      "count": 5,
      "unit": "Minute"
    }
  },
  "runAfter": {}
}
```

```json
"Delay_Until": {
  "type": "Wait",
  "inputs": {
    "until": {
      "timestamp": "@addHours(utcNow(), 2)"
    }
  },
  "runAfter": {}
}
```

Units: `Second`, `Minute`, `Hour`, `Day`, `Week`, `Month`

---

## HTTP Action

For calling external APIs outside of Dataverse.

```json
"Call_External_API": {
  "type": "Http",
  "inputs": {
    "method": "POST",
    "uri": "https://api.example.com/webhook",
    "headers": {
      "Content-Type": "application/json",
      "Authorization": "Bearer @{variables('ApiToken')}"
    },
    "body": {
      "recordId": "@triggerOutputs()?['body/accountid']",
      "name": "@triggerOutputs()?['body/name']"
    },
    "retryPolicy": {
      "type": "exponential",
      "count": 3,
      "interval": "PT10S",
      "maximumInterval": "PT1H"
    }
  },
  "runAfter": {}
}
```

---

## Response Action

Only valid with a Request (HTTP) trigger. Returns data to the caller.

```json
"Respond_with_Data": {
  "type": "Response",
  "kind": "http",
  "inputs": {
    "statusCode": 200,
    "headers": {
      "Content-Type": "application/json"
    },
    "body": {
      "success": true,
      "recordId": "@outputs('Create_Record')?['body/accountid']"
    }
  },
  "runAfter": { "Create_Record": ["Succeeded"] }
}
```

### Power Pages response outputs

For a flow called from Power Pages, make every response schema `properties` key, its `title`, and
the corresponding response body key lowercase. Keep the property key and `title` identical. The
maker editor lowercases the property key returned to Power Pages but can retain different casing
in `title`, leaving a misleading schema.

```json
"Return_result": {
  "type": "Response",
  "kind": "PowerPages",
  "inputs": {
    "statusCode": 200,
    "body": {
      "matched": "@variables('matched')",
      "resultid": "@variables('resultId')"
    },
    "schema": {
      "type": "object",
      "properties": {
        "matched": {
          "title": "matched",
          "x-ms-dynamically-added": true,
          "type": "boolean"
        },
        "resultid": {
          "title": "resultid",
          "x-ms-dynamically-added": true,
          "type": "string"
        }
      }
    }
  }
}
```

Power Pages responses use `kind: "PowerPages"`. Power Apps responses use `kind: "PowerApp"` and
follow the same lowercase output-name rule.
