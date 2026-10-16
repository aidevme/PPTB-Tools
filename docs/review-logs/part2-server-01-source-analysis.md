---
title: "Part 2 — Server-Side Source Analysis (CDX vs the live-delivery source)"
author: aidevme
date: 2026-09-10
status: draft
scope: Read-only comparative architect review of server-side (plugins/services) templates feeding a new best-in-class server template
sources:
  - "CDX: C:/Repos/HSO-Power Platform Pipeline Template - CDX/.../Server"
  - "live-delivery source: C:/Repos/workspace/NewHorizon-App-SalesAI-CRM/SourceCode/HSO.D365.Source"
  - "third repo: no server-side code"
---

# Server-Side Comparative Architect Review

Read-only review of the two repositories that carry server-side C# (plugins + services). The third
repository has no server code and is out of scope. The goal is to merge the best of both into a new
reusable **best-in-class server template**. Dataverse plugins run in the sandbox on **.NET Framework
4.6.2 IL** (the SDK ships `net462` assemblies; both repos build `net471`, which loads fine), so every
recommendation is constrained to that runtime — no `System.Text.Json`, no async sandbox tricks, no DI
container that needs reflection-emit at runtime.

Throughout: **CDX** = `HSO.Customer.*` (the "Power Platform Pipeline Template - CDX"); **live-delivery source** =
`HSO.Dynamics.Source.*` (the live Sales-AI CRM plugin solution).

---

## 1. Architecture of Each

### 1.1 CDX — `HSO.Customer.*`

**Projects** (`Server/HSO.Customer.D365.sln`):

| Project | Role | csproj style |
|---|---|---|
| `HSO.Customer.DataverseModel` | Early-bound entities + option sets + the `HSo_Error*`/`HSo_System` error catalogue | **SDK-style**, `net471` |
| `HSO.Customer.Plugins` (`.Package.csproj`) | Plugin base, context extensions, registration attributes, plugin + Custom API handlers; **builds the NuGet plugin package** | **SDK-style**, PowerApps plugin package, signed (`.snk`), `DevMode` toggle |
| `HSO.Customer.Services` | Base service, data queries, services, record-validation framework, error handler | **SDK-style**, signed |
| `HSO.Customer.Tests` | Unit tests (xUnit + Moq + AutoFixture) | SDK-style, `net471` |
| `HSO.Customer.Tests.Integration` | Live-Dataverse integration tests (`ServiceClient` + `appsettings.json`) | SDK-style |

**Layer boundaries / dependency direction.** Three-ish layers: `DataverseModel` ← `Services` ←
`Plugins`. Plugins reference Services + DataverseModel; Services reference DataverseModel. There is
**no separate Data project** — data access lives inside Services as `DataQueries/*` classes that all
derive from `BaseDataverseService` and hold a raw `IOrganizationService`. So the boundary between
"business logic" and "data access" is a *naming convention* (`Services/` vs `DataQueries/`), not a
compile-enforced one: a service can and does call `_organizationService.Create()` directly
(`AccountService.CreateAccount`, `Services/AccountService.cs:31`).

**Early vs late bound.** Early-bound throughout (`DataverseModel/Entities/*`, `DataverseContext.cs`).
Queries are hand-written **FetchXML strings** (`AccountDataQuery.cs`, `EnvironmentQueries.cs`,
`ErrorHandlerQueries.cs`) using early-bound `Fields.*`/`EntityLogicalName` constants for names.

**Plugin base / context abstraction.** This is CDX's strongest asset. `PluginBase.cs` is the
Microsoft `pac` plugin-template `ILocalPluginContext` pattern, matured:
- `PluginBase : IPlugin` with a `Type`-typed ctor, a `Trace(...)` entry/exit envelope, and a
  `FaultException<OrganizationServiceFault>` → `InvalidPluginExecutionException` translation
  (`PluginBase.cs:57`). Derived plugins override `ExecuteDataversePlugin(ILocalPluginContext)`.
- `ILocalPluginContext` exposes `InitiatingUserService`, `PluginUserService`, `PluginExecutionContext`,
  `NotificationService`, `TracingService`, `ServiceProvider`, `OrgSvcFactory`, and an
  `ILogger` (`Microsoft.Xrm.Sdk.PluginTelemetry`) — i.e. first-class App Insights logging.
- `LocalTracingService` prefixes every trace with a **millisecond delta** for perf diagnostics
  (`PluginBase.cs:228`).
- `LocalPluginContextExtensions.cs` adds generic `Target<T>()`, `PreImage<T>()`, `PostImage<T>()`,
  `TargetReference()`, `GetCustomApiParameter()`, and `AdminService()` (SYSTEM user via
  `OrgSvcFactory.CreateOrganizationService(null)`).

