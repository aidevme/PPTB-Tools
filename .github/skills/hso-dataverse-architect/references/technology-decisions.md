# Technology Decision Framework

Read this file when choosing between implementation approaches (PCF vs web resources, plugins vs Custom APIs, etc.) or when evaluating whether custom development is needed at all.

## Table of Contents
- [UI Implementation](#ui-implementation)
- [Backend Logic](#backend-logic)

---

## UI Implementation

### Virtual Controls (ReactControl) Strongly Preferred
- All new PCF controls should be Virtual Controls
- Standard Controls (`control-type="standard"`) are strongly discouraged; document justification if used

| Requirement | Value |
|------------|-------|
| Control Type | `virtual` (required; exception needs documented justification) |
| React | 16.14.0 (via platform-library) |
| Fluent UI | 9.46.2 (via platform-library) |
| Interface | `ReactControl<IInputs, IOutputs>` |
| Form Controls | Should have `usage="bound"` property |

### PCF Quality Standards
- Use Fluent UI tokens for theming (never hardcoded colors)
- Implement loading, error, and empty states
- Solution Checker compliance required
- Keyboard navigation and ARIA attributes for accessibility

### When to Choose PCF Controls
Complex data visualization, reusable components, modern React-based UI, offline capability, or cross-app compatibility needed.

### When to Choose Web Resources
Simple form scripting, quick implementation, legacy system integration, HTML dashboards, or ribbon customizations needed.

### Form Script Requirements
- Use formContext; avoid Xrm.Page (deprecated)
- Avoid direct DOM manipulation (no document.getElementById, querySelector, jQuery)
- Avoid internal/undocumented APIs (no Xrm.Internal, Mscrm.*)
- Use namespace pattern (`HSO.EntityName`)
- Always pass execution context for event handlers

### Form Header Constraints
- Form headers support **maximum 4 fields** - do not design headers with more than four fields

---

## Backend Logic

### When to Choose Plugins
Synchronous execution, complex multi-entity operations, performance-critical operations, data validation blocking save, impersonation, or guaranteed execution order required.

**Plugin Architecture (required pattern):**
- Layered Architecture: Plugins → BusinessLogic → Data → Tables
- Plugin is Composition Root (assembles dependencies)
- Business Logic is platform-agnostic (receives interfaces only)
- Constructor injection for all dependencies

### When to Choose Power Automate (Cloud Flows)
Event-driven automation, multi-step data workflows, asynchronous processing, citizen-developer maintainability, or when the logic is primarily Dataverse CRUD orchestration that doesn't require sub-second execution.

**Power Automate Strengths:**
- Low-code visual editor for citizen developers to maintain
- Built-in retry, error handling, and run history
- Ideal for: record cascading, notifications, scheduled data jobs, approval workflows
- Easy to modify without deployments (for non-solution-aware flows)

**Power Automate Limitations:**
- Not synchronous — cannot block a save operation (use plugins for pre-validation)
- Limited to ~6,000 API calls per connection per 5 minutes (throttling)
- No guaranteed execution order when multiple flows trigger on the same event
- Harder to unit test than plugins
- Flow runs have a 30-day retention limit for run history (extended in FlowRun Dataverse table for solution-aware flows)
- Action burst limit: 100,000 actions per 5-minute window
- Concurrency control on triggers is irreversible once applied

**When to Choose Plugins Instead:**
- Synchronous validation that must block save
- Performance-critical operations (sub-second response required)
- Complex multi-entity transactions with rollback
- Operations requiring impersonation or execution order control

**When to Choose Azure Logic Apps Instead:**
- Enterprise middleware with advanced monitoring (Application Insights, Log Analytics)
- High-volume integration scenarios exceeding Power Automate API limits
- Azure-centric architecture requiring Service Bus, Event Grid, or API Management
- Scenarios requiring ARM template / Bicep deployment (not Dataverse solution-aware)

**Power Automate Design Standards:** Consult [`shared/dv/agent/wiki/sop/power-automate/power-automate-cloud-flow-best-practices.md`](../../../../shared/dv/agent/wiki/sop/power-automate/power-automate-cloud-flow-best-practices.md) for:
- Single responsibility principle (one flow = one purpose)
- Trigger optimization (filtering attributes, filter expressions, trigger conditions)
- Error handling patterns (scope-based try-catch-finally)
- Performance optimization (data operations over loops, bulk operations, parallel branches)
- Anti-patterns to avoid (infinite loops, nested conditions, sync validation misuse)

**Power Automate ALM & Governance:** Consult [`shared/dv/agent/wiki/sop/power-automate/power-automate-alm-and-governance.md`](../../../../shared/dv/agent/wiki/sop/power-automate/power-automate-alm-and-governance.md) for:
- Solution-aware flow requirements (connection references, environment variables)
- Flow ownership standards (service accounts for non-dev environments)
- Monitoring strategy (FastTrack dashboard, Application Insights)
- Governance review checklist

**Power Automate Naming Convention:** See [`shared/dv/agent/wiki/sop/dataverse-naming-conventions.md`](../../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) — Power Automate Flow Naming section.
Pattern: `Table Name | Trigger | Brief Description` (automated), `Manual | Description` (instant), `Schedule | Frequency | Description` (scheduled)

**Implementation Skill:** `hso-powerautomate-writer`
**Spec Reference:** [`shared/dv/agent/wiki/references/powerautomate-flow-spec-template.md`](../../../../shared/dv/agent/wiki/references/powerautomate-flow-spec-template.md)

### When to Choose Custom APIs
Encapsulating complex operations as reusable services, exposing functionality externally, creating transaction boundaries, or building composable services.

**Custom API Deployment Order:**
1. Deploy plugin assembly FIRST (use `deploy-plugin` skill)
2. Register Custom API metadata (use `create-custom-api` skill)
3. Verify `plugintypeid` is linked
