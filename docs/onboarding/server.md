# Onboarding — Server (Dataverse plug-ins & services)

Read this to become productive in the server layer in under an hour. It assumes C# and basic Dataverse plugin
concepts. Deeper rationale is in [ADR-0004](../decisions/ADR-0004-server-architecture.md); the reference is
[`ProjectTemplate/Server/README.md`](../../ProjectTemplate/Server/README.md).

## 1. The mental model

Four layers, dependencies point **one way only**:

```
Plugins (L4) ──▶ BusinessLogic (L3) ──▶ Data (L2) ──▶ DataverseModel (L1)
```

- **L1 DataverseModel** — early-bound entities (`hso_customer_widget`, the `hso_customer_error*` catalogue).
  Regenerated with `pac modelbuilder` in a real project.
- **L2 Data** — repositories. **The only place `IOrganizationService` does CRUD.** Every repo has an interface.
- **L3 BusinessLogic** — the rules. Services take repo **interfaces**, never `IOrganizationService`. They return
  `OperationResult<T>` / `ValidationResult`. This is where "the thinking" lives, and it's unit-tested with mocks.
- **L4 Plugins** — thin handlers over `PluginBase`. Each is a **composition root**: it news up the repo and the
  service and hands off. No business logic here.

The golden rule you must not break: **no `Retrieve/Create/Update/Delete` and no `IOrganizationService` in
BusinessLogic.** A test (`LayeringTests`) fails the build if you do.

## 2. Walk the example slice

Open these, in order, and you've seen the whole pattern:

1. `DataverseModel/Entities/hso_customer_widget.cs` — an early-bound entity.
2. `Data/Repositories/WidgetRepository.cs` — projection query, aggregate count, and `UpdateIfUnchanged` (CAS).
3. `BusinessLogic/Services/Widget/WidgetService.cs` — repo interface in, `OperationResult<WidgetSummary>` out.
4. `BusinessLogic/Services/Widget/WidgetValidationService.cs` — pure rules, no data access.
5. `Plugins/Plugins/Widget/Widget_ValidateAndStamp.cs` — the plugin composition root + a `[PluginStepImage]`.
6. `Plugins/CustomApis/GetWidgetSummary.cs` — a Custom API composition root.
7. `Tests/**` — how each of the above is tested.

## 3. Do the common tasks

### Add a plugin
```csharp
[PluginStep(PluginStepMessage.Create, EntityLogicalName = "hso_customer_thing",
    Stage = PluginStepStage.PreOperation, Mode = PluginStepMode.Synchronous)]
public sealed class Thing_PreCreate : PluginBase
{
    public Thing_PreCreate() : base(typeof(Thing_PreCreate)) { }
    protected override void ExecuteDataversePlugin(ILocalPluginContext ctx)
    {
        var repo = new ThingRepository(ctx.PluginUserService, ctx.TracingService); // L2
        var svc  = new ThingService(repo, ctx.TracingService);                     // L3
        // ... svc.DoWork(ctx.Target<hso_customer_thing>());
    }
}
```
Then add a wiring test using `PluginTestContext` (see `Tests/Plugins/`).

### Add a Custom API
Same, but decorate with `[CustomApi("hso_customer_DoThing")]` + `[CustomApiRequestParameter]` /
`[CustomApiResponseProperty]`, and set every declared output on success. **Never** also add a `[PluginStep]`
for the API's own message — it would run twice.

### Add a step image (in source)
Add `[PluginStepImage(PluginStepImageType.PreImage, Attributes = "hso_customer_status", ForMessage = "Update")]`
to the plugin. Read it with `ctx.PreImage<hso_customer_widget>()`.

### Add a repository method
Add to the interface (`IThingRepository`) first, then implement. Business logic depends on the interface, so a
test mocks it.

### Throw a catalogued error
`new ErrorCatalogueService(new ErrorCatalogueRepository(svc, tracing), tracing).ThrowError("THING_001");`
— the user message comes from the `hso_customer_error` row, editable without a redeploy.

## 4. Build, test, deploy

```bash
dotnet build HSO.Customer.D365.sln -c Release
dotnet test  HSO.Customer.Tests/HSO.Customer.Tests.csproj        # must be green before you push
./Scripts/Deploy-Package.ps1                                      # dev org; see Scripts/README.md
```

Integration tests (`Tests.Integration`) need a live org via `appsettings.json` and are `[Explicit]` — they do
not run in the normal `dotnet test`.

## 5. Sandbox gotchas (things that bite)

- **`net471` on `net462`.** No `System.Text.Json`; use `Newtonsoft.Json`. No `async` in the pipeline path.
- **Version is not proof of deployment.** A later push from an older branch can revert a fix while the version
  number stays the same — verify the deployed bundle, not the number.
- **A Custom API plug-in gets no step configuration.** Use an environment variable (see
  `EnvironmentVariableRepository`) for config, not secure/unsecure config.
- **Concurrency.** When two writers race a status change, use `UpdateIfUnchanged` (compare-and-swap) instead of
  a blind `Update` — see `WidgetRepository` and `RepositoryConcurrencyTests`.
- **Trace, don't guess.** `LocalTracingService` prefixes every line with a ms delta — the trace log doubles as a
  performance timeline.

## 6. What "done" looks like

Green build, green `HSO.Customer.Tests`, your new plugin/API declared via attributes (so `RegistrationAttributeTests`
stays green), and — for anything touching data — a BusinessLogic test that mocks the repository. If your change
made you want to put an `IOrganizationService` in a service, stop: the data access belongs in a repository.
