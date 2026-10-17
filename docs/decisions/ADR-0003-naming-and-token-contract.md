---
adr: 0003
title: Naming & token contract (the reusability spine)
status: accepted
date: 2026-09-10
author: aidevme
supersedes: []
---

# ADR-0003 — Naming & token contract

## Context
Reusability hinges on one thing: the template must carry **neutral placeholder tokens** that an
initialize step rewrites per engagement, and every part (server, client, pcf, pipelines, solutions) must
use the **same** tokens so a single rename produces a coherent project. CDX and HINT already established a
token set and an init token-replacement engine; this ADR fixes it as the contract all builders honor.

## Decision — the canonical tokens

| Token (as it appears in the template) | Meaning | Rewritten at init to | Example after init |
|---|---|---|---|
| `Customer` (PascalCase namespace segment) | .NET / TS namespace root | `{CustomerName}` | `Contoso` |
| `HSO.Customer.*` | .NET project/namespace prefix | `HSO.{CustomerName}.*` | `HSO.Contoso.Plugins` |
| `hso_customer_` | Dataverse schema-name prefix for project components | `{publisherPrefix}_` | `cnto_` |
| `hso` (publisher prefix token) | Dataverse publisher customization prefix | `{publisherPrefix}` | `cnto` |
| `customer` (publisher unique name token) | Dataverse publisher unique name | `{publisherUniqueName}` | `contoso` |
| `PROJECTCODE` | short project code (pipelines, work items) | `{projectCode}` | `CNTO` |
| `solutionPrefix` | solution unique-name prefix | `{solutionPrefix}` | `Contoso` |

The **single source of truth** for the actual values is the config blueprint
`ProjectTemplate/PipelinesHelpers/config/pipeline-defaults.json` (`projectInfo.*`,
`publisherUniqueName`, `solutionPrefix`, `projectCode`). The init engine
(`ProjectTemplate/InitializeProjectScript/`) reads it and rewrites tokens across the tree.

## The configuration dependency chain (MUST stay coherent)
A change to the publisher prefix ripples; the init engine and any config-edit skill must propagate the
whole chain, never one link:

```
publisherPrefix ─▶ publisher record ─▶ solution unique names ─▶ schema names (hso_customer_*)
                                      └▶ web-resource paths (customer_/…) ─▶ Client config.ts webResourcePrefix
                                      └▶ PCF namespace/publisher ─▶ PCF solution (publisher-locked)
server namespace root (HSO.Customer) ─▶ plugin assembly name ─▶ registration attributes
projectCode ─▶ pipeline-defaults.json ─▶ ADO pipeline names / work-item area
```

## Rules for builders
1. Use ONLY the tokens above in template files — never a real customer name, never a source client's name.
2. Namespaces: `HSO.Customer.<Layer>` (Server), `HSO.Customer.Functions` (Functions), TS namespace
   `Customer` where applicable.
3. Schema names in sample components: `hso_customer_<thing>`.
4. Anything that must vary per project goes to `pipeline-defaults.json` / `solution-organizer.json`, not
   hardcoded in a file.
5. The init engine (Part-1/Pipelines deliverable) must have a test proving a full rename yields a
   coherent, buildable project (no orphan `Customer`/`hso_customer_` tokens left, config chain intact).

## Consequences
- The Server, Client, PCF, Pipelines builders share this token set → the generated project is coherent.
- `hso-generated-file-review` / `hso-project-upgrade` (agent layer) rely on these tokens being the only
  variability, so a template upgrade can be diffed against a live project cleanly.
