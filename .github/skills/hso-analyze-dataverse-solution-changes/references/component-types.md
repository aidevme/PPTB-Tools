# Solution Component Type Reference

## Component Details Extracted

| Component Type | Properties Extracted |
|----------------|---------------------|
| **Tables/Entities** | Schema name, display name, custom vs OOB, attribute count, custom fields, best practice warnings |
| **PCF Controls** | Namespace, constructor, version, control type, properties |
| **Global Option Sets** | Name, type, options with values and labels |
| **Custom APIs** | Parameters, response properties, binding type, action/function type |
| **Plugin Steps** | Message, entity, stage, mode, execution order, filtered attributes |
| **Entity Views** | Columns, filters, sort order, view type |
| **Forms** | Subgrids, views, controls, tabs, BEFORE/AFTER comparison |
| **Power Automate Workflows** | Triggers, field references, entity dependencies |
| **Web Resources** | File types, descriptions, binary assets |
| **Canvas Apps** | Names, types, entity dependencies |
| **App Modules** | Navigation items, subareas, component counts |

## Component Type Codes

| Type Code | Component | Folder Location |
|-----------|-----------|-----------------|
| 1 | Entity/Table | `Entities/` |
| 9 | Global Option Set | `OptionSets/` |
| 24/60 | Form | `Entities/{name}/FormXml/` |
| 26 | View (Saved Query) | `Entities/{name}/SavedQueries/` |
| 29 | Workflow | `Workflows/` |
| 61 | Web Resource | `WebResources/` |
| 66 | PCF Control | `Controls/` |
| 80 | Model-Driven App | `AppModules/` |
| 91 | Plugin Assembly | `PluginAssemblies/` |
| 92 | Plugin Step | `SdkMessageProcessingSteps/` |
| 300 | Canvas App | `CanvasApps/` |

## Best Practice Violation Detection

### Critical: OOB Entity with All Assets (behavior="0")

When an out-of-box/system entity (like `systemuser`, `account`, `contact`) is added to the solution with `behavior="0"` (Include Subcomponents), this is flagged as a **CRITICAL** violation because:

- It causes **solution bloat** (adds all OOB forms, views, fields)
- Creates **unmanaged layers** on top of managed components
- **Blocks Microsoft updates** to managed components
- Creates **unnecessary dependencies**
- Can cause **import failures**

**Proper approach:** Use `behavior="1"` (Do Not Include Subcomponents) or `behavior="2"` (Shell Only) for OOB entities, and only add the specific components you've customized.

### Naming Convention Validation

The script validates naming conventions against HSO standards. For the complete naming reference (column suffixes, patterns, and examples), see the `hso-dataverse-naming-conventions` skill.

**Violations detected by severity:**

| Severity | Issue Type |
|----------|------------|
| HIGH | OOB entity with all assets |
| MEDIUM | Table name with uppercase characters |
| LOW | Field suffix not matching type, Global choice uppercase, Web resource naming |

## How the Script Works

1. **Solution.xml Analysis** - Reads root component behaviors to detect best practice violations
2. **Git Diff** - Compares source and target branches to identify changed files
3. **Component Parsing** - Extracts XML/JSON properties from each changed file:
   - Entity.xml for Tables
   - ControlManifest.xml for PCF Controls
   - OptionSets/*.xml for Global Option Sets
   - customapi.xml, SdkMessageProcessingSteps, FormXml, SavedQueries, etc.
4. **BEFORE/AFTER Comparison** - For modified forms, compares old vs new versions
5. **Report Generation** - Creates structured markdown with all component details
6. **Risk Assessment** - Automatically categorizes changes by risk level (Critical/High/Medium/Low)