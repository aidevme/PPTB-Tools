# Onboarding — PCF controls

How to build, test, and ship a PCF control in this template. Read `ADR-0006-pcf-architecture.md` for
the *why*; this is the *how*. The controls live in `ProjectTemplate/PCFControls/`.

## 0. Prerequisites

- Node 18+ (built/verified on Node 22), npm 9+.
- `pac` CLI (Power Platform CLI) for deploys — path is in your `CLAUDE.local.md`.
- Never `pac pcf push` anywhere but **Dev**, and verify `pac auth list` targets Dev first.

## 1. The layout

```
PCFControls/
├── pcf-core/                 shared helper library (compiled file: package) — you rarely edit this
├── scaffold-field/           copy this for a bound field control
├── scaffold-virtual-card/    copy this for a card that persists via the Web API
├── scaffold-dataset/         reference stub for a grid control (promote when needed)
├── test-harness/             mockPcfContext.ts
├── formscripts/tabStateSync.js
├── tools/Verify-DeployedBundle.ps1
├── GOTCHAS.md                READ THIS — the G1–G11 checklist
└── solution/README.md        publisher/wave discipline
```

## 2. Scaffold a new control

1. **Copy the closest scaffold** to a new folder named for your control:
   ```bash
   cp -r scaffold-field/CustomerChoiceField scaffold-field/CustomerContactBadge
   ```
   Use `scaffold-virtual-card` instead if the control persists its own state via `context.webAPI`
   (i.e. `getOutputs()` will return `{}`) — that's the case that needs the store repaint (G1).

2. **Rename** — the control name appears in several places; change all of them:
   - the project folder and the inner source folder (both were `CustomerChoiceField`);
   - `<Name>.pcfproj` → `<NewName>.pcfproj`, and its `<Name>` element + a fresh `<ProjectGuid>`;
   - `ControlManifest.Input.xml` → `constructor="<NewName>"` and the `*_DisplayName`/`*_Description`
     keys (keep `namespace="Customer"` — the token is rewritten at init, ADR-0003);
   - the `.resx` keys to match;
   - `package.json` `name`.

3. **Provision + generate types + build**:
   ```bash
   cd scaffold-field/CustomerContactBadge
   npm ci                 # builds pcf-core dist + symlinks it (its prepare script), installs deps
   npm run refreshTypes   # generates generated/ManifestTypes from the manifest
   npm run build          # pcf-scripts PRODUCTION build → out/controls/<Name>/bundle.js
   npm test               # vitest (services + components)
   ```

> `node_modules` and `generated/` are gitignored — a fresh worktree needs `npm ci` + a build before the
> types exist. This is expected.

## 3. The lifecycle contract (both scaffolds)

```
init(context, notifyOutputChanged, state):
  synchronous only; new TypedWebApi(context.webAPI); subscribe sync buses; create the deferred reads.
updateView(context) -> ReactElement:
  this.context = context; deferredRead.maybeStart();          // late-start once an id appears (G5)
  if (getHostId(context) === null) return <FluentRoot><PreviewCard/></FluentRoot>;   // design-time (G5)
  parse context.parameters.*.raw defensively; adopt sibling state (G6);
  return <FluentRoot><LiveState store render=…/></FluentRoot>; // store-driven subtree repaints (G1)
getOutputs():
  return the bound outputs — OR {} if you persist via webAPI (then the store handles repaint).
destroy():
  bag.dispose();  // clears every timer, unsubscribes every bus, flips `disposed`
```

## 4. The repaint model — the one thing to get right (G1)

- If your control has a **bound output** (a value that rides `getOutputs()`), a change + `getOutputs()`
  reliably forces `updateView`. The **field** scaffold uses this.
- If your control **persists via `context.webAPI`** and `getOutputs()` returns `{}`, the platform
  **DROPS `notifyOutputChanged`** — it never repaints from a notify. Put the UI state in a
  `createStore()` and render the store-driven part inside `<LiveState>`; call `store.set(...)` after
  the write. The **card** scaffold demonstrates this (`onAcknowledge`).
- **Cross-tab** repaint (a value changing on another form tab) is neither of those — use the
  `formscripts/tabStateSync.js` recipe (add the column as a HIDDEN field first — G3).

## 5. Testing

- `npm test` runs vitest with jsdom. Keep pure logic in `services/` (no React/PCF imports) and test it
  directly; test components with `@testing-library/react`; use `test-harness/mockPcfContext.ts` for a
  fake `context` (incl. a stub `webAPI`) to drive lifecycle-level tests.
- **First run is slow** (~1–2 min): Fluent v9 is transformed for jsdom. This is because React 16.14 has
  no package `exports` map for the `react/jsx-runtime` subpath Fluent's `@griffel/react` imports, so
  `vitest.config.ts` aliases it and inlines `@fluentui`/`@griffel` so Vite (not native ESM) resolves
  it. Don't remove that config.
- Never rely on `pcf-start` for automated tests — its mock WebApi pops blocking `alert()`s (G7).

## 6. Deploy (Dev only from a dev machine)

```bash
# verify the connection targets DEV first
pac auth list                         # confirm the * row is the Dev org URL
npm run build
pac pcf push --publisher-prefix hso   # publisher is FIXED for the control's life (solution/README.md)
# then PROVE the fix is in the deployed bundle (a higher version is NOT proof — G2):
pwsh ../../tools/Verify-DeployedBundle.ps1 -EnvironmentUrl <dev-url> \
     -ControlNameLike CustomerContactBadge -Needle "<a string unique to your change>" -AccessToken <tok>
```

Promotion Dev → UAT → Prod is the human-run release pipeline only. Ensure the control is in a deployed
**PCF wave** solution, not just its ticket solution (`solution/README.md`) — otherwise it silently
never ships.

## 7. `pac pcf init` traps this template already avoids

- Fluent **9.68.0** (unresolvable) — the scaffolds ship **9.46.2** (G8).
- **dev** build mode on `pac pcf push` — the `.pcfproj` pins `PcfBuildMode=production` (G8).
- Missing `<feature-usage>` → runtime crash — declared per the APIs each scaffold calls (G10).
- No design-time guard → "Error loading control" — the `PreviewCard` guard is built in (G5).

## 8. Adding early-bound Dataverse types (optional, recommended for larger Web API surfaces)

The `TypedWebApi` wrapper is generic over an entity interface. For a handful of columns, hand-write the
interface (see `scaffold-virtual-card/.../services/dataverse.ts`). For more, run `dataverse-gen`
(matches the Client layer): edit the control's `.dataverse-gen.json`, run `npx dataverse-gen`, and swap
`defineTable<HandWritten>(…)` for the generated type.