**Plugin-step & Custom API registration — DECLARATIVE.** The differentiator.
`Registration/PluginStepAttribute.cs` (`[PluginStep(message, EntityLogicalName=…, Stage=…, Mode=…,
FilteringAttributes=…, ExecutionOrder=…)]`, `AllowMultiple`) and `CustomApiAttribute.cs`
(`[CustomApi]` + `[CustomApiRequestParameter]` + `[CustomApiResponseProperty]`, with binding type,
processing-step type, isfunction/isprivate/workflow enums) decorate the handler class. `Scripts/
Deploy-Package.ps1` pushes the `.nupkg`, then **reflects over the built DLL** and idempotently upserts
`plugintype`, `customapi(+request/response)`, and `sdkmessageprocessingstep` records via the Web API,
finally adding all components to the target solution. Registration intent lives **next to the code it
registers**, in source control, and is diffable. `PluginStepMessage.cs`/`PluginStepEnums.cs` give
compile-time constants for messages/stages/modes.

**Configuration / env-var handling.** `BaseDataverseService.GetEnvironmentVariable()` →
`EnvironmentQueries` FetchXML join `environmentvariablevalue` ↔ `environmentvariabledefinition`.
`Configuration/CustomerConfiguration.cs` holds field-name constants for a config entity that the
`RecordValidation` framework reads (JSON rule blobs). Both carry `TODO` markers — scaffolding, not
finished.

**Error handling / telemetry.** Two mechanisms: (a) `PluginBase` fault translation + delta tracing +
`ILogger`; (b) a **data-driven error catalogue** — `HSo_Error` (code, user message, fix, area, kind),
`HSo_ErrorArea`, `HSo_ErrorKind`, `HSo_ErrorSystem`, `HSo_System` early-bound entities +
`ErrorHandlerService.ThrowError("CODE")` which looks up the row and throws the friendly message
(`Core/ErrorHandlerService.cs:21`). This decouples user-facing error text from code.

**DI / testability.** Manual composition (no container). `Tests` mock `IOrganizationService` with Moq
and test validators/services directly (`Account_PreCreateTests`, `AccountServiceTests`).
`Tests.Integration` hits a real org and round-trips a record with best-effort cleanup. The `Services`
constructors take a concrete `IOrganizationService`, **not** repository interfaces — so services are
testable only by mocking the SDK service (coarser than mocking a repository).

**Extra machinery worth noting.** `Core/TrackedAttribute<T>` (Pre/Target/Post change tracking with
`Updated`/`WasSet`/`WasCleared`/`WasRemoved`, CRM-type-aware equality) and `BaseDataverseService<T>`'s
`GetAttribute<T>`, `GetChangedAttributes`, `SetAttributeIfChanged`, `BulkCreate/Update/Execute`,
`ExecuteMultipleUpsertRequest`; `Core/EntityExtensions` (`GetAliased<T>`, `TraceAttributes`,
`UpsertByFields`); `Core/MultiFetchJsonMerger`; a whole `RecordValidation` config-rule engine. Rich,
but much of it is generic-utility surface with example-only coverage.

### 1.2 The live-delivery source — `HSO.Dynamics.Source.*`

**Projects** (`HSO.D365.Source.sln`, 6 projects in `Source`/`Tests` solution folders):

| Project | Role | csproj style |
|---|---|---|
| `HSO.Dynamics.Source.Tables` | Early-bound entities + option sets | **old-style**, `packages.config`, `v4.7.1` |
| `HSO.Dynamics.Source.Data` | Repository pattern (`RepositoryBase<T>` + `IRepositoryBase<T>` + per-entity repos/interfaces) + a gateway (`OrchestratorClient`) | old-style |
| `HSO.Dynamics.Source.BusinessLogic` | Platform-agnostic services (depend on repo interfaces) + DTO/result models | old-style |
| `HSO.Dynamics.Source.Plugins` | Thin `IPlugin` handlers (composition root); builds `.nupkg` via nuspec + `nuget.exe` target | old-style |
| `HSO.Dynamics.Source.BusinessLogic.Tests` | NUnit + Moq service tests | old-style |
| `HSO.Dynamics.Source.Plugins.Tests` | NUnit + Moq plugin-wiring tests | old-style |

**Layer boundaries / dependency direction — the canonical HSO 4-layer.**
`Tables ← Data ← BusinessLogic ← Plugins`. This is enforced and documented as **NON-NEGOTIABLE** by
the `hso-plugin-development` skill: BusinessLogic services **MUST NOT** call `Retrieve/RetrieveMultiple/
Create/Update/Delete` directly — all data access goes through repository interfaces; the only permitted
`IOrganizationService.Execute()` in BL is for Custom API calls. The dependency direction is genuinely
compile-enforced: BusinessLogic references Data (interfaces) and Tables, never the SDK service for CRUD.

