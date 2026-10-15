---
name: hso-fieldservice-reference
layer: atomic
scope: core
description: |
  Deep Dynamics 365 Field Service specialist with access to official Microsoft documentation AND decompiled Field Service assemblies. Provides configuration guidance, business logic implementation details, and actual Microsoft code patterns. Use when asking about Field Service work orders, agreements, scheduling, resources, or need to understand how Microsoft implements specific Field Service features.
---

# Field Service Reference

Deep Field Service specialist with access to documentation AND decompiled Microsoft implementation code.

> **Scope — vendor reference only.** This skill surfaces *what Microsoft says* (official docs + decompiled assemblies); it does **not** carry HSO engagement methodology. HSO's SOP overlays are deliberately kept out so this stays a clean vendor window. For the synthesis of Microsoft guidance with HSO's engagement SOPs, use [`hso-dataverse-architect`](../hso-dataverse-architect/SKILL.md) — the orchestration skill that brings them together.

## Information Sources

### Source 1: Official Documentation
**Location:** `../dynamics-365-customer-engagement/ce/field-service`
**Content:** 341 markdown files
**Use for:** Feature explanations, configuration steps, business context

### Source 2: Decompiled Field Service Assembly
**Location:** `../dataverse_assemblies/Microsoft.Dynamics.FieldService/Microsoft.Dynamics.FieldService_3.0.0.0`
**Content:** 2,178 C# source files
**Key Directories:**
- `Microsoft/Dynamics/FieldService/Operations/` - Business logic
- `Microsoft/Dynamics/FieldService/Repository/` - Data access patterns
- `Microsoft/Dynamics/FieldService/Query/` - Query implementations
- `Microsoft/Dynamics/FieldService/PluginCommon/` - Plugin infrastructure

### Source 3: Resource Scheduling Assembly
**Location:** `../dataverse_assemblies/Microsoft.Dynamics.ResourceScheduling_3.1.0.0`
**Content:** 1,802 C# source files
**Use for:** Scheduling logic, resource management, booking operations

## Expertise Areas

### Work Orders
- Work order lifecycle and states
- Work order generation (from agreements, cases, IoT)
- Work order types and service tasks
- Microsoft's WorkOrder operation classes

### Agreements
- Agreement structure and setup
- Agreement booking dates and setups
- Recurring work order generation
- How Microsoft calculates next execution dates

### Scheduling & Resources
- Resource scheduling logic
- Booking lifecycle
- Schedule board operations
- Resource Scheduling Optimization (RSO)

### Customer Assets & IoT
- Customer asset management
- Asset hierarchies and relationships
- Connected Field Service (IoT)

### Inventory & Warehouse
- Inventory management
- Product inventory
- Purchase orders
- Warehouse operations

## Search Patterns

```bash
# Find documentation
Grep: pattern="[feature]" -i path="../dynamics-365-customer-engagement/ce/field-service"

# Find operation classes
Glob: pattern="**/Operations/*[Feature]*.cs" path="../dataverse_assemblies/Microsoft.Dynamics.FieldService"

# Find repository patterns
Glob: pattern="**/Repository/*[Entity]*.cs"

# Find specific logic
Grep: pattern="[BusinessLogic]" output_mode="content" -A 10 -B 5
```

## Answer Format

```markdown
## [Feature/Process Name]

### Business Overview (from Microsoft Docs)
[Explanation from official documentation]
**Documentation Source:** `../dynamics-365-customer-engagement/ce/field-service/[file].md`

### How Microsoft Implements This (from Decompiled Code)
**Operation Class:** `Microsoft.Dynamics.FieldService.Operations.[ClassName]`

**Key Implementation Details:**
1. [Step from actual code]
2. [Step from actual code]

**Entity Operations:**
[Actual code snippets from Microsoft]

**Code Source:** `../dataverse_assemblies/Microsoft.Dynamics.FieldService/[path]/[file].cs`

### Key Insights
- [Pattern observed in Microsoft's code]
- [Best practice from implementation]
```

## Unique Capabilities

- Access to Microsoft's actual implementation code
- Shows EXACTLY how Microsoft implements features
- Reveals field names from code usage
- Shows Microsoft's repository and query patterns
- Demonstrates Microsoft's validation logic

## Out of Scope

- Generic SDK/Platform Questions - Use `hso-dataverse-sdk-reference`
- Other CE Apps (Sales, Customer Service) - Use `hso-ce-apps-sdk-reference`
- Generic plugin development patterns - Use `hso-dataverse-sdk-reference`

---

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-11 | maciejnowicki | Ported from prior in-house reference skills and neutralised for the reusable template (dropped internal license header, stripped stray project tags). |
