---
adr: 0005
title: Client-side (TypeScript web resource) architecture
status: accepted
date: 2026-09-10
author: aidevme
supersedes: []
---

# ADR-0005 — Client-side architecture

## Context
The template needs a reusable, best-in-class client layer for Dataverse form scripting. Three
sources were compared (`docs/review-logs/part3-client-01-source-analysis.md`): **CDX/HINT** (a
TypeScript client with `dataverse-gen` early-bound types, webpack, jest + xrm-mock, and a
maintained **JSON-driven Rule Engine**, but with `console.*` logging and a clobber-prone
`libraryTarget:"var"` bundle, and CDX≡HINT duplication) and **the live-delivery source** (Solution-Checker-clean,
fail-open ES5 form scripts + a documented multi-bundle-safe `assign-properties` webpack fix, but
no types/tests/rule-engine, and an inert TS scaffold). The live-delivery source wants to standardise on TypeScript.
Constraints: reusable/neutral (ADR-0001, ADR-0003), buildable+tested locally (ADR-0001 §6), one
canonical copy, and — critically — the shipped bundle must pass the Power Apps **Solution
Checker** or it cannot be imported in a Managed Environment.

## Options considered
1. **Port CDX/HINT as-is.** Pros: least work, keeps the Rule Engine and tests. Cons: ships
   `console.*` (import blocker), keeps the `var` clobber trap, keeps duplicate copies, no
   Checker-encoded lint.
2. **Rebuild on the live-delivery source's ES5 discipline.** Pros: Checker-clean, fail-open. Cons: throws away the
   Rule Engine, types, and the whole test culture; contradicts the "standardise on TS" direction.
3. **Merge: CDX/HINT toolchain + Rule Engine as the spine, folded with the live-delivery source's Solution-Checker
   discipline and `assign-properties` packaging, one canonical de-duplicated copy, neutral
   ADR-0003 tokens.** Pros: keeps every high-value asset, fixes both concrete CDX defects, gates
   Checker rules at lint time. Cons: more up-front merge work; the ported engine stays frozen.

## Decision
Adopt **Option 3.** The client template is `ProjectTemplate/Client/clientjs`:

- **Language/types:** TypeScript 5 `strict` + `dataverse-gen` early-bound types (`.dataverse-gen.json`
  → `src/dataverse-gen/`, regenerated per project).
- **Bundling:** webpack dev/prod via `webpack-merge`, single `./src/index.ts` entry, output
  **`library: { type: 'assign-properties', name: 'HSO' }`** (the live-delivery source's multi-bundle-safe fix, NOT
  CDX's `var`). Bundle compiles via `tsconfig.build.json`, which excludes test code.
- **Handlers register as `HSO.<FormClass>.onFormLoad`**; `formName` is passed explicitly
  (minification-safe), logic lives in JSON rules.
- **Logging is console-FREE:** `Helpers/Logger` buffers records and forwards to an optional sink
  (default unset → silent). This is the fix for Solution Checker `remove-console`.
- **Lint encodes the Solution Checker rule list** (`.eslintrc.json`): `no-console`, no `eval`/
  implied-eval/`new Function`, no sync `XMLHttpRequest`, no `Xrm.Page`, `eqeqeq`, no `innerHTML`/
  `document.write`, no absolute Dataverse / `http://` URLs, no `window.top`/`parent`, no
  `debugger`/`alert`. Tests are exempted (never shipped).
- **Testing:** jest + ts-jest + xrm-mock, coverage enforced (branches 70 / functions 95 /
  lines 85 / statements 70; generated code + barrel excluded).
- **Rule Engine ported intact** (5 processors, privilege gating, perf monitor, error handler),
  treated as **frozen**. The **paired-inverse invariant** is enforced in code
  (`RuleEngine/validation/PairedInverseValidator`, `npm run validate:rules`), not just documented.
- **Config templating:** `powerPlatform.config.template.json` → git-ignored real config;
  `Scripts/push-webresources.ps1` builds + pushes the bundle and each rule JSON/XML.
- **Neutral tokens (ADR-0003):** `Customer` namespace, `hso_customer_` web-resource prefix
  (`config.ts webResourcePrefix`), rewritten by the init step.

## Rationale
Option 3 keeps the single biggest asset (a maintained, tested, declarative Rule Engine) and the
whole test culture, while fixing the two concrete defects the analysis named — `console.*`
logging and `var` clobber — and closing the discipline gap by making the Solution Checker rules
fail at lint time rather than at import. The no-console sink preserves the leveled API so call
sites are unchanged, and the console-mirroring test sink kept ~15 existing specs green. Encoding
the Checker rules in ESLint (proven to fire against a probe file) shifts a class of
Managed-Environment import failures left to the developer's keyboard. Freezing the ported engine
respects its maturity and avoids behaviour risk; the paired-inverse validator adds the one
correctness rule the engine cannot self-enforce.

## Consequences
- New form logic is written as JSON rules (paired), or a typed `Forms/<Entity>/<Form>.ts` handler
  where imperative; both are Checker-clean by lint.
- The bundle is safe to co-exist with other HSO bundles on a form (`assign-properties`).
- `dataverse-gen` output is committed and must be regenerated when the schema changes
  (documented in `docs/onboarding/client.md`); only `account`+`contact` ship by default.
- Coverage **lines** is gated at 85 (frozen-engine error paths); consumers should raise it.
- The init/rename engine (ADR-0003) must rewrite `Customer` / `hso_customer_` across this tree;
  a full rename must leave no orphan tokens and the bundle must still build.
