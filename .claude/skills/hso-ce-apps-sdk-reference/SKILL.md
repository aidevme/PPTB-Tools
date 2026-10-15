---
name: hso-ce-apps-sdk-reference
layer: atomic
scope: core
description: |
  Dynamics 365 Customer Engagement applications expert for Field Service, Customer Service, Sales, Marketing, and Project Service Automation. Provides configuration guidance, app-specific features, and best practices from official Microsoft documentation. Use when asking about Field Service work orders, Customer Service cases, Sales processes, app-specific entity configurations, or CE app setup and customization.
---

# CE Apps SDK Reference

Expert on Dynamics 365 Customer Engagement application configuration and features.

> **Scope — vendor reference only.** This skill surfaces *what Microsoft says*; it does **not** carry HSO engagement methodology. HSO's SOP overlays are deliberately kept out so this stays a clean vendor window. For the synthesis of Microsoft guidance with HSO's engagement SOPs, use [`hso-dataverse-architect`](../hso-dataverse-architect/SKILL.md) — the orchestration skill that brings them together.

## Documentation Source

**Repository:** `../dynamics-365-customer-engagement`

| App | Path |
|-----|------|
| Field Service | `../dynamics-365-customer-engagement/ce/field-service/` |
| Customer Service | `../dynamics-365-customer-engagement/ce/customer-service/` |
| Sales | `../dynamics-365-customer-engagement/ce/sales/` |
| Marketing | `../dynamics-365-customer-engagement/ce/marketing/` |
| Project Service | `../dynamics-365-customer-engagement/ce/project-service/` |

## Fallback: Online Documentation

If the local `../dynamics-365-customer-engagement/` repository is **not cloned** or files cannot be found locally, search these sources in order:

1. **GitHub repo (raw source):** https://github.com/MicrosoftDocs/dynamics-365-customer-engagement — search or browse the markdown source files directly via `gh` CLI or WebFetch
2. **Published docs:** https://learn.microsoft.com/en-us/dynamics365/ — use WebSearch or WebFetch to find the rendered documentation

The GitHub repo is the source that publishes to the Learn site. Prefer it for code samples and exact API signatures since the markdown is more tool-friendly than the rendered HTML.

## Expertise Areas

### Field Service
- Work order management and lifecycle
- Scheduling and dispatch
- Agreements and recurring work
- Resource and crew management
- Inventory and warehouse management
- Asset and customer asset management
- Connected Field Service (IoT)
- Mobile app configuration

### Customer Service
- Case management and resolution
- Queue and routing configuration
- Entitlements and SLA management
- Knowledge management
- Customer Service workspace
- Omnichannel configuration

### Sales
- Lead qualification and management
- Opportunity and pipeline management
- Quote and order processing
- Product catalog
- Sales forecasting

### Cross-App Configuration
- Security roles and permissions
- Form and view customization
- Business process flows
- Business rules
- Dashboards and reports

## Search Patterns

```bash
# Find app-specific documentation
Grep: pattern="[feature]" -i path="../dynamics-365-customer-engagement/ce/[app-name]"

# Find entity documentation
Grep: pattern="msdyn_workorder|msdyn_agreement|incident" output_mode="content"

# Find configuration guides
Glob: pattern="**/configure*.md" path="../dynamics-365-customer-engagement/ce/[app-name]"
```

## Answer Format

Include:
1. Business context - Why this feature exists
2. Step-by-step configuration - Navigation paths, menu locations
3. Prerequisites - Licenses, permissions, dependencies
4. Common scenarios - Real-world use cases
5. Documentation source - File path reference

## Out of Scope

- SDK/Plugin Development - Use `hso-dataverse-sdk-reference`
- PCF control development - Use `hso-dataverse-sdk-reference`
- Web API queries - Use `hso-dataverse-sdk-reference`

---

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-11 | maciejnowicki | Ported from prior in-house reference skills and neutralised for the reusable template (dropped internal license header, stripped stray project tags). |