**Early vs late bound.** Early-bound throughout, with a strong convention (`Entity.Fields.X`,
`Entity.EntityLogicalName`, `Entity.PrimaryIdAttribute`) and a `Generate-EarlyBound.ps1` regeneration
path. Repos use `ColumnSet(specific columns)` and `QueryExpression`; the skill bans `ColumnSet(true)`.

**Plugin base / context abstraction — NONE.** Every plugin implements `IPlugin` directly and
re-extracts `IPluginExecutionContext`/`ITracingService`/`IOrganizationServiceFactory` by hand, with its
own `try { … } catch (InvalidPluginExecutionException) { throw; } catch (Exception ex) { trace; throw
new InvalidPluginExecutionException(...); }` block and its own `GetString/GetInt/GetBool` param helpers
(see `AdvanceAIQuoteCaseToOpenPlugin.cs`, `GetCaseConversationPlugin.cs`, `StampAIQuoteStatusTimestamp.cs`).
The **composition root lives in each plugin** (`new Repo(service, tracing)` → `new Service(repo,
tracing)`), which is architecturally correct but copy-pasted across every handler.

**Repository / data-access pattern — the strong point.** `Data/Base/RepositoryBase<T>` gives
`GetById/GetMultiple/Create/Update/Delete/Exists` with `ArgumentNullException`/`ArgumentException`
guards and consistent `[EntityRepository.Method]` tracing. Per-entity repos extend it and add scenario
queries (`IncidentAIQuoteStatusRepository.GetAdvanceSnapshot/AdvanceToOpen`, with **explicit
`RowVersion` carry-through for compare-and-swap** — `IncidentAIQuoteStatusRepository.cs:38`). Every repo
has an interface, so BL depends only on abstractions.

**Service layer.** Services take repository **interfaces** + `ITracingService`, throw on null
(`AIQuoteOpenAdvanceService.cs:32`), and contain the business rule only — e.g. the New→Open advance
rule with the AP-642 "product-match memo must be present" guard and the AP-869 compare-and-swap. This is
genuinely platform-agnostic: the same service runs in a plugin, an Azure Function, or a unit test
(documented in `references/architecture.md`).

**Registration — IMPERATIVE / scripted.** No attributes. Steps are registered by invoking
`Deploy-Plugin.ps1 -Operation RegisterPluginStep -MessageName … -EntityLogicalName … -Stage … -Mode …
-FilteringAttributes …` (resolves GUIDs internally), and images via `RegisterPluginStepImage`. Custom
APIs are registered separately (via the `aidevme-dataverse-customapi` skill) and the plugin is attached
through `customapi.plugintypeid` (no SDK step — the code comments explicitly warn that registering a
step *and* attaching to a Custom API runs the plugin twice). Registration intent is **not in source** —
it lives in scripts, runbooks, and operator memory.

**Result models.** `Models/Results/OperationResult<T>` (`Ok/Fail/GetErrorMessage`) and `ValidationResult`
give services a structured return contract instead of only throwing — the `GetCaseConversationPlugin`
maps `result.Success`/`result.GetErrorMessage()` to Custom API outputs.

**Config / env vars.** `EnvironmentVariableRepository` in the Data layer (repository, not an inline
FetchXML in a base class).

**Error handling / telemetry.** Uniform `ITracingService` discipline + fault translation in each
plugin. **No** error catalogue, **no** `ILogger`/PluginTelemetry usage, **no** millisecond-delta trace.
The `hso-plugin-development` SKILL references a rich telemetry SOP (App Insights, KQL, SLOs) but the
code itself only traces.

**DI / testability — best in class.** Because BL depends on repo interfaces, tests mock the repository
with Moq and assert pure logic (no FakeXrmEasy needed) — `AIQuoteOpenAdvanceServiceTests`, and the
plugin-wiring shell tests (`StampAIQuoteStatusTimestampTests` mock `IServiceProvider`). Two test
projects (BL + Plugins), NUnit 3.14 + Moq 4.18.4, run via `vstest.console.exe` (`dotnet test` does not
work with `packages.config`). **No integration-test project.**

**Packaging.** The `.nupkg` is assembled by a nuspec (`hso_SourcePlugins`, version `1.8.10`) + a
`PackNuGetPackage` MSBuild `AfterTargets="Build"` step calling `nuget.exe`; it bundles Tables/Data/
BusinessLogic DLLs alongside the Plugins DLL (`HSO.Dynamics.Source.Plugins.nuspec`).

---

## 2. Strengths & Weaknesses (opinionated, cited)

### CDX

**Strengths**
- **Declarative registration is the single best idea in either repo.** `[PluginStep]`/`[CustomApi]` +
  `Deploy-Package.ps1` reflection = registration in source, diffable, idempotent, no drift between "what
  the code expects" and "what's registered." (`Registration/*`, `Scripts/Deploy-Package.ps1`.)
