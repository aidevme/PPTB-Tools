# Onboarding — Client (TypeScript form scripts & Rule Engine)

Read this to become productive in the client layer in under an hour. It assumes TypeScript and
basic Dataverse form-scripting concepts. Deeper rationale is in
[ADR-0005](../decisions/ADR-0005-client-architecture.md); the reference is
[`ProjectTemplate/Client/clientjs/README.md`](../../ProjectTemplate/Client/clientjs/README.md).

Everything below lives in `ProjectTemplate/Client/clientjs/`.

## 1. The mental model

Most form logic is **data, not code**. A form's OnLoad handler is thin boilerplate that hands
off to the **Rule Engine**, which loads a JSON file of rules from a web resource and applies
them:

```
Form OnLoad ─▶ HSO.<Form>.onFormLoad ─▶ RuleEngine.initialize(ctx, {formName})
                                          ├─ loads hso_customer_/rules/<Entity>/<Form>/<form>.json + .xml
                                          ├─ privilege gate (skip by security role)
                                          └─ 5 processors in order:
                                             Concatenation → CopyLookup → FormComponent
                                             → OptionSetFilter → LookupFilter
```

You write imperative TypeScript only for what the engine deliberately does NOT cover
(notifications, save-time validation, Custom API calls, ribbon logic).

Four non-negotiables (all enforced by tooling):
1. **Console-free.** Never `console.*`. Use `Logger` (it buffers + an optional sink). ESLint
   `no-console` fails the build otherwise — and so does the Solution Checker at import.
2. **`formContext`, never `Xrm.Page`.** ESLint blocks `Xrm.Page`.
3. **Fail-open.** An OnLoad handler must never throw and block a form load — wrap in try/catch.
4. **Paired rules.** Every show/require/enable FormComponentRule needs its inverse
   (`npm run validate:rules`).

## 2. Walk the example slice

Open these, in order, and you've seen the whole pattern:

1. `src/Forms/Account/AccountForm.ts` — the thin, fail-open handler. Note it passes
   `{ formName: "AccountForm" }` **explicitly** (never `ClassName.name` — webpack minifies it).
2. `src/Rules/Account/AccountForm/accountForm.json` — the rules. This is the **canonical PAIRED
   sample**: "show credit limit for large customers" is matched by "hide credit limit for small
   customers". Copy this shape.
3. `src/Rules/Account/AccountForm/accountForm.xml` — the FetchXML templates the lookup-filter
   rule uses.
4. `src/index.ts` — the barrel that re-exports handlers onto `window.HSO` (via webpack
   `assign-properties`).
5. `src/Helpers/Logger.ts` — the no-console sink. Read the header for WHY.
6. `src/RuleEngine/validation/PairedInverseValidator.ts` — the invariant, in code.

`src/Rules/TestRule/…` is an exhaustive **capability catalogue** of every rule shape — use it to
look up JSON syntax, but note it is deliberately NOT paired-inverse-correct (do not copy it as a
production form).

## 3. Add a new form

1. `src/Forms/<Entity>/<Form>.ts` — copy `AccountForm.ts`, rename the class, set the explicit
   `formName`. Export it from `src/index.ts`.
2. `src/Rules/<Entity>/<Form>/<form>.json` (+ `.xml` if you use lookup filters). Keep every
   FormComponentRule **paired**.
3. Add an entry to the `deployment.rules` array in `powerPlatform.config.template.json` (entity,
   form, and the `hso_customer_/rules/<Entity>/<Form>/<form>.json|.xml` web-resource names).
4. Write a handler test under `Forms/<Entity>/__tests__/` (copy `AccountForm.test.ts`).
5. In D365: register `HSO.<Form>.onFormLoad` on the form's OnLoad, "pass execution context" checked.

## 4. The commands

```bash
npm install            # restore deps (first time, per worktree)
npm run typecheck      # tsc --noEmit (checks src + tests)
npm run lint           # ESLint = the Solution Checker rule list; must be 0 errors
npm test               # jest + coverage thresholds (branches70/functions95/lines85/statements70)
npm run validate:rules # the paired-inverse gate over the sample rule JSON
npm run build          # prod bundle → dist/HSO_Customer_clientHooks.js (minified, console-free)
npm run build:dev      # dev bundle with source maps
```

Deploy (Dev only) with `Scripts/push-webresources.ps1` after copying
`powerPlatform.config.template.json` → `powerPlatform.config.json` (git-ignored) and filling in
your environment URL / solution.

## 5. Logging without console

```typescript
import { Logger } from "../../Helpers/Logger";

Logger.info("[MyForm]", "loading...");        // buffered; silent unless a sink is installed
Logger.getBuffer();                            // inspect records by hand while debugging
Logger.setSink((r) => { /* surface via formContext.ui, NEVER console.* in shipped code */ });
```

The default sink is unset, so a shipped bundle emits nothing and passes Solution Checker
`remove-console`. The jest setup installs a console-mirroring sink so tests can assert on
`console.*`.

## 6. Regenerating early-bound types

`src/dataverse-gen/` is generated from Dataverse metadata via `dataverse-gen` using
`.dataverse-gen.json` (entities to generate). Regenerate it when the schema changes — treat the
output as a build artifact that happens to be committed, and never hand-edit it (it is
lint- and coverage-excluded).

## 7. Common pitfalls

- **Single-direction rule.** A rule that hides a field with no partner that shows it strands the
  field hidden for every other value. `npm run validate:rules` catches this — run it.
- **`ClassName.name` for formName.** Minification changes it at runtime; always pass the literal.
- **A second HSO bundle on the form.** Safe here — `assign-properties` merges onto `window.HSO`.
  (This is why we do NOT use `libraryTarget:"var"`.)
- **Quick Create forms.** `formSelector.getCurrentItem()` returns null; the explicit `formName`
  override is what makes the config path resolve.
