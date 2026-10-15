---
name: hso-template-architecture
layer: reference
scope: core
description: |
  Master architectural reference for a project generated from this template. Documents every
  template layer, its relationships, the configuration dependency chain, initialisation order, and
  token-replacement scope. Read this BEFORE any development work on a template-derived project.

  Use when:
  - Starting any development work on a project
  - Designing a feature and needing to know which layer it belongs to
  - Changing a configuration value and needing to trace downstream impact
  - Diagnosing unexpected behaviour and needing the mental model of the template
  - Onboarding a developer to the project structure

  Read this skill BEFORE: hso-plugin-development, hso-formscript-development,
  hso-pcf-control-development, hso-dataverse-data-modeling, hso-pipeline-generation.
---

# hso-template-architecture

Master reference for the `ProjectTemplate/` architecture. All token/naming rules are governed by
[ADR-0003](../../../../docs/decisions/ADR-0003-naming-and-token-contract.md) — this skill never
invents a naming rule, it points at that contract.

## Template locations

| Location | Purpose |
|---|---|
| `ProjectTemplate/` | The master blueprint — committed, never run as a live project |
| `Project/` | The active customer repo generated from the blueprint (gitignored) |

All structural changes go into `ProjectTemplate/` first, then flow into `Project/` via init.

## Layer map

```
ProjectTemplate/
├── Server/                         C# plugin solution (4-layer architecture)
│   ├── HSO.Customer.DataverseModel/    Layer 1: early-bound entities
│   ├── HSO.Customer.Services/          Layer 2: services, repositories, validation
│   ├── HSO.Customer.Plugins/           Layer 3: plugin entry points (IPlugin)
│   └── HSO.Customer.Tests/             Layer 4: unit tests
├── Client/clientjs/                TypeScript form scripts + JSON RuleEngine
│   └── src/config.ts                   webResourcePrefix and client config
├── PCFControls/                    PCF control projects (pac pcf init)
├── Functions/                      Azure Functions (.NET 8 isolated) for integrations
├── Solutions/                      Unpacked solution XML (READ-ONLY, export output)
├── Pipelines/                      ADO YAML pipelines (generated from config)
└── PipelinesHelpers/config/        pipeline-defaults.json · solution-organizer.json
```

## Initialisation

The init engine (`ProjectTemplate/InitializeProjectScript/`) runs **once** after generating a
project. It rewrites the neutral tokens (see ADR-0003) across the tree:

| Token | Rewritten to | Example |
|---|---|---|
| `HSO.Customer.` | `HSO.{CustomerName}.` | `HSO.Contoso.` |
| `hso_customer_` | `{publisherPrefix}_` | `cnto_` |
| `Customer` (namespace) | `{CustomerName}` | `Contoso` |
| `PROJECTCODE` | `{projectCode}` | `CNTO` |

Skipped: `bin obj node_modules packages dist .git InitializeProjectScript`.

**CRITICAL:** run init BEFORE scaffolding any new code — generated code uses final names and cannot
be auto-renamed later.

## Configuration dependency chain (trace the WHOLE chain, never one link)

```
publisherPrefix → publisher record → solution unique names → schema names (hso_customer_*)
                                    └→ web-resource paths → Client config.ts webResourcePrefix
                                    └→ PCF namespace/publisher → PCF solution (publisher-locked)
server namespace root (HSO.Customer) → plugin assembly name → registration attributes
projectCode → pipeline-defaults.json → ADO pipeline names / work-item area
```

The single source of truth for the actual values is
`ProjectTemplate/PipelinesHelpers/config/pipeline-defaults.json`. Editing a value there ripples
through the chain — propagate every link.

## Layer boundaries (NEVER cross)

| Layer | CAN access | CANNOT access |
|---|---|---|
| Plugins | Services (constructor injection) | DataQueries directly |
| Services (business logic) | DataQueries | `IOrganizationService` directly |
| DataQueries | early-bound entities, `IOrganizationService` | business logic |
| Client RuleEngine | `Xrm.WebApi`, `formContext` | server-side C# / state |

## Correct order for a multi-layer feature

1. Query live schema (never assume field names).
2. Update schema if needed (`hso-dataverse-data-modeling`).
3. Regenerate early-bound C# + TypeScript models.
4. Server service/plugin code (`hso-plugin-development`).
5. Client rule config / form script (`hso-formscript-development`).
6. Deploy server; build + deploy client.
7. Run tests. Update the TOPO map (`hso-architecture-map`).

## Solutions folder is READ-ONLY

`Solutions/` is the output of `pac solution export` — never edit it, never pack/import to deploy.
Flow is one-way: **platform → export → `Solutions/`**.

## Before-you-start checklist

- [ ] Init script already run? If not, run it first.
- [ ] `config.ts` `webResourcePrefix` matches the publisher prefix?
- [ ] Early-bound C# + TypeScript models current?
- [ ] Live schema queried?

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | maciejnowicki | Ported from HINT and neutralised to the ADR-0003 token contract for the reusable template. |
