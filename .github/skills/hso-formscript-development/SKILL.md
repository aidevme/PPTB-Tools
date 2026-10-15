---
name: hso-formscript-development
layer: atomic
scope: core
description: |
  Develop and deploy JavaScript/TypeScript web resources for model-driven app forms. Covers OnLoad /
  OnSave / OnChange handlers, ribbon command scripts, and deploying/publishing web resources to the
  Dev environment for testing. Ensures 100% upgradeability by using ONLY documented Client API
  (formContext, Xrm.WebApi, Xrm.Navigation, Xrm.Utility) — never DOM manipulation, jQuery, or
  internal/undocumented APIs. Use when:
  (1) Creating or editing a form script for a form event
  (2) Writing a ribbon command script
  (3) Deploying/publishing a web resource
  Read hso-template-architecture first.
---

# hso-formscript-development

Client-side form logic that survives platform upgrades. Read
[hso-template-architecture](../../foundation/hso-template-architecture/SKILL.md) for the client
layer, `config.ts`, and the `webResourcePrefix` chain.

## The upgradeability contract (non-negotiable)

Use ONLY documented Client API:

- `formContext` (`getAttribute`, `getControl`, `ui`, `data`) — never `document.*` / DOM.
- `Xrm.WebApi` for data — never unsupported OData endpoints or `XMLHttpRequest` to internal URLs.
- `Xrm.Navigation`, `Xrm.Utility` for dialogs/navigation.
- No jQuery, no internal globals, no `Xrm.Page` (deprecated) in new code — pass `executionContext`
  and derive `formContext`.

A script that touches the DOM or an undocumented API is a defect regardless of whether it "works"
today — it will break on a platform update.

## Workflow

1. **Query live schema** for the fields the script reads/writes — never assume names. Remember a
   PCF-bound or non-form-placed column is NOT on `getAttribute`; add a hidden form field if a script
   must read it.
2. **Write the handler** (TypeScript in `Client/clientjs/src/Forms/<Entity>/`, or a rule config if
   the project uses the JSON RuleEngine). Accept `executionContext`; derive `formContext`.
3. **Build** the client bundle (`npm run build` → `dist/HSO_{CustomerName}_clientHooks.js`).
4. **Deploy** the web resource to **Dev only** and publish; register the handler on the form event
   (event, library, function, pass execution context = true).
5. **Test** on the deployed form (OnLoad gating, OnChange, save paths).
6. **Update the TOPO map** (`hso-architecture-map`): add the `[CL]` block and SET client/server
   PARITY.

## Critical rules

- Documented Client API only (see the contract above).
- Guard every `getAttribute(...)` for null before use — a field absent from the form returns null and
  silently disables an OnLoad handler if unguarded.
- Deploy to **Dev**; verify the connection first. Never hand-edit exported web-resource XML.

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | maciejnowicki | Ported from prior in-house skills; neutralised; kept the documented-API-only upgradeability contract and the getAttribute-null gotcha. |
