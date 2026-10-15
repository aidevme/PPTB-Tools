---
name: hso-fasttrack-reference
layer: atomic
scope: core
description: |
  Microsoft Dynamics 365 FastTrack Implementation Assets reference for architecture guidance, best practices, and production-ready code samples. Use when:
  (1) Designing Dataverse/D365 solutions and need FastTrack architecture patterns
  (2) Looking for Microsoft-recommended implementation approaches (ALM, monitoring, integration, data migration)
  (3) Need reference PCF controls, pipeline templates, or monitoring dashboards from FastTrack
  (4) Evaluating performance optimization, security, or telemetry patterns
  (5) The hso-dataverse-architect skill needs FastTrack best-practice validation
  Does NOT cover SDK API signatures (use hso-dataverse-sdk-reference) or app-specific configuration (use hso-ce-apps-sdk-reference).
---

# FastTrack Implementation Assets Reference

Expert on Microsoft Dynamics 365 FastTrack Implementation Assets — architecture patterns, best practices, code samples, ALM pipelines, monitoring dashboards, and integration guidance.

> **Scope — vendor reference only.** This skill surfaces Microsoft FastTrack implementation *assets* (templates, dashboards, samples); it does **not** carry HSO engagement methodology. HSO's SOP overlays are deliberately kept out so this stays a clean vendor window. For the synthesis of FastTrack assets with HSO's engagement SOPs, use [`hso-dataverse-architect`](../hso-dataverse-architect/SKILL.md) — the orchestration skill that brings them together.

## CRITICAL: Search Local Repository First

**ALWAYS search the local FastTrack repository BEFORE using WebSearch or WebFetch.**

The complete FastTrack Implementation Assets repo is available locally at:
```
../Dynamics-365-FastTrack-Implementation-Assets/
```

### Directory Structure

| Area | Local Path |
|------|------------|
| **Customer Service** | `../Dynamics-365-FastTrack-Implementation-Assets/Customer Service/` |
| **Field Service** | `../Dynamics-365-FastTrack-Implementation-Assets/Field Service/` |
| **Integration** | `../Dynamics-365-FastTrack-Implementation-Assets/Integration/` |
| **Data Migration (PO)** | `../Dynamics-365-FastTrack-Implementation-Assets/PO-DataMigration/` |
| **Monitoring & Telemetry** | `../Dynamics-365-FastTrack-Implementation-Assets/MonitoringAndTelemetry/` |
| **Analytics & Data Lake** | `../Dynamics-365-FastTrack-Implementation-Assets/Analytics/` |
| **Performance** | `../Dynamics-365-FastTrack-Implementation-Assets/Performance/` |
| **Cloud Security** | `../Dynamics-365-FastTrack-Implementation-Assets/CloudSecurity/` |
| **Dual-write** | `../Dynamics-365-FastTrack-Implementation-Assets/Dual-write/` |
| **Copilots & AI** | `../Dynamics-365-FastTrack-Implementation-Assets/Copilots/` |
| **AI ERP Agents** | `../Dynamics-365-FastTrack-Implementation-Assets/AI ERP Agents/` |
| **Finance** | `../Dynamics-365-FastTrack-Implementation-Assets/Finance/` |
| **Commerce** | `../Dynamics-365-FastTrack-Implementation-Assets/Commerce/` |
| **SCM (Supply Chain)** | `../Dynamics-365-FastTrack-Implementation-Assets/SCM/` |
| **Storage Management** | `../Dynamics-365-FastTrack-Implementation-Assets/Storage Management/` |
| **Batch Tracing** | `../Dynamics-365-FastTrack-Implementation-Assets/BatchTracing/` |
| **Schedule API** | `../Dynamics-365-FastTrack-Implementation-Assets/ScheduleAPI/` |
| **US Government** | `../Dynamics-365-FastTrack-Implementation-Assets/US government/` |

### Search Workflow