- **Mature `PluginBase`/`ILocalPluginContext`** with `PluginUserService` vs `InitiatingUserService`,
  `AdminService()`, `ILogger` (App Insights), and delta tracing. This is the Microsoft-blessed shape,
  hardened. (`PluginBase.cs`, `LocalPluginContextExtensions.cs`.)
- **Data-driven error catalogue** (`HSo_Error*` + `ErrorHandlerService.ThrowError(code)`) — user-facing
  error text managed as data, not string literals.
- **Modern SDK-style csproj + NuGet plugin package** (`Microsoft.PowerApps.MSBuild.Plugin`), assembly
  signing, and a `DevMode` suffix toggle so a dev build can coexist with the release assembly on one org.
- **`TrackedAttribute<T>`** is a genuinely useful Pre/Target/Post change-tracking helper.
- **A real integration-test project** exists (`Tests.Integration`), which the live-delivery source lacks.

**Weaknesses**
- **No enforced data/business separation.** `Services` hold a raw `IOrganizationService` and call CRUD
  directly (`AccountService.CreateAccount`); `DataQueries` vs `Services` is a folder convention. A junior
  dev will put a `RetrieveMultiple` in a "service" and nothing stops them. Weaker than the live-delivery source's model.
- **Services are testable only by mocking the SDK service**, not a repository interface — coarser, and
  couples every unit test to SDK plumbing.
- **Much of the surface is example/placeholder.** `RecordValidation/*` and `CustomerConfiguration` carry
  `TODO`s; tests cover only the sample `Account`. Impressive breadth, thin depth.
- **`AssemblyVersion` pinned `1.0.0.0`** (`HSO.Customer.Plugins.Package.csproj:8`) — the same "version is
  meaningless, use modified-date/functional test" trap the live-delivery source's memory notes call out.
- FetchXML-as-interpolated-string is injection-adjacent if any value ever comes from user input (here
  values are GUIDs/known, so low risk, but the pattern is copy-paste-risky).

### The live-delivery source

**Strengths**
- **Textbook 4-layer separation with compile-enforced dependency direction** and a written
  ZERO-TOLERANCE rule for data access in BL. This is the most maintainable, most testable shape.
  (`references/architecture.md`, `hso-plugin-development` SKILL.)
- **Repository pattern with interfaces** → BL unit tests mock repos, run in milliseconds, need no
  FakeXrmEasy. (`AIQuoteOpenAdvanceServiceTests`, `RepositoryBase.cs`, `IRepositoryBase.cs`.)
- **Composition-root-in-plugin** is correct DI without a container — explicit, sandbox-safe.
- **Production-hardened patterns**: optimistic-concurrency compare-and-swap on `RowVersion`
  (`IncidentAIQuoteStatusRepository`), Custom-API output-on-every-path discipline, deliberate opt-in
  param semantics to defeat the Power Automate "sends false for every blank" trap
  (`GetCaseConversationPlugin.cs:24`). This is real, battle-tested code, not scaffolding.
- **`OperationResult<T>`/`ValidationResult`** give a clean non-exception result contract.
- **Two focused test projects** and a strict, documented test workflow.

**Weaknesses**
- **No `PluginBase` → boilerplate everywhere.** Every handler re-extracts context, re-writes the
  try/catch envelope, and re-implements `GetString/GetInt/GetBool`. ~15–25 lines of ceremony per plugin
  that a base class would delete.
- **Imperative registration is fragile and off-source.** Step message/stage/mode/filtering live in
  script invocations and human runbooks, not next to the code. The MEMORY notes are full of
  "deploy-gap" incidents (component not in the wave, step not registered) that a declarative,
  reflected-from-source model would make far harder to get wrong.
- **Old-style csproj + `packages.config`** is a maintenance tax: manual `<Compile Include>` per file
  (easy to forget — a known build-failure mode in the skill), brittle `HintPath`s, and explicit binding
  hacks (`System.Threading.Tasks.Extensions` v4.2.0.1 comment in the test csproj). `dotnet test` doesn't
  work at all.
- **No error catalogue, no `ILogger`/App Insights, no delta tracing** — telemetry is trace-only despite a
  rich telemetry SOP existing.
- **No integration-test project.**
- **`SignAssembly=false`** on all production assemblies; plugin package version is hand-bumped in the
  nuspec.

---

## 3. Which Approach Wins, Per Axis

