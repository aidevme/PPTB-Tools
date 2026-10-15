---
name: hso-pcf-control-development
layer: atomic
scope: core
description: |
  Build PowerApps Component Framework (PCF) controls from a specification and deploy them with
  pac pcf push. Covers control manifest design (properties, dataset vs field, output), the
  index.ts/React implementation, build, and the publisher-locked deployment path. Use when:
  (1) Building a PCF control from a spec
  (2) Editing a control's manifest, properties, or bundle
  (3) Deploying/pushing a PCF control
  Read hso-template-architecture first. Uses pac pcf push (NOT npm run build) for deployment.
---

# hso-pcf-control-development

Custom UI controls for model-driven forms. Read
[hso-template-architecture](../../foundation/hso-template-architecture/SKILL.md) for the PCF
namespace/publisher lock (a PCF control is bound to the publisher it was created under and cannot be
redeployed through a pipeline under a different publisher).

## Manifest first

Design `ControlManifest.Input.xml` deliberately:

- **Field-bound vs dataset** — pick the binding the form scenario needs.
- **Properties** — name, type (`SingleLine.Text`, `Whole.None`, `Enum`, …), usage (`bound`/`input`),
  required. Bound output properties must be written via `notifyOutputChanged` + `getOutputs`.
- **Resources** — `code`, `css`, `resx`; keep everything inlined/bundled (no external CDN fetches).

## Workflow

1. `pac pcf init` (or edit the existing control under `PCFControls/`). Set namespace/publisher per
   the token contract.
2. Implement `index.ts` (`init`, `updateView`, `getOutputs`, `destroy`); React optional.
3. `npm ci` in the control folder (fresh worktrees have no `node_modules`).
4. Build & test locally (`npm run build`, test harness).
5. **Deploy with `pac pcf push --publisher-prefix {prefix}`** to **Dev only** — never `npm run build`
   as the deploy step.
6. Verify the DEPLOYED bundle content, not just the version — a later push from an older branch can
   revert a fix while leaving a higher version number.
7. **Update the TOPO map** (`hso-architecture-map`): add the `[UC]` block; update the parent `[DE]`.

## Gotchas (hard-won)

- **Publisher lock**: keep a PCF control on one publisher end-to-end; a wave/release aggregator for
  PCF must use the same publisher.
- **getOutputs returning {}** drops `notifyOutputChanged` — internal async state won't repaint via
  notify; drive repaint from a store subscription instead.
- **Version-slot clobber**: deployed version can be higher than a fix yet not contain it — verify the
  bundle, not the number.

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | maciejnowicki | Ported from prior in-house skills; neutralised; retained the publisher-lock, getOutputs, and version-clobber gotchas. |