1. Use **Glob** to find relevant files by topic name or file type
2. Use **Grep** to search for specific patterns, APIs, or keywords
3. Use **Read** to load the content (README.md files, code samples, configs)
4. Only fall back to online sources if the local repo is not cloned

## Fallback: Online Repository

If the local `../Dynamics-365-FastTrack-Implementation-Assets/` directory is **not available**, search these sources in order:

1. **GitHub repo (raw source):** https://github.com/microsoft/Dynamics-365-FastTrack-Implementation-Assets — browse or search the markdown/code files via `gh` CLI or WebFetch
2. **GitHub API search:** Use `gh api search/code` to find specific files or patterns in the repository

## Search Examples

### Find ALM pipeline templates
```
Glob: pattern="**/ALM/**/*.yml" path="../Dynamics-365-FastTrack-Implementation-Assets"
Glob: pattern="**/ALM/**/*.yaml" path="../Dynamics-365-FastTrack-Implementation-Assets"
Grep: pattern="pipeline" glob="*.yml" path="../Dynamics-365-FastTrack-Implementation-Assets/Field Service/ALM"
```

### Find monitoring dashboards and KQL queries
```
Glob: pattern="**/*.json" path="../Dynamics-365-FastTrack-Implementation-Assets/MonitoringAndTelemetry"
Glob: pattern="**/*.kql" path="../Dynamics-365-FastTrack-Implementation-Assets/MonitoringAndTelemetry"
Grep: pattern="kusto\|KQL\|query" path="../Dynamics-365-FastTrack-Implementation-Assets/MonitoringAndTelemetry"
```

### Find PCF control source code
```
Glob: pattern="**/ControlManifest.Input.xml" path="../Dynamics-365-FastTrack-Implementation-Assets"
Glob: pattern="**/*.tsx" path="../Dynamics-365-FastTrack-Implementation-Assets/Field Service/Component Library"
```

### Find integration patterns
```
Glob: pattern="**/*.md" path="../Dynamics-365-FastTrack-Implementation-Assets/Integration"
Grep: pattern="OData\|WebAPI\|endpoint" path="../Dynamics-365-FastTrack-Implementation-Assets/Integration"
```

### Find data migration guidance
```
Glob: pattern="**/*.md" path="../Dynamics-365-FastTrack-Implementation-Assets/PO-DataMigration"
Glob: pattern="**/*.json" path="../Dynamics-365-FastTrack-Implementation-Assets/PO-DataMigration"
Grep: pattern="Azure Data Factory\|ADF\|pipeline" path="../Dynamics-365-FastTrack-Implementation-Assets/PO-DataMigration"
```

### Find security guidance
```
Glob: pattern="**/*.md" path="../Dynamics-365-FastTrack-Implementation-Assets/CloudSecurity"
Grep: pattern="conditional access\|MFA\|security" path="../Dynamics-365-FastTrack-Implementation-Assets/CloudSecurity"
```

### Find performance testing assets
```
Glob: pattern="**/*.jmx" path="../Dynamics-365-FastTrack-Implementation-Assets/Performance"
Glob: pattern="**/*.md" path="../Dynamics-365-FastTrack-Implementation-Assets/Performance"
```

### Find solution component validator
```
Glob: pattern="**/*.md" path="../Dynamics-365-FastTrack-Implementation-Assets/Customer Service/ALM"
Grep: pattern="component validator\|solution component" path="../Dynamics-365-FastTrack-Implementation-Assets/Customer Service"
```

## Expertise Areas

### ALM & DevOps
- Azure DevOps pipeline templates for solution export/import
- Cross-environment deployment automation
- Solution component validation and layering
- Multi-solution architecture enforcement

