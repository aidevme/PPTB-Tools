---
title: "Part 2 — Server Template Self-Review (build → critique → improve loop)"
author: aidevme
date: 2026-09-10
status: draft
scope: Expert self-review of ProjectTemplate/Server across iterations r01..r03 until no blocker/major remains
---

# Server Template — Expert Self-Review Log

Reviewer stance: a top Dataverse server architect reviewing the merged best-in-class template built to the
recommendation in `part2-server-01-source-analysis.md`. Each finding has a severity
(**Blocker** / **Major** / **Minor** / **Nit**) and a file. Fixes are applied, then the template is
re-reviewed until no Blocker/Major remains.

Build/test harness used each round: `dotnet build HSO.Customer.D365.sln -c Release` and
`dotnet test HSO.Customer.Tests`.

---

## Iteration r01

Baseline: all 6 projects compiled (Release, 0 warnings/0 errors), plugin `.nupkg` emitted, 22 unit tests green,
4 product assemblies strong-name-verified (`sn -vf`). The architecture is in place; the review targeted
correctness and whether the template's *claims* are actually enforced.

| # | Severity | File | Finding | Resolution |
|---|---|---|---|---|
| 1 | **Major** | `Data/Base/RepositoryBase.cs` + `Interfaces/IRepositoryBase.cs` | The optimistic-concurrency `UpdateIfUnchanged` (compare-and-swap on `0x8009000C`) is the one production-hard-won pattern from the live-delivery source, but it was **demonstrated and untested** — the exact fault code and the `when` filter are easy to get subtly wrong and would fail silently. | Added `Tests/Data/RepositoryConcurrencyTests.cs`: success→true, version-mismatch fault→false, any other fault→rethrow. 3 tests. |
| 2 | **Major** | `BusinessLogic/*` | The ZERO-TOLERANCE "no CRUD in BusinessLogic" rule was only prose + convention. Because `Microsoft.CrmSdk.CoreAssemblies` is referenced, `IOrganizationService` is *visible* in L3 — nothing stopped a junior dev from taking one. The single axis where CDX was weaker than the live-delivery source must be a hard gate here. | Added `Tests/Architecture/LayeringTests.cs`: fails if any BusinessLogic type takes `IOrganizationService` in a ctor or holds it as a field, and asserts the one-way dependency direction (BL⇏Plugins, Data⇏BL). 4 tests. |
| 3 | **Minor** | `Registration/PluginStepImageAttribute.cs` + `Scripts/Deploy-Package.ps1` | The net-new image attribute lacked a `messagepropertyname`, which the `sdkmessageprocessingstepimage` upsert needs (defaults to "Target", but some messages use a different key). | Added `MessagePropertyName` (default `"Target"`) to the attribute; the deploy script writes it. |
| 4 | **Minor** | `Data/Base/RepositoryBase.cs` | `GetById` silently allowed `ColumnSet(true)` when no columns were passed (the live-delivery source's base did), which the SOPs ban. | Made it **throw** when no columns are supplied — projection is now mandatory at the base, enforced at runtime. |
| 5 | **Nit** | `Plugins/.../Widget_ValidateAndStamp.cs` | Risk that the plugin mutates a `ToEntity<T>()` **copy** of the Target (a real correctness trap — the stamp would not persist). | Verified/authored to read the **raw** `InputParameters["Target"]` via `GetInputParameter<Entity>` and mutate in place (mirrors the live-delivery source's `StampAIQuoteStatusTimestamp`). Covered by a wiring test asserting the stamp lands on the Target. |

All five resolved in-round.

## Iteration r02

Re-review after the r01 fixes. Rebuilt (Release, clean) and re-ran tests → **29 passed**.

| # | Severity | File | Finding | Resolution |
|---|---|---|---|---|
| 6 | **Minor** | `Scripts/Deploy-Package.ps1` | Step images bind to steps; a Post-image on a non-Post-operation step is invalid and would fault at registration. | The image-binding filter excludes Post-images from any step whose stage ≠ 40 (Post-operation), and warns when an image matches no step. |
| 7 | **Nit** | `Tests/Registration/RegistrationAttributeTests.cs` | The double-execution guard (Custom API handler must not also declare a self-step) was implicit. | Made it an explicit test (`CustomApiHandlers_DoNotAlsoDeclareAStepForTheirOwnMessage`) plus an image-binds-to-a-declared-message test. |

No Blocker/Major found. Both Minor/Nit addressed.

## Iteration r03 (verification pass)

No new findings. Confirmed:

- **Layering compile-enforced + test-enforced.** `Plugins → BusinessLogic → Data → DataverseModel`; BL takes
  only repository interfaces; `LayeringTests` green.
- **Sandbox-correct.** `net471` on `net462`; no `System.Text.Json`, no async in the pipeline path (the gateway
  bridges sync→async with `GetAwaiter().GetResult()` and disposes responses); readonly injected fields.
- **Registration in source, idempotent, guarded by the same reflection at build (`RegistrationAttributeTests`)
  and at deploy (`Deploy-Package.ps1`).**
- **Signing real.** `sn -vf` valid on all four product assemblies.
- **Every public example is exercised** by a unit test (validation rules, service mapping, error catalogue
  fallback, plugin wiring, Custom API outputs, CAS, layering, registration).

**Exit state:** 6/6 projects build (Release, 0/0), 29/29 unit tests pass, no Blocker/Major open. Converged.
