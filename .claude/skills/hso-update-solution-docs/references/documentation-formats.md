# Documentation Format Templates

Reference templates for updating Dataverse solution documentation.

## Version Markers

Use `*(NEW in vX.X.X.XXX)*` or `*(Updated in vX.X.X.XXX)*` for new/changed items.

## Entity Format

```markdown
#### hso_EntityName
**Purpose**: Brief description
**Ownership**: User or Team | Organization

**Key Relationships**:
- RelatedEntity (hso_field_id) - lookup, required/optional

**Key Fields**:
- Field Display Name (hso_fieldname) - Type
```

## Option Set Format

```markdown
#### hso_optionsetname_gc
**Purpose**: Description
**Options**:
- Label (value) - Description
```

## Custom API Format

```markdown
### hso_APIName
**Purpose**: Description

**Request Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|

**Response Parameters**:
| Name | Type | Description |
|------|------|-------------|
```

## Plugin Step Format

```markdown
### PluginClassName
**Entity**: tablename
**Message**: Create/Update/Delete
**Stage**: PreOperation/PostOperation
**Mode**: Sync/Async
**Description**: What the plugin does
```

## PCF Control Format

```markdown
### ControlName
**Namespace**: hso.ControlName
**Version**: X.X.X
**Type**: ReactControl/StandardControl
**Bound To**: Field type or dataset
**Description**: What the control does
```

## Cloud Flow Format

```markdown
### FlowName
**Trigger**: Dataverse table action / Scheduled / Manual
**Purpose**: What the flow does
**Key Actions**: Summary of main steps
```