### Monitoring & Telemetry
- The FastTrack `MonitoringAndTelemetry/` workbook family — `dashboard-PageViewAndPlugin.json`, `dashboard-DataverseWebRequests.json`, `dashboard-Dataverse Throttling Dashboard.json`, `dashboard-Power Automate Monitoring.json` — FastTrack's recommended day-1 PROD monitoring baseline.
- Dataverse form load and plugin performance dashboards (Application Insights)
- Query throttling dashboards (Azure Data Explorer / Log Analytics)
- KQL/Kusto queries for performance analysis
- Dual-write and Power Automate monitoring
- Web request telemetry

### Customer Engagement
- Solution Component Validator for ALM governance
- Channel Integration Framework v2.0 adapters and samples
- Click-to-Dial PCF control patterns
- AI case deflection and omnichannel patterns

### Field Service
- Schedule Board Settings Management PCF Controls (standard + virtual)
- Vendor Self-Service Solution patterns
- Service Report PCF Control (offline-capable, PDF export, signatures)
- Field Service Copilot extensibility
- Test automation frameworks for Field Service

### Integration
- OData console app patterns (.NET)
- Message processor framework for F&O
- Field Service to F&O integration extensibility
- Dual-write bootstrapping and orchestration

### Data Migration
- Azure Data Factory pipeline templates
- Project Operations data migration patterns
- AX 2012 to D365 upgrade tools

### Analytics & Data Lake
- CDMUtil for Common Data Model to Synapse conversion
- Synapse to SQL incremental pipelines
- Entity Store transformation patterns
- End-to-end analytical pipeline architectures
- Synapse Link / Fabric Link assets under `Analytics/DataverseLink/` — DVFabricLinkUtil notebook (Lakehouse→Warehouse DDL automation), MonitorSchemaDrift notebook (OneLake schema-drift detection), FabricLinkDataStaleness + Summarization notebooks (P95 latency measurement), `Staleness analysis pipeline.zip` (ADF orchestration), EDL→Synapse Link transition scripts and `D365 Synapse link & Fabric link migration template.xlsx`, pipeline templates `CopySynapseTable.zip` / `FullExport_SQL.zip` / `IncrementalExport_SQL.zip`, and CDMPathFinder (WPF/Function utility for analyzing CDM manifest files in the lake).

### Performance
- JMeter load testing configurations
- Warehouse app task validation samples
- SQL maintenance and optimization scripts

### Security
- Azure AD conditional access policies for D365
- IP whitelisting, MFA, device compliance patterns
- Sign-in risk controls

### Copilots & AI
- Finance Copilot low-code plugin samples
- AI ERP Agent implementations (Sales Order, User Onboarding)
- Copilot extensibility patterns

## Answer Format

For architecture guidance:
1. Relevant FastTrack asset name and location
2. What the asset provides (description)
3. Key patterns and best practices from the asset
4. Code/config samples when available
5. File path reference to local docs or GitHub URL

For implementation patterns:
1. Prerequisites and dependencies
2. Architecture overview from FastTrack guidance
3. Step-by-step implementation approach
4. Configuration samples or code snippets
5. Testing and validation recommendations

## Integration with hso-dataverse-architect

When the `hso-dataverse-architect` skill is designing solutions, this skill provides:
- **Architecture validation** — Check proposed designs against FastTrack patterns
- **Reference implementations** — Find similar implementations in FastTrack assets
- **ALM guidance** — Pipeline templates and solution management patterns
- **Performance baselines** — Monitoring dashboards and testing approaches
- **Security patterns** — Conditional access and governance guidance

## Out of Scope

- Dataverse SDK API signatures and method details — Use `hso-dataverse-sdk-reference`
- Application-specific configuration (Field Service settings, Customer Service routing) — Use `hso-ce-apps-sdk-reference`
- Deep Field Service implementation details — Use `hso-fieldservice-reference`
- Plugin development patterns — Use `hso-plugin-development` skill
- PCF control development workflow — Use `hso-pcf-control-development` skill

---

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-11 | maciejnowicki | Ported from prior in-house reference skills and neutralised for the reusable template (dropped internal license header, stripped stray project tags). |
