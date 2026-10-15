---
name: hso-plugin-development
layer: atomic
scope: core
description: |
  Dataverse plugin development, testing, and deployment following the 4-layer architecture
  (DataverseModel, Services, Plugins, Tests). Covers scaffolding a plugin, business-logic services,
  the repository pattern for data access, unit tests, deploying the plugin package, and registering
  steps + images. Enforces early-bound development, layer separation, and ZERO data access in the
  Business Logic layer. Use when:
  (1) Creating a plugin, service, or repository
  (2) Adding/registering a plugin step or step image
  (3) Deploying or troubleshooting a plugin package build/test
  Read hso-template-architecture first.
---

# hso-plugin-development

Server-side business logic for Dataverse, built on the template's 4-layer C# architecture. Read
[hso-template-architecture](../../foundation/hso-template-architecture/SKILL.md) first for the layer
map, token contract, and config chain.

## The four layers (NEVER cross boundaries)

| Layer | Project | Responsibility | May access |
|---|---|---|---|
| 1 Model | `HSO.Customer.DataverseModel` | Early-bound entities (generated) | — |
| 2 Services | `HSO.Customer.Services` | Business logic, validation, orchestration | DataQueries (repos) |
| 3 Plugins | `HSO.Customer.Plugins` | `IPlugin` entry points; thin | Services (constructor injection) |
| 4 Tests | `HSO.Customer.Tests` | Unit tests (mock `IOrganizationService`) | all, for testing |

**ZERO TOLERANCE:** the Business Logic (Services) layer must NOT call `IOrganizationService`
directly — all data access goes through a repository/query class in the DataQueries area. Plugins
must NOT call DataQueries directly — they call Services.

## Workflow

1. **Query live schema** (`describe_table`) — never assume field names.
2. **Regenerate early-bound classes** into `DataverseModel` after any schema change.
3. **Write the service** in `Services/` extending the base service; inject repositories.
4. **Write the plugin** in `Plugins/` — parse context, construct the service, call it. Keep it thin.
5. **Write unit tests** in `Tests/` mocking `IOrganizationService`; cover the branch logic.
6. **Build**: `dotnet build "Project/Server/HSO.{CustomerName}.D365.sln" -c Debug`.
7. **Run tests** (vstest) — all green before deploy.
8. **Deploy** the plugin package to **Dev only** (`Deploy-Plugin.ps1`); verify the assembly landed.
9. **Register** steps/images (message, stage, filtering attributes, pre/post images) as needed.
10. **Update the TOPO map** (`hso-architecture-map`): add the `[SL]` block + dependencies.

## Critical rules

- Early-bound only; no late-bound magic strings for entity/attribute names where a constant exists.
- Plugins are stateless and thread-safe — no instance/mutable static state.
- Deploy targets **Dev**; verify the active connection first (env-safety). UAT/Prod via the pipeline.
- Assembly version numbers can lie about what shipped — confirm via the solution's "deployed X ago"
  and a functional test, not the version alone.

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | maciejnowicki | Ported from prior in-house skills; neutralised to the token contract; kept the 4-layer + zero-data-access invariant. |
