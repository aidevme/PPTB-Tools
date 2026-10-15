---
name: hso-d365-guidance-reference
layer: atomic
scope: core
description: |
  Microsoft Dynamics 365 implementation guidance — Success by Design framework, business process guidance (manufacturing, finance, supply chain, sales, service), reference architectures (contact center, healthcare, field service, e-commerce, data platforms), implementation best practices (change management, data migration, ALM, security, BI), and FastTrack program guidance. Often consulted by `hso-dataverse-architect` for methodology and process validation. Does NOT cover SDK API signatures (`hso-dataverse-sdk-reference`), FastTrack code assets (`hso-fasttrack-reference`), or app-specific configuration (`hso-ce-apps-sdk-reference`).
---

# Dynamics 365 Implementation Guidance Reference

Expert on Microsoft Dynamics 365 implementation methodology — Success by Design framework, business process guidance, reference architectures, migration patterns, and organizational strategy.

> **Scope — vendor reference only.** This skill surfaces *what Microsoft says*; it does **not** carry HSO engagement methodology. HSO's SOP overlays are deliberately kept out so this stays a clean vendor window. For the synthesis of Microsoft guidance with HSO's engagement SOPs, use [`hso-dataverse-architect`](../hso-dataverse-architect/SKILL.md) — the orchestration skill that brings them together.

## CRITICAL: Search Local Repository First

**ALWAYS search the local dynamics365-guidance repository BEFORE using WebSearch or WebFetch.**

The complete Dynamics 365 Guidance repo is available locally at:
```
../dynamics365-guidance/
```

### Directory Structure

| Area | Local Path |
|------|------------|
| **Business Processes** | `../dynamics365-guidance/guidance/business-processes/` |
| **Implementation Guide** | `../dynamics365-guidance/guidance/implementation-guide/` |
| **Reference Architectures** | `../dynamics365-guidance/guidance/reference-architectures/` |
| **Resources & Tools** | `../dynamics365-guidance/guidance/resources/` |
| **TechTalks** | `../dynamics365-guidance/guidance/techtalks/` |
| **FastTrack Program** | `../dynamics365-guidance/guidance/fasttrack/` |
| **Development & Design** | `../dynamics365-guidance/guidance/develop/` |
| **Migration** | `../dynamics365-guidance/guidance/migrate/` |
| **Roles & Certifications** | `../dynamics365-guidance/guidance/roles/` |
| **Organizational Strategy** | `../dynamics365-guidance/guidance/organizational-strategy/` |
| **Agent Templates** | `../dynamics365-guidance/guidance/agent-templates/` |
| **Design Patterns** | `../dynamics365-guidance/guidance/patterns/` |
| **Implementation Portal** | `../dynamics365-guidance/guidance/implementation-portal/` |

### Search Workflow

1. Use **Glob** to find relevant files by topic name or file type
2. Use **Grep** to search for specific patterns, terms, or keywords
3. Use **Read** to load the content (markdown files, YAML configs)
4. Only fall back to online sources if the local repo is not cloned

## Fallback: Online Repository

If the local `../dynamics365-guidance/` directory is **not available**, search these sources in order:

1. **GitHub repo (raw source):** https://github.com/MicrosoftDocs/dynamics365-guidance — browse or search the markdown/code files via WebFetch on raw URLs (e.g., `https://raw.githubusercontent.com/MicrosoftDocs/dynamics365-guidance/main/guidance/...`)
2. **GitHub API search:** Use WebFetch with `https://api.github.com/search/code?q=<keyword>+repo:MicrosoftDocs/dynamics365-guidance` to find specific files or patterns
3. **Published docs:** https://learn.microsoft.com/en-us/dynamics365/guidance/ — use WebSearch or WebFetch for rendered documentation

The GitHub repo is the source that publishes to the Learn site. Prefer it for raw content since the markdown is more tool-friendly than rendered HTML.

## Search Examples

### Find implementation guide content by stage
```
Glob: pattern="**/*.md" path="../dynamics365-guidance/guidance/implementation-guide"
Grep: pattern="Success by Design" path="../dynamics365-guidance/guidance/implementation-guide"
```

### Find business process guidance
```
Glob: pattern="**/*.md" path="../dynamics365-guidance/guidance/business-processes"
Grep: pattern="manufacturing\|supply chain\|order-to-cash" path="../dynamics365-guidance/guidance/business-processes"
```

### Find reference architectures
```
Glob: pattern="**/*.md" path="../dynamics365-guidance/guidance/reference-architectures"
Grep: pattern="contact center\|field service\|healthcare" path="../dynamics365-guidance/guidance/reference-architectures"
```

### Find data migration guidance
```
Grep: pattern="data migration\|data management\|cutover" path="../dynamics365-guidance/guidance/implementation-guide"
Grep: pattern="migration\|AIM\|assessment" path="../dynamics365-guidance/guidance/migrate"
```

