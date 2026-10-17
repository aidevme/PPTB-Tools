---
title: "Part 2 — Server Template Convergence"
author: aidevme
date: 2026-09-10
status: draft
scope: Final state of ProjectTemplate/Server — what changed across iterations, why it is best-in-class, residual risks, evidence
---

# Server Template — Convergence

## What was built

A merged best-in-class Dataverse server template under `ProjectTemplate/Server/`: **the live-delivery source's strict 4-layer
separation + interface-segregated repositories + DI + test discipline**, grafted with **CDX's `PluginBase`/
`ILocalPluginContext`, declarative registration, data-driven error catalogue, delta-timed telemetry, and a
modern signed SDK-style build**, plus the **net-new `[PluginStepImage]`** attribute.

Six projects + a solution + a reflection deploy script:

```
Server/HSO.Customer.D365.sln
├── HSO.Customer.DataverseModel   L1  early-bound entities, option set, error-catalogue tables
├── HSO.Customer.Data             L2  IRepositoryBase<T>/RepositoryBase<T>, per-entity repos+ifaces,
│                                     EnvironmentVariableRepository, ErrorCatalogueRepository, HTTP gateway,
│                                     TrackedAttribute<T>, optimistic-concurrency UpdateIfUnchanged
├── HSO.Customer.BusinessLogic    L3  services (repo interfaces only), OperationResult/ValidationResult,
│                                     WidgetValidationService (pure), WidgetService, ErrorCatalogueService
├── HSO.Customer.Plugins          L4  PluginBase + ILocalPluginContext + LocalTracingService + extensions,
│                                     Registration/[PluginStep|PluginStepImage|CustomApi], sample plugin +
│                                     sample Custom API, builds the NuGet plugin package
├── HSO.Customer.Tests            unit — NUnit + Moq (services, plugin wiring, CAS, layering, registration)
└── HSO.Customer.Tests.Integration live — ServiceClient round-trip ([Explicit], out of the gate)
Scripts/Deploy-Package.ps1        reflect [PluginStep]/[PluginStepImage]/[CustomApi] → idempotent upsert
```

## What changed across iterations (r01 → r03)

| From the source analysis | As-built refinement |
|---|---|
| "Adopt CDX PluginBase as-is; handlers become composition roots" | Done. The one correctness trap (mutating a `ToEntity` copy of the Target) was caught in review and the sample reads/mutates the raw Target. |
| "Keep the live-delivery source's layering + no-CRUD-in-BL rule (the axis CDX is weaker on)" | Elevated from prose to a **test gate** (`LayeringTests`) — the build fails if L3 ever takes an `IOrganizationService` or the dependency direction reverses. |
| "Repository base + CAS/RowVersion" | `UpdateIfUnchanged` implemented against the real `0x8009000C` fault and **covered by tests** (success / conflict / other-fault). |
| "Add `[PluginStepImage]` — the missing piece" | Added, with `ForMessage`/`ForStage` scoping and `MessagePropertyName`; the deploy script upserts images and refuses to bind a Post-image to a non-Post-op step; a unit test asserts every image binds to a declared message. |
| "Declarative registration reflected + idempotently deployed" | Deploy script ported and extended to 7 steps (types → APIs → steps → images → solution). The **same reflection walk** is a unit test, so registration errors fail CI, not the environment. |
| "Error catalogue + ThrowError(code)" | `ErrorCatalogueService` depends on a Data-layer `IErrorCatalogueRepository` (fixing CDX's in-service CRUD), with a fallback-message path, tested. |
| "Modern SDK-style csproj + signing from day one" | All projects SDK-style with `PackageReference`; product assemblies strong-name signed (`sn -vf` valid); `Microsoft.NETFramework.ReferenceAssemblies` makes `dotnet build` work headless. |
| "Integration project (the live-delivery source lacked one)" | Present, `[Explicit]`/`[Category("Integration")]`, uses `ServiceClient` + `appsettings.json`, best-effort cleanup. |

## Why it is best-in-class

- **Every claim is enforced, not asserted.** Layering, projection discipline, registration correctness,
  double-execution avoidance, and concurrency semantics are all backed by passing tests — the "bulletproof =
  proven" bar from ADR-0001.
- **The strongest idea from each source survives the merge.** CDX's declarative, drift-proof registration
  (with the image gap closed) sits on the live-delivery source's testable 4-layer shape; neither source had both.
- **Sandbox-correct and upgradeable.** `net471`-on-`net462`, no container, no `System.Text.Json`, signed,
  SDK-style — the forward path, with none of the live-delivery source's `packages.config`/`<Compile Include>` tax.
- **Onboarding is built in.** A single worked vertical slice (widget) demonstrates plugin, Custom API,
  repository, service, error catalogue, images, and both test styles; a reusable `PluginTestContext` removes
  the friction of testing a `PluginBase` plugin.

## Evidence

- **Build:** `dotnet build HSO.Customer.D365.sln -c Release` → **6/6 projects, 0 warnings, 0 errors**; plugin
  `.nupkg` produced (`HSO.Customer.Plugins.Package.1.0.0.nupkg`).
- **Unit tests:** `dotnet test HSO.Customer.Tests` → **29 passed, 0 failed, 0 skipped** (~0.7 s).
- **Signing:** `sn -vf` reports *valid* for DataverseModel, Data, BusinessLogic, Plugins.Package.
- **Toolchain:** .NET SDK 9.0.305 (also 8.0.424 / 6.0.428 present); net471 restored from nuget.org.

## Residual risks

1. **Deploy script not executed here** (local-only, no environment). It is reviewed and mirrors the proven CDX
   script; the reflection half is exercised by `RegistrationAttributeTests`, but the Web API upserts (steps,
   **images**, Custom APIs) have not run against a live org in this build. First real run should be on a dev org.
2. **Early-bound model is hand-written, minimal.** The samples exist so the template compiles; a real project
   regenerates `DataverseModel` with `pac modelbuilder`. The error-catalogue and widget schema must actually be
   created in the target org (data-model part / init step) before the plugins do anything.
3. **`Microsoft.PowerApps.MSBuild.Plugin Version="1.*"`** floats; a future major could change packaging. Pin it
   when a project locks its toolchain.
4. **Integration tests need real config** and a reachable org; they are correct-by-construction but unrun here.
5. **`net471` targeting pack** must be restorable (or installed) on the build agent — handled by
   `Microsoft.NETFramework.ReferenceAssemblies`, but an air-gapped agent needs the package cached.
