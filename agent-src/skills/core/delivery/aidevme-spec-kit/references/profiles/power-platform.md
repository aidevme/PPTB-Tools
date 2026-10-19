# Profile: Power Platform

<!-- cspell:ignore Dataverse speckit -->

Purpose: principles to offer as input to `/speckit-constitution` for Power Platform and Dataverse projects. They're
principles, not a tutorial; fill in the values marked `<…>` with the user.

## Principles

1. **Solution-aware changes only.** Every component is created or changed inside the named unmanaged solution with
   the publisher prefix `<prefix>`. Environments downstream of development receive managed solutions only.
2. **No hard-coded configuration.** URLs, IDs, keys and secrets come from environment variables and connection
   references, never from code, flows or apps.
3. **Dataverse naming and security in the spec.** New tables and columns follow `<prefix>_<name>` naming; the spec
   names the security roles, and any field security profiles, that each new table or column needs.
4. **Stateless plugins within limits.** Plugins keep no state between executions, use the provided services, and
   stay inside the platform's execution time limit; long work moves to asynchronous steps or other services.
5. **PCF manifest and code change together.** `ControlManifest.Input.xml` and `index.ts` change in the same task;
   every new property is documented (name, type, usage).
6. **ALM through pipelines only.** Solutions move between environments through the pipeline; no manual changes in
   production.
7. **A test approach per component type,** named in the plan and the tasks:
   - plugins: unit tests with a mocked execution context;
   - PCF: component tests plus a check in the test harness;
   - flows and apps: documented test runs, including the error paths;
   - solution import: a pipeline run into a test environment.

## How the plan uses it

`/speckit-plan` checks the plan against these principles ([plan.md](../plan.md)). A plan for a PCF feature, for
example, must name the manifest and `index.ts` change, the new properties' documentation, and the solution the
control is packaged in.

## Optional third profile

TODO: `dotnet-plugins` (Dynamics 365 CE C# plugins) is planned and not written yet.