| Axis | Winner | Why |
|---|---|---|
| **Step/API registration** | **CDX** | Declarative `[PluginStep]`/`[CustomApi]` reflected by `Deploy-Package.ps1` keeps registration in source, diffable and idempotent; the live-delivery source's imperative scripts drift and caused repeated deploy-gap incidents. |
| **Layer separation** | **live-delivery source** | True 4-layer with a separate Data project and interface-segregated repos; CDX blurs data access into "services." |
| **Testability** | **live-delivery source** | Mocking repo interfaces beats mocking the raw SDK service; pure fast BL tests. CDX wins only on *having* an integration project. |
| **Dependency injection** | **live-delivery source** | Composition-root-in-plugin with interface-only service ctors is proper DI; CDX composes but passes concrete SDK services. |
| **Plugin base / context abstraction** | **CDX** | `PluginBase` + `ILocalPluginContext` + extensions remove boilerplate the live-delivery source repeats by hand. |
| **Maintainability** | **live-delivery source (design) + CDX (tooling)** | the live-delivery source's layering is more maintainable; CDX's SDK-style csproj + NuGet package + signing is more maintainable to *build*. Split decision. |
| **Onboarding** | **live-delivery source** | The `hso-plugin-development` skill + explicit rules make the intended shape learnable; but CDX's attributes make *registration* self-documenting. |
| **Upgradeability** | **CDX** | SDK-style projects, `PackageReference`, NuGet plugin package, `net471`-on-`net462` are the forward path; the live-delivery source's `packages.config`/old-style is legacy. |
| **Error/telemetry framework** | **CDX** | Error catalogue + `ILogger` + delta tracing vs the live-delivery source trace-only. |
| **Performance / sandbox constraints** | **tie** | Both are sandbox-correct (no container, thread-safe readonly fields, early-bound). CDX adds delta-trace perf visibility; the live-delivery source adds `ExecuteMultiple` reliability judgement and CAS. |

---

## 4. Best-in-Class Recommendation (target server architecture)

**Merge the live-delivery source's 4-layer/repository/DI discipline with CDX's `PluginBase`, declarative registration,
error framework, telemetry, and modern build.** Concretely:

### 4.1 Project / layer layout (SDK-style, `net471` targeting `net462` IL)

```
Server/<Sln>.sln
├── <Ns>.Tables            (L1) early-bound entities + option sets + HSO error-catalogue entities
├── <Ns>.Data              (L2) IRepositoryBase<T> + RepositoryBase<T> + per-entity repos/interfaces,
│                               gateways (HTTP/external), EnvironmentVariableRepository
├── <Ns>.BusinessLogic     (L3) platform-agnostic services (repo interfaces only), Models (DTO/Result),
│                               validators, ErrorCatalogueService
├── <Ns>.Plugins           (L4) PluginBase + ILocalPluginContext + extensions + Registration attributes
│                               + thin IPlugin/Custom-API handlers; BUILDS the NuGet plugin package
├── <Ns>.Tests             unit — xUnit or NUnit + Moq (mock repo interfaces + IServiceProvider)
└── <Ns>.Tests.Integration live-Dataverse round-trips (ServiceClient + appsettings.json, excluded from CI gate)
```

Keep the live-delivery source's **compile-enforced dependency direction** `Plugins → BusinessLogic → Data → Tables`, and
its **ZERO-TOLERANCE "no CRUD in BusinessLogic"** rule (the one axis where CDX is weaker). Adopt CDX's
**SDK-style csproj + `PackageReference` + `Microsoft.PowerApps.MSBuild.Plugin`** for every project,
plus assembly signing and the `DevMode` coexistence toggle — retire `packages.config`, `nuget.exe`
targets, `<Compile Include>` lists, and `HintPath`s.

### 4.2 Plugin base + context extensions

Adopt CDX's `PluginBase`/`ILocalPluginContext`/`LocalTracingService`/`LocalPluginContextExtensions`
**as-is** (they are the Microsoft shape, hardened): entry/exit + delta tracing, fault→
`InvalidPluginExecutionException` translation, `PluginUserService`/`InitiatingUserService`/
`AdminService()`, `ILogger`, and generic `Target<T>/Pre/Post/GetCustomApiParameter`. Handlers become
the **composition root** exactly as the live-delivery source does today, but now inside `ExecuteDataversePlugin(context)`:

```csharp
[PluginStep(PluginStepMessage.Update, EntityLogicalName="incident",
    Stage=PluginStepStage.PreOperation, Mode=PluginStepMode.Synchronous,
    FilteringAttributes="hso_aiquotestatus")]
public class StampAIQuoteStatusTimestamp : PluginBase
{
    public StampAIQuoteStatusTimestamp() : base(typeof(StampAIQuoteStatusTimestamp)) { }
    protected override void ExecuteDataversePlugin(ILocalPluginContext ctx)
    {
        var repo = new IncidentRepository(ctx.PluginUserService, ctx.TracingService);   // L2
        var svc  = new AIQuoteStatusTimestampService(repo, ctx.TracingService);          // L3
        svc.StampTransition(ctx.Target<Incident>(), DateTime.UtcNow);
    }
}
```

This deletes the live-delivery source's per-plugin boilerplate while keeping its DI + layering.

