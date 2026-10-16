---
adr: 0004
title: Server (Dataverse plugins/services) architecture
status: accepted
date: 2026-09-10
author: maciejnowicki
supersedes: []
---

# ADR-0004 — Server architecture

## Context

The template needs one reusable, best-in-class C# server layer for Dataverse plug-ins, Custom APIs and
services. Two sources feed it (see `docs/review-logs/part2-server-01-source-analysis.md`): **CDX**
(`HSO.Customer.*` — mature `PluginBase`, declarative registration, error catalogue, signed SDK-style build,
integration tests) and **the live-delivery source** (`HSO.Dynamics.Source.*` — strict 4-layer separation, interface-segregated
repositories, DI, test discipline, production-hardened patterns). The third source has no server code.

Constraints: plug-ins run in the Dataverse sandbox on the **.NET Framework 4.6.2 IL** runtime (no
`System.Text.Json`, no async pipeline, no runtime DI container); the template must be **neutral/reusable**
(ADR-0001/0003) and **buildable + tested locally** (ADR-0001 §6).

## Options considered

1. **Port the live-delivery source as-is.** Pros: best layering/testability, production-proven. Cons: loses CDX's declarative
   registration (the live-delivery source's recurring deploy-gap pain), no `PluginBase` (per-plugin boilerplate), legacy
   `packages.config`/`<Compile Include>`, unsigned, no integration tests.
2. **Port CDX as-is.** Pros: registration in source, `PluginBase`, error catalogue, modern signed build,
   integration project. Cons: no enforced data/business separation (services hold a raw `IOrganizationService`
   and do CRUD), services testable only by mocking the SDK service, much placeholder/`TODO` surface.
3. **Merge: live-delivery-source shape + CDX machinery** (the source-analysis recommendation). Pros: keeps the best of both.
   Cons: more design work up front; must resolve where the error handler and env-var access live so BL stays
   CRUD-free.

## Decision

Adopt **Option 3**. Concretely:

- **Four layers, one-way dependency, compile-enforced:** `Plugins → BusinessLogic → Data → DataverseModel`
  (the live-delivery source). Projects `HSO.Customer.DataverseModel|Data|BusinessLogic|Plugins` + `Tests` + `Tests.Integration`.
- **ZERO TOLERANCE — no CRUD in BusinessLogic** (the live-delivery source). Services take repository **interfaces** only, never
  `IOrganizationService`. Enforced by `Tests/Architecture/LayeringTests.cs`, not just documented.
- **`PluginBase` / `ILocalPluginContext` / `LocalTracingService` / extensions** (CDX) — delta-timed tracing,
  fault translation, `PluginUserService`/`AdminService`, `ILogger`. Handlers are thin **composition roots**
  inside `ExecuteDataversePlugin`.
- **Declarative registration** (CDX) — `[PluginStep]`, `[CustomApi]`(+params), and the **net-new
  `[PluginStepImage]`** — reflected and idempotently upserted by `Scripts/Deploy-Package.ps1`. The same
  reflection is a unit test (`RegistrationAttributeTests`).
- **Repository base** (the live-delivery source) with folded-in CDX value-adds as opt-in helpers (`TrackedAttribute<T>`), plus
  optimistic-concurrency `UpdateIfUnchanged` (CAS on `0x8009000C`).
- **Result contracts** `OperationResult<T>` / `ValidationResult` (the live-delivery source); services return them rather than only
  throwing.
- **Error catalogue** (CDX) `hso_customer_error*` + `ErrorCatalogueService.ThrowError(code)`, but reading via a
  Data-layer `IErrorCatalogueRepository` so BL stays CRUD-free (fixing CDX's in-service query).
- **Config** via a Data-layer `EnvironmentVariableRepository` (live-delivery-source location, CDX join).
- **Build:** SDK-style csproj, `PackageReference`, `Microsoft.PowerApps.MSBuild.Plugin` NuGet plugin package,
  **strong-name signed**, `net471`, `DevMode` coexistence toggle (CDX). `Microsoft.NETFramework.ReferenceAssemblies`
  makes `dotnet build` headless.
- **Tests:** NUnit + Moq unit tests as the CI gate (mock repo interfaces + `PluginTestContext` for wiring);
  `ServiceClient` + `appsettings.json` integration tests, `[Explicit]`, out of the gate.

## Rationale

- **Testability & maintainability (the live-delivery source):** mocking a repository interface beats mocking the SDK service;
  the one-way, CRUD-free BL is the most maintainable shape and now cannot silently rot (test-enforced).
- **Drift-proof delivery (CDX):** registration in source, reflected and idempotent, is the direct antidote to
  the live-delivery source's documented "component not in the wave / step not registered" incidents — and the image gap that bit
  both sources is closed.
- **Upgradeability (CDX):** SDK-style + signing + `net471`-on-`net462` is the forward path; the live-delivery source's
  `packages.config`/old-style is legacy.
- **Proven, not asserted (ADR-0001):** every example is exercised by a passing test; the build is green and the
  assemblies verifiably signed.

## Consequences

- New server work follows the 4-layer shape; a data-access call in BusinessLogic **fails the build**.
- Adding a plugin/Custom API/step-image is an attribute + a class + a test; `Deploy-Package.ps1` (and the CI
  pipeline step it models) makes the environment match source.
- The early-bound `DataverseModel` is regenerated per project (`pac modelbuilder`); the sample schema
  (`hso_customer_widget`, `hso_customer_error*`) must be created in the org by the data-model/init step.
- Neutral tokens (`HSO.Customer.*`, `hso_customer_*`) are the only variability (ADR-0003), so the init rename
  yields a coherent, buildable project.
- Follow-on parts consume this: Client/PCF call the Custom APIs registered here; Pipelines run the equivalent of
  `Deploy-Package.ps1` as a release step.