### Find ALM and deployment guidance
```
Grep: pattern="ALM\|application lifecycle\|DevOps\|deployment" path="../dynamics365-guidance/guidance/implementation-guide"
```

### Find security and compliance guidance
```
Grep: pattern="security\|compliance\|GDPR\|access control" path="../dynamics365-guidance/guidance/implementation-guide"
```

### Find change management guidance
```
Grep: pattern="change management\|adoption\|training" path="../dynamics365-guidance/guidance/implementation-guide"
```

### Find testing guidance
```
Grep: pattern="testing\|test strategy\|UAT\|performance test" path="../dynamics365-guidance/guidance/implementation-guide"
```

### Find FastTrack program info
```
Glob: pattern="**/*.md" path="../dynamics365-guidance/guidance/fasttrack"
```

### Find TechTalk content
```
Glob: pattern="**/*.md" path="../dynamics365-guidance/guidance/techtalks"
Grep: pattern="Dataverse\|Copilot\|integration" path="../dynamics365-guidance/guidance/techtalks"
```

### Find UI/UX and development guidance
```
Glob: pattern="**/*.md" path="../dynamics365-guidance/guidance/develop"
Grep: pattern="model-driven\|canvas\|UI\|UX\|design" path="../dynamics365-guidance/guidance/develop"
```

## Expertise Areas

### Success by Design Implementation Framework
- **Strategize** — Vision, goals, organizational readiness
- **Initiate** — Project planning, team setup, environment strategy
- **Implement** — Build, configure, customize, integrate
- **Prepare** — Testing, training, cutover planning, go-live readiness
- **Operate** — Support, monitoring, continuous improvement, expansion

### Business Process Guidance
- Manufacturing processes and KPI frameworks
- Finance & Operations end-to-end scenarios
- Supply chain management patterns
- Sales and customer engagement processes
- Customer service and field service workflows
- Solution plays and DevOps configurations

### Reference Architectures
- Contact center solutions (multi-agent, deployment, functional testing)
- Manufacturing (Azure-powered, product-centric journeys)
- Healthcare (FHIR integration, writeback patterns)
- Field Service (geo-scheduler, SAP integration, utilities)
- Finance & Supply Chain (hybrid connects, year-end closing)
- Travel & Hospitality solutions
- E-commerce (composable commerce, B2B)
- Data platforms (Dataverse master data, Synapse Link, data warehousing)

### Implementation Best Practices
- Change management and organizational adoption
- Data management, migration, and cutover strategies
- Application Lifecycle Management (ALM) and DevOps
- Security, compliance, and governance
- Business intelligence, reporting, and analytics
- Performance optimization and testing strategies
- Integration architecture and patterns
- Environment strategy and tenant planning

### FastTrack Program
- Eligibility and FAQ
- Implementation and go-live workshops
- Solution workshops and assessments
- Self-service engagement guidance
- Learning resources

### Migration
- Assessment & Implementation Methodology (AIM)
- On-premises to online migration
- Customer success stories and solution insights

### Development & Design
- UI/UX design principles for model-driven apps
- Canvas app component patterns
- Component testing guidance

### Organizational Strategy
- Role-specific guidance (functional consultant, solution architect)
- Certifications and career paths
- Community engagement

## Answer Format

For implementation guidance:
1. Relevant guidance topic and file location
2. Key recommendations and best practices
3. Stage in the Success by Design framework (if applicable)
4. Related reference architectures or business process docs
5. File path reference to local docs or Learn URL

For reference architectures:
1. Architecture name and scope
2. Key components and design decisions
3. Integration points and dependencies
4. Implementation considerations
5. Related implementation guide sections

For business process guidance:
1. Process area and scenario
2. End-to-end flow description
3. KPIs and success metrics (if available)
4. Technology recommendations
5. Related reference architectures

## Integration with hso-dataverse-architect

When the `hso-dataverse-architect` skill is designing solutions, this skill provides:
- **Implementation methodology** — Success by Design stage-appropriate guidance
- **Business process alignment** — Validate designs against standard D365 business processes
- **Reference architectures** — Find similar solution patterns and proven architectures
- **Change management** — Adoption and training considerations for proposed designs
- **Data strategy** — Migration patterns, data management best practices
- **Go-live readiness** — Testing strategy, cutover planning, operational support

## Out of Scope

- Dataverse SDK API signatures and method details — Use `hso-dataverse-sdk-reference`
- FastTrack Implementation Assets (code samples, pipelines, dashboards) — Use `hso-fasttrack-reference`
- Application-specific configuration (Field Service, Customer Service routing) — Use `hso-ce-apps-sdk-reference`
- Plugin development patterns — Use `hso-plugin-development` skill
- PCF control development workflow — Use `hso-pcf-control-development` skill

---

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-11 | maciejnowicki | Ported from prior in-house reference skills and neutralised for the reusable template (dropped internal license header, stripped stray project tags). |