### 4.3 Registration model — DECLARATIVE (recommended), deployed by reflection

Adopt CDX's attribute model wholesale: `[PluginStep(...)]` (multi-instance), `[CustomApi]` +
`[CustomApiRequestParameter]` + `[CustomApiResponseProperty]`, backed by `PluginStepMessage`/
`PluginStepEnums`. **How it deploys:** a `Deploy-Package.ps1`-style step (folded into the release
pipeline) pushes the `.nupkg`, reflects over the built DLL, and **idempotently upserts** `plugintype`,
`customapi(+request/response params)`, and `sdkmessageprocessingstep`, then `AddSolutionComponent`s
everything into the ticket/wave solution. Benefits directly addressing the live-delivery source's documented pain:
registration is in source, code-reviewed, drift-proof, and the "component not in the wave / step not
registered" deploy-gaps become detectable at build time.

Keep the two hard-won rules from the live-delivery source as attribute-level guardrails: a Custom-API handler is attached via
`customapi.plugintypeid` and **must not** also get an SDK step (double-execution), and step images are
declared alongside the step. (Add `[PluginStepImage]` to round out the attribute set — neither repo has
it yet; it is the obvious gap.)

### 4.4 Services / repository layer

the live-delivery source's `RepositoryBase<T>`/`IRepositoryBase<T>` + per-entity interfaces is the base. Fold in CDX's
`BaseDataverseService<T>` value-adds as **opt-in helpers on the repository base**, not on services:
`TrackedAttribute<T>` change tracking, `GetChangedAttributes`, `SetAttributeIfChanged`, `BulkCreate/
Update/Execute`, `ExecuteMultipleUpsertRequest`, and `EntityExtensions` (`GetAliased<T>`,
`TraceAttributes`, `UpsertByFields`). Services keep taking **interfaces only** and returning
`OperationResult<T>`/`ValidationResult` (live-delivery source) rather than only throwing.

### 4.5 Configuration

Env vars via a Data-layer `EnvironmentVariableRepository` (the live-delivery source's location) using CDX's
definition↔value FetchXML join. Keep config-rule/JSON validation as an **optional** module (CDX's
`RecordValidation`) — finish or drop the `TODO`s before shipping it in the template.

### 4.6 Error / telemetry framework

- Adopt CDX's **error catalogue** (`hso_error`/`hso_errorarea`/`hso_errorkind`/`hso_errorsystem`/
  `hso_system` entities + `ErrorCatalogueService.ThrowError(code)`) so user-facing text is data.
- Adopt CDX's **delta-timed `LocalTracingService`** and **`ILogger`/PluginTelemetry** wiring; then layer
  the live-delivery source's telemetry SOP on top (App Insights per-env trace policy Dev=All / Test/UAT/Prod=Exception,
  KQL workbook, SLOs: sync P95 ≤ 1 s, depth ≤ 4, failure ≤ 0.1 %).

### 4.7 Unit + integration test strategy

- **Unit (CI gate):** mock **repository interfaces** (live-delivery source) for BL logic + mock `IServiceProvider` for
  plugin wiring shells (live-delivery source `StampAIQuoteStatusTimestampTests` pattern). Moq throughout. Pick **one**
  framework — NUnit (live-delivery source) or xUnit (CDX); NUnit is the incumbent across HSO tooling, so standardize on
  **NUnit 3 + NUnit3TestAdapter**, run via `vstest.console.exe`.
- **Integration (nightly / opt-in, excluded from PR gate):** CDX's `Tests.Integration` shape —
  `ServiceClient` + `appsettings.json`, create→retrieve→delete round-trips with best-effort cleanup.
- Optionally add **FakeXrmEasy** for repository-level tests (the skill already references it).

### 4.8 .NET target + key NuGet dependencies

