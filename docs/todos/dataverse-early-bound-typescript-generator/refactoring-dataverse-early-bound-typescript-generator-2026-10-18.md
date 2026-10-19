# Refactoring: dataverse-early-bound-typescript-generator (2026-10-18)

| | |
| --- | --- |
| Tool | `tools/dataverse-early-bound-typescript-generator` (Dataverse Early-Bound TypeScript Generator, 1.0.0) |
| Date | 2026-10-18 |
| Skill | `aidevme-pptb-tool-refactoring` |
| Scope | The layout components in `src/components/layout/` |
| Decision | Accepted all |
| Status | Executed |
| Branch | `features/dataverse-early-bound-typescript-generator` (not pushed) |
| Commits | `71e2420`..`cecf9bf` (6 commits) |
| Proposal version | v1, reviewed at commit `b96eb0e` on `features/dataverse-early-bound-typescript-generator` |

Follows [refactoring-dataverse-early-bound-typescript-generator-2026-10-17-03.md](./refactoring-dataverse-early-bound-typescript-generator-2026-10-17-03.md).

## TODO

Execution order: L1 → L2 → L3 → L4 → L5 → L6.

- [x] L1 (`71e2420`): add `header.test.ts` and `footer.test.ts` (files: new tests, `build-and-testing.md`; effort S; risk Low).
  Approved
- [x] L2 (`32b0e67`): fix the stale "docs site isn't published" comment and doc line (files: `Footer.tsx`, `footer.md`; effort S;
  risk Low). Approved
- [x] L3 (`7fcb031`): extract the connection pill into `layout/ConnectionStatus.tsx` with its own styles (files: `Header.tsx`,
  new component and styles, barrels, `header.md`; effort S; risk Low). Approved
- [x] L4 (`6cca0dc`): one shared `AppIcon` (`large` / `small`) for Header and Footer (files: both components, new `AppIcon.tsx`
  and styles, both styles files, docs; effort S; risk Low). Approved
- [x] L5 (`c5997a7`): keyboard-focusable connected pill so its URL tooltip is reachable; credit links say they open in a new
  window (files: `ConnectionStatus.tsx`, `Footer.tsx`, docs; effort S; risk Low, visible). Approved
- [x] L6 (`cecf9bf`): `HeaderProps` renamed to `IHeaderProps`, old name as a deprecated alias (files: `Header.tsx`, barrel,
  `header.md`; effort S; risk Low). Approved

## Analysis

Paths are relative to `tools/dataverse-early-bound-typescript-generator/src/`.

### a) Current state

| File | Lines | Notes |
| --- | --- | --- |
| `components/layout/Header.tsx` | 65 | Connection pill markup written twice (connected / disconnected, `:39-59`); the connected pill's URL tooltip is on a non-focusable `div` (`:40-41`); props type `HeaderProps` |
| `components/layout/Footer.tsx` | 70 | Stale comment on `DOCUMENTATION_URL` (`:6`; the URL returns 200); credit links open a new window without saying so (`:38-41`) |
| `styles/Header.styles.ts`, `styles/Footer.styles.ts` | 73, 67 | The app-icon tile (gradient, centred icon) defined twice, differing in size, radius and shadow |

Other findings: `docs/.../components/layout/footer.md:28` repeats the stale claim. No tests cover Header or Footer.
Baseline: no tool code change since `af441ed`, where `npm run build` passed and `npm test` passed 258 tests in 24
files.

Microsoft Learn references: searched; Learn doesn't document the Fluent UI React v9 Tooltip, so the tooltip finding
rests on the code evidence.

### c) Risk analysis

| ID | Risk | What could break | Mitigation | Rollback |
| --- | --- | --- | --- | --- |
| L1 | Low | Nothing (tests only) | — | Delete the tests |
| L2 | Low | Nothing (comment and docs) | — | Revert the commit |
| L3, L4 | Low | Header and footer markup and styles | Same markup and tokens; L1 tests | Revert the commit |
| L5 | Low | One more Tab stop; new screen-reader text | L1 tests updated; check in PPTB, light and dark themes | Revert the commit |
| L6 | Low | Imports | Deprecated alias; build | Revert the commit |

Breaking changes: none for users; generated output, saved config keys, the manifest and the IIFE build are untouched.

## Execution report

All six approved steps ran in the agreed order; none was skipped or failed. Each step was verified from the tool
folder with `npm run build` (tsc, including `test/`, then vite) and `npm test`, then committed.

| Step | Commit | Result | Verification |
| --- | --- | --- | --- |
| L1 | `71e2420` | `test/header.test.ts` (4 tests), `test/footer.test.ts` (3 tests) | build 0; 265 tests in 26 files |
| L2 | `32b0e67` | Stale "docs site isn't published" comment and doc line replaced | build 0; 265 tests in 26 files |
| L3 | `7fcb031` | `layout/ConnectionStatus.tsx` and `styles/ConnectionStatus.styles.ts`; docs page and sidebar entry | build 0; 265 tests in 26 files; docs:build 0 |
| L4 | `6cca0dc` | `layout/AppIcon.tsx` (`large` / `small`) and `styles/AppIcon.styles.ts` | build 0; 265 tests in 26 files |
| L5 | `c5997a7` | Connected pill is a Tab stop with a focus ring; credit tooltips say "Opens in a new window." (1 new test) | build 0; 266 tests in 26 files |
| L6 | `cecf9bf` | `IHeaderProps`, `HeaderProps` kept as a deprecated alias | build 0; 266 tests in 26 files |

Files changed since `b96eb0e`: 18 files, 294 insertions, 102 deletions. `npm run docs:build` passed after the last
step. Microsoft Learn: searched during the analysis; it doesn't cover the Fluent UI React v9 Tooltip, so no page was
relied on.

Deviations from the plan:

- L3 also added a `connection-status.md` docs page, its sidebar entry and a component index row, like other
  extracted components.
- L5 put the new-window hint in the credit tooltips (announced as their description) rather than adding a visible
  icon, so the chips look the same.

Not verified: none of the steps was tested live in PPTB, in the light or dark theme; L5's focus ring and tooltip
matter most.

## Follow-up TODOs

- [ ] Test live in PPTB, light and dark themes: the Header (connection pill connected and not connected, Tab to the
  pill and its tooltip, focus ring), the Footer (credit tooltips, links), and record the results in
  `contributing/testing.md`.
- [ ] The footer test waits 300 ms for the credit tooltip (Fluent's show delay); switch to fake timers if it turns
  flaky.
- [ ] Remove the deprecated `HeaderProps` alias with the other deprecated aliases in a later major version.
- [ ] Push the branch when ready (needs your confirmation).
