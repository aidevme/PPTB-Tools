# Solution Blueprint Presentation — Slide Structure

Complete slide-by-slide guide for generating a Solution Blueprint presentation.

## Table of Contents

1. [Opening Slides](#opening-slides)
2. [Program Strategy](#program-strategy)
3. [Application Strategy](#application-strategy)
4. [Business Process Strategy](#business-process-strategy)
5. [Data Strategy](#data-strategy)
6. [Integration Strategy](#integration-strategy)
7. [Reporting & Intelligence Strategy](#reporting--intelligence-strategy)
8. [Security Strategy](#security-strategy)
9. [Test Strategy](#test-strategy)
10. [Environment & Capacity Strategy](#environment--capacity-strategy)
11. [ALM Strategy](#alm-strategy)
12. [Closing Slides](#closing-slides)

---

## Section Pattern

Every strategy section follows this pattern:
1. **Section Divider slide** — navy background, section name only, no body text
2. **1–3 Content slides** — white background, slide title + content

Skip entire sections (divider + content) that are out of scope.

---

## Opening Slides

### Slide 1 — Cover
- Layout: Full-bleed navy background
- Title: Engagement/project name (large, centered)
- Subtitle: Phase name (e.g., "Phase 1 – Design Review")
- Date: Presentation month and year
- Presenter: Author name from CLAUDE.local.md
- HSO logo or wordmark (if template has it)

### Slide 2 — Agenda
- Layout: Content slide
- Title: "Solution Blueprint"
- Content: Bulleted list of all included sections (one bullet per section)
- Sub-bullets: key topics within each section
- Also include: Attendees, meeting purpose, requirements note

### Slide 3 — Solution Review Objectives
- Layout: Content slide
- Title: "Solution Review Objectives"
- Content: 3–5 bullet points describing the purpose of the review:
  - Understand program design
  - Validate solution architecture
  - Identify risks and gaps
  - Align on next steps
- Source: `agent/README.md` or manual

### Slide 4 — Executive Summary
- Layout: Content slide
- Title: "Executive Summary"
- **Option A — Table format** (use when key decisions and risks are known):
  - Three-column table: **Key Decisions** · **Key Highlights** · **Open Risks**
  - 3–5 rows per column; each cell is a brief statement
  - Source: `agent/work/analysis/`, `agent/wiki/digests/`, ADO
- **Option B — Vision + statistics** (use when strategic framing is the priority):
  - Left: "Future State Vision" — 2–3 bullet points on strategic goals
  - Right: Statistics callout boxes — feature count (from ADO), design workshop count, blueprint focus area
  - Source: ADO feature count + `agent/wiki/system/` + manual/placeholder
- Default to Option A if decision/risk content is available; Option B if not
- Placeholder: `[PLACEHOLDER: Executive Summary — Key Decisions / Highlights / Risks]`

---

## Program Strategy

### Section Divider — "Program Strategy"
Navy background, title only.

### Goals and Objectives
- Layout: Content slide
- Title: "Goals and Objectives"
- Content: 4–6 bullet points — strategic business objectives for this project
- Source: `agent/wiki/digests/` or `agent/work/analysis/` or placeholder

### Business Challenges
- Layout: Content slide
- Title: "Business Challenges"
- Content: 3–5 bullets — key pain points driving this initiative
- Source: Discovery artifacts or placeholder

### Guiding Principles
- Layout: Content slide
- Title: "Guiding Principles"
- Content: 4–6 bullets — principles guiding solution design decisions
- Source: `agent/wiki/system/` or placeholder

### Project Details / Project Team
- Layout: Content slide or two-column slide
- Title: "Project Team" or "Project Details"
- Content: Team structure table or bullet list with roles:
  - HSO Solution Architect
  - HSO Functional Lead(s)
  - HSO Technical Lead
  - Client Project Manager
  - Client Business Lead(s)
- Source: `CLAUDE.local.md` author + placeholder for others

### Program Timeline
- Layout: Content slide
- Title: "Program Timeline"
- Content: Phase timeline — phase names and date ranges
- Source: `agent/wiki/system/` or placeholder
- Note: Use a simple table if Gantt-style timeline is too complex for PPTX

---

## Application Strategy

### Section Divider — "Application Strategy"
Navy background, title only.

### Guiding Principles
- Layout: Content slide
- Title: "Application Guiding Principles"
- Content: Principles specific to the application architecture
- Source: `agent/wiki/system/` SOPs or placeholder

### Solution Architecture Overview
- Layout: Content slide
- Title: "Solution Architecture"
- Content: Describe the architectural layers/components:
  - D365 modules in scope
  - Platform components (Power Platform, Azure)
  - ISV solutions / add-ons
  - Integration points
- Source: `agent/wiki/system/` or `agent/work/specs/`

### Solution Enhancements / Customizations
- Layout: Content slide
- Title: "Solution Enhancements"
- Content: Table or bullets listing custom components:
  - PCF Controls
  - Plugins / Custom APIs
  - Power Automate Flows
  - Web Resources
- Source: `agent/wiki/system/` component list or ADO features

### D365 Capabilities
- Layout: Content slide
- Title: "Application Strategy — [Module Name] Capabilities"
- Content: Capabilities planned for each D365 module in scope
  - One slide per module if multiple modules
- Source: ADO features + `agent/work/specs/`

---

## Business Process Strategy

### Section Divider — "Business Process Strategy"

### Business Process Catalog
- Layout: Content slide (use table if many processes)
- Title: "Business Process Catalog"
- Content: Numbered process list with process codes and names
  - Example: `100 – Account Creation & Update`
- Source: `agent/work/specs/` feature list + ADO work items

---

## Data Strategy

### Section Divider — "Data Strategy"

### Data Strategy Overview
- Layout: Content slide
- Title: "Data Strategy"
- Content: Approach sub-sections:
  - Configuration Management approach
  - Data standards and conventions
- Source: `agent/wiki/system/` or SOP references

### Data Migration Approach
- Layout: Content slide
- Title: "Data Migration Approach"
- Content: Migration strategy bullets:
  - Source systems
  - Migration tooling
  - Go-live cutover approach
  - Data volume estimates
- Source: `agent/raw/discovery/` or placeholder

### Data Model Customizations
- Layout: Content slide
- Title: "Data Model Customizations"
- Content: Custom entities/tables added to the solution
- Source: `agent/wiki/system/` schema docs or Dataverse metadata

### Data Reconciliation
- Layout: Content slide (optional — include if migration is in scope)
- Title: "Data Reconciliation"
- Content: Reconciliation approach, validation steps

---

## Integration Strategy

### Section Divider — "Integration Strategy"

### Integration Approach
- Layout: Content slide
- Title: "Integration Strategy & Approach"
- Content: Integration principles (5 numbered points):
  1. Follow Microsoft integration best practices
  2. Application-specific approach (volume, timing, performance)
  3. Align with IT infrastructure and security policies
  4. Utilize pre-built connectors where available
  5. Leverage existing integration plans
- Source: `agent/wiki/system/` or standard HSO approach

### Integrations Table
- Layout: Content slide with table
- Title: "Integrations Approach"
- Content: Table columns: Integration Name · Direction · Mechanism · Frequency · Notes
- Source: `agent/work/specs/` integration specs or placeholder table

### Integration Security
- Layout: Content slide
- Title: "Integration Security"
- Content: Service account strategy, non-interactive identity approach
- Source: `agent/wiki/system/` or standard approach

---

## Reporting & Intelligence Strategy

### Section Divider — "Reporting & Intelligence Strategy"

### Reporting Approach
- Layout: Content slide
- Title: "Reporting & Intelligence Strategy"
- Content:
  - Primary reporting tools (OOB D365 dashboards/views, Power BI)
  - User self-service approach
  - Future phase considerations
- Source: `agent/work/specs/` or placeholder

### Reporting Solutions
- Layout: Two-column content slide (optional)
- Title: "Reporting Solutions"
- Content: Comparison of reporting options with fit/scope

---

## Security Strategy

### Section Divider — "Security Strategy"

### Security Methodology
- Layout: Content slide
- Title: "Security Strategy Methodology"
- Content: Role-based security approach, principles
- Source: `agent/work/specs/` security role specs or standard HSO security approach

### Security Best Practices
- Layout: Two-column content slide
- Title: "Security Best Practices"
- Content: Left column: D365 CE security practices. Right column: Platform/Azure AD practices

### Role Matrix
- Layout: Content slide with table (optional)
- Title: "Security — Role Matrix"
- Content: Table: Role Name · Business Unit · Access Level · In-Scope Modules
- Source: `agent/work/specs/` or placeholder

---

## Test Strategy

### Section Divider — "Test Strategy"

### Test Plan Overview
- Layout: Content slide
- Title: "Test Strategy"
- Content: Test phases in scope:
  - Unit Testing
  - Regression Testing
  - Functional / Integration Testing
  - User Acceptance Testing (UAT)
- Source: `agent/work/specs/` test plan or standard approach

### Test Plan RACI
- Layout: Content slide with table
- Title: "Test Plan"
- Content: Table: Test Phase · Who Executes · Who Reviews · Who Signs Off
- Source: `agent/work/specs/` or placeholder

### Bug Severity Levels
- Layout: Content slide with table
- Title: "Software Bug Severity Levels"
- Content: Table: Severity · Definition · SLA · Example
  - Critical, High, Medium, Low
- Source: Standard HSO levels or project SLA doc

### UAT Plan
- Layout: Content slide
- Title: "User Acceptance Testing Plan"
- Content: UAT scope, timeline, sign-off criteria
- Source: `agent/work/specs/` or placeholder

---

## Environment & Capacity Strategy

### Section Divider — "Environment & Capacity Strategy"

### Environment Strategy
- Layout: Content slide
- Title: "Environment Strategy"
- Content:
  - Tenant and geo strategy
  - Environment list (Dev, Test, UAT, Production)
  - Monitoring approach
  - Platform release management
- Source: `agent/wiki/system/` or placeholder

### Capacity Strategy
- Layout: Content slide
- Title: "Capacity Strategy"
- Content:
  - Licensing summary
  - Storage estimates
  - API call volume expectations
- Source: `agent/wiki/system/` or placeholder

---

## ALM Strategy

### Section Divider — "ALM Strategy"

### ALM Overview
- Layout: Content slide
- Title: "Application Lifecycle Management (ALM)"
- Content:
  - What is ALM (brief definition)
  - Key ALM areas: Governance · Development · Maintenance · Deployment
- Source: Standard HSO ALM approach

### ALM Pipeline Strategy
- Layout: Content slide
- Title: "ALM Strategy"
- Content:
  - Solution management approach (publisher prefix, managed vs unmanaged)
  - Branch and pipeline strategy
  - Solution layering
- Source: `agent/wiki/system/` ALM docs or standard HSO approach

### Release Management
- Layout: Content slide
- Title: "CE Release Management"
- Content: Release cadence, hotfix process, version naming

---

## Closing Slides

### Q&A Slide
- Layout: Section divider (navy background)
- Title: "Q&A" or "Questions & Discussion"
- No body text

### Next Steps
- Layout: Content slide
- Title: "Next Up" or "Next Steps"
- Content: Table or bullets with:
  - Action item description
  - Owner
  - Target date
- Source: Ask user for actual next steps or insert placeholder

---

## Content Sourcing Checklist

For each section, check sources in this order before inserting a placeholder:

```
□ agent/README.md          — project overview, component list
□ agent/wiki/system/       — architecture, tech stack, schema
□ agent/work/specs/        — feature requirements and specs
□ agent/work/analysis/     — architectural analysis documents
□ agent/wiki/digests/      — ingested client artifacts and meeting notes
□ agent/raw/discovery/     — original client source files (PDF, xlsx, docx)
□ ADO (hso-ado-work-items) — features, user stories, state
□ User input               — ask for missing information
□ [PLACEHOLDER: ...]       — insert if none of the above apply
```
