---
name: hso-dataverse-sdk-reference
layer: atomic
scope: core
description: |
  Microsoft Dataverse SDK and Power Apps platform development reference from official Microsoft documentation. Use when asking about:
  - Dataverse SDK APIs (IOrganizationService, Entity, QueryExpression)
  - Plugin development (IPlugin, execution pipeline, images, registration)
  - PCF controls (lifecycle, manifest, property binding)
  - Web API (OData queries, CRUD, batch requests, functions/actions)
  - Custom APIs (request/response parameters, plugin handlers)
  - Model-driven apps (create apps via code, sitemap, app designer API, ribbons)
  - Form scripts and Client API (Xrm.Page, formContext, events, navigation)
  - Metadata operations (entity/attribute definitions, relationships)
  Provides SDK code examples and best practices.
---

# Dataverse SDK Reference

Expert on Microsoft Dataverse SDK and Power Apps platform development.

## CRITICAL: Search Local Documentation First

**ALWAYS search the local powerapps-docs repository BEFORE using WebSearch or WebFetch.**

The complete Microsoft Power Apps documentation is available locally at:
```
../powerapps-docs/powerapps-docs/developer/
```

| Area | Local Path |
|------|------------|
| Dataverse SDK | `../powerapps-docs/powerapps-docs/developer/data-platform/` |
| PCF Controls | `../powerapps-docs/powerapps-docs/developer/component-framework/` |
| Model-driven Apps | `../powerapps-docs/powerapps-docs/developer/model-driven-apps/` |

**Search workflow:**
1. Use Glob to find relevant .md files by topic name
2. Use Grep to search for specific APIs, classes, or code patterns
3. Use Read to load the documentation content
4. Only fall back to online sources if local docs are not available

## Fallback: Online Documentation

If the local `../powerapps-docs/` repository is **not cloned** or files cannot be found locally, search these sources in order:

1. **GitHub repo (raw source):** https://github.com/MicrosoftDocs/powerapps-docs — search or browse the markdown source files directly via `gh` CLI or WebFetch
2. **Published docs:** https://learn.microsoft.com/en-us/power-apps/ — use WebSearch or WebFetch to find the rendered documentation

The GitHub repo is the source that publishes to the Learn site. Prefer it for code samples and exact API signatures since the markdown is more tool-friendly than the rendered HTML.

## Search Examples

### Find model-driven app documentation
```
Glob: pattern="**/create*app*.md" path="../powerapps-docs/powerapps-docs/developer/model-driven-apps"
```

### Find form script / Client API docs
```
Glob: pattern="**/*client*api*.md" path="../powerapps-docs/powerapps-docs/developer/model-driven-apps"
Grep: pattern="formContext" path="../powerapps-docs/powerapps-docs/developer/model-driven-apps"
```

### Find plugin development docs
```
Glob: pattern="**/plug*.md" path="../powerapps-docs/powerapps-docs/developer/data-platform"
Grep: pattern="IPlugin" path="../powerapps-docs/powerapps-docs/developer/data-platform"
```

### Find Web API docs
```
Glob: pattern="**/web*api*.md" path="../powerapps-docs/powerapps-docs/developer/data-platform"
Grep: pattern="OData" path="../powerapps-docs/powerapps-docs/developer/data-platform"
```

### Find PCF control docs
```
Glob: pattern="**/*.md" path="../powerapps-docs/powerapps-docs/developer/component-framework"
Grep: pattern="updateView" path="../powerapps-docs/powerapps-docs/developer/component-framework"
```

### Find sitemap / ribbon docs
```
Grep: pattern="SiteMap" path="../powerapps-docs/powerapps-docs/developer/model-driven-apps"
Grep: pattern="ribbon" path="../powerapps-docs/powerapps-docs/developer/model-driven-apps"
```

## Expertise Areas

### Dataverse SDK
- IOrganizationService interface
- Entity and EntityReference classes
- ColumnSet and QueryExpression
- Early-bound vs late-bound entities
- SDK message processing

### Plugin Development
- IPlugin interface
- Plugin execution pipeline
- Pre/post images
- Plugin registration
- Secure vs unsecure configuration
- Impersonation

### Model-driven Apps
- Creating apps programmatically
- App modules and components
- Sitemap configuration
- Ribbon customization
- Client API / form scripts
- Navigation and URL parameters

### PCF Controls
- Component lifecycle (init, updateView, destroy)
- Manifest configuration
- Property binding
- Resources (CSS, RESX)
- PAC CLI commands
- Testing and debugging

### Web API
- OData query syntax
- CRUD operations via HTTP
- Batch requests
- Functions and actions
- Authentication (OAuth)

### Custom APIs
- Creating custom APIs
- Request/response parameters
- Plugins as custom API handlers
- Security and privileges

### Metadata Operations
- Entity/table definitions
- Attribute/column definitions
- Relationships
- Option sets/choices

## Answer Format

For SDK references:
1. Namespace and interface definition
2. Method signature with parameters
3. Working code example from documentation
4. Important notes and gotchas
5. File path reference to local docs

For How-to questions:
1. Prerequisites
2. Step-by-step guide with code
3. Complete working example
4. Testing/verification steps
5. Common issues and solutions

## Out of Scope

- Application-specific configuration - Use `hso-ce-apps-sdk-reference`
- Field Service work order setup - Use `hso-ce-apps-sdk-reference`
- Customer Service case routing - Use `hso-ce-apps-sdk-reference`

---

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-11 | maciejnowicki | Ported from prior in-house reference skills and neutralised for the reusable template (dropped internal license header, stripped stray project tags). |