- **Target:** `net471` (loads on the sandbox's `net462` runtime; matches both repos). SDK-style
  projects, sign all assemblies.
- **Plugins project:** `Microsoft.CrmSdk.CoreAssemblies` (`PrivateAssets=All`),
  `Microsoft.PowerApps.MSBuild.Plugin`, `Microsoft.NETFramework.ReferenceAssemblies`, `Newtonsoft.Json`
  (`13.0.3`).
- **Data/BusinessLogic:** `Microsoft.CrmSdk.CoreAssemblies` (+ `Newtonsoft.Json` where needed).
- **Tests:** `Microsoft.NET.Test.Sdk`, `NUnit` + `NUnit3TestAdapter`, `Moq`, `coverlet.collector`,
  optionally `AutoFixture` (CDX) and `FakeXrmEasy`.
- **Tests.Integration:** `Microsoft.PowerPlatform.Dataverse.Client` +
  `Microsoft.Extensions.Configuration.Json`.

---

## 5. Things the User May Have Missed (keep these)

1. **Declarative registration + reflection deploy (CDX).** The highest-leverage pattern in either repo
   and the direct antidote to the live-delivery source's recurring deploy-gap incidents. A brief that just says "port the
   live-delivery source's plugins" would lose it.
2. **`[PluginStepImage]` attribute — the missing piece.** Neither repo declares images in source. Add it
   so pre/post images are code-reviewed and reflected alongside steps.
3. **The error catalogue (`HSo_Error*`).** Data-driven user-facing error text is easy to overlook and
   expensive to retrofit.
4. **`ILogger`/PluginTelemetry + delta tracing (CDX).** Real App Insights logging vs trace-only; pairs
   with the existing telemetry SOP.
5. **A real integration-test project (CDX).** The live-delivery source has none; live round-trips catch what mocks cannot.
6. **`TrackedAttribute<T>` + `UpsertByFields` + `GetAliased<T>` (CDX).** Genuinely reusable; keep as
   repository-layer helpers.
7. **`DevMode` assembly-suffix toggle (CDX).** Lets a dev build coexist with the release assembly on one
   org — quietly valuable for the shared-clone, multi-session way this team works.
8. **The live-delivery source's production hard-won specifics:** `RowVersion` compare-and-swap, Custom-API
   output-on-every-path, opt-in param semantics against the Power-Automate "false-for-blank" trap, and
   the do-not-register-a-step-on-a-Custom-API rule. Bake these into the template's example handlers and
   the skill, not just prose.
9. **Assembly signing + moving off `packages.config`.** The live-delivery source ships unsigned, old-style; the template
   should sign and be SDK-style from day one.
10. **Don't ship CDX's `RecordValidation`/`CustomerConfiguration` `TODO`s as-is** — finish or omit.

---

## Recommended Server Architecture

### Directory / project tree

```
Server/<Ns>.D365.sln
├── <Ns>.Tables            L1  Early-bound entities, option sets, HSo_Error* catalogue        [from the live-delivery source layout + CDX error entities]
├── <Ns>.Data              L2  IRepositoryBase<T>, RepositoryBase<T>, per-entity repos+ifaces,
│                              gateways, EnvironmentVariableRepository                          [from the live-delivery source]
├── <Ns>.BusinessLogic     L3  Services (repo interfaces only), Models(DTO/OperationResult),
│                              validators, ErrorCatalogueService                               [live-delivery source layering + CDX error/validation]
├── <Ns>.Plugins           L4  PluginBase, ILocalPluginContext(+extensions), LocalTracingService,
│                              Registration/[PluginStep|CustomApi|StepImage], thin handlers,
│                              builds the NuGet plugin package                                  [from CDX]
├── <Ns>.Tests             Unit: NUnit + Moq (mock repo interfaces + IServiceProvider)         [live-delivery source test style]
└── <Ns>.Tests.Integration Live Dataverse: ServiceClient + appsettings.json round-trips        [from CDX]

Scripts/Deploy-Package.ps1  push .nupkg → reflect DLL → idempotent upsert plugintype/customapi/
                            step(+image) → AddSolutionComponent to ticket/wave solution         [from CDX]
```

### Decision table (concern → chosen approach → source → why)

| Concern | Chosen approach | From | Why |
|---|---|---|---|
| Project style / build | SDK-style csproj, `PackageReference`, NuGet plugin package, signed, `DevMode` toggle | CDX | Modern, upgradeable; kills `packages.config`/`<Compile Include>`/`HintPath` tax |
| Layering | 4-layer, compile-enforced `Plugins→BusinessLogic→Data→Tables`, no CRUD in BL | live-delivery source | Maximum separation + testability |
| Data access | `RepositoryBase<T>` + `IRepositoryBase<T>` + per-entity interfaces | live-delivery source | Interface-segregated, mockable |
| Repo helpers | `TrackedAttribute<T>`, Bulk*, `UpsertByFields`, `GetAliased<T>` | CDX | Reusable value-adds, moved onto repo base |
| Service contract | Interface-only ctors returning `OperationResult<T>`/`ValidationResult` | live-delivery source | Platform-agnostic, non-exception results |
| DI | Composition-root-in-plugin (no container) inside `ExecuteDataversePlugin` | live-delivery source + CDX base | Sandbox-safe explicit DI, minus the boilerplate |
| Plugin base/context | `PluginBase` + `ILocalPluginContext` + extensions + delta tracing | CDX | Removes the live-delivery source's per-plugin ceremony |
| **Step/API registration** | **Declarative attributes reflected + idempotently upserted by a pipeline deploy step** | **CDX** | **In-source, diffable, drift-proof; fixes deploy-gaps** |
| Step images | New `[PluginStepImage]` attribute, reflected with steps | new (gap in both) | Images become code-reviewed |
| Custom API rules | Attach via `customapi.plugintypeid`, never an SDK step; output on every path | live-delivery source | Avoids double-exec; robust outputs |
| Configuration | Env vars via Data-layer repo (def↔value join); optional JSON rule engine | live-delivery source + CDX | Consistent layering; validation optional |
| Error text | `HSo_Error*` catalogue + `ErrorCatalogueService.ThrowError(code)` | CDX | User-facing text as data |
| Telemetry | `ILogger`/PluginTelemetry + delta tracing + App Insights SOP (Dev=All/UAT+Prod=Exception, KQL, SLOs) | CDX + live-delivery source SOP | Real observability |
| Unit tests | NUnit + Moq, mock repo interfaces + `IServiceProvider`, `vstest.console.exe` | live-delivery source | Fast, pure, sandbox-agnostic |
| Integration tests | `ServiceClient` + `appsettings.json`, excluded from PR gate | CDX | Catches what mocks cannot |
| Target framework | `net471` (runs on sandbox `net462`), all assemblies signed | both | Compatible + upgradeable |

### Registration model, spelled out

1. **Author:** decorate each handler with `[PluginStep(message, EntityLogicalName, Stage, Mode,
   FilteringAttributes, ExecutionOrder, …)]` (multi-instance for multi-message) and, for Custom APIs,
   `[CustomApi]` + `[CustomApiRequestParameter]` + `[CustomApiResponseProperty]`; declare images with the
   new `[PluginStepImage]`. Use `PluginStepMessage`/`PluginStepEnums` constants.
2. **Build:** SDK-style Plugins project emits the signed `.nupkg` (`Microsoft.PowerApps.MSBuild.Plugin`).
3. **Deploy (pipeline step, idempotent):** push the `.nupkg`; reflect over the built DLL; upsert
   `plugintype`, then `customapi`(+request/response params), then `sdkmessageprocessingstep`(+images) via
   the Web API; `AddSolutionComponent` each into the ticket/wave solution. Re-runs update, never
   duplicate.
4. **Guardrails:** a Custom-API handler is attached via `customapi.plugintypeid` and gets **no** SDK
   step; the reflection deploy can assert every reflected component landed in a deployed wave (turning the
   MEMORY "orphaned component" checks into a build-time gate).

---

## Summary (recommended architecture, ~350 words)

The two repos are complementary, not competing. **The live-delivery source** contributes the *shape*: a strict, 4-layer,
compile-enforced architecture — `Plugins → BusinessLogic → Data → Tables` — where business services
depend only on repository **interfaces** and are forbidden from touching `IOrganizationService` CRUD.
That yields the best testability (mock a repo, not the SDK), the cleanest DI (each plugin is the
composition root), and it is proven in production (row-version compare-and-swap, Custom-API
output-on-every-path, deliberate opt-in param semantics). **CDX** contributes the *machinery*: a mature
`PluginBase`/`ILocalPluginContext` with delta-timed tracing, `ILogger` App-Insights logging and
`PluginUserService`/`AdminService` helpers; a **declarative registration model** (`[PluginStep]`/
`[CustomApi]` attributes reflected and idempotently upserted at deploy) that keeps registration in
source and drift-proof; a **data-driven error catalogue** (`HSo_Error*` + `ThrowError(code)`); modern
SDK-style csproj with a NuGet plugin package, signing and a dev/release coexistence toggle; and a real
integration-test project.

The best-in-class template keeps the live-delivery source's layering, repository interfaces, DI, `OperationResult<T>`
contracts and test discipline, and grafts on CDX's `PluginBase`, declarative registration + reflection
deploy, error framework, telemetry and modern build. Handlers become thin composition roots inside
`ExecuteDataversePlugin`, deleting the live-delivery source's per-plugin boilerplate while preserving its architecture.
Target `net471` (runs on the sandbox's `net462` IL), sign everything, standardize on NUnit + Moq +
`vstest.console.exe` for unit tests and `ServiceClient` + `appsettings.json` for integration tests.

**Top 5 decisions:**
1. **Layering & DI from the live-delivery source** — 4-layer, interface-segregated repositories, no CRUD in BusinessLogic,
   composition-root-in-plugin.
2. **`PluginBase`/`ILocalPluginContext` from CDX** — remove the live-delivery source's repeated context/try-catch/param
   boilerplate.
3. **Declarative registration from CDX** — `[PluginStep]`/`[CustomApi]` (+ a new `[PluginStepImage]`)
   reflected and idempotently deployed; fixes the live-delivery source's recurring "component not in wave / step not
   registered" deploy-gaps.
4. **Error catalogue + `ILogger`/delta telemetry from CDX**, layered with the live-delivery source's App-Insights/KQL/SLO
   SOP.
5. **Modern SDK-style build + signing + integration tests from CDX**, retiring the live-delivery source's `packages.config`
   and manual `<Compile Include>`/`HintPath` machinery.
